// Plans group — a DEBUG-only in-memory backend for plans, the weekly question and the developing state: the unit and
// snapshot tests (AppTests/Plans) and the Jolt demo (`DemoPlans`, launch argument `-PlansFakes`). It keeps rows as the
// database would and applies the server's rules the screens rely on (docs/API.md §14.2–§14.4): the maker answers Going,
// a new answer replaces the old one, Can't go rows reach only their author and the plan's maker, `next_plans` leaves
// canceled and past plans out.
#if DEBUG
import AppData
import AppModels
import Foundation

final class FakePlansData: PlansDataSource, QuestionDataSource, @unchecked Sendable {
    struct State {
        var me: UserID?
        var network: NetworkStatus = .online
        var groups: [PhotoGroup] = []
        var members: [GroupID: [MemberProfile]] = [:]
        var plans: [PlanID: Plan] = [:]
        var answers: [PlanAnswer] = []
        var photos: [PlanID: [PostWithMedia]] = [:]
        var questions: [GroupID: GroupQuestion] = [:]
        /// Newest first.
        var questionAnswers: [GroupQuestionID: [PostWithMedia]] = [:]
        var weeklyQuestion: [GroupID: Bool] = [:]
        var developing: [GroupID: OvernightStatus] = [:]
        /// Calls that throw: method name → error.
        var failures: [String: DataError] = [:]
        /// Every call, in order (method name).
        var calls: [String] = []
        /// Finds the caller's post of a media in a group (`answer_question` after posting): the demo reads the account
        /// data's feed, where the demo camera puts what it sends.
        var postLookup: (@Sendable (MediaID, GroupID) async -> PostWithMedia?)?
    }

    private let lock = NSLock()
    private var state = State()
    private var continuations: [UUID: (GroupID, AsyncStream<Void>.Continuation)] = [:]
    private var planContinuations: [UUID: (GroupID, AsyncStream<Void>.Continuation)] = [:]
    private let clock: @Sendable () -> Date

    init(me: UserID?, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.clock = clock
        state.me = me
    }

    func update(_ change: (inout State) -> Void) {
        lock.lock()
        change(&state)
        lock.unlock()
    }

    func read<T>(_ value: (State) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return value(state)
    }

    var calls: [String] { read(\.calls) }

    private func record(_ name: String) throws {
        let failure: DataError? = {
            lock.lock()
            defer { lock.unlock() }
            state.calls.append(name)
            return state.failures[name]
        }()
        if let failure { throw failure }
    }

    private func requireMe() throws -> UserID {
        guard let me = read(\.me) else { throw DataError.notSignedIn }
        return me
    }

    /// Tells `planChanges` subscribers of `groupID` (another member answered, or changed a plan).
    func notifyPlans(groupID: GroupID) {
        let targets: [AsyncStream<Void>.Continuation] = {
            lock.lock()
            defer { lock.unlock() }
            return planContinuations.values.filter { $0.0 == groupID }.map(\.1)
        }()
        targets.forEach { $0.yield(()) }
    }

    /// Tells `postChanges` subscribers of `groupID` (an answer arrived).
    func notify(groupID: GroupID) {
        let targets: [AsyncStream<Void>.Continuation] = {
            lock.lock()
            defer { lock.unlock() }
            return continuations.values.filter { $0.0 == groupID }.map(\.1)
        }()
        targets.forEach { $0.yield(()) }
    }

    private func timeZone(of groupID: GroupID) -> TimeZone {
        read { state in state.groups.first { $0.id == groupID }?.resolvedTimeZone } ?? .current
    }

    private func isOver(_ plan: Plan) -> Bool {
        plan.isOver(at: clock(), timeZone: timeZone(of: plan.groupID))
    }

    private func editablePlan(_ id: PlanID) throws -> Plan {
        guard let plan = read({ $0.plans[id] }) else { throw DataError.database(code: "PT404", message: PlansFailure.planNotFound) } // provenance-ok: fake server error code
        if isOver(plan) { throw DataError.database(code: "PT409", message: PlansFailure.planPast) } // provenance-ok: fake server error code
        return plan
    }

    // MARK: Shared

    func currentUser() async -> UserID? { read(\.me) }
    func networkStatus() async -> NetworkStatus { read(\.network) }

    func group(id: GroupID) async throws -> PhotoGroup? {
        try record("group")
        return read { $0.groups.first { $0.id == id } }
    }

    func myGroups() async throws -> [PhotoGroup] {
        try record("myGroups")
        return read(\.groups)
    }

    func members(groupID: GroupID) async throws -> [MemberProfile] {
        try record("members")
        return read { $0.members[groupID] ?? [] }
    }

    // MARK: Plans

    func nextPlans(groupID: GroupID?) async throws -> [UpcomingPlan] {
        try record("nextPlans")
        let me = read(\.me)
        let (plans, answers) = read { ($0.plans.values, $0.answers) }
        return plans
            .filter { groupID == nil || $0.groupID == groupID }
            .filter { !$0.isCanceled && !isOver($0) }
            .sorted { $0.startsAt == $1.startsAt ? $0.id < $1.id : $0.startsAt < $1.startsAt }
            .map { plan in UpcomingPlan(plan, myAnswer: answers.first { $0.planID == plan.id && $0.userID == me }?.answer) }
    }

    /// As `group_plans`: upcoming soonest first, then past latest first, then cancelled latest first.
    func groupPlans(groupID: GroupID) async throws -> [GroupPlan] {
        try record("groupPlans")
        let me = read(\.me)
        let (plans, answers) = read { ($0.plans.values, $0.answers) }
        func state(_ plan: Plan) -> GroupPlanState { plan.isCanceled ? .canceled : isOver(plan) ? .past : .upcoming }
        func rank(_ state: GroupPlanState) -> Int { state == .upcoming ? 0 : state == .past ? 1 : 2 }
        return plans
            .filter { $0.groupID == groupID }
            .map { plan in GroupPlan(plan, myAnswer: answers.first { $0.planID == plan.id && $0.userID == me }?.answer, state: state(plan)) }
            .sorted { lhs, rhs in
                if rank(lhs.state) != rank(rhs.state) { return rank(lhs.state) < rank(rhs.state) }
                if lhs.startsAt != rhs.startsAt { return lhs.state == .upcoming ? lhs.startsAt < rhs.startsAt : lhs.startsAt > rhs.startsAt }
                return lhs.id < rhs.id
            }
    }

    func plan(id: PlanID) async throws -> Plan? {
        try record("plan")
        return read { $0.plans[id] }
    }

    func answers(planID: PlanID) async throws -> [PlanAnswer] {
        try record("answers")
        let me = read(\.me)
        let maker = read { $0.plans[planID]?.createdBy }
        return read(\.answers)
            .filter { $0.planID == planID }
            .filter { $0.answer != .cantGo || $0.userID == me || (maker != nil && maker == me) }
            .sorted { $0.answeredAt < $1.answeredAt }
    }

    func photos(planID: PlanID) async throws -> [PostWithMedia] {
        try record("photos")
        guard read({ $0.plans[planID]?.isCanceled }) != true else { return [] }
        return read { $0.photos[planID] ?? [] }
    }

    func createPlan(groupID: GroupID, fields: PlanFields) async throws -> Plan {
        try record("createPlan")
        let me = try requireMe()
        let now = clock()
        let plan = Plan(
            id: PlanID(UUID().uuidString), groupID: groupID, createdBy: me, title: fields.title,
            startsAt: fields.startsAt, allDay: fields.allDay, localDate: LocalDate(fields.startsAt, in: timeZone(of: groupID)),
            place: fields.place, note: fields.note, coverPath: fields.coverPath, createdAt: now, updatedAt: now
        )
        update { state in
            state.plans[plan.id] = plan
            state.answers.append(PlanAnswer(planID: plan.id, userID: me, groupID: groupID, answer: .going, answeredAt: now))
        }
        return plan
    }

    func updatePlan(id: PlanID, fields: PlanFields) async throws -> Plan {
        try record("updatePlan")
        var plan = try editablePlan(id)
        plan.title = fields.title
        plan.startsAt = fields.startsAt
        plan.allDay = fields.allDay
        plan.localDate = LocalDate(fields.startsAt, in: timeZone(of: plan.groupID))
        plan.place = fields.place
        plan.note = fields.note
        plan.coverPath = fields.coverPath
        plan.updatedAt = clock()
        let saved = plan
        update { $0.plans[id] = saved }
        return saved
    }

    func cancelPlan(id: PlanID) async throws -> Plan {
        try record("cancelPlan")
        var plan = try editablePlan(id)
        plan.canceledAt = clock()
        plan.canceledBy = read(\.me)
        let saved = plan
        update { $0.plans[id] = saved }
        return saved
    }

    func restorePlan(id: PlanID) async throws -> Plan {
        try record("restorePlan")
        var plan = try editablePlan(id)
        plan.canceledAt = nil
        plan.canceledBy = nil
        let saved = plan
        update { $0.plans[id] = saved }
        return saved
    }

    func answer(planID: PlanID, _ answer: PlanAnswerKind) async throws {
        try record("answer")
        let me = try requireMe()
        let plan = try editablePlan(planID)
        if plan.isCanceled { throw DataError.database(code: "PT409", message: PlansFailure.planCanceled) } // provenance-ok: fake server error code
        let now = clock()
        update { state in
            state.answers.removeAll { $0.planID == planID && $0.userID == me }
            state.answers.append(PlanAnswer(planID: planID, userID: me, groupID: plan.groupID, answer: answer, answeredAt: now))
        }
    }

    func clearAnswer(planID: PlanID) async throws {
        try record("clearAnswer")
        let me = try requireMe()
        _ = try editablePlan(planID)
        update { $0.answers.removeAll { $0.planID == planID && $0.userID == me } }
    }

    /// Keeps the picked cover for the session (as the demo camera keeps what it sends), so it shows on the plan page.
    func uploadCover(jpeg: Data) async throws -> String {
        try record("uploadCover")
        let path = DemoPhotos.sentPrefix + UUID().uuidString.lowercased()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg") // provenance-ok: temporary file name
        try jpeg.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        _ = DemoPhotos.keepSent(file, path: path)
        return path
    }

    // MARK: Weekly question

    func currentQuestion(groupID: GroupID) async throws -> GroupQuestion? {
        try record("currentQuestion")
        return read { state in state.weeklyQuestion[groupID] == true ? state.questions[groupID] : nil }
    }

    func answers(questionID: GroupQuestionID, groupID: GroupID) async throws -> [PostWithMedia] {
        try record("questionAnswers")
        return read { $0.questionAnswers[questionID] ?? [] }.filter { $0.post.groupID == groupID }
    }

    func hideQuestion(id: GroupQuestionID) async throws {
        try record("hideQuestion")
        update { state in
            for (group, question) in state.questions where question.id == id {
                state.questions[group]?.hiddenByMe = true
            }
        }
    }

    func answerQuestion(mediaID: MediaID, groupID: GroupID, questionID: GroupQuestionID) async throws {
        try record("answerQuestion")
        guard let lookup = read(\.postLookup), let post = await lookup(mediaID, groupID) else { return }
        update { state in
            var answers = state.questionAnswers[questionID] ?? []
            answers.removeAll { $0.id == post.id }
            answers.insert(post, at: 0)
            state.questionAnswers[questionID] = answers
        }
        notify(groupID: groupID)
    }

    func weeklyQuestionSetting(groupID: GroupID) async throws -> (isOn: Bool, isAdmin: Bool) {
        try record("weeklyQuestionSetting")
        let me = read(\.me)
        return read { state in
            let isAdmin = state.members[groupID]?.first { $0.member.userID == me }?.member.role == .admin
            return (state.weeklyQuestion[groupID] ?? false, isAdmin)
        }
    }

    func setWeeklyQuestion(groupID: GroupID, on: Bool) async throws {
        try record("setWeeklyQuestion")
        update { $0.weeklyQuestion[groupID] = on }
    }

    // MARK: Developing

    func developing(groupID: GroupID) async throws -> OvernightStatus {
        try record("developing")
        return read { $0.developing[groupID] ?? .notDeveloping }
    }

    func planChanges(groupID: GroupID) -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        let id = UUID()
        lock.lock()
        planContinuations[id] = (groupID, continuation)
        lock.unlock()
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            self.lock.lock()
            self.planContinuations[id] = nil
            self.lock.unlock()
        }
        return stream
    }

    func postChanges(groupID: GroupID) -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        let id = UUID()
        lock.lock()
        continuations[id] = (groupID, continuation)
        lock.unlock()
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            self.lock.lock()
            self.continuations[id] = nil
            self.lock.unlock()
        }
        return stream
    }
}
#endif

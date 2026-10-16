// Data access for the plans group (plans.create, plans.page, the groups.screen plan row, widget.countdown) and the
// weekly question / developing state (question.weekly, camera.overnight B).
// Everything goes through AppData (docs/API.md §14); this file only narrows it to what these screens use, so view
// models can be tested with fakes (AppTests/Plans) and the demo build can run on its sample world (`FakePlansData`).
import AppData
import AppModels
import Foundation

/// What the plan screens read and write. `LivePlansData` forwards to AppData's repositories; `FakePlansData` (DEBUG)
/// serves the demo's and the tests' rows.
protocol PlansDataSource: Sendable {
    /// The signed-in user (nil when signed out).
    func currentUser() async -> UserID?
    /// The data layer's reachability reading.
    func networkStatus() async -> NetworkStatus

    func group(id: GroupID) async throws -> PhotoGroup?
    /// The caller's groups (the countdown widget's group names).
    func myGroups() async throws -> [PhotoGroup]
    /// The group's members with their profiles (names, avatars, roles).
    func members(groupID: GroupID) async throws -> [MemberProfile]

    /// `next_plans`: upcoming plans of one group (or all the caller's groups), soonest first, with the caller's answer.
    func nextPlans(groupID: GroupID?) async throws -> [UpcomingPlan]
    func plan(id: PlanID) async throws -> Plan?
    /// Answers visible to the caller (RLS: Can't go only for its author and the maker), oldest first.
    func answers(planID: PlanID) async throws -> [PlanAnswer]
    /// `plan_photos` with their media, oldest first.
    func photos(planID: PlanID) async throws -> [PostWithMedia]

    func createPlan(groupID: GroupID, fields: PlanFields) async throws -> Plan
    func updatePlan(id: PlanID, fields: PlanFields) async throws -> Plan
    func cancelPlan(id: PlanID) async throws -> Plan
    func restorePlan(id: PlanID) async throws -> Plan
    func answer(planID: PlanID, _ answer: PlanAnswerKind) async throws
    func clearAnswer(planID: PlanID) async throws
    /// Uploads a cover JPEG the way group covers are uploaded; returns its storage path.
    func uploadCover(jpeg: Data) async throws -> String
}

/// What the weekly question card, its camera hand-off, the `groups.settings` switch and the developing tile read and
/// write.
protocol QuestionDataSource: Sendable {
    func currentUser() async -> UserID?

    /// `current_group_question`; nil when the group has it off or no questions are configured.
    func currentQuestion(groupID: GroupID) async throws -> GroupQuestion?
    /// The question's answers with their media, newest first.
    func answers(questionID: GroupQuestionID, groupID: GroupID) async throws -> [PostWithMedia]
    func hideQuestion(id: GroupQuestionID) async throws
    /// Links the caller's post of `mediaID` in `groupID` (just sent from the camera) to the question.
    func answerQuestion(mediaID: MediaID, groupID: GroupID, questionID: GroupQuestionID) async throws

    /// `groups.weekly_question` and the caller's role (the switch is the admins').
    func weeklyQuestionSetting(groupID: GroupID) async throws -> (isOn: Bool, isAdmin: Bool)
    func setWeeklyQuestion(groupID: GroupID, on: Bool) async throws

    /// `group_developing`.
    func developing(groupID: GroupID) async throws -> OvernightStatus

    /// The group's realtime post inserts and updates (`group-<id>`): an answer arrived, a photo developed.
    func postChanges(groupID: GroupID) -> AsyncStream<Void>
}

/// The failure kinds the plan screens tell apart (each maps to a state in its spec). Plan errors are not in AppData's
/// `APIErrorCode` list (docs/API.md §3 predates §14), so they arrive as `DataError.database` with the code as message.
enum PlansFailure: Equatable, Sendable {
    case offline
    /// `plan_not_found` (removed from the group, RLS hides it).
    case notFound
    /// `plan_canceled` / `plan_past`: the plan changed under the screen.
    case closed
    case generic

    init(_ error: Error) {
        let data = DataError.from(error)
        switch data {
        case .offline:
            self = .offline
        case let .database(_, message) where message == Self.planNotFound:
            self = .notFound
        case let .database(_, message) where message == Self.planCanceled || message == Self.planPast:
            self = .closed
        case .api(.notGroupMember, _):
            self = .notFound
        default:
            self = .generic
        }
    }

    // docs/API.md §14.2 error codes.
    static let planNotFound = "plan_not_found" // provenance-ok: API error code
    static let planCanceled = "plan_canceled" // provenance-ok: API error code
    static let planPast = "plan_past" // provenance-ok: API error code
}

/// AppData-backed plans source used by the app.
struct LivePlansData: PlansDataSource {
    let environment: DataEnvironment

    func currentUser() async -> UserID? {
        environment.auth.currentUserID
    }

    func networkStatus() async -> NetworkStatus {
        environment.reachability.currentStatus
    }

    func group(id: GroupID) async throws -> PhotoGroup? {
        try await environment.groups.group(id: id)
    }

    func myGroups() async throws -> [PhotoGroup] {
        try await environment.groups.myGroups()
    }

    func members(groupID: GroupID) async throws -> [MemberProfile] {
        try await environment.groups.members(groupID: groupID)
    }

    func nextPlans(groupID: GroupID?) async throws -> [UpcomingPlan] {
        try await environment.plans.nextPlans(groupID: groupID)
    }

    func plan(id: PlanID) async throws -> Plan? {
        try await environment.plans.plan(id: id)
    }

    func answers(planID: PlanID) async throws -> [PlanAnswer] {
        try await environment.plans.answers(planID: planID)
    }

    func photos(planID: PlanID) async throws -> [PostWithMedia] {
        let posts = try await environment.plans.photos(planID: planID)
        return try await environment.posts.withMedia(posts)
    }

    func createPlan(groupID: GroupID, fields: PlanFields) async throws -> Plan {
        try await environment.plans.create(groupID: groupID, fields: fields)
    }

    func updatePlan(id: PlanID, fields: PlanFields) async throws -> Plan {
        try await environment.plans.update(id: id, fields: fields)
    }

    func cancelPlan(id: PlanID) async throws -> Plan {
        try await environment.plans.cancel(id: id)
    }

    func restorePlan(id: PlanID) async throws -> Plan {
        try await environment.plans.restore(id: id)
    }

    func answer(planID: PlanID, _ answer: PlanAnswerKind) async throws {
        try await environment.plans.answer(planID: planID, answer)
    }

    func clearAnswer(planID: PlanID) async throws {
        try await environment.plans.clearAnswer(planID: planID)
    }

    func uploadCover(jpeg: Data) async throws -> String {
        try await environment.uploader.uploadCover(jpeg: jpeg)
    }
}

/// AppData-backed question and developing source used by the app.
struct LiveQuestionData: QuestionDataSource {
    let environment: DataEnvironment

    func currentUser() async -> UserID? {
        environment.auth.currentUserID
    }

    func currentQuestion(groupID: GroupID) async throws -> GroupQuestion? {
        try await environment.questions.current(groupID: groupID)
    }

    func answers(questionID: GroupQuestionID, groupID: GroupID) async throws -> [PostWithMedia] {
        let posts = try await environment.questions.answers(questionID: questionID)
        return try await environment.posts.withMedia(posts.filter { $0.groupID == groupID })
    }

    func hideQuestion(id: GroupQuestionID) async throws {
        try await environment.questions.hide(questionID: id)
    }

    func answerQuestion(mediaID: MediaID, groupID: GroupID, questionID: GroupQuestionID) async throws {
        try await environment.questions.answer(mediaID: mediaID, groupID: groupID, questionID: questionID)
    }

    func weeklyQuestionSetting(groupID: GroupID) async throws -> (isOn: Bool, isAdmin: Bool) {
        let isOn = try await environment.questions.isOn(groupID: groupID)
        let membership = try await environment.groups.myMembership(groupID: groupID)
        return (isOn, membership?.role == .admin)
    }

    func setWeeklyQuestion(groupID: GroupID, on: Bool) async throws {
        try await environment.questions.setOn(groupID: groupID, on: on)
    }

    func developing(groupID: GroupID) async throws -> OvernightStatus {
        try await environment.questions.developing(groupID: groupID)
    }

    func postChanges(groupID: GroupID) -> AsyncStream<Void> {
        // `.all`: `developing_changed` arrives on the group's broadcast topic (camera.overnight, docs/API.md §14.3).
        let events = environment.realtime.events(for: groupID, filter: .all)
        return AsyncStream { continuation in
            let task = Task {
                for await event in events {
                    switch event {
                    case .postInserted, .postUpdated, .resubscribed, .developingChanged:
                        continuation.yield(())
                    default:
                        break
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Used while config/app.json has no Supabase URL / key (BLOCKED owner values): every call fails with
/// `DataError.notConfigured`, so screens show their error state.
struct UnconfiguredPlansData: PlansDataSource, QuestionDataSource {
    func currentUser() async -> UserID? { nil }
    func networkStatus() async -> NetworkStatus { .unknown }
    func group(id: GroupID) async throws -> PhotoGroup? { throw DataError.notConfigured }
    func myGroups() async throws -> [PhotoGroup] { throw DataError.notConfigured }
    func members(groupID: GroupID) async throws -> [MemberProfile] { throw DataError.notConfigured }
    func nextPlans(groupID: GroupID?) async throws -> [UpcomingPlan] { throw DataError.notConfigured }
    func plan(id: PlanID) async throws -> Plan? { throw DataError.notConfigured }
    func answers(planID: PlanID) async throws -> [PlanAnswer] { throw DataError.notConfigured }
    func photos(planID: PlanID) async throws -> [PostWithMedia] { throw DataError.notConfigured }
    func createPlan(groupID: GroupID, fields: PlanFields) async throws -> Plan { throw DataError.notConfigured }
    func updatePlan(id: PlanID, fields: PlanFields) async throws -> Plan { throw DataError.notConfigured }
    func cancelPlan(id: PlanID) async throws -> Plan { throw DataError.notConfigured }
    func restorePlan(id: PlanID) async throws -> Plan { throw DataError.notConfigured }
    func answer(planID: PlanID, _ answer: PlanAnswerKind) async throws { throw DataError.notConfigured }
    func clearAnswer(planID: PlanID) async throws { throw DataError.notConfigured }
    func uploadCover(jpeg: Data) async throws -> String { throw DataError.notConfigured }
    func currentQuestion(groupID: GroupID) async throws -> GroupQuestion? { throw DataError.notConfigured }
    func answers(questionID: GroupQuestionID, groupID: GroupID) async throws -> [PostWithMedia] { throw DataError.notConfigured }
    func hideQuestion(id: GroupQuestionID) async throws { throw DataError.notConfigured }
    func answerQuestion(mediaID: MediaID, groupID: GroupID, questionID: GroupQuestionID) async throws { throw DataError.notConfigured }
    func weeklyQuestionSetting(groupID: GroupID) async throws -> (isOn: Bool, isAdmin: Bool) { throw DataError.notConfigured }
    func setWeeklyQuestion(groupID: GroupID, on: Bool) async throws { throw DataError.notConfigured }
    func developing(groupID: GroupID) async throws -> OvernightStatus { throw DataError.notConfigured }
    func postChanges(groupID: GroupID) -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}

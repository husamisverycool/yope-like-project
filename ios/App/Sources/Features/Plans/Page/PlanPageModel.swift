// Plans group — PlanPageModel: state and actions of plans.page (PlanPageScreen.swift).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

@MainActor
@Observable
final class PlanPageModel {
    enum Phase: Equatable {
        case loading
        case loaded
        /// RLS hides the plan (removed from the group, or the maker is blocked).
        case notFound
        /// The first fetch failed; `isOfflineFailure` picks the copy.
        case error
    }

    /// A person in a list block or the people sheet.
    struct Person: Identifiable, Equatable {
        let id: UserID
        let firstName: String
        let avatarPath: String?
    }

    let planID: PlanID
    private(set) var phase: Phase = .loading
    private(set) var plan: Plan?
    private(set) var group: PhotoGroup?
    private(set) var members: [MemberProfile] = []
    private(set) var answers: [PlanAnswer] = []
    private(set) var photos: [PostWithMedia] = []
    private(set) var me: UserID?
    private(set) var isOffline = false
    private(set) var isOfflineFailure = false
    /// Bumped on each answer tap (`haptic.global.select`).
    private(set) var selectionCount = 0
    /// Bumped when an answer could not be saved (the toast `plans.page.error.answer`).
    private(set) var answerFailureCount = 0
    private(set) var isWorking = false

    /// The plan page shows at most 3 rows of the 3-column album grid; the album opens for the rest (plans.page item 8).
    static let albumRows = 3 // provenance-ok: row count named by the spec
    static let albumColumns = 3 // provenance-ok: column count named by the spec (C-21)

    private let services: PlansServices

    init(planID: PlanID, services: PlansServices) {
        self.planID = planID
        self.services = services
    }

    private var data: any PlansDataSource { services.plans }

    var timeZone: TimeZone { group?.resolvedTimeZone ?? .current }

    var myAnswer: PlanAnswerKind? {
        guard let me else { return nil }
        return answers.first { $0.userID == me }?.answer
    }

    var isCanceled: Bool { plan?.isCanceled ?? false }

    /// The plan's day has ended (or its end time passed): no answer row, lists read in the past.
    var isPast: Bool {
        guard let plan else { return false }
        return plan.isOver(at: services.now(), timeZone: timeZone)
    }

    /// Active plans whose day has not ended (plans.page item 5).
    var showsAnswerRow: Bool { plan != nil && !isCanceled && !isPast }

    private var isAdmin: Bool {
        members.first { $0.member.userID == me }?.member.role == .admin
    }

    /// The more menu (maker and admins, until the plan is over).
    var showsMenu: Bool {
        guard let plan, let me, !isPast else { return false }
        return plan.createdBy == me || isAdmin
    }

    var maker: Person? {
        plan?.createdBy.flatMap(person)
    }

    /// The meta block: the date and time (or "Canceled"), then the place.
    var whenLine: String {
        guard let plan else { return "" }
        if plan.isCanceled { return Copy.plansPageCanceled }
        return PlanFormats.whenLine(
            startsAt: plan.startsAt, allDay: plan.allDay, localDate: plan.localDate, timeZone: timeZone, now: services.now()
        )
    }

    /// The people who gave `answer`, oldest answer first (RLS: Can't go only reaches its author and the maker).
    func people(_ answer: PlanAnswerKind) -> [Person] {
        answers.filter { $0.answer == answer }.compactMap { person($0.userID) }
    }

    private func person(_ id: UserID) -> Person? {
        guard let member = members.first(where: { $0.member.userID == id }) else { return nil }
        let name = member.profile?.firstName ?? member.profile?.displayName ?? ""
        return Person(id: id, firstName: name, avatarPath: member.profile?.avatarPath)
    }

    /// The album block: after the plan's day, when the plan collected posts (none for a canceled plan).
    var albumPhotos: [PostWithMedia] {
        guard isPast, !isCanceled else { return [] }
        return Array(photos.prefix(Self.albumRows * Self.albumColumns))
    }

    // MARK: Loading

    /// Refetches on the group's plan changes (another member's answer, an edit, a cancel or restore; docs/API.md §14.2
    /// Realtime) until the calling task ends. Nothing before the plan is loaded (its group is not known yet).
    func followChanges() async {
        guard let groupID = plan?.groupID else { return }
        for await _ in data.planChanges(groupID: groupID) {
            await refresh()
        }
    }

    /// Fetches the plan, its group, members, answers and (after its day) its photos.
    func refresh() async {
        let data = self.data
        let planID = self.planID
        me = await data.currentUser()
        isOffline = await data.networkStatus() == .offline
        do {
            guard let plan = try await data.plan(id: planID) else {
                phase = .notFound
                return
            }
            let groupID = plan.groupID
            async let group = data.group(id: groupID)
            async let members = data.members(groupID: groupID)
            async let answers = data.answers(planID: planID)
            let loadedGroup = try await group
            let loadedMembers = try await members
            let loadedAnswers = try await answers
            self.plan = plan
            self.group = loadedGroup
            self.members = loadedMembers
            self.answers = loadedAnswers
            if isPast, !plan.isCanceled {
                photos = (try? await data.photos(planID: planID)) ?? photos
            }
            phase = .loaded
        } catch {
            switch PlansFailure(error) {
            case .notFound:
                phase = .notFound
            case .offline:
                isOffline = true
                isOfflineFailure = true
                if plan == nil { phase = .error }
            default:
                isOfflineFailure = false
                if plan == nil { phase = .error }
            }
        }
    }

    func retry() async {
        phase = .loading
        await refresh()
    }

    // MARK: Answering

    /// One tap commits (`answer_plan`); tapping the selected answer again clears it (`clear_answer`). Optimistic: the
    /// capsule and the lists change at once; a failure puts them back and shows `plans.page.error.answer`.
    func select(_ answer: PlanAnswerKind) async {
        guard showsAnswerRow, let me, let plan else { return }
        selectionCount += 1
        let previous = answers
        let clearing = myAnswer == answer
        answers.removeAll { $0.userID == me }
        if !clearing {
            answers.append(PlanAnswer(planID: planID, userID: me, groupID: plan.groupID, answer: answer, answeredAt: services.now()))
        }
        do {
            if clearing {
                try await data.clearAnswer(planID: planID)
            } else {
                try await data.answer(planID: planID, answer)
            }
            services.didChange()
        } catch {
            answers = previous
            answerFailureCount += 1
            if PlansFailure(error) == .closed { await refresh() }
        }
    }

    // MARK: Menu

    /// "Cancel Plan" after the native confirm (`cancel_plan`).
    func cancel() async {
        await change { try await self.data.cancelPlan(id: self.planID) }
    }

    /// "Restore Plan" (`restore_plan`).
    func restore() async {
        await change { try await self.data.restorePlan(id: self.planID) }
    }

    /// After "Edit Plan" saved.
    func edited(_ plan: Plan) {
        self.plan = plan
        Task { await refresh() }
    }

    private func change(_ action: @escaping () async throws -> Plan) async {
        isWorking = true
        defer { isWorking = false }
        do {
            plan = try await action()
            services.didChange()
        } catch {
            // `plan_past` / `plan_canceled`: the plan changed under the page; show what it is now.
            await refresh()
        }
    }
}

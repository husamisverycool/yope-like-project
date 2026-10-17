// Surface: plans.list — view model (design/surfaces/plans.list.md; `group_plans`, docs/API.md §14.2).
import AppData
import AppModels
import Foundation
import Observation

@MainActor
@Observable
final class PlansListModel {
    enum Phase: Equatable {
        case loading
        case loaded
        /// The group has no plan.
        case empty
        /// The fetch failed with nothing to show (tappable line, tap = retry).
        case error
        /// No connection and nothing to show.
        case offline
        /// `not_group_member`: the screen pops.
        case removed
    }

    /// One section of the list, in the server's order (Upcoming, Past Plans, Canceled), each only when it has plans.
    struct Section: Identifiable, Equatable {
        let state: GroupPlanState
        let plans: [GroupPlan]
        var id: GroupPlanState { state }
    }

    let groupID: GroupID
    private(set) var phase: Phase = .loading
    private(set) var sections: [Section] = []
    private(set) var timeZone: TimeZone = .current

    private let services: PlansServices

    init(groupID: GroupID, services: PlansServices) {
        self.groupID = groupID
        self.services = services
    }

    /// The row's day line: the medium date + short time (all-day: the date alone), as the group screen's plan row.
    func line(_ plan: GroupPlan) -> String {
        PlanFormats.rowLine(startsAt: plan.startsAt, allDay: plan.allDay, localDate: plan.localDate, timeZone: timeZone)
    }

    /// Refetches on the group's plan changes (Realtime, docs/API.md §14.2) until the calling task ends.
    func followChanges() async {
        for await _ in services.plans.planChanges(groupID: groupID) {
            await refresh()
        }
    }

    func refresh() async {
        do {
            let plans = try await services.plans.groupPlans(groupID: groupID)
            if let group = try? await services.plans.group(id: groupID) { timeZone = group.resolvedTimeZone }
            sections = [GroupPlanState.upcoming, .past, .canceled].compactMap { state in
                let inState = plans.filter { $0.state == state }
                return inState.isEmpty ? nil : Section(state: state, plans: inState)
            }
            phase = sections.isEmpty ? .empty : .loaded
        } catch {
            switch PlansFailure(error) {
            case .notFound:
                phase = .removed
            case .offline:
                // The last list stays; with nothing shown yet, the offline line.
                if sections.isEmpty { phase = .offline }
            case .closed, .generic:
                if sections.isEmpty { phase = .error }
            }
        }
    }

    func retry() async {
        phase = .loading
        await refresh()
    }
}

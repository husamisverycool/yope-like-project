// Where the plan screens, the weekly question and the developing tile get their data from: AppData
// (AppEnvironment.shared.data), or — in DEBUG builds launched with `-PlansFakes`, and in the Jolt demo build
// (`DemoMode`) — the in-memory `FakePlansData` keyed to the demo world (`DemoPlans`).
import AppData
import AppModels
import Foundation
import Observation

@MainActor
@Observable
final class PlansServices {
    let plans: any PlansDataSource
    let questions: any QuestionDataSource
    let now: @Sendable () -> Date

    /// Bumped whenever a plan, an answer, the question card or the developing state changed on this device: the group
    /// screen's plan row, the plan page and the countdown widget's snapshot refetch (`.task(id:)`).
    private(set) var revision = 0

    init(plans: any PlansDataSource, questions: any QuestionDataSource, now: @escaping @Sendable () -> Date = { Date() }) {
        self.plans = plans
        self.questions = questions
        self.now = now
    }

    /// The services every plan / question screen reads (tests replace it).
    static var shared: PlansServices = resolve()

    static func resolve() -> PlansServices {
        #if DEBUG
        if PlansLaunch.usesFakes {
            let fake = DemoPlans.makeData()
            return PlansServices(plans: fake, questions: fake)
        }
        #endif
        if let environment = AppEnvironment.shared.data {
            return PlansServices(plans: LivePlansData(environment: environment), questions: LiveQuestionData(environment: environment))
        }
        let unconfigured = UnconfiguredPlansData()
        return PlansServices(plans: unconfigured, questions: unconfigured)
    }

    /// Something changed: dependants refetch, and the countdown widget's snapshot is rewritten.
    func didChange() {
        revision += 1
        PlanWidgetSync.shared.refresh()
    }
}

#if DEBUG
/// The launch argument that switches plans, the weekly question and the developing tile to the in-memory fakes (on in
/// the Jolt demo build).
enum PlansLaunch {
    static let fakesArgument = "-PlansFakes" // provenance-ok: launch argument, not user-facing

    static var usesFakes: Bool {
        DemoMode.isOn || DemoMode.launchArguments.contains(fakesArgument)
    }
}
#endif

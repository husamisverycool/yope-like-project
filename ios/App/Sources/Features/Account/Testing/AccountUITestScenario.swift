// Account group — DEBUG-only launch scenarios with in-memory data, for UI tests (ios/AppUITests/Account) and other groups'
// UI tests that need a signed-in member: launch the app with `-account-ui-test-scenario <name>`.
//
//   signed-out   fresh install: auth.phone → auth.code (code 123456) → auth.agegate → auth.profile →
//                onboarding.permission.notifications → onboarding.widget → groups.list (empty)
//   signed-in    an onboarded member ("Ana Lima") with no groups: groups.list empty state
//   with-groups  an onboarded member in two groups with photos: groups.list with cards
#if DEBUG
import AppData
import AppModels
import Foundation

enum AccountUITestScenario: String, CaseIterable {
    case signedOut = "signed-out"
    case signedIn = "signed-in"
    case withGroups = "with-groups"

    static let argument = "-account-ui-test-scenario" // provenance-ok: launch argument, not user-facing

    static func fromLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> AccountUITestScenario? {
        guard let index = arguments.firstIndex(of: argument), arguments.indices.contains(index + 1) else { return nil }
        return AccountUITestScenario(rawValue: arguments[index + 1])
    }

    /// The scenario's data (also used by unit and snapshot tests).
    @MainActor
    func makeData() -> InMemoryAccountData {
        let data = InMemoryAccountData()
        guard self != .signedOut else { return data }
        let me = data.addProfile("Ana Lima") // provenance-ok: test fixture
        data.currentUserID = me.id
        data.privateProfile = ProfilePrivate(userID: me.id, birthday: nil, birthdayOptIn: false, ageConfirmedAt: Date(timeIntervalSince1970: 1_790_000_000), updatedAt: Date(timeIntervalSince1970: 1_790_000_000))
        if self == .withGroups {
            let rui = data.addProfile("Rui Costa") // provenance-ok: test fixture
            let family = data.addGroup("Lima family", kind: .family, createdBy: me.id, members: [me, rui]) // provenance-ok: test fixture
            data.addPost(groupID: family.id, author: rui.id, minutesAgo: 5, caption: nil)
            let friends = data.addGroup("Sunday dinners", kind: .friends, createdBy: rui.id, members: [rui, me]) // provenance-ok: test fixture
            data.addPost(groupID: friends.id, author: me.id, minutesAgo: 90, caption: nil)
        }
        return data
    }

    @MainActor
    func makeDependencies(router: AppRouter, configuration: AppConfiguration) -> AccountDependencies {
        let defaults = UserDefaults(suiteName: "account.uitest") ?? .standard // provenance-ok: defaults suite name
        defaults.removePersistentDomain(forName: "account.uitest") // provenance-ok: defaults suite name
        let purchases = InMemoryPurchases()
        return AccountDependencies.live(
            data: makeData(),
            router: router,
            configuration: configuration,
            notifications: StaticNotificationAuthorizer(status: .notDetermined, answer: .granted),
            purchases: purchases,
            liveActivity: LiveActivityPreference(defaults: defaults),
            refusals: InMemoryAgeGateRefusalStore(),
            onboarding: OnboardingRecord(defaults: defaults)
        )
    }
}
#endif

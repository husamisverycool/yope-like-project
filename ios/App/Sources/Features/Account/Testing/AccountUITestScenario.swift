// Account group — DEBUG-only launch scenarios with in-memory data, for UI tests (ios/AppUITests/Account) and other groups'
// UI tests that need a signed-in member: launch the app with `-account-ui-test-scenario <name>`.
//
//   signed-out   fresh install: auth.phone → auth.code (code 123456) → auth.agegate → auth.profile →
//                onboarding.permission.notifications → onboarding.widget → groups.list (empty)
//   signed-in    an onboarded member ("Ana Lima") with no groups: groups.list empty state
//   with-groups  an onboarded member in two groups with photos: groups.list with cards
//   demo         the Jolt demo build (`DemoMode`): Sam Reed in the social demo's "roommates" and "climbing", with their
//                people, posts and last week's recap (`SocialDemo`); opens to the camera like a member with groups
#if DEBUG
import AppData
import AppModels
import Foundation

enum AccountUITestScenario: String, CaseIterable {
    case signedOut = "signed-out"
    case signedIn = "signed-in"
    case withGroups = "with-groups"
    case demo = "demo"

    static let argument = "-account-ui-test-scenario" // provenance-ok: launch argument, not user-facing
    /// Invite host of the UI-test scenarios while the owner's domain is unset (DEBUG only).
    static let inviteTestHost = "invite.e2e.test" // provenance-ok: reserved test host (RFC 6761), not user-facing

    /// `arguments`: the launch arguments, with the Jolt demo build's (`DemoMode`).
    static func fromLaunchArguments(_ arguments: [String] = DemoMode.launchArguments) -> AccountUITestScenario? {
        guard let index = arguments.firstIndex(of: argument), arguments.indices.contains(index + 1) else { return nil }
        return AccountUITestScenario(rawValue: arguments[index + 1])
    }

    /// The scenario's data (also used by unit and snapshot tests).
    @MainActor
    func makeData() -> InMemoryAccountData {
        if self == .demo { return Self.makeDemoData() }
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

    /// The Jolt demo's account data: the social demo's world (`SocialDemo`), so the groups list, each group's screen and
    /// its chat, viewer, recaps and albums all show the same people, groups and posts.
    @MainActor
    static func makeDemoData() -> InMemoryAccountData {
        let data = InMemoryAccountData()
        let world = SocialDemo.self
        for profile in world.profiles { data.profilesByID[profile.id] = profile }
        data.currentUserID = world.me
        let confirmed = world.monday.addingTimeInterval(-30 * world.day)
        data.privateProfile = ProfilePrivate(userID: world.me, birthday: nil, birthdayOptIn: false, ageConfirmedAt: confirmed, updatedAt: confirmed)
        data.groups = [
            world.group(world.groupID, name: "roommates", createdBy: world.ana), // provenance-ok: demo data
            world.group(world.otherGroupID, name: "climbing", createdBy: world.me), // provenance-ok: demo data
        ]
        data.membersByGroup[world.groupID] = [
            world.member(world.ana, in: world.groupID, role: .admin), world.member(world.me, in: world.groupID),
            world.member(world.ben, in: world.groupID), world.member(world.cleo, in: world.groupID),
        ]
        data.membersByGroup[world.otherGroupID] = [
            world.member(world.me, in: world.otherGroupID, role: .admin), world.member(world.ben, in: world.otherGroupID),
        ]
        for post in world.posts {
            data.postsByGroup[post.post.groupID, default: []].append(post)
        }
        for group in data.postsByGroup.keys {
            data.postsByGroup[group]?.sort { $0.post.createdAt > $1.post.createdAt }
        }
        if let recap = world.recaps.first(where: { $0.status == .ready }) {
            data.recaps[world.groupID] = recap
        }
        return data
    }

    @MainActor
    func makeDependencies(router: AppRouter, configuration: AppConfiguration) -> AccountDependencies {
        let suite = self == .demo ? "jolt.demo" : "account.uitest" // provenance-ok: defaults suite names
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        let purchases = InMemoryPurchases()
        // config/app.json `domain` is the owner's (BLOCKED): UI tests build invite links on a reserved test host
        // (RFC 6761 `.test`, as the Android on-device journey) so link sharing, the share targets and the QR card show.
        var configuration = configuration
        if configuration.domain == nil { configuration.domain = Self.inviteTestHost }
        let data = makeData()
        let onboarding = OnboardingRecord(defaults: defaults)
        // The demo member has finished onboarding: the app opens home (to the camera, as with groups).
        if self == .demo, let me = data.currentUserID { onboarding.markComplete(for: me.rawValue) }
        // Signed-in scenarios are members onboarded on this phone: its onboarding pages were shown.
        if self != .signedOut { onboarding.markDevicePagesShown() }
        return AccountDependencies.live(
            data: data,
            router: router,
            configuration: configuration,
            notifications: StaticNotificationAuthorizer(status: .notDetermined, answer: .granted),
            purchases: purchases,
            liveActivity: LiveActivityPreference(defaults: defaults),
            refusals: InMemoryAgeGateRefusalStore(),
            onboarding: onboarding
        )
    }
}
#endif

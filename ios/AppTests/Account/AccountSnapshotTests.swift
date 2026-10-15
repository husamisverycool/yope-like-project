// One snapshot per account screen per state, recorded into ios/build/snapshots/account/<surface>-<state>.png for the
// side-by-side verification (design/verification/<surface>.png, made by the lead from the CI artifact). Every screen
// runs on in-memory data (InMemoryAccountData) with the dark appearance the app forces.
@testable import App
import AppData
import AppModels
import DesignSystem
import SnapshotTesting
import SwiftUI
import XCTest

/// Records `ios/build/snapshots/account/<surface>-<state>.png` (SnapshotRecorder writes `<test>.<name>.png`; the file
/// is renamed to the surface/state name the verification step uses).
enum AccountSnapshot {
    static let folder = SnapshotRecorder.directory.appendingPathComponent("account", isDirectory: true)

    @MainActor
    @discardableResult
    static func record<V: View>(
        _ view: V,
        surface: String,
        state: String,
        dependencies: AccountDependencies,
        layout: SwiftUISnapshotLayout = .device(config: .iPhone13),
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) -> URL? {
        let name = "\(surface)-\(state)"
        let hosted = view
            .environment(dependencies)
            .environment(\.storageURLResolver, dependencies.storageURLResolver)
            .toastHost(dependencies.toasts)
            .environment(\.colorScheme, .dark)
            .preferredColorScheme(.dark)
        guard let written = SnapshotRecorder.record(hosted, named: name, group: "account", layout: layout, file: file, testName: testName, line: line) else {
            return nil
        }
        let target = folder.appendingPathComponent("\(name).png")
        try? FileManager.default.removeItem(at: target)
        do {
            try FileManager.default.moveItem(at: written, to: target)
        } catch {
            return written
        }
        return target
    }
}

@MainActor
final class AccountSnapshotTests: XCTestCase {
    private var fixture: AccountFixture!
    private var dependencies: AccountDependencies!

    override func setUp() async throws {
        fixture = AccountFixture()
        dependencies = makeDependencies(fixture.data)
    }

    private func makeDependencies(_ data: InMemoryAccountData, status: PermissionStatus = .notDetermined, purchases: InMemoryPurchases = InMemoryPurchases()) -> AccountDependencies {
        let suite = "account.snapshots." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        return AccountDependencies.live(
            data: data,
            router: AppRouter(parser: .init(universalLinkHosts: [])),
            configuration: AppConfiguration(),
            notifications: StaticNotificationAuthorizer(status: status),
            purchases: purchases,
            liveActivity: LiveActivityPreference(defaults: defaults),
            refusals: InMemoryAgeGateRefusalStore(),
            onboarding: OnboardingRecord(defaults: defaults)
        )
    }

    private func record<V: View>(_ view: V, _ surface: String, _ state: String, file: StaticString = #filePath, line: UInt = #line) {
        let url = AccountSnapshot.record(view, surface: surface, state: state, dependencies: dependencies, file: file, line: line)
        XCTAssertNotNil(url, "\(surface)-\(state) not written", file: file, line: line)
    }

    /// Starts `work` with the data answering slowly and returns once `inFlight` holds (the in-progress state).
    private func whileInFlight(_ inFlight: @escaping () -> Bool, _ work: @escaping () async -> Void) async -> Task<Void, Never> {
        fixture.data.latency = .seconds(30)
        let task = Task { @MainActor in await work() }
        await waitUntil(inFlight)
        return task
    }

    // MARK: auth.phone

    func testAuthPhone() async {
        record(PhoneScreen(model: PhoneModel(data: fixture.data, phone: "+1")), "auth.phone", "default")
        record(PhoneScreen(model: PhoneModel(data: fixture.data, phone: "+1 555 123 4567")), "auth.phone", "filled")

        let sending = PhoneModel(data: fixture.data, phone: "+1 555 123 4567")
        let task = await whileInFlight({ sending.isSending }) { _ = await sending.send() }
        record(PhoneScreen(model: sending), "auth.phone", "sending")
        task.cancel()
        fixture.data.latency = nil

        fixture.data.failures["sendCode"] = .offline
        let offline = PhoneModel(data: fixture.data, phone: "+1 555 123 4567")
        _ = await offline.send()
        record(PhoneScreen(model: offline), "auth.phone", "offline")
    }

    // MARK: auth.code

    private func codeScreen(_ model: CodeModel) -> some View {
        CodeScreen(model: model, network: dependencies.network, toasts: dependencies.toasts, onVerified: { _ in }, onBack: {})
    }

    func testAuthCode() async {
        record(codeScreen(CodeModel(phone: "+15551234567", data: fixture.data, sleep: { _ in })), "auth.code", "default")
        let filled = CodeModel(phone: "+15551234567", data: fixture.data, sleep: { _ in })
        filled.setCode("123456")
        record(codeScreen(filled), "auth.code", "filled")

        let verifying = CodeModel(phone: "+15551234567", data: fixture.data, sleep: { _ in })
        verifying.setCode("123456")
        let task = await whileInFlight({ verifying.isVerifying }) { await verifying.verify { _ in } }
        record(codeScreen(verifying), "auth.code", "verifying")
        task.cancel()
        fixture.data.latency = nil

        fixture.data.failures["verifyCode"] = .offline
        let offline = CodeModel(phone: "+15551234567", data: fixture.data, sleep: { _ in })
        offline.setCode("123456")
        await offline.verify { _ in }
        record(codeScreen(offline), "auth.code", "offline")
    }

    // MARK: auth.agegate

    func testAuthAgeGate() async {
        let entry = BirthdayEntry(pattern: "MM/dd/y")
        record(AgeGateScreen(model: AgeGateModel(data: fixture.data, entry: entry)), "auth.agegate", "default")

        let filled = AgeGateModel(data: fixture.data, entry: entry)
        filled.setText("05262000")
        filled.optIn = true
        record(AgeGateScreen(model: filled), "auth.agegate", "filled-opt-in")

        let invalid = AgeGateModel(data: fixture.data, entry: entry)
        invalid.setText("02302000")
        _ = await invalid.confirm()
        record(AgeGateScreen(model: invalid), "auth.agegate", "invalid-date")

        fixture.data.failures["confirmAge"] = .api(.ageGateNotConfigured)
        let closed = AgeGateModel(data: fixture.data, entry: entry)
        closed.setText("05262000")
        _ = await closed.confirm()
        record(AgeGateScreen(model: closed), "auth.agegate", "not-configured")

        fixture.data.failures["confirmAge"] = .offline
        let offline = AgeGateModel(data: fixture.data, entry: entry)
        offline.setText("05262000")
        _ = await offline.confirm()
        record(AgeGateScreen(model: offline), "auth.agegate", "offline")

        record(AgeGateRefusedScreen(minAge: 13), "auth.agegate", "under-age")
    }

    // MARK: auth.profile

    func testAuthProfile() async {
        record(ProfileScreen(model: ProfileModel(data: fixture.data)), "auth.profile", "default")
        let filled = ProfileModel(data: fixture.data)
        filled.setName("Ana")
        record(ProfileScreen(model: filled), "auth.profile", "filled")

        let saving = ProfileModel(data: fixture.data)
        saving.setName("Ana")
        let task = await whileInFlight({ saving.isSaving }) { _ = await saving.save() }
        record(ProfileScreen(model: saving), "auth.profile", "saving")
        task.cancel()
        fixture.data.latency = nil

        fixture.data.failures["updateProfile"] = .offline
        let offline = ProfileModel(data: fixture.data)
        offline.setName("Ana")
        _ = await offline.save()
        record(ProfileScreen(model: offline), "auth.profile", "offline")
    }

    // MARK: onboarding

    func testOnboarding() {
        record(NotificationsPermissionScreen(notifications: StaticNotificationAuthorizer(status: .notDetermined), onAnswered: {}),
               "onboarding.permission.notifications", "default")
        record(WidgetGuideScreen(onContinue: {}), "onboarding.widget", "default")
        record(PermissionCardHost(card: .cameraDenied(onEnable: {})), "onboarding.permission.camera", "denied")
        record(PermissionCardHost(card: .photosDenied(onEnable: {}, onDismiss: {})), "onboarding.permission.photos", "denied")
    }

    // MARK: groups.list

    func testGroupsList() async {
        let loading = GroupsListModel(data: fixture.data)
        record(GroupsListView(model: loading), "groups.list", "loading")

        let empty = GroupsListModel(data: fixture.data)
        await empty.load()
        record(GroupsListView(model: empty), "groups.list", "empty")

        let withGroups = AccountUITestScenario.withGroups.makeData()
        dependencies = makeDependencies(withGroups)
        let loaded = GroupsListModel(data: withGroups)
        await loaded.load()
        record(GroupsListView(model: loaded), "groups.list", "loaded")
        loaded.stop()

        withGroups.failures["myGroups"] = .http(status: 500)
        let failing = GroupsListModel(data: withGroups)
        await failing.load()
        record(GroupsListView(model: failing), "groups.list", "error")

        withGroups.failures["myGroups"] = .offline
        let offline = GroupsListModel(data: withGroups)
        await offline.load()
        record(GroupsListView(model: offline), "groups.list", "offline")
    }

    // MARK: groups.create

    func testGroupsCreate() async {
        record(GroupCreateView(model: GroupCreateModel(data: fixture.data)), "groups.create", "default")
        let filled = GroupCreateModel(data: fixture.data)
        filled.setName("Lima family")
        filled.kind = .family
        record(GroupCreateView(model: filled), "groups.create", "filled")

        fixture.data.failures["createGroup"] = .http(status: 500)
        _ = await filled.submit()
        record(GroupCreateView(model: filled), "groups.create", "error")
        fixture.data.failures = [:]

        let group = fixture.familyGroup()
        let edit = GroupCreateModel(data: fixture.data, editingGroupID: group.id)
        await edit.loadForEdit()
        record(GroupCreateView(model: edit), "groups.create", "edit")
    }

    // MARK: groups.invite

    func testGroupsInvite() async {
        let group = fixture.familyGroup()
        let ready = GroupInviteModel(groupID: group.id, data: fixture.data, domain: "example.test")
        await ready.load()
        record(GroupInviteView(model: ready), "groups.invite", "ready")

        ready.add(LocalContact(id: "c1", displayName: "Rui Costa", phoneNumbers: [PhoneNumber("+351912345678")].compactMap { $0 }))
        ready.add(LocalContact(id: "c2", displayName: "Marta Lima", phoneNumbers: [PhoneNumber("+351912345679")].compactMap { $0 }))
        ready.markInvited("c2")
        record(GroupInviteView(model: ready), "onboarding.permission.contacts", "contacts-shared")

        let noDomain = GroupInviteModel(groupID: group.id, data: fixture.data, domain: nil)
        await noDomain.load()
        _ = await noDomain.linkToShare()
        record(GroupInviteView(model: noDomain), "groups.invite", "error")

        fixture.data.config = PublicAppConfig(maxGroupMembers: 2, minAgeYears: 13)
        let full = GroupInviteModel(groupID: group.id, data: fixture.data, domain: "example.test")
        await full.load()
        record(GroupInviteView(model: full), "groups.invite", "full")
    }

    // MARK: groups.screen

    func testGroupsScreen() async {
        let group = fixture.familyGroup(posts: 4)
        let loading = GroupFeedModel(groupID: group.id, data: fixture.data)
        record(NavigationStack { GroupFeedView(model: loading) }, "groups.screen", "loading")

        let loaded = GroupFeedModel(groupID: group.id, data: fixture.data)
        await loaded.refresh()
        record(NavigationStack { GroupFeedView(model: loaded) }, "groups.screen", "loaded")
        record(NavigationStack { GroupProfileView(model: loaded) }, "groups.screen", "profile")

        let fresh = fixture.familyGroup()
        let created = GroupFeedModel(groupID: fresh.id, data: fixture.data)
        await created.refresh()
        record(NavigationStack { GroupFeedView(model: created) }, "groups.screen", "created")

        let theirs = fixture.data.addGroup("Sunday dinners", createdBy: fixture.rui.id, members: [fixture.rui, fixture.me])
        let empty = GroupFeedModel(groupID: theirs.id, data: fixture.data)
        await empty.refresh()
        record(NavigationStack { GroupFeedView(model: empty) }, "groups.screen", "empty")

        fixture.data.failures["group"] = .http(status: 500)
        let failing = GroupFeedModel(groupID: theirs.id, data: fixture.data)
        await failing.refresh()
        record(NavigationStack { GroupFeedView(model: failing) }, "groups.screen", "error")

        fixture.data.failures["group"] = .offline
        let offline = GroupFeedModel(groupID: theirs.id, data: fixture.data)
        await offline.refresh()
        record(NavigationStack { GroupFeedView(model: offline) }, "groups.screen", "offline")

        fixture.data.failures["group"] = .api(.notGroupMember)
        let removed = GroupFeedModel(groupID: theirs.id, data: fixture.data)
        await removed.refresh()
        record(NavigationStack { GroupFeedView(model: removed) }, "groups.screen", "removed")
    }

    // MARK: groups.settings

    func testGroupsSettings() async {
        let mine = fixture.familyGroup()
        let admin = GroupSettingsModel(groupID: mine.id, data: fixture.data, notifications: StaticNotificationAuthorizer(status: .granted))
        await admin.load()
        record(NavigationStack { GroupSettingsView(model: admin) }, "groups.settings", "admin")

        let theirs = fixture.data.addGroup("Sunday dinners", createdBy: fixture.rui.id, members: [fixture.rui, fixture.me])
        let member = GroupSettingsModel(groupID: theirs.id, data: fixture.data, notifications: StaticNotificationAuthorizer(status: .denied))
        await member.load()
        record(NavigationStack { GroupSettingsView(model: member) }, "groups.settings", "member-notifications-off")

        fixture.data.failures["setMuted"] = .offline
        await admin.setMuted(true)
        record(NavigationStack { GroupSettingsView(model: admin) }, "groups.settings", "error")
    }

    // MARK: settings

    func testSettingsRoot() {
        record(NavigationStack { SettingsRootScreen() }, "settings.root", "default")
        let premium = InMemoryPurchases()
        premium.isPremium = true
        dependencies = makeDependencies(fixture.data, purchases: premium)
        record(NavigationStack { SettingsRootScreen() }, "settings.root", "premium")
    }

    func testSettingsNotifications() async {
        fixture.familyGroup()
        let loaded = SettingsNotificationsModel(data: fixture.data, notifications: StaticNotificationAuthorizer(status: .granted))
        await loaded.load()
        record(NavigationStack { SettingsNotificationsView(model: loaded) }, "settings.notifications", "default")

        await loaded.setQuietHoursOn(true)
        await loaded.setQuietHours(start: LocalTime(hour: 22, minute: 0)!, end: LocalTime(hour: 7, minute: 0)!)
        record(NavigationStack { SettingsNotificationsView(model: loaded) }, "settings.notifications", "quiet-hours")

        let off = SettingsNotificationsModel(data: fixture.data, notifications: StaticNotificationAuthorizer(status: .denied))
        await off.load()
        record(NavigationStack { SettingsNotificationsView(model: off) }, "settings.notifications", "system-off")
    }

    func testSettingsAccount() async {
        let model = SettingsAccountModel(data: fixture.data)
        await model.load(premium: false)
        record(NavigationStack { SettingsAccountView(model: model) }, "settings.account", "default")

        fixture.data.premium = true
        let premium = SettingsAccountModel(data: fixture.data)
        await premium.load(premium: true)
        record(NavigationStack { SettingsAccountView(model: premium) }, "settings.account", "premium")
    }

    func testSettingsBlocked() async {
        record(NavigationStack { SettingsBlockedView(model: SettingsBlockedModel(data: fixture.data)) }, "settings.blocked", "loading")

        let empty = SettingsBlockedModel(data: fixture.data)
        await empty.load()
        record(NavigationStack { SettingsBlockedView(model: empty) }, "settings.blocked", "empty")

        try? await fixture.data.block(userID: fixture.rui.id)
        let loaded = SettingsBlockedModel(data: fixture.data)
        await loaded.load()
        record(NavigationStack { SettingsBlockedView(model: loaded) }, "settings.blocked", "loaded")

        fixture.data.failures["blocked"] = .http(status: 500)
        let failing = SettingsBlockedModel(data: fixture.data)
        await failing.load()
        record(NavigationStack { SettingsBlockedView(model: failing) }, "settings.blocked", "error")
    }

    // MARK: safety

    func testSafetyReport() async {
        let person = ReportTarget(kind: .user, id: fixture.rui.id.rawValue, name: "Rui", person: BlockTarget(userID: fixture.rui.id.rawValue, firstName: "Rui"))
        record(ReportView(model: ReportModel(target: person, data: fixture.data)), "safety.report", "form")

        let sent = ReportModel(target: person, data: fixture.data)
        await sent.submit()
        record(ReportView(model: sent), "safety.report", "sent")

        fixture.data.failures["report"] = .offline
        let failed = ReportModel(target: ReportTarget(kind: .post, id: "p1"), data: fixture.data)
        await failed.submit()
        record(ReportView(model: failed), "safety.report", "error")

        fixture.data.failures["report"] = .api(.targetNotFound)
        let missing = ReportModel(target: ReportTarget(kind: .group, id: "g1", name: "Lima family"), data: fixture.data)
        await missing.submit()
        record(ReportView(model: missing), "safety.report", "not-found")
    }

    func testSafetyBlockToast() {
        dependencies.toasts.show(Copy.safetyBlockDone(firstName: "Rui"))
        record(Tokens.Colors.globalBackground.ignoresSafeArea(), "safety.block", "toast")
    }

    // MARK: paywall

    private let plans = [
        PlanOption(id: "annual", period: .year, price: "$29.99", monthlyEquivalent: "$2.49", periodUnit: "Year"),
        PlanOption(id: "monthly", period: .month, price: "$3.99", monthlyEquivalent: nil, periodUnit: "Month"),
    ]

    func testPaywall() {
        let purchases = InMemoryPurchases()
        let loading = PaywallModel(purchases: purchases, data: fixture.data)
        record(PaywallView(model: loading), "paywall", "loading")

        let loaded = PaywallModel(purchases: purchases, data: fixture.data)
        loaded.seed(plans: plans, phase: .loaded, showsHistoryPerk: true)
        record(PaywallView(model: loaded), "paywall", "loaded")
        record(PlanSheet(model: loaded, onClose: {}), "paywall", "plans")

        let unavailable = PaywallModel(purchases: purchases, data: fixture.data)
        unavailable.seed(plans: [], phase: .unavailable)
        record(PlanSheet(model: unavailable, onClose: {}), "paywall", "plans-unavailable")

        let offline = PaywallModel(purchases: purchases, data: fixture.data)
        offline.seed(plans: [], phase: .offline)
        record(PlanSheet(model: offline, onClose: {}), "paywall", "plans-offline")
    }

    // MARK: invite.appclip

    func testInviteAppClip() throws {
        let json = Data(#"{"group_name":"Lima family","group_kind":"family","inviter_first_name":"Ana","members":[{"first_name":"Ana"},{"first_name":"Rui"},{"first_name":"Marta"}]}"#.utf8)
        guard case let .valid(preview) = InvitePreviewLoader.state(status: 200, data: json) else { return XCTFail("fixture not decoded") }
        let states: [(String, InvitePreviewState)] = [
            ("loading", .loading), ("valid", .valid(preview)), ("unavailable", .unavailable), ("not-found", .notFound),
            ("rate-limited", .rateLimited), ("error", .error), ("offline", .offline), ("full", .full),
        ]
        for (name, state) in states {
            record(InvitePreviewScreen(state: state, onJoin: {}, onRetry: {}), "invite.appclip", name)
        }
        record(
            InviteJoinSheet(theme: .standard, name: .constant("Rui"), phone: .constant("+351 912 345 678"), isSending: false, onCancel: {}, onContinue: {}),
            "invite.appclip", "join-sheet"
        )
    }
}

/// A permission card where its surface places it: centred over the dark background (the camera viewfinder area /
/// the photo where the save was attempted).
private struct PermissionCardHost: View {
    let card: PermissionCard

    var body: some View {
        ZStack {
            Tokens.Colors.globalBackgroundDeep.ignoresSafeArea()
            card
        }
    }
}

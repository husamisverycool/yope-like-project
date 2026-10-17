// One snapshot per account screen per state, recorded into ios/build/snapshots/account/<surface>-<state>-<light|dark>.png
// for the side-by-side verification (design/verification/<surface>.png, made by the lead from the CI artifact). Every
// state is recorded in the light appearance and each surface's primary state in dark as well (the app follows the
// system appearance; media surfaces and the invite card stay dark by their tokens). Screens run on in-memory data
// (InMemoryAccountData); avatars, covers and posts are real sample photos (`AccountSamplePhotos`, fixtures/photos/).
// Native alerts, action sheets (safety.report, safety.block) and system prompts (system.permissions) are drawn by the
// system and are not recorded.
@testable import App
import AppData
import AppModels
import DesignSystem
import SnapshotTesting
import SwiftUI
import XCTest

/// Records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (SnapshotRecorder writes
/// `<test>.<name>.png`; the file is renamed to the surface/state name the verification step uses).
enum AccountSnapshot {
    static let folder = SnapshotRecorder.directory.appendingPathComponent("account", isDirectory: true)

    /// Both appearances (the primary state of a surface).
    static let both: [ColorScheme] = [.light, .dark]

    @MainActor
    @discardableResult
    static func record<V: View>(
        _ view: V,
        surface: String,
        state: String,
        dependencies: AccountDependencies,
        appearances: [ColorScheme] = [.light],
        layout: SwiftUISnapshotLayout = .device(config: .iPhone13),
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) -> URL? {
        var last: URL?
        for scheme in appearances {
            let name = "\(surface)-\(state)-\(scheme == .dark ? "dark" : "light")"
            let hosted = view
                .environment(dependencies)
                .environment(\.storageURLResolver, dependencies.storageURLResolver)
                .toastHost(dependencies.toasts)
                .environment(\.colorScheme, scheme)
                .preferredColorScheme(scheme)
            guard let written = SnapshotRecorder.record(hosted, named: name, group: "account", layout: layout, file: file, testName: testName, line: line) else {
                return nil
            }
            let target = folder.appendingPathComponent("\(name).png")
            try? FileManager.default.removeItem(at: target)
            do {
                try FileManager.default.moveItem(at: written, to: target)
                last = target
            } catch {
                last = written
            }
        }
        return last
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

    private func makeDependencies(
        _ data: InMemoryAccountData,
        status: PermissionStatus = .notDetermined,
        purchases: InMemoryPurchases = InMemoryPurchases()
    ) -> AccountDependencies {
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
            onboarding: OnboardingRecord(defaults: defaults),
            currentPhone: { "+351 912 345 678" }
        )
    }

    private func record<V: View>(
        _ view: V,
        _ surface: String,
        _ state: String,
        appearances: [ColorScheme] = [.light],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let url = AccountSnapshot.record(
            view, surface: surface, state: state, dependencies: dependencies, appearances: appearances, file: file, line: line
        )
        XCTAssertNotNil(url, "\(surface)-\(state) not written", file: file, line: line)
    }

    /// Starts `work` with the data answering slowly and returns once `inFlight` holds (the in-progress state).
    private func whileInFlight(_ inFlight: @escaping () -> Bool, _ work: @escaping () async -> Void) async -> Task<Void, Never> {
        fixture.data.latency = .seconds(30)
        let task = Task { @MainActor in await work() }
        await waitUntil(inFlight)
        return task
    }

    /// Ends an in-flight state started by `whileInFlight`.
    private func finish(_ task: Task<Void, Never>) {
        task.cancel()
        fixture.data.latency = nil
    }

    /// Avatars, covers and post photos for `data` (default: the fixture's), before the models read it.
    private func photos(_ data: InMemoryAccountData? = nil) async {
        await AccountSamplePhotos.prepare(data ?? fixture.data)
    }

    private func image(_ name: String) -> PhotoSource {
        .image(SamplePhotos.image(named: name))
    }

    // MARK: auth.phone

    func testAuthPhone() async {
        record(PhoneScreen(model: PhoneModel(data: fixture.data, phone: "+1", deviceRegion: "US")), "auth.phone", "landing", appearances: AccountSnapshot.both)
        record(PhoneScreen(model: PhoneModel(data: fixture.data, phone: "+1", deviceRegion: "US"), showsForm: true), "auth.phone", "form")
        record(
            PhoneScreen(model: PhoneModel(data: fixture.data, phone: "+1 555 123 4567", deviceRegion: "US"), showsForm: true),
            "auth.phone", "form-filled", appearances: AccountSnapshot.both
        )

        let sending = PhoneModel(data: fixture.data, phone: "+1 555 123 4567", deviceRegion: "US")
        let task = await whileInFlight({ sending.isSending }) { _ = await sending.send() }
        record(PhoneScreen(model: sending, showsForm: true), "auth.phone", "sending")
        finish(task)

        fixture.data.failures["sendCode"] = .offline
        let offline = PhoneModel(data: fixture.data, phone: "+1 555 123 4567", deviceRegion: "US")
        _ = await offline.send()
        record(PhoneScreen(model: offline, showsForm: true), "auth.phone", "offline")

        record(CountryCodeList(selected: "US", onSelect: { _ in }).environment(\.locale, Locale(identifier: "en_US")), "auth.phone", "country-list")
    }

    // MARK: auth.code

    private func codeScreen(_ model: CodeModel) -> some View {
        let network = self.dependencies.network
        let toasts = self.dependencies.toasts
        return NavigationStack {
            CodeScreen(model: model, network: network, toasts: toasts, onVerified: { _ in }, onBack: {})
        }
    }

    func testAuthCode() async {
        record(codeScreen(CodeModel(phone: "+15551234567", data: fixture.data, sleep: { _ in })), "auth.code", "default", appearances: AccountSnapshot.both)
        let filled = CodeModel(phone: "+15551234567", data: fixture.data, sleep: { _ in })
        filled.setCode("123456")
        record(codeScreen(filled), "auth.code", "filled")

        let verifying = CodeModel(phone: "+15551234567", data: fixture.data, sleep: { _ in })
        verifying.setCode("123456")
        let task = await whileInFlight({ verifying.isVerifying }) { await verifying.verify { _ in } }
        record(codeScreen(verifying), "auth.code", "verifying")
        finish(task)

        fixture.data.failures["verifyCode"] = .offline
        let offline = CodeModel(phone: "+15551234567", data: fixture.data, sleep: { _ in })
        offline.setCode("123456")
        await offline.verify { _ in }
        record(codeScreen(offline), "auth.code", "offline")
    }

    // MARK: auth.agegate

    func testAuthAgeGate() async {
        let entry = BirthdayEntry(pattern: "MM/dd/y")
        record(AgeGateScreen(model: AgeGateModel(data: fixture.data, entry: entry)), "auth.agegate", "default", appearances: AccountSnapshot.both)

        let filled = AgeGateModel(data: fixture.data, entry: entry)
        filled.setText("05262000")
        filled.optIn = true
        record(AgeGateScreen(model: filled), "auth.agegate", "filled-opt-in")

        let checking = AgeGateModel(data: fixture.data, entry: entry)
        checking.setText("05262000")
        let task = await whileInFlight({ checking.isChecking }) { _ = await checking.confirm() }
        record(AgeGateScreen(model: checking), "auth.agegate", "checking")
        finish(task)

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
        record(ProfileScreen(model: ProfileModel(data: fixture.data)), "auth.profile", "name", appearances: AccountSnapshot.both)
        let filled = ProfileModel(data: fixture.data)
        filled.setName("Ana Lima")
        record(ProfileScreen(model: filled), "auth.profile", "name-filled")

        let tooLong = ProfileModel(data: fixture.data)
        tooLong.setName(String(repeating: "Ana Lima ", count: 10))
        record(ProfileScreen(model: tooLong), "auth.profile", "name-too-long")

        let saving = ProfileModel(data: fixture.data)
        saving.setName("Ana Lima")
        let task = await whileInFlight({ saving.isSaving }) { _ = await saving.saveName() }
        record(ProfileScreen(model: saving), "auth.profile", "saving-name")
        finish(task)

        fixture.data.failures["updateProfile"] = .offline
        let offline = ProfileModel(data: fixture.data)
        offline.setName("Ana Lima")
        _ = await offline.saveName()
        record(ProfileScreen(model: offline), "auth.profile", "offline")
        fixture.data.failures = [:]

        record(ProfileScreen(model: ProfileModel(data: fixture.data, step: .photo)), "auth.profile", "photo-empty", appearances: AccountSnapshot.both)
        let chosen = ProfileModel(data: fixture.data, step: .photo)
        chosen.setAvatar(imageData: SamplePhotos.data(named: "avatar-01"))
        record(ProfileScreen(model: chosen), "auth.profile", "photo-chosen")

        let uploading = ProfileModel(data: fixture.data, step: .photo)
        uploading.setAvatar(imageData: SamplePhotos.data(named: "avatar-01"))
        let upload = await whileInFlight({ uploading.isSaving }) { _ = await uploading.savePhoto() }
        record(ProfileScreen(model: uploading), "auth.profile", "uploading")
        finish(upload)
    }

    // MARK: onboarding

    func testOnboarding() {
        record(
            NotificationsPermissionScreen(notifications: StaticNotificationAuthorizer(status: .notDetermined), onAnswered: {}),
            "onboarding.permission.notifications", "default", appearances: AccountSnapshot.both
        )
        record(PermissionCardHost(card: .cameraDenied(onEnable: {})), "onboarding.permission.camera", "denied", appearances: AccountSnapshot.both)
        record(
            PermissionCardHost(card: .photosDenied(onEnable: {}, onDismiss: {})),
            "onboarding.permission.photos", "denied", appearances: AccountSnapshot.both
        )

        let preview = WidgetPreviewContent(photo: image("grandma-hug-4x3"), firstName: "Rui")
        record(WidgetGuideScreen(preview: preview, onContinue: {}), "onboarding.widget", "default", appearances: AccountSnapshot.both)
        record(WidgetGuideScreen(preview: nil, onContinue: {}), "onboarding.widget", "no-photo")
        record(WidgetGuideScreen(preview: preview, onBack: {}, onContinue: {}), "onboarding.widget", "from-settings")
    }

    // MARK: groups.list

    func testGroupsList() async {
        let loading = GroupsListModel(data: fixture.data)
        record(GroupsListView(model: loading), "groups.list", "loading")

        let empty = GroupsListModel(data: fixture.data)
        await empty.load()
        record(GroupsListView(model: empty), "groups.list", "empty", appearances: AccountSnapshot.both)
        empty.stop()

        let withGroups = AccountUITestScenario.withGroups.makeData()
        await photos(withGroups)
        dependencies = makeDependencies(withGroups)
        let loaded = GroupsListModel(data: withGroups)
        await loaded.load()
        record(GroupsListView(model: loaded), "groups.list", "default", appearances: AccountSnapshot.both)
        loaded.stop()

        withGroups.failures["myGroups"] = .http(status: 500)
        let failing = GroupsListModel(data: withGroups)
        await failing.refresh()
        record(GroupsListView(model: failing), "groups.list", "error")

        withGroups.failures["myGroups"] = .offline
        let offline = GroupsListModel(data: withGroups)
        await offline.refresh()
        record(GroupsListView(model: offline), "groups.list", "offline")
    }

    // MARK: groups.create

    func testGroupsCreate() async {
        record(GroupCreateView(model: GroupCreateModel(data: fixture.data)), "groups.create", "type", appearances: AccountSnapshot.both)
        record(GroupCreateView(model: GroupCreateModel(data: fixture.data, kind: .family)), "groups.create", "details", appearances: AccountSnapshot.both)

        let filled = GroupCreateModel(data: fixture.data, kind: .family)
        filled.setName("Lima family")
        filled.setCover(imageData: SamplePhotos.data(named: "grandma-hug-4x3"))
        record(GroupCreateView(model: filled), "groups.create", "filled")

        let tooLong = GroupCreateModel(data: fixture.data, kind: .friends)
        tooLong.setName(String(repeating: "Sunday dinners ", count: 7))
        record(GroupCreateView(model: tooLong), "groups.create", "name-too-long")

        let creating = GroupCreateModel(data: fixture.data, kind: .family)
        creating.setName("Lima family")
        let task = await whileInFlight({ creating.isWorking }) { _ = await creating.submit() }
        record(GroupCreateView(model: creating), "groups.create", "creating")
        finish(task)

        let group = fixture.familyGroup()
        await photos()
        let edit = GroupCreateModel(data: fixture.data, editingGroupID: group.id)
        await edit.loadForEdit()
        record(GroupCreateView(model: edit), "groups.create", "edit")
    }

    // MARK: groups.invite

    func testGroupsInvite() async {
        let group = fixture.familyGroup()
        await photos()
        let loading = GroupInviteModel(groupID: group.id, data: fixture.data, domain: "example.test")
        record(GroupInviteView(model: loading), "groups.invite", "loading")

        let ready = GroupInviteModel(groupID: group.id, data: fixture.data, domain: "example.test")
        await ready.load()
        record(GroupInviteView(model: ready), "groups.invite", "link-off")
        let link = await ready.linkToShare()
        record(GroupInviteView(model: ready), "groups.invite", "link-on", appearances: AccountSnapshot.both)

        // The QR card (owner decision 17): the recap preview over the group's cover, the card, Save and Share.
        if let link {
            let qr = GroupInviteQRModel(link: link, groupName: group.name, cover: image("grandma-hug-4x3"), toasts: dependencies.toasts)
            record(GroupInviteQRScreen(model: qr), "groups.invite", "qr", appearances: AccountSnapshot.both)
            let noCover = GroupInviteQRModel(link: link, groupName: group.name, cover: nil, toasts: dependencies.toasts)
            record(GroupInviteQRScreen(model: noCover), "groups.invite", "qr-noCover")
        } else {
            XCTFail("the fixture's invite has a link")
        }

        ready.add(LocalContact(id: "c1", displayName: "Rui Costa", phoneNumbers: [PhoneNumber("+351912345678")].compactMap { $0 }))
        ready.add(LocalContact(id: "c2", displayName: "Marta Lima", phoneNumbers: [PhoneNumber("+351912345679")].compactMap { $0 }))
        ready.markInvited("c2")
        record(GroupInviteView(model: ready), "onboarding.permission.contacts", "chosen", appearances: AccountSnapshot.both)

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

    private func feed(_ groupID: GroupID) -> GroupFeedModel {
        let data = fixture.data
        return GroupFeedModel(groupID: groupID, data: data, now: { data.clock })
    }

    func testGroupsScreen() async {
        let group = fixture.familyGroup()
        // This week (the fixture clock is Wednesday of ISO week 42) and two earlier days.
        for (author, minutes) in [(fixture.rui.id, 40), (fixture.me.id, 200), (fixture.rui.id, 1_500), (fixture.me.id, 2_900)] {
            fixture.data.addPost(groupID: group.id, author: author, minutesAgo: minutes)
        }
        for minutes in [60 * 24 * 4, 60 * 24 * 4 + 30, 60 * 24 * 5, 60 * 24 * 9, 60 * 24 * 9 + 60] {
            fixture.data.addPost(groupID: group.id, author: fixture.rui.id, minutesAgo: minutes)
        }
        await photos()
        let loading = feed(group.id)
        record(NavigationStack { GroupFeedView(model: loading) }, "groups.screen", "loading")

        let loaded = feed(group.id)
        await loaded.refresh()
        record(NavigationStack { GroupFeedView(model: loaded) }, "groups.screen", "default", appearances: AccountSnapshot.both)
        loaded.stop()

        let fresh = fixture.familyGroup()
        await photos()
        let created = feed(fresh.id)
        await created.refresh()
        record(NavigationStack { GroupFeedView(model: created) }, "groups.screen", "created")

        let theirs = fixture.data.addGroup("Sunday dinners", createdBy: fixture.rui.id, members: [fixture.rui, fixture.me])
        await photos()
        let empty = feed(theirs.id)
        await empty.refresh()
        record(NavigationStack { GroupFeedView(model: empty) }, "groups.screen", "empty")

        fixture.data.addPost(groupID: theirs.id, author: fixture.rui.id, minutesAgo: 60 * 24 * 8)
        await photos()
        let quiet = feed(theirs.id)
        await quiet.refresh()
        record(NavigationStack { GroupFeedView(model: quiet) }, "groups.screen", "quiet-week")

        fixture.data.failures["group"] = .http(status: 500)
        let failing = feed(theirs.id)
        await failing.refresh()
        record(NavigationStack { GroupFeedView(model: failing) }, "groups.screen", "error")

        fixture.data.failures["group"] = .offline
        let offline = feed(theirs.id)
        await offline.refresh()
        record(NavigationStack { GroupFeedView(model: offline) }, "groups.screen", "offline")

        fixture.data.failures["group"] = .api(.notGroupMember)
        let removed = feed(theirs.id)
        await removed.refresh()
        record(NavigationStack { GroupFeedView(model: removed) }, "groups.screen", "removed")
    }

    // MARK: groups.settings

    func testGroupsSettings() async {
        let mine = fixture.familyGroup()
        await photos()
        let loading = GroupSettingsModel(groupID: mine.id, data: fixture.data, notifications: StaticNotificationAuthorizer(status: .granted))
        record(GroupSettingsView(model: loading), "groups.settings", "loading")

        let admin = GroupSettingsModel(groupID: mine.id, data: fixture.data, notifications: StaticNotificationAuthorizer(status: .granted))
        await admin.load()
        record(GroupSettingsView(model: admin), "groups.settings", "admin", appearances: AccountSnapshot.both)

        let theirs = fixture.data.addGroup("Sunday dinners", createdBy: fixture.rui.id, members: [fixture.rui, fixture.me])
        await photos()
        let member = GroupSettingsModel(groupID: theirs.id, data: fixture.data, notifications: StaticNotificationAuthorizer(status: .denied))
        await member.load()
        record(GroupSettingsView(model: member), "groups.settings", "member-notifications-off")

        fixture.data.failures["setMuted"] = .offline
        await admin.setMuted(true)
        record(GroupSettingsView(model: admin), "groups.settings", "change-failed")
    }

    // MARK: settings

    func testSettingsRoot() async throws {
        await photos()
        let me = try XCTUnwrap(fixture.data.profilesByID[fixture.me.id])
        record(SettingsRootScreen(profile: me, isPremium: false, statuses: [:]), "settings.root", "default", appearances: AccountSnapshot.both)
        record(SettingsRootScreen(profile: me, isPremium: nil), "settings.root", "subscription-loading")
        record(SettingsRootScreen(profile: me, isPremium: true, activePeriod: .year), "settings.root", "subscriber")
        record(
            SettingsRootScreen(profile: me, isPremium: false, statuses: [.camera: .denied, .photos: .denied, .contacts: .denied]),
            "settings.root", "permissions-denied"
        )
    }

    func testSettingsNotifications() async {
        let none = SettingsNotificationsModel(data: fixture.data, notifications: StaticNotificationAuthorizer(status: .granted))
        await none.load()
        record(NavigationStack { SettingsNotificationsView(model: none) }, "settings.notifications", "no-groups")

        fixture.familyGroup()
        fixture.data.addGroup("Sunday dinners", createdBy: fixture.rui.id, members: [fixture.rui, fixture.me])
        await photos()
        let loading = SettingsNotificationsModel(data: fixture.data, notifications: StaticNotificationAuthorizer(status: .granted))
        record(NavigationStack { SettingsNotificationsView(model: loading) }, "settings.notifications", "loading")

        let loaded = SettingsNotificationsModel(data: fixture.data, notifications: StaticNotificationAuthorizer(status: .granted))
        await loaded.load()
        record(NavigationStack { SettingsNotificationsView(model: loaded) }, "settings.notifications", "default", appearances: AccountSnapshot.both)

        await loaded.setQuietHoursOn(true)
        await loaded.setQuietHours(start: LocalTime(hour: 22, minute: 0)!, end: LocalTime(hour: 7, minute: 0)!)
        record(NavigationStack { SettingsNotificationsView(model: loaded) }, "settings.notifications", "quiet-hours")

        // Pause All on: the footer adds the end ("Until 12:00 AM", the next local midnight of the fixture's clock).
        let paused = SettingsNotificationsModel(
            data: fixture.data, notifications: StaticNotificationAuthorizer(status: .granted), now: { Date(timeIntervalSince1970: 1_792_000_000) }
        )
        await paused.load()
        await paused.setPaused(true)
        record(NavigationStack { SettingsNotificationsView(model: paused) }, "settings.notifications", "paused", appearances: AccountSnapshot.both)
        await paused.setPaused(false)

        let off = SettingsNotificationsModel(data: fixture.data, notifications: StaticNotificationAuthorizer(status: .denied))
        await off.load()
        record(NavigationStack { SettingsNotificationsView(model: off) }, "settings.notifications", "permission-off")
    }

    func testSettingsAccount() async {
        fixture.data.privateProfile?.birthday = LocalDate(year: 1994, month: 7, day: 5)
        await photos()
        let model = SettingsAccountModel(data: fixture.data)
        await model.load(premium: false)
        record(NavigationStack { SettingsAccountView(model: model) }, "settings.account", "default", appearances: AccountSnapshot.both)

        let name = SettingsAccountModel(data: fixture.data)
        await name.load(premium: false)
        record(NavigationStack { SettingsNameView(model: name) }, "settings.account", "edit-name")
        name.nameDraft = String(repeating: "Ana Lima ", count: 10)
        record(NavigationStack { SettingsNameView(model: name) }, "settings.account", "edit-name-too-long")

        let deleting = SettingsAccountModel(data: fixture.data)
        await deleting.load(premium: false)
        let task = await whileInFlight({ deleting.isDeleting }) { _ = await deleting.deleteAccount() }
        record(NavigationStack { SettingsAccountView(model: deleting) }, "settings.account", "deleting")
        finish(task)
    }

    func testSettingsBlocked() async {
        let loading = SettingsBlockedModel(data: fixture.data)
        record(NavigationStack { SettingsBlockedView(model: loading) }, "settings.blocked", "loading")

        let empty = SettingsBlockedModel(data: fixture.data)
        await empty.load()
        record(NavigationStack { SettingsBlockedView(model: empty) }, "settings.blocked", "empty")

        try? await fixture.data.block(userID: fixture.rui.id)
        await photos()
        let loaded = SettingsBlockedModel(data: fixture.data)
        await loaded.load()
        record(NavigationStack { SettingsBlockedView(model: loaded) }, "settings.blocked", "default", appearances: AccountSnapshot.both)

        fixture.data.failures["blocked"] = .http(status: 500)
        let failing = SettingsBlockedModel(data: fixture.data)
        await failing.load()
        record(NavigationStack { SettingsBlockedView(model: failing) }, "settings.blocked", "error")
    }

    // MARK: safety.report (sheet form; the app shows the same reasons as native action sheets)

    func testSafetyReport() {
        record(ReportSheet(target: ReportTarget(kind: .post, id: "p1")), "safety.report", "reasons-post", appearances: AccountSnapshot.both)
        let person = ReportTarget(
            kind: .user, id: fixture.rui.id.rawValue, name: "Rui",
            person: BlockTarget(userID: fixture.rui.id.rawValue, firstName: "Rui")
        )
        record(ReportSheet(target: person), "safety.report", "reasons-person")
    }

    // MARK: paywall

    private let plans = [
        // Owner decision 7: $35.99 a year with a 1-week free trial (StoreKit introductory offer), $3.99 a month.
        PlanOption(id: "annual", period: .year, price: "$35.99", periodUnit: "Year", trialDuration: "1 week"),
        PlanOption(id: "monthly", period: .month, price: "$3.99", periodUnit: "Month"),
    ]

    func testPaywall() async {
        let purchases = InMemoryPurchases()
        let photo = image("dinner-long-table-3x4")
        record(PaywallView(model: PaywallModel(purchases: purchases, data: fixture.data), photo: photo), "paywall", "loading")

        // SPEC_FLAGS T1 (owner decision 7): free_history_days stays NULL, so the history perk is not listed.
        let loaded = PaywallModel(purchases: purchases, data: fixture.data)
        loaded.seed(plans: plans, phase: .loaded)
        record(PaywallView(model: loaded, photo: photo), "paywall", "default", appearances: AccountSnapshot.both)

        // A person no longer eligible for the trial: "Continue" and "Billed … yearly", no pill.
        let noTrial = PaywallModel(purchases: purchases, data: fixture.data)
        noTrial.seed(plans: plans.map { plan in var plan = plan; plan.trialDuration = nil; return plan }, phase: .loaded)
        record(PaywallView(model: noTrial, photo: photo), "paywall", "default-noTrial")

        let unavailable = PaywallModel(purchases: purchases, data: fixture.data)
        unavailable.seed(plans: [], phase: .unavailable)
        record(PaywallView(model: unavailable, photo: photo), "paywall", "unavailable")

        let offline = PaywallModel(purchases: purchases, data: fixture.data)
        offline.seed(plans: [], phase: .offline)
        record(PaywallView(model: offline, photo: nil), "paywall", "offline")

        let welcome = PaywallModel(purchases: purchases, data: fixture.data)
        welcome.seed(plans: plans, phase: .loaded)
        welcome.select(plans[0])
        purchases.purchaseResult = .success(.purchased)
        await welcome.purchase()
        record(PaywallView(model: welcome, photo: photo), "paywall", "welcome")

        let restored = PaywallModel(purchases: purchases, data: fixture.data)
        restored.seed(plans: plans, phase: .loaded)
        purchases.restoreResult = .success(true)
        await restored.restore()
        record(PaywallView(model: restored, photo: photo), "paywall", "welcome-restored")
    }

    // MARK: invite.appclip

    func testInviteAppClip() throws {
        let json = Data(#"""
        {"group_name":"Lima family","group_kind":"family","inviter_first_name":"Rui","inviter_avatar_url":null,"cover":null,
         "members":[{"first_name":"Ana","avatar_url":null},{"first_name":"Rui","avatar_url":null},{"first_name":"Marta","avatar_url":null}]}
        """#.utf8)
        guard case let .valid(preview) = InvitePreviewLoader.state(status: 200, data: json) else { return XCTFail("fixture not decoded") }

        // The card with the sample photos in place of the web origin's signed URLs.
        var card = InviteCardContent.invite(preview)
        card.backdrop = image("grandma-hug-4x3")
        card.avatar = image("avatar-06")
        card.members = [image("avatar-01"), image("avatar-06"), image("avatar-03")]
        let letsGo = InviteCardPill(title: Copy.inviteWebCta, busyTitle: Copy.inviteWebOpening, identifier: "invite.join", action: {})
        record(InviteCard(content: card, pill: letsGo), "invite.appclip", "default", appearances: AccountSnapshot.both)

        var opening = letsGo
        opening.isBusy = true
        record(InviteCard(content: card, pill: opening), "invite.appclip", "opening")

        var noCover = InviteCardContent.invite(preview)
        noCover.avatar = image("avatar-06")
        noCover.backdrop = image("avatar-06")
        record(InviteCard(content: noCover, pill: letsGo), "invite.appclip", "no-cover")

        var joined = InviteCardContent.invite(preview, joined: true)
        joined.backdrop = card.backdrop
        joined.avatar = card.avatar
        joined.members = card.members
        record(InviteCard(content: joined), "invite.appclip", "joined", appearances: AccountSnapshot.both)

        let states: [(String, InvitePreviewState)] = [
            ("loading", .loading), ("unavailable", .unavailable), ("not-found", .notFound),
            ("rate-limited", .rateLimited), ("error", .error), ("offline", .offline), ("full", .full),
        ]
        for (name, state) in states {
            record(InvitePreviewScreen(state: state, onContinue: {}, onRetry: {}), "invite.appclip", name)
        }
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

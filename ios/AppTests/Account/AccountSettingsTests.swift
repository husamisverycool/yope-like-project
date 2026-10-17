// Account group — settings and safety view models: settings.notifications, settings.account, settings.blocked,
// safety.report (Retro's reason sheets), and the paywall (PaywallModel over the purchases seam).
@testable import App
import AppData
import AppModels
import DesignSystem
import XCTest

@MainActor
final class AccountSettingsTests: XCTestCase {
    // MARK: settings.notifications

    func testNotificationsLoadsGroupsAndQuietHours() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup()
        try? await fixture.data.setMuted(groupID: group.id, muted: true)
        try? await fixture.data.setQuietHours(start: LocalTime(hour: 22, minute: 0), end: LocalTime(hour: 7, minute: 0))
        let model = SettingsNotificationsModel(data: fixture.data, notifications: StaticNotificationAuthorizer(status: .granted))
        await model.load()
        XCTAssertFalse(model.isLoading)
        XCTAssertFalse(model.systemOff)
        XCTAssertEqual(model.groups.map(\.muted), [true])
        XCTAssertTrue(model.quietHoursOn)
        XCTAssertEqual(model.quietStart, LocalTime(hour: 22, minute: 0))
    }

    func testNotificationsSystemOffWhenDeniedOrNeverAsked() async {
        let model = SettingsNotificationsModel(data: AccountFixture().data, notifications: StaticNotificationAuthorizer(status: .notDetermined))
        await model.load()
        XCTAssertTrue(model.systemOff)
    }

    /// Never asked: iOS has no switch to open yet, so "Enable push" shows the system alert; a grant removes the block.
    func testEnablePushAsksWhenNeverAskedAndOpensSettingsWhenDenied() async {
        let neverAsked = StaticNotificationAuthorizer(status: .notDetermined, answer: .granted)
        let model = SettingsNotificationsModel(data: AccountFixture().data, notifications: neverAsked)
        await model.load()
        var opened = 0
        await model.enablePush { opened += 1 }
        XCTAssertEqual(opened, 0, "the system alert, not Settings")
        XCTAssertEqual(neverAsked.status, .granted)
        XCTAssertFalse(model.systemOff)

        let denied = SettingsNotificationsModel(data: AccountFixture().data, notifications: StaticNotificationAuthorizer(status: .denied))
        await denied.load()
        await denied.enablePush { opened += 1 }
        XCTAssertEqual(opened, 1, "denied: the app's notification settings")
        XCTAssertTrue(denied.systemOff)
    }

    func testGroupToggleIsOptimisticAndRollsBack() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup()
        let model = SettingsNotificationsModel(data: fixture.data, notifications: StaticNotificationAuthorizer(status: .granted))
        await model.load()
        await model.setNotifies(false, groupID: group.id)
        XCTAssertEqual(model.groups.first?.muted, true)

        fixture.data.failures["setMuted"] = .offline
        await model.setNotifies(true, groupID: group.id)
        XCTAssertEqual(model.groups.first?.muted, true, "reverted")
        XCTAssertEqual(model.groupsError, Copy.settingsNotificationsError)
    }

    func testQuietHoursAreSavedOnlyWhenTheTimesDiffer() async {
        let fixture = AccountFixture()
        let model = SettingsNotificationsModel(data: fixture.data, notifications: StaticNotificationAuthorizer(status: .granted))
        await model.load()
        await model.setQuietHoursOn(true)
        XCTAssertTrue(model.quietHoursOn)
        XCTAssertFalse(fixture.data.calls.contains("setQuietHours"), "nothing is sent until two times are chosen")

        let time = LocalTime(hour: 22, minute: 0)!
        await model.setQuietHours(start: time, end: time)
        XCTAssertFalse(fixture.data.calls.contains("setQuietHours"), "equal times are not sent")

        await model.setQuietHours(start: time, end: LocalTime(hour: 7, minute: 0)!)
        XCTAssertEqual(fixture.data.settings?.quietStart, time)

        fixture.data.failures["setQuietHours"] = .offline
        await model.setQuietHoursOn(false)
        XCTAssertTrue(model.quietHoursOn, "reverted")
        XCTAssertEqual(model.quietStart, time)
        XCTAssertEqual(model.quietError, Copy.settingsNotificationsError)
    }

    // MARK: settings.account

    func testAccountNameSaveAndRevert() async {
        let fixture = AccountFixture()
        let model = SettingsAccountModel(data: fixture.data)
        await model.load(premium: false)
        XCTAssertEqual(model.nameDraft, "Ana Lima")

        model.nameDraft = "  Ana Maria "
        await model.saveName()
        XCTAssertEqual(model.profile?.displayName, "Ana Maria")

        model.nameDraft = "   "
        await model.saveName()
        XCTAssertEqual(model.nameDraft, "Ana Maria", "an empty name is not saved")

        fixture.data.failures["updateProfile"] = .offline
        model.nameDraft = "Ana L"
        await model.saveName()
        XCTAssertEqual(model.nameDraft, "Ana Maria", "reverted")
        XCTAssertEqual(model.profileError, Copy.settingsAccountNameError)
    }

    func testAccountNameTooLongBirthdayAndPhotoRemoval() async throws {
        let fixture = AccountFixture()
        let birthday = try XCTUnwrap(LocalDate(year: 1990, month: 7, day: 5))
        fixture.data.privateProfile?.birthday = birthday
        fixture.data.profilesByID[fixture.me.id]?.avatarPath = "avatars/ana.jpg"
        let model = SettingsAccountModel(data: fixture.data)
        await model.load(premium: false)
        XCTAssertEqual(model.birthday, birthday)
        XCTAssertNotNil(SettingsAccountView.birthdayText(birthday))

        model.nameDraft = String(repeating: "a", count: ProfileModel.maxNameLength + 1)
        XCTAssertTrue(model.isNameTooLong)
        XCTAssertFalse(model.canSaveName)

        XCTAssertTrue(model.hasPhoto)
        await model.removeAvatar()
        XCTAssertNil(model.profile?.avatarPath)
        XCTAssertFalse(model.hasPhoto)
        XCTAssertEqual(model.successCount, 1)
    }

    func testAccountPremiumComesFromTheStoreOrTheServer() async {
        let fixture = AccountFixture()
        fixture.data.premium = true
        let model = SettingsAccountModel(data: fixture.data)
        await model.load(premium: false)
        XCTAssertTrue(model.isPremium)
    }

    func testDeleteAccount() async {
        let fixture = AccountFixture()
        let model = SettingsAccountModel(data: fixture.data)
        fixture.data.failures["deleteAccount"] = .offline
        var deleted = await model.deleteAccount()
        XCTAssertFalse(deleted)
        XCTAssertEqual(model.errorCount, 1)
        fixture.data.failures = [:]
        deleted = await model.deleteAccount()
        XCTAssertTrue(deleted)
        XCTAssertFalse(model.isDeleting)
    }

    // MARK: settings.blocked

    func testBlockedListAndOptimisticUnblock() async {
        let fixture = AccountFixture()
        try? await fixture.data.block(userID: fixture.rui.id)
        let model = SettingsBlockedModel(data: fixture.data)
        await model.load()
        XCTAssertEqual(model.phase, .loaded)
        XCTAssertEqual(model.rows.map(\.name), ["Rui Costa"])

        fixture.data.failures["unblock"] = .offline
        let row = model.rows[0]
        var unblocked = await model.unblock(row)
        XCTAssertFalse(unblocked)
        XCTAssertEqual(model.rows, [row], "restored")

        fixture.data.failures = [:]
        unblocked = await model.unblock(row)
        XCTAssertTrue(unblocked)
        XCTAssertTrue(model.rows.isEmpty)
    }

    func testBlockedErrorAndUnknownName() async {
        let fixture = AccountFixture()
        fixture.data.failures["blocked"] = .http(status: 500)
        let model = SettingsBlockedModel(data: fixture.data)
        await model.load()
        XCTAssertEqual(model.phase, .error)

        let row = SettingsBlockedModel.Row(block: Block(blockerID: fixture.me.id, blockedID: fixture.rui.id, createdAt: Date()), profile: nil)
        XCTAssertEqual(row.name, Copy.settingsBlockedUnknown)
    }

    // MARK: safety.report

    func testReportReasonsFollowTheTarget() {
        XCTAssertEqual(ReportReason.reasons(for: .post), [.dontLike, .nudity, .other])
        XCTAssertEqual(ReportReason.reasons(for: .message), [.dontLike, .nudity, .other])
        XCTAssertEqual(ReportReason.reasons(for: .user), [.impersonation, .inappropriate, .other])
        XCTAssertEqual(ReportReason.reasons(for: .group), [.impersonation, .inappropriate, .other])
        XCTAssertEqual(ReportModel(target: ReportTarget(kind: .post, id: "p1"), data: InMemoryAccountData()).title, Copy.safetyReportTitlePost)
        XCTAssertEqual(ReportModel(target: ReportTarget(kind: .user, id: "u1"), data: InMemoryAccountData()).title, Copy.safetyReportTitleUser)
        XCTAssertFalse(ReportReason.dontLike.filesReport, "'I don't like it' opens Next Steps instead")
    }

    func testReportFilesTheReasonsEnglishTextAtOnce() async {
        let fixture = AccountFixture()
        let model = ReportModel(target: ReportTarget(kind: .post, id: "p1"), data: fixture.data)
        let filed = await model.submit(.nudity)
        XCTAssertTrue(filed)
        XCTAssertEqual(model.filedReason, .nudity)
        XCTAssertEqual(fixture.data.reports.last?.reason, "Nudity or sexual activity")
        XCTAssertEqual(fixture.data.reports.last?.kind, .post)

        let user = ReportModel(target: ReportTarget(kind: .user, id: fixture.rui.id.rawValue), data: fixture.data)
        await user.submit(.impersonation)
        XCTAssertEqual(fixture.data.reports.last?.reason, "It's impersonating someone")

        let nothing = await model.submit(.dontLike)
        XCTAssertFalse(nothing)
        XCTAssertEqual(fixture.data.reports.count, 2)
    }

    func testReportFailureAndNotFound() async {
        let fixture = AccountFixture()
        fixture.data.failures["report"] = .offline
        let model = ReportModel(target: ReportTarget(kind: .group, id: "g1", name: "Lima family"), data: fixture.data)
        var filed = await model.submit(.inappropriate)
        XCTAssertFalse(filed)
        XCTAssertEqual(model.failure, .failed)
        XCTAssertEqual(model.errorCount, 1)

        fixture.data.failures["report"] = .api(.targetNotFound)
        filed = await model.submit(.inappropriate)
        XCTAssertFalse(filed)
        XCTAssertEqual(model.failure, .notFound)
    }

    // MARK: paywall

    // Owner decision 7: $35.99 a year (1-week trial where StoreKit offers it), $3.99 a month.
    private let yearly = PlanOption(id: "annual", period: .year, price: "$35.99", periodUnit: "Year")
    private let monthly = PlanOption(id: "monthly", period: .month, price: "$3.99", periodUnit: "Month")

    func testPaywallPreselectsTheYearlyPlan() async {
        let purchases = InMemoryPurchases()
        purchases.plansResult = .success([monthly, yearly])
        let model = PaywallModel(purchases: purchases, data: AccountFixture().data)
        await model.load()
        XCTAssertEqual(model.plansPhase, .loaded)
        XCTAssertEqual(model.selectedPlanID, "annual")
        XCTAssertEqual(model.billingLine, Copy.paywallLegalBillingIos(price: "$35.99", period: "year"))
        model.select(monthly)
        XCTAssertEqual(model.selectedPlan, monthly)
    }

    func testPaywallUnavailableAndOfflinePlans() async {
        let purchases = InMemoryPurchases()
        purchases.plansResult = .failure(.unavailable)
        let model = PaywallModel(purchases: purchases, data: InMemoryAccountData())
        await model.loadPlans()
        XCTAssertEqual(model.plansPhase, .unavailable)
        purchases.plansResult = .failure(.offline)
        await model.loadPlans()
        XCTAssertEqual(model.plansPhase, .offline)
    }

    func testPurchaseOutcomes() async {
        let purchases = InMemoryPurchases()
        purchases.plansResult = .success([yearly])
        let model = PaywallModel(purchases: purchases, data: InMemoryAccountData())
        await model.loadPlans()

        purchases.purchaseResult = .success(.cancelled)
        await model.purchase()
        XCTAssertFalse(model.showsWelcome)
        XCTAssertNil(model.purchaseMessage)

        purchases.purchaseResult = .success(.pending)
        await model.purchase()
        XCTAssertEqual(model.purchaseMessage, Copy.paywallPending)

        purchases.purchaseResult = .failure(.failed)
        await model.purchase()
        XCTAssertEqual(model.purchaseMessage, Copy.paywallErrorPurchase)

        XCTAssertEqual(model.alertMessage, Copy.paywallErrorPurchase)
        XCTAssertEqual(model.alertCount, 2, "pending and failed each raise the alert")

        purchases.purchaseResult = .success(.purchased)
        await model.purchase()
        XCTAssertTrue(model.showsWelcome)
        XCTAssertEqual(model.welcome, .purchased)
        model.welcomeDismissed()
        XCTAssertFalse(model.showsWelcome)
    }

    func testPaywallCardsReadThePlanOfTheirPeriod() async {
        let purchases = InMemoryPurchases()
        var trial = yearly
        trial.trialDuration = "1 week"
        purchases.plansResult = .success([monthly, trial])
        let model = PaywallModel(purchases: purchases, data: InMemoryAccountData())
        await model.loadPlans()
        XCTAssertEqual(model.plan(for: .year)?.trialDuration, "1 week")
        XCTAssertEqual(model.plan(for: .month), monthly)
    }

    func testTrialDurationIsTheIntroPeriodInFullUnits() {
        let us = Locale(identifier: "en_US")
        XCTAssertEqual(PlanOption.trialDuration(DateComponents(weekOfMonth: 1), locale: us), "1 week")
        XCTAssertEqual(PlanOption.trialDuration(DateComponents(day: 3), locale: us), "3 days")
        XCTAssertEqual(PlanOption.trialDuration(DateComponents(month: 1), locale: us), "1 month")
    }

    func testHistoryPerkStaysHiddenWhileFreeHistoryDaysIsNull() async {
        // SPEC_FLAGS T1 / owner decision 7: app_config.free_history_days stays NULL.
        let purchases = InMemoryPurchases()
        purchases.plansResult = .success([yearly, monthly])
        let model = PaywallModel(purchases: purchases, data: InMemoryAccountData())
        await model.load()
        XCTAssertFalse(model.showsHistoryPerk)
        XCTAssertEqual(PaywallPerk.listed(showsHistory: model.showsHistoryPerk), [.video, .widgets, .export])
    }

    func testRestoreMessages() async {
        let purchases = InMemoryPurchases()
        let model = PaywallModel(purchases: purchases, data: InMemoryAccountData())
        purchases.restoreResult = .success(true)
        await model.restore()
        XCTAssertEqual(model.restoreMessage, Copy.paywallRestoreDone)
        XCTAssertEqual(model.welcome, .restored)
        model.welcomeDismissed()
        purchases.restoreResult = .success(false)
        await model.restore()
        XCTAssertEqual(model.restoreMessage, Copy.paywallRestoreNone)
        purchases.restoreResult = .failure(.offline)
        await model.restore()
        XCTAssertEqual(model.restoreMessage, Copy.paywallOffline)
    }
}

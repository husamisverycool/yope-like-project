// Account group — settings and safety view models: settings.notifications, settings.account, settings.blocked,
// safety.report, and the paywall (PaywallModel over the purchases seam).
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

    func testReportSendsTheReasonOrTheKind() async {
        let fixture = AccountFixture()
        let target = ReportTarget(kind: .user, id: fixture.rui.id.rawValue, name: "Rui", person: BlockTarget(userID: fixture.rui.id.rawValue, firstName: "Rui"))
        let model = ReportModel(target: target, data: fixture.data)
        XCTAssertEqual(model.title, Copy.safetyReportTitleUser(firstName: "Rui"))
        XCTAssertEqual(model.sentMessage, Copy.safetyReportSentMessage(firstName: "Rui"))
        await model.submit()
        XCTAssertEqual(model.phase, .sent)
        XCTAssertEqual(fixture.data.reports.first?.reason, "user", "empty details: the target kind")

        let post = ReportModel(target: ReportTarget(kind: .post, id: "p1"), data: fixture.data)
        post.setDetails("  spam  ")
        await post.submit()
        XCTAssertEqual(fixture.data.reports.last?.reason, "spam")
        XCTAssertEqual(fixture.data.reports.last?.kind, .post)
    }

    func testReportFailureKeepsTheFormAndNotFoundIsItsOwnState() async {
        let fixture = AccountFixture()
        fixture.data.failures["report"] = .offline
        let model = ReportModel(target: ReportTarget(kind: .group, id: "g1", name: "Lima family"), data: fixture.data)
        await model.submit()
        XCTAssertEqual(model.phase, .form)
        XCTAssertTrue(model.failed)

        fixture.data.failures["report"] = .api(.targetNotFound)
        await model.submit()
        XCTAssertEqual(model.phase, .notFound)
    }

    func testReportDetailsAreCapped() {
        let model = ReportModel(target: ReportTarget(kind: .message, id: "m1"), data: InMemoryAccountData())
        model.setDetails(String(repeating: "x", count: 1500))
        XCTAssertEqual(model.details.count, ReportModel.maxDetails)
    }

    // MARK: paywall

    private let yearly = PlanOption(id: "annual", period: .year, price: "$29.99", monthlyEquivalent: "$2.49", periodUnit: "Year")
    private let monthly = PlanOption(id: "monthly", period: .month, price: "$3.99", monthlyEquivalent: nil, periodUnit: "Month")

    func testPaywallPreselectsTheYearlyPlan() async {
        let purchases = InMemoryPurchases()
        purchases.plansResult = .success([monthly, yearly])
        let model = PaywallModel(purchases: purchases, data: AccountFixture().data)
        await model.load()
        XCTAssertEqual(model.plansPhase, .loaded)
        XCTAssertEqual(model.selectedPlanID, "annual")
        XCTAssertEqual(model.billingLine, Copy.paywallLegalBillingIos(price: "$29.99", period: "year"))
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

        purchases.purchaseResult = .success(.purchased)
        await model.purchase()
        XCTAssertTrue(model.showsWelcome)
        model.welcomeDismissed()
        XCTAssertFalse(model.showsWelcome)
    }

    func testRestoreMessages() async {
        let purchases = InMemoryPurchases()
        let model = PaywallModel(purchases: purchases, data: InMemoryAccountData())
        purchases.restoreResult = .success(true)
        await model.restore()
        XCTAssertEqual(model.restoreMessage, Copy.paywallRestoreDone)
        purchases.restoreResult = .success(false)
        await model.restore()
        XCTAssertEqual(model.restoreMessage, Copy.paywallRestoreNone)
        purchases.restoreResult = .failure(.offline)
        await model.restore()
        XCTAssertEqual(model.restoreMessage, Copy.paywallOffline)
    }
}

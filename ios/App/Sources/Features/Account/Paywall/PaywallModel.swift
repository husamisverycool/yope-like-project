// Account group — PaywallModel: state and actions of the screen in PaywallScreen.swift.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

@MainActor
@Observable
final class PaywallModel {
    enum PlansPhase: Equatable {
        case loading
        case loaded
        case unavailable
        case offline
    }

    private(set) var plans: [PlanOption] = []
    private(set) var plansPhase: PlansPhase = .loading
    /// Yearly by default (Locket's default selection).
    var selectedPlanID: String?
    private(set) var isPurchasing = false
    /// Under Subscribe: `paywall.error.purchase` / `paywall.pending`.
    private(set) var purchaseMessage: String?
    /// In the legal block: `paywall.restore.done` / `.none`.
    private(set) var restoreMessage: String?
    private(set) var showsWelcome = false
    /// The history perk is listed only while the free history window is set (`free_history_days`, SPEC_FLAGS T1).
    private(set) var showsHistoryPerk = false
    private(set) var successCount = 0
    private(set) var errorCount = 0

    private let purchases: PurchasesProviding
    private let data: AccountDataSource

    init(purchases: PurchasesProviding, data: AccountDataSource) {
        self.purchases = purchases
        self.data = data
    }

    var selectedPlan: PlanOption? { plans.first { $0.id == selectedPlanID } }

    func load() async {
        if let config = try? await data.publicConfig() { showsHistoryPerk = config.freeHistoryDays != nil }
        await loadPlans()
    }

    func loadPlans() async {
        plansPhase = .loading
        do {
            plans = try await purchases.plans()
            selectedPlanID = (plans.first { $0.period == .year } ?? plans.first)?.id
            plansPhase = .loaded
        } catch {
            plansPhase = (error as? PurchasesFailure) == .offline ? .offline : .unavailable
        }
    }

    func select(_ plan: PlanOption) {
        selectedPlanID = plan.id
    }

    /// Subscribe: success → welcome sheet; cancelled → nothing; pending → message; failure → message.
    func purchase() async {
        guard let plan = selectedPlan, !isPurchasing else { return }
        purchaseMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await purchases.purchase(plan) {
            case .purchased:
                successCount += 1
                showsWelcome = true
            case .cancelled:
                break
            case .pending:
                purchaseMessage = Copy.paywallPending
            }
        } catch {
            errorCount += 1
            purchaseMessage = Copy.paywallErrorPurchase
        }
    }

    func restore() async {
        restoreMessage = nil
        do {
            if try await purchases.restore() {
                successCount += 1
                restoreMessage = Copy.paywallRestoreDone
            } else {
                restoreMessage = Copy.paywallRestoreNone
            }
        } catch {
            errorCount += 1
            restoreMessage = (error as? PurchasesFailure) == .offline ? Copy.paywallOffline : Copy.paywallRestoreNone
        }
    }

    func welcomeDismissed() {
        showsWelcome = false
    }

    /// The legal billing line of the selected plan: `paywall.legal.billing.ios` ({price}, {period}).
    var billingLine: String? {
        guard let plan = selectedPlan, let unit = plan.periodUnit else { return nil }
        return Copy.paywallLegalBillingIos(price: plan.price, period: unit.lowercased())
    }

    func seed(plans: [PlanOption], phase: PlansPhase, showsHistoryPerk: Bool = false) {
        self.plans = plans
        plansPhase = phase
        selectedPlanID = (plans.first { $0.period == .year } ?? plans.first)?.id
        self.showsHistoryPerk = showsHistoryPerk
    }
}

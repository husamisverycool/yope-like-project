// Account group — seams over the foundation services the account screens use: notification permission and
// subscriptions. Foundation-only so the view models that use them type-check anywhere; the live adapters over
// AppServices (PushService, PurchasesService / RevenueCat) are in PlatformSeams.swift, DEBUG fakes in Testing/.
import AppModels
import Foundation

// MARK: - Notifications

/// Notification permission (onboarding.permission.notifications, settings.notifications).
@MainActor
protocol NotificationAuthorizing: AnyObject, Sendable {
    func authorizationStatus() async -> PermissionStatus
    /// Shows the system alert when undetermined (then registers with APNs if allowed) and returns the outcome.
    func requestAuthorization() async -> PermissionStatus
}

// MARK: - Purchases

/// One subscription plan of the paywall's plan sheet, with the store's localized strings
/// (`paywall.layout.requiredDisclosures`: never a hard-coded price).
struct PlanOption: Identifiable, Hashable {
    enum Period: Hashable {
        case month
        case year
    }

    /// The store package identifier.
    let id: String
    let period: Period
    /// The billed amount for the period, localized by the store (`{yearly_price}` / `{monthly_price}` / `{price}`). The
    /// paywall shows no per-month breakdown (design/surfaces/paywall.md lists none; MERGE A-2).
    let price: String
    /// The localized subscription period unit for the billing line (`{period}`: "year" / "month").
    let periodUnit: String?
    /// The free trial's length in the store's terms (`{trial_duration}`: "1 week"); nil without a trial or when the person
    /// is not eligible for it (StoreKit introductory offer, owner decision 7).
    var trialDuration: String?

    /// `{trial_duration}`: a period in the locale's full unit names ("1 week", "3 days"; `DateComponentsFormatter`
    /// `.full`, PLATFORM — Android formats Play's ISO period with ICU `MeasureFormat` WIDE).
    static func trialDuration(_ components: DateComponents, locale: Locale = .current) -> String? {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .weekOfMonth, .month, .year]
        var calendar = Calendar.current
        calendar.locale = locale
        formatter.calendar = calendar
        return formatter.string(from: components)
    }
}

enum PurchaseResult: Equatable {
    case purchased
    case cancelled
    /// Ask to Buy / parental approval pending.
    case pending
}

enum PurchasesFailure: Error, Equatable {
    /// No connection.
    case offline
    /// Products could not be loaded (no RevenueCat key yet, store error).
    case unavailable
    /// The purchase did not go through.
    case failed
}

/// Subscriptions for the paywall (entitlement `premium`, products `premium_monthly` / `premium_yearly`).
@MainActor
protocol PurchasesProviding: AnyObject, Sendable {
    /// The entitlement as RevenueCat last reported it.
    var isPremium: Bool { get }
    /// The current offering's yearly and monthly plans (yearly first).
    func plans() async throws -> [PlanOption]
    func purchase(_ plan: PlanOption) async throws -> PurchaseResult
    /// Restores; returns true when premium is active afterwards.
    func restore() async throws -> Bool
    /// The period of the active subscription (settings.root "Your Subscription" subtitle); nil when unknown.
    func activePeriod() async -> PlanOption.Period?
}

extension PurchasesProviding {
    func activePeriod() async -> PlanOption.Period? { nil }
}

// MARK: - Fixed implementations (no services: previews, the unconfigured shell)

/// Always reports `status`; never shows a system alert.
@MainActor
final class StaticNotificationAuthorizer: NotificationAuthorizing {
    var status: PermissionStatus
    /// What `requestAuthorization()` answers (and then reports).
    var answer: PermissionStatus

    init(status: PermissionStatus, answer: PermissionStatus = .granted) {
        self.status = status
        self.answer = answer
    }

    func authorizationStatus() async -> PermissionStatus { status }

    func requestAuthorization() async -> PermissionStatus {
        if status == .notDetermined { status = answer }
        return status
    }
}

/// No store connection: plans are unavailable, nothing is premium.
@MainActor
final class UnavailablePurchases: PurchasesProviding {
    var isPremium: Bool { false }
    func plans() async throws -> [PlanOption] { throw PurchasesFailure.unavailable }
    func purchase(_ plan: PlanOption) async throws -> PurchaseResult { throw PurchasesFailure.unavailable }
    func restore() async throws -> Bool { throw PurchasesFailure.unavailable }
}

// Account group — seams over the foundation services the account screens use (AppServices): notification
// permission (`PushService`) and subscriptions (`PurchasesService`, RevenueCat). Live adapters below; DEBUG fakes in
// Testing/.
import AppModels
import AppServices
import Foundation
import RevenueCat
import StoreKit

// MARK: - Notifications

/// Notification permission (onboarding.permission.notifications, settings.notifications).
@MainActor
protocol NotificationAuthorizing: AnyObject, Sendable {
    func authorizationStatus() async -> PermissionStatus
    /// Shows the system alert when undetermined (then registers with APNs if allowed) and returns the outcome.
    func requestAuthorization() async -> PermissionStatus
}

@MainActor
final class LiveNotificationAuthorizer: NotificationAuthorizing {
    private let push: PushService

    init(push: PushService) {
        self.push = push
    }

    func authorizationStatus() async -> PermissionStatus {
        await push.authorizationStatus()
    }

    func requestAuthorization() async -> PermissionStatus {
        (try? await push.requestAuthorization()) ?? (await push.authorizationStatus())
    }
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
    /// The billed amount for the period, localized by the store (`{yearly_price}` / `{monthly_price}` / `{price}`).
    let price: String
    /// Yearly plans: the price ÷ 12 in the product's currency (`{monthly_equivalent}`).
    let monthlyEquivalent: String?
    /// The localized subscription period unit for the billing line (`{period}`: "year" / "month").
    let periodUnit: String?
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
}

/// `PurchasesProviding` over `PurchasesService` (RevenueCat).
@MainActor
final class RevenueCatPurchases: PurchasesProviding {
    private let service: PurchasesService
    private var packages: [String: Package] = [:]

    init(service: PurchasesService) {
        self.service = service
    }

    var isPremium: Bool { service.isPremium }

    func plans() async throws -> [PlanOption] {
        let offerings: Offerings
        do {
            offerings = try await service.offerings()
        } catch {
            throw Self.map(error, otherwise: .unavailable)
        }
        guard let offering = offerings.current else { throw PurchasesFailure.unavailable }
        var result: [PlanOption] = []
        for type in [PackageType.annual, PackageType.monthly] {
            guard let package = offering.availablePackages.first(where: { $0.packageType == type }) else { continue }
            packages[package.identifier] = package
            let product = package.storeProduct
            result.append(PlanOption(
                id: package.identifier,
                period: type == .annual ? .year : .month,
                price: product.localizedPriceString,
                monthlyEquivalent: type == .annual ? product.localizedPricePerMonth : nil,
                periodUnit: product.sk2Product?.subscription?.subscriptionPeriod.unit.localizedDescription
            ))
        }
        guard !result.isEmpty else { throw PurchasesFailure.unavailable }
        return result
    }

    func purchase(_ plan: PlanOption) async throws -> PurchaseResult {
        guard let package = packages[plan.id] else { throw PurchasesFailure.unavailable }
        do {
            switch try await service.purchase(package) {
            case .purchased: return .purchased
            case .cancelled: return .cancelled
            }
        } catch let error as RevenueCat.ErrorCode where error == .purchaseCancelledError {
            return .cancelled
        } catch let error as RevenueCat.ErrorCode where error == .paymentPendingError {
            return .pending
        } catch {
            throw Self.map(error, otherwise: .failed)
        }
    }

    func restore() async throws -> Bool {
        do {
            try await service.restore()
            return service.isPremium
        } catch {
            throw Self.map(error, otherwise: .failed)
        }
    }

    private static func map(_ error: Error, otherwise: PurchasesFailure) -> PurchasesFailure {
        if let code = error as? RevenueCat.ErrorCode, code == .networkError || code == .offlineConnectionError {
            return .offline
        }
        if (error as NSError).domain == NSURLErrorDomain { return .offline }
        return otherwise
    }
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

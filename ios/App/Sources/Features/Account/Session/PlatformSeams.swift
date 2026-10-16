// Account group — live adapters for the seams in Seams.swift: notification permission over `PushService` and
// subscriptions over `PurchasesService` (RevenueCat).
import AppModels
import AppServices
import Foundation
import RevenueCat
import StoreKit

// MARK: - Notifications

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
        if let status = try? await push.requestAuthorization() { return status }
        return await push.authorizationStatus()
    }
}

// MARK: - Purchases

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
                periodUnit: product.sk2Product?.subscription?.subscriptionPeriod.unit.localizedDescription,
                trialDuration: Self.trialDuration(of: product)
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

    /// The introductory free trial's length ("1 week", the locale's full units), or nil when the product has none.
    private static func trialDuration(of product: StoreProduct) -> String? {
        guard let intro = product.introductoryDiscount, intro.paymentMode == .freeTrial else { return nil }
        let period = intro.subscriptionPeriod
        var components = DateComponents()
        switch period.unit {
        case .day: components.day = period.value
        case .week: components.weekOfMonth = period.value
        case .month: components.month = period.value
        case .year: components.year = period.value
        @unknown default: return nil
        }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .weekOfMonth, .month, .year]
        return formatter.string(from: components)
    }

    private static func map(_ error: Error, otherwise: PurchasesFailure) -> PurchasesFailure {
        if let code = error as? RevenueCat.ErrorCode, code == .networkError || code == .offlineConnectionError {
            return .offline
        }
        if (error as NSError).domain == NSURLErrorDomain { return .offline }
        return otherwise
    }
}

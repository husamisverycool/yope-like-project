#if os(iOS)
import Foundation
import Observation
import RevenueCat

/// Subscriptions through RevenueCat (StoreKit 2): entitlement `premium` (config/app.json
/// `revenuecat.entitlement`), offerings, purchase, restore and live customer info. No UI; the
/// `paywall` screen uses this. Display prices always come from the store via `Offerings`.
@MainActor
@Observable
public final class PurchasesService {
    public enum PurchasesError: Error, Equatable, Sendable {
        /// No RevenueCat API key yet (config/app.json `revenuecat.iosApiKey` is BLOCKED).
        case notConfigured
    }

    public enum PurchaseOutcome: Hashable, Sendable {
        case purchased
        case cancelled
    }

    public private(set) var isConfigured = false
    public private(set) var isPremium = false

    /// config/app.json `revenuecat.entitlement`; nil means nothing unlocks premium.
    public let entitlementID: String?
    @ObservationIgnored private var customerInfoTask: Task<Void, Never>?

    public init(entitlementID: String?) {
        self.entitlementID = entitlementID
    }

    /// Configures the SDK once. Without an API key the service stays unconfigured and every user
    /// is treated as free. `appUserID` is the Supabase user id once signed in (nil: anonymous).
    public func configure(apiKey: String?, appUserID: String?) {
        guard !isConfigured, let apiKey, !apiKey.isEmpty else { return }
        Purchases.configure(with: Configuration.Builder(withAPIKey: apiKey).with(appUserID: appUserID).build())
        isConfigured = true
        customerInfoTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
    }

    public func refresh() async throws {
        try requireConfigured()
        apply(try await Purchases.shared.customerInfo())
    }

    public func offerings() async throws -> Offerings {
        try requireConfigured()
        return try await Purchases.shared.offerings()
    }

    /// Whether the person is eligible for the product's introductory offer (the annual plan's free trial, owner decision 7).
    /// RevenueCat: "The best course of action on unknown status is to display the non-intro pricing, to not create a
    /// misleading situation" (`checkTrialOrIntroDiscountEligibility(product:)`), so only `.eligible` counts.
    public func isEligibleForIntroOffer(_ product: StoreProduct) async -> Bool {
        guard isConfigured, product.introductoryDiscount != nil else { return false }
        return await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: product).isEligible
    }

    public func purchase(_ package: Package) async throws -> PurchaseOutcome {
        try requireConfigured()
        let result = try await Purchases.shared.purchase(package: package)
        apply(result.customerInfo)
        return result.userCancelled ? .cancelled : .purchased
    }

    public func restore() async throws {
        try requireConfigured()
        apply(try await Purchases.shared.restorePurchases())
    }

    /// Associates purchases with the signed-in user.
    public func logIn(userID: String) async throws {
        try requireConfigured()
        let (info, _) = try await Purchases.shared.logIn(userID)
        apply(info)
    }

    public func logOut() async throws {
        try requireConfigured()
        apply(try await Purchases.shared.logOut())
    }

    private func apply(_ info: CustomerInfo) {
        guard let entitlementID else {
            isPremium = false
            return
        }
        isPremium = info.entitlements[entitlementID]?.isActive == true
    }

    private func requireConfigured() throws {
        guard isConfigured else { throw PurchasesError.notConfigured }
    }
}
#endif

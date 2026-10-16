package app.billing

import android.app.Activity
import android.content.Context
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.EntitlementInfo
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.PurchasesException
import com.revenuecat.purchases.PurchasesTransactionException
import com.revenuecat.purchases.awaitCustomerInfo
import com.revenuecat.purchases.awaitLogIn
import com.revenuecat.purchases.awaitLogOut
import com.revenuecat.purchases.awaitOfferings
import com.revenuecat.purchases.awaitPurchase
import com.revenuecat.purchases.awaitRestore
import com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import java.time.Instant

/** The premium entitlement as the app sees it; no RevenueCat type reaches the screens. */
data class PremiumStatus(
    val active: Boolean,
    val expiresAt: Instant?,
    val willRenew: Boolean,
    val productId: String?,
) {
    companion object {
        val None = PremiumStatus(active = false, expiresAt = null, willRenew = false, productId = null)

        fun from(entitlement: EntitlementInfo?): PremiumStatus =
            if (entitlement == null) None else PremiumStatus(
                active = entitlement.isActive,
                expiresAt = entitlement.expirationDate?.toInstant(),
                willRenew = entitlement.willRenew,
                productId = entitlement.productIdentifier,
            )

        fun from(info: CustomerInfo?, entitlementId: String): PremiumStatus =
            from(info?.entitlements?.get(entitlementId))
    }
}

/** A purchasable package. Prices are the store's localized strings (never computed by us). */
class PremiumPackage internal constructor(internal val rc: Package) {
    val identifier: String get() = rc.identifier
    val productId: String get() = rc.product.id
    val formattedPrice: String get() = rc.product.price.formatted
    /** ISO 8601 billing period (e.g. `P1M`, `P1Y`), or null for one-time products. */
    val billingPeriodIso: String? get() = rc.product.period?.iso8601

    /**
     * The free trial this package's purchase starts with, or null (no free phase, or the person is not eligible).
     * Read from the offer RevenueCat buys for a package (`StoreProduct.defaultOption`: on Play the eligible offer
     * with the longest free trial, else the base plan), whose pricing phases are Play Billing's
     * `ProductDetails.SubscriptionOfferDetails.pricingPhases` one to one (price micros, ISO 8601 billing period).
     */
    val freeTrial: FreeTrial? get() = FreeTrial.of(rc.product.defaultOption?.pricingPhases.orEmpty().map { PhasePrice(it.price.amountMicros, it.billingPeriod.iso8601) })
}

/** One pricing phase of a subscription offer: Play Billing `PricingPhase.priceAmountMicros` and `.billingPeriod`. */
data class PhasePrice(val priceAmountMicros: Long, val billingPeriodIso: String)

/**
 * A free trial read from the store: an offer phase priced 0 ("Free trial: a set number of days, weeks, or months at
 * no charge", Play Console Help 12154973), [periodIso] its billing period (`P1W` = one week —
 * https://developer.android.com/reference/com/android/billingclient/api/ProductDetails.PricingPhase#getBillingPeriod()).
 */
data class FreeTrial(val periodIso: String) {
    companion object {
        /**
         * The first free phase before the last one (the last phase is the recurring full price), as RevenueCat's
         * `SubscriptionOption.freePhase`; Play only returns offers the person is eligible for ("a maximum of 50 user
         * eligible offers per subscription", https://developer.android.com/google/play/billing/integrate).
         */
        fun of(phases: List<PhasePrice>): FreeTrial? =
            phases.dropLast(1).firstOrNull { it.priceAmountMicros == 0L }?.let { FreeTrial(it.billingPeriodIso) }
    }
}

sealed interface PurchaseOutcome {
    data class Done(val status: PremiumStatus) : PurchaseOutcome
    data object Cancelled : PurchaseOutcome
    data class Failed(val code: String, val message: String?) : PurchaseOutcome
    data object NotConfigured : PurchaseOutcome
}

/**
 * RevenueCat, configured from config/app.json (`revenuecat.androidApiKey`, `revenuecat.entitlement`).
 * Without a key every call is a no-op and nobody is premium, so debug and CI builds run as-is.
 * The RevenueCat app user id is the Supabase user id ([identify]), so the RevenueCat webhook can
 * write `entitlements` for the right person.
 */
object Billing {
    val entitlementId: String = BuildConfig.PREMIUM_ENTITLEMENT
    private val apiKey: String? = BuildConfig.REVENUECAT_API_KEY?.takeIf { it.isNotBlank() }

    private val info = MutableStateFlow<CustomerInfo?>(null)

    /** Latest customer info from RevenueCat (null until known or when not configured). */
    val customerInfo: StateFlow<CustomerInfo?> = info.asStateFlow()

    /** Premium status, updated whenever RevenueCat reports new customer info. */
    val premium: Flow<PremiumStatus> = info.map { PremiumStatus.from(it, entitlementId) }

    val isConfigured: Boolean get() = Purchases.isConfigured

    /** Configures RevenueCat once per process. Returns false when no API key is set. */
    @Synchronized
    fun configure(context: Context, appUserId: String? = null, key: String? = apiKey): Boolean {
        if (Purchases.isConfigured) return true
        if (key.isNullOrBlank()) return false
        Purchases.configure(PurchasesConfiguration.Builder(context.applicationContext, key).appUserID(appUserId).build())
        Purchases.sharedInstance.updatedCustomerInfoListener = UpdatedCustomerInfoListener { info.value = it }
        return true
    }

    suspend fun refresh(): PremiumStatus {
        if (!isConfigured) return PremiumStatus.None
        return try {
            Purchases.sharedInstance.awaitCustomerInfo().also { info.value = it }.let { PremiumStatus.from(it, entitlementId) }
        } catch (_: PurchasesException) {
            PremiumStatus.from(info.value, entitlementId)
        }
    }

    /** Packages of the current offering; empty when not configured or unavailable. */
    suspend fun packages(): List<PremiumPackage> {
        if (!isConfigured) return emptyList()
        return try {
            Purchases.sharedInstance.awaitOfferings().current?.availablePackages.orEmpty().map(::PremiumPackage)
        } catch (_: PurchasesException) {
            emptyList()
        }
    }

    suspend fun purchase(activity: Activity, pkg: PremiumPackage): PurchaseOutcome {
        if (!isConfigured) return PurchaseOutcome.NotConfigured
        return try {
            val result = Purchases.sharedInstance.awaitPurchase(PurchaseParams.Builder(activity, pkg.rc).build())
            info.value = result.customerInfo
            PurchaseOutcome.Done(PremiumStatus.from(result.customerInfo, entitlementId))
        } catch (e: PurchasesTransactionException) {
            if (e.userCancelled) PurchaseOutcome.Cancelled else PurchaseOutcome.Failed(e.code.name, e.message)
        } catch (e: PurchasesException) {
            PurchaseOutcome.Failed(e.code.name, e.message)
        }
    }

    suspend fun restore(): PurchaseOutcome {
        if (!isConfigured) return PurchaseOutcome.NotConfigured
        return try {
            val restored = Purchases.sharedInstance.awaitRestore()
            info.value = restored
            PurchaseOutcome.Done(PremiumStatus.from(restored, entitlementId))
        } catch (e: PurchasesException) {
            PurchaseOutcome.Failed(e.code.name, e.message)
        }
    }

    /** After sign-in: ties purchases to the Supabase user id. */
    suspend fun identify(userId: String) {
        if (!isConfigured) return
        try {
            info.value = Purchases.sharedInstance.awaitLogIn(userId).customerInfo
        } catch (_: PurchasesException) {
        }
    }

    /** After sign-out / account deletion. */
    suspend fun reset() {
        if (!isConfigured) return
        try {
            info.value = Purchases.sharedInstance.awaitLogOut()
        } catch (_: PurchasesException) {
            info.value = null
        }
    }
}

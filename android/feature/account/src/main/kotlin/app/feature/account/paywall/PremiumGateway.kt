package app.feature.account.paywall

import android.app.Activity
import app.billing.Billing
import app.billing.PremiumPackage
import app.billing.PurchaseOutcome
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/** A plan's billing period (ISO 8601 `P1M` / `P1Y` from the store). */
enum class PlanPeriod { Monthly, Yearly }

/** One purchasable plan; [price] is the store's localized string (never computed by us). */
class PlanOption(val period: PlanPeriod, val price: String, internal val handle: Any?)

/** Result of a purchase / restore, as the paywall states need it. */
enum class PremiumResult { Done, Cancelled, Pending, Failed, NotConfigured }

/** The premium purchase seam over core:billing (`Billing`, RevenueCat, entitlement `premium`). */
interface PremiumGateway {
    val isActive: Flow<Boolean>

    /** The active plan's period (settings.root "Your Subscription" subtitle), null when not subscribed or unknown. */
    val activePlan: Flow<PlanPeriod?> get() = kotlinx.coroutines.flow.flowOf(null)
    suspend fun refresh(): Boolean
    /** Current offering's monthly and yearly plans; empty when not configured or unavailable. */
    suspend fun plans(): List<PlanOption>
    suspend fun purchase(activity: Activity, plan: PlanOption): PremiumResult
    suspend fun restore(): Pair<PremiumResult, Boolean>
}

/** [PremiumGateway] over [Billing]. */
object BillingPremiumGateway : PremiumGateway {
    override val isActive: Flow<Boolean> = Billing.premium.map { it.active }

    override val activePlan: Flow<PlanPeriod?> = Billing.premium.map { status ->
        val product = status.productId?.takeIf { status.active }
        when {
            product == null -> null
            app.feature.account.BuildConfig.PRODUCT_YEARLY?.let(product::startsWith) == true -> PlanPeriod.Yearly
            app.feature.account.BuildConfig.PRODUCT_MONTHLY?.let(product::startsWith) == true -> PlanPeriod.Monthly
            else -> null
        }
    }

    override suspend fun refresh(): Boolean = Billing.refresh().active

    override suspend fun plans(): List<PlanOption> = Billing.packages().mapNotNull { pkg ->
        val period = when (pkg.billingPeriodIso) {
            "P1M" -> PlanPeriod.Monthly
            "P1Y" -> PlanPeriod.Yearly
            else -> null
        } ?: return@mapNotNull null
        PlanOption(period, pkg.formattedPrice, pkg)
    }

    override suspend fun purchase(activity: Activity, plan: PlanOption): PremiumResult {
        val pkg = plan.handle as? PremiumPackage ?: return PremiumResult.Failed
        return map(Billing.purchase(activity, pkg))
    }

    override suspend fun restore(): Pair<PremiumResult, Boolean> {
        val outcome = Billing.restore()
        return map(outcome) to ((outcome as? PurchaseOutcome.Done)?.status?.active == true)
    }

    private fun map(outcome: PurchaseOutcome): PremiumResult = when (outcome) {
        is PurchaseOutcome.Done -> PremiumResult.Done
        PurchaseOutcome.Cancelled -> PremiumResult.Cancelled
        // RevenueCat reports Ask to Buy / Play PENDING purchases as PAYMENT_PENDING_ERROR.
        is PurchaseOutcome.Failed -> if (outcome.code == PAYMENT_PENDING) PremiumResult.Pending else PremiumResult.Failed
        PurchaseOutcome.NotConfigured -> PremiumResult.NotConfigured
    }

    private const val PAYMENT_PENDING = "PAYMENT_PENDING_ERROR"
}

package app.feature.account.paywall

import android.app.Activity
import app.billing.Billing
import app.billing.PremiumPackage
import app.billing.PurchaseOutcome
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/** A plan's billing period (ISO 8601 `P1M` / `P1Y` from the store). */
enum class PlanPeriod { Monthly, Yearly }

/**
 * One purchasable plan; [price] is the store's localized string (never computed by us). [trialDuration]: the free trial
 * the purchase starts with, in the locale's words ("1 week", `{trial_duration}` of `paywall.plans.trial.cta`), or null.
 */
class PlanOption(val period: PlanPeriod, val price: String, internal val handle: Any?, val trialDuration: String? = null)

/**
 * `{trial_duration}`: an ISO 8601 period from the store (Play's free phase `billingPeriod`, e.g. `P1W`) in the
 * locale's full unit names — ICU `MeasureFormat` WIDE ("1 week", "3 days"; PLATFORM, as iOS's
 * `DateComponentsFormatter` `.full`). Null when the period is not a plain years / months / weeks / days period.
 */
object TrialDuration {
    private val iso = Regex("^P(?:(\\d+)Y)?(?:(\\d+)M)?(?:(\\d+)W)?(?:(\\d+)D)?$")

    fun format(periodIso: String, locale: java.util.Locale = java.util.Locale.getDefault()): String? {
        val match = iso.matchEntire(periodIso) ?: return null
        val units = listOf(
            android.icu.util.MeasureUnit.YEAR,
            android.icu.util.MeasureUnit.MONTH,
            android.icu.util.MeasureUnit.WEEK,
            android.icu.util.MeasureUnit.DAY,
        )
        val measures = units.mapIndexedNotNull { i, unit ->
            match.groupValues[i + 1].toIntOrNull()?.takeIf { it > 0 }?.let { android.icu.util.Measure(it, unit) }
        }
        if (measures.isEmpty()) return null
        return android.icu.text.MeasureFormat.getInstance(locale, android.icu.text.MeasureFormat.FormatWidth.WIDE)
            .formatMeasures(*measures.toTypedArray())
    }
}

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
        // The free trial of the offer the purchase buys (core:billing `PremiumPackage.freeTrial`; owner decision 7:
        // one week on the annual plan, set up in Play Console as a free-trial offer — docs/OWNER_SETUP.md).
        PlanOption(period, pkg.formattedPrice, pkg, pkg.freeTrial?.let { TrialDuration.format(it.periodIso) })
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

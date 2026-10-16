package app.billing

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.revenuecat.purchases.EntitlementInfo
import com.revenuecat.purchases.OwnershipType
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PackageType
import com.revenuecat.purchases.models.Period
import com.revenuecat.purchases.models.Price
import com.revenuecat.purchases.models.PricingPhase
import com.revenuecat.purchases.models.RecurrenceMode
import com.revenuecat.purchases.models.TestStoreProduct
import com.revenuecat.purchases.PeriodType
import com.revenuecat.purchases.Store
import com.revenuecat.purchases.VerificationResult
import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.time.Instant
import java.util.Date

@RunWith(AndroidJUnit4::class)
class BillingTest {
    private fun entitlement(active: Boolean, expires: Instant?) = EntitlementInfo(
        "premium", active, true, PeriodType.NORMAL, Date(0), Date(0), expires?.let { Date.from(it) },
        Store.PLAY_STORE, "premium_monthly", null, false, null, null, OwnershipType.PURCHASED, JSONObject(),
        VerificationResult.NOT_REQUESTED,
    )

    @Test fun entitlementIdComesFromConfig() {
        assertEquals("premium", Billing.entitlementId)
    }

    @Test fun mapsTheEntitlement() {
        assertEquals(PremiumStatus.None, PremiumStatus.from(null as EntitlementInfo?))
        val expires = Instant.parse("2026-11-15T00:00:00Z")
        val status = PremiumStatus.from(entitlement(active = true, expires = expires))
        assertTrue(status.active)
        assertEquals(expires, status.expiresAt)
        assertEquals("premium_monthly", status.productId)
        assertFalse(PremiumStatus.from(entitlement(active = false, expires = null)).active)
    }

    @Test fun freeTrialIsTheZeroPricedPhaseBeforeTheFullPrice() {
        // Annual base plan $35.99 with a 1-week free-trial offer (owner decision 7): Play's phases for that offer.
        val trialOffer = listOf(PhasePrice(0L, "P1W"), PhasePrice(35_990_000L, "P1Y"))
        assertEquals(FreeTrial("P1W"), FreeTrial.of(trialOffer))
        // The base plan alone (no offer, or the person is no longer eligible): no trial.
        assertNull(FreeTrial.of(listOf(PhasePrice(35_990_000L, "P1Y"))))
        // An introductory price is not a free trial; a free phase after it still is.
        assertNull(FreeTrial.of(listOf(PhasePrice(990_000L, "P1M"), PhasePrice(3_990_000L, "P1M"))))
        assertEquals(FreeTrial("P3D"), FreeTrial.of(listOf(PhasePrice(990_000L, "P1M"), PhasePrice(0L, "P3D"), PhasePrice(3_990_000L, "P1M"))))
        // A zero-priced last phase is the recurring price, never a trial.
        assertNull(FreeTrial.of(listOf(PhasePrice(0L, "P1M"))))
        assertNull(FreeTrial.of(emptyList()))
    }

    @Test fun aPackageExposesTheFreeTrialOfTheOfferItBuys() {
        val yearly = Price("$35.99", 35_990_000L, "USD")
        val week = PricingPhase(Period.create("P1W"), RecurrenceMode.FINITE_RECURRING, 1, Price("Free", 0L, "USD"))
        fun pkg(trial: PricingPhase?) = PremiumPackage(
            Package("\$rc_annual", PackageType.ANNUAL, TestStoreProduct("premium_yearly", "Annual", "Annual", "Premium", yearly, Period.create("P1Y"), trial, null), "default"),
        )
        assertEquals(FreeTrial("P1W"), pkg(week).freeTrial)
        assertEquals("$35.99", pkg(week).formattedPrice)
        assertEquals("P1Y", pkg(week).billingPeriodIso)
        assertNull(pkg(null).freeTrial)
    }

    @Test fun withoutAnApiKeyEverythingIsANoOp() = runBlocking {
        assertFalse(Billing.configure(ApplicationProvider.getApplicationContext(), key = null))
        assertFalse(Billing.isConfigured)
        assertEquals(PremiumStatus.None, Billing.refresh())
        assertTrue(Billing.packages().isEmpty())
        assertEquals(PurchaseOutcome.NotConfigured, Billing.restore())
    }
}

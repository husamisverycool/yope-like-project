package app.billing

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.revenuecat.purchases.EntitlementInfo
import com.revenuecat.purchases.OwnershipType
import com.revenuecat.purchases.PeriodType
import com.revenuecat.purchases.Store
import com.revenuecat.purchases.VerificationResult
import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
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

    @Test fun withoutAnApiKeyEverythingIsANoOp() = runBlocking {
        assertFalse(Billing.configure(ApplicationProvider.getApplicationContext(), key = null))
        assertFalse(Billing.isConfigured)
        assertEquals(PremiumStatus.None, Billing.refresh())
        assertTrue(Billing.packages().isEmpty())
        assertEquals(PurchaseOutcome.NotConfigured, Billing.restore())
    }
}

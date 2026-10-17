package app.feature.account

import app.feature.account.paywall.PaywallUiState
import app.feature.account.paywall.Perk
import app.model.DeepLinkCodec
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** `app://premium?perk=widgets` (widget.styles → Locked) opens the paywall at the widgets perk's page. */
class PaywallPerkLinkTest {
    @Test fun perksAreNamedInLinksAsOnIos() {
        assertEquals(Perk.Widgets, Perk.fromWire(DeepLinkCodec.PERK_WIDGETS))
        assertEquals("video", Perk.Video.wire)
        assertNull(Perk.fromWire("gold"))
        assertNull(Perk.fromWire(null))
        assertNull("opened from settings: the first page", PaywallUiState().initialPerk)
        assertEquals(Perk.Widgets, PaywallUiState(initialPerk = Perk.Widgets).initialPerk)
    }
}

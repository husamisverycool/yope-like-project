package app.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `app://premium?perk=widgets&to=<route>&…`: a widget whose chosen style needs premium (design/surfaces/widget.styles.md)
 * opens the paywall once per session, then its usual destination. The same format as iOS `DeepLinkPremiumTests`.
 */
class DeepLinkPremiumTest {
    private val codec = DeepLinkCodec("example.org")

    @Test fun roundTripsWithItsDestination() {
        val links = listOf(
            DeepLink.Premium("widgets", DeepLink.Camera("g1")),
            DeepLink.Premium("widgets", DeepLink.Camera(null)),
            DeepLink.Premium("widgets", DeepLink.Collage("g1", "c1")),
            DeepLink.Premium("widgets", DeepLink.Post("g1", "p1")),
            DeepLink.Premium("widgets", null),
        )
        for (link in links) {
            val uri = codec.format(link)
            assertEquals(uri, link, codec.parse(uri))
        }
        assertEquals("app://premium?perk=widgets&to=camera&group=g1", codec.format(DeepLink.Premium("widgets", DeepLink.Camera("g1"))))
        assertEquals("app://premium?perk=widgets", codec.format(DeepLink.Premium(DeepLinkCodec.PERK_WIDGETS)))
        // An invite or a nested premium link is never a destination.
        assertEquals("app://premium?perk=widgets", codec.format(DeepLink.Premium("widgets", DeepLink.Invite("t"))))
    }

    @Test fun rejectsBadPerksAndNestedPremium() {
        assertNull(codec.parse("app://premium?perk=../x&to=camera"))
        assertNull(codec.parse("app://premium?to=camera"))
        assertEquals(DeepLink.Premium("widgets", null), codec.parse("app://premium?perk=widgets&to=premium"))
        // An incomplete destination is dropped; the paywall link stays.
        assertEquals(DeepLink.Premium("widgets", null), codec.parse("app://premium?perk=widgets&to=post&group=g1"))
        assertEquals(DeepLink.Premium("widgets", null), codec.parse("app://premium?perk=widgets&to=nowhere&group=g1"))
    }

    @Test fun neverFromANotification() {
        val alert = PushMessage.parse(
            mapOf("type" to "new_post", "group_id" to "g1", "post_id" to "p1", "title" to "Ana", "link" to "app://premium?perk=widgets&to=camera"),
            codec,
        ) as PushMessage.Alert
        assertEquals(DeepLink.Post("g1", "p1"), alert.link)
    }

    @Test fun routingShowsTheDestinationWithOrWithoutThePaywall() {
        val link = DeepLink.Premium("widgets", DeepLink.Camera("g1"))
        assertEquals(listOf(AppRoute.GroupsList, AppRoute.Camera("g1")), DeepLinkRouting.backStack(link))
        assertEquals(listOf(AppRoute.GroupsList, AppRoute.Camera("g1"), PaywallPerkRoute("widgets")), DeepLinkRouting.withPaywall(link))
        assertEquals(listOf(AppRoute.GroupsList, PaywallPerkRoute("widgets")), DeepLinkRouting.withPaywall(DeepLink.Premium("widgets")))
        assertEquals("paywall", PaywallPerkRoute("widgets").surface)
    }

    @Test fun stylesDrawPhotoWithoutPremium() {
        assertEquals(WidgetStyle.Photo, WidgetStyle.default)
        assertEquals(WidgetStyle.Photo, WidgetStyle.Date.drawn(premium = false))
        assertEquals(WidgetStyle.Frame, WidgetStyle.Frame.drawn(premium = true))
        assertTrue(WidgetStyle.Frame.isLocked(premium = false))
        assertFalse(WidgetStyle.Photo.isLocked(premium = false))
        assertEquals(WidgetStyle.Date, WidgetStyle.fromWire("date"))
        assertEquals(WidgetStyle.Photo, WidgetStyle.fromWire(null))
        assertEquals(WidgetStyle.Photo, WidgetStyle.fromWire("gold"))
    }
}

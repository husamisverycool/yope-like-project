package app.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DeepLinkTest {
    private val codec = DeepLinkCodec("example.org")

    @Test fun parsesInviteLinks() {
        assertEquals(DeepLink.Invite("AbC_12-x"), codec.parse("https://example.org/i/AbC_12-x"))
        assertEquals(DeepLink.Invite("tok"), codec.parse("https://EXAMPLE.org/i/tok/"))
        assertEquals(DeepLink.Invite("tok"), codec.parse("https://example.org/i/tok?utm=x#frag"))
    }

    @Test fun rejectsInviteLinksOnOtherHostsSchemesOrPaths() {
        assertNull(codec.parse("https://evil.example/i/tok"))
        assertNull(codec.parse("https://example.org.evil.example/i/tok"))
        assertNull(codec.parse("http://example.org/i/tok"))
        assertNull(codec.parse("https://example.org:8443/i/tok"))
        assertNull(codec.parse("https://example.org/x/tok"))
        assertNull(codec.parse("https://example.org/i/"))
        assertNull(codec.parse("https://example.org/i/a/b"))
        assertNull(codec.parse("https://example.org/i/..%2F..%2Fetc"))
    }

    @Test fun inviteLinksNeedAConfiguredDomain() {
        val unset = DeepLinkCodec(null)
        assertNull(unset.parse("https://example.org/i/tok"))
        assertNull(unset.format(DeepLink.Invite("tok")))
        assertEquals(DeepLink.Camera("g1"), unset.parse("app://camera?group=g1"))
    }

    @Test fun parsesWidgetCameraLink() {
        assertEquals(DeepLink.Camera("0b7c1f9e-4a7d-4c1e-9f00-1a2b3c4d5e6f"), codec.parse("app://camera?group=0b7c1f9e-4a7d-4c1e-9f00-1a2b3c4d5e6f"))
        assertEquals(DeepLink.Camera("g"), codec.parse("APP://CAMERA?group=g"))
        assertNull(codec.parse("app://camera/extra?group=g"))
        assertNull(codec.parse("app:camera?group=g"))
        assertNull(codec.parse("other://camera?group=g"))
    }

    @Test fun parsesNotificationRoutes() {
        assertEquals(DeepLink.Post("g", "p"), codec.parse("app://post?group=g&post=p"))
        assertEquals(DeepLink.ChatMessage("g", "m"), codec.parse("app://chat?post=x&message=m&group=g"))
        assertEquals(DeepLink.DailyInvitation("g", "i"), codec.parse("app://daily?group=g&invitation=i"))
        assertEquals(DeepLink.Recap("g", "r"), codec.parse("app://recap?group=g&recap=r"))
        assertEquals(DeepLink.BirthdayRequest("g", "r"), codec.parse("app://birthday-request?group=g&request=r"))
        assertEquals(DeepLink.Tribute("g", "t"), codec.parse("app://tribute?group=g&tribute=t"))
        assertEquals(DeepLink.YearStory("g", 2026), codec.parse("app://year-story?group=g&year=2026"))
        assertNull(codec.parse("app://year-story?group=g&year=26"))
        assertEquals(DeepLink.Collage("g", "c"), codec.parse("app://collage?group=g&collage=c"))
        assertNull(codec.parse("app://collage?group=g"))
        assertNull(codec.parse("app://post?group=g"))
        assertNull(codec.parse("app://unknown?group=g"))
    }

    /** C-24: a widget without a group (or with an unreadable one) still opens the camera. */
    @Test fun cameraLinkWithoutAReadableGroupOpensTheCamera() {
        assertEquals(DeepLink.Camera(null), codec.parse("app://camera"))
        assertEquals(DeepLink.Camera(null), codec.parse("app://camera?group="))
        assertEquals(DeepLink.Camera(null), codec.parse("app://camera?group=../x"))
        assertEquals("app://camera", codec.format(DeepLink.Camera()))
        assertEquals(DeepLink.Camera(), codec.parse(codec.format(DeepLink.Camera())))
        assertEquals(listOf(AppRoute.GroupsList, AppRoute.Camera(null)), DeepLinkRouting.backStack(DeepLink.Camera()))
    }

    @Test fun firstValueOfARepeatedKeyWins() {
        assertEquals(DeepLink.Camera("a"), codec.parse("app://camera?group=a&group=b"))
    }

    @Test fun rejectsGarbage() {
        listOf(null, "", "  ", "not a uri", "app://", "app://%zz?group=g", "app://camera?group=%zz", "app://post?group=%zz&post=p", "mailto:x@example.org")
            .forEach { assertNull(it, codec.parse(it)) }
    }

    @Test fun formatRoundTrips() {
        val links = listOf(
            DeepLink.Invite("tok_1"),
            DeepLink.Camera("g"),
            DeepLink.Post("g", "p"),
            DeepLink.ChatMessage("g", "m"),
            DeepLink.DailyInvitation("g", "i"),
            DeepLink.Recap("g", "r"),
            DeepLink.BirthdayRequest("g", "r"),
            DeepLink.Tribute("g", "t"),
            DeepLink.YearStory("g", 2025),
            DeepLink.Collage("g", "c"),
        )
        for (link in links) assertEquals(link, codec.parse(codec.format(link)))
        assertEquals("app://camera?group=g", codec.format(DeepLink.Camera("g")))
        assertEquals("https://example.org/i/tok_1", codec.format(DeepLink.Invite("tok_1")))
    }

    @Test fun routingBuildsAPredictableBackStack() {
        assertEquals(listOf(AppRoute.InviteJoin("t")), DeepLinkRouting.backStack(DeepLink.Invite("t")))
        assertEquals(listOf(AppRoute.GroupsList, AppRoute.Camera("g")), DeepLinkRouting.backStack(DeepLink.Camera("g")))
        assertEquals(
            listOf(AppRoute.GroupsList, AppRoute.Group("g"), AppRoute.PhotoViewer("g", "p")),
            DeepLinkRouting.backStack(DeepLink.Post("g", "p")),
        )
        assertEquals(AppRoute.Chat("g", "m"), DeepLinkRouting.destination(DeepLink.ChatMessage("g", "m")))
        assertEquals(AppRoute.DailyCapture("g", "i"), DeepLinkRouting.destination(DeepLink.DailyInvitation("g", "i")))
        assertEquals(AppRoute.WeekRecap("g", "r"), DeepLinkRouting.destination(DeepLink.Recap("g", "r")))
        assertEquals(AppRoute.BirthdayContribute("g", "r"), DeepLinkRouting.destination(DeepLink.BirthdayRequest("g", "r")))
        assertEquals(AppRoute.Tribute("g", "t"), DeepLinkRouting.destination(DeepLink.Tribute("g", "t")))
        assertEquals(AppRoute.YearStory("g", 2026), DeepLinkRouting.destination(DeepLink.YearStory("g", 2026)))
        // a widget showing the day's collage opens that collage over its group (collage.view)
        assertEquals(
            listOf(AppRoute.GroupsList, AppRoute.Group("g"), AppRoute.CollageById("g", "c")),
            DeepLinkRouting.backStack(DeepLink.Collage("g", "c")),
        )
        assertEquals("app://collage?group=g&collage=c", codec.format(DeepLink.Collage("g", "c")))
    }

    @Test fun everyRouteNamesASurface() {
        val routes = listOf<AppRoute>(
            AppRoute.GroupsList, AppRoute.Camera(), AppRoute.Group("g"), AppRoute.PhotoViewer("g", "p"),
            AppRoute.Paywall, AppRoute.InviteJoin("t"), AppRoute.SafetyReport(postId = "p"),
        )
        routes.forEach { assert(it.surface.isNotBlank()) }
    }
}

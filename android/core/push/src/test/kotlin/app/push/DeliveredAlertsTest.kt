package app.push

import android.Manifest
import android.app.Activity
import android.app.Application
import android.app.NotificationManager
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.links.DeepLinkIntents
import app.model.DeepLinkCodec
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Shadows.shadowOf
import java.time.Instant

/** Alerts of deleted photos and messages leave the shade (directive Part 6: "Deleting a photo removes it everywhere"). */
@RunWith(AndroidJUnit4::class)
class DeliveredAlertsTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val manager get() = app.getSystemService(NotificationManager::class.java)
    private val handler = PushHandler(app, DeepLinkCodec("example.org")) { Instant.parse("2026-10-15T12:00:00Z") }

    class Host : Activity()

    @Before fun setUp() {
        DeepLinkIntents.targetActivity = Host::class.java
        shadowOf(app).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        NotificationAppearance.current = object : NotificationAppearance {
            override val smallIcon = android.R.drawable.ic_dialog_info // test-only stand-in
        }
        NotificationChannels.register(app, name = { it.id })
    }

    @After fun tearDown() {
        DeepLinkIntents.targetActivity = null
        NotificationAppearance.current = object : NotificationAppearance {}
        DeliveredAlerts.existingPosts = null
    }

    private fun alert(type: String, vararg ids: Pair<String, String>) =
        handler.handle(mapOf("type" to type, "group_id" to "g1", "title" to "t") + ids)

    private fun shownPosts() = shadowOf(manager).activeNotifications.mapNotNull { it.notification.extras.getString(DeliveredAlerts.EXTRA_POST_ID) }.toSet()

    @Test fun alertsCarryTheirPostAndADeletionWithdrawsThem() {
        alert("new_post", "post_id" to "p1")
        alert("new_post", "post_id" to "p2")
        alert("reply", "post_id" to "p3", "message_id" to "m1")
        alert("recap_ready", "recap_id" to "r1")
        assertEquals(setOf("p1", "p2", "p3"), DeliveredAlerts.shownPostIds(app))

        assertEquals(1, DeliveredAlerts.withdraw(app, setOf("p2"), emptySet()))
        assertEquals(setOf("p1", "p3"), shownPosts())
        assertEquals(1, DeliveredAlerts.withdraw(app, emptySet(), setOf("m1")))
        assertEquals(setOf("p1"), shownPosts())
        assertEquals(2, shadowOf(manager).activeNotifications.size, "the recap alert stays")
    }

    @Test fun reconcileWithdrawsThePostsTheServerNoLongerReturns() = runBlocking {
        alert("new_post", "post_id" to "p1")
        alert("reaction", "post_id" to "p2")
        assertEquals(0, DeliveredAlerts.reconcile(app), "no lookup yet (signed out / no data layer): nothing goes")
        DeliveredAlerts.existingPosts = { null }
        assertEquals(0, DeliveredAlerts.reconcile(app), "offline: nothing goes")
        DeliveredAlerts.existingPosts = { ids -> ids - "p2" }
        assertEquals(1, DeliveredAlerts.reconcile(app))
        assertEquals(setOf("p1"), shownPosts())
    }

    private fun assertEquals(expected: Any, actual: Any, message: String) = org.junit.Assert.assertEquals(message, expected, actual)
}

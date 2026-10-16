package app.push

import android.Manifest
import android.app.Activity
import android.app.Application
import android.app.NotificationManager
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.links.DeepLinkIntents
import app.model.DeepLinkCodec
import app.model.PushMessage
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.time.Instant

/**
 * The two channels of the new features (MERGE_DECISIONS PL-12, ON-9): "Plans" carries every plan push; "Developed Photos"
 * exists with its copy, but the overnight reveal push (type `new_post`, no marker) still arrives on New Posts.
 */
@RunWith(AndroidJUnit4::class)
@Config(qualifiers = "en-rUS")
class PlanChannelsTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val manager get() = app.getSystemService(NotificationManager::class.java)
    private val handler = PushHandler(app, DeepLinkCodec("example.org")) { Instant.parse("2026-10-16T12:00:00Z") }

    class Host : Activity()

    @Before fun setUp() {
        DeepLinkIntents.targetActivity = Host::class.java
        shadowOf(app).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        NotificationAppearance.current = object : NotificationAppearance {
            override val smallIcon = android.R.drawable.ic_dialog_info // test-only stand-in
        }
    }

    @After fun tearDown() {
        DeepLinkIntents.targetActivity = null
        NotificationAppearance.current = object : NotificationAppearance {}
    }

    @Test fun alertKindsMapToTheirChannels() {
        assertEquals(AppChannel.Plans, AppChannel.forAlert(PushMessage.AlertKind.Plan))
        assertEquals("plans", AppChannel.Plans.id)
        assertEquals("developed_photos", AppChannel.DevelopedPhotos.id)
        assertEquals(NotificationManager.IMPORTANCE_DEFAULT, AppChannel.Plans.importance)
        assertEquals(NotificationManager.IMPORTANCE_DEFAULT, AppChannel.DevelopedPhotos.importance)
        // The reveal push is type new_post: nothing in it tells it from a new post.
        assertEquals(AppChannel.NewPost, AppChannel.forAlert(PushMessage.AlertKind.NewPost))
    }

    @Test fun bothChannelsAreRegisteredWithTheirCopy() {
        ChannelCopy.registerAll(app)
        val plans = manager.getNotificationChannel("plans")
        assertEquals("Plans", plans.name)
        assertEquals("When someone makes, changes or cancels a plan, and the day before one you're going to", plans.description)
        val developed = manager.getNotificationChannel("developed_photos")
        assertEquals("Developed Photos", developed.name)
        // {time}: 09:00 in the locale's short time format.
        assertEquals("When photos taken for 9:00 AM are ready to view", developed.description.replace('\u202F', ' '))
        assertTrue(ChannelCopy.registered.containsAll(listOf(AppChannel.Plans, AppChannel.DevelopedPhotos)))
    }

    @Test fun aPlanPushIsPostedOnThePlansChannelAndOpensThePlan() {
        ChannelCopy.registerAll(app)
        val outcome = handler.handle(mapOf("type" to "plan", "group_id" to "g1", "plan_id" to "p1", "title" to "Sunday Dinners", "body" to "Ana made a plan", "collapse_key" to "plan:p1"))
        assertEquals(PushHandler.Outcome.AlertShown, outcome)
        val n = shadowOf(manager).allNotifications.single()
        assertEquals("plans", n.channelId)
        assertEquals("app://plan?plan=p1&group=g1", shadowOf(n.contentIntent).savedIntent.dataString)
    }
}

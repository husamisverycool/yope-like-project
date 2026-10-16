package app.feature.capture

import android.Manifest
import android.app.Activity
import android.app.Application
import android.app.Notification
import android.app.NotificationManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import android.widget.FrameLayout
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.links.DeepLinkIntents
import app.model.DeepLinkCodec
import app.push.ChannelCopy
import app.push.NotificationAppearance
import app.push.PushHandler
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Instant

/**
 * The platform's own notification templates for what core:push posts (daily.ongoing / daily.notification,
 * notifications.push), inflated from the posted Notification and drawn, so the verification side-by-side shows the
 * real system layout (header, chronometer, title, text) with the Retro-voice copy the worker sends and no tint
 * (RC-16, RC-17). Light and dark (the system draws them in the current appearance).
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xxhdpi")
class NotificationSnapshotTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val manager get() = app.getSystemService(NotificationManager::class.java)
    private val now = Instant.parse("2026-10-15T12:00:00Z")

    class Host : Activity()

    @Before fun setUp() {
        DeepLinkIntents.targetActivity = Host::class.java
        shadowOf(app).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        NotificationAppearance.current = object : NotificationAppearance {
            override val smallIcon = android.R.drawable.ic_dialog_info // test-only stand-in: the owner's icon is BLOCKED
        }
        ChannelCopy.registerAll(app)
        // The shade's clock: the chronometer and timestamps read the device time.
        android.os.SystemClock.setCurrentTimeMillis(now.toEpochMilli())
    }

    @After fun tearDown() {
        DeepLinkIntents.targetActivity = null
        NotificationAppearance.current = object : NotificationAppearance {}
    }

    private fun render(n: Notification, expanded: Boolean, dark: Boolean = false): Bitmap {
        val builder = Notification.Builder.recoverBuilder(app, n)
        val views = if (expanded) builder.createBigContentView() ?: builder.createContentView() else builder.createContentView()
        val parent = FrameLayout(app)
        val view = views.apply(app, parent)
        val w = app.resources.displayMetrics.widthPixels
        view.measure(View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED))
        view.layout(0, 0, view.measuredWidth, view.measuredHeight)
        val bitmap = Bitmap.createBitmap(view.measuredWidth, view.measuredHeight.coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(if (dark) 0xFF000000.toInt() else 0xFFFFFFFF.toInt()) // test backdrop behind the platform's template, not app UI
        view.draw(canvas)
        return bitmap
    }

    private fun postInvitation() = PushHandler(app, DeepLinkCodec(null)) { now }.handle(
        mapOf(
            "type" to "daily_invitation", "group_id" to "g1", "invitation_id" to "inv1", "closes_at" to "2026-10-15T12:02:00Z",
            // The worker's rendering of notifications.push.dailyInvitation.title / .body.
            "title" to "Sunday dinners", "body" to "What are you up to right now?",
        ),
    )

    @Test fun dailyInvitationCountdown() {
        postInvitation()
        render(shadowOf(manager).allNotifications.single(), expanded = true).captureRoboImage("src/test/snapshots/daily.ongoing_notification.png")
    }

    @Test fun dailyInvitationCountdownDark() {
        RuntimeEnvironment.setQualifiers("+night")
        postInvitation()
        render(shadowOf(manager).allNotifications.single(), expanded = true, dark = true).captureRoboImage("src/test/snapshots/daily.ongoing_notification-dark.png")
    }

    private fun postNewPost(): Notification {
        PushHandler(app, DeepLinkCodec(null)) { now }.handle(
            // notifications.push.newPost.title / .body as the worker renders them.
            mapOf("type" to "new_post", "group_id" to "g1", "post_id" to "p1", "title" to "Sunday dinners", "body" to "Ana just posted."),
        )
        val n = shadowOf(manager).allNotifications.single()
        // The shade shows the post time relative to the device clock: pin it to the post ("now").
        android.os.SystemClock.setCurrentTimeMillis(n.`when`)
        return n
    }

    @Test fun newPostAlert() {
        render(postNewPost(), expanded = true).captureRoboImage("src/test/snapshots/notifications.push_new-post.png")
    }

    @Test fun newPostAlertDark() {
        RuntimeEnvironment.setQualifiers("+night")
        render(postNewPost(), expanded = true, dark = true).captureRoboImage("src/test/snapshots/notifications.push_new-post-dark.png")
    }
}

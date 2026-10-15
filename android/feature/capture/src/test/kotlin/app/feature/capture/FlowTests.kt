package app.feature.capture

import android.Manifest
import android.app.Activity
import android.app.Application
import android.app.Notification
import android.app.NotificationManager
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertIsOn
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.core.app.NotificationCompat
import app.feature.capture.camera.CameraControllers
import app.feature.capture.data.CaptureDataProvider
import app.feature.capture.data.CaptureServices
import app.feature.capture.data.SendTracker
import app.links.DeepLinkIntents
import app.media.DualCaptureMode
import app.model.AppRoute
import app.model.DeepLinkCodec
import app.model.QuietHours
import app.push.AppChannel
import app.push.ChannelCopy
import app.push.NotificationAppearance
import app.push.PushHandler
import app.push.QuietHoursSource
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneOffset

/** The capture group's flows end to end in Robolectric (fake camera and data layer). */
@RunWith(AndroidJUnit4::class)
@Config(qualifiers = "w393dp-h852dp-xxhdpi")
class FlowTests {
    @get:Rule val compose = createComposeRule()
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val data = FakeCaptureData()
    private lateinit var camera: FakeCameraController

    @Before fun setUp() {
        shadowOf(app).grantPermissions(Manifest.permission.CAMERA)
        CaptureDataProvider.override = data
        CaptureServices.overrideTracker(SendTracker(data, CoroutineScope(SupervisorJob() + Dispatchers.Main)))
        camera = FakeCameraController()
        CameraControllers.factory = { _, _ -> camera }
    }

    @After fun tearDown() {
        CaptureDataProvider.override = null
        CaptureServices.overrideTracker(null)
        app.feature.capture.data.CaptureHandoff.process.clear()
    }

    private fun host(start: AppRoute): NavHostController {
        lateinit var nav: NavHostController
        compose.setContent {
            nav = rememberNavController()
            NavHost(nav, startDestination = AppRoute.GroupsList) {
                composable<AppRoute.GroupsList> { Box(Modifier.fillMaxSize().testTag("home")) }
                composable<AppRoute.Paywall> { Box(Modifier.fillMaxSize().testTag("paywall")) }
                composable<AppRoute.GroupCreate> { Box(Modifier.fillMaxSize().testTag("groups.create")) }
                captureDestinations(nav)
            }
        }
        compose.runOnIdle { nav.navigate(start) }
        compose.waitForIdle()
        return nav
    }

    private fun waitFor(tag: String) = compose.waitUntil(WAIT_MS) { compose.onAllNodes(hasTestTag(tag), useUnmergedTree = true).fetchSemanticsNodes().isNotEmpty() }

    @Test fun widgetLinkOpensTheCameraOneTapCapturesAndSendsToTwoGroups() {
        data.loaded(group("g1", "Sunday dinners"), group("g2", "Roommates"), group("g3", "Family"))
        val nav = host(AppRoute.Camera("g1"))
        waitFor("camera.shutter")
        assertEquals(1, camera.binds.size) // bound as soon as the route opened
        compose.onNodeWithTag("camera.shutter").performClick()
        waitFor("sendto.rows")
        assertTrue(nav.currentDestination!!.hasRoute<AppRoute.SendTo>())
        // The widget's group is preselected; add a second one.
        compose.onNodeWithTag("sendto.row.g1", useUnmergedTree = true).assertIsOn()
        compose.onNodeWithTag("sendto.row.g2", useUnmergedTree = true).performClick()
        compose.onNodeWithTag("sendto.send", useUnmergedTree = true).performClick()
        compose.waitForIdle()
        val post = data.enqueued.single()
        assertEquals(listOf("g1", "g2"), post.groupIds)
        assertTrue(post.original.path.contains("capture"))
        // Sending returns at once (the upload continues in the background) to the home list.
        assertTrue(nav.currentDestination!!.hasRoute<AppRoute.GroupsList>())
    }

    @Test fun cameraWithoutAGroupPreselectsEveryGroup() {
        data.loaded(group("g1", "Sunday dinners"), group("g2", "Roommates"))
        host(AppRoute.Camera(null))
        waitFor("camera.shutter")
        compose.onNodeWithTag("camera.shutter").performClick()
        waitFor("sendto.rows")
        compose.onNodeWithTag("sendto.row.g1", useUnmergedTree = true).assertIsOn()
        compose.onNodeWithTag("sendto.row.g2", useUnmergedTree = true).assertIsOn()
    }

    @Test fun dailyCaptureWithTheSequentialFallbackPostsWithTheInvitation() {
        camera = FakeCameraController(mode = DualCaptureMode.Sequential)
        data.invitation = invitation(closesAt = Instant.now().plusSeconds(120))
        data.groupById["g1"] = group("g1", "Sunday dinners")
        val nav = host(AppRoute.DailyCapture("g1", "inv1"))
        waitFor("daily.shutter")
        compose.onNodeWithTag("daily.shutter").performClick()
        waitFor("daily.dualimage")
        compose.onNodeWithTag("daily.send", useUnmergedTree = true).performClick()
        compose.waitForIdle()
        val post = data.enqueued.single()
        assertEquals("inv1", post.invitationId)
        assertEquals(listOf("g1"), post.groupIds)
        assertNotNull(post.front)
        assertFalse(nav.currentDestination!!.hasRoute<AppRoute.DailyCapture>())
    }

    @Test fun collageEmptyStateOpensTheCameraForTheGroup() {
        data.invitation = invitation(closesAt = Instant.now().minusSeconds(600))
        data.groupById["g1"] = group("g1", "Sunday dinners")
        val nav = host(AppRoute.Collage("g1", "inv1"))
        compose.waitUntil(WAIT_MS) { compose.onAllNodes(androidx.compose.ui.test.hasText("open camera")).fetchSemanticsNodes().isNotEmpty() }
        compose.onNode(androidx.compose.ui.test.hasText("open camera")).performClick()
        compose.waitForIdle()
        assertTrue(nav.currentDestination!!.hasRoute<AppRoute.Camera>())
    }

    class Host : Activity()

    @Test fun dailyInvitationNotificationIsAChronometerCountdownWithTimeoutAndQuietHours() {
        DeepLinkIntents.targetActivity = Host::class.java
        shadowOf(app).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        NotificationAppearance.current = object : NotificationAppearance {
            override val smallIcon = android.R.drawable.ic_dialog_info // test-only stand-in for the owner's icon
        }
        try {
            ChannelCopy.registerAll(app)
            val manager = app.getSystemService(NotificationManager::class.java)
            val channel = manager.getNotificationChannel(AppChannel.DailyInvitation.id)
            assertEquals("Daily Invitation", channel.name)
            assertEquals("Notifications when your group’s daily photo invitation starts", channel.description)
            assertEquals(NotificationManager.IMPORTANCE_HIGH, channel.importance)
            // No channel for an event the worker never sends.
            assertEquals(null, manager.getNotificationChannel(AppChannel.YearStory.id))

            val now = Instant.parse("2026-10-15T12:00:00Z")
            val payload = mapOf(
                "type" to "daily_invitation", "group_id" to "g1", "invitation_id" to "inv1",
                "closes_at" to "2026-10-15T12:02:00Z", "title" to "Time to share a photo.",
                "body" to "Capture a photo and see what Sunday dinners is up to!",
            )
            assertEquals(PushHandler.Outcome.CountdownShown, PushHandler(app, DeepLinkCodec(null)) { now }.handle(payload))
            val n: Notification = shadowOf(manager).allNotifications.single()
            assertTrue(n.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER))
            assertTrue(n.extras.getBoolean(Notification.EXTRA_CHRONOMETER_COUNT_DOWN))
            assertEquals(Instant.parse("2026-10-15T12:02:00Z").toEpochMilli(), n.`when`)
            assertEquals(120_000L, n.timeoutAfter)
            assertEquals(0, n.flags and Notification.FLAG_ONGOING_EVENT)
            assertFalse(n.extras.getBoolean(NotificationCompat.EXTRA_REQUEST_PROMOTED_ONGOING))
            assertEquals(android.graphics.Color.argb(0xFF, 0xCD, 0xFD, 0x07), n.color) // color.global.accent
            assertEquals("app://daily?group=g1&invitation=inv1", shadowOf(n.contentIntent).savedIntent.dataString)

            // Quiet hours (not in the push contract): the same notification, silent.
            QuietHoursSource.current = QuietHoursSource { QuietHours(LocalTime.of(11, 0), LocalTime.of(13, 0)) to ZoneOffset.UTC }
            PushHandler(app, DeepLinkCodec(null)) { now }.handle(payload + ("group_id" to "g2"))
            val quiet = shadowOf(manager).allNotifications.first { it.extras.getString(Notification.EXTRA_TEXT) != null && it !== n }
            assertTrue(NotificationCompat.getGroupAlertBehavior(quiet) == NotificationCompat.GROUP_ALERT_SUMMARY || quiet.sound == null)
        } finally {
            QuietHoursSource.current = QuietHoursSource { null }
            NotificationAppearance.current = object : NotificationAppearance {}
            DeepLinkIntents.targetActivity = null
        }
    }

    private companion object {
        const val WAIT_MS = 5_000L
    }
}

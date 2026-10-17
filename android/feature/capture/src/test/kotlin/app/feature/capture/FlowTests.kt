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
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.dp
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.core.app.NotificationCompat
import app.feature.capture.camera.CameraControllers
import app.feature.capture.camera.CameraScreen
import app.feature.capture.camera.CameraViewModel
import app.feature.capture.data.CaptureDataProvider
import app.data.media.upload.UploadProgress
import app.feature.capture.sendto.SendToChrome
import app.feature.capture.sendto.SendToScreen
import app.data.model.MediaKind
import app.feature.capture.data.CapturedMedia
import app.feature.capture.sendto.SendToViewModel
import androidx.compose.ui.test.longClick
import androidx.compose.ui.unit.Dp
import app.feature.capture.sendto.VoiceActions
import app.feature.capture.sendto.VoiceNoteFile
import app.feature.capture.sendto.VoicePhase
import app.data.error.DataError
import app.feature.capture.ui.VoiceGestures
import app.designsystem.generated.Tokens
import androidx.compose.ui.test.hasText
import app.feature.capture.data.CaptureHandoff
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
        camera = FakeCameraController()
        CameraControllers.factory = { _, _ -> camera }
    }

    @After fun tearDown() {
        CaptureDataProvider.override = null
        CaptureHandoff.process.clear()
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
        waitFor("sendto.row.g1")
        assertTrue(nav.currentDestination!!.hasRoute<AppRoute.SendTo>())
        // The widget's group is preselected; add a second one.
        compose.onNodeWithTag("sendto.row.g1", useUnmergedTree = true).assertIsOn()
        compose.onNodeWithTag("sendto.row.g2", useUnmergedTree = true).performClick()
        compose.onNodeWithTag("sendto.send", useUnmergedTree = true).performClick()
        compose.waitForIdle()
        val post = data.enqueued.single()
        assertEquals(listOf("g1", "g2"), post.groupIds)
        assertTrue(post.original.path.contains("capture"))
        // Sending keeps the modal open ("Sending…") until the post exists, then returns where the camera opened from.
        assertTrue(nav.currentDestination!!.hasRoute<AppRoute.SendTo>())
        compose.onNode(hasText("Sending…")).assertExists()
        compose.runOnIdle { data.progressFlows.getValue("draft1").value = UploadProgress.Done(listOf("p1", "p2")) }
        compose.waitForIdle()
        assertTrue(nav.currentDestination!!.hasRoute<AppRoute.GroupsList>())
    }

    @Test fun aFailedSendShowsTheAlertAndCancelKeepsTheComposer() {
        data.loaded(group("g1", "Sunday dinners"))
        val nav = host(AppRoute.Camera("g1"))
        waitFor("camera.shutter")
        compose.onNodeWithTag("camera.shutter").performClick()
        waitFor("sendto.row.g1")
        compose.onNodeWithTag("sendto.send", useUnmergedTree = true).performClick()
        compose.runOnIdle { data.progressFlows.getValue("draft1").value = UploadProgress.Failed(DataError.Unexpected(null)) }
        compose.waitUntil(WAIT_MS) { compose.onAllNodes(hasText("Couldn't send photo")).fetchSemanticsNodes().isNotEmpty() }
        compose.onNode(hasText("Cancel")).performClick()
        compose.waitForIdle()
        assertTrue(compose.onAllNodes(hasText("Couldn't send photo")).fetchSemanticsNodes().isEmpty())
        assertEquals(listOf("draft1"), data.discarded)
        assertTrue(nav.currentDestination!!.hasRoute<AppRoute.SendTo>())
        compose.onNodeWithTag("sendto.row.g1", useUnmergedTree = true).assertIsOn()
    }

    @Test fun cameraWithoutAGroupPreselectsEveryGroup() {
        data.loaded(group("g1", "Sunday dinners"), group("g2", "Roommates"))
        host(AppRoute.Camera(null))
        waitFor("camera.shutter")
        compose.onNodeWithTag("camera.shutter").performClick()
        waitFor("sendto.row.g1")
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
        compose.runOnIdle { data.progressFlows.getValue("draft1").value = UploadProgress.Done(listOf("p1")) }
        compose.waitForIdle()
        assertFalse(nav.currentDestination!!.hasRoute<AppRoute.DailyCapture>())
    }

    @Test fun collageEmptyStateOpensTheCameraForTheGroup() {
        data.invitation = invitation(closesAt = Instant.now().minusSeconds(600))
        data.groupById["g1"] = group("g1", "Sunday dinners")
        val nav = host(AppRoute.Collage("g1", "inv1"))
        compose.waitUntil(WAIT_MS) { compose.onAllNodes(hasText("Take photo")).fetchSemanticsNodes().isNotEmpty() }
        compose.onNode(hasText("Take photo")).performClick()
        compose.waitForIdle()
        assertTrue(nav.currentDestination!!.hasRoute<AppRoute.Camera>())
    }

    /** Before the permission answer the viewfinder stays black: no denied / unavailable flash, no shutter. */
    @Test fun cameraDoesNotFlashTheDeniedStateWhileChecking() {
        compose.setContent {
            CameraScreen(
                state = CameraViewModel.UiState(),
                viewfinder = {}, title = "Week 42",
                onShutterTap = {}, onShutterLongPress = {}, onShutterRelease = {}, onFlash = {}, onFlip = {}, onLibrary = {},
                onCoachClose = {}, onOpenSettings = {}, onRetry = {},
            )
        }
        assertTrue(compose.onAllNodes(hasText("No Camera Access")).fetchSemanticsNodes().isEmpty())
        assertTrue(compose.onAllNodes(hasText("Camera Unavailable")).fetchSemanticsNodes().isEmpty())
        assertTrue(compose.onAllNodes(hasTestTag("camera.shutter")).fetchSemanticsNodes().isEmpty())
    }

    /**
     * The voice capsule (`chat.voice` mechanics): hold records, lift keeps, slide left discards, slide up locks; locked it
     * is a send button; paused the capsule's glyphs pause / continue / preview / delete; a note's tap plays it and its long
     * press opens its menu.
     */
    @Test fun voiceCapsuleHoldSlideLockAndNoteMenu() {
        val calls = mutableListOf<String>()
        val gestures = object : VoiceGestures {
            override fun down() { calls += "down" }
            override fun release() { calls += "release" }
            override fun cancel() { calls += "cancel" }
            override fun lock() { calls += "lock" }
        }
        val state = androidx.compose.runtime.mutableStateOf(
            SendToViewModel.UiState(
                media = CapturedMedia(MediaKind.Photo, java.io.File(app.cacheDir, "x.jpg"), 300, 400, null, false),
                groups = SendToViewModel.Groups.Loaded(listOf(group("g1", "Family"))),
                selected = setOf("g1"),
                micAvailable = true,
            ),
        )
        var deleted = 0
        compose.setContent {
            SendToScreen(
                state = state.value,
                chrome = SendToChrome(preview = null),
                onClose = {}, onSave = {}, onCaption = {}, onToggle = {}, onSend = {},
                onCreateGroup = {}, onRetryGroups = {}, onConfirmDiscard = {}, onDismissAlert = {}, onRetrySend = {},
                voice = VoiceActions(
                    gestures = gestures,
                    onDelete = { deleted++ },
                    onKeep = { calls += "keep" },
                    onPause = { calls += "pause" },
                    onResume = { calls += "resume" },
                    onPreview = { calls += "preview" },
                    onDiscard = { calls += "discard" },
                    onToggleNote = { calls += "note" },
                ),
            )
        }
        val capsule = compose.onNodeWithTag("sendto.voice", useUnmergedTree = true)
        val far = with(compose.density) { Dp(Tokens.Layouts.CameraSendtoLayoutPreview.width).toPx() }
        val up = with(compose.density) { (Tokens.Sizes.globalPillHeight * 2).toPx() }
        // Hold, then lift.
        capsule.performTouchInput { down(center); advanceEventTime(500); up() }
        assertEquals(listOf("down", "release"), calls)
        // Holding: slide left past half the row cancels; slide up locks.
        calls.clear()
        compose.runOnIdle { state.value = state.value.copy(voicePhase = VoicePhase.Holding) }
        compose.onNodeWithTag("sendto.voice.lock", useUnmergedTree = true).assertExists()
        capsule.performTouchInput { down(center); moveBy(androidx.compose.ui.geometry.Offset(-far, 0f)); up() }
        assertEquals(listOf("down", "cancel", "release"), calls)
        calls.clear()
        capsule.performTouchInput { down(center); moveBy(androidx.compose.ui.geometry.Offset(0f, -up)); up() }
        assertEquals(listOf("down", "lock", "release"), calls)
        // Locked: the capsule is send; the recording capsule's glyph pauses.
        calls.clear()
        compose.runOnIdle { state.value = state.value.copy(voicePhase = VoicePhase.Locked) }
        compose.onNodeWithTag("sendto.voice.lock", useUnmergedTree = true).assertDoesNotExist()
        capsule.performClick()
        compose.onNodeWithTag("sendto.voice.pauseResume", useUnmergedTree = true).performClick()
        assertEquals(listOf("keep", "pause"), calls)
        // Paused: continue, preview, delete.
        calls.clear()
        compose.runOnIdle { state.value = state.value.copy(voicePhase = VoicePhase.Paused) }
        compose.onNodeWithTag("sendto.voice.pauseResume", useUnmergedTree = true).performClick()
        compose.onNodeWithTag("sendto.voice.preview", useUnmergedTree = true).performClick()
        compose.onNodeWithTag("sendto.voice.discard", useUnmergedTree = true).performClick()
        assertEquals(listOf("resume", "preview", "discard"), calls)
        // With a note: a tap plays it; a long press opens its menu; "Delete recording" removes it.
        calls.clear()
        compose.runOnIdle { state.value = state.value.copy(voicePhase = VoicePhase.Idle, voice = VoiceNoteFile(java.io.File(app.cacheDir, "v.m4a"), 7_000)) }
        val note = compose.onNodeWithTag("sendto.voice.attached", useUnmergedTree = true)
        note.performClick()
        assertEquals(listOf("note"), calls)
        note.performTouchInput { longClick() }
        compose.waitUntil(WAIT_MS) { compose.onAllNodes(hasText("Delete recording")).fetchSemanticsNodes().isNotEmpty() }
        compose.onNode(hasText("Delete recording")).performClick()
        compose.waitForIdle()
        assertEquals(1, deleted)
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
            assertEquals("The daily invitation to share a photo with your group", channel.description)
            assertEquals(NotificationManager.IMPORTANCE_HIGH, channel.importance)
            // The year story's one push has its channel (owner decision 31).
            assertEquals("Year in Photos", manager.getNotificationChannel(AppChannel.YearStory.id)?.name)

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
            assertEquals(Notification.COLOR_DEFAULT, n.color) // no tint: the system default (RC-17)
            assertEquals("app://daily?group=g1&invitation=inv1", shadowOf(n.contentIntent).savedIntent.dataString)
            assertTrue(n.flags and Notification.FLAG_AUTO_CANCEL != 0)
            assertTrue(n.groupAlertBehavior != Notification.GROUP_ALERT_SUMMARY) // not silent outside quiet hours

            // Quiet hours (not in the push contract): the same notification, silent.
            QuietHoursSource.current = QuietHoursSource { QuietHours(LocalTime.of(11, 0), LocalTime.of(13, 0)) to ZoneOffset.UTC }
            PushHandler(app, DeepLinkCodec(null)) { now }.handle(payload + ("group_id" to "g2"))
            val quiet = shadowOf(manager).allNotifications.first { it !== n }
            assertEquals(Notification.GROUP_ALERT_SUMMARY, quiet.groupAlertBehavior)
            assertEquals(120_000L, quiet.timeoutAfter)
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

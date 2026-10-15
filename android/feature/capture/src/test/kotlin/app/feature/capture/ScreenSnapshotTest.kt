package app.feature.capture

import android.content.Context
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.error.DataError
import app.data.model.MediaKind
import app.designsystem.LocalReduceMotionOverride
import app.designsystem.generated.Tokens
import app.feature.capture.camera.CameraScreen
import app.feature.capture.camera.CameraViewModel
import app.feature.capture.camera.hourText
import app.feature.capture.collage.CollageScreen
import app.feature.capture.collage.CollageViewModel
import app.feature.capture.daily.DailyCaptureScreen
import app.feature.capture.daily.DailyCaptureViewModel
import app.feature.capture.data.CapturedMedia
import app.feature.capture.sendto.SendToChrome
import app.feature.capture.sendto.SendToScreen
import app.feature.capture.sendto.SendToViewModel
import app.feature.capture.sendto.VoiceNoteFile
import app.feature.capture.ui.DualImage
import app.feature.capture.ui.LimeToast
import app.feature.capture.widget.WidgetPickerScreen
import app.feature.capture.widget.WidgetPickerState
import app.media.DualCaptureMode
import app.model.CountdownState
import app.testing.SamplePhotos
import app.ui.theme.AppTheme
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Rule
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.time.Duration
import java.time.LocalDate
import java.util.TimeZone

/**
 * One snapshot per screen per state (docs/SCREENS_BRIEF.md rule 7), on a 393 × 852 dp screen at
 * 3× (the references' iPhone frame), Reduce Motion off. Every value is the release value (no
 * capture token is BLOCKED since the gap-fill pass).
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xxhdpi")
class ScreenSnapshotTest {
    @get:Rule val compose = createComposeRule()
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val dir = File(context.cacheDir, "snap").apply { mkdirs() }
    private lateinit var hour: String

    @Before fun setUp() {
        TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
        hour = hourText(context, java.time.Instant.parse("2026-05-26T17:20:00Z").toEpochMilli())
    }

    /**
     * The frame clock is paused (infinite platform spinners never go idle) and advanced past the
     * longest settle of these screens before the capture.
     */
    private fun snap(name: String, content: @Composable () -> Unit) {
        compose.mainClock.autoAdvance = false
        compose.setContent { CompositionLocalProvider(LocalReduceMotionOverride provides false) { AppTheme { content() } } }
        compose.mainClock.advanceTimeBy(SETTLE_MS)
        compose.onRoot().captureRoboImage("src/test/snapshots/$name.png")
    }

    private val photo get() = Images.photo(900, 1240, 0).asImageBitmap()
    private val front get() = Images.selfie(300, 400).asImageBitmap()

    // ---- camera.capture ---------------------------------------------------------------------

    private fun camera(name: String, state: CameraViewModel.UiState, live: Boolean = true) = snap("camera.capture_$name") {
        CameraScreen(
            state = state,
            viewfinder = { if (live) Image(photo, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize()) },
            hourText = hour,
            onShutterTap = {}, onShutterLongPress = {}, onShutterRelease = {}, onFlash = {}, onFlip = {}, onLibrary = {},
            onCoachClose = {}, onOpenSettings = {}, onRetry = {},
        )
    }

    private val live = CameraViewModel.UiState(permission = CameraViewModel.Permission.Granted, session = CameraViewModel.Session.Live, hasFlash = true, coachDone = true)

    @Test fun cameraLoading() = camera("loading", live.copy(session = CameraViewModel.Session.Starting), live = false)
    @Test fun cameraLive() = camera("live", live)
    @Test fun cameraLiveFlashOn() = camera("live-flash-on", live.copy(flashOn = true))
    @Test fun cameraCoach() = camera("coach", live.copy(videoAvailable = true, coachDone = false))
    @Test fun cameraRecording() = camera("recording", live.copy(videoAvailable = true, recording = true))
    @Test fun cameraNoFlashUnit() = camera("no-flash", live.copy(hasFlash = false))
    @Test fun cameraPermissionDenied() = camera("denied", live.copy(permission = CameraViewModel.Permission.Denied), live = false)
    @Test fun cameraUnavailable() = camera("unavailable", live.copy(session = CameraViewModel.Session.Unavailable), live = false)

    // ---- camera.sendto ------------------------------------------------------------------------

    private val media = CapturedMedia(MediaKind.Photo, File(dir, "x.jpg"), 900, 1240, null, false)
    private val groups = listOf(group("g1", "Sunday dinners"), group("g2", "Roommates"), group("g3", "Family"))
    /** Group covers (the third group has none: the default group look). */
    private val covers = mapOf("g1" to SamplePhotos.painter("dinner-long-table-3x4", 1, 1), "g2" to SamplePhotos.painter("movie-night-couch-4x3", 1, 1))
    private val loaded = SendToViewModel.UiState(media = media, groups = SendToViewModel.Groups.Loaded(groups), selected = setOf("g1", "g2"), micAvailable = true)

    private fun sendTo(name: String, state: SendToViewModel.UiState, saved: Boolean = false) = snap("camera.sendto_$name") {
        SendToScreen(
            state = state,
            chrome = SendToChrome(preview = photo, hourText = hour, covers = covers),
            onClose = {}, onSave = {}, onCaption = {}, onMic = {}, onVoiceCoachClose = {}, onToggle = {}, onSend = {},
            onCreateGroup = {}, onRetryGroups = {},
            now = { RECORDING_STARTED + 7_000 },
            savedToast = saved,
        )
    }

    @Test fun sendToLoading() = sendTo("loading", loaded.copy(groups = SendToViewModel.Groups.Loading, selected = emptySet()))
    @Test fun sendToLoaded() = sendTo("loaded", loaded)
    @Test fun sendToVoiceCoach() = sendTo("voice-coach", loaded.copy(voiceCoachVisible = true))
    @Test fun sendToCaption() = sendTo("caption", loaded.copy(caption = "sunday dinner at the limas"))
    @Test fun sendToNothingSelected() = sendTo("nothing-selected", loaded.copy(selected = emptySet()))
    @Test fun sendToEmpty() = sendTo("empty", loaded.copy(groups = SendToViewModel.Groups.Empty, selected = emptySet()))
    @Test fun sendToOffline() = sendTo("offline", loaded.copy(groups = SendToViewModel.Groups.Failed(offline = true), selected = emptySet()))
    @Test fun sendToSendFailed() = sendTo("error", loaded.copy(sendError = DataError.Unexpected(null)))
    @Test fun sendToVideoFreeMember() = sendTo("video-free", loaded.copy(media = media.copy(kind = MediaKind.Video, durationMs = 3000), premium = false))

    // The voice note (`chat.voice.layout.recording`): holding the mic, locked hands-free, attached.
    private val recording = loaded.copy(recordingVoice = true, recordingStartedAt = RECORDING_STARTED)
    @Test fun sendToVoiceRecording() = sendTo("voice-recording", recording)
    @Test fun sendToVoiceLocked() = sendTo("voice-locked", recording.copy(voiceLocked = true))
    @Test fun sendToSaved() = sendTo("saved", loaded, saved = true)
    @Test fun sendToVoiceAttached() = sendTo("voice-attached", loaded.copy(voice = VoiceNoteFile(File(dir, "v.m4a"), 7_000)))

    // The toast layouts (posted: shown only once its visible duration is sourced; failure: until sent).
    @Test fun toastPosted() = snap("camera.sendto_toast-posted") {
        Box(Modifier.fillMaxSize()) { LimeToast("posted in Sunday dinners", null, null, Modifier.padding(top = Tokens.Layouts.CameraSendtoLayoutToast.top.dp)) }
    }

    // ---- daily.capture / daily.dualimage --------------------------------------------------------

    private val open = CountdownState.Open(T0.plusSeconds(97), Duration.ofSeconds(97))
    private val dailyLive = DailyCaptureViewModel.UiState(
        permission = DailyCaptureViewModel.Permission.Granted,
        session = DailyCaptureViewModel.Session.Live,
        countdown = open,
        groupName = "Sunday dinners",
        hasFlash = true,
        mode = DualCaptureMode.Concurrent,
    )

    private fun daily(name: String, state: DailyCaptureViewModel.UiState, main: Boolean = false, inset: Boolean = false, live: Boolean = true) = snap("daily.capture_$name") {
        DailyCaptureScreen(
            state = state,
            viewfinder = { if (live) Image(photo, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize()) },
            mainImage = if (main) photo else null,
            insetImage = if (inset) front else null,
            posterName = "Ana",
            onDismiss = {}, onFlash = {}, onFlip = {}, onShutter = {}, onRetake = {}, onSend = {}, onOpenSettings = {}, onRetry = {},
        )
    }

    @Test fun dailyLoading() = daily("loading", dailyLive.copy(session = DailyCaptureViewModel.Session.Starting), live = false)
    @Test fun dailyLiveWindowOpen() = daily("live", dailyLive)
    @Test fun dailyLiveWindowClosed() = daily("live-closed", dailyLive.copy(countdown = null))
    @Test fun dailyCapturing() = daily("capturing", dailyLive.copy(phase = DailyCaptureViewModel.Phase.Capturing), live = false)
    @Test fun dailyPreview() = daily("preview", dailyLive.copy(phase = DailyCaptureViewModel.Phase.Preview), main = true, inset = true)
    @Test fun dailyPreviewSingleCamera() = daily("preview-single", dailyLive.copy(phase = DailyCaptureViewModel.Phase.Preview), main = true)
    @Test fun dailySendFailed() = daily("send-offline", dailyLive.copy(phase = DailyCaptureViewModel.Phase.Preview, sendError = DataError.Network), main = true, inset = true)
    @Test fun dailyDenied() = daily("denied", dailyLive.copy(permission = DailyCaptureViewModel.Permission.Denied), live = false)
    @Test fun dailyUnavailable() = daily("unavailable", dailyLive.copy(session = DailyCaptureViewModel.Session.Unavailable), live = false)

    @Test fun dualImage() = snap("daily.dualimage_component") {
        Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep).padding(top = 124.dp)) { DualImage(photo, front, "Back and front photos from Ana", Modifier.fillMaxWidth()) }
    }

    @Test fun dualImageLoading() = snap("daily.dualimage_loading") {
        Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep).padding(top = 124.dp)) { DualImage(null, null, null, Modifier.fillMaxWidth()) }
    }

    // ---- collage.view / collage.share ------------------------------------------------------------

    private fun pageFile(n: Int): File = File(dir, "page-$n.jpg").also { f ->
        if (!f.isFile) f.outputStream().use { CollagePage.render(1080, n).compress(android.graphics.Bitmap.CompressFormat.JPEG, 92, it) }
    }

    private fun collage(name: String, state: CollageViewModel.UiState) = snap("collage.view_$name") {
        CollageScreen(
            state = state,
            pageImage = { f -> f?.let { android.graphics.BitmapFactory.decodeFile(it.path).asImageBitmap() } },
            onBack = {}, onPage = {}, onShare = {}, onOpenCamera = {}, onRetry = {},
        )
    }

    private val day = CollageViewModel.UiState(date = LocalDate.of(2026, 5, 26), groupName = "Sunday dinners")

    @Test fun collageLoading() = collage("loading", day)
    @Test fun collageOnePage() = collage("ready", day.copy(content = CollageViewModel.Content.Ready(listOf(pageFile(1)), shareable = true)))
    @Test fun collageTwoPages() = collage("ready-pages", day.copy(content = CollageViewModel.Content.Ready(listOf(pageFile(1), pageFile(2)), shareable = true)))
    @Test fun collageNotShareable() = collage("ready-no-share", day.copy(content = CollageViewModel.Content.Ready(listOf(pageFile(1)), shareable = false)))
    @Test fun collageEmpty() = collage("empty", day.copy(content = CollageViewModel.Content.Empty))
    @Test fun collageError() = collage("error", day.copy(content = CollageViewModel.Content.Error))
    @Test fun collageOffline() = collage("offline", day.copy(content = CollageViewModel.Content.Offline))

    // ---- widget.android configure activity ------------------------------------------------------

    @Test fun widgetPickerLoading() = snap("widget.android_configure-loading") { WidgetPickerScreen(WidgetPickerState.Loading) {} }
    @Test fun widgetPickerGroups() = snap("widget.android_configure-groups") { WidgetPickerScreen(WidgetPickerState.Groups(groups)) {} }
    @Test fun widgetPickerEmpty() = snap("widget.android_configure-empty") { WidgetPickerScreen(WidgetPickerState.Empty) {} }
}

private const val SETTLE_MS = 1_000L
private const val RECORDING_STARTED = 1_000_000L

/** An option-B page (test fixture): 3 × 4 dual tiles of sample photos (back scene + selfie inset) on the matte, 9:16. */
object CollagePage {
    fun render(width: Int, seed: Int): android.graphics.Bitmap {
        val height = width * 16 / 9
        val bitmap = android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.ARGB_8888)
        val c = android.graphics.Canvas(bitmap)
        c.drawColor(0xFF000000.toInt())
        val tileW = width / 3f
        val tileH = tileW * 4 / 3
        val count = if (seed == 1) 12 else 5
        for (i in 0 until count) {
            val x = (i % 3) * tileW
            val y = (i / 3) * tileH
            val main = Images.photo(tileW.toInt(), tileH.toInt(), i + seed)
            c.drawBitmap(main, x, y, null)
            val insetW = (tileW * 0.31f).toInt()
            val inset = SamplePhotos.bitmap(SamplePhotos.avatar(i + seed), insetW, insetW * 4 / 3)
            val m = tileW * 0.03f
            c.drawBitmap(inset, x + m, y + m, null)
        }
        return bitmap
    }
}

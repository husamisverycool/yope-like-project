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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.MediaKind
import app.designsystem.LocalReduceMotionOverride
import app.designsystem.generated.Tokens
import app.feature.capture.camera.CameraScreen
import app.feature.capture.camera.CameraViewModel
import app.feature.capture.collage.CollageScreen
import app.feature.capture.collage.CollageViewModel
import app.feature.capture.daily.DailyCaptureScreen
import app.feature.capture.daily.DailyCaptureViewModel
import app.feature.capture.data.CapturedMedia
import app.feature.capture.sendto.SendToChrome
import app.feature.capture.sendto.SendToScreen
import app.feature.capture.sendto.SendToViewModel
import app.feature.capture.sendto.VoiceLive
import app.feature.capture.sendto.VoiceNoteFile
import app.feature.capture.sendto.VoicePhase
import app.feature.capture.sendto.VoicePlay
import app.ui.media.DualImage
import app.feature.capture.widget.WidgetPickerScreen
import app.feature.capture.widget.WidgetPickerState
import app.media.DualCaptureMode
import app.model.CountdownState
import app.testing.SamplePhotos
import app.ui.theme.AppTheme
import com.github.takahirom.roborazzi.captureScreenRoboImage
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.time.Duration
import java.time.LocalDate
import java.util.TimeZone

/**
 * One snapshot per screen per state (docs/SCREENS_BRIEF.md rule 7) in light, and the primary state of every surface
 * also in dark (`-dark`), on a 393 × 852 dp screen at 3×, Reduce Motion off, real sample photos (fixtures/photos).
 * The capture surfaces are media surfaces (black in both appearances, RC-1): their light and dark renders differ
 * only where a sheet, an alert or the configure page follows the appearance. The whole window is captured, so
 * native sheets and alerts are in the image.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xxhdpi")
class ScreenSnapshotTest {
    @get:Rule val compose = createComposeRule()
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val dir = File(context.cacheDir, "snap").apply { mkdirs() }

    @Before fun setUp() {
        TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
    }

    /**
     * The frame clock is paused (infinite platform spinners never go idle) and advanced past the longest settle of
     * these screens before the capture.
     */
    private fun snap(name: String, dark: Boolean = false, content: @Composable () -> Unit) {
        compose.mainClock.autoAdvance = false
        compose.setContent { CompositionLocalProvider(LocalReduceMotionOverride provides false) { AppTheme(dark = dark) { content() } } }
        compose.mainClock.advanceTimeBy(SETTLE_MS)
        captureScreenRoboImage("src/test/snapshots/$name${if (dark) "-dark" else ""}.png")
    }

    private val photo get() = Images.photo(900, 1200, 0).asImageBitmap()
    private val front get() = Images.selfie(300, 400).asImageBitmap()

    // ---- camera.trim ------------------------------------------------------------------------

    /** A 42-second library video on the trimmer (a sample photo stands in for the video frame), the range moved to 0:12. */
    private fun trim(name: String, dark: Boolean = false, busy: Boolean = false, failed: Boolean = false) = snap("camera.trim_$name", dark) {
        val range = androidx.compose.runtime.remember { app.feature.capture.camera.TrimRange(42_000L, 12_000L, 22_000L) }
        app.feature.capture.camera.VideoTrimContent(
            range = range, aspect = 3f / 4f, playing = true, busy = busy, failedToLoad = failed,
            onTogglePlay = {}, onRangeChanged = { _, _ -> }, onRetry = {}, onCancel = {}, onDone = {},
            video = { m -> Image(photo, null, contentScale = ContentScale.Crop, modifier = m) },
        )
    }

    @Test fun trimRange() = trim("range")
    @Test fun trimRangeDark() = trim("range", dark = true)
    @Test fun trimBusy() = trim("busy", busy = true)
    @Test fun trimLoadError() = trim("error", failed = true)

    // ---- camera.capture ---------------------------------------------------------------------

    private fun camera(name: String, state: CameraViewModel.UiState, live: Boolean = true, dark: Boolean = false) = snap("camera.capture_$name", dark) {
        CameraScreen(
            state = state,
            viewfinder = { if (live) Image(photo, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize()) },
            title = "Week 42",
            onShutterTap = {}, onShutterLongPress = {}, onShutterRelease = {}, onFlash = {}, onFlip = {}, onLibrary = {},
            onCoachClose = {}, onOpenSettings = {}, onRetry = {},
            // camera.overnight's mode control (Now selected): `{time}` as the en-US platform formats 09:00.
            overnight = app.feature.capture.camera.OvernightChrome(time = "9:00 AM"),
        )
    }

    private val live = CameraViewModel.UiState(permission = CameraViewModel.Permission.Granted, session = CameraViewModel.Session.Live, hasFlash = true, coachDone = true)

    @Test fun cameraLoading() = camera("loading", live.copy(session = CameraViewModel.Session.Starting), live = false)
    @Test fun cameraLive() = camera("live", live)
    @Test fun cameraLiveDark() = camera("live", live, dark = true)
    @Test fun cameraLiveFlashOn() = camera("live-flash-on", live.copy(flashOn = true))
    @Test fun cameraCoach() = camera("coach", live.copy(videoAvailable = true, coachDone = false))
    @Test fun cameraRecording() = camera("recording", live.copy(videoAvailable = true, recording = true))
    @Test fun cameraNoFlashUnit() = camera("no-flash", live.copy(hasFlash = false))
    @Test fun cameraPermissionDenied() = camera("denied", live.copy(permission = CameraViewModel.Permission.Denied, hasFlash = false), live = false)
    @Test fun cameraUnavailable() = camera("unavailable", live.copy(session = CameraViewModel.Session.Unavailable), live = false)

    // ---- camera.sendto ------------------------------------------------------------------------

    private val media = CapturedMedia(MediaKind.Photo, File(dir, "x.jpg"), 900, 1200, null, false)
    private val groups = listOf(group("g1", "Sunday dinners"), group("g2", "Roommates"), group("g3", "Family"))
    /** Group covers (the third group has none: the group glyph). */
    private val covers = mapOf("g1" to SamplePhotos.painter("dinner-long-table-3x4", 1, 1), "g2" to SamplePhotos.painter("movie-night-couch-4x3", 1, 1))
    private val loaded = SendToViewModel.UiState(media = media, groups = SendToViewModel.Groups.Loaded(groups), selected = setOf("g1", "g2"), micAvailable = true)

    private fun sendTo(name: String, state: SendToViewModel.UiState, dark: Boolean = false, sheet: Boolean = false, live: VoiceLive = VoiceLive()) = snap("camera.sendto_$name", dark) {
        SendToScreen(
            state = state,
            chrome = SendToChrome(preview = photo, covers = covers),
            onClose = {}, onSave = {}, onCaption = {}, onToggle = {}, onSend = {},
            onCreateGroup = {}, onRetryGroups = {}, onConfirmDiscard = {}, onDismissAlert = {}, onRetrySend = {},
            now = { RECORDING_STARTED + 7_000 },
            voiceLive = live,
            messageSheetOpen = sheet,
        )
    }

    @Test fun sendToLoading() = sendTo("loading", loaded.copy(groups = SendToViewModel.Groups.Loading, selected = emptySet()))
    @Test fun sendToLoaded() = sendTo("loaded", loaded)
    @Test fun sendToLoadedDark() = sendTo("loaded", loaded, dark = true)
    @Test fun sendToMessageAdded() = sendTo("message", loaded.copy(caption = "Sunday dinner at the Limas"))
    @Test fun sendToMessageSheet() = sendTo("message-sheet", loaded.copy(caption = "Sunday dinner at the Limas"), sheet = true)
    @Test fun sendToMessageSheetDark() = sendTo("message-sheet", loaded.copy(caption = "Sunday dinner at the Limas"), dark = true, sheet = true)
    @Test fun sendToNothingSelected() = sendTo("nothing-selected", loaded.copy(selected = emptySet()))
    @Test fun sendToEmpty() = sendTo("empty", loaded.copy(groups = SendToViewModel.Groups.Empty, selected = emptySet()))
    @Test fun sendToGroupsOffline() = sendTo("groups-offline", loaded.copy(groups = SendToViewModel.Groups.Failed(offline = true), selected = emptySet()))
    @Test fun sendToSending() = sendTo("sending", loaded.copy(sending = true))
    @Test fun sendToSendFailed() = sendTo("error", loaded.copy(alert = SendToViewModel.Alert.SendFailed(offline = false)))
    @Test fun sendToSendOffline() = sendTo("offline", loaded.copy(alert = SendToViewModel.Alert.SendFailed(offline = true)))
    @Test fun sendToDiscard() = sendTo("discard", loaded.copy(caption = "Sunday dinner", alert = SendToViewModel.Alert.Discard))
    @Test fun sendToVideoFreeMember() = sendTo("video-free", loaded.copy(media = media.copy(kind = MediaKind.Video, durationMs = 3000), premium = false))
    // Voice note (`camera.sendto.layout.messageField` `.recording` / `.note`, chat.voice, C-36), iOS CaptureSnapshotTests' states.
    private val recordingLive = VoiceLive(elapsedMs = 7_000, levels = VOICE_LEVELS)
    private val note = VoiceNoteFile(File(dir, "v.m4a"), 7_000, VOICE_LEVELS)
    private val attached = loaded.copy(voice = note)

    @Test fun sendToVoiceRecording() = sendTo("voice-recording", loaded.copy(voicePhase = VoicePhase.Holding), live = recordingLive)
    @Test fun sendToVoiceLocked() = sendTo("voice-locked", loaded.copy(voicePhase = VoicePhase.Locked), live = recordingLive)
    @Test fun sendToVoicePaused() = sendTo("voice-paused", loaded.copy(voicePhase = VoicePhase.Paused), live = recordingLive)
    @Test fun sendToVoicePausedPreview() = sendTo(
        "voice-paused-preview",
        loaded.copy(voicePhase = VoicePhase.Paused),
        live = recordingLive.copy(play = VoicePlay(File(dir, "draft.m4a"), isPlaying = true, progress = 0.45f)),
    )
    @Test fun sendToVoiceAttached() = sendTo("voice-attached", attached)
    @Test fun sendToVoiceAttachedDark() = sendTo("voice-attached", attached, dark = true)
    @Test fun sendToVoiceAttachedPlaying() = sendTo("voice-attached-playing", attached, live = VoiceLive(play = VoicePlay(note.file, isPlaying = true, progress = 0.45f)))

    // ---- daily.capture / daily.dualimage --------------------------------------------------------

    private val open = CountdownState.Open(T0.plusSeconds(97), Duration.ofSeconds(97))
    private val dailyLive = DailyCaptureViewModel.UiState(
        permission = DailyCaptureViewModel.Permission.Granted,
        session = DailyCaptureViewModel.Session.Live,
        countdown = open,
        groupName = "Sunday dinners",
        myName = "Ana",
        hasFlash = true,
        mode = DualCaptureMode.Concurrent,
    )

    private fun daily(name: String, state: DailyCaptureViewModel.UiState, main: Boolean = false, inset: Boolean = false, live: Boolean = true, dark: Boolean = false) =
        snap("daily.capture_$name", dark) {
            DailyCaptureScreen(
                state = state,
                viewfinder = { if (live) Image(photo, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize()) },
                mainImage = if (main) BitmapPainter(photo) else null,
                insetImage = if (inset) BitmapPainter(front) else null,
                onDismiss = {}, onFlash = {}, onFlip = {}, onShutter = {}, onRetake = {}, onSend = {}, onRetrySend = {}, onDismissSendError = {},
                onOpenSettings = {}, onRetry = {},
            )
        }

    private val preview = dailyLive.copy(phase = DailyCaptureViewModel.Phase.Preview)

    @Test fun dailyLoading() = daily("loading", dailyLive.copy(session = DailyCaptureViewModel.Session.Starting), live = false)
    @Test fun dailyLiveWindowOpen() = daily("live", dailyLive)
    @Test fun dailyLiveWindowOpenDark() = daily("live", dailyLive, dark = true)
    @Test fun dailyLiveWindowClosed() = daily("live-closed", dailyLive.copy(countdown = null))
    @Test fun dailyCapturing() = daily("capturing", dailyLive.copy(phase = DailyCaptureViewModel.Phase.Capturing), live = false)
    @Test fun dailyPreview() = daily("preview", preview, main = true, inset = true)
    @Test fun dailyPreviewSingleCamera() = daily("preview-single", preview, main = true)
    @Test fun dailySending() = daily("sending", preview.copy(sending = true), main = true, inset = true)
    @Test fun dailySendOffline() = daily("send-offline", preview.copy(sendFailedOffline = true), main = true, inset = true)
    @Test fun dailyDenied() = daily("denied", dailyLive.copy(permission = DailyCaptureViewModel.Permission.Denied, hasFlash = false), live = false)
    @Test fun dailyUnavailable() = daily("unavailable", dailyLive.copy(session = DailyCaptureViewModel.Session.Unavailable), live = false)

    private fun dual(name: String, dark: Boolean = false, loaded: Boolean = true) = snap("daily.dualimage_$name", dark) {
        Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep), contentAlignment = Alignment.Center) {
            DualImage(
                if (loaded) BitmapPainter(photo) else null,
                if (loaded) BitmapPainter(front) else null,
                "Back and front photos from Ana",
                Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin),
                cornerRadius = Tokens.Radii.globalViewfinder,
            )
        }
    }

    @Test fun dualImage() = dual("component")
    @Test fun dualImageDark() = dual("component", dark = true)
    @Test fun dualImageLoading() = dual("loading", loaded = false)

    // ---- collage.view / collage.share ------------------------------------------------------------

    private fun pageFile(n: Int): File = File(dir, "page-$n.jpg").also { f ->
        if (!f.isFile) f.outputStream().use { CollagePage.render(1080, n).compress(android.graphics.Bitmap.CompressFormat.JPEG, 92, it) }
    }

    private fun collage(name: String, state: CollageViewModel.UiState, dark: Boolean = false) = snap("collage.view_$name", dark) {
        CollageScreen(
            state = state,
            pageImage = { f -> f?.let { BitmapPainter(android.graphics.BitmapFactory.decodeFile(it.path).asImageBitmap()) } },
            onBack = {}, onPage = {}, onShare = {}, onOpenCamera = {}, onRetry = {},
        )
    }

    /** The collage's first photo (post_ids[0]): a real sample photo, the backdrop (L-7). */
    private val firstPhoto: File get() = File(dir, "first.jpg").also { f -> if (!f.isFile) SamplePhotos.writeJpeg(f, "dinner-pizza-cheers-3x4", 900, 1200) }
    private val day = CollageViewModel.UiState(date = LocalDate.of(2026, 5, 26), groupName = "Sunday dinners")
    private val ready get() = day.copy(content = CollageViewModel.Content.Ready(listOf(pageFile(1), pageFile(2)), shareable = true), backdrop = firstPhoto)

    @Test fun collageLoading() = collage("loading", day)
    @Test fun collageOnePage() = collage("ready", day.copy(content = CollageViewModel.Content.Ready(listOf(pageFile(1)), shareable = true), backdrop = firstPhoto))
    /** Before the first photo has loaded, page 1's image stands in behind the card. */
    @Test fun collageBackdropLoading() = collage("ready-backdrop-loading", day.copy(content = CollageViewModel.Content.Ready(listOf(pageFile(1)), shareable = true)))
    @Test fun collageTwoPages() = collage("ready-pages", ready)
    @Test fun collageTwoPagesDark() = collage("ready-pages", ready, dark = true)
    @Test fun collageSharing() = snap("collage.share_downloading") {
        CollageScreen(
            state = ready.copy(sharing = true),
            pageImage = { f -> f?.let { BitmapPainter(android.graphics.BitmapFactory.decodeFile(it.path).asImageBitmap()) } },
            onBack = {}, onPage = {}, onShare = {}, onOpenCamera = {}, onRetry = {},
        )
    }
    @Test fun collageNotShareable() = collage("ready-no-share", day.copy(content = CollageViewModel.Content.Ready(listOf(pageFile(1)), shareable = false), backdrop = firstPhoto))
    @Test fun collageEmpty() = collage("empty", day.copy(content = CollageViewModel.Content.Empty))
    @Test fun collageError() = collage("error", day.copy(content = CollageViewModel.Content.Error))
    @Test fun collageOffline() = collage("offline", day.copy(content = CollageViewModel.Content.Offline))

    // ---- widget.android configure activity ------------------------------------------------------

    private val pickerCovers = mapOf("g1" to SamplePhotos.painter("dinner-long-table-3x4", 1, 1), "g2" to SamplePhotos.painter("movie-night-couch-4x3", 1, 1))

    @Test fun widgetPickerLoading() = snap("widget.android_configure-loading") { WidgetPickerScreen(WidgetPickerState.Loading) {} }
    @Test fun widgetPickerGroups() = snap("widget.android_configure-groups") { WidgetPickerScreen(WidgetPickerState.Groups(groups), pickerCovers) {} }
    @Test fun widgetPickerGroupsDark() = snap("widget.android_configure-groups", dark = true) { WidgetPickerScreen(WidgetPickerState.Groups(groups), pickerCovers) {} }
    @Test fun widgetPickerEmpty() = snap("widget.android_configure-empty") { WidgetPickerScreen(WidgetPickerState.Empty) {} }
    @Test fun widgetPickerError() = snap("widget.android_configure-error") { WidgetPickerScreen(WidgetPickerState.Error) {} }
}

private const val SETTLE_MS = 1_000L
private const val RECORDING_STARTED = 1_000_000L

/** A spoken-like note: 100 levels of 0…31 (syllable peaks under a phrase envelope), as stored (C-36). */
private val VOICE_LEVELS: List<Int> = List(100) { i ->
    val phrase = kotlin.math.sin(Math.PI * (i % 50) / 50)
    val syllable = 0.55 + 0.45 * kotlin.math.abs(kotlin.math.sin(i * 0.9))
    (31 * phrase * syllable).toInt().coerceIn(0, 31)
}

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

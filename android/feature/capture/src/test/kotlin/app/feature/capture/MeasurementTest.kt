package app.feature.capture

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.unit.Density
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.MediaKind
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
import app.media.DualCaptureMode
import app.model.CountdownState
import app.ui.theme.AppTheme
import org.json.JSONObject
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import java.io.File
import java.time.Duration
import java.time.LocalDate

/**
 * Reads the laid-out bounds of every measured element (dp, screen top-left origin, 393 × 852 dp)
 * into `build/verification/<surface>.json`, the "what our screen shows" column of
 * design/verification/<surface>.md (tools: feature/capture/verification/checklists.py).
 */
@RunWith(AndroidJUnit4::class)
@Config(qualifiers = "w393dp-h852dp-xxhdpi")
class MeasurementTest {
    @get:Rule val compose = createComposeRule()

    private fun measure(surface: String, tags: List<String>, content: @Composable () -> Unit) {
        compose.mainClock.autoAdvance = false // platform spinners never go idle
        compose.setContent { AppTheme { content() } }
        compose.mainClock.advanceTimeBy(SETTLE_MS)
        val density = Density(compose.density.density, compose.density.fontScale)
        val out = JSONObject()
        for (tag in tags) {
            val nodes = compose.onAllNodes(hasTestTag(tag), useUnmergedTree = true).fetchSemanticsNodes()
            val node = nodes.firstOrNull() ?: continue
            val r: Rect = node.boundsInRoot
            fun dp(px: Float) = Math.round(px / density.density * 100) / 100.0
            out.put(tag, JSONObject().put("left", dp(r.left)).put("top", dp(r.top)).put("right", dp(r.right)).put("bottom", dp(r.bottom)).put("width", dp(r.width)).put("height", dp(r.height)))
        }
        val file = File("build/verification/$surface.json")
        file.parentFile.mkdirs()
        file.writeText(out.toString(2))
    }

    private val photo get() = Images.photo(900, 1240, 0).asImageBitmap()

    private companion object {
        const val SETTLE_MS = 1_000L
    }

    @Test fun camera() = measure(
        "camera.capture",
        listOf("camera.viewfinder", "camera.shutter", "camera.library", "camera.flip", "camera.flash", "camera.coach"),
    ) {
        CameraScreen(
            state = CameraViewModel.UiState(permission = CameraViewModel.Permission.Granted, session = CameraViewModel.Session.Live, hasFlash = true, videoAvailable = true),
            viewfinder = { Image(photo, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize()) },
            hourText = "5:00 PM",
            onShutterTap = {}, onShutterLongPress = {}, onShutterRelease = {}, onFlash = {}, onFlip = {}, onLibrary = {},
            onCoachClose = {}, onOpenSettings = {}, onRetry = {},
        )
    }

    @Test fun sendTo() = measure(
        "camera.sendto",
        listOf("sendto.close", "sendto.save", "sendto.title", "sendto.preview", "sendto.field", "sendto.mic", "sendto.row.g1", "sendto.row.g2", "sendto.avatar.g1", "sendto.name.g1", "sendto.check.g1", "sendto.send", "sendto.count", "sendto.toast"),
    ) {
        SendToScreen(
            state = SendToViewModel.UiState(
                media = CapturedMedia(MediaKind.Photo, File("x.jpg"), 900, 1240, null, false),
                groups = SendToViewModel.Groups.Loaded(listOf(group("g1", "Sunday dinners"), group("g2", "Roommates"))),
                selected = setOf("g1", "g2"),
                micAvailable = true,
                sendError = app.data.error.DataError.Network,
            ),
            chrome = SendToChrome(preview = photo, hourText = "5:00 PM"),
            onClose = {}, onSave = {}, onCaption = {}, onMic = {}, onVoiceCoachClose = {}, onToggle = {}, onSend = {}, onCreateGroup = {}, onRetryGroups = {},
        )
    }

    private val daily = DailyCaptureViewModel.UiState(
        permission = DailyCaptureViewModel.Permission.Granted,
        session = DailyCaptureViewModel.Session.Live,
        countdown = CountdownState.Open(T0, Duration.ofSeconds(97)),
        groupName = "Sunday dinners",
        hasFlash = true,
        mode = DualCaptureMode.Concurrent,
    )

    @Test fun dailyLive() = measure("daily.capture.live", listOf("daily.dismiss", "daily.countdown", "daily.viewfinder", "daily.shutter", "daily.flash", "daily.flip")) {
        DailyCaptureScreen(daily, { Image(photo, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize()) }, null, null, "Ana", {}, {}, {}, {}, {}, {}, {}, {})
    }

    @Test fun dailyPreview() = measure("daily.capture.preview", listOf("daily.dualimage", "daily.retake", "daily.chip", "daily.send")) {
        DailyCaptureScreen(daily.copy(phase = DailyCaptureViewModel.Phase.Preview), {}, photo, Images.photo(300, 400, 2).asImageBitmap(), "Ana", {}, {}, {}, {}, {}, {}, {}, {})
    }

    @Test fun collage() = measure("collage.view", listOf("collage.back", "collage.title", "collage.dots", "collage.pager", "collage.share")) {
        val dir = File("build/tmp/collage-measure").apply { mkdirs() }
        val pages = (1..2).map { n -> File(dir, "p$n.jpg").also { f -> f.outputStream().use { CollagePage.render(540, n).compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, it) } } }
        CollageScreen(
            state = CollageViewModel.UiState(content = CollageViewModel.Content.Ready(pages, shareable = true), date = LocalDate.of(2026, 5, 26), groupName = "Sunday dinners"),
            pageImage = { f -> f?.let { android.graphics.BitmapFactory.decodeFile(it.path).asImageBitmap() } },
            onBack = {}, onPage = {}, onShare = {}, onOpenCamera = {}, onRetry = {},
        )
    }

    @Test fun collageHud() = measure("collage.view.hud", listOf("collage.hud")) {
        CollageScreen(CollageViewModel.UiState(), { null }, {}, {}, {}, {}, {})
    }
}

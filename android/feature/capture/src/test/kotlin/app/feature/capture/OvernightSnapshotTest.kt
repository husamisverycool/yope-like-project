package app.feature.capture

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.designsystem.LocalReduceMotionOverride
import app.feature.capture.camera.CameraScreen
import app.feature.capture.camera.CameraViewModel
import app.feature.capture.camera.CaptureMode
import app.feature.capture.camera.OvernightChrome
import app.feature.capture.sendto.SendToViewModel
import app.testing.SamplePhotos
import app.ui.format.Formats
import app.ui.theme.AppTheme
import com.github.takahirom.roborazzi.captureScreenRoboImage
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Instant
import java.time.ZoneOffset
import java.util.Locale
import java.util.TimeZone

/**
 * camera.overnight part A per state, as ScreenSnapshotTest draws the capture surfaces (393 × 852 dp at 3×, the whole window
 * so the native sheet is in the image): the camera in 9 AM mode with the destination pill (all / one / some groups, a long
 * name truncated), the destination sheet in both appearances, and its no-groups state. `{time}` and `{reveal}` are the
 * en-US platform output for 09:00 and the next morning (the day inside the sentence: "tomorrow, 9:00 AM").
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xxhdpi")
class OvernightSnapshotTest {
    @get:Rule val compose = createComposeRule()

    @Before fun setUp() {
        TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
    }

    private fun snap(name: String, dark: Boolean = false, content: @Composable () -> Unit) {
        compose.mainClock.autoAdvance = false
        compose.setContent { CompositionLocalProvider(LocalReduceMotionOverride provides false) { AppTheme(dark = dark) { content() } } }
        compose.mainClock.advanceTimeBy(SETTLE_MS)
        captureScreenRoboImage("src/test/snapshots/camera.overnight_$name${if (dark) "-dark" else ""}.png")
    }

    private val photo get() = Images.photo(900, 1200, 0).asImageBitmap()
    private val groups = listOf(group("g1", "Sunday dinners"), group("g2", "Roommates"), group("g3", "Family"))
    private val covers = mapOf("g1" to SamplePhotos.painter("dinner-long-table-3x4", 1, 1), "g2" to SamplePhotos.painter("movie-night-couch-4x3", 1, 1))
    private val reveal = Formats.dayAndTimeInSentence(
        Instant.parse("2026-10-16T09:00:00Z"), "9:00 AM", ZoneOffset.UTC, Instant.parse("2026-10-15T20:00:00Z"), Locale.US,
    )
    private val chrome = OvernightChrome(time = "9:00 AM", reveal = reveal, covers = covers)

    private val nineAm = CameraViewModel.UiState(
        permission = CameraViewModel.Permission.Granted,
        session = CameraViewModel.Session.Live,
        hasFlash = true,
        coachDone = true,
        mode = CaptureMode.Later,
        groups = SendToViewModel.Groups.Loaded(groups),
        destinations = groups.map { it.id }.toSet(),
    )

    private fun camera(name: String, state: CameraViewModel.UiState, dark: Boolean = false) = snap(name, dark) {
        CameraScreen(
            state = state,
            viewfinder = { Image(photo, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize()) },
            title = "Week 42",
            onShutterTap = {}, onShutterLongPress = {}, onShutterRelease = {}, onFlash = {}, onFlip = {}, onLibrary = {},
            onCoachClose = {}, onOpenSettings = {}, onRetry = {},
            overnight = chrome,
        )
    }

    /** 9 AM mode, every group: the control on "9:00 AM", the pill "All groups", the library slot empty, no coach. */
    @Test fun nineAm() = camera("nine-am", nineAm.copy(videoAvailable = true, coachDone = false))

    @Test fun nineAmDark() = camera("nine-am", nineAm, dark = true)

    /** One group chosen: the pill names it. */
    @Test fun nineAmOneGroup() = camera("nine-am-one", nineAm.copy(destinations = setOf("g2")))

    /** Some groups: "Selected groups" (no number). */
    @Test fun nineAmSomeGroups() = camera("nine-am-some", nineAm.copy(destinations = setOf("g1", "g3")))

    /** A long group name truncates at the end inside the viewfinder width less the margins. */
    @Test fun nineAmLongName() = camera(
        "nine-am-long-name",
        nineAm.copy(groups = SendToViewModel.Groups.Loaded(listOf(group("g9", "The whole Lima-Okafor family and the cousins from Porto"))), destinations = setOf("g9")),
    )

    /** Camera permission denied in 9 AM mode: the mode control stays. */
    @Test fun nineAmDenied() = camera("nine-am-denied", nineAm.copy(permission = CameraViewModel.Permission.Denied, hasFlash = false))

    /** The destination sheet (follows the appearance): title, Done, the explanation, camera.sendto's group rows. */
    @Test fun destinationSheet() = camera("destination-sheet", nineAm.copy(destinations = setOf("g1", "g3"), destinationSheet = true))

    @Test fun destinationSheetDark() = camera("destination-sheet", nineAm.copy(destinations = setOf("g1", "g3"), destinationSheet = true), dark = true)

    /** No groups: camera.sendto's empty state inside the sheet. */
    @Test fun destinationSheetEmpty() = camera("destination-empty", nineAm.copy(groups = SendToViewModel.Groups.Empty, destinations = emptySet(), destinationSheet = true))
}

private const val SETTLE_MS = 1_000L

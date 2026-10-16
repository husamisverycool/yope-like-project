package app.feature.social

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import app.data.model.SelfieReaction
import app.data.repo.ReactionEntry
import app.feature.social.FakeSocialData.Companion.ANA
import app.feature.social.FakeSocialData.Companion.BASE
import app.feature.social.FakeSocialData.Companion.BEN
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.FakeSocialData.Companion.ME
import app.feature.social.chat.VoiceUi
import app.feature.social.viewer.PhotoViewerContent
import app.feature.social.viewer.PhotoViewerViewModel
import app.feature.social.viewer.SelfieCameraPhase
import app.feature.social.viewer.SelfieCameras
import app.feature.social.viewer.SelfieCaptureLayer
import app.feature.social.viewer.SelfieMode
import app.feature.social.viewer.ViewerNav
import app.feature.social.viewer.ViewerState
import app.feature.social.viewer.ViewerUiState
import app.model.PhotoContext
import app.testing.SamplePhotos
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import org.junit.After
import org.junit.Before
import org.junit.Test
import java.time.Instant

/**
 * viewer.selfiereaction per state: the faces on the photo, the capture layer (hold, armed, tap mode, camera starting,
 * permission denied), the Reactions sheet with selfie rows among emoji rows, the row menu and the remove confirmation.
 * The live front camera is a sample selfie (fixtures/photos).
 */
class SelfieSnapshotTest : SnapshotBase() {
    private val nav = ViewerNav({}, { _, _ -> }, { _, _ -> }, { _, _ -> }, {})

    @Before fun frontCamera() {
        SelfieCameras.hasFrontCamera = { true }
    }

    @After fun resetCamera() {
        SelfieCameras.hasFrontCamera = { it.packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_CAMERA_FRONT) }
    }

    private fun selfie(user: String, post: String, at: Instant) = SelfieReaction(id = "s-$user-$post", postId = post, userId = user, groupId = GROUP, imagePath = "u/$user/selfies/$user-$post.jpg", createdAt = at)

    /** viewerData() plus selfies: four people on Ana's photo (the stack shows three), two on mine. */
    private fun data() = viewerData().apply {
        profiles["u-x0"] = FakeSocialData.profile("u-x0", "Chloe Martin")
        profiles["u-x1"] = FakeSocialData.profile("u-x1", "Dev Patel")
        selfies["v-1"] = mutableListOf(
            selfie("u-x1", "v-1", BASE.minusSeconds(86_000)),
            selfie(BEN, "v-1", BASE.minusSeconds(85_000)),
            selfie("u-x0", "v-1", BASE.minusSeconds(70_000)),
            selfie(ME, "v-1", BASE.minusSeconds(60_000)),
        )
        // Emoji rows with their times, so the sheet interleaves them with the selfies.
        reactions["v-1"] = mutableListOf(ReactionEntry(BEN, "🔥", BASE.minusSeconds(80_000)), ReactionEntry(ME, "💖", BASE.minusSeconds(50_000)))
        selfies["v-2"] = mutableListOf(selfie(ANA, "v-2", BASE.minusSeconds(4_000)), selfie(BEN, "v-2", BASE.minusSeconds(3_000)))
    }

    private fun state(postId: String, data: FakeSocialData): ViewerState = PhotoViewerViewModel(data, GROUP, postId, PhotoContext.Album, "a-v", null).state.value

    private fun viewer(postId: String, ui: ViewerUiState = ViewerUiState(), screen: Boolean = false, dark: Boolean = false, layer: (@androidx.compose.runtime.Composable (SelfieMode) -> Unit)? = null) {
        val d = data()
        snap(d, screen, dark) {
            PhotoViewerContent(state(postId, d), ui, nav, VoiceUi.Idle, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, selfieLayer = layer)
        }
    }

    private fun layer(phase: SelfieCameraPhase = SelfieCameraPhase.Live, armed: Boolean = false): @androidx.compose.runtime.Composable (SelfieMode) -> Unit = { mode ->
        SelfieCaptureLayer(
            mode = mode,
            phase = phase,
            armed = armed,
            preview = { Image(SamplePhotos.painter("selfie-two-friends-1x1", 1, 1), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop) },
            onCapture = {},
            onClose = {},
            onOpenSettings = {},
        )
    }

    /** Ana's photo: three faces at its bottom-leading corner (newest leading), no number for the fourth. */
    @Test fun stack() = viewer("v-1")

    @Test fun stackDark() = viewer("v-1", dark = true)

    /** Hold mode: the panel, the live circle, "Slide here to react", the target ring, "Slide in to send". */
    @Test fun layerHold() = viewer("v-1", ViewerUiState(selfieLayer = SelfieMode.Hold), layer = layer())

    /** The finger inside a target: the white ring inside the circle. */
    @Test fun layerArmed() = viewer("v-1", ViewerUiState(selfieLayer = SelfieMode.Hold), layer = layer(armed = true))

    /** Tap mode (context menu / TalkBack): "Tap the circle to send", the ring is a button, no second hint. */
    @Test fun layerTap() = viewer("v-1", ViewerUiState(selfieLayer = SelfieMode.Tap), layer = layer())

    /** Camera starting: the circle filled black with the platform activity indicator. */
    @Test fun layerStarting() = viewer("v-1", ViewerUiState(selfieLayer = SelfieMode.Tap), layer = layer(SelfieCameraPhase.Starting))

    /** Camera permission denied: the C-27 block where the circle is; no ring, no hints. */
    @Test fun layerDenied() = viewer("v-1", ViewerUiState(selfieLayer = SelfieMode.Tap), layer = layer(SelfieCameraPhase.Denied))

    /** Long press on someone else's photo: the menu gains "React with a selfie" under the quick-reaction row. */
    @Test fun contextMenu() {
        viewer("v-1", ViewerUiState(photoMenu = true), screen = true)
        compose.onNodeWithText("React with a selfie").assertExists()
    }

    /** The Reactions sheet on Ana's photo: selfie rows among the emoji rows, newest first; yours with the remove hint. */
    @Test fun reactionsSheet() {
        viewer("v-1", ViewerUiState(reactions = true), screen = true)
        compose.onNodeWithContentDescription("Your selfie").assertExists()
        compose.onNodeWithText("You reacted with a selfie", useUnmergedTree = true).assertExists()
    }

    /** My photo: a row's long-press menu offers Remove and Report Selfie. */
    @Test fun rowMenuOnMyPhoto() = viewer("v-2", ViewerUiState(reactions = true).apply { selfieMenu = BEN }, screen = true)

    /** Removing Ben's selfie from my photo asks first. */
    @Test fun removeConfirmation() = viewer("v-2", ViewerUiState(confirmRemoveSelfie = BEN), screen = true)
}

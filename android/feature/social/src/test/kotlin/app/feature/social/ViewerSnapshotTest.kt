package app.feature.social

import androidx.compose.ui.text.input.TextFieldValue
import app.data.model.AlbumItem
import app.data.model.MessageKind
import app.data.repo.ReactionEntry
import app.feature.social.FakeSocialData.Companion.ANA
import app.feature.social.FakeSocialData.Companion.BASE
import app.feature.social.FakeSocialData.Companion.BEN
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.FakeSocialData.Companion.ME
import app.feature.social.chat.VoiceUi
import app.feature.social.viewer.PhotoViewerContent
import app.feature.social.viewer.PhotoViewerViewModel
import app.feature.social.viewer.ViewerNav
import app.feature.social.viewer.ViewerPhoto
import app.feature.social.viewer.ViewerState
import app.feature.social.viewer.ViewerUiState
import app.model.PhotoContext
import org.junit.Test

/** photo.viewer per state (dark in both appearances — the primary state is also rendered with the system in dark). */
class ViewerSnapshotTest : SnapshotBase() {
    private val nav = ViewerNav({}, { _, _ -> }, { _, _ -> }, { _, _ -> }, {})

    private fun viewer(state: ViewerState, ui: ViewerUiState = ViewerUiState(), data: FakeSocialData = viewerData(), screen: Boolean = false, approximations: Boolean = true, dark: Boolean = false) =
        snap(data, approximations, screen, dark) {
            PhotoViewerContent(state, ui, nav, VoiceUi.Idle, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {})
        }

    /** The album the viewer is opened from (three photos: the pill reads "1 of 3"). */
    private fun state(postId: String, data: FakeSocialData) = PhotoViewerViewModel(data, GROUP, postId, PhotoContext.Album, "a-v", null).state.value

    /** Someone else's captioned photo: header, pill, caption, date · tag run, voice note, reactions, comments, field. */
    @Test fun othersPhoto() {
        val d = viewerData()
        viewer(state("v-1", d), data = d)
    }

    /** The same with the system in dark: the viewer is dark in both appearances (`photo.viewer.layout.appearance`). */
    @Test fun othersPhotoDark() {
        val d = viewerData()
        viewer(state("v-1", d), data = d, dark = true)
    }

    /** Nobody tagged: the run reads "I'm in this" in white. */
    @Test fun untagged() {
        val d = viewerData().apply { tagRows.clear() }
        viewer(state("v-1", d), data = d)
    }

    /** My photo, no caption, no comments: date line only; the divider and list are left out. */
    @Test fun myPhoto() {
        val d = viewerData()
        viewer(state("v-2", d), data = d)
    }

    @Test fun loading() = viewer(ViewerState(phase = ViewerState.Phase.Ready, me = ME, photos = listOf(ViewerPhoto("v-1"))))

    @Test fun errorLoad() = viewer(ViewerState(phase = ViewerState.Phase.Ready, me = ME, photos = listOf(ViewerPhoto("v-1", loadFailed = true))))

    @Test fun gone() = viewer(ViewerState(phase = ViewerState.Phase.Ready, me = ME, photos = listOf(ViewerPhoto("v-1", gone = true, loaded = true))))

    @Test fun permissionDeniedSave() {
        val d = viewerData()
        viewer(state("v-1", d), ViewerUiState(saveDenied = true), d, screen = true)
    }

    /** The field's "•••" menu on someone else's photo: Save to Camera Roll · Report Post · Block Ana. */
    @Test fun menuOthers() {
        val d = viewerData()
        viewer(state("v-1", d), ViewerUiState(menu = true), d, screen = true)
    }

    @Test fun menuMine() {
        val d = viewerData()
        viewer(state("v-2", d), ViewerUiState(menu = true), d, screen = true)
    }

    /** Long press on the photo: the quick-reaction row and the menu items. */
    @Test fun photoContextMenu() {
        val d = viewerData()
        viewer(state("v-1", d), ViewerUiState(photoMenu = true), d, screen = true)
    }

    @Test fun deleteConfirmation() {
        val d = viewerData()
        viewer(state("v-2", d), ViewerUiState(confirmDelete = true), d, screen = true)
    }

    @Test fun replyTyping() {
        val d = viewerData()
        viewer(state("v-1", d), ViewerUiState(draft = TextFieldValue("where is this")), d)
    }

    @Test fun reactionsSheet() {
        val d = viewerData()
        viewer(state("v-1", d), ViewerUiState(reactions = true), d, screen = true)
    }
}

/** Three photos in album a-v: Ana's captioned one with a voice note, reactions, tags and two comments; mine; Ben's. */
fun viewerData(): FakeSocialData = FakeSocialData().apply {
    seedGroup()
    addPhoto("v-1", ANA, BASE.minusSeconds(86_400 * 2), caption = "sunday sunsets", voicePath = "u/$ANA/md-v-1/voice.m4a", voiceMs = 21_000)
    addPhoto("v-2", ME, BASE.minusSeconds(86_400))
    addPhoto("v-3", BEN, BASE.minusSeconds(3_600))
    albumItems["a-v"] = mutableListOf(AlbumItem("a-v", "v-1", 0), AlbumItem("a-v", "v-2", 1), AlbumItem("a-v", "v-3", 2))
    reactions["v-1"] = mutableListOf(ReactionEntry(BEN, "🔥"), ReactionEntry(ME, "💖"))
    tagRows["v-1"] = mutableListOf(ANA, ME)
    messages += FakeSocialData.message("c-1", GROUP, BEN, MessageKind.Text, body = "whoa!", replyToPostId = "v-1", at = BASE.minusSeconds(86_000))
    messages += FakeSocialData.message("c-2", GROUP, ME, MessageKind.Text, body = "need to go back there", replyToPostId = "v-1", at = BASE.minusSeconds(80_000))
}

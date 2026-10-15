package app.feature.social

import app.data.repo.ReactionEntry
import app.feature.social.FakeSocialData.Companion.ANA
import app.feature.social.FakeSocialData.Companion.BASE
import app.feature.social.FakeSocialData.Companion.BEN
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.FakeSocialData.Companion.ME
import app.feature.social.data.VoicePlayback
import app.feature.social.viewer.PhotoViewerContent
import app.feature.social.viewer.PhotoViewerViewModel
import app.feature.social.viewer.ViewerNav
import app.feature.social.viewer.ViewerPhoto
import app.feature.social.viewer.ViewerState
import app.feature.social.viewer.ViewerUiState
import app.model.PhotoContext
import org.junit.Test

/** photo.viewer per state. */
class ViewerSnapshotTest : SnapshotBase() {
    private val nav = ViewerNav({}, { _, _ -> }, { _, _ -> }, { _, _ -> }, {})

    private fun data(): FakeSocialData = FakeSocialData().apply {
        seedGroup()
        addPhoto("v-1", ANA, BASE.minusSeconds(86_400 * 2), caption = "sunday sunsets", voicePath = "u/$ANA/md-v-1/voice.m4a", voiceMs = 21_000)
        addPhoto("v-2", ME, BASE.minusSeconds(86_400))
        reactions["v-1"] = mutableListOf(ReactionEntry(BEN, "🔥"), ReactionEntry(ME, "💖"))
        tags += "v-1"
    }

    private fun viewer(state: ViewerState, ui: ViewerUiState = ViewerUiState(coach = false), data: FakeSocialData = data(), screen: Boolean = false, approximations: Boolean = true) =
        snap(data, approximations, screen) {
            PhotoViewerContent(state, ui, nav, testVoice, VoicePlayback(null, false), {}, {}, {}, {}, {}, {}, {}, {}, {})
        }

    private fun state(postId: String, data: FakeSocialData) = PhotoViewerViewModel(data, GROUP, postId, PhotoContext.Single, postId, null).state.value

    /** Someone else's photo: sender overlay, "i'm in this" (on), caption, cluster, voice note, quick reactions. */
    @Test fun othersPhoto() {
        val d = data()
        viewer(state("v-1", d), data = d)
    }

    /** The "i'm in this" coach on first opening someone else's photo. */
    @Test fun othersPhotoCoach() {
        val d = data()
        d.tags.clear()
        viewer(state("v-1", d), ViewerUiState(coach = true), d)
    }

    @Test fun myPhoto() {
        val d = data()
        viewer(state("v-2", d), data = d)
    }

    @Test fun loading() = viewer(ViewerState(phase = ViewerState.Phase.Ready, me = ME, photos = listOf(ViewerPhoto("v-1"))))

    @Test fun errorLoad() = viewer(ViewerState(phase = ViewerState.Phase.Ready, me = ME, photos = listOf(ViewerPhoto("v-1", loadFailed = true))))

    @Test fun gone() = viewer(ViewerState(phase = ViewerState.Phase.Ready, me = ME, photos = listOf(ViewerPhoto("v-1", gone = true, loaded = true))))

    @Test fun permissionDeniedSave() {
        val d = data()
        viewer(state("v-1", d), ViewerUiState(saveDenied = true, coach = false), d)
    }

    @Test fun menuOthers() {
        val d = data()
        viewer(state("v-1", d), ViewerUiState(menu = true, coach = false), d, screen = true)
    }

    @Test fun menuMine() {
        val d = data()
        viewer(state("v-2", d), ViewerUiState(menu = true, coach = false), d, screen = true)
    }

    @Test fun deleteEverywhereConfirmation() {
        val d = data()
        viewer(state("v-2", d), ViewerUiState(confirmDelete = true, coach = false), d, screen = true)
    }

    @Test fun replyTyping() {
        val d = data()
        viewer(state("v-1", d).copy(draft = "where is this"), data = d)
    }
}

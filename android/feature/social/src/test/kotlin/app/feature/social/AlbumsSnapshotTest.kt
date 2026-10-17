package app.feature.social

import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.albums.AlbumUiState
import app.feature.social.albums.AlbumViewContent
import app.feature.social.albums.AlbumViewModel
import app.feature.social.albums.AlbumViewState
import app.feature.social.albums.AlbumsListContent
import app.feature.social.albums.AlbumsState
import app.feature.social.albums.AlbumsViewModel
import app.feature.social.albums.RenameSheetContent
import app.ui.system.SystemAlertDialog
import org.junit.Test

/** albums.list and albums.view per state; each primary state also in dark. */
class AlbumsSnapshotTest : SnapshotBase() {
    private fun list(state: AlbumsState, data: FakeSocialData = FakeSocialData(), dark: Boolean = false) =
        snap(data, dark = dark) { AlbumsListContent(state, {}, {}, {}, {}, {}) }

    private fun listState(): Pair<FakeSocialData, AlbumsState> {
        val data = FakeSocialData().apply { seedAlbums() }
        return data to AlbumsViewModel(data, GROUP).state.value
    }

    @Test fun listContent() {
        val (data, state) = listState()
        list(state, data)
    }

    @Test fun listContentDark() {
        val (data, state) = listState()
        list(state, data, dark = true)
    }

    @Test fun listLoading() = list(AlbumsState())
    @Test fun listEmpty() = list(AlbumsState(phase = AlbumsState.Phase.Ready))
    @Test fun listError() = list(AlbumsState(phase = AlbumsState.Phase.Error))

    @Test fun listNoResults() {
        val (data, state) = listState()
        list(state.copy(query = "zz"), data)
    }

    private fun view(state: AlbumViewState, data: FakeSocialData = FakeSocialData(), ui: AlbumUiState = AlbumUiState(), dark: Boolean = false) =
        snap(data, screen = true, dark = dark) { SheetOverPage { AlbumViewContent(state, ui, {}, {}, {}) } }

    /** "birthday dinner": seven photos (3 + 3 + 1 — the short last row rounds the row above's trailing corner). */
    private fun viewState(id: String = "a-2"): Pair<FakeSocialData, AlbumViewState> {
        val data = FakeSocialData().apply { seedAlbums() }
        return data to AlbumViewModel(data, GROUP, id).state.value
    }

    @Test fun viewContent() {
        val (data, state) = viewState()
        view(state, data)
    }

    @Test fun viewContentDark() {
        val (data, state) = viewState()
        view(state, data, dark = true)
    }

    /** An album with a video: its grid cell carries the video pill (`layout.global.videoMarker`). */
    @Test fun viewWithVideo() {
        val data = FakeSocialData().apply {
            seedAlbums()
            makeVideo("w-1", 8_000)
        }
        view(AlbumViewModel(data, GROUP, "a-2").state.value, data)
    }

    @Test fun viewLoading() = view(AlbumViewState())

    @Test fun viewEmpty() {
        val (data, state) = viewState()
        view(state.copy(photos = emptyList()), data)
    }

    @Test fun viewNotFound() = view(AlbumViewState(phase = AlbumViewState.Phase.NotFound))

    @Test fun viewError() {
        val (data, state) = viewState()
        view(state.copy(phase = AlbumViewState.Phase.Error, photos = emptyList()), data)
    }

    /** The "•••" capsule (creator / admin): Delete Album in red. */
    @Test fun viewMenu() {
        val (data, state) = viewState()
        view(state, data, AlbumUiState(menu = true))
    }

    @Test fun renameSheet() {
        val (data, state) = viewState()
        snap(data, screen = true) { SheetOverPage { RenameSheetContent(state.copy(renaming = true, renameName = state.album?.name.orEmpty()), {}, {}, {}) } }
    }

    @Test fun deleteConfirmation() {
        val (data, state) = viewState()
        snap(data, screen = true) {
            SheetOverPage { AlbumViewContent(state, AlbumUiState(), {}, {}, {}) }
            SystemAlertDialog(
                androidx.compose.ui.res.stringResource(app.designsystem.R.string.albums_view_delete_title),
                androidx.compose.ui.res.stringResource(app.designsystem.R.string.albums_view_delete_message),
                androidx.compose.ui.res.stringResource(app.designsystem.R.string.albums_view_delete_confirm),
                {},
                androidx.compose.ui.res.stringResource(app.designsystem.R.string.photo_viewer_delete_cancel),
                {},
                destructive = true,
            )
        }
    }
}

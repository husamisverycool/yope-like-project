package app.feature.social

import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.albums.AlbumViewContent
import app.feature.social.albums.AlbumViewModel
import app.feature.social.albums.AlbumViewState
import app.feature.social.albums.AlbumsListContent
import app.feature.social.albums.AlbumsState
import app.feature.social.albums.AlbumsViewModel
import app.feature.social.albums.RenameSheetContent
import app.feature.social.week.AlbumSheetContent
import app.feature.social.week.EditError
import app.feature.social.week.EditState
import app.feature.social.week.HistoryNav
import app.feature.social.week.HistoryState
import app.feature.social.week.HistoryViewModel
import app.feature.social.week.RecapNav
import app.feature.social.week.RecapState
import app.feature.social.week.RecapViewModel
import app.feature.social.week.WeekEditContent
import app.feature.social.week.WeekEditViewModel
import app.feature.social.week.WeekHistoryContent
import app.feature.social.week.WeekRecapContent
import org.junit.Test
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import java.time.LocalDate

/** A sheet's contents at the bottom of a phone-sized frame (the native sheet itself is the platform's). */
@androidx.compose.runtime.Composable
private fun SheetFrame(content: @androidx.compose.runtime.Composable () -> Unit) {
    androidx.compose.foundation.layout.Box(
        androidx.compose.ui.Modifier.fillMaxSize().background(app.designsystem.generated.Tokens.Colors.globalBackground),
        contentAlignment = androidx.compose.ui.Alignment.BottomCenter,
    ) { content() }
}

/** week.recap, week.edit, week.history, albums.list, albums.view per state. */
class WeekSnapshotTest : SnapshotBase() {
    private val recapNav = RecapNav({}, {}, { _, _ -> }, { _, _ -> }, {})
    private val historyNav = HistoryNav({}, { _, _ -> }, {}, {}, {})

    // ---- week.recap ----

    @Test fun recapReady() {
        val data = FakeSocialData().apply { seedWeek() }
        snap(data) { WeekRecapContent(RecapViewModel(data, GROUP, "r-w").state.value, recapNav, {}) }
    }

    @Test fun recapLoading() = snap { WeekRecapContent(RecapState(), recapNav, {}) }
    @Test fun recapPending() = snap { WeekRecapContent(RecapState(phase = RecapState.Phase.Pending), recapNav, {}) }
    @Test fun recapEmpty() = snap { WeekRecapContent(RecapState(phase = RecapState.Phase.Empty), recapNav, {}) }
    @Test fun recapError() = snap { WeekRecapContent(RecapState(phase = RecapState.Phase.Error), recapNav, {}) }
    @Test fun recapOffline() = snap { WeekRecapContent(RecapState(phase = RecapState.Phase.OfflineEmpty), recapNav, {}) }

    // ---- week.edit ----

    private fun editState(albumOnly: Boolean = false): Pair<FakeSocialData, EditState> {
        val data = FakeSocialData().apply { seedWeek() }
        val vm = if (albumOnly) WeekEditViewModel(data, GROUP, null, LocalDate.parse("2026-10-12"), true) else WeekEditViewModel(data, GROUP, "r-w", null, false)
        return data to vm.state.value
    }

    @Test fun editReady() {
        val (data, state) = editState()
        snap(data) { WeekEditContent(state, {}, {}, { _, _ -> }, {}, {}, {}) }
    }

    @Test fun editReadyRelease() {
        val (data, state) = editState()
        snap(data, approximations = false) { WeekEditContent(state, {}, {}, { _, _ -> }, {}, {}, {}) }
    }

    @Test fun editSaveFailed() {
        val (data, state) = editState()
        snap(data) { WeekEditContent(state.copy(error = EditError.Save), {}, {}, { _, _ -> }, {}, {}, {}) }
    }

    @Test fun editSaving() {
        val (data, state) = editState()
        snap(data) { WeekEditContent(state.copy(saving = true), {}, {}, { _, _ -> }, {}, {}, {}) }
    }

    @Test fun editLoading() = snap { WeekEditContent(EditState(), {}, {}, { _, _ -> }, {}, {}, {}) }

    @Test fun editNotReady() = snap { WeekEditContent(EditState(phase = EditState.Phase.NotReady, error = EditError.NotReady), {}, {}, { _, _ -> }, {}, {}, {}) }

    @Test fun editAlbumSheet() {
        val (data, state) = editState(albumOnly = true)
        snap(data) { SheetFrame { AlbumSheetContent(state.copy(albumName = "lake week"), {}, {}, {}) } }
    }

    @Test fun editAlbumSheetNameError() {
        val (data, state) = editState(albumOnly = true)
        snap(data) { SheetFrame { AlbumSheetContent(state.copy(albumName = " ", albumError = EditError.AlbumName), {}, {}, {}) } }
    }

    // ---- week.history ----

    @Test fun historyContent() {
        val data = FakeSocialData().apply { seedWeek() }
        val vm = HistoryViewModel(data, GROUP) { LocalDate.parse("2026-10-21") }
        snap(data) { WeekHistoryContent(vm.state.value, historyNav, {}, {}) }
    }

    @Test fun historyEmpty() {
        val data = FakeSocialData().apply { seedGroup() }
        val vm = HistoryViewModel(data, GROUP) { LocalDate.parse("2026-10-21") }
        snap(data) { WeekHistoryContent(vm.state.value, historyNav, {}, {}) }
    }

    @Test fun historyLoading() = snap { WeekHistoryContent(HistoryState(), historyNav, {}, {}) }

    @Test fun historyError() {
        val data = FakeSocialData().apply { seedGroup() }
        snap(data) { WeekHistoryContent(HistoryState(phase = HistoryState.Phase.Error, group = data.groups[GROUP]), historyNav, {}, {}) }
    }

    @Test fun historyOffline() {
        val data = FakeSocialData().apply { seedWeek() }
        val vm = HistoryViewModel(data, GROUP) { LocalDate.parse("2026-10-21") }
        snap(data) { WeekHistoryContent(vm.state.value.copy(offline = true), historyNav, {}, {}) }
    }

    // ---- albums.list ----

    @Test fun albumsListContent() {
        val data = FakeSocialData().apply { seedAlbums() }
        snap(data) { AlbumsListContent(AlbumsViewModel(data, GROUP).state.value, {}, {}, {}, {}) }
    }

    @Test fun albumsListEmpty() = snap { AlbumsListContent(AlbumsState(phase = AlbumsState.Phase.Ready), {}, {}, {}, {}) }
    @Test fun albumsListLoading() = snap { AlbumsListContent(AlbumsState(), {}, {}, {}, {}) }
    @Test fun albumsListError() = snap { AlbumsListContent(AlbumsState(phase = AlbumsState.Phase.Error), {}, {}, {}, {}) }
    @Test fun albumsListOffline() = snap { AlbumsListContent(AlbumsState(phase = AlbumsState.Phase.OfflineEmpty), {}, {}, {}, {}) }

    // ---- albums.view ----

    private fun albumState(): Pair<FakeSocialData, AlbumViewState> {
        val data = FakeSocialData().apply { seedAlbums() }
        return data to AlbumViewModel(data, GROUP, "a-2").state.value
    }

    @Test fun albumViewContent() {
        val (data, state) = albumState()
        snap(data) { AlbumViewContent(state, {}, {}, {}, {}, {}) }
    }

    @Test fun albumViewMenu() {
        val (data, state) = albumState()
        snap(data, screen = true) { AlbumViewContent(state, {}, {}, {}, {}, {}, menuOpen = true) }
    }

    @Test fun albumViewDeleteConfirmation() {
        val (data, state) = albumState()
        snap(data, screen = true) { AlbumViewContent(state, {}, {}, {}, {}, {}, confirmOpen = true) }
    }

    @Test fun albumViewRenameSheet() {
        val (data, state) = albumState()
        snap(data) { SheetFrame { RenameSheetContent(state.copy(renaming = true, renameName = state.album!!.name), {}, {}, {}) } }
    }

    @Test fun albumViewEmpty() = snap { AlbumViewContent(AlbumViewState(phase = AlbumViewState.Phase.Ready, album = FakeSocialData().run { seedAlbums(); albums.getValue("a-1") }), {}, {}, {}, {}, {}) }
    @Test fun albumViewNotFound() = snap { AlbumViewContent(AlbumViewState(phase = AlbumViewState.Phase.NotFound), {}, {}, {}, {}, {}) }
    @Test fun albumViewLoading() = snap { AlbumViewContent(AlbumViewState(), {}, {}, {}, {}, {}) }
    @Test fun albumViewError() = snap { AlbumViewContent(AlbumViewState(phase = AlbumViewState.Phase.Error), {}, {}, {}, {}, {}) }
}

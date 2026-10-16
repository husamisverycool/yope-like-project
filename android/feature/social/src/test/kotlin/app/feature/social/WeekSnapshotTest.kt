package app.feature.social

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import app.data.model.RenderStatus
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.week.AlbumSheetContent
import app.feature.social.week.EditError
import app.feature.social.week.EditState
import app.feature.social.week.HistoryNav
import app.feature.social.week.HistoryState
import app.feature.social.week.HistoryViewModel
import app.feature.social.week.MessageSheetContent
import app.feature.social.week.RecapListContent
import app.feature.social.week.RecapListState
import app.feature.social.week.RecapListViewModel
import app.feature.social.week.RecapNav
import app.feature.social.week.RecapState
import app.feature.social.week.RecapViewModel
import app.feature.social.week.WeekEditContent
import app.feature.social.week.WeekEditViewModel
import app.feature.social.week.WeekHistoryContent
import app.feature.social.week.WeekRecapPreview
import app.ui.foundation.PageRoles
import app.ui.system.DsBottomSheet
import app.ui.system.SystemAlertDialog
import org.junit.Test
import java.time.LocalDate

/** A page sheet over a blank page: the native sheet (C-29) as the platform draws it. */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun SheetOverPage(content: @Composable () -> Unit) {
    Box(Modifier.fillMaxSize().background(PageRoles.page))
    DsBottomSheet(onDismissRequest = {}) { content() }
}

/** week.history, week.recap (list + preview), week.edit per state; each primary state also in dark. */
class WeekSnapshotTest : SnapshotBase() {
    private val recapNav = RecapNav({}, {}, {}, {}, { _, _ -> }, {})
    private val historyNav = HistoryNav({}, { _, _ -> }, {}, {}, {})

    // ---- week.history ----

    private fun history(): Pair<FakeSocialData, HistoryState> {
        val data = FakeSocialData().apply { seedWeek() }
        return data to HistoryViewModel(data, GROUP) { LocalDate.parse("2026-10-14") }.state.value
    }

    @Test fun historyContent() {
        val (data, state) = history()
        snap(data) { WeekHistoryContent(state, historyNav, {}, {}) }
    }

    @Test fun historyContentDark() {
        val (data, state) = history()
        snap(data, dark = true) { WeekHistoryContent(state, historyNav, {}, {}) }
    }

    @Test fun historyLoading() = snap { WeekHistoryContent(HistoryState(), historyNav, {}, {}) }

    @Test fun historyEmpty() {
        val data = FakeSocialData().apply { seedGroup() }
        val state = HistoryViewModel(data, GROUP) { LocalDate.parse("2026-10-14") }.state.value
        snap(data) { WeekHistoryContent(state, historyNav, {}, {}) }
    }

    @Test fun historyError() {
        val data = FakeSocialData().apply { seedGroup() }
        snap(data) { WeekHistoryContent(HistoryState(phase = HistoryState.Phase.Error, group = data.groups[GROUP]), historyNav, {}, {}) }
    }

    @Test fun historyOffline() {
        val (data, state) = history()
        snap(data) { WeekHistoryContent(state.copy(offline = true), historyNav, {}, {}) }
    }

    // ---- week.recap: list ----

    private fun list(): Pair<FakeSocialData, RecapListState> {
        val data = FakeSocialData().apply { seedRecaps() }
        return data to RecapListViewModel(data, GROUP).state.value
    }

    @Test fun recapList() {
        val (data, state) = list()
        snap(data, screen = true) { SheetOverPage { RecapListContent(state, recapNav, {}) } }
    }

    @Test fun recapListDark() {
        val (data, state) = list()
        snap(data, screen = true, dark = true) { SheetOverPage { RecapListContent(state, recapNav, {}) } }
    }

    @Test fun recapListLoading() = snap(screen = true) { SheetOverPage { RecapListContent(RecapListState(), recapNav, {}) } }

    @Test fun recapListEmpty() = snap(screen = true) { SheetOverPage { RecapListContent(RecapListState(phase = RecapListState.Phase.Empty), recapNav, {}) } }

    @Test fun recapListError() = snap(screen = true) { SheetOverPage { RecapListContent(RecapListState(phase = RecapListState.Phase.Error), recapNav, {}) } }

    // ---- week.recap: preview ----

    private fun preview(): Pair<FakeSocialData, RecapState> {
        val data = FakeSocialData().apply { seedRecaps() }
        return data to RecapViewModel(data, GROUP, "r-w").state.value
    }

    /** A recap of [count] photos without a note (week of 12 October; photos past the week's seven are added the same week). */
    private fun previewOf(count: Int): Pair<FakeSocialData, RecapState> {
        val data = FakeSocialData().apply {
            seedWeek()
            val monday = LocalDate.parse("2026-10-12")
            val extra = (8..count).map { i ->
                addPhoto("w-$i", listOf(FakeSocialData.ME, FakeSocialData.ANA, FakeSocialData.BEN)[i % 3], monday.plusDays((i % 7).toLong()).atStartOfDay(java.time.ZoneOffset.UTC).toInstant().plusSeconds(3_600L * (i / 7))).id
            }
            recaps["r-n"] = recap("r-n", monday, ((1..7).map { "w-$it" } + extra).take(count))
        }
        return data to RecapViewModel(data, GROUP, "r-n").state.value
    }

    /** `week.recap.layout.gridFill`: one photo fills the card's photo area (retro.app hero card). */
    @Test fun recapPreviewOne() {
        val (data, state) = previewOf(1)
        snap(data) { WeekRecapPreview(state, recapNav, {}) }
    }

    /** Five photos: 2 columns × 3 rows, the short last row leading-aligned with the card fill after it. */
    @Test fun recapPreviewFive() {
        val (data, state) = previewOf(5)
        snap(data) { WeekRecapPreview(state, recapNav, {}) }
    }

    /** Nine photos: 3 × 3 over the same 3:4 area (Retro TC-H). */
    @Test fun recapPreviewNine() {
        val (data, state) = previewOf(9)
        snap(data) { WeekRecapPreview(state, recapNav, {}) }
    }

    /** Twenty-four photos: 4 × 6 (Retro TC-REC); more would not be drawn on the card. */
    @Test fun recapPreviewFull() {
        val (data, state) = previewOf(24)
        snap(data) { WeekRecapPreview(state, recapNav, {}) }
    }

    /** Page 1: the white recap card with six photos (`week.recap.layout.gridFill`: 2 × 3) and the note. */
    @Test fun recapPreview() {
        val (data, state) = preview()
        snap(data) { WeekRecapPreview(state, recapNav, {}) }
    }

    @Test fun recapPreviewDark() {
        val (data, state) = preview()
        snap(data, dark = true) { WeekRecapPreview(state, recapNav, {}) }
    }


    /** Page 2: the cover full-bleed under the scrim. */
    @Test fun recapPreviewCover() {
        val (data, state) = preview()
        snap(data) { WeekRecapPreview(state, recapNav, {}, initialPage = 1) }
    }

    @Test fun recapPreviewLoading() = snap { WeekRecapPreview(RecapState(), recapNav, {}) }

    @Test fun recapPreviewPending() = snap { WeekRecapPreview(RecapState(phase = RecapState.Phase.Pending), recapNav, {}) }

    @Test fun recapPreviewError() = snap { WeekRecapPreview(RecapState(phase = RecapState.Phase.Error), recapNav, {}) }

    // ---- week.edit ----

    private fun editState(albumOnly: Boolean = false): Pair<FakeSocialData, EditState> {
        val data = FakeSocialData().apply { seedWeek() }
        val vm = if (albumOnly) WeekEditViewModel(data, GROUP, null, LocalDate.parse("2026-10-12"), true) else WeekEditViewModel(data, GROUP, "r-w", null, false)
        return data to vm.state.value
    }

    private fun edit(state: EditState, data: FakeSocialData, dark: Boolean = false) =
        snap(data, screen = true, dark = dark) { SheetOverPage { WeekEditContent(state, {}, {}, {}, { _, _ -> }, {}, {}) } }

    @Test fun editReady() {
        val (data, state) = editState()
        edit(state, data)
    }

    @Test fun editReadyDark() {
        val (data, state) = editState()
        edit(state, data, dark = true)
    }

    @Test fun editLoading() = edit(EditState(), FakeSocialData())

    @Test fun editSaving() {
        val (data, state) = editState()
        edit(state.copy(saving = true), data)
    }

    @Test fun editNotReady() = edit(EditState(phase = EditState.Phase.NotReady, error = EditError.NotReady), FakeSocialData())

    @Test fun messageSheet() {
        val (data, state) = editState()
        snap(data, screen = true) { SheetOverPage { MessageSheetContent(state.text, {}, {}) } }
    }

    @Test fun albumSheet() {
        val (data, state) = editState(albumOnly = true)
        snap(data, screen = true) { SheetOverPage { AlbumSheetContent(state.copy(albumName = "Lake weekend"), {}, {}, {}) } }
    }

    @Test fun albumSheetNameError() {
        val (data, state) = editState(albumOnly = true)
        snap(data, screen = true) { SheetOverPage { AlbumSheetContent(state.copy(albumName = " ", albumError = EditError.AlbumName), {}, {}, {}) } }
    }

    @Test fun lostChanges() {
        val (data, state) = editState()
        snap(data, screen = true) {
            SheetOverPage { WeekEditContent(state, {}, {}, {}, { _, _ -> }, {}, {}) }
            SystemAlertDialog(
                androidx.compose.ui.res.stringResource(app.designsystem.R.string.week_edit_lostchanges_title),
                androidx.compose.ui.res.stringResource(app.designsystem.R.string.week_edit_lostchanges_message),
                androidx.compose.ui.res.stringResource(app.designsystem.R.string.week_edit_lostchanges_confirm),
                {},
                androidx.compose.ui.res.stringResource(app.designsystem.R.string.photo_viewer_delete_cancel),
                {},
                destructive = true,
            )
        }
    }
}

/** The week of 12 October with its recap (six photos, a note by Ana), last week's recap, and one being made. */
fun FakeSocialData.seedRecaps() {
    seedWeek()
    recaps["r-w"] = recaps.getValue("r-w").copy(editedBy = FakeSocialData.ANA)
    recaps["r-prev"] = recap("r-prev", LocalDate.parse("2026-10-05"), listOf("w-0"))
    recaps["r-old"] = recap("r-old", LocalDate.parse("2026-09-28"), emptyList(), status = RenderStatus.Pending)
}

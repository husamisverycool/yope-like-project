// Surface: search.photos — design/surfaces/search.photos.md
// References: references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png (ED-W3: pushed header,
// search field), references/auto/retro/press/tc-2024-04-journals-1.webp phone 3 (TC-J1: 3-column grid, 2 pt gaps);
// mechanics: Yope's search on the group list (design/research/yope-a.md §2.9), Apple Shared Albums filters
// (support.apple.com/108314). No face or AI search; no result count anywhere (tenet 2).
@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package app.feature.social.search

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DateRangePicker
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDateRangePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.TextFieldValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Formats
import app.feature.social.common.RemotePhoto
import app.feature.social.common.stringRes
import app.feature.social.common.withVideoLabel
import app.feature.social.walls.ErrorLine
import app.ui.components.ActivityIndicator
import app.ui.components.CapsuleToggle
import app.ui.components.EmptyState
import app.ui.components.PushedHeader
import app.ui.components.SearchField
import app.ui.components.VideoTileMarker
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset

/** Where `search.photos` leads. */
data class SearchNav(
    val back: () -> Unit,
    /** `photo.viewer` over the results ([SearchViewModel.resultsKey]), from the photo's group. */
    val photo: (groupId: String, postId: String) -> Unit,
)

@Composable
fun SearchPhotosScreen(vm: SearchViewModel, nav: SearchNav) {
    val state by vm.state.collectAsStateWithLifecycle()
    SearchPhotosContent(
        state = state,
        nav = nav,
        onText = vm::setText,
        onSubmit = vm::search,
        onMember = vm::toggleMember,
        onDates = vm::setDates,
        onClearDates = vm::clearDates,
        onLoadMore = vm::loadMore,
    )
}

/**
 * `search.photos` (`search.photos.layout.composition`): C-02 "Search" with the C-12 field under it; one row of C-06 toggles
 * `size.global.sectionHeaderToContent` below — the date chip, then you and the members; the results as the C-21 grid
 * (`search.photos.count.gridColumns` square cells, `size.global.stripGap` apart) `size.global.titleToContent` below the
 * chips, paged at the end; idle / empty as C-27, error / offline as the tappable line.
 */
@Composable
fun SearchPhotosContent(
    state: SearchState,
    nav: SearchNav,
    onText: (String) -> Unit,
    onSubmit: () -> Unit,
    onMember: (String) -> Unit,
    onDates: (LocalDate, LocalDate) -> Unit,
    onClearDates: () -> Unit,
    onLoadMore: () -> Unit,
) {
    var field by remember { mutableStateOf(TextFieldValue(state.text)) }
    var datesOpen by rememberSaveable { mutableStateOf(false) }
    val focus = LocalFocusManager.current
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Column(Modifier.fillMaxSize().background(PageRoles.page).statusBarsPadding().testTag("search.photos")) {
        PushedHeader(
            stringRes(R.string.search_photos_title),
            nav.back,
            stringRes(R.string.chat_thread_a11y_back),
            below = {
                SearchField(
                    value = field,
                    onValueChange = {
                        field = it
                        onText(it.text)
                    },
                    placeholder = stringRes(R.string.search_photos_field),
                    accessibilityLabel = stringRes(R.string.search_photos_field_a11y),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                    keyboardActions = KeyboardActions(onSearch = {
                        focus.clearFocus()
                        onSubmit()
                    }),
                )
            },
        )
        Chips(state, onMember, onDate = { if (state.hasDates) onClearDates() else datesOpen = true })
        when (state.phase) {
            SearchState.Phase.Idle -> Box(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.globalSectionGap), contentAlignment = Alignment.TopCenter) {
                EmptyState(stringRes(R.string.search_photos_idle_title), stringRes(R.string.search_photos_idle_detail), icon = Tokens.Icons.globalSearch)
            }
            SearchState.Phase.Empty -> Box(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.globalSectionGap), contentAlignment = Alignment.TopCenter) {
                EmptyState(stringRes(R.string.search_photos_empty_title), null)
            }
            SearchState.Phase.Error -> ErrorLine(stringRes(R.string.search_photos_error), onSubmit, Modifier.padding(top = Tokens.Sizes.globalTitleToContent))
            SearchState.Phase.Offline -> ErrorLine(stringRes(R.string.search_photos_offline), onSubmit, Modifier.padding(top = Tokens.Sizes.globalTitleToContent))
            SearchState.Phase.Loading, SearchState.Phase.Results -> ResultsGrid(state, nav, bottom, onLoadMore)
        }
    }
    if (datesOpen) {
        SearchDatesDialog(
            initialFrom = state.from,
            initialTo = state.to,
            onCancel = { datesOpen = false },
            onDone = { from, to ->
                datesOpen = false
                onDates(from, to)
            },
        )
    }
}

/** C-21: the results (or, while a search is out, two rows of placeholder cells) inside `size.global.screenMargin`. */
@Composable
private fun ResultsGrid(state: SearchState, nav: SearchNav, bottom: androidx.compose.ui.unit.Dp, onLoadMore: () -> Unit) {
    val context = LocalContext.current
    val columns = Tokens.Counts.searchPhotosCountGridColumns
    val gap = Tokens.Sizes.globalStripGap
    val margin = Tokens.Sizes.globalScreenMargin
    val grid = rememberLazyGridState()
    val nearEnd by remember(state.results) {
        derivedStateOf { (grid.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0) >= grid.layoutInfo.totalItemsCount - 1 }
    }
    LaunchedEffect(nearEnd, state.phase) { if (nearEnd && state.phase == SearchState.Phase.Results) onLoadMore() }
    val me = state.members.firstOrNull { it.isMe }?.userId
    LazyVerticalGrid(
        columns = GridCells.Fixed(columns),
        state = grid,
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = margin, end = margin, top = Tokens.Sizes.globalTitleToContent, bottom = bottom + Tokens.Sizes.globalSectionGap),
        horizontalArrangement = Arrangement.spacedBy(gap),
        verticalArrangement = Arrangement.spacedBy(gap),
    ) {
        if (state.phase == SearchState.Phase.Loading) {
            item(key = "loading", span = { GridItemSpan(maxLineSpan) }) {
                // C-28: placeholder cells where the photos will appear, read as one busy element.
                Column(
                    Modifier.clearAndSetSemantics { contentDescription = context.getString(R.string.week_history_a11y_loading) },
                    verticalArrangement = Arrangement.spacedBy(gap),
                ) {
                    repeat(LOADING_ROWS) {
                        Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                            repeat(columns) { Box(Modifier.weight(1f).aspectRatio(1f).background(Tokens.Colors.globalControl)) }
                        }
                    }
                }
            }
        } else {
            items(state.results, key = { it.post.id }) { result ->
                val day = result.post.createdAt.atZone(ZoneId.systemDefault()).toLocalDate()
                val date = Formats.spokenDate(day)
                val label = withVideoLabel(
                    context,
                    if (result.post.authorId == me) stringRes(R.string.photo_viewer_a11y_photomine, date)
                    else stringRes(R.string.photo_viewer_a11y_photo, result.authorName.orEmpty(), date),
                    result.videoDurationMs,
                )
                Box(
                    Modifier
                        .aspectRatio(1f)
                        // The cell is one button read as its label (as the week strip's tiles).
                        .clearAndSetSemantics { contentDescription = label }
                        .tapClickable { nav.photo(result.post.groupId, result.post.id) },
                ) {
                    RemotePhoto(result.thumbPath, null, Modifier.fillMaxSize())
                    result.videoDurationMs?.let { VideoTileMarker(it) }
                }
            }
            if (state.loadingMore) item(key = "more", span = { GridItemSpan(maxLineSpan) }) {
                Box(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.globalSectionHeaderToContent), contentAlignment = Alignment.Center) {
                    ActivityIndicator(stringRes(R.string.week_history_a11y_loading))
                }
            }
        }
    }
}

/** Placeholder rows while a search is out (`search.photos` → loading: "two rows"). */
private const val LOADING_ROWS = 2

/**
 * The filter chips (C-06 toggles, `size.global.pillGap` apart, from `size.global.screenMargin`, scrolling sideways): the
 * date chip ("Date", or the chosen range in the on state), then you and the members (one at a time).
 */
@Composable
private fun Chips(state: SearchState, onMember: (String) -> Unit, onDate: () -> Unit) {
    val context = LocalContext.current
    val dateText = if (state.from != null && state.to != null) Formats.dayRange(context, state.from, state.to) else stringRes(R.string.search_photos_date)
    Row(
        Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(top = Tokens.Sizes.globalSectionHeaderToContent)
            .padding(horizontal = Tokens.Sizes.globalScreenMargin),
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillGap),
    ) {
        CapsuleToggle(dateText, state.hasDates, { onDate() }, Modifier.testTag("search.photos.date"))
        val you = stringRes(R.string.search_photos_member_you)
        state.members.forEach { member ->
            CapsuleToggle(if (member.isMe) you else member.name, state.memberId == member.userId, { onMember(member.userId) })
        }
    }
}

/**
 * The date filter (Android): the M3 `DateRangePicker` in a `DatePickerDialog` (PLATFORM; its own labels are the platform's),
 * days after today not selectable; Done (`search.photos.date.done`) with a start chosen applies it (one day when no end).
 */
@Composable
private fun SearchDatesDialog(initialFrom: LocalDate?, initialTo: LocalDate?, onCancel: () -> Unit, onDone: (LocalDate, LocalDate) -> Unit) {
    val todayEnd = LocalDate.now().plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
    val picker = rememberDateRangePickerState(
        initialSelectedStartDateMillis = initialFrom?.atStartOfDay(ZoneOffset.UTC)?.toInstant()?.toEpochMilli(),
        initialSelectedEndDateMillis = initialTo?.atStartOfDay(ZoneOffset.UTC)?.toInstant()?.toEpochMilli(),
        selectableDates = object : SelectableDates {
            override fun isSelectableDate(utcTimeMillis: Long): Boolean = utcTimeMillis < todayEnd
            override fun isSelectableYear(year: Int): Boolean = year <= LocalDate.now().year
        },
    )
    DatePickerDialog(
        onDismissRequest = onCancel,
        confirmButton = {
            TextButton(onClick = {
                val start = picker.selectedStartDateMillis?.let { Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate() }
                val end = picker.selectedEndDateMillis?.let { Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate() }
                if (start != null) onDone(start, end ?: start) else onCancel()
            }) { Text(stringRes(R.string.search_photos_date_done)) }
        },
        dismissButton = { TextButton(onClick = onCancel) { Text(stringRes(R.string.search_photos_date_cancel)) } },
    ) {
        DateRangePicker(picker, Modifier.weight(1f))
    }
}

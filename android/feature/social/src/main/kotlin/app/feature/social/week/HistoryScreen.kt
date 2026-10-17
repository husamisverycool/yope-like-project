// Surface: week.history — design/surfaces/week.history.md
// References: references/auto/retro/store/retro-store-02.png (section header "Week 27  Jul 3 - 9" + "•••", strips),
// references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png and …-20260528-week22-dark-a.png (empty week),
// references/auto/retro/press/engadget-2026-08-profile.jpg (current week: photos, add, placeholders),
// references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png (C-02 pushed header).
package app.feature.social.week

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
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
import androidx.compose.ui.platform.testTag
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.data.model.PhotoBatches
import app.data.model.batchKey
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Formats
import app.feature.memory.common.HistoryCalendarSheet
import app.feature.social.common.StripPhoto
import app.feature.social.common.placeholderDays
import app.feature.social.common.stringRes
import app.feature.social.common.weekStripTiles
import app.feature.social.walls.ErrorLine
import app.ui.components.ActivityIndicator
import app.ui.components.DayTile
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.EmptyStateFill
import app.ui.components.HeaderAction
import app.ui.components.PushedHeader
import app.ui.components.WeekSection
import app.ui.foundation.PageRoles
import app.ui.system.DsMenuItem
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt
import androidx.compose.ui.unit.dp
import java.time.LocalDate

/** Where `week.history` leads. */
data class HistoryNav(
    val back: () -> Unit,
    val photo: (weekStart: String, postId: String) -> Unit,
    val recap: (recapId: String) -> Unit,
    val saveAsAlbum: (weekStart: String) -> Unit,
    val camera: () -> Unit,
    /** `collage.view` of a day's same-moment collage (by its invitation). */
    val collage: (invitationId: String) -> Unit = {},
)

@Composable
fun WeekHistoryScreen(vm: HistoryViewModel, nav: HistoryNav) {
    val state by vm.state.collectAsStateWithLifecycle()
    WeekHistoryContent(state, nav, onRetry = vm::refresh, onLoadMore = vm::loadMore, onJump = vm::jumpTo, onScrolled = vm::scrolled)
}

/**
 * `week.history`: C-02 pushed header (back + the group's name in the serif), then the group's weeks newest first —
 * C-20 header ("Week 27" + the range, "•••" → week menu) over a C-17 strip; the current week always first
 * (`week.history.layout.currentWeek`).
 */
@Composable
fun WeekHistoryContent(
    state: HistoryState,
    nav: HistoryNav,
    onRetry: () -> Unit,
    onLoadMore: () -> Unit,
    listState: LazyListState = rememberLazyListState(),
    onJump: (LocalDate) -> Unit = {},
    onScrolled: () -> Unit = {},
) {
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    var calendarOpen by rememberSaveable { mutableStateOf(false) }
    // The calendar's jump: the chosen week at the top of the list once it is there.
    LaunchedEffect(state.scrollTo, state.weeks) {
        val target = state.scrollTo ?: return@LaunchedEffect
        val index = state.weeks.indexOfFirst { it.weekStart == target }
        if (index < 0) return@LaunchedEffect
        listState.scrollToItem(index + if (state.offline) 1 else 0)
        onScrolled()
    }
    Column(Modifier.fillMaxSize().background(PageRoles.page).statusBarsPadding().testTag("week.history")) {
        // C-02; once the history's months are known, the calendar glyph (`week.history.layout.calendar`).
        val calendar = stringRes(R.string.week_history_calendar_open)
        PushedHeader(
            state.group?.name.orEmpty(),
            nav.back,
            stringRes(R.string.chat_thread_a11y_back),
            actions = if (state.months.isEmpty()) emptyList() else listOf(HeaderAction(Tokens.Icons.globalCalendar, calendar) { calendarOpen = true }),
        )
        when {
            state.phase == HistoryState.Phase.Loading -> {
                val week = state.weeks.firstOrNull()?.weekStart ?: Formats.weekStartOf(LocalDate.now(state.zone))
                WeekSection(stringRes(R.string.week_history_header_title, Formats.isoWeek(week)), placeholderDays(week), Modifier.capTopAt(0.dp, CapTop.height(TextRoles.sectionLabel)))
                WeekSection(stringRes(R.string.week_history_header_title, Formats.isoWeek(week.minusWeeks(1))), placeholderDays(week.minusWeeks(1)), afterContent = true)
                Box(Modifier.weight(1f).fillMaxWidth()) { LoadingState() }
            }
            // Offline with nothing cached: the offline line, as iOS (week.history States), not the error copy.
            state.phase == HistoryState.Phase.Error -> ErrorLine(stringRes(if (state.offline) R.string.week_history_offline else R.string.week_history_error), onRetry)
            state.isEmpty -> {
                state.weeks.firstOrNull { it.isCurrent }?.let { HistorySection(it, state, nav, afterContent = false) }
                EmptyStateFill(Modifier.weight(1f).padding(bottom = bottom)) {
                    val week = state.weeks.firstOrNull { it.isCurrent }?.weekStart ?: Formats.weekStartOf(LocalDate.now(state.zone))
                    EmptyState(
                        stringRes(R.string.week_history_empty_title, Formats.isoWeek(week)),
                        null,
                        action = EmptyStateAction(stringRes(R.string.week_history_empty_action), nav.camera, Tokens.Icons.globalAdd),
                        icon = Tokens.Icons.globalCalendar,
                    )
                }
            }
            else -> {
                val nearEnd by remember(state.weeks) { derivedStateOf { (listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0) >= state.weeks.size - 1 } }
                LaunchedEffect(nearEnd) { if (nearEnd) onLoadMore() }
                LazyColumn(state = listState, modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = bottom + Tokens.Sizes.globalSectionGap)) {
                    if (state.offline) item(key = "offline") {
                        ErrorLine(stringRes(R.string.week_history_offline), onRetry, Modifier.padding(bottom = Tokens.Sizes.globalSectionHeaderToContent))
                    }
                    items(state.weeks, key = { it.weekStart.toString() }) { week ->
                        HistorySection(week, state, nav, afterContent = week != state.weeks.first())
                    }
                    if (state.loadingMore) item(key = "more") {
                        Box(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.globalSectionGap), contentAlignment = Alignment.Center) {
                            ActivityIndicator(stringRes(R.string.week_history_a11y_loading))
                        }
                    }
                }
            }
        }
    }
    if (calendarOpen) {
        HistoryCalendarSheet(
            months = state.months,
            // A day opens its week; a month title its newest week.
            onSelectDay = { day ->
                calendarOpen = false
                onJump(Formats.weekStartOf(day))
            },
            onClose = { calendarOpen = false },
            onSelectMonth = { month ->
                calendarOpen = false
                onJump(month.newestWeek)
            },
        )
    }
}

/** The C-28 indicator in the space left under the placeholder sections. */
@Composable
private fun LoadingState() = app.ui.components.LoadingState(stringRes(R.string.week_history_a11y_loading))

/** One week: header with the week menu (`week.history.layout.weekMenu`) over its strip. */
@Composable
private fun HistorySection(week: HistoryWeekUi, state: HistoryState, nav: HistoryNav, afterContent: Boolean) {
    val context = LocalContext.current
    val zone = state.zone
    val title = stringRes(R.string.week_history_header_title, Formats.isoWeek(week.weekStart))
    val range = if (week.isCurrent && week.photos.isEmpty() && week.collages.isEmpty()) null else Formats.weekRange(context, week.weekStart, zone)
    val spoken = if (range == null) title else "$title, ${Formats.spokenWeekRange(context, week.weekStart, zone)}"
    val start = week.weekStart.toString()
    // Photos posted together are one tile, the batch's first photo with the batch marker (`layout.global.photoBatch`);
    // the viewer opens on it with the whole batch (`photo.viewer.layout.batchDots`).
    val runs = PhotoBatches.runs(week.photos.sortedBy { it.post.visibleAt }) { it.post.batchKey }
    val photos = runs.map { run ->
        val p = run.first()
        // the week and the day a photo belongs to: when it became visible (an overnight photo: its reveal)
        val day = p.post.visibleAt.atZone(zone).toLocalDate()
        StripPhoto(
            p.post.id,
            p.thumbPath,
            p.post.visibleAt,
            stringRes(R.string.week_history_a11y_tile, Formats.weekdayLong(day), Formats.spokenDate(day), p.authorName.orEmpty()),
            { nav.photo(start, p.post.id) },
            p.videoDurationMs,
            batch = run.size > 1,
        )
    } + week.collages.map { c ->
        // the group's photo of the day (the same-moment collage) on its day, before that day's photos
        StripPhoto(
            "collage-" + c.collageId,
            c.tilePath,
            c.localDate.atStartOfDay(zone).toInstant(),
            stringRes(R.string.walls_browse_a11y_collage, Formats.spokenDate(c.localDate)),
            { nav.collage(c.invitationId) },
        )
    }
    val menu = buildList {
        week.recapId?.let { id -> add(DsMenuItem(stringRes(R.string.week_history_menu_viewrecap), { nav.recap(id) })) }
        if (week.photos.isNotEmpty()) add(DsMenuItem(stringRes(R.string.week_history_menu_saveasalbum), { nav.saveAsAlbum(start) }))
    }
    val add = if (week.isCurrent) DayTile.Add(stringRes(R.string.week_history_a11y_add), nav.camera) else null
    WeekSection(
        title = title,
        tiles = weekStripTiles(week.weekStart, photos, week.isCurrent, add, zone),
        // The first header's cap top sits `size.global.titleToContent` below the title baseline (C-02 ends there).
        modifier = if (afterContent) Modifier else Modifier.capTopAt(0.dp, CapTop.height(TextRoles.sectionLabel)),
        range = range,
        accessibilityLabel = spoken,
        menu = menu,
        moreContentDescription = stringRes(R.string.week_history_a11y_more),
        afterContent = afterContent,
    )
}

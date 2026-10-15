// Surface: week.history — scroll back week by week (Retro geometry and voice; dark only, S-16).
// References: references/auto/retro/store/retro-store-02.png (primary), references/auto/retro/store/retro-store-01.png
// (display title), references/auto/retro/press/jeddacp-2024-05-home-profile-journals.png, references/auto/retro/press/engadget-2026-08-profile.jpg.
package app.feature.social.week

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFromBaseline
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.LastBaseline
import androidx.compose.ui.layout.layout
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.designsystem.toFontFamily
import app.feature.social.common.ActivityIndicator
import app.feature.social.common.Formats
import app.feature.social.common.Glyph
import app.feature.social.common.HeaderCircle
import app.feature.social.common.InkGlyph
import app.feature.social.common.Line
import app.feature.social.common.RemotePhoto
import app.feature.social.common.Type
import app.feature.social.common.inkBounds
import app.feature.social.common.stringRes
import app.ui.components.HeaderCircleFill
import kotlinx.coroutines.flow.distinctUntilChanged
import java.time.LocalDate
import java.time.ZoneId

/** Where the history leads. */
data class HistoryNav(
    val back: () -> Unit,
    val photo: (weekStart: String, postId: String) -> Unit,
    val recap: (recapId: String) -> Unit,
    val saveAsAlbum: (weekStart: String) -> Unit,
    val camera: () -> Unit,
)

/** Cap height of the platform font (Roboto: 1456 / 2048 em), to place a cap top from a baseline. */
private const val PLATFORM_CAP_HEIGHT_EM = 0.711f

@Composable
fun WeekHistoryScreen(vm: HistoryViewModel, nav: HistoryNav) {
    val state by vm.state.collectAsStateWithLifecycle()
    WeekHistoryContent(state, nav, onRefresh = vm::refresh, onLoadMore = vm::loadMore)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WeekHistoryContent(state: HistoryState, nav: HistoryNav, onRefresh: () -> Unit, onLoadMore: () -> Unit, listState: LazyListState = rememberLazyListState()) {
    val density = LocalDensity.current
    val headerCap = with(density) { Tokens.FontSizes.weekHistoryFontSizeHeader.toDp() } * PLATFORM_CAP_HEIGHT_EM
    LaunchedEffect(listState) {
        snapshotFlow { listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0 }
            .distinctUntilChanged()
            .collect { last -> if (last >= listState.layoutInfo.totalItemsCount - 2) onLoadMore() }
    }
    Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep).testTag("week.history")) {
        // Native pull-to-refresh (retry after an error; its threshold feedback is the platform's own).
        PullToRefreshBox(isRefreshing = state.refreshing, onRefresh = onRefresh, modifier = Modifier.fillMaxSize()) {
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()),
            ) {
                item(key = "back") {
                    Box(Modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.statusBars).padding(start = Tokens.Sizes.globalHeaderInset)) {
                        HeaderCircle(Tokens.Icons.globalBack, stringRes(R.string.chat_thread_a11y_back), HeaderCircleFill.OnDeep, nav.back)
                    }
                }
                item(key = "title") {
                    // The layout ends at the title's baseline, so the first header's cap top can be placed from it.
                    Line(
                        state.group?.name.orEmpty(),
                        Type.style(Tokens.FontSizes.weekHistoryFontSizeTitle, Tokens.FontWeights.weekHistoryFontWeightTitle).copy(fontFamily = Tokens.Fonts.weekHistoryFontTitle.toFontFamily()),
                        Tokens.Colors.globalTextPrimary,
                        Modifier.padding(start = Tokens.Sizes.weekHistoryDimensionTitleInset, end = Tokens.Sizes.weekHistoryDimensionInset)
                            .layout { measurable, constraints ->
                                // The item ends at the title's baseline (descenders draw past it).
                                val placeable = measurable.measure(constraints)
                                val baseline = placeable[LastBaseline].takeIf { it != androidx.compose.ui.layout.AlignmentLine.Unspecified } ?: placeable.height
                                layout(placeable.width, baseline) { placeable.place(0, 0) }
                            }
                            .semantics { heading() },
                    )
                }
                when (state.phase) {
                    HistoryState.Phase.Loading -> item(key = "loading") {
                        Box(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.weekHistoryDimensionTitleToStrip), contentAlignment = Alignment.Center) { ActivityIndicator() }
                    }
                    HistoryState.Phase.Error -> item(key = "error") { ExplanationLine(stringRes(R.string.week_history_error), Tokens.Sizes.weekHistoryDimensionTitleToStrip + headerCap) }
                    HistoryState.Phase.Ready -> {
                        if (state.offline) item(key = "offline") { ExplanationLine(stringRes(R.string.week_history_offline), Tokens.Sizes.weekHistoryDimensionTitleToStrip + headerCap) }
                        itemsIndexed(state.weeks, key = { _, w -> w.weekStart.toString() }) { i, week ->
                            val gapFromPrevious = if (i == 0 && !state.offline) Tokens.Sizes.weekHistoryDimensionTitleToStrip else Tokens.Sizes.weekHistoryDimensionSectionGap
                            WeekSection(week, state.zone, gapFromPrevious + headerCap, nav)
                        }
                        if (state.isEmpty) item(key = "empty") {
                            ExplanationLine(stringRes(R.string.week_history_empty, state.group?.name.orEmpty()), Tokens.Sizes.weekHistoryDimensionSectionGap + headerCap)
                        }
                        if (state.loadingMore) item(key = "more") {
                            Box(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.weekHistoryDimensionSectionGap), contentAlignment = Alignment.Center) { ActivityIndicator() }
                        }
                    }
                }
            }
        }
    }
}

/** One explanation line (text role `listSubtitle`, `color.global.textSecondary`) at `week.history.dimension.inset`. */
@Composable
private fun ExplanationLine(text: String, baselineFromTop: Dp) {
    Line(
        text,
        Type.listSubtitle(),
        Tokens.Colors.globalTextSecondary,
        Modifier.padding(horizontal = Tokens.Sizes.weekHistoryDimensionInset).paddingFromBaseline(top = baselineFromTop),
        maxLines = Int.MAX_VALUE,
    )
}

/**
 * A week section: "Week {n}" + the locale's Monday–Sunday range (omitted for a current week with no
 * photos) and ••• at the right; the strip `week.history.dimension.headerToStrip` below the header
 * baseline. [headerBaseline] = from the section's top to the header baseline.
 */
@Composable
private fun WeekSection(week: HistoryWeekUi, zone: ZoneId, headerBaseline: Dp, nav: HistoryNav) {
    val context = LocalContext.current
    val headerStyle = Type.style(Tokens.FontSizes.weekHistoryFontSizeHeader, Tokens.FontWeights.weekHistoryFontWeightHeaderTitle)
    val rangeStyle = Type.style(Tokens.FontSizes.weekHistoryFontSizeHeader, Tokens.FontWeights.weekHistoryFontWeightHeaderRange)
    val title = stringRes(R.string.week_history_header_title, Formats.isoWeek(week.weekStart).toString())
    val range = if (week.isCurrent && week.photos.isEmpty()) null else Formats.weekRange(context, week.weekStart, zone)
    var menu by remember { mutableStateOf(false) }
    val more = Tokens.Icons.globalMore
    val bounds = remember(more) { inkBounds(more) }
    // ••• right ink edge `week.history.dimension.moreTrailing` from the screen edge (the glyph keeps its platform size).
    val glyphBox = more.defaultWidth
    val inkRightInset = glyphBox * ((more.viewportWidth - bounds.right) / more.viewportWidth)
    Column(Modifier.fillMaxWidth().semantics(mergeDescendants = false) { }) {
        val label = stringRes(R.string.week_history_a11y_more)
        Layout(
            modifier = Modifier.fillMaxWidth().padding(start = Tokens.Sizes.weekHistoryDimensionInset, end = Tokens.Sizes.weekHistoryDimensionMoreTrailing - inkRightInset),
            content = {
                Row(Modifier.semantics(mergeDescendants = true) { heading() }) {
                    Line(title, headerStyle, Tokens.Colors.globalTextPrimary, Modifier.alignByBaseline())
                    if (range != null) {
                        Spacer(Modifier.width(Tokens.Sizes.weekHistoryDimensionRangeGap))
                        Line(range, rangeStyle, Tokens.Colors.globalTextSecondary, Modifier.alignByBaseline())
                    }
                }
                Box {
                    Box(Modifier.clickable(role = Role.Button) { menu = true }.clearAndSetSemantics { contentDescription = label; role = Role.Button }) {
                        Glyph(more, Tokens.Colors.globalTextPrimary)
                    }
                    DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                        week.recapId?.let { id ->
                            DropdownMenuItem(text = { Text(stringRes(R.string.week_history_menu_viewrecap)) }, onClick = { menu = false; nav.recap(id) })
                        }
                        if (week.photos.isNotEmpty()) {
                            DropdownMenuItem(text = { Text(stringRes(R.string.week_history_menu_saveasalbum)) }, onClick = { menu = false; nav.saveAsAlbum(week.weekStart.toString()) })
                        }
                    }
                }
            },
        ) { measurables, constraints ->
            // Header baseline at [headerBaseline]; the strip starts `headerToStrip` below it; ••• centred on the text.
            val glyph = measurables[1].measure(Constraints())
            val text = measurables[0].measure(Constraints(maxWidth = (constraints.maxWidth - glyph.width).coerceAtLeast(0)))
            val textY = headerBaseline.roundToPx() - text[FirstBaseline]
            val height = (headerBaseline + Tokens.Sizes.weekHistoryDimensionHeaderToStrip).roundToPx()
            layout(constraints.maxWidth, height) {
                text.place(0, textY)
                glyph.place(constraints.maxWidth - glyph.width, textY + (text.height - glyph.height) / 2)
            }
        }
        Strip(week, zone, nav)
    }
}

/**
 * The strip: one tile per photo Mon → Sun (`week.history.dimension.tileWidth` × `.tileHeight`, gaps
 * `.tileGap`, outer corners `week.history.radius.strip`), weekday bottom-centred. Starts at
 * `week.history.dimension.inset` and clips at the screen edge. The current week ends with the add
 * tile and one empty-day tile per day without a photo (`week.history.color.emptyTile`; labels
 * `.emptyTileText`, the "+" `color.global.textPrimary`; Retro dark, G-15).
 */
@Composable
private fun Strip(week: HistoryWeekUi, zone: ZoneId, nav: HistoryNav) {
    val fill = Tokens.Colors.weekHistoryColorEmptyTile
    val ink = Tokens.Colors.weekHistoryColorEmptyTileText
    val days = remember(week) { week.photos.map { it.post.createdAt.atZone(zone).toLocalDate() } }
    val emptyDays = if (week.isCurrent) (0 until Formats.DAYS_IN_WEEK.toInt()).map { week.weekStart.plusDays(it.toLong()) }.filter { it !in days } else emptyList()
    val showAdd = week.isCurrent
    val count = week.photos.size + (if (showAdd) 1 else 0) + emptyDays.size
    if (count == 0) return
    val radius = Tokens.Radii.weekHistoryRadiusStrip
    fun shape(i: Int) = RoundedCornerShape(
        topStart = if (i == 0) radius else 0.dp,
        bottomStart = if (i == 0) radius else 0.dp,
        topEnd = if (i == count - 1) radius else 0.dp,
        bottomEnd = if (i == count - 1) radius else 0.dp,
    )
    LazyRow(
        contentPadding = PaddingValues(start = Tokens.Sizes.weekHistoryDimensionInset),
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.weekHistoryDimensionTileGap),
    ) {
        itemsIndexed(week.photos, key = { _, p -> p.post.id }) { i, photo ->
            val day = days[i]
            val label = stringRes(R.string.week_history_a11y_tile, Formats.weekdayLong(day), Formats.spokenDate(day), photo.authorName.orEmpty())
            Box(
                Modifier
                    .size(Tokens.Sizes.weekHistoryDimensionTileWidth, Tokens.Sizes.weekHistoryDimensionTileHeight)
                    .clip(shape(i))
                    .clickable(role = Role.Button) { nav.photo(week.weekStart.toString(), photo.post.id) }
                    .clearAndSetSemantics { contentDescription = label; role = Role.Button },
            ) {
                RemotePhoto(photo.thumbPath, null, Modifier.fillMaxSize())
                Line(
                    Formats.weekdayShort(day),
                    Type.style(Tokens.FontSizes.weekHistoryFontSizeWeekday, Tokens.FontWeights.weekHistoryFontWeightWeekday),
                    Tokens.Colors.globalTextPrimary,
                    Modifier.align(Alignment.BottomCenter).paddingFromBaseline(bottom = Tokens.Sizes.weekHistoryDimensionWeekdayBaseline),
                )
            }
        }
        if (showAdd) item(key = "add") {
            val label = stringRes(R.string.week_history_a11y_add)
            val i = week.photos.size
            Box(
                Modifier.size(Tokens.Sizes.weekHistoryDimensionTileWidth, Tokens.Sizes.weekHistoryDimensionTileHeight).clip(shape(i)).background(fill)
                    .clickable(role = Role.Button, onClick = nav.camera).clearAndSetSemantics { contentDescription = label; role = Role.Button },
                contentAlignment = Alignment.Center,
            ) { InkGlyph(Tokens.Icons.weekHistoryIconAdd, Tokens.Colors.globalTextPrimary, inkHeight = Tokens.Sizes.weekHistoryDimensionAddGlyph) }
        }
        itemsIndexed(emptyDays, key = { _, d -> "empty:$d" }) { j, day ->
            EmptyDayTile(day, fill, ink, shape(week.photos.size + 1 + j))
        }
    }
}

/** An empty day of the current week: month, day number (bold), weekday, in `week.history.color.emptyTileText` on `.emptyTile`. */
@Composable
private fun EmptyDayTile(day: LocalDate, fill: androidx.compose.ui.graphics.Color, ink: androidx.compose.ui.graphics.Color, shape: RoundedCornerShape) {
    val label = stringRes(R.string.week_history_a11y_emptyday, Formats.weekdayLong(day), Formats.spokenDate(day))
    val small = Type.style(Tokens.FontSizes.weekHistoryFontSizeEmptyDayLabel)
    Column(
        Modifier.size(Tokens.Sizes.weekHistoryDimensionTileWidth, Tokens.Sizes.weekHistoryDimensionTileHeight).clip(shape).background(fill).clearAndSetSemantics { contentDescription = label },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Line(day.month.getDisplayName(java.time.format.TextStyle.SHORT, java.util.Locale.getDefault()), small, ink)
        Line(day.dayOfMonth.toString(), Type.style(Tokens.FontSizes.weekHistoryFontSizeEmptyDay, androidx.compose.ui.text.font.FontWeight.Bold), ink)
        Line(Formats.weekdayShort(day), small, ink)
    }
}

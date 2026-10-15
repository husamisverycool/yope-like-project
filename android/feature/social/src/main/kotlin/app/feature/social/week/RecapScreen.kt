// Surface: week.recap — Sunday recap of the group's week.
// References: references/owner/yope-week-recap.jpg (primary: header, recap card grid, label, page dots,
// pics grid, floating "recap | pics" capsule), references/auto/yope/frames/b-alexaa-7652512140875566349-t5.33-day-view-recap.png.
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
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFromBaseline
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.designsystem.R
import app.designsystem.dsAnimateDpAsState
import app.designsystem.generated.Tokens
import app.designsystem.rememberReduceMotion
import app.feature.social.common.EmptyState
import app.feature.social.common.Formats
import app.feature.social.common.HeaderCircle
import app.feature.social.common.Line
import app.feature.social.common.LoadingHud
import app.feature.social.common.PillAction
import app.feature.social.common.RemotePhoto
import app.feature.social.common.SocialBlocked
import app.feature.social.common.Type
import app.feature.social.common.rememberHaptics
import app.feature.social.common.stringRes
import app.ui.components.HeaderCircleFill
import kotlinx.coroutines.launch

/** Where the recap leads. */
data class RecapNav(
    val back: () -> Unit,
    val edit: (recapId: String) -> Unit,
    val cardPhoto: (recapId: String, postId: String) -> Unit,
    val weekPhoto: (weekStart: String, postId: String) -> Unit,
    val camera: () -> Unit,
)

@Composable
fun WeekRecapScreen(vm: RecapViewModel, nav: RecapNav) {
    val state by vm.state.collectAsStateWithLifecycle()
    WeekRecapContent(state, nav, onRetry = vm::load)
}

/** Recap screen without its view model (snapshots). */
@Composable
fun WeekRecapContent(state: RecapState, nav: RecapNav, onRetry: () -> Unit, gridState: LazyGridState = rememberLazyGridState()) {
    val recap = state.recap
    Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackground).testTag("week.recap")) {
        val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding() + Tokens.Sizes.globalHeaderButton
        when (state.phase) {
            RecapState.Phase.Loading -> LoadingHud()
            RecapState.Phase.Pending -> Centered { Line(stringRes(R.string.week_recap_pending), Type.emptyTitle(), Tokens.Colors.globalTextPrimary, maxLines = Int.MAX_VALUE) }
            RecapState.Phase.Empty -> Centered {
                EmptyState(stringRes(R.string.week_recap_empty_title), stringRes(R.string.week_recap_empty_detail), PillAction(stringRes(R.string.week_recap_empty_action), Tokens.Icons.globalCamera, nav.camera))
            }
            RecapState.Phase.Error -> Centered {
                EmptyState(stringRes(R.string.week_recap_error_title), stringRes(R.string.chat_thread_error_detail), PillAction(stringRes(R.string.chat_thread_error_retry), null, onRetry))
            }
            RecapState.Phase.OfflineEmpty -> Centered { EmptyState(stringRes(R.string.chat_thread_offline_title), stringRes(R.string.chat_thread_offline_detail), null) }
            RecapState.Phase.Ready -> if (recap != null) RecapBody(state, recap.id, recap.weekStart, nav, top, gridState)
        }
        RecapHeader(state, nav)
        if (state.phase == RecapState.Phase.Ready) SegmentedCapsule(gridState, Modifier.align(Alignment.BottomCenter))
    }
}

@Composable
private fun Centered(content: @Composable () -> Unit) = Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { content() }

/** Header (floats): ‹ circle · week label (`week.recap.fontSize.title`) · pencil circle (ready recaps only). */
@Composable
private fun RecapHeader(state: RecapState, nav: RecapNav) {
    val recap = state.recap
    Box(Modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.statusBars).padding(horizontal = Tokens.Sizes.globalHeaderInset).height(Tokens.Sizes.globalHeaderButton)) {
        HeaderCircle(Tokens.Icons.globalBack, stringRes(R.string.chat_thread_a11y_back), HeaderCircleFill.OnDeep, nav.back, Modifier.align(Alignment.CenterStart))
        if (recap != null && state.phase == RecapState.Phase.Ready) {
            Line(
                Formats.recapWeek(recap.weekStart),
                Type.style(Tokens.FontSizes.weekRecapFontSizeTitle, Tokens.FontWeights.weekRecapFontWeightTitle),
                Tokens.Colors.globalTextPrimary,
                Modifier.align(Alignment.Center).semantics { heading() },
            )
            HeaderCircle(Tokens.Icons.globalEdit, stringRes(R.string.week_recap_a11y_edit), HeaderCircleFill.OnDeep, { nav.edit(recap.id) }, Modifier.align(Alignment.CenterEnd))
        }
    }
}

/** Index of the first pics-grid item in the grid (after the card and the dots row). */
private const val PICS_START = 2

@Composable
private fun RecapBody(state: RecapState, recapId: String, weekStart: java.time.LocalDate, nav: RecapNav, top: androidx.compose.ui.unit.Dp, gridState: LazyGridState) {
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + Tokens.Sizes.weekRecapDimensionSegmentedBottom + Tokens.Sizes.weekRecapDimensionSegmentedHeight
    LazyVerticalGrid(
        columns = GridCells.Fixed(Tokens.Counts.weekRecapCountPicsColumns),
        state = gridState,
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(top = top, bottom = bottom),
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.weekRecapDimensionPicsGap),
        verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.weekRecapDimensionPicsGap),
    ) {
        item(key = "card", span = { GridItemSpan(maxLineSpan) }) {
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.TopCenter) { RecapCard(state, recapId, weekStart, nav) }
        }
        item(key = "dots", span = { GridItemSpan(maxLineSpan) }) {
            // Page 2 is BLOCKED (`week.recap.layout.page2`): one page, dots hidden; their row keeps its place.
            val gap = Tokens.Sizes.weekRecapDimensionCardToDots + Tokens.Sizes.weekRecapDimensionPageDot + Tokens.Sizes.weekRecapDimensionDotsToPics - Tokens.Sizes.weekRecapDimensionPicsGap * 2
            Box(Modifier.fillMaxWidth().height(gap.coerceAtLeast(0.dp)), contentAlignment = Alignment.Center) {
                if (SocialBlocked.recapPage2) PageDots(pages = 2, current = 0)
            }
        }
        itemsIndexed(state.pics, key = { _, p -> "pic:" + p.post.id }) { _, photo ->
            val label = stringRes(R.string.photo_viewer_a11y_photo, photo.authorName.orEmpty(), Formats.viewerDate(photo.post.createdAt))
            RemotePhoto(
                photo.thumbPath,
                null,
                Modifier.fillMaxWidth().aspectRatio(Tokens.AspectRatios.weekRecapAspectRatioPicsTile)
                    .clickable(role = Role.Button) { nav.weekPhoto(weekStart.toString(), photo.post.id) }
                    .clearAndSetSemantics { contentDescription = label; role = Role.Button },
            )
        }
    }
}

/**
 * The recap card (`week.recap.dimension.cardWidth`, `.radius.card`): full rows of
 * `week.recap.count.gridColumns` tiles (`.aspectRatio.gridTile`, gap `.dimension.gridGap`) in recap
 * order, and the uppercase week label. The row holding the leftover 1–2 photos (first, full width)
 * has a BLOCKED split and height (`week.recap.layout.shortRowSplit`, `.dimension.shortRowHeight`):
 * those photos are left out of the card (they stay in the pics grid). The label's scrim is BLOCKED.
 */
@Composable
private fun RecapCard(state: RecapState, recapId: String, weekStart: java.time.LocalDate, nav: RecapNav) {
    val columns = Tokens.Counts.weekRecapCountGridColumns
    val leftover = state.card.size % columns
    val shortHeight = SocialBlocked.recapShortRowHeight
    val shortRow = if (SocialBlocked.recapShortRowSplit && shortHeight != null) state.card.take(leftover) else emptyList()
    val rows = state.card.drop(leftover).chunked(columns)
    if (rows.isEmpty() && shortRow.isEmpty()) return
    val weekLabel = Formats.recapWeek(weekStart)
    val cardLabel = stringRes(R.string.week_recap_a11y_card, weekLabel)
    val gap = Tokens.Sizes.weekRecapDimensionGridGap
    Box(
        Modifier
            .width(Tokens.Sizes.weekRecapDimensionCardWidth)
            .clip(RoundedCornerShape(Tokens.Radii.weekRecapRadiusCard))
            .semantics(mergeDescendants = false) { contentDescription = cardLabel },
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(gap)) {
            if (shortRow.isNotEmpty() && shortHeight != null) {
                Row(Modifier.fillMaxWidth().height(shortHeight), horizontalArrangement = Arrangement.spacedBy(gap)) {
                    shortRow.forEach { photo -> CardTile(photo, Modifier.weight(1f).fillMaxSize()) { nav.cardPhoto(recapId, photo.post.id) } }
                }
            }
            rows.forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                    row.forEach { photo ->
                        CardTile(photo, Modifier.weight(1f).aspectRatio(Tokens.AspectRatios.weekRecapAspectRatioGridTile)) { nav.cardPhoto(recapId, photo.post.id) }
                    }
                    repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
        Line(
            Formats.recapWeek(weekStart, label = true),
            Type.style(Tokens.FontSizes.weekRecapFontSizeLabel, Tokens.FontWeights.weekRecapFontWeightLabel),
            Tokens.Colors.globalTextPrimary,
            Modifier
                .align(Alignment.BottomStart)
                .padding(start = Tokens.Sizes.weekRecapDimensionLabelInsetLeading)
                .paddingFromBaseline(bottom = Tokens.Sizes.weekRecapDimensionLabelBaselineBottom)
                .clearAndSetSemantics { },
        )
    }
}

@Composable
private fun CardTile(photo: WeekPhoto, modifier: Modifier, onClick: () -> Unit) {
    val label = stringRes(R.string.photo_viewer_a11y_photo, photo.authorName.orEmpty(), Formats.viewerDate(photo.post.createdAt))
    RemotePhoto(photo.thumbPath, null, modifier.clickable(role = Role.Button, onClick = onClick).clearAndSetSemantics { contentDescription = label; role = Role.Button })
}

/** Page dots (`week.recap.dimension.pageDot` at `.pageDotPitch`; current `color.global.textPrimary`, others `color.global.controlRaised`). */
@Composable
private fun PageDots(pages: Int, current: Int) {
    val dot = Tokens.Sizes.weekRecapDimensionPageDot
    Row(horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.weekRecapDimensionPageDotPitch - dot)) {
        repeat(pages) { i ->
            Box(Modifier.size(dot).clip(CircleShape).background(if (i == current) Tokens.Colors.globalTextPrimary else Tokens.Colors.globalControlRaised))
        }
    }
}

/**
 * The floating "recap | pics" capsule (`week.recap.dimension.segmented*`): "recap" scrolls to the
 * card, "pics" to the pics grid; scrolling updates the selection (approximation). The pill moves
 * with the platform default spring (`spring.global.platformDefault.android`) and jumps under Reduce
 * Motion; the scroll animates with the system scroll animation unless Reduce Motion is on.
 */
@Composable
private fun SegmentedCapsule(gridState: LazyGridState, modifier: Modifier = Modifier) {
    val scope = rememberCoroutineScope()
    val haptics = rememberHaptics()
    val reduceMotion by rememberReduceMotion()
    val onPics by remember { derivedStateOf { gridState.firstVisibleItemIndex >= PICS_START } }
    val inset = Tokens.Sizes.weekRecapDimensionSegmentedInset
    val pillWidth = Tokens.Sizes.weekRecapDimensionSegmentedPillWidth
    val trackWidth = Tokens.Sizes.weekRecapDimensionSegmentedWidth
    val pillX by dsAnimateDpAsState(
        if (onPics) trackWidth - inset - pillWidth else inset,
        Tokens.Springs.globalPlatformDefaultAndroid.spec(),
        label = "segment",
    )
    val labels = listOf(stringRes(R.string.week_recap_segment_recap), stringRes(R.string.week_recap_segment_pics))
    val style = Type.style(Tokens.FontSizes.weekRecapFontSizeSegmented, Tokens.FontWeights.weekRecapFontWeightSegmented)
    Box(
        modifier
            .windowInsetsPadding(WindowInsets.navigationBars)
            .padding(bottom = Tokens.Sizes.weekRecapDimensionSegmentedBottom)
            .size(trackWidth, Tokens.Sizes.weekRecapDimensionSegmentedHeight)
            .clip(CircleShape)
            .background(Tokens.Colors.globalControl),
    ) {
        Box(
            Modifier
                .offset(x = pillX)
                .align(Alignment.CenterStart)
                .size(pillWidth, Tokens.Sizes.weekRecapDimensionSegmentedPillHeight)
                .clip(CircleShape)
                .background(Tokens.Colors.globalSurfaceLight),
        )
        Row(Modifier.fillMaxSize()) {
            labels.forEachIndexed { i, label ->
                val isSelected = (i == 1) == onPics
                Box(
                    Modifier
                        .weight(1f)
                        .fillMaxSize()
                        .clickable(role = Role.Tab) {
                            if (isSelected) return@clickable
                            haptics.play(Tokens.Haptics.globalSelect)
                            scope.launch {
                                val target = if (i == 0) 0 else PICS_START
                                if (reduceMotion) gridState.scrollToItem(target) else gridState.animateScrollToItem(target)
                            }
                        }
                        .semantics { selected = isSelected; role = Role.Tab },
                    contentAlignment = Alignment.Center,
                ) {
                    Line(label, style, if (isSelected) Tokens.Colors.globalOnSurfaceLight else Tokens.Colors.globalTextPrimary)
                }
            }
        }
    }
}

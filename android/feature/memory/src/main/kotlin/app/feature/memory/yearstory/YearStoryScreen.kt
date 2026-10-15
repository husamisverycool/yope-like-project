// Surface: year.story — design/surfaces/year.story.md
// References: references/auto/wrapped/frames/wrapped24-rec-emilycraig-t020.png (+ -bars-zoom2x, reveal frames, sheet-every3s),
// references/auto/wrapped/press/wrapped24-press-minutes.jpg, wrapped24-press-summary-sharecard.jpg,
// wrapped25-press-minutes.png, wrapped25-press-sharecards.png, wrapped25-press-entrypoints.png,
// references/auto/wrapped/frames/wrapped25-rec-cdragon2010-t004.800.png, -t258.000.png,
// references/auto/wrapped/frames/wrapped24-rec-xenarxoxo-sheet-every3s.png.
package app.feature.memory.yearstory

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PagerState
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.min
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.memory.common.GlyphIcon
import app.designsystem.scaledDp
import app.feature.memory.common.HeaderCircleButton
import app.feature.memory.common.MemoryBlocked
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.MessageBlock
import app.feature.memory.common.PlatformSpinner
import app.feature.memory.common.PreloadImages
import app.feature.memory.common.findActivity
import app.feature.memory.common.tokenColor
import app.feature.memory.common.rememberMemoryBackend
import app.feature.memory.common.roleStyle
import app.feature.memory.common.touchOutset
import app.feature.memory.share.MemoryFiles
import kotlinx.coroutines.launch
import java.time.Clock

/** Test tags of the player (flow tests). */
object YearStoryTags {
    const val ROOT = "year.story"
    const val CANVAS = "year.story.canvas"
    const val SHARE_ROW = "year.story.share"
    const val SHARE_PILL = "year.story.summary.share"
    const val REPLAY = "year.story.summary.replay"
}

/** The canvas size: 9:16, screen width, never taller than the safe area (`layout.year.story.canvas`). */
private fun canvasSize(maxWidth: Dp, maxHeight: Dp): Pair<Dp, Dp> {
    val canvas = Tokens.Layouts.YearStoryCanvas
    val width = min(maxWidth, maxHeight * canvas.aspectWidth / canvas.aspectHeight)
    return width to width * canvas.aspectHeight / canvas.aspectWidth
}

/**
 * The full-screen player: letterbox, 9:16 canvas, progress segments, close chrome, the card, its
 * share row on fact cards; the summary card ends the story. Tap right / left half for next /
 * previous; no auto-advance while `duration.year.story.card` is BLOCKED.
 */
@Composable
fun YearStoryScreen(
    state: YearStoryState,
    onNext: () -> Unit,
    onPrevious: () -> Unit,
    onReplay: () -> Unit,
    onRetry: () -> Unit,
    onClose: () -> Unit,
    onShare: (StoryCard) -> Unit,
    modifier: Modifier = Modifier,
    onTogglePause: () -> Unit = {},
    sharing: Boolean = false,
    shareHost: @Composable (canvasWidth: Dp) -> Unit = {},
) {
    Box(modifier.fillMaxSize().background(Tokens.Colors.yearStoryLetterbox).testTag(YearStoryTags.ROOT)) {
        BoxWithConstraints(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing), contentAlignment = Alignment.Center) {
            val (width, height) = canvasSize(maxWidth, maxHeight)
            Box(Modifier.size(width, height).background(Tokens.Colors.globalBackgroundDeep).clipToBounds()) {
                when (state) {
                    YearStoryState.Loading -> Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                        PlatformSpinner()
                        Spacer(Modifier.size(Tokens.Sizes.globalListGap))
                        BasicText(
                            stringResource(R.string.year_story_loading),
                            style = roleStyle(Tokens.FontSizes.globalListSubtitle, Tokens.FontWeights.fontWeightGlobalListSubtitle).copy(color = Tokens.Colors.globalTextSecondary),
                        )
                    }
                    is YearStoryState.Failed -> MessageBlock(
                        stringResource(if (state.offline) R.string.year_story_offline_title else R.string.year_story_error_title),
                        stringResource(if (state.offline) R.string.year_story_offline_detail else R.string.year_story_error_detail),
                        Modifier.fillMaxSize(),
                        action = stringResource(R.string.year_story_error_retry),
                        onAction = onRetry,
                    )
                    is YearStoryState.Story -> Story(state, width, height, onNext, onPrevious, onReplay, onShare, sharing)
                }
                Chrome(onClose, paused = (state as? YearStoryState.Story)?.paused, onTogglePause = onTogglePause)
            }
            shareHost(width)
        }
    }
}

@Composable
private fun Story(
    state: YearStoryState.Story,
    width: Dp,
    height: Dp,
    onNext: () -> Unit,
    onPrevious: () -> Unit,
    onReplay: () -> Unit,
    onShare: (StoryCard) -> Unit,
    sharing: Boolean,
) {
    val next by rememberUpdatedState(onNext)
    val previous by rememberUpdatedState(onPrevious)
    val nextLabel = stringResource(R.string.year_story_a11y_next)
    val previousLabel = stringResource(R.string.year_story_a11y_previous)
    val card = state.card
    // The next cards' images load before the tap (no image pops in after a card change).
    PreloadImages(state.cards.drop(state.index + 1).take(PRELOAD_AHEAD).mapNotNull(::imageUrl))
    Box(
        Modifier
            .fillMaxSize()
            .testTag(YearStoryTags.CANVAS)
            // layout.year.story.navigation: right half → next, left half → previous (first card: nothing).
            .pointerInput(Unit) { detectTapGestures { offset -> if (offset.x >= size.width / 2f) next() else previous() } }
            .semantics {
                customActions = buildList {
                    if (state.index < state.cards.lastIndex) add(CustomAccessibilityAction(nextLabel) { next(); true })
                    if (state.index > 0) add(CustomAccessibilityAction(previousLabel) { previous(); true })
                }
            },
    ) {
        if (card == StoryCard.Summary) {
            Summary(state.shareCards, width, height, onReplay, onShare, sharing)
        } else {
            StoryCardContent(card, width, height, revealed = false)
        }
        if (card.shareable) ShareRow(enabled = !sharing) { onShare(card) }
        Progress(state.cards.size, state.index, rememberCardProgress(state, onNext))
    }
}

/**
 * How far the current card is through `duration.year.story.card` (linear,
 * `easing.year.story.progress.fill`), advancing at the end; the summary waits. While that duration is
 * BLOCKED the current segment shows full and nothing advances on its own (tap-only, M-16). The fill
 * tracks time, so it stays under Reduce Motion.
 */
@Composable
private fun rememberCardProgress(state: YearStoryState.Story, onNext: () -> Unit): () -> Float {
    val duration = MemoryBlocked.yearStoryCardMs ?: return { 1f }
    val next by rememberUpdatedState(onNext)
    val fraction = remember(state.index) { Animatable(0f) }
    LaunchedEffect(state.index, state.paused) {
        if (state.paused || state.card == StoryCard.Summary) return@LaunchedEffect
        val left = ((1f - fraction.value) * duration).toInt()
        fraction.animateTo(1f, tween(left, easing = Tokens.Easings.yearStoryProgressFill))
        next()
    }
    return { fraction.value }
}

/** How many cards ahead have their images loaded. */
private const val PRELOAD_AHEAD = 2

private fun imageUrl(card: StoryCard): String? = when (card) {
    is StoryCard.MostReactedPhoto -> card.url
    is StoryCard.TogetherDay -> card.url
    else -> null
}

/** One segment per card; completed and current filled, upcoming white at the track opacity. */
@Composable
private fun Progress(count: Int, index: Int, current: () -> Float) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(top = Tokens.Sizes.yearStoryProgressTop, start = Tokens.Sizes.yearStoryProgressInset, end = Tokens.Sizes.yearStoryProgressInset)
            .clearAndSetSemantics { },
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.yearStoryProgressGap),
    ) {
        repeat(count) { i ->
            Box(
                Modifier
                    .weight(1f)
                    .height(Tokens.Sizes.yearStoryProgressHeight)
                    .background(
                        if (i < index) Tokens.Colors.yearStoryProgressFill
                        else Tokens.Colors.yearStoryProgressFill.copy(alpha = Tokens.Opacities.yearStoryProgressTrack),
                    )
                    .then(
                        if (i == index) {
                            Modifier.drawBehind {
                                drawRect(Tokens.Colors.yearStoryProgressFill, size = size.copy(width = size.width * current()))
                            }
                        } else {
                            Modifier
                        },
                    ),
            )
        }
    }
}

/**
 * Chrome row: the close circle, right-aligned. The pause circle is not shown while
 * `duration.year.story.card` is BLOCKED (no auto-advance to pause, M-16); no sound toggle (M-18).
 */
@Composable
private fun Chrome(onClose: () -> Unit, paused: Boolean?, onTogglePause: () -> Unit) {
    val circle = Tokens.Sizes.yearStoryChromeButton
    val touch = circle + touchOutset(circle) * 2
    Box(Modifier.fillMaxWidth()) {
        if (MemoryBlocked.yearStoryCardMs != null && paused != null) {
            HeaderCircleButton(
                icon = if (paused) Tokens.Icons.globalPlay else Tokens.Icons.yearStoryPause,
                contentDescription = stringResource(if (paused) R.string.year_story_a11y_play else R.string.year_story_a11y_pause),
                onClick = onTogglePause,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(
                        end = Tokens.Sizes.yearStoryChromeInsetRight - touchOutset(circle) + Tokens.Sizes.yearStoryChromePitch,
                        top = Tokens.Sizes.yearStoryChromeCenterY - touch / 2,
                    ),
                diameter = circle,
                fill = Tokens.Colors.yearStoryChromeFill,
                glyph = Tokens.Sizes.yearStoryChromeGlyph,
            )
        }
        HeaderCircleButton(
            icon = Tokens.Icons.globalClose,
            contentDescription = stringResource(R.string.year_story_a11y_close),
            onClick = onClose,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(end = Tokens.Sizes.yearStoryChromeInsetRight - touchOutset(circle), top = Tokens.Sizes.yearStoryChromeCenterY - touch / 2),
            diameter = circle,
            fill = Tokens.Colors.yearStoryChromeFill,
            glyph = Tokens.Sizes.yearStoryChromeGlyph,
        )
    }
}

/** "Share this story" row at the canvas bottom on fact cards. */
@Composable
private fun androidx.compose.foundation.layout.BoxScope.ShareRow(enabled: Boolean, onClick: () -> Unit) {
    val row = Tokens.Sizes.yearStoryShareRowHeight
    Row(
        Modifier
            .align(Alignment.BottomCenter)
            .padding(bottom = Tokens.Sizes.yearStoryShareBottomInset - touchOutset(row))
            .heightIn(min = row + touchOutset(row) * 2)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .testTag(YearStoryTags.SHARE_ROW),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        GlyphIcon(Tokens.Icons.yearStoryShare, row, Tokens.Colors.globalTextPrimary)
        Spacer(Modifier.size(Tokens.Sizes.yearStoryShareGlyphGap))
        BasicText(
            stringResource(R.string.year_story_share),
            style = roleStyle(Tokens.FontSizes.yearStoryShare, Tokens.FontWeights.fontWeightYearStoryShare, family = Tokens.Fonts.yearStory)
                .copy(color = Tokens.Colors.globalTextPrimary),
        )
    }
}

/**
 * Summary (`layout.year.story.summary`): pager of the story's share cards at `previewWidthRatio` of
 * the canvas, page dots (`layout.year.story.summary.dots`), the Share pill sharing the card in view,
 * then "Replay from beginning".
 */
@Composable
private fun Summary(cards: List<StoryCard>, width: Dp, height: Dp, onReplay: () -> Unit, onShare: (StoryCard) -> Unit, sharing: Boolean) {
    val ratio = Tokens.Layouts.YearStorySummary.previewWidthRatio
    val previewWidth = width * ratio
    val previewHeight = height * ratio
    // Vertical gaps and page spacing: the photo card's text gap, the only vertical gap measured on this surface.
    val gap = Tokens.Layouts.YearStoryPhotoCard.textGap.dp
    val pager: PagerState = rememberPagerState { cards.size }
    val density = LocalDensity.current
    Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        HorizontalPager(
            state = pager,
            modifier = Modifier.fillMaxWidth().height(previewHeight),
            contentPadding = PaddingValues(horizontal = (width - previewWidth) / 2),
            pageSpacing = gap,
        ) { page ->
            Box(Modifier.size(previewWidth, previewHeight).background(Tokens.Colors.globalBackgroundDeep)) {
                // The share image's own layout, scaled to the preview width.
                CompositionLocalProvider(LocalDensity provides Density(density.density * ratio, fontScale = 1f)) {
                    Box(Modifier.requiredSize(width, height)) { StoryCardContent(cards[page], width, height, revealed = true) }
                }
            }
        }
        if (MemoryBlocked.YEAR_STORY_SUMMARY_DOTS) {
            // layout.year.story.summary.dots: one per share card, centres 20.4 below the card and 29.3 above the pill.
            val dots = Tokens.Layouts.YearStorySummaryDots
            Spacer(Modifier.size((dots.centerBelowCarousel - dots.diameter / 2).dp))
            Row(Modifier.clearAndSetSemantics { }, horizontalArrangement = Arrangement.spacedBy((dots.pitch - dots.diameter).dp)) {
                repeat(cards.size) { i ->
                    Box(
                        Modifier
                            .size(dots.diameter.dp)
                            .clip(CircleShape)
                            .background(tokenColor(if (i == pager.currentPage) dots.selectedColor else dots.unselectedColor)),
                    )
                }
            }
            Spacer(Modifier.size((dots.centerAboveShare - dots.diameter / 2).dp))
        } else {
            Spacer(Modifier.size(gap))
        }
        Box(
            Modifier
                .widthIn(min = Tokens.Sizes.yearStorySummaryShareWidth)
                .heightIn(min = Tokens.Sizes.yearStorySummaryShareHeight)
                .clip(CircleShape)
                .background(Tokens.Colors.globalSurfaceLight)
                .clickable(enabled = !sharing && cards.isNotEmpty(), role = Role.Button) { onShare(cards[pager.currentPage]) }
                .testTag(YearStoryTags.SHARE_PILL),
            contentAlignment = Alignment.Center,
        ) {
            BasicText(
                stringResource(R.string.year_story_summary_share),
                style = roleStyle(Tokens.FontSizes.yearStorySharePill, Tokens.FontWeights.fontWeightYearStorySharePill, family = Tokens.Fonts.yearStory)
                    .copy(color = Tokens.Colors.globalOnSurfaceLight),
            )
        }
        Spacer(Modifier.size(gap))
        Row(
            Modifier
                .heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid)
                .clickable(role = Role.Button, onClick = onReplay)
                .testTag(YearStoryTags.REPLAY),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            val body = roleStyle(Tokens.FontSizes.yearStoryBody, Tokens.FontWeights.fontWeightYearStoryBody, family = Tokens.Fonts.yearStory)
            Icon(Tokens.Icons.yearStoryReplay, contentDescription = null, tint = Tokens.Colors.globalTextPrimary, modifier = Modifier.size(scaledDp(Tokens.FontSizes.yearStoryBody)))
            Spacer(Modifier.size(Tokens.Sizes.globalHeaderGap))
            BasicText(stringResource(R.string.year_story_summary_replay), style = body.copy(color = Tokens.Colors.globalTextPrimary))
        }
    }
}

/** The year-story destination: loads the story, hides the system bars, renders and shares cards. */
@Composable
fun YearStoryDestination(
    groupId: String,
    year: Int,
    onClose: () -> Unit,
    backend: MemoryBackend = rememberMemoryBackend(),
    clock: Clock = Clock.systemUTC(),
) {
    val vm = viewModel(key = "year.story/$groupId/$year") { YearStoryViewModel(groupId, year, backend, clock) }
    val state by vm.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val view = LocalView.current
    // Android: full screen, system bars hidden with transient reveal (design/surfaces/year.story.md, Platform notes).
    DisposableEffect(view) {
        val window = view.context.findActivity()?.window
        val controller = window?.let { WindowCompat.getInsetsController(it, view) }
        controller?.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        controller?.hide(WindowInsetsCompat.Type.systemBars())
        onDispose { controller?.show(WindowInsetsCompat.Type.systemBars()) }
    }
    val exporter = rememberShareCardExporter()
    val scope = rememberCoroutineScope()
    YearStoryScreen(
        state = state,
        onNext = vm::next,
        onPrevious = vm::previous,
        onReplay = vm::replay,
        onRetry = vm::retry,
        onClose = onClose,
        onTogglePause = vm::togglePause,
        onShare = { card ->
            if (!exporter.busy) scope.launch {
                val story = state as? YearStoryState.Story
                val index = story?.cards?.indexOf(card) ?: 0
                val uri = exporter.export(context, card, "year-story-$groupId-$year-$index") ?: return@launch
                context.startActivity(MemoryFiles.shareIntent(uri, MemoryFiles.MIME_PNG))
            }
        },
        sharing = exporter.busy,
        shareHost = { width -> ShareCardHost(exporter, width) },
    )
}

// Surface: year.story — design/surfaces/year.story.md ("Year in Photos" on Retro's recap preview)
// References: references/auto/retro/store/retro-store-04.png (ST-04), references/auto/retro/press/tc-2023-12-recaps.png (TC-REC),
// references/auto/retro/press/tc-2023-12-retro-header.png (TC-H); mechanics references/auto/wrapped/frames/wrapped24-rec-emilycraig-sheet-every3s.png.
package app.feature.memory.yearstory

import android.view.accessibility.AccessibilityManager
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.key
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.LayoutDirection
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.memory.common.LightSystemBarIcons
import app.feature.memory.common.MediaAppearance
import app.feature.memory.common.MediaMessage
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.MemoryFormats
import app.feature.memory.common.PreloadImages
import app.feature.memory.common.memoryModel
import app.feature.memory.common.rememberMemoryBackend
import app.feature.memory.share.MemoryFiles
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.components.EmptyStateFill
import app.ui.components.LoadingState
import app.ui.components.PositionPill
import app.ui.recap.RecapDots
import app.ui.recap.MediaReportMenu
import app.ui.recap.RecapPill
import app.ui.recap.RecapPreviewScreen
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Test tags of the player (flow tests). */
object YearStoryTags {
    const val ROOT = "year.story"
    const val CARD = "year.story.card"
    const val LEADING = "year.story.leading"
}

/** The player's actions. */
data class YearStoryActions(
    val onNext: () -> Unit = {},
    val onPrevious: () -> Unit = {},
    val onTogglePause: () -> Unit = {},
    val onReplay: () -> Unit = {},
    val onStyle: (Int) -> Unit = {},
    val onShare: (StoryCard, SummaryStyle) -> Unit = { _, _ -> },
    val onRetry: () -> Unit = {},
    val onClose: () -> Unit = {},
    /** "Report Recap" (safety.report, kind `year_story`, MERGE FV-4); null until the story's id is known. */
    val onReport: (() -> Unit)? = null,
)

/**
 * The year story on Retro's recap preview (core:ui `RecapPreviewScreen`, ST-04), dark in both appearances: the
 * rounded media page holds the card — the story's cover blurred behind it (`layout.global.materials.backdrop`) —
 * with the close circle; the position pill top-leading (C-22, hidden on the summary); the bottom row's leading
 * circle (pause / play on cards, replay on the summary) and the white Share pill on fact cards, the outro and the
 * summary (its place stays empty elsewhere). Tap the right half → next card, the left half → previous; auto-advance
 * every `duration.year.story.card` while playing. The summary is a pager of the two share styles with page dots
 * `dimension.year.story.dots.offset` below the page. [shareHost] renders share images off screen.
 */
@Composable
fun YearStoryScreen(
    state: YearStoryState,
    actions: YearStoryActions,
    modifier: Modifier = Modifier,
    sharing: Boolean = false,
    shareHost: @Composable (boxWidth: androidx.compose.ui.unit.Dp) -> Unit = {},
) {
    val closeLabel = stringResource(R.string.year_story_a11y_close)
    MediaAppearance {
        Box(modifier.fillMaxSize().testTag(YearStoryTags.ROOT)) {
            when (state) {
                YearStoryState.Loading -> RecapPreviewScreen(null, 1, 0, {}, actions.onClose, closeLabel, dots = RecapDots.Hidden) {
                    LoadingState(stringResource(R.string.year_story_loading), onMedia = true)
                }
                is YearStoryState.Failed -> RecapPreviewScreen(null, 1, 0, {}, actions.onClose, closeLabel, dots = RecapDots.Hidden) {
                    EmptyStateFill {
                        MediaMessage(
                            stringResource(if (state.offline) R.string.year_story_offline_title else R.string.year_story_error_title),
                            stringResource(if (state.offline) R.string.year_story_offline_detail else R.string.year_story_error_detail),
                            retry = stringResource(R.string.year_story_error_retry),
                            onRetry = actions.onRetry,
                        )
                    }
                }
                is YearStoryState.Story -> Story(state, actions, sharing, closeLabel, shareHost)
            }
        }
    }
}

@Composable
private fun Story(
    state: YearStoryState.Story,
    actions: YearStoryActions,
    sharing: Boolean,
    closeLabel: String,
    shareHost: @Composable (androidx.compose.ui.unit.Dp) -> Unit,
) {
    val card = state.card
    val summary = card == StoryCard.Summary
    val styles = state.recap.styles
    val next by rememberUpdatedState(actions.onNext)
    // Auto-advance while playing; the summary waits. A card change resets the timer.
    LaunchedEffect(state.index, state.paused) {
        if (!state.paused && !summary) {
            delay(Tokens.Durations.yearStoryCard.toLong())
            next()
        }
    }
    // The next cards' images load before they show (no image pops in after a card change).
    PreloadImages(state.cards.drop(state.index + 1).take(PRELOAD_AHEAD).mapNotNull(::imageUrl))
    val shareText = stringResource(R.string.year_story_share)
    val style = styles.getOrElse(state.style) { SummaryStyle.Cover }
    RecapPreviewScreen(
        backdrop = memoryModel(state.recap.coverUrl),
        pageCount = if (summary) styles.size else 1,
        currentPage = if (summary) state.style else 0,
        onPageChange = actions.onStyle,
        onClose = actions.onClose,
        closeContentDescription = closeLabel,
        pill = if (card.shareable) RecapPill(shareText, { actions.onShare(card, style) }, busy = sharing) else null,
        dots = if (summary) RecapDots.BelowPage(Tokens.Sizes.yearStoryDotsOffset) else RecapDots.Hidden,
        swipeEnabled = summary,
        beforeClose = actions.onReport?.let { report ->
            {
                MediaReportMenu(
                    stringResource(R.string.safety_report_menuitem_recap),
                    onReport = {
                        if (!state.paused) actions.onTogglePause()
                        report()
                    },
                )
            }
        },
        topLeading = if (summary) null else {
            {
                val position = stringResource(R.string.year_story_position, MemoryFormats.position(state.position), MemoryFormats.position(state.total))
                PositionPill(position, position, Modifier.padding(start = Tokens.Sizes.yearStoryFramePadding))
            }
        },
        bottomLeading = {
            val (icon, label, onClick) = when {
                summary -> Triple(Tokens.Icons.yearStoryReplay, stringResource(R.string.year_story_summary_replay), actions.onReplay)
                state.paused -> Triple(Tokens.Icons.globalPlay, stringResource(R.string.year_story_a11y_play), actions.onTogglePause)
                else -> Triple(Tokens.Icons.globalPause, stringResource(R.string.year_story_a11y_pause), actions.onTogglePause)
            }
            CircleIconButton(icon, label, onClick, Modifier.padding(start = Tokens.Sizes.globalButtonMarginH).testTag(YearStoryTags.LEADING), style = CircleButtonStyle.OnMedia)
        },
    ) { page ->
        BoxWithConstraints(Modifier.fillMaxSize()) {
            if (summary) {
                SummaryPage(styles[page], state.recap, backdropDrawn = true)
            } else {
                // One card at a time: its reveal and images start fresh on every card (cut between cards).
                key(state.index) { StoryCardPage(card, state.recap, revealed = false, backdropDrawn = true) }
                TapZones(state, actions)
            }
            // One off-screen share renderer, on the page in view.
            if (page == (if (summary) state.style else 0)) shareHost(contentBox(maxWidth, maxHeight).first)
        }
    }
}

/**
 * `layout.year.story.navigation`: right half → next card, left half → previous (first card: nothing); TalkBack: the
 * custom actions `year.story.a11y.next` / `.previous` on the frame.
 */
@Composable
private fun TapZones(state: YearStoryState.Story, actions: YearStoryActions) {
    val next by rememberUpdatedState(actions.onNext)
    val previous by rememberUpdatedState(actions.onPrevious)
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    val nextLabel = stringResource(R.string.year_story_a11y_next)
    val previousLabel = stringResource(R.string.year_story_a11y_previous)
    Box(
        Modifier
            .fillMaxSize()
            .pointerInput(rtl) {
                detectTapGestures { offset ->
                    val trailing = if (rtl) offset.x < size.width / 2f else offset.x >= size.width / 2f
                    if (trailing) next() else previous()
                }
            }
            .semantics {
                customActions = buildList {
                    if (state.index < state.cards.lastIndex) add(CustomAccessibilityAction(nextLabel) { next(); true })
                    if (state.index > 0) add(CustomAccessibilityAction(previousLabel) { previous(); true })
                }
            }
            .testTag(YearStoryTags.CARD),
    )
}

/** How many cards ahead have their images loaded. */
private const val PRELOAD_AHEAD = 2

private fun imageUrl(card: StoryCard): String? = when (card) {
    is StoryCard.Photo -> card.url
    is StoryCard.TogetherDay -> card.url
    else -> null
}

/** The year-story destination: loads the story, renders and shares cards. */
@Composable
fun YearStoryDestination(
    groupId: String,
    year: Int,
    onClose: () -> Unit,
    backend: MemoryBackend = rememberMemoryBackend(),
    onReport: (storyId: String) -> Unit = {},
) {
    val vm = viewModel(key = "year.story/$groupId/$year") { YearStoryViewModel(groupId, year, backend) }
    val state by vm.state.collectAsStateWithLifecycle()
    // The story's id for "Report Recap", once a story shows.
    val shown = state is YearStoryState.Story
    val storyId by produceState<String?>(null, groupId, year, shown) {
        if (shown && value == null) value = runCatching { backend.yearStory(groupId, year)?.id }.getOrNull()
    }
    val context = LocalContext.current
    LightSystemBarIcons()
    // TalkBack running: start paused (auto-advance would cut speech; WCAG 2.2.2).
    LaunchedEffect(vm) {
        val a11y = context.getSystemService(AccessibilityManager::class.java)
        if (a11y?.isTouchExplorationEnabled == true) vm.pause()
    }
    val exporter = rememberShareCardExporter()
    val scope = rememberCoroutineScope()
    val previewTitle = (state as? YearStoryState.Story)?.let { stringResource(R.string.year_story_entry_subtitle, it.recap.year.toString()) }
    YearStoryScreen(
        state = state,
        actions = YearStoryActions(
            onNext = vm::next,
            onPrevious = vm::previous,
            onTogglePause = vm::togglePause,
            onReplay = vm::replay,
            onStyle = vm::showStyle,
            onShare = { card, style ->
                val story = state as? YearStoryState.Story
                if (!exporter.busy && story != null) scope.launch {
                    val index = story.cards.indexOf(card)
                    val uri = exporter.export(context, card, style, story.recap, "year-story-$groupId-$year-$index-${style.name}") ?: return@launch
                    context.startActivity(MemoryFiles.shareIntent(uri, MemoryFiles.MIME_PNG, title = previewTitle))
                }
            },
            onRetry = vm::retry,
            onClose = onClose,
            onReport = storyId?.let { id -> { onReport(id) } },
        ),
        sharing = exporter.busy,
        shareHost = { width -> ShareCardHost(exporter, width) },
    )
}

// Surface: onthisday — design/surfaces/onthisday.md (Retro Rewind)
// References: references/auto/retro/press/tc-2025-12-rewind-device-b.jpg (RWB), references/auto/retro/press/tc-2025-12-rewind-device-a.png (RWA),
// references/auto/retro/press/tc-2025-12-rewind-panels.png (RWP), references/auto/retro/store/retro-store-05.png (ST-05).
package app.feature.memory.onthisday

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.layout
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.isTraversalGroup
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.traversalIndex
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.coerceAtLeast
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.max
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.memory.common.MediaAppearance
import app.feature.memory.common.MediaMessage
import app.feature.memory.common.MemoryFormats
import app.feature.memory.common.MemoryImage
import app.feature.memory.common.PreloadImages
import app.feature.memory.common.SystemAppearance
import app.feature.memory.common.centredSlot
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.components.EmptyState
import app.ui.components.EmptyStateFill
import app.ui.components.HeaderIconButton
import app.ui.components.LoadingState
import app.ui.components.TickOnStep
import app.ui.foundation.FadeVisibility
import app.ui.foundation.GlyphInk
import app.ui.foundation.PhotoScrimOverlay
import app.ui.foundation.centreAt
import app.ui.foundation.endAtLastBaseline
import app.ui.system.DsDropdownMenu
import app.ui.system.DsMenuItem
import app.ui.system.FeatureIntroRow
import app.ui.system.FeatureIntroSheet
import app.ui.system.SystemAlertDialog
import app.ui.text.CapTop
import app.ui.text.TextRoles
import kotlin.math.roundToInt
import kotlinx.coroutines.delay

/** Test tags (flow tests). */
object OnThisDayTags {
    const val ROOT = "onthisday"
    const val TITLE = "onthisday.title"
    const val SHARE = "onthisday.share"
    const val SHUFFLE = "onthisday.shuffle"
    const val MORE = "onthisday.more"
    const val MODE = "onthisday.mode"
}

/** The page's actions (one object, so the screen's signature stays readable). */
data class OnThisDayActions(
    val onStep: (Int) -> Unit = {},
    val onTogglePlay: () -> Unit = {},
    val onAdvance: () -> Unit = {},
    val onShuffle: () -> Unit = {},
    /** Mode menu "On this day…": back to the day's memories (from shuffle). */
    val onShowDay: () -> Unit = {},
    val onShare: () -> Unit = {},
    val onSave: () -> Unit = {},
    val onDelete: () -> Unit = {},
    val onReport: () -> Unit = {},
    val onRetry: () -> Unit = {},
    val onBack: () -> Unit = {},
    val onIntroDone: () -> Unit = {},
    val onDismissSaveDenied: () -> Unit = {},
    val onOpenSettings: () -> Unit = {},
)

/**
 * The Rewind page (design/surfaces/onthisday.md B), dark in both appearances: the memory full bleed under the
 * status bar (aspect fill, `radius.global.photo`, no top scrim), the C-02 header on media (back chevron, the date in
 * the display serif, the subtitle), the glass "•••" (C-11, `size.global.circleButtonPhoto`) with the native menu,
 * `layout.global.photoScrim`, and the control row (share, dial, random) centred
 * `dimension.onthisday.controls.centerY` above the safe-area bottom with equal gaps. The menu saves every memory (owner
 * decision 28); [isMine] decides the rest of it (yours: Delete; someone else's: Report) and the share circle (yours only —
 * owner decision 12: sharing out of the app is for your own photos). [showIntro]: the feature intro (C-29) over the page.
 */
@Composable
fun OnThisDayScreen(
    state: OnThisDayState,
    actions: OnThisDayActions,
    isMine: (Memory) -> Boolean,
    modifier: Modifier = Modifier,
    showIntro: Boolean = false,
    saveDenied: Boolean = false,
) {
    MediaAppearance {
        Box(modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep).semantics { isTraversalGroup = true }.testTag(OnThisDayTags.ROOT)) {
            when (state) {
                OnThisDayState.Loading -> {
                    LoadingState(stringResource(R.string.onthisday_loading), onMedia = true)
                    Header(null, null, actions.onBack)
                }
                is OnThisDayState.Failed -> {
                    EmptyStateFill {
                        MediaMessage(
                            stringResource(if (state.offline) R.string.onthisday_offline_title else R.string.onthisday_error_title),
                            stringResource(if (state.offline) R.string.onthisday_offline_detail else R.string.onthisday_error_detail),
                            retry = stringResource(R.string.onthisday_error_retry),
                            onRetry = actions.onRetry,
                        )
                    }
                    Header(null, null, actions.onBack)
                }
                OnThisDayState.Empty -> {
                    EmptyStateFill { EmptyState(stringResource(R.string.onthisday_empty_title), null) }
                    Header(null, null, actions.onBack)
                }
                OnThisDayState.Finished -> Unit
                is OnThisDayState.Page -> Page(state, actions, isMine)
            }
        }
        if (showIntro && state is OnThisDayState.Page) {
            SystemAppearance {
                FeatureIntroSheet(
                    title = stringResource(R.string.onthisday_nux_title),
                    // C-29's intro rows carry a glyph: the Rewind glyph (`icon.global.rewind`, Retro's own for this feature).
                    rows = listOf(FeatureIntroRow(Tokens.Icons.globalRewind, stringResource(R.string.onthisday_nux_message, state.groupName))),
                    actionText = stringResource(R.string.onthisday_nux_button),
                    onAction = actions.onIntroDone,
                    onDismissRequest = actions.onIntroDone,
                )
            }
        }
        if (saveDenied) {
            SystemAppearance {
                SystemAlertDialog(
                    title = stringResource(R.string.onthisday_savedenied_title),
                    text = stringResource(R.string.onthisday_savedenied_message),
                    confirmLabel = stringResource(R.string.onthisday_savedenied_button),
                    onConfirm = actions.onOpenSettings,
                    dismissLabel = null,
                    onDismiss = actions.onDismissSaveDenied,
                )
            }
        }
    }
}

@Composable
private fun BoxScope.Page(state: OnThisDayState.Page, actions: OnThisDayActions, isMine: (Memory) -> Boolean) {
    val memory = state.memory
    val advance by rememberUpdatedState(actions.onAdvance)
    // Playing: one memory every `duration.onthisday.playHold`, stopping after the last (the view model decides).
    LaunchedEffect(state.playing, state.index, state.memories.size) {
        if (state.playing) {
            delay(Tokens.Durations.onthisdayPlayHold.toLong())
            advance()
        }
    }
    // One tick per memory change: each slot crossed on the dial and each automatic step (`haptic.global.select`).
    TickOnStep(state.index)
    PreloadImages(state.memories.drop(state.index + 1).take(PRELOAD_AHEAD).mapNotNull { it.displayUrl })
    // Scrubbing cross-fades over `duration.global.crossfade`, playing over `duration.onthisday.memoryChange`.
    val fade = tween<Float>(if (state.playing) Tokens.Durations.onthisdayMemoryChange else Tokens.Durations.globalCrossfade, easing = Tokens.Easings.globalStandard)
    val dateText = MemoryFormats.memoryDate(memory.date)
    Crossfade(targetState = memory, animationSpec = fade, label = "memory") { shown ->
        MemoryImage(
            shown.displayUrl,
            contentDescription = null,
            modifier = Modifier
                .fillMaxSize()
                .clearAndSetSemantics { },
        )
    }
    PhotoScrimOverlay()
    var menuOpen by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    val photoLabel = stringResource(R.string.onthisday_a11y_photo, memory.authorName, dateText)
    // Focus order: header → photo → controls (onthisday.md → Accessibility).
    Box(Modifier.fillMaxSize().semantics { contentDescription = photoLabel; traversalIndex = 0f })
    // The mode menu lives outside the cross-fade (Crossfade keeps a shown memory's content until the memory changes, so
    // state read inside it is not observed); the title row reports where it is and the menu is anchored there.
    var modeMenuOpen by remember { mutableStateOf(false) }
    var pageOrigin by remember { mutableStateOf(Offset.Zero) }
    var titleRow by remember { mutableStateOf<Rect?>(null) }
    Box(Modifier.matchParentSize().onGloballyPositioned { pageOrigin = it.positionInRoot() })
    Crossfade(targetState = memory, animationSpec = fade, label = "memoryTitle") { shown ->
        val subtitle = stringResource(
            if (state.mode == MemoryMode.Shuffle) R.string.onthisday_subtitle_shuffle else R.string.onthisday_subtitle_day,
            shown.authorName,
        )
        Header(
            MemoryFormats.memoryDate(shown.date),
            subtitle,
            actions.onBack,
            showBack = false,
            modeMenu = ModeTitleActions(onOpen = { modeMenuOpen = true }, onPlaced = { titleRow = it }),
        )
    }
    titleRow?.let { row ->
        val density = LocalDensity.current
        Box(
            Modifier
                .offset { IntOffset((row.left - pageOrigin.x).roundToInt(), (row.top - pageOrigin.y).roundToInt()) }
                .size(with(density) { row.width.toDp() }, with(density) { row.height.toDp() }),
        ) {
            SystemAppearance {
                DsDropdownMenu(
                    modeMenuOpen,
                    { modeMenuOpen = false },
                    listOf(
                        DsMenuItem(stringResource(R.string.onthisday_mode_day), actions.onShowDay),
                        DsMenuItem(stringResource(R.string.onthisday_mode_shuffle), actions.onShuffle),
                    ),
                )
            }
        }
    }
    Header(null, null, actions.onBack) {
        Box {
            CircleIconButton(
                Tokens.Icons.globalMore,
                stringResource(R.string.onthisday_a11y_more),
                { menuOpen = true },
                Modifier.testTag(OnThisDayTags.MORE),
                style = CircleButtonStyle.Glass,
            )
            SystemAppearance {
                DsDropdownMenu(
                    menuOpen,
                    { menuOpen = false },
                    buildList {
                        add(DsMenuItem(stringResource(R.string.onthisday_menu_save), actions.onSave))
                        if (isMine(memory)) {
                            add(DsMenuItem(stringResource(R.string.onthisday_menu_delete), { confirmDelete = true }, destructive = true))
                        } else {
                            add(DsMenuItem(stringResource(R.string.onthisday_menu_report), actions.onReport, destructive = true))
                        }
                    },
                )
            }
        }
    }
    Controls(state, actions, canShare = isMine(memory), Modifier.align(Alignment.BottomCenter))
    if (confirmDelete) {
        SystemAppearance {
            SystemAlertDialog(
                title = stringResource(R.string.onthisday_delete_title),
                text = stringResource(R.string.onthisday_delete_message, state.groupName),
                confirmLabel = stringResource(R.string.onthisday_delete_confirm),
                onConfirm = {
                    confirmDelete = false
                    actions.onDelete()
                },
                dismissLabel = stringResource(R.string.onthisday_delete_cancel),
                onDismiss = { confirmDelete = false },
                destructive = true,
            )
        }
    }
}

/** How many memories ahead have their images loaded. */
private const val PRELOAD_AHEAD = 2

/**
 * The header on media (C-02 / C-35): back chevron (`icon.global.back`, ink at `size.global.backInset`, centred on the
 * title's cap middle, `color.global.textOnMedia`); the date [title] `size.global.headerGap` after the chevron's ink,
 * text role `headerTitle` in the display serif, baseline `size.global.titleTop` below the safe-area top; [subtitle]
 * (text role `textButton`, `color.onthisday.subtitle`) its baseline `dimension.onthisday.subtitleBaseline` below the
 * title's; [trailing] (the glass "•••") with its circle `size.global.headerInset` from the right edge, centred on the
 * title's cap middle. With [modeMenu] the title carries the expand chevron (`icon.global.chevronDown`, ink
 * `dimension.onthisday.modeChevron.width` wide, `dimension.onthisday.modeChevron.gap` after the title's ink, centred
 * `dimension.onthisday.modeChevron.drop` below its cap middle — RWA 'May 1, 2019 ⌄') and a tap on either opens the
 * mode menu (native, Material 3 menu).
 */
@Composable
private fun Header(
    title: String?,
    subtitle: String?,
    onBack: () -> Unit,
    showBack: Boolean = true,
    modeMenu: ModeTitleActions? = null,
    trailing: (@Composable () -> Unit)? = null,
) {
    val titleStyle = TextRoles.headerTitle
    val capMiddle = Tokens.Sizes.globalTitleTop - CapTop.height(titleStyle) / 2
    val back = Tokens.Icons.globalBack
    val box = Tokens.Sizes.globalIcon
    val hit = max(Tokens.Sizes.globalHeaderButton, Tokens.Sizes.globalMinTouchTargetAndroid)
    val hitStart = (Tokens.Sizes.globalBackInset - GlyphInk.leading(back, box) - (hit - box) / 2).coerceAtLeast(0.dp)
    val titleStart = Tokens.Sizes.globalBackInset + GlyphInk.width(back, box) + Tokens.Sizes.globalHeaderGap
    val titleEnd = Tokens.Sizes.globalHeaderInset + Tokens.Sizes.globalCircleButtonPhoto + Tokens.Sizes.globalHeaderGap
    Box(Modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.statusBars).semantics { isTraversalGroup = true; traversalIndex = -1f }) {
        if (showBack) {
            Box(Modifier.padding(start = hitStart).centreAt(capMiddle)) {
                HeaderIconButton(back, stringResource(R.string.onthisday_a11y_back), onBack, tint = Tokens.Colors.globalTextOnMedia)
            }
        }
        if (title != null) {
            Column(Modifier.padding(start = titleStart, end = titleEnd)) {
                val titleText = @Composable { modifier: Modifier, onLayout: (TextLayoutResult) -> Unit ->
                    Text(
                        title,
                        style = titleStyle,
                        color = Tokens.Colors.globalTextOnMedia,
                        onTextLayout = onLayout,
                        modifier = modifier
                            .paddingFrom(FirstBaseline, before = Tokens.Sizes.globalTitleTop)
                            .endAtLastBaseline()
                            .semantics {
                                heading()
                                liveRegion = LiveRegionMode.Polite
                            }
                            .testTag(OnThisDayTags.TITLE),
                    )
                }
                if (modeMenu == null) {
                    titleText(Modifier) {}
                } else {
                    ModeTitle(modeMenu, capMiddle, titleText)
                }
                if (subtitle != null) {
                    Text(
                        subtitle,
                        style = TextRoles.textButton,
                        color = Tokens.Colors.onthisdaySubtitle,
                        modifier = Modifier.paddingFrom(FirstBaseline, before = Tokens.Sizes.onthisdaySubtitleBaseline),
                    )
                }
            }
        }
        if (trailing != null) {
            Box(Modifier.align(Alignment.TopEnd).padding(end = Tokens.Sizes.globalHeaderInset).centreAt(capMiddle)) { trailing() }
        }
    }
}

/**
 * What the title does with a mode menu: open it, and report where it is (bounds in the root, down to the date's
 * descent) so the menu anchors under the date.
 */
private class ModeTitleActions(val onOpen: () -> Unit, val onPlaced: (Rect) -> Unit)

/**
 * The date title with the expand chevron after it; the whole row opens the mode menu (Material 3 menu anchored to the
 * title, PLATFORM). The chevron's box is sized so its ink is `dimension.onthisday.modeChevron.width` wide; it starts
 * `dimension.onthisday.modeChevron.gap` after the title and is centred `dimension.onthisday.modeChevron.drop` below the
 * title's cap middle ([capMiddle], from the header's top).
 */
@Composable
private fun ModeTitle(menu: ModeTitleActions, capMiddle: Dp, title: @Composable (Modifier, (TextLayoutResult) -> Unit) -> Unit) {
    val chevron = Tokens.Icons.globalChevronDown
    val ink = GlyphInk.bounds(chevron)
    val box = Tokens.Sizes.onthisdayModeChevronWidth * (chevron.viewportWidth / ink.width)
    // The gap and the drop are measured on the ink: shift the box by the glyph's own side bearing and ink centre.
    val lead = Tokens.Sizes.onthisdayModeChevronGap - GlyphInk.leading(chevron, box)
    val inkCentreBelowBoxCentre = box * ((ink.top + ink.bottom) / 2f / chevron.viewportHeight) - box / 2
    // The row ends at the date's baseline (the subtitle's pitch); the menu goes under the descent, read from the text
    // layout (measured before the row is placed, so no state is needed).
    val belowBaseline = remember { FloatArray(1) }
    Row(
        Modifier
            .onGloballyPositioned { val r = it.boundsInRoot(); menu.onPlaced(r.copy(bottom = r.bottom + belowBaseline[0])) }
            // No ripple: the touch area reaches up to the header's top (the title's baseline padding); the menu itself
            // is the feedback.
            .clickable(interactionSource = null, indication = null, role = Role.DropdownList, onClick = menu.onOpen)
            .semantics(mergeDescendants = true) { heading() }
            .testTag(OnThisDayTags.MODE),
    ) {
        title(Modifier.weight(1f, fill = false)) { belowBaseline[0] = it.size.height - it.lastBaseline }
        Icon(
            chevron,
            contentDescription = null,
            tint = Tokens.Colors.globalTextOnMedia,
            modifier = Modifier
                .offset(x = lead)
                .drawnAt(capMiddle + Tokens.Sizes.onthisdayModeChevronDrop - inkCentreBelowBoxCentre)
                .size(box),
        )
    }
}

/**
 * Draws the element centred on [centreY] (from the row's top) but lays it out with no height, so the title row still
 * ends at the date's last baseline and the subtitle keeps `dimension.onthisday.subtitleBaseline` below it.
 */
private fun Modifier.drawnAt(centreY: Dp): Modifier = layout { measurable, constraints ->
    val placeable = measurable.measure(constraints.copy(minHeight = 0, maxHeight = Constraints.Infinity))
    layout(placeable.width, 0) { placeable.place(0, (centreY.toPx() - placeable.height / 2f).roundToInt()) }
}

/**
 * The control row (`layout.onthisday.controls`): share circle, dial, random circle with equal gaps across the width
 * (`Arrangement.SpaceEvenly`), centres `dimension.onthisday.controls.centerY` above the safe-area bottom. Share and
 * random are glass circles (C-11 `size.global.circleButtonLarge`, `color.global.glass`); they fade out while playing
 * (`duration.global.fade`, `easing.global.standard`) and keep their places. Share shows only when [canShare] (your own
 * memory, owner decision 12); on someone else's its place stays empty, so the dial does not move.
 */
@Composable
private fun Controls(state: OnThisDayState.Page, actions: OnThisDayActions, canShare: Boolean, modifier: Modifier) {
    Box(
        modifier
            .fillMaxWidth()
            .windowInsetsPadding(WindowInsets.navigationBars)
            .centredSlot(Tokens.Sizes.onthisdayControlsCenterY)
            .semantics { isTraversalGroup = true; traversalIndex = 1f },
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly, verticalAlignment = Alignment.CenterVertically) {
            HiddenInPlace(visible = canShare && !state.playing) {
                CircleIconButton(
                    Tokens.Icons.globalShare,
                    stringResource(R.string.onthisday_a11y_share),
                    actions.onShare,
                    Modifier.testTag(OnThisDayTags.SHARE),
                    style = CircleButtonStyle.GlassLarge,
                )
            }
            RewindDial(
                index = state.index,
                count = state.memories.size,
                playing = state.playing,
                onStep = actions.onStep,
                onTogglePlay = actions.onTogglePlay,
            )
            HiddenInPlace(visible = !state.playing) {
                CircleIconButton(
                    Tokens.Icons.globalRandom,
                    stringResource(R.string.onthisday_a11y_shuffle),
                    actions.onShuffle,
                    Modifier.testTag(OnThisDayTags.SHUFFLE),
                    style = CircleButtonStyle.GlassLarge,
                    enabled = !state.picking,
                )
            }
        }
    }
}

/**
 * A control circle that fades in and out (`duration.global.fade`) and, once faded out, is not composed at all — not
 * drawn, not clickable, not in the semantics tree; its circle-sized slot stays, so the dial does not move.
 */
@Composable
private fun HiddenInPlace(visible: Boolean, content: @Composable () -> Unit) {
    Box(Modifier.size(Tokens.Sizes.globalCircleButtonLarge), contentAlignment = Alignment.Center) {
        FadeVisibility(visible) { content() }
    }
}

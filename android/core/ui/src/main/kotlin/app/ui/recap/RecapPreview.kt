package app.ui.recap

/*
 * The recap preview — Retro's 2026 recap-preview screen (references/auto/retro/store/retro-store-04.png, ST-04),
 * measured by the capture group as `collage.view.layout.screen` + `collage.share.layout.pill` (MERGE_DECISIONS
 * RC-15). One implementation for every surface that shows it (lead decision, Pass 4):
 *
 *   - collage.view / collage.share (capture): the collage page as the card, dots below the page, "Share" pill;
 *   - week.recap (social): memory's recap card / cover pages, dots below the page, select-photos thumbnail
 *     leading, "Save as Album" pill (text role `pill`);
 *   - year.story / birthday.tribute (memory): the story cards, position pill top-leading, play / pause circle
 *     leading, "Share" pill; dots below the page on the summary only; tap zones instead of swiping.
 *
 * API
 * ---
 * [RecapPreviewScreen] draws, on `color.global.backgroundDeep` (black in both appearances — a media surface):
 *
 *  1. the **media page**: full width, from the status-bar (safe-area) top to `mediaPageBottomFromScreenBottom`
 *     (94.8) above the screen bottom, corners `mediaPageCornerRadius` (26.5), content clipped. Inside it the
 *     [backdrop] (any [DsImage] model: Painter, URL, File) blurred full-bleed (`layout.global.materials.backdrop`,
 *     [backdropBlur]); with no backdrop — or below API 31, where `Modifier.blur` does nothing — the page is
 *     `color.global.controlOnDeep` (collage.view → States / Platform notes);
 *  2. the **pages**: [page] is called for each page index with a [BoxScope] that fills the media page; the caller
 *     lays its card out in it (e.g. [RecapPreviewDefaults.collageCardPadding] + aspect-fit for the collage). With
 *     [pageCount] > 1 and [swipeEnabled] the pages sit in a `HorizontalPager` (finger-tracked, platform settle);
 *     [currentPage] / [onPageChange] keep the caller's state in sync (set [currentPage] to move programmatically);
 *  3. the **close** circle (C-11 on media: `size.global.circleButton`, `color.global.controlOnDeep`,
 *     `icon.global.close`), centre `closeCentreFromTrailing` (37.7) from the trailing edge and
 *     `closeCentreBelowPageTop` (38) below the page top; label [closeContentDescription] (copy);
 *  4. optional [topLeading] content (year.story's C-22 position pill), centred on the close circle's centre line;
 *     the caller gives it its own leading padding;
 *  5. the **bottom row**, centred `bottomRowCentreFromScreenBottom` (59.2) above the screen bottom: optional
 *     [bottomLeading] (a C-11 circle or the select-photos thumbnail — the caller pads it, normally
 *     `size.global.buttonMarginH`) and the trailing [pill] at `size.global.buttonMarginH`;
 *  6. the **page dots** (C-31 on media) only with 2+ pages: by default centred `dimension.year.story.dots.offset`
 *     (16.1) below the media page ([RecapDots.BelowPage] — ST-04 measures 16.3 there, not on the pill's line;
 *     MERGE_DECISIONS RC-19), or [RecapDots.InBottomRow] / [RecapDots.Hidden]. TalkBack reads [dotsDescription] (default
 *     `global.a11y.pagePosition`, "2 of 3"); a tap on the dots' trailing half moves to the next page, on the
 *     leading half to the previous one (platform page-control behaviour);
 *  7. the **pill** ([RecapPill]): the recap-size C-09 light pill — height 43.5, horizontal padding 23
 *     (`collage.share.layout.pill`), `radius.global.capsule`, `color.global.surfaceLight` / `.onSurfaceLight`,
 *     label text role `button` (collage.share, year.story) or `pill` (week.recap); [RecapPill.busy] swaps the
 *     label for the platform indicator in the label colour (C-05 busy rule) with `duration.global.crossfade`.
 *
 * On a device with a tall navigation bar the bottom row and the media page bottom move up together so the row
 * clears the bar (Retro's values are measured from the iPhone screen bottom). Status bar: light content is the
 * caller's (media surface). Haptics: close, pill and dots play `haptic.global.tap`; page swipes none.
 * Test tags (measurements): `recap.page`, `recap.close`, `recap.dots`, `recap.pill`.
 * Snapshots: core:ui `RecapPreviewSnapshotTest` (light and dark — identical by design).
 */

import android.os.Build
import androidx.compose.animation.Crossfade
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.max
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.ui.components.BlurredBackdrop
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.components.PageDots
import app.ui.foundation.DsMotion
import app.ui.foundation.centreAt
import app.ui.foundation.reduceMotion
import app.ui.foundation.tapClickable
import app.ui.haptics.rememberHaptics
import app.ui.text.TextRoles

/** Where the recap preview's page dots sit (C-31 on media). Shown only with 2+ pages. */
sealed interface RecapDots {
    /** Centred on the bottom row's centre line (not used by Retro's 2026 render; kept for compositions). */
    data object InBottomRow : RecapDots

    /** Centred, their centre [offset] below the media page's bottom edge (ST-04; every caller). */
    data class BelowPage(val offset: Dp = Tokens.Sizes.yearStoryDotsOffset) : RecapDots

    /** No dots (year.story cards). */
    data object Hidden : RecapDots
}

/** Which text role the pill's label uses: `button` (17 semibold — "Share") or `pill` (15 semibold — "Save as Album"). */
enum class RecapPillLabel { Button, Pill }

/** The bottom row's trailing light pill: [text] (copy), [busy] shows the indicator, [enabled] false ignores taps. */
@Immutable
data class RecapPill(
    val text: String,
    val onClick: () -> Unit,
    val busy: Boolean = false,
    val enabled: Boolean = true,
    val label: RecapPillLabel = RecapPillLabel.Button,
)

/** Values of the recap preview shared by its callers. */
object RecapPreviewDefaults {
    /** Blur σ of the backdrop (`size.global.backdropBlur`, fitted on ST-04 — MERGE_DECISIONS L-5). */
    val BackdropBlur: Dp get() = Tokens.Sizes.globalBackdropBlur

    private val screen get() = Tokens.Layouts.CollageViewLayoutScreen

    /**
     * The collage card's box inside the media page (`collage.view.layout.screen.card`): inset top and bottom by
     * the close-circle centre (38) + half the circle (18) + the circle → photo gap of the Postcard preview
     * (`camera.sendto.layout.preview.topBelowHeaderCircle`, 20) = 76, and at least 32 at the sides — the token
     * gives that side minimum only in its text; it equals 2 × `size.global.screenMargin` (reported gap: no
     * numeric field). The card is aspect-fit in this box.
     */
    val collageCardPadding: PaddingValues
        get() {
            val vertical = Dp(screen.closeCentreBelowPageTop) + Tokens.Sizes.globalCircleButton / 2 +
                Dp(Tokens.Layouts.CameraSendtoLayoutPreview.topBelowHeaderCircle)
            return PaddingValues(horizontal = Tokens.Sizes.globalScreenMargin * 2, vertical = vertical)
        }

    /** Corner radius of the media page (`collage.view.layout.screen.mediaPageCornerRadius`). */
    val mediaPageCorner: Dp get() = Dp(screen.mediaPageCornerRadius)
}

/**
 * Retro's recap preview (see the file header for the full layout and API notes).
 *
 * @param backdrop page 1's image (any [app.ui.foundation.DsImage] model), drawn blurred inside the media page;
 *   null fills the page with `color.global.controlOnDeep` (loading / empty / error states).
 * @param page draws page [Int] inside the media page (a [BoxScope] filling it, clipped to its corners).
 */
@Composable
fun RecapPreviewScreen(
    backdrop: Any?,
    pageCount: Int,
    currentPage: Int,
    onPageChange: (Int) -> Unit,
    onClose: () -> Unit,
    closeContentDescription: String,
    modifier: Modifier = Modifier,
    pill: RecapPill? = null,
    dots: RecapDots = RecapDots.BelowPage(),
    dotsDescription: String? = null,
    swipeEnabled: Boolean = true,
    backdropBlur: Dp = RecapPreviewDefaults.BackdropBlur,
    topLeading: (@Composable () -> Unit)? = null,
    bottomLeading: (@Composable () -> Unit)? = null,
    page: @Composable BoxScope.(page: Int) -> Unit,
) {
    val screen = Tokens.Layouts.CollageViewLayoutScreen
    val pillSpec = Tokens.Layouts.CollageShareLayoutPill
    // Lift the row (and the page bottom with it) only when the navigation bar would cover the pill.
    val navBar = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val rowCentre = max(Dp(screen.bottomRowCentreFromScreenBottom), navBar + Dp(pillSpec.height) / 2)
    val lift = rowCentre - Dp(screen.bottomRowCentreFromScreenBottom)
    val pageBottom = Dp(screen.mediaPageBottomFromScreenBottom) + lift
    val showDots = pageCount > 1 && dots != RecapDots.Hidden
    val description = dotsDescription ?: stringResource(R.string.global_a11y_pageposition, currentPage + 1, pageCount)

    Box(modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep)) {
        // 1–4. Media page with backdrop, pages, close and top-leading content.
        Box(
            Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.statusBars)
                .padding(bottom = pageBottom)
                .clip(RoundedCornerShape(RecapPreviewDefaults.mediaPageCorner))
                .background(Tokens.Colors.globalControlOnDeep)
                .testTag("recap.page"),
        ) {
            if (backdrop != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                BlurredBackdrop(backdrop, backdropBlur)
            }
            RecapPages(pageCount, currentPage, onPageChange, swipeEnabled, page)
            if (topLeading != null) {
                Box(Modifier.align(Alignment.TopStart).centreAt(Dp(screen.closeCentreBelowPageTop))) { topLeading() }
            }
            CircleIconButton(
                Tokens.Icons.globalClose,
                closeContentDescription,
                onClose,
                Modifier
                    .align(Alignment.TopEnd)
                    .padding(end = Dp(screen.closeCentreFromTrailing) - Tokens.Sizes.globalCircleButton / 2)
                    .centreAt(Dp(screen.closeCentreBelowPageTop))
                    .testTag("recap.close"),
                style = CircleButtonStyle.OnMedia,
            )
        }

        // 6. Dots below the page: a box from the screen bottom whose centre is `offset` under the page bottom.
        if (showDots && dots is RecapDots.BelowPage) {
            Box(
                Modifier.align(Alignment.BottomCenter).fillMaxWidth().height((pageBottom - dots.offset) * 2),
                contentAlignment = Alignment.Center,
            ) { RecapDotsRow(pageCount, currentPage, onPageChange, description) }
        }

        // 5. Bottom row: a box twice the row-centre height, anchored at the bottom, so its centre line is the row's.
        Box(Modifier.align(Alignment.BottomCenter).fillMaxWidth().height(rowCentre * 2)) {
            if (bottomLeading != null) Box(Modifier.align(Alignment.CenterStart)) { bottomLeading() }
            if (showDots && dots == RecapDots.InBottomRow) {
                Box(Modifier.align(Alignment.Center)) { RecapDotsRow(pageCount, currentPage, onPageChange, description) }
            }
            if (pill != null) {
                RecapPillButton(pill, Modifier.align(Alignment.CenterEnd).padding(end = Tokens.Sizes.globalButtonMarginH).testTag("recap.pill"))
            }
        }
    }
}

/** The pages inside the media page: a pager with 2+ swipeable pages, else the current page alone. */
@Composable
private fun RecapPages(
    pageCount: Int,
    currentPage: Int,
    onPageChange: (Int) -> Unit,
    swipeEnabled: Boolean,
    page: @Composable BoxScope.(page: Int) -> Unit,
) {
    if (pageCount <= 1 || !swipeEnabled) {
        Box(Modifier.fillMaxSize()) { page(currentPage.coerceIn(0, (pageCount - 1).coerceAtLeast(0))) }
        return
    }
    val state = rememberPagerState(initialPage = currentPage.coerceIn(0, pageCount - 1)) { pageCount }
    val reduce = reduceMotion()
    val latestOnChange = rememberUpdatedState(onPageChange)
    LaunchedEffect(state) {
        snapshotFlow { state.settledPage }.collect { if (it != currentPage) latestOnChange.value(it) }
    }
    LaunchedEffect(currentPage) {
        val target = currentPage.coerceIn(0, pageCount - 1)
        if (state.currentPage != target) if (reduce) state.scrollToPage(target) else state.animateScrollToPage(target)
    }
    HorizontalPager(state = state, modifier = Modifier.fillMaxSize()) { index ->
        Box(Modifier.fillMaxSize()) { page(index) }
    }
}

/** C-31 dots on media; a tap on the trailing half → next page, leading half → previous. */
@Composable
private fun RecapDotsRow(count: Int, selected: Int, onPageChange: (Int) -> Unit, description: String) {
    val haptics = rememberHaptics()
    val latest = rememberUpdatedState(selected)
    Box(
        Modifier
            .heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid)
            .pointerInput(count) {
                detectTapGestures { offset ->
                    val forward = offset.x >= size.width / 2f
                    val target = (latest.value + if (forward) 1 else -1).coerceIn(0, count - 1)
                    if (target != latest.value) {
                        haptics.tap()
                        onPageChange(target)
                    }
                }
            },
        contentAlignment = Alignment.Center,
    ) {
        PageDots(count, selected, description, Modifier.testTag("recap.dots"), onMedia = true)
    }
}

/**
 * The recap-size C-09 light pill (`collage.share.layout.pill`): height 43.5 (grows with large text), padding 23,
 * capsule, `color.global.surfaceLight` / `color.global.onSurfaceLight`. Busy: the platform indicator replaces the
 * label (kept for TalkBack and for the width), cross-faded with `duration.global.crossfade`.
 */
@Composable
fun RecapPillButton(pill: RecapPill, modifier: Modifier = Modifier) {
    val spec = Tokens.Layouts.CollageShareLayoutPill
    val labelColor = Tokens.Colors.globalOnSurfaceLight
    val style = if (pill.label == RecapPillLabel.Button) TextRoles.button else TextRoles.pill
    Box(
        modifier
            .heightIn(min = Dp(spec.height))
            .clip(CircleShape)
            .background(Tokens.Colors.globalSurfaceLight, CircleShape)
            .tapClickable(enabled = pill.enabled && !pill.busy, onClick = pill.onClick)
            .then(if (pill.busy) Modifier.semantics { contentDescription = pill.text } else Modifier)
            .padding(horizontal = Dp(spec.paddingHorizontal)),
        contentAlignment = Alignment.Center,
    ) {
        Crossfade(targetState = pill.busy, animationSpec = DsMotion.crossfade(), label = "recapPillBusy") { busy ->
            Box(contentAlignment = Alignment.Center) {
                Text(pill.text, style = style, color = labelColor, textAlign = TextAlign.Center, maxLines = 1, modifier = Modifier.alpha(if (busy) 0f else 1f))
                if (busy) CircularProgressIndicator(color = labelColor, modifier = Modifier.size(Tokens.Sizes.globalIcon))
            }
        }
    }
}

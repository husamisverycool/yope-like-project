// Recap-preview chrome (Retro screen 20, ST-04): `references/auto/retro/store/retro-store-04.png`,
// `references/auto/retro/press/tc-2023-12-recaps.png` phones 2–3. Used by year.story (frame + bottom row) and
// birthday.tribute (bottom row).
//
// LOCAL VERSION, isolated in this one file: the shared chrome (`app.ui.recap.RecapPreviewScreen`, core:ui) is being
// built by the capture pass at the same time (lead notes, MERGE RM-8). This file draws the same tokens
// (`collage.view.layout.screen`, `collage.share.layout.pill`) so the memory screens can switch to it without layout
// changes; nothing outside this file knows how the chrome is drawn.
package app.feature.memory.common

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.designsystem.generated.Tokens
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.foundation.tapClickable
import app.ui.text.TextRoles
import kotlin.math.roundToInt

/** Measured placements of the recap preview (`collage.view.layout.screen`, `collage.share.layout.pill`). */
object RecapChrome {
    private val screen = Tokens.Layouts.CollageViewLayoutScreen
    private val pill = Tokens.Layouts.CollageShareLayoutPill

    /** Media page bottom above the screen bottom (94.8). */
    val pageBottom: Dp get() = screen.mediaPageBottomFromScreenBottom.dp

    /** Media page corners (26.5, continuous on iOS; `layout.global.cornerStyle`). */
    val pageCorner: Dp get() = screen.mediaPageCornerRadius.dp

    /** Close circle centre: from the trailing edge / below the page top (37.7 / 38). */
    val closeFromTrailing: Dp get() = screen.closeCentreFromTrailing.dp
    val closeBelowTop: Dp get() = screen.closeCentreBelowPageTop.dp

    /** Bottom row centre above the screen bottom (59.2). */
    val rowCentre: Dp get() = screen.bottomRowCentreFromScreenBottom.dp

    /** The Share pill: 43.5 high, 23 horizontal padding (label text role `button`). */
    val pillHeight: Dp get() = pill.height.dp
    val pillPadding: Dp get() = pill.paddingHorizontal.dp

    /** Page dots centre above the screen bottom: `dimension.year.story.dots.offset` below the page. */
    val dotsCentre: Dp get() = pageBottom - Tokens.Sizes.yearStoryDotsOffset
}

/**
 * Gives the element a slot [centre] × 2 tall (or wide, with [horizontal]) and centres it there, so that a slot
 * aligned to an edge puts the element's centre exactly [centre] from that edge whatever its own size.
 */
fun Modifier.centredSlot(centre: Dp, horizontal: Boolean = false): Modifier = layout { measurable, constraints ->
    val placeable = measurable.measure(constraints.copy(minWidth = 0, minHeight = 0))
    val span = (centre.toPx() * 2).roundToInt()
    if (horizontal) {
        val w = maxOf(span, placeable.width)
        layout(w, placeable.height) { placeable.place((w - placeable.width) / 2, 0) }
    } else {
        val h = maxOf(span, placeable.height)
        layout(placeable.width, h) { placeable.place(0, (h - placeable.height) / 2) }
    }
}

/**
 * The recap preview (ST-04) on `color.global.backgroundDeep`: the rounded media page — full width, from the
 * safe-area top to `mediaPageBottomFromScreenBottom` above the screen bottom, corners `mediaPageCornerRadius`,
 * content clipped — holding [content]; its close circle (C-11 on media: `size.global.circleButton`,
 * `color.global.controlOnDeep`, `icon.global.close`) centred `closeCentreFromTrailing` / `closeCentreBelowPageTop`;
 * [overlay] above the content inside the page (e.g. the position pill); [dots] centred
 * `dimension.year.story.dots.offset` below the page; the bottom row ([leading] at `size.global.buttonMarginH`,
 * [trailing] at the pill's trailing inset `size.global.buttonMarginH`) centred `bottomRowCentreFromScreenBottom`
 * above the screen bottom. Call it inside [MediaAppearance].
 */
@Composable
fun RecapPreviewFrame(
    onClose: () -> Unit,
    closeLabel: String,
    modifier: Modifier = Modifier,
    overlay: (@Composable BoxScope.() -> Unit)? = null,
    dots: (@Composable () -> Unit)? = null,
    leading: (@Composable () -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
    content: @Composable BoxScope.() -> Unit,
) {
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    Box(modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep)) {
        Box(
            Modifier
                .fillMaxSize()
                .padding(top = top, bottom = RecapChrome.pageBottom)
                .clip(RoundedCornerShape(RecapChrome.pageCorner)),
        ) {
            content()
            overlay?.invoke(this)
            Box(
                Modifier
                    .align(Alignment.TopEnd)
                    .centredSlot(RecapChrome.closeBelowTop)
                    .centredSlot(RecapChrome.closeFromTrailing, horizontal = true),
            ) {
                CircleIconButton(Tokens.Icons.globalClose, closeLabel, onClose, style = CircleButtonStyle.OnMedia)
            }
        }
        if (dots != null) Box(Modifier.align(Alignment.BottomCenter).centredSlot(RecapChrome.dotsCentre)) { dots() }
        RecapBottomRow(leading, trailing, Modifier.align(Alignment.BottomCenter))
    }
}

/**
 * The recap preview's bottom row (also under the tribute player): [leading] at `size.global.buttonMarginH`, [trailing]
 * at the Share pill's trailing inset, both centred `bottomRowCentreFromScreenBottom` above the screen bottom. Place it
 * aligned to the bottom of a full-screen box.
 */
@Composable
fun RecapBottomRow(leading: (@Composable () -> Unit)?, trailing: (@Composable () -> Unit)?, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().centredSlot(RecapChrome.rowCentre)) {
        if (leading != null) Box(Modifier.align(Alignment.CenterStart).padding(start = Tokens.Sizes.globalButtonMarginH)) { leading() }
        if (trailing != null) Box(Modifier.align(Alignment.CenterEnd).padding(end = Tokens.Sizes.globalButtonMarginH)) { trailing() }
    }
}

/**
 * The recap preview's white Share pill (`collage.share.layout.pill`: height 43.5, horizontal padding 23; C-09 light:
 * `color.global.surfaceLight` / `color.global.onSurfaceLight`, `radius.global.capsule`; label text role `button`).
 * Pressed: platform default + `haptic.global.tap`.
 */
@Composable
fun RecapSharePill(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true) {
    Box(
        modifier
            .heightIn(min = RecapChrome.pillHeight)
            .clip(CircleShape)
            .background(Tokens.Colors.globalSurfaceLight, CircleShape)
            .tapClickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = RecapChrome.pillPadding),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = TextRoles.button, color = Tokens.Colors.globalOnSurfaceLight, maxLines = 1)
    }
}

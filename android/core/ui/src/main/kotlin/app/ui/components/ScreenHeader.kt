package app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.layout.LastBaseline
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.coerceAtLeast
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.max
import app.designsystem.generated.Tokens
import app.ui.foundation.GlyphInk
import app.ui.foundation.centreAt
import app.ui.text.CapTop
import app.ui.text.TextRoles

/** A trailing header glyph button (C-01 / C-02): an `icon.global.*` token and its TalkBack label from copy. */
@Immutable
data class HeaderAction(val icon: ImageVector, val contentDescription: String, val onClick: () -> Unit)

/** Hit area of a header glyph: `size.global.headerButton` (44, PLATFORM), at least `size.global.minTouchTarget.android`. */
internal val headerHit: Dp get() = max(Tokens.Sizes.globalHeaderButton, Tokens.Sizes.globalMinTouchTargetAndroid)

/**
 * C-01 Screen header (root): display serif title + trailing glyph buttons (design/components.md C-01).
 *
 * - Title: text role `headerTitle` (40 / line 48, regular, `font.global.display`) in [titleColor]
 *   (`color.global.textPrimary`; `color.global.textOnMedia` over a photo, C-35); leading
 *   `size.global.screenMargin`; first baseline `size.global.titleTop` below the top of this element, which
 *   the caller places at the safe-area top. Wraps on several lines at large font sizes. Header trait.
 * - [accessory] (e.g. C-03 [RelativeWeekPill]) follows the title, centred on its cap middle, [accessoryGap]
 *   after it — that gap is not measured (components.md C-03 Gap), so the caller passes the surface's token.
 *   Title and accessory are read as one heading ("Week 19, Last Week").
 * - [actions]: up to two glyphs (`size.global.icon` box, `color.global.textPrimary`) centred on the title's
 *   cap middle, centre to centre `size.global.headerIconPitch`, the last glyph's **ink**
 *   `size.global.headerInset` from the edge; each has a hit area of [headerHit] and no visible circle.
 * - The first content below starts `size.global.titleToContent` below the title's last baseline.
 * - No bar background, no hairline. Scrolled / collapsed state: not captured (Gap) — scrolls with content.
 */
@Composable
fun ScreenHeader(
    title: String,
    modifier: Modifier = Modifier,
    actions: List<HeaderAction> = emptyList(),
    titleColor: Color = Tokens.Colors.globalTextPrimary,
    accessory: (@Composable () -> Unit)? = null,
    accessoryGap: Dp = Dp.Unspecified,
) {
    HeaderFrame(modifier, actions, titleColor) { capMiddle ->
        Row(Modifier.padding(start = Tokens.Sizes.globalScreenMargin).semantics(mergeDescendants = true) { heading() }) {
            HeaderTitle(title, titleColor, Modifier.weight(1f, fill = false))
            if (accessory != null) {
                Box(Modifier.padding(start = if (accessoryGap == Dp.Unspecified) 0.dp else accessoryGap).centreAt(capMiddle)) { accessory() }
            }
        }
    }
}

/**
 * C-02 Screen header (pushed): back chevron, then the serif title on the same line; trailing glyphs as C-01.
 *
 * The back glyph (`icon.global.back`, `color.global.textPrimary`) has its ink `size.global.backInset` from the
 * edge, centred on the title's cap middle, hit area [headerHit], TalkBack label [backContentDescription]
 * (copy). The title's ink starts `size.global.headerGap` after the chevron's ink. [below] (e.g. the C-12
 * search field) is drawn under the header inside `size.global.screenMargin`.
 */
@Composable
fun PushedHeader(
    title: String,
    onBack: () -> Unit,
    backContentDescription: String,
    modifier: Modifier = Modifier,
    actions: List<HeaderAction> = emptyList(),
    titleColor: Color = Tokens.Colors.globalTextPrimary,
    below: (@Composable () -> Unit)? = null,
) {
    Column(modifier.fillMaxWidth()) {
        HeaderFrame(Modifier, actions, titleColor) { capMiddle ->
            val back = Tokens.Icons.globalBack
            val box = Tokens.Sizes.globalIcon
            val inkLeft = GlyphInk.leading(back, box)
            val inkWidth = GlyphInk.width(back, box)
            // Hit area centred on the glyph box; the glyph box placed so its ink starts at backInset.
            val hitStart = Tokens.Sizes.globalBackInset - inkLeft - (headerHit - box) / 2
            val titleStart = Tokens.Sizes.globalBackInset + inkWidth + Tokens.Sizes.globalHeaderGap
            Box(Modifier.fillMaxWidth()) {
                Box(Modifier.padding(start = hitStart.coerceAtLeastZero()).centreAt(capMiddle)) {
                    HeaderIconButton(back, backContentDescription, onBack, tint = titleColor)
                }
                HeaderTitle(title, titleColor, Modifier.padding(start = titleStart).semantics { heading() })
            }
        }
        if (below != null) Box(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin)) { below() }
    }
}

/**
 * C-03 Relative-week pill ("Last Week"): capsule `color.global.badgeMuted`, label text role `badge` in
 * `color.global.onBadge`, height `size.global.badgeHeight`. Horizontal padding is half the height (the label
 * stays out of the capsule's round ends, `radius.global.capsule`; Retro's pill padding is not a token —
 * APK pills use 12 dp, equal to it here). Decorative for TalkBack when placed in [ScreenHeader] (read with the title).
 * Contrast white on #999999 2.85:1 is a recorded failure (CONTRAST failure 7).
 */
@Composable
fun RelativeWeekPill(text: String, modifier: Modifier = Modifier) {
    CapsuleLabel(text, Tokens.Colors.globalBadgeMuted, Tokens.Colors.globalOnBadge, modifier)
}

/** A 24 pt label capsule (C-03, C-24): fill, label text role `badge`, padding half the height. */
@Composable
internal fun CapsuleLabel(text: String, fill: Color, label: Color, modifier: Modifier = Modifier) {
    val height = Tokens.Sizes.globalBadgeHeight
    Box(
        modifier.height(height).background(fill, CircleShape).padding(horizontal = height / 2),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = TextRoles.badge, color = label, maxLines = 1)
    }
}

/** The title text of C-01 / C-02, its first baseline at `size.global.titleTop`, content `titleToContent` below its last baseline. */
@Composable
private fun HeaderTitle(title: String, color: Color, modifier: Modifier) {
    Text(
        title,
        style = TextRoles.headerTitle,
        color = color,
        modifier = modifier
            .paddingFrom(FirstBaseline, before = Tokens.Sizes.globalTitleTop)
            .paddingFrom(LastBaseline, after = Tokens.Sizes.globalTitleToContent),
    )
}

/**
 * Shared frame: [title] content (given the title's cap-middle y) with the trailing [actions] centred on that
 * cap middle, their last glyph's ink at `size.global.headerInset`.
 */
@Composable
private fun HeaderFrame(modifier: Modifier, actions: List<HeaderAction>, tint: Color, title: @Composable (capMiddle: Dp) -> Unit) {
    val capMiddle = Tokens.Sizes.globalTitleTop - CapTop.height(TextRoles.headerTitle) / 2
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
        Box(Modifier.weight(1f)) { title(capMiddle) }
        if (actions.isNotEmpty()) {
            val box = Tokens.Sizes.globalIcon
            val endInk = GlyphInk.trailing(actions.last().icon, box)
            val end = Tokens.Sizes.globalHeaderInset - endInk - (headerHit - box) / 2
            Row(
                Modifier.padding(end = end.coerceAtLeastZero()).centreAt(capMiddle),
                horizontalArrangement = Arrangement.spacedBy((Tokens.Sizes.globalHeaderIconPitch - headerHit).coerceAtLeastZero()),
            ) {
                actions.forEach { HeaderIconButton(it.icon, it.contentDescription, it.onClick, tint = tint) }
            }
        }
    }
}

internal fun Dp.coerceAtLeastZero(): Dp = coerceAtLeast(0.dp)

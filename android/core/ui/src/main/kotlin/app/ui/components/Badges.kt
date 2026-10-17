package app.ui.components

import androidx.compose.foundation.background
import java.time.format.DateTimeFormatter
import java.time.LocalTime
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import app.designsystem.generated.Tokens
import app.ui.text.TextRoles

/**
 * C-24 "new" badge: capsule `color.global.badge` (#EA3337), label text role `badge` (11 semibold) in
 * `color.global.onBadge`, lower case (copy), height `size.global.badgeHeight`; on a card it sits
 * `size.global.badgeInset` from the top and right (the caller aligns it). **Never a number** (tenets:
 * Retro's "6 new" count is do-not-copy). Read as part of its owner element ("new photos"), so it has no
 * semantics of its own. White on red 4.18:1 is a recorded failure for 11 pt text (CONTRAST failure 5).
 */
@Composable
fun NewBadge(text: String, modifier: Modifier = Modifier) {
    CapsuleLabel(text, Tokens.Colors.globalBadge, Tokens.Colors.globalOnBadge, modifier.clearAndSetSemantics { })
}

/** C-24 unread dot: `size.global.tabBadgeDot` circle in `color.global.badge` (passes non-text contrast). Decorative; the owner carries "new". */
@Composable
fun UnreadDot(modifier: Modifier = Modifier) {
    Box(modifier.size(Tokens.Sizes.globalTabBadgeDot).background(Tokens.Colors.globalBadge, CircleShape))
}

/**
 * C-25 video duration pill ("1:00"): capsule `color.global.surfaceLight`, `size.global.videoPillHeight` tall,
 * `size.global.videoPillPadding` each side; `icon.global.video` (`size.global.iconSmall`), `size.global.videoPillGap`, then
 * the duration in text role `pillSmall` (13 bold, tabular digits) in `color.global.onSurfaceLight` (PAY: 71 × 28).
 * [text] null: the glyph alone (a tile too narrow for the digits, `layout.global.videoMarker`). [contentDescription]
 * null: no semantics of its own (the owner's label says "Video, …").
 */
@Composable
fun VideoDurationPill(text: String?, contentDescription: String?, modifier: Modifier = Modifier) {
    Row(
        modifier
            .height(Tokens.Sizes.globalVideoPillHeight)
            .background(Tokens.Colors.globalSurfaceLight, CircleShape)
            .padding(horizontal = Tokens.Sizes.globalVideoPillPadding)
            .clearAndSetSemantics { if (contentDescription != null) this.contentDescription = contentDescription },
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalVideoPillGap),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Tokens.Icons.globalVideo, contentDescription = null, tint = Tokens.Colors.globalOnSurfaceLight, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
        if (text != null) Text(text, style = TextRoles.pillSmall.copy(fontFeatureSettings = "tnum"), color = Tokens.Colors.globalOnSurfaceLight, maxLines = 1, softWrap = false)
    }
}

/**
 * `layout.global.videoMarker`: the video pill at a photo's or tile's top-trailing corner, `size.global.videoPillInset` from
 * both edges; where the duration does not fit inside the tile less both insets, the glyph alone. Put it in a [Box] over
 * the photo (it aligns itself). Decorative: the owner's label carries "Video, {duration}" (`chat.thread.a11y.video`).
 */
@Composable
fun BoxScope.VideoTileMarker(durationMs: Long, modifier: Modifier = Modifier) {
    val text = videoDurationText(durationMs)
    val inset = Tokens.Sizes.globalVideoPillInset
    val measurer = rememberTextMeasurer()
    val style = TextRoles.pillSmall.copy(fontFeatureSettings = "tnum")
    val density = LocalDensity.current
    BoxWithConstraints(modifier.matchParentSize().padding(inset)) {
        val digits = with(density) { measurer.measure(text, style).size.width.toDp() }
        val full = Tokens.Sizes.globalVideoPillPadding * 2 + Tokens.Sizes.globalIconSmall + Tokens.Sizes.globalVideoPillGap + digits
        VideoDurationPill(if (full <= maxWidth) text else null, contentDescription = null, modifier = Modifier.align(Alignment.TopEnd))
    }
}

/**
 * `layout.global.batchMarker`: a photo that leads photos posted together (Instagram's carousel icon in the top right)
 * carries the video pill's form without digits — capsule `color.global.surfaceLight`, `size.global.videoPillHeight` tall,
 * `size.global.videoPillPadding` each side, `icon.global.batch` (`size.global.iconSmall`) in `color.global.onSurfaceLight` —
 * at the top-trailing corner, `size.global.videoPillInset` from both edges; under the video marker ([belowVideoMarker],
 * `size.global.pillGap` below it) when the photo is also a video. Never a number. Put it in a [Box] over the photo (it
 * aligns itself). Decorative: the owner's label adds "Photos posted together" (`chat.thread.a11y.batch`).
 */
@Composable
fun BoxScope.BatchTileMarker(belowVideoMarker: Boolean = false, modifier: Modifier = Modifier) {
    val inset = Tokens.Sizes.globalVideoPillInset
    val top = if (belowVideoMarker) inset + Tokens.Sizes.globalVideoPillHeight + Tokens.Sizes.globalPillGap else inset
    Box(
        modifier
            .align(Alignment.TopEnd)
            .padding(top = top, end = inset)
            .height(Tokens.Sizes.globalVideoPillHeight)
            .background(Tokens.Colors.globalSurfaceLight, CircleShape)
            .padding(horizontal = Tokens.Sizes.globalVideoPillPadding)
            .clearAndSetSemantics { },
        contentAlignment = Alignment.Center,
    ) {
        Icon(Tokens.Icons.globalBatch, contentDescription = null, tint = Tokens.Colors.globalOnSurfaceLight, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
    }
}

/** "0:10" (`chat.voice.layout.durationFormat`), whole seconds. */
fun videoDurationText(durationMs: Long): String =
    DateTimeFormatter.ofPattern(Tokens.Layouts.ChatVoiceLayoutDurationFormat.pattern).format(LocalTime.ofSecondOfDay((durationMs.coerceAtLeast(0) / MS_PER_SECOND)))

private const val MS_PER_SECOND = 1_000L

/**
 * C-25 premium pill ("FREE"): capsule filled with `layout.global.premiumGradient` (top #D543DE → bottom
 * #A327B8, vertical), label text role `pillSmall` (13 bold, caps — copy) in `color.global.onBadge`.
 * **Paywall only; the owner decides whether the premium accent is used.** Measured 51 × 26 (PAY): its own
 * height has no token (Gap) — `size.global.badgeHeight`; the coloured shadow is not measured (Gap) — none.
 */
@Composable
fun PremiumPill(text: String, modifier: Modifier = Modifier) {
    val gradient = Tokens.Layouts.GlobalPremiumGradient
    val brush = Brush.verticalGradient(listOf(hex(gradient.top), hex(gradient.bottom)))
    val height = Tokens.Sizes.globalBadgeHeight
    Box(
        modifier.height(height).background(brush, CircleShape).padding(horizontal = height / 2).semantics(mergeDescendants = true) {},
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = TextRoles.pillSmall, color = Tokens.Colors.globalOnBadge, maxLines = 1)
    }
}

/** A colour from a token's "#RRGGBB" string (layout tokens carry hex strings). */
private fun hex(value: String): Color = Color(android.graphics.Color.parseColor(value))

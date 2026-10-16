package app.ui.components

import androidx.compose.foundation.background
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
 * C-25 video duration pill ("1:00"): capsule `color.global.surfaceLight`, `icon.global.video` + the duration in
 * text role `pillSmall` (13 bold, tabular digits) in `color.global.onSurfaceLight`. Measured 71 × 24 (PAY):
 * height `size.global.badgeHeight` (the same 24), width hugs with half the height as padding (capsule ends);
 * the glyph is `size.global.iconSmall` (its own size is not measured — Gap), `size.global.pillIconGap` before
 * the digits. [contentDescription]: the duration in words (copy).
 */
@Composable
fun VideoDurationPill(text: String, contentDescription: String, modifier: Modifier = Modifier) {
    val height = Tokens.Sizes.globalBadgeHeight
    Row(
        modifier
            .height(height)
            .background(Tokens.Colors.globalSurfaceLight, CircleShape)
            .padding(horizontal = height / 2)
            .clearAndSetSemantics { this.contentDescription = contentDescription },
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillIconGap),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Tokens.Icons.globalVideo, contentDescription = null, tint = Tokens.Colors.globalOnSurfaceLight, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
        Text(text, style = TextRoles.pillSmall, color = Tokens.Colors.globalOnSurfaceLight, maxLines = 1)
    }
}

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

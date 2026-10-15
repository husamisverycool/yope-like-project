package app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import app.designsystem.generated.Tokens

/** The fill of a header circle, by what it sits on (tokens README → "circle button"). */
enum class HeaderCircleFill(val color: Color) {
    /** `color.global.control` #2E2E2E — on `color.global.background` (#171717) screens. */
    Control(Tokens.Colors.globalControl),

    /** `color.global.controlOnDeep` #101010 — on black screens and sheets (✕, back on sign-up). */
    OnDeep(Tokens.Colors.globalControlOnDeep),

    /** `color.global.controlRaised` #434343 — raised controls (e.g. ••• on a photo card, approximation per groups.screen). */
    Raised(Tokens.Colors.globalControlRaised),
}

/**
 * A circle icon button in a header (back ‹, close ✕, more •••, add +, calendar, recap).
 *
 * Tokens: diameter `size.global.headerButton` (44), fill [HeaderCircleFill], glyph [icon] (an
 * `icon.global.*` token) in `color.global.textPrimary` at the platform icon size. Callers place it at
 * `size.global.headerInset` from the screen edge and `size.global.headerGap` apart.
 * [contentDescription] comes from copy (`*.accessibilityLabel`). Touches expand to
 * `size.global.minTouchTarget.android` (Compose touch-target expansion; layout unchanged).
 */
@Composable
fun HeaderCircleButton(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    fill: HeaderCircleFill = HeaderCircleFill.Control,
    diameter: androidx.compose.ui.unit.Dp = Tokens.Sizes.globalHeaderButton,
    /** Overrides [fill] with another `color.*` token (e.g. a surface's circle-over-photo fill). */
    fillColor: Color = fill.color,
) {
    Box(
        modifier
            .size(diameter)
            .clip(CircleShape)
            .background(fillColor, CircleShape)
            .clickable(role = Role.Button, onClick = onClick)
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = Tokens.Colors.globalTextPrimary)
    }
}

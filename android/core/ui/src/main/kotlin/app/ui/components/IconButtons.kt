package app.ui.components

import androidx.compose.foundation.background
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
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import app.designsystem.generated.Tokens
import app.ui.foundation.tapClickable

/**
 * C-11 bare header glyph: an `icon.global.*` glyph in the `size.global.icon` box, no visible circle, hit area
 * [headerHit] (`size.global.headerButton`, at least `size.global.minTouchTarget.android`); [tint]
 * `color.global.textPrimary` (on media `color.global.textOnMedia`). Label from copy. Pressed: platform
 * default + `haptic.global.tap`.
 */
@Composable
fun HeaderIconButton(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    tint: Color = Tokens.Colors.globalTextPrimary,
    enabled: Boolean = true,
) {
    Box(
        modifier
            .size(headerHit)
            .clip(CircleShape)
            .tapClickable(enabled = enabled, onClick = onClick)
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(Tokens.Sizes.globalIcon))
    }
}

/** The circle variants of C-11 (design/components.md C-11 table). */
enum class CircleButtonStyle {
    /** "+" on a list row, close on a light sheet: `size.global.circleButton` (36), fill `color.global.control`, glyph `color.global.textPrimary`. */
    OnPage,

    /** Close / edit on media (postcard composer, viewer): 36, fill `color.global.controlOnDeep`, glyph `color.global.textOnMedia`. */
    OnMedia,

    /** "•••" over a photo: `size.global.circleButtonPhoto` (40), fill `color.global.glass`, glyph `color.global.textOnMedia`. */
    Glass,

    /** Share / random beside a dial: `size.global.circleButtonLarge` (64), glass. */
    GlassLarge,

    /** Close over colour (paywall): `size.global.circleButtonSmall` (32), glass (PAY measured ≈15 % white as a range — `color.global.glass`). */
    GlassSmall,
    ;

    val diameter: Dp
        get() = when (this) {
            OnPage, OnMedia -> Tokens.Sizes.globalCircleButton
            Glass -> Tokens.Sizes.globalCircleButtonPhoto
            GlassLarge -> Tokens.Sizes.globalCircleButtonLarge
            GlassSmall -> Tokens.Sizes.globalCircleButtonSmall
        }

    val fill: Color
        @Composable get() = when (this) {
            OnPage -> Tokens.Colors.globalControl
            OnMedia -> Tokens.Colors.globalControlOnDeep
            Glass, GlassLarge, GlassSmall -> Tokens.Colors.globalGlass
        }

    val glyph: Color
        @Composable get() = when (this) {
            OnPage -> Tokens.Colors.globalTextPrimary
            else -> Tokens.Colors.globalTextOnMedia
        }
}

/**
 * C-11 circle button: [style] sets diameter, fill and glyph colour; the glyph is drawn in the
 * `size.global.icon` box, Retro's Android glyph box (its APK sizes 61 glyphs to `size.global.icon`): Material's padded
 * glyphs ink 0.389 ("+") and 0.361 ("×") of the 36 circle against Retro iOS's measured `size.global.circleGlyph` /
 * `.circleCloseGlyph` (0.377 / 0.302 — components.md C-11). Hit area at least
 * `size.global.minTouchTarget.android` (touch bounds expanded by `AppTheme`). Label from copy. The fills fail
 * non-text contrast against the page (CONTRAST failure 2): the glyph identifies the control.
 */
@Composable
fun CircleIconButton(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    style: CircleButtonStyle = CircleButtonStyle.OnPage,
    enabled: Boolean = true,
) {
    Box(
        modifier
            .size(style.diameter)
            .clip(CircleShape)
            .background(style.fill, CircleShape)
            .tapClickable(enabled = enabled, onClick = onClick)
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = style.glyph, modifier = Modifier.size(Tokens.Sizes.globalIcon))
    }
}

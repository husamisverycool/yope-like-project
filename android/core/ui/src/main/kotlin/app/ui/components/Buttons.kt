package app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import app.designsystem.generated.Tokens
import app.ui.text.TextRoles

/** Which measured primary-button height a screen uses (`size.global.buttonHeight` vs `.buttonHeightSheet`, F-28). */
enum class PrimaryButtonSize(val height: Dp) {
    /** `size.global.buttonHeight` 45 — full-width button in a form ("create group", "continue"). */
    Form(Tokens.Sizes.globalButtonHeight),

    /** `size.global.buttonHeightSheet` 47 — action at the bottom of a sheet / pre-alert screen. */
    Sheet(Tokens.Sizes.globalButtonHeightSheet),
}

/**
 * The lime primary button.
 *
 * Tokens: fill `color.global.accent`, label `color.global.onAccent` in text role `button`
 * (`fontSize.global.button` / `fontWeight.global.button`), corners `radius.global.button`, height
 * [PrimaryButtonSize]; disabled fill `groups.create.color.buttonDisabledFill`, label
 * `groups.create.color.buttonDisabledLabel`. Width comes from the caller (full width minus
 * `size.global.buttonMarginH` / `.buttonMarginHSheet`). While [loading], the label is replaced by the
 * platform progress indicator (`easing.global.native` activityIndicator). Touch target: Compose
 * expands touches to `size.global.minTouchTarget.android` without changing the layout.
 */
@Composable
fun PrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    size: PrimaryButtonSize = PrimaryButtonSize.Form,
    loading: Boolean = false,
) {
    val fill = if (enabled) Tokens.Colors.globalAccent else Tokens.Colors.groupsCreateColorButtonDisabledFill
    val label = if (enabled) Tokens.Colors.globalOnAccent else Tokens.Colors.groupsCreateColorButtonDisabledLabel
    val shape = RoundedCornerShape(Tokens.Radii.globalButton)
    Box(
        modifier
            .fillMaxWidth()
            .heightIn(min = size.height)
            .clip(shape)
            .background(fill, shape)
            .clickable(enabled = enabled && !loading, role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        if (loading) {
            CircularProgressIndicator(color = label)
        } else {
            Text(text, style = TextRoles.button, color = label, textAlign = TextAlign.Center)
        }
    }
}

/** The shape of a white secondary pill. */
enum class LightPillShape {
    /** `groups.screen.radius.lightPill` 11 on a `groups.screen.size.lightPillHeight` 45 pill (MERGE A-7). */
    Rounded,

    /** `radius.global.capsule` (height / 2) — the inline card's "enable" pill. */
    Capsule,
}

/**
 * The white secondary pill ("invite more friends", "try again", "enable").
 *
 * Tokens: fill `color.global.surfaceLight`, label `color.global.onSurfaceLight` in text role
 * `button`, optional leading glyph in the label colour; [shape] per [LightPillShape]; [height]
 * defaults to `groups.screen.size.lightPillHeight`. The width hugs the content with
 * `size.global.buttonMarginH` on each side (approximation: E26's 205-pt "invite more friends" pill
 * leaves ≈19 pt each side of its glyph + label; Yope's pill padding is not a measured token). A
 * [LightPillShape.Capsule] pill has no padding: its caller sets the measured width (e.g.
 * `onboarding.permission.contacts.size.cardButtonWidth`) and the label is centred. The glyph
 * sits `size.global.headerGap` before the label (approximation, not measured).
 */
@Composable
fun LightPill(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    leadingIcon: ImageVector? = null,
    shape: LightPillShape = LightPillShape.Rounded,
    height: Dp = Tokens.Sizes.groupsScreenSizeLightPillHeight,
    enabled: Boolean = true,
) {
    val outline: Shape = when (shape) {
        LightPillShape.Rounded -> RoundedCornerShape(Tokens.Radii.groupsScreenRadiusLightPill)
        LightPillShape.Capsule -> CircleShape
    }
    Row(
        modifier
            .height(height)
            .clip(outline)
            .background(Tokens.Colors.globalSurfaceLight, outline)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .then(if (shape == LightPillShape.Rounded) Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginH) else Modifier),
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalHeaderGap, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (leadingIcon != null) Icon(leadingIcon, contentDescription = null, tint = Tokens.Colors.globalOnSurfaceLight)
        Text(text, style = TextRoles.button, color = Tokens.Colors.globalOnSurfaceLight, maxLines = 1)
    }
}

/**
 * The lime text link ("send new code", "turn off link"): `auth.code.fontSize.textLink` /
 * `auth.code.fontWeight.textLink` in `color.global.accent`; disabled = `color.global.textSecondary`.
 */
@Composable
fun TextLink(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true) {
    Text(
        text,
        modifier = modifier.clickable(enabled = enabled, role = Role.Button, onClick = onClick),
        style = app.designsystem.dsTextStyle(Tokens.FontSizes.authCodeFontSizeTextLink, Tokens.FontWeights.authCodeFontWeightTextLink),
        color = if (enabled) Tokens.Colors.globalAccent else Tokens.Colors.globalTextSecondary,
        textAlign = TextAlign.Center,
    )
}

package app.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import app.designsystem.generated.Tokens
import app.ui.foundation.Outline
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.foundation.tickToggleable
import app.ui.text.TextRoles

/** Which height token a full-width capsule uses (both 60 in Retro; kept separate as the tokens are). */
enum class PrimaryButtonSize(val height: Dp) {
    /** `size.global.buttonHeight` — bottom of a screen or card. */
    Form(Tokens.Sizes.globalButtonHeight),

    /** `size.global.buttonHeightSheet` — bottom of a sheet / modal. */
    Sheet(Tokens.Sizes.globalButtonHeightSheet),
}

/**
 * C-05 Primary capsule (full width, 60 pt).
 *
 * Fill `color.global.accent` (#000 / #FFF) with label `color.global.onAccent` in text role `button`
 * (17 semibold, Sentence case from copy); [onMedia] (media / colour surfaces, LAND, ST-03): fill
 * `color.global.surfaceLight`, label `color.global.onSurfaceLight`. Height [size] (grows with large text),
 * capsule (`radius.global.button` = height ÷ 2), full width — the caller applies
 * `size.global.buttonMarginH` (or `size.global.screenMargin` inside a plan card). The label keeps
 * `radius.global.button` clear of the ends. Disabled (captured dark, TC-R3): fill `color.global.controlRaised`,
 * label `color.global.onAccent`; light disabled not captured (Gap). [loading]: the label is replaced by the
 * platform progress indicator in the label colour (PLATFORM; Retro's busy button not captured — Gap) and the
 * button keeps its label for TalkBack. Pressed: platform default + `haptic.global.tap`.
 */
@Composable
fun PrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    size: PrimaryButtonSize = PrimaryButtonSize.Form,
    loading: Boolean = false,
    onMedia: Boolean = false,
) {
    val fill: Color
    val label: Color
    when {
        !enabled -> { fill = Tokens.Colors.globalControlRaised; label = Tokens.Colors.globalOnAccent }
        onMedia -> { fill = Tokens.Colors.globalSurfaceLight; label = Tokens.Colors.globalOnSurfaceLight }
        else -> { fill = Tokens.Colors.globalAccent; label = Tokens.Colors.globalOnAccent }
    }
    Box(
        modifier
            .fillMaxWidth()
            .heightIn(min = size.height)
            .clip(CircleShape)
            .background(fill, CircleShape)
            .tapClickable(enabled = enabled && !loading, onClick = onClick)
            .then(if (loading) Modifier.semantics { contentDescription = text } else Modifier)
            .padding(horizontal = Tokens.Radii.globalButton),
        contentAlignment = Alignment.Center,
    ) {
        if (loading) {
            CircularProgressIndicator(color = label)
        } else {
            Text(text, style = TextRoles.button, color = label, textAlign = TextAlign.Center)
        }
    }
}

/** The three C-06 capsule variants. */
enum class CapsuleStyle {
    /** Fill `color.global.accent`, label `color.global.onAccent` ("Accept"). */
    Primary,

    /** No fill, 1 pt `color.global.textPrimary` border, label `color.global.textPrimary` ("Share Profile"). */
    Outline,

    /** Fill: on Android `color.global.surfaceSecondary.android` (chips; iOS `color.global.control`), label `color.global.textPrimary` ("Create"). */
    Fill,
}

private data class CapsuleColors(val fill: Color, val border: Color?, val label: Color)

@Composable
private fun capsuleColors(style: CapsuleStyle, enabled: Boolean): CapsuleColors = when {
    // Disabled: the captured dark primary capsule (TC-R3); outline / fill disabled not captured (Gap) —
    // their label and border use the tertiary / disabled text role.
    !enabled && style == CapsuleStyle.Primary -> CapsuleColors(Tokens.Colors.globalControlRaised, null, Tokens.Colors.globalOnAccent)
    !enabled && style == CapsuleStyle.Outline -> CapsuleColors(Color.Transparent, Tokens.Colors.globalTextTertiary, Tokens.Colors.globalTextTertiary)
    !enabled -> CapsuleColors(PageRoles.secondarySurface, null, Tokens.Colors.globalTextTertiary)
    style == CapsuleStyle.Primary -> CapsuleColors(Tokens.Colors.globalAccent, null, Tokens.Colors.globalOnAccent)
    style == CapsuleStyle.Outline -> CapsuleColors(Color.Transparent, Tokens.Colors.globalTextPrimary, Tokens.Colors.globalTextPrimary)
    else -> CapsuleColors(PageRoles.secondarySurface, null, Tokens.Colors.globalTextPrimary)
}

private fun Modifier.capsule(colors: CapsuleColors): Modifier =
    clip(CircleShape)
        .background(colors.fill, CircleShape)
        .then(if (colors.border != null) Modifier.border(BorderStroke(Outline.width, colors.border), CircleShape) else Modifier)

/**
 * C-06 Medium capsule (37 pt): [style] primary · outline · fill; label text role `pill` (15 semibold);
 * height `size.global.pillHeight` (grows with large text). In an action row the caller gives each capsule
 * `Modifier.weight(1f)` (equal widths) and spaces them `size.global.pillGap`; alone it hugs its label with
 * `size.global.pillPaddingTrailing` (label → edge, H43) on both sides (Retro's text-only pill padding, APK
 * 12 dp, has no token — reported gap). Pressed: platform default + `haptic.global.tap`.
 */
@Composable
fun Capsule(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    style: CapsuleStyle = CapsuleStyle.Outline,
    enabled: Boolean = true,
) {
    val colors = capsuleColors(style, enabled)
    Box(
        modifier
            .heightIn(min = Tokens.Sizes.globalPillHeight)
            .capsule(colors)
            .tapClickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = Tokens.Sizes.globalPillPaddingTrailing),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = TextRoles.pill, color = colors.label, textAlign = TextAlign.Center)
    }
}

/**
 * C-06 selected toggle ("I'm in this", composition per mechanics): outline when off → primary fill when on
 * (the two captured variants; a captured toggle is a Gap). Toggling plays `haptic.global.select`. TalkBack:
 * a checkbox with the label.
 */
@Composable
fun CapsuleToggle(
    text: String,
    selected: Boolean,
    onSelectedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    val colors = capsuleColors(if (selected) CapsuleStyle.Primary else CapsuleStyle.Outline, enabled)
    Box(
        modifier
            .heightIn(min = Tokens.Sizes.globalPillHeight)
            .capsule(colors)
            .tickToggleable(value = selected, enabled = enabled, role = Role.Checkbox, onValueChange = onSelectedChange)
            .padding(horizontal = Tokens.Sizes.globalPillPaddingTrailing),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = TextRoles.pill, color = colors.label, textAlign = TextAlign.Center)
    }
}

/**
 * C-06 icon-only capsule (the gear after "Recaps / Share Profile"): width `size.global.iconPillWidth`,
 * height `size.global.pillHeight`, glyph `size.global.iconSmall` (e.g. `icon.global.settings`) in the label
 * colour of [style]; label from copy.
 */
@Composable
fun IconCapsule(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    style: CapsuleStyle = CapsuleStyle.Outline,
    enabled: Boolean = true,
) {
    val colors = capsuleColors(style, enabled)
    Box(
        modifier
            .widthIn(min = Tokens.Sizes.globalIconPillWidth)
            .heightIn(min = Tokens.Sizes.globalPillHeight)
            .capsule(colors)
            .tapClickable(enabled = enabled, onClick = onClick)
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = colors.label, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
    }
}

/** Spacing of capsules side by side in an action row (`size.global.pillGap`). */
val CapsuleRowSpacing: Arrangement.Horizontal get() = Arrangement.spacedBy(Tokens.Sizes.globalPillGap)

/**
 * C-07 Outline CTA with icon ("+ Get this week started"): hug-width outline capsule, 1 pt
 * `color.global.textPrimary` border; leading `size.global.pillPaddingLeading` → glyph [icon] (`icon.global.add`)
 * at `size.global.iconSmall` → `size.global.pillIconGap` → label (text role `pill`) →
 * `size.global.pillPaddingTrailing`; height `size.global.pillHeight`, capsule. The empty state's action (C-27).
 */
@Composable
fun OutlineCta(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector = Tokens.Icons.globalAdd,
    enabled: Boolean = true,
) {
    val colors = capsuleColors(CapsuleStyle.Outline, enabled)
    Row(
        modifier
            .heightIn(min = Tokens.Sizes.globalPillHeight)
            .capsule(colors)
            .tapClickable(enabled = enabled, onClick = onClick)
            .padding(PaddingValues(start = Tokens.Sizes.globalPillPaddingLeading, end = Tokens.Sizes.globalPillPaddingTrailing)),
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillIconGap),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null, tint = colors.label, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
        Text(text, style = TextRoles.pill, color = colors.label)
    }
}

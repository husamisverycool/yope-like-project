package app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import app.designsystem.generated.Tokens
import app.ui.haptics.rememberHaptics
import app.ui.text.TextRoles

/**
 * The selection circle of Yope's pickers: checked = `icon.global.check` in `color.global.selection`,
 * unchecked = `icon.global.uncheck` in `color.global.textSecondary` (inactive glyph role), both at
 * `size.global.checkCircle`. Decorative: the owning row carries the state.
 *
 * The token is the visible circle's diameter. Material Symbols draw on a 24-unit grid whose circle
 * glyphs fill the 20-unit live area (2 units of padding per side, Material "Designing icons": 24dp
 * icon, 20dp live area), so the glyph is scaled by 24/20 around its centre; the layout box stays
 * `size.global.checkCircle`, so the row's measured positions don't move.
 */
@Composable
fun CheckCircle(checked: Boolean, modifier: Modifier = Modifier) {
    Icon(
        if (checked) Tokens.Icons.globalCheck else Tokens.Icons.globalUncheck,
        contentDescription = null,
        tint = if (checked) Tokens.Colors.globalSelection else Tokens.Colors.globalTextSecondary,
        modifier = modifier
            .size(Tokens.Sizes.globalCheckCircle)
            .graphicsLayer { scaleX = MATERIAL_GLYPH_TO_LIVE_AREA; scaleY = MATERIAL_GLYPH_TO_LIVE_AREA },
    )
}

/** Material icon grid / live area = 24 / 20 (PLATFORM: Material Design "Designing icons"). */
private const val MATERIAL_GLYPH_TO_LIVE_AREA = 24f / 20f // provenance-ok: Material icon grid 24 over live area 20 (PLATFORM)

/**
 * A toggle row with a trailing [CheckCircle] (`auth.agegate.layout.optIn`): label text role
 * `listSubtitle` in `color.global.textPrimary`, optional detail in the same role in
 * `color.global.textSecondary`. The whole row toggles; TalkBack reads it as one checkbox
 * (`Role.Checkbox`) labelled [accessibilityLabel], followed by the detail (Compose has no hint
 * property, so the detail is read after the label). Plays
 * `haptic.global.select` on change.
 */
@Composable
fun CheckRow(
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    accessibilityLabel: String,
    modifier: Modifier = Modifier,
    detail: String? = null,
) {
    val haptics = rememberHaptics()
    Row(
        modifier
            .fillMaxWidth()
            .toggleable(value = checked, role = Role.Checkbox) {
                haptics.perform(Tokens.Haptics.globalSelect)
                onCheckedChange(it)
            }
            .semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalHeaderGap),
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                label,
                style = TextRoles.listSubtitle,
                color = Tokens.Colors.globalTextPrimary,
                modifier = Modifier.semantics { contentDescription = accessibilityLabel },
            )
            if (detail != null) Text(detail, style = TextRoles.listSubtitle, color = Tokens.Colors.globalTextSecondary)
        }
        CheckCircle(checked)
    }
}

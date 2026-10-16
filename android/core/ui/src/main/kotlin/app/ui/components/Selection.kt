package app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import app.designsystem.generated.Tokens
import app.ui.foundation.PageRoles
import app.ui.foundation.tickToggleable
import app.ui.text.TextRoles

/**
 * The selection circle (`size.global.checkCircle`): checked = `icon.global.check` (filled — a state) in the
 * platform tint (`color.global.system.primary` on Android; iOS `color.global.selection`), unchecked =
 * `icon.global.uncheck` (empty ring) in secondary text. Decorative: the owning row carries the state.
 *
 * The token is the visible circle's diameter. Material Symbols draw on a 24-unit grid whose circle glyphs fill
 * the 20-unit live area, so the glyph is scaled by 24/20 around its centre; the layout box stays
 * `size.global.checkCircle`.
 */
@Composable
fun CheckCircle(checked: Boolean, modifier: Modifier = Modifier) {
    Icon(
        if (checked) Tokens.Icons.globalCheck else Tokens.Icons.globalUncheck,
        contentDescription = null,
        tint = if (checked) MaterialTheme.colorScheme.primary else PageRoles.secondaryText(),
        modifier = modifier
            .size(Tokens.Sizes.globalCheckCircle)
            .graphicsLayer { scaleX = MATERIAL_GLYPH_TO_LIVE_AREA; scaleY = MATERIAL_GLYPH_TO_LIVE_AREA },
    )
}

/** Material icon grid / live area = 24 / 20 (PLATFORM: Material Design "Designing icons"). */
private const val MATERIAL_GLYPH_TO_LIVE_AREA = 24f / 20f // provenance-ok: Material icon grid 24 over live area 20 (PLATFORM)

/**
 * A toggle row with a trailing [CheckCircle]: label text role `body` in `color.global.textPrimary`, optional
 * detail text role `meta` in secondary text; the whole row toggles as one checkbox labelled
 * [accessibilityLabel] (copy), the detail read after it. Plays `haptic.global.select` on change. Row and
 * circle sit `size.global.cardNameGap` apart (no measured gap for this composition).
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
    Row(
        modifier
            .fillMaxWidth()
            .tickToggleable(value = checked, role = Role.Checkbox, onValueChange = onCheckedChange)
            .semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalCardNameGap),
    ) {
        Column(Modifier.weight(1f)) {
            Text(label, style = TextRoles.body, color = Tokens.Colors.globalTextPrimary, modifier = Modifier.semantics { contentDescription = accessibilityLabel })
            if (detail != null) Text(detail, style = TextRoles.meta, color = PageRoles.secondaryText())
        }
        CheckCircle(checked)
    }
}

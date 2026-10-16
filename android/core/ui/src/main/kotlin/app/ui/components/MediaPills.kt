package app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import app.designsystem.generated.Tokens
import app.ui.foundation.tapClickable
import app.ui.text.TextRoles

/** The two C-09 pills drawn on media. */
enum class MediaPillStyle {
    /** White capsule ("Share" on the recap preview): fill `color.global.surfaceLight`, label `color.global.onSurfaceLight`. */
    Light,

    /** Dark pill on a photo ("Add a message"): fill `color.global.controlOnDeep` (reads opaque, ST-03), label and glyph `color.global.textOnMedia`. */
    Dark,
}

/**
 * C-09 Light pill on media (and its dark "Add a message" variant). Label text role `pill`; height
 * `size.global.pillHeight` (the pill's own height is not isolated — Gap); width hugs the label. With [icon]
 * (`icon.global.edit` on the dark variant) the C-07 geometry applies (`pillPaddingLeading` → glyph
 * `iconSmall` → `pillIconGap` → label → `pillPaddingTrailing`); text only, `pillPaddingTrailing` both sides
 * (Retro's ≈61 pt "Share" pill implies APK 12 dp padding, which has no token — reported gap).
 * Pressed: platform default + `haptic.global.tap`.
 */
@Composable
fun MediaPill(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    style: MediaPillStyle = MediaPillStyle.Light,
    icon: ImageVector? = null,
) {
    val fill = if (style == MediaPillStyle.Light) Tokens.Colors.globalSurfaceLight else Tokens.Colors.globalControlOnDeep
    val label = if (style == MediaPillStyle.Light) Tokens.Colors.globalOnSurfaceLight else Tokens.Colors.globalTextOnMedia
    val start = if (icon != null) Tokens.Sizes.globalPillPaddingLeading else Tokens.Sizes.globalPillPaddingTrailing
    Row(
        modifier
            .heightIn(min = Tokens.Sizes.globalPillHeight)
            .clip(CircleShape)
            .background(fill, CircleShape)
            .tapClickable(onClick = onClick)
            .padding(PaddingValues(start = start, end = Tokens.Sizes.globalPillPaddingTrailing)),
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillIconGap),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) Icon(icon, contentDescription = null, tint = label, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
        Text(text, style = TextRoles.pill, color = label, maxLines = 1)
    }
}

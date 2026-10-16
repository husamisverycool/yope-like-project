package app.ui.components

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.HorizontalDivider
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import app.designsystem.generated.Tokens

/**
 * C-32 Divider: `size.global.hairline` (android: 1 device pixel at any density) in `color.global.separator`
 * (#CCCCCC / #4D4D4D), full width of its parent (the caller keeps it inside the margins). Used sparingly:
 * between the viewer footer and comments, above "Total", between grouped rows. On media surfaces
 * ([onMedia], the black viewer in both appearances) it is the separator's dark value. Decorative (no
 * semantics).
 */
@Composable
fun Hairline(modifier: Modifier = Modifier, onMedia: Boolean = false) {
    val onePixel = with(LocalDensity.current) { ONE_DEVICE_PIXEL.toDp() }
    val color = if (onMedia) Tokens.ColorsDark.globalSeparator else Tokens.Colors.globalSeparator
    HorizontalDivider(modifier.fillMaxWidth(), thickness = onePixel, color = color)
}

/** `size.global.hairline` android value: "1 device pixel". */
private const val ONE_DEVICE_PIXEL = 1f

package app.ui.components

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.HorizontalDivider
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import app.designsystem.generated.Tokens

/**
 * The row hairline of app (Yope-referenced) surfaces: `color.global.separator`, one physical pixel
 * thick at any density (the token's note: "Android 1 px"). Yope itself separates cards with gaps
 * (`size.global.listGap`), so draw this only where a surface's spec names the separator; system
 * surfaces use `SystemDivider` (`color.global.system.outline`).
 */
@Composable
fun Hairline(modifier: Modifier = Modifier) {
    val onePixel = with(LocalDensity.current) { ONE_PHYSICAL_PIXEL.toDp() }
    HorizontalDivider(modifier.fillMaxWidth(), thickness = onePixel, color = Tokens.Colors.globalSeparator)
}

private const val ONE_PHYSICAL_PIXEL = 1f

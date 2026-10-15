package app.designsystem

import androidx.compose.animation.core.SpringSpec
import androidx.compose.animation.core.spring
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.DeviceFontFamilyName
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset

/**
 * A font family named by a `font` token (`Tokens.Fonts.*`). `System` is the platform face
 * (Roboto / the device default), level PLATFORM.
 */
@Immutable
sealed interface DSFontFamily {
    data object System : DSFontFamily

    /**
     * A named family: a font resource bundled under `res/font/` whose file name is [resourceName],
     * else a font installed on the device under [name].
     */
    data class Custom(val name: String) : DSFontFamily {
        val resourceName: String get() = name.lowercase().replace(Regex("[^a-z0-9_]+"), "_").trim('_')
    }
}

/** Resolves the family. Bundled fonts are looked up by resource name, so adding one needs no code. */
@Composable
fun DSFontFamily.toFontFamily(): FontFamily {
    val context = LocalContext.current
    return remember(this) {
        when (this) {
            DSFontFamily.System -> FontFamily.Default
            is DSFontFamily.Custom -> {
                @Suppress("DiscouragedApi") // name-based lookup is the point: tokens name fonts by string
                val id = context.resources.getIdentifier(resourceName, "font", context.packageName)
                if (id != 0) FontFamily(Font(id)) else FontFamily(Font(DeviceFontFamilyName(name)))
            }
        }
    }
}

/**
 * A `shadow` token. [blur] is the shadow's blur radius as measured in the source; [x]/[y] the
 * offset. The color carries the token's opacity.
 */
@Immutable
data class DSShadow(val color: Color, val blur: Dp, val x: Dp, val y: Dp) {
    fun toShadow(): Shadow = Shadow(radius = blur, color = color, offset = DpOffset(x, y))
}

/** Draws [shadow] behind the content, outside [shape]. */
fun Modifier.dsShadow(shadow: DSShadow, shape: Shape): Modifier = dropShadow(shape, shadow.toShadow())

/**
 * A `spring` token. Generated from SwiftUI response/dampingFraction (mass 1) by designgen:
 * `stiffness = (2π / response)²`, `dampingRatio = dampingFraction`.
 */
@Immutable
data class DSSpring(val dampingRatio: Float, val stiffness: Float) {
    fun <T> spec(visibilityThreshold: T? = null): SpringSpec<T> =
        spring(dampingRatio = dampingRatio, stiffness = stiffness, visibilityThreshold = visibilityThreshold)
}

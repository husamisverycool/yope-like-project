package app.designsystem

import androidx.compose.animation.core.SpringSpec
import androidx.compose.animation.core.spring
import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.DeviceFontFamilyName
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import app.designsystem.generated.Tokens

/**
 * A font family named by a `font` token (`Tokens.Fonts.*`). `System` is the platform face
 * (Roboto / the device default), level PLATFORM.
 */
@Immutable
sealed interface DSFontFamily {
    data object System : DSFontFamily

    /** The platform serif (Noto Serif), level PLATFORM: fills a serif role until a licensed face is bundled. */
    data object Serif : DSFontFamily

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
    return remember(this, context) { toFontFamily(context) }
}

/**
 * Resolves the family outside composition (notifications, widgets, measurement). A bundled font
 * (`res/font/<resourceName>`) is a **variable** font with a `wght` axis (Inter Variable 4.001, axes
 * `opsz` 14–32 and `wght` 100–900 — design/research/retro-package-copy-motion.md §2.2): every weight in
 * [DSVariableWeights] is registered as its own instance of the axis
 * (`Font(id, FontWeight(w), variationSettings = FontVariation.Settings(FontVariation.weight(w)))`), so
 * `FontWeight(450)` draws the font at wght 450 — the weight Retro's Android body text uses
 * (`layout.global.variableWeight.android.body`) — instead of a synthesized or nearest static face.
 */
fun DSFontFamily.toFontFamily(context: Context): FontFamily = when (this) {
    DSFontFamily.System -> FontFamily.Default
    DSFontFamily.Serif -> FontFamily.Serif
    is DSFontFamily.Custom -> {
        @Suppress("DiscouragedApi") // name-based lookup is the point: tokens name fonts by string
        val id = context.resources.getIdentifier(resourceName, "font", context.packageName)
        if (id != 0) variableFamily(id) else FontFamily(Font(DeviceFontFamilyName(name)))
    }
}

/**
 * The `wght` instances registered for a bundled variable font: the font's nine named instances (its
 * `fvar` table: Thin 100 … Black 900, the CSS / OpenType weight classes) plus every weight the tokens
 * name off that grid (`layout.global.variableWeight.android`: body 450). A requested weight that is not
 * in the list resolves to the nearest one (Compose font matching, CSS rules).
 */
object DSVariableWeights {
    val all: List<FontWeight> by lazy {
        val named = (FontWeight.W100.weight..FontWeight.W900.weight step NAMED_INSTANCE_STEP).map(::FontWeight)
        val tokens = listOf(FontWeight(Tokens.Layouts.GlobalVariableWeightAndroid.body.toInt()))
        (named + tokens).distinct().sortedBy { it.weight }
    }

    /** OpenType weight classes are hundreds (OS/2 usWeightClass; the font's fvar instances 100, 200 … 900). */
    private const val NAMED_INSTANCE_STEP = 100
}

private val variableFamilies = HashMap<Int, FontFamily>()

/** One [FontFamily] per resource: Compose caches typefaces per family instance, so it is shared. */
private fun variableFamily(resId: Int): FontFamily = synchronized(variableFamilies) {
    variableFamilies.getOrPut(resId) {
        FontFamily(
            DSVariableWeights.all.map { weight ->
                Font(resId, weight, FontStyle.Normal, variationSettings = FontVariation.Settings(FontVariation.weight(weight.weight)))
            },
        )
    }
}

/**
 * A `shadow` token. [blur] is the shadow's Gaussian σ as measured in the source (the tokens' convention: iOS
 * `.shadow(radius:)` takes it as is); [x]/[y] the offset. The color carries the token's opacity.
 */
@Immutable
data class DSShadow(val color: Color, val blur: Dp, val x: Dp, val y: Dp)

/**
 * Draws [shadow] behind the content, outside [shape]. Compose's shadow radius is a blur radius that the platform turns
 * into σ = 0.57735 · r + 0.5 px ([blurRadiusForSigma]), so the token's σ is converted first — passed as is, the album
 * cover's shadow measured σ ≈ 4.9 dp instead of 8.5 on the render.
 */
fun Modifier.dsShadow(shadow: DSShadow, shape: Shape): Modifier = dropShadow(shape) {
    radius = blurRadiusForSigma(shadow.blur.toPx())
    color = shadow.color
    offset = Offset(shadow.x.toPx(), shadow.y.toPx())
}

/**
 * The blur radius (px) for a Gaussian σ (px): Android's blurs (`Modifier.blur`, shadows) take a "radius" r that hwui
 * turns into σ = 0.57735 · r + 0.5 px (frameworks/base libs/hwui/utils/Blur.cpp, `Blur::convertRadiusToSigma`;
 * Skia's convention; PLATFORM), so a token σ is passed as r = (σ − 0.5) / 0.57735. The one formula for every blur and
 * shadow drawn from a σ token (core:ui `BlurredBackdrop`, [dsShadow]).
 */
fun blurRadiusForSigma(sigmaPx: Float): Float =
    ((sigmaPx - HWUI_SIGMA_OFFSET) / HWUI_SIGMA_SCALE).coerceAtLeast(0f)

private const val HWUI_SIGMA_SCALE = 0.57735f // provenance-ok: hwui Blur::convertRadiusToSigma scale (platform constant)
private const val HWUI_SIGMA_OFFSET = 0.5f // provenance-ok: hwui Blur::convertRadiusToSigma offset in px (platform constant)

/**
 * A `spring` token. Generated from SwiftUI response/dampingFraction (mass 1) by designgen:
 * `stiffness = (2π / response)²`, `dampingRatio = dampingFraction`.
 */
@Immutable
data class DSSpring(val dampingRatio: Float, val stiffness: Float) {
    fun <T> spec(visibilityThreshold: T? = null): SpringSpec<T> =
        spring(dampingRatio = dampingRatio, stiffness = stiffness, visibilityThreshold = visibilityThreshold)
}

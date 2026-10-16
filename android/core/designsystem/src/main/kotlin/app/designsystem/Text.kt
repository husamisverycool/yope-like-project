package app.designsystem

import android.icu.util.ULocale
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import java.util.Locale

/*
 * Text built from tokens. Token font sizes are sp, so text follows the person's font-size
 * setting (including Android 14+ non-linear scaling) with no cap anywhere: layouts adapt instead.
 */

/** A text style from token values (`Tokens.FontSizes.*`, `Tokens.FontWeights.*`, ...). */
fun dsTextStyle(
    size: TextUnit,
    weight: FontWeight,
    family: FontFamily = FontFamily.Default,
    lineHeight: TextUnit = TextUnit.Unspecified,
    tracking: TextUnit = TextUnit.Unspecified,
): TextStyle {
    require(size.isSp) { "font size tokens are sp" }
    return TextStyle(fontSize = size, fontWeight = weight, fontFamily = family, lineHeight = lineHeight, letterSpacing = tracking)
}

/** Same as [dsTextStyle], resolving a `font` token. */
@Composable
fun dsTextStyle(
    size: TextUnit,
    weight: FontWeight,
    family: DSFontFamily,
    lineHeight: TextUnit = TextUnit.Unspecified,
    tracking: TextUnit = TextUnit.Unspecified,
): TextStyle = dsTextStyle(size, weight, family.toFontFamily(), lineHeight, tracking)

/**
 * A length that grows with text, for things sized relative to a line of text (an icon inline
 * with a label): the sp token converted at the current font scale.
 */
@Composable
@ReadOnlyComposable
fun scaledDp(size: TextUnit): Dp = with(LocalDensity.current) { size.toDp() }

/** The person's font scale, for layouts that rearrange at large text sizes. */
@Composable
@ReadOnlyComposable
fun currentFontScale(): Float = LocalDensity.current.fontScale

/**
 * Letter-spacing as Retro's Android app applies it (design/tokens/README.md → "Platform pairs";
 * retro-package-copy-motion.md §2.3, `hh3.p0`): the `letterSpacing` token only when the locale's script
 * is Latin, else 0 (tracking tuned for Latin glyphs is not applied to other scripts).
 */
object DSTracking {
    /** ISO 15924 code of the Latin script, as ICU reports it. */
    private const val LATIN = "Latn"

    /** Whether [locale] writes in the Latin script (its explicit script, else the likely one for its language and region). */
    fun isLatinScript(locale: Locale): Boolean = ULocale.addLikelySubtags(ULocale.forLocale(locale)).script == LATIN

    /** [tracking] for [locale]: the token when the script is Latin, else 0 sp. */
    fun forLocale(tracking: TextUnit, locale: Locale): TextUnit = if (isLatinScript(locale)) tracking else 0.sp // provenance-ok: 0 = no tracking (non-Latin rule)
}

/** [tracking] for the current configuration's primary locale (see [DSTracking]). */
@Composable
@ReadOnlyComposable
fun dsTracking(tracking: TextUnit): TextUnit = DSTracking.forLocale(tracking, LocalConfiguration.current.locales[0])

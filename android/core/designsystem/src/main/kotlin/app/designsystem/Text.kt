package app.designsystem

import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit

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

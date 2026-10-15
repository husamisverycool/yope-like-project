package app.feature.capture.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import app.designsystem.toFontFamily
import app.designsystem.generated.Tokens

/**
 * Text roles of the capture screens, every one built from `fontSize` / `fontWeight` tokens in the
 * platform family (`font.global.family`). Sizes are sp, so they follow the font-size setting.
 * A role without a weight token keeps the platform's regular face (no weight is invented).
 */
internal object CaptureText {
    @Composable
    fun style(size: TextUnit, weight: FontWeight?, italic: Boolean = false, tabularDigits: Boolean = false): TextStyle =
        TextStyle(
            fontSize = size,
            fontWeight = weight,
            fontStyle = if (italic) FontStyle.Italic else null,
            fontFamily = Tokens.Fonts.globalFamily.toFontFamily(),
            fontFeatureSettings = if (tabularDigits) TABULAR_DIGITS else null,
        )

    /** OpenType tabular figures: the countdown's monospaced digits (daily.capture). */
    private const val TABULAR_DIGITS = "tnum"

    val overlayTimeCamera @Composable get() = style(Tokens.FontSizes.globalOverlayTimeCamera, Tokens.FontWeights.fontWeightGlobalOverlayTimeCamera)
    val sheetTitle @Composable get() = style(Tokens.FontSizes.globalSheetTitle, Tokens.FontWeights.fontWeightGlobalSheetTitle)
    val headerTitle @Composable get() = style(Tokens.FontSizes.globalHeaderTitle, Tokens.FontWeights.fontWeightGlobalHeaderTitle)
    val button @Composable get() = style(Tokens.FontSizes.globalButton, Tokens.FontWeights.fontWeightGlobalButton)
    val body @Composable get() = style(Tokens.FontSizes.globalBody, Tokens.FontWeights.fontWeightGlobalBody)
    val emptyTitle @Composable get() = style(Tokens.FontSizes.globalEmptyTitle, Tokens.FontWeights.fontWeightGlobalEmptyTitle)

    /** `fontSize.global.emptyDetail`, italic (README: empty-state detail line); weight not measured. */
    val emptyDetail @Composable get() = style(Tokens.FontSizes.globalEmptyDetail, null, italic = true)
}

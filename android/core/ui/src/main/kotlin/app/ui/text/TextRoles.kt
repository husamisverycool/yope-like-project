package app.ui.text

import androidx.compose.runtime.Composable
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import app.designsystem.dsTextStyle
import app.designsystem.generated.Tokens
import app.designsystem.toFontFamily

/**
 * The global text roles of `design/tokens/README.md` ("A text role is four tokens with the same role
 * name"), built from `fontSize.global.<role>` (sp: they scale with the person's font size),
 * `fontWeight.global.<role>` where measured, `lineHeight.global.<role>` where measured (otherwise the
 * platform's default leading) and `font.global.family`. Colours are not part of a role: callers pass
 * the `color.*` token of their element.
 *
 * Roles without a measured weight (`placeholder`, `emptyDetail`) leave the weight unset, so the
 * platform default applies (tokens README → "Not available yet").
 */
object TextRoles {
    /** `fontSize.global.onboardingTitle` 40 / heavy — onboarding and sign-up big titles. */
    val onboardingTitle: TextStyle
        @Composable get() = role(Tokens.FontSizes.globalOnboardingTitle, Tokens.FontWeights.fontWeightGlobalOnboardingTitle)

    /** `fontSize.global.sheetTitle` 19.5 / bold. */
    val sheetTitle: TextStyle
        @Composable get() = role(Tokens.FontSizes.globalSheetTitle, Tokens.FontWeights.fontWeightGlobalSheetTitle)

    /** `fontSize.global.headerTitle` 15 / bold — group name in the header capsule. */
    val headerTitle: TextStyle
        @Composable get() = role(Tokens.FontSizes.globalHeaderTitle, Tokens.FontWeights.fontWeightGlobalHeaderTitle)

    /** `fontSize.global.listTitle` 17.5 / bold. */
    val listTitle: TextStyle
        @Composable get() = role(Tokens.FontSizes.globalListTitle, Tokens.FontWeights.fontWeightGlobalListTitle)

    /** `fontSize.global.listSubtitle` 14 / regular. */
    val listSubtitle: TextStyle
        @Composable get() = role(Tokens.FontSizes.globalListSubtitle, Tokens.FontWeights.fontWeightGlobalListSubtitle)

    /** `fontSize.global.body` 17 / regular. */
    val body: TextStyle
        @Composable get() = role(Tokens.FontSizes.globalBody, Tokens.FontWeights.fontWeightGlobalBody)

    /** `fontSize.global.button` 15 / semibold — primary button and pill labels. */
    val button: TextStyle
        @Composable get() = role(Tokens.FontSizes.globalButton, Tokens.FontWeights.fontWeightGlobalButton)

    /** `fontSize.global.caption` 12 / semibold, `lineHeight.global.caption` 15.2. */
    val caption: TextStyle
        @Composable get() = dsTextStyle(
            Tokens.FontSizes.globalCaption,
            Tokens.FontWeights.fontWeightGlobalCaption,
            Tokens.Fonts.globalFamily,
            lineHeight = Tokens.LineHeights.globalCaption,
        )

    /** `fontSize.global.sectionLabel` 16 / semibold. */
    val sectionLabel: TextStyle
        @Composable get() = role(Tokens.FontSizes.globalSectionLabel, Tokens.FontWeights.fontWeightGlobalSectionLabel)

    /** `fontSize.global.emptyTitle` 16 / bold. */
    val emptyTitle: TextStyle
        @Composable get() = role(Tokens.FontSizes.globalEmptyTitle, Tokens.FontWeights.fontWeightGlobalEmptyTitle)

    /** `fontSize.global.emptyDetail` 14, italic (weight not measured). */
    val emptyDetail: TextStyle
        @Composable get() = TextStyle(
            fontSize = Tokens.FontSizes.globalEmptyDetail,
            fontStyle = FontStyle.Italic,
            fontFamily = Tokens.Fonts.globalFamily.toFontFamily(),
        )

    /** `fontSize.global.placeholder` 17 (weight not measured). */
    val placeholder: TextStyle
        @Composable get() = TextStyle(fontSize = Tokens.FontSizes.globalPlaceholder, fontFamily = Tokens.Fonts.globalFamily.toFontFamily())

    /** `fontSize.global.overlayTime` 21 / heavy — time centred on a photo. */
    val overlayTime: TextStyle
        @Composable get() = role(Tokens.FontSizes.globalOverlayTime, Tokens.FontWeights.fontWeightGlobalOverlayTime)

    /**
     * The italic onboarding subtitle: `auth.phone.fontSize.subtitle` 14 with `auth.phone.layout.subtitle`
     * (style italic, weight regular, centred). Colour `color.global.textPrimary` per the same layout token.
     */
    val onboardingSubtitle: TextStyle
        @Composable get() = TextStyle(
            fontSize = Tokens.FontSizes.authPhoneFontSizeSubtitle,
            fontWeight = FontWeight.Normal, // auth.phone.layout.subtitle weight "regular"
            fontStyle = FontStyle.Italic, // auth.phone.layout.subtitle style "italic"
            fontFamily = Tokens.Fonts.globalFamily.toFontFamily(),
            textAlign = TextAlign.Center,
            color = Tokens.Colors.globalTextPrimary,
        )

    @Composable
    private fun role(size: androidx.compose.ui.unit.TextUnit, weight: FontWeight): TextStyle =
        dsTextStyle(size, weight, Tokens.Fonts.globalFamily)
}

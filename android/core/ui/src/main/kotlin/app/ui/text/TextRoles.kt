package app.ui.text

import androidx.compose.runtime.Composable
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import app.designsystem.DSFontFamily
import app.designsystem.dsTextStyle
import app.designsystem.dsTracking
import app.designsystem.generated.Tokens

/**
 * The global text roles of design/tokens/README.md ("A text role is up to four tokens with the same role
 * name"): `fontSize.global.<role>` (sp — they follow the person's font size, no cap),
 * `fontWeight.global.<role>` where measured, `lineHeight.global.<role>` where measured (otherwise the
 * platform's leading), on `font.global.family` (Inter Variable on Android, true `wght` instances —
 * core:designsystem `DSVariableWeights`) or, for the display roles (`headerTitle`, `displayMedium`,
 * `displaySmall`), the bundled display faces: `font.global.display` (titles) and `font.global.displayNarrow` (headlines),
 * static instances of Roboto Serif (SIL OFL) matched to Retro's two display cuts by measurement (MERGE_DECISIONS L-8).
 *
 * Android siblings (README → Platform pairs) replace the shared value where Retro's Android app differs:
 * `body` = `fontSize.global.body.android` 14 / `lineHeight.global.body.android` 17 /
 * `layout.global.variableWeight.android.body` 450 / `letterSpacing.global.body.android` −0.3;
 * `listTitle` line 18 / tracking −0.35; `badge` line 11 / tracking −0.2. Tracking applies only when the
 * locale's script is Latin (`dsTracking`). Colours are not part of a role: callers pass the `color.*` token
 * of their element. Roles without a measured weight (`placeholder`, `tileMonth`) leave the weight to the
 * platform default (regular).
 */
object TextRoles {
    /** `headerTitle` 43 / line 48, regular, `font.global.display` — screen titles ("Week 27"), profile name, Rewind date title. */
    val headerTitle: TextStyle
        @Composable get() = display(Tokens.FontSizes.globalHeaderTitle, Tokens.FontWeights.fontWeightGlobalHeaderTitle, Tokens.LineHeights.globalHeaderTitle)

    /** `displayMedium` 34.4 regular, `font.global.displayNarrow` — headlines on cards, sheets and onboarding pages. */
    val displayMedium: TextStyle
        @Composable get() = display(Tokens.FontSizes.globalDisplayMedium, Tokens.FontWeights.fontWeightGlobalDisplayMedium, family = Tokens.Fonts.globalDisplayNarrow)

    /**
     * The title face (`font.global.display`) at the `displayMedium` size (34.4, regular): an album's (a group's) name on
     * its page and the recap list's week cards — retro.app sets album titles, and Retro its month cards (TC-2023-12), in
     * Roslindale Retro, Retro's title cut (MERGE L-8).
     */
    val displayTitle: TextStyle
        @Composable get() = display(Tokens.FontSizes.globalDisplayMedium, Tokens.FontWeights.fontWeightGlobalDisplayMedium)

    /** `displaySmall` 25.8 regular, `font.global.displayNarrow` — memory feed cards, year-story card dates and labels, the Live Activity group name. */
    val displaySmall: TextStyle
        @Composable get() = display(Tokens.FontSizes.globalDisplaySmall, Tokens.FontWeights.fontWeightGlobalDisplaySmall, family = Tokens.Fonts.globalDisplayNarrow)

    /** `onboardingTitle` 30 regular — the large grey line on the landing ("Friends Only"). */
    val onboardingTitle: TextStyle
        @Composable get() = ui(Tokens.FontSizes.globalOnboardingTitle, Tokens.FontWeights.fontWeightGlobalOnboardingTitle)

    /** `sheetTitle` 17 semibold — centred sheet / modal title. */
    val sheetTitle: TextStyle
        @Composable get() = ui(Tokens.FontSizes.globalSheetTitle, Tokens.FontWeights.fontWeightGlobalSheetTitle)

    /** `listTitle` 15 semibold, Android line 18 / tracking −0.35 — names, row titles, secondary link. */
    val listTitle: TextStyle
        @Composable get() = ui(
            Tokens.FontSizes.globalListTitle,
            Tokens.FontWeights.fontWeightGlobalListTitle,
            Tokens.LineHeights.globalListTitleAndroid,
            dsTracking(Tokens.Tracking.globalListTitleAndroid),
        )

    /** `listSubtitle` 15 regular — row subtitles, date ranges, "Week 28" in the viewer header. */
    val listSubtitle: TextStyle
        @Composable get() = ui(Tokens.FontSizes.globalListSubtitle, Tokens.FontWeights.fontWeightGlobalListSubtitle)

    /** `body` on Android: 14 / line 17 / wght 450 / tracking −0.3 (Retro's most used Android style, `wv3.c`). */
    val body: TextStyle
        @Composable get() = ui(
            Tokens.FontSizes.globalBodyAndroid,
            FontWeight(Tokens.Layouts.GlobalVariableWeightAndroid.body.toInt()),
            Tokens.LineHeights.globalBodyAndroid,
            dsTracking(Tokens.Tracking.globalBodyAndroid),
        )

    /** `button` 17 semibold — label of the 60 pt capsule. */
    val button: TextStyle
        @Composable get() = ui(Tokens.FontSizes.globalButton, Tokens.FontWeights.fontWeightGlobalButton)

    /** `pill` 15 semibold — label of the 37 pt capsules. */
    val pill: TextStyle
        @Composable get() = ui(Tokens.FontSizes.globalPill, Tokens.FontWeights.fontWeightGlobalPill)

    /** `textButton` 17 regular — app-drawn header text buttons ("Invite"). */
    val textButton: TextStyle
        @Composable get() = ui(Tokens.FontSizes.globalTextButton, Tokens.FontWeights.fontWeightGlobalTextButton)

    /** `caption` 14 regular, line 21.7 — fine print, timestamps. */
    val caption: TextStyle
        @Composable get() = ui(Tokens.FontSizes.globalCaption, Tokens.FontWeights.fontWeightGlobalCaption, Tokens.LineHeights.globalCaption)

    /** `meta` 13 regular — real name under the profile name, field labels, settings subtitles and section headers. */
    val meta: TextStyle
        @Composable get() = ui(Tokens.FontSizes.globalMeta, Tokens.FontWeights.fontWeightGlobalMeta)

    /** `placeholder` 17 (weight not measured) — placeholder and typed text in fields. */
    val placeholder: TextStyle
        @Composable get() = ui(Tokens.FontSizes.globalPlaceholder, null)

    /** `sectionLabel` 15 semibold — "Week 27" before its range; dated album headers. */
    val sectionLabel: TextStyle
        @Composable get() = ui(Tokens.FontSizes.globalSectionLabel, Tokens.FontWeights.fontWeightGlobalSectionLabel)

    /** `emptyTitle` 20 semibold. */
    val emptyTitle: TextStyle
        @Composable get() = ui(Tokens.FontSizes.globalEmptyTitle, Tokens.FontWeights.fontWeightGlobalEmptyTitle)

    /** `emptyDetail` 14 regular. */
    val emptyDetail: TextStyle
        @Composable get() = ui(Tokens.FontSizes.globalEmptyDetail, Tokens.FontWeights.fontWeightGlobalEmptyDetail)

    /** `tileLabel` 13 semibold — weekday on a photo tile. */
    val tileLabel: TextStyle
        @Composable get() = ui(Tokens.FontSizes.globalTileLabel, Tokens.FontWeights.fontWeightGlobalTileLabel)

    /** `tileDay` 28 semibold, tabular digits — day number on an empty-day tile. */
    val tileDay: TextStyle
        @Composable get() = ui(Tokens.FontSizes.globalTileDay, Tokens.FontWeights.fontWeightGlobalTileDay).copy(fontFeatureSettings = TABULAR_DIGITS)

    /** `tileMonth` 14 (weight not measured) — month / weekday lines on an empty-day tile. */
    val tileMonth: TextStyle
        @Composable get() = ui(Tokens.FontSizes.globalTileMonth, null)

    /** `badge` 11 semibold, Android line 11 / tracking −0.2 — "new" badge, relative-week pill, position pill. */
    val badge: TextStyle
        @Composable get() = ui(
            Tokens.FontSizes.globalBadge,
            Tokens.FontWeights.fontWeightGlobalBadge,
            Tokens.LineHeights.globalBadgeAndroid,
            dsTracking(Tokens.Tracking.globalBadgeAndroid),
        )

    /** `pillSmall` 13 bold — "FREE", video duration (tabular digits: "monospaced digits", PAY). */
    val pillSmall: TextStyle
        @Composable get() = ui(Tokens.FontSizes.globalPillSmall, Tokens.FontWeights.fontWeightGlobalPillSmall).copy(fontFeatureSettings = TABULAR_DIGITS)

    /**
     * M3 `bodyMedium` override of Retro's theme (`layout.global.system.typography`: "bodyMedium = Inter 14/17
     * W600"): the Android body size / line / tracking at the semibold weight (`fontWeight.global.listTitle`,
     * 600). Used only inside native components (dialogs, menus).
     */
    val systemBodyMedium: TextStyle
        @Composable get() = ui(
            Tokens.FontSizes.globalBodyAndroid,
            Tokens.FontWeights.fontWeightGlobalListTitle,
            Tokens.LineHeights.globalBodyAndroid,
            dsTracking(Tokens.Tracking.globalBodyAndroid),
        )

    /** OpenType feature: tabular (monospaced) figures. */
    private const val TABULAR_DIGITS = "tnum"

    @Composable
    private fun ui(size: TextUnit, weight: FontWeight?, lineHeight: TextUnit = TextUnit.Unspecified, tracking: TextUnit = TextUnit.Unspecified): TextStyle =
        dsTextStyle(size, weight ?: FontWeight.Normal, Tokens.Fonts.globalFamily, lineHeight, tracking)

    @Composable
    private fun display(
        size: TextUnit,
        weight: FontWeight,
        lineHeight: TextUnit = TextUnit.Unspecified,
        family: DSFontFamily = Tokens.Fonts.globalDisplay,
    ): TextStyle = dsTextStyle(size, weight, family, lineHeight)

    /** The family of the title role (`font.global.display`; exposed for measuring cap heights). */
    val displayFamily: DSFontFamily get() = Tokens.Fonts.globalDisplay
}

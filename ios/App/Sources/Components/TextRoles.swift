// Shared component — text roles (design/tokens/README.md "A text role").
// A role = `fontSize.global.<role>` + `fontWeight.global.<role>` (+ `lineHeight.global.<role>` where measured), in
// `font.global.family` (SF Pro) — or `font.global.display` (the platform serif, New York) for the display roles
// `headerTitle`, `displayMedium`, `displaySmall` — scaled with Dynamic Type relative to
// `layout.global.textStyleMap.<role>`. Screens apply them with `.dsTextStyle(TextRole.<role>)`, or `.dsTextRole(_:)`
// where a component places views by the text's baseline / cap height (ComponentSupport.swift).
import DesignSystem
import SwiftUI

extension Font.TextStyle {
    /// The SwiftUI text style named by a token or spec value (`layout.global.textStyleMap.*`,
    /// the "Dynamic Type" lines of the surface specs): "largeTitle", "title", "title2", "title3",
    /// "headline", "subheadline", "body", "callout", "footnote", "caption", "caption2".
    init(tokenName: String) {
        switch tokenName {
        case "largeTitle": self = .largeTitle
        case "title", "title1": self = .title
        case "title2": self = .title2
        case "title3": self = .title3
        case "headline": self = .headline
        case "subheadline": self = .subheadline
        case "callout": self = .callout
        case "footnote": self = .footnote
        case "caption", "caption1": self = .caption
        case "caption2": self = .caption2
        default: self = .body
        }
    }
}

/// The global text roles as `DSTextStyle`s. Roles whose weight was never measured (`placeholder`, `tileMonth`) use the
/// platform's regular weight; nothing here chooses a size.
enum TextRole {
    private static func role(
        _ size: CGFloat,
        _ weight: Font.Weight,
        _ style: String,
        family: DSFontFamily = Tokens.Fonts.globalFamily,
        lineHeight: CGFloat? = nil
    ) -> DSTextStyle {
        DSTextStyle(family: family, size: size, weight: weight, relativeTo: Font.TextStyle(tokenName: style), lineHeight: lineHeight)
    }

    // MARK: Display (serif: `font.global.display` titles, `font.global.displayNarrow` headlines — MERGE L-8)

    /// Display serif screen title ('Week 43', 'Albums', a profile name; the date title on full-bleed photos):
    /// `font.global.display`, `fontSize.global.headerTitle` 43 / `lineHeight.global.headerTitle` 48, regular
    /// (C-01, C-02, C-19, C-35).
    static let headerTitle = role(
        Tokens.FontSizes.globalHeaderTitle, Tokens.FontWeights.fontWeightGlobalHeaderTitle, Tokens.Layouts.GlobalTextStyleMap.headerTitle,
        family: Tokens.Fonts.globalDisplay, lineHeight: Tokens.LineHeights.globalHeaderTitle
    )
    /// Narrow display serif headline on cards, sheets and onboarding (`font.global.displayNarrow`,
    /// `fontSize.global.displayMedium` 34.4, regular; C-33).
    static let displayMedium = role(
        Tokens.FontSizes.globalDisplayMedium, Tokens.FontWeights.fontWeightGlobalDisplayMedium, Tokens.Layouts.GlobalTextStyleMap.displayMedium,
        family: Tokens.Fonts.globalDisplayNarrow
    )
    /// Small narrow display serif: recap month cards, album titles on covers, the recap year
    /// (`font.global.displayNarrow`, `fontSize.global.displaySmall` 25.8, regular; C-34).
    static let displaySmall = role(
        Tokens.FontSizes.globalDisplaySmall, Tokens.FontWeights.fontWeightGlobalDisplaySmall, Tokens.Layouts.GlobalTextStyleMap.displaySmall,
        family: Tokens.Fonts.globalDisplayNarrow
    )

    // MARK: UI text (`font.global.family`)

    /// The large grey line on the sign-up landing ('Friends Only'; `fontSize.global.onboardingTitle` 30, regular; C-33).
    static let onboardingTitle = role(Tokens.FontSizes.globalOnboardingTitle, Tokens.FontWeights.fontWeightGlobalOnboardingTitle, Tokens.Layouts.GlobalTextStyleMap.onboardingTitle)
    /// Centred sheet / modal title (`fontSize.global.sheetTitle` 17, semibold; C-29).
    static let sheetTitle = role(Tokens.FontSizes.globalSheetTitle, Tokens.FontWeights.fontWeightGlobalSheetTitle, Tokens.Layouts.GlobalTextStyleMap.sheetTitle)
    /// Name / row title, friend-card name, secondary link (`fontSize.global.listTitle` 15, semibold).
    static let listTitle = role(Tokens.FontSizes.globalListTitle, Tokens.FontWeights.fontWeightGlobalListTitle, Tokens.Layouts.GlobalTextStyleMap.listTitle)
    /// Row subtitle, date range, secondary line (`fontSize.global.listSubtitle` 15, regular).
    static let listSubtitle = role(Tokens.FontSizes.globalListSubtitle, Tokens.FontWeights.fontWeightGlobalListSubtitle, Tokens.Layouts.GlobalTextStyleMap.listSubtitle)
    /// Body / list row text (`fontSize.global.body` 15, regular).
    static let body = role(Tokens.FontSizes.globalBody, Tokens.FontWeights.fontWeightGlobalBody, Tokens.Layouts.GlobalTextStyleMap.body)
    /// Label of the 60 pt full-width capsule (`fontSize.global.button` 17, semibold; C-05).
    static let button = role(Tokens.FontSizes.globalButton, Tokens.FontWeights.fontWeightGlobalButton, Tokens.Layouts.GlobalTextStyleMap.button)
    /// Label of the 37 pt capsules (`fontSize.global.pill` 15, semibold; C-06, C-07, C-09).
    static let pill = role(Tokens.FontSizes.globalPill, Tokens.FontWeights.fontWeightGlobalPill, Tokens.Layouts.GlobalTextStyleMap.pill)
    /// App-drawn text button in a header (`fontSize.global.textButton` 17, regular; C-08).
    static let textButton = role(Tokens.FontSizes.globalTextButton, Tokens.FontWeights.fontWeightGlobalTextButton, Tokens.Layouts.GlobalTextStyleMap.textButton)
    /// Fine print and timestamps (`fontSize.global.caption` 14, regular, `lineHeight.global.caption` 21.7).
    static let caption = role(Tokens.FontSizes.globalCaption, Tokens.FontWeights.fontWeightGlobalCaption, Tokens.Layouts.GlobalTextStyleMap.caption, lineHeight: Tokens.LineHeights.globalCaption)
    /// Small secondary line: real name under a profile name, field labels, inline field errors, grouped-section headers
    /// (`fontSize.global.meta` 13, regular).
    static let meta = role(Tokens.FontSizes.globalMeta, Tokens.FontWeights.fontWeightGlobalMeta, Tokens.Layouts.GlobalTextStyleMap.meta)
    /// Placeholder and typed text in the search / text field (`fontSize.global.placeholder` 17; weight not measured →
    /// platform regular; C-12).
    static let placeholder = role(Tokens.FontSizes.globalPlaceholder, Font.Weight.regular, Tokens.Layouts.GlobalTextStyleMap.placeholder)
    /// Section header 'Week 27' (`fontSize.global.sectionLabel` 15, semibold; C-20).
    static let sectionLabel = role(Tokens.FontSizes.globalSectionLabel, Tokens.FontWeights.fontWeightGlobalSectionLabel, Tokens.Layouts.GlobalTextStyleMap.sectionLabel)
    /// Empty-state title (`fontSize.global.emptyTitle` 20, semibold; C-27).
    static let emptyTitle = role(Tokens.FontSizes.globalEmptyTitle, Tokens.FontWeights.fontWeightGlobalEmptyTitle, Tokens.Layouts.GlobalTextStyleMap.emptyTitle)
    /// Empty-state explanation (`fontSize.global.emptyDetail` 14, regular; C-27).
    static let emptyDetail = role(Tokens.FontSizes.globalEmptyDetail, Tokens.FontWeights.fontWeightGlobalEmptyDetail, Tokens.Layouts.GlobalTextStyleMap.emptyDetail)
    /// Weekday label on a photo tile (`fontSize.global.tileLabel` 13, semibold; C-17).
    static let tileLabel = role(Tokens.FontSizes.globalTileLabel, Tokens.FontWeights.fontWeightGlobalTileLabel, Tokens.Layouts.GlobalTextStyleMap.tileLabel)
    /// Day number on an empty-day tile (`fontSize.global.tileDay` 28, semibold, tabular digits; C-17).
    static let tileDay = role(Tokens.FontSizes.globalTileDay, Tokens.FontWeights.fontWeightGlobalTileDay, Tokens.Layouts.GlobalTextStyleMap.tileDay)
    /// Month and weekday lines on an empty-day tile (`fontSize.global.tileMonth` 14; weight not measured → platform
    /// regular; C-17).
    static let tileMonth = role(Tokens.FontSizes.globalTileMonth, Font.Weight.regular, Tokens.Layouts.GlobalTextStyleMap.tileMonth)
    /// Badge, relative-week pill and position pill labels (`fontSize.global.badge` 11, semibold; C-03, C-22, C-24).
    static let badge = role(Tokens.FontSizes.globalBadge, Tokens.FontWeights.fontWeightGlobalBadge, Tokens.Layouts.GlobalTextStyleMap.badge)
    /// Small pills on media / the paywall ('FREE', '1:00'; `fontSize.global.pillSmall` 13, bold; C-25).
    static let pillSmall = role(Tokens.FontSizes.globalPillSmall, Tokens.FontWeights.fontWeightGlobalPillSmall, Tokens.Layouts.GlobalTextStyleMap.pillSmall)

    // MARK: Retired roles (Pass 4 replaces the call sites)

    /// Yope's time overlay on photos (`fontSize.global.overlayTime`, removed in the redesign). Retro's on-photo text is
    /// the weekday tile label (design/tokens/README.md "Redesign renames").
    @available(*, deprecated, renamed: "tileLabel", message: "overlayTime was removed (Yope-only); Retro's on-photo text is tileLabel")
    static var overlayTime: DSTextStyle { tileLabel }

    /// Yope's italic sign-up subtitle (`auth.phone.fontSize.subtitle`). Onboarding steps compose C-27 / C-33: the line
    /// under a title is the empty-state explanation role.
    @available(*, deprecated, renamed: "emptyDetail", message: "sign-up subtitles compose C-27 / C-33 (emptyDetail, color.global.textSecondary)")
    static var signUpSubtitle: DSTextStyle { emptyDetail }

    /// Yope's form-field text (`groups.create.fontSize.fieldText`). C-12's typed text and placeholder are `placeholder`.
    @available(*, deprecated, renamed: "placeholder", message: "C-12 field text is the placeholder role")
    static var fieldText: DSTextStyle { placeholder }

    /// Yope's lime text link (`auth.code.fontSize.textLink`). C-08's secondary link is `listTitle` in
    /// `color.global.textSecondary` (use `TextButton(style: .link)`).
    @available(*, deprecated, renamed: "listTitle", message: "C-08 secondary link: TextButton(style: .link)")
    static var textLink: DSTextStyle { listTitle }
}

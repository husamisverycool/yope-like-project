// Shared component — text roles (design/tokens/README.md "A text role").
// A role = `fontSize.global.<role>` + `fontWeight.global.<role>` (+ `lineHeight.global.<role>` where measured),
// scaled with Dynamic Type relative to `layout.global.textStyleMap.<role>`. Screens apply them with
// `.dsTextStyle(TextRole.<role>)`; italic roles (`emptyDetail`, sign-up subtitles) add `.italic()` on the Text.
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

/// The global text roles as `DSTextStyle`s. Weights that were never measured (emptyDetail, the HUD label)
/// use the platform's regular weight; nothing here chooses a size.
enum TextRole {
    private static func role(_ size: CGFloat, _ weight: Font.Weight, _ style: String, lineHeight: CGFloat? = nil) -> DSTextStyle {
        DSTextStyle(family: Tokens.Fonts.globalFamily, size: size, weight: weight, relativeTo: Font.TextStyle(tokenName: style), lineHeight: lineHeight)
    }

    /// Sign-up / onboarding big title (`fontSize.global.onboardingTitle`, heavy; Dynamic Type largeTitle).
    static let onboardingTitle = role(Tokens.FontSizes.globalOnboardingTitle, Tokens.FontWeights.fontWeightGlobalOnboardingTitle, Tokens.Layouts.GlobalTextStyleMap.onboardingTitle)
    /// Sheet title between header circles (`fontSize.global.sheetTitle`, bold).
    static let sheetTitle = role(Tokens.FontSizes.globalSheetTitle, Tokens.FontWeights.fontWeightGlobalSheetTitle, Tokens.Layouts.GlobalTextStyleMap.sheetTitle)
    /// Group name in the header capsule (`fontSize.global.headerTitle`, bold).
    static let headerTitle = role(Tokens.FontSizes.globalHeaderTitle, Tokens.FontWeights.fontWeightGlobalHeaderTitle, Tokens.Layouts.GlobalTextStyleMap.headerTitle)
    /// Card / row name (`fontSize.global.listTitle`, bold).
    static let listTitle = role(Tokens.FontSizes.globalListTitle, Tokens.FontWeights.fontWeightGlobalListTitle, Tokens.Layouts.GlobalTextStyleMap.listTitle)
    /// Card / row subtitle (`fontSize.global.listSubtitle`, regular).
    static let listSubtitle = role(Tokens.FontSizes.globalListSubtitle, Tokens.FontWeights.fontWeightGlobalListSubtitle, Tokens.Layouts.GlobalTextStyleMap.listSubtitle)
    /// Body text (`fontSize.global.body`, regular).
    static let body = role(Tokens.FontSizes.globalBody, Tokens.FontWeights.fontWeightGlobalBody, Tokens.Layouts.GlobalTextStyleMap.body)
    /// Button labels (`fontSize.global.button`, semibold).
    static let button = role(Tokens.FontSizes.globalButton, Tokens.FontWeights.fontWeightGlobalButton, Tokens.Layouts.GlobalTextStyleMap.button)
    /// Small meta text and the legal footer (`fontSize.global.caption`, semibold, `lineHeight.global.caption`).
    static let caption = role(Tokens.FontSizes.globalCaption, Tokens.FontWeights.fontWeightGlobalCaption, Tokens.Layouts.GlobalTextStyleMap.caption, lineHeight: Tokens.LineHeights.globalCaption)
    /// Time overlay on a photo (`fontSize.global.overlayTime`, heavy).
    static let overlayTime = role(Tokens.FontSizes.globalOverlayTime, Tokens.FontWeights.fontWeightGlobalOverlayTime, Tokens.Layouts.GlobalTextStyleMap.overlayTime)
    /// Section label (`fontSize.global.sectionLabel`, semibold) — drawn in `color.global.textSecondary`.
    static let sectionLabel = role(Tokens.FontSizes.globalSectionLabel, Tokens.FontWeights.fontWeightGlobalSectionLabel, Tokens.Layouts.GlobalTextStyleMap.sectionLabel)
    /// Empty-state title (`fontSize.global.emptyTitle`, bold).
    static let emptyTitle = role(Tokens.FontSizes.globalEmptyTitle, Tokens.FontWeights.fontWeightGlobalEmptyTitle, Tokens.Layouts.GlobalTextStyleMap.emptyTitle)
    /// Empty-state detail (`fontSize.global.emptyDetail`; weight not measured → platform regular). Apply `.italic()`.
    static let emptyDetail = role(Tokens.FontSizes.globalEmptyDetail, Font.Weight.regular, Tokens.Layouts.GlobalTextStyleMap.emptyDetail)

    // MARK: Surface roles shared by the account group's form screens

    /// Italic subtitle under sign-up titles (`auth.phone.fontSize.subtitle`, `auth.phone.layout.subtitle`:
    /// regular; Dynamic Type subheadline per the auth.* specs). Apply `.italic()`.
    static let signUpSubtitle = DSTextStyle(family: Tokens.Fonts.globalFamily, size: Tokens.FontSizes.authPhoneFontSizeSubtitle, weight: Font.Weight.regular, relativeTo: .subheadline)
    /// Typed text and placeholder of the Yope form field (`groups.create.fontSize.fieldText` / `.fontWeight.fieldText`; subheadline).
    static let fieldText = DSTextStyle(family: Tokens.Fonts.globalFamily, size: Tokens.FontSizes.groupsCreateFontSizeFieldText, weight: Tokens.FontWeights.groupsCreateFontWeightFieldText, relativeTo: .subheadline)
    /// Lime text link (`auth.code.fontSize.textLink` / `.fontWeight.textLink`; subheadline).
    static let textLink = DSTextStyle(family: Tokens.Fonts.globalFamily, size: Tokens.FontSizes.authCodeFontSizeTextLink, weight: Tokens.FontWeights.authCodeFontWeightTextLink, relativeTo: .subheadline)
    /// Loading HUD label (`groups.create.fontSize.hudLabel`; weight not measured → regular; subheadline).
    static let hudLabel = DSTextStyle(family: Tokens.Fonts.globalFamily, size: Tokens.FontSizes.groupsCreateFontSizeHudLabel, weight: Font.Weight.regular, relativeTo: .subheadline)
}

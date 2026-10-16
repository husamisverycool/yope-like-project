// Surfaces: widget.home.small / .medium / .large / .xl, widget.lock.rect / .circular / .inline, daily.liveactivity
// (design/surfaces/<id>.md). Reference images: references/auto/retro/apk/widget_preview_journals.webp (Retro's widget
// text stack), references/auto/retro/press/tc-2023-07-retro-1b.webp (C-16 people row roles),
// references/auto/platform/hig-live-activities-ios-dimensions.png.
// Text roles of the widget extension, built from generated tokens (design/tokens/README.md "A text role"); the app's
// `TextRole` (ios/App/Sources/Components) is not linked into the extension, so the roles the widgets use are assembled
// here from the same tokens. Also compiled into AppTests (ios/AppTests/Capture/Linked) for snapshots.
import DesignSystem
import SwiftUI

/// Resolves the Dynamic Type style named by a token text-style map or a PLATFORM typography token
/// ("caption1, semibold, monospaced digits" → `.caption`).
enum WidgetTextStyleName {
    static func resolve(_ name: String) -> Font.TextStyle {
        switch firstWord(name) {
        case "largeTitle": return .largeTitle
        case "title", "title1": return .title
        case "title2": return .title2
        case "title3": return .title3
        case "headline": return .headline
        case "subheadline": return .subheadline
        case "callout": return .callout
        case "footnote": return .footnote
        case "Caption", "caption", "caption1": return .caption
        case "caption2": return .caption2
        default: return .body
        }
    }

    /// The weight a PLATFORM typography token names ("Caption 1 (12 pt) semibold, …"), if any.
    static func weight(in token: String) -> Font.Weight? {
        let words = token.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "(" || $0 == ")" }).map(String.init)
        if words.contains("semibold") { return .semibold }
        if words.contains("bold") { return .bold }
        if words.contains("medium") { return .medium }
        if words.contains("heavy") { return .heavy }
        return nil
    }

    private static func firstWord(_ name: String) -> String {
        name.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "(" }).first.map(String.init) ?? name
    }
}

enum WidgetType {
    private static func role(_ size: CGFloat, _ weight: Font.Weight, _ style: String, family: DSFontFamily = Tokens.Fonts.globalFamily) -> DSTextStyle {
        DSTextStyle(family: family, size: size, weight: weight, relativeTo: WidgetTextStyleName.resolve(style))
    }

    /// The home widget's two-line text stack (`widget.home.small.fontSize.overlay` 11, `.fontWeight.overlay` regular,
    /// Dynamic Type `widget.home.small.layout.textStyleMap.overlay` — Caption 2), also the state line.
    static var overlay: DSTextStyle {
        role(Tokens.FontSizes.widgetHomeSmallFontSizeOverlay, Tokens.FontWeights.widgetHomeSmallFontWeightOverlay, Tokens.Layouts.WidgetHomeSmallLayoutTextStyleMap.overlay)
    }

    /// C-16 name (text role `listTitle`, 15 semibold) — `widget.lock.rect`.
    static var listTitle: DSTextStyle {
        role(Tokens.FontSizes.globalListTitle, Tokens.FontWeights.fontWeightGlobalListTitle, Tokens.Layouts.GlobalTextStyleMap.listTitle)
    }

    /// C-16 second line (text role `listSubtitle`, 15 regular) — `widget.lock.rect`.
    static var listSubtitle: DSTextStyle {
        role(Tokens.FontSizes.globalListSubtitle, Tokens.FontWeights.fontWeightGlobalListSubtitle, Tokens.Layouts.GlobalTextStyleMap.listSubtitle)
    }

    /// Text role `sheetTitle` (17 semibold): the Live Activity countdown and the expanded group name.
    static var sheetTitle: DSTextStyle {
        role(Tokens.FontSizes.globalSheetTitle, Tokens.FontWeights.fontWeightGlobalSheetTitle, Tokens.Layouts.GlobalTextStyleMap.sheetTitle)
    }

    /// The group name on the Lock Screen presentation: the narrow display serif (`font.global.displayNarrow`), text role
    /// `displaySmall` (24). Its regular weight is raised to `daily.liveactivity.fontWeight.min` (medium): HIG asks every
    /// Live Activity weight to be at least medium.
    static var liveActivityGroupName: DSTextStyle {
        role(
            Tokens.FontSizes.globalDisplaySmall,
            heavier(Tokens.FontWeights.fontWeightGlobalDisplaySmall, Tokens.FontWeights.dailyLiveactivityFontWeightMin),
            Tokens.Layouts.GlobalTextStyleMap.displaySmall,
            family: Tokens.Fonts.globalDisplayNarrow
        )
    }

    /// A PLATFORM text style from `daily.liveactivity.layout.typography` ("Caption 1 (12 pt) semibold, …").
    static func platform(_ token: String) -> Font {
        let font = Font.system(WidgetTextStyleName.resolve(token))
        guard let weight = WidgetTextStyleName.weight(in: token) else { return font }
        return font.weight(weight)
    }

    private static let weightOrder: [Font.Weight] = [.ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]

    private static func heavier(_ first: Font.Weight, _ second: Font.Weight) -> Font.Weight {
        let a = weightOrder.firstIndex(of: first) ?? 0
        let b = weightOrder.firstIndex(of: second) ?? 0
        return a >= b ? first : second
    }
}

/// The bottom photo scrim (`layout.global.photoScrim`): transparent black from the top to `startAt` of the height, then
/// to `color.global.scrim` (black 60 %) at the bottom edge. Decorative.
struct WidgetPhotoScrim: View {
    var body: some View {
        let scrim = Tokens.Layouts.GlobalPhotoScrim.self
        let start = Tokens.Colors.globalScrim.opacity(scrim.startOpacity / max(scrim.endOpacity, .leastNonzeroMagnitude))
        LinearGradient(
            stops: [
                Gradient.Stop(color: start, location: 0),
                Gradient.Stop(color: start, location: scrim.startAt),
                Gradient.Stop(color: Tokens.Colors.globalScrim, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .accessibilityHidden(true)
    }
}

/// Reads the "W x H" sizes of the PLATFORM size tokens ("52.33x36.67").
enum WidgetLayoutSize {
    static func width(_ token: String) -> CGFloat? {
        guard let first = token.split(separator: "x").first, let value = Double(first) else { return nil }
        return CGFloat(value)
    }
}

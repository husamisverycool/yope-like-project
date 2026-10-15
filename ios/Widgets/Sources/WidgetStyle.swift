// Surfaces: widget.home.small / .medium / .large / .xl, widget.lock.rect / .circular / .inline,
// daily.liveactivity. Text roles of the widget extension built from generated tokens
// (design/tokens/README.md "A text role"). Also compiled into AppTests for snapshots.
import DesignSystem
import SwiftUI

/// Resolves the Dynamic Type style named by a token text-style map or a PLATFORM typography token
/// ("headline (17 pt semibold, Dynamic Type)" → `.headline`).
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
        case "caption", "caption1": return .caption
        case "caption2": return .caption2
        default: return .body
        }
    }

    /// The weight a PLATFORM typography token names ("caption1, semibold, monospaced digits"), if any.
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
    /// `widget.home.small.fontSize.caption` / `.fontWeight.caption`, Dynamic Type caption.
    static var caption: DSTextStyle {
        DSTextStyle(
            family: Tokens.Fonts.globalFamily,
            size: Tokens.FontSizes.widgetHomeSmallFontSizeCaption,
            weight: Tokens.FontWeights.widgetHomeSmallFontWeightCaption,
            relativeTo: WidgetTextStyleName.resolve(Tokens.Layouts.WidgetHomeSmallLayoutTextStyleMap.caption)
        )
    }

    /// Lock Screen countdown: `daily.capture.fontSize.countdown`. Its weight
    /// (`daily.capture.fontWeight.countdown`) is BLOCKED; every Live Activity text is at least
    /// `daily.liveactivity.fontWeight.min`, which is used until it closes.
    static var lockScreenCountdown: DSTextStyle {
        DSTextStyle(
            family: Tokens.Fonts.globalFamily,
            size: Tokens.FontSizes.dailyCaptureFontSizeCountdown,
            weight: WidgetBlocked.countdownWeight ?? Tokens.FontWeights.dailyLiveactivityFontWeightMin,
            relativeTo: WidgetTextStyleName.resolve(Tokens.Layouts.DailyCaptureLayoutTextStyleMap.countdown)
        )
    }

    /// A PLATFORM text style from `daily.liveactivity.layout.typography`.
    static func platform(_ token: String) -> Font {
        let font = Font.system(WidgetTextStyleName.resolve(token))
        guard let weight = WidgetTextStyleName.weight(in: token) else { return font }
        return font.weight(weight)
    }
}

// Dynamic Type for token font sizes. A text style is assembled by screens from tokens
// (family, size, weight, line height, tracking) plus the platform text style the size scales
// with; nothing here chooses a value.
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct DSTextStyle: Hashable, Sendable {
    public var family: DSFontFamily
    /// `Tokens.FontSizes.*` at the default content size category.
    public var size: CGFloat
    public var weight: Font.Weight
    /// The platform text style whose Dynamic Type curve `size` follows.
    public var relativeTo: Font.TextStyle
    /// `Tokens.LineHeights.*`, in points at the default content size category.
    public var lineHeight: CGFloat?
    /// `Tokens.Tracking.*`, in points.
    public var tracking: CGFloat?

    public init(
        family: DSFontFamily,
        size: CGFloat,
        weight: Font.Weight,
        relativeTo: Font.TextStyle,
        lineHeight: CGFloat? = nil,
        tracking: CGFloat? = nil
    ) {
        self.family = family
        self.size = size
        self.weight = weight
        self.relativeTo = relativeTo
        self.lineHeight = lineHeight
        self.tracking = tracking
    }
}

extension View {
    /// Applies a token text style, scaled with Dynamic Type relative to its text style.
    public func dsTextStyle(_ style: DSTextStyle) -> some View {
        modifier(DSTextStyleModifier(style: style))
    }
}

struct DSTextStyleModifier: ViewModifier {
    let style: DSTextStyle
    @ScaledMetric private var size: CGFloat
    @ScaledMetric private var lineHeight: CGFloat

    init(style: DSTextStyle) {
        self.style = style
        _size = ScaledMetric(wrappedValue: style.size, relativeTo: style.relativeTo)
        _lineHeight = ScaledMetric(wrappedValue: style.lineHeight ?? style.size, relativeTo: style.relativeTo)
    }

    func body(content: Content) -> some View {
        content
            .font(style.family.font(size: size, weight: style.weight))
            .lineSpacing(extraLineSpacing)
            .tracking(style.tracking ?? 0)
    }

    /// SwiftUI's `lineSpacing` adds space between lines on top of the font's own line height,
    /// so the token line height is reached by adding the difference.
    private var extraLineSpacing: CGFloat {
        guard style.lineHeight != nil else { return 0 }
        return max(0, lineHeight - DSDynamicType.naturalLineHeight(family: style.family, size: size, weight: style.weight))
    }
}

public enum DSDynamicType {
    #if canImport(UIKit)
    /// A token size scaled for the current (or given) content size category, for values that
    /// are not fonts (icon sizes next to text, row heights that must grow with text).
    public static func scaled(_ value: CGFloat, relativeTo textStyle: Font.TextStyle, traits: UITraitCollection? = nil) -> CGFloat {
        UIFontMetrics(forTextStyle: uiTextStyle(textStyle)).scaledValue(for: value, compatibleWith: traits)
    }

    public static func uiTextStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        default: return .body
        }
    }

    static func naturalLineHeight(family: DSFontFamily, size: CGFloat, weight: Font.Weight) -> CGFloat {
        switch family {
        case .system:
            return UIFont.systemFont(ofSize: size, weight: uiWeight(weight)).lineHeight
        case let .custom(name):
            return UIFont(name: name, size: size)?.lineHeight ?? size
        }
    }

    static func uiWeight(_ weight: Font.Weight) -> UIFont.Weight {
        let pairs: [(Font.Weight, UIFont.Weight)] = [
            (.ultraLight, .ultraLight), (.thin, .thin), (.light, .light), (.regular, .regular),
            (.medium, .medium), (.semibold, .semibold), (.bold, .bold), (.heavy, .heavy), (.black, .black),
        ]
        return pairs.first { $0.0 == weight }?.1 ?? .regular
    }
    #else
    static func naturalLineHeight(family: DSFontFamily, size: CGFloat, weight: Font.Weight) -> CGFloat { size }
    #endif
}

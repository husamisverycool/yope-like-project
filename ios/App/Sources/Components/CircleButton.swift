// Shared component — C-11 icon buttons and circles (design/components.md), replacing Yope's header circles. The bare
// header glyph (no circle) is `HeaderIconButton` (ScreenHeader.swift). Evidence: ED-W3 ('+' x3138–3277), ST-03 (close
// 977–1063, 736–822), RWA ('•••' y276–396; share / random), PAY (glass close), TC-2B; RV §3.4, §3.7, §4 #7.
import DesignSystem
import SwiftUI

/// Where a circle button is drawn.
enum CircleButtonStyle {
    /// On a page ('+' on an album row; close on a light sheet): `size.global.circleButton`, fill
    /// `color.global.control`, glyph `color.global.textPrimary`.
    case page
    /// On a media surface (close / edit on the postcard composer, the viewer close): `size.global.circleButton`, fill
    /// `color.global.controlOnDeep`, glyph `color.global.textOnMedia`.
    case media
    /// Glass over a photo ('•••' on Rewind): `size.global.circleButtonPhoto`, fill `color.global.glass`.
    case glass
    /// Large glass beside a central control (Rewind share / random): `size.global.circleButtonLarge`.
    case glassLarge
    /// Small glass over colour (the paywall close): `size.global.circleButtonSmall`.
    case glassSmall
    /// A page circle in the primary fill (the locked voice recording's send, `chat.voice.layout.locked`: C-11's shape
    /// in C-06's primary colours): `size.global.circleButton`, fill `color.global.accent`, glyph `color.global.onAccent`.
    case primary

    var diameter: CGFloat {
        switch self {
        case .page, .media, .primary: return Tokens.Sizes.globalCircleButton
        case .glass: return Tokens.Sizes.globalCircleButtonPhoto
        case .glassLarge: return Tokens.Sizes.globalCircleButtonLarge
        case .glassSmall: return Tokens.Sizes.globalCircleButtonSmall
        }
    }

    var fill: Color {
        switch self {
        case .page: return Tokens.Colors.globalControl
        case .media: return Tokens.Colors.globalControlOnDeep
        case .glass, .glassLarge, .glassSmall: return Tokens.Colors.globalGlass
        case .primary: return Tokens.Colors.globalAccent
        }
    }

    var glyph: Color {
        switch self {
        case .page: return Tokens.Colors.globalTextPrimary
        case .media, .glass, .glassLarge, .glassSmall: return Tokens.Colors.globalTextOnMedia
        case .primary: return Tokens.Colors.globalOnAccent
        }
    }

    /// The glyph's box (= its ink: `Glyph` fits the symbol to the box). Page, media and small glass circles draw Retro's
    /// measured ink — `size.global.circleCloseGlyph` for the close '×', `size.global.circleGlyph` for the rest, both
    /// measured in the 36-pt circle and scaled with the diameter (ST-04, ED-W3; PAY's 32-pt close → 9.7). The glass
    /// circles over photos keep `size.global.icon` (RWB share / random ink fills the 24-pt box).
    func glyphSize(for icon: String) -> CGFloat {
        switch self {
        case .page, .media, .glassSmall, .primary:
            let ink = icon == Tokens.Icons.globalClose ? Tokens.Sizes.globalCircleCloseGlyph : Tokens.Sizes.globalCircleGlyph
            return ink * diameter / Tokens.Sizes.globalCircleButton
        case .glass, .glassLarge:
            return Tokens.Sizes.globalIcon
        }
    }
}

/// The circle face: a circle of `style.diameter` in `style.fill` with the glyph centred in a `glyphSize` box
/// (`style.glyphSize(for:)` by default). No shadow; glass is the fill colour only (its blur was not derivable — Gap).
/// The hit area is at least `size.global.minTouchTarget.ios` around the drawn circle.
struct CircleButtonFace: View {
    let icon: String
    var style: CircleButtonStyle = .page
    var glyphSize: CGFloat?
    /// Overrides the style's glyph colour (a red C-10 glyph in a page circle: `chat.voice.layout.locked`).
    var glyphColor: Color?

    var body: some View {
        Glyph(icon, size: glyphSize ?? style.glyphSize(for: icon))
            .foregroundStyle(glyphColor ?? style.glyph)
            .frame(width: style.diameter, height: style.diameter)
            .background(style.fill, in: Circle())
            .minimumHitArea(drawn: CGSize(width: style.diameter, height: style.diameter))
    }
}

/// C-11 circle button. Pressed: platform default. Accessibility: label from copy (the control has no text).
/// Contrast: the fills fail non-text contrast against the page (CONTRAST failure 2) — the glyph identifies them.
struct CircleButton: View {
    let icon: String
    let accessibilityLabel: String
    var style: CircleButtonStyle = .page
    var glyphSize: CGFloat?
    let action: () -> Void

    init(
        icon: String,
        accessibilityLabel: String,
        style: CircleButtonStyle = .page,
        glyphSize: CGFloat? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.style = style
        self.glyphSize = glyphSize
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            CircleButtonFace(icon: icon, style: style, glyphSize: glyphSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

/// A circle that opens a native menu ('•••' over a photo; C-29). Destructive items use `Button(role: .destructive)`.
struct CircleMenu<Content: View>: View {
    let icon: String
    let accessibilityLabel: String
    var style: CircleButtonStyle = .page
    var glyphSize: CGFloat?
    @ViewBuilder let content: () -> Content

    init(
        icon: String,
        accessibilityLabel: String,
        style: CircleButtonStyle = .page,
        glyphSize: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.style = style
        self.glyphSize = glyphSize
        self.content = content
    }

    var body: some View {
        Menu(content: content) {
            CircleButtonFace(icon: icon, style: style, glyphSize: glyphSize)
        }
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

// MARK: - Yope-era header circles (Pass 4 replaces the call sites)

/// Yope's header-circle fills, mapped to the C-11 circle of the same role: `.onDeep` (circles on black screens) →
/// `.media`; `.onBackground` (circles on the page) → `.page`; `.overPhoto` → `.glass`. Retro headers draw bare
/// glyphs (C-01 / C-02: `HeaderIconButton`, `PushedScreenHeader`); circles belong to sheets, media and photos.
enum HeaderCircleFill {
    case onDeep
    case onBackground
    case overPhoto

    var style: CircleButtonStyle {
        switch self {
        case .onDeep: return .media
        case .onBackground: return .page
        case .overPhoto: return .glass
        }
    }
}

@available(*, deprecated, message: "Retro headers draw bare glyphs: HeaderIconButton / PushedScreenHeader (C-01, C-02); circles: CircleButton (C-11)")
struct HeaderCircleButton: View {
    let icon: String
    let accessibilityLabel: String
    var fill: HeaderCircleFill = .onDeep
    let action: () -> Void

    init(icon: String, accessibilityLabel: String, fill: HeaderCircleFill = .onDeep, action: @escaping () -> Void) {
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.fill = fill
        self.action = action
    }

    var body: some View {
        CircleButton(icon: icon, accessibilityLabel: accessibilityLabel, style: fill.style, action: action)
    }
}

@available(*, deprecated, message: "Retro headers draw bare glyphs: HeaderIconMenu (C-01); over photos: CircleMenu (C-11)")
struct HeaderCircleMenu<Content: View>: View {
    let icon: String
    let accessibilityLabel: String
    var fill: HeaderCircleFill = .onDeep
    @ViewBuilder let content: () -> Content

    init(icon: String, accessibilityLabel: String, fill: HeaderCircleFill = .onDeep, @ViewBuilder content: @escaping () -> Content) {
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.fill = fill
        self.content = content
    }

    var body: some View {
        CircleMenu(icon: icon, accessibilityLabel: accessibilityLabel, style: fill.style, content: content)
    }
}

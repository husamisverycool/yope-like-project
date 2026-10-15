// Shared component — header circle buttons (‹ back, ✕ close, ••• more, + add, calendar, recap).
import DesignSystem
import SwiftUI

/// Fill of a header circle.
enum HeaderCircleFill {
    /// `color.global.controlOnDeep`: circles on black screens and sheets (sign-up, sheets, profile page).
    case onDeep
    /// `color.global.control`: circles on `color.global.background` (#171717) screens (group feed).
    case onBackground
    /// Over the home cover photo: `groups.list.color.headerCircleOverPhoto` (`DesignGaps.headerCircleOverPhoto`;
    /// BLOCKED → the glyph alone until it is set).
    case overPhoto

    var color: Color? {
        switch self {
        case .onDeep: return Tokens.Colors.globalControlOnDeep
        case .onBackground: return Tokens.Colors.globalControl
        case .overPhoto: return DesignGaps.headerCircleOverPhoto
        }
    }
}

/// The circle face shared by `HeaderCircleButton` and `HeaderCircleMenu`: diameter `size.global.headerButton`
/// (also the hit area, ≥ `size.global.minTouchTarget.ios`), glyph in `color.global.textPrimary` at the platform's
/// default symbol size (the glyph size was not measured).
struct HeaderCircleFace: View {
    let icon: String
    var fill: HeaderCircleFill = .onDeep

    var body: some View {
        Image(systemName: icon)
            .foregroundStyle(Tokens.Colors.globalTextPrimary)
            .frame(width: Tokens.Sizes.globalHeaderButton, height: Tokens.Sizes.globalHeaderButton)
            .background {
                if let color = fill.color {
                    Circle().fill(color)
                }
            }
            .contentShape(Circle())
    }
}

/// An icon-only header circle button. `accessibilityLabel` comes from copy (required: the control has no text).
/// Header rows place circles `size.global.headerInset` from the screen edges and `size.global.headerGap` apart.
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
        Button(action: action) {
            HeaderCircleFace(icon: icon, fill: fill)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

/// A header circle that opens a native menu (••• menus: `groups.screen.layout.menu`, `safety.block.layout.menu`).
/// Destructive items use `Button(role: .destructive)` inside `content`.
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
        Menu(content: content) {
            HeaderCircleFace(icon: icon, fill: fill)
        }
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

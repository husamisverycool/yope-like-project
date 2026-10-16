// Shared component — C-06 medium capsules (37 pt): primary · outline · fill, the icon-only capsule, and the toggle
// (design/components.md). Evidence: ST-02 (Recaps / Share Profile / gear, y1129–1217), TC-1B (Accept / Decide Later),
// JED ('Create' fill pill), H43 (outline); RV §3.1, §3.4, §4 #6.
import DesignSystem
import SwiftUI

/// The three captured variants.
enum CapsuleStyle {
    /// Fill `color.global.accent`, label `color.global.onAccent` ('Accept').
    case primary
    /// No fill (the page shows), 1 pt border and label `color.global.textPrimary` ('Recaps', 'Share Profile').
    case outline
    /// Fill `color.global.control`, label `color.global.textPrimary` ('Create').
    case fill
}

/// The capsule's look without the button, for a capsule inside a larger tappable row.
///
/// Height `size.global.pillHeight` (a minimum: the label grows with Dynamic Type), label text role `pill`, shape
/// `radius.global.capsule`. Text-only capsules hug their label with the platform's padding (iOS inner padding not
/// measured — Gap; Android's is 12 / 8) unless `fillsWidth` (equal widths in an action row, `CapsuleRow`). Icon-only:
/// width `size.global.iconPillWidth`, glyph `size.global.iconSmall`. The outline border is SwiftUI's default stroke
/// width, 1 pt, the measured width (no token — Gap). Disabled: primary as C-05 (`color.global.controlRaised` /
/// `color.global.onAccent`); outline and fill draw label and border in `color.global.textTertiary` (Retro's disabled
/// capsule other than the primary was not captured — Gap; the token's role is tertiary / disabled text).
struct CapsuleLabel: View {
    var title: String?
    var icon: String?
    var style: CapsuleStyle = .outline
    var fillsWidth: Bool = false
    var isEnabled: Bool = true

    var body: some View {
        content
            .foregroundStyle(labelColor)
            .frame(minHeight: Tokens.Sizes.globalPillHeight)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .background(fillColor, in: Capsule())
            .overlay {
                if style == .outline {
                    Capsule().strokeBorder(labelColor)
                }
            }
            .contentShape(Capsule())
    }

    @ViewBuilder
    private var content: some View {
        if let title {
            Text(title)
                .dsTextStyle(TextRole.pill)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        } else if let icon {
            Glyph(icon, size: Tokens.Sizes.globalIconSmall, relativeTo: TextRole.pill.relativeTo)
                .frame(width: Tokens.Sizes.globalIconPillWidth)
        }
    }

    private var fillColor: Color {
        switch style {
        case .primary: return isEnabled ? Tokens.Colors.globalAccent : Tokens.Colors.globalControlRaised
        case .outline: return Color.clear
        case .fill: return Tokens.Colors.globalControl
        }
    }

    private var labelColor: Color {
        switch style {
        case .primary: return Tokens.Colors.globalOnAccent
        case .outline, .fill: return isEnabled ? Tokens.Colors.globalTextPrimary : Tokens.Colors.globalTextTertiary
        }
    }
}

/// C-06 capsule button. Pressed: platform default. Accessibility: button; an icon-only capsule takes its label from
/// copy (`accessibilityLabel`).
struct CapsuleButton: View {
    let title: String?
    let icon: String?
    let accessibilityLabel: String
    var style: CapsuleStyle
    var fillsWidth: Bool
    var isEnabled: Bool
    let action: () -> Void

    /// A text capsule.
    init(_ title: String, style: CapsuleStyle = .outline, fillsWidth: Bool = false, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        icon = nil
        accessibilityLabel = title
        self.style = style
        self.fillsWidth = fillsWidth
        self.isEnabled = isEnabled
        self.action = action
    }

    /// An icon-only capsule (the gear after 'Recaps' / 'Share Profile').
    init(icon: String, accessibilityLabel: String, style: CapsuleStyle = .outline, isEnabled: Bool = true, action: @escaping () -> Void) {
        title = nil
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.style = style
        fillsWidth = false
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            CapsuleLabel(title: title, icon: icon, style: style, fillsWidth: fillsWidth, isEnabled: isEnabled)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

/// A selectable capsule ('I'm in this'): outline when off, primary fill when on — the two captured variants (a captured
/// toggle is a Gap). Toggling plays `haptic.global.select`; accessibility: button with the selected trait when on.
struct CapsuleToggle: View {
    let title: String
    @Binding var isOn: Bool
    var fillsWidth: Bool = false

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            CapsuleLabel(title: title, style: isOn ? .primary : .outline, fillsWidth: fillsWidth)
        }
        .buttonStyle(.plain)
        .dsAnimation(ComponentMotion.crossfade, value: isOn)
        .dsHaptic(Tokens.Haptics.globalSelect, trigger: isOn)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// An action row of capsules with equal widths `size.global.pillGap` apart (profile 'Recaps / Share Profile / ⚙',
/// request 'Accept / Decide Later'). Give text capsules `fillsWidth: true`; an icon-only capsule keeps its width.
struct CapsuleRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: Tokens.Sizes.globalPillGap) {
            content
        }
    }
}

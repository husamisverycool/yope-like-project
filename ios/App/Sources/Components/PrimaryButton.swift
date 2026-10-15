// Shared component — the lime primary button (Yope "create group", "continue", "send").
import DesignSystem
import SwiftUI

/// Full-width lime button.
///
/// Tokens: fill `color.global.accent`, label `color.global.onAccent` in text role `button`,
/// corners `radius.global.button`, height `size.global.buttonHeight` (`.form`) or
/// `size.global.buttonHeightSheet` (`.sheet`, pinned to the bottom of a screen or sheet).
/// Disabled: fill `groups.create.color.buttonDisabledFill`, label `groups.create.color.buttonDisabledLabel`.
/// The button fills the proposed width; callers apply the side margin (`size.global.buttonMarginH` /
/// `size.global.buttonMarginHSheet`). The height is a minimum so the label can grow with Dynamic Type.
struct PrimaryButton: View {
    enum Height {
        /// `size.global.buttonHeight`: the form button under a field.
        case form
        /// `size.global.buttonHeightSheet`: the action at the bottom of a sheet or onboarding step.
        case sheet

        var value: CGFloat {
            switch self {
            case .form: return Tokens.Sizes.globalButtonHeight
            case .sheet: return Tokens.Sizes.globalButtonHeightSheet
            }
        }
    }

    let title: String
    var height: Height = .form
    var isEnabled: Bool = true
    let action: () -> Void

    init(_ title: String, height: Height = .form, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.height = height
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .dsTextStyle(TextRole.button)
                .multilineTextAlignment(.center)
                .foregroundStyle(isEnabled ? Tokens.Colors.globalOnAccent : Tokens.Colors.groupsCreateColorButtonDisabledLabel)
                .frame(maxWidth: .infinity, minHeight: height.value)
                .background(
                    isEnabled ? Tokens.Colors.globalAccent : Tokens.Colors.groupsCreateColorButtonDisabledFill,
                    in: RoundedRectangle(cornerRadius: Tokens.Radii.globalButton)
                )
                .contentShape(RoundedRectangle(cornerRadius: Tokens.Radii.globalButton))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

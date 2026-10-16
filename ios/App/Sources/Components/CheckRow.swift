// Shared component — a row toggled by a selection circle (auth.agegate opt-in; pickers): `icon.global.uncheck` /
// `icon.global.check` (filled only as a state, `icon.global.variantRule`) in the system tint `color.global.selection`.
import DesignSystem
import SwiftUI

/// A full-row toggle: label (+ optional detail) and a trailing check circle.
///
/// Tokens: `icon.global.uncheck` / `icon.global.check` in `color.global.selection` at `size.global.checkCircle`;
/// label text role `listSubtitle` in `color.global.textPrimary`; detail text role `listSubtitle` in
/// `color.global.textSecondary` (`auth.agegate.layout.optIn`). Toggling plays `haptic.global.select`.
/// Accessibility: one element with the toggle trait (selected when on), label `accessibilityLabel`,
/// the detail as its hint.
struct CheckRow: View {
    let label: String
    var detail: String?
    let accessibilityLabel: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(label)
                        .dsTextStyle(TextRole.listSubtitle)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    if let detail {
                        Text(detail)
                            .dsTextStyle(TextRole.listSubtitle)
                            .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: isOn ? Tokens.Icons.globalCheck : Tokens.Icons.globalUncheck)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Tokens.Sizes.globalCheckCircle, height: Tokens.Sizes.globalCheckCircle)
                    .foregroundStyle(Tokens.Colors.globalSelection)
            }
            .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dsHaptic(Tokens.Haptics.globalSelect, trigger: isOn)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityHint(Text(detail ?? ""))
        .accessibilityAddTraits(isOn ? [.isButton, .isToggle, .isSelected] : [.isButton, .isToggle])
    }
}

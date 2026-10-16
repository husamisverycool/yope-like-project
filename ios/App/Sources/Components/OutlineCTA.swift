// Shared component — C-07 outline CTA with icon ('+ Get this week started') (design/components.md).
// Evidence: H43 (x301–905, y1641–1751: 201.7 × 37; padding 18, icon 14.7, icon → label 9.7, label → edge 17); RV §3.4.
import DesignSystem
import SwiftUI

/// Hug-width outline capsule with a leading glyph: 1 pt border, glyph and label in `color.global.textPrimary`; glyph
/// `icon` (default `icon.global.add`) at `size.global.iconSmall`; label text role `pill`; leading
/// `size.global.pillPaddingLeading` → glyph → `size.global.pillIconGap` → label → `size.global.pillPaddingTrailing`;
/// height `size.global.pillHeight` (a minimum, grows with Dynamic Type), capsule. The border is SwiftUI's default
/// stroke width, the measured 1 pt (no token — Gap). Pressed: platform default. Accessibility: button labelled with
/// the visible text (the glyph is decorative).
struct OutlineCTA: View {
    let title: String
    var icon: String = Tokens.Icons.globalAdd
    let action: () -> Void

    init(_ title: String, icon: String = Tokens.Icons.globalAdd, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            OutlineCTALabel(title: title, icon: icon)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}

/// The CTA's look without the button.
struct OutlineCTALabel: View {
    let title: String
    var icon: String = Tokens.Icons.globalAdd

    var body: some View {
        HStack(spacing: Tokens.Sizes.globalPillIconGap) {
            Glyph(icon, size: Tokens.Sizes.globalIconSmall, relativeTo: TextRole.pill.relativeTo)
            Text(title)
                .dsTextStyle(TextRole.pill)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(Tokens.Colors.globalTextPrimary)
        .padding(.leading, Tokens.Sizes.globalPillPaddingLeading)
        .padding(.trailing, Tokens.Sizes.globalPillPaddingTrailing)
        .frame(minHeight: Tokens.Sizes.globalPillHeight)
        .overlay { Capsule().strokeBorder(Tokens.Colors.globalTextPrimary) }
        .contentShape(Capsule())
    }
}

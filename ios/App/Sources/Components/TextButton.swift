// Shared component — C-08 text button (design/components.md). Evidence: TC-1B ('Invite'), VID-COMP, LAND
// ('already have an account?'); RV §3.3, §4 #6.
import DesignSystem
import SwiftUI

/// An app-drawn text action.
///
/// - `.header` ('Invite', 'Keys'): text role `textButton`, `color.global.textPrimary`.
/// - `.link` (secondary link under a capsule, 'already have an account?'): text role `listTitle`,
///   `color.global.textSecondary`.
///
/// Native sheet toolbars ('Cancel' / 'Update') are drawn by the system in the tint (`color.global.selection`) — use
/// `.sheetToolbar` (C-29), not this. Hit area at least `size.global.minTouchTarget.ios`. Pressed: platform default.
struct TextButton: View {
    enum Style {
        case header
        case link
    }

    let title: String
    var style: Style = .header
    let action: () -> Void

    init(_ title: String, style: Style = .header, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .dsTextStyle(style == .header ? TextRole.textButton : TextRole.listTitle)
                .foregroundStyle(style == .header ? Tokens.Colors.globalTextPrimary : Tokens.Colors.globalTextSecondary)
                .multilineTextAlignment(.center)
                .frame(minWidth: Tokens.Sizes.globalMinTouchTargetIos, minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

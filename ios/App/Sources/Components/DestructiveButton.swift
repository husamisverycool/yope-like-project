// Shared component — C-10 destructive actions (design/components.md). Retro shows destructive actions as red text,
// never a red-filled button. Evidence: TC-RWP, TC-J5; APK-X vv3.g; RV §4 #20; RP §3.3.
import DesignSystem
import SwiftUI

/// An app-drawn destructive action ('Delete Account', 'Yes, delete'): text role `body` in `color.global.destructive`,
/// with an optional leading glyph (e.g. `icon.global.trash`) in the same colour. In native alerts and menus use
/// `Button(role: .destructive)` — the system draws those (C-29); in grouped settings use
/// `GroupedRow(…, role: .destructive)` (C-14). Hit area at least `size.global.minTouchTarget.ios`. Accessibility: the
/// label states the action. Contrast: red on the page 4.18:1, on fills 3.62–3.90:1 — FAIL for text (CONTRAST
/// failure 5), reported, not changed.
struct DestructiveButton: View {
    let title: String
    var icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(role: .destructive, action: action) {
            HStack {
                if let icon {
                    Glyph(icon, relativeTo: TextRole.body.relativeTo)
                }
                Text(title)
                    .dsTextStyle(TextRole.body)
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(Tokens.Colors.globalDestructive)
            .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}

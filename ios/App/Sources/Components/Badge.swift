// Shared component — C-24 badges: the count-free "new" capsule and the unread dot (design/components.md).
// Evidence: ST-01 (row y=1480), ED-A ('6 new' (947–1138, 1402–1495)), H43 (dot); APK-X wv3.a (11/11 W600); RV §4 #8.
import DesignSystem
import SwiftUI

/// The red "new" capsule: fill `color.global.badge`, label text role `badge` in `color.global.onBadge` (lower case, from
/// copy), height `size.global.badgeHeight`. Retro's badge text is a count ('6 new') — ours never shows a number
/// (tenets). The label's side inset was not measured (Gap) — platform padding. Placed on a card with `.newBadge(_:)`.
/// Accessibility: read as part of the owner element ("new photos") — hidden here. Contrast: white on red 4.18:1 for
/// 11 pt text FAIL (CONTRAST failure 5), reported, not changed.
struct NewBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .dsTextStyle(TextRole.badge)
            .foregroundStyle(Tokens.Colors.globalOnBadge)
            .lineLimit(1)
            .padding(.horizontal)
            .frame(minHeight: Tokens.Sizes.globalBadgeHeight)
            .background(Tokens.Colors.globalBadge, in: Capsule())
            .accessibilityHidden(true)
    }
}

/// The unread dot: a `size.global.tabBadgeDot` circle in `color.global.badge` (tab bar C-04, people rows C-16).
/// Decorative: the owner element carries an unread value from copy.
struct UnreadDot: View {
    var body: some View {
        Circle()
            .fill(Tokens.Colors.globalBadge)
            .frame(width: Tokens.Sizes.globalTabBadgeDot, height: Tokens.Sizes.globalTabBadgeDot)
            .accessibilityHidden(true)
    }
}

extension View {
    /// Places the "new" badge `size.global.badgeInset` from the top and trailing edges (C-18 friend card).
    func newBadge(_ label: String?) -> some View {
        overlay(alignment: .topTrailing) {
            if let label {
                NewBadge(label: label)
                    .padding(.top, Tokens.Sizes.globalBadgeInset)
                    .padding(.trailing, Tokens.Sizes.globalBadgeInset)
            }
        }
    }
}

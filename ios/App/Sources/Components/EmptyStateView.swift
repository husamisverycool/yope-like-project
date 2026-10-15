// Shared component — the Yope empty-state layout ("you created group" / "and added …" / "invite more friends").
import DesignSystem
import SwiftUI

/// Centred title, optional italic detail and optional white pill (pattern `yope.voice.empty-state`).
///
/// Tokens: title text role `emptyTitle` (bold) in `color.global.textPrimary`; detail text role `emptyDetail`,
/// italic, `color.global.textSecondary`; pill = `LightPill` (`color.global.surfaceLight`,
/// `groups.screen.size.lightPillHeight`, `groups.screen.radius.lightPill`). Gaps between the three: the platform's
/// stack spacing (not measured). Used by offline / error / refusal states across the account surfaces.
struct EmptyStateView: View {
    struct Action {
        let title: String
        var icon: String?
        let handler: () -> Void

        init(_ title: String, icon: String? = nil, handler: @escaping () -> Void) {
            self.title = title
            self.icon = icon
            self.handler = handler
        }
    }

    let title: String?
    var detail: String?
    var action: Action?

    init(title: String?, detail: String? = nil, action: Action? = nil) {
        self.title = title
        self.detail = detail
        self.action = action
    }

    var body: some View {
        VStack {
            if let title {
                Text(title)
                    .dsTextStyle(TextRole.emptyTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            if let detail {
                Text(detail)
                    .italic()
                    .dsTextStyle(TextRole.emptyDetail)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            }
            if let action {
                LightPill(action.title, icon: action.icon, action: action.handler)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}

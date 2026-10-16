// Shared component — C-27 empty state (design/components.md), replacing Yope's empty-state layout. Also the error,
// offline and permission-denied states (same block, retry / settings action). Evidence: H43 (icon y1380–1445, title
// 1524–1565.5, button 1641–1751), TC-2B phone 3; RV §3.4, §4 #13.
import DesignSystem
import SwiftUI

/// A centred block: optional outline glyph (`size.global.emptyIcon`, `color.global.textPrimary`) → its bottom
/// `size.global.emptyIconToTitle` above the title's cap top → title (text role `emptyTitle`, `color.global.textPrimary`,
/// Sentence case from copy) → optional explanation (text role `emptyDetail`, `color.global.textSecondary`, ≤ 2 lines in
/// Retro; title → explanation spacing not measured, Gap — platform stack spacing) → the action, its top
/// `size.global.emptyTitleToAction` below the last baseline: an outline CTA (C-07) when the action has a glyph, else an
/// outline capsule (C-06). Error / offline / permission-denied states use the same block (copy `retro.voice.error`,
/// `retro.voice.permission`).
///
/// Placement: the caller centres the block in the free space between the content above and the tab bar (H43). Side
/// inset `size.global.screenMargin` (applied here).
/// Accessibility: the glyph is decorative; the title is a header.
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

    var icon: String?
    let title: String?
    var detail: String?
    var action: Action?

    init(icon: String? = nil, title: String?, detail: String? = nil, action: Action? = nil) {
        self.icon = icon
        self.title = title
        self.detail = detail
        self.action = action
    }

    var body: some View {
        MetricStack(alignment: .center) {
            if let icon {
                Glyph(icon, size: Tokens.Sizes.globalEmptyIcon)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
            }
            if title != nil || detail != nil {
                VStack {
                    if let title {
                        Text(title)
                            .dsTextStyle(TextRole.emptyTitle)
                            .foregroundStyle(Tokens.Colors.globalTextPrimary)
                            .accessibilityAddTraits(.isHeader)
                    }
                    if let detail {
                        Text(detail)
                            .dsTextStyle(TextRole.emptyDetail)
                            .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    }
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .capHeight(of: title != nil ? TextRole.emptyTitle : TextRole.emptyDetail)
                .metricGap(icon != nil ? Tokens.Sizes.globalEmptyIconToTitle : 0, from: .bottom, to: .capTop)
            }
            if let action {
                Group {
                    if let actionIcon = action.icon {
                        OutlineCTA(action.title, icon: actionIcon, action: action.handler)
                    } else {
                        CapsuleButton(action.title, style: .outline, action: action.handler)
                    }
                }
                .metricGap(Tokens.Sizes.globalEmptyTitleToAction, from: .lastBaseline, to: .top)
            }
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}

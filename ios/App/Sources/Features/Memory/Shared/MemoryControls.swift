// Compositions the memory surfaces share, built only from the component library (ios/App/Sources/Components,
// design/components.md): the C-27 state block on a media page with its C-09 light pill, and the C-28 loading state
// with its spoken line. Confirmations go through C-26 (`ToastCenter`: iOS draws nothing and announces the message).
import DesignSystem
import SwiftUI
import UIKit

/// C-27 error / offline / empty block on a media page (black in both appearances): title text role `emptyTitle`, detail
/// text role `emptyDetail` in `color.global.textSecondary`, then — `size.global.emptyTitleToAction` below the last
/// baseline — the C-09 light pill (`color.global.surfaceLight` / `color.global.onSurfaceLight`, `size.global.pillHeight`,
/// label text role `pill`) that retries. The page renders its subtree in the dark appearance
/// (`layout.global.appearance.media`), so the title's `color.global.textPrimary` is `color.global.textOnMedia`.
struct MemoryMediaStateBlock: View {
    let title: String
    var detail: String?
    var retryTitle: String?
    var onRetry: (() -> Void)?

    init(title: String, detail: String? = nil, retryTitle: String? = nil, onRetry: (() -> Void)? = nil) {
        self.title = title
        self.detail = detail
        self.retryTitle = retryTitle
        self.onRetry = onRetry
    }

    var body: some View {
        MetricStack(alignment: .center) {
            EmptyStateView(title: title, detail: detail)
            if let retryTitle, let onRetry {
                LightPill(retryTitle, action: onRetry)
                    .metricGap(Tokens.Sizes.globalEmptyTitleToAction, from: .lastBaseline, to: .top)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// C-28: the platform activity indicator in `color.global.textSecondary`, its loading line (`*.loading`, "Loading…")
/// announced to VoiceOver when it appears (the specs' "(announcement)").
struct MemoryLoadingIndicator: View {
    let announcement: String

    var body: some View {
        LoadingHUD()
            .accessibilityLabel(Text(announcement))
            .onAppear { AccessibilityNotification.Announcement(announcement).post() }
    }
}

/// The system Light / Dark setting, read from the window scene: a media page renders its subtree dark
/// (`.environment(\.colorScheme, .dark)`), but sheets presented over it follow the system (MERGE RM-16).
enum SystemAppearance {
    @MainActor
    static var colorScheme: ColorScheme {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }
}

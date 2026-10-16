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

extension View {
    /// Keeps the edge-swipe back on a page pushed with the system bar hidden (onthisday platform notes: "the interactive
    /// pop gesture kept"); UIKit stops the navigation controller's interactive pop while its bar is hidden. The page's
    /// navigation controller takes this page's begin rule (another page under it) while it is on screen; restored when it
    /// leaves.
    func memoryInteractivePop() -> some View {
        background(MemoryInteractivePop().frame(width: 0, height: 0).accessibilityHidden(true))
    }
}

/// The UIKit bridge behind `memoryInteractivePop()`.
struct MemoryInteractivePop: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        private weak var navigation: UINavigationController?
        private weak var previousDelegate: (any UIGestureRecognizerDelegate)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let navigation = navigationController, let gesture = navigation.interactivePopGestureRecognizer else { return }
            if gesture.delegate !== self {
                previousDelegate = gesture.delegate
                gesture.delegate = self
            }
            gesture.isEnabled = true
            self.navigation = navigation
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            // A cancelled swipe shows the page again (viewDidAppear takes the gesture back).
            guard let gesture = navigation?.interactivePopGestureRecognizer, gesture.delegate === self else { return }
            gesture.delegate = previousDelegate
        }

        nonisolated func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            MainActor.assumeIsolated {
                (navigation?.viewControllers.count ?? 0) > 1
            }
        }
    }
}

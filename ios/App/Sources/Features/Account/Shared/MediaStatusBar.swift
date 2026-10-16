// Account group (shell) — light status-bar content over a dark media page that follows the system appearance
// otherwise (`layout.global.appearance.media`: media surfaces are black in both appearances). Used by the camera tab, the
// App Clip's invite card and pushed media pages (onthisday).
import SwiftUI
import UIKit

extension View {
    /// Light status-bar content while this page is on screen: the page's own view controller (the pushed page's
    /// `UIHostingController`, or the window's root for a tab) takes the dark interface style, which the status bar follows
    /// (a `UINavigationController` with its bar hidden takes the style of its top view controller). The page is a dark
    /// media surface in both appearances, so dark menus and alerts over it are correct. Restored when the view leaves.
    func mediaStatusBar() -> some View {
        background(MediaStatusBar().frame(width: 0, height: 0).accessibilityHidden(true))
    }
}

/// The UIKit bridge behind `mediaStatusBar()`.
struct MediaStatusBar: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {}

    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) {
        controller.restore()
    }

    final class Controller: UIViewController {
        private weak var page: UIViewController?
        private var previousStyle: UIUserInterfaceStyle = .unspecified

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            if parent == nil { restore() } else { apply() }
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            apply()
        }

        /// The page's view controller: the ancestor just under a navigation controller, else the topmost one.
        private func pageController() -> UIViewController? {
            var candidate = parent
            while let current = candidate {
                guard let next = current.parent, !(next is UINavigationController) else { return current }
                candidate = next
            }
            return nil
        }

        private func apply() {
            guard let page = pageController() else { return }
            if self.page !== page {
                restore()
                previousStyle = page.overrideUserInterfaceStyle
                self.page = page
            }
            page.overrideUserInterfaceStyle = .dark
            page.setNeedsStatusBarAppearanceUpdate()
            page.navigationController?.setNeedsStatusBarAppearanceUpdate()
        }

        func restore() {
            guard let page else { return }
            page.overrideUserInterfaceStyle = previousStyle
            page.setNeedsStatusBarAppearanceUpdate()
            page.navigationController?.setNeedsStatusBarAppearanceUpdate()
            self.page = nil
        }
    }
}

// Shared component — the in-app browser (SFSafariViewController) for legal links and other web pages.
import SafariServices
import SwiftUI
import UIKit

/// `SFSafariViewController` as a SwiftUI view (system UI, platform styling).
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// A URL presented in the in-app browser.
struct BrowserLink: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
}

extension View {
    /// Opens every http(s) link tapped inside this view (e.g. `Text` with `AttributedString` links) in the in-app
    /// browser instead of Safari; other schemes (mailto:, Settings) go to the system.
    func opensLinksInAppBrowser() -> some View {
        modifier(InAppBrowserModifier())
    }
}

private struct InAppBrowserModifier: ViewModifier {
    @State private var link: BrowserLink?

    func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
                    return .systemAction
                }
                link = BrowserLink(url: url)
                return .handled
            })
            .sheet(item: $link) { link in
                SafariView(url: link.url)
                    .ignoresSafeArea()
            }
    }
}

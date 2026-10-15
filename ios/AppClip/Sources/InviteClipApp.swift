// Surface: invite.appclip — reference: Partiful + Apple HIG (App Clips).
// Reference images: design/surfaces/invite.appclip.md. Container only: the invite feature
// (screens + API passes) fills `InviteClipContainer`.
import AppModels
import Observation
import StoreKit
import SwiftUI
import UIKit

@main
struct InviteClipApp: App {
    @State private var model = InviteClipModel(
        parser: DeepLinkParser(configuration: AppConfiguration.load(from: .main) ?? AppConfiguration())
    )

    var body: some Scene {
        WindowGroup {
            InviteClipContainer(token: model.inviteToken)
                // App Clip invocations (QR, NFC, Safari banner, Messages) arrive as web activities.
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    model.open(activity.webpageURL)
                }
                // Local testing with the _XCAppClipURL scheme environment variable.
                .onOpenURL { url in
                    model.open(url)
                }
        }
    }
}

@MainActor
@Observable
final class InviteClipModel {
    private(set) var inviteToken: String?
    private let parser: DeepLinkParser

    init(parser: DeepLinkParser) {
        self.parser = parser
    }

    func open(_ url: URL?) {
        guard let url, case let .invite(token)? = parser.parse(url) else { return }
        inviteToken = token
    }
}

/// Filled by the invite feature: group preview, members, join. Until then it shows the
/// platform progress indicator while the invite would load.
struct InviteClipContainer: View {
    let token: String?

    var body: some View {
        ProgressView()
            .accessibilityIdentifier("invite.appclip")
    }
}

// MARK: - Offering the full app

extension View {
    /// Shows the App Store overlay for the full app over the App Clip. `position` comes from the
    /// invite.appclip spec.
    func fullAppOverlay(isPresented: Binding<Bool>, position: SKOverlay.Position) -> some View {
        appStoreOverlay(isPresented: isPresented) {
            SKOverlay.AppClipConfiguration(position: position)
        }
    }
}

/// UIKit presentation of the same overlay, for flows that hold a window scene.
enum FullAppOverlay {
    @MainActor
    static func present(in scene: UIWindowScene, position: SKOverlay.Position) {
        SKOverlay(configuration: SKOverlay.AppClipConfiguration(position: position)).present(in: scene)
    }

    @MainActor
    static func dismiss(in scene: UIWindowScene) {
        SKOverlay.dismiss(in: scene)
    }
}

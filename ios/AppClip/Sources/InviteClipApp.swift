// Surface: invite.appclip — iOS App Clip: the invite preview, then join. Reference: Partiful (App Clip card, invite
// page, RSVP sheet) + Apple HIG (App Clips); design/surfaces/invite.appclip.md. Reference images:
// references/auto/partiful/store/partiful-store-04.png (C1), references/auto/partiful/web/pf-web-private-past-01.png (P3),
// pf-web-public-light-rsvp-sheet.png / pf-web-public-dark-rsvp-sheet.png (P4), pf-web-notfound-01.png (NF).
// Flow: invocation URL → `preview.json` → "Join" → join sheet (name, phone) → SMS code (auth.code) → `join_group` →
// hand-off to the full app (App Group) → SKOverlay offering the full app.
import AppData
import AppModels
import DesignSystem
import Observation
import StoreKit
import SwiftUI
import UIKit

@main
struct InviteClipApp: App {
    @State private var model = InviteClipModel.live()

    var body: some Scene {
        WindowGroup {
            InviteClipContainer(model: model)
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
    struct CodeStep: Identifiable {
        let phone: String
        let sentAt: Date
        var id: String { phone }
    }

    private(set) var inviteToken: String?
    private(set) var preview: InvitePreviewState = .loading
    var showsJoinSheet = false
    var name = ""
    var phone = PhoneNumberInput.initialText()
    private(set) var isSending = false
    /// The join sheet's last send failure, shown as the form error alert (`auth.phone.layout.inlineError`).
    private(set) var sendFailure: AuthFailure?
    private(set) var sendErrorCount = 0
    var codeStep: CodeStep?
    private(set) var joined = false
    /// Offer the full app once the person has joined (`invite.appclip.layout.fullAppOverlay.when`).
    var showsFullAppOverlay = false

    let data: AccountDataSource
    let network: NetworkMonitor
    let toasts = ToastCenter()
    private let parser: DeepLinkParser
    private let loader: InvitePreviewLoader

    init(parser: DeepLinkParser, loader: InvitePreviewLoader, data: AccountDataSource, network: NetworkMonitor) {
        self.parser = parser
        self.loader = loader
        self.data = data
        self.network = network
    }

    /// App Clips get no background networking: foreground uploads only (docs/PLATFORM_CONSTRAINTS.md §3).
    static func live(bundle: Bundle = .main) -> InviteClipModel {
        let configuration = AppConfiguration.load(from: bundle) ?? AppConfiguration()
        let environment = try? DataEnvironment.live(configuration: configuration, backgroundUploads: false)
        let data = LiveAccountData(environment: environment)
        let network = NetworkMonitor(status: data.networkStatus)
        network.follow(data.networkUpdates())
        return InviteClipModel(
            parser: DeepLinkParser(configuration: configuration),
            loader: InvitePreviewLoader(domain: configuration.domain),
            data: data,
            network: network
        )
    }

    var theme: InviteTheme {
        if case let .valid(preview) = preview { return InviteTheme(preview.theme) }
        return .standard
    }

    func open(_ url: URL?) {
        guard let url, case let .invite(token)? = parser.parse(url) else {
            if inviteToken == nil { preview = .notFound }
            return
        }
        inviteToken = token
        Task { await load() }
    }

    /// A launch without an invocation URL (e.g. from a notification) shows "Invite not found".
    func launchedWithoutURL() {
        if inviteToken == nil, preview == .loading { preview = .notFound }
    }

    func load() async {
        guard let token = inviteToken else {
            preview = .notFound
            return
        }
        preview = .loading
        preview = await loader.load(token: token)
    }

    func join() {
        showsJoinSheet = true
    }

    /// Join sheet "Continue": the code is sent with the name (it becomes the account's display name).
    func sendCode() async {
        guard let number = PhoneNumberInput.normalized(phone) else {
            failSending(.invalidNumber)
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        isSending = true
        defer { isSending = false }
        do {
            try await data.sendCode(phone: number, displayName: trimmedName.isEmpty ? nil : trimmedName)
            sendFailure = nil
            showsJoinSheet = false
            codeStep = CodeStep(phone: number, sentAt: Date())
        } catch {
            guard let failure = AuthFailure.sending(error) else {
                showsJoinSheet = false
                preview = .offline
                return
            }
            failSending(failure)
        }
    }

    private func failSending(_ failure: AuthFailure) {
        sendFailure = failure
        sendErrorCount += 1
    }

    /// After the code: `join_group`; errors map to the state pages.
    func verified() async {
        codeStep = nil
        guard let token = inviteToken else { return }
        do {
            let group = try await data.joinGroup(token: token)
            joined = true
            InviteHandoff(token: token, joinedGroupID: group.id.rawValue).save(to: InviteHandoff.defaults())
            showsFullAppOverlay = true
        } catch {
            switch DataError.from(error) {
            case .api(.groupFull, _): preview = .full
            case .api(.inviteExpired, _), .api(.inviteRevoked, _): preview = .unavailable
            case .api(.inviteNotFound, _): preview = .notFound
            case .offline: preview = .offline
            default: preview = .error
            }
        }
    }

    /// `invite.appclip.layout.fullAppOverlay.position`.
    var overlayPosition: SKOverlay.Position {
        Tokens.Layouts.InviteAppclipLayoutFullAppOverlay.position == "bottomRaised" ? .bottomRaised : .bottom // provenance-ok: token value mapped to the SKOverlay case
    }
}

/// The App Clip's only screen: the preview (or a state page), the join sheet and the code step.
struct InviteClipContainer: View {
    @Bindable var model: InviteClipModel

    var body: some View {
        InvitePreviewScreen(
            state: model.preview,
            showsJoin: !model.joined,
            onJoin: { model.join() },
            onRetry: { Task { await model.load() } }
        )
        .sheet(isPresented: $model.showsJoinSheet) {
            InviteJoinSheet(
                theme: model.theme,
                name: $model.name,
                phone: $model.phone,
                isSending: model.isSending,
                onCancel: { model.showsJoinSheet = false },
                onContinue: { Task { await model.sendCode() } }
            )
            .formErrorAlert(model.sendFailure?.message, trigger: model.sendErrorCount)
            .preferredColorScheme(model.theme.isDark ? .dark : .light)
        }
        .fullScreenCover(item: $model.codeStep) { step in
            NavigationStack {
                CodeScreen(
                    model: CodeModel(phone: step.phone, data: model.data, displayName: model.name, codeSentAt: step.sentAt),
                    network: model.network,
                    toasts: model.toasts,
                    onVerified: { _ in await model.verified() },
                    onBack: { model.codeStep = nil }
                )
            }
            .toastHost(model.toasts)
        }
        .fullAppOverlay(isPresented: $model.showsFullAppOverlay, position: model.overlayPosition)
        .task {
            await Task.yield()
            model.launchedWithoutURL()
        }
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

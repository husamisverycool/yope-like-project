// Surface: invite.appclip — iOS App Clip: the invite card, sign-in, join. Visual reference: Retro's `/u/[username]` page
// and its App Clip card (`io.lonepalm.Retro.Clip`, `app-clip-display=card`; references/auto/retro/web/
// retro.app-u-nathan-iphone.png, WEBU; references/auto/retro/web/retro.app-web-copy-excerpts.txt, WEBX) + Apple HIG (App
// Clips: SKOverlay after the task); design/surfaces/invite.appclip.md.
// Flow: invocation URL → `preview.json` → the invite card → "Let's go" → auth.phone B → auth.code → auth.agegate (new
// accounts) → auth.profile step 1 (name), pushed in the clip's NavigationStack → `join_group` (the last form capsule
// stays busy) → the card's joined state + the full-app overlay (once per launch); the invite is handed to the full app
// through the App Group container.
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
                // App Clip invocations (Safari card, the invite page's App Clip link, Messages, QR) arrive as web
                // activities.
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
    /// The sign-in screens pushed over the card.
    enum Step: Hashable {
        case phone
        case code(phone: String, sentAt: Date)
        case ageGate
        case name
    }

    var path: [Step] = []
    private(set) var inviteToken: String?
    private(set) var preview: InvitePreviewState = .loading
    private(set) var joined = false
    /// `join_group` is running (the card's pill when already signed in; otherwise the last form capsule).
    private(set) var isJoining = false
    /// `under_minimum_age`: the refusal replaces the clip (auth.agegate).
    private(set) var refusedMinAge: Int??
    /// The full-app overlay (`invite.appclip.layout.fullAppOverlay`): after the join, once per launch.
    var showsFullAppOverlay = false
    @ObservationIgnored private var offeredFullApp = false
    private(set) var successCount = 0
    private(set) var errorCount = 0

    let data: AccountDataSource
    let network: NetworkMonitor
    let configuration: AppConfiguration
    let toasts = ToastCenter()
    let phoneModel: PhoneModel
    let ageGateModel: AgeGateModel
    let profileModel: ProfileModel
    private let parser: DeepLinkParser
    private let loader: InvitePreviewLoader

    init(configuration: AppConfiguration, parser: DeepLinkParser, loader: InvitePreviewLoader, data: AccountDataSource, network: NetworkMonitor) {
        self.configuration = configuration
        self.parser = parser
        self.loader = loader
        self.data = data
        self.network = network
        phoneModel = PhoneModel(data: data)
        ageGateModel = AgeGateModel(data: data)
        profileModel = ProfileModel(data: data)
    }

    /// App Clips get no background networking: foreground uploads only (docs/PLATFORM_CONSTRAINTS.md §3).
    static func live(bundle: Bundle = .main) -> InviteClipModel {
        let configuration = AppConfiguration.load(from: bundle) ?? AppConfiguration()
        let environment = try? DataEnvironment.live(configuration: configuration, backgroundUploads: false)
        let data = LiveAccountData(environment: environment)
        let network = NetworkMonitor(status: data.networkStatus)
        network.follow(data.networkUpdates())
        return InviteClipModel(
            configuration: configuration,
            parser: DeepLinkParser(configuration: configuration),
            loader: InvitePreviewLoader(domain: configuration.domain),
            data: data,
            network: network
        )
    }

    /// The invite link, or the App Clip link with its `token` (`InviteClipLink`).
    func open(_ url: URL?) {
        guard let url, let token = InviteClipLink.token(from: url, parser: parser) else {
            if inviteToken == nil { preview = .notFound }
            return
        }
        inviteToken = token
        Task { await load() }
    }

    /// A launch without an invocation URL (e.g. from the App Library) shows "Couldn't find invite".
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

    /// "Let's go": the sign-in screens, or straight to the remaining step / the join when the clip is signed in already.
    func letsGo() async {
        guard !isJoining else { return }
        guard data.currentUserID != nil else {
            path = [.phone]
            return
        }
        await continueSignedIn()
    }

    /// auth.phone sent the code.
    func codeSent(to phone: String) {
        path.append(.code(phone: phone, sentAt: Date()))
    }

    /// auth.code verified (and "Let's go" when signed in): `age_confirmed_at` null → auth.agegate; empty name →
    /// auth.profile step 1; else the join.
    func continueSignedIn() async {
        do {
            let privateProfile = try await data.myPrivateProfile()
            guard privateProfile?.ageConfirmedAt != nil else {
                path.append(.ageGate)
                return
            }
            let profile = try await data.myProfile()
            guard !profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                path.append(.name)
                return
            }
            await join()
        } catch {
            show(InvitePreviewState.state(for: error))
        }
    }

    /// auth.agegate confirmed: the name step.
    func ageConfirmed() {
        path.append(.name)
    }

    /// `under_minimum_age`: the account is removed (signed out if that fails) and the refusal shown.
    func refuseUnderAge(minAge: Int?) async {
        do {
            try await data.deleteAccount()
        } catch {
            await data.signOut()
        }
        path = []
        refusedMinAge = .some(minAge)
    }

    /// `join_group`: the card returns in its joined state and the full-app overlay rises; errors show their card.
    func join() async {
        guard let token = inviteToken, !isJoining else { return }
        isJoining = true
        defer { isJoining = false }
        do {
            let group = try await data.joinGroup(token: token)
            InviteHandoff(token: token, joinedGroupID: group.id.rawValue).save(to: InviteHandoff.defaults())
            joined = true
            path = []
            successCount += 1
            if !offeredFullApp {
                offeredFullApp = true
                showsFullAppOverlay = true
            }
        } catch {
            show(InvitePreviewState.state(for: error))
        }
    }

    private func show(_ state: InvitePreviewState) {
        errorCount += 1
        preview = state
        path = []
    }

    /// `invite.appclip.layout.fullAppOverlay.position`.
    var overlayPosition: SKOverlay.Position {
        Tokens.Layouts.InviteAppclipLayoutFullAppOverlay.position == "bottomRaised" ? .bottomRaised : .bottom // provenance-ok: token value mapped to the SKOverlay case
    }
}

/// The App Clip: the invite card at the root of a NavigationStack, the sign-in screens pushed over it (native push), the
/// refusal when under age.
struct InviteClipContainer: View {
    @Bindable var model: InviteClipModel

    var body: some View {
        Group {
            if let minAge = model.refusedMinAge {
                AgeGateRefusedScreen(minAge: minAge)
            } else {
                NavigationStack(path: $model.path) {
                    InvitePreviewScreen(
                        state: model.preview,
                        isJoined: model.joined,
                        isBusy: model.isJoining && model.path.isEmpty,
                        termsURL: model.configuration.termsURL,
                        privacyURL: model.configuration.privacyURL,
                        onContinue: { Task { await model.letsGo() } },
                        onRetry: { Task { await model.load() } }
                    )
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: InviteClipModel.Step.self) { step in
                        destination(step)
                    }
                }
                // The card is drawn on dark photos in both appearances: while it is on screen the status bar is light.
                // The sign-in screens follow the system appearance.
                .preferredColorScheme(model.path.isEmpty ? .dark : nil)
            }
        }
        .toastHost(model.toasts)
        .fullAppOverlay(isPresented: $model.showsFullAppOverlay, position: model.overlayPosition)
        .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .task {
            await Task.yield()
            model.launchedWithoutURL()
        }
        .accessibilityIdentifier("invite.appclip")
    }

    @ViewBuilder
    private func destination(_ step: InviteClipModel.Step) -> some View {
        switch step {
        case .phone:
            PhoneForm(model: model.phoneModel, network: model.network, onBack: { popStep() }) { phone in
                model.codeSent(to: phone)
            }
        case let .code(phone, sentAt):
            CodeScreen(
                model: CodeModel(phone: phone, data: model.data, codeSentAt: sentAt),
                network: model.network,
                toasts: model.toasts,
                onVerified: { _ in await model.continueSignedIn() },
                onBack: { popStep() }
            )
        case .ageGate:
            AgeGateForm(
                model: model.ageGateModel,
                network: model.network,
                onConfirmed: { model.ageConfirmed() },
                onUnderAge: { minAge in await model.refuseUnderAge(minAge: minAge) }
            )
        case .name:
            ProfileNameForm(model: model.profileModel, network: model.network) {
                await model.join()
            }
        }
    }

    private func popStep() {
        if !model.path.isEmpty { model.path.removeLast() }
    }
}

// MARK: - Offering the full app

extension View {
    /// Shows the App Store overlay for the full app over the App Clip. `position` comes from the invite.appclip spec.
    func fullAppOverlay(isPresented: Binding<Bool>, position: SKOverlay.Position) -> some View {
        appStoreOverlay(isPresented: isPresented) {
            SKOverlay.AppClipConfiguration(position: position)
        }
    }
}

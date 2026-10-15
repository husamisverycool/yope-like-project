// Surface: invite.appclip — reference app: Partiful + Apple HIG (App Clips). Inside the installed app: the same preview as
// the App Clip, then join (design/surfaces/invite.appclip.md). Reference images: listed in InvitePreviewView.swift.
// Right after onboarding with a pending invite, the join happens at once (onboarding.widget "Out": pending invite →
// `join_group` → groups.screen).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

@MainActor
@Observable
final class InviteJoinModel {
    let token: String
    private(set) var state: InvitePreviewState = .loading
    private(set) var isJoining = false
    private(set) var successCount = 0
    private(set) var errorCount = 0

    private let data: AccountDataSource
    private let loader: InvitePreviewLoader

    init(token: String, data: AccountDataSource, loader: InvitePreviewLoader) {
        self.token = token
        self.data = data
        self.loader = loader
    }

    /// `preview.json` (images and theme); without a configured domain the `invite_preview` RPC gives the text alone.
    func load() async {
        state = .loading
        if loader.previewURL(token: token) != nil {
            state = await loader.load(token: token)
            return
        }
        do {
            let preview = try await data.invitePreview(token: token)
            state = .valid(WebInvitePreview(
                groupName: preview.groupName,
                groupKind: preview.groupKind.rawValue,
                inviterFirstName: preview.inviterFirstName,
                cover: nil,
                members: preview.members.map { WebInvitePreview.Member(firstName: $0.firstName, avatarURL: nil) },
                theme: nil
            ))
        } catch {
            state = Self.state(for: error)
        }
    }

    /// `join_group`; returns the group to open.
    func join() async -> PhotoGroup? {
        guard !isJoining else { return nil }
        isJoining = true
        defer { isJoining = false }
        do {
            let group = try await data.joinGroup(token: token)
            successCount += 1
            return group
        } catch {
            errorCount += 1
            state = Self.state(for: error)
            return nil
        }
    }

    static func state(for error: Error) -> InvitePreviewState {
        switch DataError.from(error) {
        case .api(.groupFull, _): return .full
        case .api(.inviteExpired, _), .api(.inviteRevoked, _): return .unavailable
        case .api(.inviteNotFound, _): return .notFound
        case .offline: return .offline
        default: return .error
        }
    }
}

/// `AppModal.invite(token:)` (sheet).
struct InviteScreen: View {
    let token: String
    @Environment(AccountDependencies.self) private var dependencies

    var body: some View {
        InviteJoinView(model: InviteJoinModel(
            token: token,
            data: dependencies.data,
            loader: InvitePreviewLoader(domain: dependencies.configuration.domain)
        ))
    }
}

struct InviteJoinView: View {
    @State private var model: InviteJoinModel
    @Environment(AccountDependencies.self) private var dependencies

    init(model: InviteJoinModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        InvitePreviewScreen(
            state: model.state,
            onJoin: { Task { await join() } },
            onRetry: { Task { await model.load() } }
        )
        .overlay {
            if model.isJoining {
                ProgressView()
            }
        }
        .presentationDetents([.large])
        .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .task {
            if dependencies.session.consumeAutoJoin(token: model.token) {
                await join()
                if model.state == .loading { await model.load() }
            } else {
                await model.load()
            }
        }
        .accessibilityIdentifier("invite.appclip")
    }

    private func join() async {
        guard let group = await model.join() else { return }
        let router = dependencies.router
        router.modal = nil
        router.path = [.group(id: group.id.rawValue)]
    }
}

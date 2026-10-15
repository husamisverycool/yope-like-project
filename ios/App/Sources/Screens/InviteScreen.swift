// Surface: invite.appclip — reference app: Partiful + Apple HIG (App Clips). Inside the installed app: the same preview as
// the App Clip, then join (design/surfaces/invite.appclip.md). Reference images: listed in InvitePreviewView.swift.
// Right after onboarding with a pending invite, the join happens at once (onboarding.widget "Out": pending invite →
// `join_group` → groups.screen).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

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

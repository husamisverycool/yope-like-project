// Surface: collage.view — opened by the collage's id (a widget showing the group's collage of the day, deep link
// `app://collage?group=<id>&collage=<id>`). Resolves the collage's invitation, then shows capture's collage screen
// (design/surfaces/collage.view.md; Retro recap preview, references/auto/retro/store/retro-store-04.png). While it
// resolves: the media page with the platform indicator; a failure: the collage's error / offline line (tap to retry).
import AppData
import DesignSystem
import SwiftUI

struct CollageLinkScreen: View {
    let groupID: String
    let collageID: CollageID
    var data: any SocialDataSource = SocialServices.shared.data

    private enum Phase: Equatable {
        case loading
        case ready(invitationID: String)
        case failed(offline: Bool)
        case gone
    }

    @State private var phase: Phase = .loading

    var body: some View {
        Group {
            switch phase {
            case let .ready(invitationID):
                CollageScreen(groupID: groupID, invitationID: invitationID)
            case .loading:
                LoadingHUD()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(offline):
                SocialErrorLine(text: offline ? Copy.collageViewOfflineTitle : Copy.collageViewErrorTitle) {
                    Task { await resolve() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .gone:
                EmptyStateView(icon: Tokens.Icons.globalCamera, title: Copy.collageViewEmptyTitle, detail: Copy.collageViewEmptyDetail)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .socialHidesNavigationBar()
        .task { if phase == .loading { await resolve() } }
    }

    private func resolve() async {
        phase = .loading
        do {
            if let invitationID = try await data.collages(ids: [collageID]).first?.invitationID {
                phase = .ready(invitationID: invitationID.rawValue)
            } else {
                phase = .gone // deleted (its last photo removed) or not visible
            }
        } catch {
            phase = .failed(offline: SocialFailure(error) == .offline)
        }
    }
}

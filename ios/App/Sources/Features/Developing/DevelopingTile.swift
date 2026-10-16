// Surface: camera.overnight B — the developing tile in the group screen's week strip. Visual reference: Retro's C-17
// placeholder tile (references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png, H43: `color.global.control`
// tiles); mechanics Lapse's developing tiles with a centred marker (references/auto/lapse/store/lapse-store-se-3.png,
// LSE3) and Dispo's one "developing" banner (references/auto/dispo/help/help-360097208771_library.png, DLIB — its number
// not copied) (design/surfaces/camera.overnight.md B; MERGE ON-5).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

@MainActor
@Observable
final class DevelopingTileModel {
    let groupID: GroupID
    private(set) var status: OvernightStatus = .notDeveloping

    private let services: PlansServices

    init(groupID: GroupID, services: PlansServices) {
        self.groupID = groupID
        self.services = services
    }

    /// One tile while the group has at least one developing photo — whatever the number of photos or photographers.
    var isDeveloping: Bool { status.developing }

    /// `camera.overnight.tile.a11y` ("Photos developing, shown to everyone {reveal}"): the label carries the reveal the
    /// tile does not show.
    var accessibilityLabel: String {
        Copy.cameraOvernightTileA11y(reveal: status.revealAt.map(PlanFormats.reveal) ?? "")
    }

    /// `group_developing`; a failure keeps the last state.
    func refresh() async {
        guard let status = try? await services.questions.developing(groupID: groupID) else { return }
        self.status = status
    }

    /// A reveal inserts the developed photos as posts: refetch on the group's post changes.
    func follow() async {
        for await _ in services.questions.postChanges(groupID: groupID) {
            await refresh()
        }
    }
}

/// The developing tile (`camera.overnight.layout.developingTile`): a C-17 placeholder tile
/// `size.global.stripTileWidth` × `.stripTileHeight`, fill `color.global.control`, no photo, no scrim, the word
/// `camera.overnight.tile.label` centred (text role `tileLabel`, `color.global.textSecondary`). Not a button, no long
/// press; a static element labelled with the reveal time.
struct DevelopingTile: View {
    let accessibilityLabel: String

    var body: some View {
        ZStack {
            Tokens.Colors.globalControl
            Text(Copy.cameraOvernightTileLabel)
                .dsTextStyle(TextRole.tileLabel)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .lineLimit(1)
        }
        .frame(width: Tokens.Sizes.globalStripTileWidth, height: Tokens.Sizes.globalStripTileHeight)
        .clipShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityIdentifier("groups.screen.developing")
    }
}

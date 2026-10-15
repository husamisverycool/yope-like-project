// Surface: groups.screen — reference app: Yope.
// Reference images: listed in design/surfaces/groups.screen.md (docs/SURFACES.md).
// Container only: the screens pass builds this surface from its spec, with Tokens.* / Copy.*.
import SwiftUI

/// The group's photos, members, entry to chat, walls, week, settings.
struct GroupScreen: View {
    let groupID: String

    var body: some View {
        ScreenContainer(surface: "groups.screen")
    }
}

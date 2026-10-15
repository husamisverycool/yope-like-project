// Surface: groups.list — reference app: Yope.
// Reference images: listed in design/surfaces/groups.list.md (docs/SURFACES.md).
// Container only: the screens pass builds this surface from its spec, with Tokens.* / Copy.*.
import SwiftUI

/// Group list / home; switch between groups.
struct GroupsHomeScreen: View {
    var body: some View {
        ScreenContainer(surface: "groups.list")
    }
}

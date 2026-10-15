// Surface: year.story — reference app: Spotify Wrapped.
// Reference images: listed in design/surfaces/year.story.md (docs/SURFACES.md).
// Container only: the screens pass builds this surface from its spec, with Tokens.* / Copy.*.
import SwiftUI

/// December tap-through year story + share cards.
struct YearStoryScreen: View {
    let groupID: String
    let year: Int

    var body: some View {
        ScreenContainer(surface: "year.story")
    }
}

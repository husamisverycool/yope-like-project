// Surface: birthday.tribute — reference app: Tribute / VidDay.
// Reference images: listed in design/surfaces/birthday.tribute.md (docs/SURFACES.md).
// Container only: the screens pass builds this surface from its spec, with Tokens.* / Copy.*.
import SwiftUI

/// The tribute video for the birthday person.
struct TributeScreen: View {
    let tributeID: String
    let groupID: String?

    var body: some View {
        ScreenContainer(surface: "birthday.tribute")
    }
}

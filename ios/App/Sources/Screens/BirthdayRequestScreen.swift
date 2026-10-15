// Surface: birthday.request — reference app: Tribute / VidDay.
// Reference images: listed in design/surfaces/birthday.request.md (docs/SURFACES.md).
// Container only: the screens pass builds this surface from its spec, with Tokens.* / Copy.*.
import SwiftUI

/// Private request to contribute a photo + one line.
struct BirthdayRequestScreen: View {
    let requestID: String
    let groupID: String?

    var body: some View {
        ScreenContainer(surface: "birthday.request")
    }
}

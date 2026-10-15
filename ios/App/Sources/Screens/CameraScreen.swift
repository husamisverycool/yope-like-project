// Surface: camera.capture — reference app: Yope + Locket; daily.capture: BeReal.
// Reference images: listed in design/surfaces/camera.capture.md (docs/SURFACES.md).
// Container only: the screens pass builds this surface from its spec, with Tokens.* / Copy.*.
import SwiftUI

/// Opens to the camera (`camera.fromwidget` when opened from a widget). With an `invitationID` it is the daily same-moment capture (`daily.capture`): countdown, front + back.
struct CameraScreen: View {
    let groupID: String?
    let invitationID: String?

    var body: some View {
        ScreenContainer(surface: "camera.capture")
    }
}

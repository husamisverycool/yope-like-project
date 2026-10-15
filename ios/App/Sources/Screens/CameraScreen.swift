// Surface: camera.capture / camera.fromwidget — reference app: Yope + Locket; with an invitation:
// daily.capture — reference app: BeReal.
// Reference images: listed in design/surfaces/camera.capture.md, camera.fromwidget.md and
// daily.capture.md (docs/SURFACES.md).
import SwiftUI

/// Opens to the camera (`camera.fromwidget` when opened from a widget: the widget's group is
/// preselected in send-to). With an `invitationID` it is the daily same-moment capture
/// (`daily.capture`): countdown, front + back.
struct CameraScreen: View {
    let groupID: String?
    let invitationID: String?

    var body: some View {
        if let groupID, let invitationID {
            DailyCaptureScreen(groupID: groupID, invitationID: invitationID)
        } else {
            CameraCaptureScreen(contextGroupID: groupID)
        }
    }
}

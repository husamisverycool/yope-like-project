// Surface: camera.capture / camera.fromwidget — visual reference Retro (composition), mechanics Locket; with an
// invitation: daily.capture — visual reference Retro (composition), mechanics BeReal.
// Reference images: listed in design/surfaces/camera.capture.md, camera.fromwidget.md and
// daily.capture.md (references/auto/retro/…, references/auto/locket/…, references/auto/bereal/…).
import SwiftUI

/// Opens to the camera (`camera.fromwidget` when opened from a widget: the widget's group is
/// preselected in send-to). With an `invitationID` it is the daily same-moment capture
/// (`daily.capture`): countdown, front + back.
struct CameraScreen: View {
    let groupID: String?
    let invitationID: String?

    /// Starts the camera session ahead of `camera.capture` (first frame as early as the platform
    /// allows). For the shell: call when the camera is about to be shown.
    @MainActor
    static func prewarm() {
        Task { await CaptureEnvironment.shared.prewarmCamera() }
    }

    var body: some View {
        if let groupID, let invitationID {
            DailyCaptureScreen(groupID: groupID, invitationID: invitationID)
        } else {
            CameraCaptureScreen(contextGroupID: groupID)
        }
    }
}

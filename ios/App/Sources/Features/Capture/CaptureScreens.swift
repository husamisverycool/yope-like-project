// Surfaces: camera.capture (+ camera.fromwidget), camera.sendto, daily.capture, collage.view,
// collage.share. Reference images: listed in each design/surfaces/<id>.md (Retro: references/auto/retro/…).
// Screen entry points: each creates its view model once (camera sessions are expensive) from the
// capture environment and hosts the view.
import SwiftUI

struct CameraCaptureScreen: View {
    let contextGroupID: String?
    /// Nil: `CaptureEnvironment.shared`.
    var environment: CaptureEnvironment?

    @State private var model: CameraCaptureModel? = nil

    var body: some View {
        ZStack {
            if let model {
                let resolved = environment ?? CaptureEnvironment.shared
                CameraCaptureView(
                    model: model,
                    makeSendTo: { media in
                        resolved.sendToModel(
                            media: media,
                            more: model.capturedMore,
                            contextGroupID: model.sendToGroupID,
                            onClose: { model.discardCapture() },
                            onSent: { model.didSend() }
                        )
                    },
                    sendCenter: resolved.sendCenter
                )
            }
        }
        .onAppear {
            if model == nil {
                model = (environment ?? CaptureEnvironment.shared).cameraModel(contextGroupID: contextGroupID)
            }
        }
    }
}

struct DailyCaptureScreen: View {
    let groupID: String
    let invitationID: String
    var environment: CaptureEnvironment?

    @State private var model: DailyCaptureModel? = nil

    var body: some View {
        ZStack {
            if let model {
                DailyCaptureView(model: model, sendCenter: (environment ?? CaptureEnvironment.shared).sendCenter)
            }
        }
        .onAppear {
            if model == nil {
                model = (environment ?? CaptureEnvironment.shared).dailyModel(groupID: groupID, invitationID: invitationID)
            }
        }
    }
}

struct CollageScreen: View {
    let groupID: String
    let invitationID: String
    /// Presented as a full-screen cover (collage.view: "Full-screen modal"); false when pushed on the stack.
    var isPresentedModally = false
    var environment: CaptureEnvironment?

    @State private var model: CollageModel? = nil

    var body: some View {
        ZStack {
            if let model {
                CollageView(model: model, isPresentedModally: isPresentedModally)
            }
        }
        .onAppear {
            if model == nil {
                model = (environment ?? CaptureEnvironment.shared).collageModel(groupID: groupID, invitationID: invitationID)
            }
        }
    }
}

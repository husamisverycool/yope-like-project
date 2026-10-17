// Surface: camera.quickaccess — the Control Center / Lock Screen / Action button control that opens the camera (iOS 18+;
// design/surfaces/camera.quickaccess.md). Mechanics: Snapchat's Lock Screen camera control
// (https://9to5mac.com/2024/10/24/snapchat-camera-will-be-available-from-the-iphone-lock-screen-but-no-filters/); anatomy
// Apple HIG Controls (https://developer.apple.com/design/human-interface-guidelines/controls): a symbol, a title, and
// hint text for the Action button. The control runs `OpenCameraIntent` (ios/Intents), which opens the app to the camera.
import AppIntents
import AppModels
import DesignSystem
import SwiftUI
import WidgetKit

/// One control button: `icon.global.camera` and `camera.quickaccess.control.title`; in the controls gallery its name
/// and `camera.quickaccess.control.description`; on the Action button the hint `camera.quickaccess.control.actionHint`.
/// No configuration (it always opens the camera with every group to choose from, as the camera tab does).
@available(iOS 18.0, *)
struct CameraControl: ControlWidget {
    static let kind = "CameraControl" // provenance-ok: control kind identifier, not UI

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenCameraIntent()) {
                Label(Copy.cameraQuickaccessControlTitle, systemImage: Tokens.Icons.globalCamera)
            }
            .controlWidgetActionHint(Text(Copy.cameraQuickaccessControlActionHint))
        }
        .displayName(LocalizedStringResource("\(Copy.cameraQuickaccessControlTitle)"))
        .description(LocalizedStringResource("\(Copy.cameraQuickaccessControlDescription)"))
    }
}

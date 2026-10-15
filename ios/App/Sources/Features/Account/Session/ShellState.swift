// Account group — the home shell's tab state. Yope's floating tab bar (groups.list.layout.tabBar) switches between the
// camera (camera.capture: "the app opens to the camera", tab bar under it, structure item 6) and the groups list; walls
// and me push their screens on the main stack.
import Foundation
import Observation

@MainActor
@Observable
final class ShellState {
    /// The tab shown at the root: `.camera` or `.groups` (walls / me push from the groups stack).
    var tab: AppTab
    /// The group preselected in send-to when the camera was opened for one (camera.fromwidget, a group card's camera).
    private(set) var cameraGroupID: String?

    /// The shell on screen (the paywall entry closes the camera before prompting).
    static weak var active: ShellState?

    /// Starts the capture session ahead of the camera (`CameraScreen.prewarm` in the app; nothing in tests).
    let prewarm: @MainActor () -> Void

    init(tab: AppTab = .groups, prewarm: @escaping @MainActor () -> Void = {}) {
        self.tab = tab
        self.prewarm = prewarm
    }

    /// Shows the camera tab (prewarming the capture session first), optionally for a group.
    func showCamera(groupID: String? = nil) {
        prewarm()
        cameraGroupID = groupID
        tab = .camera
    }

    func showGroups() {
        tab = .groups
        cameraGroupID = nil
    }

    /// Leaves the camera (a premium prompt never shows during capture, `SessionPromptGate.Blocker.capture`).
    func leaveCamera() {
        if tab == .camera { showGroups() }
    }
}

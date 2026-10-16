// Account group — the home shell's tab state. The C-04 tab bar (groups.list.layout.tabBar) switches between the camera
// (camera.capture: "the app opens to the camera", tab bar under it, structure item 6) and the groups list; walls and me
// push their screens on the main stack.
import Foundation
import Observation

@MainActor
@Observable
final class ShellState {
    /// The tab shown at the root: `.camera` or `.groups` (walls / me push from the groups stack).
    var tab: AppTab
    /// The group preselected in send-to when the camera was opened for one (camera.fromwidget, a group card's camera).
    private(set) var cameraGroupID: String?

    /// A route whose spec presents it modally when it arrives as a push from a link (`AppRouter` pushes every link
    /// route): settings.root and groups.settings are sheets; birthday.request, birthday.tribute and collage.view are full
    /// screen. `MainShell` presents it.
    var presentedRoute: PresentedRoute?

    /// The shell on screen (the paywall entry closes the camera before prompting): the latest one created, and the
    /// one `MainShell` shows.
    static weak var active: ShellState?

    /// Starts the capture session ahead of the camera (`CameraScreen.prewarm` in the app; nothing in tests).
    let prewarm: @MainActor () -> Void

    init(tab: AppTab = .groups, prewarm: @escaping @MainActor () -> Void = {}) {
        self.tab = tab
        self.prewarm = prewarm
        Self.active = self
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

/// A pushed route shown as a sheet or full screen instead (`ShellState.presentedRoute`).
struct PresentedRoute: Identifiable, Hashable {
    enum Style: Hashable {
        case sheet
        case fullScreen
    }

    let route: AppRoute
    let style: Style

    var id: AppRoute { route }

    /// How `route` is presented when its spec asks for a modal; nil for routes that are pushed.
    /// - year.story is not here: it is `AppModal.memory(.yearStory)` (full screen), see `MainShell`.
    static func modal(for route: AppRoute) -> PresentedRoute? {
        switch route {
        case .birthdayRequest:
            // birthday.request.md structure and presentation: full screen.
            return PresentedRoute(route: route, style: .fullScreen)
        case .tribute:
            // birthday.tribute.md structure: full screen.
            return PresentedRoute(route: route, style: .fullScreen)
        case .capture(.collage):
            // collage.view: a media cover, presented full screen like send-to and the daily capture.
            return PresentedRoute(route: route, style: .fullScreen)
        case .account(.settings), .account(.groupSettings), .account(.groupProfile):
            // settings.root / groups.settings: page sheets with their own navigation (`settings.root.layout.list.sheet`).
            return PresentedRoute(route: route, style: .sheet)
        default:
            return nil
        }
    }
}

extension ShellState {
    /// Takes a pushed route whose spec presents it modally off the stack: year.story becomes `AppModal.memory(.yearStory)`
    /// (full screen, its platform notes); birthday.request, birthday.tribute, collage.view, settings.root and
    /// groups.settings become `presentedRoute`. onthisday stays pushed in the group's stack (onthisday.md B). Returns true
    /// when it moved one.
    @discardableResult
    func presentModalRoute(router: AppRouter) -> Bool {
        guard let last = router.path.last else { return false }
        if case let .yearStory(groupID, year) = last {
            router.path.removeLast()
            router.modal = .memory(.yearStory(groupID: groupID, year: year))
            return true
        }
        guard let presented = PresentedRoute.modal(for: last) else { return false }
        router.path.removeLast()
        router.modal = nil
        presentedRoute = presented
        return true
    }
}

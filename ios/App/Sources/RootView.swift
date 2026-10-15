import SwiftUI

/// The window's content: the sign-up / onboarding stack until the person is home, then the main navigation stack
/// (groups.list at its root) driven by `AppRouter.path`, with one modal slot presented as a sheet or a full-screen
/// cover depending on the surface spec (`AppModal.presentation`); the camera is a tab with the tab bar under it.
///
/// Every screen below gets the account dependencies (`.environment(AccountDependencies)`), the storage URL resolver
/// for `StorageImage` and the toast host. The appearance is dark only (`layout.global.appearance`).
struct RootView: View {
    @Bindable var router: AppRouter
    let dependencies: AccountDependencies

    /// - Parameter dependencies: nil builds an unconfigured set (no backend: the signed-out sign-up screen), used by
    ///   previews and the snapshot pipeline test.
    init(router: AppRouter, dependencies: AccountDependencies? = nil) {
        _router = Bindable(router)
        self.dependencies = dependencies ?? AccountDependencies.unconfigured(router: router)
    }

    var body: some View {
        Group {
            switch dependencies.session.phase {
            case .launching:
                LaunchingView()
            case .signUp:
                AuthFlowView(session: dependencies.session)
            case .refused:
                AgeGateRefusedScreen(minAge: dependencies.session.refusalMinAge)
            case .ready:
                MainShell(router: router, dependencies: dependencies)
            }
        }
        .environment(dependencies)
        .environment(\.storageURLResolver, dependencies.storageURLResolver)
        .toastHost(dependencies.toasts)
        .preferredColorScheme(.dark)
    }
}

/// Home and everything pushed or presented from it: the camera tab (camera.capture, tab bar under it) or the groups
/// stack (groups.list at its root). A camera link without an invitation (widget, group card, capture's own
/// "open camera") opens the camera tab, so the tab bar is always there to leave it; the daily capture stays full screen.
struct MainShell: View {
    @Bindable var router: AppRouter
    let dependencies: AccountDependencies

    private var shell: ShellState { dependencies.shell }

    var body: some View {
        ZStack {
            switch shell.tab {
            case .camera:
                CameraScreen(groupID: shell.cameraGroupID, invitationID: nil)
                    .id(shell.cameraGroupID)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        FloatingTabBar(selected: .camera, avatarPath: nil) { tab in
                            ShellNavigation.select(tab, router: router, shell: shell)
                        }
                    }
            default:
                NavigationStack(path: $router.path) {
                    GroupsHomeScreen()
                        .navigationDestination(for: AppRoute.self) { route in
                            RouteDestination(route: route)
                        }
                }
            }
        }
        .sheet(item: sheetModal) { modal in
            ModalDestination(modal: modal)
                .environment(dependencies)
                .environment(\.storageURLResolver, dependencies.storageURLResolver)
                .toastHost(dependencies.toasts)
        }
        .background {
            Color.clear
                .fullScreenCover(item: coverModal) { modal in
                    ModalDestination(modal: modal)
                        .environment(dependencies)
                        .environment(\.storageURLResolver, dependencies.storageURLResolver)
                        .toastHost(dependencies.toasts)
                }
        }
        .captureSendStatus(CaptureEnvironment.shared.sendCenter)
        .onChange(of: router.modal) { _, modal in openCameraTabIfNeeded(modal) }
        .onAppear { openCameraTabIfNeeded(router.modal) }
        .onChange(of: router.path) { _, path in
            // A route pushed from anywhere (notification, link) shows the groups stack.
            if !path.isEmpty { shell.showGroups() }
        }
    }

    /// `router.modal = .camera(groupID, nil)` → the camera tab for that group.
    private func openCameraTabIfNeeded(_ modal: AppModal?) {
        guard case let .camera(groupID, nil)? = modal else { return }
        router.modal = nil
        shell.showCamera(groupID: groupID)
    }

    /// `router.modal` when it is presented as a sheet.
    private var sheetModal: Binding<AppModal?> {
        Binding(
            get: { router.modal.flatMap { $0.presentation == .sheet ? $0 : nil } },
            set: { newValue in
                if let newValue {
                    router.modal = newValue
                } else if router.modal?.presentation == .sheet {
                    router.modal = nil
                }
            }
        )
    }

    /// `router.modal` when it is presented full screen.
    private var coverModal: Binding<AppModal?> {
        Binding(
            get: { router.modal.flatMap { $0.presentation == .fullScreen ? $0 : nil } },
            set: { newValue in
                if let newValue {
                    router.modal = newValue
                } else if router.modal?.presentation == .fullScreen {
                    router.modal = nil
                }
            }
        )
    }
}

/// What the tab bar items do (groups.list.layout.tabBar): camera and groups switch tabs; walls and me push their
/// screens on the groups stack (`CrossGroupRoutes`).
enum ShellNavigation {
    @MainActor
    static func select(_ tab: AppTab, router: AppRouter, shell: ShellState) {
        switch tab {
        case .camera:
            shell.showCamera()
        case .groups:
            router.path = []
            shell.showGroups()
        case .walls:
            if let route = CrossGroupRoutes.wallsBrowse(groupID: nil) {
                shell.showGroups()
                router.path = [route]
            }
        case .me:
            if let route = CrossGroupRoutes.wallsMine {
                shell.showGroups()
                router.path = [route]
            }
        }
    }
}

extension AppModal {
    enum Presentation: Equatable {
        case sheet
        case fullScreen
        /// The camera tab (`MainShell`), not a modal.
        case tab
    }

    /// Account surfaces follow their specs (groups.create / groups.invite / safety.report: sheets; paywall: full
    /// screen); the in-app invite preview is a sheet so it can be swiped away; the camera without an invitation is
    /// the camera tab (camera.capture structure item 6). Other groups' modals stay full screen.
    var presentation: Presentation {
        switch self {
        case .camera(_, nil): return .tab
        case .invite: return .sheet
        case let .account(modal): return modal.presentsAsSheet ? .sheet : .fullScreen
        default: return .fullScreen
        }
    }
}

/// Black screen while a stored session is checked (only for an instant at launch).
struct LaunchingView: View {
    var body: some View {
        SignUpStateView(title: nil, detail: nil)
    }
}

struct RouteDestination: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case let .group(id):
            GroupScreen(groupID: id)
        case let .post(groupID, postID):
            PhotoViewerScreen(groupID: groupID, postID: postID)
        case let .chat(groupID, messageID):
            ChatScreen(groupID: groupID, messageID: messageID)
        case let .recap(groupID, recapID):
            RecapScreen(groupID: groupID, recapID: recapID)
        case let .birthdayRequest(requestID, groupID):
            BirthdayRequestScreen(requestID: requestID, groupID: groupID)
        case let .tribute(tributeID, groupID):
            TributeScreen(tributeID: tributeID, groupID: groupID)
        case let .yearStory(groupID, year):
            YearStoryScreen(groupID: groupID, year: year)
        case let .account(route):
            AccountDestination(route: route)
        case let .capture(route):
            CaptureDestination(route: route)
        case let .social(route):
            SocialDestination(route: route)
        case let .memory(route):
            MemoryDestination(route: route)
        }
    }
}

struct ModalDestination: View {
    let modal: AppModal

    var body: some View {
        switch modal {
        case let .camera(groupID, invitationID):
            CameraScreen(groupID: groupID, invitationID: invitationID)
        case let .invite(token):
            InviteScreen(token: token)
        case let .account(modal):
            AccountModalDestination(modal: modal)
        case let .capture(modal):
            CaptureModalDestination(modal: modal)
        case let .social(modal):
            SocialModalDestination(modal: modal)
        case let .memory(modal):
            MemoryModalDestination(modal: modal)
        }
    }
}

/// Body of a screen container until the screens pass builds the surface: renders nothing
/// visible and carries the surface id as its accessibility identifier (for UI tests).
struct ScreenContainer: View {
    let surface: String

    var body: some View {
        Color.clear
            .accessibilityIdentifier(surface)
    }
}

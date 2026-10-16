// Account group — what the account screens need, injected once by the app shell (`RootView`) with
// `.environment(dependencies)`. Live: AppData + AppServices; DEBUG UI tests / snapshots: in-memory fakes.
import AppData
import AppModels
import Foundation
import Observation

@MainActor
@Observable
final class AccountDependencies {
    let data: AccountDataSource
    let router: AppRouter
    let session: AccountSession
    let network: NetworkMonitor
    let toasts: ToastCenter
    let configuration: AppConfiguration
    let notifications: NotificationAuthorizing
    let purchases: PurchasesProviding
    let liveActivity: LiveActivityPreference
    /// The home shell's tabs (camera / groups).
    var shell: ShellState { session.shell }
    /// The signed-in person's phone number (settings.account, read-only); nil when unknown.
    let currentPhone: @MainActor () -> String?
    /// Runs after the Live Activity preference changed (re-registers the device's push tokens).
    let liveActivityChanged: @MainActor () -> Void
    /// The status of a system permission (settings.root System Permissions). Nil: the live status (AppServices).
    let permissionStatus: (@MainActor (SystemPermission) async -> PermissionStatus)?

    init(
        data: AccountDataSource,
        router: AppRouter,
        session: AccountSession,
        network: NetworkMonitor,
        toasts: ToastCenter,
        configuration: AppConfiguration,
        notifications: NotificationAuthorizing,
        purchases: PurchasesProviding,
        liveActivity: LiveActivityPreference,
        currentPhone: @escaping @MainActor () -> String? = { nil },
        liveActivityChanged: @escaping @MainActor () -> Void = {},
        permissionStatus: (@MainActor (SystemPermission) async -> PermissionStatus)? = nil
    ) {
        self.data = data
        self.router = router
        self.session = session
        self.network = network
        self.toasts = toasts
        self.configuration = configuration
        self.notifications = notifications
        self.purchases = purchases
        self.liveActivity = liveActivity
        self.currentPhone = currentPhone
        self.liveActivityChanged = liveActivityChanged
        self.permissionStatus = permissionStatus
    }

    /// The status of `permission`: the injected one (tests, UI-test scenarios), else the live one.
    func status(of permission: SystemPermission) async -> PermissionStatus {
        if let permissionStatus { return await permissionStatus(permission) }
        return await SystemPermission.liveStatus(permission, notifications: notifications)
    }

    /// Resolves storage paths for `StorageImage` / `AvatarView`.
    var storageURLResolver: StorageURLResolver {
        let data = self.data
        return { path in try await data.signedURL(path: path) }
    }
}

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
    /// The signed-in person's phone number (settings.account, read-only); nil when unknown.
    let currentPhone: @MainActor () -> String?
    /// Runs after the Live Activity preference changed (re-registers the device's push tokens).
    let liveActivityChanged: @MainActor () -> Void

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
        liveActivityChanged: @escaping @MainActor () -> Void = {}
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
    }

    /// Resolves storage paths for `StorageImage` / `AvatarView`.
    var storageURLResolver: StorageURLResolver {
        let data = self.data
        return { path in try await data.signedURL(path: path) }
    }
}

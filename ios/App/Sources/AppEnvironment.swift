import AppData
import AppModels
import AppServices
import Foundation
import Observation
import SwiftUI
import UIKit

/// Tokens the API layer uploads to `devices` (push_token, push_to_start_token) and per-activity
/// update tokens. Filled by the push and Live Activity services.
@MainActor
@Observable
final class DeviceTokens {
    var apnsToken: String?
    var pushToStartToken: String?
    var activityTokens: [String: LiveActivityService.ActivityToken] = [:]

    func record(_ token: LiveActivityService.ActivityToken) {
        activityTokens[token.activityID] = token
    }
}

/// The app's long-lived services and state. One instance per process (`shared`), used by the
/// app delegate (APNs callbacks, background pushes) and the SwiftUI scene.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment(bundle: .main)

    /// Unreferenced widget files older than this are deleted when the app goes to the background.
    /// Longer than a Notification Service Extension run (about 30 s), so a rendition written by
    /// the extension is never removed before its snapshot is saved.
    static let widgetPruneGracePeriod: TimeInterval = 600

    let configuration: AppConfiguration
    let parser: DeepLinkParser
    let router: AppRouter
    let push: PushService
    let liveActivities: LiveActivityService
    let purchases: PurchasesService
    let widgetStore: WidgetStore
    let deviceTokens = DeviceTokens()
    /// The WidgetKit push token written by the widget extension (iOS 26 widget push handler).
    let widgetPushTokens: WidgetPushTokenStore
    /// The backend (AppData). Nil while config/app.json has no Supabase URL / anon key (BLOCKED).
    let data: DataEnvironment?
    /// Session flow, account screens' data and platform seams (`RootView` injects them).
    let accountDependencies: AccountDependencies

    private var hasLaunched = false
    private var wasInBackground = false

    init(bundle: Bundle) {
        let configuration = AppConfiguration.load(from: bundle) ?? AppConfiguration()
        self.configuration = configuration
        parser = DeepLinkParser(configuration: configuration)
        let router = AppRouter(parser: parser)
        self.router = router
        let push = PushService(parser: parser)
        self.push = push
        liveActivities = LiveActivityService()
        let purchases = PurchasesService(entitlementID: configuration.premiumEntitlement)
        self.purchases = purchases
        let widgetStore = WidgetStore.forBundle(bundle)
        self.widgetStore = widgetStore
        widgetPushTokens = WidgetPushTokenStore.forBundle(bundle)
        // Session glue: RevenueCat follows the signed-in user; widget reloads after the group
        // list or a deleted post changed the widget store.
        let hooks = SessionHooks(
            linkPurchases: { userID in
                if let userID {
                    try? await purchases.logIn(userID: userID.rawValue)
                } else {
                    try? await purchases.logOut()
                }
            },
            reloadWidgets: {
                await MainActor.run { WidgetReloader.reloadGroupWidgets() }
            }
        )
        let data = try? DataEnvironment.live(configuration: configuration, widgetStore: widgetStore, hooks: hooks)
        self.data = data

        #if DEBUG
        if let scenario = AccountUITestScenario.fromLaunchArguments() {
            accountDependencies = scenario.makeDependencies(router: router, configuration: configuration)
            return
        }
        #endif
        let liveData = LiveAccountData(environment: data)
        let liveActivityPreference = LiveActivityPreference()
        accountDependencies = AccountDependencies.live(
            data: liveData,
            router: router,
            configuration: configuration,
            notifications: LiveNotificationAuthorizer(push: push),
            purchases: RevenueCatPurchases(service: purchases),
            liveActivity: liveActivityPreference,
            currentPhone: { liveData.currentPhone },
            liveActivityChanged: { AppEnvironment.shared.syncDeviceTokens() }
        )
    }

    func didFinishLaunching() {
        guard !hasLaunched else { return }
        hasLaunched = true
        router.startSession()

        let router = self.router
        let deviceTokens = self.deviceTokens
        push.onRoute = { link in router.handle(link) }
        push.onDeviceToken = { [weak self] token in
            deviceTokens.apnsToken = token
            self?.syncDeviceTokens()
        }
        push.install()

        liveActivities.onPushToStartToken = { [weak self] token in
            deviceTokens.pushToStartToken = token
            self?.syncDeviceTokens()
        }
        liveActivities.onActivityToken = { token in deviceTokens.record(token) }
        liveActivities.startObserving()

        purchases.configure(apiKey: configuration.revenueCatAPIKey, appUserID: data?.auth.currentUserID?.rawValue)

        // Registers the device after sign-in, keeps widgets and RevenueCat in step with the
        // session, resumes unsent posts.
        if let data {
            Task { await data.coordinator.start() }
        }

        // Signed out → sign-up; signed in → onboarding steps not done yet, or home. The router applies links
        // (`pendingLink`) only once the person is home (`AccountSession` calls `router.setReady`).
        let account = accountDependencies
        account.network.follow(account.data.networkUpdates())
        account.session.start(handoff: InviteHandoff.take(from: InviteHandoff.defaults()))
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if wasInBackground {
                wasInBackground = false
                router.startSession()
            }
            // Reloads requested while the app is in the foreground are not budgeted
            // (docs/PLATFORM_CONSTRAINTS.md §1.1), so every foreground refreshes the widgets.
            WidgetReloader.reloadAll()
            // Picks up a widget push token the widget extension recorded meanwhile.
            syncDeviceTokens()
            let liveActivities = self.liveActivities
            Task { await liveActivities.endClosedActivities() }
        case .background:
            wasInBackground = true
            _ = try? widgetStore.prune(now: Date(), gracePeriod: Self.widgetPruneGracePeriod)
        default:
            break
        }
    }

    /// Hands the device's current push tokens to the session glue, which registers them
    /// (`register_device`) once someone is signed in. The Live Activity push-to-start token is left out while the
    /// person turned Live Activities off (settings.notifications).
    func syncDeviceTokens() {
        guard let data else { return }
        let tokens = DevicePushTokens(
            apns: deviceTokens.apnsToken,
            pushToStart: accountDependencies.liveActivity.isEnabled ? deviceTokens.pushToStartToken : nil,
            widgetPush: widgetPushTokens.load()
        )
        Task { await data.coordinator.updateDeviceTokens(tokens) }
    }

    /// Background (content-available) push carrying a `widget` payload: muted groups still get
    /// their widget updated silently (docs/SPEC_FLAGS.md T6).
    func deliverWidget(_ payload: WidgetPushPayload) async -> UIBackgroundFetchResult {
        let delivery = WidgetDelivery(store: widgetStore, downloader: NotificationWidgetDownload.downloader)
        do {
            try await delivery.deliver(payload, receivedAt: Date())
            WidgetReloader.reloadGroupWidgets()
            return .newData
        } catch {
            return .failed
        }
    }
}

/// Download limits for widget renditions delivered by push (shared with the Notification Service Extension's values).
enum NotificationWidgetDownload {
    /// Background pushes get about 30 s of execution; the request must finish well inside it.
    static let downloader = HTTPDownloader(timeout: 20, maxBytes: 10 * 1024 * 1024)
}

extension AccountDependencies {
    /// The live set: AppData-backed data, the session flow, reachability and the toast center.
    static func live(
        data: AccountDataSource,
        router: AppRouter,
        configuration: AppConfiguration,
        notifications: NotificationAuthorizing,
        purchases: PurchasesProviding,
        liveActivity: LiveActivityPreference,
        refusals: AgeGateRefusalStoring = KeychainAgeGateRefusalStore(),
        onboarding: OnboardingRecord = OnboardingRecord(),
        currentPhone: @escaping @MainActor () -> String? = { nil },
        liveActivityChanged: @escaping @MainActor () -> Void = {}
    ) -> AccountDependencies {
        let toasts = ToastCenter()
        let session = AccountSession(
            data: data,
            router: router,
            refusals: refusals,
            onboarding: onboarding,
            notifications: notifications,
            toasts: toasts
        )
        return AccountDependencies(
            data: data,
            router: router,
            session: session,
            network: NetworkMonitor(status: data.networkStatus),
            toasts: toasts,
            configuration: configuration,
            notifications: notifications,
            purchases: purchases,
            liveActivity: liveActivity,
            currentPhone: currentPhone,
            liveActivityChanged: liveActivityChanged
        )
    }

    /// No backend, no services (previews, the snapshot pipeline test): the signed-out sign-up screen.
    static func unconfigured(router: AppRouter) -> AccountDependencies {
        let dependencies = live(
            data: LiveAccountData(environment: nil),
            router: router,
            configuration: AppConfiguration(),
            notifications: StaticNotificationAuthorizer(status: .notDetermined),
            purchases: UnavailablePurchases(),
            liveActivity: LiveActivityPreference(),
            refusals: InMemoryAgeGateRefusalStore(),
            onboarding: OnboardingRecord(defaults: UserDefaults(suiteName: "account.unconfigured") ?? .standard) // provenance-ok: defaults suite name
        )
        dependencies.session.start()
        return dependencies
    }
}

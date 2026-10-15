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

    private var hasLaunched = false
    private var wasInBackground = false

    init(bundle: Bundle) {
        let configuration = AppConfiguration.load(from: bundle) ?? AppConfiguration()
        self.configuration = configuration
        parser = DeepLinkParser(configuration: configuration)
        router = AppRouter(parser: parser)
        push = PushService(parser: parser)
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
        data = try? DataEnvironment.live(configuration: configuration, widgetStore: widgetStore, hooks: hooks)
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

        // Sign-in and onboarding arrive with the API and screens passes; until then every link
        // is applied immediately.
        router.setReady(true)
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
    /// (`register_device`) once someone is signed in.
    private func syncDeviceTokens() {
        guard let data else { return }
        let tokens = DevicePushTokens(
            apns: deviceTokens.apnsToken,
            pushToStart: deviceTokens.pushToStartToken,
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

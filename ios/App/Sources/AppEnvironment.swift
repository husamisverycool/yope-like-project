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

    private var hasLaunched = false
    private var wasInBackground = false

    init(bundle: Bundle) {
        let configuration = AppConfiguration.load(from: bundle) ?? AppConfiguration()
        self.configuration = configuration
        parser = DeepLinkParser(configuration: configuration)
        router = AppRouter(parser: parser)
        push = PushService(parser: parser)
        liveActivities = LiveActivityService()
        purchases = PurchasesService(entitlementID: configuration.premiumEntitlement)
        widgetStore = WidgetStore.forBundle(bundle)
    }

    func didFinishLaunching() {
        guard !hasLaunched else { return }
        hasLaunched = true
        router.startSession()

        let router = self.router
        let deviceTokens = self.deviceTokens
        push.onRoute = { link in router.handle(link) }
        push.onDeviceToken = { token in deviceTokens.apnsToken = token }
        push.install()

        liveActivities.onPushToStartToken = { token in deviceTokens.pushToStartToken = token }
        liveActivities.onActivityToken = { token in deviceTokens.record(token) }
        liveActivities.startObserving()

        purchases.configure(apiKey: configuration.revenueCatAPIKey, appUserID: nil)

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
            let liveActivities = self.liveActivities
            Task { await liveActivities.endClosedActivities() }
        case .background:
            wasInBackground = true
            _ = try? widgetStore.prune(now: Date(), gracePeriod: Self.widgetPruneGracePeriod)
        default:
            break
        }
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

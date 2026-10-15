import AppModels
import AppServices
import SwiftUI
import UIKit

@main
struct MainApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppRootView(environment: AppEnvironment.shared)
        }
    }
}

/// Connects the scene to the environment: incoming URLs, universal links and scene phase.
struct AppRootView: View {
    let environment: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        RootView(router: environment.router)
            .onOpenURL { url in
                environment.router.open(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL { environment.router.open(url) }
            }
            .onChange(of: scenePhase) { _, phase in
                environment.scenePhaseChanged(phase)
            }
    }
}

/// APNs callbacks and background pushes. Notification taps go through `PushService`
/// (the notification center delegate).
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    private var environment: AppEnvironment { AppEnvironment.shared }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        environment.didFinishLaunching()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        environment.push.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        environment.push.didFailToRegister(error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        // Parse before suspending: only the Sendable payload crosses the await.
        guard let payload = WidgetPushPayload(userInfo: userInfo) else { return .noData }
        return await environment.deliverWidget(payload)
    }
}

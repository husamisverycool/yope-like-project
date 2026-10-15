#if os(iOS)
import AppModels
import Foundation
import UIKit
@preconcurrency import UserNotifications

/// Notification categories: the worker sets `aps.category` to the push `type`
/// (`PushType`, shared with Android). They carry no actions yet (action titles are
/// user-facing copy from design/copy.json).
public enum NotificationCategory {
    public static let identifiers: [String] = PushType.allCases
        .filter { $0 != .widget && $0 != .dailyInvitationEnded }
        .map(\.rawValue)
}

/// Notification permission, APNs registration and routing of notification taps into `DeepLink`s.
///
/// Badges are never requested: an icon badge is a count (docs/CONVENTIONS.md §6).
@MainActor
public final class PushService: NSObject, UNUserNotificationCenterDelegate {
    /// Receives the APNs device token (lowercase hex) for upload to `devices.push_token`.
    public var onDeviceToken: ((String) -> Void)?
    public var onRegistrationError: ((Error) -> Void)?
    /// Receives the destination of a tapped notification.
    public var onRoute: ((DeepLink) -> Void)?

    private let center: UNUserNotificationCenter
    private nonisolated let parser: DeepLinkParser
    /// How a notification is shown while the app is in the foreground.
    private nonisolated let foregroundPresentation: UNNotificationPresentationOptions

    /// - Parameter foregroundPresentation: defaults to the same banner, list and sound a
    ///   backgrounded app shows (no badge).
    public init(
        parser: DeepLinkParser,
        center: UNUserNotificationCenter = .current(),
        foregroundPresentation: UNNotificationPresentationOptions = [.banner, .list, .sound]
    ) {
        self.parser = parser
        self.center = center
        self.foregroundPresentation = foregroundPresentation
        super.init()
    }

    /// Becomes the notification center delegate and registers the categories. Call from
    /// `application(_:didFinishLaunchingWithOptions:)` so taps that launch the app are delivered.
    public func install() {
        center.delegate = self
        let categories = NotificationCategory.identifiers.map {
            UNNotificationCategory(identifier: $0, actions: [], intentIdentifiers: [], options: [])
        }
        center.setNotificationCategories(Set(categories))
    }

    // MARK: Permission

    public func authorizationStatus() async -> PermissionStatus {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .granted
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    /// Shows the system prompt (alerts and sounds) when undetermined, then registers with APNs if allowed.
    @discardableResult
    public func requestAuthorization() async throws -> PermissionStatus {
        if await authorizationStatus() == .notDetermined {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        }
        let status = await authorizationStatus()
        if status == .granted { registerForRemoteNotifications() }
        return status
    }

    // MARK: APNs

    public func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Forward from `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
    public func didRegister(deviceToken: Data) {
        onDeviceToken?(PushToken.hex(deviceToken))
    }

    /// Forward from `application(_:didFailToRegisterForRemoteNotificationsWithError:)`.
    public func didFailToRegister(_ error: Error) {
        onRegistrationError?(error)
    }

    // MARK: UNUserNotificationCenterDelegate

    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        foregroundPresentation
    }

    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Read the payload before any suspension point; only the Sendable link crosses actors.
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let link = parser.parse(notificationPayload: response.notification.request.content.userInfo) else { return }
        await route(link)
    }

    private func route(_ link: DeepLink) {
        onRoute?(link)
    }
}
#endif

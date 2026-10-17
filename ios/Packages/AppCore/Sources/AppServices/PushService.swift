#if os(iOS)
import AppModels
import DesignSystem
import Foundation
import UIKit
@preconcurrency import UserNotifications

/// Notification categories: the worker sets `aps.category` to the push `type` (`PushType`, shared with Android). Each
/// carries the actions of its type (`NotificationAction.actions(for:)`; design/surfaces/notifications.push.md "Actions"):
/// "Reply" with a text field (`notifications.push.action.reply`, placeholder `chat.composer.placeholderReply`, button
/// `chat.composer.a11y.send`), the first quick reaction (`chat.reactions.layout.quickReactions`, the emoji itself) and
/// "Mute This Group" (`notifications.push.action.mute`). Every action needs the iPhone unlocked
/// (`.authenticationRequired`: it speaks for the person, and the session lives in the Keychain) and runs in the
/// background — the app is launched without coming to the front (`UNNotificationActionOptions` without `.foreground`).
public enum NotificationCategory {
    public static let identifiers: [String] = PushType.allCases
        .filter { $0 != .widget && $0 != .dailyInvitationEnded }
        .map(\.rawValue)

    /// One category per identifier. `quickReaction` nil leaves the reaction out.
    public static func categories(quickReaction: String?) -> Set<UNNotificationCategory> {
        Set(identifiers.map { identifier in
            let type = PushType(rawValue: identifier)
            let actions = (type.map(NotificationAction.actions(for:)) ?? []).compactMap { makeAction($0, quickReaction: quickReaction) }
            return UNNotificationCategory(identifier: identifier, actions: actions, intentIdentifiers: [], options: [])
        })
    }

    static func makeAction(_ action: NotificationAction, quickReaction: String?) -> UNNotificationAction? {
        switch action {
        case .reply:
            return UNTextInputNotificationAction(
                identifier: action.identifier,
                title: Copy.notificationsPushActionReply,
                options: [.authenticationRequired],
                textInputButtonTitle: Copy.chatComposerA11ySend,
                textInputPlaceholder: Copy.chatComposerPlaceholderReply
            )
        case .react:
            guard let quickReaction, !quickReaction.isEmpty else { return nil }
            return UNNotificationAction(identifier: action.identifier, title: quickReaction, options: [.authenticationRequired])
        case .muteGroup:
            return UNNotificationAction(identifier: action.identifier, title: Copy.notificationsPushActionMute, options: [.authenticationRequired])
        }
    }

    /// The local notification shown when an action failed (the platform's "couldn't send"): the failed reply
    /// `chat.thread.sendFailed`, reaction `chat.reactions.error`, mute `settings.notifications.error`.
    public static func failureText(for action: NotificationAction) -> String {
        switch action {
        case .reply: return Copy.chatThreadSendFailed
        case .react: return Copy.chatReactionsError
        case .muteGroup: return Copy.settingsNotificationsError
        }
    }
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
    /// Performs a notification action (reply, react, mute) with the stored session; a thrown error (or no handler) shows
    /// the failure notification. The system keeps the app running in the background until it returns.
    public var onAction: ((NotificationActionRequest) async throws -> Void)?

    private let center: UNUserNotificationCenter
    private nonisolated let parser: DeepLinkParser
    /// How a notification is shown while the app is in the foreground.
    private nonisolated let foregroundPresentation: UNNotificationPresentationOptions
    /// The emoji of the reaction action (`chat.reactions.layout.quickReactions`, first), set by `install`.
    private var quickReaction: String?

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

    /// Becomes the notification center delegate and registers the categories with their actions (once per launch).
    /// Call from `application(_:didFinishLaunchingWithOptions:)` so taps and actions that launch the app are delivered.
    /// - Parameter quickReaction: the reaction action's emoji (the first of `chat.reactions.layout.quickReactions`);
    ///   nil offers no reaction.
    public func install(quickReaction: String? = nil) {
        self.quickReaction = quickReaction
        center.delegate = self
        center.setNotificationCategories(NotificationCategory.categories(quickReaction: quickReaction))
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

    /// Registers with APNs when notifications are allowed (authorized, provisional or ephemeral). Call at every launch and
    /// return to the foreground: Apple asks apps to register at each launch because the device token can change, and a
    /// person who turned notifications on in Settings gets a token without going back to onboarding.
    @discardableResult
    public func registerIfAuthorized() async -> Bool {
        guard await authorizationStatus() == .granted else { return false }
        registerForRemoteNotifications()
        return true
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
        // Read the payload before any suspension point; only Sendable values cross actors.
        let content = response.notification.request.content
        let userInfo = content.userInfo
        let link = parser.parse(notificationPayload: userInfo)
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            guard let link else { return }
            await route(link)
        case UNNotificationDismissActionIdentifier:
            return
        default:
            guard let action = NotificationAction(identifier: response.actionIdentifier),
                  let target = NotificationActionTarget(userInfo: userInfo) else { return }
            let text = (response as? UNTextInputNotificationResponse)?.userText
            let notice = FailureNotice(title: content.title, threadID: content.threadIdentifier, link: link)
            await perform(action, target: target, text: text, notice: notice)
        }
    }

    private func route(_ link: DeepLink) {
        onRoute?(link)
    }

    // MARK: Actions

    /// What the failure notification shows: the alert's own title and thread, and its destination on tap.
    private struct FailureNotice: Sendable {
        let title: String
        let threadID: String
        let link: DeepLink?
    }

    /// Runs the action; a reply with no text does nothing. Any failure (no session, offline, refused) posts the failure
    /// notification, which opens what the alert opened so the person can try again in the app.
    private func perform(_ action: NotificationAction, target: NotificationActionTarget, text: String?, notice: FailureNotice) async {
        guard let request = NotificationActionRequest.make(action, target: target, text: text, reaction: quickReaction) else { return }
        guard let onAction else {
            await showFailure(action, notice: notice)
            return
        }
        do {
            try await onAction(request)
        } catch {
            await showFailure(action, notice: notice)
        }
    }

    private func showFailure(_ action: NotificationAction, notice: FailureNotice) async {
        let content = UNMutableNotificationContent()
        content.title = notice.title
        content.body = NotificationCategory.failureText(for: action)
        content.threadIdentifier = notice.threadID
        // No category: the failure offers no actions; a tap opens the photo or message (the person retries there).
        if let link = notice.link { content.userInfo = parser.payload(for: link) }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await center.add(request)
    }
}
#endif

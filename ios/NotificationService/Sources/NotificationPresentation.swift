// Surfaces: notifications.push (iOS presentation), daily.notification — voice reference Retro's notifications
// (references/auto/retro/apk/retro-android-2026.10.1150-strings.txt `post_reminder_notification_*`,
// `notification_settings_description_*`); the notification itself is drawn by the system (PLATFORM) —
// design/surfaces/notifications.push.md, daily.notification.md (`notifications.push.layout.ios`,
// `daily.notification.layout.delivery`; RC-16). How the Notification Service Extension presents an alert push
// (unit-tested from AppTests).
import AppModels
import Foundation
import UserNotifications

enum NotificationPresentation {
    /// `GroupWidgetKinds.all` of the widget extension (Home Screen and Lock Screen kinds).
    static let widgetKinds = WidgetKind.allGroupPhoto

    /// `notifications.push.layout.ios.newPostAttachment`: only the new-post alert carries the widget rendition as its
    /// photo attachment; other pushes with widget fields only refresh the widget.
    static func attachesPhoto(userInfo: [AnyHashable: Any]) -> Bool {
        (userInfo[PushKey.type] as? String) == PushType.newPost.rawValue
    }

    /// Thread = group id; category = push type (registered by `PushService` with the type's actions,
    /// `NotificationAction.actions(for:)`); a time-sensitive (or critical) level is lowered to `active` — never time-sensitive (tenet 5;
    /// daily.notification C-10); `passive` (quiet hours) stays passive.
    static func apply(to content: UNMutableNotificationContent) {
        let userInfo = content.userInfo
        if content.threadIdentifier.isEmpty, let groupID = userInfo[PushKey.groupID] as? String, !groupID.isEmpty {
            content.threadIdentifier = groupID
        }
        if content.categoryIdentifier.isEmpty, let type = userInfo[PushKey.type] as? String,
           PushType(rawValue: type) != nil {
            content.categoryIdentifier = type
        }
        if content.interruptionLevel == .timeSensitive || content.interruptionLevel == .critical {
            content.interruptionLevel = .active
        }
    }
}

// Surfaces: notifications.push (iOS presentation), daily.notification — design/surfaces/notifications.push.md,
// daily.notification.md (`notifications.push.layout.ios`, `daily.notification.layout.delivery`).
// How the Notification Service Extension presents an alert push (unit-tested from AppTests).
import AppModels
import Foundation
import UserNotifications

enum NotificationPresentation {
    /// `GroupWidgetKinds.all` of the widget extension.
    static let widgetKinds = [WidgetKind.groupPhoto, "GroupPhotoLockWidget"]

    /// Thread = group id; category = push type (registered by `PushService`, no actions: none has
    /// copy); a time-sensitive level is lowered to `active` (daily.notification C-10).
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

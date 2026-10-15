// Surfaces: notifications.push (iOS presentation), daily.notification, widget.arrival — references:
// BeReal (daily), Locket (new post) — design/surfaces/notifications.push.md, daily.notification.md,
// widget.arrival.md. Alert texts come from the worker; this extension only adjusts presentation.
import AppModels
import Foundation
import UserNotifications
import WidgetKit

/// Runs for alert pushes with `mutable-content: 1`. Presentation (`notifications.push.layout.ios`):
/// one thread per group, the category = the push type, never time-sensitive (tenet 5: the daily
/// invitation is `active`, `passive` stays passive in quiet hours). When the push carries widget fields
/// (`WidgetPushPayload`), it downloads the widget rendition from the signed URL into the App
/// Group, attaches it to the notification and reloads the group photo widget. The system gives
/// the extension about 30 seconds; the download timeout stays inside that, and when time runs
/// out (or anything fails) the notification is delivered unchanged.
final class NotificationService: UNNotificationServiceExtension {
    /// Request timeout inside the extension's execution window; renditions are small.
    private static let downloader = HTTPDownloader(timeout: 20, maxBytes: 10 * 1024 * 1024)
    private static let attachmentIdentifier = "widget-rendition"
    /// `GroupWidgetKinds.all` of the widget extension.
    static let widgetKinds = [WidgetKind.groupPhoto, "GroupPhotoLockWidget"]

    /// Thread = group id; category = push type (registered by `PushService`, no actions: none has
    /// copy); a time-sensitive level is lowered to `active` (daily.notification C-10).
    static func applyPresentation(to content: UNMutableNotificationContent) {
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

    private let lock = NSLock()
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttempt: UNMutableNotificationContent?
    private var work: Task<Void, Never>?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        Self.applyPresentation(to: content)
        lock.lock()
        self.contentHandler = contentHandler
        bestAttempt = content
        lock.unlock()

        guard let payload = WidgetPushPayload(userInfo: request.content.userInfo) else {
            finish()
            return
        }
        let store = WidgetStore.forBundle(.main)
        let delivery = WidgetDelivery(store: store, downloader: Self.downloader)
        work = Task { [weak self] in
            if let snapshot = try? await delivery.deliver(payload, receivedAt: Date()) {
                // The Home Screen and the Lock Screen widget kinds (ios/Widgets/Sources/GroupPhotoWidget.swift).
                for kind in Self.widgetKinds {
                    WidgetCenter.shared.reloadTimelines(ofKind: kind)
                }
                if let file = store.photoURL(for: snapshot) {
                    self?.attach(file)
                }
            }
            self?.finish()
        }
    }

    override func serviceExtensionTimeWillExpire() {
        work?.cancel()
        finish()
    }

    /// The system moves attachment files into its own store, so a copy is attached and the
    /// widget keeps its rendition.
    private func attach(_ file: URL) {
        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(file.pathExtension)
        do {
            try FileManager.default.copyItem(at: file, to: copy)
            let attachment = try UNNotificationAttachment(identifier: Self.attachmentIdentifier, url: copy, options: nil)
            lock.lock()
            bestAttempt?.attachments = [attachment]
            lock.unlock()
        } catch {
            try? FileManager.default.removeItem(at: copy)
        }
    }

    /// Delivers the content once, whichever of completion and expiry comes first.
    private func finish() {
        lock.lock()
        let handler = contentHandler
        let content = bestAttempt
        contentHandler = nil
        lock.unlock()
        if let handler, let content {
            handler(content)
        }
    }
}

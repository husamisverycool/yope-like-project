#if os(iOS)
import AppModels
import Foundation
@preconcurrency import UserNotifications

/// Notification Center's delivered notifications of deleted photos and messages (`NotificationWithdrawal`): removed
/// when the app learns of a deletion (Realtime, a background push, the launch / foreground check).
@MainActor
public final class DeliveredNotifications {
    private let center: UNUserNotificationCenter
    private let parser: DeepLinkParser

    public init(parser: DeepLinkParser, center: UNUserNotificationCenter = .current()) {
        self.parser = parser
        self.center = center
    }

    /// The posts the delivered notifications name.
    public func shownPostIDs() async -> Set<String> {
        NotificationWithdrawal.postIDs(of: await delivered())
    }

    /// Removes every delivered notification that names one of `posts` or `messages`.
    public func withdraw(posts: Set<String>, messages: Set<String>) async {
        guard !posts.isEmpty || !messages.isEmpty else { return }
        let identifiers = NotificationWithdrawal.identifiers(of: await delivered(), deletedPosts: posts, deletedMessages: messages)
        guard !identifiers.isEmpty else { return }
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func delivered() async -> [NotificationWithdrawal.Delivered] {
        let parser = self.parser
        return await center.deliveredNotifications().map { notification in
            NotificationWithdrawal.Delivered(
                identifier: notification.request.identifier,
                userInfo: notification.request.content.userInfo,
                parser: parser
            )
        }
    }
}
#endif

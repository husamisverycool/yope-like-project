import Foundation

/// Which delivered notifications show something that no longer exists — directive Part 6, "Deleting a photo removes it
/// everywhere": a notification names its post or chat message in its payload (`post_id`, `message_id`, or a `link`),
/// and a deleted one is withdrawn from Notification Center (`AppServices.DeliveredNotifications`; Android
/// `app.push.DeliveredAlerts`).
///
/// What is guaranteed (iOS has no way for a server to remove a delivered notification): it goes as soon as the app
/// learns of the deletion — the group's Realtime deletion broadcast while the app runs, a background push the worker
/// sends when the deletion changes the widget, and the check of every delivered notification against the server at
/// launch and on each return to the foreground.
public enum NotificationWithdrawal {
    /// One delivered notification: its request identifier and what it shows.
    public struct Delivered: Hashable, Sendable {
        public let identifier: String
        public let postIDs: Set<String>
        public let messageIDs: Set<String>

        public init(identifier: String, postIDs: Set<String>, messageIDs: Set<String>) {
            self.identifier = identifier
            self.postIDs = postIDs
            self.messageIDs = messageIDs
        }

        /// Reads the ids from an APNs `userInfo` (the `post_id` / `message_id` keys and the `link` / `type` route).
        public init(identifier: String, userInfo: [AnyHashable: Any], parser: DeepLinkParser) {
            var posts = Set<String>()
            var messages = Set<String>()
            if let post = PayloadValue.string(userInfo[DeepLinkField.post.payloadKey]), DeepLinkParser.isValidIdentifier(post) {
                posts.insert(post)
            }
            if let message = PayloadValue.string(userInfo[DeepLinkField.message.payloadKey]),
               DeepLinkParser.isValidIdentifier(message) {
                messages.insert(message)
            }
            switch parser.parse(notificationPayload: userInfo) {
            case let .post(_, postID)?: posts.insert(postID)
            case let .chatMessage(_, messageID)?: messages.insert(messageID)
            default: break
            }
            self.init(identifier: identifier, postIDs: posts, messageIDs: messages)
        }
    }

    /// The identifiers to remove: notifications naming a deleted post or message.
    public static func identifiers(of delivered: [Delivered], deletedPosts: Set<String>, deletedMessages: Set<String>) -> [String] {
        delivered
            .filter { !$0.postIDs.isDisjoint(with: deletedPosts) || !$0.messageIDs.isDisjoint(with: deletedMessages) }
            .map(\.identifier)
    }

    /// Every post the delivered notifications name (checked against the server at launch and foreground).
    public static func postIDs(of delivered: [Delivered]) -> Set<String> {
        delivered.reduce(into: Set<String>()) { $0.formUnion($1.postIDs) }
    }

    /// The posts among `shown` that the server no longer returns (deleted, or no longer visible to this person).
    public static func gone(shown: Set<String>, existing: Set<String>) -> Set<String> {
        shown.subtracting(existing)
    }
}

import Foundation

/// Actions on an alert (design/surfaces/notifications.push.md "Actions"; owner decision 34, research #9): reply from the
/// notification (Apple Messages from the Lock Screen, support.apple.com/104982; Android direct reply), the first quick
/// reaction (`chat.reactions.layout.quickReactions`) and mute the group (Retro's notification actions "Reply" and "Mute
/// This Post", design/research/retro-package-copy-motion.md §6.2, adapted to groups). Same rule as Android
/// (`android/core/push` `AlertActions`).
///
/// Only alerts about a photo or a reply carry actions: never the daily invitation (an invitation, not a task), widget
/// pushes, recaps, birthdays, plans or memories. An action only ever answers what the alert already shows, so it reveals
/// nothing across blocks (the worker sends no alert from or about a person with a block).
public enum NotificationAction: String, CaseIterable, Sendable {
    case reply
    case react
    case muteGroup = "mute_group"

    /// The `UNNotificationAction` identifier.
    public var identifier: String { Self.prefix + rawValue }

    public init?(identifier: String) {
        guard identifier.hasPrefix(Self.prefix) else { return nil }
        self.init(rawValue: String(identifier.dropFirst(Self.prefix.count)))
    }

    private static let prefix = "action."

    /// The actions an alert of `type` offers, in the order the system shows them. The category per type is registered
    /// once (`PushService.install`); the worker sets `aps.category` to the type.
    public static func actions(for type: PushType) -> [NotificationAction] {
        switch type {
        // A new photo (and the overnight reveal, also `new_post`): reply to it, react, mute.
        case .newPost: return [.reply, .react, .muteGroup]
        // A reply names a chat message or a photo; a reaction names your own photo: reply in the group, mute.
        case .reply, .reaction: return [.reply, .muteGroup]
        case .widget, .dailyInvitation, .dailyInvitationEnded, .recapReady, .birthdayRequest, .tribute, .yearStory, .plan, .memory:
            return []
        }
    }
}

/// What an alert's actions act on, read from its payload (`type`, `group_id`, `post_id`, `message_id`).
public struct NotificationActionTarget: Equatable, Sendable {
    public let type: PushType
    public let groupID: String
    public let postID: String?
    public let messageID: String?

    public init(type: PushType, groupID: String, postID: String? = nil, messageID: String? = nil) {
        self.type = type
        self.groupID = groupID
        self.postID = postID
        self.messageID = messageID
    }

    /// Nil when the payload has no known type or no readable group id. Ids must be URL-safe identifiers
    /// (`DeepLinkParser.isValidIdentifier`); an unreadable one is dropped.
    public init?(userInfo: [AnyHashable: Any]) {
        func id(_ key: String) -> String? {
            PayloadValue.string(userInfo[key]).flatMap { DeepLinkParser.isValidIdentifier($0) ? $0 : nil }
        }
        guard let typeName = PayloadValue.string(userInfo[PushKey.type]), let type = PushType(rawValue: typeName),
              let group = id(PushKey.groupID) else { return nil }
        self.init(type: type, groupID: group, postID: id(PushKey.postID), messageID: id(PushKey.messageID))
    }
}

/// One action to perform, with what it needs (docs/API.md `send_message`, `react`, `set_group_muted`).
public enum NotificationActionRequest: Equatable, Sendable {
    /// `send_message(p_group_id, 'text', p_body, p_reply_to_post_id | p_reply_to_message_id)`.
    case reply(groupID: String, body: String, replyToPostID: String?, replyToMessageID: String?)
    /// `react(p_post_id, p_emoji)`.
    case react(postID: String, emoji: String)
    /// `set_group_muted(p_group_id, true)`.
    case muteGroup(groupID: String)

    /// Nil when the alert does not offer `action` (`NotificationAction.actions(for:)`) or it lacks what the action needs:
    /// a reply needs text (trimmed, not blank) and a message or photo to answer (the message wins: a text reply alert
    /// names the message); a reaction needs the photo and an emoji.
    public static func make(
        _ action: NotificationAction,
        target: NotificationActionTarget,
        text: String? = nil,
        reaction: String? = nil
    ) -> NotificationActionRequest? {
        guard NotificationAction.actions(for: target.type).contains(action) else { return nil }
        switch action {
        case .reply:
            guard let body = text?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty else { return nil }
            if let message = target.messageID {
                return .reply(groupID: target.groupID, body: body, replyToPostID: nil, replyToMessageID: message)
            }
            guard let post = target.postID else { return nil }
            return .reply(groupID: target.groupID, body: body, replyToPostID: post, replyToMessageID: nil)
        case .react:
            guard let post = target.postID, let emoji = reaction, !emoji.isEmpty else { return nil }
            return .react(postID: post, emoji: emoji)
        case .muteGroup:
            return .muteGroup(groupID: target.groupID)
        }
    }
}

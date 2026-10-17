import Foundation

/// Top-level keys of the app's push payloads (next to `aps`). Same names and values as the
/// Android FCM data contract (`android/core/model/.../PushMessage.kt`, `PushKeys`/`PushTypes`),
/// so the worker's push sender uses one vocabulary; docs/API.md is the reference once written.
public enum PushKey {
    public static let type = "type"
    /// Optional full deep link (`app://…` or invite URL); takes precedence over `type` + ids.
    public static let link = "link"
    public static let groupID = "group_id"
    public static let groupName = "group_name"
    public static let postID = "post_id"
    public static let collageID = "collage_id"
    public static let messageID = "message_id"
    public static let invitationID = "invitation_id"
    public static let recapID = "recap_id"
    public static let requestID = "request_id"
    public static let tributeID = "tribute_id"
    public static let year = "year"
    public static let planID = "plan_id"
    public static let revealedAt = "revealed_at"
    public static let kind = "kind"
    public static let renditionURL = "rendition_url"
    /// The poster of a photo: a friend widget for them takes the photo too (docs/WIDGET_REFRESH.md).
    public static let senderID = "sender_id"
    public static let senderName = "sender_name"
    public static let senderAvatarURL = "sender_avatar_url"
    /// iOS alert pushes may carry the widget fields as one object under this key instead of flat.
    public static let widget = "widget"
    public static let caption = "caption"
    public static let postedAt = "posted_at"
    public static let closesAt = "closes_at"
}

/// Values of `type`.
public enum PushType: String, CaseIterable, Sendable {
    case widget
    case dailyInvitation = "daily_invitation"
    case dailyInvitationEnded = "daily_invitation_ended"
    case newPost = "new_post"
    case reaction
    case reply
    case recapReady = "recap_ready"
    case birthdayRequest = "birthday_request"
    case tribute
    case yearStory = "year_story"
    case plan
    /// The opt-in memory notification (docs/API.md §5.21, migration 0049): `post_id` of the memory's photo; opens it.
    case memory
}

/// Reads loosely typed payload values (APNs JSON gives strings and numbers).
enum PayloadValue {
    static func string(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let int as Int:
            return String(int)
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    /// Unix seconds, Unix milliseconds (values above 10^11, i.e. past the year 5138 as seconds),
    /// numeric strings of either, or ISO 8601 with or without fractional seconds.
    static func date(_ value: Any?) -> Date? {
        let seconds: Double?
        switch value {
        case let number as Double: seconds = number
        case let number as Int: seconds = Double(number)
        case let number as NSNumber: seconds = number.doubleValue
        case let text as String:
            if let number = Double(text) {
                seconds = number
            } else {
                return iso8601(text)
            }
        default:
            return nil
        }
        guard let seconds, seconds.isFinite else { return nil }
        return Date(timeIntervalSince1970: seconds > 100_000_000_000 ? seconds / 1000 : seconds)
    }

    static func iso8601(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
}

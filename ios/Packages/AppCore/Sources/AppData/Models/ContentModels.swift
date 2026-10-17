import Foundation

/// `media` (docs/API.md §5.7): one captured photo / Live Photo / video, posted to one or more groups.
public struct Media: Codable, Hashable, Sendable, Identifiable {
    public var id: MediaID
    public var ownerID: UserID
    public var kind: MediaKind
    /// Back camera / only image, or the video file.
    public var originalPath: String
    /// Front image of a dual capture.
    public var frontOriginalPath: String?
    /// Live Photo video (required for `live_photo`).
    public var motionPath: String?
    public var displayPath: String?
    public var thumbPath: String?
    public var widgetPath: String?
    public var frontDisplayPath: String?
    public var frontThumbPath: String?
    public var width: Int?
    public var height: Int?
    public var frontWidth: Int?
    public var frontHeight: Int?
    /// Required for `video`; Live Photo motion length.
    public var durationMs: Int?
    /// Nil until the worker wrote the renditions; show `originalPath` until then.
    public var renditionsReadyAt: Date?
    public var createdAt: Date

    public init(
        id: MediaID, ownerID: UserID, kind: MediaKind, originalPath: String, frontOriginalPath: String? = nil,
        motionPath: String? = nil, displayPath: String? = nil, thumbPath: String? = nil, widgetPath: String? = nil,
        frontDisplayPath: String? = nil, frontThumbPath: String? = nil, width: Int? = nil, height: Int? = nil,
        frontWidth: Int? = nil, frontHeight: Int? = nil, durationMs: Int? = nil, renditionsReadyAt: Date? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.ownerID = ownerID
        self.kind = kind
        self.originalPath = originalPath
        self.frontOriginalPath = frontOriginalPath
        self.motionPath = motionPath
        self.displayPath = displayPath
        self.thumbPath = thumbPath
        self.widgetPath = widgetPath
        self.frontDisplayPath = frontDisplayPath
        self.frontThumbPath = frontThumbPath
        self.width = width
        self.height = height
        self.frontWidth = frontWidth
        self.frontHeight = frontHeight
        self.durationMs = durationMs
        self.renditionsReadyAt = renditionsReadyAt
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case kind
        case originalPath = "original_path"
        case frontOriginalPath = "front_original_path"
        case motionPath = "motion_path"
        case displayPath = "display_path"
        case thumbPath = "thumb_path"
        case widgetPath = "widget_path"
        case frontDisplayPath = "front_display_path"
        case frontThumbPath = "front_thumb_path"
        case width, height
        case frontWidth = "front_width"
        case frontHeight = "front_height"
        case durationMs = "duration_ms"
        case renditionsReadyAt = "renditions_ready_at"
        case createdAt = "created_at"
    }

    /// Which rendition a surface shows (docs/API.md §7 "Which image to show").
    public enum Rendition: Sendable {
        case display, thumb, widget
    }

    /// The storage path of the main image for `rendition`: the rendition once
    /// `renditions_ready_at` is set, the original until then. For a video this is the poster
    /// rendition (nil until the worker made it, since the original is the video file).
    public func imagePath(for rendition: Rendition) -> String? {
        // A video's poster renditions are written before its transcode finishes (renditions_ready_at): used at once.
        if renditionsReadyAt != nil || kind == .video {
            switch rendition {
            case .display: if let displayPath { return displayPath }
            case .thumb: if let thumbPath { return thumbPath }
            case .widget: if let widgetPath { return widgetPath }
            }
        }
        return kind == .video ? nil : originalPath
    }

    /// The front image of a dual capture for `rendition` (widgets use the main image only).
    public func frontImagePath(for rendition: Rendition) -> String? {
        guard let frontOriginalPath else { return nil }
        if renditionsReadyAt != nil {
            switch rendition {
            case .display: if let frontDisplayPath { return frontDisplayPath }
            case .thumb, .widget: if let frontThumbPath { return frontThumbPath }
            }
        }
        return frontOriginalPath
    }
}

/// `posts` (§5.8): one row per group a photo was sent to.
public struct Post: Codable, Hashable, Sendable, Identifiable {
    public var id: PostID
    public var mediaID: MediaID
    public var groupID: GroupID
    /// = the media owner.
    public var authorID: UserID
    public var caption: String?
    public var voicePath: String?
    public var voiceDurationMs: Int?
    /// The voice note's waveform: 100 levels of 0…31 (§5.8 `voice_levels`); nil for notes without one.
    public var voiceLevels: [Int]?
    /// Set only when posted inside that group's open daily invitation.
    public var invitationID: InvitationID?
    /// True only for posts made during an open invitation. There is no "late" state.
    public var inWindow: Bool
    /// A photo replying to a photo; nil if the original was deleted.
    public var replyToPostID: PostID?
    /// When taken (an overnight photo keeps it; the day it was taken shows in the viewer and On This Day).
    public var createdAt: Date
    /// When an overnight photo developed and joined the group (`revealed_at`, docs/API.md §14.3); nil for a post shared
    /// at once. Photos revealed together share it.
    public var revealedAt: Date?

    /// When the group could first see the photo (`posts.visible_at` = `revealed_at ?? created_at`, migration 0027): the
    /// week and the week-strip day a photo belongs to. An overnight photo taken on Sunday night is in Monday's week.
    public var visibleAt: Date { revealedAt ?? createdAt }

    public init(
        id: PostID, mediaID: MediaID, groupID: GroupID, authorID: UserID, caption: String? = nil,
        voicePath: String? = nil, voiceDurationMs: Int? = nil, voiceLevels: [Int]? = nil, invitationID: InvitationID? = nil,
        inWindow: Bool = false, replyToPostID: PostID? = nil, createdAt: Date, revealedAt: Date? = nil
    ) {
        self.id = id
        self.mediaID = mediaID
        self.groupID = groupID
        self.authorID = authorID
        self.caption = caption
        self.voicePath = voicePath
        self.voiceDurationMs = voiceDurationMs
        self.voiceLevels = voiceLevels
        self.invitationID = invitationID
        self.inWindow = inWindow
        self.replyToPostID = replyToPostID
        self.createdAt = createdAt
        self.revealedAt = revealedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case mediaID = "media_id"
        case groupID = "group_id"
        case authorID = "author_id"
        case caption
        case voicePath = "voice_path"
        case voiceDurationMs = "voice_duration_ms"
        case voiceLevels = "voice_levels"
        case invitationID = "invitation_id"
        case inWindow = "in_window"
        case replyToPostID = "reply_to_post_id"
        case createdAt = "created_at"
        case revealedAt = "revealed_at"
    }
}

/// A post with its media (feed cells, the photo viewer).
public struct PostWithMedia: Codable, Hashable, Sendable, Identifiable {
    public var post: Post
    /// Nil if the media row is not readable (it always is for a visible post).
    public var media: Media?

    public var id: PostID { post.id }

    public init(post: Post, media: Media?) {
        self.post = post
        self.media = media
    }
}

/// `messages` (§5.9): group chat.
public struct Message: Codable, Hashable, Sendable, Identifiable {
    public var id: MessageID
    public var groupID: GroupID
    public var authorID: UserID
    public var kind: MessageKind
    /// `text` only, ≤ 4000 characters.
    public var body: String?
    /// `photo` messages: load the post (and its media) by id; caption and voice note come from the post.
    public var postID: PostID?
    public var voicePath: String?
    public var voiceDurationMs: Int?
    /// A voice message's waveform: 100 levels of 0…31 (§5.9 `voice_levels`); nil when it has none.
    public var voiceLevels: [Int]?
    /// Reply to a specific photo; nil when that photo is deleted (the reply stays).
    public var replyToPostID: PostID?
    /// Reply to a message; nil if it was deleted.
    public var replyToMessageID: MessageID?
    public var createdAt: Date
    /// When the author last edited the text (`edit_message`, migration 0047): "Edited" shows under it; nil when never
    /// edited.
    public var editedAt: Date?

    public init(
        id: MessageID, groupID: GroupID, authorID: UserID, kind: MessageKind, body: String? = nil,
        postID: PostID? = nil, voicePath: String? = nil, voiceDurationMs: Int? = nil, voiceLevels: [Int]? = nil,
        replyToPostID: PostID? = nil, replyToMessageID: MessageID? = nil, createdAt: Date, editedAt: Date? = nil
    ) {
        self.id = id
        self.groupID = groupID
        self.authorID = authorID
        self.kind = kind
        self.body = body
        self.postID = postID
        self.voicePath = voicePath
        self.voiceDurationMs = voiceDurationMs
        self.voiceLevels = voiceLevels
        self.replyToPostID = replyToPostID
        self.replyToMessageID = replyToMessageID
        self.createdAt = createdAt
        self.editedAt = editedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case authorID = "author_id"
        case kind, body
        case postID = "post_id"
        case voicePath = "voice_path"
        case voiceDurationMs = "voice_duration_ms"
        case voiceLevels = "voice_levels"
        case replyToPostID = "reply_to_post_id"
        case replyToMessageID = "reply_to_message_id"
        case createdAt = "created_at"
        case editedAt = "edited_at"
    }
}

/// `reactions` (§5.10): rows only — who reacted with what. There is deliberately no count
/// anywhere in this module (tenet: no counts).
public struct Reaction: Codable, Hashable, Sendable {
    public var postID: PostID
    public var userID: UserID
    public var emoji: String
    public var groupID: GroupID
    public var createdAt: Date

    public init(postID: PostID, userID: UserID, emoji: String, groupID: GroupID, createdAt: Date) {
        self.postID = postID
        self.userID = userID
        self.emoji = emoji
        self.groupID = groupID
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case userID = "user_id"
        case emoji
        case groupID = "group_id"
        case createdAt = "created_at"
    }
}

/// `message_reactions` (§5.10a, migration 0047): one reaction per person per text or voice message — rows only, never a
/// count (tenet: no counts).
public struct MessageReaction: Codable, Hashable, Sendable {
    public var messageID: MessageID
    public var userID: UserID
    public var emoji: String
    public var groupID: GroupID
    /// When the current emoji was set.
    public var createdAt: Date

    public init(messageID: MessageID, userID: UserID, emoji: String, groupID: GroupID, createdAt: Date) {
        self.messageID = messageID
        self.userID = userID
        self.emoji = emoji
        self.groupID = groupID
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case userID = "user_id"
        case emoji
        case groupID = "group_id"
        case createdAt = "created_at"
    }
}

/// `chat_typing` (§5.10b, migration 0048): the person is typing while `until` is in the future. Never a number of people.
public struct ChatTyping: Codable, Hashable, Sendable {
    public var groupID: GroupID
    public var userID: UserID
    public var until: Date

    public init(groupID: GroupID, userID: UserID, until: Date) {
        self.groupID = groupID
        self.userID = userID
        self.until = until
    }

    enum CodingKeys: String, CodingKey {
        case groupID = "group_id"
        case userID = "user_id"
        case until
    }
}

/// `post_tags` (§5.11): "I'm in this" self-tags.
public struct PostTag: Codable, Hashable, Sendable {
    public var postID: PostID
    public var userID: UserID
    public var groupID: GroupID
    public var createdAt: Date

    public init(postID: PostID, userID: UserID, groupID: GroupID, createdAt: Date) {
        self.postID = postID
        self.userID = userID
        self.groupID = groupID
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case userID = "user_id"
        case groupID = "group_id"
        case createdAt = "created_at"
    }
}

import AppModels
import Foundation
import Supabase

/// A person the friend widget's picker lists (`widget_people`).
public struct WidgetPersonRow: Codable, Hashable, Sendable {
    public var userID: UserID
    public var displayName: String
    public var avatarPath: String?

    public init(userID: UserID, displayName: String, avatarPath: String? = nil) {
        self.userID = userID
        self.displayName = displayName
        self.avatarPath = avatarPath
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "display_name"
        case avatarPath = "avatar_path"
    }
}

/// One of a person's newest photos the caller can see (`newest_photos_of`): posted by them (`via` "author") or one they
/// tagged themselves in (`via` "tag").
public struct PersonPhoto: Codable, Hashable, Sendable {
    public var postID: PostID
    public var mediaID: MediaID
    public var groupID: GroupID
    public var groupName: String
    public var authorID: UserID
    public var authorName: String
    public var authorAvatarPath: String?
    public var widgetPath: String?
    public var caption: String?
    public var visibleAt: Date
    public var via: String

    public init(
        postID: PostID, mediaID: MediaID, groupID: GroupID, groupName: String, authorID: UserID, authorName: String,
        authorAvatarPath: String? = nil, widgetPath: String?, caption: String? = nil, visibleAt: Date, via: String
    ) {
        self.postID = postID
        self.mediaID = mediaID
        self.groupID = groupID
        self.groupName = groupName
        self.authorID = authorID
        self.authorName = authorName
        self.authorAvatarPath = authorAvatarPath
        self.widgetPath = widgetPath
        self.caption = caption
        self.visibleAt = visibleAt
        self.via = via
    }

    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case mediaID = "media_id"
        case groupID = "group_id"
        case groupName = "group_name"
        case authorID = "author_id"
        case authorName = "author_name"
        case authorAvatarPath = "author_avatar_path"
        case widgetPath = "widget_path"
        case caption
        case visibleAt = "visible_at"
        case via
    }
}

/// The person's own memory for one day (`my_memories`).
public struct DayMemory: Codable, Hashable, Sendable {
    public var day: LocalDate
    public var postID: PostID
    public var mediaID: MediaID
    public var groupID: GroupID
    public var groupName: String
    public var authorID: UserID
    public var authorName: String
    public var widgetPath: String?
    public var takenAt: Date
    public var yearsAgo: Int

    public init(
        day: LocalDate, postID: PostID, mediaID: MediaID, groupID: GroupID, groupName: String, authorID: UserID,
        authorName: String, widgetPath: String?, takenAt: Date, yearsAgo: Int
    ) {
        self.day = day
        self.postID = postID
        self.mediaID = mediaID
        self.groupID = groupID
        self.groupName = groupName
        self.authorID = authorID
        self.authorName = authorName
        self.widgetPath = widgetPath
        self.takenAt = takenAt
        self.yearsAgo = yearsAgo
    }

    enum CodingKeys: String, CodingKey {
        case day
        case postID = "post_id"
        case mediaID = "media_id"
        case groupID = "group_id"
        case groupName = "group_name"
        case authorID = "author_id"
        case authorName = "author_name"
        case widgetPath = "widget_path"
        case takenAt = "taken_at"
        case yearsAgo = "years_ago"
    }
}

/// The friend and memories widgets' server functions (migration 0036, docs/API.md §6.4).
public struct WidgetRepository: Sendable {
    let client: DataClient

    public init(client: DataClient) {
        self.client = client
    }

    /// Everyone who shares a group with the caller, minus blocks, by display name.
    public func people() async throws -> [WidgetPersonRow] {
        try await client.rpc("widget_people")
    }

    /// The person's newest photos the caller may see, newest first (1–10).
    public func newestPhotos(of userID: UserID, limit: Int = 3) async throws -> [PersonPhoto] {
        try await client.rpc("newest_photos_of", ["p_user_id": .id(userID), "p_limit": .int(limit)])
    }

    /// The caller's own memory per day from `from` for `days` days (1–14), in the device's `timeZone`.
    public func memories(from: LocalDate, days: Int, timeZone: TimeZone) async throws -> [DayMemory] {
        try await client.rpc("my_memories", ["p_from": .date(from), "p_days": .int(days), "p_time_zone": .text(timeZone.identifier)])
    }
}

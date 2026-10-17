import Foundation

/// `daily_invitations` (docs/API.md §5.12): visible to members only after `fires_at`.
public struct DailyInvitation: Codable, Hashable, Sendable, Identifiable {
    public var id: InvitationID
    public var groupID: GroupID
    /// The group-local day.
    public var localDate: LocalDate
    /// The same instant for every member.
    public var firesAt: Date
    /// `fires_at + invitation_window_seconds`.
    public var closesAt: Date
    public var status: InvitationStatus
    public var createdAt: Date

    public init(id: InvitationID, groupID: GroupID, localDate: LocalDate, firesAt: Date, closesAt: Date, status: InvitationStatus, createdAt: Date) {
        self.id = id
        self.groupID = groupID
        self.localDate = localDate
        self.firesAt = firesAt
        self.closesAt = closesAt
        self.status = status
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case localDate = "local_date"
        case firesAt = "fires_at"
        case closesAt = "closes_at"
        case status
        case createdAt = "created_at"
    }

    /// Whether the window is open at `date` (UI state comes from the timestamps, not `status`).
    public func isOpen(at date: Date = Date()) -> Bool {
        date >= firesAt && date <= closesAt
    }
}

/// `collages` (§5.13): show only when `status == .ready`.
public struct Collage: Codable, Hashable, Sendable, Identifiable {
    public var id: CollageID
    public var groupID: GroupID
    public var invitationID: InvitationID?
    public var option: String
    public var postIDs: [PostID]
    /// Number of composed pages (≥ 1; layout metadata used to build file paths, never shown).
    public var pageCount: Int
    /// Page 1 (`…/<version>/display-1.jpg`).
    public var imagePath: String?
    public var widgetPath: String?
    /// The 9:16 share image of page 1 (option B only).
    public var sharePath: String?
    public var status: RenderStatus
    public var composedAt: Date?
    public var createdAt: Date

    public init(
        id: CollageID, groupID: GroupID, invitationID: InvitationID?, option: String, postIDs: [PostID], pageCount: Int = 1,
        imagePath: String?, widgetPath: String?, sharePath: String?, status: RenderStatus, composedAt: Date?, createdAt: Date
    ) {
        self.id = id
        self.groupID = groupID
        self.invitationID = invitationID
        self.option = option
        self.postIDs = postIDs
        self.pageCount = pageCount
        self.imagePath = imagePath
        self.widgetPath = widgetPath
        self.sharePath = sharePath
        self.status = status
        self.composedAt = composedAt
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case invitationID = "invitation_id"
        case option
        case postIDs = "post_ids"
        case pageCount = "page_count"
        case imagePath = "image_path"
        case widgetPath = "widget_path"
        case sharePath = "share_path"
        case status
        case composedAt = "composed_at"
        case createdAt = "created_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(CollageID.self, forKey: .id)
        groupID = try container.decode(GroupID.self, forKey: .groupID)
        invitationID = try container.decodeIfPresent(InvitationID.self, forKey: .invitationID)
        option = try container.decode(String.self, forKey: .option)
        postIDs = try container.decode([PostID].self, forKey: .postIDs)
        // Migration 0015; rows read from an older server or cache have one page.
        pageCount = try container.decodeIfPresent(Int.self, forKey: .pageCount) ?? 1
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
        widgetPath = try container.decodeIfPresent(String.self, forKey: .widgetPath)
        sharePath = try container.decodeIfPresent(String.self, forKey: .sharePath)
        status = try container.decode(RenderStatus.self, forKey: .status)
        composedAt = try container.decodeIfPresent(Date.self, forKey: .composedAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    public var isReady: Bool { status == .ready && imagePath != nil }

    /// Page `page` (1-based) of the composed collage: `display-<n>.jpg` next to `imagePath`.
    public func imagePath(page: Int) -> String? {
        pagePath(imagePath, prefix: "display", page: page)
    }

    /// The 9:16 share image of page `page` (option B only).
    public func sharePath(page: Int) -> String? {
        pagePath(sharePath, prefix: "share", page: page)
    }

    private func pagePath(_ first: String?, prefix: String, page: Int) -> String? {
        guard let first, page >= 1, page <= pageCount else { return nil }
        let suffix = "/\(prefix)-1.jpg"
        guard first.hasSuffix(suffix) else { return page == 1 ? first : nil }
        return String(first.dropLast(suffix.count)) + "/\(prefix)-\(page).jpg"
    }
}

/// `weekly_recaps` (§5.14).
public struct WeeklyRecap: Codable, Hashable, Sendable, Identifiable {
    public var id: RecapID
    public var groupID: GroupID
    /// Group-local first day of the week.
    public var weekStart: LocalDate
    /// Ordered post ids; fetch them from `posts` (RLS drops any the caller cannot see).
    public var items: [PostID]
    /// The week's same-moment collages, in order (`collage_ids`, migration 0033); empty for recaps made before.
    public var collageIDs: [CollageID] = []
    public var text: String?
    /// Editable only when `.ready`.
    public var status: RenderStatus
    public var generatedAt: Date?
    public var editedBy: UserID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: RecapID, groupID: GroupID, weekStart: LocalDate, items: [PostID], text: String?, status: RenderStatus,
        generatedAt: Date?, editedBy: UserID?, createdAt: Date, updatedAt: Date
    ) {
        self.id = id
        self.groupID = groupID
        self.weekStart = weekStart
        self.items = items
        self.text = text
        self.status = status
        self.generatedAt = generatedAt
        self.editedBy = editedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case weekStart = "week_start"
        case items, text, status
        case collageIDs = "collage_ids"
        case generatedAt = "generated_at"
        case editedBy = "edited_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(RecapID.self, forKey: .id)
        groupID = try c.decode(GroupID.self, forKey: .groupID)
        weekStart = try c.decode(LocalDate.self, forKey: .weekStart)
        items = try c.decode([PostID].self, forKey: .items)
        collageIDs = try c.decodeIfPresent([CollageID].self, forKey: .collageIDs) ?? []
        text = try c.decodeIfPresent(String.self, forKey: .text)
        status = try c.decode(RenderStatus.self, forKey: .status)
        generatedAt = try c.decodeIfPresent(Date.self, forKey: .generatedAt)
        editedBy = try c.decodeIfPresent(UserID.self, forKey: .editedBy)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }
}

/// A ready same-moment collage placed on its group-local day (`group_collages`, `group_history_weeks.collages`,
/// migration 0033): the group's photo of the day in its history.
public struct GroupCollage: Codable, Hashable, Sendable, Identifiable {
    public var collageID: CollageID
    public var invitationID: InvitationID
    /// The invitation's group-local day: the day tile it belongs on.
    public var localDate: LocalDate
    /// Page 1 (`display-1.jpg`).
    public var imagePath: String?
    /// The widget image (smaller; for day tiles).
    public var widgetPath: String?
    public var sharePath: String?
    public var pageCount: Int?
    public var composedAt: Date?

    public var id: CollageID { collageID }

    public init(
        collageID: CollageID, invitationID: InvitationID, localDate: LocalDate, imagePath: String?, widgetPath: String?,
        sharePath: String? = nil, pageCount: Int? = nil, composedAt: Date? = nil
    ) {
        self.collageID = collageID
        self.invitationID = invitationID
        self.localDate = localDate
        self.imagePath = imagePath
        self.widgetPath = widgetPath
        self.sharePath = sharePath
        self.pageCount = pageCount
        self.composedAt = composedAt
    }

    enum CodingKeys: String, CodingKey {
        case collageID = "collage_id"
        case invitationID = "invitation_id"
        case localDate = "local_date"
        case imagePath = "image_path"
        case widgetPath = "widget_path"
        case sharePath = "share_path"
        case pageCount = "page_count"
        case composedAt = "composed_at"
    }

    /// The tile image: the widget rendition, else page 1.
    public var tilePath: String? { widgetPath ?? imagePath }
}

/// `albums` (§5.15).
public struct Album: Codable, Hashable, Sendable, Identifiable {
    public var id: AlbumID
    public var groupID: GroupID
    public var name: String
    public var createdBy: UserID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: AlbumID, groupID: GroupID, name: String, createdBy: UserID?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.groupID = groupID
        self.name = name
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case name
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// `album_items` (§5.15).
public struct AlbumItem: Codable, Hashable, Sendable {
    public var albumID: AlbumID
    public var postID: PostID
    /// 0-based order.
    public var position: Int

    public init(albumID: AlbumID, postID: PostID, position: Int) {
        self.albumID = albumID
        self.postID = postID
        self.position = position
    }

    enum CodingKeys: String, CodingKey {
        case albumID = "album_id"
        case postID = "post_id"
        case position
    }
}

/// An album with its visible items in order.
public struct AlbumWithItems: Codable, Hashable, Sendable, Identifiable {
    public var album: Album
    public var postIDs: [PostID]

    public var id: AlbumID { album.id }

    public init(album: Album, postIDs: [PostID]) {
        self.album = album
        self.postIDs = postIDs
    }
}

/// `tribute_requests` (§5.16): visible to members except the honoree.
public struct TributeRequest: Codable, Hashable, Sendable, Identifiable {
    public var id: TributeRequestID
    public var groupID: GroupID
    public var honoreeID: UserID
    /// The birthday being celebrated (group-local).
    public var birthdayDate: LocalDate
    /// 00:00 group-local on that date; contributions close.
    public var dueAt: Date
    public var closedAt: Date?
    public var createdAt: Date

    public init(id: TributeRequestID, groupID: GroupID, honoreeID: UserID, birthdayDate: LocalDate, dueAt: Date, closedAt: Date?, createdAt: Date) {
        self.id = id
        self.groupID = groupID
        self.honoreeID = honoreeID
        self.birthdayDate = birthdayDate
        self.dueAt = dueAt
        self.closedAt = closedAt
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case honoreeID = "honoree_id"
        case birthdayDate = "birthday_date"
        case dueAt = "due_at"
        case closedAt = "closed_at"
        case createdAt = "created_at"
    }

    public func isOpen(at date: Date = Date()) -> Bool { closedAt == nil && dueAt > date }
}

/// `tribute_contributions` (§5.17): the caller's own contribution only.
public struct TributeContribution: Codable, Hashable, Sendable, Identifiable {
    public var id: TributeContributionID
    public var requestID: TributeRequestID
    public var contributorID: UserID
    public var postID: PostID
    /// 1–280 characters.
    public var line: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: TributeContributionID, requestID: TributeRequestID, contributorID: UserID, postID: PostID, line: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.requestID = requestID
        self.contributorID = contributorID
        self.postID = postID
        self.line = line
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case requestID = "request_id"
        case contributorID = "contributor_id"
        case postID = "post_id"
        case line
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// `tributes` (§5.18): the rendered tribute video. The honoree reads it only once delivered.
public struct Tribute: Codable, Hashable, Sendable, Identifiable {
    public var id: TributeID
    public var requestID: TributeRequestID
    public var groupID: GroupID
    public var honoreeID: UserID
    public var videoPath: String?
    public var posterPath: String?
    public var status: RenderStatus
    public var renderedAt: Date?
    public var deliveredAt: Date?
    public var createdAt: Date

    public init(
        id: TributeID, requestID: TributeRequestID, groupID: GroupID, honoreeID: UserID, videoPath: String?,
        posterPath: String?, status: RenderStatus, renderedAt: Date?, deliveredAt: Date?, createdAt: Date
    ) {
        self.id = id
        self.requestID = requestID
        self.groupID = groupID
        self.honoreeID = honoreeID
        self.videoPath = videoPath
        self.posterPath = posterPath
        self.status = status
        self.renderedAt = renderedAt
        self.deliveredAt = deliveredAt
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case requestID = "request_id"
        case groupID = "group_id"
        case honoreeID = "honoree_id"
        case videoPath = "video_path"
        case posterPath = "poster_path"
        case status
        case renderedAt = "rendered_at"
        case deliveredAt = "delivered_at"
        case createdAt = "created_at"
    }
}

/// `year_stories` (§5.19).
public struct YearStory: Codable, Hashable, Sendable, Identifiable {
    public var id: YearStoryID
    public var groupID: GroupID
    public var year: Int
    public var status: RenderStatus
    /// The tap-through pages; format owned by the worker; nil while computing.
    public var data: JSONValue?
    public var postIDs: [PostID]
    /// Share cards etc. under `g/<group_id>/year/<year>/…`.
    public var assetPaths: [String]
    public var generatedAt: Date?
    public var createdAt: Date

    public init(
        id: YearStoryID, groupID: GroupID, year: Int, status: RenderStatus, data: JSONValue?, postIDs: [PostID],
        assetPaths: [String], generatedAt: Date?, createdAt: Date
    ) {
        self.id = id
        self.groupID = groupID
        self.year = year
        self.status = status
        self.data = data
        self.postIDs = postIDs
        self.assetPaths = assetPaths
        self.generatedAt = generatedAt
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case year, status, data
        case postIDs = "post_ids"
        case assetPaths = "asset_paths"
        case generatedAt = "generated_at"
        case createdAt = "created_at"
    }
}

/// A row of `wall` (§6.4).
public struct WallItem: Codable, Hashable, Sendable {
    public enum Kind: String, LenientEnum {
        case post, collage
        case unknown
        public static var unknownCase: Kind { .unknown }
    }

    public var itemKind: Kind
    /// `post`: first post of that photo in the groups the caller shares with the person.
    public var postID: PostID?
    public var mediaID: MediaID?
    public var collageID: CollageID?
    /// Shared groups it appears in.
    public var groupIDs: [GroupID]
    public var createdAt: Date

    public init(itemKind: Kind, postID: PostID?, mediaID: MediaID?, collageID: CollageID?, groupIDs: [GroupID], createdAt: Date) {
        self.itemKind = itemKind
        self.postID = postID
        self.mediaID = mediaID
        self.collageID = collageID
        self.groupIDs = groupIDs
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case itemKind = "item_kind"
        case postID = "post_id"
        case mediaID = "media_id"
        case collageID = "collage_id"
        case groupIDs = "group_ids"
        case createdAt = "created_at"
    }
}

/// A row of `group_history_weeks` (§6.4).
public struct HistoryWeek: Codable, Hashable, Sendable {
    public var weekStart: LocalDate
    /// Chronological.
    public var postIDs: [PostID]
    /// The week's same-moment collages, oldest first (migration 0033).
    public var collages: [GroupCollage]

    public init(weekStart: LocalDate, postIDs: [PostID], collages: [GroupCollage] = []) {
        self.weekStart = weekStart
        self.postIDs = postIDs
        self.collages = collages
    }

    enum CodingKeys: String, CodingKey {
        case weekStart = "week_start"
        case postIDs = "post_ids"
        case collages
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weekStart = try c.decode(LocalDate.self, forKey: .weekStart)
        postIDs = try c.decodeIfPresent([PostID].self, forKey: .postIDs) ?? []
        collages = try c.decodeIfPresent([GroupCollage].self, forKey: .collages) ?? []
    }
}

/// A row of `on_this_day` (§6.4).
public struct OnThisDayItem: Codable, Hashable, Sendable {
    public var postID: PostID
    public var mediaID: MediaID
    public var authorID: UserID
    public var createdAt: Date
    public var yearsAgo: Int

    public init(postID: PostID, mediaID: MediaID, authorID: UserID, createdAt: Date, yearsAgo: Int) {
        self.postID = postID
        self.mediaID = mediaID
        self.authorID = authorID
        self.createdAt = createdAt
        self.yearsAgo = yearsAgo
    }

    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case mediaID = "media_id"
        case authorID = "author_id"
        case createdAt = "created_at"
        case yearsAgo = "years_ago"
    }
}

import Foundation
import Supabase

/// The `media` row the client inserts before `create_post` (docs/API.md §5.0, recipe 9.4).
public struct NewMedia: Codable, Hashable, Sendable {
    public var id: MediaID
    public var kind: MediaKind
    public var originalPath: String
    public var frontOriginalPath: String?
    public var motionPath: String?
    public var width: Int?
    public var height: Int?
    public var frontWidth: Int?
    public var frontHeight: Int?
    /// Required for video; the Live Photo motion length.
    public var durationMs: Int?

    public init(
        id: MediaID, kind: MediaKind, originalPath: String, frontOriginalPath: String? = nil, motionPath: String? = nil,
        width: Int? = nil, height: Int? = nil, frontWidth: Int? = nil, frontHeight: Int? = nil, durationMs: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.originalPath = originalPath
        self.frontOriginalPath = frontOriginalPath
        self.motionPath = motionPath
        self.width = width
        self.height = height
        self.frontWidth = frontWidth
        self.frontHeight = frontHeight
        self.durationMs = durationMs
    }

    var row: JSONObject {
        [
            "id": .id(id),
            "kind": .string(kind.rawValue),
            "original_path": .string(originalPath),
            "front_original_path": .text(frontOriginalPath),
            "motion_path": .text(motionPath),
            "width": .int(width),
            "height": .int(height),
            "front_width": .int(frontWidth),
            "front_height": .int(frontHeight),
            "duration_ms": .int(durationMs),
        ]
    }
}

/// Posts and media (docs/API.md §5.7, §5.8, §6.2). Uploading and the full posting recipe are
/// in `PostPublisher`; this is the database side.
public struct PostRepository: Sendable {
    public static let pageSize = 30

    public let client: DataClient
    private let cache: OfflineCache?

    public init(client: DataClient, cache: OfflineCache? = nil) {
        self.client = client
        self.cache = cache
    }

    // MARK: Feed

    /// A group's posts, newest first (§5.8). Pass the previous page's `nextCursor` as `before`.
    public func page(groupID: GroupID, before: Date? = nil, limit: Int = PostRepository.pageSize) async throws -> Page<Post> {
        let posts = try await client.rows(Post.self) {
            var query = client.supabase.from("posts").select().eq("group_id", value: groupID.rawValue)
            if let before { query = query.lt("created_at", value: Timestamp.format(before)) }
            return query.order("created_at", ascending: false).limit(limit)
        }
        return Page(items: posts, nextCursor: posts.count == limit ? posts.last?.createdAt : nil)
    }

    /// `page` with each post's media. The first page is cached for offline display.
    public func feed(groupID: GroupID, before: Date? = nil, limit: Int = PostRepository.pageSize) async throws -> Page<PostWithMedia> {
        let page = try await page(groupID: groupID, before: before, limit: limit)
        let items = try await withMedia(page.items)
        if before == nil { await cache?.write(items, for: .feed(groupID)) }
        return Page(items: items, nextCursor: page.nextCursor)
    }

    public func cachedFeed(groupID: GroupID) async -> CachedValue<[PostWithMedia]>? {
        await cache?.read([PostWithMedia].self, for: .feed(groupID))
    }

    /// Visible posts among `ids`, in the order of `ids` (recap items, album items, history weeks).
    public func posts(ids: [PostID]) async throws -> [Post] {
        let unique = Array(Set(ids))
        guard !unique.isEmpty else { return [] }
        var found: [Post] = []
        for chunk in unique.chunked(into: 100) {
            found += try await client.rows(Post.self) {
                client.supabase.from("posts").select().in("id", values: chunk.map(\.rawValue))
            }
        }
        let byID = Dictionary(found.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    public func post(id: PostID) async throws -> Post? {
        try await client.firstRow(Post.self) {
            client.supabase.from("posts").select().eq("id", value: id.rawValue).limit(1)
        }
    }

    /// Visible posts of one photo (one per group it was sent to).
    public func posts(mediaID: MediaID) async throws -> [Post] {
        try await client.rows(Post.self) {
            client.supabase.from("posts").select().eq("media_id", value: mediaID.rawValue).order("created_at", ascending: true)
        }
    }

    /// Readable media rows among `ids`.
    public func media(ids: [MediaID]) async throws -> [Media] {
        let unique = Array(Set(ids))
        guard !unique.isEmpty else { return [] }
        var result: [Media] = []
        for chunk in unique.chunked(into: 100) {
            result += try await client.rows(Media.self) {
                client.supabase.from("media").select().in("id", values: chunk.map(\.rawValue))
            }
        }
        return result
    }

    /// Joins posts with their media, keeping the posts' order.
    public func withMedia(_ posts: [Post]) async throws -> [PostWithMedia] {
        let media = try await media(ids: posts.map(\.mediaID))
        let byID = Dictionary(media.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return posts.map { PostWithMedia(post: $0, media: byID[$0.mediaID]) }
    }

    // MARK: Posting

    /// Inserts the media row (step 2 of recipe 9.4). Idempotent: a row that already exists
    /// (a retried insert whose response was lost) counts as inserted.
    public func insertMedia(_ media: NewMedia) async throws {
        do {
            try await client.perform {
                try client.supabase.from("media").insert(media.row, returning: .minimal)
            }
        } catch let error as DataError {
            if case let .database(code, _) = error, code == "23505" { return }
            throw error
        }
    }

    /// `create_post` (step 3): one post and one chat photo message per group, all or nothing.
    /// `invitationID` marks the post in-window only while that invitation is open (never "late").
    /// `replyToPostID` needs exactly one group, the replied post's group.
    public func create(
        mediaID: MediaID,
        groupIDs: [GroupID],
        caption: String? = nil,
        voicePath: String? = nil,
        voiceDurationMs: Int? = nil,
        voiceLevels: [Int]? = nil,
        invitationID: InvitationID? = nil,
        replyToPostID: PostID? = nil
    ) async throws -> [Post] {
        try await client.rpc("create_post", [
            "p_media_id": .id(mediaID),
            "p_group_ids": .ids(groupIDs),
            "p_caption": .text(caption),
            "p_voice_path": .text(voicePath),
            "p_voice_duration_ms": .int(voiceDurationMs),
            "p_voice_levels": .levels(voiceLevels),
            "p_invitation_id": .id(invitationID),
            "p_reply_to_post_id": .id(replyToPostID),
        ])
    }

    // MARK: Deleting

    /// `delete_post` (author): removes the photo from one group; the media goes with its last post.
    public func deletePost(id: PostID) async throws {
        try await client.rpcVoid("delete_post", ["p_post_id": .id(id)])
        await cache?.purgePost(id)
    }

    /// `delete_media` (owner): removes the photo from every group, chat, album, recap, tribute,
    /// collage, year story, widget and storage.
    public func deleteMedia(id: MediaID) async throws {
        let posts = (try? await posts(mediaID: id)) ?? []
        try await client.rpcVoid("delete_media", ["p_media_id": .id(id)])
        for post in posts { await cache?.purgePost(post.id) }
    }
}

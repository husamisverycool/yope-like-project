// Social group — `SocialDataSource` over AppData's repositories (docs/API.md). Foundation + AppData only.
import AppData
import AppModels
import Foundation

/// The production data source: AppData repositories, offline cache, signed URLs, realtime and reachability.
struct LiveSocialData: SocialDataSource {
    let environment: DataEnvironment

    init(environment: DataEnvironment) {
        self.environment = environment
    }

    func currentUserID() async -> UserID? {
        environment.auth.currentUserID
    }

    // MARK: Groups and people

    func group(id: GroupID) async throws -> PhotoGroup? {
        try await environment.groups.group(id: id)
    }

    func cachedGroup(id: GroupID) async -> PhotoGroup? {
        await environment.groups.cachedGroups()?.value.first { $0.id == id }
    }

    func myGroups() async throws -> [PhotoGroup] {
        try await environment.groups.myGroups()
    }

    func cachedGroups() async -> [PhotoGroup]? {
        await environment.groups.cachedGroups()?.value
    }

    func members(groupID: GroupID) async throws -> [MemberProfile] {
        try await environment.groups.members(groupID: groupID)
    }

    func cachedMembers(groupID: GroupID) async -> [MemberProfile]? {
        await environment.groups.cachedMembers(groupID: groupID)?.value
    }

    func profiles(ids: [UserID]) async throws -> [Profile] {
        try await environment.profiles.profiles(ids: ids)
    }

    func myMembership(groupID: GroupID) async throws -> GroupMember? {
        try await environment.groups.myMembership(groupID: groupID)
    }

    // MARK: Chat

    func messages(groupID: GroupID, before: Date?) async throws -> Page<Message> {
        try await environment.chat.page(groupID: groupID, before: before, limit: SocialPaging.messages)
    }

    func cachedMessages(groupID: GroupID) async -> [Message]? {
        await environment.chat.cachedPage(groupID: groupID)?.value
    }

    func sendText(groupID: GroupID, body: String, replyToPostID: PostID?) async throws -> Message {
        try await environment.chat.sendText(groupID: groupID, body: body, replyToPostID: replyToPostID)
    }

    func sendVoice(groupID: GroupID, fileURL: URL, durationMs: Int) async throws -> Message {
        let path = try await environment.uploader.uploadChatVoice(fileURL: fileURL)
        return try await environment.chat.sendVoice(groupID: groupID, voicePath: path, durationMs: durationMs)
    }

    func deleteMessage(id: MessageID, groupID: GroupID) async throws {
        try await environment.chat.delete(messageID: id, groupID: groupID)
    }

    // MARK: Posts

    func posts(ids: [PostID]) async throws -> [PostWithMedia] {
        let posts = try await environment.posts.posts(ids: ids)
        return try await environment.posts.withMedia(posts)
    }

    func cachedPosts(groupID: GroupID) async -> [PostWithMedia] {
        await environment.posts.cachedFeed(groupID: groupID)?.value ?? []
    }

    func deleteMedia(id: MediaID) async throws {
        try await environment.posts.deleteMedia(id: id)
        await environment.signedURLs.invalidate(mediaID: id)
    }

    // MARK: Reactions and self-tags

    func reactions(postIDs: [PostID]) async throws -> [Reaction] {
        try await environment.reactions.reactions(postIDs: postIDs)
    }

    func react(postID: PostID, emoji: String) async throws -> Reaction {
        try await environment.reactions.react(postID: postID, emoji: emoji)
    }

    func isTagged(postID: PostID, userID: UserID) async throws -> Bool {
        try await environment.reactions.tags(postID: postID).contains { $0.userID == userID }
    }

    func setTagged(_ tagged: Bool, postID: PostID) async throws {
        if tagged {
            try await environment.reactions.tagSelf(postID: postID)
        } else {
            try await environment.reactions.untagSelf(postID: postID)
        }
    }

    // MARK: Safety

    func block(userID: UserID) async throws {
        try await environment.safety.block(userID: userID)
    }

    // MARK: Walls

    func wall(userID: UserID, before: Date?, limit: Int) async throws -> Page<WallItem> {
        try await environment.memories.wall(userID: userID, before: before, limit: limit)
    }

    func cachedWall(userID: UserID) async -> [WallItem]? {
        await environment.memories.cachedWall(userID: userID)?.value
    }

    func collages(ids: [CollageID]) async throws -> [Collage] {
        var result: [Collage] = []
        for id in ids {
            if let collage = try await environment.memories.collage(id: id) { result.append(collage) }
        }
        return result
    }

    // MARK: Weeks and albums

    func recaps(groupID: GroupID) async throws -> [WeeklyRecap] {
        try await environment.memories.recaps(groupID: groupID)
    }

    func recap(id: RecapID) async throws -> WeeklyRecap? {
        try await environment.memories.recap(id: id)
    }

    func updateRecap(id: RecapID, items: [PostID], text: String) async throws -> WeeklyRecap {
        try await environment.memories.updateRecap(id: id, items: items, text: text)
    }

    func historyWeeks(groupID: GroupID, beforeWeek: LocalDate?) async throws -> [HistoryWeek] {
        try await environment.memories.historyWeeks(groupID: groupID, beforeWeek: beforeWeek, limit: SocialPaging.historyWeeks)
    }

    func cachedHistoryWeeks(groupID: GroupID) async -> [HistoryWeek]? {
        await environment.memories.cachedHistoryWeeks(groupID: groupID)?.value
    }

    func albums(groupID: GroupID) async throws -> [AlbumWithItems] {
        try await environment.memories.albums(groupID: groupID)
    }

    func cachedAlbums(groupID: GroupID) async -> [AlbumWithItems]? {
        await environment.memories.cachedAlbums(groupID: groupID)?.value
    }

    func saveAlbum(groupID: GroupID, name: String, postIDs: [PostID]) async throws -> Album {
        try await environment.memories.saveAlbum(groupID: groupID, name: name, postIDs: postIDs)
    }

    func renameAlbum(id: AlbumID, name: String) async throws -> Album {
        try await environment.memories.renameAlbum(id: id, name: name)
    }

    func deleteAlbum(id: AlbumID, groupID: GroupID) async throws {
        try await environment.memories.deleteAlbum(id: id, groupID: groupID)
    }

    // MARK: Files

    func fileURL(path: String) async throws -> URL {
        try await environment.signedURLs.url(for: path)
    }

    // MARK: Live

    func events(groupID: GroupID) -> AsyncStream<GroupEvent> {
        environment.realtime.events(for: groupID)
    }

    func network() -> AsyncStream<NetworkStatus> {
        environment.reachability.updates()
    }
}

/// Used while config/app.json has no Supabase URL / key (BLOCKED owner values): every call fails with
/// `DataError.notConfigured`, so the screens show their error states.
struct UnconfiguredSocialData: SocialDataSource {
    private func fail<T>() throws -> T { throw DataError.notConfigured }

    func currentUserID() async -> UserID? { nil }
    func group(id: GroupID) async throws -> PhotoGroup? { try fail() }
    func cachedGroup(id: GroupID) async -> PhotoGroup? { nil }
    func myGroups() async throws -> [PhotoGroup] { try fail() }
    func cachedGroups() async -> [PhotoGroup]? { nil }
    func members(groupID: GroupID) async throws -> [MemberProfile] { try fail() }
    func cachedMembers(groupID: GroupID) async -> [MemberProfile]? { nil }
    func profiles(ids: [UserID]) async throws -> [Profile] { try fail() }
    func myMembership(groupID: GroupID) async throws -> GroupMember? { try fail() }
    func messages(groupID: GroupID, before: Date?) async throws -> Page<Message> { try fail() }
    func cachedMessages(groupID: GroupID) async -> [Message]? { nil }
    func sendText(groupID: GroupID, body: String, replyToPostID: PostID?) async throws -> Message { try fail() }
    func sendVoice(groupID: GroupID, fileURL: URL, durationMs: Int) async throws -> Message { try fail() }
    func deleteMessage(id: MessageID, groupID: GroupID) async throws { try fail() as Void }
    func posts(ids: [PostID]) async throws -> [PostWithMedia] { try fail() }
    func cachedPosts(groupID: GroupID) async -> [PostWithMedia] { [] }
    func deleteMedia(id: MediaID) async throws { try fail() as Void }
    func reactions(postIDs: [PostID]) async throws -> [Reaction] { try fail() }
    func react(postID: PostID, emoji: String) async throws -> Reaction { try fail() }
    func isTagged(postID: PostID, userID: UserID) async throws -> Bool { try fail() }
    func setTagged(_ tagged: Bool, postID: PostID) async throws { try fail() as Void }
    func block(userID: UserID) async throws { try fail() as Void }
    func wall(userID: UserID, before: Date?, limit: Int) async throws -> Page<WallItem> { try fail() }
    func cachedWall(userID: UserID) async -> [WallItem]? { nil }
    func collages(ids: [CollageID]) async throws -> [Collage] { try fail() }
    func recaps(groupID: GroupID) async throws -> [WeeklyRecap] { try fail() }
    func recap(id: RecapID) async throws -> WeeklyRecap? { try fail() }
    func updateRecap(id: RecapID, items: [PostID], text: String) async throws -> WeeklyRecap { try fail() }
    func historyWeeks(groupID: GroupID, beforeWeek: LocalDate?) async throws -> [HistoryWeek] { try fail() }
    func cachedHistoryWeeks(groupID: GroupID) async -> [HistoryWeek]? { nil }
    func albums(groupID: GroupID) async throws -> [AlbumWithItems] { try fail() }
    func cachedAlbums(groupID: GroupID) async -> [AlbumWithItems]? { nil }
    func saveAlbum(groupID: GroupID, name: String, postIDs: [PostID]) async throws -> Album { try fail() }
    func renameAlbum(id: AlbumID, name: String) async throws -> Album { try fail() }
    func deleteAlbum(id: AlbumID, groupID: GroupID) async throws { try fail() as Void }
    func fileURL(path: String) async throws -> URL { try fail() }

    func events(groupID: GroupID) -> AsyncStream<GroupEvent> {
        AsyncStream { $0.finish() }
    }

    func network() -> AsyncStream<NetworkStatus> {
        AsyncStream { continuation in
            continuation.yield(.unknown)
            continuation.finish()
        }
    }
}

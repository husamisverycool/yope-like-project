// Social group — `SocialDataSource` over AppData's repositories (docs/API.md). Foundation + AppData only.
import AppData
import AppModels
import Foundation

/// The production data source: AppData repositories, offline cache, signed URLs, realtime and reachability.
struct LiveSocialData: SocialDataSource {
    let environment: DataEnvironment
    /// Recaps and posts fetched this session (first paint of a reopened recap).
    private let memo = SocialMemo()

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

    func sendText(groupID: GroupID, body: String, replyToPostID: PostID?, replyToMessageID: MessageID?) async throws -> Message {
        try await environment.chat.sendText(
            groupID: groupID, body: body, replyToPostID: replyToPostID, replyToMessageID: replyToMessageID
        )
    }

    func message(id: MessageID) async throws -> Message? {
        try await environment.chat.message(id: id)
    }

    func replies(postID: PostID) async throws -> [Message] {
        try await replyRows(postID: postID)
    }

    func sendVoice(groupID: GroupID, fileURL: URL, durationMs: Int, levels: [Int]?) async throws -> Message {
        let path = try await environment.uploader.uploadChatVoice(fileURL: fileURL)
        return try await environment.chat.sendVoice(groupID: groupID, voicePath: path, durationMs: durationMs, levels: levels)
    }

    func deleteMessage(id: MessageID, groupID: GroupID) async throws {
        try await environment.chat.delete(messageID: id, groupID: groupID)
    }

    func adminDeleteMessage(id: MessageID, groupID: GroupID) async throws {
        try await environment.chat.adminDelete(messageID: id, groupID: groupID)
    }

    func editMessage(id: MessageID, body: String) async throws -> Message {
        try await environment.chat.edit(messageID: id, body: body)
    }

    func publicConfig() async throws -> PublicAppConfig {
        try await environment.account.publicConfig()
    }

    func setLinkPreview(messageID: MessageID, preview: LinkPreviewDraft) async throws -> Message {
        var imagePath: String?
        if let jpeg = preview.jpeg { imagePath = try await environment.uploader.uploadLinkPreview(jpeg: jpeg) }
        return try await environment.chat.setLinkPreview(
            messageID: messageID, url: preview.url, title: preview.title, site: preview.site, imagePath: imagePath
        )
    }

    func messageReactions(messageIDs: [MessageID]) async throws -> [MessageReaction] {
        try await environment.reactions.messageReactions(messageIDs: messageIDs)
    }

    func reactToMessage(id: MessageID, emoji: String) async throws -> MessageReaction {
        try await environment.reactions.react(messageID: id, emoji: emoji)
    }

    func unreactToMessage(id: MessageID) async throws {
        try await environment.reactions.unreact(messageID: id)
    }

    func typing(groupID: GroupID) async throws -> [ChatTyping] {
        try await environment.chat.typing(groupID: groupID)
    }

    func setTyping(_ typing: Bool, groupID: GroupID) async throws {
        try await environment.chat.setTyping(groupID: groupID, typing: typing)
    }

    // MARK: Posts

    func posts(ids: [PostID]) async throws -> [PostWithMedia] {
        let posts = try await environment.posts.withMedia(environment.posts.posts(ids: ids))
        memo.store(posts: posts, asked: ids)
        return posts
    }

    func revealedWith(_ post: Post) async throws -> [PostWithMedia] {
        guard let revealedAt = post.revealedAt else { return [] }
        let rows = try await environment.posts.revealed(groupID: post.groupID, at: revealedAt)
        let posts = try await environment.posts.withMedia(rows)
        memo.store(posts: posts, asked: rows.map(\.id))
        return posts
    }

    func batchWith(_ post: Post) async throws -> [PostWithMedia] {
        guard let batchID = post.batchID else { return [] }
        let rows = try await environment.posts.batch(groupID: post.groupID, authorID: post.authorID, batchID: batchID)
        let posts = try await environment.posts.withMedia(rows)
        memo.store(posts: posts, asked: rows.map(\.id))
        return posts
    }

    func cachedPosts(ids: [PostID], groupID: GroupID?) async -> [PostWithMedia] {
        let known = memo.posts(ids)
        let missing = ids.filter { known[$0] == nil }
        var found = known
        if !missing.isEmpty, let groupID {
            for post in await cachedPosts(groupID: groupID) where missing.contains(post.id) { found[post.id] = post }
        }
        return ids.compactMap { found[$0] }
    }

    func cachedPosts(groupID: GroupID) async -> [PostWithMedia] {
        await environment.posts.cachedFeed(groupID: groupID)?.value ?? []
    }

    func deleteMedia(id: MediaID) async throws {
        try await environment.posts.deleteMedia(id: id)
        memo.forget(mediaID: id)
        await environment.signedURLs.invalidate(mediaID: id)
    }

    func adminDeletePost(id: PostID, groupID: GroupID) async throws {
        try await environment.posts.adminDeletePost(id: id)
        memo.forget(postID: id)
    }

    func editCaption(postID: PostID, caption: String) async throws -> Post {
        let post = try await environment.posts.editCaption(postID: postID, caption: caption)
        memo.replace(post: post)
        return post
    }

    // MARK: Downloads

    func downloadItems(_ scope: DownloadScope, before: Date?) async throws -> [DownloadItem] {
        try await environment.posts.downloadItems(scope: scope, before: before, limit: SocialPaging.downloads)
    }

    // MARK: Reactions and self-tags

    func reactions(postIDs: [PostID]) async throws -> [Reaction] {
        try await environment.reactions.reactions(postIDs: postIDs)
    }

    func react(postID: PostID, emoji: String) async throws -> Reaction {
        try await environment.reactions.react(postID: postID, emoji: emoji)
    }

    func unreact(postID: PostID, emoji: String) async throws {
        try await environment.reactions.unreact(postID: postID, emoji: emoji)
    }

    func isTagged(postID: PostID, userID: UserID) async throws -> Bool {
        try await environment.reactions.tags(postID: postID).contains { $0.userID == userID }
    }

    func tags(postID: PostID) async throws -> [PostTag] {
        try await environment.reactions.tags(postID: postID)
    }

    func setTagged(_ tagged: Bool, postID: PostID) async throws {
        if tagged {
            try await environment.reactions.tagSelf(postID: postID)
        } else {
            try await environment.reactions.untagSelf(postID: postID)
        }
    }

    // MARK: Selfie reactions

    func selfieReactions(postIDs: [PostID]) async throws -> [SelfieReaction] {
        try await environment.selfies.selfies(postIDs: postIDs)
    }

    func reactWithSelfie(postID: PostID, jpeg: Data) async throws -> SelfieReaction {
        try await environment.selfies.react(postID: postID, jpeg: jpeg)
    }

    func removeSelfieReaction(postID: PostID, userID: UserID?) async throws {
        try await environment.selfies.remove(postID: postID, userID: userID)
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
        let recaps = try await environment.memories.recaps(groupID: groupID)
        memo.store(recaps: recaps)
        return recaps
    }

    func recap(id: RecapID) async throws -> WeeklyRecap? {
        let recap = try await environment.memories.recap(id: id)
        if let recap { memo.store(recaps: [recap]) }
        return recap
    }

    func cachedRecap(id: RecapID) async -> WeeklyRecap? {
        memo.recap(id)
    }

    func updateRecap(id: RecapID, items: [PostID], text: String) async throws -> WeeklyRecap {
        let recap = try await environment.memories.updateRecap(id: id, items: items, text: text)
        memo.store(recaps: [recap])
        return recap
    }

    func historyWeeks(groupID: GroupID, beforeWeek: LocalDate?) async throws -> [HistoryWeek] {
        try await environment.memories.historyWeeks(groupID: groupID, beforeWeek: beforeWeek, limit: SocialPaging.historyWeeks)
    }

    func cachedHistoryWeeks(groupID: GroupID) async -> [HistoryWeek]? {
        await environment.memories.cachedHistoryWeeks(groupID: groupID)?.value
    }

    func historyMonths(groupID: GroupID) async throws -> [HistoryMonth] {
        try await environment.memories.historyMonths(groupID: groupID)
    }

    func searchPhotos(_ query: PhotoSearchQuery, before: Date?) async throws -> [PhotoSearchHit] {
        try await environment.memories.searchPhotos(
            text: query.trimmedText, groupID: query.groupID, memberID: query.memberID, from: query.from, to: query.to,
            before: before, limit: SocialPaging.search
        )
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

    func addToAlbum(id: AlbumID, groupID: GroupID, postIDs: [PostID]) async throws -> Album {
        try await environment.memories.addToAlbum(id: id, groupID: groupID, postIDs: postIDs)
    }

    func removeFromAlbum(id: AlbumID, groupID: GroupID, postIDs: [PostID]) async throws {
        try await environment.memories.removeFromAlbum(id: id, groupID: groupID, postIDs: postIDs)
    }

    // MARK: Favorites and the group cover

    func setFavorite(_ on: Bool, mediaID: MediaID) async throws {
        try await environment.memories.setFavorite(mediaID: mediaID, on: on)
        memo.setFavorite(on, mediaID: mediaID)
    }

    func favoriteMediaIDs(among mediaIDs: [MediaID]) async throws -> Set<MediaID> {
        try await environment.memories.favoriteMediaIDs(among: mediaIDs)
    }

    func favorites(before: Date?, limit: Int) async throws -> [FavoritePhoto] {
        let rows = try await environment.memories.favorites(before: before, limit: limit).items
        if before == nil { memo.store(favorites: rows) }
        return rows
    }

    func cachedFavorites() async -> [FavoritePhoto]? {
        memo.favorites()
    }

    func setGroupCover(groupID: GroupID, postID: PostID) async throws {
        _ = try await environment.groups.setCoverFromPost(groupID: groupID, postID: postID)
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
    func sendText(groupID: GroupID, body: String, replyToPostID: PostID?, replyToMessageID: MessageID?) async throws -> Message { try fail() }
    func message(id: MessageID) async throws -> Message? { try fail() }
    func replies(postID: PostID) async throws -> [Message] { try fail() }
    func sendVoice(groupID: GroupID, fileURL: URL, durationMs: Int, levels: [Int]?) async throws -> Message { try fail() }
    func deleteMessage(id: MessageID, groupID: GroupID) async throws { try fail() as Void }
    func adminDeleteMessage(id: MessageID, groupID: GroupID) async throws { try fail() as Void }
    func editMessage(id: MessageID, body: String) async throws -> Message { try fail() }
    func publicConfig() async throws -> PublicAppConfig { try fail() }
    func setLinkPreview(messageID: MessageID, preview: LinkPreviewDraft) async throws -> Message { try fail() }
    func messageReactions(messageIDs: [MessageID]) async throws -> [MessageReaction] { try fail() }
    func reactToMessage(id: MessageID, emoji: String) async throws -> MessageReaction { try fail() }
    func unreactToMessage(id: MessageID) async throws { try fail() as Void }
    func typing(groupID: GroupID) async throws -> [ChatTyping] { try fail() }
    func setTyping(_ typing: Bool, groupID: GroupID) async throws { try fail() as Void }
    func posts(ids: [PostID]) async throws -> [PostWithMedia] { try fail() }
    func revealedWith(_ post: Post) async throws -> [PostWithMedia] { try fail() }
    func cachedPosts(groupID: GroupID) async -> [PostWithMedia] { [] }
    func cachedPosts(ids: [PostID], groupID: GroupID?) async -> [PostWithMedia] { [] }
    func deleteMedia(id: MediaID) async throws { try fail() as Void }
    func adminDeletePost(id: PostID, groupID: GroupID) async throws { try fail() as Void }
    func editCaption(postID: PostID, caption: String) async throws -> Post { try fail() }
    func downloadItems(_ scope: DownloadScope, before: Date?) async throws -> [DownloadItem] { try fail() }
    func reactions(postIDs: [PostID]) async throws -> [Reaction] { try fail() }
    func react(postID: PostID, emoji: String) async throws -> Reaction { try fail() }
    func unreact(postID: PostID, emoji: String) async throws { try fail() as Void }
    func isTagged(postID: PostID, userID: UserID) async throws -> Bool { try fail() }
    func tags(postID: PostID) async throws -> [PostTag] { try fail() }
    func setTagged(_ tagged: Bool, postID: PostID) async throws { try fail() as Void }
    func selfieReactions(postIDs: [PostID]) async throws -> [SelfieReaction] { try fail() }
    func reactWithSelfie(postID: PostID, jpeg: Data) async throws -> SelfieReaction { try fail() }
    func removeSelfieReaction(postID: PostID, userID: UserID?) async throws { try fail() as Void }
    func block(userID: UserID) async throws { try fail() as Void }
    func wall(userID: UserID, before: Date?, limit: Int) async throws -> Page<WallItem> { try fail() }
    func cachedWall(userID: UserID) async -> [WallItem]? { nil }
    func collages(ids: [CollageID]) async throws -> [Collage] { try fail() }
    func recaps(groupID: GroupID) async throws -> [WeeklyRecap] { try fail() }
    func recap(id: RecapID) async throws -> WeeklyRecap? { try fail() }
    func cachedRecap(id: RecapID) async -> WeeklyRecap? { nil }
    func updateRecap(id: RecapID, items: [PostID], text: String) async throws -> WeeklyRecap { try fail() }
    func historyWeeks(groupID: GroupID, beforeWeek: LocalDate?) async throws -> [HistoryWeek] { try fail() }
    func cachedHistoryWeeks(groupID: GroupID) async -> [HistoryWeek]? { nil }
    func historyMonths(groupID: GroupID) async throws -> [HistoryMonth] { try fail() }
    func searchPhotos(_ query: PhotoSearchQuery, before: Date?) async throws -> [PhotoSearchHit] { try fail() }
    func albums(groupID: GroupID) async throws -> [AlbumWithItems] { try fail() }
    func cachedAlbums(groupID: GroupID) async -> [AlbumWithItems]? { nil }
    func saveAlbum(groupID: GroupID, name: String, postIDs: [PostID]) async throws -> Album { try fail() }
    func renameAlbum(id: AlbumID, name: String) async throws -> Album { try fail() }
    func deleteAlbum(id: AlbumID, groupID: GroupID) async throws { try fail() as Void }
    func addToAlbum(id: AlbumID, groupID: GroupID, postIDs: [PostID]) async throws -> Album { try fail() }
    func removeFromAlbum(id: AlbumID, groupID: GroupID, postIDs: [PostID]) async throws { try fail() as Void }
    func setFavorite(_ on: Bool, mediaID: MediaID) async throws { try fail() as Void }
    func favoriteMediaIDs(among mediaIDs: [MediaID]) async throws -> Set<MediaID> { try fail() }
    func favorites(before: Date?, limit: Int) async throws -> [FavoritePhoto] { try fail() }
    func cachedFavorites() async -> [FavoritePhoto]? { nil }
    func setGroupCover(groupID: GroupID, postID: PostID) async throws { try fail() as Void }
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

/// Recaps and posts fetched this session, in memory only (no image data; deleted photos are dropped).
final class SocialMemo: @unchecked Sendable {
    private let lock = NSLock()
    private var recaps: [RecapID: WeeklyRecap] = [:]
    private var posts: [PostID: PostWithMedia] = [:]
    private var favoriteRows: [FavoritePhoto]?

    func store(recaps new: [WeeklyRecap]) {
        lock.lock()
        defer { lock.unlock() }
        for recap in new { recaps[recap.id] = recap }
    }

    /// Keeps `found`; ids that were asked for and not returned are gone (deleted or hidden).
    func store(posts found: [PostWithMedia], asked: [PostID]) {
        lock.lock()
        defer { lock.unlock() }
        for id in asked { posts[id] = nil }
        for post in found { posts[post.id] = post }
    }

    /// An edited post (`edit_caption`) replaces the session copy, keeping its media.
    func replace(post: Post) {
        lock.lock()
        defer { lock.unlock() }
        if let known = posts[post.id] { posts[post.id] = PostWithMedia(post: post, media: known.media) }
    }

    /// One group's copy of a photo removed by an admin (`admin_delete_post`); the photo's other posts stay.
    func forget(postID: PostID) {
        lock.lock()
        defer { lock.unlock() }
        posts[postID] = nil
    }

    func forget(mediaID: MediaID) {
        lock.lock()
        defer { lock.unlock() }
        posts = posts.filter { $0.value.post.mediaID != mediaID }
        favoriteRows?.removeAll { $0.mediaID == mediaID }
    }

    /// The first page of `my_favorites` loaded this session.
    func store(favorites rows: [FavoritePhoto]) {
        lock.lock()
        defer { lock.unlock() }
        favoriteRows = rows
    }

    /// An unfavorite leaves the session copy at once (a favorite joins it on the next load).
    func setFavorite(_ on: Bool, mediaID: MediaID) {
        lock.lock()
        defer { lock.unlock() }
        if !on { favoriteRows?.removeAll { $0.mediaID == mediaID } }
    }

    func favorites() -> [FavoritePhoto]? {
        lock.lock()
        defer { lock.unlock() }
        return favoriteRows
    }

    func recap(_ id: RecapID) -> WeeklyRecap? {
        lock.lock()
        defer { lock.unlock() }
        return recaps[id]
    }

    func posts(_ ids: [PostID]) -> [PostID: PostWithMedia] {
        lock.lock()
        defer { lock.unlock() }
        var result: [PostID: PostWithMedia] = [:]
        for id in ids { result[id] = posts[id] }
        return result
    }
}

// Social group — in-memory `SocialDataSource` for unit tests, snapshot tests and UI tests
// (launch argument `-SocialFakes`, see SocialServices). DEBUG builds only. Foundation + AppData only.
#if DEBUG
import AppData
import AppModels
import Foundation

/// An in-memory backend. Writes behave like the RPCs (idempotent `react`, `delete_media` removing every
/// post of the media, …); tests drive realtime with `emit(_:groupID:)` and failures with `failure`.
final class FakeSocialData: SocialDataSource, @unchecked Sendable {
    /// What failing calls throw.
    enum Mode: Equatable {
        case normal
        /// Every network call throws `DataError.offline`; cached values still answer.
        case offline
        /// Every network call throws a server error.
        case failing
    }

    private let lock = NSLock()
    private var state = State()
    private var continuations: [GroupID: [UUID: AsyncStream<GroupEvent>.Continuation]] = [:]
    private var networkContinuations: [UUID: AsyncStream<NetworkStatus>.Continuation] = [:]

    struct State {
        var me: UserID?
        var mode: Mode = .normal
        /// Names of calls that fail once with a server error (e.g. "sendText", "react", "setTagged").
        var failOnce: Set<String> = []
        /// Names of calls that fail once with `post_not_found`.
        var notFoundOnce: Set<String> = []
        /// Names of calls that never answer (loading-state snapshots); they return once the caller is cancelled.
        var holds: Set<String> = []
        var network: NetworkStatus = .unknown
        var groups: [PhotoGroup] = []
        var members: [GroupID: [MemberProfile]] = [:]
        var profiles: [UserID: Profile] = [:]
        var messages: [Message] = []
        var posts: [PostWithMedia] = []
        var reactions: [Reaction] = []
        var tags: [PostTag] = []
        var collages: [Collage] = []
        var recaps: [WeeklyRecap] = []
        var albums: [AlbumWithItems] = []
        /// Wall items per person as `wall()` returns them (newest first); derived from posts when absent.
        var walls: [UserID: [WallItem]] = [:]
        var cachedMessages: [GroupID: [Message]] = [:]
        var cachedWalls: [UserID: [WallItem]] = [:]
        var cachedHistory: [GroupID: [HistoryWeek]] = [:]
        var cachedAlbums: [GroupID: [AlbumWithItems]] = [:]
        var cachedGroups: [PhotoGroup]?
        var cachedMembers: [GroupID: [MemberProfile]] = [:]
        var cachedFeeds: [GroupID: [PostWithMedia]] = [:]
        var cachedRecaps: [RecapID: WeeklyRecap] = [:]
        var blocked: [UserID] = []
        var deletedMedia: [MediaID] = []
        var sentVoice: [(URL, Int)] = []
        var calls: [String] = []
        var messagePageSize = SocialPaging.messages
        /// Runs inside `sendText` / `sendVoice` before they return (e.g. the realtime echo arriving first).
        var beforeSendReturns: (@Sendable (Message) async -> Void)?
        var idCounter = 0
        var now = Date(timeIntervalSince1970: 1_792_000_000)
    }

    init(me: UserID? = nil) {
        state.me = me
    }

    // MARK: Test controls

    func update(_ change: (inout State) -> Void) {
        lock.lock()
        change(&state)
        lock.unlock()
    }

    func read<T>(_ body: (State) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(state)
    }

    /// Delivers a realtime event to every subscriber of the group.
    func emit(_ event: GroupEvent, groupID: GroupID) {
        lock.lock()
        let targets = Array((continuations[groupID] ?? [:]).values)
        lock.unlock()
        for continuation in targets { continuation.yield(event) }
    }

    func setNetwork(_ status: NetworkStatus) {
        lock.lock()
        state.network = status
        state.mode = status == .offline ? .offline : (state.mode == .offline ? .normal : state.mode)
        let targets = Array(networkContinuations.values)
        lock.unlock()
        for continuation in targets { continuation.yield(status) }
    }

    var subscriberCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return continuations.values.reduce(0) { $0 + $1.count }
    }

    /// Records the call and throws when the mode or a one-shot failure says so.
    private func call(_ name: String) throws {
        lock.lock()
        state.calls.append(name)
        let mode = state.mode
        let failOnce = state.failOnce.remove(name) != nil
        let notFound = state.notFoundOnce.remove(name) != nil
        lock.unlock()
        switch mode {
        case .offline: throw DataError.offline
        case .failing: throw DataError.http(status: 500)
        case .normal: break
        }
        if failOnce { throw DataError.http(status: 500) }
        if notFound { throw DataError.api(.postNotFound) }
    }

    /// Waits while `name` is held (until the calling task is cancelled).
    private func hold(_ name: String) async {
        while read({ $0.holds.contains(name) }), !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func nextID() -> String {
        lock.lock()
        state.idCounter += 1
        let value = state.idCounter
        lock.unlock()
        return "00000000-0000-4000-8000-" + String(value + 900_000_000_000).suffix(12)
    }

    private func tick() -> Date {
        lock.lock()
        state.now = state.now.addingTimeInterval(60)
        let value = state.now
        lock.unlock()
        return value
    }

    // MARK: SocialDataSource

    func currentUserID() async -> UserID? { read { $0.me } }

    func group(id: GroupID) async throws -> PhotoGroup? {
        try call("group")
        return read { $0.groups.first { $0.id == id } }
    }

    func cachedGroup(id: GroupID) async -> PhotoGroup? {
        read { $0.cachedGroups?.first { $0.id == id } }
    }

    func myGroups() async throws -> [PhotoGroup] {
        await hold("myGroups")
        try call("myGroups")
        return read { $0.groups }
    }

    func cachedGroups() async -> [PhotoGroup]? { read { $0.cachedGroups } }

    func members(groupID: GroupID) async throws -> [MemberProfile] {
        try call("members")
        return read { $0.members[groupID] ?? [] }
    }

    func cachedMembers(groupID: GroupID) async -> [MemberProfile]? { read { $0.cachedMembers[groupID] } }

    func profiles(ids: [UserID]) async throws -> [Profile] {
        try call("profiles")
        return read { state in ids.compactMap { state.profiles[$0] } }
    }

    func myMembership(groupID: GroupID) async throws -> GroupMember? {
        try call("myMembership")
        return read { state in state.members[groupID]?.first { $0.member.userID == state.me }?.member }
    }

    func messages(groupID: GroupID, before: Date?) async throws -> Page<Message> {
        await hold("messages")
        try call("messages")
        return read { state in
            let all = state.messages
                .filter { $0.groupID == groupID && (before == nil || $0.createdAt < before!) }
                .sorted { $0.createdAt > $1.createdAt }
            let page = Array(all.prefix(state.messagePageSize))
            return Page(items: page, nextCursor: page.count == state.messagePageSize ? page.last?.createdAt : nil)
        }
    }

    func cachedMessages(groupID: GroupID) async -> [Message]? { read { $0.cachedMessages[groupID] } }

    func sendText(groupID: GroupID, body: String, replyToPostID: PostID?, replyToMessageID: MessageID?) async throws -> Message {
        try call("sendText")
        let message = Message(
            id: MessageID(nextID()), groupID: groupID, authorID: read { $0.me } ?? UserID("me"), kind: .text,
            body: body, replyToPostID: replyToPostID, replyToMessageID: replyToMessageID, createdAt: tick()
        )
        update { $0.messages.append(message) }
        if let hook = read({ $0.beforeSendReturns }) { await hook(message) }
        return message
    }

    func sendVoice(groupID: GroupID, fileURL: URL, durationMs: Int) async throws -> Message {
        try call("sendVoice")
        let message = Message(
            id: MessageID(nextID()), groupID: groupID, authorID: read { $0.me } ?? UserID("me"), kind: .voice,
            voicePath: "fake/voice/\(fileURL.lastPathComponent)", voiceDurationMs: durationMs, createdAt: tick()
        )
        update {
            $0.messages.append(message)
            $0.sentVoice.append((fileURL, durationMs))
        }
        if let hook = read({ $0.beforeSendReturns }) { await hook(message) }
        return message
    }

    func message(id: MessageID) async throws -> Message? {
        try call("message")
        return read { $0.messages.first { $0.id == id } }
    }

    func replies(postID: PostID) async throws -> [Message] {
        await hold("replies")
        try call("replies")
        return read { $0.messages.filter { $0.replyToPostID == postID }.sorted { $0.createdAt < $1.createdAt } }
    }

    func deleteMessage(id: MessageID, groupID: GroupID) async throws {
        try call("deleteMessage")
        update { $0.messages.removeAll { $0.id == id } }
    }

    func posts(ids: [PostID]) async throws -> [PostWithMedia] {
        await hold("posts")
        try call("posts")
        return read { state in ids.compactMap { id in state.posts.first { $0.id == id } } }
    }

    func cachedPosts(groupID: GroupID) async -> [PostWithMedia] { read { $0.cachedFeeds[groupID] ?? [] } }

    func cachedPosts(ids: [PostID], groupID: GroupID?) async -> [PostWithMedia] {
        read { state in
            let feed = groupID.flatMap { state.cachedFeeds[$0] } ?? state.cachedFeeds.values.flatMap { $0 }
            return ids.compactMap { id in feed.first { $0.id == id } }
        }
    }

    func deleteMedia(id: MediaID) async throws {
        try call("deleteMedia")
        update { state in
            let gone = Set(state.posts.filter { $0.post.mediaID == id }.map(\.id))
            state.posts.removeAll { gone.contains($0.id) }
            state.messages.removeAll { $0.postID.map(gone.contains) ?? false }
            state.reactions.removeAll { gone.contains($0.postID) }
            state.deletedMedia.append(id)
        }
    }

    func reactions(postIDs: [PostID]) async throws -> [Reaction] {
        try call("reactions")
        let wanted = Set(postIDs)
        return read { $0.reactions.filter { wanted.contains($0.postID) } }
    }

    func react(postID: PostID, emoji: String) async throws -> Reaction {
        try call("react")
        let me = read { $0.me } ?? UserID("me")
        if let existing = read({ $0.reactions.first { $0.postID == postID && $0.userID == me && $0.emoji == emoji } }) {
            return existing
        }
        guard let post = read({ $0.posts.first { $0.id == postID } }) else { throw DataError.api(.postNotFound) }
        let reaction = Reaction(postID: postID, userID: me, emoji: emoji, groupID: post.post.groupID, createdAt: tick())
        update { $0.reactions.append(reaction) }
        return reaction
    }

    func unreact(postID: PostID, emoji: String) async throws {
        try call("unreact")
        let me = read { $0.me } ?? UserID("me")
        update { $0.reactions.removeAll { $0.postID == postID && $0.userID == me && $0.emoji == emoji } }
    }

    func isTagged(postID: PostID, userID: UserID) async throws -> Bool {
        try call("isTagged")
        return read { $0.tags.contains { $0.postID == postID && $0.userID == userID } }
    }

    func tags(postID: PostID) async throws -> [PostTag] {
        try call("tags")
        return read { $0.tags.filter { $0.postID == postID }.sorted { $0.createdAt < $1.createdAt } }
    }

    func setTagged(_ tagged: Bool, postID: PostID) async throws {
        try call("setTagged")
        let me = read { $0.me } ?? UserID("me")
        guard let post = read({ $0.posts.first { $0.id == postID } }) else { throw DataError.api(.postNotFound) }
        update { state in
            state.tags.removeAll { $0.postID == postID && $0.userID == me }
            if tagged {
                state.tags.append(PostTag(postID: postID, userID: me, groupID: post.post.groupID, createdAt: state.now))
            }
        }
    }

    func block(userID: UserID) async throws {
        try call("block")
        update { $0.blocked.append(userID) }
    }

    func wall(userID: UserID, before: Date?, limit: Int) async throws -> Page<WallItem> {
        await hold("wall")
        try call("wall")
        return read { state in
            let all = (state.walls[userID] ?? Self.derivedWall(userID: userID, state: state))
                .filter { before == nil || $0.createdAt < before! }
            let page = Array(all.prefix(limit))
            return Page(items: page, nextCursor: page.count == limit ? page.last?.createdAt : nil)
        }
    }

    private static func derivedWall(userID: UserID, state: State) -> [WallItem] {
        var seenMedia = Set<MediaID>()
        return state.posts
            .filter { $0.post.authorID == userID }
            .sorted { $0.post.createdAt > $1.post.createdAt }
            .compactMap { post -> WallItem? in
                guard seenMedia.insert(post.post.mediaID).inserted else { return nil }
                return WallItem(
                    itemKind: .post, postID: post.id, mediaID: post.post.mediaID, collageID: nil,
                    groupIDs: [post.post.groupID], createdAt: post.post.createdAt
                )
            }
    }

    func cachedWall(userID: UserID) async -> [WallItem]? { read { $0.cachedWalls[userID] } }

    func collages(ids: [CollageID]) async throws -> [Collage] {
        try call("collages")
        return read { state in ids.compactMap { id in state.collages.first { $0.id == id } } }
    }

    func recaps(groupID: GroupID) async throws -> [WeeklyRecap] {
        try call("recaps")
        return read { $0.recaps.filter { $0.groupID == groupID }.sorted { $0.weekStart > $1.weekStart } }
    }

    func recap(id: RecapID) async throws -> WeeklyRecap? {
        await hold("recap")
        try call("recap")
        return read { $0.recaps.first { $0.id == id } }
    }

    func cachedRecap(id: RecapID) async -> WeeklyRecap? { read { $0.cachedRecaps[id] } }

    func updateRecap(id: RecapID, items: [PostID], text: String) async throws -> WeeklyRecap {
        try call("updateRecap")
        guard var recap = read({ $0.recaps.first { $0.id == id } }) else { throw DataError.api(.recapNotFound) }
        guard recap.status == .ready else { throw DataError.api(.recapNotReady) }
        recap.items = items
        recap.text = text.isEmpty ? nil : text
        recap.editedBy = read { $0.me }
        let updated = recap
        update { state in
            if let index = state.recaps.firstIndex(where: { $0.id == id }) { state.recaps[index] = updated }
        }
        return updated
    }

    func historyWeeks(groupID: GroupID, beforeWeek: LocalDate?) async throws -> [HistoryWeek] {
        await hold("historyWeeks")
        try call("historyWeeks")
        return read { state in
            let zone = state.groups.first { $0.id == groupID }?.resolvedTimeZone ?? TimeZone(identifier: "UTC")!
            let posts = state.posts.filter { $0.post.groupID == groupID }.sorted { $0.post.createdAt < $1.post.createdAt }
            var weeks: [LocalDate: [PostID]] = [:]
            for post in posts {
                weeks[SocialCalendar.weekStart(containing: post.post.createdAt, in: zone), default: []].append(post.id)
            }
            return weeks
                .filter { beforeWeek == nil || $0.key < beforeWeek! }
                .sorted { $0.key > $1.key }
                .prefix(SocialPaging.historyWeeks)
                .map { HistoryWeek(weekStart: $0.key, postIDs: $0.value) }
        }
    }

    func cachedHistoryWeeks(groupID: GroupID) async -> [HistoryWeek]? { read { $0.cachedHistory[groupID] } }

    func albums(groupID: GroupID) async throws -> [AlbumWithItems] {
        await hold("albums")
        try call("albums")
        return read { $0.albums.filter { $0.album.groupID == groupID }.sorted { $0.album.createdAt > $1.album.createdAt } }
    }

    func cachedAlbums(groupID: GroupID) async -> [AlbumWithItems]? { read { $0.cachedAlbums[groupID] } }

    func saveAlbum(groupID: GroupID, name: String, postIDs: [PostID]) async throws -> Album {
        try call("saveAlbum")
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DataError.api(.invalidName) }
        guard !postIDs.isEmpty, Set(postIDs).count == postIDs.count else { throw DataError.api(.invalidItems) }
        let created = tick()
        let album = Album(id: AlbumID(nextID()), groupID: groupID, name: trimmed, createdBy: read { $0.me }, createdAt: created, updatedAt: created)
        update { $0.albums.append(AlbumWithItems(album: album, postIDs: postIDs)) }
        return album
    }

    func renameAlbum(id: AlbumID, name: String) async throws -> Album {
        try call("renameAlbum")
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DataError.api(.invalidName) }
        guard var album = read({ $0.albums.first { $0.album.id == id } }) else { throw DataError.api(.albumNotFound) }
        album.album.name = trimmed
        let renamed = album
        update { state in
            if let index = state.albums.firstIndex(where: { $0.album.id == id }) { state.albums[index] = renamed }
        }
        return renamed.album
    }

    func deleteAlbum(id: AlbumID, groupID: GroupID) async throws {
        try call("deleteAlbum")
        update { $0.albums.removeAll { $0.album.id == id } }
    }

    func fileURL(path: String) async throws -> URL {
        try call("fileURL")
        return URL(fileURLWithPath: "/fake").appendingPathComponent(path)
    }

    func events(groupID: GroupID) -> AsyncStream<GroupEvent> {
        let (stream, continuation) = AsyncStream<GroupEvent>.makeStream()
        let id = UUID()
        lock.lock()
        continuations[groupID, default: [:]][id] = continuation
        lock.unlock()
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            self.lock.lock()
            self.continuations[groupID]?[id] = nil
            self.lock.unlock()
        }
        return stream
    }

    func network() -> AsyncStream<NetworkStatus> {
        let (stream, continuation) = AsyncStream<NetworkStatus>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        lock.lock()
        networkContinuations[id] = continuation
        let current = state.network
        lock.unlock()
        continuation.yield(current)
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            self.lock.lock()
            self.networkContinuations[id] = nil
            self.lock.unlock()
        }
        return stream
    }
}
#endif

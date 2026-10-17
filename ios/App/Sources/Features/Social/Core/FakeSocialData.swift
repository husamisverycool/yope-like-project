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
        /// Reactions on text / voice messages, one per person and message (`react_to_message` replaces).
        var messageReactions: [MessageReaction] = []
        /// `chat_typing` rows of every group.
        var typing: [ChatTyping] = []
        /// Each `set_typing` value sent, in order (kept apart from `calls`).
        var typingCalls: [Bool] = []
        /// `public_app_config`: nothing set by default (no Edit item, no typing calls).
        var config = PublicAppConfig()
        /// Selfie reactions, one per person and post (`react_with_selfie` replaces).
        var selfies: [SelfieReaction] = []
        /// Stores a sent selfie's JPEG and returns its storage path (the Jolt demo keeps the file so the face shows);
        /// nil: a `fake/selfie/<id>` path.
        var selfieUpload: (@Sendable (Data) -> String)?
        var tags: [PostTag] = []
        var collages: [Collage] = []
        /// Ready same-moment collages on their group-local day (`group_history_weeks.collages`), by group.
        var historyCollages: [GroupID: [GroupCollage]] = [:]
        var recaps: [WeeklyRecap] = []
        var albums: [AlbumWithItems] = []
        /// My private favorites (`favorites`): media → when favorited.
        var favorites: [MediaID: Date] = [:]
        /// Group covers set from a photo (`set_group_cover_from_post`).
        var coverPosts: [GroupID: PostID] = [:]
        /// Posts whose display rendition is not made yet (`media_not_ready`).
        var renditionsPending: Set<PostID> = []
        /// Wall items per person as `wall()` returns them (newest first); derived from posts when absent.
        var walls: [UserID: [WallItem]] = [:]
        var cachedMessages: [GroupID: [Message]] = [:]
        var cachedWalls: [UserID: [WallItem]] = [:]
        var cachedHistory: [GroupID: [HistoryWeek]] = [:]
        /// `group_history_months` per group; absent: derived from the posts and collages (as the RPC does).
        var historyMonths: [GroupID: [HistoryMonth]] = [:]
        /// Every `search_photos` query asked, with its `before` cursor, in order.
        var searches: [(query: PhotoSearchQuery, before: Date?)] = []
        var cachedAlbums: [GroupID: [AlbumWithItems]] = [:]
        var cachedGroups: [PhotoGroup]?
        var cachedMembers: [GroupID: [MemberProfile]] = [:]
        var cachedFeeds: [GroupID: [PostWithMedia]] = [:]
        var cachedRecaps: [RecapID: WeeklyRecap] = [:]
        var blocked: [UserID] = []
        var deletedMedia: [MediaID] = []
        var sentVoice: [(URL, Int)] = []
        /// The waveform sent with each voice message, in `sentVoice`'s order.
        var sentVoiceLevels: [[Int]?] = []
        var calls: [String] = []
        var messagePageSize = SocialPaging.messages
        /// Runs inside `sendText` / `sendVoice` before they return (e.g. the realtime echo arriving first).
        var beforeSendReturns: (@Sendable (Message) async -> Void)?
        var idCounter = 0
        var now = Date(timeIntervalSince1970: 1_792_000_000)
        /// The Jolt demo: new messages, reactions and albums carry the real time.
        var realClock = false
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
        state.now = state.realClock ? max(state.now.addingTimeInterval(1), Date()) : state.now.addingTimeInterval(60)
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

    func sendVoice(groupID: GroupID, fileURL: URL, durationMs: Int, levels: [Int]?) async throws -> Message {
        try call("sendVoice")
        let message = Message(
            id: MessageID(nextID()), groupID: groupID, authorID: read { $0.me } ?? UserID("me"), kind: .voice,
            voicePath: "fake/voice/\(fileURL.lastPathComponent)", voiceDurationMs: durationMs, voiceLevels: levels, createdAt: tick()
        )
        update {
            $0.messages.append(message)
            $0.sentVoice.append((fileURL, durationMs))
            $0.sentVoiceLevels.append(levels)
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
        update {
            $0.messages.removeAll { $0.id == id }
            $0.messageReactions.removeAll { $0.messageID == id }
        }
    }

    /// Like `edit_message`: my own text message gets the new body and `edited_at`; `message_not_found` otherwise.
    func editMessage(id: MessageID, body: String) async throws -> Message {
        await hold("editMessage")
        try call("editMessage")
        let me = read { $0.me }
        guard var message = read({ $0.messages.first { $0.id == id } }), message.authorID == me, message.kind == .text else {
            throw DataError.api(.messageNotFound)
        }
        if message.body != body {
            message.body = body
            message.editedAt = tick()
        }
        let edited = message
        update { state in
            if let index = state.messages.firstIndex(where: { $0.id == id }) { state.messages[index] = edited }
        }
        return edited
    }

    func publicConfig() async throws -> PublicAppConfig {
        try call("publicConfig")
        return read { $0.config }
    }

    func messageReactions(messageIDs: [MessageID]) async throws -> [MessageReaction] {
        try call("messageReactions")
        let wanted = Set(messageIDs)
        return read { $0.messageReactions.filter { wanted.contains($0.messageID) }.sorted { $0.createdAt < $1.createdAt } }
    }

    /// Like `react_to_message`: one per person — a new emoji replaces mine (new time).
    func reactToMessage(id: MessageID, emoji: String) async throws -> MessageReaction {
        try call("reactToMessage")
        let me = read { $0.me } ?? UserID("me")
        guard let message = read({ $0.messages.first { $0.id == id } }) else { throw DataError.api(.messageNotFound) }
        let row = MessageReaction(messageID: id, userID: me, emoji: emoji, groupID: message.groupID, createdAt: tick())
        update { state in
            state.messageReactions.removeAll { $0.messageID == id && $0.userID == me }
            state.messageReactions.append(row)
        }
        return row
    }

    func unreactToMessage(id: MessageID) async throws {
        try call("unreactToMessage")
        let me = read { $0.me } ?? UserID("me")
        update { $0.messageReactions.removeAll { $0.messageID == id && $0.userID == me } }
    }

    func typing(groupID: GroupID) async throws -> [ChatTyping] {
        try call("typing")
        return read { state in state.typing.filter { $0.groupID == groupID && $0.until > state.now } }
    }

    func setTyping(_ typing: Bool, groupID: GroupID) async throws {
        update { $0.typingCalls.append(typing) }
        try call("setTyping")
    }

    func posts(ids: [PostID]) async throws -> [PostWithMedia] {
        await hold("posts")
        try call("posts")
        return read { state in ids.compactMap { id in state.posts.first { $0.id == id } } }
    }

    func revealedWith(_ post: Post) async throws -> [PostWithMedia] {
        try call("revealedWith")
        guard let revealedAt = post.revealedAt else { return [] }
        return read { state in
            state.posts
                .filter { $0.post.groupID == post.groupID && $0.post.revealedAt == revealedAt }
                .sorted { ($0.post.createdAt, $0.id.rawValue) < ($1.post.createdAt, $1.id.rawValue) }
        }
    }

    func batchWith(_ post: Post) async throws -> [PostWithMedia] {
        try call("batchWith")
        guard let key = post.batchKey else { return [] }
        return read { state in
            state.posts
                .filter { $0.post.groupID == post.groupID && $0.post.batchKey == key }
                .sorted { ($0.post.createdAt, $0.id.rawValue) < ($1.post.createdAt, $1.id.rawValue) }
        }
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
            state.selfies.removeAll { gone.contains($0.postID) }
            state.favorites[id] = nil
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

    func selfieReactions(postIDs: [PostID]) async throws -> [SelfieReaction] {
        await hold("selfieReactions")
        try call("selfieReactions")
        let wanted = Set(postIDs)
        return read { $0.selfies.filter { wanted.contains($0.postID) }.sorted { $0.createdAt < $1.createdAt } }
    }

    /// Like `react_with_selfie`: `post_not_found`, `own_post`; a new selfie replaces mine (same row id, new time).
    func reactWithSelfie(postID: PostID, jpeg: Data) async throws -> SelfieReaction {
        await hold("reactWithSelfie")
        try call("reactWithSelfie")
        let me = read { $0.me } ?? UserID("me")
        guard let post = read({ $0.posts.first { $0.id == postID } }) else { throw DataError.api(.postNotFound) }
        guard post.post.authorID != me else { throw DataError.database(code: "PT400", message: "own_post") }
        let id = read { state in state.selfies.first { $0.postID == postID && $0.userID == me }?.id } ?? SelfieReactionID(nextID())
        let path = read { $0.selfieUpload }?(jpeg) ?? "fake/selfie/\(id.rawValue.suffix(2))"
        let selfie = SelfieReaction(id: id, postID: postID, userID: me, groupID: post.post.groupID, imagePath: path, createdAt: tick())
        update { state in
            state.selfies.removeAll { $0.postID == postID && $0.userID == me }
            state.selfies.append(selfie)
        }
        return selfie
    }

    /// Like `remove_selfie_reaction`: mine, or anyone's on my own post (`not_allowed` otherwise).
    func removeSelfieReaction(postID: PostID, userID: UserID?) async throws {
        try call("removeSelfieReaction")
        let me = read { $0.me } ?? UserID("me")
        let target = userID ?? me
        guard let post = read({ $0.posts.first { $0.id == postID } }) else { throw DataError.api(.postNotFound) }
        guard target == me || post.post.authorID == me else { throw DataError.database(code: "PT403", message: "not_allowed") }
        update { $0.selfies.removeAll { $0.postID == postID && $0.userID == target } }
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
        await hold("recaps")
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
        await hold("updateRecap")
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
                weeks[SocialCalendar.weekStart(containing: post.post.visibleAt, in: zone), default: []].append(post.id)
            }
            var collages: [LocalDate: [GroupCollage]] = [:]
            for collage in (state.historyCollages[groupID] ?? []).sorted(by: { $0.localDate < $1.localDate }) {
                let start = SocialCalendar.weekStart(containing: SocialCalendar.start(of: collage.localDate, in: zone), in: zone)
                collages[start, default: []].append(collage)
                if weeks[start] == nil { weeks[start] = [] }
            }
            return weeks
                .filter { beforeWeek == nil || $0.key < beforeWeek! }
                .sorted { $0.key > $1.key }
                .prefix(SocialPaging.historyWeeks)
                .map { HistoryWeek(weekStart: $0.key, postIDs: $0.value, collages: collages[$0.key] ?? []) }
        }
    }

    func cachedHistoryWeeks(groupID: GroupID) async -> [HistoryWeek]? { read { $0.cachedHistory[groupID] } }

    /// Like `group_history_months`: the group-local days with a photo (by `visible_at`) or a ready collage, per month,
    /// newest month first, each with the newest week touching it.
    func historyMonths(groupID: GroupID) async throws -> [HistoryMonth] {
        await hold("historyMonths")
        try call("historyMonths")
        return read { state in
            if let set = state.historyMonths[groupID] { return set }
            let zone = state.groups.first { $0.id == groupID }?.resolvedTimeZone ?? TimeZone(identifier: "UTC")!
            let days = Set(
                state.posts.filter { $0.post.groupID == groupID }.map { LocalDate($0.post.visibleAt, in: zone) }
                    + (state.historyCollages[groupID] ?? []).map(\.localDate)
            )
            let byMonth = Dictionary(grouping: days) { LocalDate(year: $0.year, month: $0.month, day: 1)! }
            return byMonth.keys.sorted(by: >).map { month in
                let list = (byMonth[month] ?? []).sorted()
                let newest = list.last ?? month
                return HistoryMonth(
                    month: month, days: list,
                    newestWeek: SocialCalendar.weekStart(containing: SocialCalendar.start(of: newest, in: zone), in: zone)
                )
            }
        }
    }

    /// Like `search_photos`: every criterion given must match — all the words (each a prefix, any case) in the caption or
    /// in one chat message replying to the photo; the member posted it or tagged themselves; the day taken (group-local)
    /// in `from…to`. One row per photo (the post in the query's group, else the first), newest first, a page at a time.
    func searchPhotos(_ query: PhotoSearchQuery, before: Date?) async throws -> [PhotoSearchHit] {
        await hold("searchPhotos")
        update { $0.searches.append((query, before)) }
        try call("searchPhotos")
        guard !query.isEmpty else { throw DataError.api(.invalidArgument) }
        return read { state in
            let words = Self.words(query.trimmedText)
            func matches(_ text: String?) -> Bool {
                guard let text, !words.isEmpty else { return false }
                let have = Self.words(text)
                return words.allSatisfy { word in have.contains { $0.hasPrefix(word) } }
            }
            var hits: [(PostWithMedia, [String])] = []
            for post in state.posts {
                let p = post.post
                if let group = query.groupID, p.groupID != group { continue }
                if let before, p.createdAt >= before { continue }
                if state.blocked.contains(p.authorID) { continue }
                var why: [String] = []
                if !words.isEmpty {
                    let byCaption = matches(p.caption)
                    let byChat = state.messages.contains { $0.replyToPostID == p.id && !state.blocked.contains($0.authorID) && matches($0.body) }
                    guard byCaption || byChat else { continue }
                    if byCaption { why.append("caption") }
                    if byChat { why.append("chat") }
                }
                if let member = query.memberID {
                    let byAuthor = p.authorID == member
                    let byTag = state.tags.contains { $0.postID == p.id && $0.userID == member }
                    guard byAuthor || byTag else { continue }
                    if byAuthor { why.append("author") }
                    if byTag { why.append("tag") }
                }
                if query.from != nil || query.to != nil {
                    let zone = state.groups.first { $0.id == p.groupID }?.resolvedTimeZone ?? TimeZone(identifier: "UTC")!
                    let day = LocalDate(p.createdAt, in: zone)
                    if let from = query.from, day < from { continue }
                    if let to = query.to, to < day { continue }
                    why.append("date")
                }
                hits.append((post, why))
            }
            // One row per photo: the post in the query's group, else the first posted.
            var best: [MediaID: (PostWithMedia, [String])] = [:]
            for hit in hits {
                let media = hit.0.post.mediaID
                guard let current = best[media] else { best[media] = hit; continue }
                let inGroup = { (post: PostWithMedia) in query.groupID.map { post.post.groupID == $0 } ?? false }
                if inGroup(hit.0) && !inGroup(current.0) || (inGroup(hit.0) == inGroup(current.0) && hit.0.post.createdAt < current.0.post.createdAt) {
                    best[media] = hit
                }
            }
            return best.values
                .sorted { ($0.0.post.createdAt, $1.0.id.rawValue) > ($1.0.post.createdAt, $0.0.id.rawValue) }
                .prefix(SocialPaging.search)
                .map { hit in
                    PhotoSearchHit(postID: hit.0.id, mediaID: hit.0.post.mediaID, groupID: hit.0.post.groupID, authorID: hit.0.post.authorID,
                                   createdAt: hit.0.post.createdAt, matched: hit.1)
                }
        }
    }

    /// Lower-cased words (letters and digits), as Postgres' `simple` configuration splits them.
    private static func words(_ text: String) -> [String] {
        text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    func albums(groupID: GroupID) async throws -> [AlbumWithItems] {
        await hold("albums")
        try call("albums")
        return read { $0.albums.filter { $0.album.groupID == groupID }.sorted { $0.album.createdAt > $1.album.createdAt } }
    }

    func cachedAlbums(groupID: GroupID) async -> [AlbumWithItems]? { read { $0.cachedAlbums[groupID] } }

    func saveAlbum(groupID: GroupID, name: String, postIDs: [PostID]) async throws -> Album {
        await hold("saveAlbum")
        try call("saveAlbum")
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DataError.api(.invalidName) }
        guard !postIDs.isEmpty, Set(postIDs).count == postIDs.count else { throw DataError.api(.invalidItems) }
        let created = tick()
        let me = read { $0.me }
        let album = Album(id: AlbumID(nextID()), groupID: groupID, name: trimmed, createdBy: me, createdAt: created, updatedAt: created)
        var adders: [PostID: UserID] = [:]
        if let me { for id in postIDs { adders[id] = me } }
        let saved = adders
        update { $0.albums.append(AlbumWithItems(album: album, postIDs: postIDs, addedBy: saved)) }
        return album
    }

    /// Like `add_to_album`: any member; photos already there are skipped; each new item is added by me.
    func addToAlbum(id: AlbumID, groupID: GroupID, postIDs: [PostID]) async throws -> Album {
        await hold("addToAlbum")
        try call("addToAlbum")
        guard !postIDs.isEmpty, Set(postIDs).count == postIDs.count else { throw DataError.api(.invalidItems) }
        guard var album = read({ $0.albums.first { $0.album.id == id } }) else { throw DataError.api(.albumNotFound) }
        let me = read { $0.me }
        var adders = album.addedBy ?? Dictionary(uniqueKeysWithValues: album.postIDs.compactMap { post in album.album.createdBy.map { (post, $0) } })
        for post in postIDs where !album.postIDs.contains(post) {
            album.postIDs.append(post)
            if let me { adders[post] = me }
        }
        album.addedBy = adders
        album.album.updatedAt = tick()
        let updated = album
        update { state in
            if let index = state.albums.firstIndex(where: { $0.album.id == id }) { state.albums[index] = updated }
        }
        return updated.album
    }

    /// Like `remove_from_album`: what I added; the creator and admins remove any (`not_allowed` otherwise).
    func removeFromAlbum(id: AlbumID, groupID: GroupID, postIDs: [PostID]) async throws {
        try call("removeFromAlbum")
        guard var album = read({ $0.albums.first { $0.album.id == id } }) else { throw DataError.api(.albumNotFound) }
        let me = read { $0.me }
        let isAdmin = read { state in state.members[groupID]?.contains { $0.member.userID == me && $0.member.role == .admin } ?? false }
        let manager = isAdmin || (me != nil && album.album.createdBy == me)
        if !manager, postIDs.contains(where: { album.postIDs.contains($0) && album.adder(of: $0) != me }) {
            throw DataError.database(code: "PT403", message: "not_allowed")
        }
        album.postIDs.removeAll { postIDs.contains($0) }
        let updated = album
        update { state in
            if let index = state.albums.firstIndex(where: { $0.album.id == id }) { state.albums[index] = updated }
        }
    }

    func setFavorite(_ on: Bool, mediaID: MediaID) async throws {
        try call("setFavorite")
        let now = tick()
        update { $0.favorites[mediaID] = on ? ($0.favorites[mediaID] ?? now) : nil }
    }

    func favoriteMediaIDs(among mediaIDs: [MediaID]) async throws -> Set<MediaID> {
        await hold("favoriteMediaIDs")
        try call("favoriteMediaIDs")
        return read { state in Set(mediaIDs.filter { state.favorites[$0] != nil }) }
    }

    /// Like `my_favorites`: newest favorite first, one row per photo (its first post).
    func favorites(before: Date?, limit: Int) async throws -> [FavoritePhoto] {
        await hold("favorites")
        try call("favorites")
        return read { state in
            state.favorites
                .filter { before == nil || $0.value < before! }
                .sorted { ($0.value, $1.key.rawValue) > ($1.value, $0.key.rawValue) }
                .compactMap { mediaID, favoritedAt -> FavoritePhoto? in
                    guard let post = state.posts.filter({ $0.post.mediaID == mediaID }).min(by: { $0.post.createdAt < $1.post.createdAt }),
                          let media = post.media else { return nil }
                    let group = state.groups.first { $0.id == post.post.groupID }
                    return FavoritePhoto(
                        mediaID: mediaID, postID: post.id, groupID: post.post.groupID, groupName: group?.name ?? "",
                        authorID: post.post.authorID, kind: media.kind, thumbPath: media.thumbPath ?? media.originalPath,
                        displayPath: media.displayPath ?? media.originalPath, widgetPath: nil,
                        takenAt: post.post.createdAt, favoritedAt: favoritedAt
                    )
                }
                .prefix(limit)
                .map { $0 }
        }
    }

    func cachedFavorites() async -> [FavoritePhoto]? { nil }

    /// Like `set_group_cover_from_post`: admins only (`not_group_admin`); `media_not_ready` before the rendition exists.
    func setGroupCover(groupID: GroupID, postID: PostID) async throws {
        try call("setGroupCover")
        let me = read { $0.me }
        let isAdmin = read { state in state.members[groupID]?.contains { $0.member.userID == me && $0.member.role == .admin } ?? false }
        guard isAdmin else { throw DataError.api(.notGroupAdmin) }
        guard read({ $0.posts.contains { $0.id == postID && $0.post.groupID == groupID } }) else { throw DataError.api(.postNotFound) }
        guard !read({ $0.renditionsPending.contains(postID) }) else { throw DataError.api(.mediaNotReady) }
        update { $0.coverPosts[groupID] = postID }
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

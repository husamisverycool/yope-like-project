// Surface: chat.thread (+ chat.composer, chat.voice, chat.reactions inside it) — reference app: Yope
// (reactions: Locket). Spec: design/surfaces/chat.thread.md "States", "Data & actions".
// View model only (Foundation + Observation + AppData); the view is ChatThreadView.
import AppData
import AppModels
import Foundation
import Observation

/// A reaction just sent by this person (starts the emoji rain on their screen, `chat.reactions` §4).
struct SentReaction: Equatable, Sendable {
    var postID: PostID
    var emoji: String
    var id: Int
}

@MainActor
@Observable
final class ChatThreadModel {
    let groupID: GroupID
    /// Deep link target (`DeepLink.chatMessage`): the thread scrolls to it once loaded.
    let focusMessageID: MessageID?
    @ObservationIgnored private let data: any SocialDataSource

    private(set) var phase: SocialPhase = .loading
    /// Reachability says offline, or the last request could not reach the server.
    private(set) var isOffline = false
    private(set) var me: UserID?
    private(set) var group: PhotoGroup?
    private(set) var members: [MemberProfile] = []
    /// Oldest first (top → bottom).
    private(set) var messages: [Message] = []
    private(set) var posts: [PostID: PostWithMedia] = [:]
    private(set) var reactions: [PostID: ReactionSummary] = [:]
    private(set) var profiles: [UserID: Profile] = [:]
    /// The latest ready recap (film-strip circle; hidden while nil).
    private(set) var latestRecapID: RecapID?
    /// Cursor of the next older page (nil = no older messages).
    private(set) var olderCursor: Date?
    private(set) var isLoadingOlder = false
    private(set) var isSending = false
    private(set) var signals = SocialSignals()
    /// The newest message someone else sent while the thread was open (announced to VoiceOver).
    private(set) var arrival: Message?
    private(set) var sentReaction: SentReaction?
    /// Composer text.
    var draft = ""
    /// Local copies of my messages not yet confirmed by the server (being sent, or failed), by their temporary id.
    private(set) var pending: Set<MessageID> = []
    /// Local copies whose send failed (`chat.thread.layout.failedMessage`); a tap sends them again.
    private(set) var failed: Set<MessageID> = []
    @ObservationIgnored private var outgoing: [MessageID: Outgoing] = [:]
    /// Recorded voice files of pending / just-sent voice messages, playable before the upload finishes.
    private(set) var localVoiceFiles: [MessageID: URL] = [:]
    /// The offline copy was looked at; the loading HUD shows only when there was none (no flash before cached content).
    private(set) var hasCheckedCache = false

    private var reactionCounter = 0
    private var localCounter = 0

    init(groupID: GroupID, focusMessageID: MessageID? = nil, data: any SocialDataSource) {
        self.groupID = groupID
        self.focusMessageID = focusMessageID
        self.data = data
    }

    // MARK: Derived

    var hasOlder: Bool { olderCursor != nil }

    /// The first-load HUD (`chat.thread` loading state).
    var showsLoading: Bool { phase == .loading && hasCheckedCache }

    func isPending(_ message: Message) -> Bool { pending.contains(message.id) }

    /// Photo posts of the thread in chronological order (`photo.viewer` context).
    var photoPostIDs: [PostID] {
        messages.compactMap { $0.kind == .photo ? $0.postID : nil }
    }

    func isMine(_ message: Message) -> Bool { message.authorID == me }

    func profile(_ id: UserID) -> Profile? { profiles[id] }

    /// Empty state: the viewer created the group (`chat.thread.empty.titleCreator`) or someone else did.
    var viewerCreatedGroup: Bool {
        guard let creator = group?.createdBy else { return false }
        return creator == me
    }

    var creatorFirstName: String? {
        guard let creator = group?.createdBy else { return nil }
        return profiles[creator]?.socialFirstName
    }

    /// First names of the members the creator added (`chat.thread.empty.detail`), joining order.
    var addedMemberNames: [String] {
        let creator = group?.createdBy
        return members.filter { $0.member.userID != creator }.compactMap { $0.profile?.socialFirstName }
    }

    // MARK: Loading

    /// First load: the offline copy at once, then the newest page from the server.
    func load() async {
        if me == nil { me = await data.currentUserID() }
        if messages.isEmpty, let cached = await data.cachedMessages(groupID: groupID), !cached.isEmpty {
            messages = Self.ascending(cached)
            for post in await data.cachedPosts(groupID: groupID) where posts[post.id] == nil {
                posts[post.id] = post
            }
            phase = .ready
        }
        hasCheckedCache = true
        await loadGroup()
        await refresh()
    }

    /// Reloads the newest page (pull, foreground, reconnect — docs/API.md §8.3).
    func refresh() async {
        do {
            let page = try await data.messages(groupID: groupID, before: nil)
            isOffline = false
            let newest = Self.ascending(page.items)
            let local = messages.filter { pending.contains($0.id) }
            if let oldestNew = newest.first, hasLoadedBeyondFirstPage {
                messages = messages.filter { $0.createdAt < oldestNew.createdAt && !pending.contains($0.id) } + newest
            } else {
                messages = newest
                olderCursor = page.nextCursor
            }
            for message in local where !messages.contains(where: { $0.id == message.id }) { insert(message) }
            await loadDetails(for: newest)
            phase = messages.isEmpty ? .empty : .ready
            await loadLatestRecap()
        } catch {
            let failure = SocialFailure(error)
            if failure == .offline { isOffline = true }
            if messages.isEmpty {
                phase = isOffline ? .offline : .failed
            } else {
                phase = .ready
            }
        }
    }

    /// Error state "try again".
    func retry() async {
        phase = .loading
        await load()
    }

    /// Next older page, when the list reaches its top.
    func loadOlder() async {
        guard let cursor = olderCursor, !isLoadingOlder else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let page = try await data.messages(groupID: groupID, before: cursor)
            let known = Set(messages.map(\.id))
            let older = Self.ascending(page.items).filter { !known.contains($0.id) }
            messages = older + messages
            olderCursor = page.nextCursor
            pagesBeyondFirst += 1
            await loadDetails(for: older)
        } catch {
            if SocialFailure(error) == .offline { isOffline = true }
        }
    }

    @ObservationIgnored private var pagesBeyondFirst = 0
    private var hasLoadedBeyondFirstPage: Bool { pagesBeyondFirst > 0 }

    private func loadGroup() async {
        if let group = try? await data.group(id: groupID) {
            self.group = group
        } else if group == nil {
            group = await data.cachedGroup(id: groupID)
        }
        if let members = try? await data.members(groupID: groupID) {
            self.members = members
        } else if members.isEmpty {
            members = await data.cachedMembers(groupID: groupID) ?? []
        }
        for member in members {
            if let profile = member.profile { profiles[profile.id] = profile }
        }
    }

    private func loadLatestRecap() async {
        guard let recaps = try? await data.recaps(groupID: groupID) else { return }
        latestRecapID = recaps.first { $0.status == .ready }?.id
    }

    private func loadPosts(_ wanted: [PostID]) async {
        guard !wanted.isEmpty else { return }
        if let found = try? await data.posts(ids: wanted) {
            for post in found { posts[post.id] = post }
        } else {
            for post in await data.cachedPosts(ids: wanted, groupID: groupID) { posts[post.id] = post }
        }
    }

    /// Posts (photo messages and reply targets), their reactions, and authors' profiles.
    private func loadDetails(for batch: [Message]) async {
        let photoIDs = batch.compactMap(\.postID)
        let wanted = (photoIDs + batch.compactMap(\.replyToPostID)).socialUnique().filter { posts[$0] == nil }
        await loadPosts(wanted)
        // Photo replies to a photo (`posts.reply_to_post_id`): their quoted photo too.
        await loadPosts(photoIDs.compactMap { posts[$0]?.post.replyToPostID }.socialUnique().filter { posts[$0] == nil })
        if !photoIDs.isEmpty, let rows = try? await data.reactions(postIDs: photoIDs) {
            let summaries = ReactionSummary.byPost(rows)
            for id in photoIDs.socialUnique() {
                reactions[id] = summaries[id] ?? ReactionSummary()
            }
        }
        let people = (batch.map(\.authorID) + posts.values.map(\.post.authorID))
            .socialUnique()
            .filter { profiles[$0] == nil }
        if !people.isEmpty, let found = try? await data.profiles(ids: people) {
            for profile in found { profiles[profile.id] = profile }
        }
    }

    // MARK: Live

    /// Realtime and reachability for as long as the screen is visible (`.task`).
    func run() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.listenToEvents() }
            group.addTask { await self.listenToNetwork() }
        }
    }

    private func listenToEvents() async {
        for await event in data.events(groupID: groupID) {
            await handle(event)
        }
    }

    private func listenToNetwork() async {
        for await status in data.network() {
            await setNetwork(status)
        }
    }

    func setNetwork(_ status: NetworkStatus) async {
        let wasOffline = isOffline
        switch status {
        case .offline:
            isOffline = true
        case .online:
            isOffline = false
            if wasOffline { await refresh() }
        case .unknown:
            break
        }
    }

    /// Applies one realtime event (docs/API.md §8.1–8.2).
    func handle(_ event: GroupEvent) async {
        switch event {
        case let .messageInserted(message):
            guard message.groupID == groupID, !messages.contains(where: { $0.id == message.id }) else { return }
            removePendingCopy(of: message)
            insert(message)
            await loadDetails(for: [message])
            phase = .ready
            if message.authorID != me { arrival = message }
        case let .messageUpdated(message):
            guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
            messages[index] = message
        case let .postInserted(post), let .postUpdated(post):
            guard post.groupID == groupID, let known = posts[post.id] else { return }
            posts[post.id] = PostWithMedia(post: post, media: known.media)
        case let .postDeleted(postID, _):
            removePost(postID)
        case let .messageDeleted(messageID):
            messages.removeAll { $0.id == messageID }
            if messages.isEmpty, phase == .ready { phase = .empty }
        case let .reactionInserted(reaction):
            guard posts[reaction.postID] != nil || messages.contains(where: { $0.postID == reaction.postID }) else { return }
            reactions[reaction.postID, default: ReactionSummary()].insert(reaction)
        case let .reactionsChanged(postID):
            await reloadReactions(postID)
        case .resubscribed:
            await refresh()
        case .subscribed, .subscriptionFailed:
            break
        }
    }

    /// `post_deleted`: the photo message goes; replies to it lose their quote part.
    private func removePost(_ postID: PostID) {
        messages.removeAll { $0.kind == .photo && $0.postID == postID }
        for index in messages.indices where messages[index].replyToPostID == postID {
            messages[index].replyToPostID = nil
        }
        for id in posts.keys where posts[id]?.post.replyToPostID == postID {
            posts[id]?.post.replyToPostID = nil
        }
        posts[postID] = nil
        reactions[postID] = nil
        if messages.isEmpty, phase == .ready { phase = .empty }
    }

    private func reloadReactions(_ postID: PostID) async {
        guard let rows = try? await data.reactions(postIDs: [postID]) else { return }
        reactions[postID] = ReactionSummary(rows)
    }

    private func insert(_ message: Message) {
        let index = messages.firstIndex { Self.isOrdered(message, before: $0) } ?? messages.endIndex
        messages.insert(message, at: index)
    }

    // MARK: Composer

    /// What a local message sends (kept for a retry after a failure).
    private enum Outgoing {
        case text(String)
        case voice(URL, durationMs: Int)
    }

    /// Sends the composer text (`send_message`, kind text): the message shows at once (optimistic) and is replaced
    /// by the server's row. On failure it stays with the failed-message layout (`chat.thread.layout.failedMessage`:
    /// red "!" and `chat.thread.sendFailed`); tapping it sends it again.
    func sendDraft() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, let me else { return }
        draft = ""
        let local = makeLocal(Message(id: nextLocalID(), groupID: groupID, authorID: me, kind: .text, body: body, createdAt: Date()))
        outgoing[local.id] = .text(body)
        await deliver(local.id)
    }

    /// Uploads and sends a recorded voice message (`chat.voice`); shown at once, playable from the local file.
    func sendVoice(fileURL: URL, durationMs: Int) async {
        guard durationMs > 0, let me else { return }
        let local = makeLocal(Message(
            id: nextLocalID(), groupID: groupID, authorID: me, kind: .voice, voiceDurationMs: durationMs, createdAt: Date()
        ))
        localVoiceFiles[local.id] = fileURL
        outgoing[local.id] = .voice(fileURL, durationMs: durationMs)
        await deliver(local.id)
    }

    /// Tap on a failed message (its "!", label or bubble): sends it again.
    func retry(_ message: Message) async {
        guard failed.contains(message.id) else { return }
        failed.remove(message.id)
        await deliver(message.id)
    }

    func isFailed(_ message: Message) -> Bool { failed.contains(message.id) }

    private func deliver(_ localID: MessageID) async {
        guard let payload = outgoing[localID], messages.contains(where: { $0.id == localID }) else { return }
        isSending = true
        do {
            let message: Message
            switch payload {
            case let .text(body):
                message = try await data.sendText(groupID: groupID, body: body, replyToPostID: nil)
            case let .voice(fileURL, durationMs):
                message = try await data.sendVoice(groupID: groupID, fileURL: fileURL, durationMs: durationMs)
                localVoiceFiles[message.id] = fileURL
            }
            outgoing[localID] = nil
            isOffline = false
            confirm(localID, with: message)
            signals.emit(.sent)
        } catch {
            // Taken back meanwhile (deleted while sending, or confirmed by its realtime echo).
            guard messages.contains(where: { $0.id == localID }), pending.contains(localID) else {
                isSending = !inFlight.isEmpty
                return
            }
            failed.insert(localID)
            isSending = !inFlight.isEmpty
            if SocialFailure(error) == .offline { isOffline = true }
            signals.emit(.failed)
            signals.post(.messageNotSent)
        }
    }

    /// Recording could not start or finish (`chat.voice.error.record`).
    func voiceRecordingFailed() {
        signals.emit(.failed)
        signals.post(.recordFailed)
    }

    private func nextLocalID() -> MessageID {
        localCounter += 1
        return MessageID("local-" + String(localCounter))
    }

    /// Inserts the optimistic copy after everything already shown.
    private func makeLocal(_ draft: Message) -> Message {
        var local = draft
        if let last = messages.last, last.createdAt >= local.createdAt {
            local.createdAt = last.createdAt.addingTimeInterval(1)
        }
        pending.insert(local.id)
        messages.append(local)
        phase = .ready
        return local
    }

    private func confirm(_ localID: MessageID, with message: Message) {
        pending.remove(localID)
        failed.remove(localID)
        isSending = !inFlight.isEmpty
        guard let index = messages.firstIndex(where: { $0.id == localID }) else {
            if !messages.contains(where: { $0.id == message.id }) { insert(message) }
            return
        }
        if messages.contains(where: { $0.id == message.id }) {
            messages.remove(at: index)
        } else {
            messages[index] = message
        }
    }

    /// Local copies being sent right now (not failed).
    private var inFlight: Set<MessageID> { pending.subtracting(failed) }

    /// A realtime insert of my own message replaces its optimistic copy.
    private func removePendingCopy(of message: Message) {
        guard message.authorID == me, !pending.isEmpty else { return }
        guard let local = messages.first(where: { candidate in
            pending.contains(candidate.id) && candidate.kind == message.kind
                && candidate.body == message.body && candidate.voiceDurationMs == message.voiceDurationMs
        }) else { return }
        pending.remove(local.id)
        failed.remove(local.id)
        outgoing[local.id] = nil
        if let file = localVoiceFiles[local.id] { localVoiceFiles[message.id] = file }
        messages.removeAll { $0.id == local.id }
        isSending = !inFlight.isEmpty
    }

    // MARK: Messages

    /// Deletes one of my text / voice messages after the native confirmation: gone at once, put back if the
    /// call fails.
    func delete(_ message: Message) async {
        guard isMine(message), message.kind != .photo,
              let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        if pending.contains(message.id) {
            // A failed local copy never reached the server: it just goes.
            guard failed.contains(message.id) else { return }
            signals.emit(.warning)
            messages.remove(at: index)
            pending.remove(message.id)
            failed.remove(message.id)
            outgoing[message.id] = nil
            localVoiceFiles[message.id] = nil
            if messages.isEmpty { phase = .empty }
            return
        }
        signals.emit(.warning)
        messages.remove(at: index)
        if messages.isEmpty { phase = .empty }
        do {
            try await data.deleteMessage(id: message.id, groupID: groupID)
        } catch {
            if SocialFailure(error) == .notFound { return }
            if SocialFailure(error) == .offline { isOffline = true }
            insert(message)
            phase = .ready
            signals.emit(.failed)
        }
    }

    // MARK: Reactions

    /// `react` with optimistic display: the sticker appears at once and is removed if the call fails.
    func react(postID: PostID, emoji: String) async {
        guard let me else { return }
        let alreadyThere = reactions[postID]?.contains(userID: me, emoji: emoji) ?? false
        if !alreadyThere {
            reactions[postID, default: ReactionSummary()].insert(
                Reaction(postID: postID, userID: me, emoji: emoji, groupID: groupID, createdAt: Date())
            )
        }
        reactionCounter += 1
        sentReaction = SentReaction(postID: postID, emoji: emoji, id: reactionCounter)
        do {
            _ = try await data.react(postID: postID, emoji: emoji)
        } catch {
            if !alreadyThere { reactions[postID]?.remove(userID: me, emoji: emoji) }
            signals.emit(.failed)
            signals.post(.reactionFailed)
        }
    }

    /// The emoji I reacted with on a post (highlighted in the picker).
    func myEmoji(on postID: PostID) -> Set<String> {
        guard let me else { return [] }
        return reactions[postID]?.emoji(by: me) ?? []
    }

    /// `unreact` from the picker's highlighted emoji (`chat.reactions.layout.unreact`): optimistic, restored on failure.
    func unreact(postID: PostID, emoji: String) async {
        guard let me, let before = reactions[postID], before.contains(userID: me, emoji: emoji) else { return }
        reactions[postID]?.remove(userID: me, emoji: emoji)
        do {
            try await data.unreact(postID: postID, emoji: emoji)
        } catch {
            if SocialFailure(error) == .notFound { return }
            reactions[postID] = before
            signals.emit(.failed)
            signals.post(.reactionFailed)
        }
    }

    // MARK: Ordering

    private static func isOrdered(_ lhs: Message, before rhs: Message) -> Bool {
        lhs.createdAt != rhs.createdAt ? lhs.createdAt < rhs.createdAt : lhs.id < rhs.id
    }

    private static func ascending(_ page: [Message]) -> [Message] {
        page.sorted(by: isOrdered)
    }
}

/// The vertical gap above a message (`chat.thread` "Message geometry"); the view maps each to its token.
enum ChatGap: Equatable, Sendable {
    /// First message of the list.
    case none
    /// Same sender, bubble → bubble (`chat.thread.dimension.gapSameSender`).
    case sameSender
    /// Same sender, text → voice (`chat.thread.dimension.gapTextToVoice`).
    case textToVoice
    /// Same sender, photo → photo (`chat.thread.dimension.photoGap`); also photo ↔ bubble (not measured:
    /// the photo gap is used, spec Gaps).
    case photo
    /// Runs of different senders (`chat.thread.dimension.gapBetweenSenders`).
    case betweenSenders
}

/// One row of the thread: the message, its gap above, and whether the sender's avatar sits beside it
/// (another member's message, last of its run).
struct ChatRowLayout: Identifiable, Equatable, Sendable {
    let message: Message
    let gap: ChatGap
    let showsAvatar: Bool
    let isMine: Bool

    var id: MessageID { message.id }

    static func rows(_ messages: [Message], me: UserID?) -> [ChatRowLayout] {
        messages.indices.map { index in
            let message = messages[index]
            let previous = index > 0 ? messages[index - 1] : nil
            let next = index + 1 < messages.count ? messages[index + 1] : nil
            let isMine = message.authorID == me
            return ChatRowLayout(
                message: message,
                gap: previous.map { gap(from: $0, to: message) } ?? .none,
                showsAvatar: !isMine && next?.authorID != message.authorID,
                isMine: isMine
            )
        }
    }

    static func gap(from previous: Message, to message: Message) -> ChatGap {
        guard previous.authorID == message.authorID else { return .betweenSenders }
        if previous.kind == .photo || message.kind == .photo { return .photo }
        if previous.kind == .text, message.kind == .voice { return .textToVoice }
        return .sameSender
    }
}

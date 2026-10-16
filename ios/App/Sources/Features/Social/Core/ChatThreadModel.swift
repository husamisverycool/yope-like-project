// Surface: chat.thread (+ chat.composer, chat.voice, chat.reactions inside it) — Retro comment rows composed in Apple
// Messages / WhatsApp's order. Spec: design/surfaces/chat.thread.md "States", "Data & actions".
// View model only (Foundation + Observation + AppData); the view is ChatThreadView.
import AppData
import AppModels
import Foundation
import Observation

/// What the composer's reply bar quotes (`chat.thread.layout.replyQuote`, Retro "Reply").
enum ChatReplyTarget: Equatable, Sendable {
    /// A photo message: the reply quotes its post (`p_reply_to_post_id`).
    case post(PostID, author: UserID)
    /// A text or voice message (`p_reply_to_message_id`).
    case message(MessageID, author: UserID)

    var author: UserID {
        switch self {
        case let .post(_, author), let .message(_, author): return author
        }
    }
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
    /// Quoted messages that are not in the loaded pages (fetched by id).
    private(set) var quotedMessages: [MessageID: Message] = [:]
    /// Cursor of the next older page (nil = no older messages).
    private(set) var olderCursor: Date?
    private(set) var isLoadingOlder = false
    private(set) var isSending = false
    private(set) var signals = SocialSignals()
    /// The newest message someone else sent while the thread was open (announced to VoiceOver).
    private(set) var arrival: Message?
    /// `chat.thread.layout.followNewest`: my newest message the list has to bring into view — sent from the composer, or
    /// arriving from elsewhere (the photo viewer's reply field). The view scrolls to it once the thread shows and calls
    /// `didFollow(_:)`; others' messages never set it (they are followed only while the reader is at the bottom).
    private(set) var followRequest: MessageID?
    /// Composer text.
    var draft = ""
    /// The message or photo the composer replies to (the reply bar shows while set).
    private(set) var replyTarget: ChatReplyTarget?
    /// Local copies of my messages not yet confirmed by the server (being sent, or failed), by their temporary id.
    private(set) var pending: Set<MessageID> = []
    /// Local copies whose send failed (`chat.thread.layout.failedMessage`); a tap sends them again.
    private(set) var failed: Set<MessageID> = []
    @ObservationIgnored private var outgoing: [MessageID: Outgoing] = [:]
    /// Recorded voice files of pending / just-sent voice messages, playable before the upload finishes.
    private(set) var localVoiceFiles: [MessageID: URL] = [:]
    /// The offline copy was looked at; the loading indicator shows only when there was none (no flash before cached
    /// content).
    private(set) var hasCheckedCache = false
    /// Add-only photo access was denied on "Save": the native alert with the Settings link shows.
    var saveDenied = false

    private var localCounter = 0

    init(groupID: GroupID, focusMessageID: MessageID? = nil, data: any SocialDataSource) {
        self.groupID = groupID
        self.focusMessageID = focusMessageID
        self.data = data
    }

    // MARK: Derived

    var hasOlder: Bool { olderCursor != nil }

    /// The first-load indicator (`chat.thread` loading state).
    var showsLoading: Bool { phase == .loading && hasCheckedCache }

    func isPending(_ message: Message) -> Bool { pending.contains(message.id) && !failed.contains(message.id) }

    func isFailed(_ message: Message) -> Bool { failed.contains(message.id) }

    /// Photo posts of the thread in chronological order (`photo.viewer` context).
    var photoPostIDs: [PostID] {
        messages.compactMap { $0.kind == .photo ? $0.postID : nil }
    }

    func isMine(_ message: Message) -> Bool { message.authorID == me }

    func profile(_ id: UserID) -> Profile? { profiles[id] }

    func post(of message: Message) -> PostWithMedia? { message.postID.flatMap { posts[$0] } }

    /// The time zone of the group (week numbers of quoted posts).
    var timeZone: TimeZone { group?.resolvedTimeZone ?? .current }

    /// The photo a message quotes: a text reply's `reply_to_post_id`, or a photo reply's post `reply_to_post_id`.
    func quotedPost(of message: Message) -> PostWithMedia? {
        if let id = message.replyToPostID { return posts[id] }
        if message.kind == .photo, let id = post(of: message)?.post.replyToPostID { return posts[id] }
        return nil
    }

    /// The message a message quotes (`reply_to_message_id`), when it still exists.
    func quotedMessage(of message: Message) -> Message? {
        guard let id = message.replyToMessageID else { return nil }
        return messages.first { $0.id == id } ?? quotedMessages[id]
    }

    func hasQuote(_ message: Message) -> Bool {
        quotedPost(of: message) != nil || quotedMessage(of: message) != nil
    }

    /// The thread as day dividers and runs (`chat.thread.layout.runs`, `.timeFormat.dayDividers`).
    func entries(calendar: Calendar = .current) -> [ChatEntry] {
        ChatThreadLayout.entries(messages, me: me, calendar: calendar) { [self] in hasQuote($0) }
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
            let known = Set(messages.map(\.id))
            let newest = Self.ascending(page.items)
            let local = messages.filter { pending.contains($0.id) }
            if let oldestNew = newest.first, hasLoadedBeyondFirstPage {
                messages = messages.filter { $0.createdAt < oldestNew.createdAt && !pending.contains($0.id) } + newest
            } else {
                messages = newest
                olderCursor = page.nextCursor
            }
            for message in local where !messages.contains(where: { $0.id == message.id }) { insert(message) }
            if !known.isEmpty, let last = messages.last, isMine(last), !known.contains(last.id), !pending.contains(last.id) {
                followRequest = last.id
            }
            await loadDetails(for: newest)
            phase = messages.isEmpty ? .empty : .ready
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

    /// Error state "Try Again".
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

    private func loadPosts(_ wanted: [PostID]) async {
        guard !wanted.isEmpty else { return }
        if let found = try? await data.posts(ids: wanted) {
            for post in found { posts[post.id] = post }
        } else {
            for post in await data.cachedPosts(ids: wanted, groupID: groupID) { posts[post.id] = post }
        }
    }

    /// Posts (photo messages and quoted photos), quoted messages, reactions, and the people behind them.
    private func loadDetails(for batch: [Message]) async {
        let photoIDs = batch.compactMap(\.postID)
        let wanted = (photoIDs + batch.compactMap(\.replyToPostID)).socialUnique().filter { posts[$0] == nil }
        await loadPosts(wanted)
        // Photo replies to a photo (`posts.reply_to_post_id`): their quoted photo too.
        await loadPosts(photoIDs.compactMap { posts[$0]?.post.replyToPostID }.socialUnique().filter { posts[$0] == nil })
        let known = Set(messages.map(\.id))
        let missingQuotes = batch.compactMap(\.replyToMessageID).socialUnique()
            .filter { !known.contains($0) && quotedMessages[$0] == nil }
        for id in missingQuotes {
            if let found = try? await data.message(id: id) { quotedMessages[id] = found }
        }
        if !photoIDs.isEmpty, let rows = try? await data.reactions(postIDs: photoIDs) {
            let summaries = ReactionSummary.byPost(rows)
            for id in photoIDs.socialUnique() {
                reactions[id] = summaries[id] ?? ReactionSummary()
            }
        }
        let reactors = photoIDs.flatMap { reactions[$0]?.rows.map(\.userID) ?? [] }
        let people = (batch.map(\.authorID) + posts.values.map(\.post.authorID) + quotedMessages.values.map(\.authorID) + reactors)
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
            let replacesPendingCopy = followRequest.map { pending.contains($0) } ?? false
            removePendingCopy(of: message)
            insert(message)
            if message.authorID == me, messages.last?.id == message.id || replacesPendingCopy { followRequest = message.id }
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
            removeMessage(messageID)
        case let .reactionInserted(reaction):
            guard posts[reaction.postID] != nil || messages.contains(where: { $0.postID == reaction.postID }) else { return }
            reactions[reaction.postID, default: ReactionSummary()].insert(reaction)
            if profiles[reaction.userID] == nil, let found = try? await data.profiles(ids: [reaction.userID]) {
                for profile in found { profiles[profile.id] = profile }
            }
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
        if case let .post(id, _)? = replyTarget, id == postID { replyTarget = nil }
        if messages.isEmpty, phase == .ready { phase = .empty }
    }

    /// `message_deleted`: the message goes; replies to it lose their quote part.
    private func removeMessage(_ messageID: MessageID) {
        messages.removeAll { $0.id == messageID }
        quotedMessages[messageID] = nil
        for index in messages.indices where messages[index].replyToMessageID == messageID {
            messages[index].replyToMessageID = nil
        }
        if case let .message(id, _)? = replyTarget, id == messageID { replyTarget = nil }
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

    /// The list has brought `id` into view (`chat.thread.layout.followNewest`).
    func didFollow(_ id: MessageID) {
        if followRequest == id { followRequest = nil }
    }

    // MARK: Replies

    /// Context menu "Reply": the reply bar shows above the field (`chat.composer.placeholderReply`).
    func startReply(to message: Message) {
        guard !pending.contains(message.id) else { return }
        if message.kind == .photo, let postID = message.postID {
            replyTarget = .post(postID, author: message.authorID)
        } else {
            replyTarget = .message(message.id, author: message.authorID)
        }
    }

    /// The reply bar's close glyph.
    func cancelReply() {
        replyTarget = nil
    }

    /// The post a photo sent from the composer's camera replies to (`create_post(p_reply_to_post_id)`).
    var replyPostID: PostID? {
        if case let .post(id, _)? = replyTarget { return id }
        return nil
    }

    // MARK: Composer

    /// What a local message sends (kept for a retry after a failure).
    private enum Outgoing {
        case text(String, replyToPost: PostID?, replyToMessage: MessageID?)
        case voice(URL, durationMs: Int, levels: [Int]?)
    }

    /// Sends the composer text (`send_message`, kind text, with the reply ids): the message shows at once (optimistic)
    /// with `chat.thread.sending` under it and is replaced by the server's row. On failure it stays with
    /// `chat.thread.sendFailed` (`chat.thread.layout.failedMessage`); tapping it sends it again.
    func sendDraft() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, let me else { return }
        draft = ""
        var replyToPost: PostID?
        var replyToMessage: MessageID?
        switch replyTarget {
        case let .post(id, _)?: replyToPost = id
        case let .message(id, _)?: replyToMessage = id
        case nil: break
        }
        replyTarget = nil
        let local = makeLocal(Message(
            id: nextLocalID(), groupID: groupID, authorID: me, kind: .text, body: body,
            replyToPostID: replyToPost, replyToMessageID: replyToMessage, createdAt: Date()
        ))
        outgoing[local.id] = .text(body, replyToPost: replyToPost, replyToMessage: replyToMessage)
        await deliver(local.id)
    }

    /// Uploads and sends a recorded voice message with its waveform (`chat.voice`, C-36); shown at once, playable from
    /// the local file.
    func sendVoice(fileURL: URL, durationMs: Int, levels: [Int]? = nil) async {
        guard durationMs > 0, let me else { return }
        let waveform = levels.flatMap { VoiceLevels.isValid($0) ? $0 : nil }
        let local = makeLocal(Message(
            id: nextLocalID(), groupID: groupID, authorID: me, kind: .voice, voiceDurationMs: durationMs, voiceLevels: waveform,
            createdAt: Date()
        ))
        localVoiceFiles[local.id] = fileURL
        outgoing[local.id] = .voice(fileURL, durationMs: durationMs, levels: waveform)
        await deliver(local.id)
    }

    /// Tap on a failed message (or its status line, or "Retry"): sends it again.
    func retry(_ message: Message) async {
        guard failed.contains(message.id) else { return }
        failed.remove(message.id)
        await deliver(message.id)
    }

    private func deliver(_ localID: MessageID) async {
        guard let payload = outgoing[localID], messages.contains(where: { $0.id == localID }) else { return }
        isSending = true
        do {
            let message: Message
            switch payload {
            case let .text(body, replyToPost, replyToMessage):
                message = try await data.sendText(
                    groupID: groupID, body: body, replyToPostID: replyToPost, replyToMessageID: replyToMessage
                )
            case let .voice(fileURL, durationMs, levels):
                message = try await data.sendVoice(groupID: groupID, fileURL: fileURL, durationMs: durationMs, levels: levels)
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
        followRequest = local.id
        phase = .ready
        return local
    }

    private func confirm(_ localID: MessageID, with message: Message) {
        if followRequest == localID { followRequest = message.id }
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

    /// "Copy" on a text message: the composer's view puts it on the pasteboard; this confirms it
    /// (`chat.thread.toast.copied`: Android Toast, iOS announcement).
    func copied() {
        signals.post(.copied)
    }

    /// "Unsend" one of my text / voice messages after the confirmation: gone at once, put back if the call fails.
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

    /// "Delete" on my photo message after `photo.viewer`'s confirmation: `delete_media` removes it everywhere; it goes
    /// at once and comes back if the call fails.
    func deletePhoto(_ message: Message) async {
        guard isMine(message), message.kind == .photo, let post = post(of: message) else { return }
        signals.emit(.warning)
        let snapshot = (messages, posts, reactions)
        let removed = Set(posts.values.filter { $0.post.mediaID == post.post.mediaID }.map(\.id)).union([post.id])
        for id in removed { removePost(id) }
        do {
            try await data.deleteMedia(id: post.post.mediaID)
            signals.post(.photoDeleted)
        } catch {
            if SocialFailure(error) == .notFound { return }
            if SocialFailure(error) == .offline { isOffline = true }
            (messages, posts, reactions) = snapshot
            phase = messages.isEmpty ? .empty : .ready
            signals.emit(.failed)
            signals.post(.deleteFailed)
        }
    }

    /// "Save" on your own photo message (as `photo.viewer`'s Save to Camera Roll); someone else's photo never leaves the
    /// app (owner decision 12).
    func savePhoto(_ message: Message, using saver: any SocialPhotoSaving) async {
        guard isMine(message), let media = post(of: message)?.media else { return }
        do {
            let fileURL = try await data.fileURL(path: media.originalPath)
            var motionURL: URL?
            if media.kind == .livePhoto, let motionPath = media.motionPath {
                motionURL = try await data.fileURL(path: motionPath)
            }
            try await saver.save(kind: media.kind, fileURL: fileURL, motionURL: motionURL)
            signals.emit(.success)
            signals.post(.photoSaved)
        } catch SocialSaveFailure.notAuthorized {
            saveDenied = true
            signals.emit(.failed)
        } catch {
            if SocialFailure(error) == .offline { isOffline = true }
            signals.emit(.failed)
            signals.post(.saveFailed)
        }
    }

    // MARK: Reactions

    /// `react` with optimistic display: the chip updates at once and the emoji goes again if the call fails.
    func react(postID: PostID, emoji: String) async {
        guard let me else { return }
        let alreadyThere = reactions[postID]?.contains(userID: me, emoji: emoji) ?? false
        if !alreadyThere {
            reactions[postID, default: ReactionSummary()].insert(
                Reaction(postID: postID, userID: me, emoji: emoji, groupID: groupID, createdAt: Date())
            )
        }
        do {
            _ = try await data.react(postID: postID, emoji: emoji)
        } catch {
            if !alreadyThere { reactions[postID]?.remove(userID: me, emoji: emoji) }
            signals.emit(.failed)
            signals.post(.reactionFailed)
        }
    }

    /// A quick reaction from the context menu: an emoji I already used takes it back
    /// (`chat.reactions.layout.unreact.menu`), any other reacts.
    func toggleReaction(postID: PostID, emoji: String) async {
        if myEmoji(on: postID).contains(emoji) {
            await unreact(postID: postID, emoji: emoji)
        } else {
            await react(postID: postID, emoji: emoji)
        }
    }

    /// The emoji I reacted with on a post (selected in the quick row and the picker).
    func myEmoji(on postID: PostID) -> Set<String> {
        guard let me else { return [] }
        return reactions[postID]?.emoji(by: me) ?? []
    }

    /// `unreact` (`chat.reactions.layout.unreact`): optimistic, restored on failure.
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

// MARK: - Layout

/// The space above an entry of the thread (`chat.thread.layout.runs.spacing`); the view maps each to its token.
enum ChatGap: Equatable, Sendable {
    /// The first entry of the list.
    case none
    /// The next item of the same run (`chat.thread.dimension.itemGap`).
    case item
    /// A new run (`size.global.listGap`).
    case run
    /// A day divider (`size.global.sectionGap` to its cap top).
    case divider
    /// The first message after a divider (`size.global.sectionHeaderToContent` below its baseline).
    case afterDivider
}

/// One message of the thread with its place in a run.
struct ChatRow: Identifiable, Equatable, Sendable {
    let message: Message
    /// The run's first message: avatar, name and time lead it (C-16 comment row).
    let startsRun: Bool
    let isMine: Bool
    let gap: ChatGap

    var id: MessageID { message.id }
}

/// An entry of the thread: a day divider (C-20 dated header) or a message.
enum ChatEntry: Identifiable, Equatable, Sendable {
    /// The start of a day (device calendar) and the space above it.
    case day(Date, gap: ChatGap)
    case message(ChatRow)

    var id: String {
        switch self {
        case let .day(date, _): return "day-" + String(Int(date.timeIntervalSinceReferenceDate))
        case let .message(row): return row.id.rawValue
        }
    }
}

enum ChatThreadLayout {
    /// Day dividers before the first message of each day; runs of consecutive messages from one sender, broken by
    /// another sender, a day divider, or a reply quote (`chat.thread.layout.runs.breaks`).
    static func entries(
        _ messages: [Message],
        me: UserID?,
        calendar: Calendar = .current,
        hasQuote: (Message) -> Bool = { _ in false }
    ) -> [ChatEntry] {
        var result: [ChatEntry] = []
        var previous: Message?
        for message in messages {
            let day = calendar.startOfDay(for: message.createdAt)
            let newDay = previous.map { calendar.startOfDay(for: $0.createdAt) != day } ?? true
            if newDay {
                result.append(.day(day, gap: result.isEmpty ? .none : .divider))
            }
            let startsRun = newDay || previous?.authorID != message.authorID || hasQuote(message)
            let gap: ChatGap = newDay ? .afterDivider : (startsRun ? .run : .item)
            result.append(.message(ChatRow(message: message, startsRun: startsRun, isMine: message.authorID == me, gap: gap)))
            previous = message
        }
        return result
    }

    /// The day divider's words (`chat.thread.divider.today` / `.yesterday`, else the date).
    enum DayLabel: Equatable {
        case today
        case yesterday
        case date(Date)
    }

    static func dayLabel(_ day: Date, now: Date = Date(), calendar: Calendar = .current) -> DayLabel {
        if calendar.isDate(day, inSameDayAs: now) { return .today }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return .yesterday
        }
        return .date(day)
    }
}

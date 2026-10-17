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
    /// Reactions on text and voice messages (`chat.reactions.layout.messageReactions`): one row per person, oldest first.
    private(set) var messageReactions: [MessageID: [MessageReaction]] = [:]
    /// The tunables the thread reads (`message_edit_window_s`, `typing_ttl_s`); nil until read.
    private(set) var config: PublicAppConfig?
    /// The message the composer is editing (`chat.thread.layout.editMessage`); the edit bar shows while set.
    private(set) var editTarget: MessageID?
    /// Who is typing (`chat.thread.layout.typingLine`), in the order they started; rows whose `until` passed are dropped.
    private(set) var typists: [ChatTyping] = []
    /// The composer's unsent text, put aside while a message is edited.
    @ObservationIgnored private var draftBeforeEdit = ""
    /// When `set_typing(true)` was last sent (nil: not typing as far as the server knows).
    @ObservationIgnored private var typingSentAt: Date?
    @ObservationIgnored private var typingExpiry: Task<Void, Never>?
    @ObservationIgnored private let now: @Sendable () -> Date
    /// Builds the preview of a link in a text I send (`chat.thread.layout.linkPreview`); nil: none are built.
    @ObservationIgnored private let linkPreviews: LinkPreviewBuilder?
    /// The previews being built, by message (best effort, silent).
    @ObservationIgnored private var previewTasks: [MessageID: Task<Void, Never>] = [:]

    private var localCounter = 0

    /// - Parameters:
    ///   - now: the clock of the edit window and the typing line (tests pass a fixed one).
    ///   - linkPreviews: reads the page of a link in a text I send and builds its preview; nil builds none.
    init(
        groupID: GroupID, focusMessageID: MessageID? = nil, data: any SocialDataSource,
        now: @escaping @Sendable () -> Date = { Date() }, linkPreviews: LinkPreviewBuilder? = nil
    ) {
        self.groupID = groupID
        self.focusMessageID = focusMessageID
        self.data = data
        self.now = now
        self.linkPreviews = linkPreviews
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

    /// I am an admin of this group (`group_members.role`).
    var isAdmin: Bool { members.contains { $0.member.userID == me && $0.member.role == .admin } }

    /// "Remove" (migration 0054, admins): someone else's text, voice or photo message that reached the server. The
    /// joined / left lines have no menu.
    func canAdminRemove(_ message: Message) -> Bool {
        guard isAdmin, !isMine(message), !pending.contains(message.id) else { return false }
        switch message.kind {
        case .text, .voice: return true
        case .photo: return message.postID != nil
        default: return false
        }
    }

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

    /// The name of a joined / left line (`chat.thread.layout.systemLine`): the person's first name now, else the first
    /// word of the name the line kept (someone who left may no longer share a group with the reader).
    func systemLineName(_ message: Message) -> String {
        if let name = profile(message.authorID)?.socialFirstName { return name }
        return message.body?.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
    }

    // MARK: Derived — reactions on messages, editing, typing

    /// The reactions on a text or voice message as the chip and the Reactions sheet show them (`ReactionSummary` rows
    /// keyed by the message: the sheet reads only who, which emoji and when).
    func reactionSummary(of messageID: MessageID) -> ReactionSummary {
        ReactionSummary((messageReactions[messageID] ?? []).map { row in
            Reaction(postID: PostID(messageID.rawValue), userID: row.userID, emoji: row.emoji, groupID: row.groupID, createdAt: row.createdAt)
        })
    }

    /// My emoji on a message (selected in the quick row and the picker): none or one.
    func myEmoji(onMessage messageID: MessageID) -> Set<String> {
        guard let me else { return [] }
        return Set((messageReactions[messageID] ?? []).filter { $0.userID == me }.map(\.emoji))
    }

    /// Who reacted with what on a message, oldest first — the chip's accessibility value (rows, never a count).
    func messageReactionRows(_ messageID: MessageID) -> [MessageReaction] {
        messageReactions[messageID] ?? []
    }

    /// `chat.thread.layout.editMessage`: my own sent text message, younger than `message_edit_window_s`; no window known
    /// → no Edit.
    func canEdit(_ message: Message) -> Bool {
        guard isMine(message), message.kind == .text, !pending.contains(message.id),
              let window = config?.messageEditWindowSeconds, window > 0 else { return false }
        return now().timeIntervalSince(message.createdAt) < TimeInterval(window)
    }

    var isEditing: Bool { editTarget != nil }

    /// The first names on the typing line (`chat.thread.layout.typingLine`), in the order they started; mine never.
    func typingNames(at date: Date? = nil) -> [String] {
        let moment = date ?? now()
        return typists.filter { $0.until > moment && $0.userID != me }
            .compactMap { profile($0.userID)?.socialFirstName }
    }

    /// The preview card under a text message (`chat.thread.layout.linkPreview`): its `link_preview`, while the text still
    /// holds the address.
    func linkPreview(of message: Message) -> LinkPreview? {
        guard message.kind == .text else { return nil }
        return ChatLinkPreviews.keeps(message.linkPreview, body: message.body)
    }

    func hasQuote(_ message: Message) -> Bool {
        quotedPost(of: message) != nil || quotedMessage(of: message) != nil
    }

    /// The thread as day dividers and runs (`chat.thread.layout.runs`, `.timeFormat.dayDividers`).
    func entries(calendar: Calendar = .current) -> [ChatEntry] {
        ChatThreadLayout.entries(
            messages, me: me, calendar: calendar,
            hasQuote: { [self] in hasQuote($0) },
            batchKey: { [self] in batchKey(of: $0) }
        )
    }

    /// The batch of a photo message's post (`layout.global.photoBatch`); nil for every other message, a photo posted alone,
    /// or a local copy not yet confirmed.
    func batchKey(of message: Message) -> PhotoBatchKey? {
        guard message.kind == .photo, !pending.contains(message.id) else { return nil }
        return post(of: message)?.post.batchKey
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
        if config == nil { config = try? await data.publicConfig() }
        await refresh()
        await loadTyping()
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
        let reactable = batch.filter { ($0.kind == .text || $0.kind == .voice) && !pending.contains($0.id) }.map(\.id)
        if !reactable.isEmpty, let rows = try? await data.messageReactions(messageIDs: reactable) {
            let byMessage = Dictionary(grouping: rows, by: \.messageID)
            for id in reactable {
                messageReactions[id] = (byMessage[id] ?? []).sorted { $0.createdAt < $1.createdAt }
            }
        }
        let reactors = photoIDs.flatMap { reactions[$0]?.rows.map(\.userID) ?? [] }
            + reactable.flatMap { messageReactions[$0]?.map(\.userID) ?? [] }
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
            // An edit (`edit_message`) or a reply losing its target: the row changes in place.
            if quotedMessages[message.id] != nil { quotedMessages[message.id] = message }
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
        case let .messageReactionUpserted(reaction):
            guard reaction.groupID == groupID, messages.contains(where: { $0.id == reaction.messageID }) else { return }
            var rows = (messageReactions[reaction.messageID] ?? []).filter { $0.userID != reaction.userID }
            rows.append(reaction)
            messageReactions[reaction.messageID] = rows.sorted { $0.createdAt < $1.createdAt }
            await loadProfiles([reaction.userID])
        case let .messageReactionsChanged(messageID):
            guard messages.contains(where: { $0.id == messageID }) else { return }
            await reloadMessageReactions(messageID)
        case let .typingChanged(row):
            guard row.groupID == groupID, row.userID != me else { return }
            applyTyping(row)
            await loadProfiles([row.userID])
        case .resubscribed:
            await refresh()
            await loadTyping()
        case .subscribed, .subscriptionFailed:
            break
        case .selfieReactionUpserted, .developingChanged, .plansChanged:
            // Selfie reactions show in photo.viewer only (viewer.selfiereaction); revealed photos arrive as their own
            // inserted messages.
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
        messageReactions[messageID] = nil
        if editTarget == messageID { cancelEdit() }
        if messages.isEmpty, phase == .ready { phase = .empty }
    }

    private func reloadReactions(_ postID: PostID) async {
        guard let rows = try? await data.reactions(postIDs: [postID]) else { return }
        reactions[postID] = ReactionSummary(rows)
    }

    private func reloadMessageReactions(_ messageID: MessageID) async {
        guard let rows = try? await data.messageReactions(messageIDs: [messageID]) else { return }
        messageReactions[messageID] = rows.filter { $0.messageID == messageID }.sorted { $0.createdAt < $1.createdAt }
        await loadProfiles(rows.map(\.userID))
    }

    private func loadProfiles(_ ids: [UserID]) async {
        let missing = ids.socialUnique().filter { profiles[$0] == nil }
        guard !missing.isEmpty, let found = try? await data.profiles(ids: missing) else { return }
        for profile in found { profiles[profile.id] = profile }
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
        if isEditing { cancelEdit() }
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
        if editTarget != nil {
            await saveEdit()
            return
        }
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
        // Sent: the typing line ends (the message is already on screen, so the call never holds it up).
        await stopTyping()
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
            if message.kind == .text { startLinkPreview(for: message) }
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

    /// An admin's "Remove" after its confirmation (`chat.thread.adminRemove.*`): someone else's text / voice message
    /// (`admin_delete_message`) or photo (`admin_delete_post`, this group's copy only). Gone at once, back on failure.
    func adminRemove(_ message: Message) async {
        guard canAdminRemove(message) else { return }
        signals.emit(.warning)
        if message.kind == .photo, let postID = message.postID {
            let snapshot = (messages, posts, reactions)
            removePost(postID)
            do {
                try await data.adminDeletePost(id: postID, groupID: groupID)
                signals.post(.photoDeleted)
            } catch {
                if SocialFailure(error) == .notFound { return }
                if SocialFailure(error) == .offline { isOffline = true }
                (messages, posts, reactions) = snapshot
                phase = messages.isEmpty ? .empty : .ready
                signals.emit(.failed)
                signals.post(.deleteFailed)
            }
            return
        }
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages.remove(at: index)
        if messages.isEmpty { phase = .empty }
        do {
            try await data.adminDeleteMessage(id: message.id, groupID: groupID)
        } catch {
            if SocialFailure(error) == .notFound { return }
            if SocialFailure(error) == .offline { isOffline = true }
            insert(message)
            phase = .ready
            signals.emit(.failed)
        }
    }

    /// "Save" on a photo message (as `photo.viewer`'s Save to Camera Roll): any photo you can see (owner decision 28).
    func savePhoto(_ message: Message, using saver: any SocialPhotoSaving) async {
        guard let media = post(of: message)?.media else { return }
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

    // MARK: Reactions on messages (`chat.reactions.layout.messageReactions`)

    /// An emoji on a text or voice message (quick row or picker): one per person — another emoji replaces mine at once,
    /// my own emoji again takes it back (`unreact_to_message`). Undone if the call fails (`chat.reactions.error`).
    func toggleReaction(messageID: MessageID, emoji: String) async {
        guard let me else { return }
        let before = messageReactions[messageID] ?? []
        if before.contains(where: { $0.userID == me && $0.emoji == emoji }) {
            await unreact(messageID: messageID)
            return
        }
        guard let message = messages.first(where: { $0.id == messageID }), message.kind == .text || message.kind == .voice,
              !pending.contains(messageID) else { return }
        messageReactions[messageID] = before.filter { $0.userID != me }
            + [MessageReaction(messageID: messageID, userID: me, emoji: emoji, groupID: groupID, createdAt: now())]
        do {
            _ = try await data.reactToMessage(id: messageID, emoji: emoji)
        } catch {
            messageReactions[messageID] = before
            if SocialFailure(error) == .offline { isOffline = true }
            signals.emit(.failed)
            signals.post(.reactionFailed)
        }
    }

    /// Takes my reaction off a message (`unreact_to_message`; the Reactions sheet's own row, or my emoji again).
    func unreact(messageID: MessageID) async {
        guard let me, let before = messageReactions[messageID], before.contains(where: { $0.userID == me }) else { return }
        messageReactions[messageID] = before.filter { $0.userID != me }
        do {
            try await data.unreactToMessage(id: messageID)
        } catch {
            if SocialFailure(error) == .notFound { return }
            messageReactions[messageID] = before
            signals.emit(.failed)
            signals.post(.reactionFailed)
        }
    }

    // MARK: Editing (`chat.thread.layout.editMessage`)

    /// "Edit" on my own text message: the composer holds its text with the edit bar; an unsent draft is put aside and a
    /// reply in progress dropped.
    func startEdit(_ message: Message) {
        guard canEdit(message) else { return }
        if editTarget == nil { draftBeforeEdit = draft }
        replyTarget = nil
        editTarget = message.id
        draft = message.body ?? ""
    }

    /// The edit bar's close glyph: the message keeps its text, the composer gets back what it held.
    func cancelEdit() {
        guard editTarget != nil else { return }
        editTarget = nil
        draft = draftBeforeEdit
        draftBeforeEdit = ""
    }

    /// Send while editing (`edit_message`): the new text shows at once; the same text closes the bar without a call. On
    /// failure (offline, `edit_window_closed`, …) the message gets its text back, the composer holds the edited text with
    /// the edit bar, and `chat.thread.edit.error` is announced.
    private func saveEdit() async {
        guard let id = editTarget else { return }
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        guard let index = messages.firstIndex(where: { $0.id == id }) else {
            cancelEdit()
            return
        }
        let before = messages[index]
        editTarget = nil
        draft = draftBeforeEdit
        draftBeforeEdit = ""
        guard body != before.body else { return }
        messages[index].body = body
        messages[index].editedAt = now()
        // An edit that drops the previewed address drops the preview (the server clears it the same way).
        messages[index].linkPreview = ChatLinkPreviews.keeps(before.linkPreview, body: body)
        do {
            let saved = try await data.editMessage(id: id, body: body)
            if let current = messages.firstIndex(where: { $0.id == id }) { messages[current] = saved }
            isOffline = false
            signals.emit(.sent)
        } catch {
            if SocialFailure(error) == .offline { isOffline = true }
            guard let current = messages.firstIndex(where: { $0.id == id }) else { return }
            messages[current] = before
            if editTarget == nil {
                draftBeforeEdit = draft
                editTarget = id
                draft = body
            }
            signals.emit(.failed)
            signals.post(.editFailed)
        }
    }

    // MARK: Link previews (`chat.thread.layout.linkPreview`)

    /// After my text message is sent: when it holds an http(s) address, the page is read once on this device, its image
    /// downscaled and uploaded, and `set_link_preview` records it. Best effort and silent: any failure leaves no preview,
    /// with no message, haptic or retry; the send itself is never held up.
    private func startLinkPreview(for message: Message) {
        guard let builder = linkPreviews, isMine(message), message.kind == .text, message.linkPreview == nil,
              let body = message.body, previewTasks[message.id] == nil,
              ChatLinkPreviews.candidate(in: body) != nil else { return }
        let id = message.id
        let data = self.data
        previewTasks[id] = Task { [weak self] in
            defer { self?.previewTasks[id] = nil }
            guard let draft = await builder.build(for: body),
                  let saved = try? await data.setLinkPreview(messageID: id, preview: draft) else { return }
            self?.applyLinkPreview(saved)
        }
    }

    /// The saved row's preview, unless the message went or its text no longer holds the address meanwhile.
    private func applyLinkPreview(_ saved: Message) {
        guard let index = messages.firstIndex(where: { $0.id == saved.id }) else { return }
        messages[index].linkPreview = ChatLinkPreviews.keeps(saved.linkPreview, body: messages[index].body)
    }

    /// Waits for the previews being built (tests).
    func linkPreviewsSettled() async {
        for task in Array(previewTasks.values) { await task.value }
    }

    // MARK: Typing (`chat.thread.layout.typingLine`)

    /// The composer's text changed: `set_typing(true)` while it holds text (again once half of `typing_ttl_s` passed),
    /// `set_typing(false)` when it empties. Nothing while editing a message, nothing without a TTL.
    func composerTextChanged() async {
        guard let ttl = config?.typingTTLSeconds, ttl > 0 else { return }
        let typing = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && editTarget == nil
        if typing {
            let moment = now()
            if let sent = typingSentAt, moment.timeIntervalSince(sent) < TimeInterval(ttl) / 2 { return }
            typingSentAt = moment
            try? await data.setTyping(true, groupID: groupID)
        } else {
            await stopTyping()
        }
    }

    /// `set_typing(false)`: the message was sent, the field emptied, or the thread is closing.
    func stopTyping() async {
        guard typingSentAt != nil else { return }
        typingSentAt = nil
        try? await data.setTyping(false, groupID: groupID)
    }

    /// The rows of people typing right now, read when the thread opens.
    private func loadTyping() async {
        guard let rows = try? await data.typing(groupID: groupID) else { return }
        for row in rows.sorted(by: { $0.until < $1.until }) where row.userID != me { applyTyping(row) }
        await loadProfiles(rows.map(\.userID))
    }

    /// One `chat_typing` row: someone who was not typing joins the end of the line; a renewal keeps their place; a past
    /// `until` takes them off.
    private func applyTyping(_ row: ChatTyping) {
        let moment = now()
        if let index = typists.firstIndex(where: { $0.userID == row.userID }) {
            if row.until > moment && typists[index].until > moment {
                typists[index] = row
            } else {
                typists.remove(at: index)
                if row.until > moment { typists.append(row) }
            }
        } else if row.until > moment {
            typists.append(row)
        }
        scheduleTypingExpiry()
    }

    /// Drops the rows whose `until` has passed (the device clock; no event marks the end of typing).
    func pruneTyping() {
        let moment = now()
        let alive = typists.filter { $0.until > moment }
        if alive != typists { typists = alive }
        scheduleTypingExpiry()
    }

    private func scheduleTypingExpiry() {
        typingExpiry?.cancel()
        guard let next = typists.map(\.until).min() else {
            typingExpiry = nil
            return
        }
        let wait = max(0, next.timeIntervalSince(now()))
        typingExpiry = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.pruneTyping()
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
    /// `chat.thread.layout.batch`: the other photo messages of the batch run this photo leads (posted together, in
    /// `created_at` order), not drawn themselves; empty for every other message.
    var batch: [Message] = []

    var id: MessageID { message.id }

    /// The photo leads photos posted together: its card carries `layout.global.batchMarker`.
    var isBatch: Bool { !batch.isEmpty }
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
    /// another sender, a day divider, or a reply quote (`chat.thread.layout.runs.breaks`). A joined / left line
    /// (`chat.thread.layout.systemLine`) stands alone: it starts no run, sits `size.global.listGap` from its neighbours,
    /// and the message after it starts a new run. Photo messages posted together (`batchKey`, `layout.global.photoBatch`)
    /// that follow one another on one day without a reply quote between are one entry: the first, holding the others in
    /// `ChatRow.batch` (`chat.thread.layout.batch`).
    static func entries(
        _ messages: [Message],
        me: UserID?,
        calendar: Calendar = .current,
        hasQuote: (Message) -> Bool = { _ in false },
        batchKey: (Message) -> PhotoBatchKey? = { _ in nil }
    ) -> [ChatEntry] {
        var result: [ChatEntry] = []
        var previous: Message?
        // A photo that would break the run (a new day, a reply quote) does not join the batch before it.
        let units = PhotoBatches.runs(messages) { message in
            message.kind == .photo ? batchKey(message) : nil
        }.flatMap { run -> [[Message]] in
            guard run.count > 1 else { return [run] }
            var split: [[Message]] = []
            for message in run {
                if let last = split.last?.last, calendar.isDate(last.createdAt, inSameDayAs: message.createdAt), !hasQuote(message) {
                    split[split.count - 1].append(message)
                } else {
                    split.append([message])
                }
            }
            return split
        }
        for unit in units {
            guard let message = unit.first else { continue }
            let day = calendar.startOfDay(for: message.createdAt)
            let newDay = previous.map { calendar.startOfDay(for: $0.createdAt) != day } ?? true
            if newDay {
                result.append(.day(day, gap: result.isEmpty ? .none : .divider))
            }
            let isSystemLine = message.kind.isSystemLine
            let afterSystemLine = previous?.kind.isSystemLine ?? false
            let startsRun = !isSystemLine && (newDay || previous?.authorID != message.authorID || afterSystemLine || hasQuote(message))
            let gap: ChatGap = newDay ? .afterDivider : (startsRun || isSystemLine ? .run : .item)
            result.append(.message(ChatRow(
                message: message, startsRun: startsRun, isMine: message.authorID == me, gap: gap, batch: Array(unit.dropFirst())
            )))
            previous = unit.last ?? message
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

// MARK: - Links (`chat.thread.layout.links`)

/// The web addresses of a text message, found by the platform's own detector (`NSDataDetector`, `.link`), http and https
/// only (an address without a scheme comes back completed by the detector). Previews are built on the sender's device
/// only (`ChatLinkPreviews`, `chat.thread.layout.linkPreview`); a reader's device never contacts the site.
enum ChatLinks {
    struct Link: Equatable {
        let range: Range<String.Index>
        let url: URL
    }

    // NSDataDetector is immutable once made and documented thread-safe (NSRegularExpression).
    nonisolated(unsafe) private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func find(in text: String) -> [Link] {
        guard let detector = Self.detector, !text.isEmpty else { return [] }
        let whole = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, options: [], range: whole).compactMap { match in
            guard let url = match.url, let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
                  let range = Range(match.range, in: text) else { return nil }
            return Link(range: range, url: url)
        }
    }
}

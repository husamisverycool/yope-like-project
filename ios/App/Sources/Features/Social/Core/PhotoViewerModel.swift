// Surface: photo.viewer — reference apps: Yope + Locket. Spec: design/surfaces/photo.viewer.md
// ("States", "Menu", "Data & actions") and design/surfaces/tagging.md (the "i'm in this" toggle).
// View model only (Foundation + Observation + AppData); the view is PhotoViewerView.
import AppData
import AppModels
import Foundation
import Observation

/// Saves a photo / Live Photo / video to the photo library with add-only access (AppServices
/// `PhotoLibraryService` on iOS).
protocol SocialPhotoSaving: Sendable {
    /// Downloads `fileURL` (and the Live Photo `motionURL`) and adds it to the library.
    func save(kind: MediaKind, fileURL: URL, motionURL: URL?) async throws
}

/// Thrown by `SocialPhotoSaving` when add-only access is denied or restricted.
enum SocialSaveFailure: Error, Equatable {
    case notAuthorized
}

/// Which photos the viewer pages through, in the opener's order (thread photos, a wall, a week, an album).
struct PhotoViewerContext: Hashable, Identifiable, Sendable {
    var postIDs: [PostID]
    var start: PostID
    /// The group the photos belong to, when the opener is a group screen (offline copy of its feed).
    var groupID: GroupID?

    var id: String { start.rawValue + "|" + postIDs.map(\.rawValue).joined(separator: ",") }

    init(postIDs: [PostID], start: PostID, groupID: GroupID? = nil) {
        self.postIDs = postIDs.contains(start) ? postIDs : [start] + postIDs
        self.start = start
        self.groupID = groupID
    }
}

/// Per-device flags of the social screens (first-use coach, recently used emoji).
final class SocialFlags: @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix = "social."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// `tagging.coach`: shown once per account.
    func taggingCoachSeen(by user: UserID) -> Bool {
        defaults.bool(forKey: keyPrefix + "taggingCoachSeen." + user.rawValue)
    }

    func setTaggingCoachSeen(by user: UserID) {
        defaults.set(true, forKey: keyPrefix + "taggingCoachSeen." + user.rawValue)
    }

    /// "Frequently Used" in the reaction picker (kept per device, `chat.reactions` Platform notes), newest first.
    func recentEmoji() -> [String] {
        defaults.stringArray(forKey: keyPrefix + "recentEmoji") ?? []
    }

    func recordEmoji(_ emoji: String, keep limit: Int) {
        let updated = ([emoji] + recentEmoji().filter { $0 != emoji }).prefix(max(limit, 1))
        defaults.set(Array(updated), forKey: keyPrefix + "recentEmoji")
    }
}

@MainActor
@Observable
final class PhotoViewerModel {
    @ObservationIgnored private let data: any SocialDataSource
    @ObservationIgnored private let flags: SocialFlags

    /// The photos still in the context (deleted ones leave it).
    private(set) var postIDs: [PostID]
    private(set) var selection: PostID
    private(set) var phase: SocialPhase = .loading
    private(set) var isOffline = false
    private(set) var me: UserID?
    private(set) var posts: [PostID: PostWithMedia] = [:]
    /// Posts that are not there anymore (`post_not_found`, or a `post_deleted` broadcast while open).
    private(set) var gone: Set<PostID> = []
    private(set) var reactions: [PostID: ReactionSummary] = [:]
    private(set) var profiles: [UserID: Profile] = [:]
    private(set) var groups: [GroupID: PhotoGroup] = [:]
    /// My "i'm in this" state per post (absent until read).
    private(set) var tagged: [PostID: Bool] = [:]
    /// ≤ one `tag_self` / `untag_self` in flight per photo.
    private(set) var tagPending: Set<PostID> = []
    /// `tagging.coach` pointing at the toggle.
    private(set) var coachVisible = false
    /// Add-only photo access was denied: the inline permission card shows.
    private(set) var saveDenied = false
    /// The viewer has nothing left to show and closes.
    private(set) var isClosed = false
    private(set) var isSendingReply = false
    private(set) var signals = SocialSignals()
    private(set) var sentReaction: SentReaction?
    var replyDraft = ""

    private var reactionCounter = 0

    init(context: PhotoViewerContext, data: any SocialDataSource, flags: SocialFlags = SocialFlags()) {
        self.data = data
        self.flags = flags
        postIDs = context.postIDs
        selection = context.start
        contextGroupID = context.groupID
    }

    @ObservationIgnored private let contextGroupID: GroupID?

    // MARK: Derived

    var current: PostWithMedia? { posts[selection] }

    var isCurrentGone: Bool { gone.contains(selection) }

    func isOwn(_ post: PostWithMedia) -> Bool { post.post.authorID == me }

    var isCurrentOwn: Bool { current.map(isOwn) ?? false }

    func author(of post: PostWithMedia) -> Profile? { profiles[post.post.authorID] }

    func group(of post: PostWithMedia) -> PhotoGroup? { groups[post.post.groupID] }

    var isCurrentTagged: Bool { tagged[selection] ?? false }

    // MARK: Loading

    /// The photos already on the device first (no blank frame), then the server's, replaced in place.
    func load() async {
        if me == nil { me = await data.currentUserID() }
        if phase == .loading, posts.isEmpty { await showCached() }
        do {
            let found = try await data.posts(ids: postIDs)
            let foundIDs = Set(found.map(\.id))
            for id in postIDs where !foundIDs.contains(id) { posts[id] = nil }
            for post in found { posts[post.id] = post }
            isOffline = false
        } catch {
            if SocialFailure(error) == .offline { isOffline = true }
            if let groupID = contextGroupID {
                for post in await data.cachedPosts(groupID: groupID) where postIDs.contains(post.id) {
                    posts[post.id] = post
                }
            }
            if posts.isEmpty {
                phase = isOffline ? .offline : .failed
                return
            }
        }
        for id in postIDs where posts[id] == nil { gone.insert(id) }
        phase = .ready
        await loadDetails()
        await loadTag(for: selection)
        updateCoach()
    }

    private func showCached() async {
        let cached = await data.cachedPosts(ids: postIDs, groupID: contextGroupID)
        guard cached.contains(where: { $0.id == selection }) else { return }
        for post in cached { posts[post.id] = post }
        if let groups = await data.cachedGroups() {
            for group in groups { self.groups[group.id] = group }
        }
        if let groupID = contextGroupID, let members = await data.cachedMembers(groupID: groupID) {
            for member in members { if let profile = member.profile { profiles[profile.id] = profile } }
        }
        phase = .ready
    }

    private func loadDetails() async {
        let ids = postIDs.filter { posts[$0] != nil }
        if !ids.isEmpty, let rows = try? await data.reactions(postIDs: ids) {
            let summaries = ReactionSummary.byPost(rows)
            for id in ids { reactions[id] = summaries[id] ?? ReactionSummary() }
        }
        let people = posts.values.map(\.post.authorID).socialUnique().filter { profiles[$0] == nil }
        if !people.isEmpty, let found = try? await data.profiles(ids: people) {
            for profile in found { profiles[profile.id] = profile }
        }
        if let mine = try? await data.myGroups() {
            for group in mine { groups[group.id] = group }
        } else if let cached = await data.cachedGroups() {
            for group in cached { groups[group.id] = group }
        }
    }

    private func loadTag(for id: PostID) async {
        guard tagged[id] == nil, posts[id] != nil, let me else { return }
        if let value = try? await data.isTagged(postID: id, userID: me) { tagged[id] = value }
    }

    /// Paging moved to another photo (synchronous, so the pager never snaps back).
    func show(_ id: PostID) {
        guard postIDs.contains(id), id != selection else { return }
        selection = id
        updateCoach()
    }

    /// The "i'm in this" state of the photo on screen.
    func loadSelectedTag() async {
        await loadTag(for: selection)
    }

    func select(_ id: PostID) async {
        show(id)
        await loadSelectedTag()
    }

    /// The posts beside the current one (prefetched while the current one shows).
    var neighbours: [PostWithMedia] {
        guard let index = postIDs.firstIndex(of: selection) else { return [] }
        return [index - 1, index + 1].filter(postIDs.indices.contains).compactMap { posts[postIDs[$0]] }
    }

    // MARK: Live

    func run() async {
        let groupIDs = Set(posts.values.map(\.post.groupID))
        await withTaskGroup(of: Void.self) { group in
            for groupID in groupIDs {
                group.addTask { await self.listen(to: groupID) }
            }
            group.addTask { await self.listenToNetwork() }
        }
    }

    private func listen(to groupID: GroupID) async {
        for await event in data.events(groupID: groupID) {
            await handle(event)
        }
    }

    private func listenToNetwork() async {
        for await status in data.network() {
            switch status {
            case .offline: isOffline = true
            case .online: isOffline = false
            case .unknown: break
            }
        }
    }

    func handle(_ event: GroupEvent) async {
        switch event {
        case let .postDeleted(postID, mediaID):
            let matching = postIDs.filter { id in
                id == postID || (mediaID != nil && posts[id]?.post.mediaID == mediaID)
            }
            gone.formUnion(matching)
        case let .reactionInserted(reaction):
            guard posts[reaction.postID] != nil else { return }
            reactions[reaction.postID, default: ReactionSummary()].insert(reaction)
        case let .reactionsChanged(postID):
            guard posts[postID] != nil, let rows = try? await data.reactions(postIDs: [postID]) else { return }
            reactions[postID] = ReactionSummary(rows)
        case let .postUpdated(post):
            guard let known = posts[post.id] else { return }
            posts[post.id] = PostWithMedia(post: post, media: known.media)
        default:
            break
        }
    }

    // MARK: Reactions (Locket quick reactions and picker)

    func react(_ emoji: String) async {
        guard let me, let post = current, !isCurrentGone else { return }
        let postID = post.id
        let alreadyThere = reactions[postID]?.contains(userID: me, emoji: emoji) ?? false
        if !alreadyThere {
            reactions[postID, default: ReactionSummary()].insert(
                Reaction(postID: postID, userID: me, emoji: emoji, groupID: post.post.groupID, createdAt: Date())
            )
        }
        reactionCounter += 1
        sentReaction = SentReaction(postID: postID, emoji: emoji, id: reactionCounter)
        do {
            _ = try await data.react(postID: postID, emoji: emoji)
        } catch {
            if !alreadyThere { reactions[postID]?.remove(userID: me, emoji: emoji) }
            if SocialFailure(error) == .notFound { gone.insert(postID) }
            signals.emit(.failed)
            signals.post(.reactionFailed)
        }
    }

    // MARK: "i'm in this" (tagging.md)

    private func updateCoach() {
        guard let me, let post = current, !isOwn(post), !flags.taggingCoachSeen(by: me) else {
            coachVisible = false
            return
        }
        coachVisible = true
    }

    /// ✕ on the coach, or any tap on the toggle: dismissed for good.
    func dismissCoach() {
        guard let me else { return }
        coachVisible = false
        flags.setTaggingCoachSeen(by: me)
    }

    /// Optimistic toggle with rollback; taps are ignored while the call runs.
    func toggleTag() async {
        let postID = selection
        guard posts[postID] != nil, !gone.contains(postID), !tagPending.contains(postID) else { return }
        if coachVisible { dismissCoach() }
        if isOffline {
            signals.emit(.failed)
            signals.post(.tagOffline)
            return
        }
        let previous = tagged[postID] ?? false
        tagged[postID] = !previous
        tagPending.insert(postID)
        signals.emit(.select)
        defer { tagPending.remove(postID) }
        do {
            try await data.setTagged(!previous, postID: postID)
        } catch {
            tagged[postID] = previous
            signals.emit(.failed)
            switch SocialFailure(error) {
            case .notFound:
                gone.insert(postID)
                signals.post(.tagNotFound)
            case .offline:
                isOffline = true
                signals.post(.tagOffline)
            default:
                signals.post(.tagError)
            }
        }
    }

    // MARK: Menu

    /// `delete_media` after the confirmation: gone everywhere. The viewer moves on at once (to the next photo, or
    /// closes when there is none) and puts the photo back if the call fails.
    func deleteCurrent() async {
        guard let post = current, isOwn(post) else { return }
        signals.emit(.warning)
        let snapshot = (postIDs, selection, posts, reactions)
        let removed = Set(postIDs.filter { posts[$0]?.post.mediaID == post.post.mediaID }).union([post.id])
        removeFromContext(removed)
        do {
            try await data.deleteMedia(id: post.post.mediaID)
        } catch {
            if SocialFailure(error) != .notFound {
                if SocialFailure(error) == .offline { isOffline = true }
                (postIDs, selection, posts, reactions) = snapshot
                isClosed = false
                updateCoach()
                signals.emit(.failed)
                signals.post(.deleteFailed)
                return
            }
        }
        signals.post(.photoDeleted)
    }

    private func removeFromContext(_ removed: Set<PostID>) {
        let index = postIDs.firstIndex(of: selection) ?? 0
        let wasSelected = removed.contains(selection)
        postIDs.removeAll { removed.contains($0) }
        for id in removed {
            posts[id] = nil
            reactions[id] = nil
        }
        guard wasSelected else { return }
        if index < postIDs.count {
            selection = postIDs[index]
            updateCoach()
        } else {
            isClosed = true
        }
    }

    /// Saves the original (Live Photo: still + motion) to the photo library.
    func saveCurrent(using saver: any SocialPhotoSaving) async {
        guard let media = current?.media else { return }
        do {
            let fileURL = try await data.fileURL(path: media.originalPath)
            var motionURL: URL?
            if media.kind == .livePhoto, let motionPath = media.motionPath {
                motionURL = try await data.fileURL(path: motionPath)
            }
            try await saver.save(kind: media.kind, fileURL: fileURL, motionURL: motionURL)
            saveDenied = false
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

    /// `block_user` for the current photo's author (run by the shared block confirmation, `safety.block`).
    func blockAuthor(_ userID: UserID) async throws {
        do {
            try await data.block(userID: userID)
        } catch {
            if SocialFailure(error) == .offline { isOffline = true }
            throw error
        }
    }

    /// After a block: the person's pics leave the viewer (RLS hides them everywhere).
    func authorBlocked(_ userID: UserID) {
        removeFromContext(Set(postIDs.filter { posts[$0]?.post.authorID == userID }))
    }

    // MARK: Reply

    /// `send_message(text, p_reply_to_post_id)`: the reply appears in the group's chat.
    func sendReply() async {
        let body = replyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !isSendingReply, let post = current, !isCurrentGone else { return }
        isSendingReply = true
        replyDraft = ""
        defer { isSendingReply = false }
        do {
            _ = try await data.sendText(groupID: post.post.groupID, body: body, replyToPostID: post.id)
            signals.emit(.sent)
        } catch {
            if SocialFailure(error) == .offline { isOffline = true }
            if replyDraft.isEmpty { replyDraft = body }
            signals.emit(.failed)
            signals.post(.sendFailed)
        }
    }
}

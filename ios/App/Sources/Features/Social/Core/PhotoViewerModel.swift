// Surface: photo.viewer — Retro's media viewer (TC-2B). Spec: design/surfaces/photo.viewer.md ("States", "Menu",
// "Data & actions") and design/surfaces/tagging.md (the footer's tag run, hosted here).
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

/// Which photos the viewer moves through, in the opener's order (thread photos, a wall, a week, a recap, an album).
struct PhotoViewerContext: Hashable, Identifiable, Sendable {
    var postIDs: [PostID]
    var start: PostID
    /// The group the photos belong to, when the opener is a group screen (offline copy of its feed).
    var groupID: GroupID?
    /// Opened from a link (a push): when the photo developed overnight, the viewer holds every photo revealed with it,
    /// oldest first (camera.overnight C: "photo.viewer opens on the photos revealed at that time").
    var opensReveal: Bool

    /// Opened from a wall: the header's second line names the group (`photo.viewer.header.groupWeek`).
    var showsGroupName: Bool

    var id: String { start.rawValue + "|" + postIDs.map(\.rawValue).joined(separator: ",") }

    init(postIDs: [PostID], start: PostID, groupID: GroupID? = nil, showsGroupName: Bool = false, opensReveal: Bool = false) {
        self.postIDs = postIDs.contains(start) ? postIDs : [start] + postIDs
        self.start = start
        self.groupID = groupID
        self.showsGroupName = showsGroupName
        self.opensReveal = opensReveal
    }
}

/// Per-device flags of the social screens (recently used emoji).
final class SocialFlags: @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix = "social."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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

    /// The photos still in the context (deleted ones leave it).
    private(set) var postIDs: [PostID]
    private(set) var selection: PostID
    let showsGroupName: Bool
    private(set) var phase: SocialPhase = .loading
    private(set) var isOffline = false
    private(set) var me: UserID?
    private(set) var posts: [PostID: PostWithMedia] = [:]
    /// Posts that are not there anymore (`post_not_found`, or a `post_deleted` broadcast while open).
    private(set) var gone: Set<PostID> = []
    private(set) var reactions: [PostID: ReactionSummary] = [:]
    /// Selfie reactions on the photos (viewer.selfiereaction): the faces, the sheet rows, send and remove.
    let selfies: SelfieReactionsModel
    private(set) var profiles: [UserID: Profile] = [:]
    private(set) var groups: [GroupID: PhotoGroup] = [:]
    /// Who is in each photo (`post_tags`), in tag order; absent until read.
    private(set) var tagged: [PostID: [UserID]] = [:]
    /// ≤ one `tag_self` / `untag_self` in flight per photo.
    private(set) var tagPending: Set<PostID> = []
    /// The group-chat replies to each photo, oldest first (`photo.viewer.layout.comments`); absent until read.
    private(set) var comments: [PostID: [Message]] = [:]
    /// My private favorites among the context's photos (by media; my own `favorites` rows, then this session's changes).
    private(set) var favorites: Set<MediaID> = []
    /// ≤ one `set_favorite` in flight per photo.
    private(set) var favoritePending: Set<MediaID> = []
    /// The groups of the context where I am an admin ("Use as Cover", update_group's rule).
    private(set) var adminGroups: Set<GroupID> = []
    /// Add-only photo access was denied: the native alert with the Settings link shows.
    var saveDenied = false
    /// The viewer has nothing left to show and closes.
    private(set) var isClosed = false
    private(set) var isSendingReply = false
    private(set) var signals = SocialSignals()
    var replyDraft = ""
    /// photo.viewer.layout.video: videos play with sound once the person turns it on, for every video until the viewer
    /// closes (muted until then).
    var videoSoundOn = false
    /// Each "Play" (the circle, or the photo's VoiceOver action) on a video without autoplay.
    var videoPlayRequests = 0

    init(context: PhotoViewerContext, data: any SocialDataSource) {
        self.data = data
        selfies = SelfieReactionsModel(data: data)
        postIDs = context.postIDs
        selection = context.start
        contextGroupID = context.groupID
        expandsReveal = context.opensReveal
        expandsBatch = context.opensReveal
        showsGroupName = context.showsGroupName
    }

    @ObservationIgnored private let contextGroupID: GroupID?
    @ObservationIgnored private var expandsReveal: Bool
    /// Opened on one photo by a link (a push, `groups.screen`): a photo of a batch opens with its batch
    /// (`photo.viewer.layout.batchDots`). Once.
    @ObservationIgnored private var expandsBatch: Bool
    /// The batches among the context's photos (`layout.global.photoBatch`), each in posted order, two photos or more;
    /// side by side in `postIDs`.
    private(set) var batches: [[PostID]] = []

    // MARK: Derived

    var current: PostWithMedia? { posts[selection] }

    var isCurrentGone: Bool { gone.contains(selection) }

    func isOwn(_ post: PostWithMedia) -> Bool { post.post.authorID == me }

    var isCurrentOwn: Bool { current.map(isOwn) ?? false }

    func author(of post: PostWithMedia) -> Profile? { profiles[post.post.authorID] }

    func group(of post: PostWithMedia) -> PhotoGroup? { groups[post.post.groupID] }

    /// The ISO week of the post in its group's time zone (`photo.viewer.header.week`).
    func weekNumber(of post: PostWithMedia) -> Int {
        let zone = group(of: post)?.resolvedTimeZone ?? .current
        return SocialCalendar.weekNumber(containing: post.post.visibleAt, in: zone)
    }

    /// 1-based position of the photo on screen and the context's size (`photo.viewer.position`, shown when > 1).
    var position: (index: Int, total: Int)? {
        guard postIDs.count > 1, let index = postIDs.firstIndex(of: selection) else { return nil }
        return (index + 1, postIDs.count)
    }

    /// `photo.viewer.layout.avatarRing`: the share of the circle the header ring draws — the position over the total
    /// (TC-2B: "3 of 4" draws three quarters); one photo: the full circle.
    var ringFraction: Double {
        guard postIDs.count > 1, let index = postIDs.firstIndex(of: selection) else { return 1 }
        return Double(index + 1) / Double(postIDs.count)
    }

    /// `photo.viewer.layout.batchDots`: the photos of the batch the photo on screen belongs to, in posted order (those
    /// still in the context and not gone); empty when it was posted alone or is the one photo left of its batch.
    var currentBatch: [PostID] { batchMembers(of: selection) }

    /// The photos of the batch `id` belongs to, in posted order (still in the context and not gone, `id` always); empty
    /// when it was posted alone or is the one photo left of its batch.
    func batchMembers(of id: PostID) -> [PostID] {
        guard let batch = batches.first(where: { $0.contains(id) }) else { return [] }
        let present = Set(postIDs.filter { !gone.contains($0) || $0 == id })
        let members = batch.filter { present.contains($0) }
        return members.count > 1 ? members : []
    }

    /// The page dots' position: `id` among the photos of its batch (positions, never a count); nil without a batch.
    func batchPosition(of id: PostID) -> PhotoBatchPosition? {
        let members = batchMembers(of: id)
        return PhotoBatches.position(of: id, in: members, batch: members)
    }

    /// The photo on screen's place in its batch.
    var batchPosition: PhotoBatchPosition? { batchPosition(of: selection) }

    func taggedPeople(on postID: PostID) -> [UserID] { tagged[postID] ?? [] }

    var isCurrentTagged: Bool {
        guard let me else { return false }
        return taggedPeople(on: selection).contains(me)
    }

    /// The comments under the photo on screen.
    var currentComments: [Message] { comments[selection] ?? [] }

    /// The photo on screen is one of my favorites (the menu offers Unfavorite).
    var isCurrentFavorite: Bool { current.map { favorites.contains($0.post.mediaID) } ?? false }

    /// "Remove" (migration 0054): someone else's photo, still there, in a group where I am an admin.
    var canAdminRemoveCurrent: Bool {
        guard let post = current, !isCurrentGone, !isOwn(post) else { return false }
        return adminGroups.contains(post.post.groupID)
    }

    /// "Use as Cover": I am an admin of the photo's group and the photo is still there.
    var canUseCurrentAsCover: Bool {
        guard let post = current, !isCurrentGone else { return false }
        return adminGroups.contains(post.post.groupID)
    }

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
        await expandReveal()
        await arrangeBatches()
        phase = .ready
        await loadDetails()
        await loadSelectedDetails()
    }

    /// camera.overnight C: a link to an overnight photo opens on all the photos revealed with it, oldest first, keeping
    /// the linked photo selected (the reveal push names the first). Once; a failure keeps the one photo.
    private func expandReveal() async {
        guard expandsReveal, let post = posts[selection], post.post.revealedAt != nil else { return }
        expandsReveal = false
        guard let together = try? await data.revealedWith(post.post), together.count > 1,
              together.contains(where: { $0.id == selection }) else { return }
        for photo in together { posts[photo.id] = photo }
        postIDs = together.map(\.id)
    }

    /// `photo.viewer.layout.batchDots`: opened on one photo by a link, a photo of a batch opens with its batch (once; a
    /// failure keeps the one photo); then every batch among the photos sits side by side in posted order
    /// (`PhotoBatches.gather`), the photo on screen kept.
    private func arrangeBatches() async {
        if expandsBatch {
            expandsBatch = false
            if postIDs.count == 1, let post = posts[selection], post.post.batchKey != nil,
               let together = try? await data.batchWith(post.post), together.count > 1,
               together.contains(where: { $0.id == selection }) {
                for photo in together { posts[photo.id] = photo }
                postIDs = together.map(\.id)
            }
        }
        var byKey: [PhotoBatchKey: [PostWithMedia]] = [:]
        var order: [PhotoBatchKey] = []
        for id in postIDs {
            guard let post = posts[id], let key = post.post.batchKey else { continue }
            if byKey[key] == nil { order.append(key) }
            byKey[key, default: []].append(post)
        }
        batches = order.compactMap { key -> [PostID]? in
            guard let members = byKey[key], members.count > 1 else { return nil }
            return members
                .sorted { ($0.post.createdAt, $0.id.rawValue) < ($1.post.createdAt, $1.id.rawValue) }
                .map(\.id)
        }
        for batch in batches { postIDs = PhotoBatches.gather(postIDs, batch: batch) }
    }

    /// The page dots' adjustable action: the `index`th photo (0-based) of the batch on screen.
    func selectInBatch(_ index: Int) async {
        let members = currentBatch
        guard members.indices.contains(index) else { return }
        await select(members[index])
    }

    /// Error line "Tap to retry".
    func retry() async {
        phase = .loading
        await load()
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
        await selfies.load(postIDs: ids)
        await loadProfiles(posts.values.map(\.post.authorID) + [me].compactMap { $0 } + selfies.reactors)
        await loadFavoritesAndRoles()
        if let mine = try? await data.myGroups() {
            for group in mine { groups[group.id] = group }
        } else if let cached = await data.cachedGroups() {
            for group in cached { groups[group.id] = group }
        }
    }

    /// Which of the photos are my favorites, and the groups where I am an admin (kept on failure: the menu then offers
    /// Favorite and no cover item).
    private func loadFavoritesAndRoles() async {
        let mediaIDs = posts.values.map(\.post.mediaID).socialUnique()
        if !mediaIDs.isEmpty, let found = try? await data.favoriteMediaIDs(among: mediaIDs) {
            let pending = favoritePending
            favorites = favorites.filter { pending.contains($0) }.union(found.subtracting(pending))
        }
        for groupID in Set(posts.values.map(\.post.groupID)) where !adminGroups.contains(groupID) {
            if let membership = try? await data.myMembership(groupID: groupID), membership.role == .admin {
                adminGroups.insert(groupID)
            }
        }
    }

    private func loadProfiles(_ ids: [UserID]) async {
        let wanted = ids.socialUnique().filter { profiles[$0] == nil }
        if !wanted.isEmpty, let found = try? await data.profiles(ids: wanted) {
            for profile in found { profiles[profile.id] = profile }
        }
    }

    /// Tags and comments of the photo on screen (read when it shows).
    func loadSelectedDetails() async {
        let id = selection
        guard posts[id] != nil, !gone.contains(id) else { return }
        if tagged[id] == nil, let rows = try? await data.tags(postID: id) {
            tagged[id] = rows.map(\.userID).socialUnique()
        }
        if comments[id] == nil, let rows = try? await data.replies(postID: id) {
            comments[id] = rows
        }
        await loadProfiles(taggedPeople(on: id) + (comments[id] ?? []).map(\.authorID))
    }

    // MARK: Moving (`photo.viewer.layout.advance`)

    /// Shows another photo of the context.
    func show(_ id: PostID) {
        guard postIDs.contains(id), id != selection else { return }
        selection = id
    }

    func select(_ id: PostID) async {
        show(id)
        await loadSelectedDetails()
    }

    /// Tap on the photo: the next photo; past the last one the viewer closes.
    func advance() {
        guard let index = postIDs.firstIndex(of: selection) else { return }
        if index + 1 < postIDs.count {
            selection = postIDs[index + 1]
        } else {
            isClosed = true
        }
    }

    /// Tap on the photo's leading zone: the previous photo (none before the first).
    func goBack() {
        guard let index = postIDs.firstIndex(of: selection), index > 0 else { return }
        selection = postIDs[index - 1]
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
        await selfies.handle(event)
        switch event {
        case let .selfieReactionUpserted(selfie):
            guard posts[selfie.postID] != nil else { return }
            await loadProfiles([selfie.userID])
        case let .postDeleted(postID, mediaID):
            let matching = postIDs.filter { id in
                id == postID || (mediaID != nil && posts[id]?.post.mediaID == mediaID)
            }
            gone.formUnion(matching)
        case let .reactionInserted(reaction):
            guard posts[reaction.postID] != nil else { return }
            reactions[reaction.postID, default: ReactionSummary()].insert(reaction)
            await loadProfiles([reaction.userID])
        case let .reactionsChanged(postID):
            guard posts[postID] != nil, let rows = try? await data.reactions(postIDs: [postID]) else { return }
            reactions[postID] = ReactionSummary(rows)
        case let .postUpdated(post):
            guard let known = posts[post.id] else { return }
            posts[post.id] = PostWithMedia(post: post, media: known.media)
        case let .messageInserted(message):
            guard let postID = message.replyToPostID, comments[postID] != nil else { return }
            appendComment(message, to: postID)
            await loadProfiles([message.authorID])
        case let .messageDeleted(messageID):
            for id in comments.keys { comments[id]?.removeAll { $0.id == messageID } }
        default:
            break
        }
    }

    private func appendComment(_ message: Message, to postID: PostID) {
        guard !(comments[postID] ?? []).contains(where: { $0.id == message.id }) else { return }
        comments[postID, default: []].append(message)
        comments[postID]?.sort { $0.createdAt < $1.createdAt }
    }

    // MARK: Reactions (`chat.reactions`)

    func react(_ emoji: String) async {
        guard let me, let post = current, !isCurrentGone else { return }
        let postID = post.id
        let alreadyThere = reactions[postID]?.contains(userID: me, emoji: emoji) ?? false
        if !alreadyThere {
            reactions[postID, default: ReactionSummary()].insert(
                Reaction(postID: postID, userID: me, emoji: emoji, groupID: post.post.groupID, createdAt: Date())
            )
        }
        do {
            _ = try await data.react(postID: postID, emoji: emoji)
        } catch {
            if !alreadyThere { reactions[postID]?.remove(userID: me, emoji: emoji) }
            if SocialFailure(error) == .notFound { gone.insert(postID) }
            signals.emit(.failed)
            signals.post(.reactionFailed)
        }
    }

    /// A quick reaction from the photo's context menu: a used emoji is taken back, any other reacts.
    func toggleReaction(_ emoji: String) async {
        if myEmojiOnCurrent.contains(emoji) {
            await unreact(emoji)
        } else {
            await react(emoji)
        }
    }

    /// The emoji I reacted with on the photo on screen (selected in the quick row and the picker).
    var myEmojiOnCurrent: Set<String> {
        guard let me, let post = current else { return [] }
        return reactions[post.id]?.emoji(by: me) ?? []
    }

    /// `unreact` (`chat.reactions.layout.unreact`): the emoji goes at once and comes back if the call fails.
    func unreact(_ emoji: String) async {
        guard let me, let post = current, !isCurrentGone else { return }
        let postID = post.id
        guard let before = reactions[postID], before.contains(userID: me, emoji: emoji) else { return }
        reactions[postID]?.remove(userID: me, emoji: emoji)
        do {
            try await data.unreact(postID: postID, emoji: emoji)
        } catch {
            if SocialFailure(error) == .notFound {
                gone.insert(postID)
                return
            }
            reactions[postID] = before
            signals.emit(.failed)
            signals.post(.reactionFailed)
        }
    }

    // MARK: Selfie reactions (viewer.selfiereaction)

    /// The photo on screen takes a selfie from me: someone else's photo that is still there (the entry points are hidden
    /// on my own photo).
    var canReactWithSelfie: Bool {
        guard let post = current, !isCurrentGone else { return false }
        return selfies.canReact(to: post, me: me)
    }

    /// Sends the selfie taken in the capture layer to the photo it was opened on.
    func sendSelfie(_ jpeg: Data, to postID: PostID) async {
        guard let me, let post = posts[postID], !gone.contains(postID) else { return }
        if await selfies.send(jpeg, to: post, me: me) == .notFound { gone.insert(postID) }
    }

    /// Tap on my selfie row in the Reactions sheet: takes it back.
    func removeMySelfie(postID: PostID) async {
        guard let me else { return }
        if await selfies.removeMine(from: postID, me: me) == .notFound { gone.insert(postID) }
    }

    /// The confirmed "Remove" on someone's selfie on my own photo.
    func removeSelfie(of userID: UserID, postID: PostID) async {
        guard let post = posts[postID], isOwn(post) else { return }
        if await selfies.removeFromMyPhoto(userID: userID, postID: postID) == .notFound { gone.insert(postID) }
    }

    // MARK: "I'm in this" (tagging.md)

    /// Optimistic tag / untag of myself with rollback; taps are ignored while the call runs. `haptic.global.select`
    /// when applied, `haptic.global.error` when it fails.
    func toggleTag() async {
        let postID = selection
        guard let me, posts[postID] != nil, !gone.contains(postID), !tagPending.contains(postID) else { return }
        let previous = tagged[postID] ?? []
        let wasTagged = previous.contains(me)
        if isOffline {
            signals.emit(.failed)
            signals.post(.tagOffline)
            return
        }
        tagged[postID] = wasTagged ? previous.filter { $0 != me } : previous + [me]
        tagPending.insert(postID)
        signals.emit(.select)
        defer { tagPending.remove(postID) }
        do {
            try await data.setTagged(!wasTagged, postID: postID)
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
                signals.post(wasTagged ? .tagRemoveError : .tagError)
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
                signals.emit(.failed)
                signals.post(.deleteFailed)
                return
            }
        }
        signals.post(.photoDeleted)
    }

    /// `admin_delete_post` after the confirmation (`photo.viewer.adminRemove.*`): someone else's photo leaves this group
    /// only (the author's posts of it in other groups stay). The viewer moves on at once and puts it back on failure.
    func adminRemoveCurrent() async {
        guard let post = current, canAdminRemoveCurrent else { return }
        signals.emit(.warning)
        let snapshot = (postIDs, selection, posts, reactions)
        removeFromContext([post.id])
        do {
            try await data.adminDeletePost(id: post.id, groupID: post.post.groupID)
        } catch {
            if SocialFailure(error) != .notFound {
                if SocialFailure(error) == .offline { isOffline = true }
                if DataError.from(error).apiCode == .notGroupAdmin { adminGroups.remove(post.post.groupID) }
                (postIDs, selection, posts, reactions) = snapshot
                isClosed = false
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
        } else {
            isClosed = true
        }
    }

    /// Saves the original (Live Photo: still + motion) of the photo to your photo library — any photo you can see (owner
    /// decision 28); sharing to other apps stays your own photos only (decision 12).
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

    // MARK: Favorites and the group cover (owner decision 34)

    /// Favorite / Unfavorite (`set_favorite`): applied at once with `haptic.global.select`; back as it was with
    /// `haptic.global.error` + `photo.viewer.error.favorite` if the call fails. Taps wait while one is in flight.
    func toggleFavorite() async {
        guard let post = current, !isCurrentGone else { return }
        let mediaID = post.post.mediaID
        guard !favoritePending.contains(mediaID) else { return }
        let wasFavorite = favorites.contains(mediaID)
        if wasFavorite { favorites.remove(mediaID) } else { favorites.insert(mediaID) }
        favoritePending.insert(mediaID)
        signals.emit(.select)
        defer { favoritePending.remove(mediaID) }
        do {
            try await data.setFavorite(!wasFavorite, mediaID: mediaID)
        } catch {
            if wasFavorite { favorites.insert(mediaID) } else { favorites.remove(mediaID) }
            if SocialFailure(error) == .offline { isOffline = true }
            if SocialFailure(error) == .notFound { gone.insert(post.id) }
            signals.emit(.failed)
            signals.post(.favoriteFailed)
        }
    }

    /// "Use as Cover" (`set_group_cover_from_post`, admins): "Saved!" with `haptic.global.success`; `media_not_ready` →
    /// `photo.viewer.error.coverNotReady`, other failures `photo.viewer.error.cover`, both with `haptic.global.error`.
    func useCurrentAsCover() async {
        guard canUseCurrentAsCover, let post = current else { return }
        do {
            try await data.setGroupCover(groupID: post.post.groupID, postID: post.id)
            signals.emit(.success)
            signals.post(.coverSet)
        } catch {
            if SocialFailure(error) == .offline { isOffline = true }
            if DataError.from(error).apiCode == .notGroupAdmin { adminGroups.remove(post.post.groupID) }
            signals.emit(.failed)
            signals.post(SocialFailure.isMediaNotReady(error) ? .coverNotReady : .coverFailed)
        }
    }

    // MARK: Caption (owner decision 34, `photo.viewer.layout.editCaption`)

    /// The caption alert is open (Edit Caption / Add a Caption on my own photo).
    var isEditingCaption = false
    /// The alert's text field, kept to `SocialLimits.caption` characters (`limitCaptionText`).
    var captionText = ""
    /// The post the open alert edits (the selection may move under it).
    @ObservationIgnored private var captionTarget: PostID?

    /// My own photo that is still there: the menu's first item edits (or adds) its caption.
    var canEditCurrentCaption: Bool { isCurrentOwn && !isCurrentGone }

    /// The photo on screen has a caption (the item reads Edit Caption; without one, Add a Caption).
    var currentHasCaption: Bool { !(current?.post.caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// The footer's date line reads "{date} · Edited" once the caption was changed (`caption_edited_at`).
    func isCaptionEdited(_ post: PostWithMedia) -> Bool { post.post.captionEditedAt != nil }

    /// Opens the caption alert with the current caption.
    func beginCaptionEdit() {
        guard canEditCurrentCaption, let post = current else { return }
        captionTarget = post.id
        captionText = post.post.caption ?? ""
        isEditingCaption = true
    }

    /// The field stops at `posts.caption`'s 1000 characters (the alert's text field has no limit of its own).
    func limitCaptionText() {
        if captionText.count > SocialLimits.caption { captionText = String(captionText.prefix(SocialLimits.caption)) }
    }

    func cancelCaptionEdit() {
        isEditingCaption = false
        captionTarget = nil
    }

    /// "Save": `edit_caption` (blank removes the caption). The new caption shows at once with "Edited"; the server's row
    /// replaces it. Unchanged text sends nothing. A failure puts the caption back as it was, with `haptic.global.error` and
    /// `photo.viewer.error.caption`.
    func saveCaption() async {
        isEditingCaption = false
        guard let postID = captionTarget ?? current?.id, let before = posts[postID], isOwn(before), !gone.contains(postID) else { return }
        captionTarget = nil
        let trimmed = String(captionText.prefix(SocialLimits.caption)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != (before.post.caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        var shown = before
        shown.post.caption = trimmed.isEmpty ? nil : trimmed
        shown.post.captionEditedAt = shown.post.captionEditedAt ?? Date()
        posts[postID] = shown
        do {
            let row = try await data.editCaption(postID: postID, caption: trimmed)
            posts[postID] = PostWithMedia(post: row, media: posts[postID]?.media ?? before.media)
        } catch {
            if posts[postID] == shown { posts[postID] = before }
            switch SocialFailure(error) {
            case .notFound: gone.insert(postID)
            case .offline: isOffline = true
            default: break
            }
            signals.emit(.failed)
            signals.post(.captionFailed)
        }
    }

    /// The album picker's result (`photo.viewer.layout.albumPicker`): the photo was added or a new album saved.
    func addedToAlbum() {
        signals.emit(.success)
        signals.post(.albumAdded)
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

    /// After a block: the person's photos leave the viewer (RLS hides them everywhere).
    func authorBlocked(_ userID: UserID) {
        removeFromContext(Set(postIDs.filter { posts[$0]?.post.authorID == userID }))
    }

    // MARK: Comments

    /// "Unsend" on one of my comments (the thread's message menu): gone at once, put back if the call fails.
    func deleteComment(_ message: Message) async {
        guard message.authorID == me,
              let postID = comments.first(where: { $0.value.contains { $0.id == message.id } })?.key else { return }
        signals.emit(.warning)
        let before = comments[postID]
        comments[postID]?.removeAll { $0.id == message.id }
        do {
            try await data.deleteMessage(id: message.id, groupID: message.groupID)
        } catch {
            if SocialFailure(error) == .notFound { return }
            if SocialFailure(error) == .offline { isOffline = true }
            comments[postID] = before
            signals.emit(.failed)
        }
    }

    /// "Copy" on a comment (the view puts it on the pasteboard).
    func copied() {
        signals.post(.copied)
    }

    // MARK: Reply

    /// `send_message(text, p_reply_to_post_id)`: the reply appears in the group's chat and as a comment here.
    func sendReply() async {
        let body = replyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !isSendingReply, let post = current, !isCurrentGone else { return }
        isSendingReply = true
        replyDraft = ""
        defer { isSendingReply = false }
        do {
            let message = try await data.sendText(groupID: post.post.groupID, body: body, replyToPostID: post.id)
            if comments[post.id] != nil { appendComment(message, to: post.id) } else { comments[post.id] = [message] }
            await loadProfiles([message.authorID])
            signals.emit(.sent)
        } catch {
            if SocialFailure(error) == .offline { isOffline = true }
            if replyDraft.isEmpty { replyDraft = body }
            signals.emit(.failed)
            signals.post(.sendFailed)
        }
    }
}

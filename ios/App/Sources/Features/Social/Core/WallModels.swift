// Surfaces: walls.mine, walls.member, walls.browse — reference app: Yope. Specs: design/surfaces/walls.*.md
// ("States", "Data & actions"). View models only (Foundation + Observation + AppData).
import AppData
import AppModels
import Foundation
import Observation

/// One person's wall as the caller sees it (`wall()`, docs/API.md §6.4): photos and ready collages,
/// newest first, in pages of 50.
@MainActor
@Observable
final class WallModel {
    enum Owner: Hashable, Sendable {
        case me
        case member(UserID)
    }

    /// One grid tile.
    enum Tile: Identifiable, Equatable {
        case post(PostWithMedia)
        case collage(Collage)

        var id: String {
            switch self {
            case let .post(post): return "p" + post.id.rawValue
            case let .collage(collage): return "c" + collage.id.rawValue
            }
        }

        var createdAt: Date {
            switch self {
            case let .post(post): return post.post.createdAt
            case let .collage(collage): return collage.createdAt
            }
        }
    }

    let owner: Owner
    @ObservationIgnored private let data: any SocialDataSource

    private(set) var phase: SocialPhase = .loading
    private(set) var isOffline = false
    private(set) var userID: UserID?
    private(set) var profile: Profile?
    private(set) var items: [WallItem] = []
    private(set) var posts: [PostID: PostWithMedia] = [:]
    private(set) var collages: [CollageID: Collage] = [:]
    private(set) var cursor: Date?
    private(set) var isLoadingMore = false
    /// The offline copy was looked at (the loading indicator shows only when there was none).
    private(set) var hasCheckedCache = false

    init(owner: Owner, data: any SocialDataSource) {
        self.owner = owner
        self.data = data
    }

    /// Tiles in `wall()` order; collages only once `status = ready`.
    var tiles: [Tile] {
        items.compactMap { item in
            switch item.itemKind {
            case .post:
                return item.postID.flatMap { posts[$0] }.map(Tile.post)
            case .collage:
                return item.collageID.flatMap { collages[$0] }.flatMap { $0.isReady ? Tile.collage($0) : nil }
            case .unknown:
                return nil
            }
        }
    }

    /// Photo tiles in grid order (`photo.viewer` context).
    var photoPostIDs: [PostID] {
        tiles.compactMap { tile in
            if case let .post(post) = tile { return post.id }
            return nil
        }
    }

    var hasMore: Bool { cursor != nil }

    var showsLoading: Bool { phase == .loading && hasCheckedCache }

    var displayName: String? { profile?.displayName }

    // MARK: Loading

    func load() async {
        if userID == nil {
            switch owner {
            case .me: userID = await data.currentUserID()
            case let .member(id): userID = id
            }
        }
        guard let userID else {
            phase = .failed
            return
        }
        if profile == nil, let found = try? await data.profiles(ids: [userID]) { profile = found.first }
        if items.isEmpty, let cached = await data.cachedWall(userID: userID), !cached.isEmpty {
            items = cached
            await loadDetails(for: cached)
            phase = .ready
        }
        hasCheckedCache = true
        do {
            let page = try await data.wall(userID: userID, before: nil, limit: SocialPaging.wall)
            isOffline = false
            items = page.items
            cursor = page.nextCursor
            await loadDetails(for: page.items)
            phase = tiles.isEmpty ? .empty : .ready
        } catch {
            if SocialFailure(error) == .offline { isOffline = true }
            if items.isEmpty { phase = isOffline ? .offline : .failed }
        }
    }

    func retry() async {
        phase = .loading
        await load()
    }

    /// Next page when the grid reaches its end.
    func loadMore() async {
        guard let userID, let cursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await data.wall(userID: userID, before: cursor, limit: SocialPaging.wall)
            let known = Set(items.map(Self.key))
            let fresh = page.items.filter { !known.contains(Self.key($0)) }
            items += fresh
            self.cursor = page.nextCursor
            await loadDetails(for: fresh)
        } catch {
            if SocialFailure(error) == .offline { isOffline = true }
        }
    }

    private static func key(_ item: WallItem) -> String {
        (item.postID?.rawValue ?? "") + "|" + (item.collageID?.rawValue ?? "")
    }

    private func loadDetails(for batch: [WallItem]) async {
        let postIDs = batch.compactMap(\.postID).filter { posts[$0] == nil }
        if !postIDs.isEmpty, let found = try? await data.posts(ids: postIDs) {
            for post in found { posts[post.id] = post }
        }
        let collageIDs = batch.compactMap(\.collageID).filter { collages[$0] == nil }
        if !collageIDs.isEmpty, let found = try? await data.collages(ids: collageIDs) {
            for collage in found { collages[collage.id] = collage }
        }
    }

    // MARK: Live

    /// Deletion broadcasts of the groups this wall's items appear in.
    func run() async {
        let groupIDs = Set(items.flatMap(\.groupIDs))
        await withTaskGroup(of: Void.self) { group in
            for groupID in groupIDs {
                group.addTask { await self.listen(to: groupID) }
            }
        }
    }

    private func listen(to groupID: GroupID) async {
        for await event in data.events(groupID: groupID) {
            handle(event)
        }
    }

    /// `post_deleted` → drop the tile (any post of that photo).
    func handle(_ event: GroupEvent) {
        guard case let .postDeleted(postID, mediaID) = event else { return }
        items.removeAll { item in
            item.postID == postID || (mediaID != nil && item.mediaID == mediaID)
        }
        posts[postID] = nil
        if phase == .ready, tiles.isEmpty { phase = .empty }
    }
}

/// `walls.browse`: me and everyone who shares a group with me, and the selected person's wall.
@MainActor
@Observable
final class WallsBrowseModel {
    struct Person: Identifiable, Equatable {
        var id: UserID
        var profile: Profile?
        var isMe: Bool
    }

    @ObservationIgnored private let data: any SocialDataSource
    /// `groups.screen` profile "wall" segment: only this group's members.
    let groupID: GroupID?

    private(set) var phase: SocialPhase = .loading
    private(set) var isOffline = false
    /// Me first, then the others (order BLOCKED, `walls.browse.layout.rowOrder`: approximation newest wall item first).
    private(set) var people: [Person] = []
    private(set) var selectedID: UserID?
    /// The caller belongs to no group, or shares groups with nobody else.
    private(set) var hasNobodyElse = false
    private(set) var walls: [UserID: WallModel] = [:]
    private(set) var signals = SocialSignals()

    init(data: any SocialDataSource, groupID: GroupID? = nil) {
        self.data = data
        self.groupID = groupID
    }

    var selectedWall: WallModel? { selectedID.flatMap { walls[$0] } }

    var selectedPerson: Person? { people.first { $0.id == selectedID } }

    /// The cached copy was looked at: only then may a loading indicator show (no indicator over cached content).
    private(set) var hasCheckedCache = false

    var showsLoading: Bool { phase == .loading && hasCheckedCache }

    /// Cached people and wall first (offline copy), then the server's, replaced in place.
    func load() async {
        guard let me = await data.currentUserID() else {
            phase = .failed
            return
        }
        if people.isEmpty, let cached = await data.cachedGroups() {
            await build(me: me, groups: cached, fresh: false)
        }
        hasCheckedCache = true
        let groups: [PhotoGroup]
        do {
            groups = try await data.myGroups()
            isOffline = false
        } catch {
            if SocialFailure(error) == .offline { isOffline = true }
            if people.isEmpty { phase = isOffline ? .offline : .failed }
            return
        }
        await build(me: me, groups: groups, fresh: true)
    }

    private func build(me: UserID, groups all: [PhotoGroup], fresh: Bool) async {
        let groups = groupID.map { id in all.filter { $0.id == id } } ?? all
        var profiles: [UserID: Profile] = [:]
        var others: [UserID] = []
        for group in groups {
            var members: [MemberProfile] = []
            if fresh, let current = try? await data.members(groupID: group.id) {
                members = current
            } else {
                members = await data.cachedMembers(groupID: group.id) ?? []
            }
            for member in members {
                if let profile = member.profile { profiles[member.member.userID] = profile }
                if member.member.userID != me { others.append(member.member.userID) }
            }
        }
        if profiles[me] == nil, fresh, let mine = try? await data.profiles(ids: [me]) { profiles[me] = mine.first }
        if profiles[me] == nil { profiles[me] = people.first { $0.id == me }?.profile }
        let ordered = await newestFirst(others.socialUnique(), fresh: fresh)
        people = [Person(id: me, profile: profiles[me], isMe: true)]
            + ordered.map { Person(id: $0, profile: profiles[$0], isMe: false) }
        hasNobodyElse = ordered.isEmpty
        phase = .ready
        if selectedID == nil || !people.contains(where: { $0.id == selectedID }) {
            selectedID = nil
            await select(me, announce: false)
        }
    }

    func retry() async {
        phase = .loading
        await load()
    }

    /// Orders people by their newest wall item (approximation of the BLOCKED row order); `fresh: false` orders
    /// by the cached walls.
    private func newestFirst(_ ids: [UserID], fresh: Bool) async -> [UserID] {
        let data = self.data
        let newest = await withTaskGroup(of: (UserID, Date?).self) { group -> [UserID: Date] in
            for id in ids {
                group.addTask {
                    if fresh, let page = try? await data.wall(userID: id, before: nil, limit: 1) {
                        return (id, page.items.first?.createdAt)
                    }
                    return (id, await data.cachedWall(userID: id)?.first?.createdAt)
                }
            }
            var result: [UserID: Date] = [:]
            for await (id, date) in group {
                if let date { result[id] = date }
            }
            return result
        }
        return ids.enumerated().sorted { lhs, rhs in
            let left = newest[lhs.element] ?? .distantPast
            let right = newest[rhs.element] ?? .distantPast
            return left != right ? left > right : lhs.offset < rhs.offset
        }.map(\.element)
    }

    /// Tap on a person circle: their wall replaces the one below (`haptic.global.select`).
    func select(_ id: UserID, announce: Bool = true) async {
        guard people.contains(where: { $0.id == id }) else { return }
        if announce, id != selectedID { signals.emit(.select) }
        selectedID = id
        if walls[id] == nil {
            let isMe = people.first { $0.id == id }?.isMe ?? false
            let wall = WallModel(owner: isMe ? .me : .member(id), data: data)
            walls[id] = wall
            await wall.load()
        }
    }
}

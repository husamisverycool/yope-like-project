// Surfaces: walls.mine, walls.member, walls.browse — Retro's profile with week sections and its Friends grid.
// Specs: design/surfaces/walls.*.md ("States", "Data & actions"). View models only (Foundation + Observation + AppData).
import AppData
import AppModels
import Foundation
import Observation

/// One person's wall as the caller sees it (`wall()`, docs/API.md §6.4): photos and ready collages, grouped by week
/// (`walls.mine.layout.weeks`: device time zone, weeks starting Monday, ISO numbers), current week first.
@MainActor
@Observable
final class WallModel {
    enum Owner: Hashable, Sendable {
        case me
        case member(UserID)
    }

    /// One strip tile.
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

    /// One week section: its tiles in time order (Monday → Sunday).
    struct Week: Identifiable, Equatable {
        let weekStart: LocalDate
        let tiles: [Tile]
        let isCurrent: Bool

        var id: LocalDate { weekStart }
    }

    let owner: Owner
    @ObservationIgnored private let data: any SocialDataSource
    @ObservationIgnored private let now: @Sendable () -> Date
    /// The wall's weeks are in the device's time zone (RS-15).
    let timeZone: TimeZone

    private(set) var phase: SocialPhase = .loading
    private(set) var isOffline = false
    private(set) var userID: UserID?
    private(set) var profile: Profile?
    private(set) var items: [WallItem] = []
    private(set) var posts: [PostID: PostWithMedia] = [:]
    private(set) var collages: [CollageID: Collage] = [:]
    private(set) var cursor: Date?
    private(set) var isLoadingMore = false
    /// The offline copy was looked at (the loading tiles show only when there was none).
    private(set) var hasCheckedCache = false

    init(
        owner: Owner,
        data: any SocialDataSource,
        timeZone: TimeZone = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.owner = owner
        self.data = data
        self.timeZone = timeZone
        self.now = now
    }

    /// Tiles in `wall()` order (newest first); collages only once `status = ready`.
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

    var currentWeekStart: LocalDate { SocialCalendar.weekStart(containing: now(), in: timeZone) }

    var currentWeekNumber: Int { SocialCalendar.weekNumber(of: currentWeekStart, in: timeZone) }

    /// The current week (always), then every past week with tiles, newest first; tiles in time order inside a week.
    var weeks: [Week] {
        let current = currentWeekStart
        var byWeek: [LocalDate: [Tile]] = [:]
        for tile in tiles {
            byWeek[SocialCalendar.weekStart(containing: tile.createdAt, in: timeZone), default: []].append(tile)
        }
        if byWeek[current] == nil { byWeek[current] = [] }
        return byWeek
            .map { week, tiles in
                Week(weekStart: week, tiles: tiles.sorted { $0.createdAt < $1.createdAt }, isCurrent: week == current)
            }
            .sorted { $0.weekStart > $1.weekStart }
    }

    /// The current week's days without a photo, Monday first (empty-day / placeholder tiles).
    func emptyDays(of week: Week) -> [LocalDate] {
        guard week.isCurrent else { return [] }
        let photoDays = Set(week.tiles.map { LocalDate($0.createdAt, in: timeZone) })
        return SocialCalendar.days(of: week.weekStart).filter { !photoDays.contains($0) }
    }

    /// Photo tiles in wall order (`photo.viewer` context): newest week first, time order inside a week.
    var photoPostIDs: [PostID] {
        weeks.flatMap(\.tiles).compactMap { tile in
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

    /// Next page when the list reaches its end.
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

    /// After blocking the person (walls.member menu): the API returns nothing for them any more.
    func blocked() {
        items = []
        cursor = nil
        phase = .empty
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

/// `walls.browse`: everyone who shares at least one group with me (not me), filtered by the search field.
@MainActor
@Observable
final class WallsBrowseModel {
    struct Person: Identifiable, Equatable {
        var id: UserID
        var profile: Profile?

        var name: String { profile?.displayName ?? "" }
    }

    @ObservationIgnored private let data: any SocialDataSource
    /// Only one group's members (a group-scoped entry).
    let groupID: GroupID?
    /// `walls.browse.layout.rowOrder` is BLOCKED: DEBUG builds order by the newest wall item, then name.
    let ordersByNewestWall: Bool

    /// `.empty`: no groups, or nobody else in them.
    private(set) var phase: SocialPhase = .loading
    private(set) var isOffline = false
    private(set) var people: [Person] = []
    /// The search field's text (filters by display name).
    var search = ""
    /// The cached copy was looked at: only then may a loading indicator show (no indicator over cached content).
    private(set) var hasCheckedCache = false

    init(data: any SocialDataSource, groupID: GroupID? = nil, ordersByNewestWall: Bool = SocialOrdering.peopleByNewestWall) {
        self.data = data
        self.groupID = groupID
        self.ordersByNewestWall = ordersByNewestWall
    }

    var showsLoading: Bool { phase == .loading && hasCheckedCache }

    /// The people the grid shows for the current search.
    var visiblePeople: [Person] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return people }
        return people.filter { $0.name.localizedStandardContains(query) }
    }

    /// Cached people first (offline copy), then the server's, replaced in place.
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
            for member in members where member.member.userID != me {
                if let profile = member.profile { profiles[member.member.userID] = profile }
                others.append(member.member.userID)
            }
        }
        let unique = others.socialUnique()
        let ordered = ordersByNewestWall ? await newestFirst(unique, profiles: profiles, fresh: fresh) : unique
        people = ordered.map { Person(id: $0, profile: profiles[$0]) }
        phase = people.isEmpty ? .empty : .ready
    }

    func retry() async {
        phase = .loading
        await load()
    }

    /// The development approximation of the BLOCKED row order: newest wall item first, then by name.
    private func newestFirst(_ ids: [UserID], profiles: [UserID: Profile], fresh: Bool) async -> [UserID] {
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
        return ids.sorted { lhs, rhs in
            let left = newest[lhs] ?? .distantPast
            let right = newest[rhs] ?? .distantPast
            if left != right { return left > right }
            return (profiles[lhs]?.displayName ?? "").localizedStandardCompare(profiles[rhs]?.displayName ?? "") == .orderedAscending
        }
    }
}

// Account group — groups.screen state: the group, its members and its photos newest first (paged), split the way the
// screen shows them — this week's strip (group time zone, Monday start), the members' weeks (one friend card per member
// who shared this week) and the earlier photos by day; realtime inserts / deletions; cached content offline
// (docs/API.md §5.3–5.4, §5.8, §8, §9.6).
import AppData
import AppModels
import Foundation
import Observation
import UIKit

/// One member's week: their newest photo of this week (a C-18 friend card).
struct MemberWeek: Identifiable, Equatable {
    let member: MemberProfile
    let newest: PostWithMedia
    var id: UserID { member.member.userID }
}

/// One day of the earlier photos (a C-21 dated section), newest first.
struct DaySection: Identifiable, Equatable {
    /// Start of the day in the group's time zone.
    let day: Date
    let posts: [PostWithMedia]
    var id: Date { day }
}

@MainActor
@Observable
final class GroupFeedModel {
    enum Phase: Equatable {
        case loading
        /// The group has photos.
        case loaded
        /// The viewer created the group and nothing is posted yet.
        case created
        /// Joined group without posts.
        case empty
        /// The fetch failed with nothing cached.
        case error
        /// No connection and nothing cached.
        case offline
        /// `not_group_member`.
        case removed
    }

    let groupID: GroupID
    private(set) var group: PhotoGroup?
    private(set) var members: [MemberProfile] = []
    private(set) var posts: [PostWithMedia] = []
    private(set) var phase: Phase = .loading
    private(set) var isLoadingMore = false
    private(set) var latestRecapID: RecapID?
    /// This week's ready same-moment collages (`group_collages`, migration 0033): each day's collage joins the strip on
    /// its day once composed, the group's photo of that day.
    private(set) var thisWeekCollages: [GroupCollage] = []
    /// Bumped when a realtime insert added photos (VoiceOver layout-changed announcement).
    private(set) var insertedCount = 0

    private(set) var nextCursor: Date?
    private let data: AccountDataSource
    private let now: () -> Date
    private var realtimeTask: Task<Void, Never>?

    /// - Parameter now: the clock that decides "this week" (tests pin it to their fixture's time).
    init(groupID: GroupID, data: AccountDataSource, now: @escaping () -> Date = Date.init) {
        self.groupID = groupID
        self.data = data
        self.now = now
    }

    var me: UserID? { data.currentUserID }
    var isCreator: Bool { group?.createdBy != nil && group?.createdBy == me }
    var isAdmin: Bool { members.contains { $0.member.userID == me && $0.member.role == .admin } }

    func profile(of userID: UserID) -> Profile? {
        members.first { $0.member.userID == userID }?.profile
    }

    /// Members in joining order (the avatar stack).
    var membersInJoiningOrder: [MemberProfile] {
        members.sorted { $0.member.joinedAt < $1.member.joinedAt }
    }

    // MARK: Weeks (group time zone, ISO weeks: Monday start, `app_config.week_start_isodow`)

    /// ISO-8601 calendar in the group's time zone.
    var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        if let zone = group.flatMap({ TimeZone(identifier: $0.timeZone) }) { calendar.timeZone = zone }
        return calendar
    }

    /// The current week (group time zone).
    var currentWeek: DateInterval? {
        calendar.dateInterval(of: .weekOfYear, for: now())
    }

    /// `{number}` of `groups.screen.week.title`: the ISO week number of today in the group's time zone.
    var weekNumber: Int {
        calendar.component(.weekOfYear, from: now())
    }

    /// This week's photos, oldest → newest (the strip's order). A photo is in the week it became visible in
    /// (`visibleAt`: an overnight photo taken on Sunday night is in Monday's week, docs/API.md §5.8).
    var thisWeekPosts: [PostWithMedia] {
        guard let week = currentWeek else { return [] }
        return posts.filter { week.contains($0.post.visibleAt) }.sorted { $0.post.visibleAt < $1.post.visibleAt }
    }

    /// The days of this week from today to its end (start of day, group time zone): the empty-day tiles of a week
    /// without photos (Retro's empty week, H43 / H22).
    var remainingDaysOfWeek: [Date] {
        let calendar = calendar
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now()) else { return [] }
        let today = calendar.startOfDay(for: now())
        var days: [Date] = []
        var day = today
        while day < week.end {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    /// One friend card per member who shared this week, newest first: that member's newest photo of the week.
    var memberWeeks: [MemberWeek] {
        var newestByAuthor: [UserID: PostWithMedia] = [:]
        for post in thisWeekPosts {
            if let current = newestByAuthor[post.post.authorID], current.post.visibleAt >= post.post.visibleAt { continue }
            newestByAuthor[post.post.authorID] = post
        }
        return newestByAuthor.compactMap { userID, post -> MemberWeek? in
            guard let member = members.first(where: { $0.member.userID == userID }) else { return nil }
            return MemberWeek(member: member, newest: post)
        }
        .sorted { $0.newest.post.visibleAt > $1.newest.post.visibleAt }
    }

    /// The photos from before this week by day (group time zone), newest first.
    var earlierSections: [DaySection] {
        let calendar = calendar
        let weekStart = currentWeek?.start ?? .distantFuture
        var sections: [DaySection] = []
        for post in posts.sorted(by: { $0.post.visibleAt > $1.post.visibleAt }) where post.post.visibleAt < weekStart {
            let day = calendar.startOfDay(for: post.post.visibleAt)
            if let last = sections.last, last.day == day {
                sections[sections.count - 1] = DaySection(day: day, posts: last.posts + [post])
            } else {
                sections.append(DaySection(day: day, posts: [post]))
            }
        }
        return sections
    }

    /// Earlier photos exist but none this week ("quiet week": the strip shows the empty week without the block).
    var isQuietWeek: Bool { phase == .loaded && thisWeekPosts.isEmpty }

    // MARK: Loading

    /// Cached group, members and first page at once; then the server's.
    func load() async {
        if posts.isEmpty {
            if group == nil { group = await data.cachedGroups()?.first { $0.id == groupID } }
            if let cachedMembers = await data.cachedMembers(groupID: groupID) { members = cachedMembers }
            if let cached = await data.cachedFeed(groupID: groupID), !cached.isEmpty {
                posts = cached
                phase = .loaded
            }
        }
        await refresh()
        followRealtime()
    }

    func refresh() async {
        do {
            guard let fresh = try await data.group(id: groupID) else {
                phase = .removed
                return
            }
            group = fresh
            members = (try? await data.members(groupID: groupID)) ?? members
            let page = try await data.feed(groupID: groupID, before: nil)
            mergeFirstPage(page)
            latestRecapID = (try? await data.latestRecap(groupID: groupID))?.id
            if let week = currentWeek, let found = try? await data.groupCollages(
                groupID: groupID,
                from: LocalDate(week.start, in: calendar.timeZone),
                // `DateInterval.end` is the next Monday's start: the week's last day is the one just before it.
                to: LocalDate(week.end.addingTimeInterval(-1), in: calendar.timeZone)
            ) {
                thisWeekCollages = found.sorted { $0.localDate < $1.localDate }
            }
            updatePhase()
        } catch {
            let failure = DataError.from(error)
            if failure.apiCode == .notGroupMember {
                phase = .removed
            } else if posts.isEmpty {
                phase = failure == .offline ? .offline : .error
            }
        }
    }

    /// The first page replaces the newest photos and keeps older pages already loaded.
    private func mergeFirstPage(_ page: Page<PostWithMedia>) {
        guard let oldestFresh = page.items.last?.post.createdAt, page.nextCursor != nil else {
            posts = page.items
            nextCursor = nil
            return
        }
        let older = posts.filter { $0.post.createdAt < oldestFresh }
        posts = page.items + older
        if older.isEmpty { nextCursor = page.nextCursor }
    }

    private func updatePhase() {
        if !posts.isEmpty {
            phase = .loaded
        } else {
            phase = isCreator ? .created : .empty
        }
    }

    /// The next (older) page, when the last earlier cell appears.
    func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        guard let page = try? await data.feed(groupID: groupID, before: cursor) else { return }
        let known = Set(posts.map(\.id))
        posts += page.items.filter { !known.contains($0.id) }
        nextCursor = page.nextCursor
    }

    /// The error line's retry (tap).
    func retry() async {
        phase = .loading
        await refresh()
    }

    // MARK: Realtime

    private func followRealtime() {
        guard realtimeTask == nil else { return }
        let events = data.groupEvents(groupID: groupID)
        realtimeTask = Task { [weak self] in
            for await event in events {
                await self?.handle(event)
            }
        }
    }

    func stop() {
        realtimeTask?.cancel()
        realtimeTask = nil
    }

    func handle(_ event: GroupEvent) async {
        switch event {
        case let .postInserted(post) where post.groupID == groupID:
            guard !posts.contains(where: { $0.id == post.id }) else { return }
            await insertNewest()
        case let .postDeleted(postID, _):
            posts.removeAll { $0.id == postID }
            updatePhase()
        case .resubscribed:
            await refresh()
        default:
            break
        }
    }

    /// A new post: the first page is read again and the new photos join the strip.
    private func insertNewest() async {
        guard let page = try? await data.feed(groupID: groupID, before: nil) else { return }
        let known = Set(posts.map(\.id))
        let fresh = page.items.filter { !known.contains($0.id) }
        guard !fresh.isEmpty else { return }
        posts = (fresh + posts).sorted { $0.post.createdAt > $1.post.createdAt }
        if !members.contains(where: { member in fresh.contains { $0.post.authorID == member.member.userID } }) {
            members = (try? await data.members(groupID: groupID)) ?? members
        }
        insertedCount += 1
        updatePhase()
    }

    /// The person was blocked: their content disappears (RLS); read again.
    func blocked(_ userID: UserID) async {
        posts.removeAll { $0.post.authorID == userID }
        await refresh()
    }

    // MARK: Previews and tests

    func seed(group: PhotoGroup?, members: [MemberProfile], posts: [PostWithMedia], phase: Phase) {
        self.group = group
        self.members = members
        self.posts = posts
        self.phase = phase
    }
}

// DEBUG only: an in-memory `MemoryDataSource` for unit tests (AppTests/Memory), snapshot tests and
// UI tests (AppUITests/Memory, launch argument `-MemoryFixtures`). It answers like the backend
// (docs/API.md) except that it does not hide rows by RLS, so the screens' own guards are exercised.
#if DEBUG
import AppData
import AppModels
import Foundation

final class FixtureMemoryData: MemoryDataSource, @unchecked Sendable {
    enum Operation: String, CaseIterable, Sendable {
        case group, postsWithMedia, profiles, signedURLs, onThisDay, historyWeeks, historyMonths, deletePost, downloadData
        case hideMemory, hiddenMemories
        case myPrivateProfile, setBirthday
        case openRequests, request, myContribution, contribute, withdraw, eligiblePostIDs
        case tribute, groupTributes, downloadFile, yearStory, collages, tags, isTagged, tagSelf, untagSelf
    }

    struct State {
        var me: UserID?
        var network: NetworkStatus = .online
        var groups: [PhotoGroup] = []
        var posts: [PostWithMedia] = []
        var profiles: [Profile] = []
        var onThisDay: [OnThisDayItem] = []
        /// `on_this_day` rows for one asked date, ahead of `onThisDay` ("Pick a date…").
        var onThisDayByDate: [LocalDate: [OnThisDayItem]] = [:]
        /// The dates `on_this_day` was asked for, in order.
        var onThisDayDates: [LocalDate] = []
        /// `group_history_months` rows, newest month first.
        var historyMonths: [HistoryMonth] = []
        /// The caller's hidden photos and days (`memory_hides`), oldest hide first.
        var hides: [HiddenMemory] = []
        var privateProfile: ProfilePrivate?
        var requests: [TributeRequest] = []
        /// The caller's own contributions.
        var contributions: [TributeContribution] = []
        /// Posts the caller tagged themselves in.
        var myTags: Set<PostID> = []
        /// Other members' self-tags per post, in tag order (the caller's own tag, if any, comes after them).
        var otherTags: [PostID: [UserID]] = [:]
        var tributes: [Tribute] = []
        var yearStories: [YearStory] = []
        var collages: [Collage] = []
        /// Errors thrown by an operation (until removed).
        var failures: [Operation: DataError] = [:]
        /// Every call, in order.
        var calls: [Operation] = []
        /// Operations that never answer (loading states in snapshots).
        var suspended: Set<Operation> = []
        var now: Date = Date()
    }

    private let lock = NSLock()
    private var state: State
    private var deletionListeners: [GroupID: [UUID: AsyncStream<PostID>.Continuation]] = [:]

    init(_ state: State = State()) {
        self.state = state
    }

    /// The current state (a copy).
    var snapshot: State {
        lock.withLock { state }
    }

    func update(_ change: (inout State) -> Void) {
        lock.withLock { change(&state) }
    }

    func fail(_ operation: Operation, with error: DataError?) {
        update { $0.failures[operation] = error }
    }

    func calls(of operation: Operation) -> Int {
        snapshot.calls.filter { $0 == operation }.count
    }

    /// Sends a `post_deleted` broadcast to the group's listeners.
    func emitDeletion(postID: PostID, groupID: GroupID) {
        let listeners = lock.withLock { Array((deletionListeners[groupID] ?? [:]).values) }
        listeners.forEach { $0.yield(postID) }
    }

    private func record(_ operation: Operation) async throws -> State {
        let current = try lock.withLock { () throws -> State in
            state.calls.append(operation)
            if let error = state.failures[operation] { throw error }
            return state
        }
        if current.suspended.contains(operation) {
            try await Task.sleep(nanoseconds: 3_600_000_000_000) // provenance-ok: fixture never answers (one hour)
        }
        return current
    }

    // MARK: MemoryDataSource

    func currentUser() async -> UserID? { snapshot.me }

    func networkStatus() async -> NetworkStatus { snapshot.network }

    func group(id: GroupID) async throws -> PhotoGroup? {
        try await record(.group).groups.first { $0.id == id }
    }

    func postsWithMedia(ids: [PostID]) async throws -> [PostWithMedia] {
        let current = try await record(.postsWithMedia)
        let byID = Dictionary(current.posts.map { ($0.post.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    func profiles(ids: [UserID]) async throws -> [Profile] {
        let wanted = Set(ids)
        return try await record(.profiles).profiles.filter { wanted.contains($0.id) }
    }

    func signedURLs(paths: [String]) async throws -> [String: URL] {
        _ = try await record(.signedURLs)
        var result: [String: URL] = [:]
        for path in paths {
            // The Jolt demo build carries the photos its world names (`DemoPhotos`).
            result[path] = DemoPhotos.url(for: path) ?? URL(string: "fixture://" + path) // provenance-ok: fixture URL scheme
        }
        return result
    }

    func deletedPosts(groupID: GroupID) -> AsyncStream<PostID> {
        let (stream, continuation) = AsyncStream<PostID>.makeStream()
        let id = UUID()
        lock.withLock { deletionListeners[groupID, default: [:]][id] = continuation }
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            self.lock.withLock { self.deletionListeners[groupID]?[id] = nil }
        }
        return stream
    }

    /// As `on_this_day`: the group's rows minus the caller's hidden photos and days (the day in the group's zone).
    func onThisDay(groupID: GroupID, localDate: LocalDate) async throws -> [OnThisDayItem] {
        let current = try await record(.onThisDay)
        update { $0.onThisDayDates.append(localDate) }
        let groupPosts = Set(current.posts.filter { $0.post.groupID == groupID }.map(\.post.id))
        let zone = current.groups.first { $0.id == groupID }?.resolvedTimeZone ?? MemoryFormat.utc
        let hiddenMedia = Set(current.hides.compactMap(\.mediaID))
        let hiddenDays = Set(current.hides.compactMap(\.day))
        return (current.onThisDayByDate[localDate] ?? current.onThisDay).filter { item in
            groupPosts.contains(item.postID) && !hiddenMedia.contains(item.mediaID)
                && !hiddenDays.contains(LocalDate(item.createdAt, in: zone))
        }
    }

    /// `hide_memory`: idempotent; a photo must be one of the fixture's posts.
    func hideMemory(_ target: MemoryHideTarget) async throws {
        let current = try await record(.hideMemory)
        let row: HiddenMemory
        switch target {
        case let .photo(mediaID):
            guard !current.hides.contains(where: { $0.mediaID == mediaID }) else { return }
            guard let post = current.posts.first(where: { $0.post.mediaID == mediaID }) else { throw DataError.api(.mediaNotFound) }
            row = HiddenMemory(
                id: MemoryHideID(UUID()), mediaID: mediaID, createdAt: current.now, postID: post.post.id, groupID: post.post.groupID,
                kind: post.media?.kind, thumbPath: post.media?.thumbPath ?? post.media?.originalPath, takenAt: post.post.createdAt
            )
        case let .day(day):
            guard !current.hides.contains(where: { $0.day == day }) else { return }
            row = HiddenMemory(id: MemoryHideID(UUID()), day: day, createdAt: current.now)
        }
        update { $0.hides.append(row) }
    }

    /// `my_hidden_memories`: newest hide first.
    func hiddenMemories() async throws -> [HiddenMemory] {
        Array(try await record(.hiddenMemories).hides.reversed())
    }

    /// `group_history_months`: the fixture's months as set, else the group's posts by day (group time zone), newest month
    /// first, days oldest first.
    func historyMonths(groupID: GroupID) async throws -> [HistoryMonth] {
        let current = try await record(.historyMonths)
        if !current.historyMonths.isEmpty { return current.historyMonths }
        let zone = current.groups.first { $0.id == groupID }?.resolvedTimeZone ?? MemoryFormat.utc
        let days = Set(current.posts.filter { $0.post.groupID == groupID }.map { LocalDate($0.post.createdAt, in: zone) })
        let byMonth = Dictionary(grouping: days) { LocalDate(year: $0.year, month: $0.month, day: 1) ?? $0 }
        return byMonth.keys.sorted(by: >).map { month in
            let list = (byMonth[month] ?? []).sorted()
            let newest = list.last ?? month
            // dayNumber 0 (1970-01-01) was a Thursday: Monday-based weekday = (dayNumber + 3) mod 7.
            let weekday = ((newest.dayNumber + 3) % 7 + 7) % 7 // provenance-ok: calendar arithmetic (ISO weekday of the epoch)
            return HistoryMonth(month: month, days: list, newestWeek: newest.adding(days: -weekday))
        }
    }

    /// The group's posts by week (Monday start, group time zone), newest week first, posts chronological;
    /// `before` is exclusive, at most `limit` weeks (as `group_history_weeks`).
    func historyWeeks(groupID: GroupID, before: LocalDate?, limit: Int) async throws -> [HistoryWeek] {
        let current = try await record(.historyWeeks)
        let zone = current.groups.first { $0.id == groupID }?.resolvedTimeZone ?? MemoryFormat.utc
        var weeks: [LocalDate: [PostWithMedia]] = [:]
        for post in current.posts where post.post.groupID == groupID {
            let day = LocalDate(post.post.createdAt, in: zone)
            // dayNumber 0 (1970-01-01) was a Thursday: Monday-based weekday = (dayNumber + 3) mod 7.
            let weekday = ((day.dayNumber + 3) % 7 + 7) % 7 // provenance-ok: calendar arithmetic (ISO weekday of the epoch)
            weeks[day.adding(days: -weekday), default: []].append(post)
        }
        return weeks.keys.sorted(by: >)
            .filter { start in before.map { start < $0 } ?? true }
            .prefix(max(1, limit))
            .map { start in
                HistoryWeek(weekStart: start, postIDs: (weeks[start] ?? []).sorted { $0.post.createdAt < $1.post.createdAt }.map(\.post.id))
            }
    }

    /// `delete_post`: own posts only; the post leaves every list and the group hears `post_deleted`.
    func deletePost(id: PostID) async throws {
        let current = try await record(.deletePost)
        guard let post = current.posts.first(where: { $0.post.id == id }) else { throw DataError.api(.postNotFound) }
        guard post.post.authorID == current.me else { throw DataError.api(.postNotFound) }
        update { state in
            state.posts.removeAll { $0.post.id == id }
            state.onThisDay.removeAll { $0.postID == id }
        }
        emitDeletion(postID: id, groupID: post.post.groupID)
    }

    func downloadData(from url: URL) async throws -> Data {
        _ = try await record(.downloadData)
        return Data(url.absoluteString.utf8)
    }

    func myPrivateProfile() async throws -> ProfilePrivate? {
        try await record(.myPrivateProfile).privateProfile
    }

    func setBirthday(_ birthday: LocalDate?, optIn: Bool) async throws -> ProfilePrivate {
        let current = try await record(.setBirthday)
        guard let me = current.me else { throw DataError.notSignedIn }
        if optIn, birthday == nil { throw DataError.api(.invalidArgument) }
        let row = ProfilePrivate(
            userID: me,
            birthday: optIn ? birthday : current.privateProfile?.birthday,
            birthdayOptIn: optIn,
            ageConfirmedAt: current.privateProfile?.ageConfirmedAt,
            updatedAt: current.now
        )
        update { $0.privateProfile = row }
        return row
    }

    func openRequests() async throws -> [TributeRequest] {
        let current = try await record(.openRequests)
        return current.requests.filter { $0.isOpen(at: current.now) }.sorted { $0.dueAt < $1.dueAt }
    }

    func request(id: TributeRequestID) async throws -> TributeRequest? {
        try await record(.request).requests.first { $0.id == id }
    }

    func myContribution(requestID: TributeRequestID) async throws -> TributeContribution? {
        let current = try await record(.myContribution)
        return current.contributions.first { $0.requestID == requestID && $0.contributorID == current.me }
    }

    /// `contribute_tribute` rules (docs/API.md §6.4).
    func contribute(requestID: TributeRequestID, postID: PostID, line: String) async throws -> TributeContribution {
        let current = try await record(.contribute)
        guard let me = current.me else { throw DataError.notSignedIn }
        guard let request = current.requests.first(where: { $0.id == requestID }), request.honoreeID != me else {
            throw DataError.api(.requestNotFound)
        }
        guard request.dueAt > current.now else { throw DataError.api(.tributeClosed) }
        guard let post = current.posts.first(where: { $0.post.id == postID }) else { throw DataError.api(.postNotFound) }
        guard post.post.groupID == request.groupID, post.post.authorID == me || current.myTags.contains(postID) else {
            throw DataError.api(.postNotEligible)
        }
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...280).contains(trimmed.count) else { throw DataError.api(.invalidLine) } // provenance-ok: API integrity bound of p_line (docs/API.md §3)
        let existing = current.contributions.first { $0.requestID == requestID }
        let row = TributeContribution(
            id: existing?.id ?? TributeContributionID(UUID()), requestID: requestID, contributorID: me, postID: postID,
            line: trimmed, createdAt: existing?.createdAt ?? current.now, updatedAt: current.now
        )
        update { state in
            state.contributions.removeAll { $0.requestID == requestID }
            state.contributions.append(row)
        }
        return row
    }

    func withdraw(requestID: TributeRequestID) async throws {
        let current = try await record(.withdraw)
        if let request = current.requests.first(where: { $0.id == requestID }), request.dueAt <= current.now {
            throw DataError.api(.tributeClosed)
        }
        update { $0.contributions.removeAll { $0.requestID == requestID } }
    }

    /// Own posts of the group, then posts the caller is self-tagged in; newest first, deduplicated
    /// (as `BirthdayRepository.eligiblePostIDs`).
    func eligiblePostIDs(groupID: GroupID) async throws -> [PostID] {
        let current = try await record(.eligiblePostIDs)
        let inGroup = current.posts.filter { $0.post.groupID == groupID }.sorted { $0.post.createdAt > $1.post.createdAt }
        let own = inGroup.filter { $0.post.authorID == current.me }.map(\.post.id)
        let tagged = inGroup.filter { current.myTags.contains($0.post.id) }.map(\.post.id)
        var seen = Set<PostID>()
        return (own + tagged).filter { seen.insert($0).inserted }
    }

    func tribute(id: TributeID) async throws -> Tribute? {
        try await record(.tribute).tributes.first { $0.id == id }
    }

    /// (as `group_tributes`, migration 0034): delivered and ready, the caller's own or one they contributed to, newest
    /// delivery first. The birthday is the request's, else the delivery day (requests close at 00:00 on the birthday).
    func groupTributes(groupID: GroupID) async throws -> [GroupTribute] {
        let current = try await record(.groupTributes)
        let contributed = Set(current.contributions.filter { $0.contributorID == current.me }.map(\.requestID))
        return current.tributes
            .filter { tribute in
                guard tribute.groupID == groupID, tribute.status == .ready, let delivered = tribute.deliveredAt,
                      delivered <= current.now else { return false }
                return tribute.honoreeID == current.me || contributed.contains(tribute.requestID)
            }
            .sorted { ($0.deliveredAt ?? $0.createdAt) > ($1.deliveredAt ?? $1.createdAt) }
            .map { tribute in
                let delivered = tribute.deliveredAt ?? tribute.createdAt
                let birthday = current.requests.first { $0.id == tribute.requestID }?.birthdayDate
                    ?? LocalDate(delivered, in: MemoryFormat.utc)
                return GroupTribute(
                    id: tribute.id, groupID: tribute.groupID, honoreeID: tribute.honoreeID, posterPath: tribute.posterPath,
                    birthdayDate: birthday, deliveredAt: delivered, forMe: tribute.honoreeID == current.me
                )
            }
    }

    func downloadFile(from url: URL, name: String) async throws -> URL {
        _ = try await record(.downloadFile)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try Data().write(to: file)
        return file
    }

    func yearStory(groupID: GroupID, year: Int) async throws -> YearStory? {
        try await record(.yearStory).yearStories.first { $0.groupID == groupID && $0.year == year }
    }

    func yearStories(groupID: GroupID) async throws -> [YearStory] {
        try await record(.yearStory).yearStories.filter { $0.groupID == groupID }.sorted { $0.year > $1.year }
    }

    func collages(ids: [CollageID]) async throws -> [Collage] {
        let wanted = Set(ids)
        return try await record(.collages).collages.filter { wanted.contains($0.id) }
    }

    func tags(postID: PostID) async throws -> [PostTag] {
        let current = try await record(.tags)
        guard let post = current.posts.first(where: { $0.post.id == postID }) else { return [] }
        var users = current.otherTags[postID] ?? []
        if let me = current.me, current.myTags.contains(postID) { users.append(me) }
        return users.enumerated().map { offset, user in
            PostTag(postID: postID, userID: user, groupID: post.post.groupID, createdAt: current.now.addingTimeInterval(TimeInterval(offset)))
        }
    }

    func isTagged(postID: PostID) async throws -> Bool {
        try await record(.isTagged).myTags.contains(postID)
    }

    func tagSelf(postID: PostID) async throws {
        let current = try await record(.tagSelf)
        guard current.posts.contains(where: { $0.post.id == postID }) else { throw DataError.api(.postNotFound) }
        update { _ = $0.myTags.insert(postID) }
    }

    func untagSelf(postID: PostID) async throws {
        _ = try await record(.untagSelf)
        update { _ = $0.myTags.remove(postID) }
    }
}

// MARK: - The fixture scenario (UI tests, previews, snapshots)

/// Fixed ids, shared with AppUITests/Memory (which repeats them; it cannot import the app). In the Jolt demo build
/// (`DemoMode`) the people and the group are the social demo's (Sam, Ana, Ben in "roommates"), so the memory cards on
/// that group's screen and every memory screen belong to the same world.
enum MemoryFixtureIDs {
    static var me: UserID { DemoMode.isOn ? SocialDemo.me : UserID("00000000-0000-4000-8000-0000000000a1") }
    static var friend: UserID { DemoMode.isOn ? SocialDemo.ana : UserID("00000000-0000-4000-8000-0000000000a2") }
    static var other: UserID { DemoMode.isOn ? SocialDemo.ben : UserID("00000000-0000-4000-8000-0000000000a3") }
    static var group: GroupID { DemoMode.isOn ? SocialDemo.groupID : GroupID("00000000-0000-4000-8000-0000000000b1") }
    static let request = TributeRequestID("00000000-0000-4000-8000-0000000000c1")
    static let tribute = TributeID("00000000-0000-4000-8000-0000000000d1")
    static let collage = CollageID("00000000-0000-4000-8000-0000000000e1")
    static func post(_ number: Int) -> PostID { PostID("00000000-0000-4000-8000-0000000001" + String(format: "%02d", number)) }
    static func media(_ number: Int) -> MediaID { MediaID("00000000-0000-4000-8000-0000000002" + String(format: "%02d", number)) }
}

extension FixtureMemoryData {
    /// The process-wide fixtures of a UI-test run (`-MemoryFixtures`).
    static let uiTest = FixtureMemoryData.scenario(now: Date())

    /// A group with three members, posts across the year and earlier years, an open birthday request
    /// about the friend, a delivered tribute for the caller and a ready year story.
    static func scenario(now: Date) -> FixtureMemoryData {
        let ids = MemoryFixtureIDs.self
        let zone = DemoMode.isOn ? TimeZone.current : TimeZone(identifier: "UTC")! // provenance-ok: fixture group time zone
        let day: TimeInterval = 86_400 // provenance-ok: seconds per day (fixture arithmetic)
        let today = LocalDate(now, in: zone)
        let year = today.year
        func profile(_ id: UserID, _ name: String) -> Profile {
            // The Jolt demo: the social demo's people, with their avatars (`DemoPhotos`).
            if DemoMode.isOn, let person = SocialDemo.profiles.first(where: { $0.id == id }) { return person }
            return Profile(id: id, displayName: name, avatarPath: "avatars/\(id.rawValue)/a.jpg", createdAt: now, updatedAt: now) // provenance-ok: storage path
        }
        func post(_ number: Int, author: UserID, at date: Date, shape: (Int, Int)) -> PostWithMedia {
            let mediaID = ids.media(number)
            let base = "u/\(author.rawValue)/\(mediaID.rawValue)/" // provenance-ok: storage path
            let media = Media(
                id: mediaID, ownerID: author, kind: .photo, originalPath: base + "original.jpg",
                displayPath: base + "r/display.jpg", thumbPath: base + "r/thumb.jpg", widgetPath: base + "r/widget.jpg",
                width: shape.0, height: shape.1, renditionsReadyAt: date, createdAt: date
            )
            return PostWithMedia(post: Post(id: ids.post(number), mediaID: mediaID, groupID: ids.group, authorID: author, createdAt: date), media: media)
        }
        func yearsAgo(_ years: Int, hour: Int) -> Date {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let base = calendar.date(byAdding: .year, value: -years, to: now) ?? now
            return calendar.date(bySettingHour: hour, minute: 34, second: 0, of: base) ?? base
        }

        var state = State()
        state.me = ids.me
        state.now = now
        state.groups = [PhotoGroup(
            id: ids.group, name: DemoMode.isOn ? "roommates" : "Sunday dinners", kind: .friends, // provenance-ok: fixture data
            coverPath: DemoMode.isOn ? "fake/cover/01" : nil, timeZone: zone.identifier, // provenance-ok: fixture data
            wakingStart: nil, wakingEnd: nil, invitationPaused: false, createdBy: ids.me, createdAt: now, updatedAt: now
        )]
        state.profiles = [profile(ids.me, "Ana Lima"), profile(ids.friend, "Bea Costa"), profile(ids.other, "Caio Dias")] // provenance-ok: fixture data
        state.posts = [
            post(1, author: ids.me, at: now - 2 * day, shape: (3, 4)),
            post(2, author: ids.friend, at: now - 3 * day, shape: (4, 3)),
            post(3, author: ids.other, at: now - 4 * day, shape: (3, 4)),
            post(4, author: ids.me, at: now - 30 * day, shape: (1, 1)),
            post(5, author: ids.friend, at: now - 40 * day, shape: (3, 4)),
            post(6, author: ids.friend, at: yearsAgo(1, hour: 22), shape: (3, 4)),
            post(7, author: ids.other, at: yearsAgo(3, hour: 18), shape: (4, 3)),
            post(8, author: ids.me, at: yearsAgo(3, hour: 19), shape: (3, 4)),
            post(9, author: ids.friend, at: yearsAgo(3, hour: 20), shape: (3, 5)),
        ]
        state.myTags = [ids.post(2)]
        state.otherTags = [ids.post(2): [ids.friend], ids.post(5): [ids.other], ids.post(6): [ids.friend, ids.other]]
        state.onThisDay = [
            OnThisDayItem(postID: ids.post(6), mediaID: ids.media(6), authorID: ids.friend, createdAt: yearsAgo(1, hour: 22), yearsAgo: 1),
            OnThisDayItem(postID: ids.post(9), mediaID: ids.media(9), authorID: ids.friend, createdAt: yearsAgo(3, hour: 20), yearsAgo: 3),
            OnThisDayItem(postID: ids.post(8), mediaID: ids.media(8), authorID: ids.me, createdAt: yearsAgo(3, hour: 19), yearsAgo: 3),
            OnThisDayItem(postID: ids.post(7), mediaID: ids.media(7), authorID: ids.other, createdAt: yearsAgo(3, hour: 18), yearsAgo: 3),
        ]
        let birthday = today.adding(days: 7)
        state.requests = [TributeRequest(
            id: ids.request, groupID: ids.group, honoreeID: ids.friend, birthdayDate: birthday,
            dueAt: now + 7 * day, closedAt: nil, createdAt: now
        )]
        state.tributes = [Tribute(
            id: ids.tribute, requestID: TributeRequestID(UUID()), groupID: ids.group, honoreeID: ids.me,
            videoPath: "g/\(ids.group.rawValue)/tributes/\(ids.tribute.rawValue)/video.mp4", // provenance-ok: storage path
            posterPath: "g/\(ids.group.rawValue)/tributes/\(ids.tribute.rawValue)/poster.jpg", // provenance-ok: storage path
            status: .ready, renderedAt: now - day, deliveredAt: now - day / 2, createdAt: now - day
        )]
        let collageDate = LocalDate(year: year, month: 6, day: 14) ?? today // provenance-ok: fixture date
        state.collages = [Collage(
            id: ids.collage, groupID: ids.group, invitationID: nil, option: "B", postIDs: [ids.post(1), ids.post(2), ids.post(3)], // provenance-ok: fixture data
            imagePath: "g/\(ids.group.rawValue)/collages/\(ids.collage.rawValue)/v1/display-1.jpg", // provenance-ok: storage path
            widgetPath: nil, sharePath: nil, status: .ready, composedAt: now, createdAt: now
        )]
        let data: JSONValue = .object([
            "version": .number(1),
            "year": .number(Double(year)),
            "time_zone": .string(zone.identifier),
            "moments_shared": .number(128), // provenance-ok: fixture data
            "busiest_month": .object(["month": .number(7)]), // provenance-ok: fixture data
            "most_reacted": .array([ids.post(2), ids.post(1), ids.post(3)].map { .string($0.rawValue) }),
            "everyone_days": .array([.object([
                "local_date": .string(collageDate.description),
                "invitation_id": .string(UUID().uuidString.lowercased()),
                "collage_id": .string(ids.collage.rawValue),
                "post_ids": .array([ids.post(1), ids.post(2), ids.post(3)].map { .string($0.rawValue) }),
            ])]),
            "self_tagged": .array([ids.post(5), ids.post(2)].map { .string($0.rawValue) }),
        ])
        state.yearStories = [YearStory(
            id: YearStoryID(UUID()), groupID: ids.group, year: year, status: .ready, data: data,
            postIDs: state.posts.map(\.post.id), assetPaths: [], generatedAt: now, createdAt: now
        )]
        return FixtureMemoryData(state)
    }
}

// MARK: - UI-test launch

/// Launch arguments of the memory UI tests (ios/AppUITests/Memory):
/// `-MemoryFixtures` runs every memory screen on `FixtureMemoryData.uiTest`;
/// `-MemoryOpen <screen>` (request, contribute, tribute, yearStory, onThisDay, birthdayAdd) is the
/// screen the test starts on. `apply(to:)` must be called once the person is home (shell, DEBUG).
enum MemoryLaunch {
    /// `-MemoryFixtures` (or the Jolt demo build, `DemoMode`).
    static var usesFixtures: Bool {
        DemoMode.launchArguments.contains("-" + MemoryDependencies.fixturesArgument)
    }

    static var openArgument: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-MemoryOpen"), arguments.indices.contains(index + 1) else { return nil } // provenance-ok: launch argument
        return arguments[index + 1]
    }

    @MainActor
    static func apply(to router: AppRouter) {
        guard usesFixtures, let screen = openArgument else { return }
        let ids = MemoryFixtureIDs.self
        let group = ids.group.rawValue
        switch screen {
        case "request":
            router.path = [.birthdayRequest(requestID: ids.request.rawValue, groupID: group)]
        case "contribute":
            router.modal = .memory(.birthdayContribute(requestID: ids.request.rawValue))
        case "tribute":
            router.path = [.tribute(tributeID: ids.tribute.rawValue, groupID: group)]
        case "yearStory":
            let year = LocalDate(Date(), in: MemoryFormat.utc).year
            router.modal = .memory(.yearStory(groupID: group, year: year))
        case "onThisDay":
            router.path = [.memory(.onThisDay(groupID: group))]
        case "birthdayAdd":
            router.path = [.memory(.birthdayAdd)]
        default:
            break
        }
    }
}
#endif

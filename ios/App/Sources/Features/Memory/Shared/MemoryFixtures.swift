// DEBUG only: an in-memory `MemoryDataSource` for unit tests (AppTests/Memory), snapshot tests and
// UI tests (AppUITests/Memory, launch argument `-MemoryFixtures`). It answers like the backend
// (docs/API.md) except that it does not hide rows by RLS, so the screens' own guards are exercised.
#if DEBUG
import AppData
import AppModels
import Foundation

final class FixtureMemoryData: MemoryDataSource, @unchecked Sendable {
    enum Operation: String, CaseIterable, Sendable {
        case group, postsWithMedia, profiles, signedURLs, onThisDay, myPrivateProfile, setBirthday
        case openRequests, request, myContribution, contribute, withdraw, eligiblePostIDs
        case tribute, downloadFile, yearStory, collages, isTagged, tagSelf, untagSelf
    }

    struct State {
        var me: UserID?
        var network: NetworkStatus = .online
        var groups: [PhotoGroup] = []
        var posts: [PostWithMedia] = []
        var profiles: [Profile] = []
        var onThisDay: [OnThisDayItem] = []
        var privateProfile: ProfilePrivate?
        var requests: [TributeRequest] = []
        /// The caller's own contributions.
        var contributions: [TributeContribution] = []
        /// Posts the caller tagged themselves in.
        var myTags: Set<PostID> = []
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
            result[path] = URL(string: "fixture://" + path) // provenance-ok: fixture URL scheme
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

    func onThisDay(groupID: GroupID, localDate: LocalDate) async throws -> [OnThisDayItem] {
        let current = try await record(.onThisDay)
        let groupPosts = Set(current.posts.filter { $0.post.groupID == groupID }.map(\.post.id))
        return current.onThisDay.filter { groupPosts.contains($0.postID) }
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

    func downloadFile(from url: URL, name: String) async throws -> URL {
        _ = try await record(.downloadFile)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try Data().write(to: file)
        return file
    }

    func yearStory(groupID: GroupID, year: Int) async throws -> YearStory? {
        try await record(.yearStory).yearStories.first { $0.groupID == groupID && $0.year == year }
    }

    func collages(ids: [CollageID]) async throws -> [Collage] {
        let wanted = Set(ids)
        return try await record(.collages).collages.filter { wanted.contains($0.id) }
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

/// Fixed ids, shared with AppUITests/Memory (which repeats them; it cannot import the app).
enum MemoryFixtureIDs {
    static let me = UserID("00000000-0000-4000-8000-0000000000a1")
    static let friend = UserID("00000000-0000-4000-8000-0000000000a2")
    static let other = UserID("00000000-0000-4000-8000-0000000000a3")
    static let group = GroupID("00000000-0000-4000-8000-0000000000b1")
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
        let zone = TimeZone(identifier: "UTC")! // provenance-ok: fixture group time zone
        let day: TimeInterval = 86_400 // provenance-ok: seconds per day (fixture arithmetic)
        let today = LocalDate(now, in: zone)
        let year = today.year
        func profile(_ id: UserID, _ name: String) -> Profile {
            Profile(id: id, displayName: name, avatarPath: nil, createdAt: now, updatedAt: now)
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
            id: ids.group, name: "Sunday dinners", kind: .friends, coverPath: nil, timeZone: zone.identifier, // provenance-ok: fixture data
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
    static var usesFixtures: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-" + MemoryDependencies.fixturesArgument)
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
            router.modal = .memory(.onThisDay(groupID: group))
        case "birthdayAdd":
            router.path = [.memory(.birthdayAdd)]
        default:
            break
        }
    }
}
#endif

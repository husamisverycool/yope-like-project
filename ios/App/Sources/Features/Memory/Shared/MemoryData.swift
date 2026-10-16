// Data access for the memory group (onthisday, birthday.*, year.story, tagging).
// Everything goes through AppData (docs/API.md); this file only narrows it to what the memory
// screens use, so view models can be tested with fakes (AppTests/Memory) and the UI tests can run
// on fixtures (launch argument, MemoryDependencies).
import AppData
import AppModels
import Foundation

/// What the memory screens read and write. `LiveMemoryData` forwards to AppData's repositories;
/// `FixtureMemoryData` (DEBUG) serves fixed rows for previews, unit tests and UI tests.
protocol MemoryDataSource: Sendable {
    /// The signed-in user (nil when signed out).
    func currentUser() async -> UserID?
    /// The data layer's reachability reading.
    func networkStatus() async -> NetworkStatus

    // Groups, posts, people, files
    func group(id: GroupID) async throws -> PhotoGroup?
    /// Visible posts among `ids` with their media, in the order of `ids` (RLS drops hidden ones).
    func postsWithMedia(ids: [PostID]) async throws -> [PostWithMedia]
    func profiles(ids: [UserID]) async throws -> [Profile]
    /// Signed URLs (1 h) for storage paths; unreadable paths are absent.
    func signedURLs(paths: [String]) async throws -> [String: URL]
    /// `post_deleted` broadcasts of one group (docs/API.md §8.2).
    func deletedPosts(groupID: GroupID) -> AsyncStream<PostID>

    // onthisday
    func onThisDay(groupID: GroupID, localDate: LocalDate) async throws -> [OnThisDayItem]
    /// `group_history_weeks` (newest first; `free_history_days` applied by the server) — the shuffle's pool.
    func historyWeeks(groupID: GroupID, before: LocalDate?, limit: Int) async throws -> [HistoryWeek]
    /// `delete_post` (own post).
    func deletePost(id: PostID) async throws
    /// The bytes at a (signed) file URL (the original photo, for saving).
    func downloadData(from url: URL) async throws -> Data

    // birthday.add
    func myPrivateProfile() async throws -> ProfilePrivate?
    func setBirthday(_ birthday: LocalDate?, optIn: Bool) async throws -> ProfilePrivate

    // birthday.request / birthday.contribute
    /// Open requests visible to the caller (RLS hides requests about the caller).
    func openRequests() async throws -> [TributeRequest]
    func request(id: TributeRequestID) async throws -> TributeRequest?
    func myContribution(requestID: TributeRequestID) async throws -> TributeContribution?
    func contribute(requestID: TributeRequestID, postID: PostID, line: String) async throws -> TributeContribution
    func withdraw(requestID: TributeRequestID) async throws
    /// Posts of the group the caller posted or is self-tagged in, newest first, deduplicated.
    func eligiblePostIDs(groupID: GroupID) async throws -> [PostID]

    // birthday.tribute
    func tribute(id: TributeID) async throws -> Tribute?
    /// Downloads a (signed) file URL to a local file that stays until the next download of `name`.
    func downloadFile(from url: URL, name: String) async throws -> URL

    // year.story
    func yearStory(groupID: GroupID, year: Int) async throws -> YearStory?
    func collages(ids: [CollageID]) async throws -> [Collage]

    // tagging
    /// The post's self-tags, in tag order (`post_tags`, RLS: the group's members).
    func tags(postID: PostID) async throws -> [PostTag]
    func isTagged(postID: PostID) async throws -> Bool
    func tagSelf(postID: PostID) async throws
    func untagSelf(postID: PostID) async throws
}

/// The failure kinds the memory screens tell apart (each maps to a state in its spec).
enum MemoryFailure: Equatable, Sendable {
    case offline
    case notFound
    case closed
    case notEligible
    case generic

    init(_ error: Error) {
        switch DataError.from(error) {
        case .offline:
            self = .offline
        case .api(.requestNotFound, _), .api(.postNotFound, _), .api(.mediaNotFound, _), .storage(.notFound):
            self = .notFound
        case .api(.tributeClosed, _):
            self = .closed
        case .api(.postNotEligible, _):
            self = .notEligible
        default:
            self = .generic
        }
    }
}

/// AppData-backed source used by the app.
struct LiveMemoryData: MemoryDataSource {
    let environment: DataEnvironment

    func currentUser() async -> UserID? {
        environment.auth.currentUserID
    }

    func networkStatus() async -> NetworkStatus {
        environment.reachability.currentStatus
    }

    func group(id: GroupID) async throws -> PhotoGroup? {
        try await environment.groups.group(id: id)
    }

    func postsWithMedia(ids: [PostID]) async throws -> [PostWithMedia] {
        let posts = try await environment.posts.posts(ids: ids)
        return try await environment.posts.withMedia(posts)
    }

    func profiles(ids: [UserID]) async throws -> [Profile] {
        try await environment.profiles.profiles(ids: ids)
    }

    func signedURLs(paths: [String]) async throws -> [String: URL] {
        guard !paths.isEmpty else { return [:] }
        return try await environment.signedURLs.urls(for: paths)
    }

    func deletedPosts(groupID: GroupID) -> AsyncStream<PostID> {
        let events = environment.realtime.events(for: groupID, filter: .deletions)
        return AsyncStream { continuation in
            let task = Task {
                for await event in events {
                    if case let .postDeleted(postID, _) = event {
                        continuation.yield(postID)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func onThisDay(groupID: GroupID, localDate: LocalDate) async throws -> [OnThisDayItem] {
        try await environment.memories.onThisDay(groupID: groupID, localDate: localDate)
    }

    func historyWeeks(groupID: GroupID, before: LocalDate?, limit: Int) async throws -> [HistoryWeek] {
        try await environment.memories.historyWeeks(groupID: groupID, beforeWeek: before, limit: limit)
    }

    func deletePost(id: PostID) async throws {
        try await environment.posts.deletePost(id: id)
    }

    func downloadData(from url: URL) async throws -> Data {
        do {
            return try await URLSession.shared.data(from: url).0
        } catch {
            throw DataError.from(error)
        }
    }

    func myPrivateProfile() async throws -> ProfilePrivate? {
        try await environment.profiles.myPrivateProfile()
    }

    func setBirthday(_ birthday: LocalDate?, optIn: Bool) async throws -> ProfilePrivate {
        try await environment.birthdays.setBirthday(birthday, optIn: optIn)
    }

    func openRequests() async throws -> [TributeRequest] {
        try await environment.birthdays.openRequests()
    }

    func request(id: TributeRequestID) async throws -> TributeRequest? {
        try await environment.birthdays.request(id: id)
    }

    func myContribution(requestID: TributeRequestID) async throws -> TributeContribution? {
        try await environment.birthdays.myContribution(requestID: requestID)
    }

    func contribute(requestID: TributeRequestID, postID: PostID, line: String) async throws -> TributeContribution {
        try await environment.birthdays.contribute(requestID: requestID, postID: postID, line: line)
    }

    func withdraw(requestID: TributeRequestID) async throws {
        try await environment.birthdays.withdraw(requestID: requestID)
    }

    func eligiblePostIDs(groupID: GroupID) async throws -> [PostID] {
        try await environment.birthdays.eligiblePostIDs(groupID: groupID)
    }

    func tribute(id: TributeID) async throws -> Tribute? {
        try await environment.birthdays.tribute(id: id)
    }

    func downloadFile(from url: URL, name: String) async throws -> URL {
        do {
            let (temporary, _) = try await URLSession.shared.download(from: url)
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MemoryDownloads", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: temporary, to: destination)
            return destination
        } catch {
            throw DataError.from(error)
        }
    }

    func yearStory(groupID: GroupID, year: Int) async throws -> YearStory? {
        try await environment.memories.yearStory(groupID: groupID, year: year)
    }

    func collages(ids: [CollageID]) async throws -> [Collage] {
        var result: [Collage] = []
        for id in ids {
            if let collage = try await environment.memories.collage(id: id) {
                result.append(collage)
            }
        }
        return result
    }

    func tags(postID: PostID) async throws -> [PostTag] {
        try await environment.reactions.tags(postID: postID)
    }

    func isTagged(postID: PostID) async throws -> Bool {
        let me = try await environment.client.requireUserID()
        return try await environment.reactions.tags(postID: postID).contains { $0.userID == me }
    }

    func tagSelf(postID: PostID) async throws {
        try await environment.reactions.tagSelf(postID: postID)
    }

    func untagSelf(postID: PostID) async throws {
        try await environment.reactions.untagSelf(postID: postID)
    }
}

import AppModels
import Foundation
import XCTest
@testable import AppData

/// Offline cache, reachability and the session glue's local effects (no network).
final class OfflineTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("OfflineTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func post(_ id: String, group: String, media: String? = nil) -> Post {
        Post(id: PostID(id), mediaID: MediaID(media ?? "m-\(id)"), groupID: GroupID(group), authorID: UserID("u"), createdAt: Date(timeIntervalSince1970: 1_000))
    }

    func testWriteReadAndSavedAt() async throws {
        let cache = OfflineCache(directory: directory, now: { Date(timeIntervalSince1970: 42) })
        let groups = [PhotoGroup(id: GroupID("g1"), name: "Family", kind: .family, coverPath: nil, timeZone: "Europe/Paris",
                                 wakingStart: nil, wakingEnd: nil, invitationPaused: false, createdBy: nil,
                                 createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: 2))]
        await cache.write(groups, for: .groups)
        let value1 = await cache.read([PhotoGroup].self, for: .groups)
        let cached = try XCTUnwrap(value1)
        XCTAssertEqual(cached.value, groups)
        XCTAssertEqual(cached.savedAt, Date(timeIntervalSince1970: 42))
        let wrongType = await cache.read([Message].self, for: .groups)
        XCTAssertNil(wrongType)
        let missing = await cache.read([PhotoGroup].self, for: .feed(GroupID("nope")))
        XCTAssertNil(missing)
    }

    func testDeletionsArePurgedFromEveryCachedScreen() async throws {
        let cache = OfflineCache(directory: directory)
        let g1 = GroupID("g1")
        let g2 = GroupID("g2")
        // The same photo posted to two groups: deleting g1's post keeps g2's.
        await cache.write([PostWithMedia(post: post("p1", group: "g1", media: "m1"), media: nil),
                           PostWithMedia(post: post("p2", group: "g1"), media: nil)], for: .feed(g1))
        await cache.write([PostWithMedia(post: post("p3", group: "g2", media: "m1"), media: nil)], for: .feed(g2))
        await cache.write([
            Message(id: MessageID("msg-photo"), groupID: g1, authorID: UserID("u"), kind: .photo, postID: PostID("p1"), createdAt: Date()),
            Message(id: MessageID("msg-text"), groupID: g1, authorID: UserID("u"), kind: .text, body: "hi", createdAt: Date()),
        ], for: .chat(g1))
        await cache.write([WallItem(itemKind: .post, postID: PostID("p1"), mediaID: MediaID("m1"), collageID: nil, groupIDs: [g1, g2], createdAt: Date())],
                          for: .wall(UserID("u")))
        await cache.write([HistoryWeek(weekStart: LocalDate("2026-10-12")!, postIDs: [PostID("p1")]),
                           HistoryWeek(weekStart: LocalDate("2026-10-05")!, postIDs: [PostID("p2"), PostID("p1")])], for: .history(g1))
        await cache.write([AlbumWithItems(album: Album(id: AlbumID("a"), groupID: g1, name: "A", createdBy: nil, createdAt: Date(), updatedAt: Date()),
                                          postIDs: [PostID("p1"), PostID("p2")])], for: .albums(g1))

        await cache.purgePost(PostID("p1"))

        let feed1 = await cache.read([PostWithMedia].self, for: .feed(g1))?.value.map(\.id)
        XCTAssertEqual(feed1, [PostID("p2")])
        let feed2 = await cache.read([PostWithMedia].self, for: .feed(g2))?.value.map(\.id)
        XCTAssertEqual(feed2, [PostID("p3")], "other groups keep their copy")
        let chat = await cache.read([Message].self, for: .chat(g1))?.value.map(\.id)
        XCTAssertEqual(chat, [MessageID("msg-text")])
        let wall = await cache.read([WallItem].self, for: .wall(UserID("u")))?.value
        XCTAssertEqual(wall?.count, 0)
        let weeks = await cache.read([HistoryWeek].self, for: .history(g1))?.value
        XCTAssertEqual(weeks?.map(\.postIDs), [[PostID("p2")]])
        let albums = await cache.read([AlbumWithItems].self, for: .albums(g1))?.value
        XCTAssertEqual(albums?.first?.postIDs, [PostID("p2")])

        await cache.purgeMessage(MessageID("msg-text"), groupID: g1)
        let emptyChat = await cache.read([Message].self, for: .chat(g1))?.value
        XCTAssertEqual(emptyChat, [])

        await cache.removeGroup(g1)
        let removedFeed = await cache.read([PostWithMedia].self, for: .feed(g1))
        XCTAssertNil(removedFeed)
        let keptFeed = await cache.read([PostWithMedia].self, for: .feed(g2))
        XCTAssertNotNil(keptFeed)

        await cache.removeAll()
        let afterReset = await cache.read([PostWithMedia].self, for: .feed(g2))
        XCTAssertNil(afterReset)
    }

    func testReachabilityStreamReportsOnLinux() async {
        let reachability = Reachability()
        var iterator = reachability.updates().makeAsyncIterator()
        let first = await iterator.next()
        #if canImport(Network)
        XCTAssertNotNil(first)
        #else
        XCTAssertEqual(first, .unknown)
        let end = await iterator.next()
        XCTAssertNil(end, "no-op on Linux: one value, then finished")
        #endif
    }

    func testCoordinatorRemovesDeletedPostsFromTheWidgetStoreWithoutNetwork() async throws {
        let widgetStore = WidgetStore(rootURL: directory.appendingPathComponent("widgets"))
        try widgetStore.syncGroups([WidgetGroup(id: "g1", name: "Family")])
        let photo = WidgetSnapshot(groupID: "g1", sourceID: "p1", photoFileName: "photo-p1.jpg", kind: .photo, postedAt: Date(timeIntervalSince1970: 1_000))
        let other = WidgetSnapshot(groupID: "g1", sourceID: "p2", photoFileName: "photo-p2.jpg", kind: .photo, postedAt: Date(timeIntervalSince1970: 1_000))
        try widgetStore.writeFile(Data([1]), groupID: "g1", fileName: photo.photoFileName)
        try widgetStore.save(photo)
        let collage = WidgetSnapshot(groupID: "g1", sourceID: "c1", photoFileName: "collage-c1.jpg", kind: .collage, postedAt: Date(timeIntervalSince1970: 1_000))
        try widgetStore.writeFile(Data([2]), groupID: "g1", fileName: collage.photoFileName)
        try widgetStore.save(collage)

        // Unreachable backend: the collage cannot be checked, so it is removed (deletions win).
        let client = DataClient(configuration: DataConfiguration(url: URL(string: "http://127.0.0.1:9")!, anonKey: "anon")) { nil }
        let data = DataEnvironment(client: client, directories: .under(directory.appendingPathComponent("env")),
                                   uploadTransport: FoundationUploadTransport(), widgetStore: widgetStore)
        await data.coordinator.handle(.postDeleted(postID: PostID("p1"), mediaID: MediaID("m1")), groupID: GroupID("g1"))
        XCTAssertNil(widgetStore.snapshot(groupID: "g1", kind: .photo))
        XCTAssertNil(widgetStore.snapshot(groupID: "g1", kind: .collage))
        XCTAssertNil(widgetStore.photoURL(for: photo))

        // A deletion of another post leaves an unrelated photo snapshot alone.
        try widgetStore.writeFile(Data([3]), groupID: "g1", fileName: other.photoFileName)
        try widgetStore.save(other)
        await data.coordinator.handle(.postDeleted(postID: PostID("p9"), mediaID: nil), groupID: GroupID("g1"))
        XCTAssertEqual(widgetStore.snapshot(groupID: "g1", kind: .photo), other)
    }

    func testUploadLedgerPersists() throws {
        let url = directory.appendingPathComponent("ledger.json")
        let ledger = UploadLedger(fileURL: url)
        ledger.markCompleted("u/a/b/original.jpg")
        ledger.setResumableLocation(URL(string: "https://x/upload/resumable/abc"), for: "u/a/b/original.mp4")
        let reopened = UploadLedger(fileURL: url)
        XCTAssertTrue(reopened.isCompleted("u/a/b/original.jpg"))
        XCTAssertEqual(reopened.resumableLocation(for: "u/a/b/original.mp4")?.absoluteString, "https://x/upload/resumable/abc")
        reopened.forget(["u/a/b/original.jpg", "u/a/b/original.mp4"])
        XCTAssertFalse(UploadLedger(fileURL: url).isCompleted("u/a/b/original.jpg"))
    }

    func testRetryPolicyBacksOffAndCaps() {
        let policy = RetryPolicy(maxAttempts: 5, baseDelay: 1, maxDelay: 5)
        XCTAssertEqual((1...5).map { policy.delay(afterAttempt: $0) }, [1, 2, 4, 5, 5])
    }

    func testNotConfiguredWithoutSupabaseValues() {
        XCTAssertThrowsError(try DataConfiguration(AppConfiguration())) { error in
            XCTAssertEqual(error as? DataError, .notConfigured)
        }
        let configured = try? DataConfiguration(AppConfiguration(supabaseURL: URL(string: "https://x.supabase.co"), supabaseAnonKey: "k"))
        XCTAssertEqual(configured?.storageURL.absoluteString, "https://x.supabase.co/storage/v1")
    }
}

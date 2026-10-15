import AppModels
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import AppData

/// Uploads against local Storage: retries after lost responses, the resumable (TUS) path for
/// large files with an interrupted chunk, and the post outbox surviving a "relaunch".
final class UploadIntegrationTests: XCTestCase {
    private var users: TestUsers!

    override func setUp() async throws {
        try await LocalStack.require()
        users = TestUsers()
    }

    override func tearDown() async throws {
        await users?.cleanUp()
    }

    /// Fails chosen requests: before sending ("offline") or after the server handled them
    /// ("connection lost" — the classic case where a retry meets an object that already exists).
    final class FlakyTransport: UploadTransport, @unchecked Sendable {
        enum Failure { case beforeSending, afterSending }
        private let lock = NSLock()
        private var plan: [Failure?]
        private(set) var methods: [String] = []
        let inner = FoundationUploadTransport()

        init(plan: [Failure?]) {
            self.plan = plan
        }

        private func next(_ method: String) -> Failure? {
            lock.lock()
            defer { lock.unlock() }
            methods.append(method)
            return plan.isEmpty ? nil : plan.removeFirst()
        }

        var sentMethods: [String] {
            lock.lock()
            defer { lock.unlock() }
            return methods
        }

        func send(_ request: URLRequest, bodyFile: URL?) async throws -> (Data, HTTPURLResponse) {
            switch next(request.httpMethod ?? "GET") {
            case .beforeSending?:
                throw URLError(.notConnectedToInternet)
            case .afterSending?:
                _ = try await inner.send(request, bodyFile: bodyFile)
                throw URLError(.networkConnectionLost)
            case nil:
                return try await inner.send(request, bodyFile: bodyFile)
            }
        }
    }

    private let fastRetry = RetryPolicy(maxAttempts: 4, baseDelay: 0.05, maxDelay: 0.2)

    func testRetryAfterLostResponseFindsTheObjectAlreadyThere() async throws {
        let ana = try await users.make("Ana")
        let transport = FlakyTransport(plan: [.beforeSending, .afterSending])
        let uploader = MediaUploader(client: ana.client, transport: transport, retry: fastRetry)
        let path = StoragePaths.original(owner: ana.id, media: .generate(), fileExtension: "jpg")
        try await uploader.upload(data: tinyJPEG, path: path, contentType: ContentType.jpeg)
        XCTAssertEqual(transport.sentMethods, ["POST", "POST", "POST"], "offline, lost response, then 'already exists'")
        let url = try await ana.data.signedURLs.url(for: path)
        let (data, _) = try await URLSession.shared.data(from: url)
        XCTAssertEqual(data, tinyJPEG)
    }

    func testPermanentErrorsAreNotRetried() async throws {
        let ana = try await users.make("Ana")
        let transport = FlakyTransport(plan: [])
        let uploader = MediaUploader(client: ana.client, transport: transport, retry: fastRetry)
        await assertThrows(.storage(.invalidContentType)) {
            try await uploader.upload(data: Data("hello".utf8), path: "u/\(ana.id.rawValue)/x/notes.txt", contentType: "text/plain")
        }
        XCTAssertEqual(transport.sentMethods.count, 1)
        await assertThrows(.api(.invalidPath)) {
            try await uploader.upload(data: tinyJPEG, path: "u/\(ana.id.rawValue)/../x.jpg", contentType: ContentType.jpeg)
        }
    }

    func testResumableUploadContinuesFromTheServerOffset() async throws {
        let ana = try await users.make("Ana")
        let size = MediaUploader.chunkSize + 512 * 1024
        var bytes = Data(count: size)
        for index in stride(from: 0, to: size, by: 4096) { bytes[index] = UInt8(truncatingIfNeeded: index / 4096) }
        let file = try temporaryFile(bytes, extension: "mp4")
        // create, PATCH #1 lost after the server stored it, HEAD, PATCH #2 offline, HEAD, PATCH #2.
        let transport = FlakyTransport(plan: [nil, .afterSending, nil, .beforeSending])
        let ledgerURL = FileManager.default.temporaryDirectory.appendingPathComponent("ledger-\(UUID().uuidString).json")
        addTeardownBlock { try? FileManager.default.removeItem(at: ledgerURL) }
        let ledger = UploadLedger(fileURL: ledgerURL)
        let uploader = MediaUploader(client: ana.client, transport: transport, ledger: ledger, retry: fastRetry)
        let mediaID = MediaID.generate()
        let path = StoragePaths.original(owner: ana.id, media: mediaID, fileExtension: "mp4")
        try await uploader.upload(UploadItem(path: path, fileURL: file, contentType: ContentType.mp4))
        XCTAssertEqual(transport.sentMethods, ["POST", "PATCH", "HEAD", "PATCH", "HEAD", "PATCH"])
        XCTAssertTrue(ledger.isCompleted(path))
        XCTAssertNil(ledger.resumableLocation(for: path))

        let url = try await ana.data.signedURLs.url(for: path)
        let (downloaded, _) = try await URLSession.shared.data(from: url)
        XCTAssertEqual(downloaded.count, size)
        XCTAssertEqual(downloaded, bytes)

        // A second upload of the same path is skipped (ledger) and, without a ledger, answered
        // "already exists" by the server.
        try await uploader.upload(UploadItem(path: path, fileURL: file, contentType: ContentType.mp4))
        let fresh = MediaUploader(client: ana.client, transport: FoundationUploadTransport(), retry: fastRetry)
        try await fresh.upload(UploadItem(path: path, fileURL: file, contentType: ContentType.mp4))

        // Clean up through the API: a media row owning the object, then delete_media.
        try await ana.data.posts.insertMedia(NewMedia(id: mediaID, kind: .video, originalPath: path, durationMs: 1000))
        try await ana.data.posts.deleteMedia(id: mediaID)
    }

    func testOutboxSurvivesFailureAndResumesAfterRelaunch() async throws {
        let ana = try await users.make("Ana")
        let group = try await ana.data.groups.create(name: "Outbox \(users.runID)", kind: .friends)
        let outbox = FileManager.default.temporaryDirectory.appendingPathComponent("outbox-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: outbox) }

        // Offline: every request fails before reaching the server.
        let offline = FlakyTransport(plan: Array(repeating: .beforeSending, count: 20))
        let offlinePublisher = PostPublisher(
            posts: ana.data.posts,
            uploader: MediaUploader(client: ana.client, transport: offline, retry: RetryPolicy(maxAttempts: 2, baseDelay: 0.01, maxDelay: 0.01)),
            directory: outbox
        )
        let source = try temporaryFile(tinyJPEG, extension: "jpg")
        let draft = PostDraft(kind: .photo, original: .init(url: source, contentType: ContentType.jpeg), groupIDs: [group.id], caption: "later")
        await assertThrows(.offline) { try await offlinePublisher.publish(draft) }
        try FileManager.default.removeItem(at: source) // the outbox kept its own copy
        let pending = await offlinePublisher.pending()
        XCTAssertEqual(pending.map(\.mediaID), [draft.mediaID])

        // "Relaunch": a new publisher over the same outbox, back online.
        let publisher = PostPublisher(posts: ana.data.posts, uploader: MediaUploader(client: ana.client, retry: fastRetry), directory: outbox)
        let results = await publisher.resumePending()
        let posts = try XCTUnwrap(try results[draft.mediaID]?.get())
        XCTAssertEqual(posts.map(\.groupID), [group.id])
        XCTAssertEqual(posts.first?.caption, "later")
        let stillPending = await publisher.pending()
        XCTAssertTrue(stillPending.isEmpty)
        let feed = try await ana.data.posts.page(groupID: group.id)
        XCTAssertEqual(feed.items.map(\.mediaID), [draft.mediaID])
    }

    func testLivePhotoAndDualCapturePathsAndRows() async throws {
        let ana = try await users.make("Ana")
        let group = try await ana.data.groups.create(name: "Live \(users.runID)", kind: .friends)
        let draft = PostDraft(
            kind: .livePhoto,
            original: .init(url: try temporaryFile(tinyJPEG, extension: "jpg"), contentType: ContentType.jpeg),
            width: 1, height: 1,
            front: .init(url: try temporaryFile(tinyJPEG, extension: "jpg"), contentType: ContentType.jpeg),
            frontWidth: 1, frontHeight: 1,
            motion: .init(url: try temporaryFile(Data(repeating: 7, count: 2048), extension: "mov"), contentType: ContentType.quickTime),
            durationMs: 1500,
            groupIDs: [group.id]
        )
        let posts = try await ana.data.publisher.publish(draft)
        let value1 = try await ana.data.posts.media(ids: [posts[0].mediaID]).first
        let media = try XCTUnwrap(value1)
        XCTAssertEqual(media.kind, .livePhoto)
        XCTAssertEqual(media.frontOriginalPath, StoragePaths.front(owner: ana.id, media: draft.mediaID))
        XCTAssertEqual(media.motionPath, StoragePaths.motion(owner: ana.id, media: draft.mediaID))
        XCTAssertEqual(media.durationMs, 1500)
        let urls = try await ana.data.signedURLs.urls(for: [media.originalPath, try XCTUnwrap(media.frontOriginalPath), try XCTUnwrap(media.motionPath)])
        XCTAssertEqual(urls.count, 3)
    }
}

import Foundation
import XCTest
@testable import AppModels

final class WidgetDeliveryTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WidgetDeliveryTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func payload(_ widget: [String: Any]) -> WidgetPushPayload? {
        WidgetPushPayload(userInfo: ["aps": ["mutable-content": 1], "widget": widget])
    }

    private let base: [String: Any] = [
        "group_id": "g1",
        "post_id": "p1",
        "rendition_url": "https://cdn.example.test/media/p1.widget.jpg?token=abc",
    ]

    func testMinimalPayload() throws {
        let parsed = try XCTUnwrap(payload(base))
        XCTAssertEqual(parsed.groupID, "g1")
        XCTAssertEqual(parsed.postID, "p1")
        XCTAssertEqual(parsed.kind, .photo)
        XCTAssertNil(parsed.sender)
        XCTAssertNil(parsed.postedAt)
        XCTAssertEqual(parsed.renditionFileName, "photo-p1.jpg")
    }

    func testFullPayload() throws {
        var widget = base
        widget["sender"] = ["display_name": "Ana", "avatar_url": "https://cdn.example.test/a.png"]
        widget["caption"] = "hi"
        widget["kind"] = "collage"
        widget["group_name"] = "Roommates"
        widget["posted_at"] = 1_760_000_000
        let parsed = try XCTUnwrap(payload(widget))
        XCTAssertEqual(parsed.sender?.displayName, "Ana")
        XCTAssertEqual(parsed.sender?.avatarURL?.absoluteString, "https://cdn.example.test/a.png")
        XCTAssertEqual(parsed.caption, "hi")
        XCTAssertEqual(parsed.kind, .collage)
        XCTAssertEqual(parsed.groupName, "Roommates")
        XCTAssertEqual(parsed.postedAt, Date(timeIntervalSince1970: 1_760_000_000))
        XCTAssertEqual(parsed.renditionFileName, "collage-p1.jpg")
        XCTAssertEqual(parsed.avatarFileName, "avatar-p1.png")
    }

    func testSenderAsString() throws {
        var widget = base
        widget["sender"] = "Ana"
        XCTAssertEqual(try XCTUnwrap(payload(widget)).sender?.displayName, "Ana")
    }

    func testPostedAtFormats() {
        XCTAssertEqual(WidgetPushPayload.date("2025-10-15T12:00:00Z"), Date(timeIntervalSince1970: 1_760_529_600))
        XCTAssertEqual(WidgetPushPayload.date("2025-10-15T12:00:00.500Z"), Date(timeIntervalSince1970: 1_760_529_600.5))
        XCTAssertEqual(WidgetPushPayload.date(1_760_529_600.5), Date(timeIntervalSince1970: 1_760_529_600.5))
        XCTAssertEqual(WidgetPushPayload.date("1760529600"), Date(timeIntervalSince1970: 1_760_529_600))
        XCTAssertNil(WidgetPushPayload.date("yesterday"))
    }

    func testRejectsMalformedPayloads() {
        XCTAssertNil(WidgetPushPayload(userInfo: ["aps": [:]]))
        for key in ["group_id", "post_id", "rendition_url"] {
            var widget = base
            widget[key] = nil
            XCTAssertNil(payload(widget), "missing \(key)")
        }
        var http = base
        http["rendition_url"] = "http://cdn.example.test/p1.jpg"
        XCTAssertNil(payload(http), "non-HTTPS rendition")
        var traversal = base
        traversal["post_id"] = "../p1"
        XCTAssertNil(payload(traversal), "unsafe id")
        var kind = base
        kind["kind"] = "video"
        XCTAssertNil(payload(kind), "unknown kind")
    }

    func testUnknownExtensionFallsBackToJPEG() throws {
        var widget = base
        widget["rendition_url"] = "https://cdn.example.test/render?id=1"
        XCTAssertEqual(try XCTUnwrap(payload(widget)).renditionFileName, "photo-p1.jpg")
    }

    func testDeliveryWritesFileAndSnapshot() async throws {
        let store = WidgetStore.resolve(appGroupIdentifier: nil, fallbackDirectory: directory)
        try store.syncGroups([WidgetGroup(id: "g1", name: "Family")])
        var widget = base
        widget["sender"] = ["display_name": "Ana", "avatar_url": "https://cdn.example.test/fail.png"]
        let parsed = try XCTUnwrap(payload(widget))
        let renditionURL = parsed.renditionURL
        let delivery = WidgetDelivery(store: store) { url in
            if url == renditionURL { return Data([0xFF, 0xD8, 0xFF]) }
            throw URLError(.badServerResponse)
        }
        let received = Date(timeIntervalSince1970: 1_000)
        let snapshot = try await delivery.deliver(parsed, receivedAt: received)

        XCTAssertEqual(snapshot.groupName, "Family", "name from the stored group list")
        XCTAssertEqual(snapshot.postedAt, received)
        XCTAssertNil(snapshot.senderAvatarFileName, "avatar failure is tolerated")
        XCTAssertEqual(store.latestSnapshot(groupID: "g1"), snapshot)
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(store.photoURL(for: snapshot))), Data([0xFF, 0xD8, 0xFF]))
    }

    func testDeliveryWithAvatar() async throws {
        let store = WidgetStore.resolve(appGroupIdentifier: nil, fallbackDirectory: directory)
        var widget = base
        widget["sender"] = ["display_name": "Ana", "avatar_url": "https://cdn.example.test/a.png"]
        let parsed = try XCTUnwrap(payload(widget))
        let delivery = WidgetDelivery(store: store) { _ in Data([1, 2, 3]) }
        let snapshot = try await delivery.deliver(parsed, receivedAt: Date())
        XCTAssertEqual(snapshot.senderAvatarFileName, "avatar-p1.png")
        XCTAssertNotNil(store.avatarURL(for: snapshot))
    }

    func testDeliveryFailsWhenRenditionFails() async throws {
        let store = WidgetStore.resolve(appGroupIdentifier: nil, fallbackDirectory: directory)
        let parsed = try XCTUnwrap(payload(base))
        let delivery = WidgetDelivery(store: store) { _ in throw URLError(.timedOut) }
        do {
            try await delivery.deliver(parsed, receivedAt: Date())
            XCTFail("expected an error")
        } catch {}
        XCTAssertNil(store.latestSnapshot(groupID: "g1"))
    }

    func testDownloaderRejectsPlainHTTP() async {
        let downloader = HTTPDownloader(timeout: 1, maxBytes: 10)
        do {
            _ = try await downloader.data(from: URL(string: "http://example.test/a.jpg")!)
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? HTTPDownloader.DownloadError, .insecureURL)
        }
    }
}

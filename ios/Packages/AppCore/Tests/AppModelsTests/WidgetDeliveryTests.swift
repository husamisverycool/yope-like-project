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

    /// iOS alert push shape: the widget fields as one object.
    private func nested(_ widget: [String: Any]) -> WidgetPushPayload? {
        WidgetPushPayload(userInfo: ["aps": ["mutable-content": 1], "type": "new_post", "widget": widget])
    }

    /// Shared (Android-compatible) silent push shape: flat keys with `type: widget`.
    private func flat(_ fields: [String: Any]) -> WidgetPushPayload? {
        var userInfo: [AnyHashable: Any] = ["aps": ["content-available": 1], "type": "widget"]
        for (key, value) in fields { userInfo[key] = value }
        return WidgetPushPayload(userInfo: userInfo)
    }

    private let base: [String: Any] = [
        "group_id": "g1",
        "post_id": "p1",
        "rendition_url": "https://cdn.example.test/media/p1.widget.jpg?token=abc",
    ]

    func testMinimalPayload() throws {
        let parsed = try XCTUnwrap(nested(base))
        XCTAssertEqual(parsed.groupID, "g1")
        XCTAssertEqual(parsed.sourceID, "p1")
        XCTAssertEqual(parsed.kind, .photo)
        XCTAssertNil(parsed.sender)
        XCTAssertNil(parsed.postedAt)
        XCTAssertEqual(parsed.renditionFileName(fallbackID: "x"), "photo-p1.jpg")
    }

    func testNestedFullPayload() throws {
        var widget = base
        widget["sender"] = ["display_name": "Ana", "avatar_url": "https://cdn.example.test/a.png"]
        widget["caption"] = "hi"
        widget["kind"] = "collage"
        widget["group_name"] = "Roommates"
        widget["posted_at"] = 1_760_000_000
        let parsed = try XCTUnwrap(nested(widget))
        XCTAssertEqual(parsed.sender?.displayName, "Ana")
        XCTAssertEqual(parsed.sender?.avatarURL?.absoluteString, "https://cdn.example.test/a.png")
        XCTAssertEqual(parsed.caption, "hi")
        XCTAssertEqual(parsed.kind, .collage)
        XCTAssertEqual(parsed.groupName, "Roommates")
        XCTAssertEqual(parsed.postedAt, Date(timeIntervalSince1970: 1_760_000_000))
        XCTAssertEqual(parsed.renditionFileName(fallbackID: "x"), "collage-p1.jpg")
        XCTAssertEqual(parsed.avatarFileName(fallbackID: "x"), "avatar-p1.png")
    }

    func testSenderAsString() throws {
        var widget = base
        widget["sender"] = "Ana"
        XCTAssertEqual(try XCTUnwrap(nested(widget)).sender?.displayName, "Ana")
    }

    func testFlatSharedContract() throws {
        let parsed = try XCTUnwrap(flat([
            "group_id": "g1", "group_name": "Family", "collage_id": "c1", "kind": "collage",
            "rendition_url": "https://cdn.example.test/w.jpg?sig=1", "posted_at": "2025-10-15T12:00:00Z",
            "sender_name": "Ana", "sender_avatar_url": "https://cdn.example.test/a.jpg", "caption": "same time",
        ]))
        XCTAssertEqual(parsed.sourceID, "c1")
        XCTAssertEqual(parsed.kind, .collage)
        XCTAssertEqual(parsed.groupName, "Family")
        XCTAssertEqual(parsed.sender, WidgetPushPayload.Sender(displayName: "Ana", avatarURL: URL(string: "https://cdn.example.test/a.jpg")))
        XCTAssertEqual(parsed.postedAt, Date(timeIntervalSince1970: 1_760_529_600))
        XCTAssertNil(WidgetPushPayload(userInfo: ["type": "new_post", "group_id": "g1", "rendition_url": "https://x.test/y"]),
                     "flat widget fields count only on a widget push")
    }

    func testMissingSourceUsesFallbackName() throws {
        let parsed = try XCTUnwrap(flat(["group_id": "g1", "rendition_url": "https://cdn.example.test/w"]))
        XCTAssertNil(parsed.sourceID)
        XCTAssertEqual(parsed.renditionFileName(fallbackID: "1700"), "photo-1700.jpg")
    }

    func testPostedAtFormats() {
        XCTAssertEqual(PayloadValue.date("2025-10-15T12:00:00Z"), Date(timeIntervalSince1970: 1_760_529_600))
        XCTAssertEqual(PayloadValue.date("2025-10-15T12:00:00.500Z"), Date(timeIntervalSince1970: 1_760_529_600.5))
        XCTAssertEqual(PayloadValue.date(1_760_529_600.5), Date(timeIntervalSince1970: 1_760_529_600.5))
        XCTAssertEqual(PayloadValue.date("1760529600"), Date(timeIntervalSince1970: 1_760_529_600))
        XCTAssertEqual(PayloadValue.date("1760529600000"), Date(timeIntervalSince1970: 1_760_529_600), "milliseconds (Android contract)")
        XCTAssertEqual(PayloadValue.date(1_760_529_600_000), Date(timeIntervalSince1970: 1_760_529_600))
        XCTAssertNil(PayloadValue.date("yesterday"))
        XCTAssertNil(PayloadValue.date(nil))
    }

    func testRejectsMalformedPayloads() {
        XCTAssertNil(WidgetPushPayload(userInfo: ["aps": [:]]))
        for key in ["group_id", "rendition_url"] {
            var widget = base
            widget[key] = nil
            XCTAssertNil(nested(widget), "missing \(key)")
        }
        var http = base
        http["rendition_url"] = "http://cdn.example.test/p1.jpg"
        XCTAssertNil(nested(http), "non-HTTPS rendition")
        var file = base
        file["rendition_url"] = "file:///private/var/x.jpg"
        XCTAssertNil(nested(file), "file URL")
        var traversal = base
        traversal["post_id"] = "../p1"
        XCTAssertNil(nested(traversal), "unsafe id")
        var kind = base
        kind["kind"] = "video"
        XCTAssertNil(nested(kind), "unknown kind")
    }

    func testUnknownExtensionFallsBackToJPEG() throws {
        var widget = base
        widget["rendition_url"] = "https://cdn.example.test/render?id=1"
        XCTAssertEqual(try XCTUnwrap(nested(widget)).renditionFileName(fallbackID: "x"), "photo-p1.jpg")
    }

    func testDeliveryWritesFileAndSnapshot() async throws {
        let store = WidgetStore.resolve(appGroupIdentifier: nil, fallbackDirectory: directory)
        try store.syncGroups([WidgetGroup(id: "g1", name: "Family")])
        var widget = base
        widget["sender"] = ["display_name": "Ana", "avatar_url": "https://cdn.example.test/fail.png"]
        let parsed = try XCTUnwrap(nested(widget))
        let renditionURL = parsed.renditionURL
        let delivery = WidgetDelivery(store: store) { url in
            if url == renditionURL { return Data([0xFF, 0xD8, 0xFF]) }
            throw URLError(.badServerResponse)
        }
        let received = Date(timeIntervalSince1970: 1_000)
        let snapshot = try await delivery.deliver(parsed, receivedAt: received)

        XCTAssertEqual(snapshot.groupName, "Family", "name from the stored group list")
        XCTAssertEqual(snapshot.postedAt, received)
        XCTAssertEqual(snapshot.senderDisplayName, "Ana")
        XCTAssertNil(snapshot.senderAvatarFileName, "avatar failure is tolerated")
        XCTAssertEqual(store.latestSnapshot(groupID: "g1"), snapshot)
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(store.photoURL(for: snapshot))), Data([0xFF, 0xD8, 0xFF]))
    }

    func testDeliveryWithAvatar() async throws {
        let store = WidgetStore.resolve(appGroupIdentifier: nil, fallbackDirectory: directory)
        var widget = base
        widget["sender"] = ["display_name": "Ana", "avatar_url": "https://cdn.example.test/a.png"]
        let parsed = try XCTUnwrap(nested(widget))
        let delivery = WidgetDelivery(store: store) { _ in Data([1, 2, 3]) }
        let snapshot = try await delivery.deliver(parsed, receivedAt: Date())
        XCTAssertEqual(snapshot.senderAvatarFileName, "avatar-p1.png")
        XCTAssertNotNil(store.avatarURL(for: snapshot))
    }

    func testDeliveryFailsWhenRenditionFails() async throws {
        let store = WidgetStore.resolve(appGroupIdentifier: nil, fallbackDirectory: directory)
        let parsed = try XCTUnwrap(nested(base))
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

import AppModels
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import AppData

/// The app's own writes to the widgets (`WidgetContentSync`, docs/WIDGET_REFRESH.md "The app itself"): a member's widget
/// shows the group's newest photo and collage without any push, and nothing once every photo is gone.
final class WidgetContentIntegrationTests: XCTestCase {
    private var users: TestUsers!

    override func setUp() async throws {
        try await LocalStack.require()
        users = TestUsers()
    }

    override func tearDown() async throws {
        await users?.cleanUp()
    }

    func testTheAppWritesEachGroupsNewestPhotoAndCollageAndClearsThePhotoWhenNoneIsLeft() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("widgets-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = WidgetStore(rootURL: root)
        let downloads = DownloadLog()
        let rui = try await users.make("Rui", widgetStore: store, widgetDownload: { url in
            await downloads.record(url)
            return tinyJPEG
        })
        let ana = try await users.make("Ana")
        let group = try await ana.data.groups.create(name: "Widget \(users.runID)", kind: .friends)
        _ = try await rui.data.groups.join(token: try await ana.data.groups.createInvite(groupID: group.id).token)

        // Ana posts; the worker's widget rendition is stood in for by the uploaded original (no worker here).
        let file = try temporaryFile(tinyJPEG, extension: "jpg")
        let published = try await ana.data.publisher.publish(
            PostDraft(kind: .photo, original: .init(url: file, contentType: ContentType.jpeg), groupIDs: [group.id])
        )
        let post = try XCTUnwrap(published.first)
        let mediaRows = try await ana.data.posts.media(ids: [post.mediaID])
        let media = try XCTUnwrap(mediaRows.first)
        try await LocalStack.update("media", id: media.id.rawValue, ["widget_path": media.originalPath])

        // Sign-in loads the groups: Rui's widget shows the photo, with no push at all.
        await rui.data.coordinator.didSignIn(rui.id)
        let photo = try XCTUnwrap(store.snapshot(groupID: group.id.rawValue, kind: .photo))
        XCTAssertEqual(photo.sourceID, post.id.rawValue)
        XCTAssertEqual(photo.groupName, group.name)
        XCTAssertNotNil(store.photoURL(for: photo))
        let first = await downloads.count
        XCTAssertGreaterThanOrEqual(first, 1)

        // Unchanged: nothing is downloaded again.
        await rui.data.coordinator.refreshWidgetContent()
        let again = await downloads.count
        XCTAssertEqual(again, first)

        // A ready same-moment collage is written as the group's collage snapshot (its widget rendition uploaded as the
        // worker would).
        let widgetPath = "g/\(group.id.rawValue)/collages/\(UUID().uuidString.lowercased())/widget.jpg"
        try await uploadAsService(tinyJPEG, to: widgetPath)
        let collage = try await LocalStack.insert("collages", [
            "group_id": group.id.rawValue, "option": "B", "post_ids": [post.id.rawValue],
            "image_path": widgetPath, "widget_path": widgetPath, "status": "ready",
            "composed_at": Timestamp.format(Date()),
        ])
        await rui.data.coordinator.refreshWidgetContent(groupID: group.id)
        XCTAssertEqual(store.snapshot(groupID: group.id.rawValue, kind: .collage)?.sourceID, collage["id"] as? String)

        // Every photo deleted: the photo snapshot goes (the widget shows its empty state or the collage).
        try await ana.data.posts.deleteMedia(id: post.mediaID)
        await rui.data.coordinator.refreshWidgetContent()
        XCTAssertNil(store.snapshot(groupID: group.id.rawValue, kind: .photo))
    }
}

/// Storage upload with the service role (the worker's writes).
private func uploadAsService(_ data: Data, to path: String) async throws {
    var request = URLRequest(url: URL(string: LocalStack.url.absoluteString + "/storage/v1/object/media/" + path)!)
    request.httpMethod = "POST"
    request.setValue(LocalStack.serviceRoleKey, forHTTPHeaderField: "apikey")
    request.setValue("Bearer \(LocalStack.serviceRoleKey)", forHTTPHeaderField: "Authorization")
    request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
    request.httpBody = data
    let (body, response) = try await URLSession.shared.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(status) else { throw UploadFailure(status: status, body: String(decoding: body, as: UTF8.self)) }
}

private actor DownloadLog {
    private(set) var urls: [URL] = []
    var count: Int { urls.count }

    func record(_ url: URL) {
        urls.append(url)
    }
}

private struct UploadFailure: Error, CustomStringConvertible {
    let status: Int
    let body: String
    var description: String { "HTTP \(status): \(body)" }
}

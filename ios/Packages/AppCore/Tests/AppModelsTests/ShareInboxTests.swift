import Foundation
import XCTest
@testable import AppModels

/// share.in: the App Group inbox between the Share Extension and the app, and the link that hands over.
final class ShareInboxTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareInboxTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func file(_ name: String, _ text: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        return url
    }

    func testItemsAreTakenOnceInTheOrderShared() throws {
        let inbox = ShareInbox(rootURL: directory.appendingPathComponent(ShareInbox.directoryName, isDirectory: true))
        XCTAssertFalse(inbox.hasItems)
        try inbox.replace(with: [
            ShareInbox.File(url: try file("b.heic", "photo b"), kind: .image),
            ShareInbox.File(url: try file("a.mov", "movie a"), kind: .movie),
            ShareInbox.File(url: try file("c.jpg", "photo c"), kind: .image),
        ])
        XCTAssertTrue(inbox.hasItems)
        XCTAssertEqual(inbox.items().map(\.kind), [.image, .movie, .image])

        let destination = directory.appendingPathComponent("taken", isDirectory: true)
        let taken = inbox.take(into: destination)
        XCTAssertEqual(taken.map(\.kind), [.image, .movie, .image])
        XCTAssertEqual(try taken.map { String(decoding: try Data(contentsOf: $0.url), as: UTF8.self) }, ["photo b", "movie a", "photo c"])
        XCTAssertEqual(taken.map { $0.url.pathExtension }, ["heic", "mov", "jpg"])
        XCTAssertFalse(inbox.hasItems, "taken once")
        XCTAssertTrue(inbox.take(into: destination).isEmpty)
    }

    func testANewShareReplacesTheOneWaiting() throws {
        let inbox = ShareInbox(rootURL: directory.appendingPathComponent(ShareInbox.directoryName, isDirectory: true))
        try inbox.replace(with: [ShareInbox.File(url: try file("old.jpg", "old"), kind: .image)])
        try inbox.replace(with: [ShareInbox.File(url: try file("new.jpg", "new"), kind: .image)])
        let taken = inbox.take(into: directory.appendingPathComponent("taken", isDirectory: true))
        XCTAssertEqual(taken.count, 1)
        XCTAssertEqual(String(decoding: try Data(contentsOf: taken[0].url), as: UTF8.self), "new")
    }

    func testAManifestCannotPointOutsideTheInbox() throws {
        let root = directory.appendingPathComponent(ShareInbox.directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let manifest = #"[{"fileName":"../secret.txt","kind":"image"},{"fileName":".hidden","kind":"image"}]"#
        try Data(manifest.utf8).write(to: root.appendingPathComponent("items.json"))
        let inbox = ShareInbox(rootURL: root)
        XCTAssertTrue(inbox.items().isEmpty)
        XCTAssertFalse(inbox.hasItems)
    }

    func testTheLinkIsTheAppsOwnSchemeAndCarriesNothing() throws {
        let url = try XCTUnwrap(ShareInLink.url(scheme: "com.husamisverycool.jolt"))
        XCTAssertEqual(url.absoluteString, "com.husamisverycool.jolt://share")
        XCTAssertTrue(ShareInLink.matches(url, scheme: "com.husamisverycool.jolt"))
        XCTAssertTrue(ShareInLink.matches(try XCTUnwrap(URL(string: "COM.HUSAMISVERYCOOL.JOLT://share")), scheme: "com.husamisverycool.jolt"))
        XCTAssertFalse(ShareInLink.matches(url, scheme: nil))
        XCTAssertFalse(ShareInLink.matches(url, scheme: "app"))
        XCTAssertFalse(ShareInLink.matches(try XCTUnwrap(URL(string: "com.husamisverycool.jolt://camera")), scheme: "com.husamisverycool.jolt"))
        XCTAssertFalse(ShareInLink.matches(try XCTUnwrap(URL(string: "app://share")), scheme: "com.husamisverycool.jolt"))
    }
}

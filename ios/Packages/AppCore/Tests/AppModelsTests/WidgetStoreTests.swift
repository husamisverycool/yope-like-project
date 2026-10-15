import Foundation
import XCTest
@testable import AppModels

final class WidgetStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WidgetStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private var store: WidgetStore {
        WidgetStore.resolve(appGroupIdentifier: nil, fallbackDirectory: directory)
    }

    private func snapshot(group: String = "g1", post: String, kind: WidgetSnapshot.Kind = .photo, at seconds: TimeInterval) -> WidgetSnapshot {
        WidgetSnapshot(
            groupID: group, groupName: "Name", sourceID: post, photoFileName: "\(kind.rawValue)-\(post).jpg",
            senderDisplayName: "Sender", caption: "caption", kind: kind,
            postedAt: Date(timeIntervalSince1970: seconds)
        )
    }

    private func put(_ snapshot: WidgetSnapshot, in store: WidgetStore) throws {
        try store.writeFile(Data([0xFF, 0xD8]), groupID: snapshot.groupID, fileName: snapshot.photoFileName)
        try store.save(snapshot)
    }

    func testFallbackLocation() {
        XCTAssertEqual(store.rootURL, directory.appendingPathComponent("WidgetStore", isDirectory: true))
    }

    func testRoundTrip() throws {
        let store = self.store
        let original = snapshot(post: "p1", at: 1_760_000_000.25)
        try put(original, in: store)
        XCTAssertEqual(store.snapshot(groupID: "g1", kind: .photo), original)
        XCTAssertEqual(store.latestSnapshot(groupID: "g1"), original)
        let photo = try XCTUnwrap(store.photoURL(for: original))
        XCTAssertEqual(try Data(contentsOf: photo), Data([0xFF, 0xD8]))
        XCTAssertNil(store.avatarURL(for: original))
    }

    func testNewestOfPhotoAndCollageWins() throws {
        let store = self.store
        try put(snapshot(post: "p1", at: 100), in: store)
        try put(snapshot(post: "c1", kind: .collage, at: 200), in: store)
        XCTAssertEqual(store.latestSnapshot(groupID: "g1")?.sourceID, "c1")
        try put(snapshot(post: "p2", at: 300), in: store)
        XCTAssertEqual(store.latestSnapshot(groupID: "g1")?.sourceID, "p2")
    }

    func testSnapshotWithoutFileIsIgnored() throws {
        let store = self.store
        try put(snapshot(post: "p1", at: 100), in: store)
        try store.save(snapshot(post: "c1", kind: .collage, at: 200))
        XCTAssertEqual(store.latestSnapshot(groupID: "g1")?.sourceID, "p1")
    }

    func testLatestAcrossGroups() throws {
        let store = self.store
        try put(snapshot(group: "a", post: "p1", at: 100), in: store)
        try put(snapshot(group: "b", post: "p2", at: 200), in: store)
        XCTAssertEqual(store.latestSnapshot()?.groupID, "b")
    }

    func testRemoveSource() throws {
        let store = self.store
        let photo = snapshot(post: "p1", at: 100)
        try put(photo, in: store)
        try put(snapshot(post: "c1", kind: .collage, at: 50), in: store)
        XCTAssertTrue(try store.removeSource("p1"))
        XCTAssertNil(store.snapshot(groupID: "g1", kind: .photo))
        XCTAssertNil(store.photoURL(for: photo))
        XCTAssertEqual(store.latestSnapshot(groupID: "g1")?.sourceID, "c1")
        XCTAssertFalse(try store.removeSource("p1"))
    }

    func testSyncGroupsRemovesStaleGroups() throws {
        let store = self.store
        try put(snapshot(group: "keep", post: "p1", at: 1), in: store)
        try put(snapshot(group: "gone", post: "p2", at: 2), in: store)
        try store.syncGroups([WidgetGroup(id: "keep", name: "Keep")])
        XCTAssertEqual(store.groups(), [WidgetGroup(id: "keep", name: "Keep")])
        XCTAssertNotNil(store.latestSnapshot(groupID: "keep"))
        XCTAssertNil(store.latestSnapshot(groupID: "gone"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.groupDirectory("gone").path))
    }

    func testPruneKeepsReferencedAndRecentFiles() throws {
        let store = self.store
        try put(snapshot(post: "p1", at: 1), in: store)
        let stale = try store.writeFile(Data([1]), groupID: "g1", fileName: "photo-old.jpg")
        let fresh = try store.writeFile(Data([2]), groupID: "g1", fileName: "photo-new.jpg")
        let longAgo = Date(timeIntervalSinceNow: -3600)
        try FileManager.default.setAttributes([.modificationDate: longAgo], ofItemAtPath: stale.path)

        let deleted = try store.prune(now: Date(), gracePeriod: 600)
        XCTAssertEqual(deleted, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path))
        XCTAssertNotNil(store.latestSnapshot(groupID: "g1"))
    }

    func testRejectsUnsafeNames() {
        let store = self.store
        XCTAssertThrowsError(try store.writeFile(Data(), groupID: "../x", fileName: "a.jpg"))
        XCTAssertThrowsError(try store.writeFile(Data(), groupID: "g", fileName: "../a.jpg"))
        XCTAssertThrowsError(try store.writeFile(Data(), groupID: "g", fileName: ".hidden"))
        XCTAssertThrowsError(try store.writeFile(Data(), groupID: "g", fileName: "a/b.jpg"))
        XCTAssertThrowsError(try store.syncGroups([WidgetGroup(id: "a/b", name: "x")]))
        XCTAssertNil(store.snapshot(groupID: "..", kind: .photo))
    }

    func testRemoveAll() throws {
        let store = self.store
        try put(snapshot(post: "p1", at: 1), in: store)
        try store.removeAll()
        XCTAssertNil(store.latestSnapshot())
        XCTAssertEqual(store.groups(), [])
    }

    func testSnapshotJSONShape() throws {
        let data = try WidgetStore.encoder.encode(snapshot(post: "p1", at: 10))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["group_id", "group_name", "source_id", "photo_file", "sender_name", "caption", "kind", "posted_at"])
    }
}

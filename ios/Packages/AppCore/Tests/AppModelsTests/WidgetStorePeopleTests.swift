import Foundation
import XCTest
@testable import AppModels

/// The friend and memories widgets' files in the App Group store, the premium flag of the widget styles, and the
/// deletion rule ("a deleted photo leaves the widgets") for them.
final class WidgetStorePeopleTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WidgetStorePeopleTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private var store: WidgetStore {
        WidgetStore.resolve(appGroupIdentifier: nil, fallbackDirectory: directory)
    }

    private func snapshot(group: String = "g1", post: String, sender: String? = "u1", at seconds: TimeInterval) -> WidgetSnapshot {
        WidgetSnapshot(
            groupID: group, groupName: "Family", sourceID: post, photoFileName: "photo-\(post).jpg", senderID: sender,
            senderDisplayName: "Ana Lima", kind: .photo, postedAt: Date(timeIntervalSince1970: seconds)
        )
    }

    func testPeopleListAndUnlistedFriendsLeave() throws {
        let store = self.store
        XCTAssertFalse(store.hasPeopleList)
        try store.syncPeople([WidgetPerson(id: "u1", name: "Ana"), WidgetPerson(id: "u2", name: "Ben")])
        XCTAssertTrue(store.hasPeopleList)
        XCTAssertEqual(store.people().map(\.id), ["u1", "u2"])
        try store.savePerson(snapshot(post: "p1", at: 10), personID: "u2", photo: Data([1]))
        XCTAssertNotNil(store.personSnapshot(personID: "u2"))
        try store.syncPeople([WidgetPerson(id: "u1", name: "Ana")])
        XCTAssertNil(store.personSnapshot(personID: "u2"), "someone no longer listed (a block, no shared group) leaves")
        XCTAssertThrowsError(try store.syncPeople([WidgetPerson(id: "../x", name: "X")]))
    }

    func testPremiumFlag() throws {
        let store = self.store
        XCTAssertFalse(store.isPremium)
        XCTAssertTrue(try store.setPremium(false), "first write counts as a change")
        XCTAssertFalse(try store.setPremium(false))
        XCTAssertTrue(try store.setPremium(true))
        XCTAssertTrue(store.isPremium)
    }

    func testWatchedPeopleExpire() throws {
        let store = self.store
        let now = Date(timeIntervalSince1970: 1_000_000)
        try store.watch(personID: "u1", at: now)
        try store.watch(personID: "u2", at: now.addingTimeInterval(-WidgetStore.watchExpiry - 1))
        XCTAssertEqual(store.watchedPeople(now: now), ["u1"])
        XCTAssertEqual(store.watchedPeople(now: now.addingTimeInterval(WidgetStore.watchExpiry)), [])
        XCTAssertFalse(store.watchesMemories(now: now))
        try store.watchMemories(at: now)
        XCTAssertTrue(store.watchesMemories(now: now.addingTimeInterval(60)))
        XCTAssertEqual(store.watchedPeople(now: now), ["u1"], "watching memories keeps the friends")
    }

    func testDeliveredPhotoReachesTheFriendWidgetFollowingThePoster() async throws {
        let store = self.store
        let now = Date(timeIntervalSince1970: 2_000)
        try store.watch(personID: "u1", at: now)
        let delivery = WidgetDelivery(store: store) { _ in Data([0xFF, 0xD8]) }
        func payload(_ post: String, sender: String?, at seconds: TimeInterval) -> WidgetPushPayload {
            WidgetPushPayload(
                groupID: "g1", sourceID: post, renditionURL: URL(string: "https://cdn.example.test/\(post).jpg")!,
                sender: WidgetPushPayload.Sender(id: sender, displayName: "Ana", avatarURL: nil), kind: .photo,
                groupName: "Family", postedAt: Date(timeIntervalSince1970: seconds)
            )
        }
        try await delivery.deliver(payload("p1", sender: "u1", at: 1_000), receivedAt: now)
        XCTAssertEqual(store.personSnapshot(personID: "u1")?.sourceID, "p1")
        XCTAssertNotNil(store.personPhotoURL(personID: "u1", snapshot: try XCTUnwrap(store.personSnapshot(personID: "u1"))))
        try await delivery.deliver(payload("p2", sender: "u2", at: 1_500), receivedAt: now)
        XCTAssertNil(store.personSnapshot(personID: "u2"), "nobody follows u2")
        XCTAssertEqual(store.personSnapshot(personID: "u1")?.sourceID, "p1")
        // an older photo of u1 (another group) does not replace the newer one
        let older = WidgetPushPayload(
            groupID: "g2", sourceID: "p0", renditionURL: URL(string: "https://cdn.example.test/p0.jpg")!,
            sender: WidgetPushPayload.Sender(id: "u1", displayName: "Ana", avatarURL: nil), kind: .photo,
            groupName: "Book club", postedAt: Date(timeIntervalSince1970: 500)
        )
        try await delivery.deliver(older, receivedAt: now)
        XCTAssertEqual(store.personSnapshot(personID: "u1")?.sourceID, "p1")
        try await delivery.deliver(payload("p3", sender: "u1", at: 1_800), receivedAt: now)
        XCTAssertEqual(store.personSnapshot(personID: "u1")?.sourceID, "p3")
    }

    func testDeletedPhotoLeavesFriendAndMemoryWidgets() throws {
        let store = self.store
        try store.savePerson(snapshot(post: "p1", at: 10), personID: "u1", photo: Data([1]))
        try store.replaceMemories(days: "2026-10-17"..."2026-10-23",
                                  memories: ["2026-10-17": snapshot(post: "p1", at: 10)], photos: ["photo-p1.jpg": Data([1])])
        XCTAssertNotNil(store.memory(day: "2026-10-17"))
        XCTAssertTrue(try store.removeSource("p1"))
        XCTAssertNil(store.personSnapshot(personID: "u1"))
        XCTAssertNil(store.memory(day: "2026-10-17"))
        XCTAssertEqual(store.memoryDays(), "2026-10-17"..."2026-10-23", "the day stays known: it has no memory now")
    }

    func testLeftGroupLeavesFriendAndMemoryWidgets() throws {
        let store = self.store
        try store.syncGroups([WidgetGroup(id: "g1", name: "Family"), WidgetGroup(id: "g2", name: "Book club")])
        try store.savePerson(snapshot(group: "g2", post: "p2", at: 10), personID: "u1", photo: Data([1]))
        try store.replaceMemories(days: "2026-10-17"..."2026-10-17",
                                  memories: ["2026-10-17": snapshot(group: "g2", post: "p2", at: 10)], photos: ["photo-p2.jpg": Data([1])])
        try store.syncGroups([WidgetGroup(id: "g1", name: "Family")])
        XCTAssertNil(store.personSnapshot(personID: "u1"))
        XCTAssertNil(store.memory(day: "2026-10-17"))
    }

    func testMemoriesReplaceTheLookedUpDays() throws {
        let store = self.store
        XCTAssertNil(store.memoryDays())
        try store.replaceMemories(
            days: "2026-10-17"..."2026-10-23",
            memories: ["2026-10-17": snapshot(post: "m1", at: 1), "2026-10-19": snapshot(post: "m2", at: 2)],
            photos: ["photo-m1.jpg": Data([1]), "photo-m2.jpg": Data([2])]
        )
        XCTAssertEqual(store.memory(day: "2026-10-17")?.sourceID, "m1")
        XCTAssertNil(store.memory(day: "2026-10-18"))
        XCTAssertTrue(store.hasMemory(day: "2026-10-19", sourceID: "m2"))
        // the next look-up: the 17th is past, the 19th keeps its photo without a new download
        try store.replaceMemories(days: "2026-10-18"..."2026-10-24",
                                  memories: ["2026-10-19": snapshot(post: "m2", at: 2)], photos: [:])
        XCTAssertNil(store.memory(day: "2026-10-17"))
        XCTAssertEqual(store.memory(day: "2026-10-19")?.sourceID, "m2")
        XCTAssertEqual(store.memoryDays(), "2026-10-18"..."2026-10-24")
        XCTAssertThrowsError(try store.replaceMemories(days: "2026-10-18"..."2026-10-24",
                                                       memories: ["../x": snapshot(post: "m3", at: 3)], photos: [:]))
    }

    func testDayStrings() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        XCTAssertEqual(WidgetStore.dayString(Date(timeIntervalSince1970: 1_741_536_000), calendar: calendar), "2025-03-10")
        XCTAssertTrue(WidgetStore.isValidDay("2026-10-17"))
        XCTAssertFalse(WidgetStore.isValidDay("2026-1-17"))
        XCTAssertFalse(WidgetStore.isValidDay("../10-17x"))
    }

    func testPruneKeepsReferencedFriendAndMemoryFiles() throws {
        let store = self.store
        try store.savePerson(snapshot(post: "p1", at: 10), personID: "u1", photo: Data([1]))
        try store.savePerson(snapshot(post: "p2", at: 20), personID: "u1", photo: Data([2]))
        try store.replaceMemories(days: "2026-10-17"..."2026-10-17",
                                  memories: ["2026-10-17": snapshot(post: "m1", at: 1)], photos: ["photo-m1.jpg": Data([1]), "photo-old.jpg": Data([0])])
        let deleted = try store.prune(now: Date().addingTimeInterval(3600), gracePeriod: 60)
        XCTAssertEqual(deleted, 2, "the replaced friend photo and the unreferenced memory file")
        XCTAssertNotNil(store.personSnapshot(personID: "u1"))
        XCTAssertNotNil(store.memory(day: "2026-10-17"))
    }

    func testStyles() {
        XCTAssertFalse(WidgetPhotoStyle.photo.isPremium)
        XCTAssertEqual(WidgetPhotoStyle.frame.drawn(isPremium: false), .photo)
        XCTAssertEqual(WidgetPhotoStyle.frame.drawn(isPremium: true), .frame)
        XCTAssertTrue(WidgetPhotoStyle.date.isLocked(isPremium: false))
        XCTAssertFalse(WidgetPhotoStyle.date.isLocked(isPremium: true))
        XCTAssertFalse(WidgetPhotoStyle.photo.isLocked(isPremium: false))
    }
}

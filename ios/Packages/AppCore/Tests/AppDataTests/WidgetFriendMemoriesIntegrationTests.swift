import AppModels
import Foundation
import XCTest
@testable import AppData

/// The friend and memories widgets filled by the app (`WidgetContentSync.syncPeople` / `syncFriends` / `syncMemories`,
/// migration 0036): a friend widget shows that person's newest photo, the memories widget the person's own photo from
/// this day in an earlier year, and a block takes the friend off the picker and the widget.
final class WidgetFriendMemoriesIntegrationTests: XCTestCase {
    private var users: TestUsers!

    override func setUp() async throws {
        try await LocalStack.require()
        users = TestUsers()
    }

    override func tearDown() async throws {
        await users?.cleanUp()
    }

    private func post(_ user: TestUser, to groupID: GroupID) async throws -> Post {
        let file = try temporaryFile(tinyJPEG, extension: "jpg")
        let published = try await user.data.publisher.publish(
            PostDraft(kind: .photo, original: .init(url: file, contentType: ContentType.jpeg), groupIDs: [groupID])
        )
        let post = try XCTUnwrap(published.first)
        // The worker's widget rendition is stood in for by the uploaded original (no worker here).
        let mediaRows = try await user.data.posts.media(ids: [post.mediaID])
        let media = try XCTUnwrap(mediaRows.first)
        try await LocalStack.update("media", id: media.id.rawValue, ["widget_path": media.originalPath])
        return post
    }

    func testFriendWidgetPickerPhotoAndBlock() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("widgets-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = WidgetStore(rootURL: root)
        let rui = try await users.make("Rui", widgetStore: store, widgetDownload: { _ in tinyJPEG })
        let ana = try await users.make("Ana")
        let group = try await ana.data.groups.create(name: "Friends \(users.runID)", kind: .friends)
        _ = try await rui.data.groups.join(token: try await ana.data.groups.createInvite(groupID: group.id).token)
        let anaPost = try await post(ana, to: group.id)

        // The picker lists Ana; a friend widget for Ana (its timeline recorded the watch) gets her photo.
        try store.watch(personID: ana.id.rawValue, at: Date())
        await rui.data.coordinator.didSignIn(rui.id)
        XCTAssertEqual(store.people().map(\.id), [ana.id.rawValue])
        let shown = try XCTUnwrap(store.personSnapshot(personID: ana.id.rawValue))
        XCTAssertEqual(shown.sourceID, anaPost.id.rawValue)
        XCTAssertEqual(shown.groupID, group.id.rawValue)
        XCTAssertEqual(shown.senderID, ana.id.rawValue)
        XCTAssertNotNil(store.personPhotoURL(personID: ana.id.rawValue, snapshot: shown))

        // A block: Ana leaves the picker and the friend widget.
        try await ana.data.safety.block(userID: rui.id)
        await rui.data.coordinator.refreshWidgetContent()
        XCTAssertEqual(store.people(), [])
        XCTAssertNil(store.personSnapshot(personID: ana.id.rawValue))
    }

    func testMemoriesWidgetShowsYourOwnPhotoFromThisDay() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("widgets-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = WidgetStore(rootURL: root)
        let rui = try await users.make("Rui", widgetStore: store, widgetDownload: { _ in tinyJPEG })
        let group = try await rui.data.groups.create(name: "Memories \(users.runID)", kind: .family)
        let mine = try await post(rui, to: group.id)
        let calendar = Calendar.current
        let lastYear = try XCTUnwrap(calendar.date(byAdding: .year, value: -1, to: Date()))
        try await LocalStack.update("posts", id: mine.id.rawValue, ["created_at": Timestamp.format(lastYear)])

        // No memories widget placed: nothing is looked up.
        await rui.data.coordinator.didSignIn(rui.id)
        XCTAssertNil(store.memoryDays())

        try store.watchMemories(at: Date())
        await rui.data.coordinator.refreshWidgetContent()
        let today = WidgetStore.dayString(Date(), calendar: calendar)
        XCTAssertEqual(store.memoryDays()?.lowerBound, today)
        let memory = try XCTUnwrap(store.memory(day: today))
        XCTAssertEqual(memory.sourceID, mine.id.rawValue)
        XCTAssertNotNil(store.memoryPhotoURL(memory))
        let tomorrow = WidgetStore.dayString(try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: Date())), calendar: calendar)
        XCTAssertNil(store.memory(day: tomorrow), "a day without a memory has none")
    }
}

// Flows of the social group (chat.thread send / reply / react / unsend) on the in-memory demo backend:
// `-SocialFakes` (social data), `-SocialOpen chat` (start screen) and the account group's signed-in scenario
// (`-account-ui-test-scenario signed-in`). The app must call `SocialLaunch.apply(to:)` at launch (DEBUG).
// Labels are the copy defaults (design/copy.json): "You, {message}", "{name}, {message}", "Reply to {name}'s post",
// context menu "Reply" / "Unsend", quick reactions "React with {emoji name}".
import XCTest

final class SocialChatFlowUITests: XCTestCase {
    /// Demo ids (ios/App/Sources/Features/Social/Core/SocialDemoData.swift).
    private enum Demo {
        static let snowPhoto = "chat.photo.00000000-0000-4000-8000-00000000c002"
        static let myPhoto = "chat.photo.00000000-0000-4000-8000-00000000c003"
        static let myPhotoReactions = "chat.reactions.00000000-0000-4000-8000-00000000c003"
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    private func launchChat() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-SocialFakes", "-SocialOpen", "chat", "-account-ui-test-scenario", "signed-in"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["chat.thread"].waitForExistence(timeout: 20), "chat.thread did not open")
        return app
    }

    @MainActor
    private func composer(_ app: XCUIApplication) -> XCUIElement {
        let field = app.descendants(matching: .any)["chat.composer.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        return field
    }

    /// Scrolls the thread until `element` sits whole between the header and the composer. A message above the bottom
    /// anchor is in the accessibility tree before it is on screen, and a press at the centre of a half-visible card lands
    /// on the header that floats over the thread instead of the card's context menu.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        let thread = app.descendants(matching: .any)["chat.thread"]
        // The thread is lazy: older messages exist only once scrolled near.
        for _ in 0..<6 where !element.waitForExistence(timeout: 2) {
            thread.swipeDown()
        }
        XCTAssertTrue(element.exists, "\(element) in the thread")
        let screen = app.windows.firstMatch.frame
        let top = screen.minY + 150 // below the header (its controls end at y ≈ 137)
        let bottom = screen.maxY - 110 // above the composer (it starts at y ≈ 792)
        for _ in 0..<10 {
            let frame = element.frame
            if frame.minY >= top, frame.maxY <= bottom { break }
            // A short drag (not a swipe: no fling) moves the thread down when the element is above the band, up otherwise.
            let start = thread.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let distance: CGFloat = frame.minY < top ? 220 : -220
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)))
        }
        XCTAssertTrue(element.isHittable, "\(element) on screen")
    }

    @MainActor
    func testSendingAMessage() {
        let app = launchChat()
        let field = composer(app)
        field.tap()
        XCTAssertTrue(app.descendants(matching: .any)["chat.composer.mic"].exists, "empty field: camera and mic")
        field.typeText("dinner at 8")
        let send = app.buttons["chat.composer.send"]
        XCTAssertTrue(send.waitForExistence(timeout: 5), "text in the field: the send glyph replaces camera and mic")
        send.tap()
        XCTAssertTrue(app.descendants(matching: .any)["You, dinner at 8"].waitForExistence(timeout: 5), "the sent message shows in the thread")
        XCTAssertTrue(app.descendants(matching: .any)["chat.composer.mic"].waitForExistence(timeout: 5), "the field is empty again: the mic returns")
    }

    @MainActor
    func testReplyingToAMessageFromItsMenu() {
        let app = launchChat()
        let message = app.descendants(matching: .any)["Ana, i can do pasta"].firstMatch
        reveal(message, in: app)
        message.press(forDuration: 1.0)
        let reply = app.buttons["Reply"].firstMatch
        XCTAssertTrue(reply.waitForExistence(timeout: 5), "context menu")
        reply.tap()
        XCTAssertTrue(app.buttons["Cancel reply"].waitForExistence(timeout: 5), "the reply bar shows above the field")
        let field = composer(app)
        field.typeText("count me in")
        app.buttons["chat.composer.send"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["You, count me in"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Cancel reply"].exists, "the reply bar closes on send")
        let quotes = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Ana, i can do pasta"))
        XCTAssertGreaterThanOrEqual(quotes.count, 2, "the reply quotes the message above its text")
    }

    @MainActor
    func testReplyingToAPhoto() {
        let app = launchChat()
        let photo = app.descendants(matching: .any)[Demo.snowPhoto]
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        photo.tap()
        let viewer = app.descendants(matching: .any)["photo.viewer"]
        XCTAssertTrue(viewer.waitForExistence(timeout: 10))
        let reply = app.descendants(matching: .any)["photo.viewer.reply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 5))
        reply.tap()
        reply.typeText("love this")
        let send = app.buttons["photo.viewer.send"]
        XCTAssertTrue(send.waitForExistence(timeout: 5), "text in the field: the send glyph")
        send.tap()
        XCTAssertTrue(app.descendants(matching: .any)["You, love this"].waitForExistence(timeout: 5), "the reply shows as a comment")
        app.buttons["close"].tap()
        // The reply is the newest message, below the last one on screen when the viewer opened.
        let sent = app.descendants(matching: .any)["You, love this"]
        let thread = app.descendants(matching: .any)["chat.thread"]
        for _ in 0..<3 where !sent.waitForExistence(timeout: 2) {
            thread.swipeUp()
        }
        XCTAssertTrue(sent.exists, "the reply is in the thread")
        XCTAssertTrue(app.buttons["Reply to Ana's post"].exists, "the reply carries the quote of the photo")
    }

    @MainActor
    func testReactingToAPhotoFromItsMenu() {
        let app = launchChat()
        let photo = app.descendants(matching: .any)[Demo.myPhoto]
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)[Demo.myPhotoReactions].exists, "no reactions: no chip")
        reveal(photo, in: app)
        photo.press(forDuration: 1.0)
        // The palette item: its accessibility label, or the emoji itself where the system menu keeps the item's title.
        let fire = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR label == %@", "React with fire", "🔥"))
            .firstMatch
        XCTAssertTrue(fire.waitForExistence(timeout: 5), "the quick-reaction row of the context menu")
        fire.tap()
        let chip = app.descendants(matching: .any)[Demo.myPhotoReactions]
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "the chip shows at once")
        XCTAssertTrue(chip.label.localizedCaseInsensitiveContains("fire"))
        XCTAssertNil(chip.label.rangeOfCharacter(from: .decimalDigits), "reactions are never counted")
    }

    @MainActor
    func testUnsendingMyMessage() {
        let app = launchChat()
        let message = app.descendants(matching: .any)["You, yes please"].firstMatch
        reveal(message, in: app)
        message.press(forDuration: 1.0)
        let unsend = app.buttons["Unsend"].firstMatch
        XCTAssertTrue(unsend.waitForExistence(timeout: 5), "context menu")
        unsend.tap()
        let confirm = app.alerts.buttons["Unsend"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "native confirmation alert")
        confirm.tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: message)
        waitForExpectations(timeout: 5)
    }
}

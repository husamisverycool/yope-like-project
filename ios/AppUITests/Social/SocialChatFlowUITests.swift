// Flows of the social group (chat.thread send / reply / react / delete) on the in-memory demo backend:
// `-SocialFakes` (social data), `-SocialOpen chat` (start screen) and the account group's signed-in scenario
// (`-account-ui-test-scenario signed-in`). The app must call `SocialLaunch.apply(to:)` at launch (DEBUG).
import XCTest

final class SocialChatFlowUITests: XCTestCase {
    /// Demo ids (ios/App/Sources/Features/Social/Core/SocialDemoData.swift).
    private enum Demo {
        static let snowPhoto = "chat.photo.00000000-0000-4000-8000-00000000c002"
        static let myPhoto = "chat.photo.00000000-0000-4000-8000-00000000c003"
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

    @MainActor
    func testSendingAMessage() {
        let app = launchChat()
        let field = composer(app)
        field.tap()
        XCTAssertTrue(app.descendants(matching: .any)["chat.composer.mic"].exists, "empty field: the mic circle")
        field.typeText("dinner at 8")
        let send = app.buttons["chat.composer.send"]
        XCTAssertTrue(send.waitForExistence(timeout: 5), "text in the field: the lime send circle replaces the mic")
        send.tap()
        XCTAssertTrue(app.descendants(matching: .any)["you, dinner at 8"].waitForExistence(timeout: 5), "the sent message shows in the thread")
        XCTAssertTrue(app.descendants(matching: .any)["chat.composer.mic"].waitForExistence(timeout: 5), "the field is empty again: the mic returns")
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
        XCTAssertTrue(send.waitForExistence(timeout: 5), "the camera circle's slot shows the send circle")
        send.tap()
        app.buttons["close"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["you, love this"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["reply to Ana’s pic"].exists, "the reply carries the lime quote of the photo")
    }

    @MainActor
    func testReactingToAPhoto() {
        let app = launchChat()
        let photo = app.descendants(matching: .any)[Demo.myPhoto]
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        photo.press(forDuration: 1.0)
        let emoji = app.buttons["yellow heart"].firstMatch
        XCTAssertTrue(emoji.waitForExistence(timeout: 5), "the reaction picker opened")
        emoji.tap()
        let reacted = NSPredicate(format: "value CONTAINS[c] 'yellow heart'")
        expectation(for: reacted, evaluatedWith: photo)
        waitForExpectations(timeout: 5)
        let value = (photo.value as? String) ?? ""
        XCTAssertNil(value.rangeOfCharacter(from: .decimalDigits), "reactions are never counted")
    }

    @MainActor
    func testDeletingMyMessage() {
        let app = launchChat()
        let message = app.descendants(matching: .any)["you, yes please"]
        let thread = app.descendants(matching: .any)["chat.thread"]
        for _ in 0..<3 where !message.waitForExistence(timeout: 2) {
            thread.swipeDown()
        }
        XCTAssertTrue(message.exists)
        message.press(forDuration: 1.0)
        let delete = app.buttons["delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "context menu")
        delete.tap()
        let confirm = app.sheets.buttons["delete"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "native confirmation")
        confirm.tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: message)
        waitForExpectations(timeout: 5)
    }
}

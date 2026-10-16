#if DEMO
import XCTest

/// The Jolt demo build (`-D DEMO`, CI "ios demo tour"): opens the app on its built-in world (no launch arguments, as
/// the owner opens it in the simulator) and walks the main screens, attaching a screenshot of each — CI exports them
/// as the `jolt-demo-tour` artifact. Each step starts from a fresh launch, so one screen that does not open leaves the
/// others' screenshots.
final class DemoTourUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testTourOfTheDemoWorld() {
        let app = XCUIApplication()

        // Launch: the camera, signed in, with a photo in the viewfinder.
        launch(app)
        shot(app, "01-camera")

        // Take a photo and send it (every group is selected when the camera opens on its own).
        let shutter = element(app, "camera.capture.shutter")
        if shutter.waitForExistence(timeout: 5) {
            shutter.tap()
            if element(app, "camera.sendto").waitForExistence(timeout: 10) {
                shot(app, "02-send-to")
                let send = app.buttons["camera.sendto.send"]
                if send.waitForExistence(timeout: 5) { send.tap() }
                _ = element(app, "camera.capture").waitForExistence(timeout: 10)
                shot(app, "03-after-send")
            } else {
                XCTFail("send-to did not open after the shutter")
            }
        } else {
            XCTFail("no shutter on the camera")
        }

        // Home: the groups list, then "roommates" (with the photo just sent).
        guard openRoommates(app, step: "04-groups-list") else { return }
        shot(app, "05-roommates")
        app.swipeUp()
        shot(app, "06-roommates-scrolled")

        // The group's chat.
        launch(app)
        if openRoommates(app), tap(app, "groups.screen.chat"), element(app, "chat.thread").waitForExistence(timeout: 10) {
            shot(app, "07-chat")
        } else {
            XCTFail("the chat did not open")
        }

        // A photo in the viewer: the first photo tile of the week strip. Its tiles are buttons labelled "<date>, photo by
        // <name>" (groups.screen.photo.accessibilityLabel); "groups.screen.week" is the strip's header, which opens the
        // week's history, and the group cover above it opens nothing.
        launch(app)
        if openRoommates(app) {
            let tile = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", photo by ")).firstMatch
            if tile.waitForExistence(timeout: 5) {
                tile.tap()
                if element(app, "photo.viewer").waitForExistence(timeout: 10) {
                    shot(app, "08-viewer")
                } else {
                    shot(app, "08-viewer-missing")
                    XCTFail("the viewer did not open from the week strip")
                }
            } else {
                XCTFail("no photo tile in the week strip")
            }
        }

        // Memories: On This Day, a card at the end of the members' cards (a horizontal pager under the week strip; the
        // weekly question's card sits before it). The pager opens on a member's card, so On This Day starts off screen,
        // and `isHittable` on an element wholly outside the window fails the test ("Activation point invalid", run 91):
        // visibility is read from frames instead.
        launch(app)
        if openRoommates(app) {
            let entry = element(app, "onthisday.entry")
            let cards = element(app, "groups.screen.cards")
            for _ in 0..<3 where !onScreen(app, cards) { app.swipeUp() }
            for _ in 0..<8 where !onScreen(app, entry) && cards.exists {
                if entry.exists, entry.frame.midX < app.windows.firstMatch.frame.midX { cards.swipeRight() } else { cards.swipeLeft() }
            }
            if onScreen(app, entry) {
                entry.tap()
                _ = element(app, "onthisday").waitForExistence(timeout: 10)
                shot(app, "09-on-this-day")
            } else {
                XCTFail("no On This Day card on roommates")
            }
        }

        // Recaps and albums.
        launch(app)
        if openRoommates(app), tap(app, "groups.screen.recaps") {
            sleep(2)
            shot(app, "10-recaps")
        }
        launch(app)
        if openRoommates(app), tap(app, "groups.screen.albums") {
            sleep(2)
            shot(app, "11-albums")
        }

        // The other tabs.
        launch(app)
        if tapTab(app, "People") {
            sleep(2)
            shot(app, "12-people")
        }
        if tapTab(app, "Profile") {
            sleep(2)
            shot(app, "13-profile")
        }
    }

    // MARK: Helpers

    @MainActor
    private func launch(_ app: XCUIApplication) {
        app.terminate()
        app.launch()
        XCTAssertTrue(element(app, "camera.capture").waitForExistence(timeout: 20), "the demo opens to the camera")
    }

    @MainActor
    private func openRoommates(_ app: XCUIApplication, step: String? = nil) -> Bool {
        guard tapTab(app, "Home"), element(app, "groups.list").waitForExistence(timeout: 10) else {
            XCTFail("the groups list did not open")
            return false
        }
        if let step { shot(app, step) }
        let row = app.descendants(matching: .any).matching(identifier: "groups.list.row").firstMatch
        guard row.waitForExistence(timeout: 5) else {
            XCTFail("no group rows")
            return false
        }
        row.tap()
        guard element(app, "groups.screen").waitForExistence(timeout: 10) else {
            XCTFail("the group screen did not open")
            return false
        }
        sleep(1)
        return true
    }

    @MainActor
    private func tapTab(_ app: XCUIApplication, _ label: String) -> Bool {
        let tab = app.buttons[label].firstMatch
        guard tab.waitForExistence(timeout: 10) else {
            XCTFail("no \(label) tab")
            return false
        }
        tab.tap()
        return true
    }

    @MainActor
    private func tap(_ app: XCUIApplication, _ identifier: String) -> Bool {
        let target = element(app, identifier)
        for _ in 0..<3 where !target.exists { app.swipeUp() }
        guard target.waitForExistence(timeout: 5) else {
            XCTFail("\(identifier) missing")
            return false
        }
        target.tap()
        return true
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Whether `target`'s centre is inside the app's window (frames only, never `isHittable`).
    @MainActor
    private func onScreen(_ app: XCUIApplication, _ target: XCUIElement) -> Bool {
        guard target.exists else { return false }
        let frame = target.frame
        return !frame.isEmpty && app.windows.firstMatch.frame.contains(CGPoint(x: frame.midX, y: frame.midY))
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif

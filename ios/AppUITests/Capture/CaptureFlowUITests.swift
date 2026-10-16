import XCTest

/// capture → send flows (camera.capture → camera.sendto). The simulator has no camera: the app runs
/// with the capture fakes (`-capture-fakes`, App/Sources/Features/Capture/Support/CaptureFakes.swift).
///
/// Reaching the camera needs a signed-in session: the account group's in-memory scenario
/// `-account-ui-test-scenario with-groups` (a member with groups), then the tab bar's camera item. The
/// environment variable `CAPTURE_UI_TEST_EXTRA_ARGS` (space-separated) replaces those arguments.
final class CaptureFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launchToCamera(_ arguments: [String] = []) throws -> XCUIApplication {
        let app = XCUIApplication()
        let extra = ProcessInfo.processInfo.environment["CAPTURE_UI_TEST_EXTRA_ARGS"]?
            .split(separator: " ").map(String.init) ?? ["-account-ui-test-scenario", "with-groups"]
        app.launchArguments = ["-capture-fakes"] + arguments + extra
        app.launch()
        let camera = app.otherElements["camera.capture"]
        if camera.waitForExistence(timeout: 5) { return app }
        // The app opens to the camera (camera.capture "In"); otherwise the tab bar's camera item (its VoiceOver label,
        // copy `groups.list.tab.camera.accessibilityLabel`).
        let tab = app.buttons["Camera"].firstMatch
        if tab.waitForExistence(timeout: 10) {
            tab.tap()
            if camera.waitForExistence(timeout: 5) { return app }
        }
        XCTFail("The camera is not reachable from launch: the signed-in scenario, then the tab bar's camera item.")
        throw CameraUnreachable()
    }

    private struct CameraUnreachable: Error {}

    @MainActor
    func testCaptureThenSendClosesTheCamera() throws {
        let app = try launchToCamera()
        let shutter = app.descendants(matching: .any)["camera.capture.shutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        shutter.tap()

        let sendTo = app.otherElements["camera.sendto"]
        XCTAssertTrue(sendTo.waitForExistence(timeout: 5), "one tap captures, no edit step")
        let first = app.buttons["camera.sendto.row.fake-group-1"]
        let second = app.buttons["camera.sendto.row.fake-group-2"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(first.isSelected, "no context: every group is preselected")
        XCTAssertTrue(second.isSelected)

        second.tap()
        XCTAssertFalse(second.isSelected)

        let send = app.buttons["camera.sendto.send"]
        XCTAssertTrue(send.exists)
        XCTAssertTrue(send.isEnabled)
        send.tap()
        XCTAssertTrue(sendTo.waitForNonExistence(timeout: 10), "the composer waits for the post (busy capsule), then closes")
    }

    @MainActor
    func testCloseDiscardsAndReturnsToCamera() throws {
        let app = try launchToCamera()
        app.descendants(matching: .any)["camera.capture.shutter"].tap()
        let sendTo = app.otherElements["camera.sendto"]
        XCTAssertTrue(sendTo.waitForExistence(timeout: 5))
        app.buttons["camera.sendto.close"].tap()
        XCTAssertTrue(sendTo.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["camera.capture"].exists)
    }

    @MainActor
    func testDeselectingEveryGroupDisablesSend() throws {
        let app = try launchToCamera()
        app.descendants(matching: .any)["camera.capture.shutter"].tap()
        XCTAssertTrue(app.otherElements["camera.sendto"].waitForExistence(timeout: 5))
        app.buttons["camera.sendto.row.fake-group-1"].tap()
        app.buttons["camera.sendto.row.fake-group-2"].tap()
        let send = app.buttons["camera.sendto.send"]
        XCTAssertTrue(send.exists, "the capsule stays, disabled (#4D4D4D)")
        XCTAssertFalse(send.isEnabled)
    }

    @MainActor
    func testMessageSheetThenCloseAsksBeforeDiscarding() throws {
        let app = try launchToCamera()
        app.descendants(matching: .any)["camera.capture.shutter"].tap()
        let sendTo = app.otherElements["camera.sendto"]
        XCTAssertTrue(sendTo.waitForExistence(timeout: 5))
        app.buttons["camera.sendto.message"].tap()
        let field = app.textFields["camera.sendto.message.field"].exists
            ? app.textFields["camera.sendto.message.field"]
            : app.textViews["camera.sendto.message.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the Add a Message sheet")
        field.typeText("hi")
        app.buttons["camera.sendto.message.done"].tap()
        XCTAssertTrue(app.buttons["camera.sendto.message"].waitForExistence(timeout: 5))

        // With a message the close circle asks first (Retro's lost-changes warning).
        app.buttons["camera.sendto.close"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5), "Discard photo? (a message would be lost)")
    }

    @MainActor
    func testNoGroupsShowsEmptyState() throws {
        let app = try launchToCamera(["-capture-fake-no-groups"])
        app.descendants(matching: .any)["camera.capture.shutter"].tap()
        XCTAssertTrue(app.otherElements["camera.sendto"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["camera.sendto.empty"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["camera.sendto.send"].isEnabled)
    }

    @MainActor
    func testPremiumHoldShowsCoach() throws {
        let app = try launchToCamera(["-capture-fake-premium"])
        XCTAssertTrue(app.descendants(matching: .any)["camera.capture.coach"].waitForExistence(timeout: 5), "hold-to-record coach for members with video")
    }
}

private extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}

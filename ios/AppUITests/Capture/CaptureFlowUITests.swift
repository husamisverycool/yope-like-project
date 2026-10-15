import XCTest

/// capture → send flows (camera.capture → camera.sendto). The simulator has no camera: the app runs
/// with the capture fakes (`-capture-fakes`, App/Sources/Features/Capture/Support/CaptureFakes.swift).
///
/// Reaching the camera needs a signed-in session and an entry into the camera from the shell
/// (account group). Extra launch arguments for that (e.g. the account pass's signed-in UI-test
/// scenario) are read from the environment variable `CAPTURE_UI_TEST_EXTRA_ARGS` (space-separated).
final class CaptureFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launchToCamera(_ arguments: [String] = []) throws -> XCUIApplication {
        let app = XCUIApplication()
        let extra = ProcessInfo.processInfo.environment["CAPTURE_UI_TEST_EXTRA_ARGS"]?
            .split(separator: " ").map(String.init) ?? []
        app.launchArguments = ["-capture-fakes"] + arguments + extra
        app.launch()
        let camera = app.otherElements["camera.capture"]
        if camera.waitForExistence(timeout: 5) { return app }
        // The app opens to the camera (camera.capture "In"); otherwise the tab bar's camera item.
        let tab = app.buttons["camera"]
        if tab.waitForExistence(timeout: 5) {
            tab.tap()
            if camera.waitForExistence(timeout: 5) { return app }
        }
        throw XCTSkip("The camera is not reachable from launch: needs a signed-in UI-test scenario (CAPTURE_UI_TEST_EXTRA_ARGS) and the shell's camera entry.")
    }

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
        send.tap()
        XCTAssertTrue(sendTo.waitForNonExistence(timeout: 5), "the sheet closes at once; the outbox uploads")
        XCTAssertFalse(app.otherElements["camera.capture"].exists, "the camera closes after sending")
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
    func testDeselectingEveryGroupHidesSend() throws {
        let app = try launchToCamera()
        app.descendants(matching: .any)["camera.capture.shutter"].tap()
        XCTAssertTrue(app.otherElements["camera.sendto"].waitForExistence(timeout: 5))
        app.buttons["camera.sendto.row.fake-group-1"].tap()
        app.buttons["camera.sendto.row.fake-group-2"].tap()
        XCTAssertFalse(app.buttons["camera.sendto.send"].exists, "hidden with nothing selected")
    }

    @MainActor
    func testNoGroupsShowsEmptyState() throws {
        let app = try launchToCamera(["-capture-fake-no-groups"])
        app.descendants(matching: .any)["camera.capture.shutter"].tap()
        XCTAssertTrue(app.otherElements["camera.sendto"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["camera.sendto.empty"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["camera.sendto.send"].exists)
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

// birthday.request → birthday.contribute → back to the request with the member's own block.
import XCTest

final class MemoryContributeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testContributeAPhotoAndALine() throws {
        let app = XCUIApplication()
        app.launchArguments += MemoryUITestLaunch.arguments(open: "request")
        app.launch()
        _ = try MemoryUITestLaunch.waitForScreen(app, "birthday.request")

        // Request: "Add Your Photo".
        let cta = MemoryUITestLaunch.element(app, "birthday.request.cta")
        XCTAssertTrue(cta.waitForExistence(timeout: 10))
        cta.tap()

        // Step 1: only own / self-tagged photos; nothing selected yet, so "Use Photo" waits.
        XCTAssertTrue(MemoryUITestLaunch.element(app, "birthday.contribute").waitForExistence(timeout: 10))
        let stepper = MemoryUITestLaunch.element(app, "birthday.contribute.stepper")
        XCTAssertTrue(stepper.waitForExistence(timeout: 10))
        let use = MemoryUITestLaunch.element(app, "birthday.contribute.use")
        XCTAssertTrue(use.waitForExistence(timeout: 10))
        XCTAssertFalse(use.isEnabled)
        XCTAssertTrue(MemoryUITestLaunch.element(app, "birthday.contribute.photo.3").exists, "four eligible photos in the fixtures")
        XCTAssertFalse(MemoryUITestLaunch.element(app, "birthday.contribute.photo.4").exists, "others' untagged photos are not offered")
        let photo = MemoryUITestLaunch.element(app, "birthday.contribute.photo.1")
        photo.tap()
        XCTAssertTrue(photo.isSelected)
        XCTAssertTrue(use.isEnabled)
        use.tap()

        // Step 2: the line, then Submit (enabled once it has a non-space character).
        let submit = MemoryUITestLaunch.element(app, "birthday.contribute.submit")
        XCTAssertTrue(submit.waitForExistence(timeout: 10))
        XCTAssertFalse(submit.isEnabled)
        let field = MemoryUITestLaunch.element(app, "birthday.contribute.line")
        field.tap()
        field.typeText("the best laugh in the group")
        XCTAssertTrue(submit.isEnabled)
        submit.tap()

        // Step 3: Done → back on the request with "Your Photo".
        let done = MemoryUITestLaunch.element(app, "birthday.contribute.done")
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: done)
        waitForExpectations(timeout: 10)
        done.tap()
        XCTAssertTrue(MemoryUITestLaunch.element(app, "birthday.request.own").waitForExistence(timeout: 10))
        XCTAssertTrue(MemoryUITestLaunch.element(app, "birthday.request.change").exists)
        XCTAssertFalse(MemoryUITestLaunch.element(app, "birthday.request.cta").exists, "the button is replaced by the own block")

        // Retake reopens step 1 with the current photo selected.
        MemoryUITestLaunch.element(app, "birthday.request.change").tap()
        let selected = MemoryUITestLaunch.element(app, "birthday.contribute.photo.1")
        XCTAssertTrue(selected.waitForExistence(timeout: 10))
        XCTAssertTrue(selected.isSelected)
        MemoryUITestLaunch.element(app, "birthday.contribute.close").tap()
        XCTAssertTrue(MemoryUITestLaunch.element(app, "birthday.request.own").waitForExistence(timeout: 10))
    }
}

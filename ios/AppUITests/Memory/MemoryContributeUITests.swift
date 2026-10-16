// birthday.request → birthday.contribute (choose a photo → the composer → "Add a Message" → "Add to video") → back on the
// request with the member's own contribution; "Change photo" reopens the picker with the current photo selected.
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

        // The request card: "Add your photo".
        let cta = MemoryUITestLaunch.element(app, "birthday.request.cta")
        XCTAssertTrue(cta.waitForExistence(timeout: 10))
        cta.tap()

        // Step 1: only own / self-tagged photos; nothing selected yet, so "Next" waits.
        XCTAssertTrue(MemoryUITestLaunch.element(app, "birthday.contribute").waitForExistence(timeout: 10))
        let next = app.navigationBars.buttons.element(boundBy: 1)
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        XCTAssertFalse(next.isEnabled)
        XCTAssertTrue(MemoryUITestLaunch.element(app, "birthday.contribute.photo.3").waitForExistence(timeout: 10), "four eligible photos in the fixtures")
        XCTAssertFalse(MemoryUITestLaunch.element(app, "birthday.contribute.photo.4").exists, "others' untagged photos are not offered")
        let photo = MemoryUITestLaunch.element(app, "birthday.contribute.photo.1")
        photo.tap()
        XCTAssertTrue(photo.isSelected)
        XCTAssertTrue(next.isEnabled)
        next.tap()

        // Step 2: the composer; "Add to video" waits for a line.
        let submit = MemoryUITestLaunch.element(app, "birthday.contribute.submit")
        XCTAssertTrue(submit.waitForExistence(timeout: 10))
        XCTAssertFalse(submit.isEnabled)
        MemoryUITestLaunch.element(app, "birthday.contribute.pill").tap()

        // Step 2a: the "Add a Message" modal with the keyboard up.
        let field = MemoryUITestLaunch.element(app, "birthday.contribute.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.typeText("the best laugh in the group")
        MemoryUITestLaunch.element(app, "birthday.contribute.done").tap()
        XCTAssertTrue(MemoryUITestLaunch.element(app, "birthday.contribute.line").waitForExistence(timeout: 5), "the line under the photo")
        XCTAssertTrue(submit.isEnabled)
        submit.tap()

        // Sent: the sheet closes; the request shows "You added a photo".
        XCTAssertTrue(MemoryUITestLaunch.element(app, "birthday.request.own").waitForExistence(timeout: 10))
        XCTAssertTrue(MemoryUITestLaunch.element(app, "birthday.request.change").exists)
        XCTAssertFalse(MemoryUITestLaunch.element(app, "birthday.request.cta").exists, "the capsule is replaced by your contribution")

        // "Change photo" reopens step 1 with the current photo selected; Cancel closes without sending.
        MemoryUITestLaunch.element(app, "birthday.request.change").tap()
        let selected = MemoryUITestLaunch.element(app, "birthday.contribute.photo.1")
        XCTAssertTrue(selected.waitForExistence(timeout: 10))
        XCTAssertTrue(selected.isSelected)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(MemoryUITestLaunch.element(app, "birthday.request.own").waitForExistence(timeout: 10))
    }
}

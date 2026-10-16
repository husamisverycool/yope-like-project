// onthisday: the feature intro once, the Rewind page with the dial's play / pause (share and random hide while playing),
// the dice (shuffle) and the back chevron.
import XCTest

final class MemoryOnThisDayUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testIntroPlayPauseShuffleAndBack() throws {
        let app = XCUIApplication()
        app.launchArguments += MemoryUITestLaunch.arguments(open: "onThisDay")
        app.launch()
        _ = try MemoryUITestLaunch.waitForScreen(app, "onthisday")

        // First open: the feature intro; its capsule closes it.
        let intro = MemoryUITestLaunch.element(app, "onthisday.intro")
        if intro.waitForExistence(timeout: 10) {
            intro.buttons.firstMatch.tap()
            XCTAssertFalse(intro.waitForExistence(timeout: 2))
        }

        let dial = MemoryUITestLaunch.element(app, "onthisday.dial")
        XCTAssertTrue(dial.waitForExistence(timeout: 10))
        let title = MemoryUITestLaunch.element(app, "onthisday.title")
        let subtitle = MemoryUITestLaunch.element(app, "onthisday.subtitle")
        XCTAssertTrue(subtitle.exists)

        // Play: the centre turns to pause; share and random hide while playing.
        let play = MemoryUITestLaunch.element(app, "onthisday.play")
        let share = MemoryUITestLaunch.element(app, "onthisday.share")
        let playLabel = play.label
        play.tap()
        XCTAssertNotEqual(play.label, playLabel, "play becomes pause")
        XCTAssertFalse(share.isHittable, "share hides while playing")
        play.tap()
        XCTAssertEqual(play.label, playLabel)

        // The dice: a random memory of the group's history; the subtitle switches to "Memories · {name}".
        let daySubtitle = subtitle.label
        MemoryUITestLaunch.element(app, "onthisday.shuffle").tap()
        let switched = NSPredicate(format: "label != %@", daySubtitle)
        expectation(for: switched, evaluatedWith: subtitle)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(title.exists)

        MemoryUITestLaunch.element(app, "onthisday.back").tap()
        XCTAssertFalse(MemoryUITestLaunch.element(app, "onthisday").waitForExistence(timeout: 2))
    }
}

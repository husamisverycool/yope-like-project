// year.story: tap-through (right half next, left half previous), summary, replay, close.
import XCTest

final class MemoryYearStoryUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTapThroughToTheSummaryAndReplay() throws {
        let app = XCUIApplication()
        app.launchArguments += MemoryUITestLaunch.arguments(open: "yearStory")
        app.launch()
        let story = try MemoryUITestLaunch.waitForScreen(app, "year.story")
        let close = MemoryUITestLaunch.element(app, "year.story.close")
        XCTAssertTrue(close.waitForExistence(timeout: 10))

        let right = story.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        let left = story.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        let share = MemoryUITestLaunch.element(app, "year.story.share")
        XCTAssertFalse(share.exists, "the intro card states no fact: no share row")

        // Card 2 (setup) → card 3 (moments shared): a fact card with the share row.
        right.tap()
        right.tap()
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        left.tap()
        XCTAssertFalse(share.exists, "back on the setup card")

        // On to the summary (13 cards in the fixture story).
        for _ in 0..<15 { right.tap() }
        let replay = MemoryUITestLaunch.element(app, "year.story.replay")
        XCTAssertTrue(replay.waitForExistence(timeout: 5))
        XCTAssertTrue(MemoryUITestLaunch.element(app, "year.story.summary.share").waitForExistence(timeout: 10))
        XCTAssertTrue(MemoryUITestLaunch.element(app, "year.story.summary.pager").exists)
        replay.tap()
        XCTAssertFalse(replay.exists)
        XCTAssertFalse(share.exists, "replayed to the intro card")

        close.tap()
        XCTAssertFalse(MemoryUITestLaunch.element(app, "year.story").waitForExistence(timeout: 2))
    }
}

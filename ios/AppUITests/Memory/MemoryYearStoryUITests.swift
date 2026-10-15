// year.story: auto-advance (`duration.year.story.card`) with pause / play, tap-through (right half
// next, left half previous), summary with page dots, replay, close.
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

        // Pause first so the cards only change on taps (the story advances on its own otherwise).
        let pause = MemoryUITestLaunch.element(app, "year.story.pause")
        XCTAssertTrue(pause.waitForExistence(timeout: 5), "the pause circle shows on cards that advance on their own")
        pause.tap()

        let right = story.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        let left = story.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        // Back to card 1 in case the story advanced before the pause (left on card 1 does nothing).
        for _ in 0..<3 { left.tap() }
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
        XCTAssertFalse(pause.exists, "the summary waits: no pause circle")
        replay.tap()
        XCTAssertFalse(replay.exists)
        XCTAssertFalse(share.exists, "replayed to the intro card")

        close.tap()
        XCTAssertFalse(MemoryUITestLaunch.element(app, "year.story").waitForExistence(timeout: 2))
    }

    @MainActor
    func testCardsAdvanceOnTheirOwnAndPauseHoldsTheCard() throws {
        let app = XCUIApplication()
        app.launchArguments += MemoryUITestLaunch.arguments(open: "yearStory")
        app.launch()
        _ = try MemoryUITestLaunch.waitForScreen(app, "year.story")

        // No taps: intro → setup → "moments shared" (the first card with a share row) on their own,
        // one `duration.year.story.card` each.
        let share = MemoryUITestLaunch.element(app, "year.story.share")
        XCTAssertTrue(share.waitForExistence(timeout: 20), "the story reached a fact card without a tap")

        let pause = MemoryUITestLaunch.element(app, "year.story.pause")
        XCTAssertTrue(pause.exists)
        let pauseLabel = pause.label
        pause.tap()
        XCTAssertNotEqual(pause.label, pauseLabel, "pause becomes play")

        // Paused: the card in view stays well past a card's time.
        let shown = app.staticTexts.allElementsBoundByIndex.map(\.label)
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "paused")], timeout: 6)
        XCTAssertEqual(app.staticTexts.allElementsBoundByIndex.map(\.label), shown, "no card change while paused")

        pause.tap()
        XCTAssertEqual(pause.label, pauseLabel, "play becomes pause")
    }
}

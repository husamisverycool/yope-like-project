// year.story: auto-advance (`duration.year.story.card`) with pause / play, tap-through (right half
// next, left half previous), the Share pill on fact cards, the summary with page dots, replay, close — inside the
// shared recap preview (capture's `RecapPreviewScreen`: close `year.story.close` (`RecapPreviewClose`), dots `recap.preview.dots`).
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
        let position = MemoryUITestLaunch.element(app, "year.story.position")
        XCTAssertFalse(share.exists, "the intro card states no fact: no Share pill")
        XCTAssertTrue(position.exists, "the position pill on the cards")

        // Card 2 (look back) → card 3 (moments shared): a fact card with the Share pill.
        right.tap()
        right.tap()
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        left.tap()
        XCTAssertFalse(share.exists, "back on the look-back card")

        // On to the summary (13 cards in the fixture story).
        for _ in 0..<15 { right.tap() }
        let replay = MemoryUITestLaunch.element(app, "year.story.replay")
        XCTAssertTrue(replay.waitForExistence(timeout: 5))
        XCTAssertTrue(share.waitForExistence(timeout: 10), "the summary shares the style in view")
        XCTAssertTrue(MemoryUITestLaunch.element(app, "recap.preview.dots").exists, "page dots under the frame on the summary")
        XCTAssertFalse(position.exists, "the summary: no position pill")
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
        let story = try MemoryUITestLaunch.waitForScreen(app, "year.story")

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
        let shown = try settledTexts(of: story)
        XCTAssertFalse(shown.isEmpty, "the card's texts are read from the story")
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "paused")], timeout: 6)
        XCTAssertEqual(try texts(of: story), shown, "no card change while paused")

        pause.tap()
        XCTAssertEqual(pause.label, pauseLabel, "play becomes pause")
    }

    /// The story's texts from one accessibility snapshot. Reading them one query at a time races the screen: in run 78
    /// the list held 16 texts and only 15 were left when the last one was read.
    @MainActor
    private func texts(of element: XCUIElement) throws -> [String] {
        func collect(_ snapshot: any XCUIElementSnapshot) -> [String] {
            (snapshot.elementType == .staticText ? [snapshot.label] : []) + snapshot.children.flatMap(collect)
        }
        return collect(try element.snapshot())
    }

    /// The story's texts once two snapshots half a second apart agree: a pause can land during the cross-fade to the
    /// next card, which still finishes after the pause (both cards' texts are on screen until it does).
    @MainActor
    private func settledTexts(of element: XCUIElement) throws -> [String] {
        var previous = try texts(of: element)
        for _ in 0..<6 {
            _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: 0.5)
            let current = try texts(of: element)
            if current == previous { return current }
            previous = current
        }
        return previous
    }
}

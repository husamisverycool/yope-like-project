// year.story — data, cards and navigation tests (design/surfaces/year.story.md).
@testable import App
import AppData
import DesignSystem
import XCTest

@MainActor
final class MemoryYearStoryTests: XCTestCase {
    private var year: Int { LocalDate(MemoryTestContext.referenceNow, in: MemoryFormat.utc).year }

    private func photo(_ number: Int) -> YearStoryPhoto {
        YearStoryPhoto(postID: MemoryIDs.post(number), name: "Bea", date: LocalDate(year: 2026, month: 2, day: 25)!, imageURL: nil)
    }

    func testParsesWorkerDataV1() {
        let json: JSONValue = .object([
            "version": .number(1), "year": .number(2026), "time_zone": .string("Europe/Lisbon"),
            "moments_shared": .number(128), "busiest_month": .object(["month": .number(7)]),
            "most_reacted": .array([.string(MemoryIDs.post(2).rawValue)]),
            "everyone_days": .array([.object([
                "local_date": .string("2026-06-14"), "invitation_id": .string("x"),
                "collage_id": .string("00000000-0000-4000-8000-0000000000e1"), "post_ids": .array([.string(MemoryIDs.post(1).rawValue)]),
            ])]),
        ])
        let data = YearStoryData(json: json, fallbackYear: 2000)
        XCTAssertEqual(data?.year, 2026)
        XCTAssertEqual(data?.timeZone.identifier, "Europe/Lisbon")
        XCTAssertEqual(data?.momentsShared, 128)
        XCTAssertEqual(data?.busiestMonth, 7)
        XCTAssertEqual(data?.mostReacted, [MemoryIDs.post(2)])
        XCTAssertEqual(data?.everyoneDays.first?.localDate.description, "2026-06-14")
        XCTAssertNil(YearStoryData(json: nil, fallbackYear: 2026), "computing: no data, no story")
        XCTAssertNil(YearStoryData(json: .array([]), fallbackYear: 2026))
        let partial = YearStoryData(json: .object(["busiest_month": .object(["month": .number(13)])]), fallbackYear: 2026)
        XCTAssertNil(partial?.busiestMonth, "out-of-range month is missing data")
    }

    func testCardsFollowTheSpecOrderOneFactEach() {
        let data = YearStoryData(json: .object([
            "year": .number(2026), "moments_shared": .number(42), "busiest_month": .object(["month": .number(3)]),
        ]), fallbackYear: 2026)!
        let collage = YearStoryCollage(collageID: CollageID("00000000-0000-4000-8000-0000000000e1"), date: LocalDate(year: 2026, month: 6, day: 14)!, postIDs: [], imageURL: nil)
        let cards = YearStoryCard.build(data: data, groupName: "Sunday dinners", photos: [photo(1), photo(2)], collages: [collage])
        XCTAssertEqual(cards.map(\.id), [
            "intro", "moments-setup", "moments", "busiest-month", "most-reacted-setup",
            "most-reacted-" + MemoryIDs.post(1).rawValue, "most-reacted-" + MemoryIDs.post(2).rawValue,
            "together-setup", "together-" + collage.collageID.rawValue, "teaser", "outro", "summary",
        ])
        XCTAssertEqual(cards.filter(\.isShareable).count, 5, "only the cards that state a fact are shared")
        XCTAssertEqual(cards[2].headline, Copy.yearStoryMomentsCount(group: "Sunday dinners", count: 42.formatted()))
        XCTAssertEqual(cards[2].subline, Copy.yearStoryMomentsAside)
        XCTAssertEqual(cards[3].headline, Copy.yearStoryBusiestMonthTitle(month: MemoryFormat.storyMonth(3, year: 2026)!))
        XCTAssertEqual(cards[0].headline, Copy.yearStoryIntroTitle)
        XCTAssertEqual(cards[0].subline, Copy.yearStoryIntroSubtitle)
    }

    func testMissingDataSkipsWholeSectionsAndListsStopAtListLength() {
        let data = YearStoryData(json: .object(["year": .number(2026)]), fallbackYear: 2026)!
        let cards = YearStoryCard.build(data: data, groupName: "g", photos: (1...7).map(photo), collages: [])
        XCTAssertFalse(cards.contains(.momentsSetup), "no number → no moments cards")
        XCTAssertFalse(cards.contains(.togetherSetup), "no everyone-days → no together cards")
        let photos = cards.filter { if case .mostReacted = $0 { return true } else { return false } }
        XCTAssertEqual(photos.count, Int(Tokens.Counts.yearStoryListLength))
        XCTAssertEqual(cards.last, .summary)
    }

    func testRankedPhotosCarryNoNumbersOrRanks() {
        let data = YearStoryData(json: .object(["year": .number(2026)]), fallbackYear: 2026)!
        let cards = YearStoryCard.build(data: data, groupName: "g", photos: (1...5).map(photo), collages: [])
        let headlines = cards.compactMap { card -> String? in
            if case .mostReacted = card { return card.headline }
            return nil
        }
        XCTAssertEqual(headlines.count, 5)
        for (position, headline) in headlines.enumerated() {
            XCTAssertEqual(headline, Copy.yearStoryMostReactedPhoto(name: "Bea", date: MemoryFormat.storyDate(LocalDate(year: 2026, month: 2, day: 25)!)))
            XCTAssertFalse(headline.hasPrefix(String(position + 1)), "no rank number")
            XCTAssertFalse(headline.contains("#"))
            XCTAssertNil(cards.first { $0.headline == headline }?.subline, "no aside with a count")
        }
    }

    func testLoadsTheFixtureStoryAndNavigatesByTaps() async {
        let context = MemoryTestContext()
        let model = YearStoryModel(groupID: MemoryIDs.group, year: year, dependencies: context.dependencies)
        await model.loadIfNeeded()
        XCTAssertEqual(model.phase, .loaded)
        // intro, moments ×2, month, most-reacted setup + 3 photos, together setup + 1 day, teaser, outro, summary.
        XCTAssertEqual(model.cards.count, 13)
        let reacted = model.cards.compactMap { card -> PostID? in
            if case let .mostReacted(photo) = card { return photo.postID }
            return nil
        }
        XCTAssertEqual(reacted, [MemoryIDs.post(2), MemoryIDs.post(1), MemoryIDs.post(3)], "worker order kept")
        XCTAssertEqual(model.index, 0)
        model.previous()
        XCTAssertEqual(model.index, 0, "first card: left half does nothing")
        model.next()
        model.next()
        XCTAssertEqual(model.index, 2)
        model.previous()
        XCTAssertEqual(model.index, 1)
        for _ in 0..<20 { model.next() }
        XCTAssertEqual(model.currentCard, .summary)
        model.replay()
        XCTAssertEqual(model.index, 0)
        model.close()
        XCTAssertTrue(model.isFinished)
    }

    // MARK: Auto-advance (`duration.year.story.card`)

    func testEachCardAdvancesOnItsOwnAfterTheCardDurationAndTheSummaryWaits() async {
        let context = MemoryTestContext()
        let model = YearStoryModel(groupID: MemoryIDs.group, year: year, dependencies: context.dependencies)
        await model.loadIfNeeded()
        XCTAssertEqual(model.cardDuration, Tokens.Durations.yearStoryCard)
        XCTAssertTrue(model.advancesOnItsOwn)
        XCTAssertTrue(model.clockRuns)
        let slept = await memoryEventually { context.sleeper.requested == [Tokens.Durations.yearStoryCard] }
        XCTAssertTrue(slept, "the first card waits the full card duration")
        context.sleeper.fire()
        let advanced = await memoryEventually { model.index == 1 }
        XCTAssertTrue(advanced, "the story moves to card 2 on its own")
        let rescheduled = await memoryEventually { context.sleeper.pending == 1 }
        XCTAssertTrue(rescheduled, "card 2 gets its own full duration")
        XCTAssertEqual(context.sleeper.requested.last, Tokens.Durations.yearStoryCard)

        // The card before the summary advances to it; the summary does not advance.
        while model.index + 2 < model.cards.count { model.next() }
        await memoryEventually { context.sleeper.pending == 1 }
        context.sleeper.fire()
        let onSummary = await memoryEventually { model.currentCard == .summary }
        XCTAssertTrue(onSummary)
        XCTAssertFalse(model.advancesOnItsOwn)
        XCTAssertFalse(model.clockRuns)
        XCTAssertEqual(context.sleeper.pending, 0, "no timer on the summary")
        XCTAssertEqual(model.currentFraction(at: context.now), 1, "the summary's segment reads full")
        XCTAssertFalse(model.advanceIfDue(at: context.now.addingTimeInterval(Tokens.Durations.yearStoryCard * 2)))
        XCTAssertEqual(model.currentCard, .summary)
    }

    func testTheSegmentFillsWithElapsedTimeAndAdvancesWhenDue() async {
        let context = MemoryTestContext()
        let model = YearStoryModel(groupID: MemoryIDs.group, year: year, dependencies: context.dependencies)
        await model.loadIfNeeded()
        let start = context.now
        let duration = Tokens.Durations.yearStoryCard
        XCTAssertEqual(model.currentFraction(at: start), 0, accuracy: 0.0001)
        XCTAssertEqual(model.currentFraction(at: start.addingTimeInterval(duration / 4)), 0.25, accuracy: 0.0001)
        XCTAssertEqual(model.currentFraction(at: start.addingTimeInterval(duration * 2)), 1, "clamped")
        XCTAssertFalse(model.advanceIfDue(at: start.addingTimeInterval(duration * 0.99)))
        XCTAssertEqual(model.index, 0)
        XCTAssertTrue(model.advanceIfDue(at: start.addingTimeInterval(duration)))
        XCTAssertEqual(model.index, 1)
        XCTAssertEqual(model.currentFraction(at: start), 0, accuracy: 0.0001, "a new card starts empty")
    }

    func testPauseFreezesTheSegmentAndResumesWithTheRemainingTime() async {
        let context = MemoryTestContext()
        let model = YearStoryModel(groupID: MemoryIDs.group, year: year, dependencies: context.dependencies)
        await model.loadIfNeeded()
        await memoryEventually { context.sleeper.pending == 1 }
        let duration = Tokens.Durations.yearStoryCard
        context.clock.advance(by: duration / 4)
        model.togglePause()
        XCTAssertTrue(model.isPaused)
        XCTAssertFalse(model.clockRuns)
        let cancelled = await memoryEventually { context.sleeper.pending == 0 }
        XCTAssertTrue(cancelled, "pausing cancels the card timer")
        context.clock.advance(by: duration)
        XCTAssertEqual(model.currentFraction(at: context.now), 0.25, accuracy: 0.0001, "frozen while paused")
        XCTAssertFalse(model.advanceIfDue(at: context.now.addingTimeInterval(duration)))

        // Taps while paused change the card but keep the story paused (WCAG 2.2.2).
        model.next()
        XCTAssertEqual(model.index, 1)
        XCTAssertTrue(model.isPaused)
        XCTAssertEqual(model.currentFraction(at: context.now), 0, accuracy: 0.0001)
        model.previous()
        XCTAssertEqual(model.index, 0)

        model.togglePause()
        XCTAssertFalse(model.isPaused)
        let resumed = await memoryEventually { context.sleeper.pending == 1 }
        XCTAssertTrue(resumed)
        XCTAssertEqual(context.sleeper.requested.last, duration, "the new card's full time")

        context.clock.advance(by: duration / 2)
        model.pause()
        model.pause()
        XCTAssertTrue(model.isPaused, "pause() (sharing) never resumes")
        XCTAssertEqual(model.currentFraction(at: context.now), 0.5, accuracy: 0.0001)
        model.togglePause()
        await memoryEventually { context.sleeper.pending == 1 }
        XCTAssertEqual(context.sleeper.requested.last ?? 0, duration / 2, accuracy: 0.0001, "only the rest of the card's time")
    }

    func testTheClockStopsWhileTheAppIsInTheBackground() async {
        let context = MemoryTestContext()
        let model = YearStoryModel(groupID: MemoryIDs.group, year: year, dependencies: context.dependencies)
        await model.loadIfNeeded()
        await memoryEventually { context.sleeper.pending == 1 }
        let duration = Tokens.Durations.yearStoryCard
        context.clock.advance(by: duration / 4)
        model.setSuspended(true)
        XCTAssertFalse(model.clockRuns)
        XCTAssertFalse(model.isPaused, "not the user's pause: no play glyph")
        let stopped = await memoryEventually { context.sleeper.pending == 0 }
        XCTAssertTrue(stopped)
        context.clock.advance(by: duration * 10)
        XCTAssertEqual(model.currentFraction(at: context.now), 0.25, accuracy: 0.0001)
        model.setSuspended(false)
        XCTAssertTrue(model.clockRuns)
        await memoryEventually { context.sleeper.pending == 1 }
        XCTAssertEqual(context.sleeper.requested.last ?? 0, duration * 0.75, accuracy: 0.0001)
        XCTAssertEqual(model.index, 0)
    }

    func testSummaryDotColoursParseFromTheTokenText() {
        let selected = MemoryTokenColor.components(Tokens.Layouts.YearStorySummaryDots.selectedColor)
        XCTAssertEqual(selected, MemoryTokenColor.Components(red: 1, green: 1, blue: 1, opacity: 1))
        let others = MemoryTokenColor.components(Tokens.Layouts.YearStorySummaryDots.unselectedColor)
        XCTAssertEqual(others?.red ?? 0, 0.4, accuracy: 0.001)
        XCTAssertEqual(others?.green ?? 0, 0.4, accuracy: 0.001)
        XCTAssertEqual(others?.blue ?? 0, 0.4, accuracy: 0.001)
        XCTAssertEqual(others?.opacity, 1)
        let translucent = MemoryTokenColor.components("#00000080")
        XCTAssertEqual(translucent?.red, 0)
        XCTAssertEqual(translucent?.opacity ?? 0, 128.0 / 255.0, accuracy: 0.0001)
        XCTAssertNil(MemoryTokenColor.components("white"))
        XCTAssertNil(MemoryTokenColor.components("#12345"))
        XCTAssertGreaterThan(Tokens.Layouts.YearStorySummaryDots.pitch, Tokens.Layouts.YearStorySummaryDots.diameter, "dots never touch")
    }

    func testPreloadsTheNextCardsImages() async {
        let context = MemoryTestContext()
        let model = YearStoryModel(groupID: MemoryIDs.group, year: year, dependencies: context.dependencies)
        await model.loadIfNeeded()
        while model.currentCard != .mostReactedSetup { model.next() }
        let requested = await memoryEventually { context.images.requested.count >= 3 }
        XCTAssertTrue(requested, "the photo cards after the setup card are loaded before the tap")
    }

    func testBlockedPostsAreSkippedAndDeletionsDropCards() async {
        let context = MemoryTestContext { state in
            // Post 3 is hidden from the caller (block): RLS drops it.
            state.posts.removeAll { $0.post.id == MemoryIDs.post(3) }
        }
        let model = YearStoryModel(groupID: MemoryIDs.group, year: year, dependencies: context.dependencies)
        await model.loadIfNeeded()
        let reacted = model.cards.filter { if case .mostReacted = $0 { return true } else { return false } }
        XCTAssertEqual(reacted.count, 2)
        model.removePost(MemoryIDs.post(1))
        XCTAssertFalse(model.cards.contains { if case .togetherDay = $0 { return true } else { return false } }, "the collage with that photo goes")
        XCTAssertFalse(model.cards.contains(.togetherSetup))
        model.removePost(MemoryIDs.post(2))
        XCTAssertFalse(model.cards.contains(.mostReactedSetup), "an empty list loses its setup card")
        XCTAssertEqual(model.cards.last, .summary)
    }

    func testNotReadyAndOfflineStates() async {
        let pending = MemoryTestContext { state in
            state.yearStories = state.yearStories.map { story in
                var story = story
                story.status = .pending
                story.data = nil
                return story
            }
        }
        let pendingModel = YearStoryModel(groupID: MemoryIDs.group, year: year, dependencies: pending.dependencies)
        await pendingModel.loadIfNeeded()
        XCTAssertEqual(pendingModel.phase, .error)

        let offline = MemoryTestContext()
        offline.data.fail(.yearStory, with: .offline)
        let offlineModel = YearStoryModel(groupID: MemoryIDs.group, year: year, dependencies: offline.dependencies)
        await offlineModel.loadIfNeeded()
        XCTAssertEqual(offlineModel.phase, .offline)
    }

    func testEntryShowsOnlyWhileThisYearsStoryIsReady() async {
        let context = MemoryTestContext()
        let entry = YearStoryEntryModel(groupID: MemoryIDs.group, dependencies: context.dependencies)
        await entry.refresh()
        XCTAssertEqual(entry.year, year)
        XCTAssertEqual(entry.content?.title, Copy.yearStoryEntryTitle(year: String(year)))
        XCTAssertEqual(entry.content?.buttonTitle, Copy.yearStoryEntryButton)

        let none = MemoryTestContext { $0.yearStories = [] }
        let hidden = YearStoryEntryModel(groupID: MemoryIDs.group, dependencies: none.dependencies)
        await hidden.refresh()
        XCTAssertNil(hidden.content)
    }
}

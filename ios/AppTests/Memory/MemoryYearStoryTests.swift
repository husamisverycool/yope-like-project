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
        XCTAssertNil(model.cardDuration, "tap-only while duration.year.story.card is BLOCKED")
        XCTAssertEqual(model.currentFraction(at: Date()), 1, "the current segment is shown full")
        model.close()
        XCTAssertTrue(model.isFinished)
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

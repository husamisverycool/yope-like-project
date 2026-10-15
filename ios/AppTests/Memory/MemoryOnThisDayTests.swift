// onthisday — view-model tests (design/surfaces/onthisday.md).
@testable import App
import AppData
import DesignSystem
import XCTest

@MainActor
final class MemoryOnThisDayTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!

    func testDayRollsOverAtTheBoundaryHourInTheGroupZone() {
        let before = Date(timeIntervalSince1970: 1_792_040_340) // 2026-10-15T04:59:00Z
        let after = Date(timeIntervalSince1970: 1_792_040_400) // 2026-10-15T05:00:00Z
        XCTAssertEqual(OnThisDayCalendar.localDate(now: before, timeZone: utc).description, "2026-10-14")
        XCTAssertEqual(OnThisDayCalendar.localDate(now: after, timeZone: utc).description, "2026-10-15")
        // 05:00 in Lisbon (UTC+1 in October) is 04:00 UTC.
        let lisbon = TimeZone(identifier: "Europe/Lisbon")!
        let lisbonFive = Date(timeIntervalSince1970: 1_792_036_800) // 2026-10-15T04:00:00Z
        XCTAssertEqual(OnThisDayCalendar.localDate(now: lisbonFive, timeZone: lisbon).description, "2026-10-15")
    }

    func testRowsAreGroupedByYearsAgoAscendingKeepingAPIOrder() {
        let now = MemoryTestContext.referenceNow
        func row(_ n: Int, _ years: Int) -> OnThisDayItem {
            OnThisDayItem(postID: MemoryIDs.post(n), mediaID: MemoryFixtureIDs.media(n), authorID: MemoryIDs.me, createdAt: now, yearsAgo: years)
        }
        let years = OnThisDayCalendar.years([row(1, 3), row(2, 1), row(3, 3), row(4, 2)])
        XCTAssertEqual(years.map(\.yearsAgo), [1, 2, 3])
        XCTAssertEqual(years.last?.rows.map(\.postID), [MemoryIDs.post(1), MemoryIDs.post(3)])
    }

    func testLoadsTheDayNewestYearFirstWithOneScreenPerYear() async {
        let context = MemoryTestContext()
        let model = OnThisDayModel(groupID: MemoryIDs.group, dependencies: context.dependencies)
        XCTAssertEqual(model.phase, .idle)
        await model.loadIfNeeded()
        XCTAssertEqual(model.phase, .loaded)
        XCTAssertEqual(model.years.map(\.yearsAgo), [1, 3])
        XCTAssertEqual(model.years[0].photos.count, 1, "one photo → the single-photo layout")
        XCTAssertEqual(model.years[1].photos.map(\.id), [MemoryIDs.post(9), MemoryIDs.post(8), MemoryIDs.post(7)])
        XCTAssertEqual(model.index, 0)
        XCTAssertEqual(model.progress, 0.5, accuracy: 0.0001)
        XCTAssertEqual(model.bannerLabel(for: model.years[0]), Copy.onthisdayBannerYearsAgoOne)
        XCTAssertEqual(model.bannerLabel(for: model.years[1]), Copy.onthisdayBannerYearsAgoOther(count: "3"))
        let photo = model.years[0].photos[0]
        XCTAssertEqual(photo.authorName, "Bea")
        XCTAssertNotNil(photo.displayURL)
        XCTAssertNotNil(photo.thumbURL)
        XCTAssertEqual(photo.aspectRatio ?? 0, 0.75, accuracy: 0.0001)
        XCTAssertEqual(
            model.meta(for: photo),
            Copy.onthisdayMemoryMeta(
                weekday: MemoryFormat.metaWeekday(photo.createdAt, timeZone: utc),
                time: MemoryFormat.metaTime(photo.createdAt, timeZone: utc)
            )
        )
        XCTAssertEqual(context.data.calls(of: .onThisDay), 1)
        XCTAssertTrue(context.haptics.isEmpty, "the day plays no haptics")
    }

    func testTheNextYearsPhotosArePreloadedForTheCrossFade() async {
        let context = MemoryTestContext()
        let model = OnThisDayModel(groupID: MemoryIDs.group, dependencies: context.dependencies)
        await model.loadIfNeeded()
        await memoryEventually { !context.images.requested.isEmpty }
        XCTAssertTrue(context.images.requested.isEmpty, "nothing is decoded before the screen gives its pixel size")

        model.imagePixelSize = 2532
        model.preloadUpcoming()
        let olderYear = model.years[1].photos.compactMap(\.thumbURL)
        XCTAssertEqual(olderYear.count, 3)
        let preloaded = await memoryEventually { context.images.requested.count == olderYear.count }
        XCTAssertTrue(preloaded)
        XCTAssertEqual(context.images.requested, olderYear, "the next (older) year's grid thumbnails, in order")

        model.next()
        await memoryEventually { context.images.requested.count > olderYear.count }
        XCTAssertEqual(context.images.requested.count, olderYear.count, "the oldest year has no next year to preload")
    }

    func testMetaIsUppercasedAbbreviatedWeekdayAndShortTime() {
        let posix = Locale(identifier: "en_US_POSIX")
        let date = Date(timeIntervalSince1970: 1_760_567_640) // 2025-10-15T22:34:00Z, a Wednesday
        XCTAssertEqual(MemoryFormat.metaWeekday(date, timeZone: utc, locale: posix), "WED")
        XCTAssertEqual(MemoryFormat.spokenWeekday(date, timeZone: utc, locale: posix), "Wednesday")
        XCTAssertEqual(MemoryFormat.metaTime(date, timeZone: utc, locale: Locale(identifier: "en_US")).replacingOccurrences(of: "\u{202F}", with: " "), "10:34 PM")
    }

    func testTapZonesMoveBetweenYearsAndCloseAfterTheOldest() async {
        let context = MemoryTestContext()
        let model = OnThisDayModel(groupID: MemoryIDs.group, dependencies: context.dependencies)
        await model.loadIfNeeded()
        model.previous()
        XCTAssertEqual(model.index, 0, "left half on the newest year does nothing")
        model.next()
        XCTAssertEqual(model.index, 1)
        XCTAssertEqual(model.progress, 1, accuracy: 0.0001)
        XCTAssertFalse(model.isFinished)
        model.next()
        XCTAssertTrue(model.isFinished, "right half on the oldest year closes the day")
    }

    func testDeletedPhotoIsDroppedWithItsYearAndTheDayClosesWhenEmpty() async {
        let context = MemoryTestContext()
        let model = OnThisDayModel(groupID: MemoryIDs.group, dependencies: context.dependencies)
        await model.loadIfNeeded()
        model.next()
        // Broadcast path: `post_deleted` on the group's private topic.
        context.data.emitDeletion(postID: MemoryIDs.post(8), groupID: MemoryIDs.group)
        let removed = await memoryEventually { model.years.last?.photos.count == 2 }
        XCTAssertTrue(removed)
        XCTAssertEqual(model.index, 1, "the year in view stays in view")
        model.removePost(MemoryIDs.post(6))
        XCTAssertEqual(model.years.map(\.yearsAgo), [3])
        XCTAssertEqual(model.index, 0)
        model.removePost(MemoryIDs.post(9))
        model.removePost(MemoryIDs.post(7))
        XCTAssertTrue(model.years.isEmpty)
        XCTAssertTrue(model.isFinished)
        model.stopListening()
    }

    func testErrorAndOfflineStates() async {
        let offline = MemoryTestContext()
        offline.data.fail(.onThisDay, with: .offline)
        let offlineModel = OnThisDayModel(groupID: MemoryIDs.group, dependencies: offline.dependencies)
        await offlineModel.loadIfNeeded()
        XCTAssertEqual(offlineModel.phase, .offline)

        let failing = MemoryTestContext()
        failing.data.fail(.onThisDay, with: .api(.notGroupMember))
        let errorModel = OnThisDayModel(groupID: MemoryIDs.group, dependencies: failing.dependencies)
        await errorModel.loadIfNeeded()
        XCTAssertEqual(errorModel.phase, .error)
        failing.data.fail(.onThisDay, with: nil)
        await errorModel.retry()
        XCTAssertEqual(errorModel.phase, .loaded)

        let unconfigured = OnThisDayModel(groupID: MemoryIDs.group, dependencies: MemoryTestContext().unconfigured)
        await unconfigured.loadIfNeeded()
        XCTAssertEqual(unconfigured.phase, .error)
    }

    func testCachedDayShowsAtOnceAndStaysWhenTheRefreshIsOffline() async {
        let context = MemoryTestContext()
        let first = OnThisDayModel(groupID: MemoryIDs.group, dependencies: context.dependencies)
        await first.loadIfNeeded()
        context.data.fail(.onThisDay, with: .offline)
        let second = OnThisDayModel(groupID: MemoryIDs.group, dependencies: context.dependencies)
        await second.loadIfNeeded()
        XCTAssertEqual(second.phase, .loaded, "cached content first; no offline screen over it")
        XCTAssertEqual(second.years.map(\.yearsAgo), [1, 3])
    }

    func testCacheDropsADeletedPhoto() async {
        let context = MemoryTestContext()
        let first = OnThisDayModel(groupID: MemoryIDs.group, dependencies: context.dependencies)
        await first.loadIfNeeded()
        first.removePost(MemoryIDs.post(6))
        context.data.fail(.onThisDay, with: .offline)
        let second = OnThisDayModel(groupID: MemoryIDs.group, dependencies: context.dependencies)
        await second.loadIfNeeded()
        XCTAssertEqual(second.phase, .offline, "an entry showing a deleted photo is not served from the cache")
    }

    func testEntryShowsTitleAndNewestLabelOnlyWhenTheDayHasRows() async {
        let context = MemoryTestContext()
        let entry = OnThisDayEntryModel(groupID: MemoryIDs.group, dependencies: context.dependencies)
        await entry.refresh()
        XCTAssertEqual(entry.content?.title, Copy.onthisdayEntryTitle(group: "Sunday dinners"))
        XCTAssertEqual(entry.content?.subtitle, Copy.onthisdayBannerYearsAgoOne)

        let empty = MemoryTestContext { $0.onThisDay = [] }
        let hidden = OnThisDayEntryModel(groupID: MemoryIDs.group, dependencies: empty.dependencies)
        await hidden.refresh()
        XCTAssertNil(hidden.content, "empty: the entry is not shown")
    }
}

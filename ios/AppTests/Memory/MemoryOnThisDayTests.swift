// onthisday — view-model tests (design/surfaces/onthisday.md: Retro Rewind — one memory at a time, the dial, play / pause,
// shuffle, share / save / report / delete, the feature intro, the group-screen entry).
@testable import App
import AppData
import AppModels
import AppServices
import DesignSystem
import XCTest

@MainActor
final class MemoryOnThisDayTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!

    private func makeModel(_ context: MemoryTestContext, savePhoto: @escaping @Sendable (Data) async throws -> Void = { _ in }, random: @escaping (Int) -> Int = { _ in 0 }) -> OnThisDayModel {
        OnThisDayModel(groupID: MemoryIDs.group, dependencies: context.dependencies, savePhoto: savePhoto, randomIndex: random)
    }

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

    func testLoadsTheDayNewestFirstOneMemoryPerSlot() async {
        let context = MemoryTestContext()
        let model = makeModel(context)
        XCTAssertEqual(model.phase, .idle)
        await model.loadIfNeeded()
        XCTAssertEqual(model.phase, .loaded)
        XCTAssertEqual(model.memories.map(\.id), [MemoryIDs.post(6), MemoryIDs.post(9), MemoryIDs.post(8), MemoryIDs.post(7)], "the API's order is the dial's")
        XCTAssertEqual(model.index, 0)
        XCTAssertEqual(model.dialSlot, 0, "the indicator starts on slot 0")
        XCTAssertEqual(model.mode, .day)
        let first = try? XCTUnwrap(model.current)
        XCTAssertEqual(first?.authorName, "Bea")
        XCTAssertNotNil(first?.displayURL)
        XCTAssertNotNil(first?.originalURL)
        XCTAssertEqual(model.title, MemoryFormat.memoryDate(first?.createdAt ?? Date(), timeZone: utc))
        XCTAssertEqual(model.subtitle, Copy.onthisdaySubtitleDay(name: "Bea"))
        XCTAssertEqual(model.dialValue, Copy.onthisdayA11yDialValue(position: "1", total: "4"))
        XCTAssertEqual(model.photoLabel, Copy.onthisdayA11yPhoto(name: "Bea", date: model.title))
        XCTAssertEqual(model.memories.map(\.isMine), [false, false, true, false])
        XCTAssertEqual(model.groupName, "Sunday dinners")
        XCTAssertTrue(context.haptics.isEmpty, "opening plays no haptic")
    }

    func testMemoryDateIsTheMediumDate() {
        let date = Date(timeIntervalSince1970: 1_658_491_200) // 2022-07-22T12:00:00Z
        XCTAssertEqual(MemoryFormat.memoryDate(date, timeZone: utc, locale: Locale(identifier: "en_US")), "Jul 22, 2022")
        XCTAssertEqual(MemoryFormat.dayMonth(LocalDate(year: 2026, month: 7, day: 5)!, locale: Locale(identifier: "en_US")), "July 5")
    }

    func testTheFeatureIntroShowsOncePerAccount() async {
        let context = MemoryTestContext()
        let first = makeModel(context)
        await first.loadIfNeeded()
        XCTAssertTrue(first.showsIntro, "the first open shows the intro")
        first.dismissIntro()
        XCTAssertFalse(first.showsIntro)
        let second = makeModel(context)
        await second.loadIfNeeded()
        XCTAssertFalse(second.showsIntro, "never again on this account")
    }

    func testTheDialStepsOneMemoryPerSlotWithATickAndStopsAtTheEnds() async {
        let context = MemoryTestContext()
        let model = makeModel(context)
        await model.loadIfNeeded()
        XCTAssertFalse(model.previous(), "the first memory: counter-clockwise does nothing")
        XCTAssertTrue(model.next())
        XCTAssertTrue(model.next())
        XCTAssertTrue(model.next())
        XCTAssertEqual(model.index, 3)
        XCTAssertEqual(model.dialSlot, 3)
        XCTAssertFalse(model.next(), "the last memory: no wrap")
        XCTAssertEqual(context.haptics, Array(repeating: Tokens.Haptics.globalSelect, count: 3), "one tick per slot crossed")
        XCTAssertEqual(model.lastChange, .dial)
        XCTAssertEqual(model.subtitle, Copy.onthisdaySubtitleDay(name: "Caio"))
        XCTAssertTrue(model.previous())
        XCTAssertEqual(model.index, 2)
        XCTAssertTrue(model.current?.isMine == true)
    }

    func testPlayAdvancesEveryHoldWithATickAndStopsAfterTheLast() async {
        let context = MemoryTestContext()
        let model = makeModel(context)
        await model.loadIfNeeded()
        model.togglePlay()
        XCTAssertTrue(model.isPlaying)
        let slept = await memoryEventually { context.sleeper.requested == [Tokens.Durations.onthisdayPlayHold] }
        XCTAssertTrue(slept, "each memory stays for duration.onthisday.playHold")
        for expected in 1...3 {
            await memoryEventually { context.sleeper.pending == 1 }
            context.sleeper.fire()
            let moved = await memoryEventually { model.index == expected }
            XCTAssertTrue(moved)
            XCTAssertEqual(model.lastChange, .play)
        }
        // The last memory keeps its time, then play stops (the play glyph again).
        await memoryEventually { context.sleeper.pending == 1 }
        context.sleeper.fire()
        let stopped = await memoryEventually { !model.isPlaying }
        XCTAssertTrue(stopped)
        XCTAssertEqual(model.index, 3)
        XCTAssertEqual(context.haptics.filter { $0 == Tokens.Haptics.globalSelect }.count, 3, "one tick per automatic step")

        // From the last memory, play starts again at the first.
        model.togglePlay()
        XCTAssertEqual(model.index, 0)
        XCTAssertTrue(model.isPlaying)
        model.togglePlay()
        XCTAssertFalse(model.isPlaying, "the centre pauses")
        model.stopListening()
    }

    func testShuffleShowsRandomMemoriesFromTheGroupsHistoryAndGoesBackThroughThem() async {
        let context = MemoryTestContext()
        let model = makeModel(context)
        await model.loadIfNeeded()
        await model.shuffle()
        XCTAssertEqual(model.mode, .shuffle)
        // The newest week (Monday 12 October) holds posts 2 and 1, chronological; the first index of each is picked.
        XCTAssertEqual(model.current?.id, MemoryIDs.post(2))
        XCTAssertEqual(model.subtitle, Copy.onthisdaySubtitleShuffle(name: "Bea"))
        XCTAssertEqual(model.index, 0)
        XCTAssertTrue(model.next(), "a new random pick")
        let picked = await memoryEventually { model.picks.count == 2 }
        XCTAssertTrue(picked)
        XCTAssertEqual(model.current?.id, MemoryIDs.post(1), "never the same memory twice")
        XCTAssertTrue(model.previous())
        XCTAssertEqual(model.current?.id, MemoryIDs.post(2), "back through the picks already shown")
        XCTAssertEqual(context.data.calls(of: .historyWeeks), 1, "the history is read once (pages of 52 until a short page)")
        XCTAssertEqual(context.haptics.filter { $0 == Tokens.Haptics.globalSelect }.count, 3)
    }

    /// Moves to the fixture's own memory (index 2, posted by the signed-in member) and forgets the two dial ticks.
    private func showOwnMemory(_ model: OnThisDayModel, _ context: MemoryTestContext) {
        model.next()
        model.next()
        XCTAssertTrue(model.current?.isMine == true)
        context.clearHaptics()
    }

    func testSaveDownloadsTheOriginalAndConfirms() async {
        let saved = SavedData()
        let context = MemoryTestContext()
        let model = makeModel(context, savePhoto: { await saved.append($0) })
        await model.loadIfNeeded()
        showOwnMemory(model, context)
        await model.save()
        let count = await saved.count
        XCTAssertEqual(count, 1)
        XCTAssertEqual(context.data.calls(of: .downloadData), 1, "the original, downloaded")
        XCTAssertEqual(context.lastToast, Copy.onthisdayToastSaved)
        XCTAssertEqual(context.haptics, [Tokens.Haptics.globalSuccess])

        let denied = MemoryTestContext()
        let deniedModel = makeModel(denied, savePhoto: { _ in throw PhotoLibraryService.LibraryError.notAuthorized(.denied) })
        await deniedModel.loadIfNeeded()
        showOwnMemory(deniedModel, denied)
        await deniedModel.save()
        XCTAssertTrue(deniedModel.showsSaveDenied, "add-only access denied: the native alert that opens Settings")
        XCTAssertEqual(denied.haptics, [Tokens.Haptics.globalError])

        struct Broken: Error {}
        let failing = MemoryTestContext()
        let failingModel = makeModel(failing, savePhoto: { _ in throw Broken() })
        await failingModel.loadIfNeeded()
        showOwnMemory(failingModel, failing)
        await failingModel.save()
        XCTAssertFalse(failingModel.showsSaveDenied)
        XCTAssertEqual(failing.lastToast, Copy.onthisdaySaveFailed)
    }

    /// Owner decision 12: save and share take a photo out of the app, so only your own memory offers them.
    func testOnlyYourOwnMemoryCanBeSavedOrShared() async {
        let saved = SavedData()
        let context = MemoryTestContext()
        let model = makeModel(context, savePhoto: { await saved.append($0) })
        await model.loadIfNeeded()
        XCTAssertFalse(model.current?.isMine == true, "the newest memory is Bea's")
        XCTAssertFalse(model.canExport)
        XCTAssertNil(model.shareItem, "no share sheet for someone else's photo")
        await model.save()
        let none = await saved.count
        XCTAssertEqual(none, 0, "someone else's photo is never saved")
        XCTAssertEqual(context.data.calls(of: .downloadData), 0)
        XCTAssertNil(context.lastToast)
        showOwnMemory(model, context)
        XCTAssertTrue(model.canExport)
        XCTAssertNotNil(model.shareItem, "your own memory: the share sheet with its original")
        model.next()
        XCTAssertFalse(model.canExport, "the next memory is someone else's again")
        XCTAssertNil(model.shareItem)
    }

    func testReportOpensSafetyReportForSomeoneElsesMemoryOnly() async {
        let context = MemoryTestContext()
        let model = makeModel(context)
        await model.loadIfNeeded()
        model.report()
        XCTAssertEqual(context.reports.count, 1)
        XCTAssertEqual(context.reports.first?.kind, .post)
        XCTAssertEqual(context.reports.first?.id, MemoryIDs.post(6).rawValue)
        XCTAssertEqual(context.reports.first?.person?.firstName, "Bea")
        model.next()
        model.next()
        model.requestDelete()
        XCTAssertNotNil(model.deleteCandidate, "your own memory: delete, not report")
        model.report()
        XCTAssertEqual(context.reports.count, 1)
    }

    func testDeletingYourMemoryAsksThenRemovesItFromTheDial() async {
        let context = MemoryTestContext()
        let model = makeModel(context)
        await model.loadIfNeeded()
        model.requestDelete()
        XCTAssertNil(model.deleteCandidate, "someone else's memory cannot be deleted")
        model.next()
        model.next()
        model.requestDelete()
        XCTAssertEqual(model.deleteCandidate?.id, MemoryIDs.post(8))
        context.clearHaptics()
        await model.confirmDelete()
        XCTAssertNil(model.deleteCandidate)
        XCTAssertEqual(context.haptics.first, Tokens.Haptics.globalWarning)
        XCTAssertEqual(model.memories.map(\.id), [MemoryIDs.post(6), MemoryIDs.post(9), MemoryIDs.post(7)])
        XCTAssertEqual(model.current?.id, MemoryIDs.post(7), "the next memory shows")
        XCTAssertEqual(context.lastToast, Copy.onthisdayToastDeleted)
        XCTAssertEqual(context.data.calls(of: .deletePost), 1)
        model.stopListening()
    }

    func testDeletedMemoriesLeaveTheDialAndTheEmptyBlockShowsWhenNoneRemain() async {
        let context = MemoryTestContext()
        let model = makeModel(context)
        await model.loadIfNeeded()
        model.next()
        // Broadcast path: `post_deleted` on the group's private topic.
        context.data.emitDeletion(postID: MemoryIDs.post(9), groupID: MemoryIDs.group)
        let removed = await memoryEventually { model.memories.count == 3 }
        XCTAssertTrue(removed)
        XCTAssertEqual(model.current?.id, MemoryIDs.post(8), "the memory in view was dropped: the next one shows")
        model.removePost(MemoryIDs.post(8))
        model.removePost(MemoryIDs.post(7))
        XCTAssertEqual(model.current?.id, MemoryIDs.post(6), "the previous one when it was the last")
        model.removePost(MemoryIDs.post(6))
        XCTAssertEqual(model.phase, .empty)
        model.stopListening()
    }

    func testErrorAndOfflineStates() async {
        let offline = MemoryTestContext()
        offline.data.fail(.onThisDay, with: .offline)
        let offlineModel = makeModel(offline)
        await offlineModel.loadIfNeeded()
        XCTAssertEqual(offlineModel.phase, .offline)

        let failing = MemoryTestContext()
        failing.data.fail(.onThisDay, with: .api(.notGroupMember))
        let errorModel = makeModel(failing)
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
        let first = makeModel(context)
        await first.loadIfNeeded()
        context.data.fail(.onThisDay, with: .offline)
        let second = makeModel(context)
        await second.loadIfNeeded()
        XCTAssertEqual(second.phase, .loaded, "cached content first; no offline screen over it")
        XCTAssertEqual(second.memories.count, 4)
    }

    func testTheNeighboursArePreloadedForTheCrossFade() async {
        let context = MemoryTestContext()
        let model = makeModel(context)
        await model.loadIfNeeded()
        model.imagePixelSize = 2532
        model.preloadNeighbours()
        let next = model.memories[1].displayURL
        let preloaded = await memoryEventually { context.images.requested.contains { $0 == next } }
        XCTAssertTrue(preloaded, "the next memory is decoded before the dial reaches it")
    }

    func testEntryShowsTheCardOnlyWhenTheDayHasRowsAndPushesThePage() async {
        let context = MemoryTestContext()
        let entry = OnThisDayEntryModel(groupID: MemoryIDs.group, dependencies: context.dependencies)
        await entry.refresh()
        XCTAssertEqual(entry.content?.title, Copy.onthisdayEntryTitle)
        let today = OnThisDayCalendar.localDate(now: context.now, timeZone: utc)
        XCTAssertEqual(entry.content?.subtitle, Copy.onthisdayEntrySubtitle(date: MemoryFormat.dayMonth(today)))
        XCTAssertEqual(entry.content?.buttonTitle, Copy.onthisdayEntryButton)
        XCTAssertEqual(entry.content?.icon, Tokens.Icons.globalRewind)
        XCTAssertNotNil(entry.content?.photoPath, "the newest memory's photo for the feed card")
        entry.open()
        XCTAssertEqual(context.openedOnThisDay, [MemoryIDs.group.rawValue], "pushed on the group's stack")

        let empty = MemoryTestContext { $0.onThisDay = [] }
        let hidden = OnThisDayEntryModel(groupID: MemoryIDs.group, dependencies: empty.dependencies)
        await hidden.refresh()
        XCTAssertNil(hidden.content, "empty: the entry is not shown")
    }
}

/// Collects saved photo data across the `@Sendable` save closure.
private actor SavedData {
    private(set) var items: [Data] = []
    var count: Int { items.count }

    func append(_ data: Data) {
        items.append(data)
    }
}

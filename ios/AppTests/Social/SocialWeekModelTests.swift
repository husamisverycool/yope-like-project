// week.recap / week.edit / week.history view models (design/surfaces/week.*.md).
@testable import App
import AppData
import AppModels
import Foundation
import XCTest

@MainActor
final class SocialWeekModelTests: XCTestCase {
    // MARK: week.recap list

    func testRecapListShowsReadyAndPendingRecapsNewestFirstWithCovers() async {
        let model = WeekRecapListModel(groupID: SocialDemo.groupID, data: SocialDemo.makeData())
        XCTAssertFalse(model.showsLoading, "nothing drawn before the cache was looked at")
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.recaps.map(\.id), [SocialDemo.pendingRecapID, SocialDemo.recapID], "newest week first")
        XCTAssertEqual(model.recaps.map(\.status), [.pending, .ready])
        let ready = model.recaps[1]
        XCTAssertEqual(model.cover(of: ready)?.id, SocialDemo.p6, "the cover is the recap's first item")
        XCTAssertEqual(model.weekNumber(of: ready), 41)
    }

    func testRecapListCoverFallsBackToTheNextVisibleItem() async {
        let data = SocialDemo.makeData()
        data.update { $0.posts.removeAll { $0.id == SocialDemo.p6 } }
        let model = WeekRecapListModel(groupID: SocialDemo.groupID, data: data)
        await model.load()
        XCTAssertEqual(model.recaps.first { $0.id == SocialDemo.recapID }.flatMap(model.cover)?.id, SocialDemo.p5)
    }

    func testRecapListEmptyErrorAndOffline() async {
        let empty = WeekRecapListModel(groupID: SocialDemo.groupID, data: SocialDemo.makeEmptyData())
        await empty.load()
        XCTAssertEqual(empty.phase, .empty)

        let failingData = SocialDemo.makeData()
        failingData.update { $0.mode = .failing }
        let failing = WeekRecapListModel(groupID: SocialDemo.groupID, data: failingData)
        await failing.load()
        XCTAssertEqual(failing.phase, .failed)
        failingData.update { $0.mode = .normal }
        await failing.retry()
        XCTAssertEqual(failing.phase, .ready)

        let offlineData = SocialDemo.makeData()
        offlineData.update { $0.mode = .offline }
        let offline = WeekRecapListModel(groupID: SocialDemo.groupID, data: offlineData)
        await offline.load()
        XCTAssertEqual(offline.phase, .offline)
        XCTAssertTrue(offline.isOffline)
    }

    // MARK: week.recap preview

    func testReadyRecapShowsItemsAndTheWholeWeek() async {
        let model = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: SocialDemo.makeData())
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.cardPosts.map(\.id), [SocialDemo.p6, SocialDemo.p5], "recap order")
        XCTAssertEqual(model.weekPosts.map(\.id), [SocialDemo.p5, SocialDemo.p6], "chronological")
        XCTAssertEqual(model.cover?.id, SocialDemo.p6)
        XCTAssertEqual(model.weekNumber, 41)
        XCTAssertEqual(model.group?.name, "roommates")
        XCTAssertTrue(model.canEdit)
        XCTAssertNil(model.note, "no text: no note box")
    }

    func testTheNoteNamesItsLastEditor() async {
        let data = SocialDemo.makeData()
        data.update { state in
            if let index = state.recaps.firstIndex(where: { $0.id == SocialDemo.recapID }) {
                state.recaps[index].text = "  best week  "
                state.recaps[index].editedBy = SocialDemo.ana
            }
        }
        let model = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: data)
        await model.load()
        XCTAssertEqual(model.note?.text, "best week")
        XCTAssertEqual(model.note?.editor?.socialFirstName, "Ana")
    }

    func testPendingEmptyAndFailedRecaps() async {
        let pending = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.pendingRecapID, data: SocialDemo.makeData())
        await pending.load()
        XCTAssertEqual(pending.phase, .pending)
        XCTAssertFalse(pending.canEdit)
        XCTAssertNil(pending.editSeed)

        let missing = WeekRecapModel(groupID: SocialDemo.groupID, recapID: RecapID("00000000-0000-4000-8000-00000000d0ff"), data: SocialDemo.makeData())
        await missing.load()
        XCTAssertEqual(missing.phase, .empty)

        let offlineData = SocialDemo.makeData()
        offlineData.update { $0.mode = .offline }
        let offline = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: offlineData)
        await offline.load()
        XCTAssertEqual(offline.phase, .offline)

        let failingData = SocialDemo.makeData()
        failingData.update { $0.mode = .failing }
        let failing = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: failingData)
        await failing.load()
        XCTAssertEqual(failing.phase, .failed)
    }

    func testReopenedRecapShowsAtOnceThenRefreshesInPlace() async {
        let data = SocialDemo.makeData()
        let recap = data.read { $0.recaps.first { $0.id == SocialDemo.recapID } }
        data.update { state in
            state.cachedRecaps[SocialDemo.recapID] = recap
            state.cachedFeeds[SocialDemo.groupID] = state.posts.filter { $0.post.groupID == SocialDemo.groupID }
            state.holds.insert("recap")
        }
        let model = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: data)
        let task = Task { await model.load() }
        let shown = await socialEventually { model.phase == .ready }
        XCTAssertTrue(shown, "the recap fetched earlier shows while the server is asked")
        XCTAssertFalse(model.showsLoading, "no indicator over cached content")
        XCTAssertEqual(model.cardPosts.map(\.id), [SocialDemo.p6, SocialDemo.p5])

        data.update { $0.holds.remove("recap") }
        await task.value
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.weekPosts.map(\.id), [SocialDemo.p5, SocialDemo.p6])

        // Offline after the cached copy showed: the copy stays.
        let offline = SocialDemo.makeData()
        offline.update { state in
            state.cachedRecaps[SocialDemo.recapID] = recap
            state.cachedFeeds[SocialDemo.groupID] = state.posts.filter { $0.post.groupID == SocialDemo.groupID }
            state.mode = .offline
        }
        let fromCache = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: offline)
        await fromCache.load()
        XCTAssertEqual(fromCache.phase, .ready)
        XCTAssertTrue(fromCache.isOffline)
    }

    func testEditorOpensOnWhatTheRecapShows() async {
        let data = SocialDemo.makeData()
        let recap = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: data)
        await recap.load()
        let editor = WeekEditModel(groupID: SocialDemo.groupID, mode: .recap(SocialDemo.recapID), data: data, seed: recap.editSeed)
        XCTAssertEqual(editor.phase, .ready, "no loading state when opened from the recap")
        XCTAssertEqual(editor.gridPosts.map(\.id), [SocialDemo.p5, SocialDemo.p6], "the week's photos in time order")
        XCTAssertEqual(editor.chosen, [SocialDemo.p6, SocialDemo.p5], "the strip in recap order")
        XCTAssertFalse(editor.hasChanges)
        XCTAssertEqual(data.read { $0.calls.filter { $0 == "recap" }.count }, 1, "the editor fetched nothing")

        let album = WeekEditModel(groupID: SocialDemo.groupID, mode: .recapAlbum(SocialDemo.recapID), data: data, seed: recap.editSeed)
        XCTAssertTrue(album.isAlbumOnly)
        XCTAssertTrue(album.isAlbumSheetPresented, "Save as Album opens the album sheet")
        XCTAssertEqual(album.checkedInOrder, [SocialDemo.p6, SocialDemo.p5], "with the recap's photos selected")
    }

    func testDeletionLeavesTheCard() async {
        let model = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: SocialDemo.makeData())
        await model.load()
        model.handle(.postDeleted(postID: SocialDemo.p6, mediaID: nil))
        XCTAssertEqual(model.cardPosts.map(\.id), [SocialDemo.p5])
        XCTAssertEqual(model.weekPosts.map(\.id), [SocialDemo.p5])
        XCTAssertEqual(model.cover?.id, SocialDemo.p5, "the next item becomes the cover")
    }

    // MARK: week.edit

    func testEditStripAppendsCheckedPhotosAndSavesTheStripOrder() async {
        let data = SocialDemo.makeData()
        let extra = PostID("00000000-0000-4000-8000-00000000c007")
        data.update { $0.posts.append(SocialDemo.post(extra, by: SocialDemo.ben, at: SocialDemo.monday.addingTimeInterval(-3 * SocialDemo.day))) }
        let model = WeekEditModel(groupID: SocialDemo.groupID, mode: .recap(SocialDemo.recapID), data: data)
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.gridPosts.map(\.id), [SocialDemo.p5, SocialDemo.p6, extra], "the grid in time order")
        XCTAssertEqual(model.chosen, [SocialDemo.p6, SocialDemo.p5])
        XCTAssertEqual(model.weekNumber, 41)

        model.toggle(SocialDemo.p6)
        model.toggle(extra)
        XCTAssertEqual(model.signals.feedback?.kind, .select)
        XCTAssertEqual(model.checkedInOrder, [SocialDemo.p5, extra], "a checked photo joins the strip's end")
        XCTAssertEqual(model.chosenPosts.map(\.id), [SocialDemo.p5, extra])
        XCTAssertTrue(model.isChecked(extra))
        XCTAssertFalse(model.isChecked(SocialDemo.p6))
        XCTAssertTrue(model.hasChanges)
        model.text = "best week"
        await model.save()
        XCTAssertTrue(model.isFinished)
        XCTAssertFalse(model.hasChanges, "saved")
        XCTAssertEqual(data.read { $0.recaps.first { $0.id == SocialDemo.recapID } }?.items, [SocialDemo.p5, extra])
        XCTAssertEqual(data.read { $0.recaps.first { $0.id == SocialDemo.recapID } }?.text, "best week")
        XCTAssertEqual(model.signals.notice?.notice, .recapSaved)
    }

    func testReorderMovesWithinTheStrip() async {
        let model = WeekEditModel(groupID: SocialDemo.groupID, mode: .recap(SocialDemo.recapID), data: SocialDemo.makeData())
        await model.load()
        XCTAssertTrue(model.move(SocialDemo.p5, to: SocialDemo.p6))
        XCTAssertEqual(model.checkedInOrder, [SocialDemo.p5, SocialDemo.p6])
        XCTAssertTrue(model.hasChanges, "a new order is a change")
        XCTAssertTrue(model.move(SocialDemo.p5, by: 1), "accessibility: move later")
        XCTAssertEqual(model.checkedInOrder, [SocialDemo.p6, SocialDemo.p5])
        XCTAssertFalse(model.hasChanges, "back to the saved order")
        XCTAssertFalse(model.move(SocialDemo.p5, by: 1), "nothing after the last tile")
        model.toggle(SocialDemo.p6)
        XCTAssertFalse(model.move(SocialDemo.p5, to: SocialDemo.p6), "only tiles in the strip move")
    }

    func testTextAloneIsAChange() async {
        let model = WeekEditModel(groupID: SocialDemo.groupID, mode: .recap(SocialDemo.recapID), data: SocialDemo.makeData())
        await model.load()
        XCTAssertFalse(model.hasChanges)
        model.text = "hello"
        XCTAssertTrue(model.hasChanges, "Cancel asks first")
    }

    func testSaveFailureKeepsTheSelection() async {
        let data = SocialDemo.makeData()
        let model = WeekEditModel(groupID: SocialDemo.groupID, mode: .recap(SocialDemo.recapID), data: data)
        await model.load()
        model.toggle(SocialDemo.p6)
        data.update { $0.failOnce.insert("updateRecap") }
        await model.save()
        XCTAssertFalse(model.isFinished)
        XCTAssertEqual(model.saveError, .other)
        XCTAssertEqual(model.checkedInOrder, [SocialDemo.p5])
        XCTAssertEqual(model.signals.feedback?.kind, .failed)
    }

    func testPendingRecapIsNotEditable() async {
        let model = WeekEditModel(groupID: SocialDemo.groupID, mode: .recap(SocialDemo.pendingRecapID), data: SocialDemo.makeData())
        await model.load()
        XCTAssertEqual(model.phase, .notReady)
    }

    func testAlbumNeedsANameAndAPhoto() async {
        let data = SocialDemo.makeData()
        let model = WeekEditModel(groupID: SocialDemo.groupID, mode: .recap(SocialDemo.recapID), data: data)
        await model.load()
        XCTAssertFalse(model.isAlbumOnly)
        XCTAssertFalse(model.isAlbumSheetPresented)
        model.isAlbumSheetPresented = true
        XCTAssertFalse(model.canSaveAlbum)
        await model.saveAlbum()
        XCTAssertTrue(model.albumNameMissing, "empty name on submit: the line")
        model.albumName = "  picnic  "
        model.albumNameChanged()
        XCTAssertFalse(model.albumNameMissing)
        XCTAssertTrue(model.canSaveAlbum)
        await model.saveAlbum()
        XCTAssertEqual(model.savedAlbum?.name, "picnic")
        XCTAssertFalse(model.isAlbumSheetPresented)
        XCTAssertEqual(data.read { $0.albums.last?.postIDs }, [SocialDemo.p6, SocialDemo.p5])
        XCTAssertEqual(model.signals.notice?.notice, .albumSaved)
        XCTAssertFalse(model.isFinished, "the editor stays open after an album save from the editor")

        model.toggle(SocialDemo.p6)
        model.toggle(SocialDemo.p5)
        model.albumName = "nothing"
        XCTAssertFalse(model.canSaveAlbum, "no photo checked")
    }

    func testAlbumSaveFailureShowsItsAlertAndKeepsTheSheet() async {
        let data = SocialDemo.makeData()
        let model = WeekEditModel(groupID: SocialDemo.groupID, mode: .album(weekStart: SocialDemo.thisWeek), data: data)
        await model.load()
        model.albumName = "this week"
        data.update { $0.failOnce.insert("saveAlbum") }
        await model.saveAlbum()
        XCTAssertNotNil(model.albumError)
        XCTAssertTrue(model.isAlbumSheetPresented)
        XCTAssertFalse(model.isFinished)
        model.dismissAlbumError()
        XCTAssertNil(model.albumError)
    }

    func testAlbumModeFromHistoryChecksTheWeek() async {
        let data = SocialDemo.makeData()
        let model = WeekEditModel(groupID: SocialDemo.groupID, mode: .album(weekStart: SocialDemo.thisWeek), data: data)
        XCTAssertTrue(model.isAlbumSheetPresented)
        await model.load()
        XCTAssertEqual(model.gridPosts.map(\.id), [SocialDemo.p1, SocialDemo.p2, SocialDemo.p3, SocialDemo.p4])
        XCTAssertEqual(model.checkedInOrder.count, 4)
        model.albumName = "this week"
        await model.saveAlbum()
        XCTAssertTrue(model.isFinished)
    }

    // MARK: week.history

    private func historyModel(_ data: FakeSocialData = SocialDemo.makeData()) -> WeekHistoryModel {
        WeekHistoryModel(groupID: SocialDemo.groupID, data: data, now: { SocialDemo.monday.addingTimeInterval(4 * SocialDemo.day) })
    }

    func testHistoryWeeksNewestFirstWithRecapsAndISOWeekNumbers() async {
        let model = historyModel()
        await model.load()
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.line)
        XCTAssertEqual(model.weeks.map(\.weekStart), [SocialDemo.thisWeek, SocialDemo.lastWeek])
        XCTAssertTrue(model.weeks[0].isCurrent)
        XCTAssertEqual(model.weeks[0].postIDs, [SocialDemo.p1, SocialDemo.p2, SocialDemo.p3, SocialDemo.p4])
        XCTAssertEqual(model.readyRecaps[SocialDemo.lastWeek], SocialDemo.recapID)
        XCTAssertNil(model.readyRecaps[SocialDemo.thisWeek], "pending recaps are not offered")
        XCTAssertEqual(SocialCalendar.weekNumber(of: SocialDemo.thisWeek, in: model.timeZone), 42)
        XCTAssertEqual(model.currentWeekNumber, 42)
        XCTAssertEqual(model.weekNumber(of: model.weeks[1]), 41)
        XCTAssertEqual(SocialCalendar.weekNumber(of: LocalDate(year: 2026, month: 12, day: 28)!, in: model.timeZone), 53)
        XCTAssertEqual(SocialCalendar.weekNumber(of: LocalDate(year: 2027, month: 1, day: 4)!, in: model.timeZone), 1)
    }

    func testCurrentWeekListsItsDaysWithoutAPhoto() async {
        let model = historyModel()
        await model.load()
        let current = model.weeks[0]
        XCTAssertEqual(model.emptyDays(of: current), [
            LocalDate(year: 2026, month: 10, day: 16)!, LocalDate(year: 2026, month: 10, day: 17)!, LocalDate(year: 2026, month: 10, day: 18)!,
        ], "Mon–Thu have photos")
        XCTAssertEqual(model.emptyDays(of: model.weeks[1]), [], "past weeks have no empty-day tiles")

        let empty = historyModel(SocialDemo.makeEmptyData())
        await empty.load()
        XCTAssertEqual(empty.emptyDays(of: empty.weeks[0])?.count, 7)

        let unloaded = historyModel()
        XCTAssertNil(unloaded.emptyDays(of: WeekHistoryModel.Week(weekStart: SocialDemo.thisWeek, postIDs: [SocialDemo.p1], isCurrent: true)),
                     "no empty-day tiles before the week's photos are known")
    }

    func testEmptyGroupSynthesisesTheCurrentWeek() async {
        let model = historyModel(SocialDemo.makeEmptyData())
        await model.load()
        XCTAssertEqual(model.line, .empty)
        XCTAssertEqual(model.weeks.map(\.weekStart), [SocialDemo.thisWeek])
        XCTAssertTrue(model.weeks[0].postIDs.isEmpty)
    }

    func testHistoryPagesByEightWeeks() async {
        let data = SocialDemo.makeData()
        data.update { state in
            for week in 2...12 {
                let id = PostID("00000000-0000-4000-8000-0000002" + String(10_000 + week).suffix(5))
                state.posts.append(SocialDemo.post(id, by: SocialDemo.ana, at: SocialDemo.monday.addingTimeInterval(-Double(week) * 7 * SocialDemo.day)))
            }
        }
        let model = historyModel(data)
        await model.load()
        XCTAssertEqual(model.weeks.count, 8)
        XCTAssertTrue(model.hasMore)
        await model.loadMore()
        XCTAssertEqual(model.weeks.count, 13)
        XCTAssertFalse(model.hasMore)
        XCTAssertEqual(model.weeks.map(\.weekStart), model.weeks.map(\.weekStart).sorted(by: >))
    }

    func testHistoryRealtimeAndOffline() async {
        let data = SocialDemo.makeData()
        let model = historyModel(data)
        await model.load()
        await model.handle(.postDeleted(postID: SocialDemo.p5, mediaID: nil))
        await model.handle(.postDeleted(postID: SocialDemo.p6, mediaID: nil))
        XCTAssertEqual(model.weeks.map(\.weekStart), [SocialDemo.thisWeek], "an emptied past week disappears")

        let fresh = SocialDemo.post(PostID("00000000-0000-4000-8000-00000000c008"), by: SocialDemo.ben, at: SocialDemo.monday.addingTimeInterval(4 * SocialDemo.day))
        data.update { $0.posts.append(fresh) }
        await model.handle(.postInserted(fresh.post))
        XCTAssertEqual(model.weeks[0].postIDs.last, fresh.id)

        let cachedData = SocialDemo.makeData()
        cachedData.update { $0.cachedHistory[SocialDemo.groupID] = [HistoryWeek(weekStart: SocialDemo.lastWeek, postIDs: [SocialDemo.p5])] }
        let cachedFirst = historyModel(cachedData)
        await cachedFirst.load()
        XCTAssertEqual(cachedFirst.weeks.first?.postIDs.count, 4, "refreshed in place after the cached copy")

        let offlineData = SocialDemo.makeData()
        offlineData.update { state in
            state.mode = .offline
            state.cachedHistory[SocialDemo.groupID] = [HistoryWeek(weekStart: SocialDemo.lastWeek, postIDs: [SocialDemo.p5])]
        }
        let offline = historyModel(offlineData)
        await offline.load()
        XCTAssertEqual(offline.line, .offline)
        XCTAssertEqual(offline.weeks.map(\.weekStart), [SocialDemo.thisWeek, SocialDemo.lastWeek])

        let failingData = SocialDemo.makeData()
        failingData.update { $0.mode = .failing }
        let failing = historyModel(failingData)
        await failing.load()
        XCTAssertEqual(failing.line, .error)
    }

    func testHistoryIndicatorNeverCoversCachedWeeks() async {
        let held = SocialDemo.makeData()
        held.update { $0.holds.insert("historyWeeks") }
        let empty = historyModel(held)
        XCTAssertFalse(empty.showsLoading, "nothing drawn before the cache was looked at")
        let task = Task { await empty.load() }
        let shown = await socialEventually { empty.showsLoading }
        XCTAssertTrue(shown, "nothing cached: the indicator shows")
        task.cancel()

        let cached = SocialDemo.makeData()
        cached.update { state in
            state.holds.insert("historyWeeks")
            state.cachedHistory[SocialDemo.groupID] = [HistoryWeek(weekStart: SocialDemo.lastWeek, postIDs: [SocialDemo.p5])]
        }
        let fromCache = historyModel(cached)
        let second = Task { await fromCache.load() }
        let ready = await socialEventually { !fromCache.weeks.isEmpty }
        XCTAssertTrue(ready)
        XCTAssertFalse(fromCache.showsLoading)
        second.cancel()
        _ = await second.value

        // A server error after the cached weeks showed keeps them.
        let failing = SocialDemo.makeData()
        failing.update { state in
            state.mode = .failing
            state.cachedHistory[SocialDemo.groupID] = [HistoryWeek(weekStart: SocialDemo.lastWeek, postIDs: [SocialDemo.p5])]
        }
        let kept = historyModel(failing)
        await kept.load()
        XCTAssertEqual(kept.line, .error)
        XCTAssertTrue(kept.weeks.contains { $0.weekStart == SocialDemo.lastWeek })
    }
}

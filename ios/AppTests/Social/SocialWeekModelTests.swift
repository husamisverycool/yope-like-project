// week.recap / week.edit / week.history view models (design/surfaces/week.*.md).
@testable import App
import AppData
import AppModels
import Foundation
import XCTest

@MainActor
final class SocialWeekModelTests: XCTestCase {
    // MARK: week.recap

    func testReadyRecapShowsItemsAndTheWholeWeek() async {
        let model = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: SocialDemo.makeData())
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.cardPosts.map(\.id), [SocialDemo.p6, SocialDemo.p5], "recap order")
        XCTAssertEqual(model.weekPosts.map(\.id), [SocialDemo.p5, SocialDemo.p6], "chronological")
        XCTAssertTrue(model.canEdit)
    }

    func testPendingEmptyAndFailedRecaps() async {
        let pending = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.pendingRecapID, data: SocialDemo.makeData())
        await pending.load()
        XCTAssertEqual(pending.phase, .pending)
        XCTAssertFalse(pending.canEdit)

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

    func testSegmentAndDeletion() async {
        let model = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: SocialDemo.makeData())
        await model.load()
        model.setSegment(.pics)
        XCTAssertEqual(model.segment, .pics)
        XCTAssertEqual(model.signals.feedback?.kind, .select)
        model.setSegment(.recap, fromScroll: true)
        XCTAssertEqual(model.signals.feedback?.id, 1, "scrolling into a part plays no haptic")
        model.handle(.postDeleted(postID: SocialDemo.p5, mediaID: nil))
        XCTAssertEqual(model.cardPosts.map(\.id), [SocialDemo.p6])
        XCTAssertEqual(model.weekPosts.map(\.id), [SocialDemo.p6])
    }

    // MARK: week.edit

    func testEditGridPutsRecapItemsFirstAndSavesCheckedInOrder() async {
        let data = SocialDemo.makeData()
        let extra = PostID("00000000-0000-4000-8000-00000000c007")
        data.update { $0.posts.append(SocialDemo.post(extra, by: SocialDemo.ben, at: SocialDemo.monday.addingTimeInterval(-3 * SocialDemo.day))) }
        let model = WeekEditModel(groupID: SocialDemo.groupID, mode: .recap(SocialDemo.recapID), data: data)
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.gridPosts.map(\.id), [SocialDemo.p6, SocialDemo.p5, extra])
        XCTAssertEqual(model.checked, [SocialDemo.p6, SocialDemo.p5])

        model.toggle(SocialDemo.p6)
        model.toggle(extra)
        XCTAssertEqual(model.signals.feedback?.kind, .select)
        XCTAssertEqual(model.checkedInOrder, [SocialDemo.p5, extra])
        model.text = "best week"
        await model.save()
        XCTAssertTrue(model.isFinished)
        XCTAssertEqual(data.read { $0.recaps.first { $0.id == SocialDemo.recapID } }?.items, [SocialDemo.p5, extra])
        XCTAssertEqual(data.read { $0.recaps.first { $0.id == SocialDemo.recapID } }?.text, "best week")
        XCTAssertEqual(model.signals.notice?.notice, .recapSaved)
    }

    func testReorderMovesOnlyBetweenCheckedTiles() async {
        let model = WeekEditModel(groupID: SocialDemo.groupID, mode: .recap(SocialDemo.recapID), data: SocialDemo.makeData())
        await model.load()
        XCTAssertTrue(model.move(SocialDemo.p5, to: SocialDemo.p6))
        XCTAssertEqual(model.checkedInOrder, [SocialDemo.p5, SocialDemo.p6])
        model.toggle(SocialDemo.p6)
        XCTAssertFalse(model.move(SocialDemo.p5, to: SocialDemo.p6))
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
        XCTAssertEqual(SocialCalendar.weekNumber(of: LocalDate(year: 2026, month: 12, day: 28)!, in: model.timeZone), 53)
        XCTAssertEqual(SocialCalendar.weekNumber(of: LocalDate(year: 2027, month: 1, day: 4)!, in: model.timeZone), 1)
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
}

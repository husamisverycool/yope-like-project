// The same-moment collage in the group's history (migration 0033): groups.screen shows the day's collage on this
// week's strip once composed, week.history shows each day's collage in its week, week.recap shows the recap's
// collages (`weekly_recaps.collage_ids`) after the cover.
@testable import App
import AppData
import AppModels
import Foundation
import XCTest

@MainActor
final class CollageHistoryTests: XCTestCase {
    private func collage(_ id: String, _ date: LocalDate) -> GroupCollage {
        GroupCollage(
            collageID: CollageID(id), invitationID: InvitationID("inv-" + id), localDate: date,
            imagePath: "g/x/collages/\(id)/1/display-1.jpg", widgetPath: "g/x/collages/\(id)/1/widget.jpg"
        )
    }

    // MARK: week.history

    func testHistoryShowsEachDaysCollageInItsWeek() async {
        let data = SocialDemo.makeData()
        let tuesday = SocialDemo.thisWeek.adding(days: 1)
        let friday = SocialDemo.thisWeek.adding(days: 4)
        let earlier = SocialDemo.lastWeek.adding(days: -7).adding(days: 2)
        data.update { $0.historyCollages[SocialDemo.groupID] = [self.collage("c2", friday), self.collage("c1", tuesday), self.collage("c0", earlier)] }
        let model = WeekHistoryModel(groupID: SocialDemo.groupID, data: data, now: { SocialDemo.monday.addingTimeInterval(4 * SocialDemo.day) })
        await model.load()
        XCTAssertEqual(model.weeks[0].collages.map(\.collageID), [CollageID("c1"), CollageID("c2")], "oldest first, in their week")
        XCTAssertEqual(model.weeks[0].collages.first?.tilePath, "g/x/collages/c1/1/widget.jpg", "the widget rendition on a tile")
        XCTAssertEqual(model.emptyDays(of: model.weeks[0]), [LocalDate(year: 2026, month: 10, day: 17)!, LocalDate(year: 2026, month: 10, day: 18)!],
                       "a day with the group's collage is not an empty day")
        let onlyCollage = model.weeks.first { $0.weekStart == SocialDemo.lastWeek.adding(days: -7) }
        XCTAssertNotNil(onlyCollage, "a week with only a collage still shows")
        XCTAssertEqual(onlyCollage?.postIDs, [])
        XCTAssertEqual(onlyCollage?.collages.map(\.collageID), [CollageID("c0")])
        XCTAssertFalse(onlyCollage?.isBlank ?? true)
    }

    // MARK: week.recap

    func testRecapShowsItsCollagesInRecapOrder() async {
        let data = SocialDemo.makeData()
        let monday = SocialDemo.lastWeek
        data.update { state in
            state.historyCollages[SocialDemo.groupID] = [self.collage("c1", monday.adding(days: 1)), self.collage("c2", monday.adding(days: 3))]
            if let index = state.recaps.firstIndex(where: { $0.id == SocialDemo.recapID }) {
                state.recaps[index].collageIDs = [CollageID("c2"), CollageID("c1"), CollageID("gone")]
            }
        }
        let model = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: data)
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.collages.map(\.collageID), [CollageID("c2"), CollageID("c1")], "recap order; a deleted collage leaves")

        let before = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: SocialDemo.makeData())
        await before.load()
        XCTAssertEqual(before.collages, [], "a recap made before collages were kept has none")
    }

    // MARK: groups.screen

    func testGroupScreenStripHoldsThisWeeksCollages() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup(posts: 1)
        // The fixture clock is Wednesday 14 October 2026 (ISO week 42; the group is in UTC).
        fixture.data.collagesByGroup[group.id] = [
            collage("c-mon", LocalDate(year: 2026, month: 10, day: 12)!),
            collage("c-tue", LocalDate(year: 2026, month: 10, day: 13)!),
            collage("c-last", LocalDate(year: 2026, month: 10, day: 9)!),
        ]
        let model = GroupFeedModel(groupID: group.id, data: fixture.data, now: { fixture.data.clock })
        await model.refresh()
        XCTAssertEqual(model.thisWeekCollages.map(\.collageID), [CollageID("c-mon"), CollageID("c-tue")], "this week only, oldest first")
        model.stop()
    }
}

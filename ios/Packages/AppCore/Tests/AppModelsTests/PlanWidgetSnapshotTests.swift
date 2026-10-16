import Foundation
import XCTest
@testable import AppModels

/// The countdown widget's data (`widget.countdown`): calendar-day arithmetic, the featured plan, the midnight timeline
/// and the plan list in `WidgetStore`.
final class PlanWidgetSnapshotTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("plan-widget-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func date(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text)!
    }

    private func plan(_ id: String, group: String = "g1", day: String, startsAt: String, cover: String? = nil) -> PlanWidgetSnapshot {
        PlanWidgetSnapshot(planID: id, groupID: group, groupName: "Roommates", title: "Dinner", localDate: day, startsAt: date(startsAt), coverFileName: cover)
    }

    func testDaysAreCalendarDaysNotSpans() {
        let berlin = calendar("Europe/Berlin")
        // 23:30 on Oct 16 in Berlin: a plan on Oct 18 is 2 calendar days away although only ~25 hours remain.
        let lateEvening = date("2026-10-16T21:30:00Z")
        XCTAssertEqual(PlanCountdown.days(until: "2026-10-18", from: lateEvening, calendar: berlin), 2)
        XCTAssertEqual(PlanCountdown.days(until: "2026-10-17", from: lateEvening, calendar: berlin), 1)
        XCTAssertEqual(PlanCountdown.days(until: "2026-10-16", from: lateEvening, calendar: berlin), 0)
        XCTAssertEqual(PlanCountdown.days(until: "2026-10-15", from: lateEvening, calendar: berlin), -1)
        // The same instant is already Oct 17 in Tokyo.
        XCTAssertEqual(PlanCountdown.days(until: "2026-10-18", from: lateEvening, calendar: calendar("Asia/Tokyo")), 1)
        // Across a daylight-saving change (Oct 25 in Europe) and a year boundary.
        XCTAssertEqual(PlanCountdown.days(until: "2026-10-26", from: lateEvening, calendar: berlin), 10)
        XCTAssertEqual(PlanCountdown.days(until: "2027-01-01", from: lateEvening, calendar: berlin), 77)
        XCTAssertNil(PlanCountdown.days(until: "2026-13-01", from: lateEvening, calendar: berlin))
        XCTAssertNil(PlanCountdown.days(until: "tomorrow", from: lateEvening, calendar: berlin))
    }

    func testFeaturedPlanIsTheSoonestFromToday() {
        let utc = calendar("UTC")
        let now = date("2026-10-16T10:00:00Z")
        let plans = [
            plan("past", day: "2026-10-15", startsAt: "2026-10-15T18:00:00Z"),
            plan("later", day: "2026-10-24", startsAt: "2026-10-24T18:00:00Z"),
            plan("today", day: "2026-10-16", startsAt: "2026-10-16T08:00:00Z"),
            plan("other", group: "g2", day: "2026-10-17", startsAt: "2026-10-17T18:00:00Z"),
        ]
        XCTAssertEqual(PlanCountdown.featured(plans, groupID: nil, at: now, calendar: utc)?.planID, "today")
        XCTAssertEqual(PlanCountdown.featured(plans, groupID: "g2", at: now, calendar: utc)?.planID, "other")
        XCTAssertNil(PlanCountdown.featured(plans, groupID: "g3", at: now, calendar: utc))
        // The day after "today": it falls through to the next plan.
        XCTAssertEqual(PlanCountdown.featured(plans, groupID: "g1", at: date("2026-10-17T00:00:00Z"), calendar: utc)?.planID, "later")
    }

    func testTimelineHasAnEntryAtEachMidnightThroughTheDayAfter() {
        let utc = calendar("UTC")
        let now = date("2026-10-16T10:00:00Z")
        let dates = PlanCountdown.entryDates(through: "2026-10-18", from: now, calendar: utc, maxEntries: 40)
        XCTAssertEqual(dates, [
            now, date("2026-10-17T00:00:00Z"), date("2026-10-18T00:00:00Z"), date("2026-10-19T00:00:00Z"),
        ])
        XCTAssertEqual(PlanCountdown.entryDates(through: "2027-12-31", from: now, calendar: utc, maxEntries: 5).count, 5)
        XCTAssertEqual(PlanCountdown.entryDates(through: nil, from: now, calendar: utc, maxEntries: 5), [now])
    }

    func testStoreWritesPlansAndPrunesOldCovers() throws {
        let store = WidgetStore(rootURL: root)
        XCTAssertFalse(store.hasPlanList)
        XCTAssertEqual(store.plans(), [])
        try store.writePlanFile(Data([1, 2, 3]), fileName: "p1-cover.jpg")
        try store.writePlanFile(Data([4]), fileName: "old-cover.jpg")
        let first = plan("p1", day: "2026-10-24", startsAt: "2026-10-24T18:00:00Z", cover: "p1-cover.jpg")
        let second = plan("p2", day: "2026-10-30", startsAt: "2026-10-30T18:00:00Z")
        try store.savePlans([first, second])
        XCTAssertTrue(store.hasPlanList)
        XCTAssertEqual(store.plans(), [first, second])
        XCTAssertNotNil(store.coverURL(for: first))
        XCTAssertNil(store.coverURL(for: second))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.plansDirectory.appendingPathComponent("old-cover.jpg").path))
        // The group list sync and sign-out: plans live outside the group folders and go with the whole store.
        try store.syncGroups([])
        XCTAssertEqual(store.plans(), [first, second])
        try store.removeAll()
        XCTAssertFalse(store.hasPlanList)
    }

    func testStoreRejectsUnsafeNames() {
        let store = WidgetStore(rootURL: root)
        XCTAssertThrowsError(try store.writePlanFile(Data(), fileName: "../x.jpg"))
        XCTAssertThrowsError(try store.savePlans([plan("a/b", day: "2026-10-24", startsAt: "2026-10-24T18:00:00Z")]))
    }
}

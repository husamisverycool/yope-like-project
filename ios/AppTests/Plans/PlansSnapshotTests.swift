// One snapshot per plans-group surface per state, recorded into ios/build/snapshots/plans/<surface>-<state>-<light|dark>.png
// for the side-by-side verification (design/verification/<surface>.png, made by the lead from the CI artifact): plans.create,
// plans.page (no answer, going, maybe, can't go, canceled, past, not found, the people sheet), the weekly question card,
// the developing tile in the week strip, the countdown widget. Each surface's primary state also in dark. Screens run on
// the fake backend (`FakePlansData`); photos and avatars are real sample photos (fixtures/photos/). Native pickers,
// menus and alerts are drawn by the system and are not recorded beyond their inline forms.
@testable import App
import AppData
import AppModels
import DesignSystem
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@MainActor
final class PlansSnapshotTests: XCTestCase {
    private func record<V: View>(_ view: V, _ surface: String, _ state: String, appearances: [ColorScheme] = [.light], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotNil(PlansSnapshot.record(view, surface: surface, state: state, appearances: appearances, file: file, line: line), file: file, line: line)
    }

    // MARK: plans.create

    func testPlansCreate() async {
        let fixture = PlansFixture()
        record(PlanCreateView(model: PlanCreateModel(groupID: PlansFixture.groupID, editing: nil, services: fixture.services)), "plans.create", "empty", appearances: PlansSnapshot.both)

        let ready = PlanCreateModel(groupID: PlansFixture.groupID, editing: nil, services: fixture.services)
        await ready.load()
        ready.setTitle("Dinner at ours")
        ready.setDay(PlansFixture.dinnerStart)
        ready.setTime(PlansFixture.dinnerStart)
        ready.setPlace("Our kitchen")
        ready.setNote("Bring something sweet — we'll have pasta.")
        ready.setCover(imageData: SamplePhotos.data(named: "dinner-long-table-3x4"))
        record(PlanCreateView(model: ready), "plans.create", "ready", appearances: PlansSnapshot.both)

        let datePicker = PlanCreateModel(groupID: PlansFixture.groupID, editing: nil, services: fixture.services)
        await datePicker.load()
        datePicker.setTitle("Dinner at ours")
        datePicker.setDay(PlansFixture.dinnerStart)
        datePicker.toggle(.date)
        record(PlanCreateView(model: datePicker), "plans.create", "date-picker")

        let allDay = PlanCreateModel(groupID: PlansFixture.groupID, editing: nil, services: fixture.services)
        await allDay.load()
        allDay.setTitle("Hike day")
        allDay.setDay(PlansFixture.dinnerStart)
        allDay.setAllDay(true)
        record(PlanCreateView(model: allDay), "plans.create", "all-day")

        let tooLong = PlanCreateModel(groupID: PlansFixture.groupID, editing: nil, services: fixture.services)
        tooLong.setTitle(String(repeating: "Dinner at ours ", count: 6))
        record(PlanCreateView(model: tooLong), "plans.create", "name-too-long")

        let failing = PlansFixture()
        failing.data.update { $0.failures["createPlan"] = .http(status: 500) }
        let error = PlanCreateModel(groupID: PlansFixture.groupID, editing: nil, services: failing.services)
        await error.load()
        error.setTitle("Dinner at ours")
        error.setDay(PlansFixture.dinnerStart)
        _ = await error.submit()
        record(PlanCreateView(model: error), "plans.create", "error")

        let editing = PlansFixture(me: PlansFixture.ana)
        editing.addDinner()
        await editing.warmPhotos()
        let plan = try? await editing.data.plan(id: PlansFixture.planID)
        let edit = PlanCreateModel(groupID: PlansFixture.groupID, editing: plan, services: editing.services)
        await edit.load()
        record(PlanCreateView(model: edit), "plans.create", "edit")
    }

    // MARK: plans.page

    private func page(_ fixture: PlansFixture) async -> PlanPageModel {
        await fixture.warmPhotos()
        let model = PlanPageModel(planID: PlansFixture.planID, services: fixture.services)
        await model.refresh()
        return model
    }

    func testPlansPage() async {
        let none = PlansFixture()
        none.addDinner()
        let noAnswer = await page(none)
        record(NavigationStack { PlanPageView(model: noAnswer) }, "plans.page", "no-answer", appearances: PlansSnapshot.both)

        for (state, answer) in [("going", PlanAnswerKind.going), ("maybe", .maybe), ("cant-go", .cantGo)] {
            let fixture = PlansFixture()
            fixture.addDinner(answers: [(PlansFixture.ana, .going), (PlansFixture.ben, .going), (PlansFixture.cleo, .maybe), (PlansFixture.me, answer)])
            let model = await page(fixture)
            record(NavigationStack { PlanPageView(model: model) }, "plans.page", state, appearances: state == "going" ? PlansSnapshot.both : [.light])
        }

        let maker = PlansFixture(me: PlansFixture.ana)
        maker.addDinner(answers: [(PlansFixture.ana, .going), (PlansFixture.ben, .cantGo), (PlansFixture.cleo, .maybe)])
        let makerPage = await page(maker)
        record(NavigationStack { PlanPageView(model: makerPage) }, "plans.page", "maker")
        record(PlanPeopleSheet(model: makerPage), "plans.page", "people-sheet")

        let noCover = PlansFixture()
        noCover.addDinner(cover: nil)
        let noCoverPage = await page(noCover)
        record(NavigationStack { PlanPageView(model: noCoverPage) }, "plans.page", "no-cover")

        let canceled = PlansFixture()
        canceled.addDinner(canceled: true)
        let canceledPage = await page(canceled)
        record(NavigationStack { PlanPageView(model: canceledPage) }, "plans.page", "canceled")

        let past = PlansFixture(clock: PlansFixture.dinnerStart.addingTimeInterval(PlansFixture.day))
        past.addDinner(answers: [(PlansFixture.ana, .going), (PlansFixture.ben, .going), (PlansFixture.me, .going), (PlansFixture.cleo, .maybe)])
        past.addPlanPhotos(["dinner-pizza-cheers-3x4", "pizza-table-3x4", "dinner-toast-candles-3x4", "food-plates-4x3", "friends-floor-laughing-3x4"])
        let pastPage = await page(past)
        record(NavigationStack { PlanPageView(model: pastPage) }, "plans.page", "past")

        let gone = PlansFixture()
        let gonePage = await page(gone)
        record(NavigationStack { PlanPageView(model: gonePage) }, "plans.page", "not-found")
    }

    // MARK: groups.screen plan row

    /// The plan row as groups.screen places it under the capsules: the next plan, and "Make a Plan" without one.
    func testPlanRow() async {
        let upcoming = PlansFixture()
        upcoming.addDinner()
        let row = PlanRowModel(groupID: PlansFixture.groupID, services: upcoming.services)
        await row.refresh()
        record(rowPage(PlanRowEntry(groupID: PlansFixture.groupID.rawValue, model: row)), "groups.screen", "plan-row", appearances: PlansSnapshot.both)

        let none = PlansFixture()
        let empty = PlanRowModel(groupID: PlansFixture.groupID, services: none.services)
        await empty.refresh()
        record(rowPage(PlanRowEntry(groupID: PlansFixture.groupID.rawValue, model: empty)), "groups.screen", "plan-row-none")
    }

    private func rowPage<V: View>(_ row: V) -> some View {
        VStack {
            row
            Spacer(minLength: 0)
        }
        .background(Tokens.Colors.globalBackground)
    }

    // MARK: question.weekly

    private func card(_ fixture: PlansFixture) async -> QuestionCardModel {
        await fixture.warmPhotos()
        let model = QuestionCardModel(groupID: PlansFixture.groupID, services: fixture.services)
        await model.refresh()
        return model
    }

    /// The card as the pager shows it: inside `size.global.screenMargin` on the page.
    private func pager<V: View>(_ card: V) -> some View {
        VStack(alignment: .leading) {
            FriendCardPager { card }
            Spacer(minLength: 0)
        }
        .background(Tokens.Colors.globalBackground)
    }

    func testQuestionCard() async {
        let empty = PlansFixture()
        empty.addQuestion()
        let emptyModel = await card(empty)
        record(pager(QuestionCardEntry(groupID: PlansFixture.groupID.rawValue, model: emptyModel)), "question.weekly", "no-answers", appearances: PlansSnapshot.both)

        let answered = PlansFixture()
        answered.addQuestion(answers: ["dinner-pizza-cheers-3x4"])
        let answeredModel = await card(answered)
        record(pager(QuestionCardEntry(groupID: PlansFixture.groupID.rawValue, model: answeredModel)), "question.weekly", "with-answers", appearances: PlansSnapshot.both)

        let longest = PlansFixture()
        longest.addQuestion()
        longest.data.update { $0.questions[PlansFixture.groupID]?.questionKey = "question.weekly.q08" }
        let longModel = await card(longest)
        record(pager(QuestionCardEntry(groupID: PlansFixture.groupID.rawValue, model: longModel)), "question.weekly", "long-question")
    }

    /// The question on the viewfinder (question.weekly B), over a sample photo in the 3:4 viewfinder.
    func testQuestionCameraPill() {
        let viewfinder = ZStack(alignment: .bottom) {
            Image(uiImage: SamplePhotos.photo(named: "friends-floor-laughing-3x4", size: CGSize(width: 361, height: 481)))
                .resizable()
                .scaledToFill()
            QuestionCameraPillLabel(question: Copy.questionWeeklyQ01)
        }
        .frame(width: 361, height: 481)
        .clipShape(DSShape.rounded(Tokens.Radii.globalViewfinder))
        .padding(Tokens.Sizes.globalScreenMargin)
        .background(Tokens.Colors.globalBackgroundDeep)
        record(viewfinder, "question.weekly", "camera-pill")
        let long = ZStack(alignment: .bottom) {
            Tokens.Colors.globalBackgroundDeep
            QuestionCameraPillLabel(question: Copy.questionWeeklyQ08)
        }
        .frame(width: 361, height: 481)
        .padding(Tokens.Sizes.globalScreenMargin)
        .background(Tokens.Colors.globalBackgroundDeep)
        record(long, "question.weekly", "camera-pill-long")
    }

    // MARK: camera.overnight B

    func testDevelopingTileInTheWeekStrip() {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let monday = calendar.dateInterval(of: .weekOfYear, for: PlansFixture.now)!.start
        let photos = ["dinner-pizza-cheers-3x4", "snow-forest-walk-3x4"].enumerated().map { index, name in
            WeekStripPhoto(
                id: "p\(index)", date: monday.addingTimeInterval(Double(index + 1) * PlansFixture.day),
                source: .image(SamplePhotos.photo(named: name, size: CGSize(width: 252, height: 336)))
            )
        }
        let label = Copy.cameraOvernightTileA11y(reveal: PlanFormats.reveal(PlansFixture.now.addingTimeInterval(23 * PlansFixture.hour)))
        let withPhotos = GroupWeekStrip(
            tiles: WeekStripLayout.tiles(days: [], photos: photos, canAdd: true),
            accessibilityLabel: { _ in "" }, onSelect: { _ in }, menuPost: { _ in nil }, developing: label
        ) { _ in EmptyView() }
        record(strip(withPhotos), "camera.overnight", "developing-tile", appearances: PlansSnapshot.both)

        let days = WeekStripLayout.days(ofWeekContaining: PlansFixture.now, calendar: calendar).filter { $0 > PlansFixture.now }
        let emptyWeek = GroupWeekStrip(
            tiles: WeekStripLayout.tiles(days: days, photos: [], canAdd: true),
            accessibilityLabel: { _ in "" }, onSelect: { _ in }, menuPost: { _ in nil }, developing: label
        ) { _ in EmptyView() }
        record(strip(emptyWeek), "camera.overnight", "developing-tile-empty-week")
    }

    private func strip<V: View>(_ strip: V) -> some View {
        VStack {
            strip
            Spacer(minLength: 0)
        }
        .padding(.top, Tokens.Sizes.globalSectionGap)
        .background(Tokens.Colors.globalBackground)
    }

    // MARK: widget.countdown

    private func size(_ token: String) -> CGSize {
        let parts = token.split(separator: "x").compactMap { Double($0) }
        return CGSize(width: parts[0], height: parts[1])
    }

    /// The widget: container background + overlay, clipped like the system container (Retro's widget corner
    /// `widget.android.radius.widget` for the comp, as the group-photo widget's snapshots), on `color.global.controlRaised`.
    private func widget(_ content: PlanCountdownContent, size: CGSize, medium: Bool) -> some View {
        ZStack {
            PlanCountdownBackground(content: content)
            PlanCountdownOverlay(content: content, showsGroup: medium)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radii.widgetAndroidRadiusWidget, style: .continuous))
        .padding(Tokens.Sizes.globalScreenMargin)
        .background(Tokens.Colors.globalControlRaised)
    }

    private func recordWidget(_ content: PlanCountdownContent, state: String, appearances: [ColorScheme] = [.light]) {
        let families = [
            ("small", size(Tokens.Layouts.WidgetHomeSmallLayoutSize.w393h852), false),
            ("medium", size(Tokens.Layouts.WidgetHomeMediumLayoutSize.w393h852), true),
        ]
        for (family, frame, medium) in families {
            let margin = Tokens.Sizes.globalScreenMargin * 2
            let url = PlansSnapshot.record(
                widget(content, size: frame, medium: medium), surface: "widget.countdown", state: "\(family)-\(state)",
                appearances: appearances, layout: .fixed(width: frame.width + margin, height: frame.height + margin)
            )
            XCTAssertNotNil(url)
        }
    }

    func testCountdownWidget() {
        let cover = SamplePhotos.photo(named: "dinner-long-table-3x4", size: CGSize(width: 600, height: 630))
        let plan = { (days: Int, photo: UIImage?) in
            PlanCountdownContent(state: .plan, title: "Dinner at ours", groupName: "Roommates", days: days, photo: photo)
        }
        recordWidget(plan(3, cover), state: "in-days", appearances: PlansSnapshot.both)
        recordWidget(plan(1, cover), state: "tomorrow")
        recordWidget(plan(0, cover), state: "today")
        recordWidget(plan(12, nil), state: "no-photo")
        recordWidget(PlanCountdownContent(state: .plan, title: "Saturday Morning Climbing Crew Potluck", groupName: "Saturday Morning Climbing Crew", days: 42, photo: cover), state: "long-title")
        recordWidget(PlanCountdownContent(state: .noPlans), state: "no-plans")
        recordWidget(PlanCountdownContent(state: .notSetUp), state: "not-set-up")
        recordWidget(PlanCountdownContent(state: .signedOut), state: "signed-out")
        recordWidget(PlanCountdownContent(state: .loading), state: "loading")
    }

    /// The entries the timeline gets from the App Group store: the featured plan, its photo and the midnight swaps.
    func testCountdownEntriesFromTheStore() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("countdown-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = WidgetStore(rootURL: root)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(PlanCountdownResolver.entry(configuredGroupID: nil, store: store, at: PlansFixture.now, calendar: utc).state, .signedOut)
        try store.syncGroups([WidgetGroup(id: "g1", name: "Roommates")])
        XCTAssertEqual(PlanCountdownResolver.entry(configuredGroupID: nil, store: store, at: PlansFixture.now, calendar: utc).state, .noPlans)
        XCTAssertEqual(PlanCountdownResolver.entry(configuredGroupID: "gone", store: store, at: PlansFixture.now, calendar: utc).state, .notSetUp)
        try store.writePlanFile(SamplePhotos.data(named: "dinner-long-table-3x4"), fileName: "p1-cover.jpg")
        try store.savePlans([
            PlanWidgetSnapshot(planID: "p1", groupID: "g1", groupName: "Roommates", title: "Dinner at ours", localDate: "2026-10-17", startsAt: PlansFixture.dinnerStart, coverFileName: "p1-cover.jpg"),
        ])
        let entry = PlanCountdownResolver.entry(configuredGroupID: PlanCountdownResolver.allGroupsID, store: store, at: PlansFixture.now, calendar: utc)
        XCTAssertEqual(entry.state, .plan)
        XCTAssertEqual(entry.days, 1)
        XCTAssertNotNil(entry.content.photo)
        XCTAssertEqual(entry.tapURL?.absoluteString, "app://plan?plan=p1&group=g1")
        let entries = PlanCountdownResolver.entries(configuredGroupID: nil, store: store, now: PlansFixture.now, calendar: utc)
        XCTAssertEqual(entries.map(\.days), [1, 0, nil], "Tomorrow, the day itself, then the next plan (none)")
        XCTAssertEqual(entries.last?.state, .noPlans)
    }
}

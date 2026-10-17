// Unit tests of the plans group's view models on the fake backend: plans.create (validation, day and time in the
// group's zone, all-day), plans.page (answering, clearing, failure, who sees Can't go, past and canceled plans, the
// menu), the weekly question (card, Remove, the camera hand-off and its answer link), the developing tile, the plan
// row, the plan deep link and the countdown's wording.
@testable import App
import AppData
import AppModels
import DesignSystem
import XCTest

@MainActor
final class PlansModelTests: XCTestCase {
    // MARK: plans.create

    func testCreateNeedsATitleAndADay() async {
        let fixture = PlansFixture()
        let model = PlanCreateModel(groupID: PlansFixture.groupID, editing: nil, services: fixture.services)
        await model.load()
        XCTAssertFalse(model.canSubmit)
        XCTAssertFalse(model.hasInput, "an empty form closes at once")
        model.setTitle("  Dinner at ours  ")
        XCTAssertFalse(model.canSubmit, "no date yet")
        XCTAssertTrue(model.hasInput)
        model.setDay(PlansFixture.dinnerStart)
        XCTAssertTrue(model.canSubmit)
        XCTAssertTrue(model.isAllDay, "no time chosen = all-day")
        model.setTitle(String(repeating: "a", count: 81))
        XCTAssertTrue(model.isTitleTooLong)
        XCTAssertFalse(model.canSubmit)
    }

    func testOpeningTheCalendarChoosesTheDayItShows() async {
        // The inline calendar opens on today selected, and tapping the selected day changes nothing: without this a plan
        // for today could not be made.
        let fixture = PlansFixture()
        let model = PlanCreateModel(groupID: PlansFixture.groupID, editing: nil, services: fixture.services)
        await model.load()
        model.setTitle("Dinner at ours")
        XCTAssertNil(model.day)
        model.toggle(.date)
        XCTAssertEqual(model.openPicker, .date)
        XCTAssertEqual(model.day, model.minimumDate, "the day the calendar shows selected")
        XCTAssertTrue(model.canSubmit)
        model.setDay(PlansFixture.dinnerStart)
        model.toggle(.date)
        XCTAssertNil(model.openPicker)
        model.toggle(.date)
        // Reopened: the chosen day stays.
        XCTAssertEqual(model.startsAt, PlanCalendar.start(of: LocalDate(year: 2026, month: 10, day: 17)!, in: TimeZone(identifier: "UTC")!))
    }

    func testCreateCombinesDayAndTimeInTheGroupZoneAndMakerGoes() async throws {
        let fixture = PlansFixture()
        let services = fixture.services
        let model = PlanCreateModel(groupID: PlansFixture.groupID, editing: nil, services: services)
        await model.load()
        model.setTitle("Dinner at ours")
        model.setDay(PlansFixture.dinnerStart)
        model.setTime(PlansFixture.dinnerStart)
        model.setPlace(String(repeating: "p", count: 250))
        XCTAssertEqual(model.place.count, PlanCreateModel.maxPlaceLength, "typing stops at the server's limit")
        XCTAssertEqual(model.startsAt, PlansFixture.dinnerStart)
        let revision = services.revision
        let submitted = await model.submit()
        let plan = try XCTUnwrap(submitted)
        XCTAssertEqual(plan.title, "Dinner at ours")
        XCTAssertFalse(plan.allDay)
        XCTAssertEqual(plan.localDate.description, "2026-10-17")
        XCTAssertEqual(services.revision, revision + 1, "dependants refetch")
        let answers = try await fixture.data.answers(planID: plan.id)
        XCTAssertEqual(answers.map(\.answer), [.going], "the maker's answer starts as Going")
    }

    func testAllDayDropsTheTimeAndTheDayCannotBeBeforeToday() async {
        let fixture = PlansFixture()
        let model = PlanCreateModel(groupID: PlansFixture.groupID, editing: nil, services: fixture.services)
        await model.load()
        model.setDay(PlansFixture.now.addingTimeInterval(-3 * PlansFixture.day))
        XCTAssertEqual(model.day, model.minimumDate, "the picker's minimum is today in the group's zone")
        model.setDay(PlansFixture.dinnerStart)
        model.setTime(PlansFixture.dinnerStart)
        model.openPicker = .time
        model.setAllDay(true)
        XCTAssertNil(model.openPicker)
        XCTAssertTrue(model.isAllDay)
        XCTAssertEqual(model.startsAt, PlanCalendar.start(of: LocalDate(year: 2026, month: 10, day: 17)!, in: TimeZone(identifier: "UTC")!))
    }

    func testCreateFailureShowsTheInlineLine() async {
        let fixture = PlansFixture()
        fixture.data.update { $0.failures["createPlan"] = .offline }
        let model = PlanCreateModel(groupID: PlansFixture.groupID, editing: nil, services: fixture.services)
        model.setTitle("Dinner")
        model.setDay(PlansFixture.dinnerStart)
        let plan = await model.submit()
        XCTAssertNil(plan)
        XCTAssertEqual(model.failureMessage, Copy.plansCreateOffline)
        fixture.data.update { $0.failures["createPlan"] = .http(status: 500) }
        _ = await model.submit()
        XCTAssertEqual(model.failureMessage, Copy.plansCreateErrorFailed)
    }

    func testEditPrefillsAndSaves() async throws {
        let fixture = PlansFixture(me: PlansFixture.ana)
        fixture.addDinner()
        let stored = try await fixture.data.plan(id: PlansFixture.planID)
        let plan = try XCTUnwrap(stored)
        let model = PlanCreateModel(groupID: PlansFixture.groupID, editing: plan, services: fixture.services)
        XCTAssertTrue(model.isEditing)
        XCTAssertEqual(model.title, "Dinner at ours")
        XCTAssertEqual(model.place, "Our kitchen")
        XCTAssertTrue(model.hasCover)
        XCTAssertFalse(model.hasInput, "nothing changed yet")
        model.setTitle("Dinner at ours!")
        let submitted = await model.submit()
        let saved = try XCTUnwrap(submitted)
        XCTAssertEqual(saved.title, "Dinner at ours!")
        XCTAssertEqual(saved.coverPath, plan.coverPath, "a kept cover is sent as it is")
    }

    // MARK: plans.page

    func testAnsweringIsOneTapAndTappingAgainClears() async {
        let fixture = PlansFixture()
        fixture.addDinner()
        let model = PlanPageModel(planID: PlansFixture.planID, services: fixture.services)
        await model.refresh()
        XCTAssertEqual(model.phase, .loaded)
        XCTAssertNil(model.myAnswer)
        XCTAssertTrue(model.showsAnswerRow)
        XCTAssertEqual(model.people(.going).map(\.firstName), ["Ana", "Ben"], "oldest answer first")
        XCTAssertEqual(model.people(.maybe).map(\.firstName), ["Cleo"])

        await model.select(.going)
        XCTAssertEqual(model.myAnswer, .going)
        XCTAssertEqual(model.people(.going).map(\.firstName), ["Ana", "Ben", "Sam"])
        await model.select(.maybe)
        XCTAssertEqual(model.myAnswer, .maybe, "a new answer replaces the previous one")
        await model.select(.maybe)
        XCTAssertNil(model.myAnswer, "tapping the selected answer clears it")
        XCTAssertEqual(fixture.data.calls.filter { ["answer", "clearAnswer"].contains($0) }, ["answer", "answer", "clearAnswer"])
        XCTAssertEqual(model.selectionCount, 3)
    }

    func testFailedAnswerRevertsAndTells() async {
        let fixture = PlansFixture()
        fixture.addDinner()
        let model = PlanPageModel(planID: PlansFixture.planID, services: fixture.services)
        await model.refresh()
        fixture.data.update { $0.failures["answer"] = .http(status: 500) }
        await model.select(.going)
        XCTAssertNil(model.myAnswer, "the optimistic answer is put back")
        XCTAssertEqual(model.answerFailureCount, 1)
    }

    func testCantGoReachesOnlyItsAuthorAndTheMaker() async {
        let answers: [(UserID, PlanAnswerKind)] = [(PlansFixture.ana, .going), (PlansFixture.ben, .cantGo), (PlansFixture.cleo, .maybe)]
        let member = PlansFixture()
        member.addDinner(answers: answers)
        let memberPage = PlanPageModel(planID: PlansFixture.planID, services: member.services)
        await memberPage.refresh()
        XCTAssertEqual(memberPage.people(.cantGo), [], "a member does not see others' Can't go")
        XCTAssertFalse(memberPage.showsMenu, "the menu is the maker's and the admins'")
        XCTAssertTrue(memberPage.showsReport, "another member's plan can be reported (MERGE FV-4)")
        XCTAssertEqual(memberPage.reportTarget?.kind, .plan)
        XCTAssertEqual(memberPage.reportTarget?.person?.userID, PlansFixture.ana.rawValue, "Block the plan's maker")

        let maker = PlansFixture(me: PlansFixture.ana)
        maker.addDinner(answers: answers)
        let makerPage = PlanPageModel(planID: PlansFixture.planID, services: maker.services)
        await makerPage.refresh()
        XCTAssertEqual(makerPage.people(.cantGo).map(\.firstName), ["Ben"])
        XCTAssertTrue(makerPage.showsMenu)
        XCTAssertFalse(makerPage.showsReport, "no report of your own plan")

        let ben = PlansFixture(me: PlansFixture.ben)
        ben.addDinner(answers: answers)
        let benPage = PlanPageModel(planID: PlansFixture.planID, services: ben.services)
        await benPage.refresh()
        XCTAssertEqual(benPage.myAnswer, .cantGo, "your own Can't go is yours to see")
    }

    func testCanceledAndPastPlans() async {
        let canceled = PlansFixture()
        canceled.addDinner(canceled: true)
        let canceledPage = PlanPageModel(planID: PlansFixture.planID, services: canceled.services)
        await canceledPage.refresh()
        XCTAssertTrue(canceledPage.isCanceled)
        XCTAssertFalse(canceledPage.showsAnswerRow)
        XCTAssertEqual(canceledPage.whenLine, Copy.plansPageCanceled)
        XCTAssertEqual(canceledPage.people(.going).count, 2, "lists are kept read-only")

        let past = PlansFixture(clock: PlansFixture.dinnerStart.addingTimeInterval(PlansFixture.day))
        past.addDinner()
        past.addPlanPhotos(["dinner-pizza-cheers-3x4", "pizza-table-3x4"])
        let pastPage = PlanPageModel(planID: PlansFixture.planID, services: past.services)
        await pastPage.refresh()
        XCTAssertTrue(pastPage.isPast)
        XCTAssertFalse(pastPage.showsAnswerRow)
        XCTAssertFalse(pastPage.showsMenu, "edit, cancel and restore stop when the plan is over")
        XCTAssertEqual(pastPage.albumPhotos.count, 2)
    }

    func testCancelAndRestore() async {
        let fixture = PlansFixture(me: PlansFixture.ana)
        fixture.addDinner()
        let model = PlanPageModel(planID: PlansFixture.planID, services: fixture.services)
        await model.refresh()
        await model.cancel()
        XCTAssertTrue(model.isCanceled)
        await model.restore()
        XCTAssertFalse(model.isCanceled)
    }

    func testRemovedPlanIsNotFound() async {
        let fixture = PlansFixture()
        let model = PlanPageModel(planID: PlansFixture.planID, services: fixture.services)
        await model.refresh()
        XCTAssertEqual(model.phase, .notFound)
        fixture.data.update { $0.failures["plan"] = .offline }
        await model.retry()
        XCTAssertEqual(model.phase, .error)
        XCTAssertTrue(model.isOfflineFailure)
    }

    func testPlanRowShowsTheNextUpcomingPlan() async {
        let fixture = PlansFixture()
        let empty = PlanRowModel(groupID: PlansFixture.groupID, services: fixture.services)
        await empty.refresh()
        XCTAssertTrue(empty.isLoaded)
        XCTAssertNil(empty.next, "no plan: the row offers Make a Plan")
        fixture.addDinner()
        let row = PlanRowModel(groupID: PlansFixture.groupID, services: fixture.services)
        await row.refresh()
        XCTAssertEqual(row.next?.title, "Dinner at ours")
        XCTAssertNotNil(row.line)
        let canceled = PlansFixture()
        canceled.addDinner(canceled: true)
        let skipped = PlanRowModel(groupID: PlansFixture.groupID, services: canceled.services)
        await skipped.refresh()
        XCTAssertNil(skipped.next, "a canceled plan is not upcoming")
    }

    // MARK: plans.list

    func testPlansListHasUpcomingThenPastThenCanceled() async {
        let fixture = PlansFixture()
        fixture.addListPlans()
        let model = PlansListModel(groupID: PlansFixture.groupID, services: fixture.services)
        await model.refresh()
        XCTAssertEqual(model.phase, .loaded)
        XCTAssertEqual(model.sections.map(\.state), [.upcoming, .past, .canceled])
        XCTAssertEqual(model.sections.map { $0.plans.map(\.title) }, [["Dinner at ours"], ["Picnic by the lake"], ["Movie night"]])
        XCTAssertEqual(PlansListView.title(of: .past), Copy.plansListSectionPast)

        let none = PlansListModel(groupID: PlansFixture.groupID, services: PlansFixture().services)
        await none.refresh()
        XCTAssertEqual(none.phase, .empty)
    }

    func testPlansListFailuresKeepWhatIsShown() async {
        let fixture = PlansFixture()
        fixture.addListPlans()
        fixture.data.update { $0.failures["groupPlans"] = .offline }
        let offline = PlansListModel(groupID: PlansFixture.groupID, services: fixture.services)
        await offline.refresh()
        XCTAssertEqual(offline.phase, .offline)
        fixture.data.update { $0.failures["groupPlans"] = .http(status: 500) }
        let failed = PlansListModel(groupID: PlansFixture.groupID, services: fixture.services)
        await failed.refresh()
        XCTAssertEqual(failed.phase, .error)
        fixture.data.update { $0.failures["groupPlans"] = nil }
        await failed.retry()
        XCTAssertEqual(failed.phase, .loaded)
        fixture.data.update { $0.failures["groupPlans"] = .offline }
        await failed.refresh()
        XCTAssertEqual(failed.phase, .loaded, "a loaded list stays when the connection drops")
        fixture.data.update { $0.failures["groupPlans"] = .api(.notGroupMember, details: nil) }
        await failed.refresh()
        XCTAssertEqual(failed.phase, .removed)
    }

    func testPlanRowShowsTheListLabelWhileTheGroupHasPlans() async {
        let none = PlanRowModel(groupID: PlansFixture.groupID, services: PlansFixture().services)
        await none.refresh()
        XCTAssertFalse(none.hasPlans)
        let canceled = PlansFixture()
        canceled.addDinner(canceled: true)
        let row = PlanRowModel(groupID: PlansFixture.groupID, services: canceled.services)
        await row.refresh()
        XCTAssertTrue(row.hasPlans, "a cancelled plan is in the list")
        XCTAssertNil(row.next)
        XCTAssertNil(row.entryDay)
    }

    /// The birthday rows and the plans block, soonest first; the same day keeps the birthday rows first; a block without
    /// a day goes last (MERGE FV-1).
    func testGroupEntriesStandInDateOrder() {
        let oct18 = LocalDate(year: 2026, month: 10, day: 18)!
        let oct20 = LocalDate(year: 2026, month: 10, day: 20)!
        XCTAssertEqual(GroupEntryOrder.order([.birthday: GroupEntryDay(oct20), .plans: GroupEntryDay(oct18)]), [.plans, .birthday])
        XCTAssertEqual(GroupEntryOrder.order([.birthday: GroupEntryDay(oct18), .plans: GroupEntryDay(oct20)]), [.birthday, .plans])
        XCTAssertEqual(GroupEntryOrder.order([.birthday: GroupEntryDay(oct18), .plans: GroupEntryDay(oct18)]), [.birthday, .plans])
        XCTAssertEqual(GroupEntryOrder.order([.birthday: GroupEntryDay(oct20), .plans: GroupEntryDay(nil)]), [.birthday, .plans])
        XCTAssertEqual(GroupEntryOrder.order([.birthday: GroupEntryDay(nil), .plans: GroupEntryDay(oct18)]), [.plans, .birthday])
        XCTAssertEqual(GroupEntryOrder.order([:]), GroupEntryOrder.declared)
    }

    func testAnotherMembersAnswerShowsWhileThePageIsOpen() async {
        let fixture = PlansFixture()
        fixture.addDinner()
        let model = PlanPageModel(planID: PlansFixture.planID, services: fixture.services)
        await model.followChanges() // returns at once: before the plan is read there is no group to follow
        await model.refresh()
        let following = Task { await model.followChanges() }
        defer { following.cancel() }
        // Cleo answers Going on her phone and Realtime tells the group (run 107: Theo's Going never reached Maya's
        // open plan page).
        fixture.data.update { state in
            state.answers.removeAll { $0.userID == PlansFixture.cleo }
            state.answers.append(
                PlanAnswer(planID: PlansFixture.planID, userID: PlansFixture.cleo, groupID: PlansFixture.groupID, answer: .going, answeredAt: PlansFixture.now)
            )
        }
        await waitUntil {
            fixture.data.notifyPlans(groupID: PlansFixture.groupID)
            return model.people(.going).map(\.firstName) == ["Ana", "Ben", "Cleo"]
        }
        XCTAssertEqual(model.people(.maybe), [])
    }

    func testPlanRowFollowsAPlanMadeElsewhere() async {
        let fixture = PlansFixture()
        let row = PlanRowModel(groupID: PlansFixture.groupID, services: fixture.services)
        await row.refresh()
        XCTAssertNil(row.next)
        let following = Task { await row.followChanges() }
        defer { following.cancel() }
        fixture.addDinner() // Ana makes the plan on her phone
        await waitUntil {
            fixture.data.notifyPlans(groupID: PlansFixture.groupID)
            return row.next?.title == "Dinner at ours"
        }
    }

    // MARK: question.weekly

    func testQuestionCardShowsUntilRemoved() async {
        let fixture = PlansFixture()
        let off = QuestionCardModel(groupID: PlansFixture.groupID, services: fixture.services)
        await off.refresh()
        XCTAssertFalse(off.isVisible, "no question while the group has it off")

        fixture.addQuestion(answers: ["dinner-pizza-cheers-3x4", "friends-floor-laughing-3x4"])
        let card = QuestionCardModel(groupID: PlansFixture.groupID, services: fixture.services)
        await card.refresh()
        XCTAssertTrue(card.isVisible)
        XCTAssertEqual(card.text, Copy.questionWeeklyQ01)
        XCTAssertEqual(card.newestAnswer?.media?.displayPath, "sample/dinner-pizza-cheers-3x4.jpg")
        XCTAssertEqual(card.answersOldestFirst.first?.media?.displayPath, "sample/friends-floor-laughing-3x4.jpg")
        await card.hide()
        XCTAssertFalse(card.isVisible)
        XCTAssertTrue(fixture.data.calls.contains("hideQuestion"))
    }

    func testUnknownQuestionKeyHidesTheCard() async {
        let fixture = PlansFixture()
        fixture.addQuestion()
        fixture.data.update { $0.questions[PlansFixture.groupID]?.questionKey = "question.weekly.q99" }
        let card = QuestionCardModel(groupID: PlansFixture.groupID, services: fixture.services)
        await card.refresh()
        XCTAssertFalse(card.isVisible)
        XCTAssertNil(QuestionCopy.text(forKey: "question.weekly.q99"))
        XCTAssertEqual(QuestionCopy.text(forKey: "question.weekly.q09"), Copy.questionWeeklyQ09)
    }

    func testCameraContextIsClaimedOnceByItsGroup() {
        let context = QuestionCameraContext()
        let answer = QuestionCameraContext.Context(groupID: "g1", questionID: PlansFixture.questionID, text: "Q")
        context.prepare(answer)
        XCTAssertNil(context.claim(groupID: "g2"), "another group's camera does not answer")
        XCTAssertNil(context.active)
        context.prepare(answer)
        XCTAssertEqual(context.claim(groupID: "g1"), answer)
        XCTAssertEqual(context.active, answer)
        XCTAssertNil(context.claim(groupID: "g1"), "a later camera opening claims nothing")
        context.prepare(answer)
        _ = context.claim(groupID: "g1")
        context.drop()
        XCTAssertNil(context.active, "9 AM mode drops the question")
    }

    func testPostedCaptureIsLinkedToTheQuestionOnce() async throws {
        let fixture = PlansFixture()
        fixture.addQuestion()
        let previous = PlansServices.shared
        PlansServices.shared = fixture.services
        defer { PlansServices.shared = previous }
        let answer = PlansFixture.post(index: 40, photo: "selfie-two-friends-1x1", by: PlansFixture.me, at: PlansFixture.now)
        fixture.data.update { $0.postLookup = { media, group in media == answer.post.mediaID && group == PlansFixture.groupID ? answer : nil } }
        let context = QuestionCameraContext()
        context.prepare(QuestionCameraContext.Context(groupID: PlansFixture.groupID.rawValue, questionID: PlansFixture.questionID, text: "Q"))
        _ = context.claim(groupID: PlansFixture.groupID.rawValue)
        let file = PostDraft.File(url: URL(fileURLWithPath: "/dev/null"), contentType: "image/jpeg")
        let elsewhere = context.answering(
            PostDraft(mediaID: answer.post.mediaID, kind: .photo, original: file, groupIDs: [GroupID("other")], createdAt: PlansFixture.now)
        )
        XCTAssertNil(elsewhere.questionID, "a post to another group is not an answer")
        context.didPost(elsewhere)
        XCTAssertNotNil(context.active)
        // The draft carries the question, so the outbox links the post when it is retried too (`PostPublisher`).
        let draft = context.answering(
            PostDraft(mediaID: answer.post.mediaID, kind: .photo, original: file, groupIDs: [PlansFixture.groupID], createdAt: PlansFixture.now)
        )
        XCTAssertEqual(draft.questionID, PlansFixture.questionID)
        XCTAssertEqual(draft.questionGroupID, PlansFixture.groupID)
        try await FakeCapturePosting().publish(draft)
        context.didPost(draft)
        XCTAssertNil(context.active, "answered once")
        let later = PostDraft(kind: .photo, original: file, groupIDs: [PlansFixture.groupID], createdAt: PlansFixture.now)
        XCTAssertNil(context.answering(later).questionID, "a later capture carries no question")
        try await waitFor { fixture.data.calls.contains("answerQuestion") }
        let answers = try await fixture.data.answers(questionID: PlansFixture.questionID, groupID: PlansFixture.groupID)
        XCTAssertEqual(answers.map(\.id), [answer.id])
    }

    func testWeeklyQuestionSwitchIsTheAdmins() async {
        let member = PlansFixture()
        let memberSetting = QuestionSettingModel(groupID: PlansFixture.groupID, services: member.services)
        await memberSetting.load()
        XCTAssertFalse(memberSetting.isAdmin)

        let admin = PlansFixture(me: PlansFixture.ana)
        let setting = QuestionSettingModel(groupID: PlansFixture.groupID, services: admin.services)
        await setting.load()
        XCTAssertTrue(setting.isAdmin)
        XCTAssertFalse(setting.isOn, "off until an admin turns it on (WQ-4: the default stays the server's)")
        await setting.set(true)
        XCTAssertTrue(setting.isOn)
        admin.data.update { $0.failures["setWeeklyQuestion"] = .offline }
        await setting.set(false)
        XCTAssertTrue(setting.isOn, "a failed switch returns")
        XCTAssertEqual(setting.errorCount, 1)
    }

    // MARK: camera.overnight B

    func testDevelopingTileIsAYesOrNo() async {
        let fixture = PlansFixture()
        let tile = DevelopingTileModel(groupID: PlansFixture.groupID, services: fixture.services)
        await tile.refresh()
        XCTAssertFalse(tile.isDeveloping)
        let reveal = PlansFixture.now.addingTimeInterval(23 * PlansFixture.hour)
        fixture.data.update { $0.developing[PlansFixture.groupID] = OvernightStatus(developing: true, revealAt: reveal) }
        await tile.refresh()
        XCTAssertTrue(tile.isDeveloping)
        XCTAssertEqual(tile.accessibilityLabel, Copy.cameraOvernightTileA11y(reveal: PlanFormats.reveal(reveal)))
    }

    // MARK: Navigation

    func testPlanLinkPushesThePageOverItsGroup() {
        let router = AppRouter(parser: .init(universalLinkHosts: []))
        router.setReady(true)
        router.handle(.plan(planID: "p1", groupID: "g1"))
        XCTAssertEqual(router.path, [.group(id: "g1"), .plans(.page(planID: "p1", groupID: "g1"))])
        router.handle(.plan(planID: "p2", groupID: nil))
        XCTAssertEqual(router.path, [.plans(.page(planID: "p2", groupID: nil))])
        router.open(URL(string: "app://plan?plan=p3&group=g3")!)
        XCTAssertEqual(router.path.last, .plans(.page(planID: "p3", groupID: "g3")))
        XCTAssertEqual(AppModal.plans(.create(groupID: "g1")).presentation, .sheet)
    }

    // MARK: widget.countdown

    /// Pins the platform formatter's words in en-US (widget.countdown "The countdown line"; the same-day word "Today",
    /// shipped in every build since MERGE FV-2).
    func testCountdownWordingComesFromThePlatformFormatter() {
        let english = Locale(identifier: "en_US")
        XCTAssertEqual(PlanCountdownText.text(days: 3, locale: english), "In 3 days")
        XCTAssertEqual(PlanCountdownText.text(days: 2, locale: english), "In 2 days")
        XCTAssertEqual(PlanCountdownText.text(days: 1, locale: english), "Tomorrow")
        XCTAssertEqual(PlanCountdownText.text(days: 1, locale: english, context: .middleOfSentence), "tomorrow", "inside the accessibility label")
        XCTAssertEqual(PlanCountdownText.text(days: 0, locale: english), "Today")
        XCTAssertNil(PlanCountdownText.text(days: -1, locale: english), "a past day has no countdown")
    }

    /// A plan of today reads "… today" to VoiceOver (never a sentence ending in ", "), and the empty widget reads and
    /// shows "No plans yet" (`widget.countdown.empty.noPlans`, MERGE FV-2).
    func testCountdownLabelsOnThePlansDayAndWithNoPlans() {
        let today = PlanCountdownContent(state: .plan, title: "Dinner", groupName: "Roomies", days: 0)
        XCTAssertNotNil(today.countdown)
        XCTAssertFalse(today.accessibilityLabel.hasSuffix(", "), today.accessibilityLabel)
        XCTAssertEqual(
            today.accessibilityLabel,
            Copy.widgetCountdownA11yPlan(title: "Dinner", group: "Roomies", countdown: PlanCountdownText.text(days: 0, context: .middleOfSentence) ?? "")
        )
        let empty = PlanCountdownContent(state: .noPlans)
        XCTAssertEqual(empty.stateLine, Copy.widgetCountdownEmptyNoPlans)
        XCTAssertEqual(empty.accessibilityLabel, Copy.widgetCountdownEmptyNoPlans)
    }

    private func waitFor(_ condition: @escaping () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<200 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(condition(), file: file, line: line)
    }
}

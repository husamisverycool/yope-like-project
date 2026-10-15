// birthday.add, birthday.request, birthday.contribute — view-model tests.
@testable import App
import AppData
import DesignSystem
import XCTest

@MainActor
final class MemoryBirthdayTests: XCTestCase {
    // MARK: birthday.add — the date field (auth.agegate.layout.dateEntry)

    func testDateEntryInsertsSeparatorsInTheLocaleOrder() {
        let us = BirthdayDateEntry(pattern: "M/d/yy")
        XCTAssertEqual(us.pattern, "MM/dd/yyyy")
        XCTAssertEqual(us.format("0"), "0")
        XCTAssertEqual(us.format("052"), "05/2")
        XCTAssertEqual(us.format("05262000"), "05/26/2000")
        XCTAssertEqual(us.format("05/26/20001234"), "05/26/2000", "extra digits are dropped")
        XCTAssertEqual(us.date(from: "05/26/2000")?.description, "2000-05-26")
        XCTAssertFalse(us.isComplete("05/26/20"))
        XCTAssertNil(us.date(from: "02/30/2000"), "not a calendar day")

        let german = BirthdayDateEntry(pattern: "dd.MM.yyyy")
        XCTAssertEqual(german.format("26052000"), "26.05.2000")
        XCTAssertEqual(german.date(from: "26.05.2000")?.description, "2000-05-26")
        let iso = BirthdayDateEntry(pattern: "y-MM-dd")
        XCTAssertEqual(iso.format("20000526"), "2000-05-26")
        XCTAssertEqual(iso.date(from: "2000-05-26")?.description, "2000-05-26")
    }

    func testBirthdayDayMonthNeverShowsTheYear() {
        let text = MemoryFormat.birthdayDayMonth(LocalDate(year: 2000, month: 5, day: 26)!, locale: Locale(identifier: "en_GB"))
        XCTAssertEqual(text, "26 May")
    }

    // MARK: birthday.add — opt in / manage

    func testAddingOptsInAndCloses() async {
        let context = MemoryTestContext()
        let model = BirthdayAddModel(dependencies: context.dependencies, entry: BirthdayDateEntry(pattern: "MM/dd/yyyy"))
        await model.loadIfNeeded()
        XCTAssertEqual(model.phase, .add)
        XCTAssertFalse(model.canConfirm, "disabled until the field holds a complete date")
        model.dateText = "05/26/2000"
        XCTAssertTrue(model.canConfirm)
        await model.confirm()
        XCTAssertEqual(model.outcome, .added)
        XCTAssertEqual(context.data.snapshot.privateProfile?.birthday?.description, "2000-05-26")
        XCTAssertEqual(context.data.snapshot.privateProfile?.birthdayOptIn, true)
        XCTAssertEqual(context.haptics, [Tokens.Haptics.globalSuccess])
    }

    func testAddErrorsAreSaidInPlace() async {
        let context = MemoryTestContext()
        let model = BirthdayAddModel(dependencies: context.dependencies, entry: BirthdayDateEntry(pattern: "MM/dd/yyyy"))
        await model.loadIfNeeded()
        model.dateText = "02/30/2000"
        await model.confirm()
        XCTAssertEqual(model.inline, .invalid, "a typed day that does not exist")
        XCTAssertEqual(context.data.calls(of: .setBirthday), 0)

        model.dateText = "05/26/2000"
        context.data.fail(.setBirthday, with: .api(.invalidBirthday))
        await model.confirm()
        XCTAssertEqual(model.inline, .invalid)

        context.data.fail(.setBirthday, with: .offline)
        await model.confirm()
        XCTAssertEqual(model.inline, .offline)

        context.data.fail(.setBirthday, with: .http(status: 500))
        await model.confirm()
        XCTAssertTrue(model.showsError, "error texts above the buttons; the primary retries")
        XCTAssertNil(model.outcome)
        XCTAssertEqual(context.haptics.last, Tokens.Haptics.globalError)
    }

    func testMaybeLaterClosesWithoutACall() async {
        let context = MemoryTestContext()
        let model = BirthdayAddModel(dependencies: context.dependencies)
        await model.loadIfNeeded()
        model.later()
        XCTAssertEqual(model.outcome, .dismissed)
        XCTAssertEqual(context.data.calls(of: .setBirthday), 0)
    }

    func testOptedInShowsManageAndRemovesOptimistically() async {
        let saved = LocalDate(year: 2000, month: 5, day: 26)!
        let context = MemoryTestContext {
            $0.privateProfile = ProfilePrivate(userID: MemoryIDs.me, birthday: saved, birthdayOptIn: true, ageConfirmedAt: nil, updatedAt: MemoryTestContext.referenceNow)
        }
        let model = BirthdayAddModel(dependencies: context.dependencies)
        await model.loadIfNeeded()
        XCTAssertEqual(model.phase, .manage(saved))
        await model.remove()
        XCTAssertEqual(model.phase, .add)
        XCTAssertEqual(model.toast?.text, Copy.birthdayAddRemoved)
        XCTAssertEqual(context.data.snapshot.privateProfile?.birthdayOptIn, false)

        // Failure: the saved birthday comes back with the error.
        let failing = MemoryTestContext {
            $0.privateProfile = ProfilePrivate(userID: MemoryIDs.me, birthday: saved, birthdayOptIn: true, ageConfirmedAt: nil, updatedAt: MemoryTestContext.referenceNow)
        }
        failing.data.fail(.setBirthday, with: .http(status: 500))
        let failingModel = BirthdayAddModel(dependencies: failing.dependencies)
        await failingModel.loadIfNeeded()
        await failingModel.remove()
        XCTAssertEqual(failingModel.phase, .manage(saved))
        XCTAssertTrue(failingModel.showsError)
        XCTAssertEqual(failing.haptics, [Tokens.Haptics.globalError])
    }

    // MARK: birthday.request

    func testOpenRequestShowsTitleDueLineAndNoContribution() async {
        let context = MemoryTestContext()
        let model = BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: context.dependencies)
        await model.loadIfNeeded()
        XCTAssertEqual(model.phase, .open)
        XCTAssertEqual(model.honoreeName, "Bea")
        XCTAssertEqual(model.title, Copy.birthdayRequestTitle(name: "Bea"))
        XCTAssertEqual(model.dueText, Copy.birthdayRequestDue(date: MemoryFormat.dueDate(birthday: LocalDate(year: 2026, month: 10, day: 22)!)))
        XCTAssertNil(model.contribution)
        XCTAssertEqual(
            model.message,
            Copy.birthdayRequestBody(name: "Bea") + " " + Copy.birthdayRequestEase + " " + Copy.birthdayRequestThanks
        )
    }

    func testDueDateIsTheDayBeforeTheBirthdayInFull() {
        let text = MemoryFormat.dueDate(birthday: LocalDate(year: 2026, month: 10, day: 22)!, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(text, "Wednesday, October 21, 2026")
    }

    func testTheHonoreeNeverSeesTheirRequest() async {
        // Even if a row about the caller reached the app, neither the screen nor the group row shows it.
        let context = MemoryTestContext { state in
            state.requests = state.requests.map { request in
                var request = request
                request.honoreeID = MemoryIDs.me
                return request
            }
        }
        let model = BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: context.dependencies)
        await model.loadIfNeeded()
        XCTAssertEqual(model.phase, .notFound)
        XCTAssertTrue(model.honoreeName.isEmpty)

        let entry = BirthdayRequestsEntryModel(groupID: MemoryIDs.group, dependencies: context.dependencies)
        await entry.refresh()
        XCTAssertTrue(entry.items.isEmpty)

        let contribute = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: context.dependencies)
        await contribute.loadIfNeeded()
        XCTAssertEqual(contribute.phase, .error)
        XCTAssertTrue(contribute.photos.isEmpty)
    }

    func testGroupRowListsOpenRequestsOfThisGroupOnly() async {
        let context = MemoryTestContext()
        let entry = BirthdayRequestsEntryModel(groupID: MemoryIDs.group, dependencies: context.dependencies)
        await entry.refresh()
        XCTAssertEqual(entry.items.map(\.requestID), [MemoryIDs.request])
        XCTAssertEqual(entry.items.first?.content.title, Copy.birthdayRequestTitle(name: "Bea"))

        let elsewhere = BirthdayRequestsEntryModel(groupID: GroupID("00000000-0000-4000-8000-0000000000ff"), dependencies: context.dependencies)
        await elsewhere.refresh()
        XCTAssertTrue(elsewhere.items.isEmpty)
    }

    func testClosedAndNotFoundRequests() async {
        let closed = MemoryTestContext { state in
            state.requests = state.requests.map { request in
                var request = request
                request.dueAt = MemoryTestContext.referenceNow.addingTimeInterval(-60)
                return request
            }
        }
        let closedModel = BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: closed.dependencies)
        await closedModel.loadIfNeeded()
        XCTAssertEqual(closedModel.phase, .closed, "never 'late' or 'missed': the closed state")

        let gone = MemoryTestContext { $0.requests = [] }
        let goneModel = BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: gone.dependencies)
        await goneModel.loadIfNeeded()
        XCTAssertEqual(goneModel.phase, .notFound)

        let offline = MemoryTestContext()
        offline.data.fail(.request, with: .offline)
        let offlineModel = BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: offline.dependencies)
        await offlineModel.loadIfNeeded()
        XCTAssertEqual(offlineModel.phase, .offline)
    }

    func testOwnContributionAndOptimisticWithdraw() async {
        let context = MemoryTestContext()
        _ = try? await context.data.contribute(requestID: MemoryIDs.request, postID: MemoryIDs.post(1), line: "for every sunday")
        let model = BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: context.dependencies)
        await model.loadIfNeeded()
        XCTAssertEqual(model.contribution?.postID, MemoryIDs.post(1))
        XCTAssertEqual(model.contribution?.line, "for every sunday")
        await model.remove()
        XCTAssertNil(model.contribution)
        XCTAssertTrue(context.data.snapshot.contributions.isEmpty)
        XCTAssertEqual(context.haptics, [Tokens.Haptics.globalSuccess])

        // Failure: the block comes back with the inline line.
        _ = try? await context.data.contribute(requestID: MemoryIDs.request, postID: MemoryIDs.post(1), line: "again")
        await model.reloadContribution()
        context.data.fail(.withdraw, with: .offline)
        context.clearHaptics()
        await model.remove()
        XCTAssertEqual(model.contribution?.line, "again")
        XCTAssertEqual(model.inline, .offline)
        XCTAssertEqual(context.haptics, [Tokens.Haptics.globalError])
    }

    // MARK: birthday.contribute

    func testPickerOffersOnlyPhotosThePersonPostedOrIsSelfTaggedIn() async {
        let context = MemoryTestContext()
        let model = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: context.dependencies)
        await model.loadIfNeeded()
        XCTAssertEqual(model.phase, .loaded)
        // Own: 1, 4, 8; tagged: 2. Not: 3 (other), 5/6/7/9 (posted by others, not tagged). Newest first.
        XCTAssertEqual(model.photos.map(\.id), [MemoryIDs.post(1), MemoryIDs.post(2), MemoryIDs.post(4), MemoryIDs.post(8)])
        XCTAssertNil(model.selectedID)
        XCTAssertFalse(model.canUsePhoto)
        XCTAssertEqual(model.honoreeName, "Bea")
        XCTAssertEqual(model.groupName, "Sunday dinners")
    }

    func testThreeStepsSubmitOptimisticallyAndReplace() async {
        let context = MemoryTestContext()
        let model = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: context.dependencies)
        await model.loadIfNeeded()
        XCTAssertEqual(model.step, 1)
        model.select(MemoryIDs.post(2))
        model.select(MemoryIDs.post(2))
        XCTAssertEqual(context.haptics, [Tokens.Haptics.globalSelect], "one select haptic per change")
        model.usePhoto()
        XCTAssertEqual(model.step, 2)
        XCTAssertFalse(model.canSubmit, "disabled until the line has a non-space character")
        model.line = "   "
        XCTAssertFalse(model.canSubmit)
        model.line = "  the best laugh in the group  "
        XCTAssertTrue(model.canSubmit)
        await model.submit()
        XCTAssertEqual(model.step, 3)
        XCTAssertFalse(model.isSending)
        XCTAssertEqual(context.haptics.last, Tokens.Haptics.globalSend)
        let stored = context.data.snapshot.contributions
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.postID, MemoryIDs.post(2))
        XCTAssertEqual(stored.first?.line, "the best laugh in the group", "trimmed before sending")
        model.finish()
        XCTAssertTrue(model.isFinished)

        // "Retake" from the request: the current photo starts selected and the line is kept; sending replaces.
        let again = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: context.dependencies)
        await again.loadIfNeeded()
        XCTAssertEqual(again.selectedID, MemoryIDs.post(2))
        XCTAssertEqual(again.line, "the best laugh in the group")
        again.select(MemoryIDs.post(1))
        again.usePhoto()
        await again.submit()
        XCTAssertEqual(context.data.snapshot.contributions.map(\.postID), [MemoryIDs.post(1)], "one contribution per person")
    }

    func testSubmitFailuresRollBack() async {
        let context = MemoryTestContext()
        let model = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: context.dependencies)
        await model.loadIfNeeded()
        model.select(MemoryIDs.post(2))
        model.usePhoto()
        model.line = "hello"

        context.data.fail(.contribute, with: .offline)
        await model.submit()
        XCTAssertEqual(model.step, 2)
        XCTAssertEqual(model.inline, .offline)

        context.data.fail(.contribute, with: .http(status: 500))
        await model.submit()
        XCTAssertEqual(model.step, 2)
        XCTAssertEqual(model.inline, .error)

        // The tag was removed meanwhile: the server refuses the photo → back to step 1 with the line.
        context.data.fail(.contribute, with: nil)
        context.data.update { _ = $0.myTags.remove(MemoryIDs.post(2)) }
        await model.submit()
        XCTAssertEqual(model.step, 1)
        XCTAssertEqual(model.inline, .notEligible)
        XCTAssertEqual(context.haptics.filter { $0 == Tokens.Haptics.globalError }.count, 3)

        // Past the due time: the closed state replaces the steps.
        model.select(MemoryIDs.post(1))
        model.usePhoto()
        context.data.update { state in
            state.requests = state.requests.map { request in
                var request = request
                request.dueAt = MemoryTestContext.referenceNow.addingTimeInterval(-1)
                return request
            }
        }
        await model.submit()
        XCTAssertEqual(model.phase, .closed)
        XCTAssertEqual(model.step, 1)
    }

    func testEmptyPickerAndOpenGroup() async {
        let context = MemoryTestContext { state in
            state.posts.removeAll { $0.post.authorID == MemoryIDs.me }
            state.myTags = []
        }
        let model = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: context.dependencies)
        await model.loadIfNeeded()
        XCTAssertEqual(model.phase, .empty)
        model.openGroup()
        XCTAssertTrue(model.openGroupRequested)
        XCTAssertTrue(model.isFinished)
    }

    func testDeletedChosenPhotoGoesBackToStepOne() async {
        let context = MemoryTestContext()
        let model = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: context.dependencies)
        await model.loadIfNeeded()
        model.select(MemoryIDs.post(1))
        model.usePhoto()
        context.data.emitDeletion(postID: MemoryIDs.post(1), groupID: MemoryIDs.group)
        let dropped = await memoryEventually { !model.photos.contains { $0.id == MemoryIDs.post(1) } }
        XCTAssertTrue(dropped)
        XCTAssertNil(model.selectedID)
        XCTAssertEqual(model.step, 1)
        model.stopListening()
    }

    func testStepperEdgeInsetComesFromTheToken() {
        XCTAssertEqual(ContributeStepperMetrics.edgeInset, 11, accuracy: 0.001)
    }
}

// birthday.add, birthday.request, birthday.contribute — view-model tests.
@testable import App
import AppData
import DesignSystem
import XCTest

@MainActor
final class MemoryBirthdayTests: XCTestCase {
    // MARK: birthday.add — the date field (the auth.agegate entry, `BirthdayEntry`)

    func testDateFieldUsesTheAgeGateEntryRules() {
        let model = BirthdayAddModel(dependencies: MemoryTestContext().dependencies, entry: BirthdayEntry(pattern: "MM/dd/yyyy"))
        XCTAssertEqual(model.placeholder, Copy.authAgegateFieldPlaceholder(dateFormat: "mm/dd/yyyy"))
        model.setText("0")
        XCTAssertEqual(model.dateText, "0")
        model.setText("05262000")
        XCTAssertEqual(model.dateText, "05/26/2000", "separators inserted in the locale's order")
        XCTAssertEqual(model.typedDate?.description, "2000-05-26")
        XCTAssertTrue(model.canConfirm)
        model.setText("05/26/200")
        XCTAssertFalse(model.canConfirm, "disabled until the field holds a complete date")
    }

    func testBirthdayDayMonthNeverShowsTheYear() {
        let text = MemoryFormat.dayMonth(LocalDate(year: 2000, month: 5, day: 26)!, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(text, "May 26")
    }

    // MARK: birthday.add — opt in / manage

    func testAddingOptsInAndCloses() async {
        let context = MemoryTestContext()
        let model = BirthdayAddModel(dependencies: context.dependencies, entry: BirthdayEntry(pattern: "MM/dd/yyyy"))
        await model.loadIfNeeded()
        XCTAssertEqual(model.phase, .add)
        XCTAssertFalse(model.canConfirm, "disabled until the field holds a complete date")
        model.setText("05262000")
        XCTAssertTrue(model.canConfirm)
        await model.confirm()
        XCTAssertEqual(model.outcome, .added)
        XCTAssertEqual(context.data.snapshot.privateProfile?.birthday?.description, "2000-05-26")
        XCTAssertEqual(context.data.snapshot.privateProfile?.birthdayOptIn, true)
        XCTAssertEqual(context.haptics, [Tokens.Haptics.globalSuccess])
    }

    func testAddErrorsAreSaidInPlace() async {
        let context = MemoryTestContext()
        let model = BirthdayAddModel(dependencies: context.dependencies, entry: BirthdayEntry(pattern: "MM/dd/yyyy"))
        await model.loadIfNeeded()
        model.setText("02302000")
        await model.confirm()
        XCTAssertEqual(model.inline, .invalid, "a typed day that does not exist")
        XCTAssertEqual(context.data.calls(of: .setBirthday), 0)

        model.setText("05262000")
        context.data.fail(.setBirthday, with: .api(.invalidBirthday))
        await model.confirm()
        XCTAssertEqual(model.inline, .invalid)

        context.data.fail(.setBirthday, with: .offline)
        await model.confirm()
        XCTAssertEqual(model.inline, .offline)

        context.data.fail(.setBirthday, with: .http(status: 500))
        await model.confirm()
        XCTAssertTrue(model.showsError, "the C-27 error block above the capsule; the capsule retries")
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
        model.requestRemove()
        XCTAssertTrue(model.showsRemoveConfirmation, "asks first (native confirmation)")
        await model.remove()
        XCTAssertEqual(model.phase, .add)
        XCTAssertEqual(context.lastToast, Copy.birthdayAddRemoved)
        XCTAssertEqual(context.haptics, [Tokens.Haptics.globalWarning, Tokens.Haptics.globalSuccess])
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
        XCTAssertEqual(failing.haptics, [Tokens.Haptics.globalWarning, Tokens.Haptics.globalError])
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
        XCTAssertEqual(model.message, Copy.birthdayRequestBody(name: "Bea"))
        XCTAssertNotNil(model.avatarURL, "the honoree's photo: avatar and blurred backdrop")
    }

    func testDueDateIsTheDayBeforeTheBirthdayWithoutTheYear() {
        let text = MemoryFormat.dueDate(birthday: LocalDate(year: 2026, month: 10, day: 22)!, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(text, "Wednesday, October 21", "layout.birthday.request.dueDate: weekday, month, day — never a countdown")
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
        model.requestRemove()
        XCTAssertTrue(model.showsRemoveConfirmation, "asks first")
        await model.remove()
        XCTAssertNil(model.contribution)
        XCTAssertTrue(context.data.snapshot.contributions.isEmpty)
        XCTAssertEqual(context.haptics, [Tokens.Haptics.globalWarning, Tokens.Haptics.globalSuccess])
        XCTAssertEqual(context.lastToast, Copy.birthdayRequestRemoved)

        // Failure: the block comes back with the inline line.
        _ = try? await context.data.contribute(requestID: MemoryIDs.request, postID: MemoryIDs.post(1), line: "again")
        await model.reloadContribution()
        context.data.fail(.withdraw, with: .offline)
        context.clearHaptics()
        await model.remove()
        XCTAssertEqual(model.contribution?.line, "again")
        XCTAssertEqual(model.inline, .offline)
        XCTAssertEqual(context.haptics, [Tokens.Haptics.globalWarning, Tokens.Haptics.globalError])
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

    func testChooseComposeAndSendClosesTheSheetAndReplaces() async {
        let context = MemoryTestContext()
        let model = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: context.dependencies)
        await model.loadIfNeeded()
        XCTAssertEqual(model.step, 1)
        model.select(MemoryIDs.post(2))
        model.select(MemoryIDs.post(2))
        XCTAssertEqual(context.haptics, [Tokens.Haptics.globalSelect], "one select haptic per change")
        model.usePhoto()
        XCTAssertEqual(model.step, 2, "Next → the composer")
        XCTAssertFalse(model.canSubmit, "disabled until the line has a non-space character")
        model.editMessage()
        XCTAssertTrue(model.showsMessage, "the pill opens the 'Add a Message' modal")
        model.line = "   "
        XCTAssertFalse(model.canSubmit)
        model.line = "  the best laugh in the group  "
        XCTAssertEqual(model.counter, Copy.birthdayContributeMessageCounter(count: "31", max: "110"))
        model.doneEditing()
        XCTAssertFalse(model.showsMessage)
        XCTAssertTrue(model.canSubmit)
        await model.submit()
        XCTAssertTrue(model.didSend)
        XCTAssertTrue(model.isFinished, "sent: the sheet closes")
        XCTAssertFalse(model.isSending)
        XCTAssertEqual(context.haptics.last, Tokens.Haptics.globalSend)
        XCTAssertEqual(context.lastToast, Copy.birthdayContributeDoneTitle)
        let stored = context.data.snapshot.contributions
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.postID, MemoryIDs.post(2))
        XCTAssertEqual(stored.first?.line, "the best laugh in the group", "trimmed before sending")

        // "Change photo" from the request: the current photo starts selected and the line is kept; sending replaces.
        let again = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: context.dependencies)
        await again.loadIfNeeded()
        XCTAssertEqual(again.selectedID, MemoryIDs.post(2))
        XCTAssertEqual(again.line, "the best laugh in the group")
        again.select(MemoryIDs.post(1))
        again.usePhoto()
        await again.submit()
        XCTAssertEqual(context.data.snapshot.contributions.map(\.postID), [MemoryIDs.post(1)], "one contribution per person")
    }

    func testCancelClosesWithoutSending() async {
        let context = MemoryTestContext()
        let model = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: context.dependencies)
        await model.loadIfNeeded()
        model.finish()
        XCTAssertTrue(model.isFinished)
        XCTAssertFalse(model.didSend)
        XCTAssertEqual(context.data.calls(of: .contribute), 0)
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

    func testTheLineStaysOneLineAndStopsAtTheCharacterLimit() async {
        let context = MemoryTestContext()
        let model = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: context.dependencies)
        await model.loadIfNeeded()
        XCTAssertEqual(BirthdayContributeModel.lineMax, Int(Tokens.Layouts.BirthdayContributeLineMax.maxCharacters))
        XCTAssertEqual(BirthdayContributeModel.lineMax, 110)

        model.line = "you light up every room"
        XCTAssertFalse(model.normalizeLine(), "nothing to change")
        XCTAssertEqual(model.line, "you light up every room")

        model.line = "you light up every room\n"
        XCTAssertTrue(model.normalizeLine(), "a typed return is Done")
        XCTAssertEqual(model.line, "you light up every room")

        let limit = BirthdayContributeModel.lineMax
        model.line = String(repeating: "a", count: limit)
        model.normalizeLine()
        XCTAssertEqual(model.line.count, limit, "exactly the limit is kept")
        model.line = String(repeating: "b", count: limit + 25)
        model.normalizeLine()
        XCTAssertEqual(model.line, String(repeating: "b", count: limit), "a longer paste is cut at the limit")
        model.line = String(repeating: "🎉", count: limit + 1)
        model.normalizeLine()
        XCTAssertEqual(model.line.count, limit, "counted in characters, not bytes")
        XCTAssertEqual(model.counter, Copy.birthdayContributeMessageCounter(count: "110", max: "110"))
    }
}

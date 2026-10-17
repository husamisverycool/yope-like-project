import AppModels
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import AppData

/// Plans (docs/API.md §14.2), the weekly question (§14.4) and an overnight photo's reveal (§14.3) through AppData
/// against the local Supabase stack, as two or three members of one group.
final class PlanQuestionIntegrationTests: XCTestCase {
    private var users: TestUsers!

    override func setUp() async throws {
        try await LocalStack.require()
        users = TestUsers()
    }

    override func tearDown() async throws {
        await users?.cleanUp()
    }

    /// A group of `admin`'s (Europe/Paris) that each of `members` joined by invite.
    private func group(_ admin: TestUser, _ members: TestUser...) async throws -> PhotoGroup {
        let group = try await admin.data.groups.create(name: "Plans \(users.runID)", kind: .friends, timeZone: "Europe/Paris")
        _ = try await admin.data.groups.setInvitationPaused(groupID: group.id, paused: true)
        let invite = try await admin.data.groups.createInvite(groupID: group.id)
        for member in members {
            _ = try await member.data.groups.join(token: invite.token)
        }
        return group
    }

    func testPlanAnswersCancelRestoreAndEdit() async throws {
        let maya = try await users.make("Maya")
        let theo = try await users.make("Theo")
        let lea = try await users.make("Lea")
        let group = try await group(maya, theo, lea)

        // Maya makes a plan three days ahead: her own answer starts as Going.
        let starts = Date().addingTimeInterval(3 * 86_400)
        let plan = try await maya.data.plans.create(
            groupID: group.id,
            fields: PlanFields(title: "  Dinner at ours \(users.runID) ", startsAt: starts, allDay: false, place: "Ours")
        )
        XCTAssertEqual(plan.groupID, group.id)
        XCTAssertEqual(plan.createdBy, maya.id)
        XCTAssertEqual(plan.title, "Dinner at ours \(users.runID)", "the server trims the title")
        XCTAssertEqual(plan.place, "Ours")
        XCTAssertEqual(plan.startsAt.timeIntervalSince1970, starts.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertFalse(plan.isCanceled)
        let read = try await theo.data.plans.plan(id: plan.id)
        XCTAssertEqual(read?.id, plan.id)

        // next_plans: Theo sees it without an answer of his; Maya's says Going.
        let theoNext = try await theo.data.plans.nextPlans(groupID: group.id)
        XCTAssertEqual(theoNext.map(\.id), [plan.id])
        XCTAssertNil(theoNext.first?.myAnswer)
        let mayaNext = try await maya.data.plans.nextPlans()
        XCTAssertEqual(mayaNext.first { $0.id == plan.id }?.myAnswer, .going)

        // Theo answers Going: every member reads both answers, oldest first.
        let going = try await theo.data.plans.answer(planID: plan.id, .going)
        XCTAssertEqual(going.answer, .going)
        XCTAssertEqual(going.userID, theo.id)
        let seenByLea = try await lea.data.plans.answers(planID: plan.id)
        XCTAssertEqual(seenByLea.map(\.userID), [maya.id, theo.id])
        XCTAssertEqual(Set(seenByLea.map(\.answer)), [.going])
        let theoAgain = try await theo.data.plans.nextPlans(groupID: group.id)
        XCTAssertEqual(theoAgain.first?.myAnswer, .going)

        // Can't go replaces it, and only Theo and the plan's maker read it.
        try await theo.data.plans.answer(planID: plan.id, .cantGo)
        let leaNow = try await lea.data.plans.answers(planID: plan.id)
        XCTAssertEqual(leaNow.map(\.userID), [maya.id], "Can't go is hidden from other members")
        let mayaNow = try await maya.data.plans.answers(planID: plan.id)
        XCTAssertEqual(mayaNow.first { $0.userID == theo.id }?.answer, .cantGo)
        let theoNow = try await theo.data.plans.answers(planID: plan.id)
        XCTAssertEqual(theoNow.first { $0.userID == theo.id }?.answer, .cantGo)

        // Back to no answer, then Maybe.
        try await theo.data.plans.clearAnswer(planID: plan.id)
        let cleared = try await theo.data.plans.nextPlans(groupID: group.id)
        XCTAssertNil(cleared.first?.myAnswer)
        try await theo.data.plans.answer(planID: plan.id, .maybe)

        // Only the maker and the group's admins edit, cancel and restore.
        await assertThrows(.database(code: "PT403", message: "not_allowed")) {
            try await theo.data.plans.cancel(id: plan.id)
        }
        await assertThrows(.database(code: "PT403", message: "not_allowed")) {
            try await theo.data.plans.update(id: plan.id, fields: PlanFields(title: "Mine now", startsAt: starts, allDay: false))
        }
        let edited = try await maya.data.plans.update(
            id: plan.id,
            fields: PlanFields(title: "Dinner moved \(users.runID)", startsAt: starts.addingTimeInterval(3600), allDay: false, place: "Ours")
        )
        XCTAssertEqual(edited.title, "Dinner moved \(users.runID)")
        XCTAssertEqual(edited.startsAt.timeIntervalSince1970, starts.addingTimeInterval(3600).timeIntervalSince1970, accuracy: 0.001)

        // Canceled: the plan stays readable, leaves next_plans, and takes no answers until it is restored.
        let canceled = try await maya.data.plans.cancel(id: plan.id)
        XCTAssertTrue(canceled.isCanceled)
        XCTAssertEqual(canceled.canceledBy, maya.id)
        let afterCancel = try await theo.data.plans.nextPlans(groupID: group.id)
        XCTAssertFalse(afterCancel.contains { $0.id == plan.id })
        let stillThere = try await theo.data.plans.plan(id: plan.id)
        XCTAssertEqual(stillThere?.isCanceled, true)
        await assertThrows(.database(code: "PT409", message: "plan_canceled")) {
            try await lea.data.plans.answer(planID: plan.id, .going)
        }
        let canceledPhotos = try await theo.data.plans.photos(planID: plan.id)
        XCTAssertTrue(canceledPhotos.isEmpty)
        let restored = try await maya.data.plans.restore(id: plan.id)
        XCTAssertFalse(restored.isCanceled)
        let afterRestore = try await theo.data.plans.nextPlans(groupID: group.id)
        XCTAssertEqual(afterRestore.first { $0.id == plan.id }?.myAnswer, .maybe, "answers survive a cancel and restore")

        // Someone outside the group reads nothing.
        let outsider = try await users.make("Out")
        let outsiderRead = try await outsider.data.plans.plan(id: plan.id)
        XCTAssertNil(outsiderRead)
        let outsiderAnswers = try await outsider.data.plans.answers(planID: plan.id)
        XCTAssertTrue(outsiderAnswers.isEmpty)
    }

    /// Realtime (§14.2 "inserts and updates of both tables"): another member's plan, answer and cancel reach Maya's
    /// group subscription as `plansChanged` (her plan page and the group's plan row refetch on it).
    func testRealtimeTellsTheGroupOfPlansAndAnswers() async throws {
        try await LocalStack.requireWebSockets()
        let maya = try await users.make("Maya")
        let theo = try await users.make("Theo")
        let group = try await group(maya, theo)
        let events = EventRecorder(maya.data.realtime.events(for: group.id, filter: .changes))
        defer { events.stop() }
        let joined = await eventually { events.contains { $0 == .subscribed(topic: "realtime:group-\(group.id.rawValue)") } }
        XCTAssertTrue(joined, "\(events.events)")
        // Postgres changes need a moment after the join; probe with a chat message until one arrives.
        let ready = await eventually(timeout: 20) {
            _ = try? await theo.data.chat.sendText(groupID: group.id, body: "probe")
            try? await Task.sleep(nanoseconds: 700_000_000)
            return events.contains { if case let .messageInserted(message) = $0 { return message.body == "probe" }; return false }
        }
        XCTAssertTrue(ready, "postgres_changes never delivered: \(events.events)")
        func changes() -> Int { events.events.filter { $0 == .plansChanged }.count }

        let plan = try await theo.data.plans.create(
            groupID: group.id,
            fields: PlanFields(title: "Picnic \(users.runID)", startsAt: Date().addingTimeInterval(2 * 86_400), allDay: true)
        )
        let made = await eventually { changes() >= 1 }
        XCTAssertTrue(made, "the plan and Theo's own Going: \(events.events)")
        var seen = changes()

        _ = try await theo.data.plans.answer(planID: plan.id, .maybe)
        let answered = await eventually { changes() > seen }
        XCTAssertTrue(answered, "Theo's answer changed: \(events.events)")
        seen = changes()

        _ = try await theo.data.plans.cancel(id: plan.id)
        let canceled = await eventually { changes() > seen }
        XCTAssertTrue(canceled, "the plan was cancelled: \(events.events)")
    }

    func testWeeklyQuestionSwitchCatalogueAnswerAndRemove() async throws {
        let maya = try await users.make("Maya")
        let theo = try await users.make("Theo")
        let group = try await group(maya, theo)

        // The catalogue is an owner setting (app_config weekly_question_keys); the test sets one and puts back what
        // was there.
        let previous = try await LocalStack.config("weekly_question_keys")
        addTeardownBlock { try? await LocalStack.setConfig("weekly_question_keys", json: previous) }
        try await LocalStack.setConfig("weekly_question_keys", json: #"["question.weekly.q01", "question.weekly.q02"]"#)

        // Off by default: no question, and only an admin turns it on.
        let isOnAtFirst = try await theo.data.questions.isOn(groupID: group.id)
        XCTAssertFalse(isOnAtFirst)
        let offQuestion = try await theo.data.questions.current(groupID: group.id)
        XCTAssertNil(offQuestion)
        await assertThrows(.api(.notGroupAdmin)) {
            try await theo.data.questions.setOn(groupID: group.id, on: true)
        }
        let switched = try await maya.data.questions.setOn(groupID: group.id, on: true)
        XCTAssertEqual(switched.id, group.id)
        let isOn = try await theo.data.questions.isOn(groupID: group.id)
        XCTAssertTrue(isOn)

        // This week's question: the first key, the same row for every member.
        let current = try await theo.data.questions.current(groupID: group.id)
        let question = try XCTUnwrap(current)
        XCTAssertEqual(question.questionKey, "question.weekly.q01")
        XCTAssertFalse(question.hiddenByMe)
        let mayaQuestion = try await maya.data.questions.current(groupID: group.id)
        XCTAssertEqual(mayaQuestion?.id, question.id)

        // Theo answers with a photo from the camera: an ordinary post, linked to the question afterwards.
        let file = try temporaryFile(tinyJPEG, extension: "jpg")
        let draft = PostDraft(kind: .photo, original: .init(url: file, contentType: ContentType.jpeg), groupIDs: [group.id])
        let posted = try await theo.data.publisher.publish(draft)
        let post = try XCTUnwrap(posted.first)
        let linked = try await theo.data.questions.answer(mediaID: draft.mediaID, groupID: group.id, questionID: question.id)
        XCTAssertEqual(linked?.id, post.id)
        let answers = try await maya.data.questions.answers(questionID: question.id)
        XCTAssertEqual(answers.map(\.id), [post.id])
        let feed = try await maya.data.posts.page(groupID: group.id).items
        XCTAssertTrue(feed.contains { $0.id == post.id }, "the answer is in the group like any photo")

        // A photo taken for the question that waited in the outbox (offline, the app closed mid-send) carries the
        // question: the retry that posts it links it.
        let waitingFile = try temporaryFile(tinyJPEG, extension: "jpg")
        let waiting = try await theo.data.publisher.enqueue(PostDraft(
            kind: .photo, original: .init(url: waitingFile, contentType: ContentType.jpeg), groupIDs: [group.id],
            questionID: question.id, questionGroupID: group.id
        ))
        let retried = await theo.data.publisher.resumePending()
        let retriedPost = try XCTUnwrap(retried[waiting.mediaID]?.get().first)
        let withRetried = try await maya.data.questions.answers(questionID: question.id)
        XCTAssertEqual(Set(withRetried.map(\.id)), [post.id, retriedPost.id])

        // Only the author links their post.
        await assertThrows(.api(.postNotFound)) {
            try await maya.data.questions.answer(postID: post.id, questionID: question.id)
        }

        // Remove: gone for Maya this week, still there for Theo.
        try await maya.data.questions.hide(questionID: question.id)
        let hiddenForMaya = try await maya.data.questions.current(groupID: group.id)
        XCTAssertEqual(hiddenForMaya?.hiddenByMe, true)
        let shownForTheo = try await theo.data.questions.current(groupID: group.id)
        XCTAssertEqual(shownForTheo?.hiddenByMe, false)

        // Switched off: no question, and no new links.
        _ = try await maya.data.questions.setOn(groupID: group.id, on: false)
        let afterOff = try await theo.data.questions.current(groupID: group.id)
        XCTAssertNil(afterOff)
        await assertThrows(.database(code: "PT409", message: "question_off")) {
            try await theo.data.questions.answer(postID: post.id, questionID: question.id)
        }
    }

    /// A 9 AM photo: developing (nobody reads it, the group shows only that something develops), then the scheduler's
    /// `due_developed_posts` at its reveal time turns it into a post every member reads, stamped with the reveal.
    func testOvernightPhotoRevealsAsAPostOfTheGroup() async throws {
        let maya = try await users.make("Maya")
        let theo = try await users.make("Theo")
        let group = try await group(maya, theo)

        let file = try temporaryFile(tinyJPEG, extension: "jpg")
        let draft = PostDraft(kind: .photo, original: .init(url: file, contentType: ContentType.jpeg), width: 1, height: 1, groupIDs: [group.id], overnight: true)
        let posted = try await maya.data.publisher.publish(draft)
        XCTAssertTrue(posted.isEmpty, "nothing is posted before the reveal")
        let developing = try await theo.data.questions.developing(groupID: group.id)
        XCTAssertTrue(developing.developing)
        let reveal = try XCTUnwrap(developing.revealAt)
        let before = try await theo.data.posts.page(groupID: group.id).items
        XCTAssertFalse(before.contains { $0.mediaID == draft.mediaID })

        // What the worker's scheduler does every minute, run at the reveal time.
        _ = try await LocalStack.serviceRPC("due_developed_posts", ["p_now": Timestamp.format(reveal)])

        let after = try await theo.data.posts.page(groupID: group.id).items
        let revealedPost = try XCTUnwrap(after.first { $0.mediaID == draft.mediaID }, "the photo is in the group after the reveal")
        XCTAssertEqual(revealedPost.authorID, maya.id)
        XCTAssertEqual(revealedPost.revealedAt, reveal)
        XCTAssertLessThan(revealedPost.createdAt, reveal, "it keeps the time it was taken")
        let together = try await theo.data.posts.revealed(groupID: group.id, at: reveal)
        XCTAssertEqual(together.map(\.id), [revealedPost.id])
        let groupNow = try await theo.data.questions.developing(groupID: group.id)
        XCTAssertEqual(groupNow, .notDeveloping)
        let mineNow = try await maya.data.posts.myDeveloping()
        XCTAssertEqual(mineNow, .notDeveloping)
    }
}

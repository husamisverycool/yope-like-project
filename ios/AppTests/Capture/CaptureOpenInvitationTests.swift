// The open daily invitation answered in the app (migration 0035): camera.sendto shows each chosen group's open
// invitation with its countdown and a post sent while it is open answers it (`create_post p_invitation_ids`), as from
// the notification; groups.screen shows it as a row that opens the daily capture. Nothing marks a post sent after.
@testable import App
import AppData
import AppModels
import Foundation
import XCTest

@MainActor
final class CaptureOpenInvitationTests: XCTestCase {
    private func invitation(_ id: String, group: String, opened: TimeInterval, closesIn: TimeInterval, now: Date = Date()) -> DailyInvitation {
        DailyInvitation(
            id: InvitationID(id), groupID: GroupID(group), localDate: LocalDate(now, in: .current),
            firesAt: now.addingTimeInterval(-opened), closesAt: now.addingTimeInterval(closesIn), status: .fired, createdAt: now
        )
    }

    // MARK: camera.sendto

    func testSendAnswersEveryChosenGroupsOpenInvitation() async {
        let rig = CaptureTestRig()
        rig.groups.invitations = [
            invitation("inv-1", group: "fake-group-1", opened: 30, closesIn: 90),
            invitation("inv-2", group: "fake-group-2", opened: 10, closesIn: 110),
        ]
        let model = rig.sendToModel()
        await model.load()
        XCTAssertEqual(model.shownInvitation(for: "fake-group-1")?.id, InvitationID("inv-1"), "the row counts down")
        let seconds = try! XCTUnwrap(model.shownInvitation(for: "fake-group-2")).remainingSeconds(at: Date())
        XCTAssertNotNil(seconds)
        XCTAssertLessThanOrEqual(seconds ?? 0, 110)
        await model.send()
        let draft = try! XCTUnwrap(rig.posting.published.first)
        XCTAssertEqual(draft.invitationIDs, [InvitationID("inv-1"), InvitationID("inv-2")])
        XCTAssertNil(draft.invitationID)
    }

    func testOnlyChosenGroupsAnswerAndAClosedWindowIsAnOrdinaryPost() async {
        let rig = CaptureTestRig()
        rig.groups.invitations = [
            invitation("inv-1", group: "fake-group-1", opened: 130, closesIn: -10),
            invitation("inv-2", group: "fake-group-2", opened: 10, closesIn: 110),
        ]
        let model = rig.sendToModel(contextGroupID: "fake-group-1")
        await model.load()
        XCTAssertNil(try! XCTUnwrap(model.shownInvitation(for: "fake-group-1")).remainingSeconds(at: Date()),
                     "closed: no countdown, nothing else shown")
        XCTAssertEqual(model.answeredInvitations(at: Date()), [], "group 2 is not chosen; group 1's window closed")
        await model.send()
        XCTAssertNil(try! XCTUnwrap(rig.posting.published.first).invitationIDs, "an ordinary post, no 'late' anything")
    }

    func testAPhotoReplyAnswersNothing() async {
        let rig = CaptureTestRig()
        rig.groups.invitations = [invitation("inv-1", group: "fake-group-1", opened: 30, closesIn: 90)]
        rig.replyTarget = (groupID: "fake-group-1", postID: "post-1")
        let model = rig.sendToModel(contextGroupID: "fake-group-1")
        await model.load()
        XCTAssertNil(model.shownInvitation(for: "fake-group-1"))
        await model.send()
        let draft = try! XCTUnwrap(rig.posting.published.first)
        XCTAssertEqual(draft.replyToPostID, PostID("post-1"))
        XCTAssertNil(draft.invitationIDs)
    }

    func testNoOpenInvitationsShowNothing() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel()
        await model.load()
        XCTAssertTrue(model.openInvitations.isEmpty)
        await model.send()
        XCTAssertNil(try! XCTUnwrap(rig.posting.published.first).invitationIDs)
    }

    // MARK: groups.screen

    func testGroupScreenShowsTheOpenInvitationUntilItCloses() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup(posts: 1)
        let clock = fixture.data.clock
        fixture.data.invitationsByGroup[group.id] = invitation("inv-open", group: group.id.rawValue, opened: 20, closesIn: 100, now: clock)
        let model = GroupFeedModel(groupID: group.id, data: fixture.data, now: { clock })
        await model.refresh()
        XCTAssertEqual(model.openInvitation?.id, InvitationID("inv-open"))
        model.invitationClosed()
        XCTAssertNil(model.openInvitation)

        // closed by the next read: nothing shown, nothing said
        fixture.data.invitationsByGroup[group.id] = invitation("inv-old", group: group.id.rawValue, opened: 300, closesIn: -180, now: clock)
        await model.refresh()
        XCTAssertNil(model.openInvitation)
        model.stop()
    }
}

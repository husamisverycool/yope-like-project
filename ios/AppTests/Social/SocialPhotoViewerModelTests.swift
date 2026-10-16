// photo.viewer view model (design/surfaces/photo.viewer.md, tagging.md, chat.reactions.md).
@testable import App
import AppData
import AppModels
import Foundation
import XCTest

@MainActor
final class SocialPhotoViewerModelTests: XCTestCase {
    private func makeModel(
        _ data: FakeSocialData = SocialDemo.makeData(),
        start: PostID = SocialDemo.p2,
        ids: [PostID] = [SocialDemo.p1, SocialDemo.p2, SocialDemo.p3, SocialDemo.p4],
        showsGroupName: Bool = false
    ) -> PhotoViewerModel {
        PhotoViewerModel(
            context: PhotoViewerContext(postIDs: ids, start: start, groupID: SocialDemo.groupID, showsGroupName: showsGroupName),
            data: data
        )
    }

    func testLoadShowsThePhotoWithReactionsTagsAndComments() async {
        let data = SocialDemo.makeData()
        data.update { $0.tags = [PostTag(postID: SocialDemo.p2, userID: SocialDemo.me, groupID: SocialDemo.groupID, createdAt: SocialDemo.monday)] }
        let model = makeModel(data)
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.current?.post.caption, "first snow")
        XCTAssertEqual(model.current.flatMap(model.author)?.socialFirstName, "Ana")
        XCTAssertEqual(model.current.flatMap(model.group)?.name, "roommates")
        XCTAssertEqual(model.reactions[SocialDemo.p2]?.distinctEmoji, ["😍"])
        XCTAssertTrue(model.isCurrentTagged)
        XCTAssertEqual(model.taggedPeople(on: SocialDemo.p2), [SocialDemo.me])
        XCTAssertFalse(model.isCurrentOwn)
        XCTAssertEqual(model.currentComments.map(\.body), ["so pretty"], "replies to the photo show as comments, oldest first")
        XCTAssertEqual(model.profiles[SocialDemo.ben]?.socialFirstName, "Ben", "comment authors are loaded")
        XCTAssertNotNil(model.profiles[SocialDemo.me], "my avatar leads the reply field")
        XCTAssertEqual(model.position?.index, 2)
        XCTAssertEqual(model.position?.total, 4)
        XCTAssertEqual(model.ringFraction, 0.5, accuracy: 0.0001, "photo.viewer.layout.avatarRing: 2 of 4 draws half the circle")
        XCTAssertEqual(model.current.map(model.weekNumber), 42, "ISO week of Tue 13 Oct 2026 in the group's zone")
        XCTAssertFalse(model.showsGroupName)
    }

    func testOpenedFromAWallTheHeaderNamesTheGroup() async {
        let model = makeModel(showsGroupName: true)
        await model.load()
        XCTAssertTrue(model.showsGroupName)
        XCTAssertNil(makeModel(ids: [SocialDemo.p2]).position, "one photo: no position pill")
        XCTAssertEqual(makeModel(ids: [SocialDemo.p2]).ringFraction, 1, "one photo: the full ring")
    }

    func testTapsAdvanceAndGoBackAndCloseAfterTheLast() async {
        let model = makeModel(start: SocialDemo.p3)
        await model.load()
        model.goBack()
        XCTAssertEqual(model.selection, SocialDemo.p2)
        model.advance()
        model.advance()
        XCTAssertEqual(model.selection, SocialDemo.p4)
        XCTAssertFalse(model.isClosed)
        model.advance()
        XCTAssertTrue(model.isClosed, "past the last photo the viewer closes")

        let first = makeModel(start: SocialDemo.p1)
        await first.load()
        first.goBack()
        XCTAssertEqual(first.selection, SocialDemo.p1, "nothing before the first photo")
        XCTAssertEqual(first.neighbours.map(\.id), [SocialDemo.p2])
    }

    func testPhotosOnTheDeviceShowWithoutABlankFrameThenRefresh() async {
        let data = SocialDemo.makeData()
        data.update { state in
            state.cachedFeeds[SocialDemo.groupID] = state.posts.filter { [SocialDemo.p1, SocialDemo.p2, SocialDemo.p3].contains($0.id) }
            state.holds.insert("posts")
        }
        let model = makeModel(data)
        let task = Task { await model.load() }
        let shown = await socialEventually { model.phase == .ready }
        XCTAssertTrue(shown, "the cached photo shows while the server is asked")
        XCTAssertEqual(model.current?.id, SocialDemo.p2)

        // p3 was deleted meanwhile: the refresh marks it gone in place.
        data.update { state in
            state.posts.removeAll { $0.id == SocialDemo.p3 }
            state.holds.remove("posts")
        }
        await task.value
        XCTAssertTrue(model.gone.contains(SocialDemo.p3))
        XCTAssertEqual(model.current?.id, SocialDemo.p2)
    }

    func testRecentEmojiAreKeptNewestFirstPerDevice() {
        let flags = socialTestFlags()
        XCTAssertTrue(flags.recentEmoji().isEmpty)
        flags.recordEmoji("🔥", keep: 3)
        flags.recordEmoji("😍", keep: 3)
        flags.recordEmoji("🔥", keep: 3)
        XCTAssertEqual(flags.recentEmoji(), ["🔥", "😍"])
        flags.recordEmoji("😂", keep: 2)
        XCTAssertEqual(flags.recentEmoji(), ["😂", "🔥"])
    }

    func testPagingLoadsTheTagStateOfTheNewPhoto() async {
        let data = SocialDemo.makeData()
        data.update { $0.tags = [PostTag(postID: SocialDemo.p4, userID: SocialDemo.me, groupID: SocialDemo.groupID, createdAt: SocialDemo.monday)] }
        let model = makeModel(data)
        await model.load()
        XCTAssertFalse(model.isCurrentTagged)
        await model.select(SocialDemo.p4)
        XCTAssertEqual(model.selection, SocialDemo.p4)
        XCTAssertTrue(model.isCurrentTagged)
        XCTAssertTrue(model.currentComments.isEmpty)
    }

    func testMissingPhotoShowsGone() async {
        let missing = PostID("00000000-0000-4000-8000-00000000c0ff")
        let model = makeModel(start: missing, ids: [missing, SocialDemo.p1])
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertTrue(model.isCurrentGone)
    }

    func testLoadFailureStates() async {
        let failing = SocialDemo.makeData()
        failing.update { $0.mode = .failing }
        let failed = makeModel(failing)
        await failed.load()
        XCTAssertEqual(failed.phase, .failed)

        let offline = SocialDemo.makeData()
        offline.update { $0.mode = .offline }
        let model = makeModel(offline)
        await model.load()
        XCTAssertEqual(model.phase, .offline)

        let cached = SocialDemo.makeData()
        cached.update { state in
            state.mode = .offline
            state.cachedFeeds[SocialDemo.groupID] = SocialDemo.posts.filter { $0.post.groupID == SocialDemo.groupID }
        }
        let fromCache = makeModel(cached)
        await fromCache.load()
        XCTAssertEqual(fromCache.phase, .ready, "offline: the cached image shows")
        XCTAssertTrue(fromCache.isOffline)
    }

    // MARK: Tagging

    func testTagToggleIsOptimisticAndPersists() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        await model.toggleTag()
        XCTAssertTrue(model.isCurrentTagged)
        XCTAssertEqual(model.signals.feedback?.kind, .select)
        XCTAssertTrue(data.read { $0.tags }.contains { $0.postID == SocialDemo.p2 && $0.userID == SocialDemo.me })
        await model.toggleTag()
        XCTAssertFalse(model.isCurrentTagged)
        XCTAssertFalse(data.read { $0.tags }.contains { $0.postID == SocialDemo.p2 })
    }

    func testTagFailureRevertsWithItsLine() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        data.update { $0.failOnce.insert("setTagged") }
        await model.toggleTag()
        XCTAssertFalse(model.isCurrentTagged)
        XCTAssertEqual(model.signals.notice?.notice, .tagError)
        XCTAssertEqual(model.signals.feedback?.kind, .failed)
        XCTAssertTrue(model.tagPending.isEmpty)

        await model.toggleTag()
        XCTAssertTrue(model.isCurrentTagged)
        data.update { $0.failOnce.insert("setTagged") }
        await model.toggleTag()
        XCTAssertTrue(model.isCurrentTagged, "a failed removal keeps me tagged")
        XCTAssertEqual(model.signals.notice?.notice, .tagRemoveError)
    }

    func testOtherPeoplesTagsStayWhenITagMyself() async {
        let data = SocialDemo.makeData()
        data.update { $0.tags = [SocialDemo.tag(SocialDemo.p2, SocialDemo.ben, minutes: 1), SocialDemo.tag(SocialDemo.p2, SocialDemo.cleo, minutes: 2)] }
        let model = makeModel(data)
        await model.load()
        XCTAssertEqual(model.taggedPeople(on: SocialDemo.p2), [SocialDemo.ben, SocialDemo.cleo])
        await model.toggleTag()
        XCTAssertEqual(model.taggedPeople(on: SocialDemo.p2), [SocialDemo.ben, SocialDemo.cleo, SocialDemo.me], "I am added at the end of the run")
        await model.toggleTag()
        XCTAssertEqual(model.taggedPeople(on: SocialDemo.p2), [SocialDemo.ben, SocialDemo.cleo])
    }

    func testTagOnAGonePhotoAndOffline() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        data.update { $0.notFoundOnce.insert("setTagged") }
        await model.toggleTag()
        XCTAssertEqual(model.signals.notice?.notice, .tagNotFound)
        XCTAssertTrue(model.isCurrentGone)

        let offlineData = SocialDemo.makeData()
        let offline = makeModel(offlineData, start: SocialDemo.p1)
        await offline.load()
        offlineData.setNetwork(.offline)
        let task = Task { await offline.run() }
        defer { task.cancel() }
        _ = await socialEventually { offline.isOffline }
        await offline.toggleTag()
        XCTAssertFalse(offline.isCurrentTagged, "offline: the toggle does not change")
        XCTAssertEqual(offline.signals.notice?.notice, .tagOffline)
        XCTAssertFalse(offlineData.read { $0.calls }.contains("setTagged"))
    }

    // MARK: Reactions

    func testQuickReactionAndRollbackWithoutNumbers() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        await model.react("🔥")
        XCTAssertEqual(model.reactions[SocialDemo.p2]?.distinctEmoji, ["🔥", "😍"], "newest first")

        data.update { $0.failOnce.insert("react") }
        await model.react("💖")
        XCTAssertEqual(model.reactions[SocialDemo.p2]?.distinctEmoji, ["🔥", "😍"])
        XCTAssertEqual(model.signals.notice?.notice, .reactionFailed)
        XCTAssertFalse(model.reactions[SocialDemo.p2]!.distinctEmoji.joined().socialContainsDigit)

        // Taking it back from the picker (`chat.reactions.layout.unreact`).
        XCTAssertEqual(model.myEmojiOnCurrent, ["🔥"])
        await model.unreact("🔥")
        XCTAssertEqual(model.reactions[SocialDemo.p2]?.distinctEmoji, ["😍"])
        XCTAssertTrue(model.myEmojiOnCurrent.isEmpty)

        // The context menu's quick row toggles.
        await model.toggleReaction("😍")
        XCTAssertEqual(model.myEmojiOnCurrent, ["😍"])
        await model.toggleReaction("😍")
        XCTAssertTrue(model.myEmojiOnCurrent.isEmpty)
        XCTAssertEqual(model.reactions[SocialDemo.p2]?.distinctEmoji, ["😍"], "Ben's stays")
    }

    func testRealtimeReactionsAndDeletion() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        await model.handle(.reactionInserted(SocialDemo.reaction(SocialDemo.p2, SocialDemo.cleo, "🥰", minutes: 3000)))
        XCTAssertEqual(model.reactions[SocialDemo.p2]?.distinctEmoji, ["🥰", "😍"])
        await model.handle(.postDeleted(postID: SocialDemo.p2, mediaID: SocialDemo.mediaID(SocialDemo.p2)))
        XCTAssertTrue(model.isCurrentGone, "post_deleted while open: the gone state")
    }

    // MARK: Menu

    func testDeleteEverywhereMovesToTheNextPhotoOrCloses() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data, start: SocialDemo.p3)
        await model.load()
        XCTAssertTrue(model.isCurrentOwn)
        await model.deleteCurrent()
        XCTAssertEqual(data.read { $0.deletedMedia }, [SocialDemo.mediaID(SocialDemo.p3)])
        XCTAssertFalse(data.read { $0.posts }.contains { $0.post.mediaID == SocialDemo.mediaID(SocialDemo.p3) }, "gone from every group")
        XCTAssertEqual(model.selection, SocialDemo.p4)
        XCTAssertEqual(model.signals.notice?.notice, .photoDeleted)
        XCTAssertEqual(model.signals.feedback?.kind, .warning)

        let last = makeModel(SocialDemo.makeData(), start: SocialDemo.p3, ids: [SocialDemo.p3])
        await last.load()
        await last.deleteCurrent()
        XCTAssertTrue(last.isClosed)
    }

    func testOthersPhotosAreNeverDeleted() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        await model.deleteCurrent()
        XCTAssertTrue(data.read { $0.deletedMedia }.isEmpty)
    }

    func testDeleteFailurePutsThePhotoBack() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data, start: SocialDemo.p3)
        await model.load()
        let order = model.postIDs
        data.update { $0.failOnce.insert("deleteMedia") }
        await model.deleteCurrent()
        XCTAssertEqual(model.postIDs, order)
        XCTAssertEqual(model.selection, SocialDemo.p3)
        XCTAssertNotNil(model.current)
        XCTAssertFalse(model.isClosed)
        XCTAssertEqual(model.signals.notice?.notice, .deleteFailed)
    }

    func testSaveAndPermissionDenied() async {
        // My own Live Photo (p4 re-authored as mine for this test).
        let data = SocialDemo.makeData()
        data.update { state in
            state.posts = state.posts.map { item in
                item.post.id == SocialDemo.p4
                    ? SocialDemo.post(SocialDemo.p4, by: SocialDemo.me, at: item.post.createdAt, kind: .livePhoto)
                    : item
            }
        }
        let model = makeModel(data, start: SocialDemo.p4)
        await model.load()
        XCTAssertTrue(model.isCurrentOwn)
        let saver = RecordingPhotoSaver()
        await model.saveCurrent(using: saver)
        XCTAssertEqual(saver.savedCount, 1)
        XCTAssertNotNil(saver.lastMotionURL, "a Live Photo saves its motion too")
        XCTAssertEqual(model.signals.notice?.notice, .photoSaved)
        XCTAssertEqual(model.signals.feedback?.kind, .success)

        await model.saveCurrent(using: RecordingPhotoSaver(denied: true))
        XCTAssertTrue(model.saveDenied, "denied: the inline permission card")
    }

    /// Owner decision 12: a photo leaves the app only when it is your own.
    func testOthersPhotosAreNeverSaved() async {
        let model = makeModel(start: SocialDemo.p4)
        await model.load()
        XCTAssertFalse(model.isCurrentOwn, "Cleo's Live Photo")
        let saver = RecordingPhotoSaver()
        await model.saveCurrent(using: saver)
        XCTAssertEqual(saver.savedCount, 0)
        XCTAssertNil(model.signals.notice)
        XCTAssertFalse(model.saveDenied)
    }

    func testBlockingTheAuthorRemovesTheirPhotos() async throws {
        let data = SocialDemo.makeData()
        let model = makeModel(data, start: SocialDemo.p1)
        await model.load()
        try await model.blockAuthor(SocialDemo.ben)
        XCTAssertEqual(data.read { $0.blocked }, [SocialDemo.ben])
        model.authorBlocked(SocialDemo.ben)
        XCTAssertFalse(model.postIDs.contains(SocialDemo.p1))
        XCTAssertEqual(model.selection, SocialDemo.p2, "the viewer moves on to the next photo")

        data.update { $0.failOnce.insert("block") }
        do {
            try await model.blockAuthor(SocialDemo.ana)
            XCTFail("a failed block throws so the dialog shows safety.block.error")
        } catch {}
    }

    // MARK: Reply

    func testReplyIsSentToTheGroupChatWithTheReplyTarget() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        model.replyDraft = "love this"
        await model.sendReply()
        let sent = data.read { $0.messages.last }
        XCTAssertEqual(sent?.body, "love this")
        XCTAssertEqual(sent?.replyToPostID, SocialDemo.p2)
        XCTAssertEqual(sent?.groupID, SocialDemo.groupID)
        XCTAssertEqual(model.replyDraft, "")
        XCTAssertEqual(model.signals.feedback?.kind, .sent)

        data.update { $0.failOnce.insert("sendText") }
        model.replyDraft = "again"
        await model.sendReply()
        XCTAssertEqual(model.replyDraft, "again")
        XCTAssertEqual(model.signals.notice?.notice, .sendFailed)
        XCTAssertEqual(model.currentComments.last?.body, "love this", "the sent reply shows as a comment")
    }

    // MARK: Comments

    func testRealtimeCommentsArriveAndGo() async {
        let model = makeModel()
        await model.load()
        let comment = SocialDemo.message(95, by: SocialDemo.cleo, at: SocialDemo.monday.addingTimeInterval(2 * SocialDemo.day), text: "wow", replyTo: SocialDemo.p2)
        await model.handle(.messageInserted(comment))
        await model.handle(.messageInserted(comment))
        XCTAssertEqual(model.currentComments.map(\.body), ["so pretty", "wow"])
        XCTAssertEqual(model.profiles[SocialDemo.cleo]?.socialFirstName, "Cleo")
        await model.handle(.messageDeleted(comment.id))
        XCTAssertEqual(model.currentComments.map(\.body), ["so pretty"])
        let unrelated = SocialDemo.message(96, by: SocialDemo.cleo, at: SocialDemo.monday, text: "hi")
        await model.handle(.messageInserted(unrelated))
        XCTAssertEqual(model.currentComments.count, 1, "messages that do not reply to the photo are not comments")
    }

    func testUnsendingMyCommentIsOptimistic() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        model.replyDraft = "mine"
        await model.sendReply()
        let mine = try! XCTUnwrap(model.currentComments.last)
        data.update { $0.failOnce.insert("deleteMessage") }
        await model.deleteComment(mine)
        XCTAssertTrue(model.currentComments.contains { $0.id == mine.id }, "put back when the call fails")
        XCTAssertEqual(model.signals.feedback?.kind, .failed)
        await model.deleteComment(mine)
        XCTAssertFalse(model.currentComments.contains { $0.id == mine.id })
        let theirs = try! XCTUnwrap(model.currentComments.first)
        await model.deleteComment(theirs)
        XCTAssertTrue(model.currentComments.contains { $0.id == theirs.id }, "only my own comments")
        model.copied()
        XCTAssertEqual(model.signals.notice?.notice, .copied)
    }

    func testCommentsLoadingIsHeldWithoutBlockingThePhoto() async {
        let data = SocialDemo.makeData()
        data.update { $0.holds.insert("replies") }
        let model = makeModel(data)
        let task = Task { await model.load() }
        let ready = await socialEventually { model.phase == .ready && model.reactions[SocialDemo.p2] != nil }
        XCTAssertTrue(ready)
        XCTAssertTrue(model.currentComments.isEmpty)
        data.update { $0.holds.remove("replies") }
        await task.value
        XCTAssertEqual(model.currentComments.count, 1)
    }
}

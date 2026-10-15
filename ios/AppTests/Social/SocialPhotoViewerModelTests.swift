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
        flags: SocialFlags? = nil,
        name: String = #function
    ) -> PhotoViewerModel {
        PhotoViewerModel(
            context: PhotoViewerContext(postIDs: ids, start: start, groupID: SocialDemo.groupID),
            data: data,
            flags: flags ?? socialTestFlags(name)
        )
    }

    func testLoadShowsThePhotoWithReactionsTagAndCoach() async {
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
        XCTAssertFalse(model.isCurrentOwn)
        XCTAssertTrue(model.coachVisible, "first photo someone else posted: the coach shows")
    }

    func testCoachShowsOncePerAccountAndNeverOnOwnPhotos() async {
        let flags = socialTestFlags()
        let own = makeModel(start: SocialDemo.p3, flags: flags)
        await own.load()
        XCTAssertFalse(own.coachVisible)

        let first = makeModel(flags: flags)
        await first.load()
        XCTAssertTrue(first.coachVisible)
        first.dismissCoach()
        XCTAssertFalse(first.coachVisible)

        let second = makeModel(flags: flags)
        await second.load()
        XCTAssertFalse(second.coachVisible, "dismissed for good")
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
        XCTAssertTrue(model.coachVisible)
        await model.toggleTag()
        XCTAssertTrue(model.isCurrentTagged)
        XCTAssertFalse(model.coachVisible, "a tap on the toggle dismisses the coach")
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
        XCTAssertEqual(model.reactions[SocialDemo.p2]?.distinctEmoji, ["😍", "🔥"])
        XCTAssertEqual(model.sentReaction?.emoji, "🔥")

        data.update { $0.failOnce.insert("react") }
        await model.react("💖")
        XCTAssertEqual(model.reactions[SocialDemo.p2]?.distinctEmoji, ["😍", "🔥"])
        XCTAssertEqual(model.signals.notice?.notice, .reactionFailed)
        XCTAssertFalse(model.reactions[SocialDemo.p2]!.distinctEmoji.joined().socialContainsDigit)
    }

    func testRealtimeReactionsAndDeletion() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        await model.handle(.reactionInserted(SocialDemo.reaction(SocialDemo.p2, SocialDemo.cleo, "🥰", minutes: 3000)))
        XCTAssertEqual(model.reactions[SocialDemo.p2]?.distinctEmoji, ["😍", "🥰"])
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
        let model = makeModel(start: SocialDemo.p4)
        await model.load()
        let saver = RecordingPhotoSaver()
        await model.saveCurrent(using: saver)
        XCTAssertEqual(saver.savedCount, 1)
        XCTAssertNotNil(saver.lastMotionURL, "a Live Photo saves its motion too")
        XCTAssertEqual(model.signals.notice?.notice, .photoSaved)
        XCTAssertEqual(model.signals.feedback?.kind, .success)

        await model.saveCurrent(using: RecordingPhotoSaver(denied: true))
        XCTAssertTrue(model.saveDenied, "denied: the inline permission card")
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
    }
}

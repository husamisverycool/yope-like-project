// chat.thread / chat.composer / chat.voice / chat.reactions view model (design/surfaces/chat.*.md "States").
@testable import App
import AppData
import AppModels
import Foundation
import XCTest

@MainActor
final class SocialChatThreadModelTests: XCTestCase {
    private func makeModel(_ data: FakeSocialData = SocialDemo.makeData(), focus: MessageID? = nil) -> ChatThreadModel {
        ChatThreadModel(groupID: SocialDemo.groupID, focusMessageID: focus, data: data)
    }

    // MARK: States

    func testLoadShowsNewestPageOldestFirstWithPostsAndPeople() async {
        let model = makeModel()
        XCTAssertEqual(model.phase, .loading)
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.messages.map(\.id), SocialDemo.messages.map(\.id))
        XCTAssertEqual(model.photoPostIDs, [SocialDemo.p1, SocialDemo.p2, SocialDemo.p3, SocialDemo.p4])
        XCTAssertNotNil(model.posts[SocialDemo.p2]?.media)
        XCTAssertEqual(model.profile(SocialDemo.ana)?.socialFirstName, "Ana")
        XCTAssertEqual(model.group?.name, "roommates")
        XCTAssertFalse(model.hasOlder)
        XCTAssertEqual(model.latestRecapID, SocialDemo.recapID, "film-strip circle opens the latest ready recap")
    }

    func testEmptyThreadNamesCreatorAndAddedMembers() async {
        let model = makeModel(SocialDemo.makeEmptyData(creator: SocialDemo.ana))
        await model.load()
        XCTAssertEqual(model.phase, .empty)
        XCTAssertFalse(model.viewerCreatedGroup)
        XCTAssertEqual(model.creatorFirstName, "Ana")
        XCTAssertEqual(model.addedMemberNames, ["Sam", "Ben"])
        XCTAssertNil(model.latestRecapID, "no recap: the film-strip circle is hidden")
    }

    func testEmptyThreadCreatedByViewer() async {
        let model = makeModel(SocialDemo.makeEmptyData(creator: SocialDemo.me))
        await model.load()
        XCTAssertEqual(model.phase, .empty)
        XCTAssertTrue(model.viewerCreatedGroup)
    }

    func testErrorWhenNothingCached() async {
        let data = SocialDemo.makeData()
        data.update { $0.mode = .failing }
        let model = makeModel(data)
        await model.load()
        XCTAssertEqual(model.phase, .failed)
        XCTAssertFalse(model.isOffline)

        data.update { $0.mode = .normal }
        await model.retry()
        XCTAssertEqual(model.phase, .ready)
    }

    func testOfflineWithNothingCached() async {
        let data = SocialDemo.makeData()
        data.update { $0.mode = .offline }
        let model = makeModel(data)
        await model.load()
        XCTAssertEqual(model.phase, .offline)
        XCTAssertTrue(model.isOffline)
    }

    func testOfflineShowsCachedMessages() async {
        let data = SocialDemo.makeData()
        data.update { state in
            state.mode = .offline
            state.cachedMessages[SocialDemo.groupID] = Array(SocialDemo.messages.prefix(4).reversed())
            state.cachedFeeds[SocialDemo.groupID] = SocialDemo.posts.filter { $0.id == SocialDemo.p1 }
        }
        let model = makeModel(data)
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertTrue(model.isOffline)
        XCTAssertEqual(model.messages.map(\.id), SocialDemo.messages.prefix(4).map(\.id), "cached newest-first page shown oldest first")
        XCTAssertNotNil(model.posts[SocialDemo.p1], "photo messages use the cached feed copy")
    }

    // MARK: Pagination

    func testPaginationLoadsOlderPagesUntilTheStart() async {
        let data = SocialDemo.makeData()
        data.update { $0.messagePageSize = 4 }
        let model = makeModel(data)
        await model.load()
        XCTAssertEqual(model.messages.count, 4)
        XCTAssertTrue(model.hasOlder)
        XCTAssertEqual(model.messages.last?.id, SocialDemo.messages.last?.id, "newest page first")

        await model.loadOlder()
        XCTAssertEqual(model.messages.count, 8)
        XCTAssertTrue(model.hasOlder)

        await model.loadOlder()
        XCTAssertEqual(model.messages.map(\.id), SocialDemo.messages.map(\.id))
        XCTAssertFalse(model.hasOlder)

        await model.loadOlder()
        XCTAssertEqual(model.messages.count, SocialDemo.messages.count, "no request past the first message")
    }

    func testRefreshKeepsOlderPagesAndReplacesTheNewest() async {
        let data = SocialDemo.makeData()
        data.update { $0.messagePageSize = 4 }
        let model = makeModel(data)
        await model.load()
        await model.loadOlder()
        data.update { $0.messages.removeAll { $0.id == SocialDemo.messages[8].id } }
        await model.refresh()
        XCTAssertEqual(model.messages.map(\.id), SocialDemo.messages[1...7].map(\.id), "older pages stay, the deleted newest message is gone")
        XCTAssertFalse(model.messages.contains { $0.id == SocialDemo.messages[8].id })
    }

    // MARK: Realtime

    func testRealtimeInsertAppendsOnceAndAnnouncesOthers() async {
        let model = makeModel()
        await model.load()
        let incoming = SocialDemo.message(20, by: SocialDemo.cleo, at: SocialDemo.monday.addingTimeInterval(5 * SocialDemo.day), text: "home!")
        await model.handle(.messageInserted(incoming))
        await model.handle(.messageInserted(incoming))
        XCTAssertEqual(model.messages.last?.id, incoming.id)
        XCTAssertEqual(model.messages.filter { $0.id == incoming.id }.count, 1)
        XCTAssertEqual(model.arrival?.id, incoming.id)

        let mine = SocialDemo.message(21, by: SocialDemo.me, at: SocialDemo.monday.addingTimeInterval(6 * SocialDemo.day), text: "hi")
        await model.handle(.messageInserted(mine))
        XCTAssertEqual(model.arrival?.id, incoming.id, "my own messages are not announced")
    }

    func testRealtimeInsertIntoEmptyThreadLeavesEmptyState() async {
        let data = SocialDemo.makeEmptyData()
        let model = makeModel(data)
        await model.load()
        XCTAssertEqual(model.phase, .empty)
        await model.handle(.messageInserted(SocialDemo.message(30, by: SocialDemo.ana, at: SocialDemo.monday, text: "hello")))
        XCTAssertEqual(model.phase, .ready)
    }

    func testRealtimeMessageDeletionRemovesIt() async {
        let model = makeModel()
        await model.load()
        let target = SocialDemo.messages[0].id
        await model.handle(.messageDeleted(target))
        XCTAssertFalse(model.messages.contains { $0.id == target })
    }

    func testPostDeletedRemovesPhotoMessageAndStripsQuotes() async {
        let model = makeModel()
        await model.load()
        XCTAssertEqual(model.messages.first { $0.body == "so pretty" }?.replyToPostID, SocialDemo.p2)
        await model.handle(.postDeleted(postID: SocialDemo.p2, mediaID: SocialDemo.mediaID(SocialDemo.p2)))
        XCTAssertFalse(model.messages.contains { $0.postID == SocialDemo.p2 })
        XCTAssertNil(model.messages.first { $0.body == "so pretty" }?.replyToPostID, "the reply stays without its quote")
        XCTAssertNil(model.posts[SocialDemo.p2])
        XCTAssertNil(model.reactions[SocialDemo.p2])
    }

    func testReactionInsertIsDedupedAndChangesRefetch() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        XCTAssertEqual(model.reactions[SocialDemo.p1]?.distinctEmoji, ["🔥", "💖"])
        await model.handle(.reactionInserted(SocialDemo.reaction(SocialDemo.p1, SocialDemo.ana, "🔥", minutes: 70)))
        XCTAssertEqual(model.reactions[SocialDemo.p1]?.rows.filter { $0.userID == SocialDemo.ana }.count, 1)

        await model.handle(.reactionInserted(SocialDemo.reaction(SocialDemo.p1, SocialDemo.ben, "😂", minutes: 90)))
        XCTAssertEqual(model.reactions[SocialDemo.p1]?.distinctEmoji, ["🔥", "💖", "😂"])

        data.update { $0.reactions.removeAll { $0.postID == SocialDemo.p1 && $0.emoji == "🔥" } }
        await model.handle(.reactionsChanged(SocialDemo.p1))
        XCTAssertEqual(model.reactions[SocialDemo.p1]?.distinctEmoji, ["💖"], "reactions_changed refetches that post")
    }

    func testRunDeliversRealtimeEventsAndReconnectRefetches() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        let task = Task { await model.run() }
        defer { task.cancel() }
        let subscribed = await socialEventually { data.subscriberCount > 0 }
        XCTAssertTrue(subscribed)

        let incoming = SocialDemo.message(40, by: SocialDemo.ben, at: SocialDemo.monday.addingTimeInterval(5 * SocialDemo.day), text: "on my way")
        data.emit(.messageInserted(incoming), groupID: SocialDemo.groupID)
        let arrived = await socialEventually { model.messages.last?.id == incoming.id }
        XCTAssertTrue(arrived)

        data.emit(.postDeleted(postID: SocialDemo.p1, mediaID: nil), groupID: SocialDemo.groupID)
        let removed = await socialEventually { !model.messages.contains { $0.postID == SocialDemo.p1 } }
        XCTAssertTrue(removed)

        // Missed while disconnected: a message the server has but realtime never delivered.
        let missed = SocialDemo.message(41, by: SocialDemo.cleo, at: SocialDemo.monday.addingTimeInterval(6 * SocialDemo.day), text: "missed")
        data.update { $0.messages.append(missed) }
        data.emit(.resubscribed, groupID: SocialDemo.groupID)
        let refetched = await socialEventually { model.messages.contains { $0.id == missed.id } }
        XCTAssertTrue(refetched)
    }

    func testComingBackOnlineRefetches() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        await model.setNetwork(.offline)
        XCTAssertTrue(model.isOffline)
        let late = SocialDemo.message(50, by: SocialDemo.ana, at: SocialDemo.monday.addingTimeInterval(7 * SocialDemo.day), text: "back")
        data.update { $0.messages.append(late) }
        await model.setNetwork(.online)
        XCTAssertFalse(model.isOffline)
        XCTAssertEqual(model.messages.last?.id, late.id)
    }

    // MARK: No counts

    func testReactionsAreNeverCounted() async {
        let data = SocialDemo.makeData()
        data.update { state in
            for (index, user) in [SocialDemo.ana, SocialDemo.ben, SocialDemo.cleo, SocialDemo.me].enumerated() {
                state.reactions.append(SocialDemo.reaction(SocialDemo.p4, user, "🔥", minutes: Double(200 + index)))
            }
        }
        let model = makeModel(data)
        await model.load()
        let summary = model.reactions[SocialDemo.p4]
        XCTAssertEqual(summary?.distinctEmoji, ["🔥"], "one sticker per distinct emoji, however many people sent it")
        XCTAssertFalse(summary?.distinctEmoji.joined().socialContainsDigit ?? true)
        XCTAssertFalse(data.read { $0.calls }.contains { $0.lowercased().contains("count") }, "no count is ever requested")
    }

    // MARK: Composer

    func testSendingTextAppendsTheMessageAndPlaysSend() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        model.draft = "  dinner at 8  "
        await model.sendDraft()
        XCTAssertEqual(model.messages.last?.body, "dinner at 8")
        XCTAssertEqual(model.messages.last?.authorID, SocialDemo.me)
        XCTAssertEqual(model.draft, "")
        XCTAssertEqual(model.signals.feedback?.kind, .sent)
        XCTAssertEqual(data.read { $0.messages.last?.body }, "dinner at 8")
    }

    func testOptimisticMessageIsShownWhileSendingAndReplacedOnce() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        // The server echo arrives through realtime before the RPC returns.
        data.update { state in
            state.beforeSendReturns = { message in
                await MainActor.run {
                    XCTAssertTrue(model.messages.contains { model.isPending($0) && $0.body == message.body }, "shown before the server answers")
                }
                await model.handle(.messageInserted(message))
            }
        }
        model.draft = "on my way"
        await model.sendDraft()
        XCTAssertEqual(model.messages.filter { $0.body == "on my way" }.count, 1)
        XCTAssertTrue(model.pending.isEmpty)
        XCTAssertFalse(model.messages.last.map(model.isPending) ?? true)
        XCTAssertFalse(model.isSending)
    }

    func testOptimisticVoiceMessageKeepsItsLocalFile() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        let file = URL(fileURLWithPath: "/tmp/voice.m4a")
        await model.sendVoice(fileURL: file, durationMs: 4200)
        let sent = try! XCTUnwrap(model.messages.last)
        XCTAssertFalse(model.isPending(sent))
        XCTAssertEqual(model.localVoiceFiles[sent.id], file, "playable from the recording, no download")

        data.update { $0.failOnce.insert("sendVoice") }
        let before = model.messages.count
        await model.sendVoice(fileURL: file, durationMs: 1000)
        XCTAssertEqual(model.messages.count, before, "rolled back")
        XCTAssertEqual(model.signals.notice?.notice, .sendFailed)
    }

    func testNoLoadingHUDWhenACachedCopyExists() async {
        let data = SocialDemo.makeData()
        data.update { $0.cachedMessages[SocialDemo.groupID] = SocialDemo.messages.reversed() }
        let model = makeModel(data)
        XCTAssertFalse(model.showsLoading, "nothing drawn before the cache was checked")
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertFalse(model.showsLoading)

        let uncached = makeModel(SocialDemo.makeData())
        XCTAssertFalse(uncached.showsLoading)
    }

    func testFailedDeleteIsPutBack() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        let mine = try! XCTUnwrap(model.messages.first { $0.body == "yes please" })
        let order = model.messages.map(\.id)
        data.update { $0.failOnce.insert("deleteMessage") }
        await model.delete(mine)
        XCTAssertEqual(model.messages.map(\.id), order)
        XCTAssertEqual(model.signals.feedback?.kind, .failed)
    }

    func testBlankDraftIsNotSent() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        model.draft = " \n "
        await model.sendDraft()
        XCTAssertFalse(data.read { $0.calls }.contains("sendText"))
    }

    func testSendFailureKeepsTheTextAndAnnouncesIt() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        data.update { $0.failOnce.insert("sendText") }
        model.draft = "dinner at 8"
        await model.sendDraft()
        XCTAssertEqual(model.draft, "dinner at 8")
        XCTAssertEqual(model.signals.feedback?.kind, .failed)
        XCTAssertEqual(model.signals.notice?.notice, .sendFailed)
        XCTAssertFalse(model.messages.contains { $0.body == "dinner at 8" })
    }

    func testOfflineSendFailsAndMarksOffline() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        data.update { $0.mode = .offline }
        model.draft = "later"
        await model.sendDraft()
        XCTAssertTrue(model.isOffline)
        XCTAssertEqual(model.signals.notice?.notice, .sendFailed)
    }

    func testVoiceMessageIsUploadedAndSent() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        await model.sendVoice(fileURL: URL(fileURLWithPath: "/tmp/voice.m4a"), durationMs: 4200)
        XCTAssertEqual(model.messages.last?.kind, .voice)
        XCTAssertEqual(model.messages.last?.voiceDurationMs, 4200)
        XCTAssertEqual(model.signals.feedback?.kind, .sent)
    }

    // MARK: Delete and react

    func testDeletingMyMessage() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        let mine = try! XCTUnwrap(model.messages.first { $0.body == "yes please" })
        await model.delete(mine)
        XCTAssertFalse(model.messages.contains { $0.id == mine.id })
        XCTAssertEqual(model.signals.feedback?.kind, .warning)
        XCTAssertFalse(data.read { $0.messages }.contains { $0.id == mine.id })
    }

    func testOthersMessagesAreNeverDeleted() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        let theirs = model.messages[0]
        await model.delete(theirs)
        XCTAssertTrue(model.messages.contains { $0.id == theirs.id })
        XCTAssertFalse(data.read { $0.calls }.contains("deleteMessage"))
    }

    func testReactShowsStickerAtOnceAndStartsRain() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        await model.react(postID: SocialDemo.p3, emoji: "🥹")
        XCTAssertEqual(model.reactions[SocialDemo.p3]?.distinctEmoji, ["🥹"])
        XCTAssertEqual(model.sentReaction?.emoji, "🥹")
        XCTAssertTrue(data.read { $0.reactions }.contains { $0.postID == SocialDemo.p3 && $0.emoji == "🥹" })
    }

    func testFailedReactionRemovesTheOptimisticSticker() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        data.update { $0.failOnce.insert("react") }
        await model.react(postID: SocialDemo.p3, emoji: "🥹")
        XCTAssertEqual(model.reactions[SocialDemo.p3]?.distinctEmoji ?? [], [])
        XCTAssertEqual(model.signals.notice?.notice, .reactionFailed)
        XCTAssertEqual(model.signals.feedback?.kind, .failed)
    }

    // MARK: Row layout

    func testRowsPutTheAvatarOnTheLastMessageOfARunAndPickTheGaps() {
        let rows = ChatRowLayout.rows(SocialDemo.messages, me: SocialDemo.me)
        XCTAssertEqual(rows.map(\.gap), [.none, .sameSender, .betweenSenders, .betweenSenders, .textToVoice, .betweenSenders, .betweenSenders, .betweenSenders, .betweenSenders])
        XCTAssertEqual(rows.map(\.showsAvatar), [false, true, true, false, false, true, true, false, true])
        XCTAssertEqual(rows.map(\.isMine), [false, false, false, true, true, false, false, true, false])
        let photo = SocialDemo.message(60, by: SocialDemo.ben, at: SocialDemo.monday, post: SocialDemo.p1)
        let next = SocialDemo.message(61, by: SocialDemo.ben, at: SocialDemo.monday, post: SocialDemo.p3)
        XCTAssertEqual(ChatRowLayout.gap(from: photo, to: next), .photo)
        XCTAssertEqual(ChatRowLayout.gap(from: photo, to: SocialDemo.message(62, by: SocialDemo.ben, at: SocialDemo.monday, text: "x")), .photo)
    }
}

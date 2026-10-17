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
        XCTAssertEqual(model.timeZone, model.group?.resolvedTimeZone, "times and day dividers in the group's time zone")
    }

    func testEmptyThread() async {
        let model = makeModel(SocialDemo.makeEmptyData(creator: SocialDemo.ana))
        await model.load()
        XCTAssertEqual(model.phase, .empty)
        XCTAssertTrue(model.entries().isEmpty)
        XCTAssertEqual(model.group?.name, "roommates", "the header names the group")
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

    // MARK: Following new messages (`chat.thread.layout.followNewest`)

    func testMyOwnSendAsksTheListToBringItIntoView() async {
        let model = makeModel()
        await model.load()
        XCTAssertNil(model.followRequest)
        model.draft = "on my way"
        await model.sendDraft()
        let sent = model.messages.last
        XCTAssertEqual(sent?.body, "on my way")
        XCTAssertEqual(model.followRequest, sent?.id, "the confirmed message, not its local copy")
        model.didFollow(sent!.id)
        XCTAssertNil(model.followRequest)
    }

    func testAReplyFromTheViewerIsFollowedButSomeoneElsesMessageIsNot() async {
        let model = makeModel()
        await model.load()
        // My reply sent from the photo viewer reaches the thread as a realtime insert.
        let mine = SocialDemo.message(41, by: SocialDemo.me, at: SocialDemo.monday.addingTimeInterval(6 * SocialDemo.day), text: "love this", replyTo: SocialDemo.p2)
        await model.handle(.messageInserted(mine))
        XCTAssertEqual(model.followRequest, mine.id)
        model.didFollow(mine.id)
        let incoming = SocialDemo.message(42, by: SocialDemo.ana, at: SocialDemo.monday.addingTimeInterval(7 * SocialDemo.day), text: "ha")
        await model.handle(.messageInserted(incoming))
        XCTAssertNil(model.followRequest, "others' messages are followed only while the reader is at the bottom (the view's rule)")
    }

    func testARefreshThatBringsMyNewMessageAsksToFollowIt() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        let mine = SocialDemo.message(43, by: SocialDemo.me, at: SocialDemo.monday.addingTimeInterval(8 * SocialDemo.day), text: "sent from the viewer")
        data.update { $0.messages.append(mine) }
        await model.refresh()
        XCTAssertEqual(model.messages.last?.id, mine.id)
        XCTAssertEqual(model.followRequest, mine.id)
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

    func testPhotoReplyToAPhotoLoadsItsQuoteAndLosesItWhenTheQuotedPhotoGoes() async {
        let data = SocialDemo.makeData()
        let reply = PostID("00000000-0000-4000-8000-00000000c009")
        data.update { state in
            state.posts.append(SocialDemo.post(reply, by: SocialDemo.ben, at: SocialDemo.monday.addingTimeInterval(3 * SocialDemo.day), replyTo: SocialDemo.p1))
            state.messages.append(SocialDemo.message(90, by: SocialDemo.ben, at: SocialDemo.monday.addingTimeInterval(3 * SocialDemo.day), post: reply))
        }
        let model = makeModel(data)
        await model.load()
        XCTAssertEqual(model.posts[reply]?.post.replyToPostID, SocialDemo.p1)
        XCTAssertNotNil(model.posts[SocialDemo.p1], "the quoted photo is loaded for the quote part")
        await model.handle(.postDeleted(postID: SocialDemo.p1, mediaID: nil))
        XCTAssertNotNil(model.posts[reply], "the reply photo stays")
        XCTAssertNil(model.posts[reply]?.post.replyToPostID, "without its quote")
    }

    func testReactionInsertIsDedupedAndChangesRefetch() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        XCTAssertEqual(model.reactions[SocialDemo.p1]?.distinctEmoji, ["💖", "🔥"], "newest distinct emoji first")
        await model.handle(.reactionInserted(SocialDemo.reaction(SocialDemo.p1, SocialDemo.ana, "🔥", minutes: 70)))
        XCTAssertEqual(model.reactions[SocialDemo.p1]?.rows.filter { $0.userID == SocialDemo.ana }.count, 1)

        await model.handle(.reactionInserted(SocialDemo.reaction(SocialDemo.p1, SocialDemo.ben, "😂", minutes: 90)))
        XCTAssertEqual(model.reactions[SocialDemo.p1]?.distinctEmoji, ["😂", "💖", "🔥"], "a new emoji enters at the leading end")

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

    func testVoiceMessageCarriesItsWaveform() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        let levels = SocialDemo.voiceLevelsMessage
        await model.sendVoice(fileURL: URL(fileURLWithPath: "/tmp/levels.m4a"), durationMs: 3200, levels: levels)
        XCTAssertEqual(data.read { $0.sentVoiceLevels.last }, levels, "p_voice_levels goes with the upload")
        XCTAssertEqual(model.messages.last?.voiceLevels, levels, "the row draws the recorded bars")

        await model.sendVoice(fileURL: URL(fileURLWithPath: "/tmp/bad.m4a"), durationMs: 3200, levels: [1, 2, 3])
        XCTAssertEqual(data.read { $0.sentVoiceLevels.last }, .some(nil), "malformed levels are not sent (the API would refuse them)")
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
        XCTAssertEqual(model.messages.count, before + 1, "the failed voice message stays (failed-message layout)")
        let failed = try! XCTUnwrap(model.messages.last)
        XCTAssertTrue(model.isFailed(failed))
        XCTAssertEqual(model.localVoiceFiles[failed.id], file, "still playable")
        XCTAssertEqual(model.signals.notice?.notice, .messageNotSent)

        await model.retry(failed)
        XCTAssertFalse(model.messages.contains { $0.id == failed.id }, "replaced by the server row")
        XCTAssertEqual(model.messages.last?.voiceDurationMs, 1000)
        XCTAssertTrue(model.failed.isEmpty)
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

    func testFailedMessageStaysWithItsLayoutAndATapSendsItAgain() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        data.update { $0.failOnce.insert("sendText") }
        model.draft = "dinner at 8"
        await model.sendDraft()
        let failed = try! XCTUnwrap(model.messages.last)
        XCTAssertEqual(failed.body, "dinner at 8", "the message stays in the thread")
        XCTAssertTrue(model.isFailed(failed))
        XCTAssertEqual(model.draft, "", "the text is in the failed message, not back in the field")
        XCTAssertFalse(model.isSending)
        XCTAssertEqual(model.signals.feedback?.kind, .failed)
        XCTAssertEqual(model.signals.notice?.notice, .messageNotSent)
        XCTAssertTrue(SocialNotice.messageNotSent.isAnnouncementOnly, "the label shows it; no toast")

        // A refresh keeps the failed copy.
        await model.refresh()
        XCTAssertTrue(model.messages.contains { $0.id == failed.id })

        await model.retry(failed)
        XCTAssertFalse(model.messages.contains { $0.id == failed.id })
        XCTAssertEqual(model.messages.filter { $0.body == "dinner at 8" }.count, 1)
        XCTAssertTrue(model.failed.isEmpty)
        XCTAssertEqual(model.signals.feedback?.kind, .sent)
    }

    func testAFailedMessageCanBeDeletedLocally() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        data.update { $0.failOnce.insert("sendText") }
        model.draft = "typo"
        await model.sendDraft()
        let failed = try! XCTUnwrap(model.messages.last)
        await model.delete(failed)
        XCTAssertFalse(model.messages.contains { $0.id == failed.id })
        XCTAssertFalse(data.read { $0.calls }.contains("deleteMessage"), "it never reached the server")
    }

    func testOfflineSendFailsAndMarksOffline() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        data.update { $0.mode = .offline }
        model.draft = "later"
        await model.sendDraft()
        XCTAssertTrue(model.isOffline)
        XCTAssertEqual(model.signals.notice?.notice, .messageNotSent)
        XCTAssertTrue(model.messages.last.map(model.isFailed) ?? false)

        data.update { $0.mode = .normal }
        await model.retry(model.messages.last!)
        XCTAssertFalse(model.isOffline)
        XCTAssertEqual(data.read { $0.messages.last?.body }, "later")
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

    /// Owner decision 28: Save on a photo message is there for any photo you can see, yours or someone else's.
    func testAnyPhotoMessageIsSaved() async {
        let model = makeModel()
        await model.load()
        let theirs = try! XCTUnwrap(model.messages.first { $0.postID == SocialDemo.p4 })
        let saver = RecordingPhotoSaver()
        await model.savePhoto(theirs, using: saver)
        XCTAssertEqual(saver.savedCount, 1, "Cleo's photo, saved to my own library")
        XCTAssertEqual(model.signals.notice?.notice, .photoSaved)
        let mine = try! XCTUnwrap(model.messages.first { $0.postID == SocialDemo.p3 })
        await model.savePhoto(mine, using: saver)
        XCTAssertEqual(saver.savedCount, 2)
        XCTAssertEqual(model.signals.notice?.notice, .photoSaved)
    }

    func testReactShowsTheChipAtOnce() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        await model.react(postID: SocialDemo.p3, emoji: "🥹")
        XCTAssertEqual(model.reactions[SocialDemo.p3]?.distinctEmoji, ["🥹"])
        XCTAssertTrue(data.read { $0.reactions }.contains { $0.postID == SocialDemo.p3 && $0.emoji == "🥹" })
    }

    func testQuickReactionTogglesMyEmoji() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        XCTAssertEqual(model.myEmoji(on: SocialDemo.p1), ["💖"])
        await model.toggleReaction(postID: SocialDemo.p1, emoji: "💖")
        XCTAssertTrue(model.myEmoji(on: SocialDemo.p1).isEmpty, "an emoji I already used is taken back")
        XCTAssertEqual(model.reactions[SocialDemo.p1]?.distinctEmoji, ["🔥"])
        await model.toggleReaction(postID: SocialDemo.p1, emoji: "😂")
        XCTAssertEqual(model.myEmoji(on: SocialDemo.p1), ["😂"])
        XCTAssertEqual(model.reactions[SocialDemo.p1]?.distinctEmoji, ["😂", "🔥"], "a new emoji enters at the leading end")
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

    func testUnreactFromThePickerIsOptimisticAndRestoredOnFailure() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        await model.react(postID: SocialDemo.p3, emoji: "🥹")
        XCTAssertEqual(model.myEmoji(on: SocialDemo.p3), ["🥹"], "highlighted in the picker")

        data.update { $0.failOnce.insert("unreact") }
        let before = model.reactions[SocialDemo.p3]
        await model.unreact(postID: SocialDemo.p3, emoji: "🥹")
        XCTAssertEqual(model.reactions[SocialDemo.p3], before, "put back when the call fails")
        XCTAssertEqual(model.signals.notice?.notice, .reactionFailed)

        await model.unreact(postID: SocialDemo.p3, emoji: "🥹")
        XCTAssertFalse(model.reactions[SocialDemo.p3]?.contains(userID: SocialDemo.me, emoji: "🥹") ?? false)
        XCTAssertTrue(model.myEmoji(on: SocialDemo.p3).isEmpty)
        XCTAssertFalse(data.read { $0.reactions }.contains { $0.postID == SocialDemo.p3 && $0.emoji == "🥹" && $0.userID == SocialDemo.me })
    }

    func testEmojiOnlyMessagesAreRecognised() {
        XCTAssertEqual(SocialEmojiText.emojiOnlyCount("😂"), 1)
        XCTAssertEqual(SocialEmojiText.emojiOnlyCount("❤️ 🔥 👍🏽"), 3)
        XCTAssertEqual(SocialEmojiText.emojiOnlyCount("👨‍👩‍👧"), 1, "a ZWJ family is one emoji")
        XCTAssertEqual(SocialEmojiText.emojiOnlyCount("🔥🔥🔥🔥"), 4, "4+ stays a text bubble in the view")
        XCTAssertNil(SocialEmojiText.emojiOnlyCount("ok 👍"))
        XCTAssertNil(SocialEmojiText.emojiOnlyCount("123"), "digits are not emoji")
        XCTAssertNil(SocialEmojiText.emojiOnlyCount("  "))
    }

    func testAnEmojiUsedAgainMovesToTheFrontOfTheCluster() {
        var summary = ReactionSummary()
        summary.insert(SocialDemo.reaction(SocialDemo.p1, SocialDemo.ana, "✌️", minutes: 1))
        summary.insert(SocialDemo.reaction(SocialDemo.p1, SocialDemo.ben, "😍", minutes: 2))
        XCTAssertEqual(summary.distinctEmoji, ["😍", "✌️"])
        summary.insert(SocialDemo.reaction(SocialDemo.p1, SocialDemo.cleo, "✌️", minutes: 3))
        XCTAssertEqual(summary.distinctEmoji, ["✌️", "😍"], "chat.reactions.layout.clusterOrder: used again → front; no second chip")
        summary.insert(SocialDemo.reaction(SocialDemo.p1, SocialDemo.cleo, "✌️", minutes: 4))
        XCTAssertEqual(summary.rows.count, 3, "react is idempotent per person and emoji")
    }

    func testReactionsSheetListsOneRowPerPersonAndEmojiNewestFirst() {
        let summary = ReactionSummary([
            SocialDemo.reaction(SocialDemo.p1, SocialDemo.ana, "🔥", minutes: 1),
            SocialDemo.reaction(SocialDemo.p1, SocialDemo.ben, "😍", minutes: 5),
            SocialDemo.reaction(SocialDemo.p1, SocialDemo.ana, "😂", minutes: 3),
        ])
        XCTAssertEqual(summary.listRows().map(\.emoji), ["😍", "😂", "🔥"], "chat.reactions.layout.listOrder: newest first by created_at")
    }

    // MARK: Runs and day dividers

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private enum Shape: Equatable {
        case day(ChatGap)
        case message(Int, startsRun: Bool, isMine: Bool, gap: ChatGap)
    }

    private func shape(_ entries: [ChatEntry]) -> [Shape] {
        entries.map { entry in
            switch entry {
            case let .day(_, gap):
                return .day(gap)
            case let .message(row):
                let index = SocialDemo.messages.firstIndex { $0.id == row.id }.map { $0 + 1 } ?? 0
                return .message(index, startsRun: row.startsRun, isMine: row.isMine, gap: row.gap)
            }
        }
    }

    func testEntriesPutADividerBeforeEachDayAndStartARunPerSenderOrQuote() {
        let quoted: Set<MessageID> = [SocialDemo.messageID(7)]
        let entries = ChatThreadLayout.entries(SocialDemo.messages, me: SocialDemo.me, calendar: utc) { quoted.contains($0.id) }
        XCTAssertEqual(shape(entries), [
            .day(.none),
            .message(1, startsRun: true, isMine: false, gap: .afterDivider),
            .message(2, startsRun: false, isMine: false, gap: .item),
            .message(3, startsRun: true, isMine: false, gap: .run),
            .message(4, startsRun: true, isMine: true, gap: .run),
            .message(5, startsRun: false, isMine: true, gap: .item),
            .day(.divider),
            .message(6, startsRun: true, isMine: false, gap: .afterDivider),
            .message(7, startsRun: true, isMine: false, gap: .run),
            .day(.divider),
            .message(8, startsRun: true, isMine: true, gap: .afterDivider),
            .day(.divider),
            .message(9, startsRun: true, isMine: false, gap: .afterDivider),
        ])
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count, "stable, unique ids for the lazy list")
    }

    func testAReplyQuoteBreaksARunOfOneSender() {
        let first = SocialDemo.message(70, by: SocialDemo.ben, at: SocialDemo.monday, text: "look")
        let reply = SocialDemo.message(71, by: SocialDemo.ben, at: SocialDemo.monday.addingTimeInterval(60), text: "this one", replyTo: SocialDemo.p1)
        let plain = SocialDemo.message(72, by: SocialDemo.ben, at: SocialDemo.monday.addingTimeInterval(120), text: "and")
        let rows = ChatThreadLayout.entries([first, reply, plain], me: SocialDemo.me, calendar: utc) { $0.replyToPostID != nil }
            .compactMap { entry -> ChatRow? in if case let .message(row) = entry { return row } else { return nil } }
        XCTAssertEqual(rows.map(\.startsRun), [true, true, false])
        XCTAssertEqual(rows.map(\.gap), [.afterDivider, .run, .item])
    }

    /// `chat.thread.layout.systemLine`: a joined / left line starts no run, sits a run gap from both neighbours, and the
    /// same sender's next message starts a new run.
    func testAJoinedOrLeftLineStandsAloneBetweenRuns() {
        let first = SocialDemo.message(80, by: SocialDemo.ben, at: SocialDemo.monday, text: "hi")
        let joined = Message(
            id: MessageID("00000000-0000-4000-8000-0000000c0081"), groupID: SocialDemo.groupID, authorID: SocialDemo.cleo,
            kind: .joined, body: "Cleo Ramos", createdAt: SocialDemo.monday.addingTimeInterval(60)
        )
        let left = Message(
            id: MessageID("00000000-0000-4000-8000-0000000c0082"), groupID: SocialDemo.groupID, authorID: SocialDemo.ben,
            kind: .left, body: "Ben Ito", createdAt: SocialDemo.monday.addingTimeInterval(90)
        )
        let after = SocialDemo.message(83, by: SocialDemo.ben, at: SocialDemo.monday.addingTimeInterval(120), text: "back")
        let rows = ChatThreadLayout.entries([first, joined, left, after], me: SocialDemo.me, calendar: utc)
            .compactMap { entry -> ChatRow? in if case let .message(row) = entry { return row } else { return nil } }
        XCTAssertEqual(rows.map(\.startsRun), [true, false, false, true])
        XCTAssertEqual(rows.map(\.gap), [.afterDivider, .run, .run, .run])
        XCTAssertTrue(MessageKind.joined.isSystemLine && MessageKind.left.isSystemLine && !MessageKind.text.isSystemLine)
    }

    func testALineNamesThePersonByProfileElseByTheNameItKept() async {
        let model = makeModel()
        await model.load()
        let known = Message(
            id: MessageID("00000000-0000-4000-8000-0000000c0091"), groupID: SocialDemo.groupID, authorID: SocialDemo.ana,
            kind: .joined, body: "Old Name", createdAt: SocialDemo.monday
        )
        XCTAssertEqual(model.systemLineName(known), "Ana")
        let gone = Message(
            id: MessageID("00000000-0000-4000-8000-0000000c0092"), groupID: SocialDemo.groupID,
            authorID: UserID("00000000-0000-4000-8000-00000000a0ff"), kind: .left, body: "Dana Silva", createdAt: SocialDemo.monday
        )
        XCTAssertEqual(model.systemLineName(gone), "Dana")
    }

    func testDayLabelsAreTodayYesterdayOrTheDate() {
        let now = SocialDemo.monday.addingTimeInterval(2 * SocialDemo.day)
        XCTAssertEqual(ChatThreadLayout.dayLabel(now, now: now, calendar: utc), .today)
        XCTAssertEqual(ChatThreadLayout.dayLabel(now.addingTimeInterval(-SocialDemo.day), now: now, calendar: utc), .yesterday)
        XCTAssertEqual(ChatThreadLayout.dayLabel(SocialDemo.monday, now: now, calendar: utc), .date(SocialDemo.monday))
    }

    func testModelEntriesUseTheThreadsQuotes() async {
        let model = makeModel()
        await model.load()
        let reply = try! XCTUnwrap(model.messages.first { $0.body == "so pretty" })
        XCTAssertTrue(model.hasQuote(reply))
        XCTAssertEqual(model.quotedPost(of: reply)?.id, SocialDemo.p2)
        let rows = model.entries(calendar: utc).compactMap { entry -> ChatRow? in if case let .message(row) = entry { return row } else { return nil } }
        XCTAssertTrue(rows.first { $0.id == reply.id }?.startsRun ?? false)
    }

    // MARK: Replies

    func testReplyToAPhotoQuotesThePostAndSendsItsID() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        let photo = try! XCTUnwrap(model.messages.first { $0.postID == SocialDemo.p2 })
        model.startReply(to: photo)
        XCTAssertEqual(model.replyTarget, .post(SocialDemo.p2, author: SocialDemo.ana))
        XCTAssertEqual(model.replyPostID, SocialDemo.p2, "the camera glyph replies to this photo with a photo")
        model.draft = "love it"
        await model.sendDraft()
        XCTAssertNil(model.replyTarget, "the reply bar closes on send")
        let sent = try! XCTUnwrap(data.read { $0.messages.last })
        XCTAssertEqual(sent.body, "love it")
        XCTAssertEqual(sent.replyToPostID, SocialDemo.p2)
        XCTAssertNil(sent.replyToMessageID)
        XCTAssertEqual(model.quotedPost(of: model.messages.last!)?.id, SocialDemo.p2)
    }

    func testReplyToATextMessageQuotesTheMessage() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        let text = try! XCTUnwrap(model.messages.first { $0.body == "i can do pasta" })
        model.startReply(to: text)
        XCTAssertEqual(model.replyTarget, .message(text.id, author: SocialDemo.ana))
        XCTAssertNil(model.replyPostID)
        model.draft = "yes!"
        await model.sendDraft()
        let sent = try! XCTUnwrap(data.read { $0.messages.last })
        XCTAssertEqual(sent.replyToMessageID, text.id)
        XCTAssertNil(sent.replyToPostID)
        XCTAssertEqual(model.quotedMessage(of: model.messages.last!)?.id, text.id)
    }

    func testCancellingAReplyAndLosingItsTarget() async {
        let model = makeModel()
        await model.load()
        let text = model.messages[0]
        model.startReply(to: text)
        model.cancelReply()
        XCTAssertNil(model.replyTarget)

        model.startReply(to: text)
        await model.handle(.messageDeleted(text.id))
        XCTAssertNil(model.replyTarget, "the quoted message was unsent")

        let photo = try! XCTUnwrap(model.messages.first { $0.postID == SocialDemo.p1 })
        model.startReply(to: photo)
        await model.handle(.postDeleted(postID: SocialDemo.p1, mediaID: nil))
        XCTAssertNil(model.replyTarget, "the quoted photo was deleted")
    }

    func testQuotedMessageOutsideTheLoadedPagesIsFetched() async {
        let data = SocialDemo.makeData()
        let old = SocialDemo.message(80, by: SocialDemo.cleo, at: SocialDemo.monday.addingTimeInterval(-10 * SocialDemo.day), text: "long ago")
        let reply = SocialDemo.message(81, by: SocialDemo.ana, at: SocialDemo.monday.addingTimeInterval(4 * SocialDemo.day), text: "remember?", replyToMessage: old.id)
        data.update { state in
            state.messages.insert(old, at: 0)
            state.messages.append(reply)
            state.messagePageSize = 4
        }
        let model = makeModel(data)
        await model.load()
        XCTAssertFalse(model.messages.contains { $0.id == old.id }, "older than the first page")
        XCTAssertEqual(model.quotedMessage(of: reply)?.body, "long ago")
        XCTAssertNotNil(model.profile(SocialDemo.cleo))
    }

    func testCopyIsAnnouncedOnly() async {
        let model = makeModel()
        await model.load()
        model.copied()
        XCTAssertEqual(model.signals.notice?.notice, .copied)
    }

    func testDeletingMyPhotoFromTheThreadRemovesItAndPutsItBackOnFailure() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        let mine = try! XCTUnwrap(model.messages.first { $0.postID == SocialDemo.p3 })
        data.update { $0.failOnce.insert("deleteMedia") }
        await model.deletePhoto(mine)
        XCTAssertTrue(model.messages.contains { $0.id == mine.id }, "put back when the call fails")
        await model.deletePhoto(mine)
        XCTAssertFalse(model.messages.contains { $0.id == mine.id })
        XCTAssertNil(model.posts[SocialDemo.p3])
        XCTAssertTrue(data.read { $0.deletedMedia }.contains(SocialDemo.mediaID(SocialDemo.p3)))

        let theirs = try! XCTUnwrap(model.messages.first { $0.postID == SocialDemo.p1 })
        await model.deletePhoto(theirs)
        XCTAssertTrue(model.messages.contains { $0.id == theirs.id }, "only my own photos")
    }

    /// Saving a photo message asks for photo-library access when it was denied; p3 is mine.
    func testSavingAPhotoAskForPermissionWhenDenied() async {
        let model = makeModel()
        await model.load()
        let photo = try! XCTUnwrap(model.messages.first { $0.postID == SocialDemo.p3 })
        let saver = RecordingPhotoSaver()
        await model.savePhoto(photo, using: saver)
        XCTAssertEqual(saver.savedCount, 1)
        XCTAssertFalse(model.saveDenied)
        await model.savePhoto(photo, using: RecordingPhotoSaver(denied: true))
        XCTAssertTrue(model.saveDenied, "the permission alert shows")
    }

    // MARK: Reactions on messages (`chat.reactions.layout.messageReactions`)

    private var text4: Message { SocialDemo.messages[3] } // mine, "yes please"
    private var text1: Message { SocialDemo.messages[0] } // Ana's, "who's cooking tonight?"
    private var voice5: Message { SocialDemo.messages[4] } // mine, a voice message

    private func messageReaction(_ message: Message, _ user: UserID, _ emoji: String, minutes: Double) -> MessageReaction {
        MessageReaction(messageID: message.id, userID: user, emoji: emoji, groupID: SocialDemo.groupID, createdAt: SocialDemo.at(minutes * 60))
    }

    func testMessageReactionsLoadWithTheThreadAsRowsNeverACount() async {
        let data = SocialDemo.makeData()
        let rows = [
            messageReaction(text1, SocialDemo.ben, "😂", minutes: 30),
            messageReaction(text1, SocialDemo.cleo, "🔥", minutes: 40),
            messageReaction(text1, SocialDemo.me, "😂", minutes: 50),
        ]
        data.update { $0.messageReactions = rows }
        let model = makeModel(data)
        await model.load()
        XCTAssertEqual(model.messageReactionRows(text1.id).map(\.userID), [SocialDemo.ben, SocialDemo.cleo, SocialDemo.me])
        XCTAssertEqual(model.reactionSummary(of: text1.id).distinctEmoji, ["😂", "🔥"], "distinct emoji, newest first")
        XCTAssertEqual(model.reactionSummary(of: text1.id).listRows().map(\.userID), [SocialDemo.me, SocialDemo.cleo, SocialDemo.ben])
        XCTAssertEqual(model.myEmoji(onMessage: text1.id), ["😂"])
        XCTAssertNotNil(model.profile(SocialDemo.cleo), "the reactors' names are known for the sheet")
        XCTAssertTrue(model.reactionSummary(of: text4.id).isEmpty, "no chip without reactions")
    }

    func testOneReactionPerPersonAnotherReplacesMineAndMineAgainTakesItBack() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        await model.toggleReaction(messageID: text1.id, emoji: "🔥")
        XCTAssertEqual(model.myEmoji(onMessage: text1.id), ["🔥"])
        await model.toggleReaction(messageID: text1.id, emoji: "💖")
        XCTAssertEqual(model.myEmoji(onMessage: text1.id), ["💖"], "react_to_message replaces my reaction")
        XCTAssertEqual(model.messageReactionRows(text1.id).count, 1, "one row per person")
        XCTAssertEqual(data.read { $0.messageReactions.filter { $0.messageID == text1.id }.map(\.emoji) }, ["💖"])
        await model.toggleReaction(messageID: text1.id, emoji: "💖")
        XCTAssertTrue(model.myEmoji(onMessage: text1.id).isEmpty, "my own emoji again takes it back")
        XCTAssertTrue(data.read { $0.calls }.contains("unreactToMessage"))
        XCTAssertTrue(data.read { $0.messageReactions }.isEmpty)

        await model.toggleReaction(messageID: voice5.id, emoji: "😂")
        XCTAssertEqual(model.myEmoji(onMessage: voice5.id), ["😂"], "voice messages take reactions too")
        let photoMessage = SocialDemo.messages[2]
        await model.toggleReaction(messageID: photoMessage.id, emoji: "😂")
        XCTAssertTrue(model.myEmoji(onMessage: photoMessage.id).isEmpty, "a photo message is reacted to through its post")
    }

    func testAFailedMessageReactionIsUndone() async {
        let data = SocialDemo.makeData()
        let mine = messageReaction(text1, SocialDemo.me, "🔥", minutes: 30)
        data.update { $0.messageReactions = [mine] }
        let model = makeModel(data)
        await model.load()
        data.update { $0.failOnce.insert("reactToMessage") }
        await model.toggleReaction(messageID: text1.id, emoji: "💖")
        XCTAssertEqual(model.myEmoji(onMessage: text1.id), ["🔥"], "the earlier emoji is back")
        XCTAssertEqual(model.signals.notice?.notice, .reactionFailed)
        XCTAssertEqual(model.signals.feedback?.kind, .failed)

        data.update { $0.failOnce.insert("unreactToMessage") }
        await model.unreact(messageID: text1.id)
        XCTAssertEqual(model.myEmoji(onMessage: text1.id), ["🔥"], "put back when the call fails")
    }

    func testMessageReactionsStayLiveFromUpsertsAndTheChangedBroadcast() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        await model.handle(.messageReactionUpserted(messageReaction(text1, SocialDemo.ben, "😂", minutes: 30)))
        XCTAssertEqual(model.reactionSummary(of: text1.id).distinctEmoji, ["😂"])
        await model.handle(.messageReactionUpserted(messageReaction(text1, SocialDemo.ben, "🔥", minutes: 31)))
        XCTAssertEqual(model.messageReactionRows(text1.id).map(\.emoji), ["🔥"], "an update replaces Ben's row")
        await model.handle(.messageReactionUpserted(MessageReaction(
            messageID: MessageID("00000000-0000-4000-8000-0000000ffff1"), userID: SocialDemo.ben, emoji: "🔥",
            groupID: SocialDemo.groupID, createdAt: SocialDemo.at(60)
        )))
        XCTAssertNil(model.messageReactions[MessageID("00000000-0000-4000-8000-0000000ffff1")], "unknown messages are ignored")

        // Ben took his back: the broadcast names only the message; the rows are read again.
        data.update { $0.messageReactions = [] }
        await model.handle(.messageReactionsChanged(text1.id))
        XCTAssertTrue(model.reactionSummary(of: text1.id).isEmpty)
    }

    // MARK: Editing (`chat.thread.layout.editMessage`)

    private func editableModel(_ data: FakeSocialData, window: Int? = 900, at offset: TimeInterval = 60) -> ChatThreadModel {
        data.update { $0.config = PublicAppConfig(messageEditWindowSeconds: window, typingTTLSeconds: 6) }
        let sent = SocialDemo.messages[3].createdAt
        return ChatThreadModel(groupID: SocialDemo.groupID, data: data, now: { sent.addingTimeInterval(offset) })
    }

    func testEditIsOfferedOnMyTextInsideTheWindowOnly() async {
        let data = SocialDemo.makeData()
        let model = editableModel(data)
        await model.load()
        XCTAssertTrue(model.canEdit(text4))
        XCTAssertFalse(model.canEdit(text1), "only my own messages")
        XCTAssertFalse(model.canEdit(voice5), "only text")

        let late = editableModel(SocialDemo.makeData(), at: 901)
        await late.load()
        XCTAssertFalse(late.canEdit(text4), "the window has passed")

        let unknown = editableModel(SocialDemo.makeData(), window: nil)
        await unknown.load()
        XCTAssertFalse(unknown.canEdit(text4), "no window known → no Edit")

        let failing = SocialDemo.makeData()
        failing.update { $0.failOnce.insert("publicConfig") }
        let unread = editableModel(failing)
        await unread.load()
        XCTAssertFalse(unread.canEdit(text4), "the config could not be read → no Edit")
    }

    func testEditingHoldsTheTextInTheComposerAndSavesWithEdited() async {
        let data = SocialDemo.makeData()
        let model = editableModel(data)
        await model.load()
        model.draft = "half a thought"
        model.startReply(to: text1)
        model.startEdit(text4)
        XCTAssertTrue(model.isEditing)
        XCTAssertNil(model.replyTarget, "the reply gives way to the edit")
        XCTAssertEqual(model.draft, "yes please")

        model.draft = "yes please!"
        await model.sendDraft()
        XCTAssertFalse(model.isEditing)
        XCTAssertEqual(model.draft, "half a thought", "the unsent draft comes back")
        let edited = try! XCTUnwrap(model.messages.first { $0.id == text4.id })
        XCTAssertEqual(edited.body, "yes please!")
        XCTAssertNotNil(edited.editedAt, "\"Edited\" shows under it")
        XCTAssertEqual(model.messages.count, SocialDemo.messages.count, "an edit sends no new message")
        XCTAssertTrue(data.read { $0.calls }.contains("editMessage"))
        XCTAssertFalse(data.read { $0.calls }.contains("sendText"))
    }

    func testCancellingAnEditKeepsTheMessageAndTheSameTextMakesNoCall() async {
        let data = SocialDemo.makeData()
        let model = editableModel(data)
        await model.load()
        model.draft = "draft"
        model.startEdit(text4)
        model.draft = "something else"
        model.cancelEdit()
        XCTAssertFalse(model.isEditing)
        XCTAssertEqual(model.draft, "draft")
        XCTAssertEqual(model.messages.first { $0.id == text4.id }?.body, "yes please")

        model.startEdit(text4)
        await model.sendDraft()
        XCTAssertFalse(model.isEditing)
        XCTAssertFalse(data.read { $0.calls }.contains("editMessage"), "the same text closes the bar without a call")
    }

    func testAFailedEditPutsTheTextBackAndAnnouncesIt() async {
        let data = SocialDemo.makeData()
        let model = editableModel(data)
        await model.load()
        model.startEdit(text4)
        model.draft = "yes pls"
        data.update { $0.failOnce.insert("editMessage") }
        await model.sendDraft()
        XCTAssertEqual(model.messages.first { $0.id == text4.id }?.body, "yes please", "the message gets its text back")
        XCTAssertNil(model.messages.first { $0.id == text4.id }?.editedAt)
        XCTAssertEqual(model.editTarget, text4.id, "the composer holds the edit again")
        XCTAssertEqual(model.draft, "yes pls")
        XCTAssertEqual(model.signals.notice?.notice, .editFailed)
        XCTAssertTrue(SocialNotice.editFailed.isAnnouncementOnly)
        XCTAssertEqual(model.signals.feedback?.kind, .failed)
    }

    func testSomeoneElsesEditArrivesAsAnUpdateInPlace() async {
        let model = makeModel()
        await model.load()
        var edited = text1
        edited.body = "who's cooking tomorrow?"
        edited.editedAt = SocialDemo.at(0.25 * SocialDemo.hour)
        await model.handle(.messageUpdated(edited))
        XCTAssertEqual(model.messages.first { $0.id == text1.id }?.body, "who's cooking tomorrow?")
        XCTAssertEqual(model.messages.map(\.id), SocialDemo.messages.map(\.id), "in place")
    }

    func testEditingAMessageThatIsDeletedEndsTheEdit() async {
        let model = editableModel(SocialDemo.makeData())
        await model.load()
        model.draft = "kept"
        model.startEdit(text4)
        await model.handle(.messageDeleted(text4.id))
        XCTAssertFalse(model.isEditing)
        XCTAssertEqual(model.draft, "kept")
    }

    // MARK: Typing (`chat.thread.layout.typingLine`)

    func testTypingSendsAtMostEveryHalfTTLAndStopsWhenEmptiedOrSent() async {
        let data = SocialDemo.makeData()
        let clock = TestClock(SocialDemo.at(4 * SocialDemo.day))
        data.update { $0.config = PublicAppConfig(typingTTLSeconds: 6) }
        let model = ChatThreadModel(groupID: SocialDemo.groupID, data: data, now: { clock.now })
        await model.load()
        model.draft = "o"
        await model.composerTextChanged()
        model.draft = "on"
        clock.advance(2)
        await model.composerTextChanged()
        XCTAssertEqual(data.read { $0.typingCalls }, [true], "not again before half the TTL")
        clock.advance(1)
        model.draft = "on my"
        await model.composerTextChanged()
        XCTAssertEqual(data.read { $0.typingCalls }, [true, true])
        model.draft = ""
        await model.composerTextChanged()
        XCTAssertEqual(data.read { $0.typingCalls }, [true, true, false], "the field emptied")

        model.draft = "on my way"
        await model.composerTextChanged()
        await model.sendDraft()
        XCTAssertEqual(data.read { $0.typingCalls }.suffix(2), [true, false], "sent")
        await model.stopTyping()
        XCTAssertEqual(data.read { $0.typingCalls }.count, 5, "nothing more once stopped")
    }

    func testNoTypingCallsWithoutATTLOrWhileEditing() async {
        let data = SocialDemo.makeData()
        let model = makeModel(data)
        await model.load()
        model.draft = "hello"
        await model.composerTextChanged()
        XCTAssertTrue(data.read { $0.typingCalls }.isEmpty, "typing_ttl_s unknown")

        let editing = SocialDemo.makeData()
        let edit = editableModel(editing)
        await edit.load()
        edit.startEdit(text4)
        await edit.composerTextChanged()
        XCTAssertTrue(editing.read { $0.typingCalls }.isEmpty, "editing a sent message is not typing")
    }

    func testTheTypingLineNamesPeopleInTheOrderTheyStartedAndExpires() async {
        let data = SocialDemo.makeData()
        let clock = TestClock(SocialDemo.at(4 * SocialDemo.day))
        data.update { state in
            state.typing = [ChatTyping(groupID: SocialDemo.groupID, userID: SocialDemo.ana, until: clock.now.addingTimeInterval(4))]
        }
        let model = ChatThreadModel(groupID: SocialDemo.groupID, data: data, now: { clock.now })
        await model.load()
        XCTAssertEqual(model.typingNames(), ["Ana"], "read when the thread opens")
        await model.handle(.typingChanged(ChatTyping(groupID: SocialDemo.groupID, userID: SocialDemo.ben, until: clock.now.addingTimeInterval(6))))
        await model.handle(.typingChanged(ChatTyping(groupID: SocialDemo.groupID, userID: SocialDemo.me, until: clock.now.addingTimeInterval(6))))
        await model.handle(.typingChanged(ChatTyping(groupID: SocialDemo.groupID, userID: SocialDemo.ana, until: clock.now.addingTimeInterval(6))))
        XCTAssertEqual(model.typingNames(), ["Ana", "Ben"], "a renewal keeps its place; mine never shows")

        await model.handle(.typingChanged(ChatTyping(groupID: SocialDemo.groupID, userID: SocialDemo.ana, until: clock.now)))
        XCTAssertEqual(model.typingNames(), ["Ben"], "stopped")
        clock.advance(7)
        XCTAssertEqual(model.typingNames(), [], "until passed, with no event")
        model.pruneTyping()
        XCTAssertTrue(model.typists.isEmpty)
        await model.handle(.typingChanged(ChatTyping(groupID: SocialDemo.otherGroupID, userID: SocialDemo.ben, until: clock.now.addingTimeInterval(6))))
        XCTAssertEqual(model.typingNames(), [], "another group's row")
    }

    // MARK: Links (`chat.thread.layout.links`)

    func testLinksAreFoundByThePlatformDetectorHttpOnly() {
        let text = "menu at https://example.com/menu and www.example.org, mail me@example.com"
        let links = ChatLinks.find(in: text)
        XCTAssertEqual(links.map(\.url.absoluteString), ["https://example.com/menu", "http://www.example.org"])
        XCTAssertEqual(links.map { String(text[$0.range]) }, ["https://example.com/menu", "www.example.org"])
        XCTAssertTrue(ChatLinks.find(in: "yes please").isEmpty)
        XCTAssertTrue(ChatLinks.find(in: "").isEmpty)
    }
}

/// A clock the typing and edit tests move by hand.
private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ start: Date) { value = start }

    var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func advance(_ seconds: TimeInterval) {
        lock.lock()
        value = value.addingTimeInterval(seconds)
        lock.unlock()
    }
}

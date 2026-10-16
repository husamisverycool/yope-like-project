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
        XCTAssertEqual(summary.listRows(newestFirst: true).map(\.emoji), ["😍", "😂", "🔥"])
        XCTAssertEqual(summary.listRows(newestFirst: false).map(\.emoji), ["🔥", "😍", "😂"], "release: the data's order (listOrder BLOCKED)")
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

    func testSavingAPhotoAskForPermissionWhenDenied() async {
        let model = makeModel()
        await model.load()
        let photo = try! XCTUnwrap(model.messages.first { $0.postID == SocialDemo.p2 })
        let saver = RecordingPhotoSaver()
        await model.savePhoto(photo, using: saver)
        XCTAssertEqual(saver.savedCount, 1)
        XCTAssertFalse(model.saveDenied)
        await model.savePhoto(photo, using: RecordingPhotoSaver(denied: true))
        XCTAssertTrue(model.saveDenied, "the permission alert shows")
    }
}

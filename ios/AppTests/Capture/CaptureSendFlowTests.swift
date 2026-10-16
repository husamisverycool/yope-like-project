// camera.sendto view model and the in-place send (busy, alert on failure; through AppData's outbox) —
// design/surfaces/camera.sendto.md (RC-8), docs/API.md recipe 9.4.
@testable import App
import AppData
import AppModels
import AppServices
import DesignSystem
import XCTest

@MainActor
final class CaptureSendToModelTests: XCTestCase {
    func testNoContextPreselectsEveryGroup() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel()
        XCTAssertEqual(model.listState, .idle, "nothing drawn until the cache answered")
        await model.load()
        XCTAssertEqual(model.listState, .loaded)
        XCTAssertEqual(model.selection, CaptureFakes.groups.map(\.id))
        XCTAssertTrue(model.canSend)
    }

    func testWidgetGroupIsPreselected() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel(contextGroupID: "fake-group-2")
        await model.load()
        XCTAssertEqual(model.selection, ["fake-group-2"])
    }

    func testLeftGroupPreselectsNothingAndDisablesSend() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel(contextGroupID: "left-group")
        await model.load()
        XCTAssertTrue(model.selection.isEmpty)
        XCTAssertFalse(model.canSend, "the send capsule is disabled (#4D4D4D) with nothing selected")
    }

    func testToggleKeepsListOrderAndCountsForHaptic() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel(contextGroupID: "fake-group-2")
        await model.load()
        model.toggle("fake-group-1")
        XCTAssertEqual(model.selection, ["fake-group-1", "fake-group-2"])
        model.toggle("fake-group-2")
        XCTAssertEqual(model.selection, ["fake-group-1"])
        XCTAssertEqual(model.selectionChanges, 2)
    }

    func testCachedGroupsShowWithoutSpinnerFrame() async {
        let rig = CaptureTestRig()
        rig.groups.cached = [CaptureFakes.groups[0]]
        rig.groups.loadError = DataError.offline
        rig.groups.isOffline = true
        let model = rig.sendToModel()
        var states: [SendToModel.ListState] = [model.listState]
        let task = Task { await model.load() }
        while states.last != .loaded {
            await Task.yield()
            if states.last != model.listState { states.append(model.listState) }
        }
        await task.value
        XCTAssertEqual(states, [.idle, .loaded], "cached content first, no loading frame")
        XCTAssertEqual(model.groups.map(\.id), [CaptureFakes.groups[0].id])
    }

    func testOfflineWithoutCacheAndEmptyAndFailed() async {
        let rig = CaptureTestRig()
        rig.groups.loadError = DataError.offline
        let offline = rig.sendToModel()
        await offline.load()
        XCTAssertEqual(offline.listState, .offline)

        rig.groups.loadError = DataError.http(status: 500)
        let failed = rig.sendToModel()
        await failed.load()
        XCTAssertEqual(failed.listState, .failed)

        rig.groups.loadError = nil
        rig.groups.groups = []
        let empty = rig.sendToModel()
        await empty.load()
        XCTAssertEqual(empty.listState, .empty)
        XCTAssertFalse(empty.canSend)
        XCTAssertTrue(empty.canCreateGroup)
    }

    func testFreeMemberCannotSendVideo() async {
        let rig = CaptureTestRig()
        let video = CapturedMedia.video(CaptureVideo(fileURL: URL(fileURLWithPath: "/tmp/v.mov"), durationMs: 1000), capturedAt: Date())
        let model = rig.sendToModel(media: video)
        await model.load()
        XCTAssertFalse(model.canSend)
        rig.premium.premium = true
        let premium = rig.sendToModel(media: video)
        await premium.load()
        XCTAssertTrue(premium.canSend)
    }

    func testSendWaitsThenClosesWithConfirmation() async {
        let rig = CaptureTestRig()
        var sent = 0
        let model = rig.sendToModel(contextGroupID: "fake-group-1", onSent: { sent += 1 })
        await model.load()
        model.caption = "  sunset  "
        await model.send()
        XCTAssertEqual(sent, 1, "the composer closes once posted")
        XCTAssertFalse(model.isSending)
        XCTAssertNil(model.sendFailure)
        let draft = try! XCTUnwrap(rig.posting.published.first)
        XCTAssertEqual(draft.groupIDs, [GroupID("fake-group-1")])
        XCTAssertEqual(draft.caption, "  sunset  ")
        XCTAssertEqual(draft.kind, .photo)
        XCTAssertEqual(draft.original.contentType, ContentType.jpeg)
        XCTAssertNil(draft.invitationID)
        XCTAssertEqual(rig.haptics, [Tokens.Haptics.globalSend])
        XCTAssertEqual(rig.sendCenter.confirmations.message, Copy.cameraSendtoToastPostedOne(group: CaptureFakes.groups[0].name),
                       "iOS confirms with an accessibility announcement (C-26)")
    }

    func testManyGroupsConfirmation() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel()
        await model.load()
        await model.send()
        XCTAssertEqual(rig.sendCenter.confirmations.message, Copy.cameraSendtoToastPostedMany)
    }

    func testBlankMessageIsNoMessage() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel()
        await model.load()
        model.caption = "   "
        XCTAssertFalse(model.hasMessage)
        await model.send()
        XCTAssertNil(rig.posting.published.first?.caption)
    }

    func testSendingStateDisablesTheComposer() async {
        let rig = CaptureTestRig()
        rig.posting.suspendsPublish = true
        var closed = 0
        let model = rig.sendToModel(onClose: { closed += 1 })
        await model.load()
        let send = Task { await model.send() }
        let busy = await captureEventually { model.isSending }
        XCTAssertTrue(busy, "busy capsule, title 'Sending…'")
        let before = model.selection
        model.toggle("fake-group-1")
        XCTAssertEqual(model.selection, before, "rows are disabled while sending")
        model.close()
        XCTAssertEqual(closed, 0, "close is disabled while sending")
        send.cancel()
        _ = await captureEventually { !model.isSending }
    }

    func testFailureKeepsEverythingAndTryAgainResends() async {
        let rig = CaptureTestRig()
        rig.posting.publishError = .offline
        var sent = 0
        let model = rig.sendToModel(onSent: { sent += 1 })
        await model.load()
        model.caption = "hello"
        await model.beginVoiceRecording()
        await model.keepVoiceRecording()
        await model.send()
        XCTAssertEqual(model.sendFailure, .offline)
        XCTAssertEqual(CaptureSendCenter.Failure.offline.message, Copy.cameraSendtoErrorOffline)
        XCTAssertEqual(sent, 0, "stays in the sheet")
        XCTAssertEqual(model.caption, "hello")
        XCTAssertNotNil(model.voiceNote, "the voice note is kept")
        XCTAssertEqual(model.selection, CaptureFakes.groups.map(\.id))
        XCTAssertEqual(rig.haptics, [Tokens.Haptics.globalError])
        XCTAssertTrue(rig.posting.pending.isEmpty, "the failed draft leaves the outbox: Try Again sends the composer's capture")

        rig.posting.publishError = nil
        await model.retrySend()
        XCTAssertNil(model.sendFailure)
        XCTAssertEqual(sent, 1)
        XCTAssertEqual(rig.posting.published.count, 1)
        XCTAssertEqual(rig.posting.published.first?.caption, "hello")
        XCTAssertNotNil(rig.posting.published.first?.voice)
    }

    func testCancelOnTheAlertKeepsTheComposer() async {
        let rig = CaptureTestRig()
        rig.posting.publishError = .api(.notGroupMember)
        let model = rig.sendToModel()
        await model.load()
        await model.send()
        XCTAssertEqual(model.sendFailure, .sendFailed)
        XCTAssertEqual(CaptureSendCenter.Failure.sendFailed.message, Copy.cameraSendtoErrorGeneric)
        model.dismissSendFailure()
        XCTAssertNil(model.sendFailure)
        XCTAssertTrue(model.canSend)
    }

    func testCloseAsksOnlyWithAMessageOrVoiceNote() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel()
        await model.load()
        XCTAssertFalse(model.needsDiscardConfirmation, "nothing to lose: closes at once")
        model.caption = "hi"
        XCTAssertTrue(model.needsDiscardConfirmation)
        model.caption = ""
        await model.beginVoiceRecording()
        await model.keepVoiceRecording()
        XCTAssertTrue(model.needsDiscardConfirmation)
    }

    func testHoldRecordsAndLiftKeepsTheVoiceNote() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel()
        await model.load()
        let started = await model.beginVoiceRecording()
        XCTAssertTrue(started)
        XCTAssertEqual(model.voicePhase, .holding)
        XCTAssertTrue(model.showsVoiceRow, "the recording capsule replaces the message pill")
        await model.keepVoiceRecording()
        XCTAssertEqual(model.voicePhase, .idle)
        XCTAssertEqual(model.voiceNote?.durationMs, 1000)
        XCTAssertTrue(model.showsVoiceRow, "attached: the note capsule shows ▶, the waveform and the length")
        model.toggleVoicePlayback()
        XCTAssertTrue(model.isPlayingVoice)
        XCTAssertTrue(model.isPlayingNote)
    }

    func testTooShortRecordingIsNotANote() async {
        let rig = CaptureTestRig()
        rig.voice.recordedDurationMs = 400
        let model = rig.sendToModel()
        await model.beginVoiceRecording()
        await model.keepVoiceRecording()
        XCTAssertNil(model.voiceNote, "reads 00:00: not a voice note")
        XCTAssertFalse(model.showsVoiceRow)
    }

    func testSlideLeftCancels() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel()
        await model.beginVoiceRecording()
        model.cancelVoiceRecording()
        XCTAssertEqual(model.voicePhase, .idle)
        XCTAssertNil(model.voiceNote)
        XCTAssertFalse(rig.voice.isRecording)
    }

    func testLockPausePreviewContinueThenKeep() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel()
        await model.beginVoiceRecording()
        model.lockVoiceRecording()
        XCTAssertEqual(model.voicePhase, .locked)
        model.pauseVoiceRecording()
        XCTAssertEqual(model.voicePhase, .paused)
        XCTAssertTrue(rig.voice.isPaused, "pause uses the recorder's pause (chat.voice.layout.locked)")
        XCTAssertTrue(rig.voice.isRecording, "the draft is kept")
        await model.toggleDraftPreview()
        XCTAssertEqual(rig.voice.draftsMade, 1, "the preview plays the finished draft")
        XCTAssertEqual(rig.voice.playedFiles.count, 1)
        XCTAssertTrue(model.isPlayingVoice)
        await model.toggleDraftPreview()
        XCTAssertFalse(model.isPlayingVoice, "a second tap pauses the preview")
        model.resumeVoiceRecording()
        XCTAssertEqual(model.voicePhase, .locked, "continue records at the end of the draft")
        XCTAssertFalse(rig.voice.isPaused)
        XCTAssertFalse(model.isPlayingVoice, "continuing stops the preview")
        model.pauseVoiceRecording()
        await model.keepVoiceRecording()
        XCTAssertEqual(model.voicePhase, .idle)
        XCTAssertNotNil(model.voiceNote)
        XCTAssertEqual(model.voiceNote?.levels, rig.voice.levels, "the note keeps its waveform")
    }

    func testPauseOnlyWhileLockedAndContinueOnlyWhilePaused() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel()
        await model.beginVoiceRecording()
        model.pauseVoiceRecording()
        XCTAssertEqual(model.voicePhase, .holding, "holding has no pause")
        model.resumeVoiceRecording()
        XCTAssertEqual(model.voicePhase, .holding)
        model.lockVoiceRecording()
        model.resumeVoiceRecording()
        XCTAssertEqual(model.voicePhase, .locked)
        await model.toggleDraftPreview()
        XCTAssertEqual(rig.voice.draftsMade, 0, "no preview while recording")
    }

    func testDeletingAPausedDraftDiscardsIt() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel()
        await model.beginVoiceRecording(locked: true)
        model.pauseVoiceRecording()
        model.cancelVoiceRecording()
        XCTAssertEqual(model.voicePhase, .idle)
        XCTAssertNil(model.voiceNote)
        XCTAssertFalse(rig.voice.isRecording)
    }

    func testANewRecordingReplacesTheAttachedNote() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel()
        await model.beginVoiceRecording()
        await model.keepVoiceRecording()
        let first = model.voiceNote
        rig.voice.recordedDurationMs = 2500
        await model.beginVoiceRecording()
        XCTAssertEqual(model.voiceNote, first, "the note stays while the new one records")
        await model.keepVoiceRecording()
        XCTAssertEqual(model.voiceNote?.durationMs, 2500)
        XCTAssertNotEqual(model.voiceNote?.fileURL, first?.fileURL)
    }

    func testVoiceOverStartsHandsFree() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel()
        await model.beginVoiceRecording(locked: true)
        XCTAssertEqual(model.voicePhase, .locked)
    }

    func testFirstUseAsksMicrophoneAndDoesNotRecord() async {
        let rig = CaptureTestRig()
        rig.voice.status = .notDetermined
        let model = rig.sendToModel()
        let started = await model.beginVoiceRecording()
        XCTAssertFalse(started, "the system prompt ends the hold")
        XCTAssertEqual(model.voicePhase, .idle)
        XCTAssertEqual(rig.voice.status, .granted)
    }

    func testCloseDiscardsVoiceNote() async {
        let rig = CaptureTestRig()
        var closed = 0
        let model = rig.sendToModel(onClose: { closed += 1 })
        await model.load()
        await model.beginVoiceRecording()
        await model.keepVoiceRecording()
        XCTAssertNotNil(model.voiceNote)
        model.close()
        XCTAssertNil(model.voiceNote)
        XCTAssertEqual(closed, 1)
    }

    func testVoiceNoteGoesOnThePost() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel()
        await model.load()
        await model.beginVoiceRecording()
        await model.send()
        XCTAssertEqual(rig.posting.published.count, 1)
        XCTAssertEqual(rig.posting.published.first?.voice?.contentType, ContentType.m4a)
        XCTAssertEqual(rig.posting.published.first?.voiceDurationMs, 1000, "a recording in progress is kept on send")
        XCTAssertEqual(rig.posting.published.first?.voiceLevels, rig.voice.levels, "the waveform goes with the note (p_voice_levels)")
    }

    func testMicrophoneDeniedOpensSettings() async {
        let rig = CaptureTestRig()
        rig.voice.status = .denied
        let model = rig.sendToModel()
        await model.beginVoiceRecording()
        XCTAssertFalse(model.isRecordingVoice)
        XCTAssertEqual(rig.navigation.settingsOpened, 1)
    }

    func testCaptionIsLimitedToTheTokenLength() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel()
        XCTAssertEqual(SendToModel.captionMaxLength, Int(Tokens.Counts.cameraSendtoSizeCaptionMaxLength))
        model.caption = String(repeating: "a", count: SendToModel.captionMaxLength + 10)
        model.clampCaption()
        XCTAssertEqual(model.caption.count, SendToModel.captionMaxLength)
    }

    func testPhotoReplyCarriesItsTargetToOneGroupOnly() async {
        let rig = CaptureTestRig()
        rig.replyTarget = (groupID: "fake-group-1", postID: "post-9")
        let model = rig.sendToModel(contextGroupID: "fake-group-1")
        await model.load()
        XCTAssertEqual(model.replyToPostID, "post-9")
        model.toggle("fake-group-2")
        XCTAssertNil(model.replyToPostID, "sent to more groups it is an ordinary post (reply_group_mismatch)")
        model.toggle("fake-group-2")
        await model.send()
        XCTAssertEqual(rig.posting.published.count, 1)
        XCTAssertEqual(rig.posting.published.first?.replyToPostID, PostID("post-9"))
        XCTAssertEqual(rig.replyClears, 1, "the handoff is cleared once the reply is sent")
    }

    func testNoReplyWithoutHandoff() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel(contextGroupID: "fake-group-1")
        await model.load()
        await model.send()
        XCTAssertEqual(rig.posting.published.count, 1)
        XCTAssertNil(rig.posting.published.first?.replyToPostID)
    }

    func testSaveUsesLibrary() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel()
        await model.save()
        XCTAssertEqual(rig.library.saved.count, 1)
        XCTAssertEqual(rig.sendCenter.confirmations.message, Copy.cameraSendtoToastSaved, "iOS: announcement (C-26)")
    }
}

@MainActor
final class CaptureSendCenterTests: XCTestCase {
    private func request(groups: [String] = ["g1"], invitationID: String? = nil, daily: Bool = false) -> CaptureSendRequest {
        if daily {
            let answer = DailyAnswer(main: CaptureTestImages.still(), inset: CaptureTestImages.still(named: CaptureTestImages.selfie), capturedAt: Date())
            return CaptureSendRequest(payload: .daily(answer), groupIDs: groups, invitationID: invitationID)
        }
        return CaptureSendRequest(payload: .media(.photo(CaptureTestImages.still(), capturedAt: Date())), groupIDs: groups, caption: "hi")
    }

    func testPostedOutcomeRemovesCameraFilesAndConfirms() async {
        let rig = CaptureTestRig()
        var outgoing = request()
        outgoing.confirmation = "Added!"
        let outcome = await rig.sendCenter.send(outgoing)
        XCTAssertEqual(outcome, .posted)
        XCTAssertEqual(rig.sendCenter.postedCount, 1)
        XCTAssertEqual(rig.haptics, [Tokens.Haptics.globalSend])
        XCTAssertEqual(rig.sendCenter.confirmations.message, "Added!")
    }

    func testOfflineAndPermanentFailures() async {
        let rig = CaptureTestRig()
        rig.posting.publishError = .offline
        let offline = await rig.sendCenter.send(request())
        XCTAssertEqual(offline, .failed(.offline))
        rig.posting.publishError = .api(.notGroupMember)
        let permanent = await rig.sendCenter.send(request())
        XCTAssertEqual(permanent, .failed(.sendFailed))
        XCTAssertEqual(rig.haptics, [Tokens.Haptics.globalError, Tokens.Haptics.globalError])
        XCTAssertEqual(rig.posting.discarded.count, 2, "failed drafts never stay in the outbox to replay later")
        XCTAssertEqual(rig.sendCenter.postedCount, 0)
    }

    func testDailyAnswerDraftCarriesFrontAndInvitation() async {
        let rig = CaptureTestRig()
        _ = await rig.sendCenter.send(request(groups: ["g1"], invitationID: "inv-9", daily: true))
        let draft = try! XCTUnwrap(rig.posting.published.first)
        XCTAssertEqual(draft.kind, .photo)
        XCTAssertEqual(draft.invitationID, InvitationID("inv-9"))
        XCTAssertEqual(draft.groupIDs, [GroupID("g1")])
        XCTAssertNotNil(draft.front)
        XCTAssertEqual(draft.front?.contentType, ContentType.jpeg)
        XCTAssertEqual(draft.width, 300)
        XCTAssertEqual(draft.frontHeight, 400)
    }
}

final class CaptureDraftBuilderTests: XCTestCase {
    func testPhotoIsReencodedJPEGWithoutLocationAtFullSize() async throws {
        let request = CaptureSendRequest(payload: .media(.photo(CaptureTestImages.still(), capturedAt: Date())), groupIDs: ["g1", "g2"], caption: "   ")
        let draft = try await CaptureDraftBuilder.build(request)
        defer { CaptureDraftBuilder.cleanUp(request) }
        XCTAssertEqual(draft.kind, .photo)
        XCTAssertEqual(draft.groupIDs.map(\.rawValue), ["g1", "g2"])
        XCTAssertNil(draft.caption, "a blank caption is no caption")
        XCTAssertEqual(draft.width, 300)
        XCTAssertEqual(draft.height, 400)
        let data = try Data(contentsOf: draft.original.url)
        XCTAssertFalse(ImageEncoder.containsLocation(data))
        XCTAssertEqual(draft.original.url.pathExtension, "jpg")
    }

    func testLivePhotoKeepsMotion() async throws {
        let movie = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        try Data().write(to: movie)
        var still = CaptureTestImages.still()
        still.livePhotoMovieURL = movie
        let request = CaptureSendRequest(payload: .media(.photo(still, capturedAt: Date())), groupIDs: ["g1"])
        let draft = try await CaptureDraftBuilder.build(request)
        XCTAssertEqual(draft.kind, .livePhoto)
        XCTAssertEqual(draft.motion?.url, movie)
        XCTAssertEqual(draft.motion?.contentType, ContentType.quickTime)
    }

    func testVideoUsesFileAndDuration() async throws {
        let movie = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        try Data().write(to: movie)
        let request = CaptureSendRequest(payload: .media(.video(CaptureVideo(fileURL: movie, durationMs: 4200), capturedAt: Date())), groupIDs: ["g1"])
        let draft = try await CaptureDraftBuilder.build(request)
        XCTAssertEqual(draft.kind, .video)
        XCTAssertEqual(draft.durationMs, 4200)
        XCTAssertEqual(draft.original.contentType, ContentType.quickTime)
    }
}

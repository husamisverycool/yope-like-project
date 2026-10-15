// camera.sendto view model and the background send (outbox) — design/surfaces/camera.sendto.md,
// docs/API.md recipe 9.4.
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

    func testLeftGroupPreselectsNothingAndHidesSend() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel(contextGroupID: "left-group")
        await model.load()
        XCTAssertTrue(model.selection.isEmpty)
        XCTAssertFalse(model.canSend, "the send button is hidden with nothing selected")
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

    func testSendSubmitsAndClosesAtOnce() async {
        let rig = CaptureTestRig()
        var sent = 0
        let model = rig.sendToModel(contextGroupID: "fake-group-1", onSent: { sent += 1 })
        await model.load()
        model.caption = "  sunset  "
        model.send()
        XCTAssertEqual(sent, 1, "the sheet closes before the upload finishes")
        let posted = await captureEventually { rig.posting.published.count == 1 }
        XCTAssertTrue(posted)
        let draft = try! XCTUnwrap(rig.posting.published.first)
        XCTAssertEqual(draft.groupIDs, [GroupID("fake-group-1")])
        XCTAssertEqual(draft.caption, "  sunset  ")
        XCTAssertEqual(draft.kind, .photo)
        XCTAssertEqual(draft.original.contentType, ContentType.jpeg)
        XCTAssertNil(draft.invitationID)
        XCTAssertEqual(rig.haptics, [Tokens.Haptics.globalSend])
        XCTAssertEqual(rig.sendCenter.confirmation, Copy.cameraSendtoToastPostedOne(group: CaptureFakes.groups[0].name),
                       "the lime toast for camera.sendto.duration.toastVisible")
    }

    func testHoldRecordsAndLiftKeepsTheVoiceNote() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel()
        await model.load()
        XCTAssertTrue(model.showsVoiceCoach, "voice coach on first use")
        let started = await model.beginVoiceRecording()
        XCTAssertTrue(started)
        XCTAssertEqual(model.voicePhase, .holding)
        XCTAssertTrue(model.showsVoiceRow, "the recorder row replaces the field")
        XCTAssertTrue(rig.coach.isDismissed(.voice))
        model.keepVoiceRecording()
        XCTAssertEqual(model.voicePhase, .idle)
        XCTAssertEqual(model.voiceNote?.durationMs, 1000)
        XCTAssertTrue(model.showsVoiceRow, "attached: delete · length · play")
        model.toggleVoicePlayback()
        XCTAssertTrue(model.isPlayingVoice)
    }

    func testTooShortRecordingIsNotANote() async {
        let rig = CaptureTestRig()
        rig.voice.recordedDurationMs = 400
        let model = rig.sendToModel()
        await model.beginVoiceRecording()
        model.keepVoiceRecording()
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

    func testLockPauseThenKeep() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel()
        await model.beginVoiceRecording()
        model.lockVoiceRecording()
        XCTAssertEqual(model.voicePhase, .locked)
        model.pauseVoiceRecording()
        XCTAssertEqual(model.voicePhase, .paused)
        XCTAssertNotNil(model.voiceDraft)
        model.toggleVoicePlayback()
        XCTAssertEqual(rig.voice.playedFiles.count, 1, "the draft can be played")
        model.keepVoiceRecording()
        XCTAssertEqual(model.voicePhase, .idle)
        XCTAssertNotNil(model.voiceNote)
        XCTAssertNil(model.voiceDraft)
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
        model.keepVoiceRecording()
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
        model.send()
        let posted = await captureEventually { rig.posting.published.count == 1 }
        XCTAssertTrue(posted)
        XCTAssertEqual(rig.posting.published.first?.voice?.contentType, ContentType.m4a)
        XCTAssertEqual(rig.posting.published.first?.voiceDurationMs, 1000, "a recording in progress is kept on send")
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
        model.send()
        let posted = await captureEventually { rig.posting.published.count == 1 }
        XCTAssertTrue(posted)
        XCTAssertEqual(rig.posting.published.first?.replyToPostID, PostID("post-9"))
        XCTAssertEqual(rig.replyClears, 1, "the handoff is cleared once the reply is sent")
    }

    func testNoReplyWithoutHandoff() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel(contextGroupID: "fake-group-1")
        await model.load()
        model.send()
        let posted = await captureEventually { rig.posting.published.count == 1 }
        XCTAssertTrue(posted)
        XCTAssertNil(rig.posting.published.first?.replyToPostID)
    }

    func testSaveUsesLibrary() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel()
        await model.save()
        XCTAssertEqual(rig.library.saved.count, 1)
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

    func testOfflineFailureShowsToastAndRetriesWhenOnline() async {
        let rig = CaptureTestRig()
        rig.posting.publishError = .offline
        let center = rig.sendCenter
        center.startObservingNetwork()
        await center.send(request())
        XCTAssertEqual(center.failure, .offline)
        XCTAssertEqual(rig.haptics, [Tokens.Haptics.globalError])
        XCTAssertEqual(rig.posting.pending.count, 1, "the outbox keeps the draft")

        rig.posting.publishError = nil
        rig.posting.goOnline()
        let cleared = await captureEventually { center.failure == nil && rig.posting.published.count == 1 }
        XCTAssertTrue(cleared)
        XCTAssertEqual(rig.haptics.last, Tokens.Haptics.globalSend)
    }

    func testPermanentFailureAndManualRetry() async {
        let rig = CaptureTestRig()
        rig.posting.publishError = .api(.notGroupMember)
        let center = rig.sendCenter
        await center.send(request())
        XCTAssertEqual(center.failure, .sendFailed)
        await center.retry()
        XCTAssertEqual(center.failure, .sendFailed, "still failing")
        rig.posting.publishError = nil
        await center.retry()
        XCTAssertNil(center.failure)
        XCTAssertEqual(rig.posting.published.count, 1)
        XCTAssertEqual(center.postedCount, 1)
    }

    func testDailyAnswerDraftCarriesFrontAndInvitation() async {
        let rig = CaptureTestRig()
        await rig.sendCenter.send(request(groups: ["g1"], invitationID: "inv-9", daily: true))
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

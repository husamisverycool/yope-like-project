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
    }

    func testCloseDiscardsVoiceNote() async throws {
        let rig = CaptureTestRig()
        var closed = 0
        let model = rig.sendToModel(onClose: { closed += 1 })
        await model.load()
        try XCTSkipUnless(model.isVoiceNoteAvailable, "voice note is DEBUG-only (chat.voice.layout.recording BLOCKED)")
        await model.toggleVoiceRecording()
        XCTAssertTrue(model.isRecordingVoice)
        XCTAssertTrue(rig.coach.isDismissed(.voice))
        await model.toggleVoiceRecording()
        XCTAssertNotNil(model.voiceNote)
        model.close()
        XCTAssertNil(model.voiceNote)
        XCTAssertEqual(closed, 1)
    }

    func testVoiceNoteGoesOnThePost() async throws {
        let rig = CaptureTestRig()
        let model = rig.sendToModel()
        await model.load()
        try XCTSkipUnless(model.isVoiceNoteAvailable)
        await model.toggleVoiceRecording()
        model.send()
        let posted = await captureEventually { rig.posting.published.count == 1 }
        XCTAssertTrue(posted)
        XCTAssertEqual(rig.posting.published.first?.voice?.contentType, ContentType.m4a)
        XCTAssertEqual(rig.posting.published.first?.voiceDurationMs, 1000)
    }

    func testMicrophoneDeniedOpensSettings() async throws {
        let rig = CaptureTestRig()
        rig.voice.status = .denied
        let model = rig.sendToModel()
        try XCTSkipUnless(model.isVoiceNoteAvailable)
        await model.toggleVoiceRecording()
        XCTAssertFalse(model.isRecordingVoice)
        XCTAssertEqual(rig.navigation.settingsOpened, 1)
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
            let answer = DailyAnswer(main: CaptureTestImages.still(), inset: CaptureTestImages.still(hue: 0.6), capturedAt: Date())
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

// camera.capture / camera.fromwidget view model (design/surfaces/camera.capture.md).
@testable import App
import AppData
import AppModels
import AppServices
import DesignSystem
import XCTest

@MainActor
final class CaptureCameraModelTests: XCTestCase {
    override func setUp() async throws {
        CameraCaptureModel.sessionPosition = .back
    }

    func testOpensLiveWithBackPhotoSessionAndFlash() async {
        let rig = CaptureTestRig()
        let model = rig.cameraModel()
        XCTAssertEqual(model.phase, .starting, "viewfinder black until the first frame")
        await model.appear()
        XCTAssertEqual(model.phase, .live)
        XCTAssertEqual(rig.camera.configuredModes.last, .photo(model.position))
        XCTAssertTrue(model.isFlashAvailable)
        XCTAssertFalse(model.isFlashOn, "flash defaults to off")
    }

    func testFirstOpenAsksThenDeniedShowsDeniedState() async {
        let rig = CaptureTestRig()
        rig.camera.authorizationStatus = .notDetermined
        rig.camera.accessResult = .denied
        let model = rig.cameraModel()
        await model.appear()
        XCTAssertEqual(model.phase, .denied)
        XCTAssertTrue(rig.camera.configuredModes.isEmpty)
        model.openSettings()
        XCTAssertEqual(rig.navigation.settingsOpened, 1)
    }

    func testRestrictedIsDenied() async {
        let rig = CaptureTestRig()
        rig.camera.authorizationStatus = .restricted
        let model = rig.cameraModel()
        await model.appear()
        XCTAssertEqual(model.phase, .denied)
    }

    func testSessionFailureIsUnavailableAndRetryRecovers() async {
        let rig = CaptureTestRig()
        rig.camera.failsConfigure = true
        let model = rig.cameraModel()
        await model.appear()
        XCTAssertEqual(model.phase, .unavailable)
        rig.camera.failsConfigure = false
        await model.retry()
        XCTAssertEqual(model.phase, .live)
    }

    func testInterruptionShowsUnavailableAndResumes() async {
        let rig = CaptureTestRig()
        let model = rig.cameraModel()
        await model.appear()
        rig.camera.interrupt(true)
        XCTAssertEqual(model.phase, .unavailable)
        rig.camera.interrupt(false)
        let resumed = await captureEventually { model.phase == .live }
        XCTAssertTrue(resumed)
    }

    func testOneTapCapturesPhotoWithFlashAndOpensSendTo() async {
        let rig = CaptureTestRig()
        let model = rig.cameraModel()
        await model.appear()
        model.toggleFlash()
        XCTAssertTrue(model.isFlashOn)
        model.shutterTouchDown()
        XCTAssertTrue(model.isShutterPressed, "pressed disc and scale")
        model.shutterTouchUp()
        let captured = await captureEventually { model.captured != nil }
        XCTAssertTrue(captured)
        XCTAssertEqual(model.captured?.kind, .photo)
        XCTAssertEqual(rig.camera.flashRequests, [true])
        XCTAssertFalse(model.isShutterPressed)
    }

    func testFlashHiddenWithoutFlash() async {
        let rig = CaptureTestRig()
        rig.camera.flashAvailable = false
        let model = rig.cameraModel()
        await model.appear()
        XCTAssertFalse(model.isFlashAvailable)
        model.toggleFlash()
        XCTAssertFalse(model.isFlashOn)
    }

    func testFlipSwitchesCameraAndKeepsItForTheSession() async {
        let rig = CaptureTestRig()
        let model = rig.cameraModel()
        await model.appear()
        let start = model.position
        await model.flip()
        XCTAssertEqual(model.position, start.flipped)
        XCTAssertEqual(rig.camera.configuredModes.last, .photo(start.flipped))
        let next = rig.cameraModel()
        XCTAssertEqual(next.position, start.flipped, "front after a flip, kept for the session")
    }

    func testFreeLongPressPromptsPaywallOnceAndNeverBlocksTap() async {
        let rig = CaptureTestRig()
        let model = rig.cameraModel()
        await model.appear()
        XCTAssertFalse(model.isVideoAvailable)
        XCTAssertFalse(model.showsCoach, "coach only for members who can record video")

        model.shutterTouchDown()
        _ = await captureEventually { rig.premium.promptRequests == 1 }
        model.shutterTouchUp()
        XCTAssertEqual(rig.premium.promptRequests, 1)
        XCTAssertFalse(rig.camera.isRecording)

        model.shutterTouchDown()
        try? await Task.sleep(nanoseconds: 80_000_000)
        model.shutterTouchUp()
        XCTAssertEqual(rig.premium.promptRequests, 1, "later long presses do nothing")

        await model.takePhoto()
        XCTAssertNotNil(model.captured, "tapping always captures")
    }

    func testPremiumHoldRecordsVideoAndDismissesCoach() async {
        let rig = CaptureTestRig()
        rig.premium.premium = true
        let model = rig.cameraModel()
        await model.appear()
        XCTAssertTrue(model.showsCoach)

        model.shutterTouchDown()
        let recording = await captureEventually { model.isRecording }
        XCTAssertTrue(recording)
        XCTAssertEqual(rig.camera.configuredModes.last, .video(model.position))
        XCTAssertEqual(model.recordingStarts, 1)

        model.shutterTouchUp()
        let video = await captureEventually { model.captured?.kind == .video }
        XCTAssertTrue(video)
        XCTAssertFalse(model.showsCoach)
        XCTAssertTrue(rig.coach.isDismissed(.holdToRecord), "the first recorded video dismisses the coach for good")
        XCTAssertEqual(rig.camera.configuredModes.last, .photo(model.position), "back to photo after recording")
    }

    func testCoachCloseIsPermanent() async {
        let rig = CaptureTestRig()
        rig.premium.premium = true
        let model = rig.cameraModel()
        await model.appear()
        model.dismissCoach()
        XCTAssertFalse(model.showsCoach)
        let next = rig.cameraModel()
        await next.appear()
        XCTAssertFalse(next.showsCoach)
    }

    func testFreeMemberPickingVideoAsksPaywallOnce() async {
        let rig = CaptureTestRig()
        rig.premium.allowsPrompt = false
        let model = rig.cameraModel()
        await model.appear()
        let video = CapturedMedia.video(CaptureVideo(fileURL: URL(fileURLWithPath: "/tmp/v.mov"), durationMs: 1000), capturedAt: Date())
        model.didPick(video)
        XCTAssertEqual(rig.premium.promptRequests, 1)
        XCTAssertEqual(model.captured?.kind, .video, "prompt refused: send-to opens; its send button stays hidden")
    }

    func testDiscardAndSendResults() async {
        let rig = CaptureTestRig()
        let model = rig.cameraModel(contextGroupID: "fake-group-2")
        await model.appear()
        await model.takePhoto()
        model.discardCapture()
        XCTAssertNil(model.captured)
        XCTAssertEqual(rig.navigation.closeCount, 0, "✕ returns to the camera")
        await model.takePhoto()
        model.didSend()
        XCTAssertNil(model.captured)
        XCTAssertEqual(rig.navigation.closeCount, 1, "send closes the camera at once")
        XCTAssertEqual(model.contextGroupID, "fake-group-2")
    }

    func testDisappearStopsSession() async {
        let rig = CaptureTestRig()
        let model = rig.cameraModel()
        await model.appear()
        await model.disappear()
        XCTAssertEqual(rig.camera.stopCount, 1)
    }

    func testHourOverlayIsStartOfHourInShortTimeStyle() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 17, minute: 42))!
        XCTAssertEqual(CaptureFormat.hourStart(of: date, calendar: calendar), calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 17)))
        let text = CaptureFormat.hourOverlay(at: date, calendar: calendar, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(text.replacingOccurrences(of: "\u{202F}", with: " "), "5:00 PM")
        XCTAssertEqual(CaptureFormat.nextHour(after: date, calendar: calendar), calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 18)))
    }
}

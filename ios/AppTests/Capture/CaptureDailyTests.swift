// daily.capture (countdown, dual capture with sequential / single-camera fallback, answering after
// the window) and daily.dualimage — design/surfaces/daily.capture.md, daily.dualimage.md.
@testable import App
import AppData
import AppModels
import AppServices
import DesignSystem
import XCTest

@MainActor
final class CaptureDailyModelTests: XCTestCase {
    func testOpenWindowShowsCountdownThenNothingAfterClose() async {
        let rig = CaptureTestRig()
        let now = Date()
        rig.openInvitation(closingIn: 95, now: now)
        let model = rig.dailyModel()
        await model.appear()
        XCTAssertEqual(model.phase, .live)
        XCTAssertEqual(rig.dualCamera.configuredModes.last, .dual)
        XCTAssertEqual(model.remainingSeconds(at: now), 95)
        XCTAssertEqual(model.remainingSeconds(at: now.addingTimeInterval(94.2)), 1, "rounded up: 0 exactly at the close")
        XCTAssertNil(model.remainingSeconds(at: now.addingTimeInterval(95)), "removed at closes_at; nothing in its place")
        XCTAssertNil(model.remainingSeconds(at: now.addingTimeInterval(600)))
        XCTAssertEqual(model.groupName, CaptureFakes.groups[0].name)
    }

    func testOfflineInvitationHasNoCountdownButStillPostsWithInvitation() async {
        let rig = CaptureTestRig()
        rig.invitations.error = DataError.offline
        let model = rig.dailyModel()
        await model.appear()
        XCTAssertNil(model.remainingSeconds(at: Date()))
        await model.shutter()
        await model.send()
        XCTAssertEqual(rig.posting.published.count, 1)
        XCTAssertEqual(rig.posting.published.first?.invitationID, InvitationID("inv-1"), "the server decides in_window")
    }

    func testDualCaptureMainIsBackInsetIsFront() async {
        let rig = CaptureTestRig()
        rig.openInvitation(closingIn: 100)
        let model = rig.dailyModel()
        await model.appear()
        model.toggleFlash()
        await model.shutter()
        XCTAssertEqual(model.phase, .preview)
        XCTAssertEqual(model.answer?.main.position, .back)
        XCTAssertEqual(model.answer?.inset?.position, .front)
        XCTAssertNotNil(model.mainImage, "decoded before the preview appears (one frame)")
        XCTAssertNotNil(model.insetImage)
        XCTAssertEqual(rig.dualCamera.flashRequests, [true])
    }

    func testFlipSwapsMainPhoto() async {
        let rig = CaptureTestRig()
        let model = rig.dailyModel()
        await model.appear()
        model.flip()
        await model.shutter()
        XCTAssertEqual(model.answer?.main.position, .front)
        XCTAssertEqual(model.answer?.inset?.position, .back)
    }

    func testFrontCameraFailureFallsBackToBackPhotoAlone() async {
        let rig = CaptureTestRig()
        rig.dualCamera.failsDual = true
        let model = rig.dailyModel()
        await model.appear()
        await model.shutter()
        XCTAssertEqual(model.phase, .preview)
        XCTAssertNil(model.answer?.inset, "single-camera answer")
        XCTAssertEqual(rig.dualCamera.configuredModes.last, .photo(.back))
        XCTAssertEqual(model.dualImageLabel, Copy.widgetHomeSmallA11yPhoto(name: "", group: CaptureFakes.groups[0].name))
    }

    func testMissingFrontPhotoIsSingleCamera() async {
        let rig = CaptureTestRig()
        rig.dualCamera.hasFrontCamera = false
        let model = rig.dailyModel()
        await model.appear()
        await model.shutter()
        XCTAssertNil(model.answer?.inset)
    }

    func testRetakeIsUnlimitedAndReturnsLive() async {
        let rig = CaptureTestRig()
        let model = rig.dailyModel()
        await model.appear()
        for _ in 0..<3 {
            await model.shutter()
            XCTAssertEqual(model.phase, .preview)
            await model.retake()
            XCTAssertEqual(model.phase, .live)
            XCTAssertNil(model.answer)
        }
    }

    func testSendPostsToInvitationGroupAndCloses() async {
        let rig = CaptureTestRig()
        rig.openInvitation(closingIn: 60)
        let model = rig.dailyModel()
        await model.appear()
        await model.shutter()
        await model.send()
        XCTAssertFalse(model.isSending)
        XCTAssertEqual(rig.navigation.closeCount, 1, "the cover closes once posted")
        XCTAssertEqual(rig.posting.published.count, 1)
        XCTAssertEqual(rig.sendCenter.confirmations.message, Copy.cameraSendtoToastPostedOne(group: CaptureFakes.groups[0].name),
                       "iOS confirms with an accessibility announcement (C-26)")
        let draft = try! XCTUnwrap(rig.posting.published.first)
        XCTAssertEqual(draft.groupIDs, [GroupID(CaptureFakes.groups[0].id)])
        XCTAssertEqual(draft.invitationID, InvitationID("inv-1"))
        XCTAssertNotNil(draft.front)
        XCTAssertEqual(rig.haptics, [Tokens.Haptics.globalSend])
    }

    func testAnsweringAfterTheWindowPostsNormally() async {
        let rig = CaptureTestRig()
        rig.openInvitation(closingIn: -30)
        let model = rig.dailyModel()
        await model.appear()
        XCTAssertNil(model.remainingSeconds(at: Date()), "no countdown, no 'late' label")
        await model.shutter()
        await model.send()
        XCTAssertEqual(rig.posting.published.count, 1)
    }

    func testDeniedAndUnavailableAndDismiss() async {
        let rig = CaptureTestRig()
        rig.dualCamera.authorizationStatus = .denied
        let denied = rig.dailyModel()
        await denied.appear()
        XCTAssertEqual(denied.phase, .denied)

        let other = CaptureTestRig()
        other.dualCamera.failsConfigure = true
        let unavailable = other.dailyModel()
        await unavailable.appear()
        XCTAssertEqual(unavailable.phase, .unavailable)

        unavailable.dismiss()
        XCTAssertEqual(other.navigation.closeCount, 1)
    }

    func testSendFailureKeepsThePreviewAndRetries() async {
        let rig = CaptureTestRig()
        rig.posting.publishError = .offline
        let model = rig.dailyModel()
        await model.appear()
        await model.shutter()
        await model.send()
        XCTAssertEqual(model.sendFailure, .offline, "the native alert: Check your connection")
        XCTAssertEqual(model.phase, .preview, "the preview is kept")
        XCTAssertNotNil(model.answer)
        XCTAssertEqual(rig.navigation.closeCount, 0)
        XCTAssertEqual(rig.haptics, [Tokens.Haptics.globalError])
        XCTAssertTrue(rig.posting.pending.isEmpty, "the failed outbox draft is discarded; Try Again sends a new one")
        XCTAssertEqual(rig.posting.discarded.count, 1)

        rig.posting.publishError = nil
        await model.retrySend()
        XCTAssertNil(model.sendFailure)
        XCTAssertEqual(rig.posting.published.count, 1)
        XCTAssertEqual(rig.navigation.closeCount, 1)
    }

    func testCancelKeepsThePreview() async {
        let rig = CaptureTestRig()
        rig.posting.publishError = .api(.notGroupMember)
        let model = rig.dailyModel()
        await model.appear()
        await model.shutter()
        await model.send()
        XCTAssertEqual(model.sendFailure, .sendFailed)
        model.dismissSendFailure()
        XCTAssertNil(model.sendFailure)
        XCTAssertEqual(model.phase, .preview)
    }

    func testRetakeAndDismissWaitWhileSending() async {
        let rig = CaptureTestRig()
        rig.posting.suspendsPublish = true
        let model = rig.dailyModel()
        await model.appear()
        await model.shutter()
        let send = Task { await model.send() }
        _ = await captureEventually { model.isSending }
        await model.retake()
        model.dismiss()
        XCTAssertEqual(model.phase, .preview, "retake is disabled while sending")
        XCTAssertEqual(rig.navigation.closeCount, 0, "close is disabled while sending")
        send.cancel()
    }
}

final class CaptureCountdownFormatTests: XCTestCase {
    func testMinutesAndSecondsZeroPadded() {
        XCTAssertEqual(CaptureFormat.countdown(remainingSeconds: 119), "01:59")
        XCTAssertEqual(CaptureFormat.countdown(remainingSeconds: 120), "02:00")
        XCTAssertEqual(CaptureFormat.countdown(remainingSeconds: 5), "00:05")
        XCTAssertEqual(CaptureFormat.countdown(remainingSeconds: -3), "00:00")
    }

    func testSpokenValueHasNoLabelWords() {
        let spoken = CaptureFormat.spokenCountdown(remainingSeconds: 75)
        XCTAssertFalse(spoken.isEmpty)
        XCTAssertFalse(spoken.lowercased().contains("late"))
    }

    func testCollageDateIsTheLocaleLongDate() {
        let date = LocalDate(year: 2026, month: 5, day: 26)!
        XCTAssertEqual(CaptureFormat.collageDate(date, locale: Locale(identifier: "en_US")), "May 26, 2026", "retro.voice.formats: 'May 1, 2019'")
    }

    func testVoiceDurationIsRetrosMediaFormat() {
        XCTAssertEqual(CaptureFormat.voiceDuration(milliseconds: 7_400), "0:07")
        XCTAssertEqual(CaptureFormat.voiceDuration(milliseconds: 60_000), "1:00")
    }

    func testMessageCounter() {
        XCTAssertEqual(CaptureFormat.messageCounter(count: 58, max: 250), "58/250")
    }

    func testFirstName() {
        XCTAssertEqual(CaptureFormat.firstName("Ana Lima"), "Ana")
        XCTAssertEqual(CaptureFormat.firstName(nil), "")
    }

    func testCounterRoleUsesTheCalloutStyle() {
        XCTAssertEqual(CaptureType.counter.size, Tokens.FontSizes.cameraSendtoFontSizeCounter)
        XCTAssertEqual(CaptureType.counter.relativeTo, .callout)
    }
}

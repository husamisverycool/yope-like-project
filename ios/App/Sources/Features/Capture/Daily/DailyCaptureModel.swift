// Surface: daily.capture — reference app: BeReal.
// Reference images: references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png,
// tiktok-bereal-7339559678604627233_capture-seq_f540-f681.jpg, …_t21.30s_preview-keep-smiling.png,
// references/auto/bereal/help/help-21083708285725_bts-post-preview-2x.png (design/surfaces/daily.capture.md).
// Capture with the countdown; back + front together (simultaneous where the hardware allows,
// otherwise back then front); answering after the window posts normally with no label.
import AppData
import AppModels
import AppServices
import DesignSystem
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class DailyCaptureModel {
    enum Phase: Equatable {
        /// Camera starting (viewfinder black until the first frame).
        case starting
        case live
        /// Shutter pressed: controls out, viewfinder black, spinner + prompt.
        case capturing
        case preview
        case denied
        case unavailable
    }

    let groupID: String
    let invitationID: String

    private(set) var phase: Phase = .starting
    private(set) var invitation: CaptureInvitation? = nil
    private(set) var groupName = ""
    private(set) var memberName = ""
    private(set) var isFlashOn = false
    private(set) var isFlashAvailable = false
    /// Which camera is the main photo of this capture (flip swaps it).
    private(set) var mainPosition: CameraPosition = .back
    private(set) var isShutterPressed = false
    private(set) var answer: DailyAnswer? = nil
    /// The answer's photos decoded off the main actor at the viewfinder's size, so the preview
    /// appears in one frame (BeReal).
    private(set) var mainImage: UIImage? = nil
    private(set) var insetImage: UIImage? = nil

    let camera: CaptureCamera
    private let invitations: CaptureInvitationSource
    private let sendCenter: CaptureSendCenter
    private let navigation: CaptureNavigation

    init(
        groupID: String,
        invitationID: String,
        camera: CaptureCamera,
        invitations: CaptureInvitationSource,
        sendCenter: CaptureSendCenter,
        navigation: CaptureNavigation
    ) {
        self.groupID = groupID
        self.invitationID = invitationID
        self.camera = camera
        self.invitations = invitations
        self.sendCenter = sendCenter
        self.navigation = navigation
        camera.onInterruption = { [weak self] interrupted in
            guard let self else { return }
            if interrupted, self.phase == .live || self.phase == .starting {
                self.phase = .unavailable
            } else if !interrupted, self.phase == .unavailable {
                Task { await self.startSession() }
            }
        }
    }

    var clock: ServerClock { invitations.clock }

    // MARK: Lifecycle

    func appear() async {
        async let loaded: Void = loadInvitation()
        switch camera.authorization() {
        case .granted:
            await startSession()
        case .notDetermined:
            if await camera.requestAccess() == .granted {
                await startSession()
            } else {
                phase = .denied
            }
        default:
            phase = .denied
        }
        await loaded
    }

    func disappear() async {
        await camera.stop()
    }

    private func loadInvitation() async {
        groupName = await invitations.groupName(groupID: groupID)
        memberName = await invitations.myFirstName()
        // Without the invitation (offline) there is no countdown; the post still carries the
        // invitation id and the server decides `in_window`.
        if let loaded = try? await invitations.invitation(id: invitationID, groupID: groupID) {
            invitation = loaded
            if !loaded.groupName.isEmpty { groupName = loaded.groupName }
        }
    }

    func startSession() async {
        phase = .starting
        do {
            try await camera.configure(.dual)
            isFlashAvailable = camera.hasFlash(at: .back)
            if !isFlashAvailable { isFlashOn = false }
            phase = .live
        } catch {
            phase = .unavailable
        }
    }

    func retry() async {
        await startSession()
    }

    func openSettings() {
        navigation.openSystemSettings()
    }

    /// Remaining whole seconds while the window is open; nil when closed or unknown.
    func remainingSeconds(at date: Date) -> Int? {
        guard let invitation else { return nil }
        return CountdownState(opensAt: invitation.firesAt, closesAt: invitation.closesAt, now: date, clock: clock).remainingWholeSeconds
    }

    // MARK: Controls

    func toggleFlash() {
        guard isFlashAvailable else { return }
        isFlashOn.toggle()
    }

    /// Swaps which camera is the main photo for this capture.
    func flip() {
        guard phase == .live else { return }
        mainPosition = mainPosition.flipped
    }

    func shutterPressChanged(_ pressed: Bool) {
        guard phase == .live else { return }
        isShutterPressed = pressed
    }

    /// Takes both photos: simultaneous where supported, else back first, then front. When the
    /// dual capture fails, the back photo alone is the answer (single camera).
    func shutter() async {
        guard phase == .live else { return }
        isShutterPressed = false
        phase = .capturing
        let capturedAt = Date()
        do {
            let stills = try await camera.captureDual(flash: isFlashOn && isFlashAvailable)
            if mainPosition == .front, let front = stills.front {
                await showPreview(DailyAnswer(main: front, inset: stills.back, capturedAt: capturedAt))
            } else {
                await showPreview(DailyAnswer(main: stills.back, inset: stills.front, capturedAt: capturedAt))
            }
        } catch {
            await captureSingle(capturedAt: capturedAt)
        }
    }

    private func captureSingle(capturedAt: Date) async {
        do {
            try await camera.configure(.photo(.back))
            let still = try await camera.capturePhoto(flash: isFlashOn && isFlashAvailable)
            await showPreview(DailyAnswer(main: still, inset: nil, capturedAt: capturedAt))
        } catch {
            phase = .unavailable
        }
    }

    private func showPreview(_ answer: DailyAnswer) async {
        typealias Composition = Tokens.Layouts.DailyDualimageLayoutComposition
        let width = CaptureImageDecoder.pixels(Tokens.Layouts.DailyCaptureLayoutViewfinder.width)
        let mainPixels = width / Composition.mainAspect
        let insetPixels = width * Composition.insetWidthRatio / Composition.insetAspect
        async let main = CaptureImageDecoder.image(data: answer.main.imageData, maxPixelSize: mainPixels)
        async let inset = CaptureImageDecoder.image(optionalData: answer.inset?.imageData, maxPixelSize: insetPixels)
        mainImage = await main
        insetImage = await inset
        self.answer = answer
        phase = .preview
    }

    /// Back to the live screen; unlimited, no count.
    func retake() async {
        answer = nil
        mainImage = nil
        insetImage = nil
        await startSession()
    }

    /// Uploads and posts with `p_invitation_id`; the cover closes. Never fails for lateness.
    func send() {
        guard let answer, phase == .preview else { return }
        sendCenter.submit(CaptureSendRequest(
            payload: .daily(answer),
            groupIDs: [groupID],
            invitationID: invitationID,
            confirmation: Copy.cameraSendtoToastPostedOne(group: groupName)
        ))
        self.answer = nil
        navigation.closeCapture()
    }

    /// Dismisses, discarding an unsent preview; the invitation stays answerable from the group.
    func dismiss() {
        answer = nil
        navigation.closeCapture()
    }

    /// One label for the image; a single-camera answer uses the photo wording
    /// (`daily.dualimage.a11y.label` notes).
    var dualImageLabel: String {
        if answer?.inset == nil {
            return Copy.widgetHomeSmallA11yPhoto(name: memberName, group: groupName)
        }
        return Copy.dailyDualimageA11yLabel(name: memberName)
    }
}

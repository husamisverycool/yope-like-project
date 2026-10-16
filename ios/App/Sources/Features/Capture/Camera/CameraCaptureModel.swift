// Surface: camera.capture (+ camera.fromwidget) — visual reference Retro (composition), mechanics Locket.
// Reference images: references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png,
// references/auto/retro/press/tc-2025-12-rewind-device-a.png, references/auto/locket/store/locket-store-07.png
// (design/surfaces/camera.capture.md).
// State of the camera the app opens to: permission, session, flash, flip, one-tap photo,
// hold-to-record video (premium), coach, library pick → send-to.
import AppData
import AppModels
import AppServices
import DesignSystem
import Foundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class CameraCaptureModel {
    enum Phase: Equatable {
        /// Session starting: the viewfinder stays `color.global.backgroundDeep` until the first frame.
        case starting
        case live
        /// Camera permission denied or restricted.
        case denied
        /// Session failed or interrupted (camera in use elsewhere).
        case unavailable
    }

    /// The camera chosen in this app session ("front after a flip, kept for the session").
    static var sessionPosition: CameraPosition = .back

    static var currentSessionPosition: CameraPosition { sessionPosition }

    private(set) var phase: Phase = .starting
    /// True once the session has shown the live preview (a restart after a flip keeps the preview on screen).
    private(set) var hasBeenLive = false
    private(set) var position: CameraPosition
    private(set) var isFlashOn = false
    private(set) var isFlashAvailable = false
    private(set) var isShutterPressed = false
    private(set) var isRecording = false
    private(set) var isCapturing = false
    private(set) var isVideoAvailable = false
    private(set) var showsCoach = false
    /// A capture waiting in `camera.sendto` (presented while non-nil).
    var captured: CapturedMedia? = nil
    /// Increments when a recording starts (announcement trigger).
    private(set) var recordingStarts = 0

    /// The group from context (`app://camera?group=`, group screen, chat), preselected in send-to.
    let contextGroupID: String?
    /// camera.overnight's mode control (9 AM · Now): in 9 AM mode the shutter queues photos that develop later.
    let overnight: OvernightCaptureModel?

    let camera: CaptureCamera
    private let premium: CapturePremium
    private let coach: CaptureCoachStore
    private let clock: @MainActor () -> Date
    private let navigation: CaptureNavigation
    private let longPressThreshold: Duration
    @ObservationIgnored private var longPressTask: Task<Void, Never>?
    @ObservationIgnored private var maxDurationTask: Task<Void, Never>?
    @ObservationIgnored private var isTouching = false
    @ObservationIgnored private var longPressBegan = false
    @ObservationIgnored private var hasPromptedThisScreen = false

    /// - Parameter longPressThreshold: hold time that turns a press into a long press; the
    ///   platform's default (`UILongPressGestureRecognizer.minimumPressDuration`).
    init(
        contextGroupID: String?,
        camera: CaptureCamera,
        premium: CapturePremium,
        coach: CaptureCoachStore,
        navigation: CaptureNavigation,
        overnight: OvernightCaptureModel? = nil,
        longPressThreshold: Duration = CameraCaptureModel.platformLongPress,
        clock: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.contextGroupID = contextGroupID
        self.overnight = overnight
        self.camera = camera
        self.premium = premium
        self.coach = coach
        self.clock = clock
        self.navigation = navigation
        self.longPressThreshold = longPressThreshold
        position = Self.sessionPosition
        camera.onInterruption = { [weak self] interrupted in
            guard let self else { return }
            if interrupted {
                if self.phase == .live || self.phase == .starting { self.phase = .unavailable }
            } else if self.phase == .unavailable {
                Task { await self.startSession() }
            }
        }
    }

    static var platformLongPress: Duration {
        .milliseconds(Int((UILongPressGestureRecognizer().minimumPressDuration * 1000).rounded()))
    }

    // MARK: Lifecycle

    /// First open: the system alert appears directly over this screen (no pre-prompt).
    func appear() async {
        switch camera.authorization() {
        case .granted:
            break
        case .notDetermined:
            guard await camera.requestAccess() == .granted else {
                phase = .denied
                return
            }
        default:
            phase = .denied
            return
        }
        // The session first (first frame as early as possible); premium loads meanwhile.
        async let premiumStatus = premium.isPremium()
        await startSession()
        isVideoAvailable = await premiumStatus
        showsCoach = isVideoAvailable && !coach.isDismissed(.holdToRecord)
        await overnight?.appear()
    }

    /// `camera.capture.title`: "Week {number}", the week the photo will be added to.
    var title: String {
        Copy.cameraCaptureTitle(number: String(CaptureFormat.weekNumber(of: clock())))
    }

    func disappear() async {
        longPressTask?.cancel()
        maxDurationTask?.cancel()
        if isRecording { _ = try? await camera.stopRecording() }
        isRecording = false
        await camera.stop()
    }

    func startSession() async {
        phase = .starting
        do {
            try await camera.configure(.photo(position))
            isFlashAvailable = camera.hasFlash(at: position)
            if !isFlashAvailable { isFlashOn = false }
            phase = .live
            hasBeenLive = true
        } catch {
            phase = .unavailable
        }
    }

    /// `camera.capture.unavailable.button`: retries the session.
    func retry() async {
        await startSession()
    }

    func openSettings() {
        navigation.openSystemSettings()
    }

    /// camera.overnight's destination sheet offers groups.create when the member has no group (as camera.sendto).
    var canCreateGroup: Bool { navigation.canCreateGroup }

    // MARK: Controls

    func toggleFlash() {
        guard isFlashAvailable else { return }
        isFlashOn.toggle()
    }

    func flip() async {
        guard phase == .live, !isRecording else { return }
        position = position.flipped
        Self.sessionPosition = position
        await startSession()
    }

    func dismissCoach() {
        showsCoach = false
        coach.dismiss(.holdToRecord)
    }

    // MARK: Shutter: tap = photo, hold = video (premium)

    func shutterTouchDown() {
        guard phase == .live, !isTouching, !isCapturing else { return }
        isTouching = true
        longPressBegan = false
        isShutterPressed = true
        let threshold = longPressThreshold
        longPressTask = Task { [weak self] in
            try? await Task.sleep(for: threshold)
            guard !Task.isCancelled, let self, self.isTouching else { return }
            self.longPressBegan = true
            await self.beginLongPress()
        }
    }

    func shutterTouchUp() {
        guard isTouching else { return }
        isTouching = false
        isShutterPressed = false
        longPressTask?.cancel()
        if longPressBegan {
            Task { await endRecordingIfNeeded() }
        } else {
            Task { await takePhoto() }
        }
    }

    /// One tap: a photo (a Live Photo where supported) → camera.sendto. Never blocked. In 9 AM mode: see
    /// `takeOvernightPhoto`.
    func takePhoto() async {
        if let overnight, overnight.isLater {
            await takeOvernightPhoto(overnight)
            return
        }
        guard phase == .live, !isCapturing, !isRecording else { return }
        isCapturing = true
        defer { isCapturing = false }
        do {
            let still = try await camera.capturePhoto(flash: isFlashOn && isFlashAvailable)
            captured = .photo(still, capturedAt: Date())
        } catch {
            phase = .unavailable
        }
    }

    /// 9 AM mode (camera.overnight): one photo without Live Photo motion, straight to the upload queue for the chosen
    /// groups — no preview, no send-to — and the camera stays ready for the next one. No groups chosen: the destination
    /// sheet opens instead.
    private func takeOvernightPhoto(_ overnight: OvernightCaptureModel) async {
        guard phase == .live, !isCapturing else { return }
        guard !overnight.selection.isEmpty else {
            overnight.isDestinationOpen = true
            return
        }
        isCapturing = true
        defer { isCapturing = false }
        do {
            let still = try await camera.captureStill(flash: isFlashOn && isFlashAvailable)
            overnight.capture(still, capturedAt: clock())
        } catch {
            phase = .unavailable
        }
    }

    private func beginLongPress() async {
        // 9 AM mode takes photos only (camera.overnight: "tap = photo … Hold = nothing").
        if overnight?.isLater == true { return }
        guard isVideoAvailable else {
            // Free member: the session's first long press opens the paywall (at most one prompt
            // per session); later long presses do nothing.
            guard !hasPromptedThisScreen else { return }
            hasPromptedThisScreen = true
            _ = premium.presentPaywallIfAllowed()
            return
        }
        await startRecording()
    }

    /// Video (premium): records while held, up to `camera.capture.duration.videoMax`. The
    /// microphone is asked at the first video only, never before a photo.
    func startRecording() async {
        guard phase == .live, !isRecording else { return }
        if camera.microphoneAuthorization() == .notDetermined {
            _ = await camera.requestMicrophoneAccess()
            // The system alert ended the hold; the next hold records.
            guard isTouching else { return }
        }
        do {
            try await camera.configure(.video(position))
            try await camera.startRecording(maxDuration: Tokens.Durations.cameraCaptureDurationVideoMax)
            isRecording = true
            recordingStarts += 1
            AccessibilityNotification.Announcement(Copy.cameraCaptureA11yRecording).post()
            let limit = Tokens.Durations.cameraCaptureDurationVideoMax
            maxDurationTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(limit))
                guard !Task.isCancelled else { return }
                await self?.endRecordingIfNeeded()
            }
        } catch {
            await startSession()
        }
    }

    func endRecordingIfNeeded() async {
        guard isRecording else { return }
        maxDurationTask?.cancel()
        isRecording = false
        let video = try? await camera.stopRecording()
        if showsCoach || !coach.isDismissed(.holdToRecord) {
            // The first recorded video dismisses the coach for good.
            dismissCoach()
        }
        await startSession()
        if let video {
            captured = .video(video, capturedAt: Date())
        }
    }

    /// VoiceOver custom action `camera.capture.a11y.recordVideo`: starts, or stops, a recording.
    func toggleRecordingFromAccessibility() async {
        if isRecording {
            await endRecordingIfNeeded()
        } else if isVideoAvailable {
            await startRecording()
        }
    }

    // MARK: Library

    /// A photo, Live Photo or video picked in the system picker (no library permission).
    func didPick(_ media: CapturedMedia) {
        if media.needsPremium && !isVideoAvailable && !hasPromptedThisScreen {
            hasPromptedThisScreen = true
            if premium.presentPaywallIfAllowed() { return }
        }
        captured = media
    }

    // MARK: Send-to results

    /// ✕ in send-to: the capture is discarded and the camera is back.
    func discardCapture() {
        captured?.removeTemporaryFiles()
        captured = nil
    }

    /// Send tapped: the send-to sheet and the camera close at once.
    func didSend() {
        captured = nil
        navigation.closeCapture()
    }
}

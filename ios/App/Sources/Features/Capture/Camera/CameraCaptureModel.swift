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
    /// A capture waiting in `camera.sendto` (presented while non-nil); for several library photos, the first of them.
    var captured: CapturedMedia? = nil
    /// The rest of a library selection (several photos in one post), in the order picked; empty for one capture.
    private(set) var capturedMore: [CapturedMedia] = []
    /// share.in: the group picked in the share sheet's suggestion row for the capture waiting in send-to (nil: none).
    private(set) var sharedGroupID: String? = nil
    /// The most items the library picker offers (`batch_max_photos`, a public app_config key); 1 until it is known.
    private(set) var selectionLimit = 1
    /// camera.trim: a library video longer than `camera.capture.duration.videoMax` in the system trimmer (presented while
    /// non-nil); send-to follows with the trimmed copy.
    var trimming: CaptureTrimRequest? = nil
    /// camera.trim: the picked video cannot be trimmed on this device — the "Video too long" alert.
    var isVideoTooLong = false
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
    /// `public_app_config.batch_max_photos` (nil when unknown: one photo).
    private let batchLimit: @MainActor () async -> Int?
    /// Photos shared from another app (share.in), waiting in the App Group inbox, with the group picked in the share
    /// sheet; no media when none.
    private let sharedItems: @MainActor (_ limit: Int) async -> ShareInSelection
    /// A library selection on its way to send-to: videos over the limit go through the trimmer one at a time first.
    @ObservationIgnored private var pendingSelection: [CapturedMedia] = []
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
        clock: @escaping @MainActor () -> Date = { Date() },
        batchLimit: @escaping @MainActor () async -> Int? = { nil },
        sharedItems: @escaping @MainActor (_ limit: Int) async -> ShareInSelection = { _ in ShareInSelection() }
    ) {
        self.contextGroupID = contextGroupID
        self.overnight = overnight
        self.camera = camera
        self.premium = premium
        self.coach = coach
        self.clock = clock
        self.navigation = navigation
        self.longPressThreshold = longPressThreshold
        self.batchLimit = batchLimit
        self.sharedItems = sharedItems
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
        Task { [weak self] in await self?.loadSelectionLimit() }
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

    /// The group send-to preselects: the one picked in the share sheet for a shared capture, else the camera's context.
    var sendToGroupID: String? { sharedGroupID ?? contextGroupID }

    /// `camera.capture.title`: "Week {number}", the week the photo will be added to.
    var title: String {
        Copy.cameraCaptureTitle(number: String(CaptureFormat.weekNumber(of: clock())))
    }

    /// `batch_max_photos` for the library picker; it stays 1 when the server's value cannot be read.
    func loadSelectionLimit() async {
        if let limit = await batchLimit(), limit > 0 { selectionLimit = limit }
    }

    /// share.in: photos shared from another app open send-to as a library selection would (trimmer first for long videos).
    /// Waits while a capture is already being sent or trimmed; the items stay in the inbox until then. A group picked in
    /// the share sheet's suggestion row is preselected in send-to (`sendToGroupID`).
    func takeSharedItems() async {
        guard captured == nil, trimming == nil, pendingSelection.isEmpty else { return }
        await loadSelectionLimit()
        let shared = await sharedItems(selectionLimit)
        let items = shared.media
        guard !items.isEmpty, captured == nil, trimming == nil, pendingSelection.isEmpty else {
            items.forEach { $0.removeTemporaryFiles() }
            return
        }
        pick(items, sharedGroupID: shared.groupID)
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
            capturedMore = []
            sharedGroupID = nil
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
            capturedMore = []
            sharedGroupID = nil
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

    /// A photo, Live Photo or video picked in the system picker (no library permission). A video longer than the camera's
    /// limit goes to the system trimmer first (camera.trim; the server refuses longer videos, `video_too_long`).
    func didPick(_ media: CapturedMedia) {
        didPick([media])
    }

    /// Several items picked (or shared, share.in) at once, in the order picked: one send-to for the whole selection, each
    /// item its own post with the same `batch_id`. Each video longer than the limit goes through the trimmer in turn —
    /// its Cancel leaves that video out, and one that cannot be trimmed is left out after the "Video too long" alert; the
    /// others go on to send-to.
    func didPick(_ items: [CapturedMedia]) {
        pick(items, sharedGroupID: nil)
    }

    private func pick(_ items: [CapturedMedia], sharedGroupID: String?) {
        guard !items.isEmpty else { return }
        self.sharedGroupID = sharedGroupID
        if items.contains(where: \.needsPremium) && !isVideoAvailable && !hasPromptedThisScreen {
            hasPromptedThisScreen = true
            if premium.presentPaywallIfAllowed() { return }
        }
        pendingSelection = items
        continueSelection()
    }

    /// The next video over the limit opens the trimmer; with none left, send-to opens on the selection.
    private func continueSelection() {
        if let item = pendingSelection.first(where: { $0.video.map { CaptureVideoLimit.isTooLong($0.durationMs) } ?? false }),
           let video = item.video {
            if VideoTrimmer.canTrim(video.fileURL) {
                trimming = CaptureTrimRequest(video: video, mediaID: item.id)
            } else {
                dropFromSelection(item.id)
                item.removeTemporaryFiles()
                // The alert's dismissal continues with the rest (`videoTooLongDismissed`).
                isVideoTooLong = true
            }
            return
        }
        guard let first = pendingSelection.first else { return }
        capturedMore = Array(pendingSelection.dropFirst())
        pendingSelection = []
        captured = first
    }

    private func dropFromSelection(_ id: UUID) {
        pendingSelection.removeAll { $0.id == id }
    }

    /// The "Video too long" alert closed: the rest of the selection goes on (nothing when it was the only item).
    func videoTooLongDismissed() {
        isVideoTooLong = false
        continueSelection()
    }

    /// The trimmer closed: the trimmed copy takes the video's place in the selection; Cancel leaves the video out (back to
    /// the camera when it was the only item); a failure shows the alert.
    func didTrim(_ request: CaptureTrimRequest, to trimmed: URL?, failed: Bool) async {
        trimming = nil
        CapturedMedia.video(request.video, capturedAt: clock()).removeTemporaryFiles()
        let original = pendingSelection.first { $0.id == request.mediaID }
        guard let trimmed else {
            if let id = request.mediaID { dropFromSelection(id) }
            if failed {
                isVideoTooLong = true
            } else {
                continueSelection()
            }
            return
        }
        guard let duration = await CaptureDraftBuilder.durationMs(of: trimmed), !CaptureVideoLimit.isTooLong(duration) else {
            try? FileManager.default.removeItem(at: trimmed)
            if let id = request.mediaID { dropFromSelection(id) }
            isVideoTooLong = true
            return
        }
        let clip = CapturedMedia.video(CaptureVideo(fileURL: trimmed, durationMs: duration), capturedAt: clock(), takenOn: original?.takenOn)
        if let index = pendingSelection.firstIndex(where: { $0.id == request.mediaID }) {
            pendingSelection[index] = clip
        } else {
            pendingSelection = [clip]
        }
        continueSelection()
    }

    // MARK: Send-to results

    /// ✕ in send-to: the capture (the whole selection) is discarded and the camera is back.
    func discardCapture() {
        captured?.removeTemporaryFiles()
        capturedMore.forEach { $0.removeTemporaryFiles() }
        capturedMore = []
        sharedGroupID = nil
        captured = nil
    }

    /// Send tapped: the send-to sheet and the camera close at once.
    func didSend() {
        captured = nil
        capturedMore = []
        sharedGroupID = nil
        navigation.closeCapture()
    }
}

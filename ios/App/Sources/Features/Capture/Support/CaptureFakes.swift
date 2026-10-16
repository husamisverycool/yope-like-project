// Surfaces: camera.capture, camera.sendto, daily.capture, collage.view, collage.share (design/surfaces/<id>.md;
// reference images listed there). Fakes of the capture services (DEBUG only): unit tests, snapshot tests, and UI tests through the
// launch argument `CaptureLaunchArgument.fakes` (the simulator has no camera).
#if DEBUG
import AppData
import AppModels
import AppServices
import DesignSystem
import Foundation
import SwiftUI
import UIKit

enum FakeCaptureError: Error, Equatable {
    case failed
}

enum CaptureFakes {
    /// A small JPEG filled with `color` (a token), standing in for a camera photo.
    static func jpeg(_ color: Color) -> Data {
        let size = CGSize(width: 30, height: 40) // provenance-ok: fake capture pixel size (tests), not a design value
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor(color).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 1) ?? Data()
    }

    static func still(_ color: Color, position: CameraPosition? = .back) -> CaptureStill {
        CaptureStill(imageData: jpeg(color), livePhotoMovieURL: nil, pixelWidth: 30, pixelHeight: 40, position: position)
    }

    static let groups: [CaptureGroup] = [
        CaptureGroup(id: "fake-group-1", name: "Group 1", coverPath: nil),
        CaptureGroup(id: "fake-group-2", name: "Group 2", coverPath: nil),
    ]

    /// The Jolt demo's groups (`DemoMode`): the social demo's "roommates" and "climbing", with their covers.
    static var demoGroups: [CaptureGroup] {
        [
            CaptureGroup(id: SocialDemo.groupID.rawValue, name: "roommates", coverPath: "fake/cover/01"), // provenance-ok: demo data
            CaptureGroup(id: SocialDemo.otherGroupID.rawValue, name: "climbing", coverPath: "fake/cover/02"), // provenance-ok: demo data
        ]
    }

    /// A bundled demo photo as a capture (`DemoPhotos`).
    static func demoStill(_ name: String, position: CameraPosition) -> CaptureStill? {
        guard let shot = DemoPhotos.jpeg(named: name) else { return nil }
        return CaptureStill(imageData: shot.data, livePhotoMovieURL: nil, pixelWidth: shot.width, pixelHeight: shot.height, position: position)
    }

    /// The environment UI tests run against (launch argument `-capture-fakes`).
    @MainActor
    static func environment(arguments: [String], router: AppRouter) -> CaptureEnvironment {
        let listed = DemoMode.isOn ? Self.demoGroups : Self.groups
        let groups = FakeCaptureGroups(groups: CaptureLaunchArgument.isSet(CaptureLaunchArgument.fakeNoGroups, in: arguments) ? [] : listed)
        if DemoMode.isOn {
            for group in listed {
                if let path = group.coverPath, let cover = DemoPhotos.image(for: path) { groups.covers[path] = cover }
            }
        }
        let premium = FakeCapturePremium(isPremium: CaptureLaunchArgument.isSet(CaptureLaunchArgument.fakePremium, in: arguments))
        let invitations = FakeCaptureInvitations()
        invitations.invitation = CaptureInvitation(
            id: "fake-invitation",
            groupID: listed[0].id,
            groupName: listed[0].name,
            firesAt: Date(),
            closesAt: Date().addingTimeInterval(Tokens.Durations.cameraCaptureDurationVideoMax * 12),
            localDate: LocalDate(Date(), in: .current)
        )
        return CaptureEnvironment(
            makeCamera: { _ in DemoMode.isOn ? FakeCaptureCamera.demo() : FakeCaptureCamera() },
            makeVoiceRecorder: { FakeCaptureVoiceRecorder() },
            library: FakeCaptureLibrary(),
            groups: groups,
            premium: premium,
            posting: FakeCapturePosting(),
            invitations: invitations,
            collages: FakeCaptureCollages(),
            navigation: LiveCaptureNavigation(router: router),
            coach: InMemoryCaptureCoachStore()
        )
    }
}

// MARK: - Camera

@MainActor
final class FakeCaptureCamera: CaptureCamera {
    /// The Jolt demo's camera: a photo in the viewfinder, and the shutter takes sample photos (`DemoPhotos`).
    static func demo() -> FakeCaptureCamera {
        let camera = FakeCaptureCamera()
        camera.previewImage = DemoPhotos.image(named: DemoPhotos.viewfinder)
        camera.frontPreviewImage = DemoPhotos.image(named: DemoPhotos.frontShot)
        camera.backStill = CaptureFakes.demoStill(DemoPhotos.backShot, position: .back)
        camera.frontStill = CaptureFakes.demoStill(DemoPhotos.frontShot, position: .front)
        return camera
    }

    var authorizationStatus: PermissionStatus = .granted
    var accessResult: PermissionStatus = .granted
    var microphoneStatus: PermissionStatus = .granted
    var flashAvailable = true
    var failsConfigure = false
    var failsDual = false
    var hasFrontCamera = true
    /// Holds `captureDual` until cancelled (the 'capturing' state in snapshots).
    var suspendsCapture = false
    var previewImage: UIImage?
    /// The front camera's feed (a selfie reaction's live circle); nil: `previewImage`.
    var frontPreviewImage: UIImage?
    /// What the shutter returns (snapshot tests set photos); nil: small stills in token colours.
    var backStill: CaptureStill?
    var frontStill: CaptureStill?
    var onInterruption: ((Bool) -> Void)?

    private(set) var configuredModes: [CaptureCameraMode] = []
    private(set) var flashRequests: [Bool] = []
    /// Shots taken without Live Photo motion (`captureStill`).
    private(set) var stillRequests = 0
    private(set) var isRecording = false
    private(set) var stopCount = 0

    func authorization() -> PermissionStatus { authorizationStatus }

    func requestAccess() async -> PermissionStatus {
        authorizationStatus = accessResult
        return accessResult
    }

    func microphoneAuthorization() -> PermissionStatus { microphoneStatus }

    func requestMicrophoneAccess() async -> PermissionStatus {
        microphoneStatus = .granted
        return .granted
    }

    func hasFlash(at position: CameraPosition) -> Bool { flashAvailable && position == .back }

    func hasCamera(at position: CameraPosition) -> Bool { position == .back || hasFrontCamera }

    /// The camera the session runs (the last photo mode configured).
    private var activePosition: CameraPosition {
        if case let .photo(position)? = configuredModes.last { return position }
        return .back
    }

    func configure(_ mode: CaptureCameraMode) async throws {
        if failsConfigure { throw FakeCaptureError.failed }
        configuredModes.append(mode)
    }

    func stop() async {
        stopCount += 1
    }

    func capturePhoto(flash: Bool) async throws -> CaptureStill {
        flashRequests.append(flash)
        if activePosition == .front, let frontStill { return frontStill }
        return backStill ?? CaptureFakes.still(Tokens.Colors.globalAccent)
    }

    func captureStill(flash: Bool) async throws -> CaptureStill {
        stillRequests += 1
        var still = try await capturePhoto(flash: flash)
        still.livePhotoMovieURL = nil
        return still
    }

    func captureDual(flash: Bool) async throws -> CaptureDualStills {
        flashRequests.append(flash)
        if suspendsCapture { try await Task.sleep(for: .seconds(3600)) }
        if failsDual { throw FakeCaptureError.failed }
        return CaptureDualStills(
            back: backStill ?? CaptureFakes.still(Tokens.Colors.globalAccent, position: .back),
            front: hasFrontCamera ? frontStill ?? CaptureFakes.still(Tokens.Colors.globalSelection, position: .front) : nil,
            simultaneous: true
        )
    }

    func startRecording(maxDuration: TimeInterval) async throws {
        isRecording = true
    }

    func stopRecording() async throws -> CaptureVideo {
        isRecording = false
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        try Data().write(to: url)
        return CaptureVideo(fileURL: url, durationMs: 1000)
    }

    func preview(position: CameraPosition?) -> AnyView {
        let front = (position ?? activePosition) == .front
        return AnyView(FakeCameraPreview(image: front ? frontPreviewImage ?? previewImage : previewImage))
    }

    func interrupt(_ interrupted: Bool) {
        onInterruption?(interrupted)
    }
}

/// The fake camera feed: a still image, or no frame yet (`color.global.backgroundDeep`).
struct FakeCameraPreview: View {
    let image: UIImage?

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Tokens.Colors.globalBackgroundDeep
        }
    }
}

// MARK: - Library, groups, premium, voice

@MainActor
final class FakeCaptureLibrary: CaptureLibrary {
    private(set) var saved: [CapturedMedia] = []

    func save(_ media: CapturedMedia) async throws {
        saved.append(media)
    }
}

@MainActor
final class FakeCaptureGroups: CaptureGroupSource {
    var groups: [CaptureGroup]
    var cached: [CaptureGroup]?
    var loadError: Error?
    var isOffline = false
    /// Holds `loadGroups` until cancelled (the loading state in snapshots).
    var suspendsLoad = false
    var covers: [String: UIImage] = [:]

    init(groups: [CaptureGroup], cached: [CaptureGroup]? = nil) {
        self.groups = groups
        self.cached = cached
    }

    func cachedGroups() async -> [CaptureGroup]? { cached }

    func loadGroups() async throws -> [CaptureGroup] {
        if suspendsLoad { try await Task.sleep(for: .seconds(3600)) }
        if let loadError { throw loadError }
        return groups
    }

    func coverImage(path: String) async -> UIImage? { covers[path] }
}

@MainActor
final class FakeCapturePremium: CapturePremium {
    var premium: Bool
    var allowsPrompt = true
    private(set) var promptRequests = 0

    init(isPremium: Bool) {
        premium = isPremium
    }

    func isPremium() async -> Bool { premium }

    func presentPaywallIfAllowed() -> Bool {
        promptRequests += 1
        let allowed = allowsPrompt
        allowsPrompt = false
        return allowed
    }
}

@MainActor
final class FakeCaptureVoiceRecorder: CaptureVoiceRecorder {
    var status: PermissionStatus = .granted
    private(set) var isRecording = false
    /// Paused (between `pause()` and `resume()`).
    private(set) var isPaused = false
    var elapsedMs = 0
    /// The live waveform the fake reports, and the levels of the next stopped recording.
    var levels: [Int] = (0..<100).map { ($0 * 7) % 32 }
    /// Length of the next stopped recording.
    var recordedDurationMs = 1000
    private(set) var isPlaying = false
    private(set) var playedFiles: [URL] = []
    private(set) var playingFile: URL?
    /// The progress the fake reports while a file plays or is paused part-way (snapshots draw the played bars).
    var reportedProgress = 0.0
    var playbackProgress: Double? { playingFile == nil ? nil : reportedProgress }
    /// Drafts handed out for previews.
    private(set) var draftsMade = 0

    func togglePlayback(_ fileURL: URL) {
        isPlaying.toggle()
        if isPlaying {
            playedFiles.append(fileURL)
            playingFile = fileURL
        }
    }

    func stopPlayback() {
        isPlaying = false
        playingFile = nil
    }

    func permission() -> PermissionStatus { status }
    /// The system prompt: the fake grants.
    func requestPermission() async -> PermissionStatus {
        status = .granted
        return status
    }

    func start() throws {
        isRecording = true
        isPaused = false
    }

    func pause() {
        if isRecording { isPaused = true }
    }

    func resume() throws {
        isPaused = false
    }

    func draftFile() async throws -> URL {
        draftsMade += 1
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        try Data().write(to: url)
        return url
    }

    func stop() async throws -> VoiceNote {
        isRecording = false
        isPaused = false
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        try Data().write(to: url)
        return VoiceNote(fileURL: url, durationMs: recordedDurationMs, levels: levels)
    }

    func cancel() {
        isRecording = false
        isPaused = false
    }
}

@MainActor
final class InMemoryCaptureCoachStore: CaptureCoachStore {
    private(set) var dismissed: Set<CaptureCoach> = []

    init(dismissed: Set<CaptureCoach> = []) {
        self.dismissed = dismissed
    }

    func isDismissed(_ coach: CaptureCoach) -> Bool { dismissed.contains(coach) }
    func dismiss(_ coach: CaptureCoach) { dismissed.insert(coach) }
}

// MARK: - Posting

@MainActor
final class FakeCapturePosting: CapturePosting {
    /// When set, `publish` fails with it (the draft is kept in `pending`, like the outbox, until discarded).
    var publishError: DataError?
    /// Holds `publish` until cancelled (the sending state in snapshots).
    var suspendsPublish = false
    private(set) var published: [PostDraft] = []
    private(set) var pending: [PostDraft] = []
    private(set) var discarded: [MediaID] = []

    func publish(_ draft: PostDraft) async throws {
        if suspendsPublish { try await Task.sleep(for: .seconds(3600)) }
        if let publishError {
            pending.append(draft)
            throw publishError
        }
        published.append(draft)
        if draft.overnight == true {
            // A 9 AM photo develops: nothing to read until the reveal (`DemoDevelopingPhotos` in the Jolt demo).
            let reveal = revealAt ?? OvernightReveal.next(after: Date(), timeZones: [.current])
            developing = OvernightStatus(developing: true, revealAt: min(developing.revealAt ?? reveal, reveal))
            DemoDevelopingPhotos.add(draft, revealAt: reveal)
            return
        }
        // The Jolt demo: the photo joins its groups in the demo world.
        DemoSentPosts.add(draft)
    }

    func discard(_ mediaID: MediaID) async {
        discarded.append(mediaID)
        pending.removeAll { $0.mediaID == mediaID }
    }

    // MARK: Overnight

    /// What `my_developing()` answers; `publish` of a 9 AM draft sets it.
    var developing = OvernightStatus.notDeveloping
    /// When the fake's 9 AM photos develop; nil: the next 09:00 on this device when one is sent.
    var revealAt: Date?
    var developingError: DataError?

    func myDeveloping() async throws -> OvernightStatus {
        if let developingError { throw developingError }
        if DemoMode.isOn { return DemoDevelopingPhotos.status }
        return developing
    }
}

// MARK: - Invitations and collages

@MainActor
final class FakeCaptureInvitations: CaptureInvitationSource {
    var invitation: CaptureInvitation?
    var error: Error?
    var name = ""
    var clock: ServerClock = .device

    func invitation(id: String, groupID: String) async throws -> CaptureInvitation? {
        if let error { throw error }
        return invitation
    }

    func groupName(groupID: String) async -> String {
        invitation?.groupName ?? CaptureFakes.groups.first { $0.id == groupID }?.name ?? ""
    }

    func myFirstName() async -> String { name }
}

@MainActor
final class FakeCaptureCollages: CaptureCollageSource {
    var collage: Collage?
    var cached: Collage?
    var error: Error?
    /// Holds `collage(invitationID:)` until cancelled (the loading state in snapshots).
    var suspendsFetch = false
    var images: [String: UIImage] = [:]
    var cachedImages: [String: UIImage] = [:]
    var isOffline = false

    func collage(invitationID: String) async throws -> Collage? {
        if suspendsFetch { try await Task.sleep(for: .seconds(3600)) }
        if let error { throw error }
        return collage
    }

    func cachedCollage(invitationID: String) async -> Collage? { cached }

    func image(path: String) async throws -> UIImage {
        if let image = cachedImages[path] ?? images[path] { return image }
        throw error ?? FakeCaptureError.failed
    }

    func cachedImage(path: String) async -> UIImage? { cachedImages[path] }

    /// The first photo's storage path by the collage's first post id (nil: not resolvable).
    var firstPhotoPaths: [PostID: String] = [:]
    private(set) var firstPhotoRequests: [[PostID]] = []

    func firstPhotoPath(postIDs: [PostID]) async -> String? {
        firstPhotoRequests.append(postIDs)
        return postIDs.compactMap { firstPhotoPaths[$0] }.first
    }

    func shareFile(path: String) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent((path as NSString).lastPathComponent)
        try (images[path]?.jpegData(compressionQuality: 1) ?? Data()).write(to: url)
        return url
    }
}

// MARK: - Navigation

@MainActor
final class RecordingCaptureNavigation: CaptureNavigation {
    private(set) var closeCount = 0
    private(set) var openedCameraGroups: [String?] = []
    private(set) var settingsOpened = 0
    var canCreateGroup = true

    func closeCapture() { closeCount += 1 }
    func openCamera(groupID: String?) { openedCameraGroups.append(groupID) }
    func openSystemSettings() { settingsOpened += 1 }
}
#endif

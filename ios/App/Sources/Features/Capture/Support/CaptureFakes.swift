// Surfaces: camera.capture, camera.sendto, daily.capture, collage.view, collage.share.
// Fakes of the capture services (DEBUG only): unit tests, snapshot tests, and UI tests through the
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

    /// The environment UI tests run against (launch argument `-capture-fakes`).
    @MainActor
    static func environment(arguments: [String], router: AppRouter) -> CaptureEnvironment {
        let groups = FakeCaptureGroups(groups: CaptureLaunchArgument.isSet(CaptureLaunchArgument.fakeNoGroups, in: arguments) ? [] : Self.groups)
        let premium = FakeCapturePremium(isPremium: CaptureLaunchArgument.isSet(CaptureLaunchArgument.fakePremium, in: arguments))
        let invitations = FakeCaptureInvitations()
        invitations.invitation = CaptureInvitation(
            id: "fake-invitation",
            groupID: Self.groups[0].id,
            groupName: Self.groups[0].name,
            firesAt: Date(),
            closesAt: Date().addingTimeInterval(Tokens.Durations.cameraCaptureDurationVideoMax * 12),
            localDate: LocalDate(Date(), in: .current)
        )
        return CaptureEnvironment(
            makeCamera: { _ in FakeCaptureCamera() },
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
    var authorizationStatus: PermissionStatus = .granted
    var accessResult: PermissionStatus = .granted
    var microphoneStatus: PermissionStatus = .granted
    var flashAvailable = true
    var failsConfigure = false
    var failsDual = false
    var hasFrontCamera = true
    var previewImage: UIImage?
    var onInterruption: ((Bool) -> Void)?

    private(set) var configuredModes: [CaptureCameraMode] = []
    private(set) var flashRequests: [Bool] = []
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

    func configure(_ mode: CaptureCameraMode) async throws {
        if failsConfigure { throw FakeCaptureError.failed }
        configuredModes.append(mode)
    }

    func stop() async {
        stopCount += 1
    }

    func capturePhoto(flash: Bool) async throws -> CaptureStill {
        flashRequests.append(flash)
        return CaptureFakes.still(Tokens.Colors.globalAccent)
    }

    func captureDual(flash: Bool) async throws -> CaptureDualStills {
        flashRequests.append(flash)
        if failsDual { throw FakeCaptureError.failed }
        return CaptureDualStills(
            back: CaptureFakes.still(Tokens.Colors.globalAccent, position: .back),
            front: hasFrontCamera ? CaptureFakes.still(Tokens.Colors.globalAccentSecondary, position: .front) : nil,
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
        AnyView(FakeCameraPreview(image: previewImage))
    }

    func interrupt(_ interrupted: Bool) {
        onInterruption?(interrupted)
    }
}

/// The fake camera feed: a still image, or a token-coloured surface.
struct FakeCameraPreview: View {
    let image: UIImage?

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Tokens.Colors.cameraCaptureColorFlipButton
        }
    }
}

// MARK: - Library, groups, premium, voice

@MainActor
final class FakeCaptureLibrary: CaptureLibrary {
    var thumbnail: UIImage?
    private(set) var saved: [CapturedMedia] = []

    func newestThumbnail(side: CGFloat) async -> UIImage? { thumbnail }

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
    var covers: [String: UIImage] = [:]

    init(groups: [CaptureGroup], cached: [CaptureGroup]? = nil) {
        self.groups = groups
        self.cached = cached
    }

    func cachedGroups() async -> [CaptureGroup]? { cached }

    func loadGroups() async throws -> [CaptureGroup] {
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

    func permission() -> PermissionStatus { status }
    func requestPermission() async -> PermissionStatus { status }

    func start() throws {
        isRecording = true
    }

    func stop() throws -> VoiceNote {
        isRecording = false
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        try Data().write(to: url)
        return VoiceNote(fileURL: url, durationMs: 1000)
    }

    func cancel() {
        isRecording = false
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
    /// When set, `publish` fails with it and keeps the draft pending (like the outbox).
    var publishError: DataError?
    private(set) var published: [PostDraft] = []
    private(set) var pending: [PostDraft] = []
    private var continuation: AsyncStream<Bool>.Continuation?

    func publish(_ draft: PostDraft) async throws {
        if let publishError {
            pending.append(draft)
            throw publishError
        }
        published.append(draft)
    }

    func retryPending() async -> CaptureRetryResult {
        if let publishError, !pending.isEmpty {
            return CaptureRetryResult(posted: 0, error: publishError)
        }
        let posted = pending.count
        published += pending
        pending = []
        return CaptureRetryResult(posted: posted, error: nil)
    }

    func onlineUpdates() -> AsyncStream<Bool> {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        self.continuation = continuation
        return stream
    }

    /// The network came back.
    func goOnline() {
        continuation?.yield(true)
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
    var images: [String: UIImage] = [:]
    var cachedImages: [String: UIImage] = [:]
    var isOffline = false

    func collage(invitationID: String) async throws -> Collage? {
        if let error { throw error }
        return collage
    }

    func cachedCollage(invitationID: String) async -> Collage? { cached }

    func image(path: String) async throws -> UIImage {
        if let image = cachedImages[path] ?? images[path] { return image }
        throw error ?? FakeCaptureError.failed
    }

    func cachedImage(path: String) -> UIImage? { cachedImages[path] }

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

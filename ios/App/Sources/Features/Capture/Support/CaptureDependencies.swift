// Surfaces: camera.capture, camera.sendto, camera.fromwidget, daily.capture, collage.view,
// collage.share (design/surfaces/<id>.md; reference images listed there). The services the capture screens use, as protocols, so view models run with
// fakes in unit tests, snapshot tests and UI tests (launch argument `CaptureLaunchArgument.fakes`).
// Live implementations wrap AppServices / AppData (CaptureLiveServices.swift).
import AppData
import AppModels
import AppServices
import Foundation
import SwiftUI
import UIKit

// MARK: - Camera

/// A photo from a camera (or the library), as encoded by the camera.
struct CaptureStill: Sendable, Equatable {
    var imageData: Data
    /// The paired movie of a Live Photo, when one was captured.
    var livePhotoMovieURL: URL?
    var pixelWidth: Int
    var pixelHeight: Int
    var position: CameraPosition?
}

struct CaptureVideo: Sendable, Equatable {
    var fileURL: URL
    var durationMs: Int
}

/// Both photos of a daily same-moment capture.
struct CaptureDualStills: Sendable, Equatable {
    var back: CaptureStill
    /// Nil when the second camera failed or is unavailable (a single-camera answer).
    var front: CaptureStill?
    var simultaneous: Bool
}

enum CaptureCameraMode: Hashable, Sendable {
    /// One camera, Live Photo where supported.
    case photo(CameraPosition)
    /// One camera recording video (premium).
    case video(CameraPosition)
    /// Front and back (daily capture).
    case dual
}

/// The camera behind `camera.capture` and `daily.capture`.
@MainActor
protocol CaptureCamera: AnyObject, Sendable {
    func authorization() -> PermissionStatus
    func requestAccess() async -> PermissionStatus
    func microphoneAuthorization() -> PermissionStatus
    func requestMicrophoneAccess() async -> PermissionStatus
    /// Whether the camera at `position` can light the photo (the flash control is hidden otherwise).
    func hasFlash(at position: CameraPosition) -> Bool
    /// Whether the device has a camera at `position` (viewer.selfiereaction: no front camera, no selfie entry points).
    func hasCamera(at position: CameraPosition) -> Bool
    /// Configures and starts the session.
    func configure(_ mode: CaptureCameraMode) async throws
    func stop() async
    func capturePhoto(flash: Bool) async throws -> CaptureStill
    /// One photo without Live Photo motion, whatever the session supports: camera.overnight's 9 AM mode ("Live Photo
    /// motion is not captured in 9 AM mode") and a selfie reaction (a still JPEG, docs/API.md §14.1).
    func captureStill(flash: Bool) async throws -> CaptureStill
    func captureDual(flash: Bool) async throws -> CaptureDualStills
    func startRecording(maxDuration: TimeInterval) async throws
    func stopRecording() async throws -> CaptureVideo
    /// Live preview of the camera at `position` (nil: the active camera), aspect-fill.
    func preview(position: CameraPosition?) -> AnyView
    /// Called with true when the session is interrupted (camera in use elsewhere, runtime
    /// error) and false when the interruption ends.
    var onInterruption: ((Bool) -> Void)? { get set }
}

// MARK: - Library

@MainActor
protocol CaptureLibrary: AnyObject, Sendable {
    /// Saves to the library with add-only access (asks on first use).
    func save(_ media: CapturedMedia) async throws
}

// MARK: - Groups, premium, voice

/// A group the member can send to.
struct CaptureGroup: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let coverPath: String?
    /// The group's IANA time zone (`groups.time_zone`): camera.overnight reveals at 09:00 there. Nil when unknown (the
    /// widget's offline group list).
    var timeZone: String? = nil
}

@MainActor
protocol CaptureGroupSource: AnyObject, Sendable {
    /// Groups from the offline cache, when any were cached.
    func cachedGroups() async -> [CaptureGroup]?
    func loadGroups() async throws -> [CaptureGroup]
    /// The group cover for the recipient avatar (signed URL download).
    func coverImage(path: String) async -> UIImage?
    /// The member's groups' daily invitations open now (`open_invitations`, migration 0035); empty when none or when
    /// they cannot be read (send-to then shows no countdown and the post is an ordinary post).
    func openInvitations() async -> [DailyInvitation]
    var isOffline: Bool { get }
}

@MainActor
protocol CapturePremium: AnyObject, Sendable {
    /// Whether the member has an active premium entitlement (video).
    func isPremium() async -> Bool
    /// Opens the paywall when the session's single premium prompt is still available
    /// (`SessionPromptGate`). Returns whether it opened.
    func presentPaywallIfAllowed() -> Bool
}

struct VoiceNote: Sendable, Equatable {
    var fileURL: URL
    var durationMs: Int
    /// The waveform (100 levels of 0…31; design/components.md C-36); nil when none was recorded.
    var levels: [Int]? = nil
}

/// The send-to voice note's recorder (`chat.voice.layout.recording` / `.locked`): record, pause, continue, a playable
/// draft while paused, stop, cancel; plays the draft and the kept note.
@MainActor
protocol CaptureVoiceRecorder: AnyObject, Sendable {
    /// A recording exists (recording or paused).
    var isRecording: Bool { get }
    /// Elapsed recording time (observable in the live recorder).
    var elapsedMs: Int { get }
    /// The live / paused draft's waveform (observable in the live recorder).
    var levels: [Int] { get }
    var isPlaying: Bool { get }
    /// 0…1 of the file playing or paused part-way; nil when nothing is.
    var playbackProgress: Double? { get }
    /// The file playing or paused part-way.
    var playingFile: URL? { get }
    func permission() -> PermissionStatus
    func requestPermission() async -> PermissionStatus
    func start() throws
    /// Recording → paused.
    func pause()
    /// Paused → recording, at the end of the draft.
    func resume() throws
    /// The paused draft as one playable file.
    func draftFile() async throws -> URL
    func stop() async throws -> VoiceNote
    func cancel()
    /// Plays (or pauses) a recorded note.
    func togglePlayback(_ fileURL: URL)
    func stopPlayback()
}

// MARK: - Posting

@MainActor
protocol CapturePosting: AnyObject, Sendable {
    /// Saves the draft in the outbox and posts it (docs/API.md recipe 9.4). A draft whose post
    /// fails stays in the outbox (AppData `PostPublisher`) until `discard`.
    func publish(_ draft: PostDraft) async throws
    /// Removes a draft that failed from the outbox: the composer keeps the capture and sends a new draft when the
    /// member taps Try Again (camera.sendto error state), so the outbox never replays a post the member saw fail.
    func discard(_ mediaID: MediaID) async
    /// `my_developing()` (camera.overnight): whether my photos are developing, and the earliest reveal.
    func myDeveloping() async throws -> OvernightStatus
}

// MARK: - Daily invitation and collage

/// What the daily capture needs about an invitation.
struct CaptureInvitation: Sendable, Equatable {
    var id: String
    var groupID: String
    var groupName: String
    var firesAt: Date?
    var closesAt: Date
    var localDate: LocalDate?
}

@MainActor
protocol CaptureInvitationSource: AnyObject, Sendable {
    func invitation(id: String, groupID: String) async throws -> CaptureInvitation?
    /// The group's name from the cache, the widget's group list or the server.
    func groupName(groupID: String) async -> String
    /// The member's own first name (accessibility label of their dual image).
    func myFirstName() async -> String
    /// Server time offset (`server − device`); `.device` when the data layer measures none.
    var clock: ServerClock { get }
}

@MainActor
protocol CaptureCollageSource: AnyObject, Sendable {
    func collage(invitationID: String) async throws -> Collage?
    func cachedCollage(invitationID: String) async -> Collage?
    /// Downloads (or reads from the on-disk cache) the image at a storage path.
    func image(path: String) async throws -> UIImage
    func cachedImage(path: String) async -> UIImage?
    /// Writes the share image of a page to a local file for the share sheet.
    func shareFile(path: String) async throws -> URL
    /// The storage path of the collage's first photo — the first visible post of `postIDs` (capture order), its display
    /// rendition (the original until renditions exist) — for the recap-preview backdrop (collage.view, MERGE L-7); nil
    /// when none resolves (offline, blocked, deleted).
    func firstPhotoPath(postIDs: [PostID]) async -> String?
    var isOffline: Bool { get }
}

// MARK: - Navigation out of the capture screens

@MainActor
protocol CaptureNavigation: AnyObject, Sendable {
    /// Closes the camera / daily capture (back to where the member was).
    func closeCapture()
    /// Opens the camera with a group preselected (collage.view empty state).
    func openCamera(groupID: String?)
    /// Whether send-to's empty state can open `groups.create` (the account group's
    /// `AccountModal.groupCreate`, presented over send-to so the capture is kept).
    var canCreateGroup: Bool { get }
    /// The app's page in system Settings (permission-denied states).
    func openSystemSettings()
}

// MARK: - First-use coach marks

@MainActor
protocol CaptureCoachStore: AnyObject, Sendable {
    func isDismissed(_ coach: CaptureCoach) -> Bool
    func dismiss(_ coach: CaptureCoach)
}

enum CaptureCoach: String, CaseIterable, Sendable {
    /// `camera.capture.coach.holdToRecord`
    case holdToRecord = "capture.coach.holdToRecord"
}

@MainActor
final class UserDefaultsCoachStore: CaptureCoachStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isDismissed(_ coach: CaptureCoach) -> Bool {
        defaults.bool(forKey: coach.rawValue)
    }

    func dismiss(_ coach: CaptureCoach) {
        defaults.set(true, forKey: coach.rawValue)
    }
}

// MARK: - Launch arguments (UI tests)

enum CaptureLaunchArgument {
    /// Replaces the camera, groups, premium and posting with fakes (the simulator has no camera).
    static let fakes = "-capture-fakes"
    /// With `fakes`: the member has premium (video).
    static let fakePremium = "-capture-fake-premium"
    /// With `fakes`: the member has no groups.
    static let fakeNoGroups = "-capture-fake-no-groups"
    /// Without `fakes`: only the camera is the fake one (its stills), everything else is live (the real-server journey).
    static let fakeCamera = "-capture-fake-camera"

    /// `arguments`: the launch arguments, with the Jolt demo build's (`DemoMode`).
    static func isSet(_ argument: String, in arguments: [String] = DemoMode.launchArguments) -> Bool {
        arguments.contains(argument)
    }
}

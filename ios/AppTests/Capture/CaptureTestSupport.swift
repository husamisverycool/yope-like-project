// Helpers for the capture tests (ios/AppTests/Capture/Capture*Tests.swift).
@testable import App
import AppData
import AppModels
import AppServices
import DesignSystem
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

/// Waits (polling the main actor) until `condition` holds or `timeout` passes.
@MainActor
func captureEventually(timeout: TimeInterval = 3, _ condition: @MainActor () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
    return condition()
}

/// The capture environment over fakes, with handles on each fake.
@MainActor
final class CaptureTestRig {
    let camera = FakeCaptureCamera()
    let dualCamera = FakeCaptureCamera()
    let library = FakeCaptureLibrary()
    let groups = FakeCaptureGroups(groups: CaptureFakes.groups)
    let premium = FakeCapturePremium(isPremium: false)
    let posting = FakeCapturePosting()
    let invitations = FakeCaptureInvitations()
    let collages = FakeCaptureCollages()
    let navigation = RecordingCaptureNavigation()
    let coach = InMemoryCaptureCoachStore()
    let voice = FakeCaptureVoiceRecorder()
    private(set) var haptics: [DSHaptic] = []

    lazy var environment: CaptureEnvironment = CaptureEnvironment(
        makeCamera: { [camera, dualCamera] dual in dual ? dualCamera : camera },
        makeVoiceRecorder: { [voice] in voice },
        library: library,
        groups: groups,
        premium: premium,
        posting: posting,
        invitations: invitations,
        collages: collages,
        navigation: navigation,
        coach: coach
    )

    /// A send center that records haptics instead of playing them.
    lazy var sendCenter: CaptureSendCenter = CaptureSendCenter(posting: posting) { [weak self] haptic in
        self?.haptics.append(haptic)
    }

    /// Noon on 2026-10-15 (ISO week 42): the camera title reads "Week 42" in every snapshot.
    static let fixedNow: Date = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12)) ?? Date(timeIntervalSince1970: 0)
    }()

    func cameraModel(
        contextGroupID: String? = nil,
        now: Date = CaptureTestRig.fixedNow,
        batchLimit: @escaping @MainActor () async -> Int? = { nil },
        sharedItems: @escaping @MainActor (Int) async -> [CapturedMedia] = { _ in [] }
    ) -> CameraCaptureModel {
        CameraCaptureModel(
            contextGroupID: contextGroupID,
            camera: camera,
            premium: premium,
            coach: coach,
            navigation: navigation,
            overnight: overnightModel(contextGroupID: contextGroupID, now: now),
            longPressThreshold: .milliseconds(20),
            clock: { now },
            batchLimit: batchLimit,
            sharedItems: sharedItems
        )
    }

    /// camera.overnight's 9 AM uploads over the fake posting; announcements are recorded instead of posted.
    private(set) var announcements: [String] = []
    lazy var overnightQueue: CaptureOvernightQueue = CaptureOvernightQueue(posting: posting) { [weak self] text in
        self?.announcements.append(text)
    }

    /// The camera's mode control (9 AM · Now) over the rig's groups and posting.
    func overnightModel(contextGroupID: String? = nil, now: Date = CaptureTestRig.fixedNow) -> OvernightCaptureModel {
        OvernightCaptureModel(
            contextGroupID: contextGroupID, groups: groups, posting: posting, queue: overnightQueue, clock: { now },
            announce: { [weak self] text in self?.announcements.append(text) }
        )
    }

    /// The photo-reply handoff seen by send-to (social's `PhotoReplyHandoff` in the app).
    var replyTarget: (groupID: String, postID: String)?
    private(set) var replyClears = 0

    func sendToModel(
        media: CapturedMedia = .photo(CaptureFakes.still(Tokens.Colors.globalAccent), capturedAt: Date()),
        more: [CapturedMedia] = [],
        contextGroupID: String? = nil,
        onClose: @escaping @MainActor () -> Void = {},
        onSent: @escaping @MainActor () -> Void = {}
    ) -> SendToModel {
        SendToModel(
            media: media,
            more: more,
            contextGroupID: contextGroupID,
            groups: groups,
            premium: premium,
            library: library,
            voice: voice,
            sendCenter: sendCenter,
            navigation: navigation,
            onClose: onClose,
            onSent: onSent,
            replyTarget: { [weak self] groupID in
                guard let target = self?.replyTarget, target.groupID == groupID else { return nil }
                return target.postID
            },
            clearReply: { [weak self] in
                self?.replyTarget = nil
                self?.replyClears += 1
            }
        )
    }

    func dailyModel(groupID: String = CaptureFakes.groups[0].id, invitationID: String = "inv-1") -> DailyCaptureModel {
        DailyCaptureModel(
            groupID: groupID,
            invitationID: invitationID,
            camera: dualCamera,
            invitations: invitations,
            sendCenter: sendCenter,
            navigation: navigation
        )
    }

    func collageModel(groupID: String = CaptureFakes.groups[0].id, invitationID: String = "inv-1") -> CollageModel {
        CollageModel(groupID: groupID, invitationID: invitationID, collages: collages, invitations: invitations, navigation: navigation)
    }

    /// Real photos everywhere the camera fakes show one: the viewfinder, the shutter's stills (back scene, front
    /// selfie) and the group covers.
    func usePhotos(scene: Int = 0) {
        let preview = CaptureTestImages.scene(scene, CGSize(width: 900, height: 1200))
        let back = CaptureTestImages.still(named: CaptureTestImages.scenes[scene % CaptureTestImages.scenes.count], position: .back)
        let front = CaptureTestImages.still(named: CaptureTestImages.selfie, position: .front)
        for fake in [camera, dualCamera] {
            fake.previewImage = preview
            fake.backStill = back
            fake.frontStill = front
        }
        groups.groups = CaptureTestImages.groupsWithCovers
        groups.covers = CaptureTestImages.groupCovers
    }

    func openInvitation(closingIn seconds: TimeInterval, now: Date = Date()) {
        invitations.invitation = CaptureInvitation(
            id: "inv-1",
            groupID: CaptureFakes.groups[0].id,
            groupName: CaptureFakes.groups[0].name,
            firesAt: now.addingTimeInterval(-10),
            closesAt: now.addingTimeInterval(seconds),
            localDate: LocalDate(year: 2026, month: 5, day: 26)
        )
    }
}

/// Test pictures: real sample photos (fixtures/photos/, `SamplePhotos`) cropped to the pixel size each fixture
/// declares, at scale 1, so pixel sizes in assertions hold on every simulator.
enum CaptureTestImages {
    /// Back-camera scenes and posted photos.
    static let scenes = [
        "friends-coffee-highfive-3x4", "dinner-pizza-cheers-3x4", "hike-mountain-friends-3x4", "picnic-spread-3x4",
        "dog-beach-run-3x4", "campfire-woods-3x4", "birthday-cake-candles-3x4", "snow-forest-walk-3x4",
    ]

    /// The front camera (the daily answer's inset): a selfie.
    static let selfie = "selfie-two-friends-1x1"

    /// A photo of `size` pixels (scale 1, so its pixel size matches `still()`'s pixelWidth / pixelHeight on every
    /// simulator): `name` centre-cropped to that shape.
    static func photo(_ size: CGSize = CGSize(width: 300, height: 400), named name: String = scenes[0]) -> UIImage {
        SamplePhotos.photo(named: name, size: size)
    }

    /// The `index`th scene at `size` pixels.
    static func scene(_ index: Int, _ size: CGSize = CGSize(width: 300, height: 400)) -> UIImage {
        photo(size, named: scenes[((index % scenes.count) + scenes.count) % scenes.count])
    }

    static func jpeg(_ size: CGSize = CGSize(width: 300, height: 400), named name: String = scenes[0]) -> Data {
        photo(size, named: name).jpegData(compressionQuality: 0.9)!
    }

    /// A 300 × 400 still of `name`.
    static func still(named name: String = scenes[0], position: CameraPosition? = .back) -> CaptureStill {
        CaptureStill(imageData: jpeg(named: name), livePhotoMovieURL: nil, pixelWidth: 300, pixelHeight: 400, position: position)
    }

    /// The `index`th avatar portrait at `size` pixels.
    static func avatar(_ size: CGSize, index: Int = 0) -> UIImage {
        SamplePhotos.photo(named: SamplePhotos.avatarName(index: index), size: size)
    }

    /// A same-moment collage page of `size` pixels: dual answers (scene + selfie-style inset) three across on black.
    static func collagePage(_ size: CGSize, answers: Int = 12, first: Int = 0) -> UIImage {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let tile = CGSize(width: (size.width / 3).rounded(.down), height: (size.width / 3 * 4 / 3).rounded(.down))
            let inset = CGSize(width: (tile.width * 0.31).rounded(), height: (tile.width * 0.31 * 4 / 3).rounded())
            let margin = tile.width * 0.03
            for index in 0..<answers {
                let origin = CGPoint(x: CGFloat(index % 3) * tile.width, y: CGFloat(index / 3) * tile.height)
                scene(first + index, tile).draw(at: origin)
                avatar(inset, index: first + index).draw(at: CGPoint(x: origin.x + margin, y: origin.y + margin))
            }
        }
    }

    /// The groups of `CaptureFakes.groups` with covers (the second has none: the default group look).
    static let groupsWithCovers: [CaptureGroup] = [
        CaptureGroup(id: CaptureFakes.groups[0].id, name: CaptureFakes.groups[0].name, coverPath: "covers/1"),
        CaptureGroup(id: CaptureFakes.groups[1].id, name: CaptureFakes.groups[1].name, coverPath: nil),
    ]

    static var groupCovers: [String: UIImage] {
        ["covers/1": photo(CGSize(width: 256, height: 256), named: "dinner-long-table-3x4")]
    }
}

/// Records `ios/build/snapshots/capture/<surface>-<state>-<light|dark>.png` (SnapshotRecorder writes
/// `<test>.<name>.png`; the file is renamed to the surface/state name the verification step uses). Every state is
/// recorded in the light appearance; pass `[.light, .dark]` for a surface's primary state. The host sets the
/// appearance explicitly (`.environment(\.colorScheme)` + `.preferredColorScheme`): media surfaces render dark in
/// both by design (`layout.global.appearance.media`), sheets and system text follow the host.
enum CaptureSnapshot {
    static let folder = SnapshotRecorder.directory.appendingPathComponent("capture", isDirectory: true)

    /// Both appearances (the primary state of a surface).
    static let both: [ColorScheme] = [.light, .dark]

    @MainActor
    @discardableResult
    static func record<V: View>(
        _ view: V,
        surface: String,
        state: String,
        appearances: [ColorScheme] = [.light],
        layout: SwiftUISnapshotLayout = .device(config: .iPhone13),
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) -> URL? {
        var last: URL?
        for scheme in appearances {
            let name = "\(surface)-\(state)-\(scheme == .dark ? "dark" : "light")"
            let hosted = view
                .environment(\.colorScheme, scheme)
                .preferredColorScheme(scheme)
            guard let written = SnapshotRecorder.record(hosted, named: name, group: "capture", layout: layout, file: file, testName: testName, line: line) else {
                return nil
            }
            let target = folder.appendingPathComponent("\(name).png")
            try? FileManager.default.removeItem(at: target)
            do {
                try FileManager.default.moveItem(at: written, to: target)
                last = target
            } catch {
                last = written
            }
        }
        return last
    }
}

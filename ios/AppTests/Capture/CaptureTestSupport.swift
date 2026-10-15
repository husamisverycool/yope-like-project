// Helpers for the capture tests (ios/AppTests/Capture/Capture*Tests.swift).
@testable import App
import AppData
import AppModels
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

    func cameraModel(contextGroupID: String? = nil) -> CameraCaptureModel {
        CameraCaptureModel(
            contextGroupID: contextGroupID,
            camera: camera,
            premium: premium,
            library: library,
            coach: coach,
            navigation: navigation,
            longPressThreshold: .milliseconds(20)
        )
    }

    /// The photo-reply handoff seen by send-to (social's `PhotoReplyHandoff` in the app).
    var replyTarget: (groupID: String, postID: String)?
    private(set) var replyClears = 0

    func sendToModel(
        media: CapturedMedia = .photo(CaptureFakes.still(Tokens.Colors.globalAccent), capturedAt: Date()),
        contextGroupID: String? = nil,
        onClose: @escaping @MainActor () -> Void = {},
        onSent: @escaping @MainActor () -> Void = {}
    ) -> SendToModel {
        SendToModel(
            media: media,
            contextGroupID: contextGroupID,
            groups: groups,
            premium: premium,
            library: library,
            voice: voice,
            coach: coach,
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

/// Test pictures (literal colours are allowed in tests).
enum CaptureTestImages {
    /// A gradient "photo" of `size` pixels (scale 1, so its pixel size matches `still()`'s pixelWidth / pixelHeight
    /// on every simulator).
    static func photo(_ size: CGSize = CGSize(width: 300, height: 400), hue: CGFloat = 0.08) -> UIImage {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let colors = [UIColor(hue: hue, saturation: 0.55, brightness: 0.95, alpha: 1).cgColor,
                          UIColor(hue: hue + 0.5, saturation: 0.6, brightness: 0.45, alpha: 1).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
        }
    }

    static func jpeg(_ size: CGSize = CGSize(width: 300, height: 400), hue: CGFloat = 0.08) -> Data {
        photo(size, hue: hue).jpegData(compressionQuality: 0.9)!
    }

    static func still(hue: CGFloat = 0.08) -> CaptureStill {
        CaptureStill(imageData: jpeg(hue: hue), livePhotoMovieURL: nil, pixelWidth: 300, pixelHeight: 400, position: .back)
    }
}

/// Records `ios/build/snapshots/capture/<surface>-<state>.png` (SnapshotRecorder writes
/// `<test>.<name>.png`; the file is renamed to the surface/state name the verification step uses).
enum CaptureSnapshot {
    static let folder = SnapshotRecorder.directory.appendingPathComponent("capture", isDirectory: true)

    @MainActor
    @discardableResult
    static func record<V: View>(
        _ view: V,
        surface: String,
        state: String,
        layout: SwiftUISnapshotLayout = .device(config: .iPhone13),
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) -> URL? {
        let name = "\(surface)-\(state)"
        let hosted = view
            .environment(\.colorScheme, .dark)
            .preferredColorScheme(.dark)
        guard let written = SnapshotRecorder.record(hosted, named: name, group: "capture", layout: layout, file: file, testName: testName, line: line) else {
            return nil
        }
        let target = folder.appendingPathComponent("\(name).png")
        try? FileManager.default.removeItem(at: target)
        do {
            try FileManager.default.moveItem(at: written, to: target)
        } catch {
            return written
        }
        return target
    }
}

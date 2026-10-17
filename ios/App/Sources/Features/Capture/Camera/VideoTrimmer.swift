// Surface: camera.trim — a library video longer than `camera.capture.duration.videoMax` is trimmed before send-to, in the
// platform's trimmer (UIVideoEditorController, PLATFORM: the system's own trim interface, as Photos' "Trim"); Retro's
// own composer trims ("Trim Video", references/auto/retro/apk/retro-android-2026.10.1150-strings.txt video_editor_*).
// Spec: design/surfaces/camera.trim.md.
import DesignSystem
import Foundation
import SwiftUI
import UIKit

/// A picked video waiting for the trimmer (presented while non-nil).
struct CaptureTrimRequest: Identifiable, Sendable, Equatable {
    let id = UUID()
    let video: CaptureVideo
    /// The selection item (`CapturedMedia.id`) the trimmed clip replaces, when it came from a selection.
    var mediaID: UUID? = nil
}

/// The longest video a post may hold: `camera.capture.duration.videoMax` (the server's `app_config.video_max_ms`).
enum CaptureVideoLimit {
    static var maxMs: Int { Int((Tokens.Durations.cameraCaptureDurationVideoMax * 1000).rounded()) } // provenance-ok: seconds → milliseconds

    /// Longer than the limit in the whole seconds the apps show ("0:10" = 10,000–10,999 ms), as `create_post` counts.
    static func isTooLong(_ durationMs: Int) -> Bool {
        (durationMs / 1000) * 1000 > maxMs // provenance-ok: milliseconds → whole seconds
    }

    /// The limit in words for `camera.capture.videoTooLong.message` ("10 seconds"; platform formatter).
    static var spoken: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.second]
        return formatter.string(from: Tokens.Durations.cameraCaptureDurationVideoMax) ?? ""
    }
}

/// The system trimmer on `request`'s file, its length capped at the limit; `onFinish` gets the trimmed copy (in this app's
/// temporary folder), or nil when cancelled or failed (`failed` true).
struct VideoTrimmer: UIViewControllerRepresentable {
    let request: CaptureTrimRequest
    let onFinish: @MainActor (_ trimmed: URL?, _ failed: Bool) -> Void

    /// Whether the system trimmer can open this file (codec / container).
    static func canTrim(_ url: URL) -> Bool {
        UIVideoEditorController.canEditVideo(atPath: url.path)
    }

    func makeUIViewController(context: Context) -> UIVideoEditorController {
        let editor = UIVideoEditorController()
        editor.videoPath = request.video.fileURL.path
        editor.videoMaximumDuration = Tokens.Durations.cameraCaptureDurationVideoMax
        editor.videoQuality = .typeHigh
        editor.delegate = context.coordinator
        return editor
    }

    func updateUIViewController(_ uiViewController: UIVideoEditorController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    @MainActor
    final class Coordinator: NSObject, UIVideoEditorControllerDelegate, UINavigationControllerDelegate {
        private let onFinish: @MainActor (URL?, Bool) -> Void
        /// The editor may report a save twice; the first answer counts.
        private var finished = false

        init(onFinish: @escaping @MainActor (URL?, Bool) -> Void) {
            self.onFinish = onFinish
        }

        func videoEditorController(_ editor: UIVideoEditorController, didSaveEditedVideoToPath editedVideoPath: String) {
            guard !finished else { return }
            finished = true
            // The editor's export lives in its own temporary folder: copied before it is cleaned.
            let source = URL(fileURLWithPath: editedVideoPath)
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let copy = folder.appendingPathComponent(source.lastPathComponent)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: source, to: copy)
                onFinish(copy, false)
            } catch {
                onFinish(nil, true)
            }
        }

        func videoEditorControllerDidCancel(_ editor: UIVideoEditorController) {
            guard !finished else { return }
            finished = true
            onFinish(nil, false)
        }

        func videoEditorController(_ editor: UIVideoEditorController, didFailWithError error: any Error) {
            guard !finished else { return }
            finished = true
            onFinish(nil, true)
        }
    }
}

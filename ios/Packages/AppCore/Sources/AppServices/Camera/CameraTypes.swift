#if os(iOS)
import AppModels
@preconcurrency import AVFoundation
import Foundation

public enum CameraPosition: String, Hashable, Sendable, CaseIterable {
    case back
    case front

    var avPosition: AVCaptureDevice.Position {
        switch self {
        case .back: return .back
        case .front: return .front
        }
    }
}

public enum CameraConfiguration: Hashable, Sendable {
    /// One camera. `livePhoto` turns on Live Photo capture where the device supports it.
    case photo(CameraPosition, livePhoto: Bool)
    /// One camera recording video with sound (premium).
    case video(CameraPosition)
    /// Front and back for the daily same-moment capture: simultaneous on multi-camera hardware,
    /// otherwise back first, then front.
    case dual
}

public enum CameraError: Error, Equatable, Sendable {
    case notAuthorized(PermissionStatus)
    case deviceUnavailable(CameraPosition)
    case configurationFailed(String)
    case notConfigured
    case captureFailed(String)
    case premiumRequired
    case alreadyRecording
    case notRecording
}

public struct CaptureMetadata: Hashable, Sendable {
    public let capturedAt: Date
    public let position: CameraPosition
    public let pixelWidth: Int
    public let pixelHeight: Int
}

public struct CapturedPhoto: Sendable {
    /// The encoded photo as the camera produced it (HEIF or JPEG). Pass it through
    /// `ImageEncoder` before upload.
    public let imageData: Data
    /// The paired movie of a Live Photo (temporary directory), when one was captured.
    public let livePhotoMovieURL: URL?
    public let metadata: CaptureMetadata
}

public struct DualCapture: Sendable {
    public enum Mode: Hashable, Sendable {
        case simultaneous
        case sequential
    }

    public let back: CapturedPhoto
    public let front: CapturedPhoto
    public let mode: Mode
}

public struct RecordedVideo: Hashable, Sendable {
    public let fileURL: URL
    public let durationMs: Int
    public let position: CameraPosition
    public let capturedAt: Date
}
#endif

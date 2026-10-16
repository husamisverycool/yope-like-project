#if os(iOS)
import AppModels
@preconcurrency import AVFoundation
import Foundation
import SwiftUI
import UIKit

/// Camera capture for `camera.capture` and `daily.capture`: one-tap photos, Live Photos, video
/// (premium) and front + back capture (simultaneous on `AVCaptureMultiCamSession` hardware,
/// otherwise back then front). Returns encoded image data plus metadata; location is never
/// requested or attached.
@MainActor
public final class CameraService {
    // MARK: Authorization

    public nonisolated static var isMultiCamSupported: Bool {
        AVCaptureMultiCamSession.isMultiCamSupported
    }

    /// Camera (`.video`) or microphone (`.audio`, for video recording) permission.
    public nonisolated static func authorization(for mediaType: AVMediaType) -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    /// Shows the system prompt when the status is not determined; returns the resulting status.
    public nonisolated static func requestAccess(for mediaType: AVMediaType) async -> PermissionStatus {
        if authorization(for: mediaType) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: mediaType)
        }
        return authorization(for: mediaType)
    }

    // MARK: State

    /// The session previews attach to (`CameraPreview`).
    public let session: AVCaptureSession
    public private(set) var configuration: CameraConfiguration?
    /// How `captureDual()` works on this device, once configured with `.dual`.
    public private(set) var dualMode: DualCapture.Mode?
    public private(set) var isRecording = false

    private let controller: CaptureSessionController
    private var captureCoordinators: [CameraPosition: AVCaptureDevice.RotationCoordinator] = [:]
    private var previewCoordinators: [ObjectIdentifier: AVCaptureDevice.RotationCoordinator] = [:]
    private var previewObservations: [ObjectIdentifier: NSKeyValueObservation] = [:]

    /// - Parameter supportsDualCapture: create a multi-camera session when the hardware has one
    ///   (daily capture). A regular session otherwise.
    public init(supportsDualCapture: Bool) {
        let session: AVCaptureSession = supportsDualCapture && AVCaptureMultiCamSession.isMultiCamSupported
            ? AVCaptureMultiCamSession()
            : AVCaptureSession()
        self.session = session
        controller = CaptureSessionController(session: session)
    }

    // MARK: Lifecycle

    public func configure(_ configuration: CameraConfiguration) async throws {
        let status = Self.authorization(for: .video)
        guard status == .granted else { throw CameraError.notAuthorized(status) }
        let result = try await controller.configure(configuration)
        captureCoordinators = [:]
        for position in result.positions {
            guard let device = CaptureSessionController.device(position) else { continue }
            captureCoordinators[position] = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        }
        self.configuration = configuration
        dualMode = result.dualMode
    }

    public func start() async {
        await controller.start()
    }

    public func stop() async {
        await controller.stop()
    }

    // MARK: Preview

    /// Shows the camera at `position` in `layer` (nil: the active camera). Called by `CameraPreview`.
    public func attachPreview(_ layer: AVCaptureVideoPreviewLayer, position: CameraPosition?) {
        layer.setSessionWithNoConnection(session)
        controller.attachPreview(layer, position: position) { [weak self, weak layer] connected in
            Task { @MainActor in
                guard let self, let layer, let connected else { return }
                self.trackPreviewRotation(layer, position: connected)
            }
        }
    }

    private func trackPreviewRotation(_ layer: AVCaptureVideoPreviewLayer, position: CameraPosition) {
        guard let device = CaptureSessionController.device(position) else { return }
        let key = ObjectIdentifier(layer)
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: layer)
        previewCoordinators[key] = coordinator
        Self.apply(coordinator.videoRotationAngleForHorizonLevelPreview, to: layer)
        previewObservations[key] = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak layer] _, change in
            guard let angle = change.newValue else { return }
            Task { @MainActor in
                guard let layer else { return }
                CameraService.apply(angle, to: layer)
            }
        }
    }

    private static func apply(_ angle: CGFloat, to layer: AVCaptureVideoPreviewLayer) {
        guard let connection = layer.connection, connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    private func captureAngle(_ position: CameraPosition) -> CGFloat? {
        captureCoordinators[position]?.videoRotationAngleForHorizonLevelCapture
    }

    // MARK: Capture

    /// One photo (a Live Photo when configured with `livePhoto: true` and supported). `livePhoto: false` takes this one
    /// shot without motion on a Live Photo session (camera.overnight's 9 AM mode, selfie reactions).
    public func capturePhoto(livePhoto wantsLivePhoto: Bool = true) async throws -> CapturedPhoto {
        guard case let .photo(position, livePhoto)? = configuration else { throw CameraError.notConfigured }
        return try await controller.capturePhoto(
            position: position, livePhoto: livePhoto && wantsLivePhoto, rotationAngle: captureAngle(position)
        )
    }

    /// Back and front photos for the daily same-moment capture.
    public func captureDual() async throws -> DualCapture {
        guard configuration == .dual, let dualMode else { throw CameraError.notConfigured }
        let controller = self.controller
        switch dualMode {
        case .simultaneous:
            let backAngle = captureAngle(.back)
            let frontAngle = captureAngle(.front)
            async let back = controller.capturePhoto(position: .back, livePhoto: false, rotationAngle: backAngle)
            async let front = controller.capturePhoto(position: .front, livePhoto: false, rotationAngle: frontAngle)
            let (backPhoto, frontPhoto) = try await (back, front)
            return DualCapture(back: backPhoto, front: frontPhoto, mode: .simultaneous)
        case .sequential:
            let back = try await controller.capturePhoto(position: .back, livePhoto: false, rotationAngle: captureAngle(.back))
            try await controller.switchCamera(to: .front)
            let front: CapturedPhoto
            do {
                front = try await controller.capturePhoto(position: .front, livePhoto: false, rotationAngle: captureAngle(.front))
            } catch {
                try? await controller.switchCamera(to: .back)
                throw error
            }
            try await controller.switchCamera(to: .back)
            return DualCapture(back: back, front: front, mode: .sequential)
        }
    }

    // MARK: Video (premium)

    /// Starts recording. The server also checks the entitlement for video posts; this check keeps
    /// the camera from recording something that cannot be sent.
    public func startRecording(isPremium: Bool, maxDuration: CMTime? = nil) async throws {
        guard isPremium else { throw CameraError.premiumRequired }
        guard case let .video(position)? = configuration else { throw CameraError.notConfigured }
        try await controller.startRecording(position: position, rotationAngle: captureAngle(position), maxDuration: maxDuration)
        isRecording = true
    }

    public func stopRecording() async throws -> RecordedVideo {
        defer { isRecording = false }
        return try await controller.stopRecording()
    }
}

/// UIKit view whose layer is the preview layer.
public final class CameraPreviewUIView: UIView {
    public override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    public var previewLayer: AVCaptureVideoPreviewLayer {
        // layerClass guarantees the type.
        layer as! AVCaptureVideoPreviewLayer
    }
}

/// SwiftUI camera preview. `videoGravity` is the screen's layout decision (the camera surface spec).
public struct CameraPreview: UIViewRepresentable {
    private let camera: CameraService
    private let position: CameraPosition?
    private let videoGravity: AVLayerVideoGravity

    public init(camera: CameraService, position: CameraPosition?, videoGravity: AVLayerVideoGravity) {
        self.camera = camera
        self.position = position
        self.videoGravity = videoGravity
    }

    public func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.videoGravity = videoGravity
        camera.attachPreview(view.previewLayer, position: position)
        return view
    }

    public func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer.videoGravity = videoGravity
    }
}
#endif

#if os(iOS)
@preconcurrency import AVFoundation
import Foundation

/// Owns the AVFoundation capture graph. Every member below is touched only on `queue`
/// (AVCaptureSession configuration and `startRunning` block, so they stay off the main thread).
///
/// The graph is built with explicit connections (`addInputWithNoConnections` +
/// `AVCaptureConnection`) for both session kinds, so the same code serves a plain session and
/// an `AVCaptureMultiCamSession`, and preview layers can be pointed at a specific camera.
final class CaptureSessionController: @unchecked Sendable {
    struct ConfigurationResult: Sendable {
        let positions: [CameraPosition]
        let dualMode: DualCapture.Mode?
    }

    /// How long sequential capture waits for the newly selected camera's exposure and focus to settle.
    static let settleTimeoutNanoseconds: UInt64 = 1_500_000_000
    static let settlePollNanoseconds: UInt64 = 50_000_000

    let session: AVCaptureSession
    private let queue = DispatchQueue(label: "camera.session", qos: .userInitiated)

    private var inputs: [CameraPosition: AVCaptureDeviceInput] = [:]
    private var photoOutputs: [CameraPosition: AVCapturePhotoOutput] = [:]
    private var videoPorts: [CameraPosition: AVCaptureInput.Port] = [:]
    private var movieOutput: AVCaptureMovieFileOutput?
    private var audioPort: AVCaptureInput.Port?
    private var previews: [PreviewAttachment] = []
    private var inFlightPhotos: [Int64: PhotoCaptureProcessor] = [:]
    private var recording: MovieRecordingProcessor?
    private var livePhotoEnabled = false

    private final class PreviewAttachment {
        weak var layer: AVCaptureVideoPreviewLayer?
        let position: CameraPosition?
        let onConnect: (CameraPosition?) -> Void

        init(layer: AVCaptureVideoPreviewLayer, position: CameraPosition?, onConnect: @escaping (CameraPosition?) -> Void) {
            self.layer = layer
            self.position = position
            self.onConnect = onConnect
        }
    }

    init(session: AVCaptureSession) {
        self.session = session
    }

    static func device(_ position: CameraPosition) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position.avPosition)
    }

    // MARK: Queue helpers

    private func onQueue<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            queue.async {
                continuation.resume(with: Result { try work() })
            }
        }
    }

    // MARK: Running

    func start() async {
        _ = try? await onQueue { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() async {
        _ = try? await onQueue { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    // MARK: Configuration

    func configure(_ configuration: CameraConfiguration) async throws -> ConfigurationResult {
        try await onQueue { [self] in
            guard recording == nil else { throw CameraError.alreadyRecording }
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            removeGraph()
            switch configuration {
            case let .photo(position, livePhoto):
                if !(session is AVCaptureMultiCamSession) { session.sessionPreset = .photo }
                try addCamera(position, livePhoto: livePhoto)
                connectPreviews()
                return ConfigurationResult(positions: [position], dualMode: nil)
            case let .video(position):
                if !(session is AVCaptureMultiCamSession) { session.sessionPreset = .high }
                try addCamera(position, livePhoto: false)
                try addMovieOutput(position)
                connectPreviews()
                return ConfigurationResult(positions: [position], dualMode: nil)
            case .dual:
                if let multi = session as? AVCaptureMultiCamSession {
                    do {
                        try addCamera(.back, livePhoto: false)
                        try addCamera(.front, livePhoto: false)
                        guard multi.hardwareCost <= 1 else { throw CameraError.configurationFailed("multi-camera hardware cost") }
                        connectPreviews()
                        return ConfigurationResult(positions: [.back, .front], dualMode: .simultaneous)
                    } catch {
                        removeGraph()
                    }
                } else {
                    session.sessionPreset = .photo
                }
                try addCamera(.back, livePhoto: false)
                connectPreviews()
                return ConfigurationResult(positions: [.back, .front], dualMode: .sequential)
            }
        }
    }

    /// Sequential dual capture: replaces the single active camera with the camera at `position`
    /// and waits (bounded) until its exposure and focus have settled.
    func switchCamera(to position: CameraPosition) async throws {
        try await onQueue { [self] in
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            removeGraph()
            try addCamera(position, livePhoto: false)
            connectPreviews()
        }
        guard let device = Self.device(position) else { return }
        var waited: UInt64 = 0
        while waited < Self.settleTimeoutNanoseconds {
            let connected = (try? await onQueue { [self] in
                photoOutputs[position]?.connection(with: .video)?.isActive ?? false
            }) ?? false
            if connected && !device.isAdjustingExposure && !device.isAdjustingFocus { return }
            try await Task.sleep(nanoseconds: Self.settlePollNanoseconds)
            waited += Self.settlePollNanoseconds
        }
    }

    private func removeGraph() {
        for input in session.inputs { session.removeInput(input) }
        for output in session.outputs { session.removeOutput(output) }
        for connection in session.connections { session.removeConnection(connection) }
        inputs = [:]
        photoOutputs = [:]
        videoPorts = [:]
        movieOutput = nil
        audioPort = nil
        livePhotoEnabled = false
    }

    private func addCamera(_ position: CameraPosition, livePhoto: Bool) throws {
        guard let device = Self.device(position) else { throw CameraError.deviceUnavailable(position) }
        if session is AVCaptureMultiCamSession { try Self.selectMultiCamFormat(device) }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.configurationFailed("camera input") }
        session.addInputWithNoConnections(input)
        guard let port = input.ports.first(where: { $0.mediaType == .video }) else {
            throw CameraError.configurationFailed("camera port")
        }
        let output = AVCapturePhotoOutput()
        guard session.canAddOutput(output) else { throw CameraError.configurationFailed("photo output") }
        session.addOutputWithNoConnections(output)
        let connection = AVCaptureConnection(inputPorts: [port], output: output)
        guard session.canAddConnection(connection) else { throw CameraError.configurationFailed("photo connection") }
        session.addConnection(connection)
        // A camera joins the graph unzoomed and on continuous autofocus / exposure (a tap-to-focus lock or a zoom from an
        // earlier screen does not carry over); the screen re-applies its own zoom after configuring.
        Self.resetZoomAndFocus(device)
        if livePhoto && output.isLivePhotoCaptureSupported {
            output.isLivePhotoCaptureEnabled = true
            livePhotoEnabled = true
        }
        inputs[position] = input
        photoOutputs[position] = output
        videoPorts[position] = port
    }

    private func addMovieOutput(_ position: CameraPosition) throws {
        guard let videoPort = videoPorts[position] else { throw CameraError.notConfigured }
        let output = AVCaptureMovieFileOutput()
        guard session.canAddOutput(output) else { throw CameraError.configurationFailed("movie output") }
        session.addOutputWithNoConnections(output)
        let videoConnection = AVCaptureConnection(inputPorts: [videoPort], output: output)
        guard session.canAddConnection(videoConnection) else { throw CameraError.configurationFailed("movie connection") }
        session.addConnection(videoConnection)
        // Sound only when the microphone is authorized; otherwise the video is recorded silent.
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
           let microphone = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: microphone),
           session.canAddInput(audioInput) {
            session.addInputWithNoConnections(audioInput)
            if let port = audioInput.ports.first(where: { $0.mediaType == .audio }) {
                let audioConnection = AVCaptureConnection(inputPorts: [port], output: output)
                if session.canAddConnection(audioConnection) {
                    session.addConnection(audioConnection)
                    audioPort = port
                }
            }
        }
        movieOutput = output
    }

    /// Multi-camera sessions need formats that support it; picks the largest such format.
    private static func selectMultiCamFormat(_ device: AVCaptureDevice) throws {
        guard !device.activeFormat.isMultiCamSupported else { return }
        let formats = device.formats.filter { $0.isMultiCamSupported }
        guard let best = formats.max(by: { pixelCount($0) < pixelCount($1) }) else {
            throw CameraError.configurationFailed("no multi-camera format")
        }
        try device.lockForConfiguration()
        device.activeFormat = best
        device.unlockForConfiguration()
    }

    private static func pixelCount(_ format: AVCaptureDevice.Format) -> Int {
        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        return Int(dimensions.width) * Int(dimensions.height)
    }

    // MARK: Zoom and focus (camera.capture)

    /// The largest zoom factor the camera at `position` offers now (1 when it is not in the graph).
    func maxZoomFactor(_ position: CameraPosition) async -> CGFloat {
        (try? await onQueue { [self] in inputs[position]?.device.maxAvailableVideoZoomFactor ?? 1 }) ?? 1
    }

    /// Sets the zoom of the camera at `position`, clamped to what the device offers. Fire and forget: a pinch sends one
    /// per frame and the session queue applies them in order.
    func setZoom(_ factor: CGFloat, position: CameraPosition) {
        queue.async { [self] in
            guard let device = inputs[position]?.device else { return }
            let clamped = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            guard (try? device.lockForConfiguration()) != nil else { return }
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
        }
    }

    /// Focuses and exposes once at `devicePoint` (0…1, `captureDevicePointConverted`), then holds until `resetFocus`
    /// (the screen's timer, or a subject-area change: monitoring is on while the point holds).
    func focus(at devicePoint: CGPoint, position: CameraPosition) {
        queue.async { [self] in
            guard let device = inputs[position]?.device, (try? device.lockForConfiguration()) != nil else { return }
            if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .autoExpose
            }
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.unlockForConfiguration()
        }
    }

    /// Back to continuous autofocus and auto exposure over the whole frame.
    func resetFocus(position: CameraPosition) {
        queue.async { [self] in
            guard let device = inputs[position]?.device, (try? device.lockForConfiguration()) != nil else { return }
            Self.applyContinuousFocus(device)
            device.unlockForConfiguration()
        }
    }

    private static func resetZoomAndFocus(_ device: AVCaptureDevice) {
        guard (try? device.lockForConfiguration()) != nil else { return }
        device.videoZoomFactor = 1
        applyContinuousFocus(device)
        device.unlockForConfiguration()
    }

    /// Call with the device locked for configuration.
    private static func applyContinuousFocus(_ device: AVCaptureDevice) {
        let centre = CGPoint(x: 0.5, y: 0.5)
        if device.isFocusPointOfInterestSupported { device.focusPointOfInterest = centre }
        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        if device.isExposurePointOfInterestSupported { device.exposurePointOfInterest = centre }
        if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
        device.isSubjectAreaChangeMonitoringEnabled = false
    }

    // MARK: Previews

    /// Connects `layer` (already given the session with `setSessionWithNoConnection`) to the
    /// camera at `position`, or to the active camera when `position` is nil. Reconnected after
    /// every reconfiguration; `onConnect` reports the camera it now shows (on the session queue).
    func attachPreview(_ layer: AVCaptureVideoPreviewLayer, position: CameraPosition?, onConnect: @escaping (CameraPosition?) -> Void) {
        queue.async { [self] in
            previews.removeAll { $0.layer == nil || $0.layer === layer }
            let attachment = PreviewAttachment(layer: layer, position: position, onConnect: onConnect)
            previews.append(attachment)
            session.beginConfiguration()
            connect(attachment)
            session.commitConfiguration()
        }
    }

    private func connectPreviews() {
        previews.removeAll { $0.layer == nil }
        for attachment in previews { connect(attachment) }
    }

    private func connect(_ attachment: PreviewAttachment) {
        guard let layer = attachment.layer else { return }
        if let existing = layer.connection, session.connections.contains(existing) {
            session.removeConnection(existing)
        }
        let target: CameraPosition?
        if let wanted = attachment.position, videoPorts[wanted] != nil {
            target = wanted
        } else {
            target = videoPorts[.back] != nil ? .back : videoPorts.keys.first
        }
        guard let target, let port = videoPorts[target] else {
            attachment.onConnect(nil)
            return
        }
        let connection = AVCaptureConnection(inputPort: port, videoPreviewLayer: layer)
        guard session.canAddConnection(connection) else {
            attachment.onConnect(nil)
            return
        }
        session.addConnection(connection)
        attachment.onConnect(target)
    }

    // MARK: Photos

    func capturePhoto(position: CameraPosition, livePhoto: Bool, rotationAngle: CGFloat?) async throws -> CapturedPhoto {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CapturedPhoto, Error>) in
            queue.async { [self] in
                guard let output = photoOutputs[position] else {
                    continuation.resume(throwing: CameraError.notConfigured)
                    return
                }
                if let rotationAngle, let connection = output.connection(with: .video),
                   connection.isVideoRotationAngleSupported(rotationAngle) {
                    connection.videoRotationAngle = rotationAngle
                }
                let settings = AVCapturePhotoSettings()
                if livePhoto && livePhotoEnabled && output.isLivePhotoCaptureEnabled {
                    settings.livePhotoMovieFileURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("mov")
                }
                let id = settings.uniqueID
                let processor = PhotoCaptureProcessor(position: position) { [weak self] result in
                    self?.queue.async { self?.inFlightPhotos[id] = nil }
                    continuation.resume(with: result)
                }
                inFlightPhotos[id] = processor
                output.capturePhoto(with: settings, delegate: processor)
            }
        }
    }

    // MARK: Video

    func startRecording(position: CameraPosition, rotationAngle: CGFloat?, maxDuration: CMTime?) async throws {
        try await onQueue { [self] in
            guard let output = movieOutput else { throw CameraError.notConfigured }
            guard recording == nil, !output.isRecording else { throw CameraError.alreadyRecording }
            if let rotationAngle, let connection = output.connection(with: .video),
               connection.isVideoRotationAngleSupported(rotationAngle) {
                connection.videoRotationAngle = rotationAngle
            }
            if let maxDuration { output.maxRecordedDuration = maxDuration }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            let processor = MovieRecordingProcessor(position: position)
            recording = processor
            output.startRecording(to: url, recordingDelegate: processor)
        }
    }

    func stopRecording() async throws -> RecordedVideo {
        let processor: MovieRecordingProcessor = try await onQueue { [self] in
            guard let processor = recording, let output = movieOutput else { throw CameraError.notRecording }
            if output.isRecording { output.stopRecording() }
            return processor
        }
        defer { queue.async { [self] in if recording === processor { recording = nil } } }
        return try await processor.result()
    }
}

/// Collects one photo capture's callbacks and reports once, after `didFinishCaptureFor`.
/// AVFoundation calls these serially for a capture.
final class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let position: CameraPosition
    private let completion: (Result<CapturedPhoto, Error>) -> Void
    private var photoData: Data?
    private var dimensions: CMVideoDimensions?
    private var movieURL: URL?
    private var processingError: Error?

    init(position: CameraPosition, completion: @escaping (Result<CapturedPhoto, Error>) -> Void) {
        self.position = position
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            processingError = error
            return
        }
        photoData = photo.fileDataRepresentation()
        dimensions = photo.resolvedSettings.photoDimensions
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
        duration: CMTime,
        photoDisplayTime: CMTime,
        resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        if error == nil { movieURL = outputFileURL }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let failure = error ?? processingError {
            completion(.failure(failure))
            return
        }
        guard let photoData else {
            completion(.failure(CameraError.captureFailed("no photo data")))
            return
        }
        let size = dimensions ?? resolvedSettings.photoDimensions
        let metadata = CaptureMetadata(
            capturedAt: Date(),
            position: position,
            pixelWidth: Int(size.width),
            pixelHeight: Int(size.height)
        )
        completion(.success(CapturedPhoto(imageData: photoData, livePhotoMovieURL: movieURL, metadata: metadata)))
    }
}

/// Receives the movie file output's finish callback and hands the result to `result()`.
final class MovieRecordingProcessor: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    private let position: CameraPosition
    private let startedAt = Date()
    private let lock = NSLock()
    private var outcome: Result<RecordedVideo, Error>?
    private var waiters: [CheckedContinuation<RecordedVideo, Error>] = []

    init(position: CameraPosition) {
        self.position = position
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        // A recording that stopped at maxRecordedDuration reports an error but is complete.
        let finishedSuccessfully = error == nil
            || ((error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? false)
        let result: Result<RecordedVideo, Error>
        if finishedSuccessfully {
            let seconds = CMTimeGetSeconds(output.recordedDuration)
            let milliseconds = seconds.isFinite ? Int((seconds * 1000).rounded()) : 0
            result = .success(RecordedVideo(fileURL: outputFileURL, durationMs: milliseconds, position: position, capturedAt: startedAt))
        } else {
            result = .failure(error ?? CameraError.captureFailed("recording"))
        }
        lock.lock()
        outcome = result
        let pending = waiters
        waiters = []
        lock.unlock()
        for waiter in pending { waiter.resume(with: result) }
    }

    func result() async throws -> RecordedVideo {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let outcome {
                lock.unlock()
                continuation.resume(with: outcome)
            } else {
                waiters.append(continuation)
                lock.unlock()
            }
        }
    }
}
#endif

// Surfaces: camera.capture, camera.sendto, daily.capture, collage.view, collage.share.
// Live implementations of the capture services over AppServices (camera, photo library, voice,
// purchases) and AppData (groups, outbox, invitations, collages, signed URLs, offline cache).
import AppData
import AppModels
import AppServices
@preconcurrency import AVFoundation
import Foundation
import Photos
import SwiftUI
import UIKit

// MARK: - Camera

/// `CameraService` (AppServices) behind the `CaptureCamera` protocol.
///
/// Flash: `CameraService` exposes no flash mode for its photo settings, so the flash is the
/// camera's torch, lit for the capture and turned off after it (reported to the foundation owner).
@MainActor
final class LiveCaptureCamera: CaptureCamera {
    /// Bounded wait for exposure to settle after the torch lights (engineering bound, same order
    /// as `CaptureSessionController.settleTimeoutNanoseconds`).
    private static let torchSettleTimeout: Duration = .milliseconds(1500)
    private static let torchSettlePoll: Duration = .milliseconds(50)

    private let service: CameraService
    private let observers = NotificationObservers()
    var onInterruption: ((Bool) -> Void)?

    init(supportsDualCapture: Bool) {
        service = CameraService(supportsDualCapture: supportsDualCapture)
        let center = NotificationCenter.default
        let session = service.session
        let interrupted: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.onInterruption?(true) }
        }
        let resumed: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.onInterruption?(false) }
        }
        observers.add(center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: .main, using: interrupted))
        observers.add(center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: .main, using: interrupted))
        observers.add(center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: .main, using: resumed))
    }

    func authorization() -> PermissionStatus { CameraService.authorization(for: .video) }
    func requestAccess() async -> PermissionStatus { await CameraService.requestAccess(for: .video) }
    func microphoneAuthorization() -> PermissionStatus { CameraService.authorization(for: .audio) }
    func requestMicrophoneAccess() async -> PermissionStatus { await CameraService.requestAccess(for: .audio) }

    func hasFlash(at position: CameraPosition) -> Bool {
        Self.device(position)?.hasTorch ?? false
    }

    func configure(_ mode: CaptureCameraMode) async throws {
        switch mode {
        case let .photo(position):
            try await service.configure(.photo(position, livePhoto: true))
        case let .video(position):
            try await service.configure(.video(position))
        case .dual:
            try await service.configure(.dual)
        }
        await service.start()
    }

    func stop() async {
        await service.stop()
    }

    func capturePhoto(flash: Bool) async throws -> CaptureStill {
        let position = activePosition
        let photo = try await withTorch(flash, position: position) {
            try await self.service.capturePhoto()
        }
        return CaptureStill(photo)
    }

    func captureDual(flash: Bool) async throws -> CaptureDualStills {
        // The flash applies to the back photo (daily.capture: flash).
        let capture = try await withTorch(flash, position: .back) {
            try await self.service.captureDual()
        }
        return CaptureDualStills(back: CaptureStill(capture.back), front: CaptureStill(capture.front), simultaneous: capture.mode == .simultaneous)
    }

    func startRecording(maxDuration: TimeInterval) async throws {
        try await service.startRecording(isPremium: true, maxDuration: CMTime(seconds: maxDuration, preferredTimescale: 600))
    }

    func stopRecording() async throws -> CaptureVideo {
        let video = try await service.stopRecording()
        return CaptureVideo(fileURL: video.fileURL, durationMs: video.durationMs)
    }

    func preview(position: CameraPosition?) -> AnyView {
        AnyView(CameraPreview(camera: service, position: position, videoGravity: .resizeAspectFill))
    }

    private var activePosition: CameraPosition {
        switch service.configuration {
        case let .photo(position, _)?: return position
        case let .video(position)?: return position
        default: return .back
        }
    }

    private static func device(_ position: CameraPosition) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position == .back ? .back : .front)
    }

    private func withTorch<T>(_ on: Bool, position: CameraPosition, _ body: () async throws -> T) async throws -> T {
        guard on, let device = Self.device(position), device.hasTorch, device.isTorchModeSupported(.on) else {
            return try await body()
        }
        do {
            try device.lockForConfiguration()
            device.torchMode = .on
            device.unlockForConfiguration()
        } catch {
            return try await body()
        }
        defer {
            if (try? device.lockForConfiguration()) != nil {
                device.torchMode = .off
                device.unlockForConfiguration()
            }
        }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: Self.torchSettleTimeout)
        while device.isAdjustingExposure, clock.now < deadline {
            try? await Task.sleep(for: Self.torchSettlePoll)
        }
        return try await body()
    }
}

/// Notification observer tokens, removed when their owner goes away.
final class NotificationObservers: @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: [NSObjectProtocol] = []

    func add(_ token: NSObjectProtocol) {
        lock.lock()
        tokens.append(token)
        lock.unlock()
    }

    deinit {
        for token in tokens { NotificationCenter.default.removeObserver(token) }
    }
}

private extension CaptureStill {
    init(_ photo: CapturedPhoto) {
        self.init(
            imageData: photo.imageData,
            livePhotoMovieURL: photo.livePhotoMovieURL,
            pixelWidth: photo.metadata.pixelWidth,
            pixelHeight: photo.metadata.pixelHeight,
            position: photo.metadata.position
        )
    }
}

// MARK: - Photo library

@MainActor
final class LiveCaptureLibrary: CaptureLibrary {
    private let service = PhotoLibraryService()

    func newestThumbnail(side: CGFloat) async -> UIImage? {
        guard PhotoLibraryService.readAuthorization().allowsAccess else { return nil }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1
        guard let asset = PHAsset.fetchAssets(with: .image, options: options).firstObject else { return nil }
        let scale = UITraitCollection.current.displayScale
        let target = CGSize(width: side * scale, height: side * scale)
        let request = PHImageRequestOptions()
        request.deliveryMode = .highQualityFormat
        request.resizeMode = .fast
        request.isNetworkAccessAllowed = false
        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            PHImageManager.default().requestImage(for: asset, targetSize: target, contentMode: .aspectFill, options: request) { @Sendable image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    func save(_ media: CapturedMedia) async throws {
        switch media.kind {
        case .photo:
            guard let still = media.still else { return }
            try await service.saveImage(still.imageData)
        case .livePhoto:
            guard let still = media.still else { return }
            if let movie = still.livePhotoMovieURL {
                try await service.saveLivePhoto(imageData: still.imageData, movieURL: movie)
            } else {
                try await service.saveImage(still.imageData)
            }
        case .video:
            guard let video = media.video else { return }
            try await service.saveVideo(at: video.fileURL)
        }
    }
}

// MARK: - Groups

@MainActor
final class LiveCaptureGroups: CaptureGroupSource {
    private let data: DataEnvironment?
    private let widgetStore: WidgetStore
    private var covers: [String: UIImage] = [:]

    init(data: DataEnvironment?, widgetStore: WidgetStore) {
        self.data = data
        self.widgetStore = widgetStore
    }

    var isOffline: Bool { data?.reachability.currentStatus == .offline }

    func cachedGroups() async -> [CaptureGroup]? {
        if let cached = await data?.groups.cachedGroups() {
            return cached.value.map(CaptureGroup.init)
        }
        // The widget's group list (names only) is the last copy on the device.
        let stored = widgetStore.groups()
        return stored.isEmpty ? nil : stored.map { CaptureGroup(id: $0.id, name: $0.name, coverPath: nil) }
    }

    func loadGroups() async throws -> [CaptureGroup] {
        guard let data else { throw DataError.notConfigured }
        return try await data.groups.myGroups().map(CaptureGroup.init)
    }

    func coverImage(path: String) async -> UIImage? {
        if let image = covers[path] { return image }
        guard let data, let url = try? await data.signedURLs.url(for: path),
              let response = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: response.0) else { return nil }
        covers[path] = image
        return image
    }
}

private extension CaptureGroup {
    init(_ group: PhotoGroup) {
        self.init(id: group.id.rawValue, name: group.name, coverPath: group.coverPath)
    }
}

// MARK: - Premium

@MainActor
final class LiveCapturePremium: CapturePremium {
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func isPremium() async -> Bool {
        if environment.purchases.isPremium { return true }
        guard let data = environment.data else { return false }
        return (try? await data.account.hasPremium()) ?? false
    }

    /// The camera is a capture screen, where the prompt never shows (`SessionPromptGate.Blocker.capture`).
    /// When the member asks for a premium feature there (camera.capture: the session's first long
    /// press), the capture closes first and the paywall opens in its place, once per session.
    func presentPaywallIfAllowed() -> Bool {
        let router = environment.router
        var blockers = router.activePromptBlockers
        blockers.remove(.capture)
        guard router.promptGate.canPrompt(activeBlockers: blockers) else { return false }
        router.dismissModal()
        return router.presentPaywallForLockedFeature(isPremium: false)
    }
}

// MARK: - Voice note

@MainActor
final class LiveCaptureVoiceRecorder: CaptureVoiceRecorder {
    /// The send-to voice note draws no waveform, so one level sample per second is enough.
    private let recorder = VoiceRecorder(meteringInterval: .seconds(1))

    var isRecording: Bool { recorder.isRecording }
    func permission() -> PermissionStatus { VoiceRecorder.permission() }
    func requestPermission() async -> PermissionStatus { await VoiceRecorder.requestPermission() }
    func start() throws { try recorder.start() }

    func stop() throws -> VoiceNote {
        let recording = try recorder.stop()
        return VoiceNote(fileURL: recording.fileURL, durationMs: recording.durationMs)
    }

    func cancel() { recorder.cancel() }
}

// MARK: - Posting

@MainActor
final class LiveCapturePosting: CapturePosting {
    private let data: DataEnvironment?

    init(data: DataEnvironment?) {
        self.data = data
    }

    func publish(_ draft: PostDraft) async throws {
        guard let data else { throw DataError.notConfigured }
        _ = try await data.publisher.publish(draft)
    }

    func retryPending() async -> CaptureRetryResult {
        guard let data else { return CaptureRetryResult(posted: 0, error: .notConfigured) }
        let results = await data.publisher.resumePending()
        var posted = 0
        var firstError: DataError?
        for result in results.values {
            switch result {
            case .success: posted += 1
            case let .failure(error): firstError = firstError ?? error
            }
        }
        return CaptureRetryResult(posted: posted, error: firstError)
    }

    func onlineUpdates() -> AsyncStream<Bool> {
        guard let data else { return AsyncStream { $0.finish() } }
        let updates = data.reachability.updates()
        return AsyncStream { continuation in
            let task = Task {
                for await status in updates {
                    continuation.yield(status == .online)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - Daily invitation

@MainActor
final class LiveCaptureInvitations: CaptureInvitationSource {
    private let data: DataEnvironment?
    private let widgetStore: WidgetStore

    init(data: DataEnvironment?, widgetStore: WidgetStore) {
        self.data = data
        self.widgetStore = widgetStore
    }

    /// The data layer measures no clock offset yet; device time is used (reported).
    var clock: ServerClock { .device }

    func invitation(id: String, groupID: String) async throws -> CaptureInvitation? {
        guard let data else { throw DataError.notConfigured }
        guard let invitation = try await data.invitations.invitation(id: InvitationID(id)) else { return nil }
        let name = await groupName(groupID: invitation.groupID.rawValue)
        return CaptureInvitation(
            id: invitation.id.rawValue,
            groupID: invitation.groupID.rawValue,
            groupName: name,
            firesAt: invitation.firesAt,
            closesAt: invitation.closesAt,
            localDate: invitation.localDate
        )
    }

    func groupName(groupID: String) async -> String {
        if let cached = await data?.groups.cachedGroups()?.value.first(where: { $0.id.rawValue == groupID }) {
            return cached.name
        }
        if let stored = widgetStore.groups().first(where: { $0.id == groupID }) {
            return stored.name
        }
        if let group = try? await data?.groups.group(id: GroupID(groupID)) {
            return group.name
        }
        return ""
    }

    func myFirstName() async -> String {
        guard let profile = try? await data?.profiles.myProfile() else { return "" }
        return CaptureFormat.firstName(profile.displayName)
    }
}

// MARK: - Collage

@MainActor
final class LiveCaptureCollages: CaptureCollageSource {
    private let data: DataEnvironment?
    private let directory: URL

    init(data: DataEnvironment?) {
        self.data = data
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        directory = caches.appendingPathComponent("CaptureCollagePages", isDirectory: true)
    }

    var isOffline: Bool { data?.reachability.currentStatus == .offline }

    private static func cacheKey(_ invitationID: String) -> CacheKey {
        CacheKey("capture.collage.\(invitationID)")
    }

    func collage(invitationID: String) async throws -> Collage? {
        guard let data else { throw DataError.notConfigured }
        let collage = try await data.memories.collage(invitationID: InvitationID(invitationID))
        if let collage {
            await data.cache.write(collage, for: Self.cacheKey(invitationID))
        }
        return collage
    }

    func cachedCollage(invitationID: String) async -> Collage? {
        await data?.cache.read(Collage.self, for: Self.cacheKey(invitationID))?.value
    }

    func cachedImage(path: String) -> UIImage? {
        UIImage(contentsOfFile: fileURL(path).path)
    }

    func image(path: String) async throws -> UIImage {
        if let image = cachedImage(path: path) { return image }
        let file = try await download(path)
        guard let image = UIImage(contentsOfFile: file.path) else { throw DataError.decoding(path) }
        return image
    }

    func shareFile(path: String) async throws -> URL {
        let cached = try await download(path)
        let named = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent((path as NSString).lastPathComponent)
        try FileManager.default.createDirectory(at: named.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: cached, to: named)
        return named
    }

    /// Storage paths use only letters, digits and `_ . / -` (docs/API.md §7), so a flattened
    /// path is a safe file name; the `<version>` folder changes on every recompose.
    private func fileURL(_ path: String) -> URL {
        directory.appendingPathComponent(path.replacingOccurrences(of: "/", with: "_"))
    }

    private func download(_ path: String) async throws -> URL {
        let file = fileURL(path)
        if FileManager.default.fileExists(atPath: file.path) { return file }
        guard let data else { throw DataError.notConfigured }
        let url = try await data.signedURLs.url(for: path)
        let bytes: Data
        do {
            bytes = try await URLSession.shared.data(from: url).0
        } catch {
            throw DataError.from(error)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try bytes.write(to: file, options: [.atomic])
        return file
    }
}

// MARK: - Navigation

@MainActor
final class LiveCaptureNavigation: CaptureNavigation {
    private let router: AppRouter

    init(router: AppRouter) {
        self.router = router
    }

    func closeCapture() {
        router.dismissModal()
    }

    func openCamera(groupID: String?) {
        router.handle(.camera(groupID: groupID))
    }

    var canCreateGroup: Bool { true }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

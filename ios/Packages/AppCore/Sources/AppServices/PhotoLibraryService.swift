#if os(iOS)
import AppModels
import Foundation
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Importing from and saving to the photo library (`onboarding.permission.photos`, `photo.viewer` save).
///
/// Importing goes through the system picker (`PhotosPicker` / `PHPickerViewController`), which
/// runs out of process and needs no permission. Saving uses add-only access; a user who granted
/// "selected photos" (limited) read access can still add photos, and new items join their
/// selection automatically.
public struct PhotoLibraryService: Sendable {
    public enum LibraryError: Error, Equatable, Sendable {
        case notAuthorized(PermissionStatus)
        case unreadableItem
    }

    public init() {}

    // MARK: Permissions

    /// Add-only access, used for saving.
    public static func addAuthorization() -> PermissionStatus {
        map(PHPhotoLibrary.authorizationStatus(for: .addOnly))
    }

    /// Read access (reports `.limited` for "selected photos").
    public static func readAuthorization() -> PermissionStatus {
        map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    public static func requestAddAuthorization() async -> PermissionStatus {
        map(await PHPhotoLibrary.requestAuthorization(for: .addOnly))
    }

    public static func requestReadAuthorization() async -> PermissionStatus {
        map(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
    }

    static func map(_ status: PHAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized: return .granted
        case .limited: return .limited
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    // MARK: Import (no permission needed)

    /// Picker configuration without a photo library reference, so no access is requested.
    public static func pickerConfiguration(selectionLimit: Int, includeVideos: Bool) -> PHPickerConfiguration {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = selectionLimit
        configuration.filter = includeVideos ? .any(of: [.images, .livePhotos, .videos]) : .any(of: [.images, .livePhotos])
        configuration.preferredAssetRepresentationMode = .current
        return configuration
    }

    /// Image data of a `PhotosPicker` selection.
    public func imageData(from item: PhotosPickerItem) async throws -> Data {
        guard let data = try await item.loadTransferable(type: Data.self) else { throw LibraryError.unreadableItem }
        return data
    }

    /// Image data of a `PHPickerViewController` result.
    public func imageData(from result: PHPickerResult) async throws -> Data {
        let provider = result.itemProvider
        guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else { throw LibraryError.unreadableItem }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? LibraryError.unreadableItem)
                }
            }
        }
    }

    // MARK: Save (add-only)

    public func saveImage(_ data: Data) async throws {
        try await requireAddAccess()
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
        }
    }

    public func saveLivePhoto(imageData: Data, movieURL: URL) async throws {
        try await requireAddAccess()
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: imageData, options: nil)
            let movieOptions = PHAssetResourceCreationOptions()
            movieOptions.shouldMoveFile = false
            request.addResource(with: .pairedVideo, fileURL: movieURL, options: movieOptions)
        }
    }

    public func saveVideo(at fileURL: URL) async throws {
        try await requireAddAccess()
        try await PHPhotoLibrary.shared().performChanges {
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = false
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: fileURL, options: options)
        }
    }

    private func requireAddAccess() async throws {
        var status = Self.addAuthorization()
        if status == .notDetermined { status = await Self.requestAddAuthorization() }
        guard status.allowsAccess else { throw LibraryError.notAuthorized(status) }
    }
}
#endif

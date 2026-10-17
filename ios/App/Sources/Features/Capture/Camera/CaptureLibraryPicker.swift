// Surface: camera.capture (library circle) → camera.sendto. Reference images: references/auto/retro/press/tc-2025-12-rewind-device-a.png
// (the 64-pt circle that opens it), references/auto/locket/store/locket-store-07.png (mechanics: library pick)
// (design/surfaces/camera.capture.md).
// The system photo picker (PHPickerViewController): no library permission; a picked Live Photo
// arrives as PHLivePhoto and is exported as its still and paired movie
// (docs/PLATFORM_CONSTRAINTS.md §6). Up to `batch_max_photos` items (several photos in one post,
// docs/RESEARCH_FEATURES_2026-10-17.md #1), handed on in the order picked; each carries the day it was taken
// (`CaptureTakenOn`, migration 0050).
import AppServices
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct CaptureLibraryPicker: UIViewControllerRepresentable {
    /// The most items the picker lets the member choose (`batch_max_photos`; 1 while unknown).
    var selectionLimit: Int = 1
    /// Called once with the picked media in the order picked (unreadable items left out); empty when cancelled.
    let onFinish: @MainActor ([CapturedMedia]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PhotoLibraryService.pickerConfiguration(selectionLimit: max(1, selectionLimit), includeVideos: true)
        // The badges show the order the photos will be posted in.
        if selectionLimit > 1 { configuration.selection = .ordered }
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    @MainActor
    final class Coordinator: NSObject {
        let onFinish: @MainActor ([CapturedMedia]) -> Void

        init(onFinish: @escaping @MainActor ([CapturedMedia]) -> Void) {
            self.onFinish = onFinish
        }
    }
}

extension CaptureLibraryPicker.Coordinator: @preconcurrency PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let providers = results.map(\.itemProvider)
        guard !providers.isEmpty else {
            onFinish([])
            return
        }
        let finish = onFinish
        Task {
            var picked: [CapturedMedia] = []
            for provider in providers {
                if let media = await CaptureLibraryImport.media(from: provider) { picked.append(media) }
            }
            finish(picked)
        }
    }
}

/// Converts a picker item into `CapturedMedia`: Live Photo → still + paired movie, video → movie
/// file, image → its data; each with the day it was taken (`CaptureTakenOn`).
enum CaptureLibraryImport {
    private struct LivePhotoFiles: Sendable {
        let still: URL
        let movie: URL
    }

    static func media(from provider: NSItemProvider) async -> CapturedMedia? {
        if provider.canLoadObject(ofClass: PHLivePhoto.self), let files = await exportLivePhoto(provider),
           let data = try? Data(contentsOf: files.still), let size = ImageEncoder.pixelSize(data) {
            let still = CaptureStill(imageData: data, livePhotoMovieURL: files.movie, pixelWidth: size.width, pixelHeight: size.height, position: nil)
            return .photo(still, capturedAt: Date(), takenOn: CaptureTakenOn.fromImage(data))
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier), let file = await copyMovie(provider) {
            return await video(at: file)
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier), let data = await imageData(provider) {
            return photo(data)
        }
        return nil
    }

    /// A photo file's data (library pick, shared item): nil when it is not an image.
    static func photo(_ data: Data) -> CapturedMedia? {
        guard let size = ImageEncoder.pixelSize(data) else { return nil }
        let still = CaptureStill(imageData: data, livePhotoMovieURL: nil, pixelWidth: size.width, pixelHeight: size.height, position: nil)
        return .photo(still, capturedAt: Date(), takenOn: CaptureTakenOn.fromImage(data))
    }

    /// A movie file (library pick, shared item), with its length and creation day.
    static func video(at file: URL) async -> CapturedMedia {
        let duration = await CaptureDraftBuilder.durationMs(of: file) ?? 0
        return .video(CaptureVideo(fileURL: file, durationMs: duration), capturedAt: Date(), takenOn: await CaptureTakenOn.fromMovie(at: file))
    }

    private static func temporaryFolder() -> URL? {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return (try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)) == nil ? nil : folder
    }

    private static func exportLivePhoto(_ provider: NSItemProvider) async -> LivePhotoFiles? {
        await withCheckedContinuation { (continuation: CheckedContinuation<LivePhotoFiles?, Never>) in
            _ = provider.loadObject(ofClass: PHLivePhoto.self) { object, _ in
                guard let livePhoto = object as? PHLivePhoto, let folder = temporaryFolder() else {
                    continuation.resume(returning: nil)
                    return
                }
                let resources = PHAssetResource.assetResources(for: livePhoto)
                guard let photo = resources.first(where: { $0.type == .photo }),
                      let video = resources.first(where: { $0.type == .pairedVideo }) else {
                    continuation.resume(returning: nil)
                    return
                }
                let stillURL = folder.appendingPathComponent(photo.originalFilename)
                let movieURL = folder.appendingPathComponent("motion").appendingPathExtension("mov")
                let manager = PHAssetResourceManager.default()
                manager.writeData(for: photo, toFile: stillURL, options: nil) { error in
                    guard error == nil else {
                        continuation.resume(returning: nil)
                        return
                    }
                    manager.writeData(for: video, toFile: movieURL, options: nil) { error in
                        continuation.resume(returning: error == nil ? LivePhotoFiles(still: stillURL, movie: movieURL) : nil)
                    }
                }
            }
        }
    }

    /// The picker's file is deleted when the callback returns, so it is copied first.
    private static func copyMovie(_ provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
            _ = provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                guard let url, let folder = temporaryFolder() else {
                    continuation.resume(returning: nil)
                    return
                }
                let copy = folder.appendingPathComponent(url.lastPathComponent)
                do {
                    try FileManager.default.copyItem(at: url, to: copy)
                    continuation.resume(returning: copy)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func imageData(_ provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }
}

// Surface: camera.capture (library thumbnail) → camera.sendto. Reference: Yope library thumbnail
// (references/auto/yope/frames/a-jacob-7691153057177931039-t3.73-camera-hold-to-record.png).
// The system photo picker (PHPickerViewController): no library permission; a picked Live Photo
// arrives as PHLivePhoto and is exported as its still and paired movie
// (docs/PLATFORM_CONSTRAINTS.md §6).
import AppServices
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct CaptureLibraryPicker: UIViewControllerRepresentable {
    /// Called once with the picked media, or nil when cancelled / unreadable.
    let onFinish: @MainActor (CapturedMedia?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        let configuration = PhotoLibraryService.pickerConfiguration(selectionLimit: 1, includeVideos: true)
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
        let onFinish: @MainActor (CapturedMedia?) -> Void

        init(onFinish: @escaping @MainActor (CapturedMedia?) -> Void) {
            self.onFinish = onFinish
        }
    }
}

extension CaptureLibraryPicker.Coordinator: @preconcurrency PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard let provider = results.first?.itemProvider else {
            onFinish(nil)
            return
        }
        let finish = onFinish
        Task {
            let media = await CaptureLibraryImport.media(from: provider)
            finish(media)
        }
    }
}

/// Converts a picker item into `CapturedMedia`: Live Photo → still + paired movie, video → movie
/// file, image → its data.
enum CaptureLibraryImport {
    private struct LivePhotoFiles: Sendable {
        let still: URL
        let movie: URL
    }

    static func media(from provider: NSItemProvider) async -> CapturedMedia? {
        if provider.canLoadObject(ofClass: PHLivePhoto.self), let files = await exportLivePhoto(provider),
           let data = try? Data(contentsOf: files.still), let size = ImageEncoder.pixelSize(data) {
            let still = CaptureStill(imageData: data, livePhotoMovieURL: files.movie, pixelWidth: size.width, pixelHeight: size.height, position: nil)
            return .photo(still, capturedAt: Date())
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier), let file = await copyMovie(provider) {
            let duration = await CaptureDraftBuilder.durationMs(of: file) ?? 0
            return .video(CaptureVideo(fileURL: file, durationMs: duration), capturedAt: Date())
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier), let data = await imageData(provider),
           let size = ImageEncoder.pixelSize(data) {
            let still = CaptureStill(imageData: data, livePhotoMovieURL: nil, pixelWidth: size.width, pixelHeight: size.height, position: nil)
            return .photo(still, capturedAt: Date())
        }
        return nil
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

// Surface: camera.sendto (preview card). Reference: references/auto/yope/frames/
// a-chuongxetank-7694968408424582452-t6.73-sendto-voice-tooltip.png. The member's own capture,
// aspect-fill: a photo, a Live Photo that plays its motion on long press (PHLivePhotoView), or a
// video that plays muted in a loop.
@preconcurrency import AVFoundation
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct CapturePreviewMedia: View {
    let media: CapturedMedia

    var body: some View {
        switch media.kind {
        case .photo:
            stillImage
        case .livePhoto:
            if let still = media.still, let movie = still.livePhotoMovieURL {
                LivePhotoPreview(imageData: still.imageData, movieURL: movie)
            } else {
                stillImage
            }
        case .video:
            if let video = media.video {
                LoopingVideoPreview(url: video.fileURL)
            }
        }
    }

    @ViewBuilder
    private var stillImage: some View {
        if let image = media.still?.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        }
    }
}

/// PHLivePhotoView: touch and hold plays the motion (the system's own gesture).
struct LivePhotoPreview: UIViewRepresentable {
    let imageData: Data
    let movieURL: URL

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        guard let stillURL = Self.writeStill(imageData) else { return view }
        let placeholder = UIImage(data: imageData)
        PHLivePhoto.request(
            withResourceFileURLs: [stillURL, movieURL],
            placeholderImage: placeholder,
            targetSize: .zero,
            contentMode: .aspectFill
        ) { @Sendable [weak view] livePhoto, _ in
            // PhotoKit may call back on any queue; the view is updated on the main actor.
            guard let livePhoto else { return }
            nonisolated(unsafe) let result = livePhoto
            Task { @MainActor in
                view?.livePhoto = result
            }
        }
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {}

    /// PHLivePhoto needs the still as a file next to its movie.
    private static func writeStill(_ data: Data) -> URL? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) as String?,
              let ext = UTType(type)?.preferredFilenameExtension else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        return (try? data.write(to: url, options: [.atomic])) == nil ? nil : url
    }
}

/// A muted, looping, aspect-filled video.
struct LoopingVideoPreview: UIViewRepresentable {
    let url: URL

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
        var looper: AVPlayerLooper?
    }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        let player = AVQueuePlayer()
        player.isMuted = true
        view.looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        view.playerLayer?.player = player
        view.playerLayer?.videoGravity = .resizeAspectFill
        player.play()
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}

    static func dismantleUIView(_ uiView: PlayerView, coordinator: ()) {
        uiView.playerLayer?.player?.pause()
        uiView.looper = nil
    }
}

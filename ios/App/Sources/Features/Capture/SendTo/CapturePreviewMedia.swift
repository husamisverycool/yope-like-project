// Surface: camera.sendto (the photo frame). Reference images: references/auto/retro/store/retro-store-03.png (ST-03:
// Retro's Postcard photo frame) (design/surfaces/camera.sendto.md). The member's own capture,
// aspect-fill: a photo, a Live Photo that plays its motion on long press (PHLivePhotoView), or a
// video that plays muted in a loop.
@preconcurrency import AVFoundation
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct CapturePreviewMedia: View {
    let media: CapturedMedia
    /// The still, decoded off the main actor at the frame's size (nil until ready: the frame stays
    /// `color.global.backgroundDeep`).
    let still: UIImage?

    var body: some View {
        switch media.kind {
        case .photo:
            stillImage
        case .livePhoto:
            if let capture = media.still, let movie = capture.livePhotoMovieURL {
                LivePhotoPreview(imageData: capture.imageData, placeholder: still, movieURL: movie)
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
        if let still {
            Image(uiImage: still)
                .resizable()
                .scaledToFill()
        }
    }
}

/// PHLivePhotoView: touch and hold plays the motion (the system's own gesture).
struct LivePhotoPreview: UIViewRepresentable {
    let imageData: Data
    let placeholder: UIImage?
    let movieURL: URL

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        guard let stillURL = Self.writeStill(imageData) else { return view }
        _ = PHLivePhoto.request(
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

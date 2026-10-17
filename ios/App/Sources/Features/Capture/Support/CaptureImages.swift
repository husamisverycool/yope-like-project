// Surfaces: camera.sendto (preview, group covers), daily.capture (preview), daily.dualimage,
// collage.view (design/surfaces/<id>.md; reference images listed there). Images are decoded off the main actor, downsampled to the frame
// they are shown in, so lists scroll and previews appear without decoding on the main thread.
@preconcurrency import AVFoundation
import Foundation
import ImageIO
import UIKit

enum CaptureImageDecoder {
    /// Decodes `data` (any ImageIO format) with its EXIF orientation applied, longest side at most
    /// `maxPixelSize`, ready for display. Runs off the main actor.
    static func image(data: Data, maxPixelSize: CGFloat) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            Self.decode(CGImageSourceCreateWithData(data as CFData, nil), maxPixelSize: maxPixelSize)
        }.value
    }

    static func image(optionalData data: Data?, maxPixelSize: CGFloat) async -> UIImage? {
        guard let data else { return nil }
        return await image(data: data, maxPixelSize: maxPixelSize)
    }

    /// Same, from a file.
    static func image(contentsOf url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            Self.decode(CGImageSourceCreateWithURL(url as CFURL, nil), maxPixelSize: maxPixelSize)
        }.value
    }

    /// A video's first frame (its orientation applied), longest side at most `maxPixelSize` — the send-to selection
    /// strip's video tiles. Runs off the main actor; nil when the file has no readable frame.
    static func videoFrame(_ url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
        guard let frame = try? await generator.image(at: .zero) else { return nil }
        return UIImage(cgImage: frame.image)
    }

    /// The longest side, in pixels, of a frame `points` long on this screen.
    @MainActor
    static func pixels(_ points: CGFloat) -> CGFloat {
        points * UITraitCollection.current.displayScale
    }

    /// The width of the window's screen in points (an upper bound for full-width frames such as the viewfinder).
    @MainActor
    static var screenWidth: CGFloat {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.screen.bounds.width ?? 0
    }

    private static func decode(_ source: CGImageSource?, maxPixelSize: CGFloat) -> UIImage? {
        guard let source, CGImageSourceGetCount(source) > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize.rounded(.up))),
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}

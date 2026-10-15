// Surfaces: camera.sendto (preview card, recipient avatars), daily.capture (preview),
// daily.dualimage, collage.view. Images are decoded off the main actor, downsampled to the frame
// they are shown in, so lists scroll and previews appear without decoding on the main thread.
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

    /// The longest side, in pixels, of a frame `points` long on this screen.
    @MainActor
    static func pixels(_ points: CGFloat) -> CGFloat {
        points * UITraitCollection.current.displayScale
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

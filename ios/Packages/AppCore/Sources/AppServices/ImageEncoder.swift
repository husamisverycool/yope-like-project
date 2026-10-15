#if os(iOS)
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Prepares photos for upload. The app never collects location, so every image leaves the
/// device without GPS metadata — re-encoded images carry no metadata at all.
public enum ImageEncoder {
    public struct Options: Hashable, Sendable {
        /// Longest side in pixels after downscaling (images are never upscaled).
        public var maxPixelSize: Int
        /// JPEG quality, 0…1.
        public var compressionQuality: Double

        /// The upload limits are set by the API contract (docs/API.md), not here.
        public init(maxPixelSize: Int, compressionQuality: Double) {
            self.maxPixelSize = maxPixelSize
            self.compressionQuality = compressionQuality
        }
    }

    public enum EncoderError: Error, Equatable, Sendable {
        case unreadableImage
        case encodingFailed
    }

    /// Decodes any ImageIO format (HEIF, JPEG, PNG…), applies the EXIF orientation to the pixels,
    /// downsizes to `maxPixelSize` and encodes a JPEG with no metadata (no EXIF, no GPS, no TIFF
    /// maker notes). Color profile is kept with the pixels.
    public static func jpegForUpload(_ data: Data, options: Options) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { throw EncoderError.unreadableImage }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: options.maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            throw EncoderError.unreadableImage
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw EncoderError.encodingFailed
        }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: options.compressionQuality]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw EncoderError.encodingFailed }
        return output as Data
    }

    /// Removes GPS metadata without re-encoding the pixels (for originals that are uploaded as
    /// they are, e.g. Live Photo stills). Falls back to `nil` when the format cannot be rewritten
    /// losslessly; callers then use `jpegForUpload`.
    public static func removingLocation(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output as CFMutableData, type, 1, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageMetadataShouldExcludeGPS: true]
        guard CGImageDestinationCopyImageSource(destination, source, options as CFDictionary, nil) else { return nil }
        let result = output as Data
        return containsLocation(result) ? nil : result
    }

    /// Whether the image carries a GPS dictionary.
    public static func containsLocation(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return false }
        return properties[kCGImagePropertyGPSDictionary] != nil
    }

    /// Pixel size of the first image.
    public static func pixelSize(_ data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (width, height)
    }
}
#endif

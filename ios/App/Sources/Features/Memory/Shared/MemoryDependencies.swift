// Where the memory screens get their data, images, clock and haptics from.
// The app uses AppData (AppEnvironment.shared.data); DEBUG builds launched with the argument
// `-MemoryFixtures` (AppUITests/Memory, `MemoryLaunch`) use `FixtureMemoryData.uiTest` instead.
import AppData
import DesignSystem
import Foundation
import SwiftUI
import ImageIO
import UIKit

@MainActor
struct MemoryDependencies {
    /// Nil while the backend is not configured (config/app.json BLOCKED): screens show their error state.
    var data: (any MemoryDataSource)?
    var images: any MemoryImageLoading
    var now: @Sendable () -> Date
    /// Plays a haptic token (`Tokens.Haptics.*`).
    var haptics: @MainActor (DSHaptic) -> Void
    /// Persists small per-account flags (the tagging coach was seen).
    var defaults: UserDefaults
    /// Shows a group's screen (`groups.screen`) on the main navigation stack.
    var openGroup: @MainActor (String) -> Void
    /// Last content per screen (cache-first loading).
    var cache: MemoryCache

    init(
        data: (any MemoryDataSource)?,
        images: any MemoryImageLoading,
        now: @escaping @Sendable () -> Date = { Date() },
        haptics: @escaping @MainActor (DSHaptic) -> Void = { $0.play() },
        defaults: UserDefaults = .standard,
        openGroup: @escaping @MainActor (String) -> Void = { AppEnvironment.shared.router.path = [.group(id: $0)] },
        cache: MemoryCache = .shared
    ) {
        self.data = data
        self.images = images
        self.now = now
        self.haptics = haptics
        self.defaults = defaults
        self.openGroup = openGroup
        self.cache = cache
    }

    /// The launch argument (`-MemoryFixtures`) that switches the memory screens to fixtures.
    nonisolated static let fixturesArgument = "MemoryFixtures"

    /// The dependencies screens use when none are injected.
    static var current: MemoryDependencies {
        #if DEBUG
        if MemoryLaunch.usesFixtures {
            return MemoryDependencies(data: FixtureMemoryData.uiTest, images: MemoryImageLoader.shared)
        }
        #endif
        return MemoryDependencies(
            data: AppEnvironment.shared.data.map { LiveMemoryData(environment: $0) },
            images: MemoryImageLoader.shared
        )
    }
}

// MARK: - Images

/// Loads and caches images by (signed) URL, decoded off the main thread and downsampled to the
/// size they are shown at. `cachedImage` is read synchronously while rendering, so snapshot tests
/// and the year-story share renderer see images that were loaded before.
@MainActor
protocol MemoryImageLoading: AnyObject, Sendable {
    /// The largest decoded image of `url` in memory.
    func cachedImage(for url: URL) -> UIImage?
    /// Decodes `url` with its longest side at most `maxPixelSize` pixels (nil = full size).
    func image(for url: URL, maxPixelSize: CGFloat?) async -> UIImage?
}

extension MemoryImageLoading {
    func image(for url: URL) async -> UIImage? {
        await image(for: url, maxPixelSize: nil)
    }
}

/// Carries a decoded `CGImage` from the decoding task back to the main actor (CGImage is immutable).
struct DecodedImage: @unchecked Sendable {
    let image: CGImage
}

@MainActor
final class MemoryImageLoader: MemoryImageLoading {
    static let shared = MemoryImageLoader()

    private struct Entry {
        let image: UIImage
        /// Longest side in pixels; `.infinity` for a full-size decode.
        let pixelSize: CGFloat
    }

    private var decoded: [URL: Entry] = [:]
    private let bytes = NSCache<NSURL, NSData>()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    func cachedImage(for url: URL) -> UIImage? {
        decoded[url]?.image
    }

    func image(for url: URL, maxPixelSize: CGFloat?) async -> UIImage? {
        let wanted = maxPixelSize ?? .infinity
        if let entry = decoded[url], entry.pixelSize >= wanted { return entry.image }
        let key = url.absoluteString + "#" + String(describing: wanted) // provenance-ok: cache key
        if let task = inFlight[key] { return await task.value }
        let cachedBytes = bytes.object(forKey: url as NSURL) as Data?
        let task = Task<UIImage?, Never> { [bytes] in
            var data = cachedBytes
            if data == nil {
                data = try? await URLSession.shared.data(from: url).0
                if let data { bytes.setObject(data as NSData, forKey: url as NSURL) }
            }
            guard let data else { return nil }
            let result = await Task.detached(priority: .userInitiated) {
                Self.decode(data, maxPixelSize: maxPixelSize)
            }.value
            return result.map { UIImage(cgImage: $0.image) }
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image, (decoded[url]?.pixelSize ?? 0) < wanted {
            decoded[url] = Entry(image: image, pixelSize: wanted)
        }
        return image
    }

    /// ImageIO decode (thumbnail with transform when downsampling), off the main actor.
    nonisolated static func decode(_ data: Data, maxPixelSize: CGFloat?) -> DecodedImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        var options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        if let maxPixelSize, maxPixelSize.isFinite, maxPixelSize > 0 {
            options[kCGImageSourceThumbnailMaxPixelSize] = maxPixelSize
        }
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return DecodedImage(image: image)
    }
}

private struct MemoryImageLoaderKey: EnvironmentKey {
    static let defaultValue: (any MemoryImageLoading)? = nil
}

extension EnvironmentValues {
    /// Overrides the image loader of `MemoryRemoteImage` (tests); nil = the dependencies' loader.
    var memoryImageLoader: (any MemoryImageLoading)? {
        get { self[MemoryImageLoaderKey.self] }
        set { self[MemoryImageLoaderKey.self] = newValue }
    }
}

/// A photo from storage, decoded at the size it is shown. It takes exactly the proposed size (the
/// caller reserves it from tokens or the media's dimensions, so nothing moves when the image
/// arrives); until then the screen background shows through (no placeholder colour is specified
/// for these surfaces).
struct MemoryRemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    @Environment(\.memoryImageLoader) private var injected
    @Environment(\.displayScale) private var displayScale
    @State private var loaded: UIImage?

    var body: some View {
        let loader = injected ?? MemoryImageLoader.shared
        let image = loaded ?? url.flatMap { loader.cachedImage(for: $0) }
        GeometryReader { proxy in
            Color.clear
                .overlay {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                    }
                }
                .clipped()
                .task(id: url) {
                    guard let url else {
                        loaded = nil
                        return
                    }
                    let longest = max(proxy.size.width, proxy.size.height) * displayScale
                    loaded = await loader.image(for: url, maxPixelSize: longest > 0 ? longest : nil)
                }
        }
    }
}

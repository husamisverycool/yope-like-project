// Shared component — images from the private `media` bucket (avatars: Avatar.swift, C-23).
import DesignSystem
import ImageIO
import SwiftUI
import UIKit

/// Turns a storage path (`avatars/<uid>/…`, `u/<uid>/<media>/…`) into a short-lived signed URL
/// (docs/API.md §7). The app shell injects one backed by AppData's `SignedURLCache`.
typealias StorageURLResolver = @MainActor @Sendable (String) async throws -> URL

private struct StorageURLResolverKey: EnvironmentKey {
    static let defaultValue: StorageURLResolver? = nil
}

extension EnvironmentValues {
    /// Resolves storage paths for `StorageImage` / `PhotoView` / `AvatarView`. Nil (previews, snapshots): placeholders are shown.
    var storageURLResolver: StorageURLResolver? {
        get { self[StorageURLResolverKey.self] }
        set { self[StorageURLResolverKey.self] = newValue }
    }
}

/// Downloads, downsamples and caches storage images.
///
/// - Images are decoded off the main thread straight to the pixel size they are drawn at (ImageIO thumbnails, EXIF
///   orientation applied), so scrolling never decodes full-size photos.
/// - Decoded images live in a memory cache keyed by storage path and pixel size; a view that re-appears (lazy lists)
///   draws from it synchronously, without a placeholder frame.
/// - Concurrent requests for the same image share one download; the HTTP layer (`URLCache`) keeps the bytes while a
///   signed URL is reused (AppData's `SignedURLCache` hands out the same URL for up to an hour).
final class ImagePipeline: @unchecked Sendable {
    static let shared = ImagePipeline()

    private let cache = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]
    /// The pixel buckets decoded per path (NSCache cannot list its keys), for `largestCachedImage(path:)`.
    private var buckets: [String: Set<Int>] = [:]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Pixel sizes are rounded up to a multiple of this, so neighbouring frame sizes share one decoded image.
    private static let bucket = 64

    static func pixelBucket(_ pixels: Int) -> Int {
        max(bucket, ((pixels + bucket - 1) / bucket) * bucket)
    }

    private static func key(_ path: String, _ pixels: Int) -> String {
        path + "#" + String(pixelBucket(pixels))
    }

    /// The decoded image if it is in memory (synchronous: safe to call from `body`).
    func cachedImage(path: String, pixels: Int) -> UIImage? {
        cache.object(forKey: Self.key(path, pixels) as NSString)
    }

    /// The largest decoded image of `path` still in memory, at any pixel size (nil when none): a picture of it already on
    /// the device, without a download (the share sheet's group images, ShareTargetDonations).
    func largestCachedImage(path: String) -> UIImage? {
        let sizes = lock.withLock { buckets[path] ?? [] }
        for size in sizes.sorted(by: >) {
            if let image = cache.object(forKey: Self.key(path, size) as NSString) { return image }
        }
        return nil
    }

    /// Keeps an image decoded elsewhere (send-to's group covers) in the memory cache, under its path and pixel size.
    func insert(_ image: UIImage, path: String, pixels: Int) {
        store(image, key: Self.key(path, pixels), path: path, pixels: pixels)
    }

    private func store(_ image: UIImage, key: String, path: String, pixels: Int) {
        cache.setObject(image, forKey: key as NSString)
        lock.withLock { buckets[path, default: []].insert(Self.pixelBucket(pixels)) }
    }

    /// Loads (or joins the load of) the image at `url`, decoded to at most `pixels` on its longer side.
    func image(path: String, url: URL, pixels: Int) async -> UIImage? {
        let key = Self.key(path, pixels)
        if let image = cache.object(forKey: key as NSString) { return image }
        let session = self.session
        let size = Self.pixelBucket(pixels)
        let task: Task<UIImage?, Never> = lock.withLock {
            if let existing = inFlight[key] { return existing }
            let task = Task.detached(priority: .userInitiated) { () -> UIImage? in
                guard let (data, _) = try? await session.data(from: url) else { return nil }
                return Self.decode(data, maxPixelSize: size)
            }
            inFlight[key] = task
            return task
        }
        let image = await task.value
        lock.withLock { inFlight[key] = nil }
        if let image { store(image, key: key, path: path, pixels: pixels) }
        return image
    }

    /// Warms the cache for images about to scroll into view (next feed page).
    func prefetch(_ items: [(path: String, url: URL)], pixels: Int) {
        for item in items {
            Task.detached(priority: .utility) { [self] in
                _ = await image(path: item.path, url: item.url, pixels: pixels)
            }
        }
    }

    func removeAll() {
        cache.removeAllObjects()
        lock.withLock { buckets = [:] }
    }

    /// ImageIO thumbnail decode: downsampled, orientation applied, decoded immediately.
    static func decode(_ data: Data, maxPixelSize: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}

/// An image from the private bucket filling the frame its caller gives it (`contentMode`), with `placeholder` until
/// it has loaded (and when the path is nil or unreadable). The frame never changes when the image arrives (callers
/// reserve it from tokens), and a cached image is drawn on the first frame.
struct StorageImage<Placeholder: View>: View {
    let path: String?
    var contentMode: ContentMode = .fill
    @ViewBuilder var placeholder: () -> Placeholder

    @Environment(\.storageURLResolver) private var resolver
    @Environment(\.displayScale) private var displayScale
    @State private var loaded: (key: String, image: UIImage)?

    init(path: String?, contentMode: ContentMode = .fill, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.path = path
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        GeometryReader { proxy in
            let pixels = Int((max(proxy.size.width, proxy.size.height) * displayScale).rounded(.up))
            let key = (path ?? "") + "#" + String(pixels)
            Group {
                if let image = image(for: key, pixels: pixels) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    placeholder()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .task(id: key) { await load(key: key, pixels: pixels) }
        }
    }

    private func image(for key: String, pixels: Int) -> UIImage? {
        if let loaded, loaded.key == key { return loaded.image }
        guard let path, pixels > 0 else { return nil }
        return ImagePipeline.shared.cachedImage(path: path, pixels: pixels)
    }

    private func load(key: String, pixels: Int) async {
        guard let path, pixels > 0, let resolver else { return }
        if let cached = ImagePipeline.shared.cachedImage(path: path, pixels: pixels) {
            loaded = (key, cached)
            return
        }
        guard let url = try? await resolver(path),
              let image = await ImagePipeline.shared.image(path: path, url: url, pixels: pixels) else { return }
        loaded = (key, image)
    }
}

/// An image at a plain URL (e.g. the invite web service's re-encoded cover and avatars), through the same downsampling
/// cache as `StorageImage`, filling the frame its caller gives it.
struct URLImage<Placeholder: View>: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    @ViewBuilder var placeholder: () -> Placeholder

    @Environment(\.displayScale) private var displayScale
    @State private var loaded: (key: String, image: UIImage)?

    init(url: URL?, contentMode: ContentMode = .fill, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        GeometryReader { proxy in
            let pixels = Int((max(proxy.size.width, proxy.size.height) * displayScale).rounded(.up))
            let key = (url?.absoluteString ?? "") + "#" + String(pixels)
            Group {
                if let image = image(for: key, pixels: pixels) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    placeholder()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .task(id: key) {
                guard let url, pixels > 0,
                      let image = await ImagePipeline.shared.image(path: url.absoluteString, url: url, pixels: pixels) else { return }
                loaded = (key, image)
            }
        }
    }

    private func image(for key: String, pixels: Int) -> UIImage? {
        if let loaded, loaded.key == key { return loaded.image }
        guard let url, pixels > 0 else { return nil }
        return ImagePipeline.shared.cachedImage(path: url.absoluteString, pixels: pixels)
    }
}

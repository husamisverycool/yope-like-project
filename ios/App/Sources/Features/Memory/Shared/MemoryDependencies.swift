// Where the memory screens get their data, images, clock and haptics from.
// The app uses AppData (AppEnvironment.shared.data); DEBUG builds launched with the argument
// `-MemoryFixtures` (AppUITests/Memory, `MemoryLaunch`) use `FixtureMemoryData.uiTest` instead.
import AppData
import DesignSystem
import Foundation
import SwiftUI
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

    init(
        data: (any MemoryDataSource)?,
        images: any MemoryImageLoading,
        now: @escaping @Sendable () -> Date = { Date() },
        haptics: @escaping @MainActor (DSHaptic) -> Void = { $0.play() },
        defaults: UserDefaults = .standard,
        openGroup: @escaping @MainActor (String) -> Void = { AppEnvironment.shared.router.path = [.group(id: $0)] }
    ) {
        self.data = data
        self.images = images
        self.now = now
        self.haptics = haptics
        self.defaults = defaults
        self.openGroup = openGroup
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

/// Loads and caches images by (signed) URL. `cachedImage` is read synchronously while rendering,
/// so snapshot tests and the year-story share renderer see images that were loaded before.
@MainActor
protocol MemoryImageLoading: AnyObject, Sendable {
    func cachedImage(for url: URL) -> UIImage?
    func image(for url: URL) async -> UIImage?
}

@MainActor
final class MemoryImageLoader: MemoryImageLoading {
    static let shared = MemoryImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = cachedImage(for: url) { return cached }
        if let task = inFlight[url] { return await task.value }
        let task = Task<UIImage?, Never> {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
            return UIImage(data: data)
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        if let image { cache.setObject(image, forKey: url as NSURL) }
        return image
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

/// A photo from storage. Shows nothing until the image is there (the screen background shows
/// through; no placeholder colour is specified for these surfaces).
struct MemoryRemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    @Environment(\.memoryImageLoader) private var injected
    @State private var loaded: UIImage?

    var body: some View {
        let loader = injected ?? MemoryImageLoader.shared
        let image = loaded ?? url.flatMap { loader.cachedImage(for: $0) }
        // Takes exactly the proposed size; the photo fills or fits inside it.
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
                loaded = await loader.image(for: url)
            }
    }
}

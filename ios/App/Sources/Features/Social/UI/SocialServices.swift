// Social group — the services the social screens use: AppData (live), or the in-memory demo backend when
// the app is launched with `-SocialFakes` (DEBUG; UI tests), plus image loading through signed URLs.
import AppData
import AppModels
import AppServices
import DesignSystem
import ImageIO
import SwiftUI
import UIKit

@MainActor
final class SocialServices {
    let data: any SocialDataSource
    let images: SocialImageLoader
    let voiceLevels: SocialVoiceLevels
    let flags: SocialFlags
    let saver: any SocialPhotoSaving
    /// One voice message plays at a time across the social screens.
    let playback: SocialVoicePlayback

    init(
        data: any SocialDataSource,
        images: SocialImageLoader,
        voiceLevels: SocialVoiceLevels? = nil,
        flags: SocialFlags = SocialFlags(),
        saver: any SocialPhotoSaving = LibraryPhotoSaver()
    ) {
        self.data = data
        self.images = images
        self.voiceLevels = voiceLevels ?? SocialVoiceLevels(data: data)
        self.flags = flags
        self.saver = saver
        playback = SocialVoicePlayback(data: data)
    }

    /// The services every social screen reads (tests replace it).
    static var shared: SocialServices = resolve()

    static func resolve() -> SocialServices {
        #if DEBUG
        if SocialLaunch.usesFakes {
            let data = SocialDemo.makeData()
            return SocialServices(
                data: data, images: .demo(), voiceLevels: .demo(), flags: SocialFlags(defaults: SocialLaunch.defaults), saver: DemoPhotoSaver()
            )
        }
        #endif
        if let environment = AppEnvironment.shared.data {
            let data = LiveSocialData(environment: environment)
            return SocialServices(data: data, images: SocialImageLoader(data: data))
        }
        let data = UnconfiguredSocialData()
        return SocialServices(data: data, images: SocialImageLoader(data: data))
    }
}

/// A decoded image handed across actors (decoding happens off the main actor).
struct SocialDecodedImage: @unchecked Sendable {
    let image: UIImage
}

/// Loads private images by storage path: signed URL → download → downsampled decode off the main actor,
/// sized to the frame that shows it, cached in memory per path and size, one request per image in flight.
@MainActor
final class SocialImageLoader {
    private let cache = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<SocialDecodedImage?, Never>] = [:]
    private let data: (any SocialDataSource)?
    /// DEBUG demo images, drawn synchronously (snapshot tests, UI tests).
    private let renderer: ((String) -> UIImage?)?

    init(data: any SocialDataSource) {
        self.data = data
        renderer = nil
    }

    init(renderer: @escaping (String) -> UIImage?) {
        data = nil
        self.renderer = renderer
    }

    private static func key(_ path: String, _ maxPixel: Int?) -> String {
        path + "@" + String(maxPixel ?? 0)
    }

    /// The image already in memory for this path at (at least) this size.
    func cached(_ path: String, maxPixel: Int? = nil) -> UIImage? {
        if let image = cache.object(forKey: Self.key(path, maxPixel) as NSString) { return image }
        if maxPixel != nil, let full = cache.object(forKey: Self.key(path, nil) as NSString) { return full }
        if let renderer, let image = renderer(path) {
            cache.setObject(image, forKey: Self.key(path, maxPixel) as NSString)
            return image
        }
        return nil
    }

    /// Nil when the file cannot be read (deleted, blocked, offline). `maxPixel` downsamples to the frame
    /// (longest side in pixels); nil decodes the full image.
    func load(_ path: String, maxPixel: Int? = nil) async -> UIImage? {
        if let image = cached(path, maxPixel: maxPixel) { return image }
        guard let data else { return nil }
        let key = Self.key(path, maxPixel)
        if let task = inFlight[key] { return await task.value?.image }
        let task = Task<SocialDecodedImage?, Never> {
            guard let url = try? await data.fileURL(path: path),
                  let bytes = await Self.download(url) else { return nil }
            return await Self.decode(bytes, maxPixel: maxPixel)
        }
        inFlight[key] = task
        let image = await task.value?.image
        inFlight[key] = nil
        if let image { cache.setObject(image, forKey: key as NSString) }
        return image
    }

    /// Starts loading images that are about to show (next photos in the viewer, the next grid rows).
    func prefetch(_ paths: [String], maxPixel: Int? = nil) {
        for path in paths where cached(path, maxPixel: maxPixel) == nil {
            Task(priority: .utility) { _ = await self.load(path, maxPixel: maxPixel) }
        }
    }

    /// Downloads a file (signed URL) to memory.
    nonisolated static func download(_ url: URL) async -> Data? {
        guard let result = try? await URLSession.shared.data(from: url) else { return nil }
        if let http = result.1 as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
        return result.0
    }

    /// Decodes (and downsamples) with ImageIO on a background thread.
    nonisolated static func decode(_ bytes: Data, maxPixel: Int?) async -> SocialDecodedImage? {
        await Task.detached(priority: .userInitiated) { () -> SocialDecodedImage? in
            guard let source = CGImageSourceCreateWithData(bytes as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
                return nil
            }
            var options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
            ]
            if let maxPixel { options[kCGImageSourceThumbnailMaxPixelSize] = maxPixel }
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            return SocialDecodedImage(image: UIImage(cgImage: image))
        }.value
    }

    /// Drops every decoded image (after a deletion: deleted photos must not stay on the device).
    func forgetAll() {
        cache.removeAllObjects()
    }
}

/// Voice-message level envelopes (`chat.voice` waveform), computed once per file from its samples and kept.
@MainActor
final class SocialVoiceLevels {
    private var cache: [String: [Float]] = [:]
    private let data: (any SocialDataSource)?
    private let demo: ((String) -> [Float])?

    init(data: any SocialDataSource) {
        self.data = data
        demo = nil
    }

    init(demo: @escaping (String) -> [Float]) {
        data = nil
        self.demo = demo
    }

    func cached(_ key: String) -> [Float]? {
        if let levels = cache[key] { return levels }
        if let demo {
            let levels = demo(key)
            cache[key] = levels
            return levels
        }
        return nil
    }

    /// Levels of a remote voice file (storage path) or a local recording (file URL).
    func levels(path: String?, localFile: URL?) async -> [Float]? {
        let key = localFile?.absoluteString ?? path ?? ""
        if let levels = cached(key) { return levels }
        var fileURL = localFile
        if fileURL == nil, let path, let data, let url = try? await data.fileURL(path: path),
           let bytes = await SocialImageLoader.download(url) {
            fileURL = try? SocialVoiceFiles.write(bytes, name: key)
        }
        guard let fileURL, let levels = await VoiceEnvelope.levels(of: fileURL) else { return nil }
        cache[key] = levels
        return levels
    }
}

/// `photo.viewer` save: add-only photo library access (AppServices `PhotoLibraryService`,
/// `system.permissions.photosAdd.purpose`).
struct LibraryPhotoSaver: SocialPhotoSaving {
    func save(kind: MediaKind, fileURL: URL, motionURL: URL?) async throws {
        var status = PhotoLibraryService.addAuthorization()
        if status == .notDetermined { status = await PhotoLibraryService.requestAddAuthorization() }
        guard status.allowsAccess else { throw SocialSaveFailure.notAuthorized }
        guard let bytes = await SocialImageLoader.download(fileURL) else { throw DataError.offline }
        let library = PhotoLibraryService()
        do {
            switch kind {
            case .video:
                let local = try Self.writeTemporary(bytes, fileExtension: fileURL.pathExtension)
                defer { try? FileManager.default.removeItem(at: local) }
                try await library.saveVideo(at: local)
            case .livePhoto:
                if let motionURL, let movie = await SocialImageLoader.download(motionURL) {
                    let local = try Self.writeTemporary(movie, fileExtension: motionURL.pathExtension)
                    defer { try? FileManager.default.removeItem(at: local) }
                    try await library.saveLivePhoto(imageData: bytes, movieURL: local)
                } else {
                    try await library.saveImage(bytes)
                }
            default:
                try await library.saveImage(bytes)
            }
        } catch let error as PhotoLibraryService.LibraryError {
            if case .notAuthorized = error { throw SocialSaveFailure.notAuthorized }
            throw error
        }
    }

    private static func writeTemporary(_ bytes: Data, fileExtension: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        try bytes.write(to: url)
        return url
    }
}

#if DEBUG
/// Launch arguments of the social UI tests (ios/AppUITests/Social).
enum SocialLaunch {
    /// `-SocialFakes`: every social screen runs on `SocialDemo`'s in-memory backend.
    static var usesFakes: Bool { ProcessInfo.processInfo.arguments.contains("-SocialFakes") }

    /// A defaults suite emptied at launch, so first-use flags start fresh in each UI-test run.
    @MainActor static let defaults: UserDefaults = {
        let name = "social.uitests"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }()

    /// `-SocialOpen <screen>`: the screen the UI test starts on (chat, viewer, wallMine, recap, history, albums).
    static var openArgument: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-SocialOpen"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    /// Opens the screen named by `-SocialOpen` on the demo group once the person is home (`router.isReady`).
    /// Call once after launch (AppEnvironment `didFinishLaunching`, DEBUG) — see the social pass report.
    @MainActor
    static func apply(to router: AppRouter) {
        guard usesFakes, let screen = openArgument else { return }
        Task { @MainActor in
            while !router.isReady {
                try? await Task.sleep(for: .milliseconds(50)) // provenance-ok: UI-test launch polling, not motion
            }
            router.path = routes(for: screen)
        }
    }

    static func routes(for screen: String) -> [AppRoute] {
        let group = SocialDemo.groupID.rawValue
        switch screen {
        case "chat": return [.group(id: group), .chat(groupID: group, messageID: nil)]
        case "viewer": return [.group(id: group), .post(groupID: group, postID: SocialDemo.p2.rawValue)]
        case "wallMine": return [.social(.wallMine)]
        case "walls": return [.social(.wallsBrowse(groupID: nil))]
        case "recap": return [.group(id: group), .recap(groupID: group, recapID: SocialDemo.recapID.rawValue)]
        case "history": return [.group(id: group), .social(.weekHistory(groupID: group))]
        case "albums": return [.group(id: group), .social(.albums(groupID: group))]
        default: return []
        }
    }
}

/// Demo images: one flat colour per path from the token palette, drawn at the photos' 3:4 shape.
extension SocialImageLoader {
    static func demo() -> SocialImageLoader {
        SocialImageLoader { path in
            let palette: [Color] = [
                Tokens.Colors.globalAccent, Tokens.Colors.globalSelection, Tokens.Colors.globalAccentSecondary,
                Tokens.Colors.globalControlRaised, Tokens.Colors.chatVoiceColorWaveform, Tokens.Colors.groupsCreateColorCover,
            ]
            let index = path.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF } % palette.count
            let color = UIColor(palette[index])
            let size = CGSize(width: Tokens.Sizes.weekHistoryDimensionTileWidth, height: Tokens.Sizes.weekHistoryDimensionTileHeight)
            return UIGraphicsImageRenderer(size: size).image { context in
                color.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
        }
    }
}

extension SocialVoiceLevels {
    /// Demo envelopes: a fixed pattern per path (sample data for snapshots and UI tests, not a design value).
    static func demo() -> SocialVoiceLevels {
        SocialVoiceLevels { key in
            let seed = key.unicodeScalars.reduce(UInt32(7)) { ($0 &* 31) &+ $1.value }
            return (0..<64).map { index in
                let mixed = (seed &+ UInt32(index) &* 2_654_435_761) >> 24
                return Float(mixed) / Float(UInt8.max)
            }
        }
    }
}

/// Saves nothing; succeeds (UI tests never touch the real library).
struct DemoPhotoSaver: SocialPhotoSaving {
    func save(kind: MediaKind, fileURL: URL, motionURL: URL?) async throws {}
}
#endif

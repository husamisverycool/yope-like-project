// Social group — the services the social screens use: AppData (live), or the in-memory demo backend when
// the app is launched with `-SocialFakes` (DEBUG; UI tests), plus image loading through signed URLs.
import AppData
import AppModels
import AppServices
import DesignSystem
import SwiftUI
import UIKit

@MainActor
final class SocialServices {
    let data: any SocialDataSource
    let images: SocialImageLoader
    let flags: SocialFlags
    let saver: any SocialPhotoSaving

    init(data: any SocialDataSource, images: SocialImageLoader, flags: SocialFlags = SocialFlags(), saver: any SocialPhotoSaving = LibraryPhotoSaver()) {
        self.data = data
        self.images = images
        self.flags = flags
        self.saver = saver
    }

    /// The services every social screen reads (tests replace it).
    static var shared: SocialServices = resolve()

    static func resolve() -> SocialServices {
        #if DEBUG
        if SocialLaunch.usesFakes {
            let data = SocialDemo.makeData()
            return SocialServices(data: data, images: .demo(), flags: SocialFlags(defaults: SocialLaunch.defaults), saver: DemoPhotoSaver())
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

/// Loads private images by storage path (signed URL → download → decode), cached in memory per path.
@MainActor
final class SocialImageLoader {
    private let cache = NSCache<NSString, UIImage>()
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

    func cached(_ path: String) -> UIImage? {
        if let image = cache.object(forKey: path as NSString) { return image }
        if let renderer, let image = renderer(path) {
            cache.setObject(image, forKey: path as NSString)
            return image
        }
        return nil
    }

    /// Nil when the file cannot be read (deleted, blocked, offline).
    func load(_ path: String) async -> UIImage? {
        if let image = cached(path) { return image }
        guard let data else { return nil }
        guard let url = try? await data.fileURL(path: path),
              let bytes = await Self.download(url),
              let image = UIImage(data: bytes) else { return nil }
        cache.setObject(image, forKey: path as NSString)
        return image
    }

    /// Downloads a file (signed URL) to memory.
    nonisolated static func download(_ url: URL) async -> Data? {
        guard let result = try? await URLSession.shared.data(from: url) else { return nil }
        if let http = result.1 as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
        return result.0
    }

    /// Forgets a deleted photo's images.
    func forget(_ path: String) {
        cache.removeObject(forKey: path as NSString)
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
    static let defaults: UserDefaults = {
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

    /// Opens the screen named by `-SocialOpen` on the demo group. Call once after launch (AppEnvironment
    /// `didFinishLaunching`, DEBUG) — see the social pass report.
    @MainActor
    static func apply(to router: AppRouter) {
        guard usesFakes, let screen = openArgument else { return }
        let group = SocialDemo.groupID.rawValue
        switch screen {
        case "chat": router.path = [.group(id: group), .chat(groupID: group, messageID: nil)]
        case "viewer": router.path = [.group(id: group), .post(groupID: group, postID: SocialDemo.p2.rawValue)]
        case "wallMine": router.path = [.social(.wallMine)]
        case "walls": router.path = [.social(.wallsBrowse)]
        case "recap": router.path = [.group(id: group), .recap(groupID: group, recapID: SocialDemo.recapID.rawValue)]
        case "history": router.path = [.group(id: group), .social(.weekHistory(groupID: group))]
        case "albums": router.path = [.group(id: group), .social(.albums(groupID: group))]
        default: break
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

/// Saves nothing; succeeds (UI tests never touch the real library).
struct DemoPhotoSaver: SocialPhotoSaving {
    func save(kind: MediaKind, fileURL: URL, motionURL: URL?) async throws {}
}
#endif

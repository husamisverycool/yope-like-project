// Surface: share.in — "Share to Jolt" from Photos and other apps (design/surfaces/share.in.md; docs/RESEARCH_FEATURES_
// 2026-10-17.md #4). Mechanics: Apple Shared Albums "Share → Add to Shared Album" (support.apple.com/108314). The Share
// Extension (ios/ShareExtension) copies the shared photos and videos into the App Group inbox (AppModels `ShareInbox`)
// and opens `<app scheme>://share`; the app opens the camera tab, whose model takes them as a library selection — the
// trimmer for long videos, then camera.sendto with the whole selection (several photos in one post). Signed out, the
// link waits in `AppRouter` until the person is home.
import AppData
import AppModels
import Foundation
import Observation

/// Each share that reached the app (the link, or a foreground with items waiting) bumps `arrivals`; the camera screen
/// takes the inbox on appear and on every change.
@MainActor
@Observable
final class ShareInHandoff {
    static let shared = ShareInHandoff()

    private(set) var arrivals = 0

    func arrived() {
        arrivals += 1
    }
}

/// The inbox's items as `CapturedMedia`, with the day each was taken (`CaptureTakenOn`), in the order shared.
enum ShareInImport {
    /// At most `limit` items (`batch_max_photos`); the rest, and anything unreadable, is deleted. Photos are read into
    /// memory as library picks are; movies move into this app's temporary folder (removed once posted or discarded).
    @MainActor
    static func take(limit: Int, inbox: ShareInbox = ShareInbox.forBundle(.main)) async -> [CapturedMedia] {
        guard inbox.hasItems else { return [] }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let files = inbox.take(into: folder)
        var media: [CapturedMedia] = []
        for (index, file) in files.enumerated() {
            guard index < max(1, limit) else {
                try? FileManager.default.removeItem(at: file.url)
                continue
            }
            switch file.kind {
            case .image:
                let data = try? Data(contentsOf: file.url)
                try? FileManager.default.removeItem(at: file.url)
                if let data, let photo = CaptureLibraryImport.photo(data) { media.append(photo) }
            case .movie:
                media.append(await CaptureLibraryImport.video(at: file.url))
            }
        }
        return media
    }
}

/// `public_app_config.batch_max_photos` for the library picker and share.in: read once when first needed and kept for the
/// app session; nil while the server has not answered (offline, signed out, not configured).
@MainActor
final class CaptureBatchLimit {
    private let data: DataEnvironment?
    private var cached: Int?

    init(data: DataEnvironment?) {
        self.data = data
    }

    func value() async -> Int? {
        if let cached { return cached }
        guard let data, let limit = try? await data.account.publicConfig().batchMaxPhotos, limit > 0 else { return nil }
        cached = limit
        return limit
    }
}

// The Jolt demo's photos: the sample photos (fixtures/photos, Unsplash licence, fixtures/photos/LICENSE.md), copied
// into the demo build's bundle by CI ("ios demo build": ios/App/Resources/DemoPhotos). Every storage path of the demo
// world names one: posts, avatars and covers of the social demo (`fake/photo|avatar|cover/<nn>`, the same choices as
// the snapshot tests' `SocialSamplePhotos`), the memory scenario's posts (`u/<author>/<media>/…`), its collage and its
// tribute poster. Other builds have no bundled photos and keep their generated stand-ins.
#if DEBUG
import ImageIO
import UIKit

enum DemoPhotos {
    /// Social demo posts by media suffix (p1–p6), matching what the demo chat and captions say.
    static let posts: [String: String] = [
        "01": "dinner-pizza-cheers-3x4", // Ben, after "who's cooking tonight?" / "i can do pasta"
        "02": "snow-forest-walk-3x4", // Ana: "first snow"
        "03": "hike-meadow-trail-3x4", // Sam, also sent to "climbing"
        "04": "dog-beach-run-3x4", // Cleo's Live Photo
        "05": "autumn-path-3x4", // Ana, last week
        "06": "picnic-spread-3x4", // Sam, last week: "picnic"
    ]

    /// People by user-id suffix: Sam Reed (me), Ana Lima, Ben Ortiz, Cleo Park, the stranger.
    static let people: [String: String] = ["01": "avatar-02", "02": "avatar-01", "03": "avatar-06", "04": "avatar-05", "09": "avatar-07"]

    /// Group covers by group-id suffix: "roommates", "climbing".
    static let covers: [String: String] = ["01": "movie-night-couch-4x3", "02": "hike-mountain-friends-3x4"]

    /// The memory scenario's posts by media number (`MemoryFixtureIDs.media`): this month, then 1 and 3 years ago.
    static let memoryPosts: [String: String] = [
        "01": "coffee-latte-heart-3x4", "02": "food-plates-4x3", "03": "city-night-street-3x4",
        "04": "succulents-1x1", "05": "concert-confetti-3x4", "06": "campfire-woods-3x4",
        "07": "beach-friends-run-4x3", "08": "friends-stairs-laughing-3x4", "09": "sunset-lake-9x16",
    ]

    /// The memory scenario's collage and birthday tribute poster.
    static let collage = "friends-picnic-blanket-3x4"
    static let tributePoster = "birthday-cake-candles-3x4"

    /// The camera's view and what its shutter takes (back and front camera).
    static let viewfinder = "plants-shelf-3x4"
    static let backShot = "friends-floor-laughing-3x4"
    static let frontShot = "selfie-two-friends-1x1"

    /// The bundled photo `name`, when this build has the demo photos.
    static func url(named name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "jpg")
    }

    /// The photo a storage path of the demo world names.
    static func name(for path: String) -> String? {
        let parts = path.split(separator: "/").map(String.init)
        if parts.count == 3, parts[0] == "fake" {
            let key = String(parts[2].prefix(2))
            switch parts[1] {
            case "photo": return parts[2].hasSuffix(".mov") ? nil : posts[key]
            case "avatar": return people[key]
            case "cover": return covers[key]
            default: return nil
            }
        }
        if parts.first == "u", parts.count >= 3 {
            return memoryPosts[String(parts[2].suffix(2))]
        }
        if parts.first == "g", parts.count >= 3 {
            switch parts[2] {
            case "collages": return collage
            case "tributes": return path.hasSuffix(".jpg") ? tributePoster : nil
            default: return nil
            }
        }
        return nil
    }

    /// The file for a storage path of the demo world: a bundled photo, or one sent from the demo camera.
    static func url(for path: String) -> URL? {
        sentURL(for: path) ?? name(for: path).flatMap(url(named:))
    }

    /// The photo for a storage path, decoded at most `maxPixels` on its long side (cached).
    static func image(for path: String, maxPixels: Int = 1440) -> UIImage? { // provenance-ok: decode size of demo photos, not a design value
        if let sent = sentURL(for: path) { return image(at: sent, key: path, maxPixels: maxPixels) }
        guard let name = name(for: path) else { return nil }
        return image(named: name, maxPixels: maxPixels)
    }

    static func image(named name: String, maxPixels: Int = 1440) -> UIImage? { // provenance-ok: decode size of demo photos, not a design value
        guard let url = url(named: name) else { return nil }
        return image(at: url, key: name, maxPixels: maxPixels)
    }

    // MARK: Photos sent from the demo camera

    /// Storage paths of photos sent from the demo camera (`DemoSentPosts`).
    static let sentPrefix = "demo/sent/" // provenance-ok: demo storage path

    private static var sentFolder: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("jolt-demo-sent", isDirectory: true) // provenance-ok: demo folder
    }

    /// Keeps a copy of a sent photo for the session (the draft's own file is temporary); returns where.
    static func keepSent(_ file: URL, path: String) -> URL? {
        let target = sentFolder.appendingPathComponent(String(path.dropFirst(sentPrefix.count)) + ".jpg")
        let files = FileManager.default
        try? files.createDirectory(at: sentFolder, withIntermediateDirectories: true)
        try? files.removeItem(at: target)
        do { try files.copyItem(at: file, to: target) } catch { return nil }
        return target
    }

    private static func sentURL(for path: String) -> URL? {
        guard path.hasPrefix(sentPrefix) else { return nil }
        let url = sentFolder.appendingPathComponent(String(path.dropFirst(sentPrefix.count)) + ".jpg")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private static func image(at url: URL, key name: String, maxPixels: Int) -> UIImage? {
        let key = "\(name)#\(maxPixels)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: key)
        return image
    }

    /// JPEG bytes of a bundled photo (what the demo camera "takes").
    static func jpeg(named name: String) -> (data: Data, width: Int, height: Int)? {
        guard let image = image(named: name), let data = image.jpegData(compressionQuality: 0.9), let cgImage = image.cgImage else { return nil } // provenance-ok: JPEG quality of the demo shot, not a design value
        return (data, cgImage.width, cgImage.height)
    }

    nonisolated(unsafe) private static let cache = NSCache<NSString, UIImage>()
}
#endif

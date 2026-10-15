import Foundation

/// Object paths in the `media` bucket (docs/API.md §7). Clients write only under `u/<uid>/`
/// and `avatars/<uid>/`, never overwrite, and use lowercase ids (the RLS checks compare
/// against Postgres' lowercase uuid text).
public enum StoragePaths {
    /// `u/<uid>/<media_id>/original.<ext>` — the main image, or the video file.
    public static func original(owner: UserID, media: MediaID, fileExtension: String) -> String {
        "u/\(owner.rawValue)/\(media.rawValue)/original.\(fileExtension.lowercased())"
    }

    /// `u/<uid>/<media_id>/front.jpg` — front image of a dual capture.
    public static func front(owner: UserID, media: MediaID) -> String {
        "u/\(owner.rawValue)/\(media.rawValue)/front.jpg"
    }

    /// `u/<uid>/<media_id>/motion.mov` — Live Photo video.
    public static func motion(owner: UserID, media: MediaID) -> String {
        "u/\(owner.rawValue)/\(media.rawValue)/motion.mov"
    }

    /// `u/<uid>/<media_id>/voice.m4a` — a post's voice note.
    public static func postVoice(owner: UserID, media: MediaID) -> String {
        "u/\(owner.rawValue)/\(media.rawValue)/voice.m4a"
    }

    /// `u/<uid>/voice/<uuid>.m4a` — a chat voice message.
    public static func chatVoice(owner: UserID, id: UUID = UUID()) -> String {
        "u/\(owner.rawValue)/voice/\(id.uuidString.lowercased()).m4a"
    }

    /// `u/<uid>/covers/<uuid>.jpg` — a group cover (passed to `create_group` / `update_group`).
    public static func cover(owner: UserID, id: UUID = UUID()) -> String {
        "u/\(owner.rawValue)/covers/\(id.uuidString.lowercased()).jpg"
    }

    /// `avatars/<uid>/<uuid>.jpg`
    public static func avatar(owner: UserID, id: UUID = UUID()) -> String {
        "avatars/\(owner.rawValue)/\(id.uuidString.lowercased()).jpg"
    }

    /// Letters, digits, `_ . / -`; no `..`, no empty segments (the server's `is_safe_path`).
    public static func isSafe(_ path: String) -> Bool {
        guard !path.isEmpty, !path.contains(".."), !path.hasPrefix("/"), !path.hasSuffix("/"), !path.contains("//") else {
            return false
        }
        return path.utf8.allSatisfy { byte in
            (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A)
                || byte == 0x5F || byte == 0x2E || byte == 0x2F || byte == 0x2D
        }
    }
}

/// The `contentType` set on every upload (one of the bucket's allowed types, docs/API.md §7).
public enum ContentType {
    public static let jpeg = "image/jpeg"
    public static let heic = "image/heic"
    public static let png = "image/png"
    public static let quickTime = "video/quicktime"
    public static let mp4 = "video/mp4"
    public static let m4a = "audio/mp4"

    /// The content type for a file extension; nil for types the bucket refuses.
    public static func forExtension(_ fileExtension: String) -> String? {
        switch fileExtension.lowercased() {
        case "jpg", "jpeg": return jpeg
        case "heic": return heic
        case "heif": return "image/heif"
        case "png": return png
        case "webp": return "image/webp"
        case "mov": return quickTime
        case "mp4": return mp4
        case "m4a": return m4a
        case "aac": return "audio/aac"
        case "mp3": return "audio/mpeg"
        default: return nil
        }
    }
}

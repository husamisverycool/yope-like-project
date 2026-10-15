import Foundation

/// What a screen's cached content is stored under. One file per key.
public struct CacheKey: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }

    /// The caller's groups (`[PhotoGroup]`).
    public static let groups = CacheKey("groups")
    /// First page of a group's feed (`[PostWithMedia]`).
    public static func feed(_ group: GroupID) -> CacheKey { CacheKey("feed.\(group.rawValue)") }
    /// First page of a group's chat (`[Message]`).
    public static func chat(_ group: GroupID) -> CacheKey { CacheKey("chat.\(group.rawValue)") }
    /// Members with profiles (`[MemberProfile]`).
    public static func members(_ group: GroupID) -> CacheKey { CacheKey("members.\(group.rawValue)") }
    /// History weeks (`[HistoryWeek]`).
    public static func history(_ group: GroupID) -> CacheKey { CacheKey("history.\(group.rawValue)") }
    /// Albums with items (`[AlbumWithItems]`).
    public static func albums(_ group: GroupID) -> CacheKey { CacheKey("albums.\(group.rawValue)") }
    /// First page of a person's wall as seen by the caller (`[WallItem]`).
    public static func wall(_ user: UserID) -> CacheKey { CacheKey("wall.\(user.rawValue)") }

    var groupID: GroupID? {
        for prefix in ["feed.", "chat.", "members.", "history.", "albums."] where rawValue.hasPrefix(prefix) {
            return GroupID(String(rawValue.dropFirst(prefix.count)))
        }
        return nil
    }

    var fileName: String {
        let safe = rawValue.unicodeScalars.map { scalar -> String in
            let ok = (scalar >= "a" && scalar <= "z") || (scalar >= "A" && scalar <= "Z") || (scalar >= "0" && scalar <= "9")
                || scalar == "." || scalar == "-" || scalar == "_"
            return ok ? String(scalar) : "_"
        }.joined()
        return safe + ".json"
    }
}

/// A cached value and when it was saved (screens show it with an offline / stale state).
public struct CachedValue<Value: Sendable>: Sendable {
    public var value: Value
    public var savedAt: Date

    public init(value: Value, savedAt: Date) {
        self.value = value
        self.savedAt = savedAt
    }
}

/// A small on-disk cache of the last loaded page per group and screen: Codable JSON files in
/// Application Support (excluded from backups), written atomically.
///
/// Deleted content must not survive here (security invariant 2): `purgePost` /
/// `purgeMessage` are applied when a deletion arrives on the `group:<id>` channel, leaving a
/// group drops its folder, and `removeAll()` runs on sign-out and account deletion.
public actor OfflineCache {
    public let directory: URL
    private let now: @Sendable () -> Date

    public init(directory: URL, now: @escaping @Sendable () -> Date = { Date() }) {
        self.directory = directory
        self.now = now
    }

    /// `Application Support/AppDataCache`.
    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("AppDataCache", isDirectory: true)
    }

    private struct Envelope<Value: Codable>: Codable {
        var savedAt: Date
        var value: Value
    }

    // MARK: Read / write

    public func write<Value: Codable & Sendable>(_ value: Value, for key: CacheKey) {
        do {
            let data = try DataCoding.makeEncoder().encode(Envelope(savedAt: now(), value: value))
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(key.fileName)
            #if canImport(Darwin)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            var excluded = url
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? excluded.setResourceValues(values)
            #else
            try data.write(to: url, options: [.atomic])
            #endif
        } catch {
            // A cache write failure only costs the offline copy.
        }
    }

    public func read<Value: Codable & Sendable>(_ type: Value.Type, for key: CacheKey) -> CachedValue<Value>? {
        let url = directory.appendingPathComponent(key.fileName)
        guard let data = try? Data(contentsOf: url),
              let envelope = try? DataCoding.makeDecoder().decode(Envelope<Value>.self, from: data) else { return nil }
        return CachedValue(value: envelope.value, savedAt: envelope.savedAt)
    }

    /// Rewrites a cached value in place (keeps its `savedAt`); no-op when nothing is cached.
    public func update<Value: Codable & Sendable>(_ type: Value.Type, for key: CacheKey, _ transform: (inout Value) -> Void) {
        guard var cached = read(type, for: key) else { return }
        transform(&cached.value)
        let saved = cached.savedAt
        do {
            let data = try DataCoding.makeEncoder().encode(Envelope(savedAt: saved, value: cached.value))
            try data.write(to: directory.appendingPathComponent(key.fileName), options: [.atomic])
        } catch {
            remove(key)
        }
    }

    public func remove(_ key: CacheKey) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(key.fileName))
    }

    /// Everything cached about one group (left / removed / deleted group).
    public func removeGroup(_ group: GroupID) {
        for key in keys() where key.groupID == group {
            remove(key)
        }
        update([PhotoGroup].self, for: .groups) { $0.removeAll { $0.id == group } }
    }

    /// Sign-out and account deletion.
    public func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    func keys() -> [CacheKey] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.filter { $0.hasSuffix(".json") }.map { CacheKey(String($0.dropLast(5))) }
    }

    // MARK: Deletions

    /// Removes a deleted post from cached feeds, chats (its photo message), walls, history weeks
    /// and albums. Only that post: the same photo may still be posted in other groups (each
    /// group's deletion arrives as its own `post_deleted`).
    public func purgePost(_ post: PostID) {
        for key in keys() {
            if key.rawValue.hasPrefix("feed.") {
                update([PostWithMedia].self, for: key) { $0.removeAll { $0.post.id == post } }
            } else if key.rawValue.hasPrefix("chat.") {
                update([Message].self, for: key) { $0.removeAll { $0.postID == post } }
            } else if key.rawValue.hasPrefix("wall.") {
                update([WallItem].self, for: key) { $0.removeAll { $0.postID == post } }
            } else if key.rawValue.hasPrefix("history.") {
                update([HistoryWeek].self, for: key) { weeks in
                    for index in weeks.indices { weeks[index].postIDs.removeAll { $0 == post } }
                    weeks.removeAll { $0.postIDs.isEmpty }
                }
            } else if key.rawValue.hasPrefix("albums.") {
                update([AlbumWithItems].self, for: key) { albums in
                    for index in albums.indices { albums[index].postIDs.removeAll { $0 == post } }
                }
            }
        }
    }

    public func purgeMessage(_ message: MessageID, groupID: GroupID) {
        update([Message].self, for: .chat(groupID)) { $0.removeAll { $0.id == message } }
    }
}

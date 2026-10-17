import Foundation
import Supabase

/// Where the Supabase session (access + refresh token) is persisted.
public enum SessionStorage {
    /// The Keychain on Apple platforms (`KeychainLocalStorage`; pass the shared access group to
    /// read the session from an extension), a file under Application Support elsewhere.
    public static func platformDefault(service: String = "app.session", accessGroup: String? = nil) -> any AuthLocalStorage {
        #if canImport(Security) && !os(Linux)
        return KeychainLocalStorage(service: service, accessGroup: accessGroup)
        #else
        return File(directory: defaultDirectory())
        #endif
    }

    /// The full app's session storage when an App Clip may have signed the person in first (directive Part 6: "After
    /// install, the link drops them straight into the group"; Apple, "Sharing data between your App Clip and your full
    /// app": "Starting with iOS 15.4, information that the App Clip stores in the keychain is accessible to its
    /// corresponding full app"). The app's own Keychain item comes first; when it has none, the App Clip's (its access
    /// group, `<team>.<bundle id>.Clip`) is moved over once per key, so the app opens signed in. Nil `clipAccessGroup`
    /// (unsigned builds, the App Clip itself): the platform default alone.
    public static func appSession(clipAccessGroup: String?, service: String = "app.session") -> any AuthLocalStorage {
        let primary = platformDefault(service: service)
        guard let clipAccessGroup, !clipAccessGroup.isEmpty else { return primary }
        return Migrating(
            primary: primary,
            legacy: platformDefault(service: service, accessGroup: clipAccessGroup),
            record: MigrationRecord(defaults: .standard)
        )
    }

    /// Which keys have been looked up in the legacy storage (`Migrating`), so a session signed out in the app never comes
    /// back from the App Clip's copy.
    public final class MigrationRecord: @unchecked Sendable {
        private let defaults: UserDefaults
        private let key = "session.appClipHandoff.checkedKeys"
        private let lock = NSLock()

        public init(defaults: UserDefaults) {
            self.defaults = defaults
        }

        func wasChecked(_ storageKey: String) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return (defaults.stringArray(forKey: key) ?? []).contains(storageKey)
        }

        func markChecked(_ storageKey: String) {
            lock.lock()
            defer { lock.unlock() }
            var keys = defaults.stringArray(forKey: key) ?? []
            guard !keys.contains(storageKey) else { return }
            keys.append(storageKey)
            defaults.set(keys, forKey: key)
        }
    }

    /// `primary` first; a key `primary` lacks is read once from `legacy`, copied into `primary` and removed from `legacy`
    /// (best effort). Removing a key removes it from both, so a sign-out is never undone by the legacy copy.
    public struct Migrating: AuthLocalStorage {
        public let primary: any AuthLocalStorage
        public let legacy: any AuthLocalStorage
        public let record: MigrationRecord

        public init(primary: any AuthLocalStorage, legacy: any AuthLocalStorage, record: MigrationRecord) {
            self.primary = primary
            self.legacy = legacy
            self.record = record
        }

        public func store(key: String, value: Data) throws {
            try primary.store(key: key, value: value)
            record.markChecked(key)
        }

        public func retrieve(key: String) throws -> Data? {
            if let value = try primary.retrieve(key: key) { return value }
            guard !record.wasChecked(key) else { return nil }
            record.markChecked(key)
            // A Keychain group this build may not read (errSecMissingEntitlement) counts as empty.
            guard let value = (try? legacy.retrieve(key: key)) ?? nil else { return nil }
            // The clip's copy goes only once the app holds its own.
            if (try? primary.store(key: key, value: value)) != nil {
                try? legacy.remove(key: key)
            }
            return value
        }

        public func remove(key: String) throws {
            try primary.remove(key: key)
            try? legacy.remove(key: key)
            record.markChecked(key)
        }
    }

    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("AppDataSession", isDirectory: true)
    }

    /// One file per key, written atomically (Linux and tests; never used on Apple platforms by default).
    public struct File: AuthLocalStorage {
        public let directory: URL

        public init(directory: URL) {
            self.directory = directory
        }

        public func store(key: String, value: Data) throws {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try value.write(to: url(key), options: [.atomic])
        }

        public func retrieve(key: String) throws -> Data? {
            let url = url(key)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return try Data(contentsOf: url)
        }

        public func remove(key: String) throws {
            let url = url(key)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }

        private func url(_ key: String) -> URL {
            let safe = String(key.unicodeScalars.map { scalar -> Character in
                let allowed = CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_" || scalar == "."
                return allowed ? Character(scalar) : "_"
            })
            return directory.appendingPathComponent(safe + ".json")
        }
    }

    /// Process-lifetime storage (external-token mode, tests).
    public final class InMemory: AuthLocalStorage, @unchecked Sendable {
        private let lock = NSLock()
        private var values: [String: Data] = [:]

        public init() {}

        public func store(key: String, value: Data) throws {
            lock.lock()
            defer { lock.unlock() }
            values[key] = value
        }

        public func retrieve(key: String) throws -> Data? {
            lock.lock()
            defer { lock.unlock() }
            return values[key]
        }

        public func remove(key: String) throws {
            lock.lock()
            defer { lock.unlock() }
            values[key] = nil
        }
    }
}

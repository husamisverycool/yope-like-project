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

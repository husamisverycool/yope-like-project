import Foundation
import Supabase

/// Short-lived signed URLs for the private bucket (docs/API.md §1, §7), reused until shortly
/// before they expire. Concurrent requests for the same path share one network call.
public actor SignedURLCache {
    /// 1 h, the lifetime docs/API.md §7 sets for the app and widgets.
    public static let defaultLifetime = 3600

    public let client: DataClient
    public let lifetime: Int
    /// A URL is not handed out when it expires within this margin (an image load may take a while).
    public let renewalMargin: TimeInterval
    private let now: @Sendable () -> Date

    private struct Entry {
        var url: URL
        var expiresAt: Date
    }

    private var entries: [String: Entry] = [:]
    private var inFlight: [String: Task<URL, Error>] = [:]

    public init(
        client: DataClient,
        lifetime: Int = SignedURLCache.defaultLifetime,
        renewalMargin: TimeInterval = 300,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.lifetime = lifetime
        self.renewalMargin = min(renewalMargin, TimeInterval(lifetime) / 2)
        self.now = now
    }

    /// A signed URL for `path`. Throws `.storage(.notFound)` / `.storage(.unauthorized)` when the
    /// caller may not read it (not a member, blocked, deleted).
    public func url(for path: String) async throws -> URL {
        if let entry = entries[path], entry.expiresAt.timeIntervalSince(now()) > renewalMargin {
            return entry.url
        }
        if let task = inFlight[path] {
            return try await task.value
        }
        let client = self.client
        let lifetime = self.lifetime
        let task = Task<URL, Error> {
            try await mapErrors {
                try await client.supabase.storage.from(client.configuration.bucket)
                    .createSignedURL(path: path, expiresIn: lifetime)
            }
        }
        inFlight[path] = task
        let requestedAt = now()
        defer { inFlight[path] = nil }
        let url = try await task.value
        entries[path] = Entry(url: url, expiresAt: requestedAt.addingTimeInterval(TimeInterval(lifetime)))
        return url
    }

    /// Signed URLs for several paths in one request. Paths the caller may not read are absent.
    public func urls(for paths: [String]) async throws -> [String: URL] {
        var result: [String: URL] = [:]
        var missing: [String] = []
        for path in Set(paths) {
            if let entry = entries[path], entry.expiresAt.timeIntervalSince(now()) > renewalMargin {
                result[path] = entry.url
            } else {
                missing.append(path)
            }
        }
        guard !missing.isEmpty else { return result }
        let requestedAt = now()
        let signed: [SignedURLResult]
        do {
            signed = try await client.supabase.storage.from(client.configuration.bucket)
                .createSignedURLs(paths: missing, expiresIn: lifetime)
        } catch {
            throw DataError.from(error)
        }
        for item in signed {
            if case let .success(path, url) = item {
                result[path] = url
                entries[path] = Entry(url: url, expiresAt: requestedAt.addingTimeInterval(TimeInterval(lifetime)))
            }
        }
        return result
    }

    /// Forgets URLs whose path starts with `prefix` (e.g. `u/<owner>/<media_id>/` after a deletion).
    public func invalidate(prefix: String) {
        entries = entries.filter { !$0.key.hasPrefix(prefix) }
    }

    /// Forgets URLs of one photo's objects (`u/<owner>/<media_id>/…`).
    public func invalidate(mediaID: MediaID) {
        let segment = "/\(mediaID.rawValue)/"
        entries = entries.filter { !$0.key.contains(segment) }
    }

    public func removeAll() {
        entries.removeAll()
    }
}

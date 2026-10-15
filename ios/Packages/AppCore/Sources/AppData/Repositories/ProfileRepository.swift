import Foundation
import Supabase

/// Profiles (docs/API.md §5.1, §5.2): yours and those of people you share a group with.
public struct ProfileRepository: Sendable {
    public let client: DataClient

    public init(client: DataClient) {
        self.client = client
    }

    public func myProfile() async throws -> Profile {
        let me = try await client.requireUserID()
        guard let profile = try await profile(id: me) else { throw DataError.api(.notAuthenticated) }
        return profile
    }

    /// Nil when the person shares no group with the caller (or does not exist).
    public func profile(id: UserID) async throws -> Profile? {
        try await client.firstRow(Profile.self) {
            client.supabase.from("profiles").select().eq("id", value: id.rawValue).limit(1)
        }
    }

    /// Readable profiles among `ids` (any order).
    public func profiles(ids: [UserID]) async throws -> [Profile] {
        let unique = Array(Set(ids))
        guard !unique.isEmpty else { return [] }
        var result: [Profile] = []
        // Keeps the query string short for large groups.
        for chunk in unique.chunked(into: 100) {
            result += try await client.rows(Profile.self) {
                client.supabase.from("profiles").select().in("id", values: chunk.map(\.rawValue))
            }
        }
        return result
    }

    /// Updates the caller's name and/or avatar (the only direct `profiles` write, §5.0).
    /// `avatarPath` must be an upload under `avatars/<uid>/` (`MediaUploader.uploadAvatar`).
    @discardableResult
    public func updateProfile(displayName: String? = nil, avatarPath: String? = nil) async throws -> Profile {
        let me = try await client.requireUserID()
        var values: JSONObject = [:]
        if let displayName { values["display_name"] = .string(displayName) }
        if let avatarPath { values["avatar_path"] = .string(avatarPath) }
        guard !values.isEmpty else { return try await myProfile() }
        let rows = try await client.rows(Profile.self) {
            try client.supabase.from("profiles").update(values).eq("id", value: me.rawValue).select()
        }
        guard let profile = rows.first else { throw DataError.api(.notAuthenticated) }
        return profile
    }

    /// Removes the avatar (the old object can be deleted by its owner, §7).
    @discardableResult
    public func removeAvatar() async throws -> Profile {
        let me = try await client.requireUserID()
        let previous = try await myProfile().avatarPath
        let rows = try await client.rows(Profile.self) {
            try client.supabase.from("profiles").update(["avatar_path": AnyJSON.null]).eq("id", value: me.rawValue).select()
        }
        if let previous {
            _ = try? await client.supabase.storage.from(client.configuration.bucket).remove(paths: [previous])
        }
        guard let profile = rows.first else { throw DataError.api(.notAuthenticated) }
        return profile
    }

    /// The caller's private row (birthday, opt-in, age confirmation).
    public func myPrivateProfile() async throws -> ProfilePrivate? {
        let me = try await client.requireUserID()
        return try await client.firstRow(ProfilePrivate.self) {
            client.supabase.from("profile_private").select().eq("user_id", value: me.rawValue).limit(1)
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, count > size else { return isEmpty ? [] : [self] }
        return stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

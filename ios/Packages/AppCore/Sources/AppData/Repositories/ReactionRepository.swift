import Foundation
import Supabase

/// Reactions and "I'm in this" self-tags (docs/API.md §5.10, §5.11, §6.2).
///
/// Reactions are rows `(user, emoji)`: show who reacted with what. This type never counts them
/// and never asks the server for a count (tenet: no counts).
public struct ReactionRepository: Sendable {
    public let client: DataClient

    public init(client: DataClient) {
        self.client = client
    }

    /// The post's reactions, oldest first.
    public func reactions(postID: PostID) async throws -> [Reaction] {
        try await client.rows(Reaction.self) {
            client.supabase.from("reactions").select()
                .eq("post_id", value: postID.rawValue)
                .order("created_at", ascending: true)
        }
    }

    /// Reactions of several posts (a feed page), oldest first.
    public func reactions(postIDs: [PostID]) async throws -> [Reaction] {
        let unique = Array(Set(postIDs))
        guard !unique.isEmpty else { return [] }
        var result: [Reaction] = []
        for chunk in unique.chunked(into: 100) {
            result += try await client.rows(Reaction.self) {
                client.supabase.from("reactions").select()
                    .in("post_id", values: chunk.map(\.rawValue))
                    .order("created_at", ascending: true)
            }
        }
        return result
    }

    /// `react`: any emoji; idempotent (returns the existing row). A person may react with several emoji.
    @discardableResult
    public func react(postID: PostID, emoji: String) async throws -> Reaction {
        try await client.rpc("react", ["p_post_id": .id(postID), "p_emoji": .string(emoji)])
    }

    /// `unreact`: removes only the caller's row.
    public func unreact(postID: PostID, emoji: String) async throws {
        try await client.rpcVoid("unreact", ["p_post_id": .id(postID), "p_emoji": .string(emoji)])
    }

    // MARK: Self-tags

    public func tags(postID: PostID) async throws -> [PostTag] {
        try await client.rows(PostTag.self) {
            client.supabase.from("post_tags").select()
                .eq("post_id", value: postID.rawValue)
                .order("created_at", ascending: true)
        }
    }

    /// Posts of a group the caller tagged themselves in (tribute eligibility).
    public func myTags(groupID: GroupID) async throws -> [PostTag] {
        let me = try await client.requireUserID()
        return try await client.rows(PostTag.self) {
            client.supabase.from("post_tags").select()
                .eq("group_id", value: groupID.rawValue)
                .eq("user_id", value: me.rawValue)
                .order("created_at", ascending: false)
        }
    }

    /// `tag_self`: only ever tags the caller. Idempotent.
    @discardableResult
    public func tagSelf(postID: PostID) async throws -> PostTag {
        try await client.rpc("tag_self", ["p_post_id": .id(postID)])
    }

    /// `untag_self`. Idempotent.
    public func untagSelf(postID: PostID) async throws {
        try await client.rpcVoid("untag_self", ["p_post_id": .id(postID)])
    }
}

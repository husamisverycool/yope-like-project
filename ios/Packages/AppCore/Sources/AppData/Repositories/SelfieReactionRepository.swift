import Foundation
import Supabase

/// Selfie reactions (docs/API.md §14.1; surface viewer.selfiereaction): one live selfie per person per post, shown as
/// faces on the photo. The image is uploaded first (`u/<uid>/selfies/<uuid>.jpg`), then `react_with_selfie` records
/// it; a new selfie replaces the person's (the server deletes the old file). The post's author cannot react to their
/// own post and may remove anyone's. Removals arrive as the `reactions_changed` broadcast. This type never counts
/// rows and never asks the server for a count (tenet: no counts).
public struct SelfieReactionRepository: Sendable {
    public let client: DataClient
    public let uploader: MediaUploader

    public init(client: DataClient, uploader: MediaUploader) {
        self.client = client
        self.uploader = uploader
    }

    /// The post's selfies, oldest first.
    public func selfies(postID: PostID) async throws -> [SelfieReaction] {
        try await client.rows(SelfieReaction.self) {
            client.supabase.from("selfie_reactions").select()
                .eq("post_id", value: postID.rawValue)
                .order("created_at", ascending: true)
        }
    }

    /// The selfies of several posts (a viewer's photos), oldest first.
    public func selfies(postIDs: [PostID]) async throws -> [SelfieReaction] {
        let unique = Array(Set(postIDs))
        guard !unique.isEmpty else { return [] }
        var result: [SelfieReaction] = []
        for chunk in unique.chunked(into: 100) {
            result += try await client.rows(SelfieReaction.self) {
                client.supabase.from("selfie_reactions").select()
                    .in("post_id", values: chunk.map(\.rawValue))
                    .order("created_at", ascending: true)
            }
        }
        return result
    }

    /// Uploads `jpeg` to `u/<uid>/selfies/<uuid>.jpg` and reacts with it (replacing the caller's earlier selfie).
    @discardableResult
    public func react(postID: PostID, jpeg: Data) async throws -> SelfieReaction {
        let path = StoragePaths.selfie(owner: try await client.requireUserID())
        try await uploader.upload(data: jpeg, path: path, contentType: ContentType.jpeg)
        return try await react(postID: postID, imagePath: path)
    }

    /// `react_with_selfie` with an image already uploaded. Errors: `post_not_found`, `invalid_image` (not the caller's
    /// upload), `own_post`.
    @discardableResult
    public func react(postID: PostID, imagePath: String) async throws -> SelfieReaction {
        try await client.rpc("react_with_selfie", ["p_post_id": .id(postID), "p_image_path": .string(imagePath)])
    }

    /// `remove_selfie_reaction`: the caller's own selfie (`userID` nil), or — on the caller's own post — anyone's.
    /// Errors: `post_not_found`, `not_allowed`.
    public func remove(postID: PostID, userID: UserID? = nil) async throws {
        try await client.rpcVoid("remove_selfie_reaction", ["p_post_id": .id(postID), "p_user_id": .id(userID)])
    }
}

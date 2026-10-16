import Foundation

public typealias SelfieReactionID = Identifier<SelfieReaction>

/// `selfie_reactions` (docs/API.md §14.1; surface viewer.selfiereaction): one live front-camera selfie per person and
/// post — a new one replaces that person's — shown as faces on the photo. Rows only: who reacted, never how many
/// (tenet: no counts).
public struct SelfieReaction: Codable, Hashable, Sendable, Identifiable {
    /// The row's own id: the target of `report('selfie', id, reason)`.
    public var id: SelfieReactionID
    public var postID: PostID
    public var userID: UserID
    public var groupID: GroupID
    /// `u/<uid>/selfies/<uuid>.jpg`, readable by whoever can read the row (signed URLs only, §7).
    public var imagePath: String
    /// When it was sent; a replacement sets it again.
    public var createdAt: Date

    public init(id: SelfieReactionID, postID: PostID, userID: UserID, groupID: GroupID, imagePath: String, createdAt: Date) {
        self.id = id
        self.postID = postID
        self.userID = userID
        self.groupID = groupID
        self.imagePath = imagePath
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case postID = "post_id"
        case userID = "user_id"
        case groupID = "group_id"
        case imagePath = "image_path"
        case createdAt = "created_at"
    }
}

import Foundation

/// Whether photos are developing and the earliest reveal (docs/API.md §14.3: `my_developing()` for the camera,
/// `group_developing(p_group_id)` for a group). A yes or no — never a number, never names.
public struct OvernightStatus: Codable, Hashable, Sendable {
    public var developing: Bool
    /// The first reveal (the first `overnight_reveal_local_time` after capture, in the group's time zone); nil when
    /// nothing develops.
    public var revealAt: Date?

    public init(developing: Bool, revealAt: Date?) {
        self.developing = developing
        self.revealAt = revealAt
    }

    /// Nothing developing.
    public static let notDeveloping = OvernightStatus(developing: false, revealAt: nil)

    enum CodingKeys: String, CodingKey {
        case developing
        case revealAt = "reveal_at"
    }
}

/// One group a photo develops for (`create_overnight_post` returns one per group): when it is revealed there.
public struct DevelopingPost: Codable, Hashable, Sendable {
    public var groupID: GroupID
    public var developsAt: Date

    public init(groupID: GroupID, developsAt: Date) {
        self.groupID = groupID
        self.developsAt = developsAt
    }

    enum CodingKeys: String, CodingKey {
        case groupID = "group_id"
        case developsAt = "develops_at"
    }
}

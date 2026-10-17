import Foundation

/// One row of `group_tributes` (docs/API.md §6.4, migration 0034): a delivered, ready birthday video of the group the
/// caller may watch — their own (`forMe`), or one they contributed to (VidDay: shared with the contributors after it is
/// given). Newest delivery first. The group screen's birthday video cards.
public struct GroupTribute: Codable, Hashable, Sendable, Identifiable {
    public var id: TributeID
    public var groupID: GroupID
    public var honoreeID: UserID
    /// The title card frame (`g/<group_id>/tributes/<id>/…`).
    public var posterPath: String?
    /// The birthday (group-local day).
    public var birthdayDate: LocalDate
    public var deliveredAt: Date
    /// The caller is the honoree.
    public var forMe: Bool

    public init(
        id: TributeID, groupID: GroupID, honoreeID: UserID, posterPath: String?, birthdayDate: LocalDate, deliveredAt: Date,
        forMe: Bool
    ) {
        self.id = id
        self.groupID = groupID
        self.honoreeID = honoreeID
        self.posterPath = posterPath
        self.birthdayDate = birthdayDate
        self.deliveredAt = deliveredAt
        self.forMe = forMe
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case honoreeID = "honoree_id"
        case posterPath = "poster_path"
        case birthdayDate = "birthday_date"
        case deliveredAt = "delivered_at"
        case forMe = "for_me"
    }
}

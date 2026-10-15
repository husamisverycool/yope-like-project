import Foundation
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

/// Live Activity attributes for the daily same-moment invitation (surface `daily.liveactivity`).
///
/// The worker starts the activity with an ActivityKit push-to-start payload:
///
///     "aps": {
///       "event": "start",
///       "attributes-type": "DailyInvitationAttributes",
///       "attributes": { "group_id": "…", "invitation_id": "…" },
///       "content-state": { "closes_at": 1760000000, "group_name": "…" },
///       "stale-date": 1760000000,
///       "alert": { … }
///     }
///
/// `closes_at` is Unix seconds (not Foundation's default reference-date encoding), and the keys
/// are snake_case like the rest of the push payloads. The type name is part of the push contract.
public struct DailyInvitationAttributes: Codable, Hashable, Sendable {
    public static let attributesTypeName = "DailyInvitationAttributes"

    public struct ContentState: Codable, Hashable, Sendable {
        /// When the invitation window closes (server time).
        public var closesAt: Date
        public var groupName: String

        public init(closesAt: Date, groupName: String) {
            self.closesAt = closesAt
            self.groupName = groupName
        }

        enum CodingKeys: String, CodingKey {
            case closesAt = "closes_at"
            case groupName = "group_name"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            closesAt = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .closesAt))
            groupName = try container.decode(String.self, forKey: .groupName)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(closesAt.timeIntervalSince1970, forKey: .closesAt)
            try container.encode(groupName, forKey: .groupName)
        }
    }

    public var groupID: String
    public var invitationID: String

    public init(groupID: String, invitationID: String) {
        self.groupID = groupID
        self.invitationID = invitationID
    }

    enum CodingKeys: String, CodingKey {
        case groupID = "group_id"
        case invitationID = "invitation_id"
    }
}

#if canImport(ActivityKit) && os(iOS)
extension DailyInvitationAttributes: ActivityAttributes {}
#endif

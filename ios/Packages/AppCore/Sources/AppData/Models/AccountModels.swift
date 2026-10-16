import AppModels
import Foundation

/// `devices` (docs/API.md §5.20).
public struct Device: Codable, Hashable, Sendable, Identifiable {
    public var id: DeviceID
    public var userID: UserID
    public var platform: DevicePlatform
    /// APNs device token (hex).
    public var pushToken: String
    /// iOS Live Activity push-to-start token.
    public var pushToStartToken: String?
    /// iOS WidgetKit push token.
    public var widgetPushToken: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: DeviceID, userID: UserID, platform: DevicePlatform, pushToken: String, pushToStartToken: String?,
        widgetPushToken: String?, createdAt: Date, updatedAt: Date
    ) {
        self.id = id
        self.userID = userID
        self.platform = platform
        self.pushToken = pushToken
        self.pushToStartToken = pushToStartToken
        self.widgetPushToken = widgetPushToken
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case platform
        case pushToken = "push_token"
        case pushToStartToken = "push_to_start_token"
        case widgetPushToken = "widget_push_token"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// `notification_settings` (§5.21). No row (nil) means no quiet hours.
public struct NotificationSettings: Codable, Hashable, Sendable {
    public var userID: UserID
    public var quietStart: LocalTime?
    public var quietEnd: LocalTime?
    public var timeZone: String?
    public var updatedAt: Date
    /// The reveal push of overnight photos (`notification_settings.overnight`, `set_overnight_alerts`; docs/API.md
    /// §14.3): on unless the member turned it off. No row means on.
    public var overnight: Bool

    public init(
        userID: UserID, quietStart: LocalTime?, quietEnd: LocalTime?, timeZone: String?, updatedAt: Date, overnight: Bool = true
    ) {
        self.userID = userID
        self.quietStart = quietStart
        self.quietEnd = quietEnd
        self.timeZone = timeZone
        self.updatedAt = updatedAt
        self.overnight = overnight
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case quietStart = "quiet_start"
        case quietEnd = "quiet_end"
        case timeZone = "time_zone"
        case updatedAt = "updated_at"
        case overnight
    }

    /// Rows read before the `overnight` column existed (offline copies) decode with alerts on, the server default.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decode(UserID.self, forKey: .userID)
        quietStart = try container.decodeIfPresent(LocalTime.self, forKey: .quietStart)
        quietEnd = try container.decodeIfPresent(LocalTime.self, forKey: .quietEnd)
        timeZone = try container.decodeIfPresent(String.self, forKey: .timeZone)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        overnight = try container.decodeIfPresent(Bool.self, forKey: .overnight) ?? true
    }

    /// The quiet hours as the shared AppModels rule, when set.
    public var quietHours: QuietHours? {
        guard let quietStart, let quietEnd else { return nil }
        return QuietHours(start: quietStart, end: quietEnd, timeZoneIdentifier: timeZone)
    }
}

/// `entitlements` (§5.22).
public struct Entitlement: Codable, Hashable, Sendable {
    public var userID: UserID
    /// `premium`
    public var entitlement: String
    /// Nil = no expiry.
    public var expiresAt: Date?
    public var source: String
    public var updatedAt: Date

    public init(userID: UserID, entitlement: String, expiresAt: Date?, source: String, updatedAt: Date) {
        self.userID = userID
        self.entitlement = entitlement
        self.expiresAt = expiresAt
        self.source = source
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case entitlement
        case expiresAt = "expires_at"
        case source
        case updatedAt = "updated_at"
    }

    /// Active when there is no expiry or it is in the future.
    public func isActive(at date: Date = Date()) -> Bool {
        expiresAt.map { $0 > date } ?? true
    }
}

/// Marker for report ids (`report` returns the new report's id; clients never read reports).
public enum ReportRecord {}

/// The public tunables (`public_app_config`, §5.25 / §11). Nil = not set on the server.
public struct PublicAppConfig: Codable, Hashable, Sendable {
    public var invitationWindowSeconds: Int?
    public var maxGroupMembers: Int?
    /// ISO weekday a history week starts on (1 = Monday).
    public var weekStartISODay: Int?
    /// Nil = unlimited history for everyone.
    public var freeHistoryDays: Int?
    /// Nil = the age gate is not configured (`confirm_age` fails closed).
    public var minAgeYears: Int?

    public init(
        invitationWindowSeconds: Int? = nil, maxGroupMembers: Int? = nil, weekStartISODay: Int? = nil,
        freeHistoryDays: Int? = nil, minAgeYears: Int? = nil
    ) {
        self.invitationWindowSeconds = invitationWindowSeconds
        self.maxGroupMembers = maxGroupMembers
        self.weekStartISODay = weekStartISODay
        self.freeHistoryDays = freeHistoryDays
        self.minAgeYears = minAgeYears
    }

    struct Row: Decodable {
        var key: String
        var value: JSONValue?
    }

    init(rows: [Row]) {
        var values: [String: Int] = [:]
        for row in rows {
            if let number = row.value?.intValue { values[row.key] = number }
        }
        self.init(
            invitationWindowSeconds: values["invitation_window_seconds"],
            maxGroupMembers: values["max_group_members"],
            weekStartISODay: values["week_start_isodow"],
            freeHistoryDays: values["free_history_days"],
            minAgeYears: values["min_age_years"]
        )
    }
}

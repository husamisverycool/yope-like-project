import AppModels
import Foundation
import Supabase

/// Safety: blocks and reports (docs/API.md §5.6, §6.3).
public struct SafetyRepository: Sendable {
    public let client: DataClient

    public init(client: DataClient) {
        self.client = client
    }

    /// People the caller blocked (the blocked person never sees the row).
    public func blocked() async throws -> [Block] {
        try await client.rows(Block.self) {
            client.supabase.from("blocks").select().order("created_at", ascending: false)
        }
    }

    /// `block_user`. Idempotent; works in both directions in every shared group.
    public func block(userID: UserID) async throws {
        try await client.rpcVoid("block_user", ["p_user_id": .id(userID)])
    }

    /// `unblock_user`. Idempotent.
    public func unblock(userID: UserID) async throws {
        try await client.rpcVoid("unblock_user", ["p_user_id": .id(userID)])
    }

    /// `report`: a post or message of one of the caller's groups, a person they share a group
    /// with (or have a block with), or one of their groups. Returns the report id.
    @discardableResult
    public func report(_ kind: ReportTargetKind, targetID: String, reason: String) async throws -> ReportID {
        let id: String = try await client.rpc("report", [
            "p_target_kind": .string(kind.rawValue),
            "p_target_id": .string(targetID.lowercased()),
            "p_reason": .string(reason),
        ])
        return ReportID(id)
    }
}

/// Settings, devices, entitlements, public configuration and account deletion
/// (docs/API.md §5.20–5.22, §5.25, §6.3).
public struct AccountRepository: Sendable {
    public let client: DataClient

    public init(client: DataClient) {
        self.client = client
    }

    // MARK: Notification settings

    /// The caller's quiet hours row; nil = no quiet hours.
    public func notificationSettings() async throws -> NotificationSettings? {
        let me = try await client.requireUserID()
        return try await client.firstRow(NotificationSettings.self) {
            client.supabase.from("notification_settings").select().eq("user_id", value: me.rawValue).limit(1)
        }
    }

    /// `set_quiet_hours`. Both nil = no quiet hours; `end <= start` wraps past midnight.
    /// `timeZone` is the device's zone (required when times are set).
    @discardableResult
    public func setQuietHours(start: LocalTime?, end: LocalTime?, timeZone: String? = TimeZone.current.identifier) async throws -> NotificationSettings {
        try await client.rpc("set_quiet_hours", [
            "p_start": .time(start),
            "p_end": .time(end),
            "p_time_zone": .text(timeZone),
        ])
    }

    /// `set_overnight_alerts`: the push when overnight photos develop (docs/API.md §14.3), on by default.
    @discardableResult
    public func setOvernightAlerts(_ on: Bool) async throws -> NotificationSettings {
        try await client.rpc("set_overnight_alerts", ["p_on": .bool(on)])
    }

    /// `set_notifications_paused` (Pause All, migration 0037): on = no notification until the next midnight of
    /// `timeZone` (the device's zone); off = notifications again.
    @discardableResult
    public func setNotificationsPaused(_ paused: Bool, timeZone: String? = TimeZone.current.identifier) async throws -> NotificationSettings {
        try await client.rpc("set_notifications_paused", [
            "p_paused": .bool(paused),
            "p_time_zone": .text(paused ? timeZone : nil),
        ])
    }

    /// `set_memory_alerts` (migration 0049): the opt-in memory notification on or off. On needs `timeZone`, the
    /// device's IANA zone (`invalid_time_zone` otherwise); off sends none and the server keeps the last zone.
    @discardableResult
    public func setMemoryAlerts(_ on: Bool, timeZone: String? = TimeZone.current.identifier) async throws -> NotificationSettings {
        try await client.rpc("set_memory_alerts", [
            "p_on": .bool(on),
            "p_time_zone": .text(on ? timeZone : nil),
        ])
    }

    // MARK: Devices

    /// `register_device` (iOS): upsert by APNs token. Send everything every time any of it changes; nil clears the
    /// push-to-start token. `liveActivitiesEnabled` false: Live Activities are off on this iPhone, so the worker sends the
    /// daily invitation as an alert instead of a push-to-start (migration 0030).
    @discardableResult
    public func registerDevice(pushToken: String, pushToStartToken: String?, liveActivitiesEnabled: Bool?) async throws -> Device {
        var parameters: [String: AnyJSON] = [
            "p_platform": .string(DevicePlatform.ios.rawValue),
            "p_push_token": .string(pushToken),
            "p_push_to_start_token": .text(pushToStartToken),
        ]
        if let liveActivitiesEnabled { parameters["p_live_activities_enabled"] = .bool(liveActivitiesEnabled) }
        return try await client.rpc("register_device", parameters)
    }

    /// `unregister_device` (before signing out).
    public func unregisterDevice(pushToken: String) async throws {
        try await client.rpcVoid("unregister_device", ["p_push_token": .string(pushToken)])
    }

    public func myDevices() async throws -> [Device] {
        try await client.rows(Device.self) {
            client.supabase.from("devices").select().order("updated_at", ascending: false)
        }
    }

    // MARK: Entitlements

    public func entitlements() async throws -> [Entitlement] {
        try await client.rows(Entitlement.self) {
            client.supabase.from("entitlements").select()
        }
    }

    /// Whether the server considers the caller premium (gates video posts only).
    public func hasPremium(at date: Date = Date()) async throws -> Bool {
        try await entitlements().contains { $0.entitlement == "premium" && $0.isActive(at: date) }
    }

    // MARK: Configuration

    /// `public_app_config` (readable signed out).
    public func publicConfig() async throws -> PublicAppConfig {
        let rows = try await client.rows(PublicAppConfig.Row.self) {
            client.supabase.from("public_app_config").select()
        }
        return PublicAppConfig(rows: rows)
    }

    // MARK: Account

    /// `delete_account`. Afterwards every call fails with `notAuthenticated`; sign out
    /// (`SessionCoordinator.deleteAccount` does both and clears local data).
    public func deleteAccount() async throws {
        try await client.rpcVoid("delete_account")
    }
}

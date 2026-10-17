import AppModels
import Foundation
import Supabase

/// A page of a newest-first list and the cursor for the next (older) page.
public struct Page<Item: Sendable>: Sendable {
    public var items: [Item]
    /// Pass back as `before` to get the next page; nil when this was the last page.
    public var nextCursor: Date?

    public init(items: [Item], nextCursor: Date?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

extension Page: Equatable where Item: Equatable {}
extension Page: Hashable where Item: Hashable {}

/// What `update_group` does with the cover (`p_cover_path`: null = unchanged, "" = remove).
public enum CoverChange: Hashable, Sendable {
    case unchanged
    case remove
    /// A path the caller uploaded (`StoragePaths.cover`).
    case set(String)

    var parameter: AnyJSON {
        switch self {
        case .unchanged: return .null
        case .remove: return .string("")
        case let .set(path): return .string(path)
        }
    }
}

/// Groups, members, invites and per-group settings (docs/API.md §5.3–5.5, §6.1).
public struct GroupRepository: Sendable {
    public let client: DataClient
    private let cache: OfflineCache?
    /// Called after any change to the caller's set of groups or a group's name (create, join,
    /// update, leave, remove), so the widget's group list and caches follow (`SessionCoordinator`).
    private let onGroupsChanged: (@Sendable () async -> Void)?

    public init(client: DataClient, cache: OfflineCache? = nil, onGroupsChanged: (@Sendable () async -> Void)? = nil) {
        self.client = client
        self.cache = cache
        self.onGroupsChanged = onGroupsChanged
    }

    // MARK: Reading

    /// The caller's groups (RLS returns only groups they belong to), oldest first. Cached for offline use.
    public func myGroups() async throws -> [PhotoGroup] {
        let groups = try await client.rows(PhotoGroup.self) {
            client.supabase.from("groups").select().order("created_at", ascending: true)
        }
        await cache?.write(groups, for: .groups)
        return groups
    }

    public func cachedGroups() async -> CachedValue<[PhotoGroup]>? {
        await cache?.read([PhotoGroup].self, for: .groups)
    }

    /// Nil when the group does not exist or the caller is not a member.
    public func group(id: GroupID) async throws -> PhotoGroup? {
        try await client.firstRow(PhotoGroup.self) {
            client.supabase.from("groups").select().eq("id", value: id.rawValue).limit(1)
        }
    }

    /// Members in joining order, with their profiles. Cached for offline use.
    public func members(groupID: GroupID) async throws -> [MemberProfile] {
        let members = try await client.rows(GroupMember.self) {
            client.supabase.from("group_members").select()
                .eq("group_id", value: groupID.rawValue)
                .order("joined_at", ascending: true)
        }
        let profiles = try await ProfileRepository(client: client).profiles(ids: members.map(\.userID))
        let byID = Dictionary(profiles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let result = members.map { MemberProfile(member: $0, profile: byID[$0.userID]) }
        await cache?.write(result, for: .members(groupID))
        return result
    }

    public func cachedMembers(groupID: GroupID) async -> CachedValue<[MemberProfile]>? {
        await cache?.read([MemberProfile].self, for: .members(groupID))
    }

    /// The caller's own membership row (role, mute).
    public func myMembership(groupID: GroupID) async throws -> GroupMember? {
        let me = try await client.requireUserID()
        return try await client.firstRow(GroupMember.self) {
            client.supabase.from("group_members").select()
                .eq("group_id", value: groupID.rawValue)
                .eq("user_id", value: me.rawValue)
                .limit(1)
        }
    }

    // MARK: Creating and editing

    /// `create_group`. The caller becomes the only member, as admin. `timeZone` defaults to the
    /// device's IANA zone. `coverPath` must be an upload of the caller (`StoragePaths.cover`).
    /// Waking hours: both or neither (nil = the default window).
    public func create(
        name: String,
        kind: GroupKind,
        timeZone: String = TimeZone.current.identifier,
        coverPath: String? = nil,
        wakingStart: LocalTime? = nil,
        wakingEnd: LocalTime? = nil
    ) async throws -> PhotoGroup {
        let group: PhotoGroup = try await client.rpc("create_group", [
            "p_name": .string(name),
            "p_kind": .string(kind.rawValue),
            "p_time_zone": .string(timeZone),
            "p_cover_path": .text(coverPath),
            "p_waking_start": .time(wakingStart),
            "p_waking_end": .time(wakingEnd),
        ])
        await onGroupsChanged?()
        return group
    }

    /// `update_group` (admins). Nil arguments leave the value unchanged.
    public func update(
        groupID: GroupID,
        name: String? = nil,
        kind: GroupKind? = nil,
        cover: CoverChange = .unchanged,
        timeZone: String? = nil
    ) async throws -> PhotoGroup {
        let group: PhotoGroup = try await client.rpc("update_group", [
            "p_group_id": .id(groupID),
            "p_name": .text(name),
            "p_kind": .text(kind?.rawValue),
            "p_cover_path": cover.parameter,
            "p_time_zone": .text(timeZone),
        ])
        await onGroupsChanged?()
        return group
    }

    /// `set_group_cover_from_post` (admins, update_group's rule; migration 0039): the photo's display rendition becomes
    /// the group's cover. Errors: `not_group_admin`, `post_not_found`, `media_not_ready` (renditions not made yet).
    public func setCoverFromPost(groupID: GroupID, postID: PostID) async throws -> PhotoGroup {
        let group: PhotoGroup = try await client.rpc("set_group_cover_from_post", [
            "p_group_id": .id(groupID),
            "p_post_id": .id(postID),
        ])
        await onGroupsChanged?()
        return group
    }

    /// `set_group_muted`: the caller's own push mute for the group.
    public func setMuted(groupID: GroupID, muted: Bool) async throws {
        try await client.rpcVoid("set_group_muted", ["p_group_id": .id(groupID), "p_muted": .bool(muted)])
    }

    /// `set_group_invitation_hours` (admins). Both nil = back to the default window;
    /// `end <= start` wraps past midnight.
    public func setInvitationHours(groupID: GroupID, start: LocalTime?, end: LocalTime?) async throws -> PhotoGroup {
        try await client.rpc("set_group_invitation_hours", [
            "p_group_id": .id(groupID),
            "p_start": .time(start),
            "p_end": .time(end),
        ])
    }

    /// `set_group_invitation_paused` (admins). Pausing cancels the unfired invitation.
    public func setInvitationPaused(groupID: GroupID, paused: Bool) async throws -> PhotoGroup {
        try await client.rpc("set_group_invitation_paused", ["p_group_id": .id(groupID), "p_paused": .bool(paused)])
    }

    // MARK: Invites

    /// Unrevoked invites of the group that have no expiry (owner decision 27) or have not reached it (to share a link
    /// again).
    public func activeInvites(groupID: GroupID, now: Date = Date()) async throws -> [GroupInvite] {
        try await client.rows(GroupInvite.self) {
            client.supabase.from("group_invites").select()
                .eq("group_id", value: groupID.rawValue)
                .is("revoked_at", value: nil)
                .or("expires_at.is.null,expires_at.gt.\"\(Timestamp.format(now))\"")
                .order("created_at", ascending: false)
        }
    }

    /// `create_invite` (any member). Build the link with `GroupInvite.link(domain:)`.
    public func createInvite(groupID: GroupID) async throws -> GroupInvite {
        try await client.rpc("create_invite", ["p_group_id": .id(groupID)])
    }

    /// `revoke_invite` (its creator or an admin). Idempotent.
    public func revokeInvite(token: String) async throws {
        try await client.rpcVoid("revoke_invite", ["p_token": .string(token)])
    }

    /// `invite_preview` (works signed out). Errors: `inviteNotFound`, `inviteRevoked`, `inviteExpired`.
    public func invitePreview(token: String) async throws -> InvitePreview {
        try await client.rpc("invite_preview", ["p_token": .string(token)])
    }

    /// `join_group`. Idempotent for current members. Errors: `inviteNotFound`, `inviteRevoked`,
    /// `inviteExpired`, `groupFull`.
    public func join(token: String) async throws -> PhotoGroup {
        let group: PhotoGroup = try await client.rpc("join_group", ["p_token": .string(token)])
        await onGroupsChanged?()
        return group
    }

    // MARK: Membership

    /// `remove_member` (admins; not yourself).
    public func removeMember(groupID: GroupID, userID: UserID) async throws {
        try await client.rpcVoid("remove_member", ["p_group_id": .id(groupID), "p_user_id": .id(userID)])
        await cache?.remove(.members(groupID))
    }

    /// `leave_group`. The last member leaving deletes the group and all its content.
    public func leave(groupID: GroupID) async throws {
        try await client.rpcVoid("leave_group", ["p_group_id": .id(groupID)])
        await cache?.removeGroup(groupID)
        await onGroupsChanged?()
    }
}

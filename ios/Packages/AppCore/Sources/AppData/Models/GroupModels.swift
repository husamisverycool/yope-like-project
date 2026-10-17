import AppModels
import Foundation

/// `profiles` (docs/API.md §5.1).
public struct Profile: Codable, Hashable, Sendable, Identifiable {
    public var id: UserID
    /// ≤ 80 characters; `""` until set.
    public var displayName: String
    /// `avatars/<id>/…`
    public var avatarPath: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UserID, displayName: String, avatarPath: String?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.displayName = displayName
        self.avatarPath = avatarPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarPath = "avatar_path"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// The first word of the display name (what the invite preview shows); nil when unset.
    public var firstName: String? {
        displayName.split(separator: " ").first.map(String.init)
    }
}

/// `profile_private` (§5.2): own row only.
public struct ProfilePrivate: Codable, Hashable, Sendable {
    public var userID: UserID
    public var birthday: LocalDate?
    public var birthdayOptIn: Bool
    public var ageConfirmedAt: Date?
    public var updatedAt: Date

    public init(userID: UserID, birthday: LocalDate?, birthdayOptIn: Bool, ageConfirmedAt: Date?, updatedAt: Date) {
        self.userID = userID
        self.birthday = birthday
        self.birthdayOptIn = birthdayOptIn
        self.ageConfirmedAt = ageConfirmedAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case birthday
        case birthdayOptIn = "birthday_opt_in"
        case ageConfirmedAt = "age_confirmed_at"
        case updatedAt = "updated_at"
    }
}

/// `groups` (§5.3). Named `PhotoGroup` so it does not collide with SwiftUI's `Group`.
public struct PhotoGroup: Codable, Hashable, Sendable, Identifiable {
    public var id: GroupID
    public var name: String
    public var kind: GroupKind
    public var coverPath: String?
    /// IANA zone; invitations, weeks, on-this-day and birthdays use it.
    public var timeZone: String
    /// The group's invitation hours; both nil = the default window. `end <= start` wraps past midnight.
    public var wakingStart: LocalTime?
    public var wakingEnd: LocalTime?
    public var invitationPaused: Bool
    /// Nil once that account is deleted.
    public var createdBy: UserID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: GroupID, name: String, kind: GroupKind, coverPath: String?, timeZone: String,
        wakingStart: LocalTime?, wakingEnd: LocalTime?, invitationPaused: Bool, createdBy: UserID?,
        createdAt: Date, updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.coverPath = coverPath
        self.timeZone = timeZone
        self.wakingStart = wakingStart
        self.wakingEnd = wakingEnd
        self.invitationPaused = invitationPaused
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, kind
        case coverPath = "cover_path"
        case timeZone = "time_zone"
        case wakingStart = "waking_start"
        case wakingEnd = "waking_end"
        case invitationPaused = "invitation_paused"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// The group's zone, or UTC when the stored name is not known to this device.
    public var resolvedTimeZone: TimeZone {
        TimeZone(identifier: timeZone) ?? TimeZone(identifier: "UTC")!
    }
}

/// `group_members` (§5.4).
public struct GroupMember: Codable, Hashable, Sendable, Identifiable {
    public var groupID: GroupID
    public var userID: UserID
    public var role: MemberRole
    /// Per-group push mute (readable by co-members, §12.12).
    public var muted: Bool
    public var joinedAt: Date

    public var id: UserID { userID }

    public init(groupID: GroupID, userID: UserID, role: MemberRole, muted: Bool, joinedAt: Date) {
        self.groupID = groupID
        self.userID = userID
        self.role = role
        self.muted = muted
        self.joinedAt = joinedAt
    }

    enum CodingKeys: String, CodingKey {
        case groupID = "group_id"
        case userID = "user_id"
        case role, muted
        case joinedAt = "joined_at"
    }
}

/// A member with their profile (member lists, settings).
public struct MemberProfile: Codable, Hashable, Sendable, Identifiable {
    public var member: GroupMember
    /// Nil only if the profile is not readable (it always is for co-members).
    public var profile: Profile?

    public var id: UserID { member.userID }

    public init(member: GroupMember, profile: Profile?) {
        self.member = member
        self.profile = profile
    }
}

/// `group_invites` (§5.5).
public struct GroupInvite: Codable, Hashable, Sendable, Identifiable {
    public var id: InviteID
    public var groupID: GroupID
    /// 24 URL-safe characters; the link is `https://<domain>/i/<token>`.
    public var token: String
    public var createdBy: UserID
    public var createdAt: Date
    /// Nil = the link never expires (owner decision 27: `invite_ttl_seconds` is NULL); it works until revoked.
    public var expiresAt: Date?
    public var revokedAt: Date?

    public init(id: InviteID, groupID: GroupID, token: String, createdBy: UserID, createdAt: Date, expiresAt: Date? = nil, revokedAt: Date?) {
        self.id = id
        self.groupID = groupID
        self.token = token
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.revokedAt = revokedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case token
        case createdBy = "created_by"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case revokedAt = "revoked_at"
    }

    public func isUsable(at date: Date = Date()) -> Bool {
        revokedAt == nil && (expiresAt.map { $0 > date } ?? true)
    }

    /// `https://<domain>/i/<token>`; nil while the domain is not configured.
    public func link(domain: String?) -> URL? {
        guard let domain, !domain.isEmpty else { return nil }
        return URL(string: "https://\(domain)/i/\(token)")
    }
}

/// `invite_preview` result (§6.1): the only thing a non-member learns before joining.
public struct InvitePreview: Codable, Hashable, Sendable {
    public struct Member: Codable, Hashable, Sendable {
        public var firstName: String?
        public var avatarPath: String?

        public init(firstName: String?, avatarPath: String?) {
            self.firstName = firstName
            self.avatarPath = avatarPath
        }

        enum CodingKeys: String, CodingKey {
            case firstName = "first_name"
            case avatarPath = "avatar_path"
        }
    }

    public var groupName: String
    public var groupKind: GroupKind
    public var coverPath: String?
    public var inviterFirstName: String?
    /// The inviter's avatar (`inviter_avatar_path`, migration 20261015000016); nil without a photo or from older servers.
    public var inviterAvatarPath: String?
    /// In joining order.
    public var members: [Member]

    public init(
        groupName: String, groupKind: GroupKind, coverPath: String?, inviterFirstName: String?, members: [Member],
        inviterAvatarPath: String? = nil
    ) {
        self.groupName = groupName
        self.groupKind = groupKind
        self.coverPath = coverPath
        self.inviterFirstName = inviterFirstName
        self.inviterAvatarPath = inviterAvatarPath
        self.members = members
    }

    enum CodingKeys: String, CodingKey {
        case groupName = "group_name"
        case groupKind = "group_kind"
        case coverPath = "cover_path"
        case inviterFirstName = "inviter_first_name"
        case inviterAvatarPath = "inviter_avatar_path"
        case members
    }
}

/// `blocks` (§5.6): rows where the caller is the blocker.
public struct Block: Codable, Hashable, Sendable {
    public var blockerID: UserID
    public var blockedID: UserID
    public var createdAt: Date

    public init(blockerID: UserID, blockedID: UserID, createdAt: Date) {
        self.blockerID = blockerID
        self.blockedID = blockedID
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case blockerID = "blocker_id"
        case blockedID = "blocked_id"
        case createdAt = "created_at"
    }
}

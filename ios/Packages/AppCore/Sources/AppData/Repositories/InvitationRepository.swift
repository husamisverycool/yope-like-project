import Foundation
import Supabase

/// Daily same-moment invitations (docs/API.md §5.12, recipe 9.5). Invitations are visible only
/// after `fires_at`, so the moment stays a surprise.
public struct InvitationRepository: Sendable {
    public let client: DataClient

    public init(client: DataClient) {
        self.client = client
    }

    /// The group's invitation whose window has not closed yet (open now), or nil.
    public func currentInvitation(groupID: GroupID, now: Date = Date()) async throws -> DailyInvitation? {
        try await client.firstRow(DailyInvitation.self) {
            client.supabase.from("daily_invitations").select()
                .eq("group_id", value: groupID.rawValue)
                .gte("closes_at", value: Timestamp.format(now))
                .order("fires_at", ascending: false)
                .limit(1)
        }
    }

    public func invitation(id: InvitationID) async throws -> DailyInvitation? {
        try await client.firstRow(DailyInvitation.self) {
            client.supabase.from("daily_invitations").select().eq("id", value: id.rawValue).limit(1)
        }
    }

    /// The group's invitation of a group-local day (nil before it fired).
    public func invitation(groupID: GroupID, localDate: LocalDate) async throws -> DailyInvitation? {
        try await client.firstRow(DailyInvitation.self) {
            client.supabase.from("daily_invitations").select()
                .eq("group_id", value: groupID.rawValue)
                .eq("local_date", value: localDate.description)
                .limit(1)
        }
    }

    /// Recent fired invitations of the group, newest first.
    public func recentInvitations(groupID: GroupID, limit: Int = 14) async throws -> [DailyInvitation] {
        try await client.rows(DailyInvitation.self) {
            client.supabase.from("daily_invitations").select()
                .eq("group_id", value: groupID.rawValue)
                .order("fires_at", ascending: false)
                .limit(limit)
        }
    }

    /// The caller's in-window answer to an invitation (their post with that `invitation_id`).
    /// Nil when they have not answered in the window. A post sent after the window is an
    /// ordinary post and is not an answer; nothing is ever labelled late.
    public func myAnswer(invitationID: InvitationID) async throws -> Post? {
        let me = try await client.requireUserID()
        return try await client.firstRow(Post.self) {
            client.supabase.from("posts").select()
                .eq("invitation_id", value: invitationID.rawValue)
                .eq("author_id", value: me.rawValue)
                .order("created_at", ascending: false)
                .limit(1)
        }
    }

    /// Every member's in-window posts for the invitation (the same-moment grid before the collage).
    public func answers(invitationID: InvitationID) async throws -> [Post] {
        try await client.rows(Post.self) {
            client.supabase.from("posts").select()
                .eq("invitation_id", value: invitationID.rawValue)
                .order("created_at", ascending: true)
        }
    }
}

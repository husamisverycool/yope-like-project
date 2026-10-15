import Foundation
import Supabase

/// Birthday tributes (docs/API.md §5.16–5.18, §6.3 `set_birthday`, §6.4 `contribute_tribute`).
///
/// Requests are private: the honoree never sees requests about them, and nobody sees who else
/// contributed (each person reads only their own contribution).
public struct BirthdayRepository: Sendable {
    public let client: DataClient

    public init(client: DataClient) {
        self.client = client
    }

    /// `set_birthday`. Opting in needs a date; opting out deletes requests about the caller that
    /// are not yet due.
    @discardableResult
    public func setBirthday(_ birthday: LocalDate?, optIn: Bool) async throws -> ProfilePrivate {
        try await client.rpc("set_birthday", ["p_birthday": .date(birthday), "p_opt_in": .bool(optIn)])
    }

    /// Tribute requests visible to the caller that are still open, soonest first.
    public func openRequests(now: Date = Date()) async throws -> [TributeRequest] {
        try await client.rows(TributeRequest.self) {
            client.supabase.from("tribute_requests").select()
                .is("closed_at", value: nil)
                .gt("due_at", value: Timestamp.format(now))
                .order("due_at", ascending: true)
        }
    }

    /// Every request of a group visible to the caller (open or closed), newest first.
    public func requests(groupID: GroupID) async throws -> [TributeRequest] {
        try await client.rows(TributeRequest.self) {
            client.supabase.from("tribute_requests").select()
                .eq("group_id", value: groupID.rawValue)
                .order("due_at", ascending: false)
        }
    }

    public func request(id: TributeRequestID) async throws -> TributeRequest? {
        try await client.firstRow(TributeRequest.self) {
            client.supabase.from("tribute_requests").select().eq("id", value: id.rawValue).limit(1)
        }
    }

    /// `contribute_tribute`: one per person per request; calling again replaces it until `due_at`.
    /// The photo must be from that group and posted by the caller or one they are self-tagged in.
    @discardableResult
    public func contribute(requestID: TributeRequestID, postID: PostID, line: String) async throws -> TributeContribution {
        try await client.rpc("contribute_tribute", [
            "p_request_id": .id(requestID),
            "p_post_id": .id(postID),
            "p_line": .string(line),
        ])
    }

    /// The caller's own contribution to a request.
    public func myContribution(requestID: TributeRequestID) async throws -> TributeContribution? {
        let me = try await client.requireUserID()
        return try await client.firstRow(TributeContribution.self) {
            client.supabase.from("tribute_contributions").select()
                .eq("request_id", value: requestID.rawValue)
                .eq("contributor_id", value: me.rawValue)
                .limit(1)
        }
    }

    /// Withdraws the caller's contribution (direct DELETE, allowed before `due_at`).
    public func withdraw(requestID: TributeRequestID) async throws {
        let me = try await client.requireUserID()
        try await client.perform {
            client.supabase.from("tribute_contributions")
                .delete(returning: .minimal)
                .eq("request_id", value: requestID.rawValue)
                .eq("contributor_id", value: me.rawValue)
        }
    }

    /// Tributes made for the caller (visible to the honoree only once delivered), newest first.
    public func tributesForMe() async throws -> [Tribute] {
        let me = try await client.requireUserID()
        return try await client.rows(Tribute.self) {
            client.supabase.from("tributes").select()
                .eq("honoree_id", value: me.rawValue)
                .order("delivered_at", ascending: false)
        }
    }

    public func tribute(id: TributeID) async throws -> Tribute? {
        try await client.firstRow(Tribute.self) {
            client.supabase.from("tributes").select().eq("id", value: id.rawValue).limit(1)
        }
    }

    /// Posts of the group the caller may contribute: their own and those they are self-tagged in.
    public func eligiblePostIDs(groupID: GroupID) async throws -> [PostID] {
        let me = try await client.requireUserID()
        let own = try await client.rows(Post.self) {
            client.supabase.from("posts").select()
                .eq("group_id", value: groupID.rawValue)
                .eq("author_id", value: me.rawValue)
                .order("created_at", ascending: false)
        }
        let tagged = try await ReactionRepository(client: client).myTags(groupID: groupID)
        var seen = Set<PostID>()
        return (own.map(\.id) + tagged.map(\.postID)).filter { seen.insert($0).inserted }
    }
}

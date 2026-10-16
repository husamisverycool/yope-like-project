import Foundation
import Supabase

/// The weekly question (docs/API.md §14.4): one light question per group week, answered with ordinary posts. No push,
/// no reminder, no streak, and nothing here counts or lists who answered.
public struct QuestionRepository: Sendable {
    public let client: DataClient

    public init(client: DataClient) {
        self.client = client
    }

    /// `current_group_question`: this group week's question (created on first read), or nil when the group has the
    /// question off or no questions are configured.
    public func current(groupID: GroupID) async throws -> GroupQuestion? {
        let rows: [GroupQuestion] = try await client.rpc("current_group_question", ["p_group_id": .id(groupID)])
        return rows.first
    }

    /// `hide_question` ("Remove"): the card goes for the caller, for that week.
    public func hide(questionID: GroupQuestionID) async throws {
        try await client.rpcVoid("hide_question", ["p_question_id": .id(questionID)])
    }

    /// `answer_question`: links one of the caller's posts in the question's group to it during its week (nil unlinks).
    @discardableResult
    public func answer(postID: PostID, questionID: GroupQuestionID?) async throws -> Post {
        try await client.rpc("answer_question", ["p_post_id": .id(postID), "p_question_id": .id(questionID)])
    }

    /// Links the caller's post of `mediaID` in `groupID` (just published from the camera) to the question. Returns the
    /// post, or nil when that post is not readable (deleted meanwhile).
    @discardableResult
    public func answer(mediaID: MediaID, groupID: GroupID, questionID: GroupQuestionID) async throws -> Post? {
        let me = try await client.requireUserID()
        let post = try await client.firstRow(Post.self) {
            client.supabase.from("posts").select()
                .eq("media_id", value: mediaID.rawValue)
                .eq("group_id", value: groupID.rawValue)
                .eq("author_id", value: me.rawValue)
                .limit(1)
        }
        guard let post else { return nil }
        return try await answer(postID: post.id, questionID: questionID)
    }

    /// The question's answers: posts carrying `question_id`, newest first (`limit` 1 for the card, nil for the viewer).
    public func answers(questionID: GroupQuestionID, limit: Int? = nil) async throws -> [Post] {
        try await client.rows(Post.self) {
            let query = client.supabase.from("posts").select()
                .eq("question_id", value: questionID.rawValue)
                .order("created_at", ascending: false)
            if let limit { return query.limit(limit) }
            return query
        }
    }

    /// `groups.weekly_question`: whether the group has the weekly question on.
    public func isOn(groupID: GroupID) async throws -> Bool {
        let row = try await client.firstRow(WeeklyQuestionSetting.self) {
            client.supabase.from("groups").select("weekly_question").eq("id", value: groupID.rawValue).limit(1)
        }
        return row?.weeklyQuestion ?? false
    }

    /// `set_group_weekly_question` (admins): the `groups.settings` switch.
    @discardableResult
    public func setOn(groupID: GroupID, on: Bool) async throws -> PhotoGroup {
        try await client.rpc("set_group_weekly_question", ["p_group_id": .id(groupID), "p_on": .bool(on)])
    }

    /// `group_developing` (§14.3): whether the group has overnight photos developing and the earliest reveal — the
    /// group screen's developing tile. Never a number.
    public func developing(groupID: GroupID) async throws -> OvernightStatus {
        let rows: [OvernightStatus] = try await client.rpc("group_developing", ["p_group_id": .id(groupID)])
        return rows.first ?? .notDeveloping
    }
}

/// `groups.weekly_question` alone.
private struct WeeklyQuestionSetting: Decodable {
    let weeklyQuestion: Bool

    enum CodingKeys: String, CodingKey {
        case weeklyQuestion = "weekly_question"
    }
}

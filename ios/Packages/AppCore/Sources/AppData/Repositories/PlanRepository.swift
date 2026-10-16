import Foundation
import Supabase

/// Plans (docs/API.md §14.2): make, edit, cancel and restore a plan (its maker and the group's admins), answer it
/// (Going · Maybe · Can't go), and read what the group screen, the plan page and the countdown widget show.
///
/// No counts anywhere: the plan page lists the people who answered (RLS hides Can't go from everyone but its author
/// and the plan's maker); nothing here counts them.
public struct PlanRepository: Sendable {
    public let client: DataClient

    public init(client: DataClient) {
        self.client = client
    }

    /// `next_plans`: upcoming plans (not canceled, not over) of the caller's groups — or of one group — soonest first,
    /// each with the caller's own answer.
    public func nextPlans(groupID: GroupID? = nil) async throws -> [UpcomingPlan] {
        try await client.rpc("next_plans", ["p_group_id": .id(groupID)])
    }

    public func plan(id: PlanID) async throws -> Plan? {
        try await client.firstRow(Plan.self) {
            client.supabase.from("plans").select().eq("id", value: id.rawValue).limit(1)
        }
    }

    /// The plan's answers visible to the caller, oldest answer first (the avatar stack's order).
    public func answers(planID: PlanID) async throws -> [PlanAnswer] {
        try await client.rows(PlanAnswer.self) {
            client.supabase.from("plan_answers").select()
                .eq("plan_id", value: planID.rawValue)
                .order("answered_at", ascending: true)
        }
    }

    /// `create_plan`: the maker's answer starts as Going; the group's members get one push.
    public func create(groupID: GroupID, fields: PlanFields) async throws -> Plan {
        var params = Self.params(fields)
        params["p_group_id"] = .id(groupID)
        return try await client.rpc("create_plan", params)
    }

    /// `update_plan` (maker or admin, until the plan is over). A change of day, time or place tells Going + Maybe once.
    public func update(id: PlanID, fields: PlanFields) async throws -> Plan {
        var params = Self.params(fields)
        params["p_plan_id"] = .id(id)
        return try await client.rpc("update_plan", params)
    }

    /// `cancel_plan`: tells Going + Maybe; the plan stays and can be restored.
    public func cancel(id: PlanID) async throws -> Plan {
        try await client.rpc("cancel_plan", ["p_plan_id": .id(id)])
    }

    /// `restore_plan`: tells nobody.
    public func restore(id: PlanID) async throws -> Plan {
        try await client.rpc("restore_plan", ["p_plan_id": .id(id)])
    }

    /// `answer_plan`: one tap; replaces the caller's previous answer.
    @discardableResult
    public func answer(planID: PlanID, _ answer: PlanAnswerKind) async throws -> PlanAnswer {
        try await client.rpc("answer_plan", ["p_plan_id": .id(planID), "p_answer": .string(answer.rawValue)])
    }

    /// `clear_answer`: back to no answer.
    public func clearAnswer(planID: PlanID) async throws {
        try await client.rpcVoid("clear_answer", ["p_plan_id": .id(planID)])
    }

    /// `plan_photos`: the group's posts of the plan's local days, oldest first (none for a canceled plan).
    public func photos(planID: PlanID) async throws -> [Post] {
        try await client.rpc("plan_photos", ["p_plan_id": .id(planID)])
    }

    private static func params(_ fields: PlanFields) -> JSONObject {
        [
            "p_title": .string(fields.title),
            "p_starts_at": .timestamp(fields.startsAt),
            "p_all_day": .bool(fields.allDay),
            "p_place": .text(fields.place),
            "p_note": .text(fields.note),
            "p_cover_path": .text(fields.coverPath),
        ]
    }
}

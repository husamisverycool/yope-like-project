import Foundation

// Plans and the weekly question (docs/API.md §14.2, §14.4). The group's developing state is `OvernightStatus`
// (OvernightModels.swift, §14.3).

public typealias PlanID = Identifier<Plan>
public typealias GroupQuestionID = Identifier<GroupQuestion>

/// `plan_answers.answer` (docs/API.md §14.2): Going · Maybe · Can't go, in Partiful's order (MERGE PL-1). No answer is
/// no row, never a value.
public enum PlanAnswerKind: String, LenientEnum {
    case going
    case maybe
    case cantGo = "cant_go"
    case unknown
    public static var unknownCase: PlanAnswerKind { .unknown }

    /// The three answers a member can give, in display order.
    public static var choices: [PlanAnswerKind] { [.going, .maybe, .cantGo] }
}

/// `plans` (§14.2). `localDate` is the plan's day in the group's time zone; an all-day plan starts at 00:00 of it.
/// There is no delete: a canceled plan stays (and can be restored).
public struct Plan: Codable, Hashable, Sendable, Identifiable {
    public var id: PlanID
    public var groupID: GroupID
    /// Nil once the maker's account is deleted.
    public var createdBy: UserID?
    /// 1–80 characters.
    public var title: String
    public var startsAt: Date
    /// Set by the server only (the create sheet sends none, MERGE "Problems found").
    public var endsAt: Date?
    public var allDay: Bool
    public var localDate: LocalDate
    /// ≤ 200 characters of typed text (no location data).
    public var place: String?
    /// ≤ 2,048 characters.
    public var note: String?
    public var coverPath: String?
    public var canceledAt: Date?
    public var canceledBy: UserID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: PlanID, groupID: GroupID, createdBy: UserID?, title: String, startsAt: Date, endsAt: Date? = nil, allDay: Bool,
        localDate: LocalDate, place: String? = nil, note: String? = nil, coverPath: String? = nil, canceledAt: Date? = nil,
        canceledBy: UserID? = nil, createdAt: Date, updatedAt: Date
    ) {
        self.id = id
        self.groupID = groupID
        self.createdBy = createdBy
        self.title = title
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.allDay = allDay
        self.localDate = localDate
        self.place = place
        self.note = note
        self.coverPath = coverPath
        self.canceledAt = canceledAt
        self.canceledBy = canceledBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case createdBy = "created_by"
        case title
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case allDay = "all_day"
        case localDate = "local_date"
        case place, note
        case coverPath = "cover_path"
        case canceledAt = "canceled_at"
        case canceledBy = "canceled_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public var isCanceled: Bool { canceledAt != nil }

    /// "Over" as the server reads it (`private.plan_over`): after `endsAt`, or after the end of `localDate` in the
    /// group's time zone when there is no end. Answers, edits, cancel and restore stop then.
    public func isOver(at date: Date = Date(), timeZone: TimeZone) -> Bool {
        if let endsAt { return date >= endsAt }
        return date >= PlanCalendar.start(of: localDate.adding(days: 1), in: timeZone)
    }
}

/// `plan_answers` (§14.2). RLS: Going and Maybe rows for every member; Can't go rows only for their author and the
/// plan's maker.
public struct PlanAnswer: Codable, Hashable, Sendable {
    public var planID: PlanID
    public var userID: UserID
    public var groupID: GroupID
    public var answer: PlanAnswerKind
    public var answeredAt: Date

    public init(planID: PlanID, userID: UserID, groupID: GroupID, answer: PlanAnswerKind, answeredAt: Date) {
        self.planID = planID
        self.userID = userID
        self.groupID = groupID
        self.answer = answer
        self.answeredAt = answeredAt
    }

    enum CodingKeys: String, CodingKey {
        case planID = "plan_id"
        case userID = "user_id"
        case groupID = "group_id"
        case answer
        case answeredAt = "answered_at"
    }
}

/// A row of `next_plans` (§14.2): an upcoming plan (not canceled, not over) with the caller's own answer — the group
/// screen's plan row and the countdown widget.
public struct UpcomingPlan: Codable, Hashable, Sendable, Identifiable {
    public var id: PlanID
    public var groupID: GroupID
    public var createdBy: UserID?
    public var title: String
    public var startsAt: Date
    public var endsAt: Date?
    public var allDay: Bool
    public var localDate: LocalDate
    public var place: String?
    public var coverPath: String?
    /// Nil: no answer.
    public var myAnswer: PlanAnswerKind?

    public init(
        id: PlanID, groupID: GroupID, createdBy: UserID?, title: String, startsAt: Date, endsAt: Date? = nil, allDay: Bool,
        localDate: LocalDate, place: String? = nil, coverPath: String? = nil, myAnswer: PlanAnswerKind? = nil
    ) {
        self.id = id
        self.groupID = groupID
        self.createdBy = createdBy
        self.title = title
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.allDay = allDay
        self.localDate = localDate
        self.place = place
        self.coverPath = coverPath
        self.myAnswer = myAnswer
    }

    /// The upcoming row of a plan (local fakes; the server builds the real one).
    public init(_ plan: Plan, myAnswer: PlanAnswerKind?) {
        self.init(
            id: plan.id, groupID: plan.groupID, createdBy: plan.createdBy, title: plan.title, startsAt: plan.startsAt,
            endsAt: plan.endsAt, allDay: plan.allDay, localDate: plan.localDate, place: plan.place, coverPath: plan.coverPath,
            myAnswer: myAnswer
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case createdBy = "created_by"
        case title
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case allDay = "all_day"
        case localDate = "local_date"
        case place
        case coverPath = "cover_path"
        case myAnswer = "my_answer"
    }
}

/// Where a plan sits in the group's plans list (`group_plans`, docs/API.md §14.2): upcoming (not cancelled, not over),
/// past (over), cancelled (upcoming or not).
public enum GroupPlanState: String, LenientEnum {
    case upcoming
    case past
    case canceled
    case unknown
    public static var unknownCase: GroupPlanState { .unknown }
}

/// A row of `group_plans` (§14.2): one plan of a group with the caller's own answer and its list section. The server
/// orders the rows: upcoming soonest first, then past latest first, then cancelled latest first.
public struct GroupPlan: Codable, Hashable, Sendable, Identifiable {
    public var id: PlanID
    public var groupID: GroupID
    public var createdBy: UserID?
    public var title: String
    public var startsAt: Date
    public var endsAt: Date?
    public var allDay: Bool
    public var localDate: LocalDate
    public var place: String?
    public var coverPath: String?
    public var canceledAt: Date?
    /// Nil: no answer.
    public var myAnswer: PlanAnswerKind?
    public var state: GroupPlanState

    public init(
        id: PlanID, groupID: GroupID, createdBy: UserID?, title: String, startsAt: Date, endsAt: Date? = nil, allDay: Bool,
        localDate: LocalDate, place: String? = nil, coverPath: String? = nil, canceledAt: Date? = nil,
        myAnswer: PlanAnswerKind? = nil, state: GroupPlanState
    ) {
        self.id = id
        self.groupID = groupID
        self.createdBy = createdBy
        self.title = title
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.allDay = allDay
        self.localDate = localDate
        self.place = place
        self.coverPath = coverPath
        self.canceledAt = canceledAt
        self.myAnswer = myAnswer
        self.state = state
    }

    /// The list row of a plan (local fakes; the server builds the real one).
    public init(_ plan: Plan, myAnswer: PlanAnswerKind?, state: GroupPlanState) {
        self.init(
            id: plan.id, groupID: plan.groupID, createdBy: plan.createdBy, title: plan.title, startsAt: plan.startsAt,
            endsAt: plan.endsAt, allDay: plan.allDay, localDate: plan.localDate, place: plan.place, coverPath: plan.coverPath,
            canceledAt: plan.canceledAt, myAnswer: myAnswer, state: state
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case createdBy = "created_by"
        case title
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case allDay = "all_day"
        case localDate = "local_date"
        case place
        case coverPath = "cover_path"
        case canceledAt = "canceled_at"
        case myAnswer = "my_answer"
        case state
    }
}

/// What `create_plan` / `update_plan` take (§14.2). No end time: the design has no end row (MERGE "Problems found").
public struct PlanFields: Hashable, Sendable {
    public var title: String
    /// The chosen day and time; for an all-day plan any instant of the day (the server moves it to 00:00 of the day in
    /// the group's zone).
    public var startsAt: Date
    public var allDay: Bool
    public var place: String?
    public var note: String?
    /// An upload of the caller (`StoragePaths.cover`), or the plan's current cover.
    public var coverPath: String?

    public init(title: String, startsAt: Date, allDay: Bool, place: String? = nil, note: String? = nil, coverPath: String? = nil) {
        self.title = title
        self.startsAt = startsAt
        self.allDay = allDay
        self.place = place
        self.note = note
        self.coverPath = coverPath
    }
}

/// A row of `current_group_question` (§14.4): this group week's question. The text is app copy found by `questionKey`
/// (`question.weekly.q01` …); the server stores only the key.
public struct GroupQuestion: Codable, Hashable, Sendable, Identifiable {
    public var id: GroupQuestionID
    public var questionKey: String
    /// Monday (`week_start_isodow`) of the group week, in the group's time zone.
    public var weekStart: LocalDate
    /// The caller removed the card for this week (`hide_question`).
    public var hiddenByMe: Bool

    public init(id: GroupQuestionID, questionKey: String, weekStart: LocalDate, hiddenByMe: Bool) {
        self.id = id
        self.questionKey = questionKey
        self.weekStart = weekStart
        self.hiddenByMe = hiddenByMe
    }

    enum CodingKeys: String, CodingKey {
        case id
        case questionKey = "question_key"
        case weekStart = "week_start"
        case hiddenByMe = "hidden_by_me"
    }
}

/// Calendar arithmetic on group-local days.
public enum PlanCalendar {
    /// 00:00 of `day` in `timeZone`.
    public static func start(of day: LocalDate, in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(year: day.year, month: day.month, day: day.day)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: TimeInterval(day.dayNumber) * 86_400)
    }
}

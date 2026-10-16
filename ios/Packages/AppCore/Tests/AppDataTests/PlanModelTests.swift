import AppModels
import Foundation
import XCTest
@testable import AppData

/// Wire format of plans, answers, the weekly question and the group's developing state (docs/API.md §14.2–§14.4; no network).
final class PlanModelTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try DataCoding.makeDecoder().decode(type, from: Data(json.utf8))
    }

    func testPlanRowDecodes() throws {
        let plan = try decode(Plan.self, """
        {"id":"8B2E3C2A-1D4F-4E7A-9B1C-2D3E4F5A6B7C","group_id":"g","created_by":"u","title":"Dinner at ours",
         "starts_at":"2026-10-24T17:30:00+00:00","ends_at":null,"all_day":false,"local_date":"2026-10-24",
         "place":"Maya's place","note":null,"cover_path":"u/u/covers/c.jpg","canceled_at":null,"canceled_by":null,
         "created_at":"2026-10-16T09:00:00.123456+00:00","updated_at":"2026-10-16T09:00:00.123456+00:00"}
        """)
        XCTAssertEqual(plan.id.rawValue, "8b2e3c2a-1d4f-4e7a-9b1c-2d3e4f5a6b7c")
        XCTAssertEqual(plan.localDate.description, "2026-10-24")
        XCTAssertFalse(plan.allDay)
        XCTAssertFalse(plan.isCanceled)
        XCTAssertEqual(plan.place, "Maya's place")
        XCTAssertNil(plan.note)
        XCTAssertEqual(plan.createdBy?.rawValue, "u")

        let canceled = try decode(Plan.self, """
        {"id":"p","group_id":"g","created_by":null,"title":"x","starts_at":"2026-10-24T00:00:00Z","all_day":true,
         "local_date":"2026-10-24","canceled_at":"2026-10-20T10:00:00Z","canceled_by":"u",
         "created_at":"2026-10-16T09:00:00Z","updated_at":"2026-10-20T10:00:00Z"}
        """)
        XCTAssertTrue(canceled.isCanceled)
        XCTAssertNil(canceled.createdBy, "a deleted maker's plan stays")
    }

    func testPlanIsOverAtTheEndOfItsDayInTheGroupZone() throws {
        let plan = try decode(Plan.self, """
        {"id":"p","group_id":"g","title":"x","starts_at":"2026-10-24T17:00:00Z","all_day":false,"local_date":"2026-10-24",
         "created_at":"2026-10-16T09:00:00Z","updated_at":"2026-10-16T09:00:00Z"}
        """)
        let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        // Midnight Oct 25 in New York (EDT, UTC−4) is 04:00Z.
        XCTAssertFalse(plan.isOver(at: try XCTUnwrap(Timestamp.parse("2026-10-25T03:59:59Z")), timeZone: newYork))
        XCTAssertTrue(plan.isOver(at: try XCTUnwrap(Timestamp.parse("2026-10-25T04:00:00Z")), timeZone: newYork))
        var ended = plan
        ended.endsAt = Timestamp.parse("2026-10-24T20:00:00Z")
        XCTAssertTrue(ended.isOver(at: try XCTUnwrap(Timestamp.parse("2026-10-24T20:00:00Z")), timeZone: newYork))
    }

    func testAnswersAndUpcomingRows() throws {
        let answers = try decode([PlanAnswer].self, """
        [{"plan_id":"p","user_id":"a","group_id":"g","answer":"going","answered_at":"2026-10-16T09:00:00Z"},
         {"plan_id":"p","user_id":"b","group_id":"g","answer":"cant_go","answered_at":"2026-10-16T09:01:00Z"},
         {"plan_id":"p","user_id":"c","group_id":"g","answer":"interested","answered_at":"2026-10-16T09:02:00Z"}]
        """)
        XCTAssertEqual(answers.map(\.answer), [.going, .cantGo, .unknown])
        XCTAssertEqual(PlanAnswerKind.choices, [.going, .maybe, .cantGo])

        let upcoming = try decode([UpcomingPlan].self, """
        [{"id":"p","group_id":"g","created_by":"u","title":"Dinner","starts_at":"2026-10-24T17:30:00Z","ends_at":null,
          "all_day":false,"local_date":"2026-10-24","place":null,"cover_path":null,"my_answer":null},
         {"id":"q","group_id":"g","created_by":null,"title":"Hike","starts_at":"2026-10-25T00:00:00Z","ends_at":null,
          "all_day":true,"local_date":"2026-10-25","place":"Trailhead","cover_path":null,"my_answer":"maybe"}]
        """)
        XCTAssertNil(upcoming[0].myAnswer)
        XCTAssertEqual(upcoming[1].myAnswer, .maybe)
        XCTAssertTrue(upcoming[1].allDay)
    }

    func testQuestionAndDevelopingRows() throws {
        let questions = try decode([GroupQuestion].self, """
        [{"id":"q","question_key":"question.weekly.q01","week_start":"2026-10-12","hidden_by_me":false}]
        """)
        XCTAssertEqual(questions.first?.questionKey, "question.weekly.q01")
        XCTAssertEqual(questions.first?.weekStart.description, "2026-10-12")
        XCTAssertEqual(try decode([GroupQuestion].self, "[]"), [], "no row when the group has the question off")

        // `group_developing` returns one row: a yes or no and the earliest reveal, never a number.
        let developing = try decode([OvernightStatus].self, """
        [{"developing":true,"reveal_at":"2026-10-17T07:00:00+00:00"}]
        """)
        XCTAssertEqual(developing.first?.developing, true)
        XCTAssertNotNil(developing.first?.revealAt)
        let idle = try decode([OvernightStatus].self, #"[{"developing":false,"reveal_at":null}]"#)
        XCTAssertEqual(idle.first, OvernightStatus.notDeveloping)
    }

    func testPostsKeepDecodingWithTheQuestionColumn() throws {
        let post = try decode(Post.self, """
        {"id":"p","media_id":"m","group_id":"g","author_id":"u","in_window":false,"question_id":"q","revealed_at":null,
         "created_at":"2026-10-16T09:00:00Z"}
        """)
        XCTAssertEqual(post.id.rawValue, "p")
    }

    func testPlanStartOfDay() throws {
        let tokyo = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let day = try XCTUnwrap(LocalDate("2026-10-24"))
        XCTAssertEqual(PlanCalendar.start(of: day, in: tokyo), Timestamp.parse("2026-10-23T15:00:00Z"))
    }
}

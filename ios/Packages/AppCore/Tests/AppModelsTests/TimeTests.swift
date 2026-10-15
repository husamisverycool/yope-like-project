import Foundation
import XCTest
@testable import AppModels

final class CountdownStateTests: XCTestCase {
    let opens = Date(timeIntervalSince1970: 1_000)
    let closes = Date(timeIntervalSince1970: 1_120)

    func testStates() {
        XCTAssertEqual(CountdownState(opensAt: opens, closesAt: closes, now: Date(timeIntervalSince1970: 990)), .upcoming(opensIn: 10))
        XCTAssertEqual(CountdownState(opensAt: opens, closesAt: closes, now: opens), .open(remaining: 120))
        XCTAssertEqual(CountdownState(opensAt: opens, closesAt: closes, now: Date(timeIntervalSince1970: 1_119.5)), .open(remaining: 0.5))
        XCTAssertEqual(CountdownState(opensAt: opens, closesAt: closes, now: closes), .closed, "closing instant is closed")
        XCTAssertEqual(CountdownState(opensAt: nil, closesAt: closes, now: Date(timeIntervalSince1970: 0)), .open(remaining: 1_120))
    }

    func testRemainingSecondsRoundUp() {
        XCTAssertEqual(CountdownState.open(remaining: 0.2).remainingWholeSeconds, 1)
        XCTAssertEqual(CountdownState.open(remaining: 59).remainingWholeSeconds, 59)
        XCTAssertNil(CountdownState.closed.remainingWholeSeconds)
        XCTAssertTrue(CountdownState.open(remaining: 1).isOpen)
        XCTAssertFalse(CountdownState.upcoming(opensIn: 1).isOpen)
    }

    func testServerClockOffset() {
        // Device clock is 30 s behind the server.
        let clock = ServerClock(offset: 30)
        let deviceNow = Date(timeIntervalSince1970: 1_080)
        XCTAssertEqual(CountdownState(opensAt: opens, closesAt: closes, now: deviceNow, clock: clock), .open(remaining: 10))
        XCTAssertEqual(CountdownState.nextTransition(opensAt: opens, closesAt: closes, now: deviceNow, clock: clock), Date(timeIntervalSince1970: 1_090))
        XCTAssertEqual(CountdownState.timerRange(closesAt: closes, now: deviceNow, clock: clock), deviceNow...Date(timeIntervalSince1970: 1_090))
    }

    func testNextTransition() {
        XCTAssertEqual(CountdownState.nextTransition(opensAt: opens, closesAt: closes, now: Date(timeIntervalSince1970: 0)), opens)
        XCTAssertEqual(CountdownState.nextTransition(opensAt: opens, closesAt: closes, now: opens), closes)
        XCTAssertNil(CountdownState.nextTransition(opensAt: opens, closesAt: closes, now: closes))
    }

    func testTimerRangeNeverInverts() {
        let late = Date(timeIntervalSince1970: 5_000)
        let range = CountdownState.timerRange(closesAt: closes, now: late)
        XCTAssertEqual(range.lowerBound, closes)
        XCTAssertEqual(range.upperBound, closes)
    }
}

final class QuietHoursTests: XCTestCase {
    private let utc = "UTC"

    private func date(_ hour: Int, _ minute: Int, day: Int = 15, zone: String = "UTC") -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    func testLocalTimeParsing() {
        XCTAssertEqual(LocalTime("07:30"), LocalTime(hour: 7, minute: 30))
        XCTAssertEqual(LocalTime("22:00:00"), LocalTime(hour: 22, minute: 0))
        XCTAssertEqual(LocalTime("22:00:00.000"), LocalTime(hour: 22, minute: 0))
        XCTAssertNil(LocalTime("24:00"))
        XCTAssertNil(LocalTime("7"))
        XCTAssertNil(LocalTime("aa:bb"))
        XCTAssertEqual(LocalTime(hour: 7, minute: 5)?.description, "07:05")
    }

    func testSameDayInterval() throws {
        let quiet = QuietHours(start: try XCTUnwrap(LocalTime("13:00")), end: try XCTUnwrap(LocalTime("15:00")), timeZoneIdentifier: utc)
        XCTAssertFalse(quiet.contains(date(12, 59)))
        XCTAssertTrue(quiet.contains(date(13, 0)), "start is inclusive")
        XCTAssertTrue(quiet.contains(date(14, 59)))
        XCTAssertFalse(quiet.contains(date(15, 0)), "end is exclusive")
    }

    func testWrapsMidnight() throws {
        let quiet = QuietHours(start: try XCTUnwrap(LocalTime("22:00")), end: try XCTUnwrap(LocalTime("07:00")), timeZoneIdentifier: utc)
        XCTAssertTrue(quiet.contains(date(23, 30)))
        XCTAssertTrue(quiet.contains(date(0, 0)))
        XCTAssertTrue(quiet.contains(date(6, 59)))
        XCTAssertFalse(quiet.contains(date(7, 0)))
        XCTAssertFalse(quiet.contains(date(21, 59)))
        XCTAssertEqual(quiet.currentPeriodEnd(after: date(23, 30)), date(7, 0, day: 16))
        XCTAssertEqual(quiet.currentPeriodEnd(after: date(1, 0)), date(7, 0))
        XCTAssertNil(quiet.currentPeriodEnd(after: date(12, 0)))
    }

    func testEmptyInterval() throws {
        let time = try XCTUnwrap(LocalTime("09:00"))
        let quiet = QuietHours(start: time, end: time, timeZoneIdentifier: utc)
        XCTAssertTrue(quiet.isEmpty)
        XCTAssertFalse(quiet.contains(date(9, 0)))
    }

    func testUsesConfiguredTimeZone() throws {
        let quiet = QuietHours(start: try XCTUnwrap(LocalTime("22:00")), end: try XCTUnwrap(LocalTime("07:00")), timeZoneIdentifier: "America/New_York")
        // 03:00 UTC on Oct 15 is 23:00 in New York on Oct 14.
        XCTAssertTrue(quiet.contains(date(3, 0)))
        // 12:00 UTC is 08:00 in New York.
        XCTAssertFalse(quiet.contains(date(12, 0)))
    }

    func testCodable() throws {
        let json = Data(#"{"quiet_start":"22:00:00","quiet_end":"07:30:00","time_zone":"Europe/Madrid"}"#.utf8)
        let quiet = try JSONDecoder().decode(QuietHours.self, from: json)
        XCTAssertEqual(quiet.start, LocalTime(hour: 22, minute: 0))
        XCTAssertEqual(quiet.end, LocalTime(hour: 7, minute: 30))
        XCTAssertEqual(quiet.timeZone.identifier, "Europe/Madrid")
        XCTAssertEqual(try JSONDecoder().decode(QuietHours.self, from: try JSONEncoder().encode(quiet)), quiet)
    }
}

final class SessionPromptGateTests: XCTestCase {
    func testOncePerSession() {
        var gate = SessionPromptGate()
        XCTAssertFalse(gate.canPrompt(activeBlockers: []), "no session started")
        gate.startSession()
        XCTAssertTrue(gate.consumePrompt(activeBlockers: []))
        XCTAssertFalse(gate.consumePrompt(activeBlockers: []))
        gate.startSession()
        XCTAssertTrue(gate.consumePrompt(activeBlockers: []))
    }

    func testBlockersDoNotConsume() {
        var gate = SessionPromptGate()
        gate.startSession()
        XCTAssertFalse(gate.consumePrompt(activeBlockers: [.capture]))
        XCTAssertFalse(gate.consumePrompt(activeBlockers: [.onboarding]))
        XCTAssertFalse(gate.hasPromptedInSession)
        XCTAssertTrue(gate.consumePrompt(activeBlockers: []))
    }
}

final class DailyInvitationAttributesTests: XCTestCase {
    func testContentStateMatchesPushPayload() throws {
        let json = Data(#"{"closes_at":1760529720,"group_name":"Roommates"}"#.utf8)
        let state = try JSONDecoder().decode(DailyInvitationAttributes.ContentState.self, from: json)
        XCTAssertEqual(state.closesAt, Date(timeIntervalSince1970: 1_760_529_720))
        XCTAssertEqual(state.groupName, "Roommates")
        let reencoded = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(state)) as? [String: Any]
        XCTAssertEqual(reencoded?["closes_at"] as? Double, 1_760_529_720)
    }

    func testAttributesMatchPushPayload() throws {
        let json = Data(#"{"group_id":"g1","invitation_id":"i1"}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(DailyInvitationAttributes.self, from: json), DailyInvitationAttributes(groupID: "g1", invitationID: "i1"))
    }

    func testTypeNameIsThePushContract() {
        XCTAssertEqual(String(describing: DailyInvitationAttributes.self), DailyInvitationAttributes.attributesTypeName)
    }
}

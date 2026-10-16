import Foundation
import XCTest
@testable import AppModels

/// The plan route (`plans.page`): `app://plan?plan=<id>&group=<id>` (same format as Android's `DeepLink.Plan`) and the
/// `plan` push type with `plan_id` (docs/API.md §14.2).
final class PlanDeepLinkTests: XCTestCase {
    let parser = DeepLinkParser(universalLinkHosts: ["invite.example.test"])

    private func url(_ string: String) -> URL { URL(string: string)! }

    func testPlanURL() {
        XCTAssertEqual(parser.parse(url("app://plan?plan=p-1&group=g-1")), .plan(planID: "p-1", groupID: "g-1"))
        XCTAssertEqual(parser.parse(url("app://plan?group=g-1&plan=p-1")), .plan(planID: "p-1", groupID: "g-1"))
        XCTAssertEqual(parser.parse(url("app://plan?plan=p-1")), .plan(planID: "p-1", groupID: nil))
        XCTAssertEqual(parser.parse(url("app:///plan?plan=p-1")), .plan(planID: "p-1", groupID: nil))
        XCTAssertEqual(parser.parse(url("app://plan?plan=p-1&group=../x")), .plan(planID: "p-1", groupID: nil), "unsafe group is dropped")
        XCTAssertNil(parser.parse(url("app://plan?group=g-1")), "the plan id is required")
        XCTAssertNil(parser.parse(url("app://plan?plan=a/b")), "unsafe plan id")
    }

    func testPlanURLRoundTripAndFormat() throws {
        let links: [DeepLink] = [
            .plan(planID: "8a6e0804-2bd0-4672-b79d-d97027f9071a", groupID: "g"),
            .plan(planID: "p", groupID: nil),
        ]
        for link in links {
            let built = try XCTUnwrap(parser.url(for: link), "\(link)")
            XCTAssertEqual(parser.parse(built), link, built.absoluteString)
        }
        // Same link format as Android (android/core/model/.../DeepLink.kt `DeepLink.Plan`).
        XCTAssertEqual(parser.url(for: .plan(planID: "p", groupID: "g"))?.absoluteString, "app://plan?plan=p&group=g")
        XCTAssertEqual(parser.url(for: .plan(planID: "p", groupID: nil))?.absoluteString, "app://plan?plan=p")
    }

    func testPlanPushPayload() {
        XCTAssertEqual(
            parser.parse(notificationPayload: ["type": "plan", "plan_id": "p", "group_id": "g", "aps": ["alert": "x"]]),
            .plan(planID: "p", groupID: "g")
        )
        XCTAssertEqual(parser.parse(notificationPayload: ["type": "plan", "plan_id": "p"]), .plan(planID: "p", groupID: nil))
        XCTAssertNil(parser.parse(notificationPayload: ["type": "plan", "group_id": "g"]), "no plan id")
        XCTAssertEqual(parser.payload(for: .plan(planID: "p", groupID: "g")), ["type": "plan", "plan_id": "p", "group_id": "g"])
        let payload: [AnyHashable: Any] = parser.payload(for: .plan(planID: "p", groupID: nil))
        XCTAssertEqual(parser.parse(notificationPayload: payload), .plan(planID: "p", groupID: nil))
    }

    func testPlanLinkFields() {
        XCTAssertEqual(DeepLink.plan(planID: "p", groupID: "g").groupID, "g")
        XCTAssertNil(DeepLink.plan(planID: "p", groupID: nil).groupID)
        XCTAssertEqual(DeepLink.plan(planID: "p", groupID: nil).route, .plan)
        XCTAssertEqual(DeepLinkField.plan.payloadKey, PushKey.planID)
        XCTAssertEqual(DeepLinkRoute.plan.rawValue, "plan")
    }
}

import Foundation
import XCTest
@testable import AppModels

final class DeepLinkTests: XCTestCase {
    let parser = DeepLinkParser(universalLinkHosts: ["invite.example.test"])

    private func url(_ string: String) -> URL { URL(string: string)! }

    // MARK: Universal links

    func testInviteLink() {
        XCTAssertEqual(parser.parse(url("https://invite.example.test/i/AbC-123_x")), .invite(token: "AbC-123_x"))
        XCTAssertEqual(parser.parse(url("https://INVITE.example.test/i/tok/")), .invite(token: "tok"))
        XCTAssertEqual(parser.parse(url("https://invite.example.test/i/tok?utm=1#x")), .invite(token: "tok"))
    }

    func testInviteLinkRejections() {
        XCTAssertNil(parser.parse(url("https://other.example.test/i/tok")), "unknown host")
        XCTAssertNil(parser.parse(url("http://invite.example.test/i/tok")), "plain http")
        XCTAssertNil(parser.parse(url("https://invite.example.test/x/tok")), "wrong prefix")
        XCTAssertNil(parser.parse(url("https://invite.example.test/i")), "no token")
        XCTAssertNil(parser.parse(url("https://invite.example.test/i/tok/extra")), "extra segment")
        XCTAssertNil(parser.parse(url("https://invite.example.test/i/to%2Fk")), "encoded slash")
        XCTAssertNil(parser.parse(url("https://invite.example.test/i/" + String(repeating: "a", count: 257))), "too long")
    }

    func testNoConfiguredDomainAcceptsNoUniversalLinks() {
        let blocked = DeepLinkParser(configuration: AppConfiguration())
        XCTAssertNil(blocked.parse(url("https://invite.example.test/i/tok")))
        XCTAssertNil(blocked.url(for: .invite(token: "tok")))
        XCTAssertEqual(blocked.parse(url("app://camera")), .camera(groupID: nil))
    }

    // MARK: Custom scheme

    func testWidgetCameraLink() {
        XCTAssertEqual(parser.parse(url("app://camera?group=g-1")), .camera(groupID: "g-1"))
        XCTAssertEqual(parser.parse(url("APP://camera")), .camera(groupID: nil))
        XCTAssertEqual(parser.parse(url("app://camera?group=../etc")), .camera(groupID: nil), "unsafe id is dropped")
        XCTAssertEqual(parser.parse(url("app:///camera?group=g")), .camera(groupID: "g"))
        XCTAssertNil(parser.parse(url("app://unknown?group=g")))
        XCTAssertNil(parser.parse(url("other://camera?group=g")))
    }

    func testRequiredFields() {
        XCTAssertNil(parser.parse(url("app://post?group=g")))
        XCTAssertNil(parser.parse(url("app://year-story?group=g&year=abc")))
        XCTAssertNil(parser.parse(url("app://year-story?group=g&year=0")))
        XCTAssertEqual(parser.parse(url("app://birthday-request?request=r")), .birthdayRequest(requestID: "r", groupID: nil))
    }

    static let allLinks: [DeepLink] = [
        .invite(token: "tok_1"),
        .camera(groupID: nil),
        .camera(groupID: "8a6e0804-2bd0-4672-b79d-d97027f9071a"),
        .post(groupID: "g", postID: "p"),
        .chatMessage(groupID: "g", messageID: "m"),
        .dailyInvitation(groupID: "g", invitationID: "i"),
        .recap(groupID: "g", recapID: "r"),
        .birthdayRequest(requestID: "b", groupID: "g"),
        .birthdayRequest(requestID: "b", groupID: nil),
        .tribute(tributeID: "t", groupID: "g"),
        .tribute(tributeID: "t", groupID: nil),
        .yearStory(groupID: "g", year: 2026),
        .collage(groupID: "g", collageID: "c"),
    ]

    func testURLRoundTrip() throws {
        for link in Self.allLinks {
            let built = try XCTUnwrap(parser.url(for: link), "\(link)")
            XCTAssertEqual(parser.parse(built), link, built.absoluteString)
        }
        XCTAssertEqual(parser.url(for: .camera(groupID: "g1"))?.absoluteString, "app://camera?group=g1")
        XCTAssertEqual(parser.url(for: .collage(groupID: "g1", collageID: "c1"))?.absoluteString, "app://collage?group=g1&collage=c1")
        XCTAssertNil(parser.parse(URL(string: "app://collage?group=g1")!), "a collage link needs the collage")
        // Same link format as Android (android/core/model/.../DeepLink.kt).
        XCTAssertEqual(parser.url(for: .chatMessage(groupID: "g", messageID: "m"))?.absoluteString, "app://chat?group=g&message=m")
        XCTAssertEqual(parser.url(for: .dailyInvitation(groupID: "g", invitationID: "i"))?.absoluteString, "app://daily?group=g&invitation=i")
        XCTAssertEqual(parser.url(for: .yearStory(groupID: "g", year: 2026))?.absoluteString, "app://year-story?group=g&year=2026")
        XCTAssertEqual(parser.url(for: .invite(token: "abc"))?.absoluteString, "https://invite.example.test/i/abc")
    }

    // MARK: Notification payloads

    func testNotificationPayloads() {
        let cases: [([AnyHashable: Any], DeepLink)] = [
            (["type": "new_post", "group_id": "g", "post_id": "p", "aps": ["alert": "x"]], .post(groupID: "g", postID: "p")),
            (["type": "reaction", "group_id": "g", "post_id": "p"], .post(groupID: "g", postID: "p")),
            (["type": "reply", "group_id": "g", "post_id": "p", "message_id": "m"], .chatMessage(groupID: "g", messageID: "m")),
            (["type": "reply", "group_id": "g", "post_id": "p"], .post(groupID: "g", postID: "p")),
            (["type": "daily_invitation", "group_id": "g", "invitation_id": "i"], .dailyInvitation(groupID: "g", invitationID: "i")),
            (["type": "recap_ready", "group_id": "g", "recap_id": "r"], .recap(groupID: "g", recapID: "r")),
            (["type": "birthday_request", "request_id": "b"], .birthdayRequest(requestID: "b", groupID: nil)),
            (["type": "tribute", "tribute_id": "t", "group_id": "g"], .tribute(tributeID: "t", groupID: "g")),
            (["type": "year_story", "group_id": "g", "year": 2026], .yearStory(groupID: "g", year: 2026)),
            (["type": "year_story", "group_id": "g", "year": "2025"], .yearStory(groupID: "g", year: 2025)),
            // the opt-in memory notification opens its photo
            (["type": "memory", "group_id": "g", "post_id": "p"], .post(groupID: "g", postID: "p")),
            (["type": "new_post", "group_id": "g", "post_id": "p", "link": "app://chat?group=g&message=m"], .chatMessage(groupID: "g", messageID: "m")),
            (["link": "app://camera?group=g"], .camera(groupID: "g")),
        ]
        for (payload, expected) in cases {
            XCTAssertEqual(parser.parse(notificationPayload: payload), expected, "\(payload)")
        }
        XCTAssertNil(parser.parse(notificationPayload: [:]))
        XCTAssertNil(parser.parse(notificationPayload: ["type": "new_post", "group_id": "g"]))
        XCTAssertNil(parser.parse(notificationPayload: ["type": "streak_reminder"]), "unknown types are ignored")
        XCTAssertNil(parser.parse(notificationPayload: ["type": "widget", "group_id": "g"]), "widget pushes do not navigate")
        XCTAssertNil(parser.parse(notificationPayload: ["type": "new_post", "group_id": "g/..", "post_id": "p"]))
    }

    func testPayloadRoundTrip() {
        for link in Self.allLinks where link.route != nil {
            let payload: [AnyHashable: Any] = parser.payload(for: link)
            XCTAssertEqual(parser.parse(notificationPayload: payload), link)
        }
        XCTAssertEqual(parser.payload(for: .post(groupID: "g", postID: "p")), ["type": "new_post", "group_id": "g", "post_id": "p"])
    }

    func testGroupID() {
        XCTAssertEqual(DeepLink.post(groupID: "g", postID: "p").groupID, "g")
        XCTAssertNil(DeepLink.invite(token: "t").groupID)
        XCTAssertNil(DeepLink.tribute(tributeID: "t", groupID: nil).groupID)
    }
}

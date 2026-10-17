import Foundation
import XCTest
@testable import AppModels

/// `app://premium?perk=widgets&to=<route>&…`: a widget whose chosen style needs premium (design/surfaces/widget.styles.md)
/// opens the paywall once per session, then its usual destination. Same format as Android `DeepLink.Premium`.
final class DeepLinkPremiumTests: XCTestCase {
    private let parser = DeepLinkParser(universalLinkHosts: [])

    func testRoundTripsWithItsDestination() throws {
        let links: [DeepLink] = [
            .premium(perk: "widgets", then: .camera(groupID: "g1")),
            .premium(perk: "widgets", then: .camera(groupID: nil)),
            .premium(perk: "widgets", then: .collage(groupID: "g1", collageID: "c1")),
            .premium(perk: "widgets", then: .post(groupID: "g1", postID: "p1")),
            .premium(perk: "widgets", then: nil),
        ]
        for link in links {
            let url = try XCTUnwrap(parser.url(for: link))
            XCTAssertEqual(parser.parse(url), link, url.absoluteString)
        }
        XCTAssertEqual(parser.url(for: .premium(perk: "widgets", then: .camera(groupID: "g1")))?.absoluteString,
                       "app://premium?perk=widgets&to=camera&group=g1")
        XCTAssertEqual(DeepLink.premium(perk: "widgets", then: .post(groupID: "g1", postID: "p1")).groupID, "g1")
    }

    func testRejectsBadPerksAndNestedPremium() {
        XCTAssertNil(parser.parse(URL(string: "app://premium?perk=../x&to=camera")!))
        XCTAssertNil(parser.parse(URL(string: "app://premium?to=camera")!))
        XCTAssertEqual(parser.parse(URL(string: "app://premium?perk=widgets&to=premium")!), .premium(perk: "widgets", then: nil))
        XCTAssertEqual(parser.parse(URL(string: "app://premium?perk=widgets&to=post&group=g1")!), .premium(perk: "widgets", then: nil),
                       "an incomplete destination is dropped; the paywall link stays")
    }

    func testNeverFromANotification() {
        XCTAssertNil(parser.parse(notificationPayload: ["type": "widget", "perk_id": "widgets"]))
        XCTAssertEqual(parser.payload(for: .premium(perk: "widgets", then: .camera(groupID: "g1")))[PushKey.link],
                       "app://premium?perk=widgets&to=camera&group=g1")
    }
}

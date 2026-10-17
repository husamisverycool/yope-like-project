import Foundation
import XCTest
@testable import AppModels

/// Withdrawing delivered notifications of deleted photos and messages (directive Part 6: "Deleting a photo removes it
/// everywhere").
final class NotificationWithdrawalTests: XCTestCase {
    private let parser = DeepLinkParser(universalLinkHosts: ["example.test"])

    func testReadsThePostAndMessageAPayloadNames() {
        let newPost = NotificationWithdrawal.Delivered(identifier: "n1", userInfo: ["aps": [:], "type": "new_post", "group_id": "g", "post_id": "p1"], parser: parser)
        XCTAssertEqual(newPost.postIDs, ["p1"])
        XCTAssertEqual(newPost.messageIDs, [])

        let reply = NotificationWithdrawal.Delivered(identifier: "n2", userInfo: ["type": "reply", "group_id": "g", "post_id": "p2", "message_id": "m2"], parser: parser)
        XCTAssertEqual(reply.postIDs, ["p2"])
        XCTAssertEqual(reply.messageIDs, ["m2"])

        let linked = NotificationWithdrawal.Delivered(identifier: "n3", userInfo: ["link": "app://chat?group=g&message=m3"], parser: parser)
        XCTAssertEqual(linked.messageIDs, ["m3"])

        let recap = NotificationWithdrawal.Delivered(identifier: "n4", userInfo: ["type": "recap_ready", "group_id": "g", "recap_id": "r"], parser: parser)
        XCTAssertTrue(recap.postIDs.isEmpty && recap.messageIDs.isEmpty, "nothing to withdraw for a recap")

        let crafted = NotificationWithdrawal.Delivered(identifier: "n5", userInfo: ["type": "new_post", "group_id": "g", "post_id": "../x"], parser: parser)
        XCTAssertTrue(crafted.postIDs.isEmpty, "unsafe ids are ignored")
    }

    func testOnlyNotificationsOfDeletedContentAreWithdrawn() {
        let delivered = [
            NotificationWithdrawal.Delivered(identifier: "a", postIDs: ["p1"], messageIDs: []),
            NotificationWithdrawal.Delivered(identifier: "b", postIDs: ["p2"], messageIDs: []),
            NotificationWithdrawal.Delivered(identifier: "c", postIDs: [], messageIDs: ["m1"]),
            NotificationWithdrawal.Delivered(identifier: "d", postIDs: [], messageIDs: []),
        ]
        XCTAssertEqual(NotificationWithdrawal.identifiers(of: delivered, deletedPosts: ["p2"], deletedMessages: ["m1"]), ["b", "c"])
        XCTAssertEqual(NotificationWithdrawal.identifiers(of: delivered, deletedPosts: [], deletedMessages: []), [])
        XCTAssertEqual(NotificationWithdrawal.postIDs(of: delivered), ["p1", "p2"])
        XCTAssertEqual(NotificationWithdrawal.gone(shown: ["p1", "p2"], existing: ["p1"]), ["p2"])
    }
}

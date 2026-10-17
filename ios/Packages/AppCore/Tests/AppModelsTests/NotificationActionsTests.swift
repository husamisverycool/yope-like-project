import Foundation
import XCTest
@testable import AppModels

/// Notification actions (notifications.push "Actions"): which alerts offer them, what they act on, and the request each
/// becomes (same rule as Android `AlertActions`).
final class NotificationActionsTests: XCTestCase {
    func testOnlyPhotoReplyAndReactionAlertsOfferActions() {
        XCTAssertEqual(NotificationAction.actions(for: .newPost), [.reply, .react, .muteGroup])
        XCTAssertEqual(NotificationAction.actions(for: .reply), [.reply, .muteGroup])
        XCTAssertEqual(NotificationAction.actions(for: .reaction), [.reply, .muteGroup])
        // Never on the daily invitation, widget pushes, or the other alerts (the memory notification included).
        for type in PushType.allCases where ![PushType.newPost, .reply, .reaction].contains(type) {
            XCTAssertEqual(NotificationAction.actions(for: type), [], "\(type)")
        }
    }

    func testIdentifiersRoundTrip() {
        for action in NotificationAction.allCases {
            XCTAssertEqual(NotificationAction(identifier: action.identifier), action)
        }
        XCTAssertEqual(NotificationAction.muteGroup.identifier, "action.mute_group")
        XCTAssertNil(NotificationAction(identifier: "reply"))
        XCTAssertNil(NotificationAction(identifier: "com.apple.UNNotificationDefaultActionIdentifier"))
    }

    func testTargetReadsThePayload() {
        let target = NotificationActionTarget(userInfo: ["type": "new_post", "group_id": "g1", "post_id": "p1", "aps": ["category": "new_post"]])
        XCTAssertEqual(target, NotificationActionTarget(type: .newPost, groupID: "g1", postID: "p1"))
        XCTAssertNil(NotificationActionTarget(userInfo: ["type": "new_post", "post_id": "p1"]), "no group")
        XCTAssertNil(NotificationActionTarget(userInfo: ["type": "streak", "group_id": "g1"]), "unknown type")
        XCTAssertNil(NotificationActionTarget(userInfo: ["type": "new_post", "group_id": "g/.."]), "unsafe group id")
        XCTAssertNil(NotificationActionTarget(userInfo: ["type": "reply", "group_id": "g1", "message_id": "m?1"])?.messageID)
    }

    func testReplyAnswersTheMessageElseThePhoto() {
        let message = NotificationActionTarget(type: .reply, groupID: "g", postID: "p", messageID: "m")
        XCTAssertEqual(
            NotificationActionRequest.make(.reply, target: message, text: "  on my way \n"),
            .reply(groupID: "g", body: "on my way", replyToPostID: nil, replyToMessageID: "m")
        )
        let photo = NotificationActionTarget(type: .newPost, groupID: "g", postID: "p")
        XCTAssertEqual(
            NotificationActionRequest.make(.reply, target: photo, text: "so good"),
            .reply(groupID: "g", body: "so good", replyToPostID: "p", replyToMessageID: nil)
        )
        // A reaction alert names your own photo: the reply answers it in the group.
        let reaction = NotificationActionTarget(type: .reaction, groupID: "g", postID: "mine")
        XCTAssertEqual(
            NotificationActionRequest.make(.reply, target: reaction, text: "thanks"),
            .reply(groupID: "g", body: "thanks", replyToPostID: "mine", replyToMessageID: nil)
        )
        XCTAssertNil(NotificationActionRequest.make(.reply, target: photo, text: "   "), "blank text sends nothing")
        XCTAssertNil(NotificationActionRequest.make(.reply, target: photo, text: nil))
        XCTAssertNil(NotificationActionRequest.make(.reply, target: NotificationActionTarget(type: .newPost, groupID: "g"), text: "hi"), "nothing to answer")
    }

    func testReactNeedsThePhotoAndTheEmojiAndOnlyOnNewPhotos() {
        let photo = NotificationActionTarget(type: .newPost, groupID: "g", postID: "p")
        XCTAssertEqual(NotificationActionRequest.make(.react, target: photo, reaction: "🔥"), .react(postID: "p", emoji: "🔥"))
        XCTAssertNil(NotificationActionRequest.make(.react, target: photo, reaction: nil))
        XCTAssertNil(NotificationActionRequest.make(.react, target: NotificationActionTarget(type: .reaction, groupID: "g", postID: "p"), reaction: "🔥"))
    }

    func testMuteMutesTheAlertsGroup() {
        XCTAssertEqual(NotificationActionRequest.make(.muteGroup, target: NotificationActionTarget(type: .reply, groupID: "g", messageID: "m")), .muteGroup(groupID: "g"))
        XCTAssertNil(NotificationActionRequest.make(.muteGroup, target: NotificationActionTarget(type: .dailyInvitation, groupID: "g")))
        XCTAssertNil(NotificationActionRequest.make(.muteGroup, target: NotificationActionTarget(type: .memory, groupID: "g", postID: "p")))
    }
}

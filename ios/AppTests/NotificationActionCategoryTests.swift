// notifications.push "Actions": the categories PushService registers (one per push type) and the quick reaction the app
// hands it (the first emoji of chat.reactions.layout.quickReactions).
@testable import App
import AppModels
import AppServices
import DesignSystem
import UserNotifications
import XCTest

final class NotificationActionCategoryTests: XCTestCase {
    private func category(_ type: PushType, in set: Set<UNNotificationCategory>) -> UNNotificationCategory? {
        set.first { $0.identifier == type.rawValue }
    }

    func testPhotoAlertsReplyReactAndMute() throws {
        let categories = NotificationCategory.categories(quickReaction: "🔥")
        let newPost = try XCTUnwrap(category(.newPost, in: categories))
        XCTAssertEqual(newPost.actions.map(\.identifier), ["action.reply", "action.react", "action.mute_group"])
        XCTAssertEqual(newPost.actions.map(\.title), [Copy.notificationsPushActionReply, "🔥", Copy.notificationsPushActionMute])
        let reply = try XCTUnwrap(newPost.actions.first as? UNTextInputNotificationAction)
        XCTAssertEqual(reply.textInputPlaceholder, Copy.chatComposerPlaceholderReply)
        XCTAssertEqual(reply.textInputButtonTitle, Copy.chatComposerA11ySend)
        // Background actions (never `.foreground`) that need the iPhone unlocked.
        for action in newPost.actions {
            XCTAssertTrue(action.options.contains(.authenticationRequired))
            XCTAssertFalse(action.options.contains(.foreground))
        }
        XCTAssertEqual(category(.reply, in: categories)?.actions.map(\.identifier), ["action.reply", "action.mute_group"])
        XCTAssertEqual(category(.reaction, in: categories)?.actions.map(\.identifier), ["action.reply", "action.mute_group"])
    }

    func testOtherAlertsHaveCategoriesWithoutActions() {
        let categories = NotificationCategory.categories(quickReaction: "🔥")
        for type in [PushType.dailyInvitation, .recapReady, .birthdayRequest, .tribute, .yearStory, .plan, .memory] {
            XCTAssertEqual(category(type, in: categories)?.actions.count, 0, "\(type)")
        }
        // Silent pushes have no category at all.
        XCTAssertNil(category(.widget, in: categories))
        XCTAssertNil(category(.dailyInvitationEnded, in: categories))
    }

    func testNoQuickReactionLeavesTheReactionOut() {
        let newPost = NotificationCategory.categories(quickReaction: nil).first { $0.identifier == PushType.newPost.rawValue }
        XCTAssertEqual(newPost?.actions.map(\.identifier), ["action.reply", "action.mute_group"])
    }

    func testTheReactionIsTheFirstQuickReactionToken() {
        XCTAssertEqual(SocialEmoji.quick.first, "🔥")
    }

    func testFailuresUseTheCouldntSendCopy() {
        XCTAssertEqual(NotificationCategory.failureText(for: .reply), Copy.chatThreadSendFailed)
        XCTAssertEqual(NotificationCategory.failureText(for: .react), Copy.chatReactionsError)
        XCTAssertEqual(NotificationCategory.failureText(for: .muteGroup), Copy.settingsNotificationsError)
    }
}

@testable import App
import AppModels
import XCTest

final class AppRouterTests: XCTestCase {
    private let parser = DeepLinkParser(universalLinkHosts: ["invite.example.test"])

    @MainActor
    private func readyRouter() -> AppRouter {
        let router = AppRouter(parser: parser)
        router.setReady(true)
        return router
    }

    @MainActor
    func testWidgetTapOpensCameraForGroup() {
        let router = readyRouter()
        router.open(URL(string: "app://camera?group=g1")!)
        XCTAssertEqual(router.modal, .camera(groupID: "g1", invitationID: nil))
        XCTAssertTrue(router.path.isEmpty)
    }

    @MainActor
    func testNotificationRoutesBuildTheStack() {
        let router = readyRouter()
        router.handle(.post(groupID: "g", postID: "p"))
        XCTAssertEqual(router.path, [.group(id: "g"), .post(groupID: "g", postID: "p")])
        XCTAssertNil(router.modal)

        router.handle(.chatMessage(groupID: "g", messageID: "m"))
        XCTAssertEqual(router.path, [.group(id: "g"), .chat(groupID: "g", messageID: "m")])

        router.handle(.recap(groupID: "g", recapID: "r"))
        XCTAssertEqual(router.path.last, .recap(groupID: "g", recapID: "r"))

        router.handle(.yearStory(groupID: "g", year: 2026))
        XCTAssertEqual(router.path.last, .yearStory(groupID: "g", year: 2026))

        router.handle(.birthdayRequest(requestID: "b", groupID: nil))
        XCTAssertEqual(router.path, [.birthdayRequest(requestID: "b", groupID: nil)])

        router.handle(.tribute(tributeID: "t", groupID: "g"))
        XCTAssertEqual(router.path, [.tribute(tributeID: "t", groupID: "g")])
    }

    @MainActor
    func testDailyInvitationOpensCaptureOverTheGroup() {
        let router = readyRouter()
        router.handle(.dailyInvitation(groupID: "g", invitationID: "i"))
        XCTAssertEqual(router.path, [.group(id: "g")])
        XCTAssertEqual(router.modal, .camera(groupID: "g", invitationID: "i"))
    }

    @MainActor
    func testRouteDismissesModal() {
        let router = readyRouter()
        router.handle(.camera(groupID: nil))
        router.handle(.post(groupID: "g", postID: "p"))
        XCTAssertNil(router.modal)
    }

    @MainActor
    func testInviteUniversalLink() {
        let router = readyRouter()
        router.open(URL(string: "https://invite.example.test/i/tok")!)
        XCTAssertEqual(router.modal, .invite(token: "tok"))
        XCTAssertEqual(router.inviteToken, "tok")
    }

    @MainActor
    func testLinksWaitUntilReady() {
        let router = AppRouter(parser: parser)
        router.open(URL(string: "https://invite.example.test/i/tok")!)
        XCTAssertNil(router.modal)
        XCTAssertEqual(router.inviteToken, "tok", "onboarding can read the pending invite")
        router.setReady(true)
        XCTAssertEqual(router.modal, .invite(token: "tok"))
        XCTAssertNil(router.pendingLink)
    }

    @MainActor
    func testUnknownURLIsIgnored() {
        let router = readyRouter()
        router.open(URL(string: "https://elsewhere.example/i/tok")!)
        router.open(URL(string: "app://nowhere")!)
        XCTAssertNil(router.modal)
        XCTAssertTrue(router.path.isEmpty)
    }

    @MainActor
    func testNotificationPayloadToRoute() throws {
        let router = readyRouter()
        let payload: [AnyHashable: Any] = ["type": "new_post", "group_id": "g", "post_id": "p"]
        router.handle(try XCTUnwrap(parser.parse(notificationPayload: payload)))
        XCTAssertEqual(router.path, [.group(id: "g"), .post(groupID: "g", postID: "p")])
    }

    @MainActor
    func testPremiumPromptOncePerSessionAndNeverDuringCapture() {
        let router = readyRouter()
        router.startSession()
        router.handle(.camera(groupID: nil))
        XCTAssertFalse(router.consumePremiumPrompt(), "never during capture")
        router.dismissModal()
        XCTAssertTrue(router.consumePremiumPrompt())
        XCTAssertFalse(router.consumePremiumPrompt(), "once per session")
        router.startSession()
        XCTAssertTrue(router.consumePremiumPrompt())
    }

    @MainActor
    func testPremiumPromptNeverDuringOnboarding() {
        let router = AppRouter(parser: parser)
        router.startSession()
        XCTAssertFalse(router.consumePremiumPrompt())
    }
}

@testable import App
import AppModels
import XCTest

/// `app://premium?perk=widgets&to=…` (widget.styles: a widget whose chosen style needs premium): the paywall at the
/// widgets perk once per session, then the widget's own destination; for a premium member, or once the session's prompt
/// was used, the destination at once.
final class AppRouterPremiumLinkTests: XCTestCase {
    private let parser = DeepLinkParser(universalLinkHosts: [])

    @MainActor
    private func router(premium: Bool) -> AppRouter {
        let router = AppRouter(parser: parser)
        router.isPremium = { premium }
        router.startSession()
        router.setReady(true)
        return router
    }

    @MainActor
    func testLockedStyleOpensThePaywallOnceThenTheCamera() {
        let router = router(premium: false)
        router.open(URL(string: "app://premium?perk=widgets&to=camera&group=g1")!)
        XCTAssertEqual(router.modal, .account(.paywall))
        XCTAssertEqual(router.paywallPerk, "widgets", "the widgets perk's page first")
        router.dismissModal()
        XCTAssertEqual(router.modal, .camera(groupID: "g1", invitationID: nil), "the widget's own destination follows")

        router.dismissModal()
        router.open(URL(string: "app://premium?perk=widgets&to=post&group=g1&post=p1")!)
        XCTAssertNil(router.modal, "one prompt per session")
        XCTAssertEqual(router.path, [.group(id: "g1"), .post(groupID: "g1", postID: "p1")])
    }

    @MainActor
    func testPremiumMemberGoesStraightOn() {
        let router = router(premium: true)
        router.handle(.premium(perk: "widgets", then: .camera(groupID: "g1")))
        XCTAssertEqual(router.modal, .camera(groupID: "g1", invitationID: nil))
        XCTAssertNil(router.paywallPerk)
    }
}

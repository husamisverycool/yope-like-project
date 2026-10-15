// Account group — pieces that need UIKit / SwiftUI: shared component logic (two-tone titles, the invite title fit, the
// image pipeline's pixel buckets, the toast center), the legal footer links, photo picks, and the paywall presenter's
// session-prompt rule.
@testable import App
import AppData
import AppModels
import DesignSystem
import SwiftUI
import UIKit
import XCTest

@MainActor
final class AccountComponentTests: XCTestCase {
    private func jpeg() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }.jpegData(compressionQuality: 0.8) ?? Data()
    }

    // MARK: Components

    func testTwoToneTitleSplitsOnTheAccentPhrase() {
        let accented = TwoToneTitle.split("pick your friends", accent: "friends")
        XCTAssertEqual(accented.first, "pick your")
        XCTAssertEqual(accented.second, "friends")
        let halves = TwoToneTitle.split("one two three four", accent: nil)
        XCTAssertEqual(halves.first, "one two")
        XCTAssertEqual(halves.second, "three four")
        let single = TwoToneTitle.split("hello", accent: nil)
        XCTAssertEqual(single.first, "")
        XCTAssertEqual(single.second, "hello")
    }

    func testInviteTitleFitShrinksLongTitlesWithinTheTokenRange() {
        let short = InviteTitleFit.size(for: "Limas", width: 320)
        let long = InviteTitleFit.size(for: "The extended Lima family and friends of the house", width: 320)
        XCTAssertLessThanOrEqual(long, short)
        XCTAssertGreaterThanOrEqual(long, Tokens.FontSizes.inviteWebFontSizeTitleMin)
        XCTAssertLessThanOrEqual(short, max(Tokens.FontSizes.inviteWebFontSizeTitleSingleLineMax, Tokens.FontSizes.inviteWebFontSizeTitleBase))
        XCTAssertEqual(InviteTitleFit.size(for: "", width: 320), Tokens.FontSizes.inviteWebFontSizeTitleMin)
    }

    func testImagePipelineBucketsPixelSizes() {
        XCTAssertEqual(ImagePipeline.pixelBucket(1), 64)
        XCTAssertEqual(ImagePipeline.pixelBucket(64), 64)
        XCTAssertEqual(ImagePipeline.pixelBucket(65), 128)
        let image = ImagePipeline.decode(jpeg(), maxPixelSize: 16)
        XCTAssertNotNil(image)
        XCTAssertLessThanOrEqual(max(image?.size.width ?? 0, image?.size.height ?? 0) * (image?.scale ?? 1), 16)
    }

    func testToastStaysForItsDwellOrUntilTapped() async {
        let toasts = ToastCenter()
        toasts.show("done")
        XCTAssertEqual(toasts.message, "done")
        toasts.dismiss()
        XCTAssertNil(toasts.message, "a tap dismisses it")

        toasts.show("again")
        try? await Task.sleep(nanoseconds: UInt64((Tokens.Durations.safetyBlockDurationToast + 0.5) * 1_000_000_000))
        XCTAssertNil(toasts.message, "gone after safety.block.duration.toast")
    }

    // MARK: auth.phone legal footer

    func testLegalFooterLinksOnlyConfiguredURLs() throws {
        let terms = try XCTUnwrap(URL(string: "https://example.test/terms"))
        let text = PhoneModel.legalText(termsURL: terms, privacyURL: nil)
        let links = text.runs.compactMap { $0.link }
        XCTAssertEqual(links, [terms])
        XCTAssertEqual(String(text.characters), Copy.authPhoneLegalText)
    }

    // MARK: Photo picks

    func testProfilePhotoUploadsBeforeTheProfileSaves() async {
        let fixture = AccountFixture()
        let model = ProfileModel(data: fixture.data)
        model.setAvatar(imageData: jpeg())
        XCTAssertNotNil(model.avatarImage)
        model.setName("Ana")
        let saved = await model.save()
        XCTAssertTrue(saved)
        XCTAssertEqual(fixture.data.calls.suffix(2), ["uploadAvatar", "updateProfile"])
        XCTAssertNotNil(fixture.data.profilesByID[fixture.me.id]?.avatarPath)
    }

    func testProfilePhotoUploadFailureEmptiesTheAvatar() async {
        let fixture = AccountFixture()
        fixture.data.failures["uploadAvatar"] = .http(status: 500)
        let model = ProfileModel(data: fixture.data)
        model.setAvatar(imageData: jpeg())
        model.setName("Ana")
        let saved = await model.save()
        XCTAssertFalse(saved)
        XCTAssertNil(model.avatarImage)
        XCTAssertEqual(model.failureMessage, Copy.authProfileErrorUpload)
    }

    func testUnreadablePhotoIsRejected() {
        let model = ProfileModel(data: InMemoryAccountData())
        model.setAvatar(imageData: Data("not an image".utf8))
        XCTAssertNil(model.avatarImage)
        XCTAssertEqual(model.failureMessage, Copy.authProfileErrorUpload)
    }

    func testGroupCoverUploadsWithTheGroup() async {
        let fixture = AccountFixture()
        let model = GroupCreateModel(data: fixture.data)
        model.setCover(imageData: jpeg())
        XCTAssertTrue(model.hasCover)
        model.setName("Lima family")
        let group = await model.submit()
        XCTAssertNotNil(group?.coverPath)
        XCTAssertEqual(fixture.data.calls.suffix(2), ["uploadCover", "createGroup"])
    }

    // MARK: Paywall presenter

    func testLockedFeaturePromptLeavesTheCameraAndShowsOncePerSession() {
        let router = AppRouter(parser: .init(universalLinkHosts: []))
        router.setReady(true)
        router.startSession()
        let shell = ShellState(tab: .camera)
        XCTAssertTrue(ShellState.active === shell)

        XCTAssertFalse(router.presentPaywallForLockedFeature(isPremium: true), "premium members are never prompted")
        XCTAssertTrue(router.presentPaywallForLockedFeature(isPremium: false))
        XCTAssertEqual(shell.tab, .groups, "the camera closes first")
        XCTAssertEqual(router.modal, .account(.paywall))

        router.modal = nil
        XCTAssertFalse(router.presentPaywallForLockedFeature(isPremium: false), "once per session")
    }

    func testLockedFeaturePromptIsBlockedDuringOnboardingAndCapture() {
        let router = AppRouter(parser: .init(universalLinkHosts: []))
        router.startSession()
        XCTAssertFalse(router.presentPaywallForLockedFeature(isPremium: false), "not home yet")

        router.setReady(true)
        router.modal = .camera(groupID: "g1", invitationID: "i1")
        XCTAssertFalse(router.presentPaywallForLockedFeature(isPremium: false), "daily capture is on screen")
    }

    func testPaywallIsFullScreenAndAccountSheetsAreSheets() {
        XCTAssertEqual(AppModal.account(.paywall).presentation, .fullScreen)
        XCTAssertEqual(AppModal.account(.groupCreate).presentation, .sheet)
        XCTAssertEqual(AppModal.account(.groupInvite(groupID: "g")).presentation, .sheet)
        XCTAssertEqual(AppModal.account(.report(ReportTarget(kind: .post, id: "p"))).presentation, .sheet)
        XCTAssertEqual(AppModal.invite(token: "t").presentation, .sheet)
        XCTAssertEqual(AppModal.camera(groupID: nil, invitationID: nil).presentation, .tab)
        XCTAssertEqual(AppModal.camera(groupID: "g", invitationID: "i").presentation, .fullScreen)
        XCTAssertEqual(AppModal.memory(.yearStory(groupID: "g", year: 2026)).presentation, .fullScreen)
    }
}

// Account group — pieces that need UIKit / SwiftUI: shared component logic (the invite card's content and backdrop, the
// App Clip's invocation links, the image pipeline's pixel buckets, the toast center), the legal footer links, photo
// picks, the paywall presenter's session-prompt rule and the shell's presentations.
@testable import App
import AppData
import AppModels
import DesignSystem
import SwiftUI
import UIKit
import XCTest

@MainActor
final class AccountComponentTests: XCTestCase {
    /// A picked photo: a sample portrait (fixtures/photos/) as a small JPEG.
    private func jpeg() -> Data {
        SamplePhotos.jpeg(named: "avatar-01", size: CGSize(width: 40, height: 40), quality: 0.8)
    }

    // MARK: Components

    func testInviteCardShowsTheInviterTheGroupAndTheMembers() throws {
        let json = Data("""
        {"group_name":"Lima family","group_kind":"family","inviter_first_name":"Rui",
         "cover":{"url":"https://example.test/i/t/cover.jpg","width":1200,"height":900},
         "members":[{"first_name":"Ana","avatar_url":"https://example.test/i/t/avatar/0.jpg"},
                    {"first_name":"Rui","avatar_url":"https://example.test/i/t/avatar/1.jpg"},
                    {"first_name":"Teo","avatar_url":null}]}
        """.utf8)
        guard case let .valid(preview) = InvitePreviewLoader.state(status: 200, data: json) else { return XCTFail("not decoded") }
        XCTAssertEqual(preview.inviterIndex, 1, "the one member named like the inviter")
        let card = InviteCardContent.invite(preview)
        XCTAssertEqual(card.headline, Copy.inviteWebInvitedBy(firstName: "Rui"))
        XCTAssertEqual(card.line, Copy.inviteWebBody(groupName: "Lima family"))
        XCTAssertEqual(card.backdrop, .url(try XCTUnwrap(URL(string: "https://example.test/i/t/cover.jpg"))), "the cover first")
        XCTAssertEqual(card.avatar, .url(try XCTUnwrap(URL(string: "https://example.test/i/t/avatar/1.jpg"))))
        XCTAssertEqual(card.members.count, 3)
        XCTAssertNil(card.members[2], "no photo: the placeholder avatar")
        XCTAssertEqual(card.membersLabel, Copy.inviteWebMembersTitle(groupName: "Lima family"))

        let joined = InviteCardContent.invite(preview, joined: true)
        XCTAssertEqual(joined.headline, Copy.inviteAppclipJoinedTitle(groupName: "Lima family"))
        XCTAssertEqual(joined.line, Copy.inviteAppclipJoinedBody)
    }

    func testInviteCardUsesTheInvitersAvatarURL() throws {
        let json = Data(#"{"group_name":"Limas","group_kind":"friends","inviter_first_name":"Ana","inviter_avatar_url":"https://example.test/i/t/avatar/3.jpg","cover":null,"members":[{"first_name":"Ana","avatar_url":null},{"first_name":"Ana","avatar_url":null}]}"#.utf8)
        guard case let .valid(preview) = InvitePreviewLoader.state(status: 200, data: json) else { return XCTFail("not decoded") }
        let avatar = PhotoSource.url(try XCTUnwrap(URL(string: "https://example.test/i/t/avatar/3.jpg")))
        XCTAssertNil(preview.inviterIndex, "two members share the name")
        XCTAssertEqual(InviteCardContent.invite(preview).avatar, avatar, "inviter_avatar_url wins")
        XCTAssertEqual(InviteCardContent.invite(preview).backdrop, avatar, "no cover: the inviter's photo")
    }

    func testInviteCardFallsBackWithoutCoverOrInviter() {
        var preview = WebInvitePreview(
            groupName: "Limas", groupKind: nil, inviterFirstName: "Rui", cover: nil,
            members: [WebInvitePreview.Member(firstName: "Rui", avatarURL: nil, avatarPath: "avatars/rui.jpg")]
        )
        XCTAssertEqual(InviteCardContent.invite(preview).backdrop, .storage("avatars/rui.jpg"), "no cover: the inviter's photo")
        preview.inviterFirstName = nil
        let card = InviteCardContent.invite(preview)
        XCTAssertEqual(card.headline, Copy.inviteWebInvitedFallback)
        XCTAssertNil(card.backdrop, "neither: color.global.backgroundDeep")
        XCTAssertTrue(card.showsAvatar, "the placeholder circle shows")
        XCTAssertNil(card.avatar)
    }

    func testInviteStateCardsCarryTheirTitleAndExplanation() {
        let expected: [(InvitePreviewState, String, String?)] = [
            (.unavailable, Copy.inviteWebUnavailableTitle, Copy.inviteWebUnavailableBody),
            (.notFound, Copy.inviteWebNotFoundTitle, nil),
            (.rateLimited, Copy.inviteWebErrorTitle, Copy.inviteWebRateLimitedBody),
            (.error, Copy.inviteWebErrorTitle, Copy.inviteWebErrorBody),
            (.offline, Copy.inviteWebErrorTitle, Copy.inviteAppclipOfflineBody),
            (.full, Copy.inviteAppclipFullTitle, Copy.inviteAppclipFullBody),
        ]
        for (state, headline, line) in expected {
            let card = InviteCardContent.state(state)
            XCTAssertEqual(card.headline, headline, "\(state)")
            XCTAssertEqual(card.line, line, "\(state)")
            XCTAssertFalse(card.showsAvatar)
            XCTAssertNil(card.backdrop)
            XCTAssertTrue(card.members.isEmpty)
        }
    }

    func testInviteBackdropBlursToAColourField() {
        XCTAssertEqual(InviteBackdrop.sigma(width: 378), 378 * Tokens.Layouts.InviteWebLayoutBackdrop.blurSigmaToWidth, accuracy: 0.001)
        XCTAssertGreaterThan(InviteBackdrop.sigma(width: 378), Tokens.Sizes.globalBackdropBlur, "stronger than the recap's C-34 blur")
    }

    func testAppClipReadsTheTokenFromTheInviteLinkAndTheAppClipLink() throws {
        let parser = DeepLinkParser(universalLinkHosts: ["invite.example.test"])
        let invite = try XCTUnwrap(URL(string: "https://invite.example.test/i/tok_123"))
        XCTAssertEqual(InviteClipLink.token(from: invite, parser: parser), "tok_123")
        let clip = try XCTUnwrap(URL(string: "https://appclip.apple.com/id?p=com.example.app.Clip&token=tok_123"))
        XCTAssertEqual(InviteClipLink.token(from: clip, parser: parser), "tok_123")
        let noToken = try XCTUnwrap(URL(string: "https://appclip.apple.com/id?p=com.example.app.Clip"))
        XCTAssertNil(InviteClipLink.token(from: noToken, parser: parser))
        let other = try XCTUnwrap(URL(string: "https://elsewhere.test/id?token=tok_123"))
        XCTAssertNil(InviteClipLink.token(from: other, parser: parser))
    }

    func testImagePipelineBucketsPixelSizes() {
        XCTAssertEqual(ImagePipeline.pixelBucket(1), 64)
        XCTAssertEqual(ImagePipeline.pixelBucket(64), 64)
        XCTAssertEqual(ImagePipeline.pixelBucket(65), 128)
        let image = ImagePipeline.decode(jpeg(), maxPixelSize: 16)
        XCTAssertNotNil(image)
        XCTAssertLessThanOrEqual(max(image?.size.width ?? 0, image?.size.height ?? 0) * (image?.scale ?? 1), 16)
    }

    func testToastIsAnAnnouncementThatStaysUntilDismissedOrReplaced() async {
        let toasts = ToastCenter()
        XCTAssertNil(toasts.message)
        toasts.show("done")
        XCTAssertEqual(toasts.message, "done", "posted as an accessibility announcement and recorded")
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(toasts.message, "done", "iOS draws nothing, so nothing times out")
        toasts.show("again")
        XCTAssertEqual(toasts.message, "again", "the next confirmation replaces it")
        toasts.dismiss()
        XCTAssertNil(toasts.message)
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

    func testProfileNameSavesBeforeThePhotoStep() async {
        let fixture = AccountFixture()
        let model = ProfileModel(data: fixture.data)
        XCTAssertEqual(model.step, .name, "Retro's order: name first")
        model.setName("  Ana  ")
        let saved = await model.saveName()
        XCTAssertTrue(saved)
        XCTAssertEqual(fixture.data.profilesByID[fixture.me.id]?.displayName, "Ana")
        model.showPhotoStep()
        XCTAssertEqual(model.step, .photo)
    }

    func testProfileNameLongerThanTheLimitIsRefusedInline() async {
        let model = ProfileModel(data: AccountFixture().data)
        model.setName(String(repeating: "a", count: ProfileModel.maxNameLength + 1))
        XCTAssertTrue(model.isNameTooLong)
        XCTAssertFalse(model.canContinue)
        let saved = await model.saveName()
        XCTAssertFalse(saved)
    }

    func testProfilePhotoUploadsThenSavesTheAvatarPath() async {
        let fixture = AccountFixture()
        let model = ProfileModel(data: fixture.data, step: .photo)
        model.setAvatar(imageData: jpeg())
        XCTAssertNotNil(model.avatarImage)
        let saved = await model.savePhoto()
        XCTAssertTrue(saved)
        XCTAssertEqual(fixture.data.calls.suffix(2), ["uploadAvatar", "updateProfile"])
        XCTAssertNotNil(fixture.data.profilesByID[fixture.me.id]?.avatarPath)
    }

    func testProfilePhotoUploadFailureEmptiesTheAvatar() async {
        let fixture = AccountFixture()
        fixture.data.failures["uploadAvatar"] = .http(status: 500)
        let model = ProfileModel(data: fixture.data, step: .photo)
        model.setAvatar(imageData: jpeg())
        let saved = await model.savePhoto()
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

    func testPaywallIsFullScreenAccountSheetsAreSheetsAndReportIsActionSheets() {
        XCTAssertEqual(AppModal.account(.paywall).presentation, .fullScreen)
        XCTAssertEqual(AppModal.account(.groupCreate).presentation, .sheet)
        XCTAssertEqual(AppModal.account(.groupCreateKind(.family)).presentation, .sheet)
        XCTAssertEqual(AppModal.account(.groupInvite(groupID: "g")).presentation, .sheet)
        XCTAssertEqual(AppModal.account(.report(ReportTarget(kind: .post, id: "p"))).presentation, .dialog)
        XCTAssertEqual(AppModal.invite(token: "t").presentation, .sheet)
        XCTAssertEqual(AppModal.camera(groupID: nil, invitationID: nil).presentation, .tab)
        XCTAssertEqual(AppModal.camera(groupID: "g", invitationID: "i").presentation, .fullScreen)
        XCTAssertEqual(AppModal.memory(.yearStory(groupID: "g", year: 2026)).presentation, .fullScreen)
    }
}

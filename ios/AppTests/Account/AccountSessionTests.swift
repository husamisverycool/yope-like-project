// Account group — the root flow: signed out → sign-up → onboarding → home, pending links, sign-out and deletion, the
// age-gate refusal, and the home shell's tab state (RootView / AccountSession / ShellState).
@testable import App
import AppData
import AppModels
import DesignSystem
import XCTest

@MainActor
final class AccountSessionTests: XCTestCase {
    // MARK: Launch

    func testSignedOutLaunchShowsThePhoneStep() {
        let rig = AccountSessionRig()
        rig.session.start()
        XCTAssertEqual(rig.session.phase, .signUp)
        XCTAssertEqual(rig.session.root, .phone)
        XCTAssertTrue(rig.session.path.isEmpty)
        XCTAssertFalse(rig.router.isReady)
    }

    func testOnboardedLaunchWithAGroupOpensTheCameraTab() async {
        let fixture = AccountFixture()
        fixture.familyGroup()
        let rig = AccountSessionRig(data: fixture.data)
        rig.onboarding.markComplete(for: fixture.me.id.rawValue)
        rig.session.start()
        XCTAssertEqual(rig.session.phase, .launching, "LaunchingView until the group check answers")
        XCTAssertFalse(rig.router.isReady)
        await waitUntil { rig.session.phase == .ready }
        XCTAssertTrue(rig.router.isReady)
        XCTAssertEqual(rig.shell.tab, .camera, "owner decision 13: with a group the app opens to the camera")
    }

    func testOnboardedLaunchWithoutGroupsOpensTheGroupsList() async {
        let fixture = AccountFixture()
        let rig = AccountSessionRig(data: fixture.data)
        rig.onboarding.markComplete(for: fixture.me.id.rawValue)
        rig.session.start()
        await waitUntil { rig.session.phase == .ready }
        XCTAssertEqual(rig.shell.tab, .groups, "owner decision 13: no group → the groups list (Ideas to Get Started)")
        XCTAssertTrue(fixture.data.calls.contains("myGroups"), "nothing cached: the first fetch answers")
    }

    func testOfflineLaunchWithNothingCachedOpensTheGroupsList() async {
        let fixture = AccountFixture()
        fixture.familyGroup()
        fixture.data.failures["myGroups"] = .offline
        let rig = AccountSessionRig(data: fixture.data)
        rig.onboarding.markComplete(for: fixture.me.id.rawValue)
        rig.session.start()
        await waitUntil { rig.session.phase == .ready }
        XCTAssertEqual(rig.shell.tab, .groups, "unknown groups count as none: the list shows its offline state")
    }

    func testSignOutDuringTheLaunchCheckLeavesTheSignUpStack() async {
        let fixture = AccountFixture()
        fixture.familyGroup()
        fixture.data.latency = .milliseconds(200)
        let rig = AccountSessionRig(data: fixture.data)
        rig.onboarding.markComplete(for: fixture.me.id.rawValue)
        rig.session.start()
        await rig.session.signOut()
        try? await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(rig.session.phase, .signUp, "the late answer does not take the person home")
        XCTAssertFalse(rig.router.isReady)
    }

    func testPendingLinkAtLaunchLandsOnGroupsAndIsApplied() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup()
        let rig = AccountSessionRig(data: fixture.data)
        rig.onboarding.markComplete(for: fixture.me.id.rawValue)
        rig.router.handle(.post(groupID: group.id.rawValue, postID: "p1"))
        XCTAssertNotNil(rig.router.pendingLink, "held until the person is home")
        rig.session.start()
        await waitUntil { rig.session.phase == .ready }
        XCTAssertEqual(rig.shell.tab, .groups)
        XCTAssertNil(rig.router.pendingLink)
        XCTAssertEqual(rig.router.path, [.group(id: group.id.rawValue), .post(groupID: group.id.rawValue, postID: "p1")])
    }

    func testSignedInButNotOnboardedResumesAtTheFirstMissingStep() async {
        let data = InMemoryAccountData()
        let me = data.addProfile("")
        data.currentUserID = me.id
        let rig = AccountSessionRig(data: data)
        rig.session.start()
        XCTAssertEqual(rig.session.phase, .signUp)
        await waitUntil { rig.session.root == .ageGate }

        data.privateProfile = ProfilePrivate(userID: me.id, birthday: nil, birthdayOptIn: false, ageConfirmedAt: Date(), updatedAt: Date())
        await rig.session.resolve(me.id)
        XCTAssertEqual(rig.session.root, .profile, "age confirmed, empty display name")

        _ = try? await data.updateProfile(displayName: "Ana", avatarPath: nil)
        await rig.session.resolve(me.id)
        XCTAssertEqual(rig.session.phase, .ready)
    }

    func testResolveFailureOffersRetry() async {
        let data = InMemoryAccountData()
        let me = data.addProfile("")
        data.currentUserID = me.id
        data.failures["myPrivateProfile"] = .offline
        let rig = AccountSessionRig(data: data)
        await rig.session.resolve(me.id)
        XCTAssertEqual(rig.session.root, .resolveFailed)

        data.failures = [:]
        rig.session.retryResolve()
        await waitUntil { rig.session.root == .ageGate }
    }

    // MARK: Sign-up → onboarding → home

    func testNewAccountWalksEveryStepThenGoesHome() async throws {
        let rig = AccountSessionRig(notificationStatus: .notDetermined)
        rig.session.start()
        rig.session.codeSent(phone: "+15551234567", at: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(rig.session.path, [.code(phone: "+15551234567", sentAt: Date(timeIntervalSince1970: 0))])

        let user = try await rig.data.verifyCode(phone: "+15551234567", code: InMemoryAccountData.validCode)
        await rig.session.didVerify(user)
        XCTAssertEqual(rig.session.path.last, .ageGate)

        rig.session.ageConfirmed()
        XCTAssertEqual(rig.session.path.last, .profile)

        await rig.session.profileSaved()
        XCTAssertEqual(rig.session.path.last, .notifications, "the system has not asked yet")

        rig.session.notificationsAnswered()
        XCTAssertEqual(rig.session.path.last, .widget)
        XCTAssertFalse(rig.router.isReady)

        rig.session.finishOnboarding()
        XCTAssertEqual(rig.session.phase, .ready)
        XCTAssertTrue(rig.session.path.isEmpty)
        XCTAssertTrue(rig.router.isReady)
        XCTAssertEqual(rig.shell.tab, .groups, "after onboarding: groups.list (onboarding.widget Out)")
        XCTAssertTrue(rig.onboarding.isComplete(for: user.rawValue))
    }

    func testNotificationsStepIsSkippedWhenTheSystemAlreadyAsked() async {
        let rig = AccountSessionRig(notificationStatus: .denied)
        rig.session.start()
        await rig.session.profileSaved()
        XCTAssertEqual(rig.session.path.last, .widget)
    }

    func testReturningAccountGoesStraightHome() async {
        let fixture = AccountFixture()
        let rig = AccountSessionRig(data: fixture.data)
        rig.session.start()
        await waitUntil { rig.session.phase == .ready }
        XCTAssertEqual(rig.shell.tab, .groups)
    }

    func testInviteOpenedBeforeSignUpJoinsRightAfterOnboarding() async throws {
        let rig = AccountSessionRig()
        rig.router.handle(.invite(token: "tok1"))
        rig.session.start()
        let user = try await rig.data.verifyCode(phone: "+15551234567", code: InMemoryAccountData.validCode)
        await rig.session.didVerify(user)
        rig.session.finishOnboarding()
        XCTAssertEqual(rig.router.modal, .invite(token: "tok1"))
        XCTAssertTrue(rig.session.consumeAutoJoin(token: "tok1"))
        XCTAssertFalse(rig.session.consumeAutoJoin(token: "tok1"), "only once")
    }

    func testAppClipHandoffBecomesThePendingInvite() {
        let rig = AccountSessionRig()
        rig.session.start(handoff: InviteHandoff(token: "clip-token", joinedGroupID: nil))
        XCTAssertEqual(rig.router.inviteToken, "clip-token")
    }

    // MARK: Age gate refusal

    func testUnderAgeRefusalIsRememberedAndDeletesTheAccount() async {
        let fixture = AccountFixture()
        let rig = AccountSessionRig(data: fixture.data)
        rig.session.start()
        await rig.session.refuseUnderAge(minAge: 13)
        XCTAssertEqual(rig.session.phase, .refused)
        XCTAssertEqual(rig.session.refusalMinAge, 13)
        XCTAssertEqual(rig.refusals.refusal, 13)
        XCTAssertTrue(fixture.data.calls.contains("deleteAccount"))
        XCTAssertFalse(rig.router.isReady)

        // A relaunch (same device) shows the refusal again.
        let again = AccountSession(
            data: InMemoryAccountData(), router: AppRouter(parser: .init(universalLinkHosts: [])), refusals: rig.refusals,
            onboarding: rig.onboarding, notifications: rig.notifications, toasts: ToastCenter(), shell: ShellState()
        )
        again.start()
        XCTAssertEqual(again.phase, .refused)
    }

    func testRefusalFallsBackToSignOutWhenDeletionFails() async {
        let fixture = AccountFixture()
        fixture.data.failures["deleteAccount"] = .offline
        let rig = AccountSessionRig(data: fixture.data)
        await rig.session.refuseUnderAge(minAge: nil)
        XCTAssertEqual(rig.session.phase, .refused)
        XCTAssertNil(rig.session.refusalMinAge)
        XCTAssertTrue(fixture.data.calls.contains("signOut"))
    }

    // MARK: Leaving

    func testSignOutReturnsToThePhoneStep() async {
        let fixture = AccountFixture()
        let rig = AccountSessionRig(data: fixture.data)
        rig.onboarding.markComplete(for: fixture.me.id.rawValue)
        rig.session.start()
        await rig.session.signOut()
        XCTAssertEqual(rig.session.phase, .signUp)
        XCTAssertEqual(rig.session.root, .phone)
        XCTAssertFalse(rig.router.isReady)
    }

    /// The phone step must not keep the previous person's number: every ended session gives the sign-up flow a new
    /// identity (AuthFlowView `.id`), so auth.phone starts on its landing with an empty field.
    func testEndedSessionsStartAFreshSignUp() async {
        let fixture = AccountFixture()
        let rig = AccountSessionRig(data: fixture.data)
        rig.onboarding.markComplete(for: fixture.me.id.rawValue)
        rig.session.start()
        let first = rig.session.signUpGeneration
        await rig.session.signOut()
        XCTAssertEqual(rig.session.signUpGeneration, first + 1, "sign-out")
        XCTAssertTrue(rig.session.path.isEmpty, "no code step holding the number")
        rig.session.accountDeleted()
        XCTAssertEqual(rig.session.signUpGeneration, first + 2, "account deletion")
    }

    func testAccountDeletedShowsTheToastOnThePhoneStep() {
        let fixture = AccountFixture()
        let rig = AccountSessionRig(data: fixture.data)
        rig.onboarding.markComplete(for: fixture.me.id.rawValue)
        rig.session.start()
        rig.session.accountDeleted()
        XCTAssertEqual(rig.session.root, .phone)
        XCTAssertEqual(rig.toasts.message, Copy.settingsAccountDeletedToast)
    }

    func testExpiredSessionWhileHomeReturnsToSignUp() async {
        let fixture = AccountFixture()
        let rig = AccountSessionRig(data: fixture.data)
        rig.onboarding.markComplete(for: fixture.me.id.rawValue)
        rig.session.start()
        fixture.data.setAuth(.signedOut)
        await waitUntil { rig.session.phase == .signUp }
    }

    // MARK: Shell

    func testShellCameraAndGroupsTabs() {
        var prewarms = 0
        let shell = ShellState(tab: .groups) { prewarms += 1 }
        shell.showCamera(groupID: "g1")
        XCTAssertEqual(shell.tab, .camera)
        XCTAssertEqual(shell.cameraGroupID, "g1")
        XCTAssertEqual(prewarms, 1, "the capture session starts before the camera shows")
        shell.leaveCamera()
        XCTAssertEqual(shell.tab, .groups)
        XCTAssertNil(shell.cameraGroupID)
        shell.leaveCamera()
        XCTAssertEqual(shell.tab, .groups)
    }

    func testLinkedMemoryRoutesArePresentedPerTheirSpecs() {
        let router = AppRouter(parser: .init(universalLinkHosts: []))
        let shell = ShellState()

        router.path = [.group(id: "g1"), .yearStory(groupID: "g1", year: 2026)]
        XCTAssertTrue(shell.presentModalRoute(router: router))
        XCTAssertEqual(router.path, [.group(id: "g1")])
        XCTAssertEqual(router.modal, .memory(.yearStory(groupID: "g1", year: 2026)), "year.story: full-screen modal")

        router.modal = nil
        router.path = [.birthdayRequest(requestID: "r1", groupID: "g1")]
        XCTAssertTrue(shell.presentModalRoute(router: router))
        XCTAssertTrue(router.path.isEmpty)
        XCTAssertEqual(shell.presentedRoute, PresentedRoute(route: .birthdayRequest(requestID: "r1", groupID: "g1"), style: .fullScreen))

        router.path = [.tribute(tributeID: "t1", groupID: nil)]
        XCTAssertTrue(shell.presentModalRoute(router: router))
        XCTAssertEqual(shell.presentedRoute?.style, .fullScreen)

        router.path = [.capture(.collage(groupID: "g1", invitationID: "i1"))]
        XCTAssertTrue(shell.presentModalRoute(router: router))
        XCTAssertEqual(shell.presentedRoute?.style, .fullScreen, "collage.view: a media cover")

        router.path = [.group(id: "g1"), .recap(groupID: "g1", recapID: "r1")]
        XCTAssertTrue(shell.presentModalRoute(router: router))
        XCTAssertEqual(router.path, [.group(id: "g1")], "the recap preview covers its group")
        XCTAssertEqual(shell.presentedRoute, PresentedRoute(route: .recap(groupID: "g1", recapID: "r1"), style: .fullScreen))

        router.path = [.account(.groupSettings(groupID: "g1"))]
        XCTAssertTrue(shell.presentModalRoute(router: router))
        XCTAssertEqual(shell.presentedRoute?.style, .sheet, "groups.settings: a page sheet")

        router.path = [.group(id: "g1"), .memory(.onThisDay(groupID: "g1"))]
        XCTAssertFalse(shell.presentModalRoute(router: router), "onthisday is pushed in the group's stack")
        XCTAssertEqual(router.path, [.group(id: "g1"), .memory(.onThisDay(groupID: "g1"))])
        XCTAssertNil(router.modal)

        router.path = [.group(id: "g1")]
        XCTAssertFalse(shell.presentModalRoute(router: router), "ordinary routes stay pushed")
        XCTAssertEqual(router.path, [.group(id: "g1")])
    }

    func testCrossGroupRoutesPointAtTheOtherPassesScreens() {
        XCTAssertEqual(CrossGroupRoutes.wallsMine, .social(.wallMine))
        XCTAssertEqual(CrossGroupRoutes.wallsBrowse(groupID: nil), .social(.wallsBrowse(groupID: nil)))
        XCTAssertEqual(CrossGroupRoutes.wallMember(userID: "u1"), .social(.wallMember(userID: "u1")))
        XCTAssertEqual(CrossGroupRoutes.weekHistory(groupID: "g1"), .social(.weekHistory(groupID: "g1")))
        XCTAssertEqual(CrossGroupRoutes.birthdayAdd, .memory(.birthdayAdd))
    }

    // MARK: UI-test scenarios

    func testUITestScenariosParseAndSeed() {
        XCTAssertEqual(AccountUITestScenario.fromLaunchArguments(["App", "-account-ui-test-scenario", "with-groups"]), .withGroups)
        XCTAssertNil(AccountUITestScenario.fromLaunchArguments(["App"]))
        XCTAssertNil(AccountUITestScenario.signedOut.makeData().currentUserID)
        XCTAssertNotNil(AccountUITestScenario.signedIn.makeData().currentUserID)
        XCTAssertEqual(AccountUITestScenario.withGroups.makeData().groups.count, 2)
    }

    // MARK: Files of an ended session

    func testSessionFilesRemovesEverythingInTheFolder() throws {
        let fileManager = FileManager.default
        let folder = fileManager.temporaryDirectory.appendingPathComponent("SessionFilesTest-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let drafts = folder.appendingPathComponent("CaptureDrafts", isDirectory: true)
        try fileManager.createDirectory(at: drafts, withIntermediateDirectories: true)
        try Data("photo".utf8).write(to: drafts.appendingPathComponent("original.jpg"))
        try Data("voice".utf8).write(to: folder.appendingPathComponent("voice-note.m4a"))
        SessionFiles.removeContents(of: folder)
        XCTAssertEqual(try fileManager.contentsOfDirectory(atPath: folder.path), [])
        XCTAssertTrue(fileManager.fileExists(atPath: folder.path), "the folder itself stays")
    }
}

// camera.overnight (design/surfaces/camera.overnight.md, part A; docs/API.md §14.3): the mode control, the destination
// choice and its pill, the 9 AM shutter (no preview, upload queue), the reveal rule and texts, and the settings switch.
@testable import App
import AppData
import AppModels
import DesignSystem
import Foundation
import XCTest

@MainActor
final class CaptureOvernightTests: XCTestCase {
    override func setUp() async throws {
        CameraCaptureModel.sessionPosition = .back
        OvernightCaptureModel.resetSession()
    }

    override func tearDown() async throws {
        OvernightCaptureModel.resetSession()
    }

    /// A rig in 9 AM mode with its groups chosen and the sheet closed.
    private func laterModel(_ rig: CaptureTestRig, contextGroupID: String? = nil) async -> OvernightCaptureModel {
        let model = rig.overnightModel(contextGroupID: contextGroupID)
        model.setMode(.later)
        await model.loadGroups()
        model.destinationClosed()
        return model
    }

    // MARK: Mode and destination

    func testNowByDefaultAndTheFirstNineAMOpensTheSheetOncePerSession() async {
        let rig = CaptureTestRig()
        let model = rig.overnightModel()
        XCTAssertEqual(model.mode, .now, "ON-1: Now at every launch")
        XCTAssertEqual(model.title(of: .now), Copy.cameraOvernightModeNow)
        XCTAssertEqual(model.title(of: .later), Copy.cameraOvernightModeLater(time: OvernightReveal.timeText()))

        model.setMode(.later)
        XCTAssertTrue(model.isDestinationOpen, "the first switch to 9 AM in a session opens the destination sheet")
        await model.loadGroups()
        XCTAssertEqual(model.selection, CaptureFakes.groups.map(\.id), "every group selected (owner decision 11)")
        model.destinationClosed()
        XCTAssertTrue(model.isLater)

        model.setMode(.now)
        model.setMode(.later)
        XCTAssertFalse(model.isDestinationOpen, "only the first time in a session")
        let reopened = rig.overnightModel()
        XCTAssertEqual(reopened.mode, .later, "the choice is kept while the app stays in memory")
        XCTAssertEqual(reopened.selection, CaptureFakes.groups.map(\.id), "the groups are kept for the session")
    }

    func testPillNamesOneGroupAllOrSomeNeverANumber() async {
        let rig = CaptureTestRig()
        rig.groups.groups = CaptureFakes.groups + [CaptureGroup(id: "fake-group-3", name: "Group 3", coverPath: nil)]
        let model = await laterModel(rig)
        XCTAssertEqual(model.pillLabel, Copy.cameraOvernightDestinationAll)
        model.toggle("fake-group-3")
        XCTAssertEqual(model.pillLabel, Copy.cameraOvernightDestinationSome)
        model.toggle("fake-group-2")
        XCTAssertEqual(model.pillLabel, Copy.cameraOvernightDestinationOne(group: "Group 1"))
        XCTAssertEqual(model.selectionChanges, 2, "haptic.global.select per toggle")
        XCTAssertFalse(Copy.cameraOvernightDestinationSome.contains(where: \.isNumber))
        XCTAssertFalse(Copy.cameraOvernightDestinationAll.contains(where: \.isNumber))
    }

    func testDoneWithNothingSelectedGoesBackToNow() async {
        let rig = CaptureTestRig()
        let model = rig.overnightModel()
        model.setMode(.later)
        await model.loadGroups()
        for group in CaptureFakes.groups { model.toggle(group.id) }
        model.destinationClosed()
        XCTAssertEqual(model.mode, .now)
        XCTAssertEqual(OvernightCaptureModel.sessionMode, .now)
    }

    func testTheContextGroupIsPreselectedAndNoGroupsShowsTheEmptyState() async {
        let rig = CaptureTestRig()
        let model = await laterModel(rig, contextGroupID: "fake-group-2")
        XCTAssertEqual(model.selection, ["fake-group-2"], "as camera.sendto: the group the camera was opened from")

        OvernightCaptureModel.resetSession()
        let empty = CaptureTestRig()
        empty.groups.groups = []
        let none = empty.overnightModel()
        none.setMode(.later)
        await none.loadGroups()
        XCTAssertEqual(none.listState, .empty)
        none.destinationClosed()
        XCTAssertEqual(none.mode, .now, "no group to develop for")
    }

    // MARK: Shutter in 9 AM mode

    func testNineAMShutterQueuesThePhotoWithoutPreviewAndAnnouncesTheReveal() async {
        let rig = CaptureTestRig()
        rig.usePhotos()
        let overnight = await laterModel(rig)
        OvernightCaptureModel.sessionMode = .later
        let camera = rig.cameraModel()
        await camera.appear()
        XCTAssertTrue(camera.overnight?.isLater ?? false)

        await camera.takePhoto()
        XCTAssertNil(camera.captured, "no preview and no camera.sendto in 9 AM mode")
        XCTAssertEqual(rig.camera.stillRequests, 1, "photo only: no Live Photo motion")
        let sent = await captureEventually { rig.posting.published.count == 1 }
        XCTAssertTrue(sent)
        let draft = rig.posting.published.first
        XCTAssertEqual(draft?.overnight, true, "create_overnight_post")
        XCTAssertEqual(draft?.kind, .photo)
        XCTAssertNil(draft?.motion)
        XCTAssertNil(draft?.caption)
        XCTAssertEqual(draft?.groupIDs.map(\.rawValue), overnight.selection)
        XCTAssertEqual(rig.library.saved.count, 0, "never written to the photo library before the reveal")
        let announced = Copy.cameraOvernightA11yCaptured(reveal: OvernightReveal.revealText(OvernightReveal.next(after: CaptureTestRig.fixedNow, timeZones: [.current])))
        XCTAssertEqual(rig.announcements.first, announced)
        let developing = await captureEventually { camera.overnight?.developing.developing == true }
        XCTAssertTrue(developing, "my_developing() read again after the photo is queued")
        XCTAssertEqual(camera.phase, .live, "the camera stays ready for the next photo")
    }

    func testHoldingTheShutterInNineAMDoesNothing() async {
        let rig = CaptureTestRig()
        rig.premium.premium = true
        _ = await laterModel(rig)
        let camera = rig.cameraModel()
        await camera.appear()
        camera.shutterTouchDown()
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertFalse(rig.camera.isRecording, "hold-to-record is off in 9 AM mode")
        camera.shutterTouchUp()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(rig.camera.stillRequests, 0, "spec: tap = photo, hold = nothing")
        XCTAssertTrue(rig.posting.published.isEmpty)
        XCTAssertEqual(rig.premium.promptRequests, 0, "no paywall either")
    }

    func testShutterWithNoGroupChosenOpensTheSheet() async {
        let rig = CaptureTestRig()
        OvernightCaptureModel.sessionMode = .later
        OvernightCaptureModel.sessionSelection = []
        OvernightCaptureModel.didOpenDestinationThisSession = true
        let camera = rig.cameraModel()
        await camera.appear()
        await camera.takePhoto()
        XCTAssertTrue(camera.overnight?.isDestinationOpen ?? false)
        XCTAssertEqual(rig.camera.stillRequests, 0)
    }

    // MARK: Upload queue (`camera.overnight.layout.uploadQueue`)

    func testOfflineWaitsSilentlyAndARefusalIsAnnounced() async {
        let rig = CaptureTestRig()
        let still = CaptureTestImages.still()

        rig.posting.publishError = .offline
        let offline = await rig.overnightQueue.enqueue(still, groupIDs: ["fake-group-1"], capturedAt: Date()).value
        XCTAssertEqual(offline, .waiting, "kept in the outbox; uploads when the connection returns")
        XCTAssertTrue(rig.announcements.isEmpty, "nothing extra while offline")
        XCTAssertTrue(rig.posting.discarded.isEmpty)

        rig.posting.publishError = .api(.mediaNotFound)
        let refused = await rig.overnightQueue.enqueue(still, groupIDs: ["fake-group-1"], capturedAt: Date()).value
        XCTAssertEqual(refused, .failed)
        XCTAssertEqual(rig.announcements, [Copy.cameraSendtoErrorSendFailed])
        XCTAssertEqual(rig.posting.discarded.count, 1)
        XCTAssertEqual(rig.overnightQueue.inFlight, 0)
    }

    func testDraftsFromNineAMArePhotosToDevelop() async throws {
        let still = CaptureTestImages.still()
        let request = CaptureSendRequest(payload: .media(.photo(still, capturedAt: Date())), groupIDs: ["fake-group-1"], overnight: true)
        let draft = try await CaptureDraftBuilder.build(request)
        CaptureDraftBuilder.cleanUp(request)
        XCTAssertEqual(draft.overnight, true)
        XCTAssertEqual(draft.kind, .photo)
        let normal = CaptureSendRequest(payload: .media(.photo(still, capturedAt: Date())), groupIDs: ["fake-group-1"])
        let posted = try await CaptureDraftBuilder.build(normal)
        CaptureDraftBuilder.cleanUp(normal)
        XCTAssertNil(posted.overnight)
    }

    // MARK: Reveal (`camera.overnight.layout.reveal`)

    func testRevealIsTheFirstNineAfterCaptureInEachGroupsZone() throws {
        let paris = try XCTUnwrap(TimeZone(identifier: "Europe/Paris"))
        let tokyo = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = paris
        let early = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 8, minute: 59)))
        let sameDay = OvernightReveal.next(after: early, timeZones: [paris])
        XCTAssertEqual(calendar.dateComponents([.day, .hour, .minute], from: sameDay), DateComponents(day: 16, hour: 9, minute: 0))
        let late = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 9, minute: 0)))
        let nextDay = OvernightReveal.next(after: late, timeZones: [paris])
        XCTAssertEqual(calendar.dateComponents([.day, .hour], from: nextDay), DateComponents(day: 17, hour: 9))
        // Daylight saving ends in Paris on 25 Oct 2026: still 09:00 on the wall clock.
        let beforeChange = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 22)))
        let afterChange = OvernightReveal.next(after: beforeChange, timeZones: [paris])
        XCTAssertEqual(calendar.dateComponents([.day, .hour], from: afterChange), DateComponents(day: 25, hour: 9))
        // Two groups in two zones: the earliest of their reveals.
        let both = OvernightReveal.next(after: late, timeZones: [paris, tokyo])
        XCTAssertEqual(both, min(OvernightReveal.next(after: late, timeZones: [tokyo]), nextDay))
    }

    func testTimeAndRevealTextsAreThePlatformsFormats() {
        let english = Locale(identifier: "en_US")
        XCTAssertTrue(OvernightReveal.timeText(locale: english).contains("9:00"))
        let german = OvernightReveal.timeText(locale: Locale(identifier: "de_DE"))
        XCTAssertTrue(german.hasSuffix("9:00") && !german.contains("AM"), "the locale's 24-hour short time: \(german)")
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        XCTAssertTrue(OvernightReveal.revealText(tomorrow, locale: english).lowercased().hasPrefix("tomorrow"), "the relative day")
    }

    // MARK: Reveal push (`camera.overnight.layout.push`)

    func testAPushOpensTheViewerOnThePhotosRevealedTogether() async {
        let data = SocialDemo.makeData()
        let reveal = SocialDemo.at(3 * SocialDemo.day)
        data.update { state in
            // Ana's and my photos revealed together; the same photo in "climbing" revealed there too (another group).
            for index in state.posts.indices where [SocialDemo.p2, SocialDemo.p3, SocialDemo.p3b].contains(state.posts[index].id) {
                state.posts[index].post.revealedAt = reveal
            }
        }
        let link = { (start: PostID) in
            PhotoViewerModel(
                context: PhotoViewerContext(postIDs: [start], start: start, groupID: SocialDemo.groupID, opensReveal: true), data: data
            )
        }
        let first = link(SocialDemo.p2)
        await first.load()
        XCTAssertEqual(first.postIDs, [SocialDemo.p2, SocialDemo.p3], "oldest first, this group only")
        XCTAssertEqual(first.selection, SocialDemo.p2)
        XCTAssertEqual(first.position?.index, 1)
        XCTAssertEqual(first.position?.total, 2, "the viewer's position badge")

        let second = link(SocialDemo.p3)
        await second.load()
        XCTAssertEqual(second.selection, SocialDemo.p3, "the linked photo stays selected")
        XCTAssertEqual(second.position?.index, 2)

        let shared = link(SocialDemo.p1)
        await shared.load()
        XCTAssertEqual(shared.postIDs, [SocialDemo.p1], "a photo shared at once opens alone")

        let fromWall = PhotoViewerModel(
            context: PhotoViewerContext(postIDs: [SocialDemo.p2], start: SocialDemo.p2, groupID: SocialDemo.groupID), data: data
        )
        await fromWall.load()
        XCTAssertEqual(fromWall.postIDs, [SocialDemo.p2], "only links expand")

        data.update { $0.failOnce.insert("revealedWith") }
        let offline = link(SocialDemo.p2)
        await offline.load()
        XCTAssertEqual(offline.postIDs, [SocialDemo.p2], "a failure keeps the one photo")
        XCTAssertEqual(offline.phase, .ready)
    }

    // MARK: settings.notifications switch

    func testOvernightAlertsSwitchIsOnByDefaultAndRollsBack() async {
        let fixture = AccountFixture()
        let model = SettingsNotificationsModel(data: fixture.data, notifications: StaticNotificationAuthorizer(status: .granted))
        await model.load()
        XCTAssertTrue(model.overnightOn, "default on (no settings row)")
        await model.setOvernightAlerts(false)
        XCTAssertFalse(model.overnightOn)
        XCTAssertEqual(fixture.data.settings?.overnight, false)

        fixture.data.failures["setOvernightAlerts"] = .offline
        await model.setOvernightAlerts(true)
        XCTAssertFalse(model.overnightOn, "reverted")
        XCTAssertEqual(model.alertMessage, Copy.settingsNotificationsError)
        XCTAssertFalse(Copy.cameraOvernightSettingsRowDetail(time: OvernightReveal.timeText()).isEmpty)
    }
}

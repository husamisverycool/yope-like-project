// Several photos in one post, the day a library photo was taken, and "Share to Jolt" (docs/RESEARCH_FEATURES_2026-10-17.md
// #1, #5, #4; design/surfaces/camera.sendto.md "Several photos", camera.capture.md, share.in.md).
@testable import App
import AppData
import AppModels
import AppServices
import DesignSystem
import SwiftUI
import XCTest

@MainActor
final class CaptureBatchTests: XCTestCase {
    private func photo(_ color: Color = Tokens.Colors.globalAccent, takenOn: String? = nil) -> CapturedMedia {
        .photo(CaptureFakes.still(color), capturedAt: Date(), takenOn: takenOn.flatMap { LocalDate($0) })
    }

    // MARK: Send-to with a selection

    func testASelectionPostsEachPhotoInOrderWithOneBatchIDAndTheMessageOnTheFirst() async {
        let rig = CaptureTestRig()
        var sent = 0
        let first = photo(takenOn: "2026-09-01")
        let second = photo(takenOn: "2026-09-02")
        let third = photo(takenOn: "2026-09-03")
        let model = rig.sendToModel(media: first, more: [second, third], contextGroupID: "fake-group-1", onSent: { sent += 1 })
        await model.load()
        XCTAssertTrue(model.showsSelection)
        XCTAssertEqual(model.items.map(\.id), [first.id, second.id, third.id])
        model.caption = "the weekend"
        await model.send()

        let drafts = rig.posting.published
        XCTAssertEqual(drafts.count, 3, "each photo is its own post")
        XCTAssertEqual(drafts.map(\.takenOn), [LocalDate("2026-09-01"), LocalDate("2026-09-02"), LocalDate("2026-09-03")], "in the order picked")
        let batch = drafts.first?.batchID
        XCTAssertNotNil(batch)
        XCTAssertEqual(Set(drafts.map(\.batchID)), [batch], "one batch id for the whole selection")
        XCTAssertEqual(drafts.map(\.caption), ["the weekend", nil, nil], "the message goes with the first photo only")
        XCTAssertEqual(Set(drafts.flatMap(\.groupIDs)), [GroupID("fake-group-1")])
        XCTAssertEqual(rig.haptics, [Tokens.Haptics.globalSend], "one confirmation for the selection")
        XCTAssertEqual(sent, 1)
    }

    func testOnePhotoHasNoBatchAndACameraPhotoNoDay() async {
        let rig = CaptureTestRig()
        let model = rig.sendToModel(contextGroupID: "fake-group-1")
        await model.load()
        XCTAssertFalse(model.showsSelection, "no strip for one photo")
        await model.send()
        XCTAssertEqual(rig.posting.published.count, 1)
        XCTAssertNil(rig.posting.published.first?.batchID)
        XCTAssertNil(rig.posting.published.first?.takenOn)
    }

    func testAFailedPhotoOfASelectionKeepsTheRestAndTryAgainSendsOnlyThose() async {
        let rig = CaptureTestRig()
        var sent = 0
        let model = rig.sendToModel(media: photo(), more: [photo(), photo()], contextGroupID: "fake-group-1", onSent: { sent += 1 })
        await model.load()
        model.caption = "hi"
        rig.posting.publishError = .offline
        rig.posting.publishErrorAfter = 1
        await model.send()
        XCTAssertEqual(rig.posting.published.count, 1)
        XCTAssertEqual(model.sendFailure, .offline)
        XCTAssertEqual(model.postedItemIDs, [model.items[0].id])
        XCTAssertEqual(sent, 0, "the composer stays open")

        rig.posting.publishError = nil
        await model.retrySend()
        let drafts = rig.posting.published
        XCTAssertEqual(drafts.count, 3, "the posted photo is not sent again")
        XCTAssertEqual(Set(drafts.map(\.mediaID)).count, 3)
        XCTAssertEqual(drafts.map(\.caption), ["hi", nil, nil])
        XCTAssertEqual(Set(drafts.map(\.batchID)).count, 1, "Try Again keeps the selection's batch id")
        XCTAssertEqual(sent, 1)
    }

    func testASelectionWithAVideoNeedsPremium() async {
        let rig = CaptureTestRig()
        let video = CapturedMedia.video(CaptureVideo(fileURL: URL(fileURLWithPath: "/tmp/v.mov"), durationMs: 3000), capturedAt: Date())
        let model = rig.sendToModel(media: photo(), more: [video], contextGroupID: "fake-group-1")
        await model.load()
        XCTAssertFalse(model.canSend, "free member: a video in the selection keeps Send disabled")
        rig.premium.premium = true
        let premium = rig.sendToModel(media: photo(), more: [video], contextGroupID: "fake-group-1")
        await premium.load()
        XCTAssertTrue(premium.canSend)
    }

    func testTheDraftCarriesTheDayAndTheBatch() async throws {
        var request = CaptureSendRequest(payload: .media(photo(takenOn: "2026-08-30")), groupIDs: ["g1"])
        request.batchID = "5b0b5e43-2f0e-4c5e-9a55-3f7d0b8f1a20"
        let draft = try await CaptureDraftBuilder.build(request)
        XCTAssertEqual(draft.takenOn, LocalDate("2026-08-30"))
        XCTAssertEqual(draft.batchID, "5b0b5e43-2f0e-4c5e-9a55-3f7d0b8f1a20")
        XCTAssertEqual(draft.mediaRow(owner: UserID("9f1c1d2e-0000-4000-8000-000000000002")).takenOn, LocalDate("2026-08-30"))
    }

    // MARK: The camera's library picker

    func testPickingSeveralOpensOneSendToInTheOrderPicked() async {
        let rig = CaptureTestRig()
        let model = rig.cameraModel()
        await model.appear()
        let items = [photo(), photo(), photo()]
        model.didPick(items)
        XCTAssertEqual(model.captured?.id, items[0].id)
        XCTAssertEqual(model.capturedMore.map(\.id), [items[1].id, items[2].id])
        model.discardCapture()
        XCTAssertNil(model.captured)
        XCTAssertTrue(model.capturedMore.isEmpty)
        // A camera photo afterwards is a single capture again.
        model.didPick([photo(), photo()])
        model.didSend()
        await model.takePhoto()
        XCTAssertTrue(model.capturedMore.isEmpty)
    }

    func testAVideoThatCannotBeTrimmedIsLeftOutAfterTheAlertAndTheRestGoOn() async {
        let rig = CaptureTestRig()
        rig.premium.premium = true
        let model = rig.cameraModel()
        await model.appear()
        let notAMovie = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        FileManager.default.createFile(atPath: notAMovie.path, contents: Data([0]))
        let first = photo()
        let last = photo()
        model.didPick([first, .video(CaptureVideo(fileURL: notAMovie, durationMs: 42000), capturedAt: Date()), last])
        XCTAssertTrue(model.isVideoTooLong)
        XCTAssertNil(model.captured, "send-to waits for the alert")
        model.videoTooLongDismissed()
        XCTAssertEqual(model.captured?.id, first.id)
        XCTAssertEqual(model.capturedMore.map(\.id), [last.id])
    }

    func testTheLibraryLimitComesFromTheServerAndIsOneWhileUnknown() async {
        let rig = CaptureTestRig()
        let unknown = rig.cameraModel()
        await unknown.loadSelectionLimit()
        XCTAssertEqual(unknown.selectionLimit, 1)
        let known = rig.cameraModel(batchLimit: { 20 })
        await known.loadSelectionLimit()
        XCTAssertEqual(known.selectionLimit, 20)
    }

    // MARK: share.in

    func testSharedItemsOpenSendToAsASelection() async {
        let rig = CaptureTestRig()
        let shared = [photo(takenOn: "2026-07-04"), photo()]
        var asked: Int?
        let model = rig.cameraModel(batchLimit: { 20 }, sharedItems: { limit in
            asked = limit
            return shared
        })
        await model.takeSharedItems()
        XCTAssertEqual(asked, 20, "at most batch_max_photos")
        XCTAssertEqual(model.captured?.id, shared[0].id)
        XCTAssertEqual(model.captured?.takenOn, LocalDate("2026-07-04"))
        XCTAssertEqual(model.capturedMore.map(\.id), [shared[1].id])
    }

    func testTheShareLinkWaitsUntilThePersonIsHome() {
        let router = AppRouter(parser: DeepLinkParser(universalLinkHosts: []), shareScheme: "com.example.jolt")
        let before = ShareInHandoff.shared.arrivals
        router.open(URL(string: "com.example.jolt://share")!)
        XCTAssertTrue(router.pendingShare, "signed out: sign-in first")
        XCTAssertNil(router.modal)
        router.setReady(true)
        XCTAssertFalse(router.pendingShare)
        XCTAssertEqual(ShareInHandoff.shared.arrivals, before + 1)
        // The camera link opens the camera tab (MainShell).
        XCTAssertEqual(router.modal, .camera(groupID: nil, invitationID: nil))
        // Another app's scheme, or another route, is not a share.
        router.modal = nil
        router.open(URL(string: "other://share")!)
        router.open(URL(string: "com.example.jolt://camera")!)
        XCTAssertNil(router.modal)
        XCTAssertEqual(ShareInHandoff.shared.arrivals, before + 1)
    }

    // MARK: The day a library photo was taken

    func testTakenOnIsTheDateOnlyInTheDeviceZone() throws {
        let paris = try XCTUnwrap(TimeZone(identifier: "Europe/Paris"))
        let today = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-17T12:00:00Z"))
        // No offset: the camera's own calendar day.
        XCTAssertEqual(CaptureTakenOn.fromEXIF(dateTimeOriginal: "2026:09:14 23:30:00", offset: nil, timeZone: paris, today: today), LocalDate("2026-09-14"))
        // With an offset: the instant, on the device's day (23:30 in New York is the next morning in Paris).
        XCTAssertEqual(CaptureTakenOn.fromEXIF(dateTimeOriginal: "2026:09:14 23:30:00", offset: "-04:00", timeZone: paris, today: today), LocalDate("2026-09-15"))
        // Never after today, never before 1900, nothing from garbage.
        XCTAssertNil(CaptureTakenOn.fromEXIF(dateTimeOriginal: "2027:01:01 10:00:00", offset: nil, timeZone: paris, today: today))
        XCTAssertNil(CaptureTakenOn.fromEXIF(dateTimeOriginal: "1899:12:31 10:00:00", offset: nil, timeZone: paris, today: today))
        XCTAssertNil(CaptureTakenOn.fromEXIF(dateTimeOriginal: "0000:00:00 00:00:00", offset: nil, timeZone: paris, today: today))
        XCTAssertNil(CaptureTakenOn.fromEXIF(dateTimeOriginal: nil, offset: nil, timeZone: paris, today: today))
        XCTAssertEqual(CaptureTakenOn.offsetSeconds("+05:30"), 19800)
        XCTAssertEqual(CaptureTakenOn.offsetSeconds("-0400"), -14400)
        XCTAssertEqual(CaptureTakenOn.offsetSeconds("Z"), 0)
        XCTAssertNil(CaptureTakenOn.offsetSeconds("soon"))
        // A video's creation instant, on the device's day.
        let instant = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-01T22:30:00Z"))
        XCTAssertEqual(CaptureTakenOn.fromDate(instant, timeZone: paris, today: today), LocalDate("2026-05-02"))
        // The camera's own JPEGs carry no capture date: nothing is sent.
        XCTAssertNil(CaptureTakenOn.fromImage(CaptureFakes.still(Tokens.Colors.globalAccent).imageData, timeZone: paris, today: today))
    }
}

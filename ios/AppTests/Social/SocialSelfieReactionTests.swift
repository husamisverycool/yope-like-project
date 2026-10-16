// viewer.selfiereaction (design/surfaces/viewer.selfiereaction.md): the faces' data, sending and removing, the Reactions
// sheet's rows, the capture layer's geometry, camera and hold gesture, and the selfie report target.
@testable import App
import AppData
import AppModels
import AppServices
import DesignSystem
import Foundation
import UIKit
import XCTest

@MainActor
final class SocialSelfieReactionTests: XCTestCase {
    private let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])

    private func selfie(_ n: Int, on post: PostID, by user: UserID, minutes: Double) -> SelfieReaction {
        SelfieReaction(
            id: SelfieReactionID("00000000-0000-4000-8000-0000000b" + String(2000 + n).suffix(4)), postID: post, userID: user,
            groupID: SocialDemo.groupID, imagePath: "fake/selfie/\(user.rawValue.suffix(2))", createdAt: SocialDemo.at(minutes * 60)
        )
    }

    /// The demo backend with Ana and Cleo's selfies on Ben's photo (p1) and Ana's on my own photo (p3).
    private func makeData() -> FakeSocialData {
        let data = SocialDemo.makeData()
        let selfies = [
            selfie(1, on: SocialDemo.p1, by: SocialDemo.ana, minutes: 70),
            selfie(2, on: SocialDemo.p1, by: SocialDemo.cleo, minutes: 80),
            selfie(3, on: SocialDemo.p3, by: SocialDemo.ana, minutes: 3000),
        ]
        data.update { $0.selfies = selfies }
        return data
    }

    private func makeViewer(_ data: FakeSocialData, start: PostID = SocialDemo.p2) -> PhotoViewerModel {
        PhotoViewerModel(
            context: PhotoViewerContext(
                postIDs: [SocialDemo.p1, SocialDemo.p2, SocialDemo.p3, SocialDemo.p4], start: start, groupID: SocialDemo.groupID
            ),
            data: data
        )
    }

    // MARK: Faces

    func testSummaryKeepsOneSelfiePerPersonNewestFirst() {
        var summary = SelfieSummary([
            selfie(1, on: SocialDemo.p1, by: SocialDemo.ana, minutes: 10),
            selfie(2, on: SocialDemo.p1, by: SocialDemo.ben, minutes: 20),
            selfie(3, on: SocialDemo.p1, by: SocialDemo.cleo, minutes: 30),
            selfie(4, on: SocialDemo.p1, by: SocialDemo.me, minutes: 40),
        ])
        XCTAssertEqual(summary.rows.map(\.userID), [SocialDemo.me, SocialDemo.cleo, SocialDemo.ben, SocialDemo.ana])
        let limit = Int(Tokens.Counts.chatReactionsCountClusterMaxVisible)
        XCTAssertEqual(summary.faces(limit: limit).map(\.userID), [SocialDemo.me, SocialDemo.cleo, SocialDemo.ben],
                       "chat.reactions.count.clusterMaxVisible faces, newest leading; nobody is counted")
        summary.upsert(selfie(5, on: SocialDemo.p1, by: SocialDemo.ana, minutes: 50))
        XCTAssertEqual(summary.rows.map(\.userID), [SocialDemo.ana, SocialDemo.me, SocialDemo.cleo, SocialDemo.ben], "a new selfie replaces the person's")
        summary.remove(userID: SocialDemo.cleo)
        XCTAssertNil(summary.selfie(by: SocialDemo.cleo))
        XCTAssertFalse(Copy.viewerSelfiereactionA11yStack(names: ListFormatter.localizedString(byJoining: ["Ana", "Sam"])).contains(where: \.isNumber))
    }

    func testSheetRowsMergeSelfiesAmongEmojiByTime() {
        let emoji = [
            SocialDemo.reaction(SocialDemo.p1, SocialDemo.cleo, "🔥", minutes: 90),
            SocialDemo.reaction(SocialDemo.p1, SocialDemo.ana, "🔥", minutes: 60),
        ]
        let selfies = SelfieSummary([
            selfie(1, on: SocialDemo.p1, by: SocialDemo.ben, minutes: 75),
            selfie(2, on: SocialDemo.p1, by: SocialDemo.me, minutes: 95),
        ])
        let entries = ReactionsSheetEntry.merged(emoji: emoji, selfies: selfies.rows)
        let minutes: [TimeInterval] = [95, 90, 75, 60]
        XCTAssertEqual(entries.map(\.createdAt), minutes.map { SocialDemo.at($0 * 60) }, "newest first")
        guard case .selfie(let first) = entries.first else { return XCTFail("my selfie leads") }
        XCTAssertEqual(first.userID, SocialDemo.me)
    }

    func testViewerReadsTheSelfiesAndTheirPeople() async {
        let model = makeViewer(makeData(), start: SocialDemo.p1)
        await model.load()
        XCTAssertEqual(model.selfies.summary(for: SocialDemo.p1).rows.map(\.userID), [SocialDemo.cleo, SocialDemo.ana])
        XCTAssertTrue(model.selfies.summary(for: SocialDemo.p2).isEmpty)
        XCTAssertEqual(model.profiles[SocialDemo.cleo]?.socialFirstName, "Cleo", "reactors' names are read for the rows and labels")
        XCTAssertTrue(model.canReactWithSelfie, "someone else's photo")
    }

    // MARK: Sending

    func testSendShowsMyFaceAtOnceThenReplacesIt() async {
        let data = makeData()
        let model = makeViewer(data)
        await model.load()
        data.update { $0.holds.insert("reactWithSelfie") }
        let task = Task { await model.sendSelfie(jpeg, to: SocialDemo.p2) }
        let optimistic = await socialEventually { model.selfies.summary(for: SocialDemo.p2).selfie(by: SocialDemo.me) != nil }
        XCTAssertTrue(optimistic, "sending: my face joins the stack at once")
        XCTAssertTrue(model.selfies.sending.contains(SocialDemo.p2))
        let pending = model.selfies.summary(for: SocialDemo.p2).selfie(by: SocialDemo.me)
        XCTAssertEqual(pending.flatMap { model.selfies.sentImages[$0.id] }, jpeg, "drawn from the JPEG until its file loads")
        data.update { $0.holds.remove("reactWithSelfie") }
        await task.value
        let stored = model.selfies.summary(for: SocialDemo.p2).selfie(by: SocialDemo.me)
        XCTAssertFalse(stored?.imagePath.isEmpty ?? true)
        XCTAssertEqual(model.selfies.signals.notice?.notice, .selfieSent, "viewer.selfiereaction.a11y.sent")
        XCTAssertNil(model.selfies.signals.feedback, "sent: no haptic (owner decision 15)")

        await model.sendSelfie(jpeg, to: SocialDemo.p2)
        XCTAssertEqual(model.selfies.summary(for: SocialDemo.p2).rows.count, 1, "one per person per post: replaced")
        XCTAssertEqual(data.read { $0.selfies.filter { $0.postID == SocialDemo.p2 }.count }, 1)
    }

    func testAFailedSendTakesMyFaceBackOut() async {
        let data = makeData()
        let model = makeViewer(data)
        await model.load()
        data.update { $0.failOnce.insert("reactWithSelfie") }
        await model.sendSelfie(jpeg, to: SocialDemo.p2)
        XCTAssertTrue(model.selfies.summary(for: SocialDemo.p2).isEmpty)
        XCTAssertTrue(model.selfies.sentImages.isEmpty)
        XCTAssertEqual(model.selfies.signals.notice?.notice, .selfieFailed)
        XCTAssertEqual(model.selfies.signals.feedback?.kind, .failed)
        XCTAssertEqual(SocialNotice.selfieFailed.text, Copy.viewerSelfiereactionError)
    }

    func testADeletedPhotoGoesWhenTheSelfieIsRefused() async {
        let data = makeData()
        let model = makeViewer(data)
        await model.load()
        data.update { $0.notFoundOnce.insert("reactWithSelfie") }
        await model.sendSelfie(jpeg, to: SocialDemo.p2)
        XCTAssertTrue(model.isCurrentGone)
    }

    func testNoSelfieOnMyOwnPhoto() async {
        let data = makeData()
        let model = makeViewer(data, start: SocialDemo.p3)
        await model.load()
        XCTAssertFalse(model.canReactWithSelfie, "the entry points are hidden on my own photo")
        await model.sendSelfie(jpeg, to: SocialDemo.p3)
        XCTAssertFalse(data.read { $0.calls.contains("reactWithSelfie") })
    }

    // MARK: Removing

    func testTapOnMyRowTakesMySelfieBack() async {
        let data = makeData()
        let model = makeViewer(data)
        await model.load()
        await model.sendSelfie(jpeg, to: SocialDemo.p2)
        await model.removeMySelfie(postID: SocialDemo.p2)
        XCTAssertNil(model.selfies.summary(for: SocialDemo.p2).selfie(by: SocialDemo.me))
        XCTAssertTrue(data.read { $0.selfies.filter { $0.postID == SocialDemo.p2 }.isEmpty })
    }

    func testTheAuthorRemovesSomeonesSelfieAfterTheConfirmation() async {
        let data = makeData()
        let model = makeViewer(data, start: SocialDemo.p3)
        await model.load()
        await model.removeSelfie(of: SocialDemo.ana, postID: SocialDemo.p3)
        XCTAssertTrue(model.selfies.summary(for: SocialDemo.p3).isEmpty)
        XCTAssertEqual(model.selfies.signals.feedback?.kind, .warning, "haptic.global.warning")

        // Only on my own photo: Ben's photo keeps Ana's selfie.
        await model.removeSelfie(of: SocialDemo.ana, postID: SocialDemo.p1)
        XCTAssertNotNil(model.selfies.summary(for: SocialDemo.p1).selfie(by: SocialDemo.ana))
    }

    func testAFailedRemovalPutsTheSelfieBack() async {
        let data = makeData()
        let model = makeViewer(data, start: SocialDemo.p3)
        await model.load()
        data.update { $0.failOnce.insert("removeSelfieReaction") }
        await model.removeSelfie(of: SocialDemo.ana, postID: SocialDemo.p3)
        XCTAssertNotNil(model.selfies.summary(for: SocialDemo.p3).selfie(by: SocialDemo.ana))
        XCTAssertEqual(model.selfies.signals.feedback?.kind, .failed)
    }

    // MARK: Live

    func testRealtimeAddsSelfiesAndARemovalRereads() async {
        let data = makeData()
        let model = makeViewer(data, start: SocialDemo.p1)
        await model.load()
        let ben = selfie(9, on: SocialDemo.p1, by: SocialDemo.ben, minutes: 100)
        data.update { $0.selfies.append(ben) }
        await model.handle(.selfieReactionUpserted(ben))
        XCTAssertEqual(model.selfies.summary(for: SocialDemo.p1).rows.first?.userID, SocialDemo.ben, "the new face leads")

        data.update { $0.selfies.removeAll { $0.userID == SocialDemo.ben } }
        await model.handle(.reactionsChanged(SocialDemo.p1))
        XCTAssertNil(model.selfies.summary(for: SocialDemo.p1).selfie(by: SocialDemo.ben), "reactions_changed: the post's selfies are read again")
    }

    // MARK: Report

    func testASelfieIsReportedWithThePostsReasons() async {
        XCTAssertEqual(ReportReason.reasons(for: .selfie), ReportReason.reasons(for: .post))
        let account = InMemoryAccountData(signedIn: SocialDemo.me)
        let report = ReportModel(target: ReportTarget(kind: .selfie, id: "00000000-0000-4000-8000-0000000b2001"), data: account)
        XCTAssertEqual(report.title, Copy.safetyReportTitlePost)
        let filed = await report.submit(.nudity)
        XCTAssertTrue(filed)
        XCTAssertEqual(account.reports.last?.kind, .selfie)
        XCTAssertEqual(account.reports.last?.reason, ReportReason.nudity.wireValue(for: .post))
    }

    // MARK: Capture layer

    func testLayerGeometryCentresTheCircleOnTheScreen() {
        let screen = CGSize(width: 393, height: 852)
        let hint: CGFloat = 16
        let roomy = SelfieLayerGeometry.layout(size: screen, panelTop: 110, contentBottom: 818, hintHeight: hint)
        XCTAssertEqual(roomy.circle.width, screen.width - 2 * Tokens.Sizes.globalScreenMargin, accuracy: 0.001)
        XCTAssertEqual(roomy.circle.midY, screen.height / 2, accuracy: 0.001, "AP-375: the circle's centre on the screen's middle")
        XCTAssertEqual(roomy.ring.midY, roomy.circle.maxY, accuracy: 0.001, "the target ring centred on the circle's bottom edge")
        XCTAssertEqual(roomy.ring.width, Tokens.Sizes.cameraCaptureSizeShutterOuter, accuracy: 0.001)
        XCTAssertEqual(roomy.hintCapTop, roomy.ring.maxY + Tokens.Sizes.globalScreenMargin, accuracy: 0.001)

        let short = SelfieLayerGeometry.layout(size: screen, panelTop: 400, contentBottom: 818, hintHeight: hint)
        XCTAssertLessThan(short.circle.width, roomy.circle.width, "a short panel shrinks the circle")
        XCTAssertEqual(short.circle.midY, (400 + 818) / 2, accuracy: 0.001, "centred on the panel's middle")
        XCTAssertLessThanOrEqual(short.ring.maxY + Tokens.Sizes.globalScreenMargin + hint, 818 + 0.001)
    }

    func testLayerRunsTheFrontCameraAndArmsInsideTheTarget() async throws {
        let camera = FakeCaptureCamera()
        camera.frontStill = CaptureTestImages.still(named: CaptureTestImages.selfie, position: .front)
        let layer = SelfieCaptureModel(postID: SocialDemo.p2, mode: .hold, camera: camera)
        await layer.start()
        XCTAssertEqual(layer.phase, .live)
        XCTAssertEqual(camera.configuredModes.last, .photo(.front))
        layer.circleFrame = CGRect(x: 16, y: 245, width: 361, height: 361)
        layer.ringFrame = CGRect(x: 153.5, y: 563, width: 86, height: 86)
        layer.moved(to: CGPoint(x: 360, y: 790))
        XCTAssertFalse(layer.isArmed)
        layer.moved(to: CGPoint(x: 196, y: 640))
        XCTAssertTrue(layer.isArmed, "inside the target ring")
        layer.moved(to: CGPoint(x: 196, y: 400))
        XCTAssertTrue(layer.isArmed, "inside the circle")
        XCTAssertEqual(layer.armings, 1, "haptic.global.select once when the finger enters")
        XCTAssertFalse(layer.contains(CGPoint(x: 20, y: 250)), "the circle's corner box is outside the circle")

        let captured = await layer.capture()
        let photo = try XCTUnwrap(captured)
        XCTAssertEqual(camera.stillRequests, 1, "a still without Live Photo motion")
        let size = try XCTUnwrap(ImageEncoder.pixelSize(photo))
        XCTAssertEqual(size.width, size.height, "square crop for the circle")
    }

    func testLayerWithoutCameraAccessShowsTheDeniedBlock() async {
        let camera = FakeCaptureCamera()
        camera.authorizationStatus = .denied
        let layer = SelfieCaptureModel(postID: SocialDemo.p2, mode: .tap, camera: camera)
        await layer.start()
        XCTAssertEqual(layer.phase, .denied)
        let nothing = await layer.capture()
        XCTAssertNil(nothing)
        XCTAssertTrue(FakeCaptureCamera().hasCamera(at: .front))
        let noFront = FakeCaptureCamera()
        noFront.hasFrontCamera = false
        XCTAssertFalse(noFront.hasCamera(at: .front), "no front camera: the entry points are hidden")
    }

    func testHoldOnTheGlyphOpensTheLayerAndATapOpensThePicker() async {
        let tracker = SelfieHoldTracker(threshold: .milliseconds(20))
        let log = GestureLog()
        tracker.changed(.zero, onHold: { log.holds += 1 }, onMove: { log.moves.append($0) })
        tracker.ended(.zero, onTap: { log.taps += 1 }, onRelease: { log.releases.append($0) })
        XCTAssertEqual(log.taps, 1, "a plain tap keeps opening the emoji picker")
        XCTAssertEqual(log.holds, 0)

        tracker.changed(.zero, onHold: { log.holds += 1 }, onMove: { log.moves.append($0) })
        _ = await socialEventually { log.holds == 1 }
        tracker.changed(CGPoint(x: 5, y: 5), onHold: { log.holds += 1 }, onMove: { log.moves.append($0) })
        tracker.ended(CGPoint(x: 9, y: 9), onTap: { log.taps += 1 }, onRelease: { log.releases.append($0) })
        XCTAssertEqual(log.holds, 1, "the hold opens the layer with the finger still down")
        XCTAssertEqual(log.moves, [CGPoint(x: 5, y: 5)])
        XCTAssertEqual(log.releases, [CGPoint(x: 9, y: 9)])
        XCTAssertEqual(log.taps, 1, "a hold is not a tap")
    }
}

/// What the add-reaction glyph's touch reported.
@MainActor
private final class GestureLog {
    var taps = 0
    var holds = 0
    var moves: [CGPoint] = []
    var releases: [CGPoint] = []
}

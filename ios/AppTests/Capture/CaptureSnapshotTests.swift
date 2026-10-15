// One snapshot per capture screen per state, per widget family / state and per Live Activity
// presentation, recorded into ios/build/snapshots/capture/<surface>-<state>.png for the side-by-side
// verification (design/verification/<surface>.png, made by the lead from the CI artifact).
@testable import App
import AppData
import AppModels
import DesignSystem
import SnapshotTesting
import SwiftUI
import UIKit
import WidgetKit
import XCTest

@MainActor
final class CaptureScreenSnapshotTests: XCTestCase {
    override func setUp() async throws {
        CameraCaptureModel.sessionPosition = .back
    }

    private func assertRecorded(_ url: URL?, file: StaticString = #filePath, line: UInt = #line) {
        guard let url else { return XCTFail("snapshot not written", file: file, line: line) }
        XCTAssertTrue(url.lastPathComponent.hasSuffix(".png"), file: file, line: line)
    }

    // MARK: camera.capture

    private func cameraView(_ rig: CaptureTestRig, _ model: CameraCaptureModel, recordingProgress: CGFloat = 0) -> some View {
        CameraCaptureView(model: model, makeSendTo: { rig.sendToModel(media: $0) }, sendCenter: rig.sendCenter, recordingProgress: recordingProgress)
    }

    func testCameraCaptureStates() async {
        let loadingRig = CaptureTestRig()
        assertRecorded(CaptureSnapshot.record(cameraView(loadingRig, loadingRig.cameraModel()), surface: "camera.capture", state: "loading"))

        let rig = CaptureTestRig()
        rig.usePhotos()
        let live = rig.cameraModel()
        await live.appear()
        assertRecorded(CaptureSnapshot.record(cameraView(rig, live), surface: "camera.capture", state: "live"))

        live.toggleFlash()
        assertRecorded(CaptureSnapshot.record(cameraView(rig, live), surface: "camera.capture", state: "flash-on"))

        live.shutterTouchDown()
        assertRecorded(CaptureSnapshot.record(cameraView(rig, live), surface: "camera.capture", state: "shutter-pressed"))
        live.shutterTouchUp()

        let premiumRig = CaptureTestRig()
        premiumRig.premium.premium = true
        premiumRig.usePhotos(scene: 2)
        let coach = premiumRig.cameraModel()
        await coach.appear()
        assertRecorded(CaptureSnapshot.record(cameraView(premiumRig, coach), surface: "camera.capture", state: "coach"))
        await coach.startRecording()
        assertRecorded(CaptureSnapshot.record(cameraView(premiumRig, coach, recordingProgress: 0.4), surface: "camera.capture", state: "recording"))

        let deniedRig = CaptureTestRig()
        deniedRig.camera.authorizationStatus = .denied
        let denied = deniedRig.cameraModel()
        await denied.appear()
        assertRecorded(CaptureSnapshot.record(cameraView(deniedRig, denied), surface: "camera.capture", state: "permission-denied"))

        let failingRig = CaptureTestRig()
        failingRig.camera.failsConfigure = true
        let unavailable = failingRig.cameraModel()
        await unavailable.appear()
        assertRecorded(CaptureSnapshot.record(cameraView(failingRig, unavailable), surface: "camera.capture", state: "error"))
    }

    // MARK: camera.sendto / camera.fromwidget

    private func photoMedia() -> CapturedMedia {
        .photo(CaptureTestImages.still(), capturedAt: Date())
    }

    /// A rig with photos (`usePhotos`).
    private func photoRig() -> CaptureTestRig {
        let rig = CaptureTestRig()
        rig.usePhotos()
        return rig
    }

    /// Loads the group list and waits for the covers (fetched in tasks of their own).
    private func loadWithCovers(_ model: SendToModel) async {
        await model.load()
        _ = await captureEventually { !model.covers.isEmpty }
    }

    func testSendToStates() async {
        let rig = photoRig()
        rig.coach.dismiss(.voice)

        rig.groups.suspendsLoad = true
        let loading = rig.sendToModel(media: photoMedia())
        let loadingTask = Task { await loading.load() }
        _ = await captureEventually { loading.listState == .loading }
        assertRecorded(CaptureSnapshot.record(SendToView(model: loading), surface: "camera.sendto", state: "loading"))
        loadingTask.cancel()
        rig.groups.suspendsLoad = false

        let loaded = rig.sendToModel(media: photoMedia())
        await loadWithCovers(loaded)
        loaded.caption = "golden hour"
        assertRecorded(CaptureSnapshot.record(SendToView(model: loaded), surface: "camera.sendto", state: "loaded"))

        let widget = rig.sendToModel(media: photoMedia(), contextGroupID: "fake-group-2")
        await loadWithCovers(widget)
        assertRecorded(CaptureSnapshot.record(SendToView(model: widget), surface: "camera.fromwidget", state: "preselected"))

        let none = rig.sendToModel(media: photoMedia(), contextGroupID: "left-group")
        await loadWithCovers(none)
        assertRecorded(CaptureSnapshot.record(SendToView(model: none), surface: "camera.sendto", state: "nothing-selected"))

        let coachRig = photoRig()
        let coach = coachRig.sendToModel(media: photoMedia())
        await loadWithCovers(coach)
        assertRecorded(CaptureSnapshot.record(SendToView(model: coach), surface: "camera.sendto", state: "voice-coach"))

        let voiceRig = photoRig()
        voiceRig.voice.elapsedMs = 7000
        let holding = voiceRig.sendToModel(media: photoMedia())
        await loadWithCovers(holding)
        await holding.beginVoiceRecording()
        assertRecorded(CaptureSnapshot.record(SendToView(model: holding), surface: "camera.sendto", state: "voice-recording"))
        holding.lockVoiceRecording()
        assertRecorded(CaptureSnapshot.record(SendToView(model: holding), surface: "camera.sendto", state: "voice-locked"))
        holding.keepVoiceRecording()
        assertRecorded(CaptureSnapshot.record(SendToView(model: holding), surface: "camera.sendto", state: "voice-attached"))

        let emptyRig = CaptureTestRig()
        emptyRig.groups.groups = []
        let empty = emptyRig.sendToModel(media: photoMedia())
        await empty.load()
        assertRecorded(CaptureSnapshot.record(SendToView(model: empty), surface: "camera.sendto", state: "empty"))

        let offlineRig = CaptureTestRig()
        offlineRig.groups.loadError = DataError.offline
        let offline = offlineRig.sendToModel(media: photoMedia())
        await offline.load()
        assertRecorded(CaptureSnapshot.record(SendToView(model: offline), surface: "camera.sendto", state: "offline"))

        let failRig = photoRig()
        failRig.coach.dismiss(.voice)
        failRig.posting.publishError = .api(.notGroupMember)
        let failing = failRig.sendToModel(media: photoMedia())
        await loadWithCovers(failing)
        await failRig.sendCenter.send(CaptureSendRequest(payload: .media(photoMedia()), groupIDs: ["fake-group-1"]))
        assertRecorded(CaptureSnapshot.record(SendToView(model: failing), surface: "camera.sendto", state: "error"))

        let offlineSendRig = photoRig()
        offlineSendRig.coach.dismiss(.voice)
        offlineSendRig.posting.publishError = .offline
        let offlineSend = offlineSendRig.sendToModel(media: photoMedia())
        await loadWithCovers(offlineSend)
        await offlineSendRig.sendCenter.send(CaptureSendRequest(payload: .media(photoMedia()), groupIDs: ["fake-group-1"]))
        assertRecorded(CaptureSnapshot.record(SendToView(model: offlineSend), surface: "camera.sendto", state: "offline-send"))

        let videoRig = photoRig()
        videoRig.coach.dismiss(.voice)
        let video = videoRig.sendToModel(media: .video(CaptureVideo(fileURL: URL(fileURLWithPath: "/dev/null"), durationMs: 1000), capturedAt: Date()))
        await loadWithCovers(video)
        assertRecorded(CaptureSnapshot.record(SendToView(model: video), surface: "camera.sendto", state: "video-free-member"))
    }

    func testSendToConfirmationToastLayout() {
        let toast = CaptureConfirmationToast(text: Copy.cameraSendtoToastPostedOne(group: CaptureFakes.groups[0].name))
            .padding(.top, Tokens.Layouts.CameraSendtoLayoutToast.top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Tokens.Colors.globalBackground)
        assertRecorded(CaptureSnapshot.record(toast, surface: "camera.sendto", state: "sent-toast"))
    }

    // MARK: daily.capture

    private func dailyView(_ rig: CaptureTestRig, _ model: DailyCaptureModel) -> some View {
        DailyCaptureView(model: model, sendCenter: rig.sendCenter)
    }

    func testDailyCaptureStates() async {
        let startingRig = CaptureTestRig()
        startingRig.openInvitation(closingIn: 95)
        let starting = startingRig.dailyModel()
        assertRecorded(CaptureSnapshot.record(dailyView(startingRig, starting), surface: "daily.capture", state: "loading"))

        let rig = CaptureTestRig()
        rig.openInvitation(closingIn: 95)
        rig.usePhotos(scene: 1)
        let live = rig.dailyModel()
        await live.appear()
        assertRecorded(CaptureSnapshot.record(dailyView(rig, live), surface: "daily.capture", state: "live"))

        rig.dualCamera.suspendsCapture = true
        let capture = Task { await live.shutter() }
        _ = await captureEventually { live.phase == .capturing }
        assertRecorded(CaptureSnapshot.record(dailyView(rig, live), surface: "daily.capture", state: "capturing"))
        capture.cancel()
        _ = await captureEventually { live.phase != .capturing }

        let previewRig = CaptureTestRig()
        previewRig.openInvitation(closingIn: 80)
        previewRig.usePhotos(scene: 1)
        let preview = previewRig.dailyModel()
        await preview.appear()
        await preview.shutter()
        assertRecorded(CaptureSnapshot.record(dailyView(previewRig, preview), surface: "daily.capture", state: "preview"))

        let singleRig = CaptureTestRig()
        singleRig.usePhotos(scene: 1)
        singleRig.dualCamera.failsDual = true
        let single = singleRig.dailyModel()
        await single.appear()
        await single.shutter()
        assertRecorded(CaptureSnapshot.record(dailyView(singleRig, single), surface: "daily.capture", state: "preview-single-camera"))

        let closedRig = CaptureTestRig()
        closedRig.openInvitation(closingIn: -30)
        closedRig.usePhotos(scene: 1)
        let closed = closedRig.dailyModel()
        await closed.appear()
        assertRecorded(CaptureSnapshot.record(dailyView(closedRig, closed), surface: "daily.capture", state: "window-closed"))

        let deniedRig = CaptureTestRig()
        deniedRig.dualCamera.authorizationStatus = .denied
        let denied = deniedRig.dailyModel()
        await denied.appear()
        assertRecorded(CaptureSnapshot.record(dailyView(deniedRig, denied), surface: "daily.capture", state: "permission-denied"))

        let failingRig = CaptureTestRig()
        failingRig.dualCamera.failsConfigure = true
        let unavailable = failingRig.dailyModel()
        await unavailable.appear()
        assertRecorded(CaptureSnapshot.record(dailyView(failingRig, unavailable), surface: "daily.capture", state: "error"))
    }

    // MARK: daily.dualimage

    func testDualImageStates() {
        let layout = SwiftUISnapshotLayout.fixed(width: 393, height: 524)
        let main = CaptureTestImages.scene(1, CGSize(width: 600, height: 800))
        let inset = CaptureTestImages.photo(CGSize(width: 300, height: 400), named: CaptureTestImages.selfie)
        func framed(_ view: DualImageView) -> some View {
            view.background(Tokens.Colors.globalBackgroundDeep)
        }
        assertRecorded(CaptureSnapshot.record(framed(DualImageView(main: main, inset: inset, accessibilityLabel: "")), surface: "daily.dualimage", state: "dual", layout: layout))
        assertRecorded(CaptureSnapshot.record(framed(DualImageView(main: main, inset: nil, accessibilityLabel: "")), surface: "daily.dualimage", state: "single-camera", layout: layout))
        assertRecorded(CaptureSnapshot.record(framed(DualImageView(main: nil, inset: nil, accessibilityLabel: "")), surface: "daily.dualimage", state: "loading", layout: layout))
    }

    // MARK: collage.view / collage.share

    private func collage(pages: Int, status: RenderStatus = .ready) -> Collage {
        Collage(
            id: CollageID("c1"), groupID: GroupID("g1"), invitationID: InvitationID("inv-1"), option: "B",
            postIDs: [PostID("p1")], pageCount: pages,
            imagePath: status == .ready ? "g/g1/collages/c1/v1/display-1.jpg" : nil, widgetPath: nil,
            sharePath: status == .ready ? "g/g1/collages/c1/v1/share-1.jpg" : nil,
            status: status, composedAt: Date(), createdAt: Date()
        )
    }

    func testCollageStates() async {
        let page = CaptureTestImages.collagePage(CGSize(width: 540, height: 960))
        let secondPage = CaptureTestImages.collagePage(CGSize(width: 540, height: 960), answers: 5, first: 12)

        let loadingRig = CaptureTestRig()
        loadingRig.collages.collage = collage(pages: 1, status: .pending)
        let loading = loadingRig.collageModel()
        await loading.load()
        assertRecorded(CaptureSnapshot.record(CollageView(model: loading), surface: "collage.view", state: "loading"))

        let rig = CaptureTestRig()
        rig.openInvitation(closingIn: -60)
        rig.collages.collage = collage(pages: 2)
        rig.collages.images = ["g/g1/collages/c1/v1/display-1.jpg": page, "g/g1/collages/c1/v1/display-2.jpg": secondPage]
        let ready = rig.collageModel()
        await ready.load()
        assertRecorded(CaptureSnapshot.record(CollageView(model: ready), surface: "collage.view", state: "ready"))
        assertRecorded(CaptureSnapshot.record(CollageView(model: ready), surface: "collage.share", state: "pill"))

        let singleRig = CaptureTestRig()
        singleRig.openInvitation(closingIn: -60)
        singleRig.collages.collage = collage(pages: 1)
        singleRig.collages.images = ["g/g1/collages/c1/v1/display-1.jpg": page]
        let single = singleRig.collageModel()
        await single.load()
        assertRecorded(CaptureSnapshot.record(CollageView(model: single), surface: "collage.view", state: "ready-one-page"))

        let emptyRig = CaptureTestRig()
        emptyRig.openInvitation(closingIn: -60)
        let empty = emptyRig.collageModel()
        await empty.load()
        assertRecorded(CaptureSnapshot.record(CollageView(model: empty), surface: "collage.view", state: "empty"))

        let errorRig = CaptureTestRig()
        errorRig.collages.collage = collage(pages: 1, status: .failed)
        let error = errorRig.collageModel()
        await error.load()
        assertRecorded(CaptureSnapshot.record(CollageView(model: error), surface: "collage.view", state: "error"))

        let offlineRig = CaptureTestRig()
        offlineRig.collages.error = DataError.offline
        let offline = offlineRig.collageModel()
        await offline.load()
        assertRecorded(CaptureSnapshot.record(CollageView(model: offline), surface: "collage.view", state: "offline"))
    }
}

/// Widgets and Live Activity presentations as plain SwiftUI views at the HIG sizes (393 × 852 screen).
@MainActor
final class CaptureWidgetSnapshotTests: XCTestCase {
    private func size(_ token: String) -> CGSize {
        let parts = token.split(separator: "x").compactMap { Double($0) }
        return CGSize(width: parts[0], height: parts[1])
    }

    /// The widget rendition (600 × 630): `photo`, or a collage page cropped to that shape; the sender's avatar.
    private func content(_ state: GroupWidgetContent.State, caption: String? = nil, photo: String = CaptureTestImages.scenes[0]) -> GroupWidgetContent {
        let size = CGSize(width: 600, height: 630)
        let rendition: UIImage? = switch state {
        case .photo: CaptureTestImages.photo(size, named: photo)
        case .collage: SamplePhotos.cropped(CaptureTestImages.collagePage(CGSize(width: 600, height: 1067)), to: size)
        default: nil
        }
        return GroupWidgetContent(
            state: state, groupName: "Family", senderName: "Ana", caption: caption, postedAt: Date(),
            photo: rendition,
            avatar: CaptureTestImages.avatar(CGSize(width: 60, height: 60))
        )
    }

    /// The Home Screen widget: container background + overlay, clipped like the system container.
    private func home(_ content: GroupWidgetContent, family: WidgetFamily, size: CGSize) -> some View {
        ZStack {
            WidgetEmptyState(content: content)
            WidgetOverlay(content: content, family: family)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(16)
        .background(Color(white: 0.25))
    }

    /// Lock Screen accessory: vibrant mode approximated with zero saturation on a dark wallpaper.
    private func lock<V: View>(_ view: V, size: CGSize) -> some View {
        view
            .frame(width: size.width, height: size.height)
            .saturation(0)
            .padding(16)
            .background(Color(white: 0.15))
    }

    private func record<V: View>(_ view: V, size: CGSize, surface: String, state: String) {
        let url = CaptureSnapshot.record(view, surface: surface, state: state, layout: .fixed(width: size.width + 32, height: size.height + 32))
        XCTAssertNotNil(url)
    }

    func testHomeWidgetFamiliesAndStates() {
        let families: [(String, WidgetFamily, CGSize)] = [
            ("widget.home.small", .systemSmall, size(Tokens.Layouts.WidgetHomeSmallLayoutSize.w393h852)),
            ("widget.home.medium", .systemMedium, size(Tokens.Layouts.WidgetHomeMediumLayoutSize.w393h852)),
            ("widget.home.large", .systemLarge, size(Tokens.Layouts.WidgetHomeLargeLayoutSize.w393h852)),
            ("widget.home.xl", .systemExtraLarge, size(Tokens.Layouts.WidgetHomeXlLayoutSize.ipad1024x1366)),
        ]
        for (surface, family, frame) in families {
            record(home(content(.photo, caption: "Sundays"), family: family, size: frame), size: frame, surface: surface, state: "photo-caption")
            record(home(content(.photo), family: family, size: frame), size: frame, surface: surface, state: "photo")
            record(home(content(.collage), family: family, size: frame), size: frame, surface: surface, state: "collage")
            record(home(.loading, family: family, size: frame), size: frame, surface: surface, state: "loading")
            record(home(GroupWidgetContent(state: .empty), family: family, size: frame), size: frame, surface: surface, state: "empty")
            record(home(GroupWidgetContent(state: .notSetUp), family: family, size: frame), size: frame, surface: surface, state: "not-set-up")
        }
        let avatarless = GroupWidgetContent(state: .photo, groupName: "Family", senderName: "Ana", caption: "Sundays",
                                            photo: CaptureTestImages.photo(CGSize(width: 600, height: 630)))
        let small = size(Tokens.Layouts.WidgetHomeSmallLayoutSize.w393h852)
        record(home(avatarless, family: .systemSmall, size: small), size: small, surface: "widget.home.small", state: "no-avatar")
    }

    func testArrivalSwapsInstantly() {
        let small = size(Tokens.Layouts.WidgetHomeSmallLayoutSize.w393h852)
        record(home(content(.photo, caption: "Sundays", photo: CaptureTestImages.scenes[0]), family: .systemSmall, size: small), size: small, surface: "widget.arrival", state: "before")
        record(home(content(.photo, caption: "brunch", photo: CaptureTestImages.scenes[3]), family: .systemSmall, size: small), size: small, surface: "widget.arrival", state: "after")
        XCTAssertEqual(Tokens.Durations.widgetArrivalDurationTransition, 0, "no transition between entries")
    }

    func testLockScreenWidgets() {
        let rect = size(Tokens.Layouts.WidgetLockRectLayoutSize.w393h852)
        let circle = size(Tokens.Layouts.WidgetLockCircularLayoutSize.w393h852)
        let inline = size(Tokens.Layouts.WidgetLockInlineLayoutSize.w393h852)
        record(lock(WidgetRectangularSlot(content: content(.photo, caption: "Sundays at the lake")), size: rect), size: rect, surface: "widget.lock.rect", state: "photo-caption")
        record(lock(WidgetRectangularSlot(content: content(.photo)), size: rect), size: rect, surface: "widget.lock.rect", state: "photo-no-caption")
        record(lock(WidgetRectangularSlot(content: GroupWidgetContent(state: .empty)), size: rect), size: rect, surface: "widget.lock.rect", state: "empty")
        record(lock(WidgetRectangularSlot(content: GroupWidgetContent(state: .notSetUp)), size: rect), size: rect, surface: "widget.lock.rect", state: "not-set-up")
        record(lock(WidgetRectangularSlot(content: .loading), size: rect), size: rect, surface: "widget.lock.rect", state: "loading")
        record(lock(WidgetCircularSlot(content: content(.photo)), size: circle), size: circle, surface: "widget.lock.circular", state: "photo")
        record(lock(WidgetCircularSlot(content: GroupWidgetContent(state: .empty)), size: circle), size: circle, surface: "widget.lock.circular", state: "empty")
        record(lock(WidgetInlineSlot(content: content(.photo, caption: "Sundays at the lake")).foregroundStyle(.white), size: inline), size: inline, surface: "widget.lock.inline", state: "photo-caption")
        record(lock(WidgetInlineSlot(content: content(.photo)).foregroundStyle(.white), size: inline), size: inline, surface: "widget.lock.inline", state: "photo-no-caption")
        record(lock(WidgetInlineSlot(content: GroupWidgetContent(state: .notSetUp)).foregroundStyle(.white), size: inline), size: inline, surface: "widget.lock.inline", state: "not-set-up")
    }

    func testLiveActivityPresentations() {
        let attributes = DailyInvitationAttributes(groupID: "g1", invitationID: "i1")
        let now = Date()
        let state = DailyInvitationAttributes.ContentState(closesAt: now.addingTimeInterval(95), groupName: "Family")
        let lockSize = CGSize(width: 371, height: 84)
        let lockScreen = InvitationLockScreenSlot(attributes: attributes, state: state, isStale: false, now: now)
            .frame(width: lockSize.width, height: lockSize.height)
            .background(Tokens.Colors.globalBackgroundDeep)
        record(lockScreen, size: lockSize, surface: "daily.liveactivity", state: "lock-screen")
        let stale = InvitationLockScreenSlot(attributes: attributes, state: state, isStale: true, now: now)
            .frame(width: lockSize.width, height: lockSize.height)
            .background(Tokens.Colors.globalBackgroundDeep)
        record(stale, size: lockSize, surface: "daily.liveactivity", state: "lock-screen-stale")

        let compactSize = CGSize(width: 250, height: 37)
        let compact = HStack {
            InvitationCompactLeadingSlot()
            Spacer()
            InvitationCompactTrailingSlot(state: state, now: now)
        }
        .padding(.horizontal, 12)
        .frame(width: compactSize.width, height: compactSize.height)
        .background(Capsule().fill(Color.black))
        record(compact, size: compactSize, surface: "daily.liveactivity", state: "compact")

        let minimalSize = CGSize(width: 45, height: 37)
        record(InvitationMinimalSlot(state: state, now: now).frame(width: minimalSize.width, height: minimalSize.height).background(Circle().fill(Color.black)),
               size: minimalSize, surface: "daily.liveactivity", state: "minimal")

        let expandedSize = CGSize(width: 371, height: 120)
        let expanded = VStack {
            HStack {
                InvitationCompactLeadingSlot()
                Spacer()
                InvitationCompactTrailingSlot(state: state, now: now)
            }
            Spacer()
            InvitationExpandedSlot(state: state)
        }
        .padding(16)
        .frame(width: expandedSize.width, height: expandedSize.height)
        .background(RoundedRectangle(cornerRadius: 40).fill(Color.black))
        record(expanded, size: expandedSize, surface: "daily.liveactivity", state: "expanded")
    }
}

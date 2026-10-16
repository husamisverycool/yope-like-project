// One snapshot per capture screen per state (light; the primary state of each surface also in dark), per widget family
// / state and per Live Activity presentation, recorded into ios/build/snapshots/capture/<surface>-<state>-<appearance>.png
// for the side-by-side verification (design/verification/<surface>.png, made by the lead from the CI artifact). Real
// sample photos (fixtures/photos/, `SamplePhotos`) everywhere a photo shows.
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

    /// The camera as the shell shows it: the view with the C-04 tab bar (media variant) under it.
    private func cameraView(_ rig: CaptureTestRig, _ model: CameraCaptureModel, recordingProgress: CGFloat = 0) -> some View {
        CameraCaptureView(model: model, makeSendTo: { rig.sendToModel(media: $0) }, sendCenter: rig.sendCenter, recordingProgress: recordingProgress)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AppTabBar(selected: .camera, surface: .media) { _ in }
            }
    }

    func testCameraCaptureStates() async {
        let loadingRig = CaptureTestRig()
        assertRecorded(CaptureSnapshot.record(cameraView(loadingRig, loadingRig.cameraModel()), surface: "camera.capture", state: "loading"))

        let rig = CaptureTestRig()
        rig.usePhotos()
        let live = rig.cameraModel()
        await live.appear()
        assertRecorded(CaptureSnapshot.record(cameraView(rig, live), surface: "camera.capture", state: "live", appearances: CaptureSnapshot.both))

        live.toggleFlash()
        assertRecorded(CaptureSnapshot.record(cameraView(rig, live), surface: "camera.capture", state: "flash-on"))

        let noFlashRig = CaptureTestRig()
        noFlashRig.usePhotos(scene: 4)
        noFlashRig.camera.flashAvailable = false
        let noFlash = noFlashRig.cameraModel()
        await noFlash.appear()
        assertRecorded(CaptureSnapshot.record(cameraView(noFlashRig, noFlash), surface: "camera.capture", state: "no-flash"))

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

        rig.groups.suspendsLoad = true
        let loading = rig.sendToModel(media: photoMedia())
        let loadingTask = Task { await loading.load() }
        _ = await captureEventually { loading.listState == .loading }
        assertRecorded(CaptureSnapshot.record(SendToView(model: loading), surface: "camera.sendto", state: "loading"))
        loadingTask.cancel()
        rig.groups.suspendsLoad = false

        let loaded = rig.sendToModel(media: photoMedia())
        await loadWithCovers(loaded)
        assertRecorded(CaptureSnapshot.record(SendToView(model: loaded), surface: "camera.sendto", state: "loaded", appearances: CaptureSnapshot.both))

        let message = rig.sendToModel(media: photoMedia())
        await loadWithCovers(message)
        message.caption = "Golden hour at the lake"
        assertRecorded(CaptureSnapshot.record(SendToView(model: message), surface: "camera.sendto", state: "message-added"))
        assertRecorded(CaptureSnapshot.record(SendToMessageSheet(model: message), surface: "camera.sendto", state: "message-sheet", appearances: CaptureSnapshot.both))

        let blank = rig.sendToModel(media: photoMedia())
        assertRecorded(CaptureSnapshot.record(SendToMessageSheet(model: blank), surface: "camera.sendto", state: "message-sheet-empty"))

        let widget = rig.sendToModel(media: photoMedia(), contextGroupID: "fake-group-2")
        await loadWithCovers(widget)
        assertRecorded(CaptureSnapshot.record(SendToView(model: widget), surface: "camera.fromwidget", state: "preselected", appearances: CaptureSnapshot.both))

        let none = rig.sendToModel(media: photoMedia(), contextGroupID: "left-group")
        await loadWithCovers(none)
        assertRecorded(CaptureSnapshot.record(SendToView(model: none), surface: "camera.sendto", state: "nothing-selected"))

        let voiceRig = photoRig()
        voiceRig.voice.elapsedMs = 7000
        voiceRig.voice.recordedDurationMs = 7000
        let holding = voiceRig.sendToModel(media: photoMedia())
        await loadWithCovers(holding)
        await holding.beginVoiceRecording()
        assertRecorded(CaptureSnapshot.record(SendToView(model: holding), surface: "camera.sendto", state: "voice-recording"))
        holding.lockVoiceRecording()
        assertRecorded(CaptureSnapshot.record(SendToView(model: holding), surface: "camera.sendto", state: "voice-locked"))
        holding.pauseVoiceRecording()
        assertRecorded(CaptureSnapshot.record(SendToView(model: holding), surface: "camera.sendto", state: "voice-paused"))
        holding.keepVoiceRecording()
        assertRecorded(CaptureSnapshot.record(SendToView(model: holding), surface: "camera.sendto", state: "voice-attached"))

        let sendingRig = photoRig()
        sendingRig.posting.suspendsPublish = true
        let sending = sendingRig.sendToModel(media: photoMedia())
        await loadWithCovers(sending)
        let sendTask = Task { await sending.send() }
        _ = await captureEventually { sending.isSending }
        assertRecorded(CaptureSnapshot.record(SendToView(model: sending), surface: "camera.sendto", state: "sending"))
        sendTask.cancel()
        _ = await captureEventually { !sending.isSending }

        let emptyRig = CaptureTestRig()
        emptyRig.groups.groups = []
        let empty = emptyRig.sendToModel(media: photoMedia())
        await empty.load()
        assertRecorded(CaptureSnapshot.record(SendToView(model: empty), surface: "camera.sendto", state: "empty"))

        let offlineRig = CaptureTestRig()
        offlineRig.groups.loadError = DataError.offline
        let offline = offlineRig.sendToModel(media: photoMedia())
        await offline.load()
        assertRecorded(CaptureSnapshot.record(SendToView(model: offline), surface: "camera.sendto", state: "offline-groups"))

        let failRig = photoRig()
        failRig.posting.publishError = .api(.notGroupMember)
        let failing = failRig.sendToModel(media: photoMedia())
        await loadWithCovers(failing)
        await failing.send()
        // The native alert is drawn by the system over this composer (not part of the hosted view).
        assertRecorded(CaptureSnapshot.record(SendToView(model: failing), surface: "camera.sendto", state: "error-composer-kept"))

        let videoRig = photoRig()
        let video = videoRig.sendToModel(media: .video(CaptureVideo(fileURL: URL(fileURLWithPath: "/dev/null"), durationMs: 1000), capturedAt: Date()))
        await loadWithCovers(video)
        assertRecorded(CaptureSnapshot.record(SendToView(model: video), surface: "camera.sendto", state: "video-free-member"))
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
        assertRecorded(CaptureSnapshot.record(dailyView(rig, live), surface: "daily.capture", state: "live", appearances: CaptureSnapshot.both))

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
        assertRecorded(CaptureSnapshot.record(dailyView(previewRig, preview), surface: "daily.capture", state: "preview", appearances: CaptureSnapshot.both))

        previewRig.posting.suspendsPublish = true
        let sendTask = Task { await preview.send() }
        _ = await captureEventually { preview.isSending }
        assertRecorded(CaptureSnapshot.record(dailyView(previewRig, preview), surface: "daily.capture", state: "sending"))
        sendTask.cancel()
        _ = await captureEventually { !preview.isSending }

        let singleRig = CaptureTestRig()
        singleRig.openInvitation(closingIn: 80)
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
        deniedRig.openInvitation(closingIn: 95)
        deniedRig.dualCamera.authorizationStatus = .denied
        let denied = deniedRig.dailyModel()
        await denied.appear()
        assertRecorded(CaptureSnapshot.record(dailyView(deniedRig, denied), surface: "daily.capture", state: "permission-denied"))

        let failingRig = CaptureTestRig()
        failingRig.openInvitation(closingIn: 95)
        failingRig.dualCamera.failsConfigure = true
        let unavailable = failingRig.dailyModel()
        await unavailable.appear()
        assertRecorded(CaptureSnapshot.record(dailyView(failingRig, unavailable), surface: "daily.capture", state: "error"))
    }

    // MARK: daily.dualimage

    func testDualImageStates() {
        let layout = SwiftUISnapshotLayout.fixed(width: 361, height: 482)
        let main = CaptureTestImages.scene(1, CGSize(width: 600, height: 800))
        let inset = CaptureTestImages.photo(CGSize(width: 300, height: 400), named: CaptureTestImages.selfie)
        func framed(_ view: DualImageView, page: Bool = false) -> some View {
            view.background(page ? Tokens.Colors.globalBackground : Tokens.Colors.globalBackgroundDeep)
        }
        let viewfinder = DualImageView.Corners.host(Tokens.Radii.globalViewfinder)
        assertRecorded(CaptureSnapshot.record(framed(DualImageView(main: main, inset: inset, accessibilityLabel: "", corners: viewfinder)), surface: "daily.dualimage", state: "dual", appearances: CaptureSnapshot.both, layout: layout))
        assertRecorded(CaptureSnapshot.record(framed(DualImageView(main: main, inset: inset, accessibilityLabel: "")), surface: "daily.dualimage", state: "dual-viewer", layout: layout))
        assertRecorded(CaptureSnapshot.record(framed(DualImageView(main: main, inset: nil, accessibilityLabel: "", corners: viewfinder)), surface: "daily.dualimage", state: "single-camera", layout: layout))
        assertRecorded(CaptureSnapshot.record(framed(DualImageView(main: nil, inset: nil, accessibilityLabel: "", corners: viewfinder)), surface: "daily.dualimage", state: "loading-media", layout: layout))
        assertRecorded(CaptureSnapshot.record(framed(DualImageView(main: nil, inset: nil, accessibilityLabel: "", corners: .host(Tokens.Radii.globalCard), onMedia: false), page: true), surface: "daily.dualimage", state: "loading-page", layout: layout))
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

        // The backdrop is the collage's first photo (MERGE L-7): a real sample photo at the display rendition's shape.
        let firstPhoto = CaptureTestImages.scene(0, CGSize(width: 900, height: 1200))
        let firstPhotoPath = "u/u1/m1/display.jpg"

        let rig = CaptureTestRig()
        rig.openInvitation(closingIn: -60)
        rig.collages.collage = collage(pages: 2)
        rig.collages.images = ["g/g1/collages/c1/v1/display-1.jpg": page, "g/g1/collages/c1/v1/display-2.jpg": secondPage, firstPhotoPath: firstPhoto]
        rig.collages.firstPhotoPaths = [PostID("p1"): firstPhotoPath]
        let ready = rig.collageModel()
        await ready.load()
        assertRecorded(CaptureSnapshot.record(CollageView(model: ready), surface: "collage.view", state: "ready", appearances: CaptureSnapshot.both))
        assertRecorded(CaptureSnapshot.record(CollageView(model: ready), surface: "collage.share", state: "pill", appearances: CaptureSnapshot.both))

        let singleRig = CaptureTestRig()
        singleRig.openInvitation(closingIn: -60)
        singleRig.collages.collage = collage(pages: 1)
        singleRig.collages.images = ["g/g1/collages/c1/v1/display-1.jpg": page, firstPhotoPath: firstPhoto]
        singleRig.collages.firstPhotoPaths = [PostID("p1"): firstPhotoPath]
        let single = singleRig.collageModel()
        await single.load()
        assertRecorded(CaptureSnapshot.record(CollageView(model: single), surface: "collage.view", state: "ready-one-page"))

        // First photo not resolvable (offline / blocked): page 1's image stands in as the backdrop.
        let pageBackdropRig = CaptureTestRig()
        pageBackdropRig.openInvitation(closingIn: -60)
        pageBackdropRig.collages.collage = collage(pages: 1)
        pageBackdropRig.collages.images = ["g/g1/collages/c1/v1/display-1.jpg": page]
        let pageBackdrop = pageBackdropRig.collageModel()
        await pageBackdrop.load()
        assertRecorded(CaptureSnapshot.record(CollageView(model: pageBackdrop), surface: "collage.view", state: "backdrop-page-1"))

        let noShareRig = CaptureTestRig()
        noShareRig.openInvitation(closingIn: -60)
        var withoutShare = collage(pages: 1)
        withoutShare.sharePath = nil
        noShareRig.collages.collage = withoutShare
        noShareRig.collages.images = ["g/g1/collages/c1/v1/display-1.jpg": page, firstPhotoPath: firstPhoto]
        noShareRig.collages.firstPhotoPaths = [PostID("p1"): firstPhotoPath]
        let noShare = noShareRig.collageModel()
        await noShare.load()
        assertRecorded(CaptureSnapshot.record(CollageView(model: noShare), surface: "collage.share", state: "not-ready"))

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

    /// The widget rendition (600 × 630): `photo`, or a collage page cropped to that shape; the poster's avatar.
    private func content(_ state: GroupWidgetContent.State, photo: String = CaptureTestImages.scenes[0], avatar: Bool = true) -> GroupWidgetContent {
        let size = CGSize(width: 600, height: 630)
        let rendition: UIImage? = switch state {
        case .photo: CaptureTestImages.photo(size, named: photo)
        case .collage: SamplePhotos.cropped(CaptureTestImages.collagePage(CGSize(width: 600, height: 1067)), to: size)
        default: nil
        }
        return GroupWidgetContent(
            state: state, groupName: "Family", senderName: "Ana Lima", postedAt: CaptureTestRig.fixedNow,
            photo: rendition,
            avatar: avatar ? CaptureTestImages.avatar(CGSize(width: 60, height: 60)) : nil
        )
    }

    /// The Home Screen widget: container background + overlay, clipped like the system container (the system's own
    /// corner — the HIG container — drawn here with Retro's widget corner `widget.android.radius.widget` for the comp), on
    /// a wallpaper of `color.global.controlRaised`.
    private func home(_ content: GroupWidgetContent, size: CGSize) -> some View {
        ZStack {
            WidgetContainerBackground(content: content)
            WidgetOverlay(content: content)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radii.widgetAndroidRadiusWidget, style: .continuous))
        .padding(Tokens.Sizes.globalScreenMargin)
        .background(Tokens.Colors.globalControlRaised)
    }

    /// Lock Screen accessory: vibrant mode approximated with zero saturation on a dark wallpaper.
    private func lock<V: View>(_ view: V, size: CGSize) -> some View {
        view
            .frame(width: size.width, height: size.height)
            .saturation(0)
            .padding(Tokens.Sizes.globalScreenMargin)
            .background(Tokens.Colors.globalControlOnDeep)
    }

    private func record<V: View>(_ view: V, size: CGSize, surface: String, state: String, appearances: [ColorScheme] = [.light]) {
        let margin = Tokens.Sizes.globalScreenMargin * 2
        let url = CaptureSnapshot.record(view, surface: surface, state: state, appearances: appearances, layout: .fixed(width: size.width + margin, height: size.height + margin))
        XCTAssertNotNil(url)
    }

    func testHomeWidgetFamiliesAndStates() {
        let families: [(String, CGSize)] = [
            ("widget.home.small", size(Tokens.Layouts.WidgetHomeSmallLayoutSize.w393h852)),
            ("widget.home.medium", size(Tokens.Layouts.WidgetHomeMediumLayoutSize.w393h852)),
            ("widget.home.large", size(Tokens.Layouts.WidgetHomeLargeLayoutSize.w393h852)),
            ("widget.home.xl", size(Tokens.Layouts.WidgetHomeXlLayoutSize.ipad1024x1366)),
        ]
        for (surface, frame) in families {
            record(home(content(.photo), size: frame), size: frame, surface: surface, state: "photo", appearances: CaptureSnapshot.both)
            record(home(content(.collage), size: frame), size: frame, surface: surface, state: "collage")
            record(home(.loading, size: frame), size: frame, surface: surface, state: "loading")
            record(home(GroupWidgetContent(state: .empty), size: frame), size: frame, surface: surface, state: "empty")
            record(home(GroupWidgetContent(state: .notSetUp), size: frame), size: frame, surface: surface, state: "not-set-up")
            record(home(GroupWidgetContent(state: .signedOut), size: frame), size: frame, surface: surface, state: "signed-out")
        }
        let small = size(Tokens.Layouts.WidgetHomeSmallLayoutSize.w393h852)
        let longNames = GroupWidgetContent(state: .photo, groupName: "Saturday Morning Climbing Crew", senderName: "Maximiliana",
                                           postedAt: CaptureTestRig.fixedNow, photo: CaptureTestImages.photo(CGSize(width: 600, height: 630), named: CaptureTestImages.scenes[5]))
        record(home(longNames, size: small), size: small, surface: "widget.home.small", state: "long-names")
    }

    func testArrivalSwapsInstantly() {
        let small = size(Tokens.Layouts.WidgetHomeSmallLayoutSize.w393h852)
        record(home(content(.photo, photo: CaptureTestImages.scenes[0]), size: small), size: small, surface: "widget.arrival", state: "before")
        record(home(content(.photo, photo: CaptureTestImages.scenes[3]), size: small), size: small, surface: "widget.arrival", state: "after")
        XCTAssertEqual(Tokens.Durations.widgetArrivalDurationTransition, 0, "no transition between entries")
    }

    func testLockScreenWidgets() {
        let rect = size(Tokens.Layouts.WidgetLockRectLayoutSize.w393h852)
        let circle = size(Tokens.Layouts.WidgetLockCircularLayoutSize.w393h852)
        let inline = size(Tokens.Layouts.WidgetLockInlineLayoutSize.w393h852)
        record(lock(WidgetRectangularSlot(content: content(.photo)), size: rect), size: rect, surface: "widget.lock.rect", state: "photo", appearances: CaptureSnapshot.both)
        record(lock(WidgetRectangularSlot(content: content(.photo, avatar: false)), size: rect), size: rect, surface: "widget.lock.rect", state: "no-avatar")
        record(lock(WidgetRectangularSlot(content: content(.collage)), size: rect), size: rect, surface: "widget.lock.rect", state: "collage")
        record(lock(WidgetRectangularSlot(content: GroupWidgetContent(state: .empty)), size: rect), size: rect, surface: "widget.lock.rect", state: "empty")
        record(lock(WidgetRectangularSlot(content: GroupWidgetContent(state: .notSetUp)), size: rect), size: rect, surface: "widget.lock.rect", state: "not-set-up")
        record(lock(WidgetRectangularSlot(content: GroupWidgetContent(state: .signedOut)), size: rect), size: rect, surface: "widget.lock.rect", state: "signed-out")
        record(lock(WidgetRectangularSlot(content: .loading), size: rect), size: rect, surface: "widget.lock.rect", state: "loading")
        record(lock(WidgetCircularSlot(content: content(.photo)), size: circle), size: circle, surface: "widget.lock.circular", state: "photo", appearances: CaptureSnapshot.both)
        record(lock(WidgetCircularSlot(content: content(.photo, avatar: false)), size: circle), size: circle, surface: "widget.lock.circular", state: "no-avatar")
        record(lock(WidgetCircularSlot(content: content(.collage)), size: circle), size: circle, surface: "widget.lock.circular", state: "collage")
        record(lock(WidgetCircularSlot(content: GroupWidgetContent(state: .empty)), size: circle), size: circle, surface: "widget.lock.circular", state: "empty")
        let white = Tokens.Colors.globalTextOnMedia
        record(lock(WidgetInlineSlot(content: content(.photo)).foregroundStyle(white), size: inline), size: inline, surface: "widget.lock.inline", state: "photo", appearances: CaptureSnapshot.both)
        record(lock(WidgetInlineSlot(content: content(.collage)).foregroundStyle(white), size: inline), size: inline, surface: "widget.lock.inline", state: "collage")
        record(lock(WidgetInlineSlot(content: GroupWidgetContent(state: .notSetUp)).foregroundStyle(white), size: inline), size: inline, surface: "widget.lock.inline", state: "not-set-up")
    }

    func testLiveActivityPresentations() {
        let attributes = DailyInvitationAttributes(groupID: "g1", invitationID: "i1")
        let now = Date()
        let state = DailyInvitationAttributes.ContentState(closesAt: now.addingTimeInterval(95), groupName: "Family")
        let lockWidth = WidgetLayoutSize.width(Tokens.Layouts.DailyLiveactivityLayoutSize.w393lockScreen) ?? 0
        let lockSize = CGSize(width: lockWidth, height: InvitationLockScreenSlot.minimumHeight ?? 0)
        let lockScreen = InvitationLockScreenSlot(attributes: attributes, state: state, isStale: false, now: now)
            .frame(width: lockSize.width, height: lockSize.height)
            .background(Tokens.Colors.globalBackgroundDeep)
        record(lockScreen, size: lockSize, surface: "daily.liveactivity", state: "lock-screen", appearances: CaptureSnapshot.both)
        let stale = InvitationLockScreenSlot(attributes: attributes, state: state, isStale: true, now: now)
            .frame(width: lockSize.width, height: lockSize.height)
            .background(Tokens.Colors.globalBackgroundDeep)
        record(stale, size: lockSize, surface: "daily.liveactivity", state: "lock-screen-stale")

        // Dynamic Island comps: the island itself is system black (`daily.liveactivity.layout.colors.islandBackground`).
        let compactWidth = (WidgetLayoutSize.width(Tokens.Layouts.DailyLiveactivityLayoutSize.w393compact) ?? 0) * 2 + lockWidth / 3
        let compactSize = CGSize(width: compactWidth, height: WidgetLayoutSize.minimumHeight(Tokens.Layouts.DailyLiveactivityLayoutSize.w393compact) ?? 0)
        let compact = HStack {
            InvitationCompactLeadingSlot()
            Spacer()
            InvitationCompactTrailingSlot(state: state, now: now)
        }
        .padding(.horizontal, Tokens.Sizes.dailyLiveactivitySizeLockScreenMargin)
        .frame(width: compactSize.width, height: compactSize.height)
        .background(Capsule().fill(Tokens.Colors.globalBackgroundDeep))
        record(compact, size: compactSize, surface: "daily.liveactivity", state: "compact")

        let minimalSize = CGSize(width: compactSize.height, height: compactSize.height)
        record(InvitationMinimalSlot(state: state, now: now).frame(width: minimalSize.width, height: minimalSize.height).background(Circle().fill(Tokens.Colors.globalBackgroundDeep)),
               size: minimalSize, surface: "daily.liveactivity", state: "minimal")

        let expandedSize = CGSize(width: lockWidth, height: lockSize.height * 2)
        let expanded = VStack {
            HStack {
                InvitationCompactLeadingSlot()
                Spacer()
                InvitationCompactTrailingSlot(state: state, now: now)
            }
            Spacer()
            InvitationExpandedSlot(state: state)
        }
        .padding(Tokens.Sizes.dailyLiveactivitySizeLockScreenMargin)
        .frame(width: expandedSize.width, height: expandedSize.height)
        .background(RoundedRectangle(cornerRadius: Tokens.Radii.globalCardLarge, style: .continuous).fill(Tokens.Colors.globalBackgroundDeep))
        record(expanded, size: expandedSize, surface: "daily.liveactivity", state: "expanded")
    }
}

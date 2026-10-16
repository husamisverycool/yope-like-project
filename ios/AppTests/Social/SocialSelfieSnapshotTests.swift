// Snapshots of viewer.selfiereaction (design/surfaces/viewer.selfiereaction.md): the faces on the photo, the capture
// layer in each state, and the Reactions sheet with selfie rows, written to
// ios/build/snapshots/social/<surface>-<state>-<light|dark>.png for design/verification/. The viewer is a media
// surface (dark in both appearances by design); the sheet follows the appearance. Real sample photos (fixtures/photos/):
// the posts' (`SocialSamplePhotos`), the people's portraits as their selfies, the selfie fixture in the live circle.
@testable import App
import AppData
import AppModels
import DesignSystem
import SwiftUI
import XCTest

@MainActor
final class SocialSelfieSnapshotTests: XCTestCase {
    private var account: AccountDependencies!
    private var camera: FakeCaptureCamera!

    override func setUp() async throws {
        try await super.setUp()
        let suite = "social.selfie.snapshots.account"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        account = AccountDependencies.live(
            data: InMemoryAccountData(signedIn: SocialDemo.me),
            router: AppRouter(parser: .init(universalLinkHosts: [])),
            configuration: AppConfiguration(),
            notifications: StaticNotificationAuthorizer(status: .granted),
            purchases: InMemoryPurchases(),
            liveActivity: LiveActivityPreference(defaults: defaults),
            refusals: InMemoryAgeGateRefusalStore(),
            onboarding: OnboardingRecord(defaults: defaults)
        )
        camera = FakeCaptureCamera()
        camera.frontPreviewImage = CaptureTestImages.photo(CGSize(width: 900, height: 900), named: CaptureTestImages.selfie)
        camera.frontStill = CaptureTestImages.still(named: CaptureTestImages.selfie, position: .front)
    }

    /// The demo backend with selfies: Ana and Cleo then Ben on Ben's dinner (p1, three faces), Ben on Ana's first snow
    /// (p2), Ana and Ben on my own hike (p3).
    private func makeData() -> FakeSocialData {
        let data = SocialDemo.makeData()
        let selfies = [
            selfie(1, on: SocialDemo.p1, by: SocialDemo.ana, minutes: 72),
            selfie(2, on: SocialDemo.p1, by: SocialDemo.cleo, minutes: 74),
            selfie(3, on: SocialDemo.p1, by: SocialDemo.ben, minutes: 76),
            selfie(4, on: SocialDemo.p2, by: SocialDemo.ben, minutes: 1510),
            selfie(5, on: SocialDemo.p3, by: SocialDemo.ana, minutes: 3000),
            selfie(6, on: SocialDemo.p3, by: SocialDemo.ben, minutes: 3010),
        ]
        data.update { $0.selfies = selfies }
        let suite = "social.selfie.snapshots"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        let front = camera!
        SocialServices.shared = SocialServices(
            data: data, images: Self.images(), flags: SocialFlags(defaults: defaults), saver: DemoPhotoSaver(),
            selfieCamera: { front }
        )
        return data
    }

    private func selfie(_ n: Int, on post: PostID, by user: UserID, minutes: Double) -> SelfieReaction {
        SelfieReaction(
            id: SelfieReactionID("00000000-0000-4000-8000-0000000b" + String(3000 + n).suffix(4)), postID: post, userID: user,
            groupID: SocialDemo.groupID, imagePath: "fake/selfie/\(user.rawValue.suffix(2))", createdAt: SocialDemo.at(minutes * 60)
        )
    }

    /// The sample photos, with each person's portrait as their selfie.
    private static func images() -> SocialImageLoader {
        SocialImageLoader { path in
            SocialSamplePhotos.image(for: path.replacingOccurrences(of: "fake/selfie/", with: "fake/avatar/"))
        }
    }

    private func viewer(_ start: PostID, data: FakeSocialData) async -> PhotoViewerModel {
        let model = PhotoViewerModel(
            context: PhotoViewerContext(postIDs: [SocialDemo.p1, SocialDemo.p2, SocialDemo.p3, SocialDemo.p4], start: start, groupID: SocialDemo.groupID),
            data: data
        )
        await model.load()
        return model
    }

    /// Records `social/<surface>-<state>-<appearance>.png`.
    private func record<V: View>(
        _ view: @autoclosure () -> V,
        _ surface: String,
        _ state: String,
        _ appearances: [ColorScheme] = [.light],
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        for scheme in appearances {
            let name = surface + "-" + state + "-" + (scheme == .dark ? "dark" : "light")
            let built = view()
            let content = NavigationStack { built }
                .environment(account)
                .environment(\.colorScheme, scheme)
            guard let written = SnapshotRecorder.record(content, named: name, group: "social", file: file, testName: testName, line: line) else {
                XCTFail("snapshot \(name) not written", file: file, line: line)
                continue
            }
            let target = written.deletingLastPathComponent().appendingPathComponent(name + ".png")
            try? FileManager.default.removeItem(at: target)
            XCTAssertNoThrow(try FileManager.default.moveItem(at: written, to: target), file: file, line: line)
        }
    }

    // MARK: Faces on the photo

    func testFacesOnThePhoto() async {
        let data = makeData()
        let three = await viewer(SocialDemo.p1, data: data)
        record(PhotoViewerView(model: three, presentation: .pushed), "viewer.selfiereaction", "stack", [.light, .dark])

        let one = await viewer(SocialDemo.p2, data: data)
        record(PhotoViewerView(model: one, presentation: .pushed), "viewer.selfiereaction", "stack-one")

        let own = await viewer(SocialDemo.p3, data: data)
        record(PhotoViewerView(model: own, presentation: .pushed), "viewer.selfiereaction", "stack-own-photo")

        // Sending: my face at the leading end at once, drawn from the JPEG just taken.
        let sending = await viewer(SocialDemo.p2, data: data)
        data.update { $0.holds.insert("reactWithSelfie") }
        let jpeg = CaptureTestImages.jpeg(CGSize(width: 300, height: 300), named: CaptureTestImages.selfie)
        let task = Task { await sending.sendSelfie(jpeg, to: SocialDemo.p2) }
        _ = await socialEventually { sending.selfies.sending.contains(SocialDemo.p2) }
        record(PhotoViewerView(model: sending, presentation: .pushed), "viewer.selfiereaction", "sending")
        task.cancel()
        data.update { $0.holds.remove("reactWithSelfie") }
        await task.value

        let idle = await viewer(SocialDemo.p4, data: data)
        record(PhotoViewerView(model: idle, presentation: .pushed), "viewer.selfiereaction", "idle")
    }

    // MARK: Capture layer

    private func layer(_ mode: SelfieCaptureModel.Mode, start: Bool = true) async -> SelfieCaptureModel {
        let layer = SelfieCaptureModel(postID: SocialDemo.p2, mode: mode, camera: camera)
        if start { await layer.start() }
        return layer
    }

    func testCaptureLayer() async {
        let data = makeData()
        let model = await viewer(SocialDemo.p2, data: data)

        let hold = await layer(.hold)
        record(PhotoViewerView(model: model, presentation: .pushed, selfieLayer: hold), "viewer.selfiereaction", "layer-hold", [.light, .dark])

        let armed = await layer(.hold)
        armed.circleFrame = CGRect(x: 0, y: 0, width: 10, height: 10)
        armed.moved(to: CGPoint(x: 5, y: 5))
        record(PhotoViewerView(model: model, presentation: .pushed, selfieLayer: armed), "viewer.selfiereaction", "layer-armed")

        let tap = await layer(.tap)
        record(PhotoViewerView(model: model, presentation: .pushed, selfieLayer: tap), "viewer.selfiereaction", "layer-tap")

        let starting = await layer(.hold, start: false)
        record(PhotoViewerView(model: model, presentation: .pushed, selfieLayer: starting), "viewer.selfiereaction", "layer-camera-starting")

        camera.authorizationStatus = .denied
        let denied = await layer(.tap)
        record(PhotoViewerView(model: model, presentation: .pushed, selfieLayer: denied), "viewer.selfiereaction", "layer-permission-denied")
        camera.authorizationStatus = .granted
    }

    // MARK: Reactions sheet

    func testReactionsSheetWithSelfies() async {
        let data = makeData()
        data.update { state in
            state.reactions += [SocialDemo.reaction(SocialDemo.p1, SocialDemo.ben, "😂", minutes: 75)]
        }
        let model = await viewer(SocialDemo.p1, data: data)
        let actions = SelfieRowActions(
            face: { SelfieFaceImages.source($0, sent: nil, displayScale: 3) },
            isAuthor: false, removeMine: { _ in }, remove: { _ in }, report: { _ in }
        )
        record(
            ReactionsSheet(
                reactions: model.reactions[SocialDemo.p1] ?? ReactionSummary(), selfies: model.selfies.summary(for: SocialDemo.p1),
                me: SocialDemo.me, profile: { model.profiles[$0] }, onRemove: { _ in }, selfieActions: actions
            ),
            "chat.reactions", "sheet-selfies", [.light, .dark]
        )

        // My selfie on Ana's photo: my row is a button with "Tap to remove".
        let mine = await viewer(SocialDemo.p2, data: data)
        await mine.sendSelfie(CaptureTestImages.jpeg(CGSize(width: 300, height: 300), named: CaptureTestImages.selfie), to: SocialDemo.p2)
        let sent = mine.selfies.sentImages
        let myActions = SelfieRowActions(
            face: { SelfieFaceImages.source($0, sent: sent[$0.id], displayScale: 3) },
            isAuthor: false, removeMine: { _ in }, remove: { _ in }, report: { _ in }
        )
        record(
            ReactionsSheet(
                reactions: mine.reactions[SocialDemo.p2] ?? ReactionSummary(), selfies: mine.selfies.summary(for: SocialDemo.p2),
                me: SocialDemo.me, profile: { mine.profiles[$0] }, onRemove: { _ in }, selfieActions: myActions
            ),
            "chat.reactions", "sheet-selfies-mine"
        )
    }
}

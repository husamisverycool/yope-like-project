// Snapshots of camera.overnight part A (design/surfaces/camera.overnight.md): the mode control on the camera in Now and
// 9 AM mode (destination pill, empty leading slot), the destination sheet in its states, and settings.notifications'
// overnight switch off — ios/build/snapshots/capture/<surface>-<state>-<appearance>.png (the settings state under
// account/) for the verification images. Real sample photos (fixtures/photos/, `SamplePhotos`).
@testable import App
import AppData
import AppModels
import DesignSystem
import SwiftUI
import XCTest

@MainActor
final class CaptureOvernightSnapshotTests: XCTestCase {
    override func setUp() async throws {
        CameraCaptureModel.sessionPosition = .back
        OvernightCaptureModel.resetSession()
    }

    override func tearDown() async throws {
        OvernightCaptureModel.resetSession()
    }

    private func assertRecorded(_ url: URL?, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotNil(url, "snapshot not written", file: file, line: line)
    }

    /// The camera as the shell shows it: the view with the C-04 tab bar (media variant) under it.
    private func cameraView(_ rig: CaptureTestRig, _ model: CameraCaptureModel) -> some View {
        CameraCaptureView(model: model, makeSendTo: { rig.sendToModel(media: $0) }, sendCenter: rig.sendCenter)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AppTabBar(selected: .camera, surface: .media) { _ in }
            }
    }

    /// 9 AM chosen for this session with `deselect` left out, the sheet closed.
    private func chooseLater(_ rig: CaptureTestRig, deselect: [String] = []) async {
        let model = rig.overnightModel()
        model.setMode(.later)
        await model.loadGroups()
        for id in deselect { model.toggle(id) }
        model.destinationClosed()
    }

    func testModeControlOnTheCamera() async {
        let rig = CaptureTestRig()
        rig.usePhotos()
        let now = rig.cameraModel()
        await now.appear()
        assertRecorded(CaptureSnapshot.record(cameraView(rig, now), surface: "camera.overnight", state: "now", appearances: CaptureSnapshot.both))

        await chooseLater(rig)
        let later = rig.cameraModel()
        await later.appear()
        assertRecorded(CaptureSnapshot.record(cameraView(rig, later), surface: "camera.overnight", state: "later", appearances: CaptureSnapshot.both))

        OvernightCaptureModel.resetSession()
        await chooseLater(rig, deselect: [CaptureFakes.groups[1].id])
        let one = rig.cameraModel()
        await one.appear()
        assertRecorded(CaptureSnapshot.record(cameraView(rig, one), surface: "camera.overnight", state: "later-one-group"))

        OvernightCaptureModel.resetSession()
        let long = CaptureTestRig()
        long.usePhotos(scene: 3)
        long.groups.groups = [CaptureGroup(id: "fake-group-1", name: "The Sunday dinner club at the old house by the lake", coverPath: nil)]
        await chooseLater(long)
        let truncated = long.cameraModel()
        await truncated.appear()
        assertRecorded(CaptureSnapshot.record(cameraView(long, truncated), surface: "camera.overnight", state: "later-long-name"))
    }

    func testDestinationSheet() async {
        let rig = CaptureTestRig()
        rig.usePhotos()
        let loaded = rig.overnightModel()
        loaded.setMode(.later)
        await loaded.loadGroups()
        _ = await captureEventually { !loaded.covers.isEmpty }
        assertRecorded(CaptureSnapshot.record(OvernightDestinationSheet(model: loaded), surface: "camera.overnight", state: "destination-sheet", appearances: CaptureSnapshot.both))

        loaded.toggle(CaptureFakes.groups[0].id)
        assertRecorded(CaptureSnapshot.record(OvernightDestinationSheet(model: loaded), surface: "camera.overnight", state: "destination-sheet-one-off"))

        OvernightCaptureModel.resetSession()
        let emptyRig = CaptureTestRig()
        emptyRig.groups.groups = []
        let empty = emptyRig.overnightModel()
        empty.setMode(.later)
        await empty.loadGroups()
        assertRecorded(CaptureSnapshot.record(OvernightDestinationSheet(model: empty), surface: "camera.overnight", state: "destination-sheet-no-groups"))

        OvernightCaptureModel.resetSession()
        let slowRig = CaptureTestRig()
        slowRig.groups.suspendsLoad = true
        let loading = slowRig.overnightModel()
        let task = Task { await loading.loadGroups() }
        _ = await captureEventually { loading.listState == .loading }
        assertRecorded(CaptureSnapshot.record(OvernightDestinationSheet(model: loading), surface: "camera.overnight", state: "destination-sheet-loading"))
        task.cancel()
    }

    func testSettingsSwitchOff() async {
        let data = InMemoryAccountData(signedIn: UserID("00000000-0000-4000-8000-00000000a001"))
        let suite = "capture.overnight.snapshots." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let dependencies = AccountDependencies.live(
            data: data,
            router: AppRouter(parser: .init(universalLinkHosts: [])),
            configuration: AppConfiguration(),
            notifications: StaticNotificationAuthorizer(status: .granted),
            purchases: InMemoryPurchases(),
            liveActivity: LiveActivityPreference(defaults: defaults),
            refusals: InMemoryAgeGateRefusalStore(),
            onboarding: OnboardingRecord(defaults: defaults)
        )
        let model = SettingsNotificationsModel(data: data, notifications: StaticNotificationAuthorizer(status: .granted))
        await model.load()
        await model.setOvernightAlerts(false)
        let url = AccountSnapshot.record(
            NavigationStack { SettingsNotificationsView(model: model) }, surface: "settings.notifications", state: "overnight-off",
            dependencies: dependencies
        )
        XCTAssertNotNil(url)
    }
}

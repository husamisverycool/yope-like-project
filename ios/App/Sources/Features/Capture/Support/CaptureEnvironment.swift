// Surfaces: camera.capture, camera.sendto, camera.fromwidget, daily.capture, collage.view,
// collage.share (design/surfaces/<id>.md; reference images listed there). Wires the capture screens to their services: live (AppEnvironment) or, for UI
// tests, fakes selected by `CaptureLaunchArgument.fakes`.
import AppData
import AppModels
import AppServices
import Foundation

@MainActor
final class CaptureEnvironment {
    static let shared: CaptureEnvironment = {
        #if DEBUG
        if CaptureLaunchArgument.isSet(CaptureLaunchArgument.fakes) {
            return CaptureFakes.environment(arguments: DemoMode.launchArguments, router: AppEnvironment.shared.router)
        }
        // The real-server journey: everything live but the camera (the simulator has none).
        if CaptureLaunchArgument.isSet(CaptureLaunchArgument.fakeCamera) {
            return .live(AppEnvironment.shared) { _ in FakeCaptureCamera() }
        }
        #endif
        return .live(AppEnvironment.shared)
    }()

    let makeCamera: @MainActor (_ supportsDualCapture: Bool) -> CaptureCamera
    let makeVoiceRecorder: @MainActor () -> CaptureVoiceRecorder
    let library: CaptureLibrary
    let groups: CaptureGroupSource
    let premium: CapturePremium
    let posting: CapturePosting
    let invitations: CaptureInvitationSource
    let collages: CaptureCollageSource
    let navigation: CaptureNavigation
    let coach: CaptureCoachStore
    let sendCenter: CaptureSendCenter
    /// camera.overnight's 9 AM uploads (they continue after the camera closes).
    let overnightQueue: CaptureOvernightQueue
    /// `public_app_config.batch_max_photos` (the library picker's limit); nil when unknown (one photo). Live: read once
    /// from the server, then kept.
    var batchLimit: @MainActor () async -> Int? = { nil }
    /// share.in: the photos another app shared, taken from the App Group inbox (at most `limit`); none by default.
    var sharedItems: @MainActor (_ limit: Int) async -> [CapturedMedia] = { _ in [] }

    init(
        makeCamera: @escaping @MainActor (_ supportsDualCapture: Bool) -> CaptureCamera,
        makeVoiceRecorder: @escaping @MainActor () -> CaptureVoiceRecorder,
        library: CaptureLibrary,
        groups: CaptureGroupSource,
        premium: CapturePremium,
        posting: CapturePosting,
        invitations: CaptureInvitationSource,
        collages: CaptureCollageSource,
        navigation: CaptureNavigation,
        coach: CaptureCoachStore
    ) {
        self.makeCamera = makeCamera
        self.makeVoiceRecorder = makeVoiceRecorder
        self.library = library
        self.groups = groups
        self.premium = premium
        self.posting = posting
        self.invitations = invitations
        self.collages = collages
        self.navigation = navigation
        self.coach = coach
        sendCenter = CaptureSendCenter(posting: posting)
        overnightQueue = CaptureOvernightQueue(posting: posting)
    }

    static func live(
        _ app: AppEnvironment,
        makeCamera: @escaping @MainActor (_ supportsDualCapture: Bool) -> CaptureCamera = { LiveCaptureCamera(supportsDualCapture: $0) }
    ) -> CaptureEnvironment {
        let data = app.data
        let environment = CaptureEnvironment(
            makeCamera: makeCamera,
            makeVoiceRecorder: { LiveCaptureVoiceRecorder() },
            library: LiveCaptureLibrary(),
            groups: LiveCaptureGroups(data: data, widgetStore: app.widgetStore),
            premium: LiveCapturePremium(environment: app),
            posting: LiveCapturePosting(data: data),
            invitations: LiveCaptureInvitations(data: data, widgetStore: app.widgetStore),
            collages: LiveCaptureCollages(data: data),
            navigation: LiveCaptureNavigation(router: app.router),
            coach: UserDefaultsCoachStore()
        )
        let limit = CaptureBatchLimit(data: data)
        environment.batchLimit = { await limit.value() }
        environment.sharedItems = { max in await ShareInImport.take(limit: max) }
        return environment
    }

    // MARK: Camera pre-warm

    /// One single-camera session for every opening of camera.capture (kept configured; stopped
    /// while the camera is not shown).
    private var singleCamera: CaptureCamera?

    func sharedSingleCamera() -> CaptureCamera {
        if let singleCamera { return singleCamera }
        let camera = makeCamera(false)
        singleCamera = camera
        return camera
    }

    /// Configures and starts the camera ahead of camera.capture (call when the camera is about to
    /// appear: the camera tab pressed, a widget or deep link received). Never asks for permission.
    func prewarmCamera() async {
        let camera = sharedSingleCamera()
        guard camera.authorization() == .granted else { return }
        try? await camera.configure(.photo(CameraCaptureModel.currentSessionPosition))
    }

    // MARK: View models

    func cameraModel(contextGroupID: String?) -> CameraCaptureModel {
        CameraCaptureModel(
            contextGroupID: contextGroupID,
            camera: sharedSingleCamera(),
            premium: premium,
            coach: coach,
            navigation: navigation,
            overnight: overnightModel(contextGroupID: contextGroupID),
            batchLimit: batchLimit,
            sharedItems: sharedItems
        )
    }

    /// camera.overnight's mode on the camera (9 AM · Now) with its groups and upload queue.
    func overnightModel(contextGroupID: String?) -> OvernightCaptureModel {
        OvernightCaptureModel(contextGroupID: contextGroupID, groups: groups, posting: posting, queue: overnightQueue)
    }

    func sendToModel(
        media: CapturedMedia,
        more: [CapturedMedia] = [],
        contextGroupID: String?,
        onClose: @escaping @MainActor () -> Void,
        onSent: @escaping @MainActor () -> Void
    ) -> SendToModel {
        SendToModel(
            media: media,
            more: more,
            contextGroupID: contextGroupID,
            groups: groups,
            premium: premium,
            library: library,
            voice: makeVoiceRecorder(),
            sendCenter: sendCenter,
            navigation: navigation,
            onClose: onClose,
            onSent: onSent
        )
    }

    func dailyModel(groupID: String, invitationID: String) -> DailyCaptureModel {
        DailyCaptureModel(
            groupID: groupID,
            invitationID: invitationID,
            camera: makeCamera(true),
            invitations: invitations,
            sendCenter: sendCenter,
            navigation: navigation
        )
    }

    func collageModel(groupID: String, invitationID: String) -> CollageModel {
        CollageModel(
            groupID: groupID,
            invitationID: invitationID,
            collages: collages,
            invitations: invitations,
            navigation: navigation
        )
    }
}

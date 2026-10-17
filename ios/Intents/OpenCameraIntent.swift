// Surface: camera.quickaccess — the system ways into the camera (design/surfaces/camera.quickaccess.md): the iOS 18
// Control Center / Lock Screen / Action button control (ios/Widgets/Sources/CameraControl.swift) and the App Shortcuts
// (ios/App/Sources/Shortcuts/CameraShortcuts.swift) run this intent. Compiled into the app and the widget extension
// (ios/project.yml): a control's intent must exist in both, and with `openAppWhenRun` the system runs it in the app.
// References: https://developer.apple.com/design/human-interface-guidelines/controls,
// https://developer.apple.com/documentation/appintents/app-shortcuts, Snapchat's Lock Screen camera control
// (https://9to5mac.com/2024/10/24/snapchat-camera-will-be-available-from-the-iphone-lock-screen-but-no-filters/).
import AppIntents
import AppModels
import Foundation

/// A group the camera can be opened for (Siri / Spotlight / Shortcuts: "Take a photo for {group}"), from the group list
/// the app writes to the App Group (`WidgetStore`).
struct CameraGroupEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "camera.quickaccess.intent.group")
    }

    static var defaultQuery: CameraGroupQuery { CameraGroupQuery() }

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct CameraGroupQuery: EntityStringQuery {
    private var groups: [CameraGroupEntity] {
        WidgetStore.forBundle(.main).groups().map { CameraGroupEntity(id: $0.id, name: $0.name) }
    }

    func entities(for identifiers: [CameraGroupEntity.ID]) async throws -> [CameraGroupEntity] {
        let all = groups
        return identifiers.compactMap { id in all.first { $0.id == id } }
    }

    func entities(matching string: String) async throws -> [CameraGroupEntity] {
        groups.filter { $0.name.localizedCaseInsensitiveContains(string) }
    }

    func suggestedEntities() async throws -> [CameraGroupEntity] {
        groups
    }
}

/// Opens the app to the camera (`camera.capture`), with the group preselected when one is given — the widget's own link
/// (`app://camera?group=<id>`, camera.fromwidget). It does not capture on a locked device (no LockedCameraCapture
/// extension): from the Lock Screen the system asks to unlock, then the app opens (`camera.quickaccess.layout.entries`).
struct OpenCameraIntent: AppIntent {
    static var title: LocalizedStringResource { "camera.quickaccess.intent.title" }
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "camera.quickaccess.intent.group")
    var group: CameraGroupEntity?

    init() {}

    init(group: CameraGroupEntity?) {
        self.group = group
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        CameraIntentInbox.open(.camera(groupID: group?.id))
        return .result()
    }
}

/// Hands a link from an intent to the app's router. The intent may run before the app's environment is ready (a cold
/// launch from the control): the link waits until the app installs its handler.
@MainActor
enum CameraIntentInbox {
    private static var pending: DeepLink?
    private static var handler: ((DeepLink) -> Void)?

    static func open(_ link: DeepLink) {
        if let handler {
            handler(link)
        } else {
            pending = link
        }
    }

    /// Called once by the app at launch; delivers a link that arrived first.
    static func install(_ handler: @escaping (DeepLink) -> Void) {
        self.handler = handler
        if let pending {
            self.pending = nil
            handler(pending)
        }
    }
}

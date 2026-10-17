// Surface: camera.quickaccess — App Shortcuts (Siri, Spotlight, the Shortcuts app) that open the camera, for every
// group or one (design/surfaces/camera.quickaccess.md; https://developer.apple.com/documentation/appintents/app-shortcuts).
// App Intents metadata is extracted at build time, so the phrases are literals: each is the copy text of the key named
// on its line ({app_name} → \(.applicationName), {group} → \(\.$group)), and tools/provenance-check.mjs fails the
// build when one drifts from design/copy/capture.json.
import AppIntents
import AppModels

struct CameraShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenCameraIntent(),
            phrases: [
                "Take a photo with \(.applicationName)", // provenance-ok: phrase of camera.quickaccess.shortcut.phrase
                "Take a photo for \(\.$group) with \(.applicationName)", // provenance-ok: phrase of camera.quickaccess.shortcut.groupPhrase
            ],
            shortTitle: "camera.quickaccess.intent.title",
            systemImageName: "camera" // provenance-ok: icon.global.camera (ios), a literal for App Intents metadata
        )
    }
}

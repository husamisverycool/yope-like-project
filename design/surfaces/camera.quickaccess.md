# camera.quickaccess — quick ways into the camera from the system

**What it is.** Opening the camera without finding the app (owner decision 34; research #11): the **iOS 18 control**
(Control Center, the Lock Screen's bottom controls, the Action button), **App Shortcuts** (Siri, Spotlight, the
Shortcuts app: "Take a photo with Jolt", "Take a photo for Family with Jolt"), the **Android Quick Settings tile** and
**Android launcher shortcuts** (a static "Camera" and one per group recently sent to). Each opens `camera.capture`
exactly as a widget tap does (`camera.fromwidget`, `app://camera[?group=<id>]`).

- **Mechanics: Snapchat's Lock Screen camera control**
  (https://9to5mac.com/2024/10/24/snapchat-camera-will-be-available-from-the-iphone-lock-screen-but-no-filters/) — one
  control that opens the app's camera. Ours does **not** capture on a locked device (Snapchat's "Camera Only" mode is a
  LockedCameraCapture extension): from the Lock Screen the system asks to unlock, then the app opens to the camera
  (`openAppWhenRun`). Capturing without unlocking would need a second camera UI in an extension with no access to the
  person's groups; HIG asks that such a camera share the app's UI, so it is left for later.
- **Components: platform** — Apple HIG Controls (https://developer.apple.com/design/human-interface-guidelines/controls),
  App Shortcuts (https://developer.apple.com/documentation/appintents/app-shortcuts), Android Quick Settings tiles
  (https://developer.android.com/develop/ui/views/quicksettings-tiles), launcher shortcuts
  (https://developer.android.com/develop/ui/views/launch/shortcuts, …/shortcuts/best-practices). Token
  `camera.quickaccess.layout.entries`.

## Structure and elements

| entry | what shows | tokens | copy | behaviour |
|---|---|---|---|---|
| iOS control (18+) | the symbol on the Lock Screen; symbol + title in Control Center at larger sizes; symbol in the Dynamic Island for the Action button | `icon.global.camera` | title `camera.quickaccess.control.title` ("Camera"); gallery description `.control.description`; Action button hint `.control.actionHint` ("Take photo") | runs `OpenCameraIntent` → the app opens to the camera (unlock first on the Lock Screen) |
| App Shortcuts | Spotlight / Shortcuts tile "Take Photo"; Siri phrases | `icon.global.camera` | `camera.quickaccess.intent.title`, phrases `.shortcut.phrase`, `.shortcut.groupPhrase`; parameter `.intent.group` | the camera, with the spoken / chosen group preselected; the groups come from the App Group list and are refreshed whenever it changes |
| Android Quick Settings tile | the tile: icon, label, subtitle; always inactive (a button, not a switch) | `drawable/ic_tile_camera` (Material `photo_camera` outlined, solid white vector) | label `camera.quickaccess.tile.label` (the app's name), subtitle `.tile.subtitle` ("Camera") | collapses the panel and opens the camera; on a secure lock screen `unlockAndRun` first |
| Android launcher shortcuts | long-press menu of the app icon | `drawable/ic_shortcut_camera` (adaptive: the same glyph on the app icon's media black, `color.global.backgroundDeep`) | static: short `camera.quickaccess.shortcut.short` ("Camera"), long `.shortcut.long` ("Take photo"); dynamic: short = the group's name, long `.shortcut.groupLong` ("Take photo for {group}") | the camera (with that group); dynamic ones are the 3 groups most recently sent to (4 shortcuts in all), pushed after each send |

## States

| state | behaviour |
|---|---|
| signed out | the app opens on sign-up (the link waits for `setReady`, as every deep link) |
| no groups | the camera opens with nobody preselected (as `app://camera`) |
| a group gone (left / deleted) | iOS: the parameter no longer resolves → the camera without a group; Android: its dynamic shortcut is removed when the group list loads |
| camera permission denied | `camera.capture`'s own denied state |
| loading / empty / error / offline | n/a (system UI) |

## Motion, haptics

System (control, tile, shortcuts). None of our own.

## Accessibility

System labels from the titles above; the tile's content description is its label.

## Platform notes

- iOS: `ios/Intents/OpenCameraIntent.swift` (app + widget extension), `ios/Widgets/Sources/CameraControl.swift`
  (`@available(iOS 18)` in the widget bundle), `ios/App/Sources/Shortcuts/CameraShortcuts.swift`. App Intents need
  compile-time literals: titles are copy keys resolved from the generated `Localizable.strings`; the phrases repeat the
  copy text and `tools/provenance-check.mjs` fails if they drift.
- Android: `CameraTileService` (feature/capture), static `res/xml/shortcuts.xml` (app), dynamic shortcuts
  (`CameraShortcuts`, feature/capture).

## Do-not-copy

Snapchat's name, ghost glyph and "Camera Only" UI.

## Gaps

| item | status |
|---|---|
| capturing from the Lock Screen without unlocking (LockedCameraCapture) | not built (documented above) |

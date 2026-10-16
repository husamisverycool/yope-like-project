# camera.fromwidget — a widget tap opens straight into the camera

**Mechanics: Locket** ("Tap the widget to open the camera"). No screen of its own: the route from any widget
(`widget.home.*`, `widget.lock.*`, `widget.android`) into `camera.capture` with the widget's group preselected in
`camera.sendto`. **Visual reference: none** — the destination is drawn as `camera.capture` (Retro components on the
media surface). Retro's own widget tap reloads the widget (its "Tap to reload" states); our tap opens the camera
(RC-9). Decisions: `design/MERGE_DECISIONS.md` RC-9.

## References

| image / source | what it verifies |
|---|---|
| `references/auto/locket/store/locket-store-07.png` ("Tap the widget to open the camera"), `references/auto/locket/play/locket-play-05.png` | the mechanic on iOS and Android |
| `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` `app_widget_empty_message` ("No media. Tap to reload") | Retro's tap behaviour (not used — RC-9) |

## Structure

1. The member taps a widget.
2. The app opens (cold or warm) directly on `camera.capture` — no splash, intro or interstitial.
3. After a capture, `camera.sendto` opens with the widget's group selected.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| tap target | `camera.fromwidget.layout.target` | none (the widget's own accessibility label, `widget.home.small.a11y.*`) | iOS: `widgetURL(app://camera?group=<id>)` on the whole widget; Android: a `PendingIntent` (ACTION_VIEW, same URI) on the Glance root (`actionStartActivity`) |
| group preselection | — | — | `DeepLink.camera(groupID:)`; a missing or unreadable id still opens the camera with nothing preselected; `camera.sendto` then uses its no-context default |

## States

| state | behaviour |
|---|---|
| signed out | the app opens on its sign-in flow (`auth.*`); the camera after sign-in (the widget shows `widget.home.small.empty.signedOut`) |
| group left / deleted | camera opens; nothing preselected |
| camera permission denied | `camera.capture` permission-denied state |
| offline | camera works; sending handled in `camera.sendto` |
| loading / empty / error | none of its own (no screen) |

## Motion

The system app-launch animation (zoom from the widget) — PLATFORM. Reduce Motion: the system's.

## Haptics

None (system launch; Retro's tap haptic applies to in-app presses only).

## Accessibility

The widget element announces its label (`widget.home.small.a11y.photo` / `.a11y.collage` or its state text) with the
button trait; activating it opens the camera. Focus lands on the camera page's title (`camera.capture` focus order).

## Data & actions

Deep link `app://camera?group=<group_id>` (`ios/Packages/AppCore/Sources/AppModels/DeepLink.swift` `.camera`,
`android/core/model/src/main/kotlin/app/model/DeepLink.kt` `Camera`). No API call on open. Out: `camera.capture` →
`camera.sendto`.

## Platform notes

- Android `DeepLink.Camera(groupId: String)` requires an id; it must accept none (MERGE_DECISIONS C-24, still open).
- Locked iPhone: the tap first asks for unlock (system). A camera on the locked device (LockedCameraCapture + Control
  widget) is in no reference → not built.
- Android lock-screen hub: launched activities require authentication (default) — PLATFORM_CONSTRAINTS §4.2.

## Do-not-copy

Locket's analytics event names; Retro's "Tap to reload" behaviour.

## Gaps

None BLOCKED.

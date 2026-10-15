# camera.fromwidget — a widget tap opens straight into the camera

Reference: **Locket** ("Tap the widget to open the camera"). No screen of its own: it is the route from any
home-screen or Lock Screen widget into `camera.capture`, with the widget's group preselected in `camera.sendto`.

## References

| image | what it verifies |
|---|---|
| `references/auto/locket/store/locket-store-07.png` (headline "Tap the widget to open the camera") | behavior |
| `references/auto/locket/play/locket-play-05.png` | same on Android |
| Locket APK 1.243.0 Hermes strings 'logOpenedFromWidget', 'Failed to parse widget launch URL' (locket.md §5) | the widget launches the app with a URL |

## Structure

1. The member taps a widget (`widget.home.*`, `widget.lock.*`, `widget.android`).
2. The app opens (cold or warm) directly on `camera.capture` — no splash, intro or interstitial.
3. When the member captures, `camera.sendto` opens with the widget's group selected.

## Elements

| element | tokens | copy | behavior |
|---|---|---|---|
| tap target | `camera.fromwidget.layout.target` | none (the widget's accessibility label describes the photo; see widget specs) | iOS: `widgetURL(app://camera?group=<id>)` on the whole widget (a `Button(intent:)` must "do more than open the app", so a URL); Android: a `PendingIntent` (ACTION_VIEW, same URI) on the widget root |
| group preselection | — | — | `DeepLink.camera(groupID:)`; an unreadable or missing id still opens the camera with nothing preselected (DeepLinkParser) — then `camera.sendto` uses its no-context default |

## States

| state | behavior |
|---|---|
| signed out | the app opens on its sign-in flow (auth surfaces); the camera opens after sign-in |
| group left / deleted | camera opens; nothing preselected (the id no longer matches a membership) |
| camera permission denied | `camera.capture` denied state |
| offline | camera works; sending handled in `camera.sendto` |
| loading / empty / error | none of its own (no screen) |

## Motion

The system app-launch animation (zoom from the widget) — PLATFORM; nothing custom. Reduce Motion: the system's.

## Haptics

None (system launch).

## Accessibility

The widget element announces its photo label (`widget.home.small.a11y.*`) and is a button; activating it opens the
camera. Focus lands on the camera's first control (flash) — `camera.capture` focus order.

## Data & actions

Deep link `app://camera?group=<group_id>` (`ios/Packages/AppCore/Sources/AppModels/DeepLink.swift` `.camera`,
`android/core/model/.../DeepLink.kt` `Camera`). No API call on open. Out: `camera.capture` → `camera.sendto`.

## Platform notes

- Android's `DeepLink.Camera(groupId: String)` requires an id; it must accept none (MERGE_DECISIONS C-24).
- Locked iPhone: the tap first asks for unlock (the system). A camera on the locked device would need a
  LockedCameraCapture extension + Control widget (iOS 18); not in any reference → not built.
- Android lock-screen hub: activities launched from it need authentication (the default) — PLATFORM_CONSTRAINTS §4.2.

## Do-not-copy

Locket's analytics event names; nothing visual.

## Gaps

None BLOCKED. Locket's iOS mechanism is not observable (native app); the URL route is the platform's documented way.

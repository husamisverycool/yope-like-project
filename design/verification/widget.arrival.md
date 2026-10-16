# Verification — `widget.arrival` (iOS, Pass 4 — Retro redesign)

New photo on the widget — `ios/Widgets/Sources/GroupPhotoWidget.swift` (timeline), `ios/NotificationService/Sources/NotificationService.swift` (rendition + reload).

Checklist written from the spec (`design/surfaces/widget.arrival.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>-<light|dark>.png` (every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/widget.arrival.png` next to the reference image(s) below.

Reference image(s): `references/auto/locket/frames/locket-tt-7168613044728155438-15.133s-widget-placeholder-just-added.jpg`, `references/auto/retro/apk/retro-android-2026.10.1150-excerpts.txt §WIDGET PROVIDERS`

Snapshots (CI, `ios/build/snapshots/capture/`): `widget.arrival-before-light.png`, `widget.arrival-after-light.png`

**Summary: 2 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Refresh

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `widget.arrival.duration.transition` | 0 ms (SOURCED) | 0 ms swap | `.transition(.identity)`, `contentTransition(.identity)` |
| matched | `widget.arrival.duration.expectedDelay` | 300000 ms (SOURCED) | QA bound ≤ 5 min | NSE reload + timeline `.after(15…60 min)` jittered |

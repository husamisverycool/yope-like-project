# Verification — `daily.dualimage` (iOS, Pass 4 — Retro redesign)

Back + front photo — `ios/App/Sources/Features/Capture/Daily/DualImageView.swift` (also placed by social's viewer).

Checklist written from the spec (`design/surfaces/daily.dualimage.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>-<light|dark>.png` (every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/daily.dualimage.png` next to the reference image(s) below.

Reference image(s): `references/auto/bereal/help/help-21083730354333_feed-bonus-3x.png`, `references/auto/bereal/help/help-21083708285725_bts-post-preview-2x.png`, `references/auto/retro/store/retro-store-01.png`

Snapshots (CI, `ios/build/snapshots/capture/`): `daily.dualimage-dual-light.png`, `daily.dualimage-dual-dark.png`, `daily.dualimage-dual-viewer-light.png`, `daily.dualimage-single-camera-light.png`, `daily.dualimage-loading-media-light.png`, `daily.dualimage-loading-page-light.png`

**Summary: 6 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Composition

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `daily.dualimage.layout.composition` | mainAspect: 0.75; mainRadiusRatio: 0.0455; insetWidthRatio: 0.31; insetAspect: 0.75; insetMarginRatio: 0.03; insetBorderRatio: 0.0051; insetOuterRadiusRatio: 0.126 (SOURCED) | main 3:4; inset 0.31 W, 3:4, margin 0.03 W, border 0.0051 W in backgroundDeep, outer radius 0.126 × inset | ratios of the frame width |
| matched | `radius.global.viewfinder` | 18 pt (SOURCED) | host corners in daily.capture (18) | `corners: .host(...)` |
| matched | `radius.global.photo` | 0 pt (SOURCED) | viewer host corners 0 (default) | default `.host(radius.global.photo)`; `.composition` uses mainRadiusRatio where the host draws no shape |
| matched | `color.global.backgroundDeep` | #000000 (SOURCED) | loading fill on media hosts; inset border | `onMedia: true` |
| matched | `color.global.control` | light: #F1F1F1; dark: #262626 (SOURCED) | loading fill on page hosts | `onMedia: false` |
| matched | `duration.global.fade` | 150 ms (SOURCED) | images fade in | `.dsTransition(.opacity)` + fade |

## Notes

- Social's viewer calls `DualImageView(main:inset:accessibilityLabel:)` unchanged; the default corners are now the viewer's (radius.global.photo, 0).

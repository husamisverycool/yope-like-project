# Verification — `daily.capture` (iOS, Pass 4 — Retro redesign)

Daily same-moment capture — `ios/App/Sources/Features/Capture/Daily/DailyCaptureView.swift`, `DailyCountdownView.swift` (`DailyCaptureTitle`), `DailyCaptureModel.swift`, `DualImageView.swift`.

Checklist written from the spec (`design/surfaces/daily.capture.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>-<light|dark>.png` (every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/daily.capture.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/store/retro-store-03.png (ST-03)`, `references/auto/retro/press/tc-2025-12-rewind-device-a.png (RWA)`, `references/auto/retro/store/retro-store-01.png (ST-01)`, `references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png (mechanics)`, `references/auto/bereal/frames/tiktok-bereal-7339559678604627233_t21.30s_preview-keep-smiling.png (mechanics)`

Snapshots (CI, `ios/build/snapshots/capture/`): `daily.capture-live-light.png`, `daily.capture-live-dark.png`, `daily.capture-preview-light.png`, `daily.capture-preview-dark.png`, `daily.capture-loading-light.png`, `daily.capture-capturing-light.png`, `daily.capture-sending-light.png`, `daily.capture-preview-single-camera-light.png`, `daily.capture-window-closed-light.png`, `daily.capture-permission-denied-light.png`, `daily.capture-error-light.png`

**Summary: 19 matched · 1 approximated · 0 not matched (BLOCKED or not buildable).**

## Header (C-29 on media)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.sendto.layout.header` | title: centred, text role sheetTitle, colour color.global.textOnMedia; its cap middle on the circles' centre line; trailing: close circle (C-11 on media): size.global.circleButton, centre 37.7 pt from the trailing edge; leading: save circle, mirrored (centre 37.7 pt from the leading edge); centreBelowSafeArea: 25.8 (SOURCED) | title slot cap middle 25.8 below the safe-area top; close centre 37.7 from the trailing edge | `CaptureMediaHeader` |
| matched | `daily.capture.countdown` | “{mm}:{ss}” (SOURCED) | MM:SS, sheetTitle, monospaced digits, textOnMedia; changed digits cross-fade | `CountdownDigits` (per-digit opacity transition, `duration.global.crossfade`), ticks each second |
| matched | `fontSize.global.sheetTitle` | 17 pt (SOURCED) | 17 semibold | `TextRole.sheetTitle` |
| matched | `duration.global.crossfade` | 100 ms (SOURCED) | countdown → group name at closes_at | cross-fade in `DailyCaptureTitle` |
| matched | `daily.capture.a11y.dismiss` | “Close” (SOURCED) | close label | header circle |

## Live

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `daily.capture.layout.viewfinder` | aspect: 0.75; width: screen width − 2 × size.global.screenMargin; corners: radius.global.viewfinder; top: 20 pt below the header circle's bottom (camera.sendto.layout.preview.topBelowHeaderCircle); shrink: as camera.capture.layout.viewfinder (SOURCED) | 3:4, screen − 32, 20 below the close circle, corners 18; shrink rule | `viewfinderSize(in:)` + `.padding(.top, topBelowHeaderCircle)` |
| matched | `camera.capture.layout.controlRow` | centre: the shutter, horizontally centred; sideControls: two circles of size.global.circleButtonLarge (64): library (leading), flip (trailing); sideCentre: each side circle is centred in the free space between the screen edge and the shutter's outer edge; vertical: the row is vertically centred between the viewfinder bottom and the tab bar top (daily.capture: the safe-area bottom); minimumGap: size.global.screenMargin above and below the shutter (SOURCED) | flash · shutter · flip centred between viewfinder and safe-area bottom | `CaptureControlRow` |
| matched | `size.global.circleButtonLarge` | 64 pt (SOURCED) | flash / flip 64 #262626 | `CaptureLargeCircleButton` |
| approximated | `camera.capture.size.shutterOuter` | 86 pt (SOURCED) | shutter 86 / 4.5 / 3 / 70 | `CaptureShutter` (gap 3.5, see camera.capture) |
| matched | `daily.capture.a11y.flash` | “Flash” (SOURCED) | label + value | accessibilityValue On / Off |

## Capturing

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `daily.capture.prompt` | “Taking the front photo…” (SOURCED) | indicator (textOnMedia) → 26 → line emptyTitle textOnMedia, centred in the black frame | `CaptureMediaProgress` (MetricStack: indicator bottom → line cap top `emptyIconToTitle`) |
| matched | `duration.global.fade` | 150 ms (SOURCED) | row out, frame to black, block in | row opacity + `ComponentMotion.fade` |

## Preview

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `daily.dualimage.layout.composition` | mainAspect: 0.75; mainRadiusRatio: 0.0455; insetWidthRatio: 0.31; insetAspect: 0.75; insetMarginRatio: 0.03; insetBorderRatio: 0.0051; insetOuterRadiusRatio: 0.126 (SOURCED) | dual image in the frame, host corners 18 | `DualImageView(corners: .host(radius.global.viewfinder))` |
| matched | `size.global.circleButtonPhoto` | 40 pt (SOURCED) | retake glass 40 at badgeInset 12 from top / trailing | `CircleButton(style: .glass)` + paddings `size.global.badgeInset` |
| matched | `daily.capture.audience` | “{group} only” (SOURCED) | C-09 on media "{group} only" with group glyph, 20.5 above the image bottom, not interactive | `LightPillLabel(style: .dark)` |
| matched | `daily.capture.send` | “Send” (SOURCED) | C-05 on media, bottom 44.5 from the screen bottom; busy as send-to | `PrimaryButton(surface: .media, isBusy:)` |
| matched | `camera.sendto.error.sendFailed` | “Couldn't send photo” (SOURCED) | send failed / offline: native alert, preview kept | `.alert(presenting: sendFailure)` Try Again / Cancel |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.capture.denied.title` | “No Camera Access” (SOURCED) | permission denied: C-27 in the frame; controls hidden | `EmptyStateView` |
| matched | `camera.capture.unavailable.title` | “Camera Unavailable” (SOURCED) | camera unavailable | `EmptyStateView` |
| matched | `daily.dualimage.a11y.label` | “Back and front photos from {name}” (SOURCED) | image label | DualImageView label (single camera: the photo sentence) |

## Notes

- The back photo does not fade in behind the progress line before the front photo: the camera service returns both photos together (simultaneous capture), so the frame stays black until the preview.
- Status bar: the cover sets `.preferredColorScheme(.dark)` (light content); the old Yope build hid it.

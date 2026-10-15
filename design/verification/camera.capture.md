# Verification — `camera.capture` (iOS)

Camera the app opens to — `ios/App/Sources/Features/Capture/Camera/CameraCaptureView.swift`, `CameraCaptureModel.swift`.

Checklist written from the spec (`design/surfaces/camera.capture.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>.png`, then `tools/sidebyside.py` makes `design/verification/camera.capture.png` next to the reference image(s) below.

Reference image(s): `references/auto/yope/frames/a-jacob-7691153057177931039-t3.73-camera-hold-to-record.png`, `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t4.73-camera.png`, `references/auto/locket/frames/locket-tt-7069892557970345259-03.367s-shutter-pressed-2022.jpg`

Snapshots (CI): `camera.capture-loading.png`, `camera.capture-live.png`, `camera.capture-flash-on.png`, `camera.capture-shutter-pressed.png`, `camera.capture-coach.png`, `camera.capture-recording.png`, `camera.capture-permission-denied.png`, `camera.capture-error.png`

**Summary: 47 matched · 5 approximated · 0 not matched (BLOCKED or not buildable).**

## Layout

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `color.global.backgroundDeep` | #000000 (SOURCED) | screen background | ZStack background |
| matched | `camera.capture.layout.viewfinder` | width: full screen width; heightOverWidth: 1.38; top: 103 (SOURCED) | viewfinder full width, top 103, h = w × 1.38 | frame(width, width × heightOverWidth), offset(y: top) |
| matched | `radius.global.viewfinder` | 18.5 pt (SOURCED) | viewfinder corners | RoundedRectangle(cornerRadius:, .continuous) clip |
| matched | `camera.capture.size.shutterTopGap` | 38 pt (SOURCED) | ring top 38 pt below viewfinder | row centre = vf bottom + gap + outer/2 |
| matched | `camera.capture.size.sideControlOffset` | 110 pt (SOURCED) | thumb / flip centres ±110 from shutter | .position(x: centre ∓ offset) |
| matched | `camera.capture.layout.flashGlyph` | centerFromLeading: 28.3; centerFromBottom: 33; glyphHeight: 15 (SOURCED) | flash glyph centre (28.3, bottom − 33), height 15 | .position + .frame(height: glyphHeight) |

## Hour overlay

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `fontSize.global.overlayTimeCamera` | 26 pt (SOURCED) | hour overlay size | DSTextStyle size, Dynamic Type relative to `title` |
| matched | `fontWeight.global.overlayTimeCamera` | heavy (SOURCED) | hour overlay weight | DSTextStyle weight |
| matched | `layout.global.textStyleMap` | onboardingTitle: largeTitle; sheetTitle: title3; headerTitle: subheadline; listTitle: headline; listSubtitle: subheadline; body: body; button: subheadline; caption: caption; overlayTime: title2; overlayTimeCamera: title; placeholder: body; sectionLabel: callout; emptyTitle: callout; emptyDetail: subheadline (PLATFORM) | overlayTimeCamera → title | relativeTo resolved from the map |
| matched | `color.global.textPrimary` | #FFFFFF (SOURCED) | overlay colour | foregroundStyle |
| matched | `camera.capture.hourOverlay` | “{time}” (SOURCED) | {time} = start of hour, short time style | CaptureFormat.hourOverlay (Date.FormatStyle time .shortened); TimelineView(.everyMinute) |

## Shutter

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.capture.size.shutterOuter` | 80 pt (SOURCED) | outer 80 | CaptureShutterGraphic outer |
| matched | `camera.capture.size.shutterRing` | 3.5 pt (SOURCED) | ring 3.5 accent | strokeBorder(accent, lineWidth: ring) |
| approximated | `camera.capture.size.shutterGap` | 5.5 pt (SOURCED) | gap 5.5 backgroundDeep | fill backgroundDeep inside the ring; the measured outer/ring/disc leave 7 pt, not 5.5 (values do not sum; drawn from outer, ring and disc) |
| matched | `camera.capture.size.shutterDisc` | 59 pt (SOURCED) | disc 59 surfaceLight | Circle 59 |
| matched | `camera.capture.color.shutterDiscPressed` | #E0DEDF (SOURCED) | pressed disc | disc colour while pressed |
| matched | `camera.capture.layout.shutterPress` | scale: 0.85 (SOURCED) | press scale 0.85 | dsMotion scale (dropped under Reduce Motion) |
| matched | `camera.capture.spring.shutterPress` | response: 0.233; dampingFraction: 1 (SOURCED) | press spring 233 ms, no overshoot | .spring(token) via dsMotion / dsAnimation |
| matched | `camera.capture.duration.videoMax` | 10000 ms (SOURCED) | video stops at 10 s | CMTime maxDuration + model timer |
| matched | `haptic.global.shutter` | ios: none; android: none (PLATFORM) | no haptic | none played |

## Controls

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.capture.size.libraryThumb` | 46 pt (SOURCED) | thumbnail 46 | frame 46 × 46 |
| matched | `camera.capture.radius.libraryThumb` | 8 pt (SOURCED) | thumbnail corners 8 | clip + border shape |
| matched | `camera.capture.size.libraryThumbBorder` | 1 pt (SOURCED) | 1-pt border textPrimary | strokeBorder |
| approximated | `icon.global.gallery` | ios: photo.on.rectangle; android: Rounded.PhotoLibrary (PLATFORM) | no photo / no access | Image(systemName:) textPrimary, platform default size (glyph size not measured) |
| matched | `camera.capture.size.flipButton` | 47 pt (SOURCED) | flip circle 47 | frame 47 circle |
| matched | `camera.capture.color.flipButton` | #1F1F1F (SOURCED) | flip fill | background Circle |
| approximated | `icon.global.flip` | ios: arrow.triangle.2.circlepath; android: Rounded.Sync (PLATFORM) | flip glyph | Image(systemName:), platform default size (not measured) |
| matched | `icon.global.flashOff` | ios: bolt.slash.fill; android: Rounded.FlashOff (PLATFORM) | flash off glyph | Image |
| matched | `icon.global.flashOn` | ios: bolt; android: Rounded.FlashOn (PLATFORM) | flash on glyph | Image |

## Coach tooltip

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.capture.layout.coach` | height: 34; cornerRadius: 8; paddingHorizontal: 13.6; textToCloseGap: 13.6; closeGlyph: 9.5; pointerWidth: 13.6; pointerHeight: 6.8; pointerToTarget: 2 (SOURCED) | lime pill: h 34, r 8, padding 13.6, ✕ 9.5, pointer 13.6 × 6.8, 2 pt above ring | CaptureCoachTooltip |
| approximated | `camera.capture.icon.recordHint` | ios: video.fill; android: Rounded.Videocam (PLATFORM) | leading glyph at text size | Text(Image) + word space + Text — the glyph-to-text gap is a word space (not measured) |
| matched | `camera.capture.fontSize.coach` | 11 pt (SOURCED) | coach text size | DSTextStyle |
| matched | `camera.capture.fontWeight.coach` | semibold (SOURCED) | coach text weight | DSTextStyle |
| matched | `camera.capture.layout.textStyleMap` | coach: caption2 (PLATFORM) | coach → caption2 | relativeTo |
| matched | `camera.capture.coach.holdToRecord` | “hold down to record” (SOURCED) | coach text | Copy |
| matched | `color.global.accent` | #CDFD07 (SOURCED) | coach fill | background |
| matched | `color.global.onAccent` | #000000 (SOURCED) | coach text / glyphs | foregroundStyle |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.capture.denied.title` | “can’t take pics?” (SOURCED) | permission denied: emptyTitle | CaptureEmptyState in the viewfinder; shutter + flip hidden; thumb stays |
| matched | `camera.capture.denied.detail` | “enable camera access in settings” (SOURCED) | emptyDetail, textSecondary, italic | CaptureEmptyState |
| approximated | `camera.capture.denied.button` | “open settings” (SOURCED) | light pill → Settings | CaptureLightPill (height permissionButtonHeight, capsule; label inset = height/2, padding not measured) |
| matched | `camera.capture.size.permissionButtonHeight` | 45 pt (SOURCED) | pill height 45 | minHeight |
| matched | `camera.capture.unavailable.title` | “camera isn’t available right now” (SOURCED) | error / interrupted | same layout; retry restarts the session; AVCaptureSession interruption notifications |
| matched | `camera.capture.unavailable.button` | “try again” (SOURCED) | retry | CaptureLightPill |
| matched | `camera.capture.size.recordingOutline` | 6 pt (SOURCED) | recording outline 6 pt, accent, progress stroke | RoundedRectangle(radius.global.viewfinder).inset.trim(0…progress).stroke; progress 0 → 1 linearly over camera.capture.duration.videoMax |
| matched | `camera.capture.a11y.recording` | “recording” (SOURCED) | announcement on record start | AccessibilityNotification.Announcement |

## Accessibility

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.capture.a11y.shutter` | “take a pic” (SOURCED) | shutter label | accessibilityLabel + button trait; custom action recordVideo for premium |
| matched | `camera.capture.a11y.recordVideo` | “record a video” (SOURCED) | custom action | accessibilityActions (premium only) |
| matched | `camera.capture.a11y.flash` | “flash” (SOURCED) | flash label + value | accessibilityLabel/Value (flashOn/flashOff) |
| matched | `camera.capture.a11y.flip` | “flip camera” (SOURCED) | flip | label |
| matched | `camera.capture.a11y.library` | “choose from library” (SOURCED) | library | label |
| matched | `camera.capture.a11y.close` | “close” (SOURCED) | coach ✕ | label; hit area minTouchTarget |
| matched | `size.global.minTouchTarget.ios` | 44 pt (VERIFIED) | flash / ✕ hit areas | frame(minWidth/minHeight) / overlay hit area |

## Notes

- No tab bar under the camera: the tab bar is the navigation surfaces' (account shell); the camera is presented as `AppModal.camera` (full-screen cover) and has no exit control of its own in the spec — reported.
- Flash: `CameraService` has no flash mode for its photo settings; the flash is the camera's torch around the capture (reported to the foundation owner).
- Live Photo: on where supported (`CameraConfiguration.photo(_, livePhoto: true)`); no toggle (not in any reference).
- Free member long press: the camera closes and the paywall opens once per session (`SessionPromptGate` never prompts during capture); later long presses do nothing; tap always captures.

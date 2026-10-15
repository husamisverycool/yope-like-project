# Verification — `daily.capture` (iOS)

Capture with the countdown; front + back — `ios/App/Sources/Features/Capture/Daily/`.

Checklist written from the spec (`design/surfaces/daily.capture.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>.png`, then `tools/sidebyside.py` makes `design/verification/daily.capture.png` next to the reference image(s) below.

Reference image(s): `references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png`, `references/auto/bereal/frames/tiktok-bereal-7339559678604627233_t21.30s_preview-keep-smiling.png`, `references/auto/bereal/help/help-21083708285725_bts-post-preview-2x.png`

Snapshots (CI): `daily.capture-loading.png`, `daily.capture-live.png`, `daily.capture-capturing.png`, `daily.capture-preview.png`, `daily.capture-preview-single-camera.png`, `daily.capture-window-closed.png`, `daily.capture-permission-denied.png`, `daily.capture-error.png`

**Summary: 30 matched · 4 approximated · 0 not matched (BLOCKED or not buildable).**

## Live

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `daily.capture.layout.dismiss` | centerFromLeading: 31.7; centerFromTop: 74.5 (SOURCED) | chevron centre (31.7, 74.5) | .position |
| matched | `icon.global.chevronDown` | ios: chevron.down; android: Rounded.ExpandMore (PLATFORM) | chevron | Image, platform size |
| matched | `daily.capture.color.text` | #FAFAFA (SOURCED) | #FAFAFA text / glyphs | foregroundStyle |
| matched | `daily.capture.layout.countdown` | digitsTop: 92.3; gapAboveViewfinder: 16.2 (SOURCED) | digits 16.2 above the viewfinder | baseline = viewfinder top − gap |
| matched | `daily.capture.fontSize.countdown` | 23 pt (SOURCED) | 23 pt, monospaced digits | DSTextStyle (title2) + monospacedDigit |
| matched | `daily.capture.fontWeight.countdown` | bold (SOURCED) | bold | DSTextStyle weight (app and Lock Screen Live Activity) |
| matched | `daily.capture.countdown` | “{mm}:{ss}” (SOURCED) | MM:SS zero-padded | CaptureFormat.countdown |
| matched | `daily.capture.layout.countdownTick` | tick: 1000; digitOut: 100; digitIn: 300; digitFadeIn: 550; travel: 3 (SOURCED) | tick 1 s; digit out 100 / in 300 / fade 550 ms, travel 3 | TimelineView periodic; per-digit transitions (springs, platform damping); Reduce Motion cross-fade |
| matched | `daily.capture.layout.viewfinder` | width: 378.7; sideMargin: 7; top: 124.4; aspect: 0.75; cornerRadius: 16 (SOURCED) | 3:4, side 7, top 124.4, r 16 | frame + clip |
| matched | `daily.capture.layout.shutter` | outer: 74; ring: 4; gap: 2.75; disc: 60.5; centerFromBottom: 148 (SOURCED) | 74 / ring 4 / gap 2.75 / disc 60.5, centre 148 above bottom | CaptureShutterGraphic, surfaceLight |
| matched | `daily.capture.layout.sideControls` | flashCenterFromLeading: 59.2; flipCenterFromTrailing: 60.1 (SOURCED) | flash 59.2 / flip 60.1 | .position |

## Capturing

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| approximated | `daily.capture.layout.captureSequence` | pressScale: 0.912; press: 133; controlsOut: 370; viewfinderFadeOut: 267; betweenShots: 500; backPhotoFadeIn: 200 (SOURCED) | press 0.912 / 133 ms, shrink by 370, black over 267, back photo fade 200 | DailyShutterStyle + dsMotion + fade overlay; the back-photo fade-in mid-sequence is not shown (CameraService returns both photos together; the preview appears in one frame) |
| approximated | `daily.capture.size.progress` | 34.7 pt (SOURCED) | spinner 34.7 | ProgressView .large in a 34.7 frame (platform size) |
| matched | `daily.capture.layout.prompt` | gapBelowSpinner: 11.4 (SOURCED) | prompt 11.4 below | VStack spacing |
| approximated | `daily.capture.fontSize.prompt` | 17 pt (SOURCED) | 17 pt | DSTextStyle (body), weight not measured → regular |
| matched | `daily.capture.prompt` | “Getting both sides” (SOURCED) | ‘Getting both sides’ | Copy |

## Preview

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `daily.dualimage.layout.composition` | mainAspect: 0.75; mainRadiusRatio: 0.0455; insetWidthRatio: 0.31; insetAspect: 0.75; insetMarginRatio: 0.03; insetBorderRatio: 0.0051; insetOuterRadiusRatio: 0.126 (SOURCED) | dual image ratios | DualImageView |
| matched | `daily.capture.layout.retake` | diameter: 34; inset: 12; glyph: 14 (SOURCED) | ✕ 34, 12 from top/trailing, glyph 14 | frames + padding; hit area minTouchTarget |
| matched | `daily.capture.color.overlayControl` | #00000075 (SOURCED) | retake circle / chip fill #00000075 | Circle / Capsule fill |
| matched | `daily.capture.layout.audienceChip` | height: 37.4; paddingLeading: 15.7; paddingTrailing: 18; glyphToText: 7.6; bottomInset: 12.5 (SOURCED) | h 37.4, pad 15.7 / 18, gap 7.6, 12.5 above bottom | HStack paddings |
| approximated | `daily.capture.fontSize.chip` | 13 pt (SOURCED) | 13 pt | DSTextStyle (footnote), weight not measured |
| matched | `daily.capture.audience` | “{group} only” (SOURCED) | ‘{group} only’ | Copy |
| matched | `daily.capture.layout.send` | capTopBelowImage: 69; glyphGap: 11.4; glyph: 19.5 (SOURCED) | cap top 69 below image, glyph gap 11.4, glyph 19.5 | baseline = image bottom + 69 + cap height (UIFont metrics) |
| matched | `daily.capture.fontSize.send` | 40.5 pt (SOURCED) | 40.5 | DSTextStyle (largeTitle) |
| matched | `daily.capture.fontWeight.send` | heavy (SOURCED) | heavy | DSTextStyle |
| matched | `daily.capture.send` | “SEND” (SOURCED) | ‘SEND’ | Copy |
| matched | `icon.global.play` | ios: play.fill; android: Rounded.PlayArrow (PLATFORM) | triangle | Image 19.5 |

## Accessibility

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `daily.capture.a11y.dismiss` | “Close” (SOURCED) | chevron | label |
| matched | `daily.capture.a11y.shutter` | “Take photo” (SOURCED) | shutter | label |
| matched | `daily.capture.a11y.flash` | “Flash” (SOURCED) | flash + value | label/value |
| matched | `daily.capture.a11y.flip` | “Flip camera” (SOURCED) | flip | label |
| matched | `daily.capture.a11y.retake` | “Retake” (SOURCED) | retake | label |
| matched | `daily.capture.a11y.send` | “Send” (SOURCED) | SEND | label |
| matched | `daily.capture.layout.textStyleMap` | countdown: title2; prompt: body; chip: footnote; send: largeTitle (PLATFORM) | countdown title2, prompt body, chip footnote, SEND largeTitle | relativeTo |

## Notes

- Window closed / opened after: no countdown, nothing in its place; the post still carries p_invitation_id and the server decides in_window (never 'late').
- Sequential fallback: CameraService captures back then front on the same session; if the dual capture fails the back photo alone is the answer.
- Flip on a device without multi-cam: the main photo swaps, but the live preview stays on the back camera (the sequential session shows only the back camera before the shutter).
- Clock skew: the data layer measures no server offset; `ServerClock.device` is used (reported).

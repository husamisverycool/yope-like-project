# Verification — `camera.capture` (iOS, Pass 4 — Retro redesign)

Camera the app opens to — `ios/App/Sources/Features/Capture/Camera/CameraCaptureView.swift`, `CameraCaptureModel.swift`, `ios/App/Sources/Features/Capture/Support/CaptureComponents.swift` (shutter, control row, 64-pt circle); tab bar = the shell's `AppTabBar(surface: .media)`.

Checklist written from the spec (`design/surfaces/camera.capture.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>-<light|dark>.png` (every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/camera.capture.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png (H43)`, `references/auto/retro/press/tc-2025-12-rewind-device-a.png (RWA)`, `references/auto/retro/press/tc-2025-12-rewind-device-b.jpg (RWB)`, `references/auto/retro/store/retro-store-03.png (ST-03)`, `references/auto/locket/store/locket-store-07.png (AS-7, mechanics)`

Snapshots (CI, `ios/build/snapshots/capture/`): `camera.capture-live-light.png`, `camera.capture-live-dark.png`, `camera.capture-loading-light.png`, `camera.capture-flash-on-light.png`, `camera.capture-no-flash-light.png`, `camera.capture-coach-light.png`, `camera.capture-recording-light.png`, `camera.capture-permission-denied-light.png`, `camera.capture-error-light.png`

**Summary: 43 matched · 2 approximated · 0 not matched (BLOCKED or not buildable).**

## Page and header (C-01 on media)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `color.global.backgroundDeep` | #000000 (SOURCED) | page, both appearances | `.background(backgroundDeep.ignoresSafeArea())`; subtree rendered dark (`captureMediaAppearance`) |
| matched | `layout.global.appearance` | mode: follows the system Light / Dark setting; ios: no UIUserInterfaceStyle key and no preferredColorScheme override; colour tokens are dynamic (Color(light:dark:)); android: DsTheme(dark = isSystemInDarkTheme()) wraps the app and every test host; colour getters read LocalDsDarkTheme; media: photo / story viewer, camera, postcard-style composer, recap preview and full-bleed media stay dark (color.global.backgroundDeep) in both appearances; sheets over them follow the appearance (SOURCED) | media surface stays black | `environment(\.colorScheme, .dark)` on the page only; send-to cover and picker sheet attached outside it |
| matched | `camera.capture.title` | “Week {number}” (SOURCED) | "Week {number}" serif title | `ScreenHeader(title:onMedia: true)`; {number} = ISO-8601 week of today (device time zone) |
| matched | `fontSize.global.headerTitle` | 40 pt (SOURCED) | 40 / line 48, regular, display serif | `TextRole.headerTitle` inside C-01 |
| matched | `size.global.titleTop` | 64 pt (SOURCED) | baseline 64 below the safe-area top | C-01 metric stack |
| matched | `color.global.textOnMedia` | #FFFFFF (SOURCED) | title, flash glyph | `onMedia: true`, `HeaderIconButton(color:)` |
| matched | `icon.global.flashOff` | ios: bolt.slash; android: Outlined.FlashOff (PLATFORM) | flash off glyph | bare header glyph, `size.global.icon` box, cross-fade on toggle |
| matched | `icon.global.flashOn` | ios: bolt; android: Outlined.FlashOn (PLATFORM) | flash on glyph | same |
| approximated | `size.global.headerInset` | 16 pt (SOURCED) | glyph ink 16 from the trailing edge, centred on the title's cap middle | C-01 trailing-glyph geometry reproduced (hit area 44 + 6 padding; cap middle = titleTop − capHeight/2) because `HeaderAction` cannot carry the On/Off value |
| matched | `size.global.headerButton` | 44 pt (PLATFORM) | flash hit area 44 | HeaderIconButton frame |

## Viewfinder

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.capture.layout.viewfinder` | aspect: 0.75; width: screen width − 2 × size.global.screenMargin; corners: radius.global.viewfinder; top: size.global.titleToContent below the header title baseline (C-01); fill: aspect-fill live preview; what the frame shows is what is captured; shrink: if the control row would get less than size.global.screenMargin above and below the shutter, the viewfinder height shrinks (3:4 kept, centred horizontally) (SOURCED) | 3:4, screen − 2 × 16 (361 × 481), top 30 below the title baseline, aspect-fill; shrinks if the row gets < 16 above/below the shutter | `CameraCaptureView.viewfinderSize(in:)` below the C-01 header (whose bottom is `titleToContent` below the baseline) |
| matched | `size.global.titleToContent` | 30 pt (SOURCED) | 30 | C-01 bottom edge |
| matched | `radius.global.viewfinder` | 18 pt (SOURCED) | 18, continuous | `DSShape.rounded` clip |
| matched | `duration.global.fade` | 150 ms (SOURCED) | preview fades in after the first frame; C-27 block in/out | `.dsTransition(.opacity)` + `ComponentMotion.fade`; preview kept on screen through a flip restart (`hasBeenLive`) |
| matched | `camera.capture.size.recordingOutline` | 6 pt (SOURCED) | 6 pt outline while recording | `DSShape.rounded(18).inset(3).trim(0, progress).stroke(lineWidth: 6)` |
| matched | `color.global.surfaceLight` | #FFFFFF (SOURCED) | outline colour | stroke colour |
| matched | `camera.capture.duration.videoMax` | 10000 ms (SOURCED) | linear 0 → 1 over 10 s; video stops at 10 s | linear `DSAnimation.timing`; model stops at the token |

## Coach pill (C-09 on media)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.capture.coach.holdToRecord` | “Hold to record a video” (SOURCED) | "Hold to record a video" | `LightPill(_, icon: icon.global.video, style: .dark)` |
| matched | `color.global.controlOnDeep` | #262626 (SOURCED) | pill fill | LightPill `.dark` |
| matched | `icon.global.video` | ios: video.fill; android: Rounded.Videocam (PLATFORM) | leading glyph at iconSmall | LightPill icon |
| matched | `size.global.pillHeight` | 37 pt (SOURCED) | 37 | LightPill minHeight |
| matched | `size.global.pillPaddingLeading` | 18 pt (SOURCED) | 18 → glyph → 9.7 → label → 17 | LightPill anatomy |
| matched | `camera.sendto.layout.messageField` | message: C-09 glass pill on the photo: fill color.global.controlOnDeep, icon.global.edit + label text role pill, colour color.global.textOnMedia, height size.global.pillHeight, width hugs the label; voice: icon-only capsule after it: width size.global.iconPillWidth, height size.global.pillHeight, same fill, icon.global.mic; gap: size.global.pillGap; bottomInset: 20.5; align: the pair centred horizontally on the photo (SOURCED) | bottom 20.5 above the viewfinder bottom (bottomInset) | `.padding(.bottom, bottomInset)` in a bottom overlay |

## Control row (C-35)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.capture.layout.controlRow` | centre: the shutter, horizontally centred; sideControls: two circles of size.global.circleButtonLarge (64): library (leading), flip (trailing); sideCentre: each side circle is centred in the free space between the screen edge and the shutter's outer edge; vertical: the row is vertically centred between the viewfinder bottom and the tab bar top (daily.capture: the safe-area bottom); minimumGap: size.global.screenMargin above and below the shutter (SOURCED) | shutter centred; side circles centred between edge and shutter (76.8 pt on 393); row centred between viewfinder and tab bar | `CaptureControlRow` layout: side centre = (W/2 − 43)/2; row fills the remaining height, content centred |
| matched | `camera.capture.size.shutterOuter` | 86 pt (SOURCED) | 86 | `CaptureShutter` frame |
| matched | `camera.capture.size.shutterRing` | 4.5 pt (SOURCED) | 4.5 surfaceLight | strokeBorder |
| approximated | `camera.capture.size.shutterGap` | 3 pt (SOURCED) | 3 backgroundDeep | values do not sum (86 − 9 − 70 = 7 → 3.5 per side): outer, ring, disc drawn exactly, gap shows 3.5 |
| matched | `camera.capture.size.shutterDisc` | 70 pt (SOURCED) | 70 surfaceLight | Circle 70 |
| matched | `size.global.circleButtonLarge` | 64 pt (SOURCED) | library / flip circles 64 | `CaptureLargeCircleButton` (no C-11 style for 64 on #262626 — component gap) |
| matched | `icon.global.gallery` | ios: photo.on.rectangle; android: Outlined.PhotoLibrary (PLATFORM) | library glyph 24, textOnMedia | Glyph in `size.global.icon` box |
| matched | `icon.global.flip` | ios: arrow.triangle.2.circlepath; android: Rounded.Sync (PLATFORM) | flip glyph | Glyph |
| matched | `haptic.global.shutter` | ios: none; android: none (PLATFORM) | none | none played |
| matched | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | iOS none | none played |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.capture.denied.title` | “No Camera Access” (SOURCED) | C-27 in the viewfinder: camera glyph → title → detail → outline capsule; shutter + flip hidden | `EmptyStateView(icon:title:detail:action:)` in the dark subtree (textPrimary → white, outline capsule white) |
| matched | `camera.capture.denied.detail` | “Turn on camera access in Settings to take photos for your groups.” (SOURCED) | emptyDetail, textSecondary | C-27 |
| matched | `camera.capture.denied.button` | “Open Settings” (SOURCED) | outline capsule → Settings | C-06 outline capsule (no icon) |
| matched | `camera.capture.unavailable.title` | “Camera Unavailable” (SOURCED) | same block; Try Again restarts the session | C-27, `model.retry()` |
| matched | `size.global.emptyIcon` | 22 pt (SOURCED) | 22 | C-27 |
| matched | `icon.global.camera` | ios: camera; android: Outlined.PhotoCamera (PLATFORM) | state glyph | C-27 icon |

## Accessibility

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.capture.a11y.shutter` | “Take photo” (SOURCED) | shutter label + custom action record video | element with button trait, default action photo, custom action when premium |
| matched | `camera.capture.a11y.recordVideo` | “Record video” (SOURCED) | custom action | `accessibilityActions` |
| matched | `camera.capture.a11y.flash` | “Flash” (SOURCED) | label + value On / Off | `accessibilityValue` on the flash glyph |
| matched | `camera.capture.a11y.library` | “Choose from Library” (SOURCED) | library label | CaptureLargeCircleButton label |
| matched | `camera.capture.a11y.flip` | “Flip camera” (SOURCED) | flip label | label |
| matched | `camera.capture.a11y.recording` | “Recording” (SOURCED) | announcement at record start | `AccessibilityNotification.Announcement` |

## Notes

- Tab bar: drawn by the shell (`RootView` → `AppTabBar(selected: .camera, surface: .media)`); the snapshots host it the same way.
- Status bar: the camera is a tab of the main window (not a cover), so its status-bar content follows the system appearance; in light appearance the clock is dark on black — the shell (account group) owns the window and is told (report).
- Shutter press: no custom press state (RC-3: platform default; Retro's press not recorded) — the drag-tracked shutter shows none.

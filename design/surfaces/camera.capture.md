# camera.capture — the camera the app opens to

**Visual reference: Retro** has no camera (it posts from the camera roll — `design/research/retro-visual.md` §5), so
this page is **composed only from Retro components** — C-01 root header, the C-17 / C-18 photo container
(`radius.global.viewfinder`), C-11 circles, the C-35 control row (central control flanked by 64-pt circles), C-09 pill,
C-27 empty block, C-04 tab bar — on Retro's media surface (`color.global.backgroundDeep`, black in both appearances,
`layout.global.appearance.media`). **Mechanics: Locket** (one tap captures, hold records a video, flip, library pick,
recording outline, video length). Decisions: `design/MERGE_DECISIONS.md` → "Redesign — Capture" RC-1 … RC-4.
Composition record: `camera.capture.layout.viewfinder` / `.controlRow` (level SOURCED, method "composition of Retro
components … in Locket's order").

## References

| image | what it verifies |
|---|---|
| `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png` (H43, RAW dark) | C-01 serif root title, trailing bare glyph, 16 margin, 18-pt photo-container corners, tab bar on black |
| `references/auto/retro/press/tc-2025-12-rewind-device-a.png` (RWA, RAW), `…-device-b.jpg` (RWB) | C-35 media page: central control flanked by 64-pt circles, side-circle centring rule (`camera.capture.layout.controlRow`), tab bar over media |
| `references/auto/retro/store/retro-store-03.png` (ST-03) | C-09 pill on a photo (coach pill), C-11 circle on media (#262626) |
| `references/auto/locket/store/locket-store-07.png` (AS-7), `references/owner/locket-06-capture.webp` | mechanics: viewfinder above a flash / shutter / flip row; shutter geometry (`camera.capture.size.shutter*`) |
| `references/auto/locket/frames/locket-tt-7069892557970345259-02.800s-camera-2022.jpg` | mechanics: tap captures, the shutter hands over to send-to |
| Locket help HC 7915017 (design/research/locket.md §5) | mechanics: touch and hold records; an outline around the viewfinder shows progress |

## Structure (top to bottom, 393 × 852 pt)

Page `color.global.backgroundDeep` in both appearances; status bar light content.

1. **Header (C-01 on media).** Serif title `camera.capture.title` ("Week 42") — text role `headerTitle` (40 / line 48,
   regular, `font.global.display`), `color.global.textOnMedia`, leading `size.global.screenMargin`, baseline
   `size.global.titleTop` (64) below the safe-area top. Trailing: the **flash** glyph as a bare header glyph
   (`icon.global.flashOff` / `icon.global.flashOn`, `size.global.icon`, `color.global.textOnMedia`), centred on the
   title's cap middle, ink at `size.global.headerInset` (16) from the trailing edge, hit area `size.global.headerButton`.
   Hidden when the active camera has no flash.
2. **Viewfinder** — `camera.capture.layout.viewfinder`: 3:4, width = screen − 2 × `size.global.screenMargin` (361 ×
   481), corners `radius.global.viewfinder` (18, `layout.global.cornerStyle` continuous on iOS), top
   `size.global.titleToContent` (30) below the title baseline; live preview aspect-fill (WYSIWYG: the 3:4 frame is the
   photo). On it, while a video records: the **recording outline** (`camera.capture.size.recordingOutline` 4 — Material 3's progress-indicator thickness,
   `color.global.surfaceLight`) traced along the viewfinder's rounded outline from empty to full, linearly over
   `camera.capture.duration.videoMax`. First use only: the **coach pill** (C-09 on media: fill
   `color.global.controlOnDeep`, `icon.global.video` at `size.global.iconSmall` + `camera.capture.coach.holdToRecord`,
   text role `pill`, `color.global.textOnMedia`, height `size.global.pillHeight`, width hugs the label, paddings
   `size.global.pillPaddingLeading` / `.pillPaddingTrailing`, icon gap `size.global.pillIconGap`), centred, its bottom
   20.5 pt above the viewfinder bottom (`camera.sendto.layout.messageField.bottomInset`, Retro's pill-on-photo inset).
3. **Control row** — `camera.capture.layout.controlRow`, vertically centred between the viewfinder bottom and the tab
   bar top (≥ `size.global.screenMargin` above and below the shutter; if less, the viewfinder shrinks, 3:4 kept):
   - centre: **shutter** — outer `camera.capture.size.shutterOuter` (86); ring `camera.capture.size.shutterRing` (4.5)
     in `color.global.surfaceLight`; gap `camera.capture.size.shutterGap` (3) showing `color.global.backgroundDeep`;
     disc `camera.capture.size.shutterDisc` (70) in `color.global.surfaceLight`;
   - leading: **library** circle — C-11, `size.global.circleButtonLarge` (64), fill `color.global.controlOnDeep`,
     `icon.global.gallery` (`size.global.icon`, `color.global.textOnMedia`);
   - trailing: **flip** circle — same, `icon.global.flip`;
   - each side circle centred in the free space between the screen edge and the shutter's outer edge
     (393-pt screen: centre 76.8 pt from the edge — Retro's Rewind rule).
4. **Tab bar** (C-04, owned by `groups.list` — `groups.list.layout.tabBar`) in its media variant: background
   `color.global.backgroundDeep`, selected `color.global.textOnMedia`, unselected `color.global.tabInactiveOnMedia`.

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| title | C-01 · `headerTitle`, `font.global.display`, `color.global.textOnMedia`, `size.global.titleTop` | `camera.capture.title` ({number} = current week number, as `week.history` numbers weeks) | the week the photo will be added to; static text with the header trait |
| flash | C-01 trailing glyph · `icon.global.flashOff` / `.flashOn`, `size.global.headerButton` | a11y `camera.capture.a11y.flash`, value `.a11y.flashOn` / `.a11y.flashOff` | toggles off ↔ on (glyph swap, `duration.global.crossfade`); default off; hidden without a flash |
| viewfinder | C-17/C-18 container · `camera.capture.layout.viewfinder`, `radius.global.viewfinder` | — | back camera on open; front after a flip, kept for the session; the captured photo is the 3:4 frame shown |
| shutter | mechanics (Locket) · `camera.capture.size.shutterOuter/Ring/Gap/Disc`, `color.global.surfaceLight`, `color.global.backgroundDeep` | a11y `camera.capture.a11y.shutter`; custom action `camera.capture.a11y.recordVideo` (video members) | **tap** = photo (Live Photo where supported) → `camera.sendto`. **Hold** = video (premium): records while held, stops on release or at `camera.capture.duration.videoMax` (10 s). Free member: the session's first hold opens `paywall` (at most one prompt per session); later holds do nothing; tap always captures |
| recording outline | `camera.capture.size.recordingOutline`, `color.global.surfaceLight`, `radius.global.viewfinder` | announcement `camera.capture.a11y.recording` | visible while a video records |
| library | C-11 64 circle · `size.global.circleButtonLarge`, `color.global.controlOnDeep`, `icon.global.gallery` | a11y `camera.capture.a11y.library` | system photo picker (iOS PhotosPicker, Android Photo Picker — no library permission); the picked photo / Live Photo / video → `camera.sendto` |
| flip | C-11 64 circle · same, `icon.global.flip` | a11y `camera.capture.a11y.flip` | front ↔ back |
| coach pill | C-09 on media · `color.global.controlOnDeep`, `icon.global.video`, text role `pill`, `size.global.pillHeight` | `camera.capture.coach.holdToRecord` | once per install, only to members who can record video; tapping it or the first recorded video dismisses it for good |
| tab bar | C-04 media variant · `color.global.textOnMedia` / `.tabInactiveOnMedia` | owned by `groups.list` | — |

## States

All states keep the header and the tab bar; the C-27 block replaces the viewfinder content (inside its frame, fill
`color.global.backgroundDeep`) and is drawn with media colours.

| state | design (components · tokens) | copy | source |
|---|---|---|---|
| loading (session starting) | viewfinder frame filled `color.global.backgroundDeep` until the first frame, then the preview fades in (`duration.global.fade`); controls visible | — | C-28 (Retro shows no skeletons) |
| permission not yet asked | the system prompt over this page on first open (iOS `NSCameraUsageDescription`, Android CAMERA) | purpose string owned by `system.permissions` | PLATFORM |
| permission denied | C-27 in the viewfinder: `icon.global.camera` (`size.global.emptyIcon`, `color.global.textOnMedia`) → `size.global.emptyIconToTitle` → title text role `emptyTitle` `color.global.textOnMedia` → explanation `emptyDetail` `color.global.textSecondary` → `size.global.emptyTitleToAction` → C-07 outline capsule without icon (1-pt border and label `color.global.textOnMedia`, text role `pill`, `size.global.pillHeight`); shutter and flip hidden; library and flash stay | `camera.capture.denied.title` / `.detail` / `.button` (opens the app's system Settings page) | `retro.voice.permission`; C-27 permission variant |
| microphone (video) | asked at the first video only, never before a photo (App Review 5.1.1(iv)) | owned by `system.permissions` | PLATFORM |
| error (session interrupted, camera in use) | same C-27 block | `camera.capture.unavailable.title` / `.detail` / `.button` (restarts the session) | `retro.voice.error`; C-27 error variant |
| offline | no change (capture is local; sending is handled in `camera.sendto`) | — | — |
| empty | n/a | — | — |

## Motion

| motion | tokens | Reduce Motion |
|---|---|---|
| preview appears after the session starts; C-27 block in / out | `duration.global.fade` (150) + `easing.global.standard` | same (fade only) |
| flash glyph on ↔ off, flip | glyph `duration.global.crossfade` (100); the camera feed switch is the platform's | same |
| shutter press | platform default press (C rules: Retro's press state not recorded) — no custom scale | same |
| recording outline | linear trim 0 → 1 over `camera.capture.duration.videoMax` (tracks recording time, a progress indicator) | unchanged (progress, not decoration) |
| capture → `camera.sendto` | native full-screen presentation (`easing.global.native.sheet`; custom presentations match `spring.global.sheetPresent`) | cross-fade of `duration.global.sheetPresent` |
| coach pill in / out | `duration.global.fade` | same |

## Haptics

Shutter: `haptic.global.shutter` (none — camera rule). Flash, flip, library, coach: `haptic.global.tap` (Android
VIRTUAL_KEY before the action; iOS none). Paywall hand-off: none.

## Accessibility

- Labels: shutter `camera.capture.a11y.shutter` (button; custom action `.a11y.recordVideo` when video is available),
  flash `.a11y.flash` + value `.a11y.flashOn` / `.flashOff` (iOS accessibilityValue; Android stateDescription), library
  `.a11y.library`, flip `.a11y.flip`; coach pill is a button labelled with its text. Recording start posts
  `.a11y.recording` as an announcement. Viewfinder: not an element.
- Title: header trait. Dynamic Type: `headerTitle` → largeTitle; coach `pill` → subheadline; C-27 roles per
  `layout.global.textStyleMap` (fixed controls do not grow).
- Focus order: title → flash → (coach pill when shown) → library → shutter → flip → tab bar.
- Touch targets: 64-pt circles and the 86-pt shutter exceed 44 / 48; the flash glyph's hit area is
  `size.global.headerButton` (44) / 48 dp.
- Contrast (`node tools/contrast.mjs`; identical in light and dark — media surface):

| pair | ratio | result |
|---|---|---|
| title / flash glyph `textOnMedia` on `backgroundDeep` | 21.00:1 | pass |
| circle glyph `textOnMedia` on `controlOnDeep` (#262626) | 15.13:1 | pass |
| circle fill `controlOnDeep` vs `backgroundDeep` (non-text) | 1.39:1 | **FAIL** — container edge (CONTRAST failure 2); the glyph identifies the control |
| shutter `surfaceLight` vs `backgroundDeep` (non-text) | 21.00:1 | pass |
| coach label `textOnMedia` on `controlOnDeep` | 15.13:1 | pass |
| C-27 title `textOnMedia` / detail `textSecondary` on `backgroundDeep` | 21.00:1 / 7.37:1 | pass |
| tab unselected `tabInactiveOnMedia` (#FFFFFF9E) on `backgroundDeep` (non-text) | 7.84:1 | pass |
| recording outline over the live image | photo-dependent | reported |

## Data & actions

- Reads: `entitlements` (own row; active when `expires_at` is null or future) decides whether hold records.
- Writes: none here. The capture (photo, Live Photo motion, video) is handed to `camera.sendto`, which uploads and
  calls `create_post` (docs/API.md recipe 9.4).
- In: app launch (the app opens to the camera tab), tab bar, `camera.fromwidget` (`app://camera?group=<id>` →
  `DeepLink.camera(groupID:)`; the group is preselected in `camera.sendto`), chat composer camera.
- Out: `camera.sendto` (after capture / pick), `paywall` (free hold, once per session), system Settings.

## Platform notes

- iOS: `AVCaptureSession`, photo preset (4:3 sensor → 3:4 portrait, matching the viewfinder); Live Photo when
  `AVCapturePhotoOutput.isLivePhotoCaptureSupported` (docs/PLATFORM_CONSTRAINTS.md §6); no Live Photo toggle.
- Android: CameraX, `AspectRatio.RATIO_4_3`; no Live Photo; page background `color.global.backgroundDeep` (media — not
  `color.global.background.android`).
- Corners: iOS `RoundedRectangle(cornerRadius:style: .continuous)`, Android `RoundedCornerShape`
  (`layout.global.cornerStyle`).
- Video: `media.kind = video` needs premium at `create_post` (`premium_required`).
- Android `DeepLink.Camera` must accept no group id (MERGE_DECISIONS C-24, still open in code).

## Do-not-copy

Retro: its wordmark / "R" mark anywhere in the header. Locket: '12 Friends' pill (a count), chat button with a count
badge, photo-tinted background, yellow ring, 'History' row. Yope: wordmark, hour overlay, lime ring, filter carousel and
'1x' zoom label. Streak pills anywhere.

## Gaps

| item | status | smallest capture / decision |
|---|---|---|
| Retro press state | not recorded → platform default (RC-3) | 60 fps recording of any Retro capsule press (README "Not available yet") |
| Live Photo on / off control | not built (no reference shows one) | one screenshot of a camera with a Live Photo control in Locket |
| hold-to-record visuals on the current Locket build | outline known from Locket's help text; its width is Material 3's progress-indicator default (4), since the earlier 6 came from Locket's decompiled bundle (owner decision 22) | one screenshot (or a 10-s recording) of Locket recording a video |
| zoom, tap to focus | not built (not observed) | — |
| camera as a tab vs a modal | follows `groups.list.layout.tabBar` (account group) | — |

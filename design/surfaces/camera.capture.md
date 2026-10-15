# camera.capture — the camera the app opens to

Reference: **Yope** (visuals, voice) + **Locket** (what Yope does not show: press motion, recording outline,
video length, widget entry). Conflicts: `design/MERGE_DECISIONS.md` → Capture C-1 … C-4. Tokens:
`design/tokens/capture.json` (`camera.capture.*`) + global foundations by name. Copy: `design/copy/capture.json`.

## References

| image | what it verifies |
|---|---|
| `references/auto/yope/frames/a-jacob-7691153057177931039-t3.73-camera-hold-to-record.png` (2026-09-30) | whole layout, viewfinder, hour overlay, flash glyph, coach tooltip, shutter, library thumbnail, flip button |
| `references/auto/yope/frames/a-alexaa-7684388619099933966-t5.23-camera-hold-to-record-tabbar.png` (2026-09-11) | tooltip copy, tab bar under the camera |
| `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t4.73-camera.png` (2026-10-10) | camera layout, 4-item tab bar variant |
| `references/auto/yope/frames/a-virgi-7686278541255642390-t36.23-camera-first-open-es.png`, `…t35.23-camera-permission-alert.png` | first open: the system alert appears over the camera (no pre-prompt) |
| `references/auto/locket/store/locket-store-07.png`, `references/owner/locket-06-capture.webp` | Locket camera (C-1 comparison only) |
| `references/auto/locket/frames/locket-tt-7069892557970345259-02.800s-camera-2022.jpg`, `…-03.367s-shutter-pressed-2022.jpg` | shutter press motion and pressed disc |

## Structure (top to bottom, 393-pt screen)

1. Status bar (system). Background `color.global.backgroundDeep`.
2. Wordmark slot (Yope's 'YOPE' logotype — **not copied**; the slot stays empty, C-2).
3. **Viewfinder** — full screen width, top 103 pt, height = width × 1.38 (`camera.capture.layout.viewfinder`),
   corners `radius.global.viewfinder`. Inside it:
   - **Hour overlay** centred on both axes: `camera.capture.hourOverlay`, text role `overlayTimeCamera`
     (`fontSize.global.overlayTimeCamera` / `fontWeight.global.overlayTimeCamera`), `color.global.textPrimary`.
   - **Flash toggle** glyph bottom-leading, centre 28.3 pt from the leading edge and 33 pt above the bottom edge,
     glyph height 15 pt (`camera.capture.layout.flashGlyph`); `icon.global.flashOff` / `icon.global.flashOn`.
   - While recording a video: an outline around the viewfinder in `color.global.accent`
     (width `camera.capture.size.recordingOutline`, BLOCKED).
4. **Coach tooltip** (first use only, video available): lime pill centred on the shutter, pointer apex 2 pt above
   the shutter ring (`camera.capture.layout.coach`): leading video glyph `camera.capture.icon.recordHint`
   (at the text size) · `camera.capture.coach.holdToRecord` · ✕
   (`icon.global.close`, 9.5 pt).
5. **Control row**, 38 pt below the viewfinder (`camera.capture.size.shutterTopGap` to the ring top), all three
   vertically centred on the shutter:
   - leading: **library thumbnail** — 46 pt square (`camera.capture.size.libraryThumb`), corners
     `camera.capture.radius.libraryThumb`, 1-pt `color.global.textPrimary` border, centre 110 pt left of the shutter
     centre (`camera.capture.size.sideControlOffset`); shows the newest library photo, or `icon.global.gallery` in
     `color.global.textPrimary` when there is none / no access;
   - centre: **shutter** — outer 80 pt; 3.5-pt ring `color.global.accent`; 5.5-pt gap `color.global.backgroundDeep`;
     59-pt disc `color.global.surfaceLight` (`camera.capture.size.shutterOuter/Ring/Gap/Disc`);
   - trailing: **flip** — 47-pt circle `camera.capture.color.flipButton`, `icon.global.flip` in
     `color.global.textPrimary`, centre 110 pt right of the shutter centre.
6. App tab bar (global tab-bar tokens; owned by the navigation surfaces), as on Yope's camera.

## Elements

| element | tokens | copy | behavior |
|---|---|---|---|
| viewfinder | `camera.capture.layout.viewfinder`, `radius.global.viewfinder` | — | live back camera on open (front after a flip, kept for the session). Aspect-fill the camera feed. |
| hour overlay | text role `overlayTimeCamera`, `color.global.textPrimary` | `camera.capture.hourOverlay` ({time} = start of the current hour, device short-time style) | the hour slot the photo will be filed under; updates on the hour |
| flash toggle | `camera.capture.layout.flashGlyph`, `icon.global.flashOff` / `.flashOn`, `color.global.textPrimary` | a11y `camera.capture.a11y.flash` + value `.flashOn` / `.flashOff` | tap toggles off ↔ on (glyph swap, no animation observed). Default off. Hidden when the active camera has no flash. |
| coach tooltip | `camera.capture.layout.coach`, `camera.capture.icon.recordHint`, `camera.capture.fontSize.coach` / `.fontWeight.coach`, `color.global.accent` fill, `color.global.onAccent` text and glyphs | `camera.capture.coach.holdToRecord`; ✕ a11y `camera.capture.a11y.close` | shown once per install, only when video is available to the member; ✕ or the first recorded video dismisses it for good |
| shutter | `camera.capture.size.shutter*`, `color.global.accent`, `color.global.surfaceLight`, `camera.capture.color.shutterDiscPressed` | a11y `camera.capture.a11y.shutter`; custom action `camera.capture.a11y.recordVideo` (premium) | **tap** = photo (Live Photo where supported, see Platform notes) → `camera.sendto`. **Long press** = video (premium): records while held, stops on release or at `camera.capture.duration.videoMax` (10 s). Free member: the session's first long press opens `paywall` (owned there; at most one prompt per session); later long presses do nothing; tapping always captures (never blocks the core). |
| recording outline | `camera.capture.size.recordingOutline` (BLOCKED), `color.global.accent` | announcement `camera.capture.a11y.recording` | visible while a video records |
| library thumbnail | `camera.capture.size.libraryThumb`, `.radius.libraryThumb`, `.size.libraryThumbBorder`, `icon.global.gallery` | a11y `camera.capture.a11y.library` | opens the system photo picker (iOS PHPickerViewController / PhotosPicker, Android Photo Picker — no library permission); the picked photo / Live Photo / video goes to `camera.sendto` |
| flip | `camera.capture.size.flipButton`, `camera.capture.color.flipButton`, `icon.global.flip` | a11y `camera.capture.a11y.flip` | switches front ↔ back |

## States

| state | design | copy | source |
|---|---|---|---|
| loading (session starting) | viewfinder area `color.global.backgroundDeep` until the first frame; controls visible | — | no indicator in any Yope frame |
| permission not yet asked | the system alert appears directly over this screen on first open (iOS `NSCameraUsageDescription` / Android CAMERA runtime prompt) | purpose string owned by `system.permissions` | yope-a §2.6 (V-virgi t35.23) |
| permission denied | inside the viewfinder, Yope empty-state layout centred: title text role `emptyTitle`, detail `emptyDetail` in `color.global.textSecondary`, light pill (`color.global.surfaceLight` / `color.global.onSurfaceLight`, `radius.global.capsule`, height `camera.capture.size.permissionButtonHeight`, text role `button`); shutter and flip hidden, library thumbnail stays | `camera.capture.denied.title` / `.detail` / `.button` (opens the app's system Settings page) | `yope.voice.empty-state`, `yope.voice.permission` (V-chuong t7.73) |
| microphone (video) | asked at the first video only, never before a photo (App Review 5.1.1(iv)) | purpose string owned by `system.permissions` | platform.md §system.permissions |
| error (session interrupted / camera in use) | same empty-state layout | `camera.capture.unavailable.title` / `.detail` / `.button` (retries the session) | `yope.voice.error` |
| offline | no change: capture is local; sending is handled in `camera.sendto` | — | — |
| empty | n/a (library empty → `icon.global.gallery` in the thumbnail slot) | — | global icon note |

## Motion

| motion | tokens | Reduce Motion |
|---|---|---|
| shutter press: scale to 0.85 and disc → `camera.capture.color.shutterDiscPressed` | `camera.capture.spring.shutterPress` (response 233 ms, no overshoot), `camera.capture.layout.shutterPress` | no scale; the disc color change only (`layout.global.reduceMotion`) |
| capture → `camera.sendto` | Yope sheet: `duration.global.sheetPresent` + `spring.global.sheetPresent` (BLOCKED, F-15); until F-15 closes the documented alternative is the native presentation (`easing.global.native.sheet`) | cross-fade of the same duration |
| flash / flip / coach / recording outline | none observed → no custom animation (camera feed switch is the platform's) | — |

## Haptics

No haptic on any control of this screen: `haptic.global.shutter` (none — HIG: "Ensure that haptic vibrations don't
disrupt experiences involving … the camera"). The same rule covers flash, flip and the library button.

## Accessibility

- Labels: shutter `camera.capture.a11y.shutter` (button; custom action `.recordVideo` when video is available),
  flash `camera.capture.a11y.flash` with value `.flashOn` / `.flashOff` (iOS button + accessibilityValue; Android
  stateDescription), flip `camera.capture.a11y.flip`, library `camera.capture.a11y.library`, coach ✕
  `camera.capture.a11y.close`. The coach text is read as static text. Recording start posts
  `camera.capture.a11y.recording` as an announcement.
- Hour overlay: static text, read after the viewfinder (the viewfinder itself is not an element).
- Dynamic Type: hour overlay `overlayTimeCamera` → title; coach → `camera.capture.layout.textStyleMap.coach`
  (caption2); empty-state texts → `emptyTitle` / `emptyDetail` / `button` roles (global map).
- Focus order: flash → shutter → library → flip → (coach ✕ when shown, first) → tab bar.
- Touch targets: thumbnail 46 pt and flash glyph get a hit area of `size.global.minTouchTarget.ios` /
  `.android`.
- Contrast (`node tools/contrast.mjs`): coach text `color.global.onAccent` on `color.global.accent` 17.65:1 pass;
  shutter ring `color.global.accent` on `color.global.backgroundDeep` 17.65:1 pass; disc 21:1 pass; flip glyph white
  on `camera.capture.color.flipButton` 16.48:1 pass; **flip circle vs black 1.27:1 FAIL** (container edge; no
  sourced alternative — the glyph itself passes); thumbnail border 21:1 pass; hour overlay and flash glyph white
  over the live image: **photo-dependent, no scrim** (`color.global.scrim` BLOCKED).

## Data & actions

- Reads: none from the API on this screen; `public_app_config` not needed. Premium: `entitlements` (own row,
  active when `expires_at` is null or future) decides whether long press records.
- Writes: none here. The captured media (back photo, Live Photo motion, video) is handed to `camera.sendto`, which
  uploads (`u/<uid>/<media_id>/original.<ext>`, `motion.mov`) and calls `create_post` (docs/API.md recipe 9.4).
- In: app launch (the app opens to the camera), tab bar, `camera.fromwidget` deep link `app://camera?group=<id>`
  (`DeepLink.camera(groupID:)`; the group is preselected in `camera.sendto`), chat composer camera button (Yope).
- Out: `camera.sendto` (after capture / pick), `paywall` (free long press, once per session), system Settings.

## Platform notes

- iOS: `AVCaptureSession` single camera; Live Photo on when `AVCapturePhotoOutput.isLivePhotoCaptureSupported`
  (still + paired movie, docs/PLATFORM_CONSTRAINTS.md §6). No Live Photo toggle (none in any reference — Gaps).
- Android: CameraX; no Live Photo capture (PLATFORM_CONSTRAINTS: not researched → still photo). Tooltip glyph
  `camera.capture.icon.recordHint` (iOS `video.fill`, Android `Rounded.Videocam`).
- Video: `media.kind = video` needs premium at `create_post` (`premium_required`).
- Android deep link model requires a group id today (C-24): the camera must open without one too.

## Do-not-copy

YOPE wordmark; filter-name carousel and '1x' zoom label (not features, C-4); Locket's '12 Friends' pill (a count),
chat button with a count badge, photo-tinted background; streak pills anywhere.

## Gaps

| item | status | smallest capture / decision |
|---|---|---|
| `camera.capture.size.recordingOutline` | BLOCKED | 10-s iPhone screen recording of Locket hold-to-record |
| Yope hold-to-record visuals, shutter press on the current Yope build | not observed (Locket 2022 motion used) | 10-s Yope recording: one tap capture + one hold-to-record |
| Live Photo on/off control | not built (no reference shows one) | one screenshot of a Yope / Locket camera with Live Photo |
| zoom, focus tap | not built (not observed) | — |
| free-member long press after the session's prompt | does nothing (owner decision) | owner |
| coach shown only to members with video | owner decision | owner |

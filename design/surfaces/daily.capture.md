# daily.capture — capture with the countdown; back + front together; sequential fallback

Reference: **BeReal** (2026 App Store preview for the live screen; 2024 unedited recording and 2023 lossless help
screenshots for the capture sequence and the post preview). Tenet 5: the countdown is shown only while the window is
open, nothing changes color or says "late", and a photo taken after the window posts normally (SPEC_FLAGS T4).

## References

| image | what it verifies |
|---|---|
| `references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png` (AP #106) | live layout: chevron, countdown, 3:4 viewfinder, flash / shutter / flip |
| `references/auto/bereal/frames/appstore-preview-2026_timer-roll_f086-f129.png`, `tiktok-bereal-7339559678604627233_timer-roll_f496-f529.png` | countdown roll |
| `references/auto/bereal/frames/tiktok-bereal-7339559678604627233_shutter-press_f518-f546.jpg`, `…_capture-seq_f540-f681.jpg`, `…_t17.63s_black-spinner-prompt.png`, `…_t18.97s_back-photo-prompt.png` | press, controls out, spinner + prompt, back photo, preview |
| `references/auto/bereal/frames/tiktok-bereal-7339559678604627233_t21.30s_preview-keep-smiling.png` | post preview: inset, retake ✕, chips, SEND ➤ |
| `references/auto/bereal/help/help-21083708285725_bts-post-preview-2x.png` (H2, lossless) | preview geometry, countdown on the preview, text color |
| `references/owner/bereal-02-dualcam-preview.webp`, `references/auto/bereal/store/bereal-store-02.png` | preview (marketing, ratios only) |

## Structure

Full-screen cover on `color.global.backgroundDeep`; status bar hidden (as in AP). Positions on an 852-pt screen.

**Live (capturing)**
1. **Dismiss chevron** `icon.global.chevronDown`, centre (31.7, 74.5) (`daily.capture.layout.dismiss`), color
   `daily.capture.color.text`.
2. Wordmark slot above the countdown — **empty** (BeReal's wordmark is not copied).
3. **Countdown** centred, digits top 92.3 pt, 16.2 pt above the viewfinder (`daily.capture.layout.countdown`):
   `daily.capture.countdown` (MM:SS), `daily.capture.fontSize.countdown` (23 pt) / `.fontWeight.countdown` (bold),
   monospaced digits, `daily.capture.color.text`.
4. **Viewfinder** 3:4, 378.7 pt wide (7-pt side margins), top 124.4 pt, corner 16 pt (`daily.capture.layout.viewfinder`);
   back camera live.
5. **Control row** centred 148 pt above the screen bottom (`daily.capture.layout.shutter.centerFromBottom`): flash glyph
   (`icon.global.flashOff` / `.flashOn`) centred 59.2 pt from the leading edge; **shutter** 74 pt — 4-pt ring, 2.75-pt
   gap, 60.5-pt disc, ring and disc `color.global.surfaceLight` (`daily.capture.layout.shutter`); flip glyph
   (`icon.global.flip`) centred 60.1 pt from the trailing edge (`daily.capture.layout.sideControls`); glyphs
   `daily.capture.color.text`.

**Capturing (after the shutter)** — the viewfinder area turns black; in its centre the platform progress indicator
(34.7 pt, `daily.capture.size.progress`) and 11.4 pt below it one centred line `daily.capture.prompt`
(`daily.capture.fontSize.prompt`, `daily.capture.color.text`) (`daily.capture.layout.prompt`); the back photo fades in
behind them while the front photo is taken; chevron and countdown stay.

**Preview**
1. Chevron and countdown as above (the countdown keeps running).
2. **Dual image** in the viewfinder's frame: back photo 3:4 with the front photo inset top-leading
   (`daily.dualimage.layout.composition` — corner 0.0455 × width, inset 0.31 × width, margin 0.03 × width, 2-pt-ratio
   black border).
3. On the image: **retake ✕** circle 34 pt, 12 pt from the top and trailing edges, glyph 14 pt `icon.global.close`
   (`daily.capture.layout.retake`), fill `daily.capture.color.overlayControl` (black at 0.46 over a backdrop blur), glyph `daily.capture.color.text`;
   **audience chip** centred, 12.5 pt above the image bottom, height 37.4, capsule (`daily.capture.layout.audienceChip`):
   `icon.global.group` · `daily.capture.audience` ({group} only), `daily.capture.fontSize.chip`,
   `daily.capture.color.text`, fill `daily.capture.color.overlayControl`.
4. **SEND** — `daily.capture.send` (capitals, `daily.capture.fontSize.send` 40.5 pt, `.fontWeight.send` heavy,
   `daily.capture.color.text`), then 11.4 pt later the 19.5-pt triangle `icon.global.play`; the pair centred, cap top
   69 pt below the image bottom (`daily.capture.layout.send`).

## Elements

| element | tokens | copy | behavior |
|---|---|---|---|
| chevron | `daily.capture.layout.dismiss`, `icon.global.chevronDown` | a11y `daily.capture.a11y.dismiss` | dismisses (discarding an unsent preview); the invitation stays answerable from the group |
| countdown | `daily.capture.layout.countdown`, `.fontSize.countdown`, `.fontWeight.countdown`, `.color.text`, `.layout.countdownTick` | `daily.capture.countdown` | `closes_at − now` (server time), MM:SS, ticks every second; visible on the live screen, while capturing and on the preview; **removed at `closes_at`** and absent when opened after it |
| viewfinder | `daily.capture.layout.viewfinder` | — | back camera |
| flash | `daily.capture.layout.sideControls`, `icon.global.flashOff` / `.flashOn` | a11y `daily.capture.a11y.flash` + value `.flashOn` / `.flashOff` | applies to the back photo |
| flip | `daily.capture.layout.sideControls`, `icon.global.flip` | a11y `daily.capture.a11y.flip` | swaps which camera is the main photo for this capture |
| shutter | `daily.capture.layout.shutter`, `color.global.surfaceLight` | a11y `daily.capture.a11y.shutter` | takes both photos: simultaneous where the device supports it (iOS `AVCaptureMultiCamSession.isMultiCamSupported`, Android `FEATURE_CAMERA_CONCURRENT`), else sequential — back first, then front (BeReal's own observed order) |
| spinner + prompt | `daily.capture.size.progress`, `.layout.prompt`, `.fontSize.prompt` | `daily.capture.prompt` | while the photos are taken |
| retake | `daily.capture.layout.retake`, `daily.capture.color.overlayControl` | a11y `daily.capture.a11y.retake` | back to the live screen; unlimited, no count |
| audience chip | `daily.capture.layout.audienceChip`, `.fontSize.chip`, `icon.global.group` | `daily.capture.audience` | not interactive: the answer goes to the invitation's group |
| SEND | `daily.capture.layout.send`, `.fontSize.send`, `.fontWeight.send`, `icon.global.play` | `daily.capture.send`; a11y `daily.capture.a11y.send` | uploads and posts with `p_invitation_id`; the cover closes; `camera.sendto.toast.postedOne` + `haptic.global.send` |

## States

| state | design | copy |
|---|---|---|
| loading (camera starting) | viewfinder black until the first frame | — |
| window open | countdown visible | `daily.capture.countdown` |
| window closed (or opened after) | no countdown, nothing in its place; the photo posts as an ordinary post (`in_window` false, no label) | — |
| no simultaneous capture | sequential capture with the same visuals | — |
| front camera failed / unavailable | back photo alone (a single-camera answer, `daily.dualimage`) | — |
| camera permission denied | `camera.capture` denied layout inside the viewfinder | `camera.capture.denied.*` |
| camera unavailable | `camera.capture` unavailable layout | `camera.capture.unavailable.*` |
| send failed / offline | `camera.sendto` error toast with retry; the preview is kept | `camera.sendto.error.*` |
| empty | n/a | — |

## Motion

| motion | tokens | Reduce Motion |
|---|---|---|
| countdown tick: only changed digits move; old digit slides up and fades out (100 ms), new digit rises from 3 pt below (300 ms) and fades in to full (550 ms); colon fixed | `daily.capture.layout.countdownTick` | changed digits cross-fade (digitOut / digitIn durations), no movement |
| countdown removal at `closes_at` | the whole label leaves with the digit-out motion (100 ms) — approximation (C-18) | fade |
| shutter press → controls out → black → back photo in | `daily.capture.layout.captureSequence` (press to 0.912 in 133 ms, shutter shrinks to 0 by 370 ms, flash / flip gone, viewfinder fades to black over 267 ms, 500 ms black + spinner + prompt, back photo fades in over 200 ms) | no scale; fades only |
| preview appears | in one frame (BeReal) | same |
| dismiss | `easing.global.native` (cover / sheet dismissal) | system |

Curves were not measurable: each is a spring with the platform default damping (dampingFraction 1, as
`spring.global.platformDefault.*`) and response = the measured duration (as `camera.capture.spring.shutterPress`).

## Haptics

None while the camera is live or capturing (HIG camera rule; `haptic.global.shutter` none). Sent → `haptic.global.send`;
send failed → `haptic.global.error`.

## Accessibility

- Labels: chevron `daily.capture.a11y.dismiss`, shutter `.a11y.shutter`, flash `.a11y.flash` (+ value), flip
  `.a11y.flip`, retake `.a11y.retake`, SEND `.a11y.send`; dual image `daily.dualimage.a11y.label`; chip read as text.
- Countdown: accessibility value = the platform's spoken duration (iOS `Duration.formatted(.units(width: .wide))`,
  Android `DateUtils.formatElapsedTime` spoken), read when focused; no label words.
- Dynamic Type (`daily.capture.layout.textStyleMap`): countdown → title2, prompt → body, chip → footnote,
  SEND → largeTitle.
- Focus order: chevron → countdown → viewfinder area → flash → shutter → flip; preview: chevron → countdown → image →
  retake → chip → SEND.
- Contrast: `daily.capture.color.text` #FAFAFA on black 20.12:1 pass; shutter white on black 21:1 pass; chip text and
  ✕ on the translucent fill over a photo: photo-dependent; over a white photo #FAFAFA on the fill 3.45:1 (✕ passes the 3:1
  non-text rule; 13-pt chip text fails 4.5:1) — reported, not adjusted.

## Data & actions

- In: `app://daily?group=<id>&invitation=<id>` (push, Live Activity, ongoing notification) → read the invitation
  (`daily_invitations` by id; visible after `fires_at`). Out: back to where the member was; the collage arrives later
  (`collage.view`).
- Writes (recipe 9.4 / 9.5): upload `original.jpg` (main) and `front.jpg` (inset) under `u/<uid>/<media_id>/`; insert
  `media` (`kind = photo`, `front_original_path`, `front_width/height`); `create_post(p_media_id, [group_id],
  p_invitation_id)` — never fails for lateness; `in_window` is decided by the server.

## Platform notes

- iOS: `AVCaptureMultiCamSession` when `isMultiCamSupported` and `hardwareCost` / `systemPressureCost` ≤ 1; else one
  `AVCaptureSession`, switching inputs between shots. No Live Photo here (multicam Live Photo UNCONFIRMED).
- Android: CameraX `ConcurrentCamera` when `FEATURE_CAMERA_CONCURRENT` and the pair is in `availableConcurrentCameraInfos`;
  else sequential. Status-bar hiding: `WindowInsetsControllerCompat.hide(statusBars())`.
- Countdown uses the server's `closes_at`; correct for clock skew as the Android notifier does.

## Do-not-copy

BeReal wordmark; smile directives and every BeReal prompt line; 'VIDEO' / 'PHOTO' mode labels (no video here);
location chip 'Off'; 'BTS' controls; '{n} retakes'; '{n} min late' labels; any color change near 00:00; "keep an eye on
the timer".

## Gaps

| item | status | capture |
|---|---|---|
| `daily.capture.fontWeight.countdown` | SOURCED by gap fill: bold (SF Pro Display '1' stem ÷ height 0.207 vs BeReal 0.205, MERGE G2-14) | — (closed) |
| `daily.capture.color.overlayControl` (retake circle, chip) | SOURCED by gap fill: black at 0.46 ±0.06 on BeReal's lossless help frame over flat sky (MERGE G2-15) | one lossless BeReal post-preview screenshot over a flat light photo (would tighten the alpha) |
| countdown start value, 00:00 behavior | not observed (hidden at `closes_at` per T4) | 2–3-min BeReal recording from the push through the end of the window |
| tap-to-swap / drag of the inset | not found → not built | same recording |
| BeReal Android capture screen | not found | 20-s Android BeReal capture recording |
| prompt line weight | not measured (no token) | side-by-side verification |

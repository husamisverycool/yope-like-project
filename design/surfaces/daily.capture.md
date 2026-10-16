# daily.capture — capture with the countdown; back + front together; sequential fallback

**Visual reference: Retro** has no camera, so this full-screen cover is **composed only from Retro components** on
the media surface (`color.global.backgroundDeep`, both appearances): C-29 sheet header with the countdown in the title
slot and a C-11 close circle, the C-17 / C-18 photo container as viewfinder, the C-35 control row (shutter flanked by
64-pt circles), C-11 glass circle on the photo, C-09 pill on the photo, C-05 bottom capsule, C-27 / C-28 blocks.
**Mechanics: BeReal** (same-moment window with a countdown, back + front photos, sequential fallback, retake, the
answer goes to the invitation's group). Tenet 5: the countdown shows only while the window is open, nothing changes
colour or says "late", and a photo taken after the window posts normally (SPEC_FLAGS T4). Decisions:
`design/MERGE_DECISIONS.md` RC-12, RC-13.

## References

| image | what it verifies |
|---|---|
| `references/auto/retro/store/retro-store-03.png` (ST-03) | header geometry (`camera.sendto.layout.header`), photo frame gap (20 pt), pill on a photo (20.5-pt inset), bottom capsule position (`camera.sendto.size.sendButtonBottom`) |
| `references/auto/retro/press/tc-2025-12-rewind-device-a.png` (RWA), `…-device-b.jpg` | control row rule (`camera.capture.layout.controlRow`); glass circle over a photo |
| `references/auto/retro/store/retro-store-01.png` (ST-01, badge on a friend card; C-24) | overlay inset on a photo card (`size.global.badgeInset` 12) |
| `references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png` | mechanics: countdown above a 3:4 viewfinder, flash / shutter / flip |
| `references/auto/bereal/frames/tiktok-bereal-7339559678604627233_capture-seq_f540-f681.jpg`, `…_t17.63s_black-spinner-prompt.png` | mechanics: back photo, then front photo with a progress state |
| `references/auto/bereal/frames/tiktok-bereal-7339559678604627233_t21.30s_preview-keep-smiling.png` | mechanics: preview with the inset, retake, audience, send |

## Structure (393 × 852 pt)

Full-screen cover on `color.global.backgroundDeep`; status bar visible (light content).

**Header** (`camera.sendto.layout.header`): title slot centred, cap middle 25.8 pt below the safe-area top —
while the window is open the **countdown** `daily.capture.countdown` (text role `sheetTitle`, monospaced digits,
`color.global.textOnMedia`); after `closes_at` (or when opened late) the **group name** in the same role. Trailing
**close** circle (C-11 on media, `size.global.circleButton`, `color.global.controlOnDeep`, `icon.global.close`), centre
37.7 pt from the trailing edge.

**Live**
1. **Viewfinder** (`daily.capture.layout.viewfinder`): 3:4, screen − 2 × `size.global.screenMargin`, corners
   `radius.global.viewfinder`, top 20 pt below the close circle; back camera live.
2. **Control row** (`camera.capture.layout.controlRow`), centred between the viewfinder bottom and the safe-area
   bottom: **flash** circle (leading; C-11 64, `size.global.circleButtonLarge`, `color.global.controlOnDeep`,
   `icon.global.flashOff` / `.flashOn`), **shutter** (`camera.capture.size.shutterOuter/Ring/Gap/Disc`, ring and disc
   `color.global.surfaceLight`), **flip** circle (trailing, `icon.global.flip`).

**Capturing** (after the shutter): the control row fades out; inside the viewfinder frame (black): C-28 / C-27 block —
platform activity indicator (`color.global.textOnMedia`) → `size.global.emptyIconToTitle` → `daily.capture.prompt`
(text role `emptyTitle`, `color.global.textOnMedia`), centred; the back photo fades in behind it while the front photo
is taken.

**Preview**
1. **Dual image** in the viewfinder frame (`daily.dualimage.layout.composition` inside the frame's
   `radius.global.viewfinder` corners): back photo 3:4, front photo inset top-leading.
2. On it: **retake** — C-11 glass circle over a photo (`size.global.circleButtonPhoto` 40, `color.global.glass`,
   `icon.global.close` in `color.global.textOnMedia`), `size.global.badgeInset` (12) from the image's top and trailing
   edges; **audience pill** — C-09 on media (`color.global.controlOnDeep`, `icon.global.group` at
   `size.global.iconSmall` + `daily.capture.audience`, text role `pill`, `color.global.textOnMedia`,
   `size.global.pillHeight`), centred, 20.5 pt above the image bottom (`camera.sendto.layout.messageField.bottomInset`).
3. **Send capsule** (C-05 on media): `size.global.buttonHeight`, `size.global.buttonMarginH`, bottom
   `camera.sendto.size.sendButtonBottom` (44.5), fill `color.global.surfaceLight`, label `daily.capture.send` text role
   `button` `color.global.onSurfaceLight`.

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| close | C-11 on media · `camera.sendto.layout.header` | a11y `daily.capture.a11y.dismiss` | dismisses (an unsent preview is discarded); the invitation stays answerable from the group |
| countdown / title | C-29 title slot · `sheetTitle`, monospaced digits, `color.global.textOnMedia` | `daily.capture.countdown` (MM:SS); after the window: group name (data) | `closes_at − now` (server time), ticks every second, on all three stages; at `closes_at` the title slot cross-fades to the group name |
| viewfinder | C-17/C-18 container · `daily.capture.layout.viewfinder` | — | back camera |
| flash | C-11 64 · `icon.global.flashOff` / `.flashOn` | a11y `daily.capture.a11y.flash` + value `.a11y.flashOn` / `.flashOff` | applies to the back photo |
| shutter | mechanics shutter · `camera.capture.size.shutter*` | a11y `daily.capture.a11y.shutter` | takes both photos: simultaneous where supported (iOS `AVCaptureMultiCamSession.isMultiCamSupported`, Android `FEATURE_CAMERA_CONCURRENT`), else back first, then front |
| flip | C-11 64 · `icon.global.flip` | a11y `daily.capture.a11y.flip` | swaps which camera is the main photo |
| progress | C-28 indicator + C-27 title role | `daily.capture.prompt` | while the photos are taken |
| retake | C-11 glass 40 · `color.global.glass`, `size.global.badgeInset` | a11y `daily.capture.a11y.retake` | back to the live stage; unlimited, no count |
| audience pill | C-09 on media · `icon.global.group` | `daily.capture.audience` | not interactive: the answer goes to the invitation's group |
| send | C-05 on media | `daily.capture.send` | busy state as `camera.sendto`; uploads and posts with `p_invitation_id`; success → cover closes, `haptic.global.send`, Android toast `camera.sendto.toast.postedOne` |

## States

| state | design | copy |
|---|---|---|
| loading (camera starting) | viewfinder frame `color.global.backgroundDeep` until the first frame (fade in `duration.global.fade`) | — |
| window open | countdown in the title slot | `daily.capture.countdown` |
| window closed / opened after | group name in the title slot; the photo posts as an ordinary post (`in_window` false, no label) | — |
| no simultaneous capture | sequential capture, same visuals | — |
| front camera failed / unavailable | back photo alone (`daily.dualimage` single camera) | — |
| permission denied | `camera.capture` permission-denied C-27 block inside the viewfinder; flash / shutter / flip hidden | `camera.capture.denied.*` |
| camera unavailable | `camera.capture` error C-27 block | `camera.capture.unavailable.*` |
| send failed / offline | native alert as `camera.sendto` (preview kept) | `camera.sendto.error.*`, `camera.sendto.cancel` |
| empty | n/a | — |

## Motion

| motion | tokens | Reduce Motion |
|---|---|---|
| countdown digits | changed digits cross-fade `duration.global.crossfade` (100), monospaced so nothing shifts; countdown → group name: same cross-fade | same |
| live → capturing: control row out, viewfinder to black, block in | `duration.global.fade` (150) + `easing.global.standard` | same (fades) |
| back photo in behind the block; preview in | `duration.global.fade` | same |
| shutter press | platform default press | same |
| cover in / out | native full-screen cover (`easing.global.native.sheet`) | system |

BeReal's digit roll and capture choreography are not copied (motion is Retro's — RC-13).

## Haptics

Shutter: `haptic.global.shutter` (none). Close, flash, flip, retake, send presses: `haptic.global.tap` (Android
VIRTUAL_KEY; iOS none). Sent: `haptic.global.send`; failed: `haptic.global.error`.

## Accessibility

- Labels: close `daily.capture.a11y.dismiss`, shutter `.a11y.shutter`, flash `.a11y.flash` (+ value), flip
  `.a11y.flip`, retake `.a11y.retake`; send = its visible text; dual image `daily.dualimage.a11y.label`; pill read as text.
- Countdown: accessibility value = the platform's spoken duration (iOS `Duration.formatted(.units(width: .wide))`,
  Android `DateUtils.formatElapsedTime`), updated without announcements.
- Dynamic Type: `sheetTitle` → headline; `emptyTitle` → title3; `pill` → subheadline; `button` → headline.
- Focus order: countdown → close → viewfinder area → flash → shutter → flip; preview: countdown → close → image →
  retake → pill → send.
- Contrast (both appearances identical — media surface): `textOnMedia` on `backgroundDeep` 21.00:1 pass;
  `textOnMedia` on `controlOnDeep` 15.13:1 pass; circle fills vs black 1.39:1 **FAIL** (container edge, glyph
  identifies it); shutter vs black 21.00:1 pass; retake glyph on `color.global.glass` over a white photo 1.00:1 **FAIL**,
  over black 16.48:1 (photo-dependent, as Retro's Rewind circles); send label 21.00:1 pass.

## Data & actions

- In: `app://daily?group=<id>&invitation=<id>` (push, Live Activity, ongoing notification) → read
  `daily_invitations` by id (visible after `fires_at`).
- Writes (recipe 9.4 / 9.5): upload `original.jpg` (main) and `front.jpg` (inset) under `u/<uid>/<media_id>/`; insert
  `media` (`kind = photo`, `front_original_path`, `front_width/height`); `create_post(p_media_id, [group_id],
  p_invitation_id)` — never fails for lateness; `in_window` is set by the server.
- Out: back to where the member was; the collage arrives later (`collage.view`).

## Platform notes

- iOS: `AVCaptureMultiCamSession` when supported and `hardwareCost` / `systemPressureCost` ≤ 1; else one session,
  switching inputs between shots. No Live Photo here.
- Android: CameraX `ConcurrentCamera` when available; else sequential. Page `color.global.backgroundDeep`.
- Countdown from the server's `closes_at`, corrected for clock skew (as the Android notifier does).

## Do-not-copy

BeReal: wordmark, smile directives and prompts, 'SEND ➤' capitals, 'VIDEO' / 'PHOTO' labels, 'BTS', location chip,
'{n} retakes', '{n} min late', colour change near 00:00, "keep an eye on the timer", the digit-roll choreography.
Retro: wordmark.

## Gaps

| item | status | smallest capture |
|---|---|---|
| countdown start value, 00:00 behaviour in BeReal | not observed; title switches to the group name at `closes_at` (T4) | 2–3-min BeReal recording from the push to the end of the window |
| tap-to-swap / drag of the inset | not found → not built | same recording |
| Retro press state | platform default (RC-3) | 60 fps Retro recording |

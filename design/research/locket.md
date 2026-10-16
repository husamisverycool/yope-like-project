# Locket: reference research (widgets, camera, send, reactions, onboarding widget step, Gold paywall, push)

> **Owner decision 22 (2026-10-16):** what this file reports from Locket's decompiled app bundle (rows citing the APK's
> Hermes string table or JS constants) no longer counts as evidence. The canonical tokens and strings were re-sourced from
> public screenshots, help pages and platform documentation (design/MERGE_DECISIONS.md, OD22-*); this file is kept as the
> record of the research pass.

Researched on 2026-10-15. Locket (Locket Labs, Inc.) is the reference for these surfaces:
`widget.home.*`, `widget.lock.*`, `widget.arrival`, `widget.android`, `camera.fromwidget`, the
Locket parts of `camera.capture` and `camera.sendto`, `chat.reactions`, the Locket parts of
`photo.viewer`, `onboarding.widget`, `paywall`, and the Locket parts of `notifications.push`.

Evidence lives in `references/auto/locket/` (see its `INDEX.md`) and in `references/owner/locket-*`
(level CAPTURED). File paths below are relative to `references/auto/locket/` unless they start with
`references/owner/`. Pixel coordinates are in the source file's own pixels.

## 0. Sources and scale

| id | source | what it is | scale used | date / version |
|---|---|---|---|---|
| **AS-n** | `store/locket-store-0n.png` (1242×2688) | App Store marketing panels: a phone mock-up, tilted by about 2°, on a dark background | Tilt was corrected first (PIL rotate about the measured element). In AS-3 and AS-7 the phone screen measures 800 px between the bezel's inner edges (AS-8: 795 px), so **2.036 px/pt for a 393-pt-wide (6.1" Pro) screen**. The mock-up has a Dynamic Island, so 393 pt was assumed. Check: the small widget in AS-3 measures 323 px = 158.6 pt, and HIG's small widget on 393×852 is 158 pt | listing v2.68.0 (2026-10-11) |
| **GP-n** | `play/locket-play-0n.png` (1080×2338) | Google Play marketing panels (Android) | ratios only | Play listing updated 2026-10-08 |
| **MB** | `mobbin/locket-mobbin-paywall-screen.png` and `mobbin/locket-mobbin-gold-flow-0..7.png` | Raw iOS screenshots (1180×2556 = 393 pt @3x) from Mobbin's "Subscribing to Locket Gold" flow | **pt = px / 3** | Mobbin capture 2025-10-08 |
| **LZ** | `lazyweb/locket-lazyweb-*.png` | Raw iOS screenshots (1206×2622 = 402 pt @3x) from Lazyweb's Locket onboarding and locked-feature-paywall flows | **pt = px / 3** | captured 2026-08-03 to 2026-08-21 (current app) |
| **APK** | Locket Widget for Android **1.243.0** (versionCode 612), APKMirror bundle `com.locket.Locket_1.243.0-612_…apkm`, uploaded 2026-10-09. Read locally at `/tmp/claude-0/locket/apk/`; the APK is not in the repo | `res/layout/widget*.xml`, `res/xml/widget_info.xml`, drawables, `resources.arsc` (strings, colors, dimens), `AndroidManifest.xml`, and the string table of the React Native Hermes bundle `assets/index.android.bundle`. Decoded with androguard 4 and hermes-dec | **exact dp/sp values** from the app's own resources | 2026-10-09 |
| **HC** | help.locket.com (Intercom), all 56 articles fetched with curl | Official help text, verbatim | — | articles show "updated" dates; e.g. 5859739 updated 2026-05-05 |
| **TT-…** | @locketcamera TikToks, downloaded with yt-dlp to `/tmp/claude-0/locket/tt/`; frames are in `frames/` | see the table below | per video | posted 2022-02 → 2025-07 |
| **OW** | `references/owner/locket-*.jpg` | Owner's TikTok frames (540×960). `locket-add-widget-steps`, `-reply-grid` and `-emoji-rain` come from TT-7282839171952102686 (2023-09-25), found during this pass. **`locket-home-widget.jpg` is completely black** (every pixel 0,0,0), so it is unusable | 540 px = 390 pt assumed (fill-width crop), so 1.385 px/pt, ±4 pt | 2023 |

TikTok videos used (all from the official @locketcamera account):

| video | posted | kind | fps (avg) | used for |
|---|---|---|---|---|
| 7069892557970345259 | 2022-02-28 | **raw iOS screen recording**, 1080×1920 | 30 | camera, shutter press, send-to (2022 build) |
| 7147749171762908462 | 2022-09-26 | **raw iOS screen recording**, 1080×1920 | 29.97 | emoji picker, **emoji rain measurement** |
| 7168613044728155438 | 2022-11-21 | raw iOS screen recording, 576×1024 (screen = 472 px wide, 1.21 px/pt) | 30 | widget gallery card, placeholder → photo arrival |
| 7182656074468674859 | 2022-12-29 | screen recording | 30 | home-screen widget with caption, "2022 Rewind" widget |
| 7282839171952102686 | 2023-09-25 | phone filmed on a table | 30 | add-widget steps, reply sheet, emoji rain (2023) |
| 7460656081153445163 | 2025-01-16 | phone filmed in hand | 29.97 | Rollcall Live Activity, emoji sheet, reaction fly-to-cluster |
| 7498394022428331295 | 2025-04-28 | Android phone filmed in hand | 29.97 | Android widget, send-state sequence, settings |
| 7532209311150329102 | 2025-07-28 | iPhone filmed on a table | 29.97 | widget gallery: Locket / Best Friend / Crush widgets |

Not usable: @locketcamera's profile listing fails in yt-dlp (JSON error); @mrhackio 7151313369453104389
returned "IP address is blocked"; Firecrawl is out of credits (HTTP 402); YouTube was not tried
(bot-blocked per the brief).

---

## 1. `widget.home.small` / `.medium` / `.large` / `.xl`: iOS home-screen widget

### Reference images
- `store/locket-store-03.png`: small widget with a photo, round sender avatar at the bottom-left, caption pill "Sundays ☀️", and a yellow "9" badge at the top-right.
- `store/locket-store-06.png`: small widget with a photo and an avatar at the bottom-left; no caption, no badge.
- `store/locket-store-02.png` and `references/owner/locket-01-widget.webp`: an illustrated widget with a yellow outline (marketing art).
- `help/locket-help-7914857-widget-with-avatar-crop.png`: Locket's own help-center drawing of the widget (photo plus avatar at the bottom-left).
- `frames/locket-tt-7182656074468674859-00.500s-homescreen-widget-and-rewind-2022.jpg`: small widget with the avatar and a "luv" caption at the bottom-left.
- `frames/locket-tt-7168613044728155438-15.133s-widget-placeholder-just-added.jpg` → `15.167s-widget-photo-arrived.jpg` (placeholder, then the first photo).
- Widget gallery: `frames/locket-tt-7168613044728155438-11.900s-widget-gallery-card.jpg` (2022), `frames/locket-tt-7282839171952102686-10.300s-gallery-add-widget-2023.jpg`, `frames/locket-tt-7532209311150329102-13.750s/14.500s/15.500s-*` (2025).

### Layout (small widget)
The photo fills the whole widget (full bleed). The corner radius is the system widget radius.
- **Bottom-left:** a round sender avatar.
- **Right of the avatar, vertically centred on it:** a capsule caption pill with white text, when the photo has a caption.
- **Top-right:** a yellow circular badge with a dark number. It counts photos not yet seen; this is a do-not-copy count.
- **Below the widget:** the system label "Locket".
- Tapping the widget opens the app's camera (§5).

Sizes Locket offers on iOS:
- **Not directly observed.** Only small widgets appear in every image found.
- The iOS gallery shows **4 page dots** on the "Locket Widget" card in 2022 (`…11.900s-widget-gallery-card.jpg`) and **2 dots** in 2023 (`…10.300s-gallery-add-widget-2023.jpg`).
- In 2025 the gallery pages are "Locket Widget", "Best Friend Widget" and "Crush Widget" (all square previews). Pages in the iOS gallery can be sizes *or* kinds, so medium/large sizes stay unconfirmed.

Configuration options:
- **Per friend:** The "Best Friend Widget" and "Crush Widget" show one person. The App Store text says: "Add the “Crush” or “Best Friend” picture widget, and see photos only from that person. Plus, you can send images just to that person too!"
- **Per audience:** In the 2026 profile sheet (`lazyweb/locket-lazyweb-20260803-autocap-21.png`), a "Widgets  New" section shows one tile per configured widget ("Everyone" / Edit) and a "Create" tile.
- **Frames:** Gold adds "Widget frames / Personalize your widgets" (MB flow 2) and "Edit widget frame" (Android settings).

### Measured values (iOS)

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| 158.6 pt (323 px) | small widget width | AS-3 deskewed 1.72° | left 260.5, right 583.5 at y 1000–1100 | edge scan, ÷2.036 | ±1 pt | SOURCED (validates scale: HIG 158 pt) |
| **24 pt** (range 23.7–25.0) | sender avatar diameter | AS-3: 51 px (x 275→327, y 1151→1201); AS-6: 48 px / 320-px widget; help drawing: 24 px / 155 px; TT-7168613044728155438 placeholder: 30 px at 1.21 px/pt | as listed | edge scan; ratio × 158 pt | ±1 pt | SOURCED |
| **6 pt** (range 4.7–7.1) | avatar inset from widget left/bottom | AS-3 left 14.5 px / bottom 9.5 px; AS-6 left 11.75 / bottom 12.5 px; TT placeholder ≈7 px | as listed | edge scan | ±1.5 pt | SOURCED |
| ~1 pt light ring | avatar border | help drawing; AS-6 (subtle) | — | visual | — | SOURCED (Android source: 1 dp `#1A000000`, §2) |
| **23 pt** (47 px) | caption pill height | AS-3 | y 1151→1198 at x 340–480 | ASCII render of pixel rows | ±1 pt | SOURCED |
| capsule (radius = height/2) | caption pill corners | AS-3 | — | visual | — | SOURCED |
| **7 pt** | caption pill horizontal padding | AS-3 | pill left 336.7 → "S" 350 (14 px); emoji end ≈470 → pill right 483 (13 px) | edge scan | ±1 pt | SOURCED (Android source: 7 dp) |
| **5 pt** | gap from avatar to caption pill | AS-3 | avatar right 327 → pill left 336.7 | edge scan | ±1 pt | SOURCED (Android source: 6 dp) |
| **≈12 pt**, semibold/bold, white | caption text | AS-3 | "S" cap height 17 px (y 1167→1183) | cap height ÷ 0.705 (SF cap ratio) | ±1 pt | SOURCED (weight by eye) |
| translucent dark (blurred) | caption pill fill | AS-3 | inside vs outside: (88,90,88) over dark hair (33,32,36); (81,106,147) over blue (57,129,249) | medians of 5×10 blocks | not solvable to one alpha (the pill blurs the photo) | approximated. Android source: `#CC333333` |
| **23 pt** (47 px) | count badge diameter (**do-not-copy**) | AS-3 | x 519→565, y 907→953 | yellow mask bbox | ±1 pt | SOURCED |
| 9 pt | badge inset top/right | AS-3 | top 17.5 px, right 18.5 px | edge scan | ±1 pt | SOURCED |
| `#FEB700` | badge fill | AS-3 | annulus at (554–561, 910–950) | median | ±3/255 | SOURCED |
| `#171100` (near-black) | badge digit | AS-3 | darkest pixel in the digit | min | ±10/255 | SOURCED |
| system (circle fit 25 pt) | widget corner radius | AS-3 top-left corner | points (273,907), (265,919), (279,901) | circle fit r = 50.3–50.9 px | — | PLATFORM: use `ContainerRelativeShape` / system widget radius |
| `#2D2B2F` → `#201E21` (top → bottom) | empty placeholder tile, just after the widget is added | `frames/…15.133s-widget-placeholder-just-added.jpg` | blocks (150–220, 120–140) and (200–260, 240–255) | median | ±5/255 (lossy) | SOURCED (2022 build) |
| 3 avatars of 25 pt, 2–3 pt apart, not overlapping, bottom-left | empty placeholder content | same | avatars y 250→280, step 33 px | edge scan, ÷1.21 | ±1.5 pt | SOURCED (2022) |

### Widget gallery (iOS) copy, verbatim
- 2022 (`…11.900s-widget-gallery-card.jpg`): title **"Locket Widget"**, description **"See live pics from all your friends right on your Home Screen"**, preview text **"20 Friends"**. The preview is a dark rounded square with 3 overlapping avatars in yellow rings. The "Add Widget" button is system UI.
- 2023: same title, preview "26 Friends" (the preview shows the user's real friend count).
- 2025 (`TT-7532209311150329102`, filmed at an angle; the descriptions are partly cropped):
  - "Locket Widget", preview "3 Friends".
  - **"Best Friend Widget"**, description "…a special widget just for your best friend". The first word is cut off in every frame. Preview: gold-brown tile, crown in a yellow ring, "**Best Friend**" / "**Pick one friend**".
  - **"Crush Widget"**, description "…a special widget just for your crush". Preview: dark-red tile, ❤️ in a red ring, "**Crush**" / "**Pick your crush**".
- Android widget-picker description (APK `app_widget_description`): **"Live pics from your friends, on your home screen"**.

### Do-not-copy (widget)
- **Unseen-photo count badge** ("9"; Android `locket_missed_moments_badge`, 28 dp).
- **Streak pill on the widget** ("🔥158", `frames/locket-tt-7498394022428331295-04.000s-android-widget-streak-DONOTCOPY.jpg`; Android `locket_streak_frame`; setting "Streak on widget").
- Friend-count previews ("20 Friends") are acceptable only as "who is in this group"; never as a score.
- Gold "widget frames" are a paid decoration: record only.

### Not found
- **Medium, large and extra-large Locket widget layouts on iOS:** no image of any size other than small. Tried the App Store (7 panels), Google Play (7), Mobbin, Lazyweb, 8 TikToks and the help center.
- **iOS caption pill background colour:** approximated only (blur material).
- **iOS widget font name:** not found (see §10).

---

## 2. `widget.android`: Glance/AppWidget reference (exact values from the APK)

### Reference images
- `play/locket-play-01.png`
- `play/locket-play-02.png`
- `play/locket-play-04.png`
- `frames/locket-tt-7498394022428331295-04.000s-android-widget-streak-DONOTCOPY.jpg`
- APK resources (listed in the table below)

### Layout
Taken from `res/layout/widget.xml`, a RelativeLayout with ids resolved:
- **`locket_image_view`:** the photo, centred, `scaleType=centerCrop`, `adjustViewBounds`. The initial image is `@drawable/ic_widget_preview_static`.
- **`locket_frame_view`:** the frame overlay. It holds the Gold widget frame image.
- **`locket_profile_view`:** the sender avatar, 32×32 dp. It is aligned to the photo's bottom-start with an 8 dp margin and has a `bg_circle_border` ring.
- **Caption container:** to the end of the avatar, `marginStart` 6 dp, `marginEnd` 8 dp, bottom margin 8 dp. It holds one of these variants:
  - a rendered text caption (`locket_caption_view`, background `bg_rounded`);
  - location (`bg_overlay_caption_regular`, 18 dp icon tinted `#B3FFFFFF`, padding 7 dp);
  - weather;
  - music;
  - link;
  - streak (the streak variant is do-not-copy).
  The text is rendered as a bitmap.
- **Top-end:** `locket_missed_moments_badge` (28×28 dp; 38×28 dp for the "max" variant). This is the do-not-copy count.
- **Top-start:** `locket_streak_frame`, 28 dp high, elevation 12 dp (do-not-copy).
- **Container style:** `Widget.Locket.AppWidget.Container`, with `android:id="@android:id/background"`, background `app_widget_background`, padding `?appWidgetPadding` = 0 dp. Because the root has `id/background`, Android 12+ clips the widget to the system corner radius. `appWidgetRadius` = 8 dp is the fallback for older Android versions.

`res/xml/widget_info.xml`:
- `minWidth` 110 dp and `minHeight` 110 dp.
- `resizeMode` = horizontal|vertical.
- `updatePeriodMillis` = **86 400 000** (24 h).
- `widgetCategory` = home_screen only.
- `previewImage` = `ic_widget_preview_static`.
- `description` = "Live pics from your friends, on your home screen".

Empty states:
- `widget_empty` (default) and its `_sm` / `_lg` variants:
  - a 512-dp gradient background;
  - an avatar circle;
  - a yellow outline ring;
  - a photo icon;
  - a label bitmap below.
- Strings `no_pics_yet` = **"No pics yet"** and `tap_to_set_up` = **"Tap to set up"**.

### Values (all level SOURCED, precision exact; evidence = APK 1.243.0 file and resource)

| value | element | resource |
|---|---|---|
| 110 × 110 dp | minimum widget size | `res/xml/widget_info.xml` |
| 32 dp | sender avatar diameter (`widget_profile_photo_size`) | `res/layout/widget.xml`, `dimen/widget_profile_photo_size` |
| 8 dp | avatar margin start/bottom; caption bottom margin; badge margins | `res/layout/widget.xml` |
| 6 dp | gap avatar → caption | `res/layout/widget.xml` |
| 1 dp `#1A000000` stroke | avatar ring | `drawable/bg_circle_border` |
| linear 270°, `#F5A0A0A0` → `#F5828282` | avatar placeholder (no photo) | `drawable/bg_profile_placeholder` |
| radius 17 dp, fill `@color/black_30` = `#4D000000`, padding 6 / 6.5 dp | text caption background | `drawable/bg_rounded` |
| radius 999 dp (capsule), fill `#CC333333` | location caption pill | `drawable/bg_overlay_caption_regular`, `color/overlayBackgroundDark` |
| radius 17 dp, fill `#66333333`, padding 7 dp | light overlay | `drawable/bg_overlay_light`, `color/overlayBackgroundLight` |
| 18 dp icon, tint `#B3FFFFFF`; pill padding 7 dp; icon→text 4 dp; pill height 32 dp | location/weather/music caption pills | `res/layout/widget.xml` |
| 28 × 28 dp, radius 16 dp, gradient `#FFCD4E`→`#FFC52D` with 2.5 dp inset fill `#FFB800` | count badge (**do-not-copy**) | `drawable/bg_badge` |
| linear 270° `#2E2E2E` → `#1B1B1B` | empty widget background | `drawable/bg_widget_empty` |
| 72 dp circle `#3DFFFFFF` (sm 54, lg 98) | empty avatar circle | `layout/widget_empty*.xml`, `drawable/bg_widget_empty_circle` |
| 82 dp ring, 3 dp stroke `#FFB800` (sm 62, lg 110) | empty yellow ring | `drawable/bg_widget_empty_circle_outline` |
| 32 × 28 dp white photo glyph (sm 24×21, lg 43×36) | empty icon | `drawable/ic_widget_empty_icon` |
| 19 sp (sm 14, lg 21); margin-top 9 dp (sm 6, lg 24) | empty label | `dimen/empty_widget_label_font_size_*`, layouts |
| 8 dp | fallback corner radius (pre-Android 12) | theme attr `appWidgetRadius` |

### Do-not-copy
Streak frame and "Streak on widget"; missed-moments count badge.

### Not found
The Android empty-label text bitmap content beyond "No pics yet" / "Tap to set up".

---

## 3. `widget.lock.rect` / `.circular` / `.inline`

**Not found.**
- No source shows a Locket lock-screen widget.
- The Android `widget_info.xml` declares only `widgetCategory=home_screen`. It has an `initialKeyguardLayout`, but not the keyguard category.
- The Android bundle has **0** strings containing "lock screen".
- The App Store text, the help center (56 articles), Google Play, Mobbin, Lazyweb and TikTok searches mention only the Home Screen.
- Web searches (3 queries) found only third-party claims.

Locket's presence on the lock screen is the **Rollcall Live Activity**: `frames/locket-tt-7460656081153445163-01.000s-rollcall-live-activity-lockscreen.jpg`. It reads "Rollcall / Photo dumps with your friends, every Sunday / Pick your photos", with a "Locket" pill. That is a different surface (`daily.liveactivity`-like) and is out of scope here.

**Smallest capture that would settle it:** one screenshot of the iOS Lock Screen "Add Widgets" sheet after searching "Locket".

---

## 4. `widget.arrival`: how a new photo arrives, and Locket's refresh approach

### What Locket says (verbatim)

| text | source |
|---|---|
| "When a friend sends you a photo on Locket, it will appear on your Home Screen, but there may be a slight delay of up to 5 minutes. This delay helps conserve your phone’s battery. If you experience a delay of more than 5 minutes, try the following steps." followed by the list "Restart your device" / "Check that the Locket app is up to date" / "Check that iOS/Android is up to date" | HC 5859739 "Why isn't my Locket widget updating?" (updated 2026-05-05) |
| "After you install Locket, it can occasionally take up to an hour for the widget to appear in the Widget Gallery. If you don't want to wait, restarting your device will make the widget appear immediately." | HC 5859709 "Why doesn't Locket appear when I try to add the widget?" |
| "When a friend sends a picture, it will appear on your Home Screen instantly, like a virtual picture frame." | HC 14225418 (parent article) |
| "When a friend sends you a photo, it instantly appears on your Locket widget!" | App Store and Play description |

The "up to 5 minutes" statement and the "instantly" claims contradict each other. The troubleshooting article is the specific and more recent one.

### Mechanism visible in the Android build (APK 1.243.0, SOURCED)
- **Push path:**
  - `FirebaseMessagingService` → `com.locket.Locket.NotificationHandler`.
  - `com.locket.Locket.WidgetRefreshReceiver` handles the actions **`NOTIFICATION_WIDGET_UPDATE`** and **`ALARM_WIDGET_UPDATE`**.
- **Scheduled fallback:**
  - `com.locket.Locket.AlarmReceiver` re-arms on `BOOT_COMPLETED`.
  - `widget_info.xml` keeps the system `updatePeriodMillis` at 24 h, so it is effectively push- and alarm-driven.
- **Foreground service while refreshing:**
  - `com.asterinet.react.bgactions.RNBackgroundActionsTask` with `foregroundServiceType` 0x800 (shortService).
  - Notification channel "**Widget Updating**", described as "**Shown briefly while the home screen widget refreshes**".
  - Notification title "**Updating widget...**".
- Bundle log strings: "Widget Refreshed: ", "Failed to refresh widget: ", "logOpenedFromWidget", "Failed to parse widget launch URL".

### Visual arrival
- **iOS, 2022 screen recording** (`frames/…15.133s-widget-placeholder-just-added.jpg` → `…15.167s-widget-photo-arrived.jpg`; TT-7168613044728155438 at 30 fps, frames 49→50 counted from 13.5 s):
  - The dark placeholder with 3 avatars is replaced by the photo **between two consecutive frames**: ≤33 ms, with no fade or slide.
  - The rest of the screen is identical in both frames, so this is not a video cut.
  - **Duration: 0 (instant swap); curve not applicable.**
- **iOS 17+ content transitions:** no recent recording, so not observed.
- **Help-center drawing of a widget that has not updated** (`help/locket-help-5859739-widget-refresh-placeholder-crop.png`): a gray rounded tile with a circular refresh arrow. This is a drawing, not an in-app screenshot.

### Notification that accompanies arrival
See §9. The Android client builds "Sent you a Locket!" (title presumably the sender's name) and multi-sender variants.

### Not found
- How the current iOS widget animates when a new photo arrives.
- Locket's iOS refresh mechanism (iOS app is native; no binary inspected).

**Smallest capture:** a 10-second screen recording of an iPhone (iOS 17+) Home Screen while a friend sends a photo.

---

## 5. `camera.fromwidget` and `camera.capture` (Locket parts)

### Copy (verbatim)
- **Store headline:** "Capture" / "Tap the widget to open the camera" (AS-7, GP-5).
- **Description:** "To share a pic back, tap into the widget, take a pic with the camera, and then hit send! It appears right on your friends’ Home Screens".
- **HC 7915017:** "Touch and hold on the shutter button to begin recording. The yellow outline around the viewfinder indicates that capture is in progress." and "Release your finger to stop recording."
- **Android:** "Tap the switch to enter video mode." / "Tap the shutter button to begin recording, then tap the stop button to stop the capture."
- **History entry:** "History" with a chevron below the shutter (AS-7, GP-5).

### Reference images
- `store/locket-store-07.png` (AS-7, current iOS)
- `play/locket-play-05.png` (Android)
- `references/owner/locket-06-capture.webp`
- `references/owner/locket-camera-early.jpg`
- `frames/locket-tt-7069892557970345259-02.800s-camera-2022.jpg`
- `…03.367s-shutter-pressed-2022.jpg`

### Layout (AS-7, top to bottom)
- **Top row** (vertical centre y = 914.5 px), three 44-pt controls:
  - left: the user's avatar in a translucent ring;
  - centre: the capsule "👥 12 Friends" (Android: "8 friends");
  - right: a circular chat button with a yellow count badge.
- **Viewfinder:**
  - square, **full screen width**, large rounded corners;
  - 62 pt below the top row's bottom;
  - Android draws the flash toggle inside its top-left and a photo/video toggle at its bottom centre.
- **41 pt below the viewfinder, a control row:**
  - flash glyph (left);
  - shutter (centre);
  - flip-camera glyph (right);
  - Android swaps the flash for a library button.
- **Below the controls:** a "History" row with a rounded-square thumbnail of the last photo, the word "History", and a chevron ⌄ under it.

The 2022 build (TT-7069892557970345259) had a smaller shutter and icon-only corners: friends icon at top-left, profile icon at top-right.

### Measured values

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| 393 pt wide, 1:1 (798 × 804.5 px) | viewfinder | AS-7 deskewed 2.0° | x 216→1014, y 1084.5→1889 | edge scan | ±2 pt | SOURCED; GP-5 also full-width |
| **49 pt** (98–102 px) | viewfinder corner radius | AS-7 | TL points (244,1114), (234,1126), (258,1102) give r = 98.1/98.2/97.8 px; BL (234,1846), (245,1858) give 100.3/102.4 | 3-point circle fits, ÷2.036 | ±2 pt | SOURCED (ratio r/width = 0.124) |
| 62 pt | top-row bottom → viewfinder top | AS-7 | 959 → 1084.5 | edge scan | ±1 pt | SOURCED |
| 16 pt | side margin of top-row controls | AS-7 | avatar left 250 (screen 216); chat right 982 (screen 1014) | edge scan | ±1 pt | SOURCED |
| **44 pt** (89–90 px) | avatar button, friends pill height, chat button | AS-7 | avatar x 250→339; pill y 870→959; chat x 892→982 | edge scan | ±1 pt | SOURCED |
| 3 pt translucent ring, photo 38 pt | avatar button | AS-7 | ring x 250→255 (47,60,68) over bg (26,39,47) | pixel row 914 | ±1 pt | SOURCED |
| 138 pt (281 px) | friends pill width (content-sized) | AS-7 | x 475→756 | edge scan | ±1 pt | SOURCED |
| 16 / 9 / 14 pt | pill padding left / icon→text gap / padding right | AS-7 | 475→507, 551→570, 728→756 | edge scan | ±1 pt | SOURCED |
| ≈16 pt bold, white | "12 Friends" label | AS-7 | digit "1" height 23 px (y 903→925) | cap height ÷ 0.705 | ±1 pt | SOURCED |
| translucent white over the background: (52–55, 62–68, 72–76) over (26–29, 37–40, 44–49) | pill and chat button fill | AS-7 | pixel rows 912, 918 | samples | — | SOURCED (≈ white 12% by eye; alpha not solved) |
| 18 pt (37 px) | chat count badge (**do-not-copy**) | AS-7 | x 953→990, y 857→894 | yellow mask bbox | ±1 pt | SOURCED |
| **86 pt** (174.5 px) | shutter outer diameter (yellow ring) | AS-7 | x 530→703, y 1972→2146 | yellow mask bbox | ±1 pt | SOURCED |
| **4.5 pt** (9 px) | ring stroke width | AS-7 | row 2059: x 529→538; column 616: y 1972→1980 | pixel scan | ±0.5 pt | SOURCED |
| **3 pt** (6 px) | dark gap between ring and disc | AS-7 | x 539→544; y 1981→1987 | pixel scan | ±0.5 pt | SOURCED |
| **70 pt** (143 px) | white disc diameter | AS-7 | disc starts x 545 and y 1988; centre (616.5, 2059) | pixel scan | ±1 pt | SOURCED |
| `#FFB900` | shutter ring | AS-7 | (531–535, 2059), (616, 1974–1978) | samples | ±2/255 | SOURCED |
| `#EBEBEB` | shutter disc | AS-7 | (616, 2059), (600, 2030), (640, 2090) | samples | ±2/255 | SOURCED (in the 2022 recording the disc is `#FDFDFD`) |
| 41 pt | viewfinder bottom → ring top | AS-7 | 1889 → 1972 | edge scan | ±1 pt | SOURCED |
| 126 pt / 118 pt | shutter centre → flash glyph centre / → flip glyph centre | AS-7 | flash bbox x 336→383, flip x 816→897 | white-pixel bbox | ±3 pt | SOURCED |
| 23 × 36 pt / 40 × 33 pt | flash / flip glyph boxes | AS-7 | as above | bbox | ±2 pt | SOURCED |
| 36 pt rounded square | History thumbnail | AS-7 | ≈ x 501→575, y 2230→2303 | zoom read | ±2 pt | SOURCED |
| ≈19–20 pt semibold, white | "History" label | AS-7 | "H" cap height 28 px | cap ÷ 0.705 | ±1.5 pt | SOURCED |
| 33 × 11 pt, rounded stroke | chevron ⌄ | AS-7 | zoom 2× x 200→335, y 255→300 | zoom read | ±2 pt | SOURCED |
| 74 pt (204 px at 1080 px = 390 pt) | shutter ring, 2022 build | `frames/…02.800s-camera-2022.jpg` | ring x 438→641, y 1345→1548 | yellow mask | ±1 pt | SOURCED (older build; superseded) |
| (26, 39, 47) top → (31, 16, 6) bottom | camera background | AS-7 | (300, 1000) and (640, 1920) | samples | — | SOURCED. The background is tinted by the photo: lead 30 measured `#1D1914`→`#2E1A09`; MB's own capture shows other tints. Not a constant |

### Motion: shutter press (2022 build; TT-7069892557970345259, 30 fps, raw screen recording)
Ring outer diameter per frame, measured with a yellow mask in the region x 330–700, y 1300–1650. Frame k is at t = 2.8 + k/30 s.

| k | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
|---|---|---|---|---|---|---|---|---|---|
| px | 204 | 200 | 191 | 184 | 179 | 176 | 175 | 173 | 173 |

- The disc dims from `#FDFDFD` to `#E0DEDF` over the same frames.
- **The shutter scales to 0.85 in about 7 frames (233 ms ±33 ms).** The per-frame change is 4, 9, 7, 5, 3, 1, 2: velocity peaks in the second frame, then decelerates (ease-out-like). The exact curve cannot be measured.
- At k = 21 the shutter cross-fades into the gray send button in one frame. It is settled at k = 22, 33–67 ms after the press settles. The capture time is included.

### Not found
- Hold-to-record visuals on the current build (the yellow outline is known only from the help text).
- Current iOS shutter press timing (only the 2022 build was measured).

**Smallest capture:** a 10-second iPhone screen recording of one tap capture and one hold-to-record.

---

## 6. `camera.sendto` (Locket parts)

### Reference images
- `references/owner/locket-review-sendto.jpg`, `-review-caption.jpg`, `-review-sending.jpg`, `-review-sent.jpg` (2023)
- `frames/locket-tt-7069892557970345259-03.533s-review-sendto-all-friends-2022.jpg`
- `frames/locket-tt-7498394022428331295-01.300s-android-sendto-add-a-message.jpg`
- `…01.734s-android-send-spinner.jpg`
- `…02.134s-android-sent-check.jpg`

### Layout
- **Header:** small gray "Send to" (2022/2023), or "Send to..." (Android 2025). Below it, the recipient in white semibold ("All Friends" in 2022, "Ava" in 2023).
- **Photo:** the captured photo in the same rounded square as the viewfinder.
- **Caption:** entered with a capsule placeholder "**Add a message**" at the bottom of the photo (Android 2025 frame; APK string). The white boxes with black text in the owner frames ("When either of us sends a photo…") are **TikTok overlays**, not app UI. So are the red and purple boxes in TT-2022-02.
- **Control row:**
  - ✕ discard (left);
  - send button (centre): a paper plane in a gray circle that takes the shutter's place;
  - download (right; 2022/2023) or a sticker/emoji button (Android 2025).
- **Below the controls (2022):** a "Pick Friends ›" capsule. The App Store text describes the default audience as all friends; the APK strings include "All Friends", "Send to..." and "Everyone".
- **Recipient avatar row:** the current horizontal row of friend avatars with "All" first was **not observed** in any image.

### Send button states
- **iOS 2023** (OW): paper plane → spinner (system-style, 8 spokes) → ✓. All three are drawn in the same gray circle.
- **Android 2025** (TT-7498394022428331295, 29.97 fps, filmed; frame k at t = 1.2 + k/29.97 s):

| k | state |
|---|---|
| 0–10 | idle paper plane |
| 11 | tap (glyph dims); ✕ and the sticker button disappear |
| 12–21 | spinner arc rotating |
| 22–26 | circle colour changes from translucent gray to yellow, and the ✓ appears |
| 26–33 | yellow ✓ holds (the rest of the screen is black) |
| 34–38 | fades out; the app then closes to the Home Screen |

Derived durations:
- **Colour change: ≈5 frames = 167 ms (±33 ms).**
- **✓ hold: ≈7 frames = 233 ms.**
- **Fade-out: ≈5 frames = 167 ms.**
- The spinner time (≈10 frames) depends on the network; it is not a design constant.
- Curves cannot be measured from a filmed video.

### Measured values

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| **81 pt** (≈112 px) | send button diameter (2023) | `references/owner/locket-review-sendto.jpg` | x 213→327, y 772→880 | pixel scan, 540 px = 390 pt | ±4 pt | CAPTURED |
| `#444245` | send button fill (all 3 states, 2023) | same, plus `-sending`, `-sent` | blocks (230–245, 800–815), (300–312, 840–855) | median | ±3/255 (JPEG) | CAPTURED |
| `#010002` | review background | same | (205, 827) | sample | ±2/255 | CAPTURED |
| ±119 pt from centre | ✕ / download glyph centres | same | ✕ x 88→119, download x 417→452 | white bbox | ±4 pt | CAPTURED |
| ≈12–13 pt, gray | "Send to" | same | cap ≈12 px (y 48→60) | cap ÷ 0.705 | ±1.5 pt | CAPTURED |
| ≈16–17 pt semibold, white | recipient name ("Ava") | same | "A" 16 px (y 78→94) | cap ÷ 0.705 | ±1.5 pt | CAPTURED |
| (255, 173, 7) ≈ brand yellow | Android sent-state circle | `frames/…02.134s-android-sent-check.jpg` (k = 28) | block (540–640, 1200–1300) | median of bright pixels | camera-filmed; ±10/255 | SOURCED (consistent with `#FFB800`) |

### Do-not-copy
Nothing specific; streak captions exist ("Streak" caption view) and are do-not-copy.

### Not found
- Current iOS send-to row (avatars + "All").
- Caption entry keyboard state.
- Send button size on the current iOS build.

**Smallest capture:** one 15-second iPhone screen recording of capture → pick 2 friends → type caption → send.

---

## 7. `chat.reactions` and Locket parts of `photo.viewer`

### Reference images
- `frames/locket-tt-7147749171762908462-02.000s-emoji-picker-search.jpg`, `…05.300s-emoji-rain-rising-behind-photo.jpg`, `…05.667s-emoji-rain-exit-top.jpg` (2022)
- `references/owner/locket-reply-grid.jpg`, `references/owner/locket-emoji-rain.jpg`, `frames/…7282839171952102686-16.600s-reply-sheet-emoji-rain-2023.jpg` (2023)
- `frames/locket-tt-7460656081153445163-15.000s-emoji-picker-sheet-search-popular.jpg`, `…16.534s-reaction-fly-to-cluster.jpg`, `…16.734s-reaction-cluster-landed.jpg` (2025)
- `store/locket-store-08.png` (History reply bar), `store/locket-store-04.png` (reaction cluster), `play/locket-play-07.png`, `play/locket-play-03.png`

### Layout
- **History / photo viewer** (AS-8, GP-7):
  - photo in the rounded square, caption centred near its bottom;
  - below it, the sender avatar + name + short relative time ("Jessica 36m");
  - then the **reply bar**: a capsule with placeholder "Send message..." and quick reactions at its right. AS-8 shows 🔥 💖 and an add-emoji glyph (smiley with +). The 2022 recording shows 💬 😂 💛 🔥 and the add-emoji glyph; GP-7 shows 🔥 💛 and add;
  - bottom bar: grid (left), small shutter (centre), share (right).
- **Reply sheet** (2023, opened from the widget): ⌄ handle; photo with caption pill; "Reply to {name}" with avatar; a **2 × 5 emoji grid**; "Send message..." field.
  - Row 1: 💛 🫶 💕 😍 🤣
  - Row 2: 🥹 😋 🥰 😱 and an add-emoji button.
- **Full picker:**
  - 2022: a sheet with a "Search Emoji" field and the keyboard.
  - 2025: a sheet with a "Search" field and the sections "Frequently Used", "Popular" and "All". Any emoji can be used.
- **How reactions show on a photo** (Rollcall, AS-4 and 2025 video): a horizontal **cluster of overlapping emoji stickers** (each with a white outline) at the photo's bottom-left. There are **no numbers**. A smiley-plus button sits at the bottom-right.

### Motion: emoji rain (2022 build, History screen; TT-7147749171762908462, 29.97 fps, raw screen recording)
Method:
- Frames 4.0–10.0 s were extracted at the native rate.
- Each frame got a yellow mask (R > 215, G > 160, B < 110, R−B > 130).
- Connected components larger than 400 px were labelled, and each copy was tracked by x position.
- Frame k is at t = 4.0 + k/29.97 s.

Results:
- **One tap spawns 18 copies of the chosen emoji** (😵‍💫). 18 bottom entries and 18 top exits were counted, at x = 742, 910, 340, 40, 650, 780, 263, 800, 100, 50, 520, 620, 763, 345, 165, 645, 535, 825 px (of 1080). Entry positions are spread across the full width.
- **Spawn window:** first entry at k = 29 (t = 4.968 s), last entry at k = 93 (t = 7.103 s). That is 64 frames = 2.14 s, an average interval of 3.8 frames = **125 ms** between copies.
- **Each copy travels from the bottom edge up and off the top edge in ≈23 frames = 0.77 s (±2 frames).** Seven copies were checked: 23, 24, 24, 22, 23, 23, 23 frames.
- **Whole effect:** k = 29 → 117 (last copy leaves) = **88 frames = 2.94 s (±2 frames)**.
- **Direction is upward** (rising), although the App Store copy says "rain down". In the 2022 History screen the copies pass **behind** the photo card. In the 2023 reply sheet (OW, `…16.600s` frame) they are drawn **over** the photo, also rising.
- **Size:** each copy is ≈145 px wide in the 1080-px recording. With 1080 px = 390 pt that is **≈52 pt** (±3 pt; the recording is assumed uncropped horizontally).
- **Curve:** not measurable. Copies are partly hidden at the edges and behind the photo, so the centroids are biased.

### Motion: reaction fly-to-cluster (2025, Rollcall; TT-7460656081153445163, 29.97 fps, filmed)
- After the sheet closes, the emoji appears inside a translucent circular backdrop in the upper half of the photo. It grows slightly, then flies to the bottom-left cluster, shrinking. It lands at k ≈ 32 and the cluster has settled by k ≈ 34 (frame k at t = 15.6 + k/29.97 s).
- The start is hidden by a video cut at k = 24, so only **≥8 frames (≥0.27 s)** of flight are visible. **Duration not measurable**; curve not measurable.

### Measured values

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| 352 × 57 pt (712 × 115 px) | reply bar capsule | AS-8 | x 281→993 at y 2150; y 2093→2208 at x 640 | edge scan; screen 795 px = 393 pt | ±1.5 pt | SOURCED |
| 20 pt | reply bar side margins | AS-8 | screen 240 / 1035 | edge scan | ±1 pt | SOURCED |
| (57–62, 43–44, 32) over (31, 17, 7) | reply bar fill (translucent white) | AS-8 | column 640 | samples | — | SOURCED (alpha not solved) |
| (154, 144, 138) | "Send message..." placeholder | AS-8 | bbox x 315→592, y 2146→2175 | median of text pixels (anti-aliased) | ±10/255 | SOURCED |
| 22 pt | reply bar → shutter ring | AS-8 | 2208 → 2252 | scan | ±1 pt | SOURCED |
| **39 pt** (78–81 px) including the white outline | emoji in the reaction cluster | AS-4 | 🤩 at 2× zoom: x 78→240, y 82→238 | zoom read | ±2 pt | SOURCED |
| 27 pt (55 px) | cluster step (centre to centre); overlap ≈7 pt | AS-4 | centres 159 / 264 / 381 (2× zoom) | zoom read | ±2 pt | SOURCED |
| 2 pt, white | sticker outline around each emoji | AS-4 | ≈4 px | zoom read | ±1 pt | SOURCED |
| ≈17 pt / ≈20 pt | cluster inset from the photo's left / bottom | AS-4 | zoom read | — | ±3 pt | SOURCED |
| 18 copies; 125 ms apart; 0.77 s each; 2.94 s total; ≈52 pt; upward | emoji rain | TT-7147749171762908462 | see above | frame tracking | ±1 copy; ±2 frames | SOURCED |

### Copy (verbatim)
- App Store: "Send a Locket reaction to your friends to let them know you saw their image."
- App Store: "They’ll get a notification and you’ll love watching the emojis rain down on your photo."
- App Store: "We don’t count or track the reactions, so you can be real and authentic without worrying about likes and filters like other platforms." The Play wording is "We don’t count or track reactions publicly, so …".
- HC 14225418: "React to photos Send emoji reactions back to your friends to show appreciation for their photos. Locket doesn't have likes or like counts to reduce pressure and anxiety."
- APK strings:
  - "Send message..."
  - "Reply to {{name}}..."
  - "Reply to one of {{name}}’s Lockets to start chatting"
  - "No reactions yet"
  - "Activity"
  - "{{contactName}} reacted {{emoji}} to your Locket"
  - "{{contactName}} reacted {{emoji}} to {{name}}'s Locket"
  - "{{contactName}} reacted {{emoji}} to "{{message}}""
  - "You reacted {{emoji}} to {{name}}'s Locket"
  - "{{name}} sent {{emoji}}"
- Screens: "Reply to Kile" (2023 reply sheet); "Frequently Used", "Popular", "All", "Search" (2025 sheet); "Search Emoji" (2022).

### Do-not-copy
- APK "{{friendsCount}} friends sent {{emojis}}": a count of reactors.
- "Locket views / See who's opened your Lockets": a view list (Gold).
- Unread count badge on the chat button.
- The reaction *activity* list is fine only without counts.

### Not found
- Haptics (not observable).
- Emoji-rain motion on the current build.
- Exact emoji count/timing for the 2023+ reply sheet: filmed at an angle; the yellow mask was unreliable.

**Smallest capture:** one 8-second iPhone screen recording of tapping a quick reaction on a friend's photo in History (current build).

---

## 8. `onboarding.widget`: guided add-the-widget step

### Reference images
- `lazyweb/locket-lazyweb-20260821-cap-welcome.png` (welcome illustration: a phone with the widget in the yellow outline)
- `lazyweb/locket-lazyweb-20260821-cap-personalization-3.png`, `-setup-3.png`
- `references/owner/locket-add-widget-steps.jpg` (TT 2023, official TikTok overlay text)
- `frames/locket-tt-7532209311150329102-*` (2025 tutorial)
- `frames/locket-tt-7498394022428331295-04.600s-android-settings-widget-tutorial.jpg` ("Widget Tutorial" row in Android settings)
- HC 7914857 header image (gray widget tiles)

The in-app widget-tutorial screens themselves were **not seen as images**. Their copy comes from the Android app bundle; the illustrations are unknown, and proprietary illustrations must not be copied anyway.

### Step copy, verbatim

| string | context | source |
|---|---|---|
| "Add the widget\nto your home screen" | title | APK Hermes string table |
| "Finally, add the widget\nto your home screen" | title, last onboarding step | APK |
| "How to add the widget" | title | APK |
| "Hold down on an empty\nspace on your Home Screen" | step (Android) | APK |
| "Tap the “Widgets” button\nto add a new widget" | step (Android) | APK |
| "Search for Locket and\nadd the widget" | step | APK |
| "Have you enabled the widget?" | confirmation question | APK |
| "I've enabled the widget" | confirmation button | APK |
| "Locket doesn't work unless you add the widget to your home screen." | warning | APK |
| "Widget Setup" / "Widget Tutorial" / "Add Widget" / "Personalize your widget" / "Customize the widget" | screen and row titles | APK |
| "We’ll notify you once your\nfriends have set up theirs" | waiting copy | APK |
| "Once a friend accepts your friend request, you can add them to a widget." | per-friend widget info | APK |
| "1. Edit Home Screen" / "2. Click on + in left corner" / "3. Search Locket and Add Widget" | official TikTok overlay, iOS | `references/owner/locket-add-widget-steps.jpg`; TT-7282839171952102686 |
| iPhone: "From your Home Screen, touch and hold a widget or empty area until the apps jiggle." / "Tap Edit in the upper-left corner." / "Tap Add Widget." / "Search for "Locket", then tap on it." / "Select a widget size, then tap Add Widget." / "You're done!" | help steps | HC 7914857 |
| Android: "From your Home Screen, touch and hold on an empty space." / "Tap Widgets." / "Search for "Locket", tap on the widget, then tap Add." / "You're done!" | help steps | HC 7914857 |
| "Live pics from your friends, on your home screen" / "Set up my Locket" | welcome screen | LZ welcome; APK |
| "Add your friends" / "0 of 5 friends added" / "Continue" | the step before | LZ personalization-3 |
| "Finish setting up your Locket" / "Locket works best once you’ve added your best friends." / "OK" | alert | LZ setup-3 |

### Measured values

| value | element | file | method | level |
|---|---|---|---|---|
| 214 × 54 pt capsule, `#FFB800` | "Set up my Locket →" button | LZ welcome: x 282→923, y 2184→2345 | yellow bbox ÷3; median colour | SOURCED ±1 pt, ±2/255 |
| (184, 182, 178) ≈ `#B8B6B2`; line pitch 32 pt | welcome tagline | LZ welcome: y 1916→1975 and 2013→2071 | median of text pixels (anti-aliased) | SOURCED |
| `#0E0A07`→`#0B090B` | welcome background (warm near-black) | LZ welcome: (30, 300), (30, 2500) | samples | SOURCED |

### Not found
- The visual layout of the in-app widget tutorial screens.
- Their order on iOS.

**Smallest capture:** screenshots (or a 30-second recording) of Locket's in-app "Widget Tutorial" from Settings on an iPhone.

---

## 9. `notifications.push` (Locket parts: new post, reactions)

Verbatim client strings from APK 1.243.0 `resources.arsc` (SOURCED). On Android these are composed on the device.

| key | text |
|---|---|
| moment_notif_body_one_user_one_moment | "Sent you a Locket!" |
| moment_notif_body_two_users | "%1$s and %2$s sent you Lockets!" |
| moment_notif_body_three_users | "%1$s, %2$s, and %3$s sent you Lockets!" |
| moment_notif_body_many_users | "%1$s, %2$s, and %3$d other friends sent you Lockets!" |
| moment_notif_sender_fallback_name | "A friend" |
| notification_rollcall_post_title / _subtitle | "Shared their Rollcall!" / "Tap to see what they did this week." |
| notification_widget_refresh_title | "Updating widget..." |
| notification channels | "New Lockets": "Notifications when friends post new Lockets". "Groups": "Notifications for new messages and reactions in groups". "Reactions" (Rollcall): "Notifications when friends react to Rollcall posts". "Widget Updating": "Shown briefly while the home screen widget refreshes". "Upload Failures": "Notifications for failed photo/video uploads". "Daily Reminders": "Reminders to share a Locket with your friends" |
| daily_reminder_title_fallback / body (**do-not-copy**) | "Tap to update your Locket …" (the emoji did not decode) / "It's been #day# days since your last Locket" (guilt/nag) |

- **Reaction push:** the exact push text was **not observed**. The closest verbatim in-app strings are "{{contactName}} reacted {{emoji}} to your Locket" and "{{name}} sent {{emoji}}" (APK). The App Store text confirms that a notification is sent: "They’ll get a notification…".
- **The title of the single-sender push** (presumably the sender's name) is not observed.
- **iOS push texts:** not observed.

**Smallest capture:** one screenshot of an iOS notification banner for a new Locket and one for a reaction.

---

## 10. `paywall`: Locket Gold

### Reference images
- `mobbin/locket-mobbin-paywall-screen.png` (MB, 2025-10)
- `mobbin/locket-mobbin-gold-flow-0..7.png`
- `lazyweb/locket-lazyweb-20260803-cap-paywall-2.png`, `-cap-plan-picker.png`, `-autocap-25.png`, `-autocap-21.png`

### When Locket prompts (observed entry points)
- **Profile sheet:** a yellow-outlined row "Locket Gold / Unlock the best of Locket ›" (2026), or a pill "Get Locket Gold" (2025). After purchase the pill reads "View Locket Gold".
- **Locked features:** the profile rows "Change app icon (💛 Gold ›)" and "Camera theme (💛 Gold ›)" open the app-icon picker, and choosing an icon opens the paywall. This is Lazyweb's "Locked Feature Paywall", 5 steps.
- **Friend limit:** HC 7915024 says "there's a limit of 20 of your closest friends. You can add unlimited friends with Locket Gold!"
- **Prompt frequency:** not observed.

### Layout (MB, top to bottom)
- **Top:** a rounded-square tile with the gold heart icon (the app-icon art; do not copy). Below it the title "Locket Gold" and a two-line subtitle.
- **Middle:** a vertical stack of perk cards. Each card has an emoji icon at the left and two lines of text (title, then muted subtitle). An "Early access!" yellow capsule sits after the "Unlimited friends" title.
- **Below the cards** (after scrolling): a line "Plus so much more..." and centred chips: "🆕 Early product updates", "🎁 Monthly feature drops", "(medal emoji) Membership badge".
- **Bottom, fixed:** a full-width yellow capsule CTA "Upgrade your Locket 🔓" and a text button "No thanks!".
- **Background:** a vertical gradient from black to dark gold.
- **The CTA opens a sheet** "Subscribe to\nLocket Gold" with plan cards (the selected card has a yellow border) and a "Subscribe" button. It then shows a spinner, then the system "You’re all set / Your purchase was successful." alert. After that comes a sheet "Welcome to Gold!" / "You now have access to all Locket Gold features. We’re always adding more benefits, so check back soon." / "Done", with a **rain of 💛 hearts** over it (MB flow 5).

### Perks, verbatim

| title | subtitle | source |
|---|---|---|
| Remove ads | Never see an ad in History! | MB 2025-10, LZ 2026-08, APK |
| Video Lockets | Record short video clips! | MB 2025-10 (replaced in 2026 by the next row) |
| Longer videos | Record up to 10 seconds | LZ 2026-08; APK |
| Locket views | See who's opened your Lockets | MB, LZ, APK |
| Upload from camera roll | Share memories from your library | MB, LZ, APK |
| Unlimited friends + badge "Early access!" | Add as many friends as you’d like! | MB, LZ, APK |
| Widget frames | Personalize your widgets | MB flow 2 |
| Custom app icon | Decorate your Home Screen | MB flow 2; APK |
| Send longer captions | Type even more on your photos! | MB flow 2; APK |
| "Plus so much more..." chips | "Early product updates", "Monthly feature drops", "Membership badge" | MB flow 2; APK |

- **Help-center list** (HC 11057185): "Locket Gold is the ultimate Locket experience — with features that make it easier to personalize your Locket. Locket Gold includes features like..."
  - Custom app icons
  - Upload from Camera Roll
  - Unlimited Friends
  - Longer videos
  - Streak restoration
  - No Ads
  - Custom Gold Badge
  - Camera themes
  - Closing line: "We are constantly adding new features to Locket Gold as well, so you’ll always have fresh ways to enjoy your Locket experience!"

### Price display, verbatim
- **MB (2025-10):** a single plan card "Monthly" / "Cancel anytime!" / "$5.98/mo". The region is unknown. $5.98 is not in the US in-app purchase list.
- **LZ (2026-08):**
  - selected plan card: "1 Year" / "12 mo • $36 per year" / "$2.99/mo" (APK template: "12 mo • #yearlyprice# per year");
  - second plan card: "1 Month" / "$3.99/mo";
  - "Subscribe" button;
  - the system sheet shows "$36.00 per year".
- **US App Store in-app purchase list (store/listing.html):** Locket Gold at $3.99, $36.00, $3.99, $1.99, $2.99, $1.99, $16.00, $4.99, $3.99 and $36.00.

### Legal footer
- **No Locket-authored footer is visible** on the paywall or the plan sheet in either source.
- The APK contains "Subscription renews automatically. Cancel anytime." and "After your trial ends, you will be charged {{price}} {{perFrequency}} starting {{renewalDate}}. You can cancel any time before this date.". The second is in 20+ languages and may come from a bundled paywall SDK. The placement of either string is not observed.
- The only renewal text seen is Apple's system sheet: "Cancel anytime in Settings > Apple Account at least a day before each renewal date. Plan automatically renews until canceled." (PLATFORM).

### Measured values (MB, pt = px/3; screen 393 pt)

| value | element | px coords | method | precision | level |
|---|---|---|---|---|---|
| `#030101` (y 200) → `#0E0803` (700) → `#1E1404` (1500) → `#372805` (2200) → `#342406` (2500) | background gradient, at x = 20 | samples | single pixels | ±2/255 | SOURCED |
| 76 pt square | icon tile (app-icon art; **do not copy the art**) | x 477→705, y 249→477 | bbox | ±1 pt | SOURCED |
| cap 21 pt, so ≈30 pt bold; colour `#FDEAB8` | title "Locket Gold" | y 554→617; width 338→843 (169 pt) | bbox; median of glyph pixels | ±1 pt, ±3/255 | SOURCED |
| cap 11.7 pt, so ≈16–17 pt regular; line height 22 pt; colour ≈ (178, 170, 140) | subtitle | lines y 682→716 and 748→782 | bbox; median (anti-aliased) | ±1 pt | SOURCED |
| **353 × 78 pt**, gap **4 pt** | perk card | card 1 y 891→1124; gap 1125→1136; x 60→1120 | edge scan | ±0.5 pt | SOURCED |
| **≈23 pt** | perk card radius | top-left points (82, 909), (73, 921) | circle fit r = 68–71 px | ±1.5 pt | SOURCED |
| `#211B13` over bg `#150E06` (top cards); lighter further down | perk card fill (translucent white ≈5%) | (1000, 1000) vs (30, 1000) | samples | — | SOURCED (alpha approximated) |
| 30 pt; centre 59 pt from the screen edge | perk emoji icon | bbox x 133→221, y 964→1052 | bbox | ±1 pt | SOURCED |
| 73 pt from the card edge | perk text left inset | text x 280 | bbox | ±1 pt | SOURCED |
| cap 12.3 pt, so ≈17–18 pt semibold; `#F5F1EB` | perk title | y 956→992 | run length; median | ±1 pt | SOURCED |
| cap 10.3 pt, so ≈15 pt regular; ≈ (145, 138, 128) | perk subtitle | "N" y 1031→1061 | run length; median (anti-aliased) | ±1 pt | SOURCED |
| ≈91 × 16 pt capsule, `#FAB913`, dark text | "Early access!" badge | x 699→971, y 1942→1987 | yellow bbox; median | ±1 pt | SOURCED |
| **353 × 56 pt** capsule, side margins 20 pt | CTA | x 62→1119, y 2161→2327; corner reaches the edge at dy ≈ 80 px (= height/2) | yellow scan | ±0.5 pt | SOURCED |
| `#FEB900` | CTA fill | blocks (150–200, 2190–2200), (1000–1050, 2250–2260) | median | ±2/255 | SOURCED |
| cap 13 pt, so ≈18 pt bold; dark (`#2A1E05` darkest) | CTA label "Upgrade your Locket 🔓" | "U" y 2225→2263 | bbox | ±1 pt | SOURCED |
| cap 11 pt, so ≈16 pt; ≈ (186, 170, 130) | "No thanks!" | x 473→704, y 2396→2429 | bbox; median | ±1 pt | SOURCED |
| 370 × 81 pt, **3 pt `#FFB800` border** | selected plan card (LZ plan picker, 402-pt screen) | border y 1709→1717; card y 1709→1950; x 48→1157 | yellow runs | ±0.5 pt | SOURCED |
| 370 × 58 pt capsule | "Subscribe" button (LZ) | y 2298→2471, x 48→1157 | yellow runs | ±0.5 pt | SOURCED |

### Do-not-copy
- **Ads** ("Remove ads": the free tier shows ads in History).
- **Locket views** (who opened your photo).
- **Streak restoration**.
- Membership / "Custom Gold Badge": a status display shown to others.
- "Unlimited friends" vs a 20-friend cap. A cap is a product rule, not a design value.
- The icon art and the heart artwork.

### Not found
- The paywall prompt frequency/timing.
- A Locket-written legal footer.
- Android paywall visuals.

**Smallest capture:** a 20-second iPhone recording of opening Gold from the profile and scrolling to the bottom of the paywall (shows any footer).

---

## 11. Foundations: colour, type, pills, buttons (Locket surfaces)

### Brand yellow: `#FFB800`

| sample | where | evidence |
|---|---|---|
| `#FFB800` exact | Android badge inner fill, empty-widget ring | APK `drawable/bg_badge`, `drawable/bg_widget_empty_circle_outline` |
| `rgba(255, 184, 0, 1)` exact | JS colour literal (also at 0.3, 0.2, 0.1 and 0 alpha) | APK Hermes string table |
| `#FFB703` exact | Android theme `colorPrimary` | APK `color/colorPrimary` |
| `#FFB800` | welcome CTA | LZ welcome, median |
| `#FEB900` | paywall CTA | MB, median |
| `#FFB900` | shutter ring | AS-7 |
| `#FEB700` | widget badge | AS-3 |

All values fall within ±2/255 except `colorPrimary`. Lead 30 (`#F6B100`, measured on the 460-px webp) is superseded by these lossless or exact values.

### Other colours
- **Gold title cream:** `#FDEAB8` (MB).
- **Badge gradient border:** `#FFCD4E` → `#FFC52D` (APK).
- **Dark surfaces:** splash `#000000` (APK `splashscreen_background`); review background `#010002` (OW). Camera and history backgrounds are photo-tinted gradients, not constants (AS-7, AS-8; lead 30).
- **Overlays (APK):** `#CC333333` dark overlay, `#66333333` light overlay, `#4D000000` (black 30%), avatar border `#1A000000`.

### Type
- **Android bundles the font files** `ProximaSoft.otf`, `ProximaSoftMedium.otf`, `ProximaSoftSemibold.otf` and `ProximaSoftBold.otf` (APK `assets/fonts/`). Proxima Soft is a commercial typeface by Mark Simonson Studio. **It is proprietary: do not ship it. The token is PLATFORM (SF Pro / Roboto).** Do not copy the font files.
- The iOS font is not verified. The rounded letterforms in MB and LZ look similar to Android's, but this was not checked.
- Sizes measured above: caption 12, pill label 16, "History" 19–20, paywall title ≈30, perk title ≈17–18, perk subtitle ≈15, CTA ≈18, "No thanks!" ≈16 (pt, by cap height).

### Pills and buttons
- Controls are **capsules or circles**:
  - 44-pt circle and capsule controls on the camera top row;
  - 56–58-pt full-width yellow capsule CTAs with 16–20-pt margins (paywall, subscribe);
  - a 54-pt content-width capsule on the welcome screen;
  - 81–86-pt round central action (shutter, send).
- Translucent-white fills sit on dark backgrounds (camera pill, reply bar, perk cards).

### Voice pattern (copy)
Five features recur across the strings:

| feature | examples |
|---|---|
| Second person, warm, short | "Add your friends" / "Send pics to friends’ Home Screens" / "Live pics from your friends, on your home screen" |
| Exclamation marks on confirmations and benefits | "Sent you a Locket!" / "Welcome to Gold!" / "No thanks!" / "Never see an ad in History!" / "Add as many friends as you’d like!" / "This helps your friends find you on Locket!" |
| Three-period ellipsis in placeholders and progress text | "Send message..." / "Send to..." / "Reply to {{name}}..." / "Updating widget..." / "Plus so much more..." |
| Mostly sentence case | perk titles "Remove ads", "Upload from camera roll" |
| Title case for product and widget names | "Locket Widget", "Best Friend Widget", "Widget Tutorial", "Locket Gold" |

- "pics" is used colloquially.
- Emoji appear in marketing and help text (💛) and in the "Plus so much more..." chips, rarely in UI labels.
- The posted photo is called "a Locket". Our build must use our own noun; the trademark is not to be reused.
- **In ours:** "Locket" → `{app_name}` or the group's photo noun.

---

## 12. Do-not-copy summary
- Streaks: the 🔥N widget pill, "Streak on widget", "0d streak", streak restoration.
- Counts:
  - unseen-photo badge;
  - chat unread count;
  - "N friends sent {{emojis}}";
  - "0 Lockets";
  - "0 of 5 friends added";
  - "%3$d other friends";
  - "Locket views".
- Guilt and nag: "It's been #day# days since your last Locket", "Tap to update your Locket" daily reminders, "Locket doesn't work unless you add the widget to your home screen." (pressure; reword if used).
- Ads in History; Gold badge as status; celebrity Lockets.
- Locket's name, logo, heart icon, app-icon art, help-center drawings and Proxima Soft.

## 13. Gaps and the smallest owner capture for each

| gap | smallest capture |
|---|---|
| Medium, large and XL widget layouts (iOS) | 1 screenshot of the iOS widget gallery swiped through every Locket size, plus 1 Home Screen screenshot with a Locket medium and a Locket large widget placed |
| Lock-screen widgets (existence) | 1 screenshot of the Lock Screen "Add Widgets" sheet after searching "Locket" |
| iOS arrival animation (iOS 17+) | a 10-s screen recording of the Home Screen while a friend sends a photo |
| Current send-to row (avatars + "All"), caption entry, send-button size | a 15-s screen recording: capture → pick 2 friends → caption → send |
| Current emoji-rain timing and count | an 8-s screen recording of tapping a quick reaction in History |
| In-app widget tutorial screens | a 30-s recording of Settings → Widget Tutorial |
| Push banner texts (new Locket, reaction) on iOS | 2 notification-banner screenshots |
| Paywall bottom and any legal footer; prompt frequency | a 20-s recording of opening Gold and scrolling the paywall to the end |
| iOS font name | not capturable by screenshot. Would need Locket's iOS app bundle (not available) |

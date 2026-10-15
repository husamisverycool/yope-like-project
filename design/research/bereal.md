# BeReal — reference research (daily invitation surfaces)

Researched 2026-10-15. BeReal is the reference **only** for `daily.notification`, `daily.capture`,
`daily.dualimage`, `daily.liveactivity` / `daily.ongoing` (BeReal parts), the daily line of
`notifications.push`, and the BeReal half of `collage.view` (the dual-image layout).

Evidence files are in `references/auto/bereal/` (see its `INDEX.md`) and `references/owner/bereal-*`
(CAPTURED, same panels as the App Store PNGs). Coordinates below are in source-image pixels.

## 0. Sources and how they were used

| id | source | what it is | quality | date |
|---|---|---|---|---|
| **AP** | App Store App Preview video (HLS `P1262494525`, variant 886×1920, 30 fps) from https://apps.apple.com/us/app/id1459645446 | Official marketing video built from screen recordings. Frames used are at 1:1 screen scale (checked: the header wordmark is 161–162 px wide on every frame used). 886 px = 393 pt, so **2.2545 px/pt** (frame aspect 0.4615 matches a 393×852 pt screen) | H.264, lossy; parts are edited (zooms, dissolves) | poster image dated 2026-01-30; listing v4.96.1 |
| **TT** | https://www.tiktok.com/@bereal/video/7339559678604627233 (official verified @bereal) | Unedited screen recording of a real capture, 720×1556 HEVC, 30 fps. The frame equals a 1170×2532 (390 pt) screen scaled to 1556 px high (width 719.0 px), so **1.846 px/pt** | lossy; uncropped | posted 2024-02-25 |
| **H3** | help.bereal.com attachment 21083730354333 | Raw iPhone screenshot, 1179×2556, **3x**: pt = px / 3 | lossless PNG | ~2023-12 (article edited 2024-05-22) |
| **H2** | help.bereal.com attachment 21083708285725 | Post-preview screenshot at **2x** (786×1704 = 393×852 pt): pt = px / 2. A dim "long press" hint overlay covers the image and the controls | lossless (palette PNG) | 2023-12-05 |
| **HG** | help.bereal.com attachment 21083730407325, GIF frame 48 | 786×1048 crop of the same post image as H2 (not independent of H2) | lossless palette | 2023-12-05 |
| **HN** | help.bereal.com attachment 21089073691933 | Screenshot of the push notification | lossless | 2023-12 |
| **S2, S3, S7** | `references/auto/bereal/store/bereal-store-02/03/07.png` (1284×2778) | Marketing composites in a phone mock-up; the phone-screen width cannot be measured (bezel and screen are both black), so they are used for **ratios only** | lossless; composites | listing v4.96.1 |
| **FJ** | Taylor Annabell, "Bonus point for the smile!", *Flow* journal, 2023-02-10, http://www.flowjournal.org/2023/02/smile-directive-happiness-bereal/ | Academic essay listing the in-capture prompts verbatim | text | 2023-02 |
| help text | help.bereal.com articles via the Zendesk API (`/api/v2/help_center/en-us/articles/<id>.json`; the HTML pages are behind a Cloudflare challenge) | Verbatim copy | official | see dates per row |

Google Play (`com.bereal.ft`) screenshots were downloaded at full size (6 × 1284×2778). They are
pixel-identical to App Store PNGs 01, 02, 03, 04, 05 and 07 (mean abs. difference 0.0), so they are
not independent and were not saved again.

The handle `@bereal.app` given in the task does not exist on TikTok (user-detail statusCode 10221). The
verified official account is `@bereal` (815 videos, 2.0 M followers, checked 2026-10-15). Its video list
and TikTok search both need a login, so only videos linked from the public `#bereal` tag page could be
downloaded. Of 10 downloaded, only TT shows the app UI.

---

## 1. `daily.notification` — the daily push

### Reference images
- `help/help-21089073691933_time-to-bereal-push.png` (HN, official)
- `frames/appstore-preview-2026_t0.30s_notification.png` (AP, 2026)
- `references/owner/bereal-03-same-time-feed.webp` / `store/bereal-store-03.png` (friend-posted banner, see §5)

### Verbatim copy (two independent renders agree character for character)

| element | text | sources |
|---|---|---|
| iOS header line | `TIME SENSITIVE` | HN; AP #10. This is the iOS label for interruption level `.timeSensitive` (system text, PLATFORM) |
| title | `⚠️ Time to BeReal. ⚠️` (one space on each side of the text, period after "BeReal") | HN; AP #10 |
| body | `2 min left to capture a BeReal and see what your friends are up to!` | HN; AP #10 |
| time | `now` | HN; AP #10 (system) |

Spacing conflict: help-article *titles* write the name with no spaces, `⚠️Time to BeReal.⚠️`
(articles 7350386715165, 15416869159197, 15951201919517). The push itself (2 renders) has spaces.

Other official renderings of the same line:
- `⚠️Time to BeReal⚠️` (no period, in body text of article 15416869159197).
- `⚠️Time To BeReal⚠️` (capital "To", same article).
- Group variant: `⚠️It’s Time to BeReal.⚠️` (article 15753219937821 title). The settings toggle in its
  screenshot reads `It's time to BeReal.`
- Bonus blog: `UK Users, ⚠️ It's Time for Bonus BeReal! ⚠️` (https://bereal.com/en/?p=521, lead from
  dossier 03; not re-fetched).

### Timing rules (verbatim, official)
- "Every day, everyone in your time zone receives a notification at the same time (before you ask, we
  truly do not know when it’s sent). You have 2 minutes to open the app and take your BeReal."
  (https://help.bereal.com/hc/en-us/articles/7350386715165--Time-to-BeReal, edited 2024-01-16)
- "Everyone in your time zone (don’t worry, we won’t crash your beauty sleep in the middle of the night)
  receives the notification at the same time. We're clueless about the timing, so don't even bother
  asking." (article 15416869159197, edited 2024-01-08). This is official evidence that night hours are
  excluded. The exact allowed hours are not published.
- "There will ever only be one ⚠️Time To BeReal⚠️ notification." (same article)
- "Every day at a random time, everyone gets the same two-minute window to take and share a photo."
  (App Store description, listing v4.96.1, 2026)
- "Every day at a different time, everyone captures a photo within 2 minutes." (Google Play description,
  updated 2026-10-07)
- Changing time zone: "When changing your time zone, you won’t receive the notification for that day."
  and "You can change your time zone once every 24 hours." (article 7539711771549). Path: Profile → more
  option at top right → "Time Zone".
- Third-party leads, not official: the time zone setting offers four regions (Europe, Americas, West Asia,
  East Asia); a Kapwing sample saw US notifications between about 9:48 am and 9:12 pm Central
  (https://www.kapwing.com/resources/when-is-bereal-notification-time/ ;
  https://nerdschalk.com/how-to-change-your-time-zone-in-bereal-step-by-step-guide/).
- Tap behaviour: tapping opens the camera with the countdown already running (PetaPixel guide, lead from
  dossiers 03/11). Consistent with AP, where the countdown is already at 01:31 while the banner shows
  "now". Not re-observed in an unedited recording.

### Voice pattern (push and help copy)
- Second person, casual, short. Sentence case. A trailing period is kept even in the title ("Time to BeReal.").
- Numerals and abbreviations for time ("2 min left", "9m late", "27 h late").
- Exclamation marks for encouragement ("…what your friends are up to!", "Go, go, go!", "It happens!",
  "Fair’s fair!", "No worries! There’s always tomorrow.").
- Emoji are used as markers at the edges of a line (⚠️ … ⚠️, "Claire ✨"), never mid-sentence.
- Examples: "Go, go, go! It’s time to BeReal." · "Missed the two-minute window? It happens!" ·
  "One daily notification. Two minutes. Real friends, real moments." (App Store) · "Post on time or post
  late—it still counts." (App Store).

### Do-not-copy (tenet 5: invitations, never obligations)
- The ⚠️ hazard emoji framing in the title.
- The `TIME SENSITIVE` interruption level, which breaks through Focus modes.
- "2 min left …" deadline framing, and "Go, go, go!".
- "your friends will know you posted late" (help).
- The brand name used as a verb ("Time to BeReal"). It is a trademark: never copy it, not even adapted.

### Not found
- Android rendering of the daily push (title/body on Android, channel name, importance). Tried: Play
  listing (screenshots identical to iOS), help center (66 en-us articles fetched in full), web search.
- Notification sound: a TikTok "notification sound" clip exists (`@jk291816/video/7315676840620838145`).
  It was not used: it is not an official source, and sound is out of scope here.

---

## 2. `daily.capture` — capture screen with countdown

### Reference images
- 2026: `frames/appstore-preview-2026_t3.50s_capture.png` (AP #106)
- 2024: `frames/tiktok-bereal-7339559678604627233_t16.97s_capture-2024.png` (TT #510), plus the capture
  sequence frames (TT #518–#681)
- 2023: `help/help-21083708285725_bts-post-preview-2x.png` (H2, post preview with live countdown)
- `store/bereal-store-02.png` and owner `bereal-02-dualcam-preview.webp` (post preview, marketing)

### Layout (2026, AP #106; top to bottom; status bar hidden, background black)
1. **Dismiss chevron** (down chevron) at top-left: glyph bbox x56–87, y159–177 px. Centre is 31.7 pt from the left and 74.5 pt from the top.
2. **Title row**: the app wordmark, centred (y151–185 px). Our build replaces it; logos are never copied.
3. **Countdown** directly under the wordmark, centred (bbox x371–511 → centre x = 441 px vs screen centre 443). Format `MM:SS`, white, bold-looking digits.
4. **Viewfinder**: 3:4 rounded rectangle, nearly full width.
5. **Mode labels** `VIDEO` · `PHOTO`, with the selected one centred and drawn yellow. New in the 2026 build; absent in 2024.
6. **Control row**, all three vertically centred on the same line: flash-off glyph (left), shutter (centre), flip-camera glyph (right).

2024 build (TT): same order. The viewfinder is **full-bleed** (x 3–719 of 720 px), a `1.0x` zoom chip sits at the bottom centre inside the viewfinder, there are no mode labels, and the shutter is a **hollow white ring** (no inner disc).

### Measured values

2026 values come from AP #106 (`pt = px / 2.2545`). 2024 values come from TT (`pt = px / 1.846`). 2023 values come from H2 (`pt = px / 2`).

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| #000000 | screen background | AP #106; H2; H3 | (200–700, 20–120); (300–500, 20–60) | median of block | ±1/255 | SOURCED |
| 378.7 pt wide; side margins 6.9 / 7.4 pt | viewfinder (2026) | AP #106 | L 15.64, R 869.35 | subpixel max-gradient edge, median of 801 rows | ±0.5 pt | SOURCED |
| top at 124.4 pt, bottom at 631.0 pt, height 506.6 pt; aspect 0.7475 (3:4) | viewfinder (2026) | AP #106 | T 280.46, B 1422.50 | same method, 501 columns | ±0.5 pt | SOURCED |
| 16.0 pt | viewfinder corner radius (2026) | AP #106 | TL and TR corners | circle fit to the edge profile (r = 36.0 / 35.75 px, rms 0.34 px) | ±0.5 pt | SOURCED |
| full-bleed (393 pt / 390 pt) | viewfinder / preview width (2023–2024) | TT #510; H2 | x 3–719 of 720; x 0–785 of 786 | threshold edges | ±1 pt | SOURCED |
| 74.0 pt | shutter outer diameter (2026) | AP #106 | x 360.1–526.65; y 1503.5–1670.3 | threshold-128 crossings | ±0.5 pt | SOURCED |
| 4.0 pt | shutter ring stroke (2026) | AP #106 | 8.6–9.1 px | same | ±0.5 pt | SOURCED |
| 2.75 pt | gap between ring and disc (2026) | AP #106 | 6.1–6.25 px | same | ±0.5 pt | SOURCED |
| 60.5 pt | shutter inner disc diameter (2026) | AP #106 | 136.5 px | same | ±0.5 pt | SOURCED |
| centre 703.9 pt from top (148 pt above the bottom of an 852 pt screen); horizontally centred | shutter | AP #106 | (443.4, 1586.9) | midpoint of crossings | ±0.5 pt | SOURCED |
| 80 pt outer; stroke ≈ 6 pt (stroke/diameter 0.074); no inner disc | shutter (2024) | TT #510 | bbox 290–437 × 1192–1338 (148 px) | threshold bbox | ±1 pt | SOURCED |
| glyph 18.6 × 24.8 pt; centre x 59.2 pt from the left | flash-off glyph (2026) | AP #106 | bbox 113–154 × 1559–1614 | threshold-128 bbox | ±0.5 pt | SOURCED |
| glyph 26.6 × 22.2 pt; centre x 332.9 pt (60.1 pt from the right) | flip glyph (2026) | AP #106 | bbox 721–780 × 1562–1611 | threshold-128 bbox | ±0.5 pt | SOURCED |
| digit height 16.4 pt; "0" 10.6 pt wide; "01:28" 62.5 pt wide | countdown (2026) | AP #106 | bbox 371–511 × 208–244 | threshold-128 bbox (blur adds ≈ 1 px) | ±0.5 pt | SOURCED |
| digit height 16.5 pt; "0" 9.5 pt wide; stem 3.2–3.3 pt (stem / digit height 0.19–0.20) | countdown (2023) | H2 | "0": 333–351 × 206–238; "1" stem x370–375 at y222 | threshold bbox; stem from the row profile | ±0.5 pt | SOURCED |
| digits top 92.3 pt from the screen top; 10.2 pt below the wordmark; 16.2 pt above the viewfinder | countdown position (2026) | AP #106 | y 208 / 185 / 280 | difference / 2.2545 | ±0.5 pt | SOURCED |
| #FAFAFA | countdown text | H2 (and H3 for all other app text) | digits core; H3 "My Friends" (230–520, 300–370) | top-10 % luminance median; max = 250 while the iOS status bar in the same file is 255 | exact (lossless) | SOURCED |
| (253, 250, 254) and (255, 254, 255) | countdown text in video | AP #106; TT #510 | same bboxes | top-10 % median | ±5/255 (lossy) | SOURCED (consistent with #FAFAFA within compression) |
| ≈ #F0D63C | selected mode label "PHOTO" (2026) | AP #106 | 396–490 × 1450–1469 | median of the brightest 15 % | ±15/255 (4:2:0 chroma on 20 px text) | SOURCED, low confidence |
| ≈ #FDFAFC (white) | "VIDEO", shutter ring and disc | AP #106 | core pixels | top-10 % median | ±5/255 | SOURCED |
| cap height 9.1 pt (20–21 px); row centre 647.6 pt from top; "PHOTO" centred, "VIDEO" centre x 131 pt | mode labels | AP #106 | y 1450–1470 | bbox | ±0.5 pt | SOURCED |
| 12.2 pt gap viewfinder → labels; 14.9 pt gap labels → shutter | vertical rhythm | AP #106 | 1422.5→1450; 1470→1503.5 | difference | ±0.5 pt | SOURCED |
| 34 pt circle; 12 pt from the image's top and right edges; glyph 14 × 14 pt | retake ✕ button on the preview | H2 | circle x694–761, y288–355; glyph 714–741 × 308–335 | luminance profile | ±0.5 pt | SOURCED |
| diameter / main-image width 0.083 | retake ✕ (cross-check) | S2 | x≈1022–1106 at row 1162; main width 1014.1 | ratio | ±2 % | SOURCED |
| 34.7 pt arc spinner; prompt text block 31 px tall | spinner + prompt (2024) | TT #530 | spinner bbox 332–395 × 600–662; text 178–550 × 681–711 | threshold bbox / 1.846 | ±1 pt | SOURCED |

Fonts: no reliable source names BeReal's UI typeface (dossier 03 lists only conflicting fan claims:
Inter, "Texta Heavy", "Genera Grotesk"). Use **PLATFORM**. Converting the measured digit height (16.4–16.5 pt) with SF Pro's cap-height ratio of 0.705 gives about **23 pt** for a platform font. That is a derivation, not a BeReal value. Weight cannot be measured; the stem is 0.19–0.20 × digit height, so match it in side-by-side verification. Whether the digits are tabular cannot be determined.

Icons, matched to platform glyphs:

| BeReal glyph | iOS | Android |
|---|---|---|
| down chevron | `chevron.down` | `expand_more` |
| bolt with slash | `bolt.slash.fill` | `flash_off` |
| two circular arrows | `arrow.triangle.2.circlepath` | `sync` |
| ✕ in a dark circle | `xmark` | `close` |
| open-arc spinner | platform progress indicator | platform progress indicator |

### Countdown — format and window
- Format **`MM:SS`, zero-padded minutes**. Observed values: `01:31`, `01:30`, `01:29`, `01:28`, `01:27` (AP);
  `01:16` … `01:00`, `00:59` … `00:54` (TT); `01:4[2→3]` (H2).
- Window: 2 minutes (help articles 7350386715165 and 15416869159197; App Store and Play descriptions).
- The countdown keeps running during capture and on the post preview (TT: `00:59` on the black capture
  screen, `00:55` on the preview; H2 shows it ticking on the preview).
- The value at the moment the camera opens (`02:00`?) was never observed.

### Countdown motion (measured)
Two unedited ticks in TT (01:01→01:00 starting at #484; 01:00→00:59 starting at #514) and two ticks in AP (9→8; 8→7 starting at #116). All at 30 fps:

| value | what | evidence | precision |
|---|---|---|---|
| 1000 ms | tick period | TT tick starts #484 → #514 = 30 frames; AP new digit settles #95 → #125 = 30 frames | ±1 frame |
| ≈ 100 ms | old digit slides **up** and fades out (centroid 113.8 → 109.7 → 103.5 px, peak 255 → 224 → 185 → 139, gone at the 4th frame) | TT #484–#487; AP #116–#121 (same direction) | ±1 frame (33 ms) |
| 300–333 ms | new digit rises **from below** and reaches its rest position (first visible ≈ 3 pt below rest) | TT #487 → #493 (start +9 frames); TT #517 → #524/525 (+10–11); AP #116 → #125 (+9) | ±1 frame |
| 533–600 ms | new digit reaches full white (peak 153 → 170 → 186 → 198 → 226 → 235 → 244 → 254 → 255, about linear) | TT #493–#501 (+16–17 frames after the tick start); #524–#531 (+17–18) | ±1 frame |
| — | Only the digits that change roll. At a minute boundary (01:00 → 00:59) three digits roll together; the colon stays still | TT #513–#526 | — |
| — | Same direction in a lossless still: the old "4" is clipped at the top while the new "3" rises with a faded bottom | H2 | — |
| curve | duration only; the curve cannot be measured (3–9 samples per phase, sub-3-pt travel). The new-digit position samples flatten out near the end (120.7, 119.1, 117.8, 116.7, 115.9, 115.8 px) | TT | — |

No colour change of the countdown was seen anywhere between 01:31 and 00:54. **What happens near and at
00:00 is not documented** in any source found (see Not found).

### Dual capture sequence (TT, unedited, 30 fps; t = (frame − 1) / 30)

| phase | frames | time | observation |
|---|---|---|---|
| shutter press | #515–#518 | 17.133–17.233 s (133 ms) | the ring scales uniformly 1.000 → 0.986 → 0.966 → 0.939 → 0.912 |
| controls out | #519–#526 | 17.267–17.500 s | the ring keeps shrinking (0.872, 0.797, 0.709, 0.514, 0.345, 0.182, 0.081, 0); flash and flip glyphs are gone at #523; the viewfinder fades to black (mean 133 → 3 over #518–#526, about 267 ms). Press to shutter at 0: 11–12 frames ≈ 370–400 ms |
| between shots | #526–#540 | 17.500–17.967 s (500 ms) | black screen, a white arc spinner, and the prompt `Smile now, uh I mean now` centred under it; header and countdown still visible |
| back photo appears | #541–#546 | 18.000–18.167 s (≈ 200 ms) | the captured back photo fades in (mean 6 → 150) behind the spinner and prompt |
| second (front) capture | #546–#601 | 18.167–20.000 s (≈ 1.83 s) | the back photo stays on screen with spinner and prompt |
| preview | #602 | 20.033 s | the front photo appears as the top-left inset; retake ✕, chips `My friends only` and `Off`, and `SEND ➤` appear; the prompt changes to `Keep smiling and don't change a thing` (still on screen at the end of the video, 22.67 s, so it lasts ≥ 2.6 s) |
| **total** | #515 → #602 | **2.90 s** | press to preview, one device (a 390 pt iPhone), 2024 build |

Reading: the on-screen order (black, then the back photo while waiting, then the inset appears) is consistent with **sequential capture, back camera first, then front**. The App Store copy says "The camera snaps both the front and back simultaneously" (2026). Google Play says "designed to take both a selfie and a frontal photo simultaneously". Third-party guides report a short delay, with the rear first. Camera-hardware timing cannot be observed from a screen recording.

The 2026 AP covers this section with a linear editor dissolve: all pixels drop by 32 levels per frame over #121–#128. That is an edit, not app motion, so AP gives **no** capture-sequence data.

### On-screen prompts (verbatim)
- During capture, observed in-app: `Smile now, uh I mean now` (TT #526–#601).
- After capture, observed in-app: `Keep smiling and don't change a thing` (TT #600–#681).
- Listed by FJ (2023) as in-capture prompts: "Smile now, uh I mean now", "Say cheese!", "Wait, wait, wait, now smile".
  When no face is visible: "Who goes there?", "Umm, anybody here?", "Your friends will definitely prefer
  to see your face!". After capture: "Aye what a smiiile!", "Keep smiling and don't change a thing",
  "Bonus point for the smile!". FJ: "these phrases flash up for less than 3 seconds".
- The string **"Keep still…" was not found** in any BeReal source.
- Voice: playful interjections, sentence case, usually no final period; an exclamation mark is optional.

### Post-preview copy (verbatim)
- `SEND` with a right-pointing triangle glyph (`SEND ➤`): H2, TT #640, S2, and help article 15272815079453 ("Tap ‘SEND’").
- Audience chip: `My friends only` (TT 2024) / `My Friends` (H2 2023, S2 shows `My Friends` with a lock glyph).
- Location chip: `Off` (TT, H2, S2) with a slashed location arrow.
- Mode labels (2026): `VIDEO`, `PHOTO`.
- `Long press to see Behind The Scenes`, `BTS On` / `BTS Off` (H2). BTS is not one of our features; recorded only.

### Retake affordance
- ✕ in a dark circle at the top-right of the captured image (H2, TT #640, S2). Help: "You can retake your
  BeReal as many times as you want before posting. Just keep an eye on the timer."
- The ✕ circle is 34 pt and sits 12 pt in from the image's top and right edges (H2). It is not tinted: H2 is under a dim overlay, and S2 shows a dark translucent fill (luminance 42–45 over a bright photo).

### Sequential fallback
- No BeReal statement about devices without simultaneous capture was found. As observed, BeReal's own
  flow on iPhone is already sequential (above). Android behaviour: not found.
- Minimum devices: "For Android, your device needs to run Google Play Services Android 8 or more recent.
  For iOS, your device needs to run iOS 16 or newer." (article 7531346369053, edited 2026-10-07). The App Store listing says "Requires iOS 17.0 or later" (conflict).

### Do-not-copy
- Retake counts: the `2 retakes` chip on your own post detail (AP 16.5 s), and friends can see the count (trustedreviews lead in dossier 03).
- Smile directives ("Smile now…", "Your friends will definitely prefer to see your face!") conflict with "Real, not performed". Use the **layout** (spinner + one centred line) but not this copy.
- The deadline framing of the countdown ("Just keep an eye on the timer.").

### Not found
- Countdown behaviour near and at 00:00: colour change, "late" state, count-up. Tried: AP (only 01:31–01:27), TT (01:16–00:54), help center (66 articles), web search, Reddit (403 from this machine), TikTok search (needs login).
- What the capture screen shows when opened after the window. Tried the same sources.
- The countdown value when the camera first opens.
- Android capture screen (all screenshots found are iOS).
- Haptics and sounds: not observable, and out of scope by the brief.

---

## 3. `daily.dualimage` — front + back together

### Reference images (≥ 2 independent, high resolution)
1. **H3** `help/help-21083730354333_feed-bonus-3x.png`: raw 3x screenshot, lossless (feed, ~2023-12).
2. **H2 / HG** `help/help-21083708285725_bts-post-preview-2x.png` + `help/help-21083730407325_bts-gif-frame48.png`: 2x, lossless (post preview, 2023-12). Independent of H3.
3. **AP #205, #220** (2026 feed, lossy, 1:1 screen scale) and **AP #145** (2026 post-capture, mid-edit).
4. **S3** `store/bereal-store-03.png` and **S2** `store/bereal-store-02.png`: lossless marketing composites; ratios only.

### Layout
- Main image = back camera, 3:4 portrait, rounded corners.
- Inset = front camera, also 3:4, at the **top-left** corner. It has a solid **black** border and rounded corners. Its margin from the main image's top and left edges is the same on both axes.
- In 2023–2024 builds the main image is full-bleed (393 pt) on both the feed (H3) and the preview (H2). In the 2026 feed (AP) the image is inset from the screen edges (main width 368–374 pt across frames; an action column sits inside the image at the right). The inset keeps the **same proportions to the main image** across all versions (table).
- When switching cameras, the image from the other camera shows in the top left (mrhack.io / blinksandbuttons leads in dossier 03; not re-verified). The help center does not mention swapping or dragging.

### Measured values

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| 3:4 (786 × 1048 exactly) | main image aspect, preview | H2 / HG | main image y 264–1311, x 0–785 | threshold run lengths | exact | SOURCED |
| 0.750 (830.3 × 1107 px) | main image aspect, 2026 feed | AP #205 | x 32.3–862.6, y 354.6–1461 | edge medians | ±0.003 | SOURCED |
| 0.748 | viewfinder aspect, 2026 | AP #106 | see §2 | — | ±0.002 | SOURCED |
| 393 pt (full width) | main image width, 2023–24 feed | H3 | x 0–1178 at 3x | threshold | ±0.3 pt | SOURCED |
| 368.3 / 370.6 / 374.2 pt | main image width, 2026 feed (varies by frame) | AP #205 / #220 / #250 | 830.3 / 835.5 / 843.6 px | edge medians / 2.2545 | ±0.5 pt per frame | SOURCED (variation unexplained; possibly a horizontal pager) |
| **17.8 pt** / **17.9 pt** | main image corner radius | H3 TL, TR (53.5 px, rms 0.65); H2 TL, TR, BL, BR (35.25–36.0 px, rms 0.24–0.38) | corners | circle fit to the edge profile | ±0.5 pt | SOURCED |
| 14.9–16.4 pt | main image corner radius, 2026 | AP #205 TL / TR (33.5 / 37.0 px, rms 0.85) | — | circle fit on a lossy frame | ±1.5 pt | SOURCED, low confidence |
| **0.310** | inset outer width ÷ main width | H3 365.7/1179 = 0.3102; H2/HG 242/786 = 0.3079; AP #205 257.6/830.3 = 0.3102; AP #220 261.2/835.5 = 0.3126; S3 312.1/1008 = 0.310 | inset outer edges | subpixel edges (H3 rows 2100–2400, cols 150–300) | ±0.003 | SOURCED |
| 121.9 × 162.6 pt (3:4, 0.750) | inset outer size at 393 pt main width | H3 | x 34.72–400.46, y 1990.72–2478.40 | subpixel edges / 3 | ±0.3 pt | SOURCED |
| **11.7 pt** / **12.0 pt** (0.0299 / 0.0305 × main width; same on both axes) | inset margin from the main image's top and left | H3 (35.2 px both axes); HG (24 px both axes) | outer border edge minus main edge | difference / scale | ±0.3 pt | SOURCED |
| 0.0298 × main width (≈ 11.0 pt at 368 pt) | inset margin, 2026 | AP #205 (24.5 / 25.0 px) | — | — | ±0.5 pt | SOURCED |
| **2.0 pt** | inset border width | H3 6.0 px; HG 4 px; AP #205 4.1–4.4 px (1.9 pt); S3 5.0/1008 of width (= 2.0 pt at 393) | border rows and columns | inner − outer edge | ±0.2 pt | SOURCED |
| **#000000** | inset border colour | H3 (0, 0, 0) exact on rows 1992–1994 and columns 36–38; HG (0, 0, 2) | core of border | median and max of core | exact | SOURCED |
| **15.5 pt** (14.8–16.25) | inset outer corner radius | H3 (44.5, 47.25, 48.75, 48.75 px); HG (31.0, 29.75, 30.75, 31.0 px = 14.9–15.5 pt) | 4 corners each | circle fit, bright→dark outer edge | ±0.75 pt | SOURCED |
| ≈ 13.5 pt | inset inner (photo) corner radius | derived: outer − border | — | arithmetic | ±0.8 pt | SOURCED (derived) |
| 0.126 | inset outer radius ÷ inset outer width | H3 47.3/365.7 = 0.129; HG 30.6/242 = 0.126 | — | ratio | ±0.01 | SOURCED |
| ✕ 34 pt at 12 pt from the top and right | retake on the preview image | H2 | §2 | — | ±0.5 pt | SOURCED |

Marketing outliers, kept for the record:
- S2 (post-preview panel): inset 0.335 × main width; main aspect 0.770; inset radius 40–44.75 px.
- S3: main radius 0.054 × width versus 0.0455 on real screenshots.
- AP #250: inset 0.289, main aspect 0.757.
- AP #145: inset 0.316 with a 10.2 pt margin, mid-dissolve.
- AP #220: main aspect 0.64 (one post is taller; reason unknown).

None of these is used for values.

### Dual-image composition facts (BeReal half of `collage.view`)
1. **Two images, one frame.** The back photo is the full frame and the front photo is a picture-in-picture, both portrait **3:4**.
2. **Inset size:** outer width **0.31 × main width** (four sources agree, 0.308–0.313). The height follows from 3:4.
3. **Inset position:** **top-left**, with an equal margin on both axes of **0.030 × main width** (12 pt when the main image is 393 pt wide).
4. **Inset border:** solid **#000000**, **2 pt** (0.0051 × main width), drawn outside the photo.
5. **Corners:** main image **≈ 18 pt** (0.0455 × width). Inset outer **≈ 15.5 pt** (0.126 × inset width). Inset inner = outer − 2 pt.
6. **Scaling:** in the 2026 feed the whole composition shrinks with the main image (margin and inset keep their ratios), so specify the inset by ratios, not fixed points.
7. **Background around the composition:** #000000.
8. **Controls live inside the main image:** retake ✕ (34 pt, 12 pt from the top-right) on the preview; in the 2026 feed an action column sits at the right edge and a wordmark watermark at the bottom right. Do not copy the watermark.
9. **Tap-to-swap / drag-to-move:** **not found**. Do not specify them from BeReal.

### Do-not-copy
- Post-header labels: `5 min late` (S5, AP 10.5 s), `9m late` (`Paris, 1st Arr • 9m late`, AP #250), `27 h late` (AP #205).
- `2 retakes` chip (AP 16.5 s); RealMoji count `RealMojis 5`; comment counts (`💬 10`, `View 10 comments`).
- The BeReal wordmark watermark inside the image.

### Not found
- Tap-to-swap (main ↔ inset) and drag-to-move inset, in the feed and in the preview. Tried: help center (search
  "swap", "switch", "move" → no article; all 66 articles grepped), web search (only an unverified blog
  claiming a double-tap emphasis), AP and TT (no swap gesture shown).
- Inset snapping positions (which corners) and any motion for swap or drag.

---

## 4. `daily.liveactivity` / `daily.ongoing` (BeReal parts)

**Not found. No evidence that BeReal has a Live Activity, a Dynamic Island presence, a lock-screen countdown widget or an Android ongoing countdown notification.**

What was checked:
- App Store listing v4.96.1: the description and "What’s New" text (all recent notes are generic bug-fix copy) mention no Live Activity or widget.
- Google Play description (2026-10-07): the only widget is **"WIDGETMOJI • See your friends right on your Home Screen when they react to your BeReal with a widget."** That is a home-screen reaction widget, not a countdown.
- Help center (all 66 en-us articles): no widget or Live Activity article; searches for "widget", "live activity", "lock screen" return unrelated articles.
- Web searches ("BeReal Live Activity", "BeReal widget lock screen countdown", "dynamic island") returned nothing BeReal-specific.

AP's first 3 s show a large `01:31` countdown above the push on a lock-screen-like photo. Frames #86–#91 show this is a **marketing zoom of the in-app header timer** (it shrinks into the `01:29` header), so it is not a Live Activity.

The build should take these surfaces from Apple HIG (Live Activities) and Material 3 only. The BeReal parts that can carry over are the countdown format `MM:SS` and the roll motion from §2.

---

## 5. `notifications.push` — BeReal wording

| text | where | source |
|---|---|---|
| `⚠️ Time to BeReal. ⚠️` / `2 min left to capture a BeReal and see what your friends are up to!` | daily push (iOS, TIME SENSITIVE) | HN; AP #10 |
| `{name} ✨ and {count} others posted a BeReal`: name and "{count} others" in bold; observed "Claire ✨ and **24 others** posted a BeReal"; title line `BeReal.`; the sender's avatar is the large image with the app icon small at its bottom right | friends-posted banner (marketing) | S3 (owner `bereal-03`) |
| `It's time to BeReal.` (toggle) / `Get notified when it's time to BeReal in this conversation` | group daily notification setting | help image 36182541825309 |
| `Daily BeReal` / `Set up a daily reminder for everyone to post a BeReal together` | group setting | same |
| `Messages` / `Get notified for new messages` | group setting | same |
| "ONE ⚠️It’s Time to BeReal.⚠️ notification max per group per day!" | help | article 15753219937821 |
| "Your friends will not receive a notification when you add or remove a pinned BeReal." | help | article 12848519138461 |

Do-not-copy:
- The count in "and 24 others" (a count).
- "friends will be notified that you posted late" (Digital Trends lead).
- Any use of the brand as a verb.

---

## 6. Late-posting behaviour (all do-not-copy)
- "Missed the two-minute window? It happens! After receiving the notification, you can post a BeReal anytime, but your friends will know you posted late." (article 7350386715165)
- "Posted late? The option to post Bonus BeReal is locked. No worries! There’s always tomorrow." (article 10388190752669)
- Streaks: "To grow your Streak, post a BeReal each day after you receive the ⚠️Time to BeReal.⚠️ Notification." (article 15951201919517)
- Labels seen: `5 min late`, `9m late`, `27 h late` (formats differ between builds and screens), placed in grey under the username in the post header (AP #205, #250; S5).
- `2 retakes` chip on your own post (AP 16.5 s).
- App Store 2026: "Post on time or post late—it still counts." This is the only non-punitive line found.

---

## 7. Smallest owner captures that would close the gaps
1. **One 2–3 minute iPhone screen recording** that starts by tapping the daily push, lets the countdown run out (00:10 → 00:00 → past the window), takes a photo, then **taps the inset and drags it** on the preview, posts, and **taps and drags the inset on the feed post**. This settles: countdown end state and colour, start value, late state of the capture screen, tap-to-swap, drag/snap behaviour and their motion.
2. **One Android screenshot of the daily push** (shade expanded) plus a 20-second Android screen recording of a capture. This settles Android notification wording, any ongoing notification, and the capture sequence on Android.
3. Optional: one lock-screen screenshot during an active window, to confirm that no Live Activity exists.

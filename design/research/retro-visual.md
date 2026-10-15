# Retro — static visual system (measured from images)

Research pass: 2026-10-15. Anchor app: **Retro** (Lone Palm Labs; iOS `id6443709020`, Android `io.lonepalm.retro`).
Scope: every value that can be read from still images of Retro's real UI — colour (light and dark), type roles, spacing,
shape, iconography, materials, photo treatment, components — plus the screen inventory and the mapping of our surfaces.

Companion files (do not duplicate):
- `design/research/retro-package-copy-motion.md` — Android package (APK 2026.10.1150): exact colour constants, fonts and
  their licences, shape/spacing constants in code, motion, copy voice, widgets, web pages. **Where the APK gives a
  constant, this file cites it as a cross-check; where they disagree it says so.**
- `design/research/retro-timehop.md` — first pass on `week.history` (profile weeks) and Rewind. Values re-measured here
  supersede it where noted (§3.5 strip radius, §3.4 margin).

Path abbreviation **R** = `references/auto/retro/`. Every file has a row in `R/INDEX.md` (source URL, date, content).
Evidence level of every value in this file is **SOURCED** (Retro images we found) unless marked **PLATFORM** (the value is
the operating system's own component) or **BLOCKED** (not found).

---

## 0. How the numbers were obtained

### 0.1 Source hierarchy (used to resolve conflicts)
1. **RAW** — untouched device screenshots (status bar visible, exact @3x pixels). Highest weight.
2. **REAL** — photos or user screenshots of the live app (low resolution; ratios and colours only where flat).
3. **RENDER** — marketing renders built from app screens (App Store, Play, press kits, Apple editorial). Lossless and
   sharp, but layouts are sometimes older or retouched. Where a render disagrees with RAW/REAL, RAW/REAL wins and the
   render value is listed as the conflict.
4. **FRAME** — frames of screen-recording videos (other researcher; 640×800 or 1080×1920, lossy, colour-shifted).

### 0.2 Scale per image (px → pt)

| id | file (under R) | kind | px/pt | how the scale is known | ± |
|---|---|---|---|---|---|
| H43 | `lazyweb/retro-lazyweb-20251020-week43-dark.png` 1206×2622 | RAW iOS, dark, Oct 2025 | 3.000 | iPhone 16/17 Pro, 402×874 pt @3x | ±1 px = ±0.33 pt |
| H22 | `lazyweb/retro-lazyweb-20260528-week22-dark-a.png` (+ `-b`) 1206×2622 | RAW iOS, dark, May 2026 | 3.000 | same | ±0.33 pt |
| LAND | `lazyweb/retro-lazyweb-20251119-social.png` 1206×2622 | RAW iOS, dark, Nov 2025 | 3.000 | same | ±0.33 pt |
| PAY | `lazyweb/retro-lazyweb-20260529-paywall.png` 1206×2622 (Display P3) | RAW iOS, May 2026 | 3.000 | same | ±0.33 pt |
| RWA | `press/tc-2025-12-rewind-device-a.png` 1320×2868 (Display P3) | RAW iOS, Dec 2025 | 3.000 | 440×956 pt Pro Max | ±0.33 pt |
| RWB | `press/tc-2025-12-rewind-device-b.jpg` 1260×2736 | RAW iOS (JPEG), Dec 2025 | 3.000 | 420×912 pt | ±0.33 pt + JPEG |
| ST-01…05 | `store/retro-store-0N.png` 1284×2778 (+ `store/jp|kr|de/…`) | RENDER iOS, listing 124.0 | 2.389 | screen span x 171–1109 = 939 px ÷ 393 pt; tile 200 px ÷ 84 pt = 2.381 agrees | ±0.42 pt ±0.5 % |
| ED-A | `store/editorial/retro-appstore-story-1840659619-albums.png` 3524×3348 | RENDER (Apple editorial) | 3.89 | strip tile pitch 335 px ÷ 86 pt; screen 1526 px ÷ 393 pt = 3.88 | ±0.26 pt ±1 % |
| ED-W3 | `store/editorial/retro-appstore-story-1854931006-week3-albums.png` 3524×3348 | RENDER (Apple editorial) | 3.89 | same method (left screen x 188–1713, right 1809–3333) | ±0.26 pt ±1 % |
| TC-1B | `press/tc-2023-07-retro-1b.webp` 3510×2163 | RENDER press 2023 (WebP) | 2.204 | phone 2 screen x 1323–2188 = 866 px ÷ 393 pt | ±0.45 pt ±2.5 % |
| TC-2B | `press/tc-2023-07-retro-2b.jpg` 3510×2160 | RENDER press 2023 (JPEG) | 2.298 (phone 2) / 2.204 (phone 1) | screen width ÷ 393 pt | ±2.5 % |
| TC-R3, TC-REC, TC-J1, TC-J5, TC-RWP | `press/tc-2023-12-retro3.png`, `press/tc-2023-12-recaps.png`, `press/tc-2024-04-journals-1.webp`, `press/tc-2024-04-retro-journals-5.png`, `press/tc-2025-12-rewind-panels.png` | RENDER press | 1.70–2.07 | screen width ÷ 393 pt | ±3 % |
| JED | `press/jeddacp-2024-05-home-profile-journals.png` 1350×852 | REAL user screenshots in mock frames, 2024 | ≈0.93 | ratios only (frame may crop the screen edge) | ±5 % |
| ENG-* | `press/engadget-2026-08-*.jpg` | REAL photos of the live app, Aug 2026 | — | layout only | — |
| PLAY-01…06 | `play/retro-play-0N.png` (+ `play/ja/`) 1563×2778 | RENDER Android | ratios (screen x 297–1262 = 966 px) | — | — |
| WEB-PLUS | `web/retro.app-plus.png` 736×981 | lossless web asset of the add tile | ratios | — | — |
| VID-SET, VID-COMP | `video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png`, `video/ig-DDbA_F7x-j7-composer-f130-147-f188-197.png` | FRAME (other researcher) | ≈0.45 | layout only; colours shifted toward magenta | — |

### 0.3 Methods
- **Flat colour:** median of a box (box given as x0–x1, y0–y1 px); the standard deviation was 0 on every RAW flat area
  quoted. **Text/glyph colour:** median of the darkest (light mode) or brightest (dark mode) 8–20 % of pixels in the
  glyph box; thin text reads lighter than its true colour, so text colours are ±4/255 unless a 2 pt stem was available.
- **Type size:** cap height (flat-topped capitals or digits; O/G/S lose ~1 px of overshoot) and x-height measured in px,
  divided by px/pt, then divided by SF Pro's cap-height ratio 0.705 and x-height ratio 0.517 (the same ratios as
  `retro-timehop.md`). Both estimates are given when they differ. Serif display sizes are given as **cap height in pt**,
  because the font's em ratio belongs to Roslindale (APK: Android sets it at 40 sp / 48 sp line, W400 — other file §2.3).
- **Corner radius:** per-row edge inset profile of the corner (sub-pixel coverage), fitted against (a) a circular arc and
  (b) a continuous ("squircle") corner rendered with the figma-squircle construction (smoothing s = 0.6–0.75, the range
  that approximates iOS `.continuous`). The model with the lower residual is named.
- **Colour management.** PAY and RWA carry a Display P3 profile; their chromatic colours are converted to sRGB here.
  Neutral greys are identical in both spaces. The Lazyweb dark captures and store renders read **#EA3337** for Retro's
  red, which equals the APK constant `0xFFEA3337` (sRGB) — so their values are sRGB-correct. The two Apple editorial
  images (ED-A, ED-W3) read the same red as **#FF002A**, which is exactly sRGB #EA3337 mis-assigned as Display P3 and
  converted back: **do not sample chromatic colours from ED-A / ED-W3** (geometry only). Neutral greys there also carry a
  slight vignette (#EDEDED–#F2F2F2 for a #F1F1F1 fill).

### 0.4 Version drift seen in the images (important when reading renders)
| item | 2023 (TC press) | 2024 (JED, TC-J1, PH) | 2025 (ED-A, H43) | 2026 (H22, store 124.0, ENG) |
|---|---|---|---|---|
| tabs | Home · Friends · Activity · Profile (4) | Home · Friends · **Journals (book)** · Activity · Profile | same 5, book = "Albums" | Home · Friends · **Rewind (clock)** · Activity · Profile; book glyph moved to the home header beside chat |
| home header glyphs | calendar (+ envelope in TC 2023 photo) | calendar | chat only (H43) or book + chat (ED) | **book + chat** (H22, ST-01, ENG-D) |
| add tile | first, before empty days | after photos | first when the week is empty (H43) | after photos (ST-01), first when empty (H22) |
| weekday labels | "Tues", "Thurs" | "Mon", "Tue" | "Mon", "Tue" | "Mon", "Tue" |
| shared collections | — | "Journals" | "Albums" | "Albums" (web still says journal) |

---

## 1. Sources collected in this pass

Already present before this pass (indexed earlier): US App Store set (6), Play set (5), TechCrunch 2023-07 (2),
2023-12 (1), 2024-04 (1), 2025-12 (3), Engadget 2026-08 (2), jedda 2024 (1), three Lazyweb dark captures, retro.app CSS.

Added in this pass (44 files, ~160 MB, all indexed in `R/INDEX.md` § "Static visual pass"):

| source | files | what is new |
|---|---|---|
| Lazyweb public company page (`lazyweb.com/company/retro`, `/flow/retro/locked-feature-paywall`, `retro.md`) | `lazyweb/retro-lazyweb-20260529-paywall.png`, `lazyweb/retro-lazyweb-20251119-social.png` | The public page shows **5 of 66** screens; all 5 are now saved (2 new: RAW paywall, RAW dark sign-up landing). The other 61 require a Lazyweb account — not created (gap §6). experiments.lazyweb.com shows the same 5. Lazyweb's agent API answers questions about Lazyweb only. |
| App Store storefronts us, gb, au, ca, jp, de, fr, br, mx, es, it, nl, kr, in, se, nz, ie, sg (+ `?platform=ipad`) | `store/jp/*` (6), `store/kr/*` (6), `store/de/*` (6) | 8 localised sets exist (EN, JP, KR, GE, FR, BR, LATAM, IT) — **same 5 screens** re-rendered with localised UI text; JP/KR/DE kept as script/length evidence. **No iPad set** (iTunes lookup `ipadScreenshotUrls: []`). No App Preview video on the listing. |
| App Store editorial stories id1840659619, id1854931006, id1888002859 | `store/editorial/*` (5) | Two high-res light composites (Home + **Albums list**, root and pushed with search); story art; preview poster of an editorial video (HLS URL in INDEX, for the motion researcher). |
| Google Play (en, ja; de/ko/fr/pt_BR compared) | `play/retro-play-06.png`, `play/ja/*` (6) | 6th EN screenshot (end card) and the JA Android set. |
| TechCrunch 2023-07, 2023-12, 2024-04, 2024-07, 2025-12, 2026-08 | `press/tc-2023-07-retro.jpg`, `press/tc-2023-12-retro-header.png`, `press/tc-2023-12-retro3.png`, `press/tc-2024-04-retro-journals-5.png` | Story-viewer header + "New! Photo Postcards" sheet, dark Postcard modal (2023), "Add a Message" modal, recap collage card, journal share flow. 2024-07 and 2026-08 reuse earlier images (2026-08 `rewind.jpeg` is pixel-identical to RWB). |
| Engadget 2026-08 gallery | `press/engadget-2026-08-l-intro-…jpg`, `press/engadget-2026-08-the-problem-with-friends-only-socials-…jpg` | Live **Messages inbox** (light, low-res); app icon on device (brand only). |
| Apptisan #013 (2024-05-17) | `press/apptisan-2024-05-collage.png` | Profile "nathan" with Recaps / Settings / ••• pills (2024). |
| Product Hunt (`products/retro-3`) | `producthunt/*` (3) | Two 4K Journals-list renders, one real Journals list frame. |
| retro.app assets | `web/retro.app-plus.png`, `web/retro.app-postcardTest.png` | **Lossless add-tile asset** (#F1F1F1 + "+"), postcard back art. |

Tried and not usable: Fast Company 2025-12 Co.Design article (DataDome captcha; WebFetch 403; Firecrawl out of credits;
its lead image `p-1-91462432-…jpg` is a stock hand-and-phone photo, not Retro UI); Mintz 2026-10-08 (text only, no
images); Wayback Machine (connection reset — older store sets unreachable); Mobbin / Screenlane / Screensdesign (no
Retro pages); AlternativeTo, Bitrise (no screenshots); Threads @retrodotapp (no UI images in the public view); Reddit
(nothing found); Product Hunt launch pages (gallery is the same 3 images).

---

## 2. Screen inventory

Counts: **41 distinct screens/states** — 26 light, 15 dark; 36 iOS, 5 Android (Android only as marketing renders);
6 of them RAW device captures (all iOS: 4 dark, 2 photo-backed/colour-backed). "best" = the file to measure from.

| # | screen / state | light — best file | dark — best file | platform · kind | notes |
|---|---|---|---|---|---|
| 1 | Home, current week **empty** ("Welcome to Week N!" + outline CTA) | — | H43 (2025, book tab), H22 a/b (2026, Rewind tab) | iOS RAW | add tile first, empty-day tiles, calendar glyph, 4 pt red tab dots |
| 2 | Home, populated (title, strip, friend cards, "N new") | ST-01; ED-A; ED-W3; PLAY-01 | ENG-D (photo, low-res) | iOS/Android RENDER; REAL | "Last Week" pill on Mon/Tue (JED, ENG-D); "Seen" pill (ENG-D, TC 2023 photo) |
| 3 | Home 2023 with empty days + locked friend cards ("Post to see") | TC-2B phone 1 | — | RENDER | do-not-copy lock |
| 4 | Profile (own): serif username, info rows, Recaps / Share Profile / gear, week sections | ST-02; `store/jp|kr|de/*-journals.png`; PLAY-02 | — | iOS/Android RENDER | 2023 variant: Edit Profile / Settings / ••• (TC-1B phone 3); 2024: Recaps / Settings / ••• (JED, Apptisan) |
| 5 | Profile, current week with empty days + "Getting Started" card | JED phone 2; ENG-P | — | REAL | progress ring = count (do not copy) |
| 6 | Profile below 4 weeks: "Key holders only" gate | TC-2B phone 3; VID (retrospective contact sheet) | — | RENDER/FRAME | behaviour do-not-copy; layout = empty-state block |
| 7 | Week section "•••" menu | — | — | — | **not found** |
| 8 | Friends tab: serif title, Invite/Keys, search, 3-col avatar grid with key badges, page dots | TC-1B phone 2 | — | RENDER 2023 | current version not captured |
| 9 | Friend requests list (Accept / Decide Later, unread dot) | TC-1B phone 2 (lower half) | — | RENDER 2023 | "Expires in…" urgency = do-not-copy |
| 10 | Albums / Journals list (root tab) | ED-A right; TC-J1 middle; PH hero | — | RENDER | rows: 3:4 thumb, title, "x shared N posts", avatar stack, + circle |
| 11 | Albums list pushed (back chevron + 52 pt search field) | ED-W3 right | — | RENDER | |
| 12 | Journals list with "Ideas to Get Started" templates (Event / Friends / Couple + "Create" pills) | JED phone 3 | — | REAL 2024 | maps to our group types |
| 13 | Album / journal detail (cover, serif title, members · photos, Settings / Share / + , dated grid) | TC-J1 right; PH hero (partial) | — | RENDER | web version `/j/` in other file |
| 14 | Album share flow: "Turn on link sharing" → menu (Reset link / Make journal private) + share targets → IG story sticker | TC-J5 (3 phones) | — | RENDER | |
| 15 | Story / media viewer (header avatar ring, "3 of 4", close, location/date footer, comment row, comment field) | — | TC-2B phone 2; TC-R3 phone 1 header | RENDER 2023 | heart like = do-not-copy |
| 16 | "New! Photo Postcards" bottom sheet over viewer | TC-R3 phone 1 (light sheet) | (dark backdrop) | RENDER | feature-intro sheet pattern |
| 17 | Postcard composer modal | — | ST-03; PLAY-03; TC-R3 phone 2 (2023, disabled grey CTA) | RENDER | |
| 18 | "Add a Message" text modal (counter 58/250, stamp, keyboard) | TC-R3 phone 3 | — | RENDER | |
| 19 | Create Recap (segmented Yearly/Monthly/Weekly/All Posts, month cards) | — | TC-REC phone 1 | RENDER | segmented control = native |
| 20 | Recap preview: collage card on blurred backdrop, page dots, Share pill | — | TC-REC phones 2–3; ST-04 (polaroid); PLAY-04 | RENDER | |
| 21 | Yearly recap collage card ("2023 / nathan / retro.app") | TC-H (`press/tc-2023-12-retro-header.png`) | — | RENDER | share-card pattern |
| 22 | Rewind (date + chevron, dial, share/dice) | — | RWA (May 1, 2019 ⌄), RWB (Jul 22, 2022); ST-05; PLAY-05 | iOS RAW | photo-backed, tab bar over scrim |
| 23 | Rewind playing ("On this week" subtitle, pause) | — | TC-RWP phone 1; ST-05 | RENDER | |
| 24 | Rewind "•••" context menu (Share to my week / Add to Album / Hide photo / Delete from Photos) | — | TC-RWP phone 2 | RENDER | native UIMenu (PLATFORM) |
| 25 | Rewind share sheet ("Tuesday, December 2 / Memory") | (system sheet is light) | TC-RWP phone 3 | RENDER | native share sheet (PLATFORM) |
| 26 | Sign-up landing ("Friends Only", Get started, already have an account?, legal) | — | LAND | iOS RAW | |
| 27 | Paywall "Retro Premium" — locked feature (Share Video) with referral plan card | colour-backed, light card | PAY | iOS RAW | purple accent is premium-only |
| 28 | Settings sheet (profile card, Subscription, Notifications, Widgets carousel) | VID-SET frames 42–44 | — | iOS FRAME | grouped rows |
| 29 | "Your Referrals" sheet (member ring, count-up) | VID-SET frames 45–59 | — | iOS FRAME | count = do-not-copy |
| 30 | Composer "Add to Your Week" (Cancel / Update, selected strip, Camera Roll ⌄, photo grid) | VID-COMP | — | iOS FRAME | posting flow |
| 31 | Messages inbox (serif "Messages" + back, search, rows) | ENG-M | — | REAL (low-res) | thread not captured |
| 32 | Journal-share Instagram story sticker | TC-J5 phone 3 | — | RENDER | |
| 33 | Localised home / profile / postcard / recap / Rewind (JP, KR, DE iOS; JA Android) | `store/jp|kr|de/*`, `play/ja/*` | (postcard/recap/Rewind are dark) | RENDER | |
| 34 | Home-screen widgets (preview art) | `apk/widget_preview_*.webp` (other file) | — | APK | |
| 35 | Web invite / album pages | other file §7 | — | web | |
| 36–41 | Activity / notifications tab, toasts, sign-up form (phone / code / username), onboarding pages, permission pre-prompts, iPad, Android raw | — | — | — | **not found** (§6) |

---

## 3. Foundations

### 3.1 Colour — light

| role | value | evidence (file, px box) | method | ± | level · cross-check |
|---|---|---|---|---|---|
| Page background | **#FFFFFF** | ST-02 (600–606, 1700–1706); JED (150–250, 290–300); ED-A row y=1600 x 188–241 | box median, σ 0 | 0 | SOURCED · APK background #FFFFFF |
| Tile fill: add tile, empty-day tile, strip placeholder | **#F1F1F1** | ST-01 (850–1030, 870–1130) grid of 104 samples all #F1F1F1; ST-02 (860–866, 1360–1366); TC-2B (390, 420); PLAY-01 (1000–1050, 950–1000) | box median | ±1 | SOURCED · APK `d42.o` #F1F1F1; WEB-PLUS lossless #F1F1F1; JED reads #EDEDED (recompression, −4 on every grey) |
| Search field fill | **#F1F1F1** | TC-1B (1700–1750, 430–450); ED-W3 (2400–2500, 640–680) | box median | ±2 | SOURCED |
| "+" circle button fill, "Create" pill fill | **#F1F1F1** | ED-W3 (3138–3179, 1027) run #F4F4F4 with vignette; JED (1216–1218, 480–488) #EDEDED | runs | ±4 | SOURCED (vignette/recompression) |
| Grouped list rows (Settings sheet) | ≈ #F2F2F2 (frame reads #F3F0F4) | VID-SET frame 42 (100–130, 175–180) | box median on a magenta-shifted video frame | ±6 | SOURCED (FRAME) · APK secondary surface `vv3.l` **#F7F7F7** (Android) — **conflict**: iOS still images only ever show #F1F1F1 for fills; the row value needs a raw capture (§6) |
| Text primary | **#000000** | ST-02 info row "Weeks Posted" darkest px (255–520, 905–945) | darkest pixel | 0 | SOURCED · APK `vv3.m` #000000 |
| Text secondary (date range, real name, list subtitles) | **#999999** | ST-02 range "Jul 3 - 9" (367–490, 1288–1314) = #999999 (`retro-timehop.md`); ST-02 "Isabel Reyes" darkest px #999999; ED-W3 "daniel shared 2 posts" #959595 | darkest px / darkest 10 % | ±4 | SOURCED · APK `vv3.e` #999999; APK `vv3.o` black @ 50 % (#808080 on white) is used on Android for meta lines |
| Text tertiary (placeholder, timestamp) | #B0B0B0 – #B4B4B4 | TC-1B search placeholder (1430–1560, 415–465) #B0B0B0; "1d" (2060–2110, 1268–1298) #B4B4B4 | darkest 10–15 % | ±6 (WebP) | SOURCED · APK tertiary `vv3.p` #C1C1C1. ED-W3's 2025 search placeholder reads #979797 (≈ secondary) |
| Empty-day tile text (month / day / weekday) | ≈ **#D9D9D9** | TC-2B tile x 378–564, y 402–650 (221/216/218); JED (530–560, 380–400) #D5D5D5 | darkest 10 % | ±6 | SOURCED (JPEG) |
| Tab icon selected | **#000000** | ST-01 home glyph (271–319, 2462–2513) | darkest px | 0 | SOURCED |
| Tab icon unselected | **#B2B2B2** (= black @ 30 % on white) | ST-01 four glyphs, darkest px all #B2B2B2 | darkest px | ±2 | SOURCED |
| Accent red — "N new" badge, unread dot, destructive | **#EA3337** | ST-01 badge row y=1480 x 640–664 and 680–684 #EA3337; H43 tab dot (361, 2501) #EA3337; TC-1B dot #E13A41 (WebP), TC-2B heart #E83437 (JPEG) | runs / centre px | ±2 | SOURCED · APK `error` / `vv3.g` #EA3337 |
| Black capsule button fill / label | #000000 / #FFFFFF | TC-1B Accept col x=1550 y 1403–1481 #000000; PAY Claim (200–300, 2300–2340) #000000 | box median | 0 | SOURCED |
| Outline capsule border / fill / label | #000000 1 pt / #FFFFFF / #000000 | ST-02 Recaps col x=250: y 1129–1131 and 1215–1217 (#101010/#0C0C0C cores) | runs | ±0.4 pt | SOURCED |
| "Last Week" pill fill / label | **#999999** / white | JED (302–304, 118–126) #999999, label brightest #EEEEEE | box / brightest 10 % | ±4 | SOURCED (REAL, small) |
| Page dots selected / unselected | #000000 / ≈#D9D9D9–#E4E4E4 | TC-1B row y=1116 x 1696–1706 / 1749–1760, 1777–1788 | runs | ±8 (WebP) | SOURCED |
| Hairline divider | ≈ #E3E3E3 – #EFEFEF (1 device px) | TC-1B col x=1700 y 1158–1159; JED col x=700 y 292–293 | runs (anti-aliased 1-px line reads lighter than its colour) | ±8 | SOURCED · APK separator `vv3.h` #CCCCCC |
| System tint (nav text buttons "Cancel", "Update") | system blue | VID-COMP frames 188–197 (anti-aliased #72B1D1) | saturated px median | — | PLATFORM · APK primary #0A84FF |
| Premium purple pill ("FREE") | P3 #A239BB → **sRGB #B02EC1**; vertical gradient top sRGB #D543DE → bottom #A327B8, purple drop shadow | PAY (945–955, 1480–1495); col x=960 y 1450–1525 | box median, ICC-converted | ±3 | SOURCED — paywall only |
| Paywall plan card (material over colour) | translucent white, reads sRGB #EEF4FA–#EFF6FC over a blue backdrop | PAY (900–1000, 1700–1760), (900–1000, 2050–2100) | box median | — | SOURCED (alpha not derivable) |
| Text on paywall card: primary / secondary / tertiary | #090A0A / #757A7D / #A5ABAF (sRGB) | PAY "1 Year Free" (140–500, 1460–1520); "Thanks for…" (140–780, 1550–1590); price (140–800, 2100–2150) | darkest 12–20 % | ±4 | SOURCED |

### 3.2 Colour — dark

| role | value | evidence (file, px box) | method | ± | level · cross-check |
|---|---|---|---|---|---|
| Page background (iOS) | **#000000** | H43 (100–300, 1400–1450), (600–700, 2500–2600) σ 0; H22; LAND (100–300, 1500–1700); ST-03 (250–300, 1950–2000) | box median | 0 | SOURCED (RAW) · APK Android default dark #1C1C1E, "true black" option #000000 — **iOS shows true black in every capture** |
| Tile fill (add tile, empty-day tile) | **#262626** | H43 strip row y=470 x 91–299, 306–557…; col x=170 y 468–601 | runs σ 0 | 0 | SOURCED (RAW) · APK secondary surface `vv3.f` #262626 |
| Secondary fill: pills, circle buttons, fields | **#262626** | ST-03 close (990–995, 770–780), "Add a message" pill col x=520 y 1743–1773, edit circle (975–980, 2030–2035); TC-2B "3 of 4" pill (1990–1995, 320–330), comment field (1700–1720, 1880–1890); ST-04 recap close run x 989–1052 | box median | 0 | SOURCED |
| Empty-day tile text | **#515151** | H43 month/day/weekday glyph maxima (306–557, 530–740) all #515151 | brightest pixel | 0 | SOURCED (RAW) |
| Text primary | #FFFFFF | H43 title (40–300, 280–380) brightest 30 % | | 0 | SOURCED |
| Text secondary | **#999999** | LAND "Friends Only" (360–840, 1230–1310), "already have an account?" (330–870, 2260–2320), legal (110–1090, 2385–2435): all #999999; ST-03 "Mailing Address", price: #999999; TC-2B "Week 28" #959595, date #929292 | brightest 8–15 % | ±4 | SOURCED (RAW) · APK dark secondary white @ 60 % = #999999 on black |
| Placeholder in field | #8B8B8B | TC-2B "Add a comment…" (1470–1690, 1860–1900) | brightest 10 % | ±6 (JPEG) | SOURCED |
| Tab icon selected | **#FFFFFF** | H43 / H22 home glyph (89–148, 2416–2480) | brightest 8 % | 0 | SOURCED (RAW) |
| Tab icon unselected | **#999999** (= white @ 60 % on black) | H43 runs y=2440 x 361–366, 381–386; y=2450 x 566–571, 599–604 | runs (2 pt stems, solid core) | 0 | SOURCED (RAW) |
| Tab badge dot | **#EA3337**, 4 pt | H43 (356–367, 2496–2507), centre (361, 2501) | centre px | 0 | SOURCED (RAW) |
| Outline capsule border / label | #FFFFFF 1 pt / #FFFFFF; fill = page (#000000) | H43 col x=600: y 1641–1643, 1749–1751; row y=1694 x 301–303 | runs | 0 | SOURCED (RAW) |
| White capsule button fill / label | #FFFFFF / #000000 | LAND col x=600 y 2032–2211 (rows 2036–2205 all #FFFFFF); ST-03 Send Postcard rows 2366–2500 #FFFFFF | px | 0 | SOURCED (RAW) |
| Hairline divider | ≈ #333333 – #353535 (1 device px) | ST-03 col x=640 y 2159; TC-2B col x=1600 y 1667 | runs | ±8 | SOURCED · APK dark separator #4D4D4D |
| Segmented control track / selected | #1E1E1E / #6B6B6B | TC-REC row y=446 x 238–273 / 370–401; col x=300 y 420–480 | runs | ±3 | PLATFORM (native UISegmentedControl, dark) |
| Glass circle on photo (Rewind 40 / 64 pt buttons) | photo lightened by ≈ +10–16 levels: inside #8B8273 vs outside #7D7263 (RWA, sRGB) ⇒ ≈ white 8–12 % or a light blur material | RWA row y=2285 x 119–310 (share) and row y=335 x 1152–1271 (more) | inside/outside comparison | — | SOURCED |
| Tab icons over photo (Rewind) | selected #FFFFFF; unselected ≈ white @ 60 % (#B2AFAC over #322C25) | RWA icon bands y 2640–2740 | brightest 25 px vs darkest 200 px per icon | ±4 | SOURCED (RAW) |
| Paywall close circle on colour | white ≈ 15 % over backdrop (#8B6BA4 inside vs #73508F around, sRGB) | PAY (1045–1055, 230–240) vs (1000–1031, 252) | box | — | SOURCED (RAW) |

**Palette summary (what the images support):**

| semantic | light | dark (iOS) |
|---|---|---|
| background | #FFFFFF | #000000 |
| fill / secondary surface (tiles, fields, pills, circle buttons) | #F1F1F1 | #262626 |
| text primary | #000000 | #FFFFFF |
| text secondary | #999999 | #999999 |
| text tertiary / placeholder | #B0B0B0–#B4B4B4 (APK #C1C1C1) | #8B8B8B (APK white @ 30 %) |
| empty-tile text | #D9D9D9 | #515151 |
| icon selected / unselected | #000000 / #B2B2B2 | #FFFFFF / #999999 |
| hairline | #CCCCCC (APK; images read #E3E3E3–#EFEFEF at 1 px) | #4D4D4D (APK; images read #333333) |
| accent / destructive / badge | #EA3337 | #EA3337 |
| primary button | #000000 fill, #FFFFFF label | #FFFFFF fill, #000000 label |
| outline button | 1 pt #000000 | 1 pt #FFFFFF |
| system tint (text buttons in sheets) | system blue (PLATFORM) | system blue |

There is **no brand colour** in Retro's chrome: everything is black/white/grey; colour comes only from photos, the
red #EA3337 (badges, destructive), system blue (sheet nav buttons) and the premium-only purple.

### 3.3 Type roles

Family classes: **D** = display serif (Roslindale Retro; our build: platform serif until a licence exists — see other
file §2.4); **S** = platform sans (iOS SF Pro, measured; Android Inter Variable per APK).

| role | example | family | size (pt) | weight | case · tracking | colour light / dark | evidence + method | ± |
|---|---|---|---|---|---|---|---|---|
| Display title (screen title) | "Week 43", "Albums", "Friends", "Journals", "Messages", username "isareyes" | D | **cap height 30.5 pt**; x-height 21.8 pt (x/cap 0.72); ascender 32.7 pt | Regular (heavy-looking design) | as written; tight default spacing | #000000 / #FFFFFF | H43 "W" y 287–378 (92 px → 30.7); ST-01 73 px → 30.6; TC-1B "F" 69 px → 31.3; ST-02 username x-height 52 px → 21.8; APK Android 40 sp/48 sp W400 | ±0.4 |
| Display date title on photo | "May 1, 2019 ⌄", "Jul 22, 2022", "July 5, 2021" | D | cap 30.5 pt (digits 92 px RWA); chevron 19.7 × 12.3 pt | Regular | — | #FFFFFF on photo | RWA "1" y 285–376; chevron (570–628, 319–355) | ±0.3 |
| Display medium (paywall headline) | "Share Video" | D | cap 22.3 pt; x-height 15.3 pt | Regular | centred | #FFFFFF on colour | PAY "S/h" y 1051–1121 | ±0.4 |
| Display small (recap month cards, journal title, recap year) | "December", "CDMX", "2023" | D | ≈ cap 17–20 pt (renders only) | Regular | — | #FFFFFF on photo / #000 on card | TC-REC, TC-J1, TC-H | ±10 % |
| Empty-state title | "Welcome to Week 43!" | S | **20** (cap 13.8, x 10.3) | Semibold | Sentence | — / #FFFFFF | H43 W y 1524–1565.5; x-height 1534–1566 | ±0.5 |
| Week section header | "Week 27" + "Jul 3 - 9" | S | **15** | Semibold + Regular | — | #000000 + #999999 | ST-02 (`retro-timehop.md` table) | ±1 |
| Body / list row text | "Weeks Posted: 32", "Expires in 1 month", address lines | S | **15** (cap 10.0) | Regular | Sentence | #000000 / #FFFFFF | ST-02 "W" y 914–937 (24 px → 10.0 → 14.2; x 18 px → 14.6); TC-1B "E" 23 px; ST-03 "C" 25 px | ±1 |
| Name / row title | "olson", "Mexico City", "elton", "Total" | S | **15** | Semibold | lower-case usernames as typed | #000000 / #FFFFFF | ST-01 "olson" x-height 19 px → 15.4; ED-W3 "M" 38 px → 13.9 (x-height → 14.4); ST-03 "T" 24 px → 14.2 | ±1 |
| Secondary line | "Isabel Reyes", "Elton Cah", "daniel shared 2 posts", "Mailing Address" | S | **13–15** (real name 13; list subtitle 15) | Regular | Sentence | #999999 | ST-02 "I" 19–20 px → ≈12–13; TC-1B "E" 20 px → 12.9; ED-W3 subtitle x-height 29 px → 14.4; ST-03 label 23 px → 13.6 | ±1 |
| Capsule label, large (60 pt buttons) | "Claim", "Send Postcard", "Get started" | S | **17** (Claim, Send Postcard); 18 (Get started) | Semibold | Sentence / Title for product objects | #FFFFFF on black / #000000 on white | PAY "C" 35 px → 16.5, x 25 px → 16.1; ST-03 "S" 29 px → 17.2; LAND "G" 38.5 px → 18.2, x 29 px → 18.7 | ±1 |
| Capsule label, medium (36–37 pt pills) | "Get this week started", "Recaps", "Accept", "Manage Key Holders" | S | **15** | Semibold | | as button | H43 "G" 30 px → 14.2, x 23 px → 14.8; ST-02 "R" 24 px → 14.2; TC-1B "A" 23 px → 14.8 | ±1 |
| Modal / sheet nav title | "Postcard", "Create Recap", "Settings", "Add to Your Week" | S | **17** | Semibold | Title Case | #000000 / #FFFFFF | ST-03 "P" 28 px → 16.6 | ±1 |
| Nav text buttons | "Invite", "Keys"; sheet "Cancel" / "Update" | S | **17** | Regular | Title Case | #000000 (Friends) / system blue (sheets) | TC-1B "I" 27 px → 17.4 | ±1 |
| Tile weekday label | "Mon", "Tue" | S | **13** | Semibold | 3-letter | #FFFFFF over scrim | ST-02 (`retro-timehop.md`) | ±1 |
| Empty-day tile month / weekday | "Oct" / "Mon" | S | **14–15** (cap 10.0, x 7.7) | Medium/Regular | | #D9D9D9 / #515151 | H43 "M" y 703–732, "o" 710–733 | ±0.7 |
| Empty-day tile day number | "20" | S | **28** (digit height 20.0) | Semibold | tabular digits | #D9D9D9 / #515151 | H43 "2" y 606–665 | ±0.5 |
| Badge (count pill) | "6 new" | S | **11** (cap 7.5, x 5.7) | Semibold | lower case | #FFFFFF on #EA3337 | ED-A "6" y 1436–1464, "n" 1443–1464 | ±0.5 (APK `bodySmall` 11/11 W600) |
| Pill label small | "FREE" pill, "1:00" | S (digits monospaced in "1:00") | 13 | Bold | caps | #FFFFFF / #000000 | PAY "F" 27 px → 12.8 | ±1 |
| Large grey subtitle (landing) | "Friends Only" | S | **30** (cap 21.3) | Regular | Title Case | — / #999999 | LAND "F" y 1235–1298 | ±0.5 |
| Secondary link | "already have an account?" | S | 15 | Semibold | lower case | — / #999999 | LAND x-height 23 px → 14.8 | ±1 |
| Fine print | "By continuing, I confirm…" + underlined "Terms", "Privacy Policy" | S | 14 (line height 21.7) | Regular | | — / #999999 | LAND "B" 30 px → 14.2; baselines 2429 → 2494 | ±1 |
| Paywall plan title / price | "1 Year Free" / "FREE" | S | 24 / 22 | Bold / Heavy | | #090A0A | PAY "Y" 51 px → 24.1; "F" 47 px → 22.2 | ±1 |
| Paywall body / steps / footnote | "Thanks for bringing…" / "Claim 1 free year…" / "$36.00/year…" | S | 15 / 17 / 15 | Regular | | #757A7D / #090A0A (done steps #757A7D struck through) / #A5ABAF | PAY | ±1 |
| Timestamps | "1d", "2h" | S | 14–15 | Regular | | #B4B4B4 / #999999 | TC-1B "1" 22 px → 14.2 | ±1 |

Localisation (ST jp/kr/de): the display role keeps Latin/digits in the serif and falls back to a heavy sans for Hangul
("27주") and Japanese ("第27週" headers); JP keeps the English home title "Week 27"; German strings run ~25 % longer
("Gepostete Wochen: 32", "Profil teilen") and still fit the 147 pt pills.

### 3.4 Layout and spacing (iOS, pt)

| item | value | evidence + method | ± | note |
|---|---|---|---|---|
| **Screen margin (content, titles, strips, cards, list rows)** | **16** | H43/H22 strip x=48 px → 16.0; title ink x=46 → 15.3 (W side-bearing); header icon right ink 1158 → (1206−1158)/3 = 16.0; ST-01 friend card x=209 → 15.9; ED-W3 album thumb x=1870 → 15.7; ST-02 avatar right → 15.5; TC-1B search x=1357 → 15.4 | ±0.4 | **Conflict:** renders show the photo strips at 20 (ST-01 x=218 → 19.7; ST-02 → 19.7; PLAY ratio 5.07 %; TC-J1 journal grid 19.8). RAW (2025, 2026) and REAL (JED 2024: strip left = title left) agree on one 16 pt margin. `retro-timehop.md`'s 20 pt is the render value. APK: horizontal padding 16 dp ×58 is the most common. |
| Full-width bottom capsule margin | **20** | LAND x 60–1145 → 20.0 / 20.3; ST-03 Send Postcard x 219 → 20.1; PAY card x 60 → 20.0 | ±0.4 | buttons and the paywall card sit at 20, content at 16 |
| Home title baseline from top | 126.0 (64 below the 62 pt safe-area top) | H43/H22 baseline y=378 | ±0.3 | iPhone 16 Pro |
| Header glyphs (book, chat) | centred on the title's cap middle (111.7 vs 110.8); centre-to-centre **48**; right ink at the 16 margin | H22 book (942–1011, 307–365), chat (1084–1158, 304–366) | ±0.3 | |
| Title baseline → strip top | **30** | H43/H22 378 → 468 (90 px); ED-W3 521 → 634 = 113 px → 29.0 | ±0.4 | ST-01 renders 17.6 (conflict; RAW wins) |
| Strip tile | **84 × 112** (3:4) | H43 x 48–299, y 468–803 (252 × 336 px) | ±0.3 | ST-01/02 84 × 112 ±0.5; 4 independent images give aspect 1.32–1.335 |
| Gap between tiles | **2** (page colour shows through) | H43 x 300–305 (6 px #000000) | ±0.3 | light: white gap |
| Tile pitch | 86 | H43 48 → 306 → 564 (258 px) | ±0.3 | strip scrolls; no trailing inset when it overflows |
| Strip → first friend row (home) | ≈ 70–80 to the avatar row | ST-01 strip bottom 1135 → avatar top 1331 (196 px → 82) | ±2 | render |
| Friend card | **240 × 361** (2:3); gap **16** between cards (next card peeks) | ST-01 x 209–782, y 1417–2278; gap x 784–820 (37 px → 15.5); ED-A 1353 → 2766 = 363 | ±1 | |
| Friend avatar → name → card | avatar **26.5** circle; name 15 semibold at avatar right + ≈7; avatar bottom → card top ≈ 10 | ST-01 avatar col x=264 y 1331–1393 (63 px → 26.4); ED-A y 1213–1315 (103 px → 26.5) | ±0.5 | |
| "N new" badge position | 12 from card top and right | ED-A badge (947–1138, 1402–1495) vs card (243–1183, 1353) | ±0.5 | |
| Profile week section | header baseline → strip 11.7; strip → next header cap 36.4; pitch 170 | ST-02 (`retro-timehop.md`) | ±0.5 | render |
| Profile header | avatar **64** at right margin; info rows pitch **29**, icon 14; buttons row h **37**, gap **8.8**, gear capsule 49 wide | ST-02 avatar 919–1072; rows y 911/978/1048; icons 33 px; buttons y 1129–1217, Recaps 209–561, Share 582–933, gear 954–1071 | ±0.5 | |
| Albums row | pitch **119.5**; thumbnail **72 × 97** (3:4); text starts thumbnail + 17; "+" circle **36** at the right margin | ED-W3 thumbs (1870–2148, 842–1217), (…, 1307–1682); title x=2213; + circle x 3138–3277 | ±1 | |
| Search field | 2025: **52** high, full width inside 16 margins; 2023: 36 high | ED-W3 col x=2600 y 558–759 (202 px → 51.9); TC-1B y 398–478 (80 px → 36.3) | ±1 | |
| Friends grid | 3 columns, avatar **81**, column pitch 125, name 15 bold centred below | TC-1B avatar (1391–1569), (1666–1843) | ±2 % | 2023 |
| Friend-request row | avatar 37; buttons **150 × 36**, gap 8–9 | TC-1B (1356–1436); Accept x 1473–1802, y 1402–1482 | ±2 % | 2023 |
| Empty-state block | icon 22 → 26 → title (20 pt) → 25 → outline capsule 37 high; block centred in the space between strip and tab bar (block centre 521.8 vs space centre 529) | H43 icon y 1380–1445, title 1524–1565.5, button 1641–1751 | ±0.4 | |
| Outline capsule (empty-state CTA) | **201.7 × 37**; padding 18 (to icon), icon 14.7, icon → label 9.7, label → edge 17 | H43 x 301–905, y 1641–1751 | ±0.4 | APK PaddingValues (12, 8, 12, 8) for small pills |
| Bottom primary capsule | **60** high, full width minus 2 × 20 | LAND y 2032–2211 (180 px); ST-03 2362–2505 (143 px → 59.9); PAY Claim 2229–2408 | ±0.3 | |
| Paywall card | 362 × 357, padding 27 (ink), CTA inset 16 from card sides and bottom; next card peeks after 8 | PAY x 60–1144, y 1386–2456; text x 141; Claim x 108–1096; next card x 1169 | ±0.5 | |
| Postcard modal | close 36; photo 298 × 423 centred; "Add a message" pill 149 × 37 centred near photo bottom | ST-03 (977–1063, 736–822), photo (285–996, 870–1880), pill (463–819, 1743–1830) | ±0.5 | |
| Rewind controls | dial 150 Ø; side buttons 64 Ø; "•••" 40 Ø at right margin; title left 16.3 | RWA/RWB (`retro-timehop.md` + RWA more y 276–396, x 1152–1271) | ±0.5 | |
| **Tab bar** | standard height (49 + home indicator); **5 icon-only items evenly distributed** (centres 39.5 / 120.2 / 200.5 / 281.2 / 361.5 on 402 pt → pitch 80.4 = width ÷ 5); icon centre 58 above the screen bottom; badge dot 4 Ø, 5 below the icon, centred | H43/H22 glyph boxes y 2414–2480; dot y 2496–2507 | ±0.3 | **Conflict:** renders (ST-01, ED-A) pack the icons with pitch 72–73 and side insets 50–52; RAW and REAL (JED pitch ≈80) are even |

### 3.5 Shape

| element | radius / shape | evidence + method | ± | note |
|---|---|---|---|---|
| Week strip (outer corners only; inner tile corners square) | **18 continuous** (circle-equivalent 18.7) | H43 TL and BL corners, inset profile 100 rows: continuous fit R = 54 px (residual 5.3 at s 0.75; circle fit 56 px residual 211) | ±0.5 | renders: ST-01 add-tile TR 37.5–38.5 px → 15.7–16.1; ST-02 38.5 px → 16.1 (supersedes `retro-timehop.md` 14 pt). RAW wins → 18 |
| Friend card (photo) | **18–19 continuous** | ST-01 card TL: continuous R 44.5 px → 18.6 (residual 54 vs circle 124) | ±1 | same family as the strip |
| Postcard photo | **8.5** | ST-03 photo TL circle fit 20.5 px | ±1 | |
| Album thumbnail | ≈ **4** | ED-W3 thumb TL inset profile (blurred upscale) | ±2 | APK 4 dp ×10 |
| Search field | 2023: **12** (36 high); 2025: ≈ 19 (52 high) | TC-1B TL fit 26 px → 11.8; ED-W3 fit 74.5 px → 19.2 | ±1 / ±2 | APK 12 dp ×9 |
| Paywall plan card | ≈ **36** | PAY TL: edge 23 px lower at 40 px in → analytic circle r ≈ 106 px | ±3 | gradient backdrop prevents a clean fit; APK 34–36 dp exist (×4, ×3) |
| Buttons 60 / 37 / 36 high, pills, badges | **capsule** (radius = height ÷ 2) | LAND and PAY inset profiles run the full half-height (90 px) | — | |
| Avatars, close / more / share / "+" buttons | **circle** | all images | — | |
| Bottom sheet ("New! Photo Postcards") | large top corners ≈ 24–28; inset card style (sheet floats with side margins in 2023) | TC-R3 phone 1 | ±4 | APK 24 dp ×14 |
| Grouped rows (Settings) | ≈ 12 | VID-SET frame 42 | ±3 | APK grouped-list 12 dp |
| Widgets | 22 dp | APK (other file §6.1) | — | |
| Inner photo grid cells (journal 3-col, composer 4-col) | 0 (square cells, 2 pt gaps) | TC-J1 row y=1950 white run x 2751–2754 (4 px at 2.07 px/pt) | ±0.5 | |

Corners are **continuous** wherever a fit could tell (strip, friend card). Outlines exist only on outline capsules
(1 pt). No card has a border.

### 3.6 Iconography

Style: **outline, uniform 2 pt stroke, rounded caps/joins**, ~20–25 pt glyphs (tab bar, header); a few filled glyphs
only as states (filled "key" badge, filled location arrow, filled heart = like). Stroke measured: H43 home glyph run
6–7 px → 2.0–2.3 pt; H22 book run 942–948 (7 px); ST-01 tab run 5 px → 2.1 pt.

| glyph (where) | measured size (pt, ink box) | SF Symbol candidate | Material Symbols (Rounded/Outlined) candidate |
|---|---|---|---|
| Home (tab) | 20 × 21.7 | `house` | `Outlined.Home` |
| Friends (tab) | 24 × 20 | `person.2` | `Outlined.Group` / `People` |
| Rewind (tab, 2026) | 24 × 20–22 | `clock.arrow.circlepath` | `Outlined.History` |
| Albums / journals (tab ≤2025, header 2026) | 23.3 × 19.7 | `book` | `Outlined.MenuBook` |
| Activity (tab) | 18.7 × 22 | `bell` | `Outlined.Notifications` |
| Profile (tab) | 22 × 22 | `person.crop.circle` | `Outlined.AccountCircle` |
| Chat (header) | 25 × 21 | `bubble.left` | `Outlined.ChatBubbleOutline` |
| Empty week / "Weeks posted" row / old home header | 22 × 22 (empty state) | `calendar` (dot grid) | `Outlined.CalendarMonth` |
| Add (tile "+") | 23 × 23, bar 2.3 (H43); 20 × 20 (ST) | `plus` (light-medium weight) | `Rounded.Add` |
| Add (CTA icon) | 14.7 | `plus` | `Rounded.Add` |
| More "•••" | dots 4.2 Ø, pitch 7.1 | `ellipsis` | `Rounded.MoreHoriz` |
| Close | X 9.7 inside 32–36 circle | `xmark` | `Rounded.Close` |
| Back | chevron | `chevron.left` | `AutoMirrored.Rounded.ArrowBackIos` |
| Expand (Rewind date) | 19.7 × 12.3 | `chevron.down` | `Rounded.ExpandMore` |
| Share (Rewind) | inside 64 circle | `square.and.arrow.up` | `Rounded.IosShare` |
| Random (Rewind) | inside 64 circle | `dice` | `Outlined.Casino` |
| Play / pause (dial centre) | — | `play.fill` / `pause.fill` | `Rounded.PlayArrow` / `Pause` |
| Homebase / location rows | 14 | `building.2` / `location` (arrow) | `Outlined.Apartment` / `Outlined.NearMe` |
| Last photo row | 14 | `camera.viewfinder` | `Outlined.CenterFocusStrong` |
| Settings (profile pill) | ≈ 15 | `gearshape` | `Outlined.Settings` |
| Key (friend badge, gate) | — | `key.fill` / `key.viewfinder` | `Outlined.Key` |
| Search | — | `magnifyingglass` | `Rounded.Search` |
| New album (header) | — | `book.closed` + `plus` badge (closest: `plus.rectangle.on.rectangle` — no exact match) | `Outlined.LibraryAdd` |
| Edit (pencil, add message) | — | `pencil` / `pencil.line` | `Outlined.Edit` |
| Lock (private week header, video FRAME) | — | `lock.fill` | `Outlined.Lock` |
| Video ("1:00" pill) | — | `video.fill` | `Rounded.Videocam` |
| Delete (red, menu) | — | `trash` | `Outlined.Delete` |
| Hide (menu) | — | `eye` / `eye.slash` | `Outlined.VisibilityOff` |

SF-symbol names are visual matches (PLATFORM assets); Retro's Android build draws the same outlines (PLAY renders), so
the icon set is drawn per platform to match.

### 3.7 Elevation and materials
- **No shadows on cards, tiles, lists or buttons** in any light or dark capture (friend cards, strips, rows sit flat on
  the page). Exceptions: the journal **cover** has a soft drop shadow (TC-J1, TC-J5 — the "book" metaphor); the paywall
  "FREE" pill has a coloured shadow (PAY col x=960 y 1526–1533).
- **Materials (blur/glass)** only over photos or colour: Rewind circle buttons (≈ white 8–12 %), paywall close circle
  (≈ white 15 %), paywall plan card (translucent white), "Add a message" pill (reads opaque #262626 in ST-03),
  context menus and share sheets (native, PLATFORM).
- **Backdrops for modal content:** recap preview and paywall use a full-screen **blurred, colour-rich version of the
  photo** behind a white card (TC-REC phone 2, PAY, ST-04). This is the one "decorative" surface Retro has.
- **Scrims on photos:** (a) day tiles: bottom gradient — mean luminance over 12 tiles in ST-02 stays ≈ 100–107 down to
  57 % of tile height, then falls monotonically to ≈ 41 at 95 % (side columns only, labels excluded) ⇒ black gradient
  from transparent at ~55 % to ≈ 60 % opacity at the bottom edge; (b) Rewind: bottom gradient behind dial and tab bar
  (RWA row-mean luminance ≈ 120 at y 2300 → 42 at y 2800). Values ±15 % (content-dependent).
- Dark mode raises nothing: surfaces are flat #262626 on #000000 (no elevation tint).

### 3.8 Photo treatment
| place | crop / aspect | corners | gaps | overlays |
|---|---|---|---|---|
| Week strip tile | aspect-fill 3:4 (84 × 112) | outer strip corners only (18) | 2 pt | weekday label 13 pt semibold white, bottom-centred, baseline 13.4 above the bottom, over the bottom scrim |
| Friend card (home) | aspect-fill 2:3 (240 × 361) | 18–19 continuous | 16 between cards | "N new" red capsule top-right (count — do not copy); "Seen" grey pill in the same place (read state — do not copy) |
| Story / media viewer | full width, native aspect (letterboxed on black) | 0 | — | header and footer on black, outside the photo |
| Rewind | full-bleed | 0 | — | serif date top-left + "On this week" subtitle; bottom scrim; glass buttons |
| Postcard composer | ≈ 1.42 (A6) | 8.5 | — | glass "Add a message" pill near bottom-centre |
| Journal / album detail | 3-column square-ish grid | 0 | 2 pt | date headers between groups |
| Composer picker | 4-column grid (FRAME) | 0 | ≈1–2 pt | — |
| Album list thumbnail | 3:4 cover with title in a display/script face on the photo | ≈ 4 | — | cover title (user-styled) |
| Recap collage card | white card, 3–4 col grid, footer "2023" serif + name + "retro.app" | card ≈ 12 | 1–2 pt | — |
| Widget | full-bleed | 22 dp | — | name + location white text stack bottom-right (other file) |

---

## 4. Components catalogue (measured specs)

Values in pt; L = light, D = dark. "Fill" = #F1F1F1 (L) / #262626 (D).

1. **Screen title header (display).** Serif title (cap 30.5) at the 16 margin, baseline 126 on a 402×874 device (64
   below safe-area top). Trailing glyphs 24-ish pt, 2 pt stroke, centred on the title's cap middle, 48 apart, last one
   at the 16 margin (H22). Optional grey capsule next to the title: "Last Week" (#999999 fill, white 11–12 pt text,
   ≈24 high; JED, ENG-D). Pushed screens put a `chevron.left` before the serif title (ED-W3, ENG-M). Content starts 30
   below the title baseline.
2. **Week strip.** Horizontal scroller at the 16 margin; tiles 84 × 112, 2 apart; outer corners 18 continuous; tiles:
   - *photo tile* — aspect-fill, bottom scrim, weekday label (13 semibold white, centred, baseline 13.4 above bottom);
   - *add tile* — Fill, "+" 23 (2.3 stroke) centred, #000 (L) / #FFF (D); first when the week is empty, last otherwise;
   - *empty-day tile* — Fill, three centred lines: month 14–15 regular, day number 28 semibold, weekday 14–15; line
     pitch 27; text #D9D9D9 (L) / #515151 (D).
3. **Week section (profile / history).** Header row: "Week N" 15 semibold + date range 15 regular #999999 (one space
   apart, same baseline) + `ellipsis` 4.2 pt dots at the right margin; header baseline → strip 11.7; strip → next header
   36.4; current week without photos shows no range (tiles carry dates).
4. **Friend card (home feed, horizontal pager).** Avatar 26.5 circle + name 15 semibold above a 240 × 361 photo card
   (2:3, 18–19 continuous corners), cards 16 apart with the next one peeking; badge top-right 12 in.
5. **Tab bar.** Icon-only, 5 items evenly spread, standard height, background = page colour, **no top hairline**,
   no labels; selected #000/#FFF, unselected #B2B2B2 (black 30 %) / #999999 (white 60 %); activity badge = 4 pt red dot
   5 below the glyph. Over photos (Rewind): white / white 60 % on a bottom scrim.
6. **Buttons.**
   - *Primary bottom capsule:* 60 high, full width − 2×20; L: #000 fill, #FFF 17 semibold; D: #FFF fill, #000 label
     (LAND "Get started", ST-03 "Send Postcard", PAY "Claim"). Disabled (2023 TC-R3): #3A3A3A-ish grey fill, grey label.
   - *Medium capsule pair (actions):* 36–37 high; primary black fill / white label, secondary outline 1 pt black /
     black label; 15 semibold; equal widths with 8–9 gap (TC-1B Accept / Decide Later; ST-02 Recaps / Share Profile +
     49-wide gear capsule).
   - *Outline CTA with icon:* 37 high, hugging width (201.7 for "Get this week started"), 1 pt border, `plus` 14.7 then
     label 15 semibold, paddings 18 / 17 (H43).
   - *Fill pill:* Fill colour, black 15 semibold label ("Create" JED; "Settings"/"Share" journal pills are outline).
   - *Small white pill on dark/photo:* "Share" ≈ 61 × 36, black semibold (ST-04, TC-REC).
   - *Text button:* 17 regular (Invite / Keys; Cancel / Update in system blue in sheets).
7. **Circle buttons.** "+" add 36 Ø Fill with black "+" (Albums rows); close 32 Ø (paywall, glass) / 36 Ø (#262626,
   postcard) / ≈23 (story header, #262626); edit 30 Ø #262626; more "•••" 40 Ø glass on photo; share / random 64 Ø
   glass on photo.
8. **Badges / pills.** "N new" #EA3337 capsule ≈ 49 × 24, 11 semibold white (counts — do not copy); "3 of 4" #262626
   capsule 22 high on dark; "1:00" white capsule 71 × 24 with `video.fill` + monospaced digits (PAY); premium "FREE"
   purple gradient capsule 51 × 26 with shadow (PAY only).
9. **Search field.** Fill colour, `magnifyingglass` + "Search" placeholder (#B0B0B0 2023 / #979797 2025); 36 high r 12
   (2023) or 52 high r ≈19 (2025), inside the 16 margins.
10. **List row with thumbnail (Albums).** Pitch 119.5; 72 × 97 (3:4) cover r ≈4; title 15 semibold; subtitle 15 regular
    #999999 with the actor name in semibold ("**daniel** shared 2 posts"); avatar stack (22.6 Ø avatars, ≈3 overlap,
    white ring) below; trailing "+" circle 36 Fill at the right margin.
11. **Avatar.** Circle; sizes seen: 22.6 (stack), 26.5 (feed), 36–37 (request row, story header), 64 (profile header),
    81 (Friends grid). Story header avatar has a white ring with a gap (TC-2B). Key-holder badge: white circle with a
    filled key, top-right of the 81 avatar (TC-1B). No-photo avatar: initials on a solid colour circle ("SF" on green,
    ED-W3).
12. **Profile header.** Serif username (display role) + real name 13 #999999; avatar 64 at the right margin aligned to
    the title; 3 info rows (14 icon + 15 regular text, pitch 29); action row (37-high outline capsules). Section list
    follows (no divider in 2026 renders; 2023/2024 show a full-width hairline under the buttons).
13. **Empty state.** Centred: 22 pt outline glyph → 26 → 20 pt semibold title → 25 → outline CTA capsule (H43). Variant
    with grey explanation and avatars (Key holders only gate, TC-2B): glyph, 17 semibold title, 13–15 grey two-line
    body, avatar stack, outline capsule "Manage Key Holders".
14. **Modal / sheet header.** Centred 17 semibold title; trailing close circle (36 #262626 on dark; on light sheets an
    "×" in a #F1F1F1 circle, VID-SET); or iOS nav pattern Cancel / Title / Update (system blue) (VID-COMP).
15. **Media viewer chrome (2023).** Black page; header row: avatar 36 with ring + name 15 semibold + "Week 28" 15 #999999,
    trailing "3 of 4" pill + close circle; footer: location 15 semibold + date 15 #999999, trailing reaction glyph;
    hairline #333; comment row (avatar 36, "name 2h", text 15); bottom field: #262626, 48 high, rounded, own avatar
    leading, "Add a comment…" #8B8B8B, `ellipsis` trailing.
16. **Bottom sheet (feature intro).** Light rounded sheet over a dimmed screen: 64-ish app-style icon tile, 17 semibold
    title ("New! Photo Postcards"), 2 rows of 15 regular grey text each with a leading 20 outline glyph, full-width black
    capsule (TC-R3).
17. **Grouped settings list (sheet).** White sheet; profile card (name, @handle, location chip, avatar) in a Fill group;
    small grey section headers (Subscription / Notifications / Widgets); rows in Fill groups with title + grey subtitle
    + `chevron.right`; widgets carousel of rounded thumbnails (VID-SET, low-res; APK: 12 dp group radius, 16 dp
    padding).
18. **Composer sheet "Add to Your Week".** Page-sheet; nav Cancel / title / Update; selected-media strip using the
    week-strip tile style with grey placeholders; "Camera Roll ⌄" + grey "Photos taken since Sep 9" + camera glyph;
    4-column square grid below (VID-COMP).
19. **Rewind player.** Full-bleed photo; display date 30.5 cap at 16 margin + optional `chevron.down`; subtitle "On
    this week" 17 regular white 60–70 %; top-right "•••" 40 glass; bottom dial 150 Ø (≈45 ticks, long 18 / short 11)
    with play/pause, flanked by 64 glass circles; tab bar over scrim.
20. **Segmented control, context menu, share sheet, keyboard, alerts.** Native (PLATFORM): TC-REC, TC-RWP, TC-R3.
    Destructive menu items in #EA3337 ("Delete from Photos", "Make journal private").
21. **Page dots.** 5 pt dots, 12 pitch, selected #000, others ≈#DDDDDD (TC-1B); white/grey on dark (TC-REC).
22. **Divider.** 1 device px, #CCCCCC (L, APK) / #4D4D4D (D, APK); images read lighter at 1 px. Used sparingly:
    between profile header and weeks (2023–24), above "Friend Requests", between footer and comments, above "Total".
23. **Recap card.** White card (≈12 corners) on a blurred photo backdrop; photo grid; footer: serif year + right-aligned
    name (semibold) over "retro.app" (grey) (TC-H, TC-REC); polaroid variant: square photo in an off-white frame with
    a meta line ("August 2025 · Barcelona, Spain · @cindyttt · 2:06am · retro.app") (ST-04).
24. **Album detail header.** Book-like cover (photo + display title) with drop shadow centred; serif title; "6 members ·
    307 photos" 13–15 #999999; outline pills Settings / Share + "+" circle; dated group header "January 25, 2024" 15
    semibold + `ellipsis`; 3-col grid with 2 pt gaps (TC-J1).

---

## 5. Our surfaces → closest Retro screens

"Transfers" = layout pattern and components to take; tokens always from §3. Where Retro has no analog, the
mechanics source is the one already assigned in `docs/SURFACES.md`.

| our surface | closest Retro screen(s) (inventory #) | what transfers |
|---|---|---|
| `global` | all | §3 palette (L/D), type roles, 16/20 margins, 2 pt strip gaps, 18 continuous radius, outline icon set, flat surfaces |
| `global.system` | 20, 24, 25 (native menu / share sheet / segmented) | Retro keeps native components; destructive = #EA3337 |
| `invite.web`, `invite.appclip` | 35 (retro.app `/u/`, `/j/` — other file §7) | blurred-photo card, serif headline, translucent white capsule "Let's go"; App Clip card |
| `auth.phone`, `auth.code`, `auth.agegate`, `auth.profile` | 26 (landing, RAW dark) | black page, serif mark area, 30 pt grey subtitle, 60 pt white capsule at 20 margins, 15 semibold grey secondary link, 14 pt legal with underlined links. Form screens **not captured** (order phone → code → username → full name from APK); draw fields with the Fill-colour field (#F1F1F1 / #262626) |
| `onboarding.permission.camera / .notifications / .photos / .contacts` | 16 (feature-intro sheet), 1 / 13 (empty-state block) | sheet: icon tile, 17 semibold title, 2 icon rows, black capsule; or full-screen empty-state block with outline CTA; then the system prompt (PLATFORM) |
| `onboarding.widget` | 28 (Settings → Widgets carousel), 34 (widget art) | rounded widget thumbnails, 60 pt capsule; mechanics Locket |
| `groups.list` | 10, 11 (Albums list); 2 (home title + friend cards) | serif title + trailing new-group glyph; rows: 3:4 cover, title 15 semibold, grey subtitle with semibold actor, avatar stack, "+" circle to post; pushed variant with 52 pt search |
| `groups.create` | 12 (Ideas to Get Started: Event / Friends / Couple + "Create" pills) | template rows (cover thumb, title, grey line, Fill pill) ↔ our types friends / family / roommates / custom; name field = Fill field |
| `groups.invite` | 14 (link sharing flow), 8 (Invite text button) | cover sheet + black capsule "Turn on link sharing", grouped menu with red destructive row, circular share targets (QR, Copy Link, Instagram, Share…) |
| `groups.screen` | 13 (album detail), 2 (friend cards) | cover with shadow, serif group name, grey meta, outline pills (Settings / Share / +), dated sections with "•••", 3-col 2 pt grid; members' weeks as friend cards |
| `groups.settings` | 17/28 (Settings sheet), 9 (request rows) | grouped rows on Fill, section headers, chevrons; member rows like friend-request rows (avatar 37, name, grey line); destructive red; switches PLATFORM |
| `camera.capture`, `camera.fromwidget` | no Retro analog (Retro posts from the camera roll) | draw with D tokens: #000 page, white controls, 64 pt glass circles (Rewind), 2 pt outline glyphs; mechanics Locket |
| `camera.sendto` | 18 (composer), 17 (postcard modal), 8 (avatar grid) | sheet header Cancel / title / primary; group chooser as 81 pt avatar or 3:4 cover grid with a selection badge (key-badge position); "Add a message" glass pill for caption; 60 pt bottom capsule "Send" |
| `widget.*`, `widget.arrival`, `widget.android` | 34 (Retro widgets, other file §6.1) | full-bleed photo, 22 dp corners, white name + place stack bottom-right; lock-screen widgets: no analog (PLATFORM); mechanics Locket |
| `chat.thread`, `chat.composer`, `chat.voice` | 31 (Messages inbox, low-res), 15 (comment row + field) | serif "Messages" header + search; message field = #262626/#F1F1F1 48-high rounded field with avatar and trailing glyph; thread bubbles **not captured** (BLOCKED → Messages mechanics, Retro tokens) |
| `chat.reactions` | 15 (viewer footer reaction position) | reaction affordance in the viewer footer; Retro's heart-like and counts are do-not-copy |
| `photo.viewer` | 15 (media viewer), 24 (menu) | black page, header (avatar ring, name, "Week N" grey, close circle; position pill only if not a count), footer location/date, comment field, `ellipsis` → native menu (Save / Delete / Report, red destructive) |
| `walls.mine`, `walls.member` | 4 (profile), 3 (week sections) | serif name, grey real name, 64 avatar, info rows, outline action pills, week sections with strips (strip rules §4.2) |
| `walls.browse` | 8 (Friends grid) | 3-col 81 pt avatars with names, search field, page dots |
| `daily.notification`, `daily.liveactivity`, `daily.ongoing` | no analog | PLATFORM surfaces; Live Activity drawn with D tokens (black, white SF, serif "Week"-style title if a title is used); mechanics BeReal |
| `daily.capture` | no analog | D tokens as `camera.capture`; mechanics BeReal |
| `daily.dualimage`, `collage.view` | 21/23 (recap collage card), 13 (2 pt grid) | white card on blurred backdrop, grid with 1–2 pt gaps, serif footer |
| `collage.share` | 20 (recap preview + Share), 32 (story sticker) | blurred backdrop, card, page dots, white "Share" pill, close circle; share-image footer serif + name + domain (ours: `{app_name}`) |
| `week.recap` | 19, 20 (Create Recap, preview), 21 | native segmented control (Weekly / Monthly / Yearly), serif month cards with chevron, preview + Share |
| `week.edit` | 18 (composer), 3 ("•••" per week) | strip editing in the composer sheet; week menu contents BLOCKED |
| `week.history` | 3, 4, 5 | covered in `retro-timehop.md` + §4.3 here (16 margin, 18 radius corrections) |
| `albums.list`, `albums.view` | 10, 13 | as `groups.list` / `groups.screen` (Retro's Albums are exactly saved, shared collections) |
| `onthisday` | 22, 23, 24, 25 (Rewind) | full-bleed photo, serif date title + chevron, "On this week" subtitle, glass "•••", dial with tick haptic (other file), 64 glass share / random buttons, bottom scrim |
| `birthday.add` | 26 / 13 patterns | Fill field on the landing/empty-state layout |
| `birthday.request` | 27 (paywall plan card on blurred backdrop), 16 (intro sheet) | blurred-photo backdrop, white rounded card (≈36 corners), serif headline, 60 black capsule; strip counts |
| `birthday.contribute` | 17, 18 (postcard modal "Add a message", 250-char counter in "Add a Message" modal) | photo + message composer, counter grey, 60 capsule |
| `birthday.tribute`, `year.story` | 22/23 (Rewind full-bleed + serif date), 20 (recap preview), VID retrospective (other file) | full-bleed media, serif titles, page dots, glass circle controls; pacing from Wrapped (mechanics) |
| `tagging` | no analog | outline capsule toggle ("I'm in this") per §4.6; mechanics Yope voice |
| `settings.root`, `settings.notifications`, `settings.account`, `settings.blocked` | 17/28 (Settings sheet) | grouped Fill rows, section headers, chevrons, profile card on top; switches/pickers PLATFORM; blocked rows = request-row pattern |
| `paywall` | 27 (Retro Premium, RAW) | close 32 glass, two-part title, media card, serif headline, translucent plan card (pager, 8 gap), black 60 capsule, footer "Cancel anytime"; purple pill only if premium accent is wanted; referral steps / counts are do-not-copy; StoreKit sheet PLATFORM |
| `safety.report`, `safety.block` | 24 (native menu with red destructive), 20 | native action sheets / alerts (PLATFORM) with #EA3337 destructive |
| `system.permissions`, `notifications.push` | — | PLATFORM |

---

## 6. Gaps and the smallest capture that closes each

| gap | why it matters | smallest capture |
|---|---|---|
| **No RAW light-mode capture of any screen.** All light values come from renders (lossless but sometimes older/retouched): fills (#F1F1F1 vs APK #F7F7F7 rows), 16 vs 20 strip margin, 18 vs 16 strip radius, tab spacing | light mode is the default appearance | 3 raw iPhone screenshots in light mode: Home (populated week), Profile (scrolled to show 2 week sections), Albums list |
| Activity / notifications tab | our `notifications.push` + in-app activity list | 1 raw screenshot of the bell tab (light + dark) |
| Settings at full resolution (only 640×800 video frames) | all `settings.*` | 2 raw screenshots: Settings sheet top + scrolled |
| Message thread (bubbles, photo replies, composer) | `chat.*` | 1 raw screenshot of a thread with a photo reply (light + dark) |
| Current media viewer (2023 only) with comments | `photo.viewer`, `chat.reactions` | 1 raw screenshot of a friend's photo with a comment |
| Sign-up form, onboarding pages, permission pre-prompts | `auth.*`, `onboarding.*` | screenshots of the first 4 sign-up steps on a fresh install |
| Composer / camera-roll picker at full resolution | `camera.sendto`, `week.edit` | 1 raw screenshot of "Add to Your Week" with 2 photos selected |
| Current Friends tab and request rows (2023 only) | `walls.browse`, `groups.settings` | 1 raw screenshot of the Friends tab |
| Week "•••" menu and profile "•••" menu contents | `week.edit`, `walls.*` | 1 screenshot with the week menu open |
| Dark mode of profile, Albums, Friends, Settings, paywall | dark tokens for list/row surfaces | the 3 light captures above repeated in dark mode |
| iOS toasts / confirmations | feedback states | 1 screenshot after "Copy Link" |
| Android raw screenshots (only marketing renders; APK gives constants) | Android parity (dark bg #1C1C1E vs #000) | 2 raw Android screenshots (Home light + dark) |
| iPad layout | none needed unless we ship iPad | App Store has no iPad set |
| Lazyweb's 61 account-gated captures | would close most rows above | a free Lazyweb account (owner decision) |
| Fast Company 2025-12 inline images | Rewind/press imagery | open the article in a normal browser and save its images |
| Older App Store screenshot sets (Wayback) | version history of the visual system | a network that can reach web.archive.org |

One capture session closes almost everything: **on one iPhone, take raw screenshots of Home, Profile, Albums, an album,
Friends, Activity, Settings (top + scrolled), a message thread, a photo with a comment, the composer with 2 photos
selected, and the week "•••" menu — once in light mode and once in dark mode (24 screenshots).**

---

## 7. Do-not-copy reminders specific to the visuals
- Counts and read states in badges: "N new", "Seen", "2 of 9"-style counters on viewers if they read as pressure,
  "Weeks Posted: N", referral counters, "N friends joined".
- Likes: filled red heart on the viewer and comment hearts.
- Lock / "Post to see" cards, the "Key holders only" gate.
- Brand assets: Retro wordmark, 3-D "R" mark, app icon, Roslindale font files, the "Retro Premium" two-part wordmark,
  postcard stamps, the purple premium gradient as brand (use only if the owner wants a premium accent, sourced here).

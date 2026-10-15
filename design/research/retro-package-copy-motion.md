# Retro — Android package, website, fonts, copy voice, motion

Research pass: 2026-10-15. Scope: everything about Retro (Lone Palm Labs; Android `io.lonepalm.retro`, iOS `id6443709020`)
that is not measured from static store screenshots: the shipped Android package, the public website and its share/invite
pages, the typefaces, the copy voice, motion from real screen recordings, and widgets / notifications / onboarding /
paywall. Static screenshot measurements live in `design/research/retro-visual.md` (other researcher).

Path abbreviation: **R** = `references/auto/retro/`. Every file below has a row in `R/INDEX.md` with its source URL.
Binaries and `.txt/.css` extracts are git-ignored (internal reference only); the INDEX is committed.

Evidence levels: everything read out of Retro's own package, website or videos is **SOURCED**. Behaviour that is the
operating system's (iOS sheet spring, Android toast length) is marked **PLATFORM** where it is the OS doing the work.

---

## 1. Sources

| id | what | where | version / date | how obtained |
|---|---|---|---|---|
| APK | Retro Android XAPK (base + `config.arm64_v8a` + `config.en` + `config.mdpi`) | https://d.apkpure.net/b/APK/io.lonepalm.retro?version=latest | **2026.10.1150** (version_code 1150), min SDK 32, target 37 | downloaded 2026-10-15; SHA-256 xapk `b8bfab18646335e59785fbedbb5a931a85fc7ac1374a4e3320544f9bae3d8237`, base apk `aba95a8ada75862a77fb954e76faf2f29a241514af0442b43886508e5fc12f91` (all split hashes in the excerpts header). Decompiled with jadx 1.5.3; resources read with androguard 4.1.4; font tables with fontTools 4.67. APK and decompiled tree deleted after extraction. |
| APK-X | code excerpts with obfuscated class + line numbers, tallies, font name tables | R `apk/retro-android-2026.10.1150-excerpts.txt` | same | text evidence only |
| APK-S | all 1,814 app string resources (key → value, library strings removed) | R `apk/retro-android-2026.10.1150-strings.txt` | same | androguard `ARSCParser` |
| APK-W | widget preview images and 3 graphics from the mdpi split | R `apk/widget_preview_{friends,journals,memories}.webp`, `apk/retro_membership_paywall_*.webp`, `apk/nux_card_what_to_share_0.webp` | same | unzip |
| WEB | retro.app: 8 CSS files, page chunks, Playwright captures (desktop 1440, iPhone 13, Pixel 7; light + `prefers-color-scheme: dark`) | R `web/retro.app-*.css`, R `web/retro.app-*.png`, R `web/retro.app-web-copy-excerpts.txt` | build `OvP-FXe5AR_mBG5aVTXHV`, accessed 2026-10-15 | curl + Playwright/Chromium |
| V1 | Instagram post (screen recording, iOS): Settings → **Your Referrals** sheet | https://www.instagram.com/p/DJXvmqRv2_N/ (item 2) | posted 2025-05-07; 640×800, **29.97 fps**, 7.74 s | yt-dlp; strips in R `video/ig-DJXvmqRv2_N-*.png` |
| V2 | Instagram reel "2024 Retrospective": profile scroll, Key-holder gate, **Add to Your Week** composer | https://www.instagram.com/reel/DDbA_F7x-j7/ | posted 2024-12-11; 1080×1920, **30 fps**, 13.7 s (frame-blended export) | yt-dlp; strips in R `video/ig-DDbA_F7x-j7-*.png` |
| V3 | Instagram reels "Sticker recaps" and "nostalgia" (no app UI; copy only) | https://www.instagram.com/reel/DWCJuPYAgiq/, https://www.instagram.com/reel/DefHn8NPdPJ/ | 2026-03-18, 2026-10-14; 30 fps | contact sheets only |
| VM | all video measurements (edge tracks, fits, frame-diff series) | R `video/retro-motion-measurements.txt` | — | ffmpeg + numpy |

Videos were deleted after measurement (hashes recorded in VM). 60 fps sources were tried and were not obtainable: the
App Store listing (all of us, gb, au, ca, kr, jp, de, fr storefronts) has **no app preview videos**; the Play listing's
promo video `https://www.youtube.com/watch?v=ATmTINhY5vQ` ("A new way to stay close to friends without having to text
them every day", 2025-04-10, 720×1280 **60 fps**) lists formats but every media request returns HTTP 403 / "sign in to
confirm you're not a bot" from this network; TikTok `@retrodotapp` renders no video links to a headless browser.

---

## 2. Framework and fonts

### 2.1 Framework (APK, SOURCED)
- **Native Kotlin + Jetpack Compose.** No `assets/index.android.bundle` (not React Native), no `libflutter.so` (not
  Flutter), 4 dex files with `androidx/compose/*`, and **no app XML layouts** (the only layouts are library/Glance ones).
  Code is R8-obfuscated; only manifest components keep names (`com.lpl.retro.app.MainActivity`,
  `com.lpl.retro.widget.{friends,journals,memories}.*AppWidget`, `com.lpl.retro.wallpaper.annual.AnnualRecapLiveWallpaperService`,
  `com.lpl.retro.postreminder.PostReminderWorker`, `com.lpl.retro.onthisweekreminder.OnThisWeekReminderWorker`,
  `com.lpl.retro.onboardingnudge.*`…).
- Home-screen widgets: **androidx.glance** (3 widgets). Animations: Compose animation APIs + **Rive** (`librive-android.so`;
  2 files: `res/raw/recap_sticker_collage_loading_anim.riv`, `res/raw/set_profile_picture_empty_state.riv`). No Lottie.
- Other SDKs present (not design): Stripe (payment sheet + Link), RevenueCat (subscriptions), Firebase, AppsFlyer/Airbridge,
  Amplitude, Google Places, ML Kit face detection + subject segmentation (stickers), Media3/ExoPlayer.
- **Caution for anyone reading the APK:** classes whose `toString` says `LinkColors(…surfacePrimary…buttonBrand…)`,
  `LinkShapes`, `LinkTypography`, `StripeColors` are the **Stripe Link** SDK theme (brand green `0xFF00D66F` in `e42`),
  not Retro. They are excluded from every value below.
- iOS app: not inspected (no IPA). The website and App Clip meta tags confirm an **App Clip** `io.lonepalm.Retro.Clip`
  exists (§7).

### 2.2 Bundled font files (APK `res/font/`, name tables in APK-X)

| file | family (name ID 1/16) | foundry / designer | licence as embedded | fsType |
|---|---|---|---|---|
| `roslindale_retro.ttf` | **Roslindale Retro v0.2** Regular (v0.020) | DJR — David Jonathan Ross, "(c) 2017. All rights reserved", licence URL djr.com/license | commercial, custom pre-release cut | 4 (preview & print) |
| `roslindale_narrow.otf` | **Roslindale Display Narrow** Regular (v2) | DJR | commercial | 4 |
| `roslindale_deck_narrow.otf` | **Roslindale Deck Narrow** Regular (v1.0) | DJR | commercial | 4 |
| `inter_variable.ttf`, `inter_variable_italic.ttf` | **Inter Variable** 4.001 (axes `opsz` 14–32, `wght` 100–900) | rsms / Rasmus Andersson | **SIL OFL 1.1** (free, redistributable) | 0 |
| `pp_neue_montreal_{regular,book,medium,bold}.otf` | **PP Neue Montreal** 2.200 | Pangram Pangram (Mathieu Desjardins) | commercial | 4 |
| `rader_bold.ttf` | PP Rader Bold | Pangram Pangram (Valerio Monopoli) | commercial, "All rights reserved" | 0 |
| `mondwest_bold.ttf` | Mondwest Bold | Pangram Pangram (Steve Marchal) | commercial | 4 |
| `pp_fraktion_mono_regular.otf` | PP Fraktion Mono | Pangram Pangram (Juri Zaech) | commercial | 4 |
| `ed_lavonia.ttf` | ED Lavonia (script) | Emyself Design, "All rights reserved" | commercial | 8 |
| `helvetica.ttf` | Helvetica 10.0d4e1 | "© 1990-2006 Apple Computer Inc. © 1981 Linotype" (a macOS system copy) | commercial (Linotype/Monotype); not licensable from the file | 0 |
| `vcr_ocd_mono.ttf` | VCR OSD Mono 1.001 | "MrManet" (no licence string) | unknown — treat as BLOCKED | 8 |
| `chango.ttf` | Chango | Fontstage | SIL OFL 1.1 | 0 |
| `cedarville_cursive.ttf` | Cedarville Cursive | Kimberly Geswein | SIL OFL 1.1 | 0 |
| `roboto_medium_numbers.ttf` | Roboto Medium (31-glyph numerals subset) | Google | Apache 2.0 | 0 |

The website additionally loads `RoslindaleRetrov0.2-Regular.woff2`, `Roslindale-DisplayNarrowRegular.ttf`,
`CedarvilleCursive-Regular.ttf`, `Chango-Regular.ttf`, `Mondwest-Bold.ttf`, `PPRader-Bold.ttf` and
`PPEditorialNew-UltralightItalic.ttf` (CSS `c857ab11667cdfc8.css`). No font file was saved in this repo.

### 2.3 Font roles (APK code `osg`, `wv3`, `gfb.f`, `fh7`; usage contexts in APK-X "FONT FAMILY USAGE")

| role | Android (SOURCED from code) | iOS / web (SOURCED) | where it is used |
|---|---|---|---|
| **Display serif** (titles like "Week 27", profile name) | Roslindale Retro, M3 `headlineLarge` = **40 sp / 48 sp line, W400, tracking 0** (`wv3.e`) | Roslindale Retro Web on the site (hero 64 px desktop / 32 px mobile; album title 48/32 px) | week header / home title; also one 94 sp W400 style (`wv3` ctor, unused field) |
| **Display narrow serif** (cards, invite page) | Roslindale Display Narrow: home feed cards ("Retro is for the important people in your life.", "Want to see your best friend on Retro?", backfill + Rewind upsell cards), onboarding subtitles 26/32 sp, other sizes 24/29, 32/34, 32/40, 48/52, 18/21 | invite page h1 "Nathan Invited You!" 48 px desktop, 32 px mobile | |
| **Deck narrow serif** | Roslindale Deck Narrow 31/36 sp ("Enter your code"), 32/38 sp tracking −0.6 sp, referrals 32 sp | — | invite-code redemption, referrals |
| **UI sans** | **Inter Variable** (not Roboto): `bodySmall` 11/11 sp W600; `bodyMedium` 14/17 sp W600; `wv3.c` **14/17 sp W450** (most used, 33 call sites); `bodyLarge` 15/18 sp W600; tracking −0.2 / −0.3 / −0.3 / −0.35 sp **only when the locale script is Latin** (`hh3.p0`), else 0 | iOS: SF Pro (web CSS stacks name `SF Pro Display`; in-app glyphs are SF — see retro-visual.md) | all UI text |
| Year in Photos / Retrospective | PP Neue Montreal 13–48 sp ("RETRO.APP" 48 sp, tracking −1.5) | — | annual recap pages |
| Script numerals | ED Lavonia ("12 friends joined" count) | iOS referral screen (V1) | referrals |
| Tiny print | Helvetica 9 sp tracking 0.45; 10–12 sp | — | QR card "Retro.app - Photos with Friends", "Member since 2023", postcards |
| Stamp / camcorder | PP Fraktion Mono 10 sp; VCR OSD Mono 16 sp | — | recap film frames, video recap date stamp |
| User-chosen recap text | enum `eh7`: CHANGO, MONDWEST_BOND, CEDARVILLE_CURSIVE, RADER_BOLD, ROSLINDALE_RETRO | — | sticker/collage recap editor |

### 2.4 What the owner must decide / license
1. **Display serif** — Retro's identity face is Roslindale (Retro cut + Display Narrow + Deck Narrow). Roslindale is sold
   by DJR (djr.com/roslindale; licence terms djr.com/license); the "Retro v0.2" cut is a custom/pre-release version only
   DJR can provide. DESIGN_DIRECTION already rules out copying Retro's font files. Options: license Roslindale (Display
   Narrow / Deck Narrow are retail styles) or another licensed display serif; until then the role stays PLATFORM
   (New York / Noto Serif).
2. **UI sans** — Android: Inter is **OFL** and can ship free (role SOURCED: Retro uses Inter on Android). iOS: SF Pro
   is the platform font (free, PLATFORM).
3. Do **not** ship: Helvetica (the file is Apple's system copy), PP Neue Montreal / Rader / Mondwest / Fraktion Mono
   (Pangram Pangram commercial), ED Lavonia (commercial), VCR OSD Mono (licence unknown). Chango and Cedarville Cursive
   are OFL if a sticker-text feature ever needs them (owner decision).

---

## 3. Palette and constants from the package (SOURCED, APK 2026.10.1150)

### 3.1 Theme structure
Retro's root theme (`gfb.f(isDark, trueBlack, content)`) provides an M3 `ColorScheme`, an M3 `Typography` built from
`wv3`, and a semantic colour accessor `vv3(isDark, trueBlack)` through `CompositionLocal d42.t`:
`colorScheme = isDark ? (trueBlack ? d42.w : d42.v) : d42.u`. Window background (splash) `splash_screen_background`:
**#FFFFFF** light / **#1C1C1E** night (`res/values{,-night}/colors.xml`); `Theme.Retro` parent
`Theme.Material.Light.NoActionBar`.

### 3.2 Material 3 ColorScheme (`d42.u` light via `lightColorScheme`, `d42.v` dark, `d42.w` dark "true black")

| M3 role | light | dark | dark, true black |
|---|---|---|---|
| primary | **#0A84FF** | **#0A84FF** | #0A84FF |
| onPrimary | #FFFFFF | #FFFFFF | #FFFFFF |
| primaryContainer | #CCCCCC | #4D4D4D | #4D4D4D |
| onPrimaryContainer | #000000 | #FFFFFF | #FFFFFF |
| secondaryContainer | #F7F7F7 | #262626 | #262626 |
| onSecondaryContainer | #000000 | #FFFFFF | #FFFFFF |
| background | **#FFFFFF** | **#1C1C1E** | **#000000** |
| onBackground | #000000 | #FFFFFF | #FFFFFF |
| surface | #FFFFFF | #1C1C1E | #000000 |
| onSurface | #000000 | #FFFFFF | #FFFFFF |
| error | **#EA3337** | #EA3337 | #EA3337 |
| onError | #FFFFFF | #FFFFFF | #FFFFFF |
| others (secondary, tertiary, surfaceVariant, outline…) | M3 baseline defaults | M3 dark baseline (`x32.*`) | same |

### 3.3 Retro semantic colours (`vv3`, light : dark; call-site counts in Retro code)

| accessor | light | dark | uses | role (from values and contexts) |
|---|---|---|---|---|
| `vv3.m` / `.b` | #000000 | #FFFFFF | 58 + 20 | primary text and glyphs |
| `vv3.o` / `.d` | #000000 @ 50 % | #FFFFFF @ 60 % | 46 + 10 | secondary text (meta lines "A · B", NUX body) |
| `vv3.p` | #C1C1C1 | #FFFFFF @ 30 % | — | tertiary / disabled text |
| `vv3.e` | #999999 | #999999 | 10 | quaternary grey text (character counter "/250", unsupported-message text) — matches web meta `#999` and the store date range #999999 |
| `vv3.g` | #EA3337 | #EA3337 | 58 | destructive: delete glyphs/labels, warning glyph, "Remove", report |
| `vv3.k` | #FFFFFF | #1C1C1E (true black: #000000) | 2 | screen background |
| `vv3.a` / `.i` | #FFFFFF | #181818 | 4 + 1 | elevated surface |
| `vv3.l` / `.f` | #F7F7F7 | #262626 | 18 + 2 | secondary surface (chips, rows, reply bar, sheet cards) |
| `vv3.h` / `.j` | #CCCCCC | #4D4D4D | 1 + 1 | separators / container fill |
| `vv3.n` / `.c` | #FFFFFF | #000000 | — | inverse (text on primary-coloured pills) |
| other `d42` constants | #F1F1F1 (`o`, 3 uses: also the web count pill and note bubble), #1F1F1F (`p`, light-mode variant of `q`=#4D4D4D in `f4a`) | | | |
| `d42.s` gradient | 16 stops: #20AE3E → #009A44 → #019A6B → #019C96 → #00A1BE → #009FE8 → #0185D0 → #0067B6 → #03469D → #202289 → #611987 → #910184 → #BF0081 → #DD017D → #E3026A → #E4004F | | 3 | rainbow sweep (green → blue → purple → magenta → red) used in 3 places |

Alpha-copies of black/white used directly in Retro code (counts): black @ 0.5 (10), 0.2 (6), 0.25 (5), 0.7 (4), 0.1 (4),
0.05 (4), 0.4 (3), 0.3 (3); white @ 0.2 (4), 0.15 (2), 0.85 (1, widget glyph tint). Glance widget locked overlay =
black @ 0.7.

### 3.4 Typography constants
See §2.3. Exact `wv3` styles (all `includeFontPadding=false`): 11/11 W600; 14/17 W600; 14/17 W450; 15/18 W600;
Roslindale Retro 40/48 W400. Letter-spacing values are sp, applied only for Latin-script locales.

### 3.5 Shape constants (Retro code, `see.b(dp)` = RoundedCornerShape)
Counts: **24 dp ×14, 20 dp ×13, 4 dp ×10, 50 % (pill/circle) ×10, 16 dp ×9, 12 dp ×9, 8 dp ×7, 10 dp ×7, 18 dp ×6,
6 dp ×5, 34 dp ×4, 36 dp ×3**, 9/30/28/22/3 dp ×2, 40/26/14 dp ×1.
- Grouped-list rows (`pik`): single row 12 dp all corners; first row top 12 dp; last row bottom 12 dp; middle rows square.
- Recap time-range preview: top corners 16 dp only. Glance widget: 22 dp. Web: album grid 12 px, note bubble 18 px,
  view-journal button 32 px, invite pill 28 px (= height/2), count pill 999 px.

### 3.6 Spacing constants (Retro code)
- Horizontal padding (`padding(horizontal=…)`): **16 dp ×58**, 32 ×32, 24 ×29, 60 ×22, 12 ×8, 44 ×4, 8 ×5.
- Uniform padding: **16 ×47, 8 ×40, 6 ×29, 12 ×25, 4 ×21**, 2 ×15, 18 ×8, 10 ×7, 32 ×5.
- Sizes (`Modifier.size`): **24 dp ×61** (glyphs), 36 ×41, 28 ×23, 16 ×23, 48 ×19, 20 ×19, 18 ×17, 30 ×15, 60 ×12, 44 ×11,
  32 ×11, 64 ×9. Heights: 24 ×52, 16 ×48, 12 ×24, 8 ×21, 4 ×21 (spacers).
- PaddingValues: (12, 8, 12, 8) ×6 (pill buttons), (24, 8, 24, 8), (8), (4), (24), (20, 24, 20, 24).

### 3.7 Motion constants in code (SOURCED; Compose `tween(ms, delay, easing)` = `nrh.X`, `spring(ζ, stiffness)` = `nrh.T`)
Default tween easing is FastOutSlowIn (0.4, 0, 0.2, 1).

| spec | count | where (animation label / context) |
|---|---|---|
| tween **150 ms**, FastOutSlowIn | **51** | the house default: fade in/out paired with slide in composers, message composer, caption box, photo-library picker (`fadeIn(tween 150)` + `slideIn`), "media preview content scale", "comment media preview crossfade" |
| tween 100 ms | 17 | "crossfade" and small state fades |
| tween 500 ms | 13 | onboarding page enter/exit (fadeIn + expand / fadeOut + shrink), "onboarding header height" (0 → 58 dp), postcard composer reveal, "progress animation" |
| tween 120 ms | 4 | small fades |
| tween 250 ms FastOutSlowIn | 1 | "comment media viewer transition" (open a photo from a comment) |
| tween 250 ms Linear | 1 | "entry animation" (message thread) |
| tween 250 ms LinearOutSlowIn | 1 | "subtitle alpha" (Claim Premium sheet) |
| tween 350 ms EaseOutCubic (0.33,1,0.68,1) | 1 | "recap style fanout animation" (paywall recap cards fan out) |
| tween 500 ms custom cubic | 2 | "order complete scale transition" / "order complete transition" (postcard ordered) |
| tween 1000 ms delay 1000 / 500 | 1 | onboarding recap preview: fadeIn 1000 ms after 1 s + slideIn 1000 ms after 0.5 s; exit fadeOut 500 ms |
| tween 4000 ms linear, repeat | 1 | paywall "heartbeat" heart pulse (benefit slide) |
| tween 800 ms repeat | 1 | Share-to-Stories walkthrough "touch indicator" pulse (scale 1.0 ↔ 1.2) |
| tween 500 ms repeat | 1 | "Blinking caret" chevron |
| spring ζ 0.75, stiffness 200 | 4 | "recap style fanout animation" (second leg), blur ("blur_"), two others |
| spring ζ 0.75, stiffness 400 | 1 | "avatar 1 entry animation" (onboarding avatars) |
| spring ζ 0.5, stiffness 1500 | 1 | "avatar-jiggle" / "avatar-spring-back" (onboarding friend avatars jiggle) |
| springs ζ 0.9 / 200, 0.82 / 400, 0.86 / 400, 0.72 / 200; tween 140 ms | — | recap collage layer-action menu (`x2d`: action alpha, action scale ×1.2, label offsets) |
| spring default ζ 1.0, stiffness 400 | 2+ | Compose defaults for `AnimatedVisibility` expand/shrink and `fadeIn/fadeOut` without a spec |

Profile "Say Hey!" button uses a "wiggle" + "wiggle_rotation" animation (`xw1`); the Rewind dial and onboarding friend
picker use the tick haptic (below).

### 3.8 Haptics (SOURCED usage; constants are PLATFORM `HapticFeedbackConstants`)
- **Tap:** `View.performHapticFeedback(1)` = `VIRTUAL_KEY`, wrapped in try/catch before the action (`cm9`: 17 wrapped
  click handlers; also `gd`, `h21` notification-permission buttons, `kbh`, `w1a`, `wc1` sticker picker, `xk9`, `n9e`).
- **Tick:** `performHapticFeedback(27)` = `SEGMENT_FREQUENT_TICK` on API 34+, else `4` = `CLOCK_TICK` (`lh2`, `e25`,
  `f9e`, `hw`, `ig`, `kbh`, `p6a`, `pyj` video-trim timeline). The Rewind tab (`w9e`, reads `has_seen_rewind_tab`)
  collects the dial's item flow into the tick helper ⇒ **one tick per memory step on the Rewind dial**.
- No `VibrationEffect`/`Vibrator` calls in app code.

### 3.9 Toasts
Android confirmations use the **platform `Toast`**: 49 `Toast.makeText` calls, all `LENGTH_SHORT` (0) except
`widget_pin_failed` (`LENGTH_LONG`). Examples: "Saved!", "Phone number changed", "Message sent!", "Like sent!",
"Refreshing" (widget). Duration is PLATFORM (Android short toast).

---

## 4. Copy voice guide (SOURCED: APK-S keys; web; captures)

### 4.1 Rules derived from the 1,673 Retro strings (counts from APK-S)
1. **Casing depends on the element**, not one global rule:
   - **Settings rows and settings titles: Title Case** (31 of 31 multi-word): "Notification Settings", "Lock My Friend
     Requests", "Change Phone Number", "Neighborhood Captions", "Redeem a Code".
   - **Screen / sheet titles: split** — 95 sentence case vs 80 Title Case. Tool screens are Title Case ("Add to Your
     Week", "Create Recap", "Edit Profile", "Key Holders", "New Album", "Share Profile"); conversational titles are
     sentence case ("Welcome to your weekly photo journal", "Every week is precious", "Who else should be here?").
   - **Buttons: mostly sentence case** — 72 sentence vs 26 Title (46 single words): "Add friends", "Choose friends",
     "Send reminder", "Try it out", "Invite friends", "Add a memory", "Got it", "Maybe later". Title Case buttons
     cluster around named product objects: "Send Postcard", "Create Album", "Join Album", "Give Key", "Share Recap",
     "Add Friend", "Accept Friend Request".
   - Section headers: single words, Title Case ("Account", "Privacy", "Reminders", "System Permissions").
   - Product nouns are capitalised mid-sentence when they name a feature: "Week 27", "Retro Premium", "Rewind",
     "Recaps Pro", "This Week In", "Key Holders"; but lower case in prose: "your week", "albums", "a key".
2. **"Week N"** is always a capital W + digits ("Week %1$d", "Week %1$d is almost over"); relative weeks are Title Case
   with words: "This Week", "Last Week", "Two Weeks Ago", "Three Weeks Ago", "%1$s Weeks Ago".
3. **Punctuation:** 42 strings end in "!" — greetings, celebrations and success toasts only ("Welcome to Week %1$d!",
   "Saved!", "Copied!", "Your postcard is on the way!", "You've got a key!"). **Errors never use "!"** except two
   upsell lines. Explanations end with a period; titles and buttons have no terminal punctuation (148 of 150 buttons).
   67 strings end in "?" — prompts and confirmations ("Are you sure?", "Anything from today you want to remember?").
   In-progress states use the ellipsis character "…" (33×: "Updating…", "Creating your collage…", "Add a comment…").
   Separator "·" for meta ("Muted · Seen", "on Retro · Admin", "Ordered · %1$s"); em dash for asides
   ("Welcome to Retro Premium — forever."). Apostrophes are mixed (32 curly, 54 straight).
   *Correction to `retro-timehop.md` §Voice pattern:* Retro **does** use exclamation marks (42×).
4. **Emoji: almost none in product UI** (4 strings: "❤️ your post", "❤️ %1$d of your posts", "Like ❤️", "✌️%1$s left
   the thread", plus "👋" in "%1$s added %2$s to the thread"). Emoji appear in Instagram captions ("💫"), not in the app.
5. **Tone:** warm, second person, short; reassurance over pressure ("no pressure", "We will never spam your contacts.",
   "These photos are only visible to you."); light self-aware humour ("Beep boop — we're processing your referral
   code", "Post good photos or dumb photos with your two favorite people, no pressure."). Prompts are questions about
   moments ("Caught up with a friend?", "Ate something tasty?").
6. **Numbers as digits** ("4 weeks", "Expires in %1$d days", "1–2 weeks") except the relative-week labels and
   `number_to_words_*` used in prose ("three weeks ago").
7. **Product name in copy:** "Retro" is used freely ("Retro is better with friends", "on Retro"). Ours → `{app_name}`.

### 4.2 Verbatim examples by category (key in APK-S unless marked)

**Home / prompts / week**
- "Welcome to Week %1$d!" — `home_empty_state_title_template`
- "Get this week started" — iOS only (R `lazyweb/retro-lazyweb-20251020-week43-dark.png`; not in the Android strings)
- "Week %1$d" — `header_title_week_number_template`
- "Last Week" / "This Week" / "Two Weeks Ago" — `weeks_ago_*`
- "Add memories to Week %1$d over the years" / "Add memories" — `home_backfill_feed_card_*`
- "Revisit memories from Week %1$s over the years" / "View memories" — `home_rewind_upsell_feed_card_*`
- "Retro is for the important people in your life." / "Choose friends" — `home_invite_feed_card_*`
- "Want to see your best friend on Retro?" / "Choose friend" — `home_feed_card_invite_suggestion_placeholder_*`
- "This week in %1$s" — `home_feed_card_on_this_week_title_template`
- "Photos taken since %1$s" — `composer_header_template_current_week`

**NUX tips ("Tips from Retro", "Ideas to share")**
- "We hope you're liking it here so far. Here's how to make the most out of Retro" — `nux_card_title_tips_from_retro_first_week_0`
- "Document the moments that are important to you" — `…first_week_1`
- "It's more fun when you can see what they're up to and vice versa. Post good photos or dumb photos with your two favorite people, no pressure." — `nux_card_message_tips_from_retro_first_week_friends`
- "Caught up with a friend?", "Did something nice for yourself?", "Ate something tasty?", "Anything else you want to remember?" — `nux_card_title_what_to_share_0..7`
- "Add a memory" — `nux_card_cta_what_to_share`
- "Tap anywhere to advance %1$s" — `nux_card_message_tap_to_advance`

**Onboarding / sign-up** (order in §6.3)
- "Photos with friends", "Recap your life", "No Ads. Ever.", "Weekly photo journal" — `onboarding_landing_welcome_subtitle_0..3`
- "Continue with Apple" / "Continue with Google" / "Continue with phone" — `onboarding_landing_welcome_continue_with_*`
- "Enter your phone number…", "Enter the code…", "Choose a username…", "Enter your full name…" — `onboarding_form_input_hint_*`
- "Your code may take up to 30 seconds to arrive" / "Didn't receive a code?" / "Send again" — `onboarding_form_input_*`
- "Hi %1$s, let's get your Retro set up." — `onboarding_v3_splash_screen_title_template`
- "Welcome to your weekly photo journal" / "Retro is a social photo journal for moments big and small. Add to any week, any time." — `onboarding_v3_page_*_education`
- "Every week is precious" / "Life moves fast — how often do you want to get reminders to document your journey?" (Daily / Weekly / Monthly / Never) — `onboarding_v3_page_*_reminders`
- "Retro is better with friends" / "Retro is a safe and private way to share. Who are the important people in your life?" — `…friend_picker`
- "A private space for your friends. One scan away." — `onboarding_v3_page_title_share_invite_link`
- "Let your friends know it's you by setting a profile photo!" — `onboarding_v3_profile_photo_skip_attempt_message`
- "Start by picking a few moments to remember" / "Select %1$d to continue" — `onboarding_post_invite_media_picker_*`
- "Look back on your life, one week at a time" — `onboarding_post_invite_weeks_preview_subtitle`

**Permission asks (in-app pre-prompts)**
- "Allow Access to Photos" / "Retro needs permission to access your photo library so you can select and post photos." / "Give Permission" — `composer_permission_upsell_*`
- "No Contacts Access" / "Connect your phone contacts to find friends to invite here. We will never spam your contacts." / "Connect Contacts" — `contact_permission_upsell_*`
- "Camera Roll Access" / "Rewind uses your camera roll to show you memories from past years. These photos are only visible to you." / "Allow Photo Access" — `rewind_home_no_permission_upsell_*`
- "Never miss a message" / "Do you want to get notifications for direct messages, friend requests, and other activity?" — `onboarding_notification_permission_retry_*`
- "Keep up to date!" / "Enable push notifications to make sure that you always see the latest updates from your friends on Retro." / "Enable push" — `notification_settings_enable_permission_*`

**Notifications (local, built in the app)**
- title "Week %1$d" / body "Anything from today you want to remember?" — `post_reminder_notification_*`
- Sunday: "Week %1$d is almost over" / "Anything you want to look back on?" — `post_reminder_notification_*_sunday*`
- "On This Week" / "Relive %1$d memories from this week over the years." — `on_this_week_notification_*`
- "Finish setting up your Retro!" / "Your Retro is unlocked and ready!" — `onboarding_nudge_*`, `onboarding_resume_unlocked_*`
- Server pushes, as previewed in Notification Settings: "%1$s just posted.", "%1$s commented on your post: "Wow this looks yummy!"", "%1$s says you're friends, that true?", "%1$s gave you a key to their Retro archive", "%1$s just joined Retro.", "Week %1$d is almost over - any photos you want to remember?" — `notification_settings_description_*`
- Channels: "New Posts — Recent posts from users you care about", "Friend Activity", "Messages", "Media Feedback", "Upload Progress", "Other" — `notification_channel_display_*`

**Empty states**
- "Nothing to see here yet" — `activity_tab_empty_message`
- "Let's get started" / "Add some photos or videos to your album!" — `journal_profile_empty_state_*`
- "Your chats will show up here." / "Create a chat" — `message_inbox_empty_state_*`
- "%1$s is now on Retro" / "Be the first to say hi\nand welcome them" — `user_profile_empty_new_user_*`
- "No postcards sent" / "Postcards that you send to yourself or a friend will appear here" — `postcard_orders_empty_state_*`
- "When you fill in your weeks on Retro, you'll see recaps here." — `recap_time_selector_empty_message`
- "No keys shared yet" — `manage_keys_given_empty_state_title`

**Errors**
- "Something went wrong" / "There was a problem. Please try again." — `error_message_dialog_default_title`, `error_message_generic`
- "Code Expired" / "That code has expired. Send a new code and try again." — `error_message_expired_auth_code*`
- "Error retrieving your activity. Tap here to try again" — `activity_tab_loading_error`
- "Couldn't send comment" / "Try Again" — `media_viewer_comment_send_failed_*`
- "Couldn't find album" — `journal_profile_by_slug_does_not_exist_message`
- "Error loading media. Tap to retry" — `app_widget_error_message`

**Confirmations / destructive**
- "Are you sure?" + "Yes, go back" / "Any media you selected will not be added" — `composer_lost_changes_warning_*`
- "Unfriend %1$s?" / "They will not be notified" — `user_profile_confirm_unfriend_*`
- "Delete address?" / "Yes, delete" — `edit_address_delete_confirmation_*`
- "WARNING: This cannot be undone. …" / "Type "%1$s"" — `delete_account_page_*`

**Success toasts**: "Saved!", "Copied!", "Submitted!", "Message sent!", "Added to Album!", "Order cancelled!",
"Invite link copied to clipboard", "Updating…", "Downloading…".

**Settings**: "Settings", sections "Subscription", "Account", "Notifications", "Postcards", "Privacy", "System
Permissions", "Follow Retro", "About"; rows "Retro Premium", "Your Referrals", "Notification Settings", "Email
Settings", "Mailing Address", "Lock My Friend Requests" ("Others will not be able to send you friend requests."),
"Neighborhood Captions" ("Show the neighborhood or city on photos you post with locations."), "Product Manual",
"Contact Us", "Sign Out", "Delete Account"; notifications "Pause All — Turn off all notifications for the day";
reminders "Sharing Reminders — How often do you want reminders?" (Daily / Weekly / Monthly / Never).

**Paywall ("Retro Premium" — not "Retro Plus")**: title "Retro" + "Premium" (`retro_membership_paywall_title_prefix/suffix`);
benefit slides "Support Ad-Free Social Media", "Unlimited Profile History — Add photos from any time in your life. No
matter how far back.", "Exclusive Recap Styles", "Share Videos — Go beyond photos and share video clips to your weeks.",
"Unlimited Keys", "Sticker & GIF Comments"; plan cards "Annual — Best value for long-term use", "Monthly — Best for
flexibility and control" (badge "Popular"), "Weekly — Try Premium for just a week" (badge "Flexible"); CTAs "Try %1$s
free", "Continue", "Claim Offer"; footer "Cancel anytime", "Restore purchase"; billing "Billed %1$s yearly", "And then
billed %1$s yearly after"; welcome "Welcome to\nRetro Premium", "You've unlocked unlimited profile history", "Go as far
back as you want.", "Thanks for supporting ad-free social".

**Widgets**: "Friend Updates — See live updates from your friends", "Your Memories — See memories from your profile",
"Albums — See memories from your album"; config "See photos from…", "Photos to show", "Most recent — Prefer seeing the
most recently added photos", "All memories — Show a selection of all photos"; states "No media. Tap to reload", "Log in
to see your content", "Refreshing"; home upsell "New! Widgets for your home screen" / "Never miss a moment from a friend,
relive memories from your profile or an album — all directly from your home screen" / "Try out widgets".

**Sharing / recaps / web**: "Check out my %1$s on Retro!\n%2$s" (`recap_composer_share_export_template`), "Share your
Retro link", "Create Recap" (Week / Month / Year / All Posts), "Year in Photos", "Here's to another year in the books",
"Life Lately". Web: "Your friends, week to week", "Nathan Invited You!", "See what Nathan is up to this week on Retro.",
"Let's go", "Opening Retro...", "Add me on Retro" / "Photos with friends." (OG), "Ryan shared with you", "View Journal",
"Open Retro", "Download the app to read and leave comments", "Retro is a movement towards healthier standards for
social apps. An ad-free, ai-free way to stay up to date with friends and family". Marketing captions: "Nostalgia is
proof you are living a life to be proud of.", "build a life worth feeling nostalgic for", "It's not too late to look
back on your weeks".

### 4.3 Naming drift to note
- In-app the shared collections are now **"Albums"** ("New Album", "Albums" tab, "Album Members") while keys and the
  website still say **journal** ("View Journal", "You're invited to join the private journal.", `/j/` URLs).
- iOS and Android differ in places (iOS "Get this week started" has no Android key).

---

## 5. Motion

### 5.1 Measured from screen recordings (SOURCED; V1 is 29.97 fps → ±33 ms per frame; V2 is 30 fps with frame blending)

| motion | file + frames | duration | curve | notes |
|---|---|---|---|---|
| **Sheet presentation** (iOS page sheet "Your Referrals" over the Settings sheet; underlying sheet scales back) | V1 `ig-DJXvmqRv2_N-2.mp4` frames 43 → 60 (strip R `video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png`) | 90 % at ≈225 ms, 99 % at ≈390 ms, settled by ≈567 ms (±33 ms) | **critically damped spring**, ω = 18.1 rad/s (response 0.347 s), fit RMSE 0.001; no overshoot | progress per frame in VM §A: 0.074, 0.287, 0.495, 0.659, 0.781, 0.863, 0.915, 0.948, 0.968, 0.981 … This is the system UIKit sheet → **PLATFORM** behaviour that Retro uses unmodified |
| Composer sheet "Add to Your Week" | V2 frames 134 → 148 | same within ±1 frame (0.95 at 267 ms vs 0.948) | same | second independent capture of the same system spring |
| **Photo selection in composer** — existing tile slides one slot right, new tile appears at left | V2 frames 190 → 198 (strip R `video/ig-DDbA_F7x-j7-composer-f130-147-f188-197.png`) | ≈250 ms ±33 ms | S-curve (ease-in-out 245 ms and FastOutSlowIn 300 ms fit equally, RMSE 0.03) | slot pitch 201 px = tile + 9 px gap at that scale |
| First tile appears in empty slot | V2 frames 170 → 175 | ≈150–170 ms | scale from ≤ 0.875 to 1 with fade | |
| **Membership ring rotation** ("RETRO MEMBER SINCE 2023" text circle) | V1 frames 70 → 220 | 12.0 °/s constant → **30 s per turn** | linear, clockwise | polar cross-correlation, 5 windows all +12.0° per 30 frames |
| Count-up "0 → 12 friends joined" | V1 frames 44 → 60 | runs during the sheet rise | — | a count (do not copy) |

### 5.2 Motion from code (Android, SOURCED) — see §3.7
House default **150 ms FastOutSlowIn** fades (51 sites); 100 ms crossfades; 500 ms onboarding page transitions;
250 ms photo-from-comment open; spring ζ 0.75 / stiffness 200 for playful reveals.

### 5.3 Requested motions not measurable from available sources
| motion | status | what exists |
|---|---|---|
| Screen push / pop | **BLOCKED** | no clip with a push; Android has no Navigation library — screens are custom Compose; no shared transition spec found |
| Story viewer progress + tap-advance | **BLOCKED (duration)** | the viewer shows an **"%1$d of %2$d" badge** (`media_viewer_progress_badge_template`; press 2023 "3 of 4"), not progress bars; NUX "Tap to advance" / "Tap left to go back" (`viewer_nux_tap_*`); no auto-advance timer found in code |
| Photo open / close (zoom) | partial | code: "comment media viewer transition" tween 250 ms FastOutSlowIn; no video |
| Tile press feedback | partial | tap haptic `VIRTUAL_KEY` before action (§3.8); visual press state not recorded |
| Pull-to-refresh | **BLOCKED** | not found in code or video |
| Toasts | **PLATFORM** (Android) | `Toast.LENGTH_SHORT`; iOS toast not captured |
| Recap / Rewind | partial | Rewind dial ticks one haptic per step; recap paywall fan-out 350 ms EaseOutCubic + spring 0.75/200; sticker collage loading is a Rive file |
| Tab switch | **BLOCKED** | tabs: Home, Friends, Rewind, Activity, Profile (+ Album) from `main_tab_title_*` and `main_tab_icon_*`; no transition captured |

---

## 6. Widgets, notifications, onboarding, sign-up, invite, paywall

### 6.1 Widgets (APK, SOURCED)
- Three Glance widgets: **Friend Updates**, **Your Memories**, **Albums** (`widget_title_*`). Provider XML: minWidth/
  minHeight **200 dp**, min resize **100 dp**, target **2×2** cells, `updatePeriodMillis` **3,600,000** (1 h),
  reconfigurable, config activity `RetroAppWidgetConfigurationActivity`.
- Look (preview art R `apk/widget_preview_*.webp`, 158×158 px at mdpi = 158 dp): full-bleed photo, rounded corners
  (code `cornerRadius 22 dp`; preview art ≈24–27 px), bottom-right white text stack: name ("cheryl", "livs") over a
  location with a location-arrow glyph ("Naoshima", "Seoul") or an album/year ("Seoul 2024").
- States: refresh glyph in a 48 dp box (12 dp padding) tinted white @ 85 %; texts "No media. Tap to reload", "Error
  loading media. Tap to retry", "Log in to see your content"; locked state = black @ 70 % scrim + 32 dp lock glyph +
  "Post to see" (**do not copy** — tenet 5). iOS Settings (V1) shows a "Widgets" carousel with "Memories" and "Friend
  Updates" thumbnails.
- Android also ships an **Annual Recap live wallpaper** ("See your year in progress - any media added to your Retro for
  the year will show up in this beautiful Grid").

### 6.2 Notifications
Local notifications are scheduled by WorkManager workers: `PostReminderWorker` (cadence follows the "Sharing
Reminders" setting Daily / Weekly / Monthly / Never — inferred from the strings, scheduling code not traced; Sunday
variant "Week N is almost over"), `OnThisWeekReminderWorker` ("On This Week"),
`OnboardingNudgeWorker` / `OnboardingResumeNudgeWorker`. Reply and mute actions exist in notifications
(`MessageReplyNotificationReceiver`, `CommentReplyActionReceiver` "Reply", `CommentNotificationMuteReceiver` "Mute This
Post"). Notification icon asset `ic_retro_notification` (mdpi split). Copy in §4.2.

### 6.3 Onboarding and sign-up order (enum declaration order, `e4b` and `hbb`)
Sign-up form: **PHONE_NUMBER → AUTH_CODE → USER_NAME → FULL_NAME** (landing offers Apple / Google / phone; "By continuing,
I confirm that I am %1$d or older and agree to the Terms and Privacy policy."). Then: **SPLASH** ("Hi %1$s, let's get
your Retro set up.") → **EDUCATION** → **REMINDERS** (Daily/Weekly/Monthly/Never) → **NOTIFICATION_PERMISSION_RETRY** →
**PROFILE_PHOTO** → **INCOMING_REQUESTS** ("%1$s invited you!") → FRIENDS_ALREADY_ON_RETRO → FRIENDS_YOU_MAY_ALSO_KNOW →
WHO_ELSE_SHOULD_BE_HERE → **SHARE_INVITE_LINK** ("A private space for your friends. One scan away.") → FRIEND_PICKER →
POST_INVITE_WELCOME ("Welcome to Retro") → POST_INVITE_REASONS ("We're here to help you do two things": "Make more
memories", "Appreciate your own life") → POST_INVITE_MEDIA_PICKER ("Start by picking a few moments to remember") →
POST_INVITE_WEEKS_PREVIEW ("Retro is a weekly photo journal") → POST_INVITE_RECAP_PREVIEW ("Create something beautiful to
look back on", "Life Lately"). Enum order is declaration order; the runtime may skip steps (e.g. incoming requests only
when invited). Motion: page enter fade+expand 500 ms, header height 500 ms, recap preview fade 1000 ms after 1 s.

### 6.4 Invite flow
App invite sheet: "Invite to Retro", share targets Message / Copy Link / Instagram / Snapchat / Threads / Bluesky /
KakaoTalk / Line / Share (`invites_option_*`), contact rows "Invite" / "Waiting" / "Joined", toast "Invite link copied to clipboard". Profile QR
card: "Retro.app - Photos with Friends" + "Member since %1$d". Web side §7. Referral programme: "Get %1$d friends to
join to receive a free year of Retro Premium, or %2$d friends for a lifetime subscription." (counts and rewards — out of
scope for us).

### 6.5 Paywall
Structure from strings + assets: title "Retro Premium" (two-part), benefit slider (rating laurels "Join thousands of
subscribers", heart-pulse graphic animated 4 s loop, recap fan-out cards, post-to-see lock graphic), plan cards Annual /
Monthly ("Popular") / Weekly ("Flexible") with three bullets each, CTA "Try %1$s free" or "Continue", "Cancel anytime",
"Restore purchase". Payments via RevenueCat (+ Stripe). Welcome flow after purchase: "Welcome to\nRetro Premium" pager
"%1$d of %2$d". Not captured as images: the paywall screen itself (only its benefit graphics, R `apk/retro_membership_paywall_*.webp`).

---

## 7. Web pages (SOURCED, retro.app, accessed 2026-10-15)

No page has a dark scheme (`prefers-color-scheme: dark` renders identically; no dark rules in any CSS). Base:
`body` #000 on #FFF, font stack `-apple-system, BlinkMacSystemFont, Segoe UI, Roboto…`; UI text `SF Pro Display` stack;
display `Roslindale Retro Web` / `Roslindale Display Narrow Regular`.

| route | purpose | key copy | key values |
|---|---|---|---|
| `/` | landing | "Your friends, week to week" (h1, Roslindale Retro 64 px desktop / hidden on mobile); TikTok in-app browser notice "TikTok blocks app store links…" | hero animation cycles recap cards ("2026 / nathan / retro.app") (R `web/retro.app-home-*.png`) |
| `/u/[username]` | **invite / add-me page** | desktop: QR (250 px) + "Nathan Invited You!" + "Scan the code to see what Nathan Sharp is up to this week on Retro."; mobile: "Nathan Invited You!" + "See what Nathan is up to this week on Retro." + pill **"Let's go"** ("Opening Retro..." while busy); OG "Add me on Retro" / "Photos with friends." | mobile: full-bleed blurred photo background (`/invite-background/bg1..6.jpeg`), avatar 112 px circle, h1 Roslindale Display Narrow 32 px #FFF, body 14/19.6 px #FFF @ 62 % tracking −0.4 px max 260 px, pill 56 px high, width calc(100 % − 76 px), radius 28, bg #FFF @ 20 % (hover 30 %, 0.3 s ease); desktop h1 48 px #000, body 20/28 px #000 @ 50 % max 300 px, avatar 70 px. iOS "Let's go" opens `https://appclip.apple.com/id?p=io.lonepalm.Retro.Clip&username=…&t=a` (**App Clip card**); Android → Play Store. OG image 600×600: blurred dark gradient, round avatar, username in serif, "retro.app" grey (R `web/retro.app-og-userogsquare-nathan.png`) |
| `/j/[journalSlug]` (and `/j/invite/:slug`, `/ji/:slug`) | **shared album page** (example `/j/6ki3C4g_BCiikpa` "Welcome to Journals") | "Ryan shared with you" / "%1$s invited you to join the private journal." / "You're invited to view the journal."; "7 members • 24 photos"; "View Journal" (desktop) / "Open Retro" (mobile); "Scan to view this journal on the mobile app."; mobile footer "Download the app to read and leave comments" + "Download Retro" | cover = photo masked by `/journal-overlay.webp` (hard-light) like a book cover, white Roslindale Retro title at 15 cqw; title 48/32 px; meta 16/14 px #999; outlined pill button 1 px #0D0D0D radius 32 px; day headers "March 7, 2024" 14 px/600; note bubbles radius 18 px bg #F1F1F1; photo grid **4 columns, 4 px gap, 12 px radius**; immersive viewer with "1 of N" count pill (#F1F1F1, 999 px) and close button #262626/#999 (R `web/retro.app-j-welcome-*.png`) |
| `/m/[mediaSlug]` | **shared photo / recap page** | title "This week in %YEAR%" or "<caption or location · date> · Retro"; subtitle "Week N" or album name; "1 of N"; mobile "Retro is a movement towards healthier standards for social apps. An ad-free, ai-free way to stay up to date with friends and family" + "Download Retro"; upsell modal "See <Full Name>'s full week on the app" / "Download and create an account to see what else <username> shared this week" | App Clip card meta; `retro://media?publicSlug=`; upsell modal radius 40/10/40/40 px desktop, sheet #262626 radius 15 15 0 0 on mobile, slides in `transform .3s ease, opacity .3s ease`. **No live example found** (gap) |
| `/ethos` | About | "Retro is a social app that feels like a joy, not a habit." + 5 principles (full text in R `web/retro.app-web-copy-excerpts.txt`); SF Mono 16 px | |
| `/downloads` | signed package download | "Download your package", "Checking your link…", "This link is invalid, expired, or revoked. Contact the sender for a new link." | |
| `/emails/unsubscribe` | email prefs | "Email Preferences", "Sorry, it seems something went wrong." | |

robots.txt: "Shared content sends noindex via HTTP headers and page metadata." All share pages set
`robots: noindex, noimageindex`.

---

## 8. Do-not-copy (tenets / legal)
- Counts and pressure: "%1$d new", "%1$d posts", "Weeks posted: %1$d", "N friends joined" count-up, likes ("❤️ your
  post", "Like ❤️", "Likers"), "Seen", "Expires in N days" urgency on friend requests.
- **"Post to see" / "No Lurking"** (`product_manual_v2_no_lurking_message` "Post each week to unlock photos from
  friends.", widget lock, `unlock_media_sheet_*`, "Unlock for 24 hours") — an obligation, breaks tenet 5.
- Key-holder 4-week gate, referral rewards ("Refer 10 friends"), "Join thousands of subscribers" rating bar.
- Name "Retro", wordmark, chrome "R" icon (`retro_brand_icon*`, `ic_splash`), hero icons, Rive files, NUX photos,
  postcard stamps, every bundled font file.

---

## 9. Gaps and the smallest capture that closes each

| gap | smallest capture |
|---|---|
| 60 fps motion of the real app (push/pop, tab switch, story tap-advance, photo open/close, pull-to-refresh) | owner screen-records Retro on an iPhone (ProMotion, 60 fps) for 60 s: open a friend's week → tap through 3 photos → back → switch tabs → pull to refresh. Or a network that can fetch the Play promo `youtube.com/watch?v=ATmTINhY5vQ` (720×1280 60 fps, 21 s) |
| iOS strings (Info.plist purpose strings, iOS-only copy like "Get this week started") | the iOS `.ipa` (decrypted) or screenshots of each permission alert |
| iOS UI sans confirmation in-app | one raw iOS screenshot with "Welcome to Week N!" at 100 % (other researcher's raw Lazyweb captures may already suffice) |
| Story viewer auto-advance (if any) | 10 s recording of the viewer left untouched |
| `/m/[mediaSlug]` live page | any public "Share Photo" / recap link from the app |
| Paywall and onboarding screens as images | one pass through sign-up and Settings → Retro Premium on a test account (screenshots) |
| Widget rendering on device (text sizes of name/location overlay) | one home-screen screenshot with the Friend Updates widget at 2×2 |
| Toast style on iOS | screenshot after "Copy Link" in the iOS app |
| xxhdpi widget/NUX art (only mdpi in the APKPure split set) | the `config.xxhdpi.apk` split (APKMirror bundle) |

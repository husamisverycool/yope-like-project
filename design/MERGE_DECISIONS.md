# Merge decisions

How the research proposals (`design/proposals/*.json`, `design/research/*.md`) were merged into the
canonical files (`design/tokens/*.json`, `design/copy/*.json`, `design/copy-patterns.md`). Each
consolidation pass appends its own section. Rules applied by every pass (directive Part 2): no design
decision is ours; every value traces to evidence already in the research or gathered and logged here; when
two references conflict, the reference assigned to the surface in `docs/SURFACES.md` wins (Yope for
app-wide foundations; Apple HIG / Material 3 for system surfaces); between two measurements of the same
thing, lossless PNG beats video / JPEG and 2026 beats older; a sourced value is never adjusted to make it
work — problems are reported.

---

## Foundations

Pass: foundations consolidation, 2026-10-15. Owns `design/tokens/global.json` (146 tokens, surfaces
`global` / `global.system`), `design/tokens/README.md`, `design/copy-patterns.md`, `design/CONTRAST.md`,
`tools/contrast.mjs` and this section. Inputs: all of `design/research/*.md` and `design/proposals/*.json`.

### Evidence gathered in this pass

| what | source | used for |
|---|---|---|
| HIG system color values (light / dark) | https://developer.apple.com/tutorials/data/design/human-interface-guidelines/color.json (image alt text of the system-colors table; change log 2025-06-09 "Updated system color values"): Blue R-0,G-136,B-255 / R-0,G-145,B-255; Red R-255,G-56,B-60 / R-255,G-66,B-69; grays. The dynamic background / label / separator colors are listed **by name only** (no values). | `color.global.selection`, `color.global.destructive`, `color.global.system.ios` |
| HIG Dark Mode | https://developer.apple.com/design/human-interface-guidelines/dark-mode (2024-08-06): "In rare cases, consider using only a dark appearance … an app that supports immersive media viewing" | `layout.global.appearance` |
| Apple `UIUserInterfaceStyle` | https://developer.apple.com/documentation/bundleresources/information-property-list/uiuserinterfacestyle: "force the dark user interface style, even when the systemwide style is set to light" | `layout.global.appearance` |
| Yope dark-only frame | `references/auto/yope/frames/a-yrrah-7454430216123862280-t21.23-photos-permission-alert-2024.png`: light-appearance iOS alert over Yope's dark group screen | `layout.global.appearance` |
| HIG Motion, Sheets, Icons, SF Symbols, Playing haptics, Accessibility, Typography, Settings | DocC JSON of each page (fetched 2026-10-15): Motion "Many system components automatically include motion"; Sheets publishes no corner radius; Icons standard table (Close → xmark, More → ellipsis, Share → square.and.arrow.up, Add → plus, Done → checkmark, Search → magnifyingglass, Calendar → calendar; no Settings row); SF Symbols "an iOS tab bar prefers the fill variant, whereas a toolbar takes the outline variant"; haptics "Ensure that haptic vibrations don't disrupt experiences involving … the camera" | motion, `radius.global.sheet`, icons, `icon.global.variantRule`, `haptic.global.shutter` |
| SwiftUI `Animation.default` | https://developer.apple.com/documentation/swiftui/animation/default: spring, response 0.55, dampingFraction 1.0 (iOS 17+) | `spring.global.platformDefault.ios` |
| Compose `Spring` constants | https://developer.android.com/reference/kotlin/androidx/compose/animation/core/Spring (2026-06-24): StiffnessMedium 1500.0f, DampingRatioNoBouncy 1.0f | `spring.global.platformDefault.android` |
| Material 3 baseline dark scheme, motion tokens | androidx `compose/material3/.../tokens/ColorDarkTokens.kt` (v0_210), `PaletteTokens.kt`, `MotionTokens.kt` (v0_103) on raw.githubusercontent.com | `color.global.system.*`, `easing.global.system.standard`, `duration.global.system.scale` |
| Compose icon names | `androidx.compose.material:material-icons-extended-android:1.7.8` + `-core-android:1.7.8` classes.jar listings (dl.google.com Maven): every Android icon name in `global.json` exists; `ChevronLeft` / `ChevronRight` have no AutoMirrored variant; `KeyboardArrowLeft/Right`, `Send`, `Logout` do | `icon.global.*` |
| Material Icons Round outlines | fonts.gstatic.com `materialiconsround/{chevron_left,keyboard_arrow_left,chevron_right,keyboard_arrow_right}/v1/24px.svg`: same vertices, different start point | `icon.global.back`, `icon.global.chevron` |
| SF Symbol names and versions | SFSafeSymbols `stable` `Sources/SFSafeSymbols/Symbols/SFSymbol+{1.0…7.0}.swift`: all iOS names exist; `film.stack` = SF Symbols 4 (iOS 16); `person.2.badge.plus` = SF Symbols 6 (iOS 18) | `icon.global.*`, F-27 |
| WCAG 2.2 | https://www.w3.org/TR/WCAG22/ (Rec 2024-12-12): relative luminance with 0.04045, contrast ratio, SC 1.4.3 / 1.4.11 text | `tools/contrast.mjs`, `layout.global.contrast.*` |
| Pixel measurements on lossless PNGs | `yope-store-05.png` lime disc: non-lime px darkest 50 % all (0,0,0); placeholder box x395-580 y2415-2465: plateau 279 px (150,150,150), max 151; composer-field rim col 600: peak (75,75,75) top, (71,71,71) bottom. `yope-store-04.png` "today" pill: 17,794 white px, text 1687 px (0,0,0). `yope-store-02.png` tab-bar rim col 900 y2333-2334 (85,85,85), fill (45,45,45) | `onAccent`, `textSecondary`, `surfaceLight`, `onSurfaceLight`, CONTRAST.md |
| Glyph checks (crops) | `yope-store-05.png` right header circle = outlined film frame; `yope-store-02.png` 4th tab = filled film frame; `a-jacob-…-t3.73` flip = two circular arrows, no camera body; `locket-store-08.png` grid = 2×2 outlined rounded squares; `references/owner/locket-review-sendto.jpg` send = outline paper plane; sheet-title rows in `a-chuongxetank-…-t6.73` (x-height 13 px) vs `a-itsmthuyope-…-t49.23` (9 px) | F-6, F-16, F-17, icons |

### Conflicts and resolutions

| # | topic | values and sources | resolution | rule / evidence | status |
|---|---|---|---|---|---|
| F-1 | Appearance | Yope dark in every source 2024-2026; 2024 build let system alerts follow a light device (yrrah t21.23); 2026 alerts dark (virgi t9.23, t35.23; cause unknown) | Dark only, app-wide (`layout.global.appearance`), system surfaces included, so system colors are recorded with dark values | Yope (app) + HIG Dark Mode allowance + Apple's UIUserInterfaceStyle mechanism (system surfaces' reference) | resolved; owner to confirm |
| F-2 | Backgrounds by screen | #171717 group / chat / profile grid (store-01, -02, -05, Play-05 lossless) vs #000000 home, sheets, camera, sign-up (videos), press-kit profile (lossless exact), group photo cards June 2026 (S6) | Two role tokens: `color.global.background` (#171717) and `color.global.backgroundDeep` (#000000). `groups.screen` itself conflicts (store-01 #171717 vs S6 2026-06 #000000) — left to that surface's pass | different roles; both lossless | resolved (roles); `groups.screen` open |
| F-3 | Secondary text / placeholder color | yope-a #969696 (3 elements, original PNGs) vs yope-b #A3A3A3 (placeholder on the bicubic-rotated `b-derot-store-05-rot-1.68.png`) | #969696. Re-measured on the original PNG: 279 glyph px exactly #969696, none above 151 → #A3A3A3 is resampling overshoot | lossless original over interpolated derivative | resolved |
| F-4 | Body (chat message) size | 16 pt (yope-a, ascender ÷ generic 0.74) vs 17 pt (yope-b, x-height ÷ SF Pro 0.526), same PNG | 17 | x-height method uses the platform font's own ratio and matches the placeholder (17, same method) | resolved |
| F-5 | Header circle on black | #101010 (V-chuong 2026-10, V-mthu 2026-05) vs #131313 (S6 2026-06) — all H.264 | #101010 (two videos incl. the newest). The same videos render #171717 as #101010, so the true value may be lighter | newest + majority; video-only | unresolved (needs one lossless frame) |
| F-6 | Sheet title | "send to..." ≈19.5 pt bold (V-chuong 2026-10) vs "new group" ≈14.5 pt medium (V-mthu 2026-05); x-height 13 px vs 9 px at the same 1.181 px/pt | `fontSize.global.sheetTitle` 19.5 bold (newest); 14.5 stays with `groups.create` (yope-a `fontSize.groups.create.title`) | 2026-10 over 2026-05; the gap is beyond precision, so it may be a version change or two roles | unresolved |
| F-7 | Pink accent | #FE1F84 measured only on the "find friends like you" stranger-profile panel (do-not-copy surface); yope.app demo has a per-profile "vibe color" | Kept as measured (`color.global.accentSecondary`) with the caveat; contrast: white on pink only as bold / ≥18 pt | — | unresolved: may be a user color, not an app accent |
| F-8 | Time-overlay weight | heavy (yope-a, 3 images) vs bold (yope-b token; "bold/heavy", stem/cap 0.24) | heavy | majority of observations; no SF Pro stem reference available to decide | unresolved (side-by-side verification) |
| F-9 | System colors as hex | CONVENTIONS / provenance-check: UI code uses token constants only; HIG: "Avoid hard-coding system color values … Use APIs like Color" | Documented hex recorded (dark values, HIG 2025-06-09) and the API names kept (`color.global.system.ios`, notes) | both rules recorded | unresolved: the DS may resolve `selection` / `destructive` through `UIColor.systemBlue` / `.systemRed` on iOS |
| F-10 | Photo corner radius | 15 pt (S1r lossless chat photo; Play-05 wall thumbnails) vs 16.5 (S5 1:1 video) vs 19 (owner JPEG) vs ≈16 (send-to, ±3) | 15 | lossless over video / JPEG | resolved |
| F-11 | Navigation push | 100 ms ±33 (V-mthu, low confidence) vs native NavigationStack / Compose Navigation (system duration, not configurable or published) | Token kept (`duration.global.navigationPush`); native components listed in `easing.global.native` | — | unresolved: a native push cannot take the measured duration |
| F-12 | Android system color scheme | baseline dark scheme (purple primary #D0BCFF) vs dynamic color (Android 12+) vs a brand scheme | Baseline values recorded (`color.global.system.*`) as the documented defaults | M3 documents both; no reference evidence decides | unresolved (owner) |
| F-13 | Dynamic Type mapping method | — | nearest Large (default) size; tie → weight match; still tied → larger style (`layout.global.textStyleMap`) | HIG text-style table; the tie rule is a method choice | flagged |
| F-14 | Header inset | 11.5 (S1r lossless subpixel; S6 11.6) vs 13 (store-01 12.3 / 13.1, V-chuong 14.4) | 11.5 | lossless subpixel + independent device recording agree; store-01 is the marketing scale-up panel | resolved |
| F-15 | Sheet presentation | Yope: 215 ms with a 16 pt overshoot (S5, 5 samples, "curve not fittable") vs a native sheet | `duration.global.sheetPresent` and `spring.global.sheetPresentObserved` kept; `spring.global.sheetPresent` BLOCKED | fitting 5 samples would be a decision | unresolved (60 fps capture, or choose the native sheet) |
| F-16 | Flip-camera icon, Android | yope-a `cameraswitch` ("close") vs BeReal / Locket passes `sync` for the same SF Symbol | `Rounded.Sync` | Yope's glyph has two circular arrows and no camera body (crop) | resolved |
| F-17 | Recap header glyph | yope-a `film.stack` vs yope-b `film.stack.fill` for the same header circle | header `film.stack` (`icon.global.recap`); tab `film.stack.fill` (`icon.global.wall`) | crops: header outline, tab filled; HIG variant rule | resolved |
| F-18 | `onboarding.widget` voice | Locket (assigned) is Sentence case; the onboarding around it is Yope lowercase | Locket patterns govern that surface | SURFACES assignment | flagged for owner (case changes mid-onboarding) |
| F-19 | Composer height | 40 pt (group chat, S1r) vs 49-51 pt (1:1 space, S5 / O4) | Out of foundations; different roles; this product has groups only → the group-chat values apply in `chat.composer` | role separation | for the chat pass |
| F-20 | Purpose-string voice | Yope fragments without a final period ("Allow camera access. So you can …") vs `platform.purposeString` (complete sentence, period) | `system.permissions` follows `platform.purposeString`; Yope's benefit content is usable | SURFACES: system.permissions = HIG / M3 | resolved |
| F-21 | Safety copy | SURFACES "Yope voice for copy" vs platform.md "Report / Block follow platform.alertButton" | Native menu items and buttons: `platform.menuItem` / `platform.alertButton`; titles and explanations: Yope voice | both sources read together | resolved |
| F-22 | Small avatar | 32.6 (S1r lossless chat) vs 32 (video send-to) | 32.6 | lossless | resolved |
| F-23 | Lime | #CDFD07 (store-05, two passes), #CCFD07 (store-04), #CDFE08 (press kit), #D1FF17 / #D2FC09 (JPEG / video), #C8FF2E (website CSS) | #CDFD07 | lossless; the three PNGs agree within ±1/255; web lime is not the app | resolved |
| F-24 | Caption weight | voice duration semibold (S1r); legal footer weight unmeasured | semibold | only measured weight at 12 pt | resolved (footer weight open) |
| F-25 | Selection blue | Yope video ≈#166AFA (lossy, darker) vs documented systemBlue | systemBlue dark #0091FF (PLATFORM) | reference names the system color; the video value is lossy | resolved |
| F-26 | Haptics | Android has no warning constant; no documented shutter haptic; no reaction-sent mapping | warning → CONFIRM (platform.md); shutter = none (HIG camera rule); reaction = the long-press mapping; long press on iOS = system | platform.md table + HIG | resolved |
| F-27 | `person.2.badge.plus` | yope-a `icon.list.newGroup` | needs SF Symbols 6 / iOS 18; deployment target is iOS 17.2 (`config/app.json`) | SFSafeSymbols availability | for the groups.list pass |
| F-28 | Button heights | 44.9 (form, V-mthu) vs 47 (sheet bottom, V-chuong) | both kept as roles (`buttonHeight`, `buttonHeightSheet`) with their margins 19 / 27 | yope-a §1.4 "report both" | resolved |
| F-29 | Screen margin | no single Yope screen margin; home cards 12.3, header 11.5, chat avatar 11.2 | `size.global.screenMargin` = 12 (home cards); surfaces with their own margins keep them | naming of a measured role, value unchanged | resolved |
| F-30 | Copy pattern ids | Locket, BeReal, Retro, Timehop, Partiful general, Yope punctuation / formats, `platform.menuItem`, `platform.appClipCard` had no ids | New ids in `design/copy-patterns.md`, each citing its research section; researcher ids kept unchanged | naming only | resolved |

### Problems found in the proposals (for the per-surface passes)

- **Bicubic derivatives.** yope-b sampled colors on `b-derot-store-0{4,5}-…png` (rotated with bicubic
  resampling). Flat fills are safe, but thin features overshoot: placeholder #A3A3A3 (F-3), and likely the
  rim peaks (#404040 bubble, #535353 field). On the original PNG the field rim peaks at #4B4B4B and the
  tab-bar rim at #555555. Re-sample thin features on the originals.
- **Codegen-incompatible values.** `tools/designgen.mjs` emits `num(value)` for dimension / radius tokens,
  so object values (e.g. yope-a `dimension.header.capsule` `{width, height}`, platform
  `radius.safety.sheet.android` `{topLeft, …}`) pass `--check` but crash generation — split them or make
  them `layout`. Icon `android` values must be Compose references (`Rounded.Mic`,
  `AutoMirrored.Rounded.Send`), not Material Symbols names (`mic`, `chevron_left`). Haptic values must be
  a `DSHaptic` case path (`selection`, `notification.success`, `impact.light`) and a bare
  `HapticFeedbackConstants` name (`CONFIRM`); platform.md's descriptive strings would not compile.
- **Platform `surface: "all"` tokens** (touch targets, contrast thresholds, Reduce Motion) are now
  `size.global.minTouchTarget.*`, `layout.global.contrast.*`, `layout.global.reduceMotion`; do not merge the
  `*.all.*` proposals again.
- **Contrast** (design/CONTRAST.md): control fills against their backgrounds (1.10-1.37:1), the selected-tab
  state (1.37:1 pill, 2.96:1 glyph), small white text on the pink (3.66:1) and the M3 drag handle (2.71:1)
  fail; no sourced alternative pair reaches 3:1.

### Unresolved (owner, capture or verification)

F-1 (confirm dark only), F-2 (`groups.screen` background), F-5 (lossless frame of a black sheet header),
F-6 (sheet title treatment), F-7 (pink: app accent or user color), F-8 (overlay weight), F-9 (system colors:
hex vs API), F-11 (navigation push), F-12 (Android color scheme), F-13 (tie rule), F-15 (sheet spring),
F-18 (onboarding.widget case), and the BLOCKED tokens `color.global.separator`, `color.global.scrim`,
`spring.global.sheetPresent`.

---

## Memory (`onthisday`, `birthday.add`, `birthday.request`, `birthday.contribute`, `birthday.tribute`, `year.story`, `tagging`)

Pass: memory consolidation, 2026-10-15. Owns `design/tokens/memory.json` (169 tokens), `design/copy/memory.json`
(131 strings), `design/surfaces/{onthisday,birthday.add,birthday.request,birthday.contribute,birthday.tribute,year.story,tagging}.md`
and this section. Inputs: `design/research/{retro-timehop,wrapped-tribute-partiful,yope-a}.md`, their proposals, the
foundations, `backend/worker/src/tribute/render.ts` (token contract) and `backend/worker/COPY_KEYS.md`.

### Evidence gathered in this pass

| what | source | used for |
|---|---|---|
| Tribute sample files: 640 × 360, `r_frame_rate` 30000/1001; hard cut into the end slot (Tess: diff 64.2 at 94.201 s, then 0.00; Doug: 125.8 at 62.400 s, then 0.00) and out of the intro (7.034 s / 7.000 s); end slot to stream end 10.003 s / 10.006 s | https://website.tribute.co/6KY_IZ1tLME.mp4, https://website.tribute.co/QQe5RpbFIyI.mp4 (ffprobe; per-frame mean abs diff of decoded grey frames) | `layout.birthday.tribute.video`, `duration.birthday.tribute.endTransition`, `.endHold` |
| VidDay "1080p": "Your finalized video is delivered in crisp, high-definition 1080p — perfect for watching on any screen." | https://help.vidday.com/what-features-do-finalized-video-gifts-get/ (fetched 2026-10-15) | `layout.birthday.tribute.video` |
| VidDay tour re-measured frame by frame on the player crop (x688-1232, y175-728 of the 1920 × 1080 tour): ribbons clear 117.267-117.767 s; static (diff 2.85 = noise) 117.767-118.933 s; crossfade decays to the zoom baseline by ≈119.57 s | https://static.vidday.com/videos/vidday-group-videos-getting-started-2-minute-tour.mp4 | `duration.birthday.tribute.titleHold`, `.titleCrossfade` |
| VidDay title card at 118.3 s: player 542 × 553 px; caps 33.0 px (2 lines, pitch 54 px), widest line 398 px centred; text (68,67,71); paper (239,238,243) over 125,000 px; stems 5.16 px (sub-pixel coverage, 19 stems) vs Roboto stem / cap: Regular 0.134, Medium 0.173, Bold 0.208 (rendered from `backend/worker/fonts`) | same frame | `layout.birthday.tribute.titleCard` |
| Timehop 2023 memory view: screen 681 px (1.733 px/pt); progress bar y395-402 (fill (247,210,62) x629-732, track (147,20,10) x734-1308); source icon 33 px at x656, centre y532.5; text cap 13 px; photo top y488 | `references/auto/timehop/help/th-help-2023-04-memory-view-hide.png` | `*.onthisday.progress.*`, `*.onthisday.meta.*` |
| Wrapped 2024 device recording: chrome circles 64-68 px (29.6 pt) centred y320 (card top 214 → 48.3 pt), pitch 101 px, right inset 23 px; circle fill ≈ black 0.5 (channel ratios 0.47-0.56); share row glyph 41 px, label cap 25 px, gap 34 px | `references/auto/wrapped/frames/wrapped24-rec-emilycraig-t020.png` | `*.year.story.chrome.*`, `*.year.story.share.*` |
| Wrapped 2024 "Your top song" card on the contact sheet: canvas 144 × 257 px; art x43-137 y414-507 (square, 0.66 of width, centre 0.412 of height); text 9 px below | `references/auto/wrapped/frames/wrapped24-rec-emilycraig-sheet-every3s.png` (row 2, col 1) | `layout.year.story.photoCard` |

### Conflicts and resolutions

| # | topic | values and sources | resolution | rule / evidence | status |
|---|---|---|---|---|---|
| M-1 | Tribute video canvas | Tribute samples 640 × 360 (16:9, 29.97 fps, marketing web encodes); VidDay "1080p"; VidDay's mobile players show the video cropped to square / portrait containers | 1920 × 1080 at 29.97 | 16:9 from both measured files; 1080 lines from VidDay's own spec; the players' crops are presentation | resolved; owner may prefer 9:16 |
| M-2 | Title card hold | proposal 1300 ms (117.67 → 118.97 s) vs this pass 1167 ms (117.767 → 118.933 s, frames static) vs 1667 ms if playback starts at the unwrap tap | 1167 ms | frame-accurate static span = the worker's "fully visible" hold; the proposal's start frame still had ribbons over the card | resolved (capture 5 can raise it) |
| M-3 | End card | Tribute: hard cut + 10.0 s slot filled by the brand outro (wordmark, tagline, URL on brand teal); VidDay: not observed | slot timing kept (`endTransition` 0, `endHold` 10003); look (`layout.birthday.tribute.endCard`) and text (`birthday.tribute.endCard`) BLOCKED | the outro's content is do-not-copy; nothing else observed | BLOCKED (capture 5) |
| M-4 | Title card look | VidDay theme: hand-lettered face over watercolour confetti on paper; capitals | solid paper colour, measured text colour / size / position, Roboto Medium (worker font), Sentence case per P-BT-1 | theme art and face are VidDay assets; `maxWidthRatio` assumes the 16:9 frame was cropped to fill the square gift-page player | resolved with stated approximations |
| M-5 | Photo inside the video | Tribute: whole clip pillarboxed on black ("nothing gets cut off"); VidDay: photo inset in a theme frame with a slow zoom (curve not measurable) | Tribute pillarbox (`color.birthday.tribute.pillarbox`), no zoom | VidDay's frame is theme art and its zoom curve was not measurable | resolved |
| M-6 | Transitions | Tribute hard cuts everywhere (50 cuts); VidDay crossfade title → first photo (only transition observed) | title → first contribution: VidDay 600 ms crossfade; contribution → contribution and → end: Tribute 0 ms | each transition takes the reference that shows it | resolved |
| M-7 | Primary button colour on birthday surfaces | Tribute #FF4B4A, VidDay #0086FE (each brand's accent) | `color.global.accent` / `color.global.onAccent`; Tribute's geometry (62 / r8 / 22-600; step buttons 50 / r8 / 16-600) kept | brand colours are not copied (same rule the research applied to Wrapped); two assigned references disagree; app-wide accent is the foundation | resolved |
| M-8 | Light pages in a dark-only app | Tribute body #F6F4F3 and white prompt card; Timehop grid #F5F0ED (light appearance; Timehop has a dark mode, not measured) | page / grid gaps use `color.global.backgroundDeep` / `color.global.background`; Tribute's dark elements (hero black + photo 0.7, header bar #292D34, step page whites) kept | `layout.global.appearance` dark only (F-1) | resolved; depends on F-1 |
| M-9 | On-this-day banner colour | v5 shows #FC5F33 (store-01, -03), #FFC700 (store-02), #14B6EF (store-05), #DB6FA3 (share card); assignment rule not observed | #FC5F33 for every memory; variation BLOCKED | white label fails on yellow (1.56) and blue (2.34); without the rule, one observed colour that passes (3.08) | resolved for shipping; variation open (capture: Timehop v5 recording) |
| M-10 | On-this-day progress bar | 2023 composite shows it (4.3 pt, #F7D23E on #93140A, full width); v5 marketing renders show none | kept from 2023 | only evidence of the day's position indicator; track vs banner 2.91:1 and fill vs banner 2.09:1 reported | open (same capture) |
| M-11 | Year story navigation | 2024 tap-through with progress segments vs 2025 vertical swipe pages | 2024 | docs/SURFACES.md / brief: "tap-through year story"; one fact per card | resolved |
| M-12 | Progress side inset | 11 pt (device recording) vs 16.7 / 17.7 / 14.9 pt (press renders) | 11 pt | the device recording is the product; renders are JPEG presentations (no lossless source either way) | resolved |
| M-13 | Chrome row centre | 48.3 pt (device, this pass) vs 42 pt (press B) | 48.3 pt; glyph height 14.9 pt from press B (not measurable on the device frame) | device over render | resolved |
| M-14 | Story type sizes | 2024: headline 31.6 / 36.4, subline 15.4 / 21.4; 2025: 25 / 30.9, 17 / 23.3 | 2024 | matches the chosen 2024 model (M-11) | resolved |
| M-15 | Story canvas colour | Wrapped per-chapter art and brand palette (#272727 / #EFEFEA in 2025) | `color.global.backgroundDeep` | brand colours / art not copied (research §1.3) | resolved |
| M-16 | Auto-advance | segment fill durations 11.29 s / 26.28 s are chapters of several beats; per-fact time not measurable | `duration.year.story.card` BLOCKED; tap-only; pause hidden | a chapter duration is not a card duration | BLOCKED (research capture 1) |
| M-17 | Reveal easing | 3 samples (0.125 / 0.725 / 0.925) of an S-curve | `easing.year.story.reveal` BLOCKED; durations and distances kept; everyone gets the Reduce Motion cross-fade until captured | fitting 3 samples is under-determined (same rule as F-15) | BLOCKED |
| M-18 | Sound toggle | Wrapped 2024 / 2025 have one | not built | the year story has no audio | resolved |
| M-19 | Photo and collage cards | Wrapped "Your top song": square art 0.66 of width, centre 0.412, text below; lists of 5 | photos fill the square (as album art); collages are fitted inside it; up to 5 per list (`count.year.story.listLength`), no rank numbers | album art is square by nature; cropping a collage would cut members out (tenet "Nothing gets lost") | resolved; which five everyone-days = owner decision |
| M-20 | Timehop features not built | share screen (SQUARE / FULL / THEN & NOW, Save, social targets), Then & Now, HIDE FROM, Timeskip, intro card, daily reminder push | not built | share: the day contains other members' photos and the product spec gives on-this-day no share; Then & Now: not in the product spec, "AND NOW" blue fails 2.34:1; hide: no API; Timeskip: premium perk; intro card: white date on yellow; reminder: not in the directive's push list (brief) | resolved; owner may revisit share / hide |
| M-21 | Tribute / VidDay features not built | gift-wrap unwrap, "Present Now", custom intro, music, Add to Calendar, countdowns, reminders, public submissions list, email collection, gift money | not built | wrap art and music are reference assets / timings not found; the rest is do-not-copy (research §2.5, §3.6, §4.5) | resolved |
| M-22 | Push copy keys | worker reads `notifications.push.birthdayRequest.{title,body}` and `notifications.push.tribute.{title,body}` (surface `notifications.push`, another pass) | this pass writes the texts as `birthday.request.push.*` and `birthday.tribute.push.*` (own surface prefix, no key collision) | brief: prefix keys with own surface ids | **hand-off**: the notifications.push pass should take these texts (same evidence) or the worker key map should point here |
| M-23 | Story text width | wrap width between 274 and 320 pt (widest line vs lines that did not fit) | 274 pt (`dimension.year.story.text.maxWidth`, lower bound) | the widest observed line is the only exact value | open (capture 1 at full resolution) |
| M-24 | Tap zones | Timehop "tap or swipe the right side / left side"; Wrapped press "tap the left or right of the screen" | halves | literal reading of both sources; widths not found | open (capture 1 / Timehop recording) |
| M-25 | Meta-row leading circle | Timehop shows the third-party source icon (Instagram) | the poster's avatar in the same slot and size | third-party icons are do-not-copy; in a group the source of a memory is the member who posted it | resolved |
| M-26 | Request page | Tribute legacy page (VERIFIED computed styles) vs Tribute current mockup and VidDay tour (SOURCED, ±1.5 pt) | legacy geometry; current page's due line placed under the title; VidDay's "Message Ideas" content in Tribute's prompts block | higher evidence level for sizes; content order shared by all three | resolved |
| M-27 | Stepper | Tribute: Info · Video · Photos · Done | Photo · Message · Done, same circle geometry and distribution | "Info" asks group members for name and email (do-not-copy); the second step is the one line | resolved |
| M-28 | Date formats | Tribute "Wednesday, December 31, 2025"; Wrapped "February 25" / "January"; Yope "26 May"; Timehop "TUE 10:34 PM" | each surface uses its own reference's format (`layout.birthday.request.dueDate`, `layout.year.story.dateFormat` / `.monthFormat`, `layout.birthday.add.dateFormat`, `onthisday.memory.meta`) | reference assigned to the surface | resolved |
| M-29 | Foundation roles where the surface reference has no measurement | on-this-day close button; entry rows on `groups.screen`; error / empty / loading layouts on every surface; birthday.add screen; tagging toggle; request close and own-contribution block; contribute photo grid (Yope wall grid) and selection check; tribute screen title / player width | `global.*` tokens by name, listed per element in each spec | `design/tokens/README.md`: foundations are app-wide (Yope is the app-wide reference); states without a reference string use the app default voice (`design/copy-patterns.md` map) | resolved; each listed as a gap where a capture could replace it |
| M-30 | Year-story card copy | Wrapped headlines carry consumption counts and ranks | group-level number only on "moments shared" (T3); most-reacted shown in order without numbers, ranks or reaction glyphs (T2); everyone-days celebrates the days without naming absences | tenet filters (design/copy-patterns.md) | resolved; T2 / T3 remain owner decisions |
| M-31 | Birthday opt-in at sign-up | `auth.agegate` pass puts an opt-in row under its birthday field (`auth.agegate.optIn.*`) vs a separate `birthday.add` onboarding step | the sign-up opt-in is the age-gate row; `birthday.add` is the later opt-in / manage screen opened from settings and reuses the age-gate date field | the birthdate from `confirm_age` is not stored, so the opt-in must happen on that screen; one owner per element | resolved |

### Problems found (for other passes)

- **Worker copy keys** (M-22): `notifications.push.birthdayRequest.*` / `notifications.push.tribute.*` are read by the
  worker; the texts live in `design/copy/memory.json` under `birthday.request.push.*` / `birthday.tribute.push.*`.
- **Worker is blocked by design** until research capture 5: `duration.birthday.tribute.photoHold`,
  `layout.birthday.tribute.caption`, `layout.birthday.tribute.endCard` and copy `birthday.tribute.endCard` are BLOCKED,
  so `tribute.render` fails with `MissingTokenError` and retries — no tribute is rendered with invented values.
- **Year story and tags:** `backend/worker/src/jobs/year.ts` does not read `post_tags`; tags currently feed only the
  birthday contribution picker.
- **Photo-library add permission** (tribute Download, year-story share sheet "save image"): one Info.plist key
  (`NSPhotoLibraryAddUsageDescription`) for the whole app — owned by `system.permissions`, not duplicated here.
- **Entry rows** for on-this-day, the year story and open birthday requests are placed by `groups.screen`; their copy
  keys are `onthisday.entry.title` + `onthisday.banner.yearsAgo.*`, `year.story.entry.*`, `birthday.request.title` +
  `birthday.request.due`.
- **Shared scratch space:** generator scripts under the session scratchpad `gen/` were overwritten by another pass
  running in parallel; the canonical memory files were already written and are the source of truth.

### Unresolved (owner, capture or verification)

M-1 (video aspect, owner), M-3 / photo hold / caption (research capture 5: one finished Tribute or VidDay with photos and
text on clips), M-9 / M-10 / M-24 (Timehop v5 15-20 s recording), M-16 / M-17 / M-23 / M-24 (Wrapped capture 1 + one
60 fps reveal), M-19 everyone-days selection (owner), M-20 share / hide on on-this-day (owner), M-22 (notifications pass),
docs/SPEC_FLAGS.md T2 / T3 / T5.

---

## Capture

Pass: capture group consolidation, 2026-10-15. Owns `design/tokens/capture.json` (133 tokens),
`design/copy/capture.json` (106 strings), `design/surfaces/{camera.capture, camera.sendto, camera.fromwidget,
widget.home.small, widget.home.medium, widget.home.large, widget.home.xl, widget.lock.rect, widget.lock.circular,
widget.lock.inline, widget.arrival, widget.android, daily.notification, daily.capture, daily.liveactivity,
daily.ongoing, daily.dualimage, collage.view, collage.share, notifications.push}.md` and this section. Inputs:
`design/research/{locket,yope-a,yope-b,bereal,platform}.md`, `docs/PLATFORM_CONSTRAINTS.md`,
`design/collage-options/README.md`, `design/proposals/{locket,bereal,yope-a,yope-b,platform,collage}.*.json`,
`backend/worker/COPY_KEYS.md` (push keys used exactly). `docs/WIDGET_REFRESH.md` does not exist.

### Evidence gathered in this pass

All pixel work on the original files (`python3 -I`, PIL + numpy); scales as documented by the research passes
(720-px Yope recordings 1.466 px/pt, 576-px 1.181 px/pt, BeReal TT 1.846 px/pt, BeReal H2 2 px/pt).

| what | source (coordinates) | used for |
|---|---|---|
| Yope camera: viewfinder bottom y937.5 (cols 150/550/600; col 360 is covered by the tooltip); shutter ring top y994; library thumbnail border peaks x165 / x232, y1018 / y1084, corner x172→165 over y1018→1025; flip centre x520; flash glyph bbox x106–121 y879–900; hour digits y531–557 centred on the viewfinder | `references/auto/yope/frames/a-jacob-7691153057177931039-t3.73-camera-hold-to-record.png` | `camera.capture.size.shutterTopGap` 38, `.sideControlOffset` 110, `.libraryThumb` 46, `.radius.libraryThumb` 8, `.layout.flashGlyph` |
| Yope coach tooltip: lime body y932–981 x226–495, pointer base x350–369 y982–991 (apex on the shutter centre), ✕ x461–474, text ascender 12 px / x-height 8 px | same frame | `camera.capture.layout.coach`, `fontSize.coach` 11 |
| Yope send-to: field x172–352 y438–482, mic x361–406, card x160–416 y159–500, placeholder x-height 9 px (near-white (254,251,238)), check circles x456–485 at y544–573 / 615–643, 'my wall' x-height 9 px, count disc x303–324 y931–952, button bottom y969 vs screen bottom y1019, header circle y72–123 | `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t6.73-sendto-voice-tooltip.png` | `camera.sendto.layout.*`, `.fontSize.*`, `.size.*` |
| Yope caption on the preview: x-height y458–470, ascender y453–470; overlay baseline y425 → caption baseline y470 | `references/auto/yope/frames/a-savannahclooney-7683341732695592206-t5.73-sendto-caption-keyboard.png` | `camera.sendto.fontSize.caption` 16, `.size.captionBaselineOffset` 31 |
| Yope toast: lime x66–509, y74–132, bottom corner x84/78/74/70/68 at y131/129/126/122/120 (r ≈ 24 px), glyph = black disc with a lime check cut out x89–109 y95–113, text x-height 9 px | `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png` | `camera.sendto.layout.toast`; C-12 |
| Yope loading HUD: x229–347 y467–584, corner x240→229 over y467→476, flat fill (12,12,12) / (13,13,13) | `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t50.60-loading-hud.png` | `collage.view.layout.hud`, `.color.hud`; C-13 |
| Yope day view: back circle y91–157, '26 May' digit '2' y115–131, page dots y188 shrinking toward the ends (native page control), first card top y218 | `references/auto/yope/frames/b-alexaa-7652512140875566349-t5.33-day-view-recap.png` | `collage.view.layout.screen`, `.fontSize.title` 16, C-22 |
| Yope share pill vs screen bottom: pill bottom y2459, bezel y≈2540 (col 610) | `references/auto/yope/frames/b-derot-store-04-rot-3.65.png` | `collage.share.layout.pill.bottomFromScreenBottom` 36 |
| Locket widget caption pill ≈ uniform gray (≈90) over light hair, matching #CC333333 over white (#5C5C5C) | `references/auto/locket/store/locket-store-03.png` crop x255–500 y1130–1230 | `widget.home.small.color.captionPill` |
| Locket `widget_empty.xml` decoded with androguard (72-dp circle, 82-dp ring, label = ImageView drawn in code, marginTop 9 dp); `bg_widget_empty` #FF2E2E2E→#FF1B1B1B; `bg_widget_empty_circle` #3DFFFFFF; `bg_widget_empty_circle_outline` 3 dp #FFFFB800; `ic_widget_empty_icon` 32×28 dp fill #FFFFFFFF; no label color resource among the public resources | Locket APK 1.243.0 (research extraction, not in repo) | `widget.home.small.layout.empty`, `.color.empty*`; `color.emptyLabel` BLOCKED |
| BeReal post preview 2024: SEND bbox x246–442 y1239–1291, triangle x463–498 y1247–1282, image bottom y1110; chip y1019–1087 x143–425, 'M' cap y1045–1061, glyph x172–203; prompt 'S' cap y683–705, spinner bottom y661 → text top y682 | `references/auto/bereal/frames/tiktok-bereal-7339559678604627233_t21.30s_preview-keep-smiling.png`, `…_t17.63s_black-spinner-prompt.png`; H2 SEND top y1447 vs image bottom y1311 | `daily.capture.layout.send`, `.fontSize.send` 40.5, `.layout.audienceChip`, `.fontSize.chip` 13, `.fontSize.prompt` 17 |
| HIG Live Activities and Widgets pages (DocC JSON, change log 2026-10-13), quoted rules for compact / minimal / expanded / Lock Screen presentations, colors, margins, vibrant rendering, Lock Screen widgets ('don't treat it as an additional way for people to launch into your app'), 'Avoid expanding a smaller widget's content to simply fill a larger area', 'show content quickly without hiding stale data behind placeholder content' | https://developer.apple.com/tutorials/data/design/human-interface-guidelines/live-activities.json, …/widgets.json | `daily.liveactivity.*`, `widget.lock.*`, widget states |

### Conflicts and resolutions

| # | topic | values and sources | resolution | rule / evidence | status |
|---|---|---|---|---|---|
| C-1 | Camera shutter and viewfinder | Yope: 80-pt lime ring, full-width 1:1.38 viewfinder r18.5 (2026 videos) vs Locket: 86-pt yellow ring, square viewfinder r49 (2026 store PNG) | Yope | both are assigned to `camera.capture`; Yope is the app-wide primary reference and the foundations already bind the camera to it (`radius.global.viewfinder`, `color.global.accent` "shutter ring"); Locket supplies only what Yope does not show (press motion, pressed disc, recording outline, video length) | resolved |
| C-2 | Camera top row | Locket avatar / '12 Friends' pill / chat button with a count badge vs Yope wordmark only | Yope; the wordmark slot stays empty (do-not-copy); Locket's friend count and badge are counts | assigned reference + tenets | resolved |
| C-3 | Camera background | Locket photo-tinted gradient vs Yope #000000 | `color.global.backgroundDeep` | C-1 | resolved |
| C-4 | Filters, zoom label, edit pencil | Yope camera filter carousel and '1x'; send-to pencil (Sep 2026) | not built | no filters / edits / zoom in the product ('one tap, no edits', yope-a §3.1) | resolved |
| C-5 | Send control | Locket round send button with spinner → ✓ states vs Yope 'send to...' sheet with lime 'send ⓝ' and a toast | Yope | multi-group selection is required by the spec; Yope's sheet is the multi-recipient pattern | resolved |
| C-6 | Widget overlay inset | Locket avatar 6 pt from the edges vs HIG 'standard margin … 16 points' | Locket (`contentMarginsDisabled`) | assigned reference for a non-system surface | resolved |
| C-7 | Empty-widget ring color | Locket #FFB800 (APK, exact) vs the app's lime `color.global.accent` | #FFB800 kept | assigned reference wins (as F-18) | **owner** may prefer the app accent |
| C-8 | Android caption style | APK text caption `bg_rounded` #4D000000 → white text 2.12:1 over a white photo (fails) vs APK `bg_overlay_caption_regular` #CC333333 capsule, padding 7 dp (6.71:1) | the capsule style on both platforms (it is also the iOS pill's geometry) | 'report it and look for a sourced alternative' | resolved |
| C-9 | Avatar ring | iOS 'subtle light ring' (≤2 px, not measurable) vs APK 1 dp #1A000000 | APK value on both | exact resource of the same element | resolved |
| C-10 | Daily invitation urgency | `backend/worker/src/push/payloads.ts` sends `time-sensitive` when Live Activities are off; `AppChannel.DailyInvitation` comment calls the iOS counterpart Time Sensitive vs copy-patterns tenet filter 'no TIME SENSITIVE interruption level', SPEC_FLAGS T4 | `active` (passive in quiet hours), `daily.notification.layout.delivery` | tenet 5 | **code change** (worker / android push) |
| C-11 | Android countdown promotion | `DailyInvitationNotifier` asks for a promoted ongoing notification vs Android Live Update criteria ('Don't allow activities triggered by other parties…') and PLATFORM_CONSTRAINTS §4.6 | standard, dismissible chronometer notification; promotion only after an explicit opt-in with Unpin | platform rule | **code change** |
| C-12 | Toast glyph | Foundations note on `icon.global.checkmark` ('bare check … in the posted-in-the-wall toast') vs the t7.73 crop: a black disc with a lime check cut out | `icon.global.check` (checkmark.circle.fill) in `color.global.onAccent` | lossless crop of the actual element | resolved (foundations note to update) |
| C-13 | HUD fill | yope-a ≈#262626 (median incl. glyphs) vs flat blocks (12,12,12) | #0C0C0C (±8, video) | flat-area sampling | resolved |
| C-14 | Daily viewfinder / preview corners | 2026 viewfinder r16 inset 3:4 vs 2023–24 full-bleed; dual image main r = 0.0455 × width (2023 lossless) | live viewfinder 2026; the preview (a dual image) uses `daily.dualimage` ratios | newest; preview = dual image | resolved |
| C-15 | Daily shutter | BeReal white ring vs Yope lime ring | BeReal | `daily.capture` is BeReal-assigned | resolved |
| C-16 | Recipient name | 14.5 pt bold measured vs `fontSize.global.headerTitle` 15 bold | role reused | equal within ±1.5 pt; no duplicate foundation value | resolved |
| C-17 | Send-to placeholder color | measured near-white vs `color.global.textSecondary` (composer placeholder) | `color.global.textPrimary` here | measured on this element | resolved |
| C-18 | Countdown at 00:00 | not observed in any BeReal source | hidden at `closes_at` (SPEC_FLAGS T4); exit uses the measured digit-out (100 ms) on the whole label | only measured exit motion of the countdown | approximation, flagged |
| C-19 | Lock Screen widgets | Locket has none; HIG vibrant rendering | circular = newest sender's avatar; rectangular = avatar + caption; inline = caption; the no-caption case BLOCKED | brief: compose from the small anatomy + HIG, else BLOCKED | partly BLOCKED |
| C-20 | Medium / large / xl | HIG 'Avoid expanding a smaller widget's content to simply fill a larger area' vs Locket's resizable Android widget keeping one layout at every size | Locket layout at every size | assigned reference | resolved, flagged |
| C-21 | Collage token names | worker reads `layout.collage.dualTile`, `layout.collage.optionB`, `color.collage.*`, `dimension.collage.share.storyCanvas` (proposal names) vs the brief's surface-id prefix | canonical `daily.dualimage.layout.composition`, `collage.view.layout.page`, `collage.share.layout.export` with identical values; the worker keeps reading the proposals | brief | **worker team** to switch names |
| C-22 | Page dots | Yope S6 day view (edge-shrinking dots = native page control) vs yope-a S1 lossless dots 7.6 / 15.5 / #F4F4F4 / #424242 | iOS native page control; Android draws the S1 dots | Yope uses the native control on this kind of screen; Android has none | resolved |
| C-23 | Collage bottom pill | S2 frosted 'share' pill (on a recap collage) vs S6 dark 'view recap' pill (day view) | S2 (the actual share pill over a collage); its frosted fill is BLOCKED | same element | partly BLOCKED |
| C-24 | Camera deep link | Android `DeepLink.Camera(groupId: String)` (required) vs iOS `.camera(groupID: String?)` | group optional (an unconfigured widget still opens the camera) | DeepLinkParser comment 'An unreadable group id still opens the camera' | **code change** (android model) |
| C-25 | Widget configuration copy keys | code literals `widget.configuration.title / .group / .group.type` (ios/Widgets/Sources/GroupSelection.swift) vs prefixed keys | `widget.home.small.configuration.title / .group / .groupType` | brief | **code change** (rename) |
| C-26 | Android ARGB colors | APK colors are #AARRGGBB; the canonical schema and `tools/designgen.mjs` read #RRGGBBAA | converted (#CC333333 → #333333CC etc.); the Locket proposal values are in the wrong order | CONVENTIONS §3 | resolved (proposal readers beware) |

### Owner decisions and open items

- C-7 widget ring color; default audience in send-to with no context (references preselect everyone — Locket
  'All Friends', Yope 'my wall' — built as all of the member's groups); the hold-to-record coach is shown only to
  members who can record video; a free member's first long press in a session opens the paywall and later long
  presses do nothing (one prompt per session, tap still captures); Android Lock Screen hub eligibility of the
  widget (opt out with `not_keyguard`); a `{app_name}` watermark on shared collages (none built);
  `AppChannel.YearStory` has no sent event (no channel copy).
- BLOCKED tokens (9) and their captures: see each surface's Gaps and `design/BLOCKED.md`.
- Contrast failures (no sourced alternative): flip circle vs black 1.27:1, Android inactive page dots
  (`color.global.controlRaised`) 2.12:1, empty-widget circle vs its background 2.16:1, avatar ring over white
  1.26:1, HUD vs black 1.07:1 (container edges; the glyphs and text on them pass); white overlay text on photos
  without a scrim is photo-dependent (`color.global.scrim` BLOCKED).

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

## Lead reconciliation

- **L-1 Birthday push texts.** The memory pass wrote `birthday.request.push.*` and `birthday.tribute.push.*`; the capture pass owns all push texts (`notifications.push.*`, the keys the worker sends per `backend/worker/COPY_KEYS.md`) and wrote the same events under `notifications.push.birthdayRequest.*` / `notifications.push.tribute.*` following the same patterns (P-BR-1, P-BT-1). The memory duplicates were never read by any code and were removed.

---

## Account (`auth.*`, `onboarding.permission.*`, `onboarding.widget`, `groups.list`, `groups.create`, `groups.invite`, `groups.screen`, `groups.settings`, `settings.*`, `safety.*`, `system.permissions`, `paywall`)

Pass: account consolidation, 2026-10-15. Owns `design/tokens/account.json` (171 tokens), `design/copy/account.json`
(350 strings), `design/surfaces/{auth.phone,auth.code,auth.agegate,auth.profile,onboarding.permission.camera,
onboarding.permission.notifications,onboarding.permission.photos,onboarding.permission.contacts,onboarding.widget,
groups.list,groups.create,groups.invite,groups.screen,groups.settings,settings.root,settings.notifications,
settings.account,settings.blocked,safety.report,safety.block,system.permissions,paywall}.md` and this section.
Inputs: `design/research/{yope-a,yope-b,locket,platform}.md`, `docs/PLATFORM_CONSTRAINTS.md`, the proposals
`design/proposals/{yope-a,locket,platform}.*.json`, `docs/API.md`.

### Evidence gathered in this pass

| what | source | method | used for |
|---|---|---|---|
| 2024 sign-up screen | `references/auto/yope/frames/a-yrrah-7454430216123862280-t6.73-signup-2024.png` (screen x50-525 = 476 px → 1.211 px/pt) | glyph heights; brightest-8 % glyph colour | `auth.phone.fontSize.subtitle` (14, italic), title 39-40 pt confirms the onboarding title role, footer text "by continuing you agree to our Terms of Use and Privacy Policy" (legible; yope-a had not used it) |
| 2024 "create new group" | `…a-yrrah-7452976839846382855-t3.73-create-new-group-empty-2024.png` | edge runs, corner fit, box medians | cover placeholder 330 × 221 r 7 (#494949), gaps 71 / 34 / 23 / 18 pt, disabled button #201D21 / #49464A, two-tone title |
| 2026 "new group" | `…a-itsmthuyope-7644974799302823175-t49.23-new-group-selected-create.png` | x-height / ascender | field text 15 pt bold, picker name 13.5 pt bold |
| 2026 group screen / profile / created state | `…-t43.73`, `-t51.73`, `-t51.23` | runs, corner fits | photo cards 378 × 152 r 20 gap 8.5; chat pill 88 × 51 #080808 15 bold; segmented control 41.5 / inset 4 / #111111 / 14.5 bold; profile avatar 92, name 25 bold; white pill r 11 |
| 2026 sign-in link, HUD label, home cover | `…a-virgi-…-t31.23`, `…-t50.60`, `…a-chuongxetank-…-t7.73` | x-height, cap height, column runs | lime link 14.5 bold; "Loading" 15 pt; cover header 205 pt |
| Locket welcome screen | `references/auto/locket/lazyweb/locket-lazyweb-20260821-cap-welcome.png` (@3x) | cap heights, runs, medians | `onboarding.widget.*` title 33 bold, steps 22 semibold #B8B6B2, CTA label 18 / #332500 / padding 18 / arrow gap 17 |
| Locket plan sheet | `…locket-lazyweb-20260803-cap-plan-picker.png` (@3x) | edge scans, circle fit, medians | sheet radius ≈46 pt + grabber 34 × 5 (= system sheet), sheet fill #292824 → #312C1F, title 24.5 / pitch 29, plan name 18, price 17, detail 15 #BFB598, cards #2C2922 / #3B3627, unselected height 58, Subscribe #F4BB40 / label 19 #302506 |
| Locket perk stack inner corners | `…locket-mobbin-paywall-screen.png` | corner fit at the card joins | `paywall.radius.perkInner` 6 |

### Conflicts and resolutions

| # | topic | values and sources | resolution | rule / evidence | status |
|---|---|---|---|---|---|
| A-1 | Paywall and onboarding.widget palette | Locket's measured Gold palette (black→dark-gold gradient, cream title, #FEB900 / #FFB800 yellow) vs the app-wide Yope lime/black foundations | Locket values as surface tokens (`paywall.color.*`, `onboarding.widget.color.*`) | SURFACES assigns Locket to both surfaces; tokens README: a surface adds tokens when its own reference measured differently | resolved by rule; **owner to confirm** (the gold/yellow is Locket's brand look; the alternative is the global lime/black mapping) |
| A-2 | Yearly plan price prominence | Locket: "$2.99/mo" big, "$36 per year" in the detail line | billed amount `{yearly_price}/yr` is the prominent price; the monthly equivalent moves to the detail line (`paywall.plans.yearly.*`) | App Store 3.1.2 / HIG IAP ("the billing amount … the most prominent pricing element") — a legal constraint, not a design choice | resolved |
| A-3 | Sign-up legal footer | 2026: gray, bold link phrases, 12 pt (V-virgi t31.23); 2024: lighter (#BFBDC0 core), white underlined links, ≈13-14 pt (S24) | 2026 (`auth.phone.layout.legalFooter`, global caption role) | 2026 beats older | resolved; footer weight stays F-24's open item |
| A-4 | `onboarding.widget` reference and voice | Locket (assigned) vs Yope's own widget pre-prompt (es, lime "añadir widget", "saltar") and Yope's English coach line "install widget for friends updates on your home screen" (V-arkadeep) | Locket layout and Sentence case | SURFACES assignment (F-18) | resolved; case change mid-onboarding flagged (F-18) |
| A-5 | Contacts ask on iOS | Yope: dismissible inline card ("can’t see your friends?" + ✕) vs HIG pre-alert rule (one button, no close) | iOS: no card, no onboarding screen — system `ContactAccessButton` (iOS 18) / `CNContactPickerViewController` (iOS 17) inside `groups.invite`; Android keeps Yope's card (Android requires a cancel) | PLATFORM_CONSTRAINTS Summary + platform §system.permissions | resolved |
| A-6 | `groups.screen` background (F-2) and card height | feed #171717 (store-01 lossless; 2026-05 group screen and created state, video 16/255) vs black (2026-06 S6 cards; 2026-10 1:1 space V-chuong t8.73); cards 152 pt (2026-05 group) vs ≈305 pt (2026-10 1:1) | feed = `color.global.background`, profile page = `backgroundDeep` (`groups.screen.layout.background`); cards from the 2026-05 group screen | lossless first; same surface type (group, not 1:1) | resolved for build; **capture** one lossless 2026-10 group screen to confirm |
| A-7 | White secondary pill corners | foundations map white pills to `radius.global.capsule`; this surface measures r ≈ 11 pt on a 45-pt pill (V-mthu t51.23; yope-a "≈10, not full pill") | `groups.screen.radius.lightPill` = 11 for pills on this group's surfaces | README: surface token when its own reference measured differently | resolved |
| A-8 | Native menu labels on `groups.screen` / `groups.settings` | copy-patterns: native menus use `platform.menuItem` (Title Case); Yope's observed native group menu uses lowercase ("share invite", "leave group", "report") | observed Yope menu items verbatim lowercase; unobserved native menus (member row, photo card, safety) use `platform.menuItem` | a verbatim string on the surface itself beats a pattern | resolved |
| A-9 | Pre-alert button | platform proposal "Continue" vs Yope "continue" | lowercase "continue" on the Yope-referenced pre-alert; HIG requires the term, not its case; "Continue" kept for the Android rationale dialog (system surface) | yope.voice.button + HIG | resolved |
| A-10 | Purpose strings | Yope fragments without period vs `platform.purposeString` | platform proposal texts (F-20) | system.permissions = HIG | resolved |
| A-11 | Group creation flow | 2026: name (optional) + friend picker, no cover/type; 2024-25: cover step; directive: name, cover, type; API: name required | 2026 sheet header, field and button; 2024 cover placeholder; Yope's segmented control (group profile) for the type; placeholder "name group" without "(optional)" | newest per element; the type step has no Yope source (approximation) | resolved with approximation; owner to confirm |
| A-12 | Android channel strings | copy-patterns maps `locket.push.channel` to both `settings.*` and `notifications.push`; the capture pass owns `notifications.push.channel.*` | this pass writes none and references the capture keys | lead note: push texts live under `notifications.push.*` | resolved; `AppChannel.YearStory` still has no string (capture pass) |
| A-13 | Safety titles in native dialogs | F-21: titles/explanations in Yope voice; `platform.alertTitle` would give "Block Sam?" | lowercase Yope titles ("block {first_name}?") in the block confirmation and report sheet; buttons/menus platform | F-21 | resolved |
| A-14 | `groups.settings` labels vs `settings.*` labels | groups.settings = Yope + HIG/M3 (Yope labels, lowercase); settings.* = HIG/M3 only (Title Case labels via `platform.menuItem`) | as stated | SURFACES assignments + copy-patterns surface map | resolved (two cases inside the app, by design of the references) |
| A-15 | Paywall CTA yellows | #FEB900 (paywall CTA, MB 2025-10) vs #F4BB40 (Subscribe, LZ 2026-08) vs #FFB800 (border, brand) | each kept for its own element | different elements, all measured | resolved |
| A-16 | Contrast of container fills | field #141414, card #181818, permission card #131313, HUD #262626, segment track #111111, chat pill #080808, cover #494949, perk card, unselected plan card vs their backgrounds: 1.05-2.33:1 | reported, not adjusted (no sourced alternative); every container carries text or a glyph that passes | rule: never adjust a sourced value | reported |

### Unresolved (owner, capture or verification)

- BLOCKED: `auth.phone.layout.countryCode`, `auth.phone.layout.inlineError` — one ~40 s English screen recording of a
  fresh Yope install up to the first camera screen, tapping "try other options" (entering one wrong code);
  `safety.block.duration.toast` — one 10-s recording until Yope's "posted in the wall" toast disappears;
  `groups.list.color.headerCircleOverPhoto` — one lossless screenshot of the 2026 Yope home with its cover photo;
  `paywall.layout.iconTileArt` — the app icon; `paywall.perk.history.emoji` — owner pick (perk hidden while history is
  unlimited); `safety.report.layout.reasons` — the moderation categories.
- Owner: A-1 palette, A-11 type step, `min_age_years`, tier name "Premium", tenet check of the paywall subtitle,
  support e-mail, legal URLs, invite domain, deletion-completion statement, shared-photo deletion vs "Nothing gets lost".

---

## Social (`chat.thread`, `chat.composer`, `chat.voice`, `chat.reactions`, `photo.viewer`, `walls.mine`, `walls.member`, `walls.browse`, `week.recap`, `week.edit`, `week.history`, `albums.list`, `albums.view`)

Pass: social consolidation, 2026-10-15. Owns `design/tokens/social.json`, `design/copy/social.json`, the 13
`design/surfaces/<id>.md` above and this section. Inputs: `design/research/yope-b.md` (primary), `yope-a.md`, `locket.md` §7,
`retro-timehop.md` §week.history, `platform.md`, the matching proposals, and (read-only, for reuse by name) the finished
`global`, `account`, `capture` and `memory` files.

### Evidence gathered in this pass

| what | source | used for |
|---|---|---|
| Lossless re-sample of yope-b's chat colours | `references/auto/yope/store/yope-store-05.png` rotated −1.68° about (621,1344) with **NEAREST** resampling (same geometry as `b-derot-store-05-rot-1.68.png`; mean difference to the bicubic copy 3/255, every pixel an original pixel) | S-2 |
| Reply-to-photo bubble geometry and type | `references/auto/yope/frames/b-yopeapp-7591560669967682847-t49.50-reply-to-photo.png`: lime corner circle fit 24.5 px; thumbnail mask x285–341 / y540–594; 'Gabriel' cap rows 549–562, x-height 553–562; 'pic' x-height 576–584; caption box 'Chloe' x323.75–458.75 / y1001–1062.5, text cap 1022–1041 (×0.744 pt/px) | `chat.thread.*reply*`, `chat.thread.*caption*` |
| Viewer header, photo frame, sender overlay, top-right chip slot, background | `…-t57.07-photo-viewer.png`: ✕ x139–157 / y163–181; ••• x559–592; title rows 155–174, date 185–197; photo x98–621 / y291–988; avatar row 333 x116.5–168.5; chip ink x428–589 / y326–345; background (300,240) etc. #1C191D | `photo.viewer.*` |
| Walls browser | `…-t116.00-me-and-friends.png`: title x-height rows 166–179; circles x230–312 / y232–311, centres 167…584; label baseline y342; wall top y380 | `walls.browse.*` |
| Profile 'pics' title → grid | `references/auto/yope/frames/b-presskit-profile.png` (exact @2x): 'pics' x-height rows 1306–1327, grid top 1374 | `walls.mine.dimension.titleToGrid` |
| Composer glyphs and text start | S1 nearest copy: camera glyph y2417–2460 / x240–293; mic glyph y2413–2462 / x941–975; placeholder ink from x367 | `chat.composer.dimension.*Glyph`, `.fieldPaddingLeading` |
| Home card avatar → name | `references/auto/yope/frames/a-savannahclooney-7683341732695592206-t6.73-home-list.png`: avatar right x207, name ink x229 (÷1.466) | `albums.list.dimension.coverToTitle` |
| Locket emoji-picker Popular grid | `references/auto/locket/frames/locket-tt-7460656081153445163-15.000s-emoji-picker-sheet-search-popular.jpg` crop x340–880 / y1040–1480 (28 of 30 cells legible) | `chat.reactions.layout.pickerPopular`, `.count.pickerColumns`, picker sizes (filmed, approximate) |
| Week-recap colours | `references/owner/yope-week-recap.jpg`: background #121011, header circle #0A0809, segment track #292526–#2B292A (JPEG ±6) | S-15 |

### Conflicts and resolutions

| # | topic | values and sources | resolution | rule / evidence | status |
|---|---|---|---|---|---|
| S-1 | Composer height (F-19) | 40.6 / 39.5 pt group chat (S1, lossless) vs 49–51 pt 1:1 space (S5, O4) | group-chat values | this product has groups only; S1 is the group-chat reference | resolved |
| S-2 | yope-b colours sampled on the bicubic copy | re-sampled on lossless pixels: their bubble #2B2B2B (confirmed); my bubble #232323 (confirmed, #222222→#242424); rims #414141 / #363636 (theirs), #393939 / #343434 (mine) vs yope-b #404040; **voice bubble #262626** vs yope-b #222222 (yope-b's column 400 y1903–1910 is the bubble's rim); play circle #333333 vs #313131; waveform #919191 (confirmed, plateau 145); **duration #929292** vs #949494 (plateau 146, bicubic max 161); mic circle median #414141 vs #3F3F3F → within ±2 of `color.global.controlRaised` (#434343), which is used; field rim #4B4B4B / #474747 (foundations) vs #535353; placeholder #969696 (F-3) vs #A3A3A3 | lossless values | lossless original beats an interpolated derivative (Foundations rule) | resolved |
| S-3 | Text-bubble corners | global: chat bubbles = `radius.global.capsule` (h/2 = 17.8) vs measured corner fit 16 (15.4–16.0) | `chat.thread.radius.bubble` 16 | the measurement itself; it also defines multi-line bubbles | resolved |
| S-4 | Reactions under chat photos | Yope: dark capsule (#2C2C2C, 24 pt) with emoji + reactor avatar under the photo (S1) vs Locket: overlapping emoji stickers on the photo, no numbers (AS-4) | Locket cluster in the thread and the viewer | SURFACES: `chat.reactions` = Locket | resolved |
| S-5 | Text part of a reply bubble | #444145 (S5, 1:1 space, video) vs the group chat's bubble fills #2B2B2B / #232323 (S1, lossless) | the sender's S1 bubble fill | same role (message text in a bubble); lossless + group-chat reference | resolved |
| S-6 | Message timestamps | S5 (1:1) shows "8:47 PM" beside a reply; S1 (group chat) shows none | none on text / voice bubbles; photo messages keep the time overlay | group-chat reference | open: S1 is a marketing mock (owner capture yope-b §14 #1) |
| S-7 | Reply to a photo with a photo | not observed | photo message with the lime quote part attached above | composition of two observed parts | flagged |
| S-8 | Caption position on a photo | Yope 1:1 cards: box left of centre by different amounts (S5 'Chloe', O4 'Best dayyy') — no consistent rule; Locket History: centred near the bottom | centred, Yope box styling (21 bold, 45.8 pt box, 13 corners) | `photo.viewer` = Yope + Locket; Locket's placement is the only consistent one | resolved; fill = `color.global.scrim` (BLOCKED) |
| S-9 | Emoji-rain layer | 2022 History: copies behind the photo card; 2023 reply sheet: over the photo | behind (History is the viewer's counterpart) | same kind of screen; values are from the 2022 build (flagged in every token) | resolved; current-build capture open |
| S-10 | Viewer reply row and quick reactions | Yope viewer row: sticker · field "message to Oblong" · camera; Yope 1:1 field holds ❤️ 😂 🔥; Locket History bar holds 🔥 💖 + add glyph | Yope row minus the sticker; Locket's 🔥 💖 + add inside the field's right end | reactions = Locket; the field / row = Yope | resolved |
| S-11 | What a wall looks like | Yope 2026 free-form 9:16 canvas (no observable rule) vs profile "pics" grid (S4, Jul 2026, lossless) vs 2-column grid of 9:16 wall thumbnails (S3 Play, rotated marketing render); background #000000 (S4) vs #171717 (S3) | every wall = the S4 3-column grid on `color.global.backgroundDeep`; canvas BLOCKED | the only fully specified layout; lossless, exact device render | flagged (owner capture yope-b §14 #3) |
| S-12 | "me & friends", "invite more friends" | verbatim Yope nouns vs family / roommates groups | kept verbatim | a noun swap needs the owner's member noun | owner decision |
| S-13 | `week.edit` | no Yope UI beyond release-note verbs | built from Yope components: sheet header (✕ + title), check circles, week pics grid, lime / dark button pair, "new group" name sheet; reorder and text placement BLOCKED; pencil circle on `week.recap` as the entry | brief: "build from documented Yope components and patterns where possible, else BLOCKED" | flagged |
| S-14 | `albums.list` / `albums.view` | no Yope album screen | home list card (V-sav) for albums; week pics grid + native ••• menu + name sheet for one album | same brief rule | flagged |
| S-15 | Recap presentation | O3 grid card (CAPTURED, ≈Jan 2026) vs 2026 "recaps are now walls" (free-form, unobservable); page dots 8 / 17.3 pt and #4B4B4B (O3, JPEG) vs 7.6 / 15.5 pt #424242 (S1 group header, lossless); O3 header circle #0A0809, background #121011, track #292526 (JPEG) | O3 grid card; dot size from O3 (its own screen), dot colour `color.global.controlRaised` (lossless, same role); circle `color.global.controlOnDeep`, background `color.global.background`, track `color.global.control` (each within the JPEG's ±6) | the only measurable recap; lossless colour for the same role | resolved; 2026 wall recaps open |
| S-16 | `week.history` colours | Retro measured light mode only (#FFFFFF, #000000, #999999, #F1F1F1, #D9D9D9); app is dark only (F-1); Retro dark mode seen only in a low-res photo (black background, dark-gray tiles) | text / background from global dark tokens (`backgroundDeep`, `textPrimary`, `textSecondary`); empty / add tile colours BLOCKED; Retro geometry, sizes, voice kept; a Yope back circle above Retro's display title (Retro's profile is a tab root) | appearance is app-wide (F-1); unmeasured dark values are not invented | flagged |
| S-17 | Viewer ••• labels | Yope's own native menu: lowercase "report" (2024) vs platform.menuItem "Report…" / "Block" used inside the safety flows (F-21, account group) | Yope lowercase on the viewer menu (`photo.viewer.menu.*`, `chat.thread.menu.*`); the safety sheets keep their own copy | `photo.viewer` is a Yope app surface; F-21 covers the safety surfaces | resolved |
| S-18 | Viewer background | #1C191D (S5 video) vs `color.global.background` #171717 | #1C191D (`photo.viewer.color.background`) | the same video renders the 1:1 sheet exactly #171717, so the viewer is genuinely lighter | resolved (±6/255) |
| S-19 | "I'm in this" | memory pass owns `tagging` (`tagging.toggle` etc., white capsule toggle placed by this pass) | the toggle sits in Yope's top-right chip slot on the viewer photo (where "✂ create sticker" is, do-not-build), measured `photo.viewer.dimension.actionTrailing` / `.actionCenterTop`; keys `tagging.*` reused, none defined here | brief + coordinator: reuse memory's keys | resolved |
| S-20 | Push texts | reaction / reply / recap-ready pushes | owned by the capture pass (`notifications.push.reaction.*`, `.reply.*`, `.recapReady.*`); this pass defines none | one owner per push (Lead L-1) | resolved |
| S-21 | Loading HUD, white pill, toast, permission card | duplicated measurements would collide with other groups | reused by name: `groups.create.size.hud` / `.color.hud` / `.fontSize.hudLabel` + `groups.create.hud.loading`; `groups.screen.size.lightPillHeight` / `.radius.lightPill`; `camera.sendto.layout.toast`; `onboarding.permission.contacts.*` card tokens; this pass adds only `chat.thread.radius.loadingHud` (BLOCKED) | single source per measured component | resolved |
| S-22 | Delete confirmation | Yope's not observed; HIG action sheet for intentional actions, M3 AlertDialog | platform component, Yope-voice text ("delete this pic?" / "it’ll be gone everywhere — …"), buttons lowercased ("delete", "cancel") | brief: confirmation in Yope's voice and must say it is removed everywhere | flagged (case of "cancel" vs HIG "Cancel") |

### Contrast failures (reported, not adjusted; no sourced alternative pair)

Non-text boundaries only (all text and glyph pairs pass): their / my bubble on #171717 1.27 / 1.14:1; bubble rim 1.76:1;
HUD 1.18:1; composer field 1.32:1 and its rim 2.06:1; mic circle 1.81:1; play circle on the voice bubble 1.20:1; voice bubble
1.18:1; viewer reply field 1.28:1 and camera circle 1.76:1 on #1C191D; recap header circle #101010 on #171717 1.06:1;
inactive page dot 1.81:1; album card on black 1.18:1. Lowest passing text pair: placeholder #969696 on #2E2E2E 4.59:1;
voice duration #929292 on #262626 4.86:1.

### Unresolved (owner, capture or verification)

S-6, S-7, S-11, S-12, S-13, S-14, S-16, S-22 and the 33 BLOCKED tokens in `design/tokens/social.json` (each names its
smallest capture in `notes`; summary in the surface specs' Gaps sections).

---

## Gap fill (social)

Pass: social gap fill, 2026-10-15, under the owner decision of the same day (`docs/OWNER_DECISIONS.md`: any successful app
may be a reference; each surface keeps its primary reference; every value still traces to evidence). Scope: the 33 BLOCKED
tokens of `design/tokens/social.json`. Result: **19 filled** (edited in place, same keys and types), **14 still BLOCKED**
with what was tried in each token's `notes`. Evidence files and their `INDEX.md` rows: `references/auto/{imessage,
apple-photos,google-photos,whatsapp,telegram,instagram}/` (new) and appended rows in `references/auto/{retro,yope,locket}/`.

Adaptation rules applied to every cross-app value: sizes are converted to a 393-pt screen (`pt = px ÷ display px × 393`;
mockups whose device is 402 pt say so); a colour is taken from another app only when the element's role matches, and then
mapped onto Yope's own global colour for that role (accent, selection, destructive, text); otherwise only layout, size or
timing is taken. Tenets: no counts are carried over (reaction counts, "Seen by", "N reactions" seen in the sources are
do-not-copy); no logos, names or glyph art were copied (glyphs are SF Symbols / Material icons matched to the reference).

### Evidence gathered in this pass

| what | source | used for |
|---|---|---|
| Retro dark appearance, raw @3x | Lazyweb public company page (3 of its 5 public Retro screens, 2025-10-20 and 2026-05-28): add tile and empty-day tiles all #262626, labels #515151, "+" #FFFFFF, background #000000 (lossless, std 0) | G-15 |
| Apple iPhone User Guide (iOS 27) + support article 118433 | Tapbacks (stack, attribution, remove by tapping the same Tapback; highlighted state in the image), audio messages (record / pause / send glyphs, record glyph inside the field), "Not Delivered" (red "!" + label, Try Again), Photos albums (custom order: touch and hold, drag; Albums grid image) | G-1, G-4, G-6, G-8, G-13, G-16, G-17 |
| WhatsApp Help Center (iOS, rendered) | react / remove reaction; send voice message (press and hold, release to send, slide to cancel, hands-free); play voice message | G-9, G-13 |
| App Store panels (2026 listings) | WhatsApp 26.40.77 (recording row; idle dark composer), Telegram 13.0 (recording row with lock; incoming text = incoming voice fill), Instagram 451.0.0 (composer inset), Google Photos 7.96.0 (renders Messages: empty vs filled field, wrapped bubbles) | G-1, G-5, G-6, G-7, G-9 |
| Telegram blog video "Flexible Playback Speed" | played vs unplayed bars, pause glyph, elapsed time while playing | G-8 |
| Locket TikToks (re-downloaded) | 2022 raw screen recording: 28 rain copies tracked in three path segments; 2025 filmed video: fly-to-cluster frames, cluster before / after | G-10, G-11, G-12 |
| Yope TikToks (re-downloaded) | HUD corner fit on 3 frames; viewer swipe boundary on 3 frames | G-3, G-14 |
| Press descriptions of emoji-only sizing | SlashGear 2023 (Messages: up to three), Xataka (WhatsApp: four or more = normal size) | G-2 |
| Yope press-kit profile (re-measured) | "pics" grid row 2 has two tiles under row 1's three | `walls.mine.layout.mosaic` notes (still BLOCKED) |

### Cross-app choices

| # | token | value | model app — why it is the right model | adaptation |
|---|---|---|---|---|
| G-1 | `chat.thread.dimension.bubbleMaxWidth` | 256 pt (0.652 × screen width) | Apple Messages: its iOS 27 group conversation has the same structure as Yope's thread (avatar column beside incoming runs, tail-less multi-line bubbles). Two images wrap at 64.7 % and 65.2 % of the display | % of display × 393; lower bound (+0/+11 %) |
| G-2 | `chat.thread.count.emojiOnlyMax` | 3 | Messages and WhatsApp agree (1–3 emoji enlarged, 4+ normal); Yope's own S1 shows the 3-emoji case enlarged | none (count) |
| G-3 | `chat.thread.radius.loadingHud` | 10.5 pt | Yope itself (3 video frames), not another app | px ÷ 1.181 (same scale as `groups.create.size.hud`) |
| G-4 | `chat.thread.layout.failedMessage` | trailing red "!" circle 22 pt, 14 pt from the bubble; red label under it; tap retries | Messages: Apple documents the state and its retry; Yope has no observed failed state | sizes ÷ 1.468 px/pt (402-pt device); red = `color.global.destructive` (same systemRed, error role); label = existing copy `chat.thread.sendFailed`, text role `caption` (12 pt vs 11 ± 1 measured); one-tap retry instead of Messages' two-item menu because the existing copy names one action |
| G-5 | `chat.composer.dimension.bottomInset` | 8 pt above the bottom safe area | WhatsApp (round controls beside the field, as in Yope) and Instagram agree within 0.3 pt; Messages iOS 26/27 sits inside the safe area (26 pt from the screen bottom) and was not used | (px ÷ display px × 393) − 34 pt; keyboard-up gap not measured: the same value is used against the keyboard (platform safe area), flagged |
| G-6 | `chat.composer.layout.typingState` | mic circle swaps in place to a send circle while the field has text | Messages (empty vs filled states of the same composer, same slot and diameter); WhatsApp documents the idle mic beside the field | fill = `color.global.accent` + `color.global.onAccent` (the references fill send with their accent; Yope's composer camera circle already uses this pair); glyph `icon.global.send` |
| G-7 | `chat.voice.color.bubbleTheirs` | #2B2B2B | Telegram (incoming poll and incoming voice bubble both #2D2135) and Yope's own pair (voice #262626 vs text #232323) show the rule "voice bubble = sender's text bubble" | value = Yope's `chat.thread.color.bubbleTheirs`; no Telegram colour used |
| G-8 | `chat.voice.color.waveformPlayed`, `chat.voice.icon.pause` | #FFFFFF; `pause.fill` / `Rounded.Pause` | Telegram's playback (played = full-opacity colour, unplayed = same colour at ≈30 %); Messages / WhatsApp / Telegram all show a pause glyph in the play circle while playing | Yope's unplayed bars are white at 49 % over the bubble, so full opacity = #FFFFFF; glyph = SF Symbol / Material match (filled, as `icon.global.play`) |
| G-9 | `chat.voice.layout.recording` | hold to record, release to send, slide left to cancel, slide up to lock; row: red dot · timer · hint, mic under the finger | WhatsApp (documented gestures) + Telegram (same row in its 2026 panel): the two most used voice-message composers, both with Yope's mic-beside-field structure | red dot = `color.global.destructive`; timer = `chat.voice.layout.durationFormat` (Yope's own format) in `textPrimary`; hint in `textSecondary`; **hint string missing from design/copy** (verbatim reference "slide to cancel") — this pass may not add copy |
| G-10 | `chat.reactions.layout.clusterOrder` | newest distinct emoji first; earlier ones shift one step trailing | Locket itself (the surface's reference), 2025 video | none |
| G-11 | `chat.reactions.easing.rain` | easeInOut | Locket itself, 2022 raw recording: 49.8 → 74.6 → 52–56 px/frame across three segments (28 copies) | preset with the measured slow–fast–slow shape; control points not fitted |
| G-12 | `chat.reactions.duration.flyToCluster` | 300 ms | Locket itself, 2025 video (9 frames at 30 fps, decelerating) | none |
| G-13 | `chat.reactions.layout.unreact` | your reactions are highlighted in the picker; tap one to remove it | Messages and WhatsApp document the same rule in first-party help | highlight = `color.global.selection` (Messages' selected Tapback circle is its system blue; Yope's selection colour is iOS system blue — same role); several highlights because this product allows several emoji per person |
| G-14 | `photo.viewer.dimension.pageGap` | 0 pt | Yope itself: on three mid-swipe frames the straight edges touch (≤1 px); the "thin dark gap" was the rounded corners | none |
| G-15 | `week.history.color.emptyTile`, `.emptyTileText` | #262626, #515151 | Retro itself (the surface's reference) in its dark appearance, three lossless captures | `emptyTileText` now covers the labels only; the "+" uses `color.global.textPrimary` (#FFFFFF in Retro dark). Contrast 1.92:1 for the labels — reported, not adjusted (Retro's light pair also fails) |
| G-16 | `week.edit.layout.reorder` | touch and hold a checked tile, drag to a new position | Apple Photos (custom-order albums) and Google Photos (albums: "re-order … by dragging") — the two photo apps with user-ordered photo sets | haptics = existing `week.edit.haptic.*` |
| G-17 | `albums.list.layout.yopeAlbums` | 2-column grid of square covers (168 pt, gap 12.4, margins 23, corners 18.5), name over the bottom-leading corner (15 pt, inset 14 / baseline 17) | Apple Photos' Albums collection (iOS 27): the most used album list; Yope shows no album screen | sizes ÷ 1.132 px/pt; name in `color.global.textPrimary`, background `color.global.backgroundDeep`; subtitle moves to the accessibility label (the reference shows the name only); name legibility treatment not measurable (flagged) |

### Problems found (for other passes)

- **Account group, HUD fill.** On the HUD frames (t50.40–50.60) the HUD interior reads ≈#0C0C0C over black;
  `groups.create.color.hud` (#262626) was sampled on a box that includes the spinner and the "Loading" label. Not changed
  here (not this group's token).
- **Copy owner.** `chat.voice.layout.recording` needs a hint string (verbatim reference: WhatsApp "slide to cancel");
  `chat.reactions.layout.unreact` and `week.edit.layout.reorder` need no new strings.
- **Contrast.** `week.history.color.emptyTileText` on `week.history.color.emptyTile` is 1.92:1 (text) — reported per the
  Foundations rule (a sourced value is not adjusted). Album names on cover photos (G-17) have no fixed backdrop.

### Still BLOCKED (14)

`chat.voice.layout.widthRule`, `chat.reactions.count.clusterMaxVisible`, `chat.reactions.layout.activitySheet`,
`photo.viewer.layout.voiceNote`, `walls.mine.layout.mosaic` (narrowed: row 2 has two tiles), `walls.mine.layout.freeformWall`,
`walls.browse.layout.rowOrder`, `walls.browse.layout.selection`, `week.recap.layout.shortRowSplit`,
`week.recap.dimension.shortRowHeight`, `week.recap.layout.scrim`, `week.recap.layout.page2`, `week.edit.layout.recapText`,
`week.history.layout.weekMenu`. Each token's `notes` says what was tried and the smallest capture that closes it.

---

## Gap fill (account, capture, global, memory)

Pass: account / capture / global / memory gap fill, 2026-10-15, under the owner decision of the same day
(`docs/OWNER_DECISIONS.md`). Scope: the 26 BLOCKED tokens of `design/tokens/{global,account,capture,memory}.json` and the
BLOCKED copy `birthday.tribute.endCard`. Result: **24 tokens filled** in place (same keys, same types; null → value),
**2 still BLOCKED** (`paywall.layout.iconTileArt`, `safety.report.layout.reasons`), copy `birthday.tribute.endCard` sourced,
one token added (`easing.year.story.reveal.subline`), one copy key added (`auth.phone.error.dismiss`), and one coordinator
correction (`groups.create.color.hud`, G2-27). Evidence files and `INDEX.md` rows: `references/auto/locket/apk/` (new),
`references/auto/{vidday,tribute,platform,yope,wrapped,bereal}/`.

Rules applied: each surface keeps its primary reference; another app fills only what the primary does not show; sizes in
pt are taken as-is (source constants) or converted to a 393-pt screen; a colour is taken from another app only when the
element's role matches (dimming behind a sheet, row divider, translucent control over a photo), otherwise the app's global
colour for the role is kept (G2-12). Translucent fills over photos were solved from the primary app's own frames where
possible (Yope, BeReal), with the solve model stated. No logos, names, fonts or assets were copied (the SF Pro web font
was used only to measure, and is not stored).

### Evidence gathered in this pass

| what | source | used for |
|---|---|---|
| Locket Android 1.243.0 JS bundle (Hermes, decompiled) — **withdrawn as evidence** by owner decision 22; the values it gave were re-sourced or replaced (OD22-*) | `references/auto/locket/apk/locket-1.243.0-hermes-excerpts.txt` | G2-1, G2-2, G2-4, G2-5, G2-7, G2-8, G2-9, G2-11 |
| VidDay help: photos and text cards 4 s by default; text cards 110 characters | `references/auto/vidday/help/*.png` (both updated 07.02.2025) | G2-18, G2-21, G2-22 |
| VidDay birthday theme sample render (1080p30, 135.7 s): title card, photo slots, 0.7-s crossfades, end text card "We Love You!" | `references/auto/vidday/frames/vidday-theme-happy-birthday-*` | G2-17, G2-18, G2-22, G2-23, G2-25 |
| Tribute video editor: name badge (default ↙ / Dark) and caption styles, computed | `references/auto/tribute/web/tribute-web-video-editor-name-badge*` | G2-24 |
| Yope TikTok re-downloaded at 1080×1920 60 fps (home cover header circle; toast entrance) | `references/auto/yope/frames/a-chuongxetank-…-1080p-*` | G2-6, G2-7 |
| AOSP toast constants; React Navigation iOS modal spring | `references/auto/platform/aosp-toast-duration-excerpt.txt`, `react-navigation-ios-modal-spring-excerpt.txt` | G2-3, G2-7 |
| SF Pro Display '1' stem ratios per weight vs BeReal's countdown | `references/auto/platform/sf-pro-display-digit-one-stem-ratio.csv` | G2-14 |
| Wrapped reveal positions refitted (all 25 / 19 samples); summary dots measured | `references/auto/wrapped/frames/wrapped24-rec-emilycraig-reveal-fit.csv`; press render | G2-19, G2-20 |
| Searched, not found / not usable | Instagram story photo duration (only third-party guides; Meta's ads guide: 5–16 s for ads); Instagram App Store preview (no story player); Timehop video (App Store none, Play = YouTube, bot-blocked); BeReal / Locket Lock Screen widget (none found); Locket empty-widget label colour (bitmap drawn at run time; no resource / JS style found); Tribute photo duration (undocumented) | — |

### Cross-app choices

| # | token | value | model app — why it is the right model | adaptation / precision |
|---|---|---|---|---|
| G2-1 | `color.global.separator` | #FFFFFF33, hairline | Locket: a dark-only photo app on black (like Yope's deep surfaces) dividing grouped-list rows; Yope itself draws no dividers | source constant (white 0.2, `hairlineWidth`); exact |
| G2-2 | `color.global.scrim` | #00000080 | Locket's sheets: gorhom backdrop black at `SEE_THROUGH` 0.5 — the dimming behind a sheet in the closest dark photo app; Yope's sheets are full black | exact |
| G2-3 | `spring.global.sheetPresent` | response 0.3441, dampingFraction 4.564 | the iOS modal sheet, as documented by React Navigation (`ModalPresentationIOS` → `TransitionIOSSpec` k1000 c500 m3, shipped in Locket) | exact conversion; **conflict**: Yope's observed 16-pt overshoot (`spring.global.sheetPresentObserved`) — closes F-15 toward the native curve |
| G2-4 | `auth.phone.layout.countryCode` | flag slot 20×13 at 20 pt + inline calling code, auto-formatted, flag opens a country list | Locket's phone-first sign-up (same app category); Yope's phone screen never filmed | field geometry/colours stay Yope's; flag art = regional-indicator emoji (PLATFORM); single source |
| G2-5 | `auth.phone.layout.inlineError` + copy `auth.phone.error.dismiss` "OK" | native alert, message only, one "OK", not cancelable | Locket: phone / code errors are `{title, message}` shown through `Alert.alert(…, [{text:'OK'}], {cancelable:false})` | our errors are one sentence → no title; call site inferred (not traced); button in platform case (A-13) |
| G2-6 | `groups.list.color.headerCircleOverPhoto` | #00000094 (black 0.58) | Yope itself (2026 home, 1080p frame) | ±0.06 alpha; blur not measured |
| G2-7 | `safety.block.duration.toast`, `camera.sendto.duration.toastVisible` | 2000 ms | Locket's confirmation after a safety action ("Photo reported") is `ToastAndroid.SHORT` = AOSP `SHORT_DELAY` 2000; Yope's own dwell is cut by the only video's edit (≥0.57 s) | exact; Yope entrance ≈117 ms recorded in notes |
| G2-8 | `safety.report.layout.reasons` | still BLOCKED | presentation sourced: Locket reports friends' content without a reason list (alert "Report?" + explanation, then a SHORT toast) | categories = owner |
| G2-9 | `camera.capture.size.recordingOutline` | 6 pt | Locket itself (co-reference of `camera.capture`): `BorderProgressBar` default, a progress stroke filling linearly over the max video length | exact |
| G2-10 | `camera.sendto.color.messageField` | #0000007A (black 0.48) | Yope itself: three channels agree only for a black tint (0.44/0.46/0.48; 0.50/0.52) | ±0.05; blur radius not measured |
| G2-11 | `camera.sendto.size.captionMaxLength` | 36 | Locket (co-reference of `camera.sendto`): the one-line caption's `MAX_CHARS` (200 / 4 lines is the Gold perk) | exact |
| G2-12 | `widget.home.small.color.emptyLabel` | #969696 | Locket's colour is unrecoverable → rule: keep Yope's global colour for the role (secondary text on a dark tile) | 4.59:1 on #2E2E2E |
| G2-13 | `widget.lock.rect.layout.content` | no caption: avatar alone (rect) / a11y sentence (inline); collage newest: keep the newest single photo's sender | Locket's own no-caption widget (store-06) and one-photo rule; no app with such a Lock Screen widget found | composition, flagged for the owner |
| G2-14 | `daily.capture.fontWeight.countdown` | bold | BeReal (primary): stem ÷ height 0.205 vs SF Pro Display Bold 0.207 (Semibold 0.175, Heavy 0.253) | closes the capture pass's stated step |
| G2-15 | `daily.capture.color.overlayControl` | #00000075 (black 0.46) | BeReal itself, lossless help frame over a flat sky (retake ✕ and chip) | ±0.06 |
| G2-16 | `collage.share.color.pill` | #9A9489A8 | Yope itself: the pill spans a light and a dark backdrop on the lossless store PNG → two-background solve | tint ±8, alpha ±0.08; **white label on it over white: 1.98:1 FAIL** (as Yope draws it) |
| G2-17 | `duration.onthisday.memoryChange` | 700 ms | VidDay's memory montage: photo-to-photo crossfade (7 transitions, 21–22 frames); Timehop's own unobtainable | ±33 ms; curve native |
| G2-18 | `duration.year.story.card` | 4000 ms | VidDay documents 4 s per photo / text card and its render shows 4.0-s slots; Wrapped's per-fact time is not measurable; Instagram's ≈5 s is third-party only | exact (documented) |
| G2-19 | `easing.year.story.reveal` (headline) + new `easing.year.story.reveal.subline` | (0.56, 0.08, 0.14, 0.87); (0.05, 0.36, 0.26, 0.94) | Wrapped itself: the existing CSV has 25 / 19 samples, not 3; a 4-parameter fit is determined (0.5-px residual); no single curve fits both | ±0.05 per control point |
| G2-20 | `layout.year.story.summary.dots` | one per card, 8.4 pt, pitch 16.8, #FFFFFF / #666666, 20.4 pt below the card, 29.3 pt above Share | Wrapped itself (the press render the BLOCKED note cited) | ±0.9 pt (JPEG) |
| G2-21 | `layout.birthday.contribute.lineMax` | `{maxCharacters: 110}` | VidDay's written-message text card limit (same role as the one line) | exact; API 280 stays |
| G2-22 | `duration.birthday.tribute.photoHold` | 4000 ms | VidDay (assigned reference): documented default + 4.0-s slots in its render; Tribute's value undocumented | exact; our cards hard-cut, so the whole slot is visible |
| G2-23 | `layout.birthday.tribute.endCard` | = `layout.birthday.tribute.titleCard` values | VidDay draws its end text card exactly like its title card (same colour, 65-px caps, centring) | colours kept from the title card so both cards match (M-4) |
| G2-24 | `layout.birthday.tribute.caption` | white; name 700 @ 0.0463 H; line 700 @ 0.0795 H; left 0.0577 W; bottom 0.0861 H; max width 0.8845 W; gap 0.0099 H; band #11202FC7 | Tribute's own contributor credit (name badge default bottom-left / Dark) + its Classic caption text | badge box → full-width band (worker shape); white on band 17.7:1 / 8.1:1 |
| G2-25 | copy `birthday.tribute.endCard` | "We love you!" | VidDay's end card text, case normalised by P-BT-1 (replaces "From {group}", which came from a cover attribution) | `{group}` no longer used |
| G2-26 | `paywall.layout.iconTileArt` | still BLOCKED | owner asset (the app icon) | — |
| G2-27 | `groups.create.color.hud` (coordinator request) | #262626 → **#0C0C0C** | Yope itself: on t50.40 / t50.53 / t50.60 every flat block of the HUD reads (12,12,12)–(13,13,13), interior luma mode 12; the old bbox x254–322 y488–562 also reads 12–13 (its recorded (38,38,38) is not reproducible) | now equal to `collage.view.color.hud` (C-13); ±8/255 (H.264); white label 19.6:1; container vs #000000 1.07:1, vs #171717 1.09:1 |

### Problems found (for other passes)

- **Worker tests (worker team).** Now that the tribute tokens exist, three assertions that expect them to be missing fail:
  `test/unit/copy-tokens.test.ts:49` (uses `duration.birthday.tribute.photoHold` as its BLOCKED example — switch to
  `paywall.layout.iconTileArt`), `test/unit/media-render.test.ts:95-97` and `test/handlers/tribute-year.test.ts`
  ("fails … while the research values are absent"). `backend/worker/COPY_KEYS.md` still lists `photoHold`, `endCard`,
  `caption` as missing. A real render with these tokens was checked (contribution cards over a bright and a dark photo,
  end card): no errors.
- **Worker shape.** `CaptionLayout` can only draw a full-width band; Tribute draws a rounded box around the name
  (radius 10 / 302 of the frame height, padding 9 × 14 px of 302 / 537) and a soft text shadow under caption words. A box
  mode would match the reference exactly.
- **Timings not in scope, recorded for the memory owner.** VidDay crossfades photo → photo in 0.70–0.73 s (Tribute's hard
  cut is kept, M-6), its title → first photo fade in this render is 0.73 s (canonical `titleCrossfade` 600 ms, from the
  tour), and it holds its end text card for a 4-s slot (canonical `endHold` 10 003 ms, Tribute's brand-outro slot). Not changed.
- **Stale text outside this pass's files.** `design/tokens/README.md` ("Not available yet": separator, scrim, sheet spring
  still listed as BLOCKED; scrim/separator rows in the colour table); `design/surfaces/chat.thread.md:162-163` and
  `design/CONTRAST.md` quote the HUD as #262626 (now #0C0C0C: white 19.6:1, container 1.09:1 on #171717).
- **Screens.** `MemoryBlocked.swift` / `MemoryBlocked.kt` accessors can now return the tokens (card duration, reveal easing
  — note the new `.subline` curve —, summary dots, memory change, line max, toast dwell). Release builds that referenced
  `BlockedTokens.*` for these names move to `Tokens.*` (same identifiers).
- **Contrast (reported, not adjusted).** White on the share pill over a white collage 1.98:1; white text on the send-to
  field over a white photo 3.69:1 (placeholder 16-17 pt regular needs 4.5:1); BeReal chip text on its fill over white
  3.45:1; separator 1.66:1 on black (decorative).

### Still BLOCKED (2)

`paywall.layout.iconTileArt` (the app icon, owner) and `safety.report.layout.reasons` (moderation categories, owner;
presentation now sourced, G2-8).

## Lead reconciliation (continued)

**L-2 — `spring.global.sheetPresent` dampingFraction 4.564 → 1.0.** The gap fill converted React
Navigation's `TransitionIOSSpec` (stiffness 1000, damping 500, mass 3) literally, giving a damping
ratio of 4.564. React Native's `SpringAnimation.js` has no overdamped solver: for every ratio ≥ 1 it
runs the critically damped solution (`if (zeta < 1) { … } else { // Critically damped … }`, checked
in react-native main on 2026-10-15). The motion Locket actually shows is therefore response 0.3441 s
with dampingFraction 1.0, settling in about 0.4 s; 4.564 in SwiftUI / Compose would be a much slower
overdamped curve (about 90 % after 1.1 s). Found by the Android capture pass; value changed, evidence
unchanged.

---

## Redesign — Foundations (R-*)

Pass: redesign Pass 1 (Foundations), 2026-10-15 — docs/REDESIGN_BRIEF.md. Owns `design/tokens/global.json`
(259 tokens: 182 SOURCED, 70 PLATFORM, 7 VERIFIED, 0 BLOCKED — surfaces `global` / `global.system`),
`design/tokens/README.md`, `design/components.md` (new), `design/copy-patterns.md`, `tools/contrast.mjs`,
`design/CONTRAST.md`, `docs/SURFACES.md`, `docs/OWNER_SETUP.md` §0 item 6, the Inter font in
`android/core/designsystem/` and this section. Inputs: `design/research/retro-visual.md`,
`design/research/retro-package-copy-motion.md`, `references/auto/retro/` (INDEX.md); platform values carried over
from the Foundations section above. Rule: Retro is the reference for every visual value and the copy voice;
between two Retro measurements RAW beats render, exact constants beat image readings, newer beats older.

### Evidence gathered in this pass

| what | source | used for |
|---|---|---|
| Apple editorial video of story id1888002859 (HLS, 1080×1350, 30 fps, 40.47 s; mp4 SHA-256 `0d544f8e…660de`, deleted) | `references/auto/retro/video/apple-editorial-1888002859-retro-segment-t31.5-37.5-10fps.png` (INDEX row) | R-14: the Retro part is a montage of the static App Store renders (pans / zooms with ease-out, 0.5–0.9 s); **no in-app motion** to measure |
| Page dots, dark | `press/tc-2023-12-recaps.png` phone 2: dots x1360–1417 y1470–1478, active (255,255,255), inactive (128,128,128) on (0,0,0); 10 px Ø, 16.3 px pitch; screen x1056–1722 = 666 px ÷ 393 = 1.695 px/pt | `color.global.pageDotInactive` dark, `size.global.pageDot`, `.pageDotPitch` |
| Pushed header, search field | `store/editorial/…-1854931006-week3-albums.png`: chevron ink x1891–1933 y388–458 (11.1 × 18.3 pt, left ink 21.1 pt); title ink from x1991 (gap 14.6 pt); "Search" 'S' rows 635–681, 'e' 647–681 (17.1 / 17.4 pt); magnifier rows 632–684 | `size.global.backInset`, `.headerGap`, text role `placeholder` (17) |
| Viewer in light appearance; disabled capsule | `press/tc-2023-12-retro3.png`: phone 1 black viewer under a white sheet, phone 3 light modal + light keyboard; phone 2 disabled "Send Postcard" fill (77,77,77) (47,057 px), label (0,0,0) (814 px) | `color.global.backgroundDeep` role, `layout.global.appearance.media`, `color.global.controlRaised`, components C-05 |
| Viewer comment field and avatars | `press/tc-2023-07-retro-2b.jpg`: field rows 1821–1934 (48 pt), TL corner circle fit 27.9 px → 12.1 pt (residual 7.3); comment avatar x1356–1423 (29.6 pt); field avatar x1377–1446 (30.5 pt); header avatar x1345–1434 (39.2 pt) | `radius.global.commentField`, `size.global.avatarComment`, `.avatarHeader` |
| Alphas solved from RWA pairs | `press/tc-2025-12-rewind-device-a.png`: glass inside #8D8376 vs outside #7D7263 → white 0.123 / 0.121 / 0.122; inactive tab #B2AFAC over #322C25 → white 0.62 per channel | `color.global.glass` (#FFFFFF1F), `color.global.tabInactiveOnMedia` (#FFFFFF9E) |
| Material 3 baseline light scheme | androidx-main `compose/material3/…/tokens/ColorLightTokens.kt` + `PaletteTokens.kt` (v0_210, fetched 2026-10-15): SurfaceContainerHigh Neutral92 (236,230,240), SurfaceContainerLow Neutral96 (247,242,250), OnSurfaceVariant NeutralVariant30 (73,69,79), Outline NeutralVariant50 (121,116,126) | `color.global.system.*` light values |
| Compose icon names | `material-icons-extended-android` / `-core-android` 1.7.8 classes.jar from the Gradle cache: all 48 Android icon names in `global.json` exist (incl. `AutoMirrored.Rounded.ArrowBackIos`, `AutoMirrored.Outlined.MenuBook`, `Outlined.History`, `Outlined.Casino`, `Outlined.LibraryAdd`) | `icon.global.*` |
| Inter Variable for Android | rsms/inter git tag `v4.1` (commit e3a3d4c, 2024-11-15), `docs/font-files/InterVariable.woff2` (SHA-256 `693b77d4…429a8e3`) converted to TTF with fontTools 4.67 (container change only) → `android/core/designsystem/src/main/res/font/inter.ttf` (SHA-256 `27b6b7cb…af65c8`): family "Inter Variable", "Version 4.001;git-9221beed3", axes opsz 14–32 / wght 100–900, fsType 0 — the same file Retro bundles (`inter_variable.ttf`, RP §2.2). Licence `LICENSE.txt` of the same tag → `android/core/designsystem/licenses/Inter-OFL.txt` (SIL OFL 1.1). The GitHub release asset itself was unreachable from this session (github.com 403 for release downloads); the git tag is the same build | `font.global.family` android "Inter" |
| Android compile | `./gradlew --offline compileDebugKotlin` after generation: errors only in `core:ui` (removed tab-bar / overlay tokens; themed colours read outside composition) — downstream modules not reached; the rest found by read-only scan (README "Compile impact") | "Problems found" below |

### Conflicts and resolutions

| # | topic | values and sources | resolution | rule / evidence | status |
|---|---|---|---|---|---|
| R-1 | Appearance | Foundations F-1 "dark only" (Yope) vs Retro in both appearances (ST-01/02, ED-A/W3, JED light; H43, H22, LAND, ENG-D dark) | Follow the system setting (`layout.global.appearance`); media surfaces (viewer, camera, composer-on-photo, recap preview, full-bleed photos) black in both | owner decision 2026-10-15; TC-R3 phone 1 shows the viewer black under a white sheet | resolved |
| R-2 | "Accent" | Researchers call #EA3337 the "accent red"; the token `color.global.accent` (56 code sites) is the primary action fill | `color.global.accent` = Retro's primary fill (#000000 / #FFFFFF) with `onAccent` the inverse; the red is `color.global.badge` + `color.global.destructive` (+ `color.global.system.error`) | keep a name when its role is unchanged (brief); Retro has no brand colour in chrome (RV §3.2) | resolved |
| R-3 | Dark page per platform | iOS #000000 in every capture vs Android default #1C1C1E (APK `d42.v`, values-night splash), "true black" #000000 as an Android option | Two tokens: `color.global.background` (iOS) and `color.global.background.android`; our Android uses Retro's default; the true-black option is offered in Android Settings since owner decision 21 (`color.global.background.android.trueBlack`, OD21-*) | Retro differs per platform → per-platform values (brief) | resolved; option added (OD21) |
| R-4 | Grouped rows / chips fill | APK `vv3.l` #F7F7F7 (18 call sites: chips, rows, reply bar, sheet cards) vs iOS stills: every fill #F1F1F1, settings frame ≈#F2F2F2 (±6, magenta-shifted) | iOS rows = `color.global.control` (#F1F1F1); Android rows / chips = `color.global.surfaceSecondary.android` (#F7F7F7); tiles #F1F1F1 on both (APK `d42.o`, PLAY-01) | per-platform evidence; the iOS frame is closer to #F1F1F1 | resolved; raw iOS light Settings capture would confirm |
| R-5 | Hairline | APK #CCCCCC / #4D4D4D vs image readings #E3E3E3–#EFEFEF / #333333–#353535 | APK values | 1-device-px lines in 2.2–2.4 px/pt renders are resampled (lighter in light, darker in dark); exact constant wins | resolved |
| R-6 | Secondary / tertiary / placeholder greys | iOS secondary #999999 (RAW + renders, APK `vv3.e`) vs Android meta black 50 % / white 60 % (`vv3.o`); placeholder 2025 ED-W3 #979797 vs 2023 #B0B0B0 (light) / #8B8B8B (dark); tertiary APK #C1C1C1 / white 30 % vs iOS 2023 timestamp #B4B4B4 | secondary per platform (`textSecondary`, `textSecondary.android`); placeholder = `textSecondary` (2025: in the same image known-#999999 text reads #959595, the placeholder #979797); tertiary = APK constants (no exact iOS sample) | newest; exact over WebP | resolved; tertiary iOS open (one raw capture with a timestamp) |
| R-7 | 60 pt capsule label size | 17 (PAY 16.5 / 16.1, ST-03 17.2) vs 18 (LAND 18.2 / 18.7) | 17 | 2 of 3 captures incl. the newest RAW (PAY 2026-05) | resolved |
| R-8 | Display sizes with the platform serif | APK Roslindale Retro 40/48; iOS cap 30.5 pt (consistent with 40 pt at cap/em 0.76); display-narrow sizes 32 (APK ×5, web h1 32 px) vs iOS PAY "Share Video" cap 22.3 (≈29 pt at the same ratio, face unknown) | `headerTitle` 40 / line 48; `displayMedium` 32; `displaySmall` 24 (APK 24/29, 24/28); sizes are Retro's and are **not** re-fitted to New York / Noto Serif (they render a smaller cap height) | exact constants; re-fitting to another face would be a design decision | resolved; exact when the owner licenses Roslindale |
| R-9 | UI sans on Android | Retro: Inter Variable (OFL) for every UI style (APK `osg.b`, `wv3`) | Bundled (`inter.ttf`), `font.global.family.android` = "Inter"; Android body = Inter 14/17 W450 (−0.3 sp tracking, Latin only), names 15/18 W600 (−0.35), badge 11/11 W600 (−0.2) as `.android` tokens; W450 in `layout.global.variableWeight.android` (named weights cannot express 450) | APK constants | resolved; **Pass 3**: `DSFontFamily.Custom` loads one `Font(id)` (weight 400 only), so W450 / W600 would be synthesized — declare one `Font(resId, FontWeight(w), variationSettings = FontVariation.Settings(FontVariation.weight(w)))` per weight used |
| R-10 | Margins and strip radius | renders: strips at 20, strip radius 16, retro-timehop 20 / 14 vs RAW 2025–2026 + JED: 16 margin, 18 continuous radius | 16 / 18 | RAW beats render (RV §3.4, §3.5) | resolved |
| R-11 | Field radius | 2025 search field 52 high r ≈19 (ED-W3, ±2) vs 2023 search 36 high r 12 (TC-1B), comment field 48 high r 12.1 (TC-2B, this pass), APK 12 dp ×9 | search / text field `radius.global.field` 19 (newest); comment / reply field `radius.global.commentField` 12 | newest per element; the two fields are different components | resolved |
| R-12 | Haptics | Retro Android plays only tap (VIRTUAL_KEY, 17 wrapped handlers) and tick (SEGMENT_FREQUENT_TICK / CLOCK_TICK); no CONFIRM / REJECT / Vibrator; iOS app not inspected | `haptic.global.tap` {ios none, android VIRTUAL_KEY}; `haptic.global.select` android → SEGMENT_FREQUENT_TICK; `send` / `success` / `warning` / `error` kept as PLATFORM outcome feedback (82 + 42 + 17 + 15 code sites) | APK call sites; HIG notification feedback | resolved; owner / verification may drop the outcome haptics to match Retro exactly |
| R-13 | Contrast of Retro's palette | light secondary #999999 2.85:1 on white; fills vs page 1.07–1.39:1; empty-tile text 1.25 / 1.91:1; light inactive tab 2.12:1, dark tab state 2.85:1; white on red 4.18:1; red text 3.62–4.18:1; Retro blue on M3 dialog 2.98 / 3.94:1; inactive dot 1.36:1 | Reported in `design/CONTRAST.md` with the alternatives searched; **no value changed** | CONVENTIONS (never adjust a sourced value) | unresolved — owner / verification |
| R-14 | Motion not captured | push / pop, tab switch, viewer advance / close, pull-to-refresh, iOS photo open: not in any source; the Apple editorial video holds no in-app motion | Native components keep platform motion (`easing.global.native`); custom transitions use Retro's house fade (150 ms FastOutSlowIn); `duration.global.navigationPush` (Yope) removed; `spring.global.sheetPresent` = Retro's fit (response 0.347, ζ 1) instead of Locket's 0.3441 (within 1 %) | VM §A / §C; APK-X motion counts | resolved; 60 fps owner recording would close the rest |
| R-15 | Comment avatar | RV §4 #15 "comment row (avatar 36…)" vs re-measured 29.6 (row) / 30.5 (field) on the same image | `size.global.avatarComment` 30; `avatarPicker` 37 cites only the request rows (TC-1B 36.3) | re-measurement on the cited image | resolved |
| R-16 | Tab bar spacing | renders pitch 72–73 with 50–52 side insets (ST-01, ED-A) vs RAW / REAL even pitch 80.4 = width ÷ 5 (H43, H22, JED ≈80) | even distribution; `size.global.tabBarInset` 0 (name kept; Yope's 22 floating inset has no Retro counterpart) | RAW wins | resolved |
| R-17 | Alphas | researchers: glass "white 8–12 % or a light blur material", over-photo inactive tab "≈60 %" | solved from the measured pairs: glass 12 % (#FFFFFF1F), inactive tab on photo 62 % (#FFFFFF9E) | arithmetic on the cited pixel values | resolved (blur not excluded) |
| R-18 | Header buttons | Yope 44 pt circles vs Retro bare outline glyphs, 48 pt apart | `size.global.headerButton` 44 = hit area (PLATFORM), no circle; `size.global.headerIconPitch` 48; `headerInset` 16 = ink of the last glyph | H22; HIG minimum hit area | resolved |
| R-19 | Tab glyph variant | HIG: tab bars prefer the fill variant (basis of Foundations F-17) vs Retro: outline glyphs selected and unselected | outline (`icon.global.variantRule.tabBar`) | identity layer = Retro | resolved |
| R-20 | Menu item casing | `platform.menuItem` title-style vs Retro's own menus in Sentence case ("Share to my week", "Hide photo") | item text `retro.voice.menu-labels`; HIG layout rules (destructive placement, ellipsis) stay | copy voice = Retro (brief) | resolved |
| R-21 | Dialog titles | Retro titles some confirmations "Are you sure?" (`composer_lost_changes_warning_title`, `rewind_home_delete_confirmation_title`) vs HIG rejects it | use Retro's other form, the action question ("Unfriend %1$s?", "Block %1$s?") — `retro.voice.confirm` | both forms are Retro's; the HIG-compatible one is chosen | resolved |
| R-22 | Section header separator | brief example "Week 26 · Jun 26 – Jul 2" vs Retro "Week 27  Jul 3 - 9" (space; semibold black + regular grey) | Retro's form (C-20); " · " is Retro's meta separator elsewhere ("Muted · Seen") | ST-02, retro-timehop | resolved |
| R-23 | Kept names with changed roles | `backgroundDeep` (home / sheets → media), `controlRaised` (selected tab → disabled / container), `surfaceLight` (secondary pill → pill on media), `headerTitle` (capsule title → serif screen title), avatar sizes, `buttonMarginHSheet` = `buttonMarginH`, `buttonHeightSheet` = `buttonHeight`, `radius.global.viewfinder` = `radius.global.card` | names kept so code compiles; role text rewritten in each token's `element`; listed in README "Redesign renames" | brief: keep names where the role survives | resolved |
| R-24 | Removed Yope-only tokens | `accentSecondary`, `overlayTime*`, `tabBarWidth`, `tabBarSelectedWidth/Height`, `tabBarAvatar`, `sheetPresentObserved`, `photoSwipe` (2), `navigationPush`, `icon.global.grid` | removed; code references listed in README (iOS 8 lines, Android 6 lines) | no Retro role | resolved; Pass 3 / 4 replace the components |
| R-25 | Page-dot geometry | TC-1B (2023-07, light): 5 pt / 12 pitch vs TC-REC (2023-12, dark): 5.9 / 9.6 | TC-REC | newer | resolved |
| R-26 | Copy voice of mechanics surfaces | Timehop (on this day), Partiful (invite web), Locket (widgets, paywall, pushes), Wrapped (year story), BeReal (push, labels) vs Retro analogs (Rewind, `/u/` and `/j/` pages, widgets, paywall, notifications, retrospective) | Retro voice; those ids retired with successors (`design/copy-patterns.md` "Retired patterns"); content-only patterns kept where Retro has nothing (countdown format, widget steps, reaction line, birthday) | brief: copy voice = Retro | resolved |
| R-27 | Android viewer appearance | iOS 2023 viewer black in light appearance (TC-R3) vs APK `vv3.l` lists the "reply bar" among #F7F7F7 (light) surfaces | media stays black on both platforms (`layout.global.appearance.media`); the reply bar takes `controlOnDeep` on media and `surfaceSecondary.android` on page threads | iOS capture is direct evidence; the APK role list is inferred from contexts | open: one Android capture of the viewer in light mode |
| R-28 | Display face | Roslindale (commercial, DJR) | `font.global.display` = platform serif (PLATFORM) until the owner licenses Roslindale Display Narrow / Deck Narrow or keeps the platform serif (OWNER_SETUP §0 item 6) | DESIGN_DIRECTION; never bundle Retro's files | owner decision |

### Problems found (for Pass 2 / 3 / 4)

- **Compile impact.** Removed tokens are referenced by `ios/App/Sources/Components/{TextRoles,FloatingTabBar}.swift`,
  `ios/App/Sources/Features/Capture/Support/{CaptureStyle,CaptureFakes}.swift`,
  `ios/App/Sources/Features/Social/UI/SocialServices.swift`, `ios/AppTests/Account/AccountTestSupport.swift`,
  `android/core/ui/…/{text/TextRoles,components/FloatingTabBar}.kt`, `android/feature/capture/…/ui/CaptureText.kt`,
  `android/feature/social/…/common/SocialUi.kt`; `{light, dark}` colours read outside composition in
  `android/core/ui/…/components/HeaderCircleButton.kt:23,29`, `android/core/ui/…/theme/AppTheme.kt:21-29`,
  `android/app/…/App.kt:44`, `android/core/push/…/NotificationUi.kt:62`,
  `android/feature/capture/…/ui/Components.kt:273` (exact lines in `design/tokens/README.md`). All are component /
  theme code (Pass 3) or screen code (Pass 4).
- **Theme.** iOS still forces dark (`ios/Config/App.xcconfig` `INFOPLIST_KEY_UIUserInterfaceStyle = Dark`,
  `.preferredColorScheme(.dark)` in `RootView.swift`, `SignUpLayout.swift` and three test hosts); Android
  `AppTheme` builds a dark-only scheme and nothing provides `DsTheme` — so `{light, dark}` tokens render light on
  Android until Pass 3 wraps the app.
- **Group token files** (`design/tokens/{account,capture,social,memory,invite}.json`) mention Yope global values in
  `element` / `notes` (e.g. "on #171717", "lime") and override foundations Retro now covers — Pass 2 rewrites them.
- **Copy entries** name retired pattern ids (`yope.voice.*`, `locket.*`, `P-IW-*` …) — resolvable through the
  retired table; Pass 2 rewrites the strings and their `pattern` fields.
- **Inter weights** — see R-9.

### Unresolved (owner, capture or verification)

R-3 (true-black option), R-4 (raw light Settings capture), R-6 (iOS tertiary), R-12 (outcome haptics), R-13
(contrast of Retro's palette), R-14 (60 fps recording), R-27 (Android viewer in light mode), R-28 (display face
licence); gaps listed in `design/tokens/README.md` → "Not available yet" and `design/components.md` → "Gaps".

---

## Redesign — Capture (RC-*)

Pass: redesign Pass 2, capture group, 2026-10-16 (docs/REDESIGN_BRIEF.md "Pass 2"). Owns `design/tokens/capture.json`
(57 tokens: 35 SOURCED, 14 VERIFIED, 8 PLATFORM, 0 BLOCKED — was 133), `design/copy/capture.json` (114 strings, all
SOURCED: 24 verbatim, 22 adapted, 68 new — was 106), `design/surfaces/{camera.capture, camera.fromwidget,
camera.sendto, daily.capture, daily.dualimage, daily.liveactivity, daily.notification, daily.ongoing, collage.view,
collage.share, widget.home.small, widget.home.medium, widget.home.large, widget.home.xl, widget.lock.rect,
widget.lock.circular, widget.lock.inline, widget.android, widget.arrival, notifications.push}.md` and this section.
Inputs: `design/components.md` (C-01 … C-35), `design/copy-patterns.md`, `design/research/retro-visual.md`,
`design/research/retro-package-copy-motion.md`, `references/auto/retro/` (APK strings and excerpts, store / press
renders), mechanics research (`design/research/{locket,bereal}.md`), `backend/worker/COPY_KEYS.md`. Rule: Retro is the
identity (colour, type, spacing, shape, motion, voice); Locket (camera, widgets), BeReal (daily capture, dual image)
and the worker composition (collage) keep the mechanics; native components are PLATFORM. 86 Yope / Locket / BeReal
visual tokens were removed (list in "Problems found").

### Evidence gathered in this pass

All measurements with `python3 -I` (PIL + numpy) on the files below; scales as in `design/research/retro-visual.md` §0.2.

| what | source (coordinates) | used for |
|---|---|---|
| Postcard modal: close circle y736–821 (67.0–102.6 pt, centre 37.7 pt from the right edge), title cap y763–793; photo x286–997 / y869–1879 (297.6 × 422.8 pt, 20 pt below the circle); "Add a message" pill bottom 20.5 pt above the photo bottom; "Mailing Address" label 35.2 pt below the photo; divider y2159 x210–1069 (16.3-pt margins); capsule y2362–2505 (bottom 44.5 pt above the screen bottom) | `references/auto/retro/store/retro-store-03.png` (2.389 px/pt, screen y576–2611) | `camera.sendto.layout.header`, `.layout.preview`, `.layout.messageField`, `.layout.recipientRow`, `.size.sendButtonBottom`; `daily.capture` geometry |
| "Add a Message" modal: text from 21.9 pt, counter '58/250' digits 18 px tall (11.3 pt), right edge 20.7 pt, 22 pt above the keyboard; disabled "Send Postcard" #4D4D4D with a black label | `references/auto/retro/press/tc-2023-12-retro3.png` phones 3 / 2 (phone 3 screen x1937–2564 = 1.595 px/pt) | `camera.sendto.layout.messageSheet`, `.fontSize.counter`, `.size.captionMaxLength`; disabled send |
| Recap preview 2026: media page full width, y717–2385 (safe-area top → 94.8 pt above the bottom); corner fits on 70 rows: circle 27.1 pt, continuous (figma-squircle s 0.6) 26.6 pt, threshold 25.5 pt; close #262626 ≈36 pt, centre 37.7 / 38 pt; Share pill x846–1062 / y2418–2521 (90.8 × 43.5 pt), label glyphs x901–1007 (23-pt paddings), 'S' cap 29 px, x-height 21 px (17 pt), 'h' stem 5 px (semibold); page dots 5.0 pt Ø, 10.0 pt pitch | `references/auto/retro/store/retro-store-04.png` | `collage.view.layout.screen`, `collage.share.layout.pill` |
| Recap preview 2023: page inset 11 pt, card centred with 32–33-pt side insets and 103-pt top / bottom; Share 85 × 42 pt | `references/auto/retro/press/tc-2023-12-recaps.png` (1.697 px/pt) | card inset rule; conflict RC-15 |
| Rewind control row: 64-pt circles centred 71.3 / 71.7 pt from the edges on 440 pt (RWA) and 67.7 / 68.3 pt on 420 pt (RWB) = centred between the screen edge and the 150-pt dial | `references/auto/retro/press/tc-2025-12-rewind-device-a.png`, `…-device-b.jpg` | `camera.capture.layout.controlRow` |
| Widget preview art (1 px = 1 dp): name x-height rows 124–129, ascender 122; second line cap 135–142; both lines end at x146 (11 dp trailing inset); last baseline 15 dp above the bottom; pitch 13; stems ≈0.8 px; Albums preview shows the album line without a location glyph; corners ≈24–27 px | `references/auto/retro/apk/widget_preview_{friends,journals,memories}.webp` | `widget.home.small.layout.overlay`, `.fontSize.overlay` (11), `.fontWeight.overlay` (regular) |
| Glance constants: corner 22 dp; state glyph 48-dp box, 12 padding, tint white 0.85 (`qmh.a`); provider 200 × 200 dp, minResize 100 dp, 2 × 2, updatePeriodMillis 3 600 000 | `references/auto/retro/apk/retro-android-2026.10.1150-excerpts.txt` §"Glance widget", §"WIDGET PROVIDERS" | `widget.android.radius.widget`, `.layout.provider`, `.duration.updatePeriod`, `widget.home.small.color.stateTint` |
| Retro strings used verbatim / adapted (keys cited per entry): `postcard_composer_*`, `media_viewer_shareout_title`, `media_shareout_save_success_message`, `media_viewer_comment_send_failed_*`, `composer_lost_changes_warning_*`, `widget_title_friends`, `widget_description_friends`, `app_widget_*`, `notification_settings_description_posts` / `_comments`, `notification_channel_display_*`, `recap_sticker_collage_loading_message`, `recap_composer_share_cta`, `recap_composer_members_only_pill`, `journal_profile_take_photo`, `activity_tab_empty_message`, `friends_tab_loading_error` | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `design/copy/capture.json` |

### Conflicts and resolutions

| # | topic | values and sources | resolution | rule / evidence | status |
|---|---|---|---|---|---|
| RC-1 | Appearance of capture surfaces | Foundations: media surfaces (camera, postcard-style composer, recap preview, full-bleed media) black in both appearances | camera, send-to, daily capture, collage, widgets, Live Activity on `color.global.backgroundDeep` with `textOnMedia` / `controlOnDeep` / `surfaceLight`; sheets over them ("Add a Message") follow the appearance; themed tokens used on media take their dark value (separator #4D4D4D, disabled #4D4D4D, inactive dot #808080) | `layout.global.appearance.media`; TC-R3 phone 1, ST-03, ST-04 | resolved |
| RC-2 | Camera viewfinder | Yope full width × 1.38 (removed identity); Locket square, full width, r 49; C-35 full-bleed (lead's suggestion) | Retro photo container: 3:4, 16-pt margins, `radius.global.viewfinder` (18), under a C-01 header; full-bleed rejected: a 3:4 photo aspect-filled into 393 × 852 shows only 61 % of the captured width (not what is captured). C-35's rule is used for the control row | foundations defined `radius.global.viewfinder` as "the viewfinder drawn as Retro's photo container"; 3:4 = Retro's single-photo container (retro-visual §3.8) and the 4:3 sensor (PLATFORM) | resolved |
| RC-3 | Shutter | Yope 80 / 3.5 / 5.5 / 59 lime ring (removed); Locket 86 / 4.5 / 3 / 70, yellow ring, #EBEBEB disc, press 0.85 in 233 ms, pressed disc #E0DEDF | Retro has no shutter: geometry from the mechanics reference (Locket AS-7), colours Retro's (ring + disc `color.global.surfaceLight`, gap `backgroundDeep`), press = platform default; Locket's press scale / colour removed; recording outline Locket 6 pt in `surfaceLight` | identity = Retro (colour, motion); a control Retro lacks keeps its mechanic's form (brief: compositions add no new values — none exists) | resolved; flag for review |
| RC-4 | Camera chrome | Yope hour overlay (README: replaced by Retro roles in Pass 2), flash glyph in the viewfinder, library thumbnail, 47-pt flip circle, lime coach tooltip | C-01 serif title `camera.capture.title` "Week {number}" (Retro root title), flash as a bare header glyph, library / flip as C-11 64-pt circles (`controlOnDeep`) centred per Rewind's rule, coach as a C-09 pill on the photo 20.5 pt above its bottom | C-01, C-11, C-35, C-09; README "Removed" row `overlayTimeCamera` | resolved |
| RC-5 | Send-to header | Yope: ✕ and download circles + "send to..." title; Retro Postcard: centred title + trailing close only | Retro header (`camera.sendto.layout.header`) + a mirrored leading save circle (Locket keeps save opposite discard) | ST-03; locket.md §6 | resolved |
| RC-6 | Message (caption) | Yope: caption drawn on the photo, 36 chars (Locket); Retro: "Add a message" pill → "Add a Message" sheet, 250-char counter, pill relabels "Edit message" | Retro flow; limit 250 (API allows 1000); caption no longer on the photo or the widget | ST-03, TC-R3 phones 2–3, APK `postcard_composer_*` | resolved |
| RC-7 | Group chooser | Yope recipient rows (22.6 avatar, 60 pitch); Retro albums list C-15 (72 × 97 covers, 119.5 pitch); retro-visual §5's alternative, the Friends 81-pt avatar grid with a badge in the key-badge position (a key badge, not a selection state in Retro); Retro composer selection circles | C-16 rows (cover in a 37 circle, `listTitle`, trailing `checkCircle`) separated by C-32 hairlines under a Postcard-style label; row 69 pt (APK grouped-list padding 16; Postcard rows ≈67) — C-15 rejected for density (5 groups = 600 pt) | C-16, C-32, C-29 check circle, ST-03 | resolved |
| RC-8 | Send and its states | Yope: lime 'send ⓝ' with count disc, hidden when nothing is selected, lime toast; Locket: send spinner → sent | C-05 on media "Send", disabled #4D4D4D (Retro's own disabled Send Postcard), busy capsule + title "Sending…" (Retro "Ordering postcard…"), modal closes on success; failure = native alert "Couldn't send photo" / "Try Again" (Retro comment failure); success toast Android only, iOS announcement (C-26); discard asks only when a message or voice note exists (Retro lost-changes) | TC-R3 phone 2; APK strings; C-26 | resolved |
| RC-9 | Widget anatomy and tap | Locket: photo + 24-pt avatar + caption pill, 6-pt inset; Retro: full-bleed photo, name + place / album stack bottom-trailing, 22-dp corners, tap reloads | Retro anatomy (Albums variant: name over group — our posts carry no location); tap opens the camera (Locket mechanic) | APK, preview art; lead's note | resolved |
| RC-10 | Widget states | Locket gradients, yellow ring, "No pics yet"; Retro: refresh glyph + line in white 85 %, background not captured | Retro's state column (glyph 24 in a 48 box, white 85 %, one line) with `icon.global.camera` (the tap's action) on `backgroundDeep` (composition); loading = black; errors keep the last photo (HIG) | APK `qmh`; HIG Widgets | resolved; background flagged (capture) |
| RC-11 | Sizes and Lock Screen | HIG "avoid expanding a smaller widget's content"; Retro's provider resizes one layout (minResize 100 dp); Lock Screen: Locket avatar + caption composition (G2-13, no-caption case) | one layout at every home size (Retro); Lock Screen = Retro information (name, group) in C-16 (rect), C-23 (circular), " · " line (inline) — the no-caption case disappears; gallery / label "Group Updates" (Retro names widgets by content) | APK provider; `widget_title_friends` | resolved; closes 3 BLOCKED copy entries |
| RC-12 | Daily capture chrome | BeReal: chevron, 23-pt bold countdown, 378.7-pt r16 viewfinder, white shutter, translucent retake / chip, 40.5-pt heavy 'SEND ➤' | Retro: C-29 header (countdown `sheetTitle` monospaced in the title slot, close circle), camera viewfinder container, C-35 row, C-11 glass retake (40) at `badgeInset`, C-09 audience pill, C-05 "Send"; after the window the title slot shows the group name | components; SURFACES daily.capture "media surface as camera.capture" | resolved |
| RC-13 | Motion on mechanics surfaces | BeReal digit roll and capture choreography, Locket press spring | Retro house motion: `duration.global.crossfade` for digits / state swaps, `duration.global.fade` for appear / disappear, platform press and presentations; dual-image corners follow the host container | identity = Retro motion; R-14 | resolved |
| RC-14 | Collage composition | worker option B (Yope walls) pending the owner (A / B / C, all Yope-derived); Retro analog: recap card (white card, 3–4 columns, 1–2 pt gaps, serif year + name + domain footer) | worker tokens unchanged (`collage.view.layout.page`, `daily.dualimage.layout.composition`, `collage.share.layout.export` are a code contract); the app draws the page as Retro's recap card on the blurred backdrop (option B's 0.0498 corner = the card's ≈5 %); a Retro recap-card composition is added to the owner's choice (needs worker code) | brief (don't edit code); collage-options README | owner |
| RC-15 | Recap-preview layout and Share pill | TC-REC 2023: page inset 11, corners ≈29, close top-left, Share 85 × 42; ST-04 2026: full-width page, 26.5 corners, close top-right, Share 90.8 × 43.5, label 17 semibold; C-09: height "Gap — use pillHeight (37)", label `pill` (15); page dots ST-04 5.0 / 10.0 vs `size.global.pageDot` 5.9 / 9.6 (TC-REC) | 2026 render for the screen and the pill (newer, same element) — surface tokens; page dots keep the global tokens (foundations' value) | newer wins; a surface token only where Retro measured this surface | resolved; reported to foundations |
| RC-16 | Push voice | old: BeReal / Locket / Yope wording ("Time to share a photo.", "{name} sent you a photo!", "new recap added"); Retro: context title, prompt question or statement with a period | Retro voice; invitation title "{group}" (the worker fills only {group}; Retro's "Week N" needs a placeholder), body "What are you up to right now?"; reaction noun "post" (Retro's) with Locket's content rule; birthday request keeps P-BR-1 with Retro's "No pressure." | copy-patterns `retro.voice.push`, "Daily invitation (tenet 5)" | resolved |
| RC-17 | Live Activity / ongoing colours and type | Yope lime countdown and key line; BeReal 23-pt countdown | `textOnMedia` on `backgroundDeep`; group name in the display serif (`displaySmall`) on the Lock Screen, countdown `sheetTitle` monospaced; Android notification: no tint (Retro's not captured) | retro-visual §5; HIG | resolved; **code** (`InvitationAppearance.accentColor`) |
| RC-18 | Reactions / replies channel | Retro "Media Feedback — Media activity, such as comments and likes." | "Post Activity" / "Reactions and replies to your posts" (likes are do-not-copy) | tenets | resolved |
| RC-19 | Recap-preview page dots (collage.view) | spec text (Pass 2): dots centred in the bottom row (centre 59.2 pt above the screen bottom, on the Share pill's centre line); ST-04 at full resolution: media page bottom y2385, dot centre y2424 = 39 px ≈ 16.3 pt below the page at 2.389 px/pt, Share pill y2418–2521 (centre 2469.5) — the dots are not on the pill's line | followed the image: dots centred `dimension.year.story.dots.offset` (16.1, memory's measurement of the same render) below the media page, as week.recap and year.story; the shared Android recap preview (`app.ui.recap.RecapPreviewScreen`, `RecapDots.BelowPage`) draws it for all three | `references/auto/retro/store/retro-store-04.png` (lead check, Pass 4) | resolved (Pass 4, Android capture); spec text fixed |

### Problems found (for other passes)

- **Foundations (lead).** ST-04 (2026) measures the recap Share pill at 43.5 pt high with 23-pt paddings and a 17-pt
  semibold label (C-09 still says "height not isolated — use pillHeight", label `pill`), and page dots at 5.0 pt / 10.0
  pitch vs `size.global.pageDot` 5.9 / 9.6 (TC-REC 2023). Not changed here.
- **Removed tokens still referenced by code (Pass 4)** — 84 of the 86 removed (`widget.android.size.minSize` and
  `.radius.fallback` have no reference): `ios/App/Sources/Features/Capture/{Camera/CameraCaptureView,
  Camera/CameraCaptureModel, Daily/DailyCaptureView, Daily/DailyCountdownView, SendTo/SendToView, SendTo/SendToVoice,
  SendTo/CaptureSendCenter, Collage/CollageView, Support/CaptureStyle, Support/CaptureComponents}.swift`,
  `ios/Widgets/Sources/{WidgetSlots,WidgetStyle}.swift`, `ios/AppTests/Capture/{CaptureDailyTests,
  CaptureSnapshotTests}.swift`, `android/feature/capture/…/{camera/CameraScreen, daily/DailyCaptureScreen,
  daily/CountdownText, sendto/SendToScreen, sendto/SendToRoute, collage/CollageScreen, ui/Components,
  ui/CaptureToastHost}.kt`, `android/feature/capture/src/test/…/FlowTests.kt`,
  `android/core/widget/…/{PhotoWidgetUi, WidgetArt, WidgetGroupMeta}.kt`. **Other groups' code uses capture
  tokens that are gone:** `ios/App/Sources/Features/Memory/Tagging/SelfTagToggle.swift` and
  `android/feature/memory/…/tagging/SelfTagToggle.kt` (`camera.capture.layout.coach`, `.fontSize.coach`,
  `.fontWeight.coach`, `.layout.textStyleMap`), `ios/App/Sources/Features/Memory/Shared/MemoryControls.swift`
  (`camera.sendto.layout.toast`), `android/feature/social/…/common/SocialUi.kt` (`camera.sendto.duration.toastVisible`)
  — they should move to C-26 (platform toast / announcement) and their own components.
- **Removed copy keys still referenced by code:** `camera.capture.hourOverlay`, `camera.capture.a11y.close`,
  `camera.sendto.coach.voice`, `widget.home.small.a11y.photoWithCaption`, `daily.capture.a11y.send`,
  `collage.view.title`, `collage.view.error.button`, `collage.view.a11y.back` (files in the reply of this pass).
- **Worker:** no key or token the worker reads changed shape; push texts change without code. Retro's invitation title
  "Week N" would need a `{week}` placeholder (owner / worker team).
- **Android code:** `InvitationAppearance.accentColor` (`android/core/push/…/NotificationUi.kt`) should return no
  colour (RC-17); `DeepLink.Camera` must accept no group (C-24, still open); `DailyInvitationNotifier` promotion (C-11).
- **Account group:** the camera tab uses the tab bar's media variant (C-04 over media) — `groups.list.layout.tabBar`;
  `onboarding.widget` should name the widget "Group Updates" (`widget.home.small.gallery.name`) and may reuse
  `widget.arrival.help.delay`.

### Unresolved (owner, capture or verification)

RC-3 (shutter form — review in Pass 5), RC-10 (Retro's empty widget background: one screenshot of an empty Retro
widget), RC-14 (collage option, now including a Retro recap-card composition), RC-15 (foundations: Share pill and page
dots); owner: default audience with no context (all groups), Android lock-screen hub eligibility, static widget
`previewImage`, notification small icon, `{app_name}` mark on shared collages; captures: Retro widget on a device at
2 × 2, raw "Add to Your Week" with 2 photos selected, raw "Add a Message", Retro notifications as rendered.

---

## Redesign — Memory (RM-*)

Pass: redesign Pass 2, memory group, 2026-10-16 (docs/REDESIGN_BRIEF.md "Pass 2"). Owns `design/tokens/memory.json`
(74 tokens: 71 SOURCED, 3 PLATFORM, 0 BLOCKED — was 170), `design/copy/memory.json` (168 strings: 146 SOURCED, 21
PLATFORM, 1 BLOCKED; 58 verbatim, 39 adapted, 71 new — was 127), `design/surfaces/{onthisday, year.story, birthday.add,
birthday.request, birthday.contribute, birthday.tribute, tagging}.md` and this section. Inputs: `design/components.md`
(C-01 … C-35), `design/copy-patterns.md`, `design/research/retro-visual.md`, `…/retro-package-copy-motion.md`,
`…/retro-timehop.md`, `references/auto/retro/` (RAW Rewind and paywall captures, store / press renders, APK strings and
excerpts), the mechanics research (`design/research/wrapped-tribute-partiful.md`, earlier "Memory" / "Gap fill"
sections) and `backend/worker/{COPY_KEYS.md, src/tribute/render.ts, src/copy.ts}`. Rule: Retro is the identity; Wrapped
(year-story pacing), Tribute / VidDay (birthday flow and video) keep the mechanics; native components are PLATFORM.
All Timehop, Wrapped, Tribute and Yope visual tokens were removed (136; list in "Problems found").

### Evidence gathered in this pass

All measurements with `python3 -I` (PIL + numpy) on the files below.

| what | source (coordinates) | used for |
|---|---|---|
| Rewind dial at rest: centre (630, 2217.5); ticks at 5.7° + k × 8.19° (44 slots), long ticks inner radius 167 px, short 191 px, outer 226.5 px; tick width ≈ 9–10 px; tick alpha white 0.30–0.33; indicator at slot 21 (178°), radius 176.5–226 px, solid white; play glyph ink 31.7 × 35.0 pt; share x107–299 / random x959–1151 (64 pt) on 1260 px; dial centre 739.2 pt on a 912-pt screen | `references/auto/retro/press/tc-2025-12-rewind-device-b.jpg` (RAW, 3.000 px/pt) | `*.onthisday.dial.*`, `count.onthisday.dial.ticks`, `layout.onthisday.dial`, `.controls`, `dimension.onthisday.controls.centerY` |
| Rewind dial, second state: centre (660, 2288.5); ticks 6.0° + k × 8.19°, long 155.5–214.5 px, short 179.5–214.5 px, outer 214.5 px (143 pt ring), indicator slot 0 (6°) radius 130–214 px; 26 ticks alpha 0.295–0.307 (median 0.300); play glyph 33.7 × 37.3 pt; share x118.5–310.5, random x1009.5–1201.5; '•••' x1152–1271 y276–396; date '1' cap y285–376 | `references/auto/retro/press/tc-2025-12-rewind-device-a.png` (RAW PNG) | tick colour, slot geometry, RM-3 |
| 'On this week' subtitle: glyph core (218,204,197) over (38–39,65–66,52) → white 0.83 / 0.73 / 0.71; date baseline y823 → subtitle baseline y886 | `references/auto/retro/press/tc-2025-12-rewind-panels.png` phone 1, `references/auto/retro/store/retro-store-05.png` | `color.onthisday.subtitle`, `dimension.onthisday.subtitleBaseline` |
| Recap preview 2023: frame x1075–1702 y320.5–1448.5 (corner fit R 40.6 px = 24 pt), card x1129.5–1647.5 y494.5–1274.5, grid 4 × 6, cells 121.5 × 108.5 px, gaps 2–3 px, padding 12.5 px, corner fit 26.4 px (rms 0.5), footer 109 px; close fill 143 over 90, bar circle 76 on 0 (white 0.30); Share x1529.5–1673 y1468.5–1539.5, label 'S' 1495–1514; dots y1474; phone 3 footer '2023' y1352–1401, name / app right ink x2530 | `references/auto/retro/press/tc-2023-12-recaps.png` (1.695 px/pt) | `layout.year.story.recapCard`, `dimension.year.story.frame.padding`, `.footer.baseline`; chrome superseded by the 2026 render (RM-8) |
| Recap preview 2026: page bottom y2385.5, dots y2417–2431, leading thumbnail x216–306 | `references/auto/retro/store/retro-store-04.png` (2.389 px/pt) | `dimension.year.story.dots.offset`; other values = capture's `collage.view.layout.screen` / `collage.share.layout.pill` |
| Yearly recap card: card x1650–2503, padding 16 px, gaps 6 px, 3 × 3 cells 3:4, footer 191 px, '2023' cap 66 px | `references/auto/retro/press/tc-2023-12-retro-header.png` | `layout.year.story.recapCard` (variant) |
| Paywall plan card (RAW): close x1031.5–1127.5 y203.5–299.5; headline baseline y1121 → line 1179; line 2 bottom 1299 → card top 1386; title 1464–1515; detail 1548–1588; steps 1668 / 1764 / 1860 (52 px markers, text from x210); footnote 2101–2141 → capsule 2229; card bottom 2456 → line under it 2502 | `references/auto/retro/lazyweb/retro-lazyweb-20260529-paywall.png` (3.000 px/pt) | `*.birthday.request.*` |
| Postcard composer: 'Postcard' baseline y792, photo y870–1880 x285.5–996, pill bottom 1830 | `references/auto/retro/store/retro-store-03.png` (2.389 px/pt) | `*.birthday.contribute.titleToPhoto`, `.photoWidth`, `.photoMaxHeight`, `.pillBottom` |
| 'Add a Message' modal: screen x1937–2564 (1.595 px/pt), text from x1972, 'Done' right 2531, counter x2439–2531 y1006–1029, keyboard top 1058.5 | `references/auto/retro/press/tc-2023-12-retro3.png` phone 3 | `*.birthday.contribute.messageInset`, `.counterInset`, `.counterAboveKeyboard` |
| Retro strings (keys cited per entry): `rewind_home_*`, `rewind_mode_selection_sheet_shuffle`, `add_to_user_profile_week_sheet_badge_text_rewind_memory`, `home_rewind_upsell_feed_card_*`, `home_feed_card_annual_recap_title`, `home_feed_card_annual_retrospective_attribution_template`, `retrospective_page_title_*`, `recap_composer_share_cta`, `media_viewer_comment_overflow_*`, `media_viewer_footer_tagged_users_*`, `media_viewer_tagged_user_*`, `media_viewer_view_tagged_users_empty`, `media_viewer_tag_user_permission_denied_error_tag_title`, `postcard_composer_*`, `error_message_*`, `edit_address_success_message`, `delete_media_confirmation_action_delete` | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `design/copy/memory.json` |

### Conflicts and resolutions

| # | topic | values and sources | resolution | rule / evidence | status |
|---|---|---|---|---|---|
| RM-1 | Visual references | onthisday: Timehop banner + masonry; year.story: Wrapped canvas, progress segments, chrome; birthday.*: Tribute web pages and stepper; tagging / birthday.add: Yope roles | Retro: Rewind (onthisday), recap preview + Year in Photos copy (year.story), paywall card / postcard composer / 'Add a Message' (birthday.request / .contribute), C-35 + recap row (birthday.tribute), viewer tag footer + 'In this photo' (tagging), C-33 / C-14 (birthday.add); mechanics tokens kept (Wrapped reveal and tap-through, VidDay card time and line limit, Tribute / VidDay video contract, day boundary) | docs/REDESIGN_BRIEF.md three layers | resolved |
| RM-2 | Rewind copy for a day-matching feature | Retro 'On this week' (camera roll, week match); our `on_this_day` matches month and day in the group | 'On this day' (noun swap) with ' · {name}' for the member who posted; shuffle → Retro's 'Memories'; entry 'Revisit memories from {date} over the years' / 'View memories' | docs/API.md `on_this_day`; copy-patterns adaptation rules | resolved |
| RM-3 | Two dial states | RWB: ring 150, indicator 16.7, glyph 35, centre 139.2 above the safe-area bottom; RWA (same month): ring 143, indicator 28, glyph 37.3, centre 159.2 | RWB = the resting dial (matches research's 150 ±2); RWA recorded as another state (pressed / dragging — not identifiable from a still) | both RAW; the resting state is the one a static spec draws | open: 10 s recording of the dial dragged and released |
| RM-4 | Dial semantics | Retro: 'Drag the dial to take a spin through your memories', one tick haptic per step (APK); indicator seen on slots 0, 21 and others (renders) | one slot per memory, indicator on the current memory's slot, start slot 0 (RWA), clockwise = next; playing advances one slot per memory | Retro's own string and package; clock convention for direction | open (same recording) |
| RM-5 | Dice (random) | Retro 'Shuffle' mode over the camera roll; our API has no random RPC and `on_this_day` is per date | shuffle = random post of the group's history via `group_history_weeks` (pages of 52); respects `free_history_days` (T1) | lead's group notes ('share + dice buttons'); API 6.4 | **owner**: keep shuffle beyond today's date? |
| RM-6 | Share on Rewind | Retro shares the user's own camera-roll photo (share frame with 'retro.app'); M-20 had dropped share (other members' photos leave the group) | native share sheet with the photo for every memory (as `photo.viewer`'s "save" already allows); Retro's frame not built (Helvetica / Fraktion Mono type, brand line); preview 'Tuesday, December 2' (today) / 'Memory' | RWP phone 3; consistency with the viewer | **closed** by owner decision 12: your own photos only (OD12-1) |
| RM-7 | Rewind as a pushed page | Retro: a tab with the tab bar over the photo; our feature opens from a group | pushed page with C-02 back + date title; no tab bar; the controls keep Retro's distance from the bottom (139.2 pt) | C-02, C-35 | resolved |
| RM-8 | Recap-preview chrome (year.story frame, bottom row; tribute bottom row) | TC-REC 2023 (frame 11.5 inset, r 24, close top-left white 30 %, bar circle 41.9, Share 84.7 × 41.9) vs ST-04 2026 (full-width page, r 26.5, close #262626 top-right, Share 90.8 × 43.5) — the capture group took ST-04 (RC-15) for `collage.view` / `collage.share` | ST-04 via the capture tokens `collage.view.layout.screen` and `collage.share.layout.pill` (referenced, not duplicated); TC-REC kept only for the recap card's inner layout and the full-bleed footer (not shown in ST-04); 9:16 content box (ST-04 page = 393 × 698) | newer beats older (R-* rule); one definition per Retro screen | resolved; **lead / Pass 5**: promote the recap preview (page, close, row, Share pill, dots offset) to a global component — `week.recap` (social) uses the same screen |
| RM-9 | Tagging affordance | Yope-era white pill toggle + lime coach; Retro: footer run 'Tag friends' / ' · with {names}', 'In this photo' sheet, 'Remove tag' | Retro's footer run ('I'm in this' when untagged → tags you; 'with {names}' → sheet) and sheet; only self-tags; tags shown to members (API 5.11); no coach (Retro has none) | Retro strings; tenet: no counts ('%1$d friends' not used) | resolved; **hand-off `photo.viewer` (social)**: append the run to the C-22 footer's second line |
| RM-10 | Birthday request composition | Tribute: photo hero at 0.7, 24/600 title, 62-pt r8 button, prompts on #292D34; Retro paywall: blurred backdrop, serif headline, plan card with numbered steps | PAY composition: honoree avatar (C-23 64) in place of PAY's feature media, serif headline, invitation line, card with 'Message ideas' + numbered prompt rows + C-05, due date under the card | SURFACES (screen 27 assigned); C-34 | resolved |
| RM-11 | Contribution flow | Tribute 3-step stepper, 46-pt translucent field, 'Use Photo' / 'Retake'; VidDay 'no visible counter' | Retro composer sheet (grid) → dark postcard-style composer ('Add a message' pill) → 'Add a Message' modal with Retro's counter ('{count}/110'); stepper removed | SURFACES (screens 17, 18, 30); TC-R3 shows the counter | resolved |
| RM-12 | Tribute video look | VidDay paper title / end cards (#EFEEF3 / #444347, Medium), Tribute navy badge (#11202FC7, bold) | Retro media: black cards, white text, weight 400; caption band = `color.global.scrim` (#00000099), name 600, line 400; geometry (ratios, timings) unchanged; token names and shapes unchanged | identity = Retro; worker contract kept | resolved; worker hand-off done (Roboto Serif / Inter, then the fallback fonts for other scripts and colour emoji, OD12-F) |
| RM-13 | Year-story copy | Wrapped verbatim lines ('We're ready for you.', 'Come on down.', 'Long live the moment.', 'Luckily, we took notes.', 'One more thing...', 'Until we meet again...', 'Replay from beginning'); Retro Year in Photos ('Let’s look back at your 52 weeks', '… was the most memorable', 'You didn’t go through these moments alone —', 'Here’s to another year in the books') | Retro's lines; counts only where T3 allows ('{group} shared {count} photos this year'); most-reacted framed as 'The moments you reacted to most' (T2; Retro's 'loved the most' is do-not-copy) | copy-patterns `retro.voice.retrospective` + tenet filters | resolved; T2 / T3 stay owner decisions |
| RM-14 | Date formats | Timehop 'TUE 10:34 PM', Wrapped 'February 25', Tribute 'Wednesday, December 31, 2025', Yope '26 May' | Retro: Rewind 'Jul 22, 2022' (medium), within the year 'Wednesday, July 5', birthday 'July 5', month 'December' | RWA / RWB, TC-2B, RWP, TC-REC | resolved |
| RM-15 | Research corrections | retro-timehop: '≈45 ticks', long tick 18 (p50 inner radius); C-35 subtitle 'not measurable' | 44 ticks (constant 8.19° pitch on both RAW captures); long 19.8 / short 11.8 measured on the ticks; subtitle white 76 % ±6 % (channel mismatch noted) | direct measurement | resolved |
| RM-16 | Media pages in light appearance | themed tokens on always-dark pages (e.g. page-dot inactive #DDDDDD in light = 1.36:1 against white active dots) | media pages render their subtree in the dark appearance (iOS `.environment(\.colorScheme, .dark)`, Android `DsTheme(dark = true)`); sheets over them follow the system | `layout.global.appearance.media`; capture RC-1 does the same | resolved; Pass 3 / 4 |
| RM-17 | Removed surfaces' states (empty / error / offline) | Yope lowercase lines, Timehop 'Collecting Memories' / 'Time Travel Failed' | C-27 / C-28 states with Retro's error strings ('Something went wrong' / 'There was a problem. Please try again.' / 'Try Again'); offline 'No Connection' + 'Check your connection and try again.' | copy-patterns `retro.voice.error` | resolved |
| RM-18 | Rewind mode selection | Retro: tapping the date title opens a mode sheet ('On this week…', 'Shuffle', 'Pick a date…' — APK strings `rewind_mode_selection_sheet_*`; the sheet itself never captured); RWA shows a chevron after the title | a platform pull-down menu on the date title (iOS `Menu`, Android M3 `DropdownMenu`): 'On this day…' (RM-2 noun swap) → the day's memories, 'Shuffle' → as the dice, 'Pick a date…' (verbatim) → week.history's calendar (`week.history.layout.calendar`; Retro's own picker never captured), the picked month and day across the years with the 'Memories' subtitle; chevron `icon.global.chevronDown`, `dimension.onthisday.modeChevron.{width 19.7, gap 8.7, drop 2.0}` measured on RWA, weight medium (PLATFORM) | RWA; HIG pull-down buttons; M3 menus | resolved; open: one recording of Retro's mode sheet |

### BLOCKED re-examined

- Closed by Retro: the Timehop items M-9 (banner colour rule) and M-10 (progress bar) no longer exist (Rewind has no
  banner); M-23 (Wrapped text width) replaced by the frame padding; M-20 share (built for your own memories, RM-6 / owner decision 12) — Retro's 'Hide photo'
  is built since owner decision 34 (research #12; migration 0038 `hide_memory`): "Hide Photo" and "Hide This Day" in the
  Rewind menu, shown again from `settings.hidden` (onthisday.md D).
- Still BLOCKED: copy `year.story.card.app` (the app line on the recap card, Retro's 'retro.app') — owner names the app
  and its domain. No token is BLOCKED.
- Still open (not BLOCKED, captures listed in each spec's Gaps): RM-3 / RM-4 (dial recording), M-24 (tap halves —
  Wrapped capture 1), T2 / T3 / T5 (owner), everyone-days selection (owner).

### Problems found (for other passes)

- **Removed tokens still referenced by code (Pass 4)** — 129 of 136 (unreferenced: `layout.onthisday.navigation`,
  `.progress`, `.photo.single`, `layout.year.story.progress`, `.reveal.samples`, `.text`,
  `layout.birthday.request.structure`): `ios/App/Sources/Features/Memory/{OnThisDay/OnThisDayScreen,
  YearStory/YearStoryCanvas, YearStory/YearStoryScreen, Birthday/BirthdayRequestScreen, Birthday/BirthdayContributeScreen,
  Birthday/TributeScreen, Shared/MemoryControls}.swift`, `ios/AppTests/Memory/MemoryYearStoryTests.swift`,
  `android/feature/memory/…/{onthisday/OnThisDayScreen, yearstory/YearStoryScreen, yearstory/YearStoryCards,
  yearstory/ShareCards, birthday/BirthdayRequestScreen, birthday/BirthdayContributeScreen, birthday/BirthdayParts,
  birthday/TributeScreen}.kt`. Kept layout tokens that lost fields: `layout.year.story.summary.previewWidthRatio`
  (`ios/…/YearStory/YearStoryScreen.swift:253`, `android/…/yearstory/YearStoryScreen.kt:326`),
  `layout.birthday.request.dueDate.style` (no code use).
- **Removed copy keys still referenced by code** (all 26): `onthisday.banner.yearsAgo.one` / `.other`,
  `onthisday.memory.meta`, `onthisday.a11y.close`, `year.story.moments.title`, `.moments.aside`, `.busiestMonth.aside`,
  `.mostReacted.aside`, `.outro.teaser`, `.outro.subtitle`, `.summary.share`, `birthday.add.a11y.close`,
  `birthday.request.ease`, `.thanks`, `.notFound.detail`, `birthday.contribute.step.photo` / `.message` / `.done`,
  `.greeting`, `.thanks`, `.review.use`, `.review.retake`, `.line.label`, `.done.button`,
  `birthday.tribute.notFound.detail`, `tagging.coach` — in the memory screens, `ios/…/Memory/Shared/MemoryStyle.swift`,
  `android/…/memory/common/Formats.kt`, `…/tagging/SelfTagToggle.{swift,kt}` and the memory tests.
- **Cross-group token use:** `year.story` and `birthday.tribute` read the capture group's `collage.view.layout.screen`
  and `collage.share.layout.pill` (RM-8); `year.story` reads `dimension.birthday.request.headlineToMessage` and
  `birthday.tribute` reads `dimension.onthisday.subtitleBaseline` (same group). The capture pass notes that
  `SelfTagToggle` and `MemoryControls` used its removed coach / toast tokens — the new tagging spec needs neither.
- **groups.screen (account):** the entry cards change copy — on-this-day card title / line / action
  (`onthisday.entry.title`, `.entry.subtitle`, `.entry.button`; the years-ago keys are gone), year story
  (`year.story.entry.*`: 'Year in Photos' / '{year} Recap' / 'View memories'), birthday request row
  (`birthday.request.title`, `.due`).
- **photo.viewer (social):** host the tag run in the C-22 footer's second line (RM-9) and expose it to assistive
  technology as one button.
- **settings.account (account):** the 'Birthday' row pushes `birthday.add` (title `birthday.add.manage.title`).
- **notifications.push (capture):** the birthday request / tribute pushes are the capture group's
  (`notifications.push.birthdayRequest.*`, `.tribute.*`, already in Retro voice with "No pressure."); the request
  screen's line (`birthday.request.body`) matches them.
- **Worker:** no key or token name the worker reads changed; values of `layout.birthday.tribute.titleCard`, `.endCard`,
  `.caption` changed (RM-12) — re-render the tribute test fixtures; `backend/worker/COPY_KEYS.md` status column still
  quotes the old values.
- **Foundations (lead):** `color.onthisday.dial.tick` and the recap-preview values are candidates for global tokens if
  another surface needs them; C-35's subtitle opacity gap is closed by `color.onthisday.subtitle` (±6 %).

### Unresolved (owner, capture or verification)

RM-3 / RM-4 (10 s recording of Retro's Rewind dial), RM-5 (shuffle scope) — owner; RM-6 closed by owner decision 12;
RM-8 (promote the recap preview to a global component — lead); RM-12 (worker fonts — worker team); copy
`year.story.card.app` (app name); docs/SPEC_FLAGS.md T2 / T3 / T5; captures: one RAW Retro Year in Photos recording
(December), one RAW recap preview, one RAW screenshot of a tagged photo with its 'In this photo' sheet, RAW
'Add to Your Week' with 2 photos selected.

---

## Redesign — Social (RS-*)

Pass: redesign Pass 2, social group, 2026-10-16 (docs/REDESIGN_BRIEF.md). Owns `design/tokens/social.json` (98 tokens:
88 SOURCED, 4 PLATFORM, 6 BLOCKED — was 232), `design/copy/social.json` (185 strings: 184 SOURCED, 1 PLATFORM; 97 verbatim,
12 adapted, 76 new — was 141), the 13 surface specs `design/surfaces/{chat.thread, chat.composer, chat.voice,
chat.reactions, photo.viewer, walls.mine, walls.member, walls.browse, week.recap, week.edit, week.history, albums.list,
albums.view}.md` and this section. Every surface is drawn on Retro (identity) with components C-01 … C-35; feature
mechanics come from Apple Messages / WhatsApp (chat, voice, reactions), Locket (quick emoji, order), Telegram (playback
time), Apple Photos / Google Photos (reorder). Retro analogs: chat.* ↔ Messages inbox (ENG-M) + viewer comment rows /
field (TC-2B) + Retro's thread strings (APK); photo.viewer ↔ media viewer (TC-2B, web `/j/`); walls.mine / walls.member ↔
profile with week sections (ST-02, JED, ENG-P); walls.browse ↔ Friends grid (TC-1B); week.history ↔ profile week strips
(ST-02, H43 / H22, ENG-P); week.recap ↔ Create Recap + recap preview (TC-REC, ST-04); week.edit ↔ "Add to Your Week"
composer (VID-COMP) + "Add a Message" (TC-R3); albums.* ↔ Albums list (ED-W3) / album detail (TC-J1) / web album grid.
No string uses `{app_name}`. Push texts for these surfaces stay with `notifications.push` (capture group, RC-16, L-1).

### Evidence gathered in this pass

All measurements with `python3 -I` (PIL + numpy) on the files below.

| what | source (coordinates) | used for |
|---|---|---|
| **TC-2B phone-2 scale**: the viewer photo spans x 1320–2188 (868 px = 393 pt) → **2.209 px/pt** (not 2.298 as in retro-visual §0.2); the comment field's margins then come out 16.3 pt and the home indicator 8.6 pt above the screen bottom (both iOS constants) | `references/auto/retro/press/tc-2023-07-retro-2b.jpg` | every TC-2B value below; RS-25 |
| Viewer header: avatar x 1345–1434 / y 279–368 (40.7 pt with ring, inset 11.3); 'tim' baseline y 312, 'Week 28' y 356 (19.9 pitch), text from x 1460 (11.8 after the avatar); pill x 1978–2081 / y 295–352 (fill #262626, label cap 16 px ≈ 11 pt); close circle x 2100–2152 / y 298–349 (23.7 pt, #262626, × ink 6.8 pt, right edge on the 16 margin); photo top y 388 (9.1 below the avatar) | same | `photo.viewer.dimension.header*`, `.closeCircle`, `.closeGlyph`, `.headerToPhoto` |
| Viewer footer and comments: photo bottom y 1535 → 'Greenville, SC' baseline 1591 (25.4) → date 1632 (18.6) → hairline 1667 (15.8) → comment avatar top 1704 (16.7); comment avatar x 1356–1423 (30.8), text from x 1460 (16.7 after it), 'elton 2h' baseline 1724 → 'whoa!' 1766 (19.0); avatar bottom 1767 → field top 1821 (24.4) | same | `photo.viewer.dimension.footer*`, `.dividerToComments`, `.commentsToField`, `chat.thread.dimension.rowAvatarToText`, `.rowLinePitch` |
| Comment field: x 1357–2152 (margins 16.3), y 1821–1934 (51.2 pt), own avatar x 1376–1445 (8.6 in, 31.2 Ø), placeholder ink from x 1469 (10.9 after the avatar), '•••' ink x 2077–2113 (17.7 from the edge); field bottom 32.6 pt above the screen bottom (−1.4 vs the 34-pt safe area) | same | `chat.composer.dimension.*` |
| Friends grid: avatars 179 px (81 pt), columns at x 1392 / 1940 (pitch 124.3), rows y 527 → 816 (131.1), avatar bottom → name baseline 60 px (27.2) | `references/auto/retro/press/tc-2023-07-retro-1b.webp` (screen x 1322–2187 = 2.204 px/pt) | `walls.browse.dimension.*` |
| Profile header (render): name baseline y 803, real name baseline ≈856, info rows pitch 68.5 px (28.7), last info baseline 1074 → capsules 1129–1217 (23.0 / 37 pt) → 'Week 27' cap 1289 (30.1); screen top y 576 | `references/auto/retro/store/retro-store-02.png` (2.389 px/pt) | `walls.mine.dimension.nameToActions`, `.actionsToWeeks` |
| Current-week strip, 2026 live app: 'Mon', 'Mon', add tile, then uniform blank tiles (no date text; σ ≈ 1 level across the tile) | `references/auto/retro/press/engadget-2026-08-profile.jpg` | `week.history.layout.currentWeek` |
| Create Recap month cards: card x 244–813 / y 499–925 (336 × 251 pt), gap 28 px (16.5); corner fits r 23.5–24.8 px (14 pt); 'December' D cap 536–579 (25.7 pt cap ≈ displayMedium), ink x 280 (21.2 in), cap top 21.8 below the card top; '2023' baseline 614 (20.6 below) | `references/auto/retro/press/tc-2023-12-recaps.png` phone 1 (1.695 px/pt) | `week.recap.aspectRatio.weekCard`, `.radius.card`, `.dimension.weekCard*` |
| Recap preview 2023 (superseded for the chrome, kept for the record): panel inset 11.2, corners r 35.9–40.6 px (≈23 pt), close 33.6 pt at 20.6 / 23.6, card x 1130–1647 / y 496–1274 (2:3, white on a dark-mode screen), grid inset 7.1, 4 columns 122 × 108 px, gaps 2–3 px, grid outer corner r 13.3 px (7.9 pt), footer '2023' digit height 50 px (29.5 pt = headerTitle), 'nathan' ascender 16 px (≈13 pt), circle 71 px / pill 70 px (41.6 pt), pill padding 23.5 | same, phones 2–3 | RS-17 (reported; the chrome uses ST-04 via the capture group) |
| Recap preview 2026: leading photo thumbnail x 217–306 (37.7 pt), white border 4 px (1.7 pt), corner r 21.4–22.5 px (9 pt), count badge '9' at its bottom-trailing corner (do-not-copy) | `references/auto/retro/store/retro-store-04.png` (2.389 px/pt) | `week.recap.dimension.selectThumb*`, `.radius.selectThumb` |
| Album detail (render): cover x 2697–3054 / y 823–1332 (172.5 × 246 pt), 'CDMX' cap 1408–1455 (23.2 pt cap ≈ displayMedium), meta baseline ≈1504 (23.7 below), capsules y 1563–1638 (28.5 below the meta; Settings / Share 135 pt, '+' 47.8, gap 8.7); grid cells x 2510–2750 / 2755–2995 / 3000–3240 and y 1767–2066 (116.5 × 145 pt = 4:5, gaps 4 px = 1.9 pt); grid outer corner r 23.5–25 px (11.4–12.1 pt) | `references/auto/retro/press/tc-2024-04-journals-1.webp` phone 3 (sheet x 2469–3281 = 2.069 px/pt) | `albums.view.dimension.*`, `.aspectRatio.gridCell`, `.radius.grid` |
| retro.app CSS: album grid 4 columns, gap .25rem (2 px mobile), border-radius .75rem with top-right / bottom-right corner classes; cells padding-top 133.33 % (3:4); note box mobile padding 1rem 1.125rem, #f1f1f1, radius 1.125rem, notes list padding-bottom 1.25rem, attribution avatar + name; viewer mobile image 100vw radius 0 contain, count pill #262626 999px, close #262626 1.75rem, footer padding .75rem with a 1-px white-25 % divider, footer text gap .5rem | `references/auto/retro/web/retro.app-42b38811bebcd07d.css` | `albums.view.radius.grid`, `week.recap.radius.note` / `.dimension.note*`, `chat.reactions.dimension.chipTop`, `chat.thread.dimension.itemGap` |
| Retro thread strings: composer placeholders, reply bar, day dividers, post attachment title / week, context menu (Reply / Copy / Unsend / Delete / Save / Retry), delivery 'Sending', 'Reactions' sheet, 'Error loading your messages' | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` (`message_thread_*`, `message_reactions_sheet_title`) | chat copy |
| Thread motion: m6a.java:1509 tween 250 ms qh4.d "entry animation"; composer fade 150 ms (m6a 1213–1240) | `references/auto/retro/apk/retro-android-2026.10.1150-excerpts.txt` | `chat.thread.duration.entry`, `.easing.entry` |
| WhatsApp reaction summary: seven reactions shown as three distinct emoji (+ a count) | `references/auto/whatsapp/store/whatsapp-store-04.png` | `chat.reactions.count.clusterMaxVisible` |

### Conflicts and resolutions

| # | topic | values and sources | resolution | rule / evidence | status |
|---|---|---|---|---|---|
| RS-1 | Thread drawing | Yope bubbles (rims, insets, lime quote); Messages / WhatsApp coloured bubbles; Retro thread not captured; Retro comment rows (TC-2B) | thread = Retro comment rows (C-16) in runs, under a C-02 pushed serif header; no bubbles | brief: no Retro analog → compose Retro components in the mechanics' order (SURFACES: "composed from C-13 / C-16") | resolved; capture of a Retro DM thread would confirm |
| RS-2 | Photo message | Yope 323 × 174 landscape frame | C-18 photo card 240 × 361, radius 18, aspect fill | Retro's photo container in a feed context | resolved |
| RS-3 | Spacing inside / between runs | not captured | items 8 pt (web footer stack gap), runs `size.global.listGap`, dividers C-20 spacing | composition from Retro constants | flagged |
| RS-4 | Times and emoji-only | Yope: no times; Retro: relative '2h' on comments, 'Today' / 'Yesterday' dividers in threads; Yope 47.5-pt emoji | day dividers (C-20 dated) + clock time on run headers; emoji-only at `fontSize.global.headerTitle` (Messages / WhatsApp 1–3 rule kept) | Retro thread strings; G-2 rule | resolved |
| RS-5 | Reply quote | Yope lime quote block | C-15 attachment row with Retro's "Post by %1$s" / "Week %1$d"; message quote as a grey C-15 subtitle line; replies to messages now offered (API `reply_to_message_id`; Retro "Reply") | Retro strings | resolved |
| RS-6 | Composer | Yope lime camera + rimmed field + mic circle; Messages / WhatsApp idle / typing | C-13 field with own avatar; camera + mic glyphs inside (textSecondary), send glyph (textPrimary) while typing; placeholder "Send a message…" | C-13; Retro placeholders; G-6 mechanic | resolved |
| RS-7 | Voice message | Yope waveform bubble; WhatsApp / Telegram waveforms | C-06 fill capsule with C-07 anatomy: play glyph + "0:38" (C-25 format); elapsed while playing (Telegram); recording in the C-13 field with a red mic (C-10), lock circle (C-11) | identity = Retro (no waveform component); closes `chat.voice.layout.widthRule` (hug width) | resolved; owner may want a waveform |
| RS-8 | Reactions | Locket sticker cluster, emoji rain, fly-to-cluster, 'Popular' list; SURFACES: mechanics Locket; lead note: Messages / WhatsApp | chip (C-06 fill) with ≤ 3 distinct emoji under the photo / in the viewer footer slot; Reactions sheet (Retro's title) with C-16 rows, tap your own to remove; rain, fly-in and Popular removed (another app's visuals); Locket kept for the quick emoji (🔥 💖) and order | identity rule; WhatsApp / Messages help; closes `clusterMaxVisible` (3) and the sheet layout | resolved; row order BLOCKED |
| RS-9 | Where quick reactions live | Locket: inside the viewer's reply field; Messages / WhatsApp: a row above the long-pressed message | the platform context menu's palette row (iOS 17 ControlGroup palette; Compose Row) on photo messages and the viewer photo | mechanics; PLATFORM component | resolved |
| RS-10 | Viewer appearance | Yope #1C191D; foundations: media black in both | `color.global.backgroundDeep`, the viewer forced to the dark appearance (themed tokens resolve dark: separator #4D4D4D, control #262626) | TC-R3 phone 1 | resolved |
| RS-11 | Viewer footer content | Retro: place (semibold) / date (grey); our posts have no place; web title "caption or location · date" | caption in the place line, date line under it; tag run after the date (memory RM-9); voice note as a footer line | Retro footer + web title rule | resolved; captioned Retro capture would confirm |
| RS-12 | Moving between photos | Yope swipe (167 ms) | Retro tap to advance / tap left to go back, no auto-advance, no progress bars, "N of M" pill; cross-fade 100 ms | Retro strings + package; brief note | resolved; back-zone width BLOCKED |
| RS-13 | Viewer voice note | BLOCKED position | footer line (voice capsule on #262626) | composition | resolved (old BLOCKED closed) |
| RS-14 | Walls | Yope 3-column grid, BLOCKED mosaic / free-form wall; Retro profile with week sections | walls = Retro profile: serif name + 64 avatar, one trailing icon capsule (gear → settings; "•••" → Report / Block Profile on others), week sections (C-20 + C-17) from `wall()`; no "Recaps" / "Share Profile" (recaps per group; no public profiles), no info rows (no data / counts), no week "•••" on walls | ST-02, TC-1B phone 3, APK `user_profile_more_options` | resolved; old BLOCKED mosaic / freeformWall closed |
| RS-15 | Week of a wall item | walls span groups with different time zones | device time zone, `week_start_isodow` | data rule (API has no per-user zone) | resolved |
| RS-16 | Friends grid paging | TC-1B pages 2 rows sideways (dots) to leave room for Friend Requests | vertical grid (nothing follows it); no selection state — tap opens the wall (closes `walls.browse.layout.selection`); no "Invite" / "Keys" text buttons | C-21; Retro grid behaviour | resolved; order BLOCKED |
| RS-17 | Recap screens | Yope O3 grid card (BLOCKED short row, scrim, page 2), segmented "recap \| pics"; Retro Create Recap (segmented Yearly / Monthly / Weekly / All Posts + month cards) and preview (TC-REC 2023 inset panel vs ST-04 2026 full-width page) | list = Retro month cards as week cards (no segmented control: weekly only); preview chrome = ST-04 via the capture group's `collage.view.layout.screen` / `collage.share.layout.pill` (RC-15), pages = the memory group's `layout.year.story.recapCard` + cover style (RM-8) — one definition in the product. This pass's TC-REC readings that differ from the memory card are reported: the card is **white on the dark-mode capture** (memory: `color.global.surfaceElevated` → #181818 in dark), card corner fit 22.6–24.8 px (memory: 26.4 px), group name ≈13 pt semibold (memory / C-34: listTitle 15), footer year = headerTitle (memory agrees; C-34 says displaySmall) | newer beats older; one definition per Retro screen | resolved; **memory / lead**: white vs surfaceElevated card in dark; promote the recap preview to a global component (RM-8) |
| RS-18 | Recap "Share" | Retro exports (Stories, Reels, Postcard …) | no export; the light pill is "Save as Album"; the leading thumbnail (Retro "Select photos", its count badge dropped) opens `week.edit` | product scope (albums are the brief's saving feature) | resolved |
| RS-19 | Recap text | Yope page 2 (BLOCKED); Retro recaps carry no text | Retro's journal note box (web constants) under the card, attributed to `edited_by` | composition | resolved |
| RS-20 | week.history tokens | old surface tokens 84.5 × 112, radius 14, inset 20 (renders), emptyTile #262626 (dark only) | global strip tokens (RAW: 84 × 112, radius 18, margin 16) and `color.global.control` / `.emptyTileText` in both appearances; current week per ENG-P (photos, add, blank placeholders) over ST-02 (render shows nothing after "+"); week "•••" = native menu with the product's two actions (old BLOCKED closed; Retro's own items stay uncaptured) | R-10; REAL beats render | resolved |
| RS-21 | Albums | Yope list card → Apple Photos 2-column grid (G-17); Retro list rows (stack, "+", "shared N posts"), detail (cover with shadow, Settings / Share / +, dated 3-column grid) | list = C-15 rows with "{name} created the album" (no stack, no "+", no counts); detail = cover (shadow BLOCKED), serif name, meta, Rename + "•••" capsules, grid 3 columns 4:5 cells (TC-J1; C-21 says square, web 3:4 — in-app capture wins) with 12-pt outer corners (TC-J1 fit = web .75rem), saved order (no date headers) | Retro analog; same-surface evidence | resolved; G-17 superseded |
| RS-22 | Recap editor | Yope-built editor (S-13), BLOCKED text position | Retro composer sheet (Cancel / Edit Recap / Update), chosen-photos strip on top (reorder there), 4-column grid, "Add a message" → Retro "Add a Message" modal (closes `week.edit.layout.recapText`), album sheet "New Album" / "Name your album" / "Create Album"; lost-changes dialog | VID-COMP, TC-R3, APK strings | resolved; selection mark BLOCKED |
| RS-23 | Copy voice | Yope lowercase; Retro menu-label rule (Sentence case) vs Retro's own Title-Case items ("Report Post", "Save to Camera Roll", "Delete Album", "Report Profile") | verbatim Retro items keep their case; new items follow `retro.voice.menu-labels` | verbatim beats a pattern | resolved |
| RS-24 | Push texts | reaction / reply / recap-ready pushes | owned by `notifications.push` (capture group, RC-16); none defined here | L-1 | resolved |
| RS-25 | Foundations' TC-2B scale | retro-visual §0.2 / components C-13, C-22 use 2.298 px/pt for phone 2; the full-width photo gives 2.209 | surface tokens measured at 2.209; **global tokens not changed**: at 2.209 `size.global.commentFieldHeight` = 51.2 (not 48), `size.global.avatarComment` 31.2 (30), `size.global.avatarHeader` 40.7 (39.2), `size.global.positionPillHeight` 26.3 (22), `radius.global.commentField` 12.6 (12.1) | never adjust another pass's value; report | **foundations / lead** |

### BLOCKED items

- **Closed (13 of the 14 old ones):** `chat.voice.layout.widthRule` (RS-7), `chat.reactions.count.clusterMaxVisible` (RS-8),
  `chat.reactions.layout.activitySheet` (RS-8; row order split out), `photo.viewer.layout.voiceNote` (RS-13),
  `walls.mine.layout.mosaic`, `walls.mine.layout.freeformWall` (RS-14), `walls.browse.layout.selection` (RS-16),
  `week.recap.layout.shortRowSplit`, `week.recap.dimension.shortRowHeight`, `week.recap.layout.scrim`, `week.recap.layout.page2`
  (RS-17), `week.edit.layout.recapText` (RS-22), `week.history.layout.weekMenu` (RS-20).
- **Still BLOCKED (1 old):** `walls.browse.layout.rowOrder` — one raw screenshot of Retro's current Friends tab with 7 or
  more friends.
- **New BLOCKED (5):** `chat.reactions.layout.listOrder` (one WhatsApp / Retro reaction list with three reactors at different
  times), `photo.viewer.layout.backZone` (10-s recording of Retro's viewer tapped at several x positions),
  `week.recap.layout.gridFill` (one Retro Week-style recap preview for a week with 5 photos), `week.edit.layout.selectionMark`
  (one raw screenshot of "Add to Your Week" with 2 photos selected), `albums.view.shadow.cover` (one raw screenshot of a Retro
  album sheet on white). Each carries a development approximation in its `notes`; release builds cannot use them.
- **All six closed 2026-10-16** (social finishing pass; OWNER_DECISIONS 2026-10-15 lets any widely used app supply the
  evidence; tokens and specs carry it): `chat.reactions.layout.listOrder` newest first (Stream Chat's "who reacted" list);
  `photo.viewer.layout.backZone` the leading 20 % (Retro's own album-page viewer script: `clientX < 0.2 × width` → previous);
  `walls.browse.layout.rowOrder` by name (Apple Photos' People & Pets "Sort by Name"); `week.recap.layout.gridFill` ⌊√n⌋
  columns × ⌈n ÷ columns⌉ rows over one 3:4 area (Retro's cards with 1, 9 and 24 photos — retro.app hero, TC-H, TC-REC);
  `week.edit.layout.selectionMark` the Android system photo picker's mark (PLATFORM, measured; both platforms);
  `albums.view.shadow.cover` the TC-J1 fit already used for `groups.screen.shadow.cover`. New: `photo.viewer.layout.avatarRing`
  (TC-2B: the header ring is a progress arc, "3 of 4" = three quarters) and the reorder action names
  `week.edit.a11y.moveLeft` / `.moveRight` (Chrome for Android's tab reorder actions, noun swap). Found on the way: Compose's
  shadow radius is a blur radius (σ = 0.57735 r + 0.5 px), so `dsShadow` now converts the token's σ through the shared
  `blurRadiusForSigma` (core:designsystem) — Android cover shadows were drawn at σ ≈ 4.9 instead of 8.5.

### Contrast failures (reported, not adjusted — Retro's palette, design/CONTRAST.md)

Light: `color.global.textSecondary` on page 2.85:1 (date ranges, times, meta, quote lines, error lines) and on
`color.global.control` 2.52:1 (placeholders); Android `textSecondary.android` 4.00 / 3.95:1; `color.global.destructive` text
4.18:1 (failed-send line, inline errors; Android dark 4.07:1); `color.global.emptyTileText` on `control` 1.25:1 (dark 1.91:1);
date range on the white recap card 2.85:1 (both appearances). Non-text: fills against the page 1.07–1.39:1 (fields, tiles,
chips, voice capsules, viewer pill / close / field); viewer divider #4D4D4D on black 2.48:1 (decorative). Everything else
listed in the specs passes (textPrimary 17.0–21.0:1, textOnMedia on #262626 15.13:1, textSecondary on black / #262626
7.37 / 5.31:1).

### Problems found (for other passes)

- **Foundations:** RS-25 (TC-2B scale); C-13 has no internal metrics (avatar inset 8.6, text start 10.9, trailing glyph 17.7 —
  measured here as `chat.composer.dimension.*`); C-11 lists the viewer close (≈23) under the 36-pt circle (measured 23.7,
  `photo.viewer.dimension.closeCircle`); C-21 calls album cells square (TC-J1: 4:5); C-34 says the recap card is
  `surfaceElevated` and its year `displaySmall` (TC-REC: white card in dark, year = headerTitle); C-21's people-grid pitch 125
  has no token (`walls.browse.dimension.columnPitch` 124.3 here).
- **Memory group:** RS-17 (card colour in dark, corner, name size). `tagging.md` is hosted in the viewer footer as asked
  (RM-9); the old `photo.viewer.dimension.actionTrailing` / `.actionCenterTop` are removed.
- **Account group:** `walls.mine` keeps the settings entry (`walls.mine.a11y.settings`) — now a gear icon capsule in the profile
  action row (settings.root's "entry circle" row); the Profile / Friends tab items (C-04 `icon.global.wall` / `.group`) open
  `walls.mine` / `walls.browse`; `groups.screen` may label its recap entry with `week.recap.open` (it now opens the recap list).
- **Pass 4 (code):** every removed social token / copy key below stops compiling; six kept copy keys changed placeholders
  (Swift signatures): `chat.thread.empty.detail` {names} → none, `chat.reactions.activity.rowMine` {emoji, name} → {emoji},
  `photo.viewer.reply.placeholder` {group_name} → none, `walls.mine.empty.title` none → {week_number},
  `walls.member.empty.title` {name} → none, `week.recap.a11y.card` {week_label} → {week_number, date_range}. Kept tokens
  that changed level: `photo.viewer.layout.voiceNote`, `week.history.layout.weekMenu`, `chat.reactions.count.clusterMaxVisible`
  BLOCKED → SOURCED (move out of `BlockedTokens`).

### Removed keys still referenced by code (202 tokens and 15 strings removed; 190 tokens and all 15 strings are referenced)

Removed copy keys: `chat.thread.a11y.groupCapsule`, `chat.thread.a11y.recap`, `chat.thread.reply.photoLabel`,
`chat.thread.empty.titleCreator`, `chat.thread.empty.titleMember`, `chat.reactions.picker.popular`, `photo.viewer.title.you`,
`photo.viewer.title.sentTo`, `walls.mine.title`, `walls.mine.empty.detail`, `walls.browse.me`, `week.recap.segment.recap`,
`week.recap.segment.pics`, `week.edit.a11y.close`, `week.history.empty`. Code references by file (`static grep of ios/,
android/, web/src, backend/worker/src`; web and worker: none):

| file | removed keys it references |
|---|---|
| `android/feature/account/…/groups/GroupProfileScreen.kt` | `walls.mine.`{aspectRatio.gridTile, count.gridColumns, dimension.gridGap} |
| `android/feature/capture/…/sendto/SendToScreen.kt` | `chat.voice.`{color.duration} |
| `android/feature/memory/…/birthday/BirthdayContributeScreen.kt` | `walls.mine.`{aspectRatio.gridTile, count.gridColumns, dimension.gridGap} |
| `android/feature/memory/test/…/tagging/SelfTagSnapshotTest.kt` | `photo.viewer.`{dimension.actionCenterTop, dimension.actionTrailing} |
| `android/feature/social/…/albums/Albums.kt` | `photo.viewer.`{icon.delete}; `week.recap.`{aspectRatio.picsTile, count.picsColumns, dimension.picsGap, fontSize.title, fontWeight.title}; `albums.list.`{layout.yopeAlbums} |
| `android/feature/social/…/chat/ChatScreen.kt` | `chat.thread.`{a11y.groupCapsule, a11y.recap, color.bubbleMine, color.bubbleRimMineBottom, color.bubbleRimMineTop, color.bubbleRimTheirsBottom, color.bubbleRimTheirsTop, color.bubbleTheirs, dimension.avatarGap, dimension.avatarInset, dimension.bubbleHeight, dimension.bubbleInsetMine, dimension.bubbleInsetTheirs, dimension.bubbleMaxWidth, dimension.bubblePaddingH, dimension.bubbleRim, dimension.captionHeight, dimension.captionInsetBottom, dimension.captionPaddingH, dimension.emojiOnlyGlyph, dimension.gapBetweenSenders, dimension.gapSameSender, dimension.gapTextToVoice, dimension.headerCapsuleHeight, dimension.photoGap, dimension.photoHeight, dimension.photoInsetTrailing, dimension.photoWidth, dimension.replyLabelBaseline, dimension.replyNameCapTop, dimension.replyQuoteBar, dimension.replyQuoteBarInset, dimension.replyQuoteHeight, dimension.replyTextInset, dimension.replyThumb, dimension.replyThumbInsetTop, dimension.replyThumbInsetTrailing, dimension.replyWidth, empty.titleCreator, empty.titleMember, fontSize.caption, fontSize.replyLabel, fontSize.replyName, fontWeight.caption, fontWeight.replyLabel, fontWeight.replyName, radius.bubble, radius.caption, radius.replyQuote, radius.replyThumb, reply.photoLabel}; `chat.voice.`{color.bubble, color.bubbleTheirs}; `chat.reactions.`{dimension.clusterEmoji, dimension.clusterInsetBottom, dimension.clusterInsetLeading}; `photo.viewer.`{icon.delete} |
| `android/feature/social/…/chat/Composer.kt` | `chat.composer.`{color.fieldRimBottom, color.fieldRimTop, dimension.cameraButton, dimension.cameraGlyph, dimension.fieldHeight, dimension.fieldPaddingLeading, dimension.fieldRim, dimension.gapCameraField, dimension.gapFieldButton, dimension.insetLeading, dimension.insetTrailing, dimension.micGlyph, dimension.sideButton} |
| `android/feature/social/…/chat/Voice.kt` | `chat.composer.`{dimension.fieldHeight, dimension.sideButton}; `chat.voice.`{color.bubble, color.duration, color.playButton, color.waveform, color.waveformPlayed, dimension.barMaxHeight, dimension.barMinHeight, dimension.barPitch, dimension.barWidth, dimension.durationTrailing, dimension.height, dimension.playButton, dimension.playGlyph, dimension.playInsetLeading, dimension.playToWaveform, dimension.waveformToDuration, dimension.width, icon.pause, layout.widthRule, radius.bubble} |
| `android/feature/social/…/common/Blocked.kt` | `chat.thread.`{dimension.bubbleMaxWidth}; `chat.voice.`{color.bubbleTheirs, layout.widthRule}; `chat.reactions.`{layout.activitySheet}; `photo.viewer.`{dimension.pageGap}; `walls.mine.`{layout.freeformWall}; `walls.browse.`{layout.selection}; `week.recap.`{dimension.shortRowHeight, layout.page2, layout.scrim, layout.shortRowSplit}; `week.edit.`{layout.recapText}; `week.history.`{color.emptyTile}; `albums.list.`{layout.yopeAlbums} |
| `android/feature/social/…/common/Formats.kt` | `week.recap.`{layout.weekFormat} |
| `android/feature/social/…/common/SocialUi.kt` | `chat.thread.`{radius.loadingHud} |
| `android/feature/social/…/data/SocialServices.kt` | `chat.voice.`{color.waveformPlayed} |
| `android/feature/social/…/reactions/EmojiCatalog.kt` | `chat.reactions.`{layout.pickerPopular} |
| `android/feature/social/…/reactions/Reactions.kt` | `chat.reactions.`{color.clusterOutline, count.rainCopies, dimension.clusterEmoji, dimension.clusterOutline, dimension.clusterStep, dimension.pickerEmoji, dimension.rainEmoji, duration.flyToCluster, duration.rainSpawnInterval, duration.rainTotal, duration.rainTravel, easing.rain, fontSize.pickerSection, fontWeight.pickerSection, layout.activitySheet, layout.rainPath, layout.reduceMotion, picker.popular} |
| `android/feature/social/…/viewer/PhotoViewerScreen.kt` | `chat.thread.`{dimension.captionHeight, dimension.captionInsetBottom, dimension.captionPaddingH, fontSize.caption, fontWeight.caption, radius.caption}; `chat.composer.`{dimension.fieldPaddingLeading, dimension.gapFieldButton, dimension.insetLeading, dimension.insetTrailing, dimension.sideButton}; `chat.voice.`{color.bubble, color.bubbleTheirs, dimension.height}; `chat.reactions.`{dimension.clusterEmoji, dimension.clusterInsetBottom, dimension.clusterInsetLeading}; `photo.viewer.`{color.background, dimension.actionCenterTop, dimension.actionTrailing, dimension.closeCenterX, dimension.headerCenterY, dimension.moreCenterTrailing, dimension.moreGlyphWidth, dimension.pageGap, dimension.photoTop, dimension.senderAvatar, dimension.senderInsetLeading, dimension.senderInsetTop, dimension.senderNameGap, dimension.titleToDate, icon.delete, title.sentTo, title.you} |
| `android/feature/social/…/walls/WallScreens.kt` | `walls.mine.`{aspectRatio.gridTile, count.gridColumns, dimension.gridGap, dimension.gridInset, dimension.titleToGrid, empty.detail, radius.gridTile, title}; `walls.browse.`{dimension.avatar, dimension.avatarPitch, dimension.labelBaselineGap, dimension.rowCenter, dimension.rowInset, dimension.titleBaseline, dimension.wallTop, layout.selection, me} |
| `android/feature/social/…/week/EditScreen.kt` | `week.recap.`{aspectRatio.picsTile, count.picsColumns, dimension.picsGap}; `week.edit.`{a11y.close} |
| `android/feature/social/…/week/HistoryScreen.kt` | `week.history.`{color.emptyTile, color.emptyTileText, dimension.addGlyph, dimension.headerToStrip, dimension.inset, dimension.moreTrailing, dimension.rangeGap, dimension.sectionGap, dimension.tileGap, dimension.tileHeight, dimension.tileWidth, dimension.titleInset, dimension.titleToStrip, dimension.weekdayBaseline, empty, font.title, fontSize.emptyDay, fontSize.emptyDayLabel, fontSize.header, fontSize.title, fontSize.weekday, fontWeight.headerRange, fontWeight.headerTitle, fontWeight.title, fontWeight.weekday, icon.add, radius.strip} |
| `android/feature/social/…/week/RecapScreen.kt` | `week.recap.`{aspectRatio.gridTile, aspectRatio.picsTile, count.gridColumns, count.picsColumns, dimension.cardToDots, dimension.cardWidth, dimension.dotsToPics, dimension.gridGap, dimension.labelBaselineBottom, dimension.labelInsetLeading, dimension.pageDot, dimension.pageDotPitch, dimension.picsGap, dimension.segmentedBottom, dimension.segmentedHeight, dimension.segmentedInset, dimension.segmentedPillHeight, dimension.segmentedPillWidth, dimension.segmentedWidth, fontSize.label, fontSize.segmented, fontSize.title, fontWeight.label, fontWeight.segmented, fontWeight.title, layout.page2, layout.shortRowSplit, segment.pics, segment.recap} |
| `android/feature/social/test/…/ChatSnapshotTest.kt` | `chat.reactions.`{duration.flyToCluster, easing.rain, layout.activitySheet} |
| `ios/App/Sources/Components/LoadingHUD.swift` | `chat.thread.`{radius.loadingHud} |
| `ios/App/…/Features/Account/Groups/GroupProfileScreen.swift` | `walls.mine.`{aspectRatio.gridTile, count.gridColumns, dimension.gridGap} |
| `ios/App/…/Features/Capture/SendTo/SendToVoice.swift` | `chat.voice.`{icon.pause}; `photo.viewer.`{icon.delete} |
| `ios/App/…/Features/Memory/Birthday/BirthdayContributeScreen.swift` | `walls.mine.`{aspectRatio.gridTile, count.gridColumns, dimension.gridGap} |
| `ios/App/…/Features/Memory/Tagging/SelfTagToggle.swift` | `photo.viewer.`{dimension.actionTrailing} |
| `ios/App/…/Features/Social/Core/ChatThreadModel.swift` | `chat.thread.`{dimension.gapBetweenSenders, dimension.gapSameSender, dimension.gapTextToVoice, dimension.photoGap, empty.titleCreator} |
| `ios/App/…/Features/Social/Core/WeekModels.swift` | `week.history.`{empty} |
| `ios/App/…/Features/Social/UI/AlbumViews.swift` | `photo.viewer.`{icon.delete}; `albums.list.`{layout.yopeAlbums} |
| `ios/App/…/Features/Social/UI/ChatThreadView.swift` | `chat.thread.`{a11y.groupCapsule, a11y.recap, color.bubbleMine, color.bubbleRimMineBottom, color.bubbleRimMineTop, color.bubbleRimTheirsBottom, color.bubbleRimTheirsTop, color.bubbleTheirs, dimension.avatarGap, dimension.avatarInset, dimension.bubbleHeight, dimension.bubbleInsetMine, dimension.bubbleInsetTheirs, dimension.bubbleMaxWidth, dimension.bubblePaddingH, dimension.bubbleRim, dimension.captionInsetBottom, dimension.emojiOnlyGlyph, dimension.gapBetweenSenders, dimension.gapSameSender, dimension.gapTextToVoice, dimension.headerCapsuleHeight, dimension.photoGap, dimension.photoHeight, dimension.photoInsetTrailing, dimension.photoWidth, dimension.replyLabelBaseline, dimension.replyNameCapTop, dimension.replyQuoteBar, dimension.replyQuoteBarInset, dimension.replyQuoteHeight, dimension.replyTextInset, dimension.replyThumb, dimension.replyThumbInsetTop, dimension.replyThumbInsetTrailing, dimension.replyWidth, empty.titleCreator, empty.titleMember, layout.textStyleMap, radius.bubble, radius.replyQuote, radius.replyThumb, reply.photoLabel}; `chat.composer.`{color.fieldRimBottom, color.fieldRimTop, dimension.cameraButton, dimension.cameraGlyph, dimension.fieldHeight, dimension.fieldPaddingLeading, dimension.fieldRim, dimension.gapCameraField, dimension.gapFieldButton, dimension.insetLeading, dimension.insetTrailing, dimension.micGlyph, dimension.sideButton}; `chat.reactions.`{dimension.clusterInsetBottom, dimension.clusterInsetLeading, layout.rainPath}; `photo.viewer.`{icon.delete} |
| `ios/App/…/Features/Social/UI/PhotoParts.swift` | `chat.thread.`{dimension.captionHeight, dimension.captionPaddingH, fontSize.caption, radius.caption} |
| `ios/App/…/Features/Social/UI/PhotoViewerView.swift` | `chat.thread.`{dimension.captionInsetBottom}; `chat.composer.`{color.fieldRimBottom, color.fieldRimTop, dimension.cameraGlyph, dimension.fieldHeight, dimension.fieldPaddingLeading, dimension.fieldRim, dimension.gapFieldButton, dimension.insetLeading, dimension.insetTrailing, dimension.sideButton}; `chat.reactions.`{dimension.clusterInsetBottom, dimension.clusterInsetLeading}; `photo.viewer.`{color.background, dimension.actionCenterTop, dimension.actionTrailing, dimension.closeCenterX, dimension.headerCenterY, dimension.moreCenterTrailing, dimension.moreGlyphWidth, dimension.photoTop, dimension.senderAvatar, dimension.senderInsetLeading, dimension.senderInsetTop, dimension.senderNameGap, dimension.titleToDate, icon.delete, title.sentTo, title.you} |
| `ios/App/…/Features/Social/UI/ReactionsUI.swift` | `chat.reactions.`{color.clusterOutline, count.rainCopies, dimension.clusterEmoji, dimension.clusterInsetBottom, dimension.clusterOutline, dimension.clusterStep, dimension.pickerEmoji, dimension.rainEmoji, duration.flyToCluster, duration.rainSpawnInterval, duration.rainTotal, duration.rainTravel, easing.rain, layout.activitySheet, layout.pickerPopular, layout.rainPath, layout.reduceMotion, picker.popular} |
| `ios/App/…/Features/Social/UI/SocialBlocked.swift` | `chat.voice.`{layout.widthRule}; `chat.reactions.`{layout.activitySheet}; `walls.mine.`{layout.freeformWall}; `walls.browse.`{layout.selection}; `week.recap.`{dimension.shortRowHeight, layout.page2, layout.scrim, layout.shortRowSplit}; `week.edit.`{layout.recapText} |
| `ios/App/…/Features/Social/UI/SocialServices.swift` | `chat.voice.`{color.waveform}; `week.history.`{dimension.tileHeight, dimension.tileWidth} |
| `ios/App/…/Features/Social/UI/SocialStyle.swift` | `chat.thread.`{dimension.emojiOnlyGlyph, fontSize.caption, fontSize.replyLabel, fontSize.replyName, fontWeight.caption, fontWeight.replyLabel, fontWeight.replyName}; `chat.reactions.`{fontSize.pickerSection, fontWeight.pickerSection}; `week.recap.`{fontSize.label, fontSize.segmented, fontSize.title, fontWeight.label, fontWeight.segmented, fontWeight.title, layout.weekFormat}; `week.history.`{font.title, fontSize.emptyDay, fontSize.emptyDayLabel, fontSize.header, fontSize.title, fontSize.weekday, fontWeight.headerRange, fontWeight.headerTitle, fontWeight.title, fontWeight.weekday}; `albums.list.`{layout.yopeAlbums} |
| `ios/App/…/Features/Social/UI/VoiceUI.swift` | `chat.composer.`{dimension.fieldHeight, dimension.micGlyph}; `chat.voice.`{color.bubble, color.bubbleTheirs, color.duration, color.playButton, color.waveform, color.waveformPlayed, dimension.barMaxHeight, dimension.barMinHeight, dimension.barPitch, dimension.barWidth, dimension.durationTrailing, dimension.height, dimension.playButton, dimension.playGlyph, dimension.playInsetLeading, dimension.playToWaveform, dimension.waveformToDuration, dimension.width, icon.pause, layout.widthRule, radius.bubble}; `photo.viewer.`{icon.delete} |
| `ios/App/…/Features/Social/UI/WallsViews.swift` | `walls.mine.`{aspectRatio.gridTile, count.gridColumns, dimension.gridGap, dimension.gridInset, dimension.titleToGrid, empty.detail, layout.freeformWall, radius.gridTile, title}; `walls.browse.`{dimension.avatar, dimension.avatarPitch, dimension.labelBaselineGap, dimension.rowCenter, dimension.rowInset, dimension.titleBaseline, dimension.wallTop, layout.selection, me} |
| `ios/App/…/Features/Social/UI/WeekViews.swift` | `photo.viewer.`{dimension.moreGlyphWidth}; `week.recap.`{aspectRatio.gridTile, aspectRatio.picsTile, count.gridColumns, count.picsColumns, dimension.cardToDots, dimension.cardWidth, dimension.dotsToPics, dimension.gridGap, dimension.labelBaselineBottom, dimension.labelInsetLeading, dimension.pageDot, dimension.picsGap, dimension.segmentedBottom, dimension.segmentedHeight, dimension.segmentedInset, dimension.segmentedPillHeight, dimension.segmentedPillWidth, dimension.segmentedWidth, fontSize.segmented, layout.page2, layout.shortRowSplit, segment.pics, segment.recap}; `week.edit.`{a11y.close, layout.recapText}; `week.history.`{color.emptyTile, color.emptyTileText, dimension.addGlyph, dimension.headerToStrip, dimension.inset, dimension.moreTrailing, dimension.rangeGap, dimension.sectionGap, dimension.tileGap, dimension.tileHeight, dimension.tileWidth, dimension.titleInset, dimension.titleToStrip, dimension.weekdayBaseline, empty, icon.add, radius.strip} |
| `ios/AppTests/Account/AccountTestSupport.swift` | `walls.mine.`{aspectRatio.gridTile} |
| `ios/AppTests/Memory/MemorySnapshotTests.swift` | `photo.viewer.`{dimension.actionTrailing} |

### Unresolved (owner, capture or verification)

RS-7 (waveform or not — owner), RS-17 (card colour in dark; global recap-preview component — memory / lead), RS-25 (TC-2B
scale in the foundations — lead), RS-3 (thread spacing), the six BLOCKED tokens above, S-12 (the noun "Friends" for family /
roommates groups — owner), and the light-mode text contrast of Retro's greys and red (R-13). One capture session would close
most of it: on one iPhone, raw screenshots of a Retro DM thread with a photo reply and a reacted message, a captioned photo
in the viewer with a comment, the current Friends tab, a profile mid-week, "Add to Your Week" with 2 photos selected, a Week
recap preview with 5 photos, an album sheet, and a 10-s recording of tapping through the viewer — light and dark.

**L-3 — TC-2B phone-2 scale 2.209 px/pt (social RS-25 over foundations).** The foundations measured phone 2 of the
2023 press render at 2.298 px/pt from the screen width. The viewer photo, full width in Retro's viewer (web CSS: 100vw),
spans 868 px = 393 pt → 2.209 px/pt, and at that scale the comment field's side margins are 16.3 pt and the home
indicator 8.6 pt, both platform constants; at 2.298 neither holds. Global values re-derived: comment field 48 → 51.2,
comment avatar 30 → 31.2, viewer header avatar 39 → 40.7, position pill 22 → 26.3, comment field corner 12 → 12.6.

**L-4 — The recap card is white in both appearances (social RS-17 over memory RM-8).** Retro's recap render shows the
white card with black text on a dark-mode screen; `layout.year.story.recapCard` background → `color.global.surfaceLight`,
footer text → `color.global.onSurfaceLight`. week.recap (social) and year.story (memory) share this one definition.

**L-5 — Backdrop blur and dim measured (closes the C-34 / `layout.global.materials` gap).** ST-04 (Retro's recap preview,
2026 store render, 2.389 px/pt) shows the same photo twice: sharp inside the card (x 328–960, y 1197–1831) and as the
backdrop of the media page (x 171–1110, y 717–2385). A least-squares fit over the visible backdrop (216 072 px; card,
close circle, footer and edge bands masked) of `gain · Gσ[photo scaled s and shifted] + bias` per channel gives s 3.000,
shift (2.8, −2.4) px, **σ 4.18 px = 1.75 pt** (1 − R² 0.0131; the linear-light variant fits worse, 0.0181, so the
compositing is in sRGB), and equal channel gains 0.779 / 0.774 / 0.777 with ≈0 bias — a **22 % black layer**, no
saturation change. The card photo used as the sharp source is itself softened by the render (≈1.5 px at backdrop
scale), so σ ≈ 1.86 pt; σ ± 25 % raises the residual ≈10 %. Tokens: `size.global.backdropBlur` 1.8 (σ, pt; iOS
`.blur(radius:)` takes σ, Android's `Modifier.blur` radius r is converted by hwui as σ = 0.57735 r + 0.5 px, so the
component passes r = (σ − 0.5) / 0.57735), `color.global.backdropDim` #00000039. The earlier implementations were not
Retro's look: iOS used `.ultraThinMaterial` (a frosted, tinted material) and Android a 32-dp placeholder radius; both
C-34 components (`BlurredBackdrop`) now draw the measured blur and dim, and the recap preview reads the token.

**L-6 — The invite card blur is a colour field, not the recap blur (web RA over L-5).** The web pass applied L-5's
σ 1.8 pt to the invite card, which left the cover photo recognisable and busy behind white text, unlike Retro's `/u/`
card (a stock photo blurred to a soft colour field) and the spec's own share image ("blurred to a colour field").
Measured: edge-spread fits on `bg2.jpeg` bound σ at ≤ 7.0 % of the width (sharpest edge; high-contrast edges 9.3–10.6 %),
and the share image's backdrop fits the avatar photo best at σ 8.3 % of the width. Token `invite.web.layout.backdrop`
σ = 0.08 × the card / image width under `color.global.backdropDim`; the App Clip card uses the same.

**L-7 — A recap backdrop is one photo, never the composed grid (capture over collage.view's "page 1 blurred").** ST-04
(2026, the newest capture of Retro's recap preview) shows the card's own photo magnified ≈3× and blurred σ 1.8 pt behind
the card; TC-REC (2023) shows a grid card on a smooth wash, not on a blurred grid. A blurred copy of our composed page
puts a busy grid behind the grid card, a look no Retro capture shows. week.recap and year.story already blur their cover
photo; collage.view now blurs the collage's first photo (`post_ids[0]`, display rendition), with page 1's image only
until that photo loads.

**L-8 — Display faces: Roboto Serif instances matched to Retro's two display cuts (over the platform serif, R-8).**
The platform serif (New York / Noto Serif) made every title read as a different product: on the RAW capture H43, Noto
Serif sets "Week 43" 36 % wider than Retro at the same cap height, with a lower x-height and thinner strokes. Retro
uses two Roslindale cuts (APK): **Roslindale Retro** for screen titles (heavy, narrow, x-height 0.72 of the cap) and
**Roslindale Display Narrow** for headlines (lighter, narrow). Each was measured (cap-height-normalised ink width of the
whole title and of 'Week' / 'e' / '4' or 'n' / 'N', x-height, ascender, ink coverage) on H43 + H22 ("Week 43" / "Week
22") and on retro.app's invite headline ("Nathan Invited You!", Display Narrow 32 px at 3×), and 15 OFL serifs were
searched over their variable axes for the smallest mean relative error. Roboto Serif wins both by a wide margin:
**title** wdth 50 · opsz 120 · wght 530 · GRAD 100 (error 0.038; Fraunces 0.142, Noto Serif Display 0.143, Noto Serif
0.241) and **headline** wdth 52 · opsz 96 · wght 430 · GRAD −50 (0.028; Noto Serif Display 0.075, Instrument Serif
0.080). Static instances (fontTools instancer, renamed "Roboto Serif Title" / "Roboto Serif Headline", SIL OFL with
its licence) are bundled on iOS (DesignSystem/Fonts, registered at first use), Android (core:designsystem res/font),
the worker and the web page. `font.global.display` → title instance; new `font.global.displayNarrow` → headline
instance for text roles displayMedium / displaySmall, the invite headline, the Live Activity group name and the
tribute cards. Sizes are re-fitted so cap heights equal Retro's (Roboto Serif cap/em 0.71 vs Roslindale 0.7625):
headerTitle 40 → 43, displayMedium 32 → 34.4, displaySmall 24 → 25.8, wordmark 64 → 71.4 (cap 50.7 pt measured),
invite desktop headline 48 → 51.5; line heights stay Retro's. Licensing Roslindale (owner) remains the exact match.

**L-9 — The paywall backdrop is a colour field (account review over C-34's recap blur).** Retro's paywall (PAY, RAW)
shows a structure-free colour wash behind the plan card; edge-spread fits find no edge sharper than σ ≈ 100 px (8 % of
the width). The recap's σ 1.8 pt (L-5) left the benefit photo readable behind the card. New token
`layout.global.colourFieldBackdrop` (σ = 0.08 × the frame width, 3σ bleed, `color.global.backdropDim`) — the invite's
measured ratio (L-6) — drives a shared `ColourFieldBackdrop` component on both platforms, used by the paywall.

---

## Redesign — Account (RA-*)

Pass: redesign Pass 2, account group, 2026-10-16 (docs/REDESIGN_BRIEF.md "Pass 2"). Owns `design/tokens/account.json`
(66 tokens: 47 SOURCED, 10 PLATFORM, 9 VERIFIED, 0 BLOCKED — was 171), `design/tokens/invite.json` (40 tokens: 36 SOURCED,
3 PLATFORM, 1 VERIFIED — was 110), `design/copy/account.json` (411 strings: 359 SOURCED, 50 VERIFIED, 2 PLATFORM; 193 verbatim,
98 adapted, 120 new — was 351; includes 4 `global.a11y.*` component strings), `design/copy/invite.json` (30 strings: 25 SOURCED, 5 VERIFIED — was 31), the specs
`design/surfaces/{auth.phone, auth.code, auth.agegate, auth.profile, onboarding.permission.notifications,
onboarding.permission.camera, onboarding.permission.photos, onboarding.permission.contacts, onboarding.widget, groups.list,
groups.create, groups.invite, groups.screen, groups.settings, settings.root, settings.notifications, settings.account,
settings.blocked, safety.report, safety.block, system.permissions, paywall, invite.web, invite.appclip}.md` and this
section. `invite.json` belongs to this group because `invite.web` / `invite.appclip` do. Inputs: `design/components.md`
(C-01 … C-35), `design/copy-patterns.md`, `design/research/retro-visual.md` (RV), `design/research/retro-package-copy-motion.md`
(RP), `references/auto/retro/` (APK strings, web CSS and captures, RAW landing / paywall, TC press renders), the platform
research. Rule: Retro is the identity and the voice; Locket (country code, widget steps), the platform (permissions,
purchases, App Clips, alerts, menus) and this app's API keep the mechanics. Strings blocked only by `{app_name}`: 20 → 7.

### Evidence gathered in this pass

All measurements with `python3 -I` (PIL) on the files below; scales as in RV §0.2 unless stated.

| what | source (coordinates) | used for |
|---|---|---|
| Landing layout: wordmark ink y1025–1176, tagline y1234–1313, capsule y2032–2211, link y2273–2314, legal lines y2399–2437 / 2463–2502 on 2622 px (3.000 px/pt) | `references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png` | `auth.phone.size.wordmarkToTagline` 19.3, `.capsuleToLink` 20.7, `.linkToLegal` 28.4, `.legalToBottom` 40, `auth.phone.layout.landingBlock` centre 0.446 |
| Mobile wordmark 4rem | `references/auto/retro/web/retro.app-5bff8a0be69f7ec7.css` `.page_largeRetroWordmark` | `auth.phone.fontSize.wordmark` 64 |
| Album detail: screen x2469–3281 (2.0687 px/pt); cover x2696–3054 / y824–1332; title ink y1407–1455 (cap 23.2); meta y1488–1508; capsules y1563–1638; dated header y1718–1743 | `references/auto/retro/press/tc-2024-04-journals-1.webp` phone 3 | `groups.screen.size.coverWidth` 173.5, `.coverHeight` 246, `.coverToTitle` 36.7, `.titleToMeta` 16, `.metaToActions` 26.6 |
| Cover drop shadow: luminance profiles below / right / left / above the cover on white (201 → 255 over 27 pt; 216 → 255 over 20; 233 → 255 over 14; 241 → 255 over 7); least-squares fit of an offset Gaussian box (sse 0.0021) | same file | `groups.screen.shadow.cover` {#000000, σ 8.5, x 3, y 10, opacity 0.25} — closes the "album cover drop shadow — unmeasured" note of `layout.global.elevation` |
| Link-sharing sheet (2.0687 px/pt): cover x559–1141 / y1185–1999 (phone 1), x1570–2152 / y1017–1830 (phone 2); note y2059–2084 / 1890–1916, darkest (118,118,118); eye x1567–1602, text from x1615; grouped fill (241,241,241) y2022–2264, x1496–2226; '↻' x1533; 'Reset link' x1605 (cap 25 px); red row (234,51,55); share circles x1515–1646, 1702–1833, 1889–2020, 2076–2207 (63.8 pt, fill (241,241,241)); label ink y2455–2475 | `references/auto/retro/press/tc-2024-04-retro-journals-5.png` | `groups.invite.size.coverWidth` 281.8, `.coverHeight` 393.5, `.coverToNote` 29, `.color.note` #767676, `.noteGlyphGap` 6.3, `.menuRowHeight` 58.7, `.menuGlyphInset` 17.9, `.menuTextInset` 52.7, `.targetPitch` 90.4, `.targetLabelGap` 11.6; `settings.root.size.rowHeight` 58.7 |
| Paywall (Display P3 → sRGB): media card edges x231 / 974 at y600, top y411; top-left corner inset profile (circle fit r 82 px, residual 6 px²); title ink y235–270; headline y1051–1121; description 'G' y1180–1217, line 2 x-height y1251–1277; plan-card edge alpha estimates 0.75–0.97 per channel (a blurred material, not a flat alpha); footer brightest (255,238,210) over (150,102,84) | `references/auto/retro/lazyweb/retro-lazyweb-20260529-paywall.png` | `paywall.size.mediaCardWidth` 248, `paywall.radius.mediaCard` 27, description = text role `textButton` (17), plan card opaque (`paywall.layout.planCard`), footer white |
| /u/ invite page (390 CSS px at 3×): card edge x18 / 1151, top y18, bottom y1973; top-left corner inset profile (circle r ≈ 108–110 px); pill x132–1038 / y1614–1782; backdrop samples #4F241E, #57231C, #61342B, #6B4740 | `references/auto/retro/web/retro.app-u-nathan-iphone.png` | `invite.web.size.cardInset` 6, `invite.web.radius.card` 36, pill geometry check, contrast samples |
| /u/ page CSS (mobile + desktop), meta tags, OG text | `references/auto/retro/web/retro.app-5bff8a0be69f7ec7.css`, `…/retro.app-web-copy-excerpts.txt` | every other `invite.web.*` token; `invite.web.layout.linkPreview`; App Clip card display |
| OG share image 600 × 600: avatar x258–340 / y208–290; name ink y309–348; domain ink y369–389, brightest (187,197,201); corners (0–3, 14–24, 33–45) | `references/auto/retro/web/retro.app-og-userogsquare-nathan.png` | `invite.web.layout.ogImage` |
| Retro strings (keys cited per entry): sign-up form (`onboarding_form_input_*`, `onboarding_landing_*`, `error_message_*`), album flow (`journal_*`), settings (`settings_*`, `notification_settings_*`, `edit_profile_*`, `delete_account_*`), report / block (`media_viewer_report_*`, `profile_report_*`, `user_profile_*`), permissions (`*_permission_upsell_*`), widgets (`widget_*`, `home_widget_nux_upsell_*`), paywall (`retro_membership_*`, `redeem_code_sheet_*`), web (`/u/`, `/j/`, `/downloads`) | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`, `references/auto/retro/web/retro.app-web-copy-excerpts.txt` | all copy |

### Conflicts and resolutions

| # | topic | values and sources | resolution | rule / evidence | status |
|---|---|---|---|---|---|
| RA-1 | Visual references | Yope (auth, groups), Locket (paywall, widget page), Partiful (invite page), HIG-only settings | Retro per surface: landing LAND; Albums list / templates / album detail / link sharing (ED-W3, JED, TC-J1, TC-J5); Settings sheet (VID-SET); paywall PAY; `/u/` page; Yope / Locket / Partiful visual tokens removed (247) | docs/REDESIGN_BRIEF.md; docs/SURFACES.md | resolved |
| RA-2 | Sign-up form screens | not captured (RV §2 rows 36–41); only the APK order PHONE_NUMBER → AUTH_CODE → USER_NAME → FULL_NAME and hints | onboarding form composition: C-02 back, display title (`displayMedium`) at C-01's `titleTop`, explanation as C-19's secondary line, C-12 field at `titleToContent`, C-05 above the keyboard; the same frame for every `auth.*` step | composition rule (brief); APK hints verbatim | resolved; capture open |
| RA-3 | Landing | LAND is dark RAW only; "already have an account?" leads Retro's returning users elsewhere | dark geometry used in light; the link is kept (verbatim) and opens the same phone step (one-time-code sign-in serves both) | LAND | resolved; light capture open |
| RA-4 | Age confirmation | Retro: "By continuing, I confirm that I am %1$d or older…" on the landing; FTC COPPA neutral age screen (no cutoff before entry) | `auth.agegate` keeps the neutral date entry; the landing line drops the age clause ("By continuing, I agree to the Terms and Privacy Policy.") | docs/PLATFORM_CONSTRAINTS.md §9 (legal) over Retro | resolved |
| RA-5 | Sign-up errors | Locket message-only alert (gap fill G2-5) vs Retro titled dialogs ("Code Expired" / message) with recoveries ("Send a new code", "Edit code", "Get help") | native alert with Retro's title + message pairs and the two recoveries; "Get help" not built (no destination) | APK-S `error_message_*`, `onboarding_landing_error_*` | resolved |
| RA-6 | Loading HUD | Yope "Loading" HUD (#0C0C0C, 100 pt) | removed; Retro shows busy controls and placeholders: C-05 busy capsule, C-28 placeholders / platform indicator; announcement "Creating…" | C-28; APK-S `journal_profile_share_to_week_generating_title` | resolved |
| RA-7 | Tab bar | Retro 2026: Home · Friends · Rewind · Activity · Profile (5); this app: camera · groups · walls · me | the app's destinations kept, drawn as C-04 with Retro's glyphs by role (house, person.2, person.crop.circle; camera outline); no unread dot (no Activity tab); media variant while the camera tab shows (capture RC note) | C-04; RV §3.6 | resolved; Rewind / Activity tabs = IA decision for the lead / owner |
| RA-8 | Group list | Retro root Albums list (2024, no search) vs pushed list (2025, 52-pt search) | root variant (no search) with the serif title, C-15 rows, the new-album glyph and "Ideas to Get Started" mapped to `group_kind`; template thumbnails are Fill placeholders (Retro's photos are its assets) | ED-W3, TC-J1, JED | resolved |
| RA-9 | Group screen container and header | Retro album detail is a page sheet (TC-J1); header glyphs book + chat (H22); album capsules Settings / Share / + vs profile Recaps / Share Profile / gear | pushed screen (the hub deep links return to); header book → `albums.list` + chat → `chat.thread`; capsules Recaps / Invite / gear (profile pattern; the album "+" becomes the strip's add tile); week history from the week header's chevron (C-20's "•••" menu was not captured) | TC-J1, H22, ST-02; docs/API.md §9.6 | resolved |
| RA-10 | Group week and members | album detail (dated grid only) vs home (strip + friend cards) | album header + this week's strip (C-17, add tile; empty-day tiles only for an empty week) + members' weeks as C-18 cards + earlier photos as the dated 3-column grid; Retro's meta counts → member avatar stack; onthisday / year.story entry cards sit in the same pager (Retro puts its Rewind and Year-in-Photos cards in the home feed), the birthday request row above the week (memory group's request) | TC-J1, H43, ST-01; APK-S `home_rewind_upsell_feed_card_*` | resolved (feed-card image not captured: composition) |
| RA-11 | Invite link | old: a link created on first share; Retro: explicit "Turn on link sharing", then Reset / make private + share targets (QR Code, Copy Link, Instagram, Share to…) | explicit turn-on (create_invite), Reset = revoke + create, Turn off = revoke (red); targets Message / Copy Link / Share to… (Instagram is a third-party brand; Retro's QR card art and copy are brand assets → owner); expiry shown as a date | TC-J5; APK-S `journal_settings_link_sharing_*`, `journal_broadcast_invite_*` | resolved; QR → OD17-1 (owner decision 17, 2026-10-16) |
| RA-12 | Report reasons | BLOCKED (moderation categories, owner) | Retro's lists: posts / messages "I don't like it · Nudity or sexual activity · Other"; people / groups "It's impersonating someone · It's inappropriate · Other"; "I don't like it" files nothing and offers Next Steps — Retro's "Send a message" / "Unfriend" become "Leave the group" / "Block" (no DMs or friendships here); no free-text details (Retro has none) | APK-S `media_viewer_report_*`, `profile_report_*` | closed; owner may extend categories (docs/API.md §12 item 19) |
| RA-13 | Toasts | Yope lime toast tokens (`safety.block.layout.toast`, `.duration.toast` 2000 ms, used app-wide) | removed; C-26 (Android Toast LENGTH_SHORT; iOS accessibility announcement, no custom toast until Retro's iOS toast is captured) | C-26; RP §3.9 | resolved |
| RA-14 | Settings rows | iOS `List(.insetGrouped)` + M3 ListItem heights (56 / 72 / 88 dp) | Retro's own C-14 rows on both platforms; one-line row height 58.7 from TC-J5 (the only measured Retro grouped row); M3 list-item tokens removed | VID-SET, TC-J5, APK-X `pik` | resolved; raw Settings capture open |
| RA-15 | Menu labels | `retro.voice.menu-labels` Sentence case vs Retro's overflow items in Title Case ("Report Post", "Block Profile", "Remove from Album"); HIG ellipsis for "more input follows" | Retro's verbatim Title-Case items; no ellipsis (Retro uses none) | a verbatim string on the analog beats the pattern (A-8 precedent); R-20 | resolved |
| RA-16 | Confirm buttons | HIG verbs ("Delete", "Leave") vs Retro "Yes, delete" | "Yes, <verb>" for every app-drawn confirmation (leave, remove, block, turn off, delete, sign out); titles as action questions (R-21) | APK-S `edit_address_delete_confirmation_*` | resolved |
| RA-17 | Paywall | Locket Gold (gradient, icon tile, perk stack, plan sheet, yellow CTAs; A-1) | Retro PAY: blurred backdrop, title row + glass close, benefit media card + serif headline, plan-card pager, footer; icon tile (BLOCKED `paywall.layout.iconTileArt`) and perk emoji (BLOCKED `paywall.perk.history.emoji`) removed — Retro has neither; plan card opaque white with the light capsule in both appearances; "No thanks!" → close circle; purple `color.global.premium` unchanged, used only on the trial / locked pills (owner); bullets that make a popularity claim or promise pausing dropped | PAY; APK-S `retro_membership_*` | resolved; purple = owner |
| RA-18 | Paywall media | Retro: per-benefit graphics (its assets) | the person's newest group photo (real content) as the media card and the backdrop source; none → no card, black backdrop | do-not-copy assets | resolved |
| RA-19 | Invite page | Partiful page (theme colour, auto-fit title, member list, gate card, 1200 × 630 OG) | Retro `/u/`: blurred-photo card (inset 6, r 36), 112 avatar, 32/32 serif headline, 62 % line, translucent 56-pt pill, 8-px footer; desktop QR above 840 px; 600 × 600 OG; same in both appearances (Retro's web has no dark scheme); added: the members' avatar stack (SPEC_FLAGS T7 "who you're joining") | RP §7; retro.app CSS | resolved |
| RA-20 | App Clip | Partiful-style join sheet (name + phone) | the clip shows the `/u/` card, then the app's own sign-in screens (auth.* B, code, age, name), `join_group`, a "Welcome to {group_name}!" state and SKOverlay | RP §7; HIG App Clips | resolved |
| RA-21 | Purpose strings | Retro's iOS strings not captured (no IPA); Retro's in-app equivalents name the app | kept HIG sentences "The app …" (no `{app_name}`, so Info.plist ships); Android rationale dialogs in Retro's permission voice with "We" (Retro's own first person) | HIG; APK-S | resolved |
| RA-22 | App name in copy | Retro uses its name freely ("on Retro") | dropped wherever a string must ship before the app is named (age refusal, rationale messages, premium subtitle, notifications-off line, web body / opening line); 7 strings keep `{app_name}` (title, premium row, share message, widget steps, document title, Play line) | CONVENTIONS §4 | resolved |
| RA-23 | Group kinds ↔ templates | Retro Event / Friends / Couple / Kid(s) / Hobbies / Anything else | friends ← Friends (verbatim), family ← Kid(s) / Couple (noun swap), roommates (new, Event pattern), custom ← "Or anything else" | APK-S `journal_tab_suggestion_*`; docs/API.md `group_kind` | resolved |
| RA-24 | Name and photo | one Yope screen (name + avatar) vs Retro FULL_NAME then PROFILE_PHOTO pages | `auth.profile` step 1 (name form), step 2 (photo page: 112 avatar, "Choose photo", "Maybe Later"); Retro's skip nudge not copied; the App Clip runs step 1 only | RP §6.3 | resolved |
| RA-25 | Contacts ask | Yope dismissible card (Android) | Retro "No Contacts Access" C-27 block inside the invite sheet's Contacts section (part of the scroll — no dismiss needed); iOS system controls unchanged (A-5) | APK-S `contact_permission_upsell_*` | resolved |
| RA-26 | Mute semantics | Yope "mute this group" (on = muted) vs Retro "Album updates" (on = updates on) | Retro's: new key `groups.settings.notifications.updates` (on = not muted); `groups.settings.notifications.mute` removed | APK-S `journal_settings_notifications_title` | resolved |
| RA-27 | Two cover sizes | album detail 173.5 × 246 vs link-sharing sheet 281.8 × 393.5 (same 0.71 proportion) | each surface keeps its own; the create form uses the detail size | TC-J1, TC-J5 | resolved |
| RA-28 | Note colour on the link sheet | measured #767676 (TC-J5) vs global `textSecondary` #999999 | surface token `groups.invite.color.note` in light (4.54:1 pass); dark keeps `textSecondary` (Retro's dark secondary) | surface measured differently (brief) | resolved |
| RA-29 | Invite page desktop order | spec Structure text: avatar → headline → line → QR; WEBD capture and Retro's DOM (`[QR(data, profilePhotoURL), h1, p]`, WEBX): QR with the profile photo in its centre, then headline and line | Retro's order: QR (70-pt avatar centred over it, error correction H) → headline (70 below) → line → "Download the app" → footer; spec text corrected; `invite.web.size.bodyToQrDesktop` (Retro's p margin-bottom 30) is the line → link space | WEBD, WEBX | resolved |

### BLOCKED items

- **Closed:** `safety.report.layout.reasons` (Retro's reason lists, RA-12); `paywall.layout.iconTileArt` (no icon tile in
  Retro's paywall, RA-17); `paywall.perk.history.emoji` (no emoji on Retro's benefits, RA-17); `auth.phone.layout.countryCode`
  and `auth.phone.layout.inlineError` stay sourced (Locket mechanics in C-12 / Retro's dialog pairs).
- **Still BLOCKED:** none at the token or string level. Seven strings wait for the app's name (`{app_name}`). Owner
  assets: the landing wordmark / app mark (`auth.phone.fontSize.wordmark` gives its size only), App Clip card art.

### Contrast failures (reported, not adjusted — Retro's palette, `design/CONTRAST.md`)

Light `textSecondary` text on the page / fills (rows 3, 4, 11; tagline, links, fine print, subtitles, footers), light
inactive tab (row 22) and dark tab state (row 23), fills vs page (rows 13–14), empty-day tile text (rows 15–16), red
text on rows (rows 31–33), Android meta (rows 5–6), M3 dialog actions (failure 6). Surface pairs: paywall card subtitle
#757A7D on white 4.34:1 and footnote #A5ABAF 2.32:1; invite page line white 62 % on a light backdrop (#8A4A3A) 3.67:1;
pill fill vs backdrop 1.80:1 (non-text); desktop line black 50 % 4.00:1 at 20 px (passes as large text).

### Problems found (for Pass 3 / 4 and other groups)

- **Removed keys still referenced by code** (code scan of `ios/`, `android/`, `web/`, `backend/worker/`, generated files
  excluded — 242 of 247 removed tokens and 64 of 66 removed strings):
  - Tokens: `auth.phone.`{fontSize.subtitle, layout.subtitle, layout.legalFooter}; `auth.code.`{fontSize.textLink,
    fontWeight.textLink}; `groups.create.`{color.field, fontSize.fieldText, fontWeight.fieldText, fontSize.title,
    fontWeight.title, color.buttonDisabledFill, color.buttonDisabledLabel, size.cover.width, size.cover.height,
    radius.cover, color.cover, size.coverGlyph, size.sheetTopToTitle, size.titleToContent, size.mediaToField,
    size.fieldToButton, layout.titleAccent, color.hud, size.hud, fontSize.hudLabel}; `groups.list.`{color.card,
    size.cardHeight, size.avatarInset, size.cameraGlyph, size.coverHeight, color.headerCircleOverPhoto};
    `groups.screen.`{size.cardHeight, size.cardMarginH, size.cardGap, radius.card, size.chatPillWidth,
    size.chatPillHeight, color.chatPill, fontSize.chatPill, radius.lightPill, size.lightPillHeight, size.profileAvatar,
    fontSize.profileName, fontWeight.profileName, size.segmentHeight, size.segmentMarginH, size.segmentInset,
    color.segmentTrack, fontSize.segmentLabel, fontWeight.segmentLabel, layout.background}; `groups.invite.`{size.pickerRowPitch,
    fontSize.pickerName, fontWeight.pickerName}; `onboarding.permission.notifications.`{color.secondaryButton, size.buttonGap};
    `onboarding.permission.contacts.`{color.card, size.cardHeight, size.cardMarginH, fontSize.cardTitle, fontWeight.cardTitle,
    fontSize.cardDetail, size.cardButtonWidth, size.cardButtonHeight, layout.card}; `onboarding.widget.`{color.backgroundTop,
    color.backgroundBottom, fontSize.title, fontWeight.title, color.title, fontSize.step, fontWeight.step, lineHeight.step,
    color.step, size.ctaHeight, color.cta, color.ctaLabel, fontSize.ctaLabel, size.ctaPaddingH, size.ctaArrowGap,
    size.ctaArrow, icon.ctaArrow}; `paywall.`{color.backgroundTop, color.backgroundUpper, color.backgroundLower,
    color.backgroundBottom, layout.iconTileArt, fontSize.title, color.title, fontSize.subtitle, lineHeight.subtitle,
    color.subtitle, size.perkHeight, size.perkMarginH, size.perkGap, radius.perkOuter, radius.perkInner, color.perk,
    size.perkIcon, size.perkTextInset, fontSize.perkTitle, fontWeight.perkTitle, color.perkTitle, fontSize.perkSubtitle,
    color.perkSubtitle, size.ctaHeight, color.cta, fontSize.ctaLabel, color.ctaLabel, icon.ctaUnlock, fontSize.dismiss,
    color.dismiss, layout.planSheet, color.planSheetTop, color.planSheetBottom, fontSize.planSheetTitle,
    lineHeight.planSheetTitle, size.planMarginH, size.planSelectedHeight, size.planHeight, size.planBorder, color.planBorder,
    color.planSelected, color.plan, fontSize.planName, fontSize.planDetail, color.planDetail, size.subscribeHeight,
    color.subscribe, fontSize.subscribeLabel, color.subscribeLabel}; `settings.root.`{size.listItemOneLine.android,
    size.listItemPaddingH.android, size.listItemPaddingV.android, size.listItemAvatar.android, size.divider.android};
    `settings.blocked.layout.empty`; `safety.block.`{layout.toast, duration.toast}; `invite.appclip.`{fontSize.sheetInput,
    opacity.sheetPlaceholder.light, opacity.sheetPlaceholder.dark, fontSize.sheetHelper, opacity.sheetHelper.light,
    opacity.sheetHelper.dark}; and every Partiful-era `invite.web.*` token (`dimension.*`, `color.text.*`, `color.theme.default`,
    `layout.theme*`, `font`, `lineHeight.default`, `opacity.*`, `layout.text`, `layout.link`, `fontSize.title.*`,
    `count.title.maxLines`, `layout.title*`, `fontWeight.*`, `letterSpacing.title`, `radius.*`, `layout.cover`,
    `fontSize.sectionHeader`, `fontSize.button.medium`, `blur.*`, `color.button.filled.*`, `duration.button.*`,
    `easing.button`, `color.gateCard.*`, `fontSize.detail`, `icon.lock`, `icon.getApp`, `layout.state*`,
    `fontSize.state.*` — 100 names in `web/src/render/css.ts`, `web/scripts/verify.ts`, `web/src/contrastReport.ts`,
    `web/src/titleFit.ts`, `web/src/theme.ts`, `web/src/images.ts`, `web/src/render/pages.ts`, `web/src/render/icons.ts`,
    the iOS `Features/Account/Shared/InvitePreview/*` views and `android/…/account/invite/InviteJoinScreen.kt`).
  - Copy: `auth.phone.toast.codeSent`; `auth.code.offline.detail`; `auth.agegate.offline.detail`; `auth.profile.offline.detail`;
    `onboarding.permission.contacts.`{card.title.friends, card.title.family, card.title.roommates, card.title.custom,
    card.dismissAccessibilityLabel}; `groups.list.`{cover.accessibilityLabel, error.detail, error.retry};
    `groups.create.hud.loading` (11 files); `groups.invite.title.`{friends, family, roommates, custom};
    `groups.screen.`{header.accessibilityLabel, photo.more.accessibilityLabel, photo.menu.open, memberJoined,
    profile.more.accessibilityLabel, profile.segment.pics, profile.segment.wall, profile.segment.recaps, menu.shareInvite,
    menu.settings, menu.leave, menu.report, error.detail, error.retry}; `groups.settings.`{notifications.mute, shareInvite};
    `settings.blocked.retry`; `safety.report.`{explanation, details.placeholder, submit, sent.message, sent.messageGroup,
    sent.block, sent.done}; `paywall.`{subtitle, perk.video.emoji, perk.widgets.emoji, perk.history.emoji, perk.export.emoji,
    cta, dismiss, plans.title, plans.selected.accessibilityLabel, legal.renews}; `invite.web.`{members.viewAll, gate.title,
    gate.body, state.glyph, state.glyphLabel}; `invite.appclip.`{sheet.name, sheet.phone, sheet.helper, sheet.cancel,
    sheet.continue, join, full.glyph, full.glyphLabel}.
  - Files: the account feature on both platforms (`ios/App/Sources/Features/Account/**`, `ios/App/Sources/Screens/{GroupsHomeScreen,GroupScreen}.swift`,
    `android/feature/account/**`), shared components that borrowed account tokens (`ios/App/Sources/Components/{FormField,
    PrimaryButton, LoadingHUD, Toast, PermissionCard, LightPill, EmptyStateView, SegmentedPills, OnboardingTitle,
    TextRoles, CheckRow, HeaderCircleButton, FloatingTabBar, BlockConfirmation, StorageImage, DesignGaps}.swift`,
    `android/core/ui/…/{components/{Buttons, LoadingHud, PermissionCard, EmptyState, Selection, SegmentedControl, Avatar},
    text/TextRoles, system/SystemList, paywall/PaywallGate}.kt`), the memory / social / capture screens that reused them
    (`BirthdayDateField`, `MemoryControls`, `MemoryUi.kt`, `WeekViews`, `SocialStyle`, `SocialServices`, `EditScreen.kt`,
    `PhotoViewerScreen.kt`, `ChatThreadView`, `PhotoViewerView`), tests (`ios/AppTests/Account/*`, `android/…/account/src/testDebug/*`,
    `ios/AppTests/Social/SocialSnapshotTests.swift`, `backend/worker/test/unit/copy-tokens.test.ts`) and the web page.
    Their replacements are components: C-12 field, C-05 capsule (busy / disabled), C-28 loading, C-26 toast, C-27 empty /
    permission block, C-06 / C-09 pills, C-29 native segmented / menus, C-14 rows, C-04 tab bar.
- **Kept keys whose placeholders changed** (Swift / Kotlin signatures change): `groups.list.row.sentPic` and `.newPic`
  (`{time}` dropped), `groups.screen.photo.accessibilityLabel` (`{time}` → `{date}`), `groups.screen.created.detail`
  (`{names}` dropped), `groups.settings.members.more.accessibilityLabel` (`{first_name}` dropped),
  `safety.report.title.user` / `.group` (name dropped), `groups.invite.link.label`
  and `invite.web.members.title` (`{group_name}` added), `paywall.plans.yearly.detail` (`{monthly_equivalent}` → `{yearly_price}`).
- **Keys that left BLOCKED** (now in `Copy`, no longer in `BlockedCopy` — the iOS `AccountBlockedCopy` wrappers and Android
  `BlockedValues.kt` read them from the debug-only tables): `auth.agegate.underAge.title`, `settings.root.premium.subtitle`,
  `settings.notifications.off.footer`, `system.permissions.rationale.{camera,microphone,notifications,contacts}.message`,
  `paywall.welcome.body`; token `safety.report.layout.reasons` (was `BlockedTokens`; `DesignGaps.swift`, `BlockedValues.kt`).
- **Layout tokens whose fields changed** (code reading `Tokens.Layouts.X.field` must follow): `auth.phone.layout.countryCode`
  (+ `field`), `auth.phone.layout.inlineError`, `auth.code.layout.codeField`, `auth.agegate.layout.optIn`,
  `onboarding.permission.notifications.layout.preAlert`, `onboarding.permission.photos.layout.request`, `groups.list.layout.tabBar`,
  `groups.screen.layout.menu`, `groups.invite.layout.share`, `settings.root.layout.list`, `safety.report.layout.flow`,
  `safety.report.layout.reasons`, `invite.web.layout.ogImage`, `invite.web.layout.linkPreview`, `invite.appclip.layout.*`.
- **Web**: the invite page (`web/src/**`) is rebuilt from the new `invite.web.*` tokens (Retro `/u/` card, desktop QR,
  600 × 600 OG image); Pass 4's agent list names iOS / Android only — the lead assigns the web page.
- **Foundations candidates**: the grouped-row height 58.7 (TC-J5) closes C-14's row-height Gap and could become a global
  token; the cover shadow fit could update `layout.global.elevation`; `invite.web.radius.card` equals `radius.global.cardLarge`.
- **Shared components (lead request):** the account keys Pass 3 components read are kept (`groups.list.tab.*`,
  `onboarding.permission.camera.denied.*`, `onboarding.permission.photos.denied.*`, `safety.block.*` — `done` / `undone`
  keep `{first_name}` — and `auth.phone.error.dismiss`); four component strings are added in `design/copy/account.json`
  with surface `global`: `global.a11y.newBadge` ("New", Retro verbatim), `global.a11y.unread` ("New activity", PLATFORM),
  `global.a11y.pagePosition` ("{position} of {count}", Retro's position badge), `global.a11y.loading` ("Loading…", PLATFORM).
- **Capture group:** tab bar media variant recorded in `groups.list.layout.tabBar.overMedia`; `onboarding.widget` names the
  widget with `widget.home.small.gallery.name` and shows `widget.arrival.help.delay`.
- **Memory group:** `groups.screen` places the on-this-day and year-story entry cards in its members' pager (C-18
  geometry, `displaySmall` title, C-09 pill) and the birthday request row (C-14 + C-16) above the week; `settings.account`'s
  Birthday row pushes `birthday.add`.
- **Social group:** `groups.screen` header book glyph → `albums.list`, chat glyph → `chat.thread`, week header chevron →
  `week.history`, "Recaps" capsule → `week.recap` (list); `walls.mine`'s gear capsule → `settings.root`; `walls.member`
  report / block → `safety.report` / `safety.block`.

### Unresolved (owner, capture or verification)

- Owner: app name and mark (landing wordmark, App Clip card), template cover photos (decided: OD9-1), QR invite card (decided: OD17-1),
  Rewind / Activity tabs (RA-7), the purple premium accent (RA-17), moderation categories / report details (RA-12),
  tier name "Premium", support e-mail, legal URLs, invite domain, `min_age_years`.
- Captures (each closes a composition): Retro's first 4 sign-up steps and onboarding pages on a fresh install; Retro's
  Settings (top + scrolled) and an album's Settings, light and dark; a raw album detail (light and dark); the album link
  sheet in dark; a `/u/` page in iPhone Safari with the photo loaded; Retro's paywall with Annual / Monthly cards;
  Retro's report sheet and block dialog; Retro's App Clip opened from a `/u/` link; the "Ideas to Get Started" "•••" menu.

## Owner decision 16 — voice waveform and recording pause (V-*)

Owner decision 16 (`docs/OWNER_DECISIONS.md`, 2026-10-16) adds a waveform to voice notes; the same pass adds pause /
continue / preview to a locked recording (both platforms had none). Measurements: `design/research/voice-waveform.md`
(tool `tools/measure_bars.py`). New: component C-36 (`design/components.md`), tokens `size.global.waveformBarWidth`,
`.waveformBarGap`, `.waveformBarMinHeight`, `layout.global.waveform`, `chat.voice.dimension.waveform`,
`chat.voice.layout.locked`; copy `chat.voice.a11y.pauseRecording`, `.resumeRecording`; API `voice_levels`
(migration `20261015000017_voice_levels.sql`, docs/API.md §5.8 / §5.9 / §6.2).

| id | question | references | decision | reason |
|---|---|---|---|---|
| V-1 | waveform at all (RS-7 said none) | Messages, WhatsApp, Telegram all draw one | C-36 in Retro's colours | owner decision 16 supersedes RS-7 |
| V-2 | bar width / gap | Messages 2.02 / 2.07 pt (1.11 px/pt, 38 bars); WhatsApp iOS 2.63 / 1.88 pt (2.37 px/pt ±5 %) | Messages' (2.0 / 2.1) | Apple's own audio message, exact device scale; WhatsApp within 0.6 pt |
| V-3 | bar heights | WhatsApp draft capsule: max 0.553 of the capsule, silent bars = dots; Telegram Desktop: height ∝ level ÷ the note's max | max = 0.553 × holder height, min = bar width, scaled to the note's own max | the only capsule-shaped reference (the voice capsule is a capsule); two WhatsApp images agree on dots |
| V-4 | bar count | WhatsApp: one bubble width for every duration; Telegram Desktop: ⌊width ÷ (bar + skip)⌋, ≤ 100 | width-driven, peak per bucket | one rule for the 154-pt capsule, the recording field and the send-to capsule |
| V-5 | waveform length | Messages 154.1 pt, WhatsApp ≈ 151 pt | 154 | both apps; 38 bars like Messages |
| V-6 | played / unplayed / idle | WhatsApp share 0.41, Telegram 0.33; idle all unplayed (WhatsApp, Telegram Desktop) | played `textPrimary` / `textOnMedia`, unplayed `textSecondary`, idle unplayed, split bar at the progress | nearest Retro global colour (0.365 light); Telegram's unread all-accent state is a read state (tenets) |
| V-7 | data | Telegram API: 100 five-bit values; example implementation: peak per bucket, scale max(2500, 1.8 × mean) | 100 smallint of 0…31, validated server-side, optional | same format on both platforms; unpacked for simple validation |
| V-8 | notes without levels | Telegram Desktop: flat bars at the minimum until the file is loaded, then computed from the audio | the same | old notes and clients that send none still draw |
| V-9 | locked recording layout | WhatsApp blog panels: field with time + live waveform; row of trash · pause / mic · send | two rows: C-13 field + controls row (bare trash, C-11 circle with red pause / mic, C-11 circle in the primary fill for send) | WhatsApp's order in Retro components (green → primary fill, red ring → C-10 red glyph) |
| V-10 | preview of a paused draft | WhatsApp FAQ "preview a draft"; Messages "Listen to review it", "Continue Recording" | pause = platform pause; first preview closes the segment, continue starts a new one, send joins the segments | MPEG-4 is finished only by `stop()` |
| V-11 | send-to: where the kept note's waveform goes | no reference composes a voice note with a photo | the note capsule (same as the thread, 154-pt waveform) centred `size.global.pillGap` above the message pill + mic pair; the mic records a replacement | the pair has no room for a 154-pt waveform; the message pill keeps Retro's label |
| V-12 | live waveform direction / rate | WhatsApp panels draw the whole recording across the width (0:07 → 77 bars; 0:11 draft in its capsule) | live = the samples so far reduced like a stored note, across the available width | the only still evidence; what you see is what is sent |

**Android parity (send-to).** Android's send-to voice capsule recorded press-and-hold only (no lock, no draft, no
playback of the kept note) while iOS had lock and a stopped draft; both now follow `chat.voice.layout.locked` and the
note capsule (rule 9: both platforms behave the same).

**Built since** (`chat.voice.layout.scrub`). Scrubbing along the waveform: while a note plays or is paused part-way a horizontal drag seeks (Apple Voice Memos drags its waveform to change where playback begins); the tap stays play / pause; VoiceOver / TalkBack adjust in 5-s steps.

## Owner decisions 7, 18, 21 — premium, true black, lock-screen widgets (OD7-*, OD18-*, OD21-*)

Pass: 2026-10-16, implementing `docs/OWNER_DECISIONS.md` #7 (premium), #18 (Android lock-screen widgets) and #21 (Android
dark background). Files: tokens `color.global.background.android.trueBlack`, `color.global.system.surface.trueBlack`
(global.json), `paywall.size.planPillInset` (account.json), `widget.android.layout.lockScreen` (capture.json); copy
`settings.root.appearance.header`, `settings.root.trueBlack`, `settings.root.trueBlack.detail`; specs `paywall`,
`settings.root`, `widget.android`; `docs/OWNER_SETUP.md` §0, §1.6, §2.3; `docs/PLATFORM_CONSTRAINTS.md` §4.2, §8.

### Evidence gathered in this pass

| what | source | used for |
|---|---|---|
| Retro's label for its true-black option | re-downloaded the same XAPK (2026.10.1150, SHA-256 `b8bfab18…bd8237`, identical to RP §1) and searched the four dex string tables (`strings -n 3 classes*.dex`, case-insensitive "black", "amoled", "oled", "pure", "dark mode") and the 1,814 string resources (APK-S): only library names (`abc_*_black_*`, `quantum_black_*`, `BLACK`) — **no user-facing string names the option**; the flag reaches `gfb.f(isDark, trueBlack, …)` without a label (it may be internal / remote). Download deleted after the search. | OD21-1 |
| The option's words and mechanics in a widely used Android app | AntennaPod `ui/i18n/src/main/res/values/strings.xml` `pref_black_theme_title` "Full black", `pref_black_theme_message` "Use full black for the dark theme"; `ui/preferences/.../preferences_user_interface.xml`: a `SwitchPreferenceCompat` (default false) in its "Theming" category next to the theme choice (GitHub raw, read 2026-10-16) | `settings.root.trueBlack`, `.detail`, the switch row |
| Section header | Mastodon for Android `strings.xml` `settings_theme` "Appearance" | `settings.root.appearance.header` |
| What true black changes in Retro | APK-X 'Retro root theme' (`colorScheme = isDark ? (trueBlack ? d42.w : d42.v) : d42.u`), 'Retro palette' (d42.w = d42.v except background / surface #000000), 'Retro semantic colour accessor' (only `vv3.k` reads the flag: `isDark ? (trueBlack ? Color.Black : #1C1C1E) : #FFFFFF`) | the two `….trueBlack` tokens; rows, controls, text unchanged |
| Retro's FREE pill on the plan card | PAY row y=1487 (3.000 px/pt): card x 61.5–1143.5, pill x 933.5–1085, title ink from x142 (cap y1465–1514), pill rows 1446–1528 | `paywall.size.planPillInset` 19.5 (outside the 27-pt text padding), centred on the title's cap middle |
| Play free trial representation | Play Billing `ProductDetails.PricingPhase` (`getBillingPeriod` "P1W equates to one week", `getPriceAmountMicros`); "a maximum of 50 user eligible offers per subscription" (billing/integrate); Play Console Help 12154973 (free trial 3 days – 3 years); RevenueCat purchases-android 10.27.1 `SubscriptionOptions.defaultOffer` ("longest free trial or cheapest first phase"), `SubscriptionOption.freePhase` (first zero-priced phase before the last), `GoogleStoreProduct.purchasingData` = `defaultOption`, `pricingPhaseConversions.kt` (1 : 1 from Play) | core:billing `FreeTrial`, `PremiumPackage.freeTrial` |
| iOS trial eligibility | RevenueCat purchases-ios 5.95.0 `checkTrialOrIntroDiscountEligibility(product:)`: "The best course of action on unknown status is to display the non-intro pricing" | `PurchasesService.isEligibleForIntroOffer` |
| Lock-screen hub | Android Developers Blog 2025-03-06 FAQ; `AppWidgetProviderInfo` reference (WIDGET_CATEGORY_KEYGUARD, API 17; NOT_KEYGUARD, API 36); Glance `setWidgetPreviews` default categories | `widget.android.layout.lockScreen`, provider XML |

### Conflicts and resolutions

| # | topic | values and sources | resolution | rule / evidence | status |
|---|---|---|---|---|---|
| OD21-1 | Label of the true-black option | Retro: the scheme exists (d42.w) but no string names it; decision 21 calls it "True black"; AntennaPod "Full black" / "Use full black for the dark theme" | "True Black" (Title Case, `retro.voice.settings`) / "Use true black for the dark theme." — AntennaPod's switch with "full" → "true" (the decision's name for Retro's scheme), under the header "Appearance" (Mastodon) | any widely used app may supply what Retro does not show (2026-10-15); copy-patterns `retro.voice.settings` | resolved |
| OD21-2 | Where the switch sits | Retro's Settings has no appearance section; AntennaPod: a Theming section with the switch | Android Settings: "Appearance" after "Widgets" (both are how the app looks on this device), one C-14 toggle row; always listed (it names the dark theme); iOS: none (its page is already Retro's iOS #000000) | composition of C-14 + native switch (C-29) in AntennaPod's order; decision 21 "Android only" | resolved |
| OD21-3 | What it changes | d42.w vs d42.v differ only in background / surface; vv3.k is the only semantic colour that reads the flag | page (`PageRoles.page`, window background, bar scrims, tab bar, sheets) and M3 background / surface → #000000 in **dark only**; rows #262626, controls, text, separators unchanged; light unchanged | APK-X | resolved |
| OD21-4 | Persistence | other device settings: SharedPreferences behind an interface with an in-memory twin (`DeviceAccountStores`, `SharedCapturePrefs`) | core:ui `AppearanceSettings` (prefs "appearance", key `true_black`, default off) as a StateFlow; `MainActivity` provides it to `AppTheme` and repaints the window when it changes | as the app persists settings | resolved |
| OD7-1 | Prices | `config/app.json` 3.99 / 35.99 (already); iOS snapshot fixtures $29.99 / $2.49; Android fixtures $35.99 | every fixture $3.99 / $35.99; the unused iOS `monthlyEquivalent` (a per-month line the spec does not list — A-2) removed | decision 7; paywall.md | resolved |
| OD7-2 | Android trial | core:billing exposed none (REVIEW known gap) | `FreeTrial.of(phases)` over the purchased offer's phases → `PlanOption.trialDuration` (ICU `MeasureFormat` WIDE "1 week") → pill + "Try 1 week free" + "And then billed … yearly after", as iOS | Play / RevenueCat docs above | resolved |
| OD7-3 | iOS trial shown to ineligible people | `introductoryDiscount` alone (a returning subscriber saw "Try 1 week free" but would be charged) | trial UI only when `checkTrialOrIntroDiscountEligibility` = eligible; unknown → plain card | RevenueCat guidance; App Store 3.1.2 "trick users" | resolved |
| OD7-4 | Pill position | spec: "trailing premium pill" (inside the 27-pt padding on both platforms) vs PAY 19.5 pt from the edge | `paywall.size.planPillInset`; the pill shifts by planCardPadding − planPillInset (7.5) | PAY measurement above | resolved |
| OD7-5 | Paywall walk (Android vs spec / iOS) | busy capsule on both cards while one plan was bought; restore failures offline said "No previous purchases found"; plan pager steps played no tick; loading indicator in page grey | busy = the bought plan only (a second tap ignored); offline restore → `paywall.offline` (as iOS); `haptic.global.select` on plan pager steps; indicator in `paywall.color.planTextTertiary` | paywall.md States / Haptics | resolved |
| OD7-6 | History perk (T1) | `free_history_days` NULL in the foundation migration | stays NULL; the perk is not listed on either platform (tests on both); iOS `default` snapshot no longer seeds it | decision 7 | resolved |
| OD18-1 | Lock-screen widgets | provider `home_screen` (owner question) | `home_screen|keyguard`; the hub slot (≈ 4 × 3 cells) renders the Medium layout (snapshots); taps need unlock; preview covers keyguard (Glance default) | decision 18; platform docs | resolved |

## Owner decisions 9, 10, 13, 17 — template covers, "members", first screen, QR invite card (OD9-*, OD10-*, OD13-*, OD17-*)

Surfaces: `groups.invite`, `groups.list`, `groups.create` (step A rows), `walls.browse`, `chat.thread` (empty state). Tokens
`groups.invite.icon.qr`, `groups.invite.fontSize.qrTagline`, `groups.invite.layout.qrCard`, `groups.list.layout.templateCovers`
(design/tokens/account.json); copy `groups.invite.link.qr`, `groups.invite.qr.*` (account), `walls.browse.title`,
`walls.browse.error.title`, `chat.thread.empty.invite` (social). Licences: `android/feature/account/licenses/ZXing-*`,
`fixtures/photos/LICENSE.md` → "Shipped in the apps".

### Evidence gathered in this pass

| what | source | used for |
|---|---|---|
| Retro's link-sharing targets | TC-J5 phone 2: four 64-pt circles "QR Code · Copy Link · Instagram · Share to…"; QR glyph ink 23.2 × 23.2 pt (x 1557–1604, y 2343–2390) | target order, `groups.invite.icon.qr` |
| Retro's QR strings and tiny print | APK-S `journal_settings_link_sharing_qr_code_cta` / `journal_broadcast_invite_option_qr_code` "QR Code", `journal_qr_code_action_sheet_title` "Share Link", `qr_card_content_subtitle` "Retro.app - Photos with Friends", `qr_card_content_member_since_template`, `friends_tab_profile_qr` "Profile QR code"; APK-X `osg.g cs1.java:165` 10 sp next to the subtitle | QR copy, `groups.invite.fontSize.qrTagline` |
| What Retro's QR is for | TechCrunch 2024-04-04 (accessed 2026-10-16): "this very beautiful QR code that you can either save to your camera roll or print" | Save + Share (print in the share sheet) |
| Images of Retro's in-app QR card | searched the web (TechCrunch, Engadget, Product Hunt, App Store / Play listings, Retro's site): none found; retro.app desktop pages show only the web QR (WEBD; `/j/` small QR at 0.7 scale beside "Scan to view this journal on the mobile app.") | the card is a composition (below) |
| Quiet zone and colours | DENSO WAVE qrcode.com "QR Code requires a four-module wide margin at all sides of a symbol." (accessed 2026-10-16); Tor Browser issue 41049 (inverted dark-theme codes not read by some readers) | `quietZoneModules` 4; the card stays white in dark |
| Retro's journal noun | retro.app `/j/` "7 members • 24 photos", "%1$s invited you to join the private journal" (RP §7); APK-S `journal_edit_members_screen_title` "Members", `journal_profile_add_members` "Add Members" | the "members" audit |
| Template covers | every photo in `fixtures/photos/` viewed at full size (contact sheets + full-resolution crops): no person at all in road-trip-window, cake-chocolate-candles, pizza-table, sunset-lake, picnic-spread, plants-shelf, succulents, coffee-cup-top, coffee-latte-heart, cat-orange, cat-window, kitten-yawn, dog-beach-run; small or blurred figures in sunset-sea, city-night-street (also a shop sign), autumn-path, autumn-bike, campfire-woods, birthday-cake-candles (a blurred figure behind the cake); hands and heads in food-plates, dinner-pizza-cheers, dinner-toast-candles; a hand in ice-cream-cone; every other photo shows people | `groups.list.layout.templateCovers` |

### Conflicts and resolutions

| # | topic | values and sources | resolution | rule / evidence | status |
|---|---|---|---|---|---|
| OD17-1 | Where the QR lives | RA-11 left it to the owner; decision 17: in the invite sheet | a fourth share target, first as in TC-J5: QR Code · Copy Link · Message (in Instagram's place, the platform's own messages app) · Share to…; narrow screens share the width in quarters | TC-J5 | resolved |
| OD17-2 | The card's look | Retro's QR card art never captured; its strings point to a card with tiny print, like its recap card "2023 / nathan / retro.app" (TC-H) | the recap card shell (`layout.year.story.recapCard`, white in both appearances, L-4) with the code in its grid area; footer = group name (`displayTitle`) over the 10-pt tagline in `groups.invite.color.note` (#767676: Retro's grey on this sheet, 4.54 : 1 on white), placed by Retro's recap-footer baselines (TC-REC: last baseline 0.0637 × width above the bottom edge, name → detail pitch 0.056 × width — the first build centred the line boxes and sat the tagline too low, lead review of run 64); shown in the recap preview (ST-04: blurred cover, close, Save circle, Share pill) | composition of C-34, C-11, C-09 in Retro's recap-preview order | resolved |
| OD17-3 | Encoding | web: qrcode-generator EC H, whole-pixel modules, black on white (`web/src/render/qr.ts`); Retro's desktop QR has rounded modules | reuse the web's parameters (EC H, square whole-pixel modules, black on white) so both QR surfaces match; quiet zone made explicit (4 modules inside the white card); iOS CoreImage, Android ZXing core 3.5.3 (Apache-2.0) | task: reuse web encoding; DENSO WAVE | resolved |
| OD17-4 | Centre image | web `/i/` puts the inviter's avatar over the code (Retro `/u/`) | none on the card: the footer names the group, and Save / Share export the card alone; EC H kept for printed wear | — | resolved |
| OD17-5 | Copy from Retro's card | "Retro.app - Photos with Friends", "Member since %1$d" | tagline "Photos with friends and family" (domain dropped — owner's, BLOCKED; noun as `invite.appclip.card.subtitle`); "Member since" not copied (a person's join year) | copy-patterns `retro.voice.share` | resolved |
| OD17-6 | Actions | TechCrunch: save to camera roll or print; APK: profile QR sheet has share options | Save (photo library: iOS add-only, Android MediaStore; denied → Settings alert) and Share (system sheet, which offers Print / Save Image) | — | resolved |
| OD10-1 | "friends" audit | 11 strings contain "friend" | changed (the people of your groups): `walls.browse.title` "Friends" → "Members" (closes S-12), `walls.browse.error.title` "Error loading friends…" → "Error loading members…", `chat.thread.empty.invite` "Invite friends" → "Add members"; kept (friends in general or the Friends kind): `auth.phone.tagline`, `groups.create.type.friends` (+ `.detail`), `groups.screen.created.invite.friends`, `groups.settings.members.invite.friends` (the Friends kind's own noun, beside "Invite Family" / "Invite Roommates"), `camera.sendto.empty.detail`, `invite.web.og.description`, `invite.appclip.card.subtitle` | decision 10 | resolved |
| OD13-1 | First screen | iOS opened the camera at every launch with a session; Android only with ≥ 1 group (`RootGate`) | iOS `AccountSession.start` waits on `LaunchingView` for `hasGroups()` (the cached list, else the first fetch; a failed fetch = none) and lands on the camera only with a group; a sign-out during the check wins | decision 13; parity with Android | resolved |
| OD9-1 | Template covers | placeholders (REVIEW known gap) | friends `road-trip-window-3x2`, family `cake-chocolate-candles-4x5`, roommates `pizza-table-3x4`, custom `sunset-lake-9x16`; `picnic-spread-3x4` (best "friends" match) dropped for its wine (alcohol reference in a bundled asset); 216 × 291 px JPEG q80 in the iOS asset catalog (new: `ios/App/Resources/Assets.xcassets`, `ASSETCATALOG_COMPILER_APPICON_NAME` "" until the owner's icon — OWNER_SETUP §0.2) and Android `feature/account` `drawable-nodpi` | decision 9; Unsplash License | resolved |

### Unresolved (capture)

- One screenshot of Retro's journal "QR Code" sheet would replace the composed card with Retro's own layout.

## Owner decisions 12 and 22 — your own photos leave the app; Locket evidence re-sourced; share-image fonts (OD12-*, OD22-*)

Surfaces: `onthisday`, `year.story`, `birthday.tribute`, `photo.viewer`, `chat.thread` (decision 12); `collage.share`,
`week.recap` (stated as group pieces); `auth.phone`, `camera.capture`, `camera.fromwidget`, `onboarding.widget`,
`chat.reactions`, `notifications.push` (decision 22); worker tribute renders and the web invite image (fonts). Code:
iOS `Features/Memory/{OnThisDay, YearStory, Birthday}`, `Features/Social/{UI/PhotoViewerView, Core/PhotoViewerModel,
UI/ChatThreadView, Core/ChatThreadModel}`; Android `feature/memory/…/{onthisday, yearstory, birthday}`,
`feature/social/…/{viewer/PhotoViewerScreen, chat/ChatScreen}`; `backend/worker/{fonts/fonts.conf, src/tribute/render.ts}`;
`web/{assets/fonts/fonts.conf, src/images.ts}`; `fonts/fallback/` (+ `SOURCE.txt`).

### Owner decision 12 — sharing outside the app

| # | action | before | now | evidence | status |
|---|---|---|---|---|---|
| OD12-1 | On This Day share circle and menu "Save to Camera Roll" | every memory | your own memory only; on another member's memory the share circle's place stays empty (no layout shift) and the menu offers Report | Retro's Rewind and Timehop resurface only your own photos; BeReal offers no way to share another person's post | resolved (RM-6 closed) |
| OD12-2 | Year story most-reacted photo cards (Share pill) | every photo card | your own photo only; the pill is not shown on another member's photo | same | resolved |
| OD12-3 | Tribute video Save / Share | honoree and members | honoree only (the tribute is the honoree's gift, as Tribute / VidDay hand the video to the recipient); members get no bottom row and no local copy | same; Tribute / VidDay delivery | resolved |
| OD12-4 | Photo viewer and chat photo message "Save to Camera Roll" | every photo | your own photo only: saving to the camera roll takes the photo out of the app; others' photos keep Report / Block | same | resolved |
| OD12-5 | Group pieces made for sharing | — | keep Share for every member: same-moment collage pages (`collage.share`), the year story's text cards, everyone-was-there collages and summary styles (recap card, full-bleed cover); the week recap has no outside action ("Save as Album" is in-app) | Retro's recap preview and Spotify Wrapped share the recap as a whole | resolved |

Tests: iOS `MemoryOnThisDayTests` (own-only save / share, mode menu), `MemoryYearStoryTests`, `MemoryTributeTests`,
`SocialPhotoViewerModelTests`, `SocialChatThreadModelTests`, `MemoryOnThisDayUITests`; Android `OnThisDayViewModelTest`,
`YearStoryViewModelTest`, `TributeAndAddViewModelTest`, snapshots `onthisday_*` (own / others), `year.story` (no Share on
another member's card), `birthday.tribute` (member view), social viewer / chat menus.

### OD12-F — fallback fonts for server-rendered text (closes the RM-12 colour-emoji hand-off)

| what | worker (tribute title / end cards, captions) | web (invite share image `og.png`) |
|---|---|---|
| renderer | libvips `text` (Pango + cairo 1.18.6): draws COLRv1 colour emoji | librsvg: SVG text as filled outlines (a colour font comes out as a silhouette) |
| emoji | Noto Color Emoji COLRv1 v2.051 (4.99 MB) | Noto Emoji, monochrome, wght 400 (0.89 MB) |
| scripts | Noto Sans / Serif: Arabic (Naskh for the serif role), Hebrew, Devanagari, Thai; Noto Serif Greek (Roboto Serif has none); Noto Sans SC subset (16,507 Han of GB 2312 / Big5 / JIS X 0208 / KS X 1001 + kana, 6.14 MB); Noto Sans KR Hangul subset (2.70 MB); Cyrillic from the app faces | same `scripts/` folder |
| config | `backend/worker/fonts/fonts.conf` (`FONTCONFIG_FILE`; aliases `serif` / `sans-serif` list the order) | `web/assets/fonts/fonts.conf` |
| image size added | 15.2 MB (`scripts/` + `emoji-color/`) | 11.1 MB (`scripts/` + `emoji-mono/`) |

All SIL OFL 1.1, licence files beside the fonts; how each file was made: `fonts/fallback/SOURCE.txt`. The two emoji
fonts live in separate folders because Pango drew emoji from the monochrome font whenever fontconfig could see both.
CJK renders in the sans regular weight in both roles (a serif CJK face would add ≈ 20 MB). Tests: worker
`test/unit/fonts-render.test.ts` (47: each script against its cmap, no tofu, colour emoji pixels, ZWJ / flag
sequences), web `test/unit/og-fonts.test.ts` (43). Deployment: both Dockerfiles copy the folders; `docs/DEPLOY.md`.

### Owner decision 22 — Locket values re-sourced from public evidence

The decompiled bundle (`references/auto/locket/apk/locket-1.243.0-hermes-excerpts.txt`, kept on disk as the record of
what was read) is no longer cited by any token or string; the research files `design/research/locket.md` and
`design/proposals/locket.*.json` are the history of that pass and are not canonical.

| # | token / string | before (bundle) | now | public evidence | status |
|---|---|---|---|---|---|
| OD22-1 | `auth.phone.layout.countryCode` | flag 20 × 13, 20 leading, 5 to the text (G2-4) | flag 30 × 20 at the field's leading edge (19 = the field's own inset), 10 to the text | react-native-phone-input 1.4.1 (MIT, public npm package) `styles.js`; Android `PhoneNumberFormattingTextWatcher` for the inline formatting | changed (iOS / Android snapshots re-recorded) |
| OD22-2 | `camera.capture.size.recordingOutline` | 6 (G2-9) | 4: Material 3's progress-indicator stroke; the outline itself from Locket's help centre ("The yellow outline around the viewfinder indicates that capture is in progress.") | help.locket.com 7915017; androidx material3 `CircularProgressIndicatorTokens` | changed; no public frame of Locket recording found (Gaps) |
| OD22-3 | `auth.phone.layout.inlineError`, `camera.sendto.size.captionMaxLength` | Locket alert pattern (G2-5); 36 (G2-11) | Retro's titled error alerts; 250 (Retro's message counter "58/250") | Retro strings; TC 2023-12 phone 3 | already replaced; notes reworded |
| OD22-4 | `camera.fromwidget.layout.target` | store screenshots + bundle strings (`logOpenedFromWidget`, widget launch URL) | bundle strings dropped; App Store / Play screenshots "Tap the widget to open the camera"; Apple WidgetKit docs (`widgetURL`) | store listings | evidence replaced, value unchanged |
| OD22-5 | `widget.home.small.layout.photo`, `widget.android.layout.provider`, `notifications.push.layout.channels`, `camera.sendto.layout.header` | bundle mentions in evidence / notes | Retro's widget previews and providers, Android developer docs (app widgets, notification channels), Locket's capture-review frame | public | evidence replaced, values unchanged |
| OD22-6 | copy `onboarding.widget.step.android.1`–`.3` | bundle string table | "From your Home Screen, touch and hold on an empty space." / "Tap Widgets." / "Search for “{app_name}”, tap on the widget, then tap Add." | help.locket.com 7914857 (verbatim, name swapped) | changed |
| OD22-7 | copy `chat.reactions.activity.row` / `.rowMine`, `notifications.push.reaction.body`; pattern `locket.push.reaction` → `messaging.reaction` | bundle push string "{{contactName}} reacted {{emoji}} to your Locket" | same shape, sourced from WhatsApp's help and the Apple iPhone User Guide (tapbacks) | public help pages | evidence replaced, texts unchanged |
| OD22-8 | `spring.global.sheetPresent` | — | Retro's measured spring; the React Navigation value it superseded is public source, not the bundle | — | note reworded |

Not in scope and left for the lead: Retro's values read from its decompiled Android APK
(`references/auto/retro/apk/retro-android-2026.10.1150-excerpts.txt`) are still cited widely (colours, type, widget
providers); decision 22 names only Locket.

---

## New features — selfie reactions, plans, countdown widget, overnight photos, weekly question (SR-*, PL-*, ON-*, WQ-*)

Pass: new-features consolidation, 2026-10-16. Moves the values the six draft specs carried "only in this file" into the
canonical files and finalises the specs. Owns: `design/tokens/social.json` `viewer.selfiereaction.*` (3 tokens) and
`design/copy/social.json` `viewer.selfiereaction.*` (19 strings); `design/tokens/capture.json` `camera.overnight.*`
(8 tokens) and the `developed_photos` / `plans` rows of `notifications.push.layout.channels`; `design/copy/capture.json`
`camera.overnight.*` (17 strings) and `notifications.push.channel.developedPhotos.*` / `.plans.*` (4); the new
`design/copy/plans.json` (`plans.create.*`, `plans.page.*`, `widget.countdown.*`, 60 strings); `design/tokens/account.json`
`question.weekly.*` (5 tokens) and `design/copy/account.json` `question.weekly.*` (17 strings); the specs
`design/surfaces/{viewer.selfiereaction, plans.create, plans.page, widget.countdown, camera.overnight, question.weekly}.md`;
their rows in `docs/SURFACES.md` and in `design/copy-patterns.md` ("Which pattern governs which surface"); this section.
Totals added: 16 tokens (13 SOURCED, 3 BLOCKED), 117 strings (107 SOURCED, 7 VERIFIED, 1 PLATFORM, 2 BLOCKED; 17 verbatim,
41 adapted, 59 new). The push texts the server pass already made canonical (`notifications.push.selfieReaction.*`,
`.planNew.*`, `.planTomorrow.*`, `.planChanged.*`, `.planCanceled.*`, `camera.overnight.push.*`) are unchanged.

Inputs: the six drafts; `design/research/{selfie-reactions, plans, plans-data, overnight-and-questions,
overnight-and-questions-data}.md`; `backend/worker/COPY_KEYS.md` (placeholder names); `docs/API.md` §14. Rule: Retro is
the identity (colour, type, spacing, shape, motion, voice); each feature's mechanics reference keeps the mechanics
(BeReal RealMoji; Apple Invites, Partiful and the countdown widgets; Dispo and Lapse; Retro's prompt cards and Apple
Journal); a control Retro lacks keeps its mechanic's geometry (RC-3); when two references conflict on one surface, the
reference assigned to that surface in `docs/SURFACES.md` wins; the tenets gate everything (CONVENTIONS §6).

### Evidence gathered in this pass

| what | source | used for |
|---|---|---|
| Contrast of the pairs the drafts quote | `node tools/contrast.mjs` (2026-10-16): `textSecondary` on `control` light 4.51:1, on the page light 5.10:1 (owner decision 20's #6E6E6E); `textOnMedia` on `controlOnDeep` 15.13:1; `textSecondary` on `controlOnDeep` 5.31:1; widget state tint on black 14.88:1; `control` vs page 1.13 / 1.39:1 (known C-17 failure); `backgroundDeep` vs `controlOnDeep` 1.39:1 | the drafts' "2.52:1 / 2.85:1 FAIL" lines in `plans.create` / `plans.page` predate decision 20 and were corrected; every other ratio in the six specs re-checked unchanged |
| Retro string keys cited by the copy | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`: `home_invite_feed_card_cta` "Choose friends", `journal_profile_by_slug_does_not_exist_message` "Couldn't find album", `friends_tab_loading_error`, `media_viewer_comment_box_placeholder` "Add a comment…", `edit_address_delete_confirmation_*`, `edit_address_success_message` "Saved!", `weeks_ago_this_week` "This Week", `settings_description_lock_friend_requests` / `_neighborhood_captions`, `nux_card_*_what_to_share*`, `retrospective_page_title_most_popular_places` | `evidence` of the strings that the drafts cited by text only |
| Server contract for the catalogue and placeholders | `backend/supabase/migrations/20261016000020_overnight_and_questions.sql` (`question_key ~ '^question\.weekly\.[a-z0-9]+$'`, `app_config.weekly_question_keys` NULL); `backend/worker/COPY_KEYS.md` placeholders `{name}`, `{group}`, `{title}`, `{time}`, `{when}`, `{place}` | key names `question.weekly.q01`…`q09`; PL-11 |

### Conflicts and resolutions

| # | topic | values and sources | resolution | rule / evidence | status |
|---|---|---|---|---|---|
| SR-1 | Face overlap in the stack | Retro C-23 `size.global.avatarStackOverlap` 3 pt (ED-W3 album rows, retro-visual §4 #10) vs BeReal 16.0 pt (step 26.6 pt on 42.6-pt faces, AP #427) vs Locket ≈12 pt (27-pt step on 39-pt items, AS-4) | 3 pt (`size.global.avatarStackOverlap`) | an overlap is a visual value → Retro; BeReal and Locket supply placement and order (mechanics) | resolved |
| SR-2 | Face size | BeReal 42.6 pt (2026, AP #427) / 56.0 pt (2024, H-RP); Retro viewer avatar 40.7 pt | `size.global.avatarHeader` (40.7, ring included) | identity = Retro; BeReal 2026 within 2 pt | resolved |
| SR-3 | Face ring | BeReal black 1.1–2.0 pt; Retro C-23 white stack ring, viewer ring 2.0 pt (TC-2B) | white `color.global.textOnMedia`, 2.0 | Retro colour; BeReal's lossless width is the same 2.0 | resolved |
| SR-4 | Stack inset; capture-circle border | insets BeReal 6.0 / 15.2 pt (2026, H.264) vs 16.3 / 16.3 pt (2024, lossless 3x), Locket ≈17 / 20; border BeReal 3.4 pt black (no Retro counterpart) | inset `size.global.screenMargin` (16) on both axes; border `viewer.selfiereaction.size.captureBorder` 3.4 in `color.global.backgroundDeep` | lossless beats video and equals Retro's margin within 0.3 pt; a control Retro lacks keeps its mechanic's geometry (RC-3) in Retro's colour | resolved |
| SR-5 | Target ring | BeReal 72.7 pt, 2.4-pt stroke, white ≈ 50 % (≈ its own 74.0-pt shutter) vs Jolt's shutter ring 86 / 4.5 | Jolt's shutter ring (`camera.capture.size.shutterOuter` / `.shutterRing`), no disc, `color.global.textSecondary` | BeReal's ring is its shutter; Jolt's shutter is the same control | resolved |
| SR-6 | Layer look and motion | BeReal opaque #403934 card, 300-ms linear fade, 370–400-ms armed-ring growth, white capture flash, rising bubbles, fly-to-stack | `color.global.controlOnDeep` panel; `duration.global.fade` + `easing.global.standard`; armed ring `duration.global.crossfade`; no flash; face enters with `spring.global.playful` | identity = Retro; the effects are do-not-copy (RS-8 rule) | resolved |
| SR-7 | Entry | BeReal: tap the smiley or double-tap the post; Instant = hold and slide | hold the add-reaction glyph (a tap keeps the emoji picker); context-menu item and accessibility action open tap mode; no double-tap | a viewer tap advances (`photo.viewer.layout.advance`); WCAG 2.2 SC 2.5.7 needs a single-pointer path (BeReal's own mood flow is tap-based) | resolved |
| SR-8 | Mood set, unlock gate, counts | BeReal five stored moods + Instant; "Send 20 RealMoji to Unlock"; `RealMojis 5`, `+7`, `3+` | live selfies only, for everyone from the start; no number anywhere (stack, sheet, push, labels) | tenets 2 and 5 | resolved |
| SR-9 | Reaction push | BeReal's RealMoji push text not found | `notifications.push.selfieReaction.*` (server pass) on the "Post Activity" channel | `messaging.reaction` pattern | resolved; a screenshot of BeReal's push would confirm |
| SR-10 | Report sheet for a selfie reaction | BeReal reports one RealMoji from its own view ("Tap the RealMoji you want to report." · "Select the report option.", HC 10100086147229) — its sheet's wording is not quoted; Retro's post sheet "Why are you reporting this post?" with "I don't like it · Nudity or sexual activity · Other" | `safety.report.title.selfie` "Why are you reporting this selfie?" (noun swap post → selfie, as `.title.message`) and the `selfie` list of `safety.report.layout.reasons` = the post reasons; "I don't like it" opens Next Steps (Leave / Block the selfie's author) | the mechanic is BeReal's, the words Retro's (the menu item is already "Report Selfie"); a selfie is photo content | resolved; a capture of BeReal's RealMoji report sheet would confirm |
| PL-1 | Answer set and order | Apple Going · Not Going · Maybe; Partiful Going · Maybe · Can't Go | Going · Maybe · Can't go | Partiful (help 15525363, PF-W sheet); Retro Sentence case | resolved |
| PL-2 | Answer control | Apple 80-pt segmented capsule, selected segment light, systemGreen label; Partiful 96-pt emoji circles (web) / one round button (app) | three C-06 capsules (`size.global.pillHeight`, `size.global.pillGap`), outline → primary on select; one tap commits | identity = Retro (C-06 toggle); one-tap commit = Partiful's app (PF-S 01) | resolved |
| PL-3 | Who sees Can't go | Apple: guests see who is invited after replying; Partiful: guests see Going and Maybe, hosts see Can't Go | Can't go visible to its member and the plan's maker only | Partiful help 15525438; tenet 5 (an absence is not shown to the group) | resolved |
| PL-4 | Reminders | Partiful events: Going 2 h before, Maybe / no answer "finalize your RSVP" 1 week before; Partiful Group Reminder: when added + 24 h before; Apple: none documented | one push when made (`planNew`), one 24 h before to Going + Maybe (`planTomorrow`) | Partiful Group Reminder (the lightweight plan, help 15774034); "finalize" and a second reminder fail tenet 5 | resolved |
| PL-5 | Changes and cancel | Partiful: no notice for date changes, cancel notifies, no un-cancel; Apple: changes notified, cancel notifies, crossed-out name, restorable | changes and cancel notify Going + Maybe; "Restore Plan"; title struck through | Apple guide (VERIFIED); tenet 4 (nothing gets lost) | resolved |
| PL-6 | Who edits and cancels | Apple host + co-hosts; Partiful Group Reminder anyone added | the plan's maker and group admins | Jolt's album rule (`albums.view`); no host role (tenet 3) | resolved |
| PL-7 | "Hosted by" | Apple "Hosted by {name}"; Partiful "Hosted by" with a crown | "Made by {name}", no badge | tenet 3 | resolved |
| PL-8 | Plan page type | Apple title ≈42 pt bold, date / place 17 pt (26.3 pitch); Retro album detail: serif `displayMedium`, `listSubtitle` 15 | Retro roles | identity = Retro | resolved |
| PL-9 | Countdown widget layout | Apple Invites medium: square photo + text column, title ≈19–20 pt at 62 % white, countdown ≈24 pt bold; Widgetsmith full-bleed; Retro Glance: full-bleed photo + bottom-trailing stack | Retro anatomy at both sizes (`widget.home.small.*`), countdown in `displaySmall` (24) display face | identity = Retro; one layout at every size (RC-11); Apple's countdown line is the same 24 pt | resolved; Apple's split layout recorded in `plans.md` §9.1 for the owner |
| PL-10 | Countdown wording | Apple "In 9 Days" (Title Case); Widgetsmith "4 DAYS"; countdown apps with hours / minutes / seconds | the platform relative formatter at day granularity, Sentence case ("In 3 days", "Tomorrow"); never hours or seconds | PLATFORM output, no typed string; `retro.voice.sentence-case`; SPEC_FLAGS T4 | resolved; the same-day word stays BLOCKED until a snapshot test pins it |
| PL-11 | Placeholder names | drafts / research `{first_name}`, `{plan_title}`, `{group_name}`, `{date_time}` | `{name}`, `{title}`, `{group}`, `{when}` (`plans.page.madeBy`, `.cancel.title`, `.cover.accessibilityLabel`, `widget.countdown.a11y.plan`) | one vocabulary for app and worker (`backend/worker/COPY_KEYS.md`) | resolved |
| PL-12 | Plans channel | research: one Android channel "Plans" for the four plan pushes; no id or importance stated | `notifications.push.channel.plans.*`; `notifications.push.layout.channels` `plans` = IMPORTANCE_DEFAULT | stored like the other channels; default importance as every event channel but the daily invitation (heads-up for the invitation only, `daily.ongoing`) | resolved |
| PL-13 | Origin of strings reused from Jolt | drafts call copies of `groups.create.*` / `widget.home.small.*` strings "verbatim" or "adapted", but some sources are Jolt's own `new` strings | origin follows the source string: `plans.create.close.accessibilityLabel`, `.cover.accessibilityLabel`, `.name.accessibilityLabel`, `.error.failed`, `.error.cover`, `widget.countdown.configuration.group` are `new` with the source's pattern; levels as the drafts gave them | CONVENTIONS §4 (verbatim / adapted = a reference app's string) | resolved |
| ON-1 | Default mode | Dispo: 9AM selected in every store image, "traditionally" in its help (DX1, DUG, DH-TP); Lapse: always delayed; `camera.capture` (mechanics reference Locket, docs/SURFACES.md): one tap captures and posts now | **Now**, at every app launch | the control sits on `camera.capture`, whose assigned reference posts at once; Dispo's default belongs to an app whose only camera is the delayed one; tenet 5 (a member who never touches the control never has a photo held back) | resolved; owner may choose Dispo's 9 AM |
| ON-2 | Segment order | Dispo 9AM · NOW; Retro's TC-REC control does not put its selected segment first | "9 AM" · "Now", Now selected | Dispo (the only reference with the switch) | resolved |
| ON-3 | Viewfinder | Dispo small 9:16 window in an illustrated body; Lapse full viewfinder | `camera.capture`'s viewfinder | Dispo's window is brand illustration (do-not-copy); Lapse shares with friends as Jolt does | resolved |
| ON-4 | Review before sharing | Lapse: the author reviews developed snaps before they go anywhere; Dispo: shot to a roll, developed there for everyone | Dispo: revealed to the chosen groups at 09:00 | the feature's mechanic (a shared reveal) | resolved; risk F-2 (no delete before the reveal) → owner |
| ON-5 | Developing placeholder | Lapse one tile per photo with a lock glyph; Dispo one banner "15 photos developing" | one C-17 tile per group, "Developing", no number, no names | tenets 2 / 3; Lapse's lock reads as Retro's "Post to see" (do-not-copy) | resolved |
| ON-6 | Reveal time | Dispo 09:00 the next morning (documented); Lapse 24 h (2021 press) / hours (press) | 09:00 in the group's time zone, the first after capture | the only documented fixed time | resolved |
| ON-7 | Control look | Dispo #B4CDE2 / #191D21, caps labels, 105.3 × 42.5 pt, "DEVELOP" header | C-30 native segmented control (TC-REC), no visible header (accessibility label "Develop") | identity = Retro | resolved; header comprehension → owner check |
| ON-8 | Developing stack on the camera | Lapse stack in the leading slot, measurable only as a whole | `camera.overnight.layout.stackCards` BLOCKED; the slot stays empty | no traceable geometry | BLOCKED (capture) |
| ON-9 | Channel copy keys | draft `camera.overnight.push.channel.name` / `.description` vs every channel string stored as `notifications.push.channel.<id>.*` (read by `android/app/…/AppNotificationChannels.kt`) | `notifications.push.channel.developedPhotos.*`; `notifications.push.layout.channels` `developed_photos` = IMPORTANCE_DEFAULT (the draft's "default importance") | one storage scheme for channel strings | resolved |
| ON-10 | "9 AM" inside strings | draft texts "…photos taken for 9 AM…" with the note that the words are `{time}` | `{time}` in `camera.overnight.a11y.modeHint`, `.settings.rowDetail` and the channel description | the locale formats the time, as `camera.overnight.mode.later` | resolved |
| ON-11 | Reveal edge | a photo taken at 08:59 reveals at 09:00 (first 09:00 after capture) vs the next day | first 09:00 after capture | a reading of Dispo's "9 AM the next morning" / "every day at 9am" | open (owner test in Dispo at 08:55) |
| WQ-1 | Shared or personal question | Apple Journal: per-person prompts with refresh; BeReal: one moment for everyone | one question per group per week, the same for every member | "answers show together" needs one shared question | resolved |
| WQ-2 | Card look | Apple REFLECTION card (#DD5A58, caps tracked eyebrow, refresh glyph, ≈14.5 corners); Retro prompt cards (photo + dark gradient, one CTA) | Retro feed card (C-18) in Apple's eyebrow → prompt → action order: label line above, question in `displaySmall`, C-06 primary / C-09 light pill | identity = Retro | resolved |
| WQ-3 | Notifications | Apple: only on a schedule the person sets; Retro: member-chosen reminder cadence | no push for the question | tenet 5 (a second, unrequested alert) | resolved |
| WQ-4 | Default for a new group | Apple: opt-in at first launch; Retro: cadence chosen during onboarding, prompt cards shown in the feed | `question.weekly.layout.defaultOn` = on for new groups, an admin can turn it off | docs/OWNER_DECISIONS.md 2026-10-17 decision 30 (lead) | resolved 2026-10-17 (was BLOCKED) |
| WQ-5 | Rotation | Retro's 8 prompts in a fixed order; no reference rotates a weekly group question | `question.weekly.layout.rotation` = the catalogue q01–q09 in order, again from the start after the last; `app_config.weekly_question_keys` (migration 20261017000024) | docs/OWNER_DECISIONS.md 2026-10-17 decision 30 (lead) and Retro's fixed order | resolved 2026-10-17 (was BLOCKED) |
| WQ-6 | Question list | Retro's 8 NUX prompts include "Took a nice fit pic?", "Took a cute selfie?", "Something unfortunate happened?" | q02–q06 Retro (+ "this week"), q07–q08 Apple Journal, q01 the brief's example, q09 Retro's retrospective line; the three above not used | tenet "Real, not performed" and the light tone (OQ F-4) | resolved |
| WQ-7 | Card action | Retro "Add a memory" | "Add a photo" | noun swap (answers are photos) | resolved |

### BLOCKED items (debug-only outputs; `design/BLOCKED.md`)

Token `camera.overnight.layout.stackCards` (ON-8) (`question.weekly.layout.rotation` (WQ-5) and
`question.weekly.layout.defaultOn` (WQ-4) closed 2026-10-17 by lead decision 30); copy `plans.page.went` (past-plan list label: Partiful's word appears only as
"{n} Went") and `widget.countdown.empty.noPlans` (no reference widget shows an empty plan state). Behaviour gaps with no
proposed token stay in each spec's Gaps table: selfie enlarged view, stored-selfie mirroring, selfie resolution, hold
timeout, Android capture layer; plan album day boundary, the same-day word (widget and plan page), answer-lock time,
editing a past plan, capsule toggle motion, plan-row order on `groups.screen`; overnight reveal animation, capture →
stack motion, a 9 AM capture haptic, "delete everything still developing"; the question inside `photo.viewer`.

### Problems found (for other passes)

- **Android channels (code):** `AppChannel` has no `DevelopedPhotos` / `Plans`; `AppNotificationChannels` and
  `NotificationUi` should map them to `R.string.notifications_push_channel_developedphotos_*` (the description takes the
  formatted 09:00 as its argument) and `R.string.notifications_push_channel_plans_*`, ids `developed_photos` and `plans`
  (`Tokens.Layouts.NotificationsPushLayoutChannels`).
- **Server (weekly question):** `groups.weekly_question` defaults off and `app_config.weekly_question_keys` is NULL
  (docs/API.md §14.4), so nothing is asked — consistent with WQ-4 / WQ-5. When the lead decides, the list is
  `question.weekly.q01` … `q09` (the migration's key check accepts them).
- **Server (plans):** `create_plan` takes an optional `p_ends_at`; the design has no end-time row (research: not in the
  brief). The create sheet sends none.
- **Server (plan photos):** the research proposed an `albums` row per plan (`albums.plan_id`), so `plans.page`'s "Photos"
  label opens `albums.view`; the server exposes `plan_photos(p_plan_id)` instead (no album row, docs/API.md §14.2). The
  grid's cells still open `photo.viewer`; the label's target needs an album row or a lead decision.
- **Server (overnight push):** `push.photos_developed` is sent as type `new_post` with the first photo's `post_id`
  (docs/API.md §14.3); the spec's tap opens `groups.screen` and then the viewer on that reveal's photos, oldest first —
  the app pass needs the reveal time on the client (the post's `revealed_at`).

### Unresolved (owner, capture or verification)

ON-1 (owner may prefer Dispo's 9 AM default), ON-4 / F-2 (no delete before the reveal), ON-7 (header label
comprehension), ON-8, ON-11, WQ-4, WQ-5, PL-9 (Apple's split widget layout as the owner's alternative), PL-10 (same-day
word), the two BLOCKED strings, and the captures listed in each spec's Gaps.

## Finishing the vision — plans list, plan words, tributes in the app, reports, deletion, group types (FV-*)

Owner decisions 24–35 (2026-10-17). Each row names the evidence; values and words are in the canonical files.

### Conflicts and resolutions

| id | topic | references | resolution | evidence | status |
|---|---|---|---|---|---|
| FV-1 | Past and cancelled plans; the plan row next to a birthday row | Apple Invites: events "sorted into the following categories: Upcoming, All Events, Past Events …", on iCloud.com "See more events and categories: Scroll down", "+" beside "Upcoming" (AI-S 03), the widget's "your next event"; Partiful "Past Events" (help 15525513); Retro's Albums list (ED-W3) and C-20 week headers | **`plans.list`**: one scroll, Upcoming (soonest first) · Past Plans (latest first) · Canceled (latest first), Retro's album rows; reached from a C-20 "Plans" label with a chevron above the group screen's plan row while the group has any plan (the week header's "see all"). The plan row and the birthday request rows **both show, soonest first** (the birthday's day vs the next plan's day; same day: birthday rows first; no upcoming plan: the plan block last) | Apple's "Upcoming" leads with the next event; release builds hid the plan row (the only "Make a Plan") whenever a birthday row showed (plans.md §12 item 6, now closed) | resolved (server `group_plans`, migration 0028) |
| FV-2 | The three BLOCKED plan words (`plans.page.went`, `widget.countdown.empty.noPlans`, the same-day word) | Partiful past event "11 Went · 4 Maybe" (pf-web-private-past-01, computed styles); no published Apple Invites past guest list; no reference widget's empty plan state (searched Apple Invites store + support guide, 9to5Mac 2026-03-11, iGeeksBlog, MacTrast); Apple `doesRelativeDateFormatting` "phrases such as “today” and “tomorrow”"; ICU `format(THIS, DAY) // "today"` | **"Went"** (Partiful's past label, count dropped as `plans.page.going` drops "GOING (9)"); **"No plans yet"** (Retro "No stickers yet", noun swap — the closest sourced pattern, no action named because the widget's tap opens the app); the formatter's **"Today"** on the widget (day 0) and in the plan page's meta line on the plan's day, in every build; VoiceOver reads "… today" (the label no longer ends in ", ") | `references/auto/platform/relative-day-word-docs-excerpt.txt`; Retro APK `recap_sticker_picker_empty`; release builds dropped the line / left the glyph alone before | resolved (empty widget: closest pattern; a capture of Apple Invites' empty widget would confirm) |
| FV-3 | Who watches a birthday video, and where it is found in the app | spec: the birthday person gets a group-made video; VidDay help (how-can-i-share-the-final-video, `references/auto/vidday/INDEX.md`): "The final video is private right from the start!", the recipient's private link, "To automatically notify your contributors via email, click on Share with Friends."; Tribute: the finished video goes to the recipient and the people who made it; Retro's home feed cards (Rewind, "Year in Photos") in the friend-card pager | **RLS changed (migration 0034)**: nobody reads a tribute or its files before `delivered_at`; then the honoree and the members who **contributed** (not blocked with the honoree) — non-contributors never (before: every member except the honoree, at any time). In the app: one feed card per video in the group screen's pager (`group_tributes`), after the question card and before on-this-day / year story (the pager is newest first), kept for good like the year story's cards (owner decision 31), so the honoree finds it on the day, afterwards, and in a muted group; the card is the year-story card's composition with `icon.global.video`, the poster, the birthday in the memory date format, and "Play" (Retro `video_editor_play`) | both references keep the video private until it is given and then share it with the contributors only; a member who did not contribute is outside VidDay's "Share with Friends" list; the previous rule let non-contributors watch another person's gift before the person did | resolved |
| FV-4 | Report on every surface with user- or group-made content | spec Safety "Block, report and leave on every relevant surface"; Retro's report strings ("Report Post", "Why are you reporting this post?", post / profile reason lists, Next Steps); Retro Rewind's "•••" native menu (TC-RWP); Apple Invites' newsroom "have the ability to leave or report an event at any time" | new kinds `plan`, `tribute`, `year_story`, `collage`, `recap` (migration 0032, as 'selfie' in 0018); "Report Plan" / "Report Video" / "Report Recap" / "Report Collage" and "Why are you reporting this plan / video / recap / collage?" (Retro's noun swap, as SR-10); the post reasons (photo content); the plan page's "•••" adds Report and "Block {first_name}" for another member's plan; the media surfaces get a C-11 "•••" at the C-01 pair pitch (`size.global.headerIconPitch`) before the close circle; group-made content's Next Steps offer "Leave the group" only | the nouns are the app's own for each surface ("birthday video", "{year} Recap", "collage"); one shared "More" label (`safety.report.a11y.more`) | resolved |
| FV-5 | What a deleted account leaves behind | spec "Full account deletion deletes all data"; Partiful: "Deleting your Partiful account removes your personal data and account history from Partiful's servers" (help 15525644); Partiful's own event delete needs a cancel first, which notifies guests (15525450, 15525452); Apple Invites notifies the guest list when a host deletes an event (cancel-or-delete-an-event); Apple Shared Albums: "the shared album is automatically removed from all of your devices and the devices of your subscribers" (support.apple.com/108314) | the plans a person made (upcoming, past, cancelled) and the albums they named are deleted with the account; **no notice**; the photos in their albums stay in the group; the RevenueCat customer is deleted when `REVENUECAT_SECRET_KEY` is set | the notices both references send belong to a host's own Delete / Cancel action, not to leaving the service; a notice would carry the departed person's name and title after the deletion (spec: deletes all data); album = its owner's, as Apple's shared album goes with its owner | resolved (migration 0025) |
| FV-6 | What a group's type changes | spec: "Group types offered at creation … This affects only copy and defaults"; Retro's six journal templates; Yope (no types) | only the words (`GroupKindCopy`) and the template cover offered at creation; no server default differs by kind (docs/API.md `create_group`) | Retro `journal_tab_suggestion_title_*` / `_description_*` are a title and a line each, and every template opens the one "New Album" form (`journal_creation_flow_title`, `journal_creation_name_placeholder`, "+ Add cover image"); no per-template setting string exists; Retro's album settings ("Who can share photos?", "Who can edit cover & title?", "Who can manage members?", link sharing) are chosen after creation for every album alike; Yope: "Group type … not found in any build" (design/research/yope-a.md) | resolved |

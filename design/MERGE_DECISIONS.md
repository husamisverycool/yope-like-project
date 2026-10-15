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
| Locket Android 1.243.0 JS bundle (Hermes, decompiled) | `references/auto/locket/apk/locket-1.243.0-hermes-excerpts.txt` | G2-1, G2-2, G2-4, G2-5, G2-7, G2-8, G2-9, G2-11 |
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

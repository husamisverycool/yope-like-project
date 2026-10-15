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

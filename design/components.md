# Components — the Retro catalogue

Every screen is built from these components (docs/REDESIGN_BRIEF.md, Pass 1). Values are **token names**
(`design/tokens/global.json`; naming map `design/tokens/README.md`); colours show their value as
`light / dark` (one value = same in both). Nothing here is a new value: each part cites its evidence, and
gaps are marked **Gap** with the smallest capture that closes them. Pass 3 implements each component once
(iOS `ios/App/Sources/Components/`, Android `android/core/ui/`) with a snapshot per state in light and dark.

A surface without a Retro analog composes these components in the mechanics reference's order and records
it in its spec as `level: SOURCED`, `method: "composition of Retro components <list> in <mechanics ref>'s
order"` — no new visual values.

## Evidence shorthands

Paths under `references/auto/retro/` (`INDEX.md`); research files `design/research/retro-visual.md` (RV) and
`design/research/retro-package-copy-motion.md` (RP).

| id | file | kind |
|---|---|---|
| H43, H22 | `lazyweb/retro-lazyweb-20251020-week43-dark.png`, `lazyweb/retro-lazyweb-20260528-week22-dark-a.png` | RAW iOS dark, 3.000 px/pt |
| LAND, PAY | `lazyweb/retro-lazyweb-20251119-social.png`, `lazyweb/retro-lazyweb-20260529-paywall.png` | RAW iOS, 3.000 px/pt |
| RWA | `press/tc-2025-12-rewind-device-a.png` | RAW iOS, 3.000 px/pt |
| ST-01…05 | `store/retro-store-0N.png` | render, 2.389 px/pt |
| ED-A, ED-W3 | `store/editorial/retro-appstore-story-1840659619-albums.png`, `…-1854931006-week3-albums.png` | render, 3.89 px/pt (geometry only) |
| TC-1B, TC-2B | `press/tc-2023-07-retro-1b.webp`, `press/tc-2023-07-retro-2b.jpg` | render 2023, ≈2.2–2.3 px/pt |
| TC-R3, TC-REC, TC-J1, TC-J5 | `press/tc-2023-12-retro3.png`, `press/tc-2023-12-recaps.png`, `press/tc-2024-04-journals-1.webp`, `press/tc-2024-04-retro-journals-5.png` | render, ≈1.7–2.1 px/pt |
| JED | `press/jeddacp-2024-05-home-profile-journals.png` | real user screenshots 2024 |
| VID-SET, VID-COMP | `video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png`, `video/ig-DDbA_F7x-j7-composer-f130-147-f188-197.png` | video frames |
| APK-X, VM | `apk/retro-android-2026.10.1150-excerpts.txt`, `video/retro-motion-measurements.txt` | package constants, motion fits |

## Rules every component follows

- **Shape.** Corners use `layout.global.cornerStyle` (iOS continuous, Android `RoundedCornerShape`). Buttons,
  pills and badges are capsules (`radius.global.capsule`); avatars and circle buttons are circles.
- **Flat.** No shadows on cards, tiles, rows or buttons; dark mode adds no elevation tint
  (`layout.global.elevation`). Glass only over photos or colour (`layout.global.materials`).
- **Icons.** Outline, 2 pt stroke, 24 pt glyph box (`layout.global.iconStyle`, `size.global.icon`); fill variants
  only as a state (`icon.global.variantRule`).
- **Pressed.** Retro's visual press state was not recorded (RP §5.3). Pressed = the platform default (iOS:
  SwiftUI `Button` highlight; Android: `Modifier.clickable` default indication) — PLATFORM. Android plays
  `haptic.global.tap` (VIRTUAL_KEY) just before the action, as Retro does (APK-X 'Tap haptic wrapper'); iOS
  plays none.
- **Disabled.** Retro's only captured disabled control is the dark primary capsule: fill
  `color.global.controlRaised` (#4D4D4D) with label `color.global.onAccent` (#000000) (TC-R3 phone 2, measured).
  Other disabled states are not captured (**Gap** — one raw screenshot of each disabled control).
- **Motion.** Appear / disappear: fade `duration.global.fade` (150 ms) with `easing.global.standard`; state
  crossfades `duration.global.crossfade` (100 ms); Reduce Motion per `layout.global.reduceMotion`.
- **Touch targets.** Every control's hit area is at least `size.global.minTouchTarget.ios` (44 pt) /
  `.android` (48 dp), even when its drawn size is smaller (header glyphs, 32–36 pt circles, 23 pt close).
- **Dynamic Type.** Text roles scale with the style in `layout.global.textStyleMap` (iOS) / the font scale
  (Android sp). Retro's behaviour at large sizes was not captured (**Gap**); fixed-size containers (tiles,
  badges, pills) must not clip text that carries information — their accessibility label carries it in full
  (HIG / M3 accessibility, PLATFORM).
- **Media surfaces** (viewer, camera, full-bleed photos) are black in both appearances: use
  `color.global.backgroundDeep`, `color.global.textOnMedia`, `color.global.controlOnDeep`, `color.global.glass`.
- **Android page.** On Android, "page" means `color.global.background.android` (#FFFFFF / #1C1C1E); grouped rows,
  chips and the reply bar use `color.global.surfaceSecondary.android` where iOS uses `color.global.control`;
  secondary text uses `color.global.textSecondary.android`.

---

## C-01 Screen header (root): serif title + trailing icon buttons

**Anatomy.** Display serif title at the leading margin; up to two trailing glyph buttons (e.g. albums `book`,
messages `bubble.left`); optional relative-week pill (C-03) after the title. No bar background, no hairline;
content starts below.

| part | token |
|---|---|
| title | text role `headerTitle` (40 / line 48, regular) in `font.global.display`; colour `color.global.textPrimary` #000000 / #FFFFFF |
| title position | leading `size.global.screenMargin` (16); baseline `size.global.titleTop` (64) below the safe-area top |
| trailing glyphs | `icon.global.albums`, `icon.global.chats` (or any `icon.global.*`) in `size.global.icon` box, `color.global.textPrimary`; centred on the title's cap middle; centre-to-centre `size.global.headerIconPitch` (48); last glyph's ink at `size.global.headerInset` (16) from the edge |
| hit area | `size.global.headerButton` (44, PLATFORM), no visible circle |
| title → first content | `size.global.titleToContent` (30) from the title baseline |

**States.** Pressed: platform default. Scrolled: Retro's collapsed / inline title was not captured (**Gap** —
one screenshot of a scrolled home); until then the title scrolls with the content.
**Accessibility.** Title has the header trait (`.isHeader` / `heading()`); each glyph button has a label from
copy (`*.accessibilityLabel`, pattern `platform.a11yLabel`); focus order title → glyphs left to right.
Contrast: `textPrimary` on page 21:1 (CONTRAST rows 1–2).
**Evidence.** H43, H22 (title baseline y=378; glyphs (942–1011,307–365), (1084–1158,304–366)); ST-01; RV §3.3,
§3.4, §4 #1; APK-X wv3.e (40/48 W400).

## C-02 Screen header (pushed): back + serif title

**Anatomy.** Back chevron, then the serif title on the same line; trailing glyphs as C-01; optional search
field (C-12) below.

| part | token |
|---|---|
| back glyph | `icon.global.back` (ink 11.1 × 18.3 pt), `color.global.textPrimary`; ink at `size.global.backInset` (21.1) from the edge; native back button where the platform draws one |
| title | as C-01; ink starts `size.global.headerGap` (14.6) after the chevron ink |
| search field below | C-12, inside `size.global.screenMargin` |

**States / accessibility.** Back has label from copy ("Back" is the platform's own on native bars); title is a
header. **Evidence.** ED-W3 (chevron ink x1891–1933 y388–458, title from x1991 — measured this pass); ENG-M
(Messages, low-res); RV §4 #1.

## C-03 Relative-week pill ("Last Week")

Grey capsule after the title when the shown week is not the current one.

| part | token |
|---|---|
| fill | `color.global.badgeMuted` #999999 |
| label | text role `badge` (11 semibold), `color.global.onBadge` #FFFFFF |
| height | ≈24 (JED, ±5 %) — use `size.global.badgeHeight` (24) |
| shape | `radius.global.capsule` |

**Accessibility.** Read as part of the title ("Week 19, Last Week"). Contrast: white on #999999 **2.85:1 FAIL**
(CONTRAST failure 7). **Evidence.** JED (302–304,118–126; col x=305 y111–132); ENG-D (dark); RV §4 #1.

## C-04 Tab bar

**Anatomy.** Standard-height bar at the bottom, background = page, **no hairline, no labels**; up to 5
icon-only items distributed evenly (centres at width ÷ 10, 3/10, …). Retro's order: Home · Friends · Rewind ·
Activity · Profile (2026).

| part | token |
|---|---|
| height | `size.global.tabBarHeight` (49) above the home indicator; inset `size.global.tabBarInset` (0) |
| glyph | `size.global.tabBarIcon` (24 box), outline (`icon.global.home`, `.group`, `.rewind`, `.activity`, `.wall`) |
| selected | `color.global.textPrimary` #000000 / #FFFFFF |
| unselected | `color.global.tabInactive` #B2B2B2 / #999999 |
| unread dot | `size.global.tabBadgeDot` (4) circle `color.global.badge` #EA3337, centred, `size.global.tabBadgeOffset` (5) below the glyph |
| over a photo (full-bleed page) | selected `color.global.textOnMedia`, unselected `color.global.tabInactiveOnMedia` (white 62 %), on `layout.global.photoScrim` |
| background | `color.global.background` (iOS) / `.background.android` |

**States.** Selected = glyph colour only (no pill, no fill variant). Pressed: platform default. Tab switch
motion: not captured (**Gap**, RP §5.3) — platform default (no custom transition).
**Accessibility.** Each item: label from copy, selected trait (`.isSelected` / `selected = true` in a
`selectableGroup`); the unread dot adds a value ("new activity"), never a count. Contrast: light inactive
2.12:1 and dark state change 2.85:1 **FAIL** (CONTRAST failure 4).
**Platform.** iOS: a custom bar (the system `TabView` bar draws labels and a material) built to these values;
Android: a custom bottom bar (Retro's Compose bar is custom — Play renders show no M3 indicator).
**Evidence.** H43 / H22 glyph boxes y2414–2480, dot (356–367,2496–2507); ST-01; RWA (over photo); RV §3.1, §3.2,
§3.4, §4 #5.

## C-05 Primary capsule (full width, 60 pt)

**Anatomy.** Full-width capsule at the bottom of a screen, sheet or card; centred label.

| part | token |
|---|---|
| fill / label | `color.global.accent` #000000 / #FFFFFF; label `color.global.onAccent` #FFFFFF / #000000 |
| on media / colour surfaces | fill `color.global.surfaceLight` #FFFFFF, label `color.global.onSurfaceLight` #000000 (LAND, ST-03) |
| size | height `size.global.buttonHeight` (60); side margin `size.global.buttonMarginH` (20) — or 16 inside a card (PAY) |
| shape | `radius.global.button` (30, capsule) |
| label | text role `button` (17 semibold), Sentence case (copy `retro.voice.button`) |

**States.** Pressed: platform default + Android tap haptic. Disabled (dark, captured): fill
`color.global.controlRaised` #4D4D4D, label #000000 (`onAccent` dark); light disabled not captured (**Gap**).
Busy: the label is replaced by the platform activity indicator in the label colour (PLATFORM; Retro's busy
button not captured — **Gap**).
**Accessibility.** Button trait; label = visible text. Contrast 21:1 (row 17); disabled is exempt.
**Evidence.** LAND (y2032–2211, x60–1145), ST-03 ("Send Postcard" 2362–2505), PAY ("Claim" 2229–2408), TC-R3
phone 1 ("Try it for free") and phone 2 (disabled); RV §3.4, §3.5, §4 #6.

## C-06 Medium capsules (37 pt): primary · outline · fill

**Anatomy.** Capsules in action rows (profile "Recaps / Share Profile / ⚙", request "Accept / Decide Later") or
alone; equal widths in a row, `size.global.pillGap` (8.8) apart.

| variant | fill | border | label |
|---|---|---|---|
| primary | `color.global.accent` #000000 / #FFFFFF | — | `color.global.onAccent` |
| outline (secondary) | none (page shows) | 1 pt `color.global.textPrimary` #000000 / #FFFFFF | `color.global.textPrimary` |
| fill | `color.global.control` #F1F1F1 / #262626 (Android rows / chips: `color.global.surfaceSecondary.android`) | — | `color.global.textPrimary` |

| part | token |
|---|---|
| height | `size.global.pillHeight` (37) |
| label | text role `pill` (15 semibold) |
| icon-only capsule | width `size.global.iconPillWidth` (49), glyph `size.global.iconSmall` (e.g. `icon.global.settings`) |
| text-only padding (Android) | 12 horizontal / 8 vertical (APK PaddingValues(12, 8, 12, 8)) |

**States.** Selected toggle (e.g. "I'm in this", composition per mechanics): outline → primary fill (the two
captured variants; **Gap** for a captured toggle). Pressed / disabled: as C-05.
**Accessibility.** Button trait; icon-only capsule needs a label. Contrast rows 9, 17, 20.
**Evidence.** ST-02 (Recaps 209–561, Share 582–933, gear 954–1071, y1129–1217), TC-1B (Accept x1473–1802
y1402–1482), JED ("Create" fill pill), H43 (outline); RV §3.1, §3.4, §4 #6.

## C-07 Outline CTA with icon

Hug-width outline capsule with a leading glyph ("+ Get this week started").

| part | token |
|---|---|
| border / label / glyph | 1 pt `color.global.textPrimary`; label text role `pill`; glyph `icon.global.add` at `size.global.iconSmall` (14.7) |
| spacing | leading `size.global.pillPaddingLeading` (18) → icon → `size.global.pillIconGap` (9.7) → label → `size.global.pillPaddingTrailing` (17) |
| height / shape | `size.global.pillHeight` (37), capsule |

**Evidence.** H43 (x301–905, y1641–1751: 201.7 × 37); RV §3.4, §4 #6.

## C-08 Text button

App-drawn text action in a header ("Invite", "Keys"): text role `textButton` (17 regular),
`color.global.textPrimary`. In native sheet toolbars ("Cancel" / "Update") the system draws them in the tint
(`color.global.selection` / `color.global.system.primary`) — PLATFORM. Secondary link under a capsule
("already have an account?"): text role `listTitle` (15 semibold) in `color.global.textSecondary`.
**Evidence.** TC-1B ("Invite" 27 px), VID-COMP, LAND; RV §3.3, §4 #6.

## C-09 Light pill on media

Small white capsule over a photo / black surface ("Share" on the recap preview): fill `color.global.surfaceLight`,
label `color.global.onSurfaceLight` text role `pill`; width hugs the label (≈61 pt for "Share"); height not
isolated (**Gap**) — use `size.global.pillHeight`. Glass variant ("Add a message" on the postcard photo): fill
`color.global.controlOnDeep` #262626 (reads opaque in ST-03) with `icon.global.edit` + label in
`color.global.textOnMedia`, 149 × 37. **Evidence.** TC-REC, ST-04 (row y=2420 x882–1026), ST-03 (463–819,
1743–1830); RV §4 #6, §3.7.

## C-10 Destructive actions

Retro shows destructive actions as **red text**, never a red-filled button: menu items ("Delete from Photos",
"Make journal private"), settings rows ("Delete Account"), confirmation buttons ("Yes, delete").

| place | token |
|---|---|
| app-drawn row / menu text | `color.global.destructive` #EA3337, text role `body` (rows) |
| glyph | `icon.global.trash` (or the action's glyph) in `color.global.destructive` |
| native alerts / menus | role `.destructive` / M3 `color.global.system.error` — the platform draws them (iOS systemRed) |

**Accessibility.** Label states the action ("Delete account"). Contrast: red on page 4.18:1, on fills
3.62–3.90:1 — **FAIL** for text (CONTRAST failure 5).
**Evidence.** TC-RWP (`press/tc-2025-12-rewind-panels.png`), TC-J5; APK-X vv3.g (58 call sites); RV §4 #20; RP §3.3.

## C-11 Icon buttons and circles

| variant | size | fill | glyph |
|---|---|---|---|
| bare header glyph | hit `size.global.headerButton` (44), glyph `size.global.icon` | none | `color.global.textPrimary` |
| circle on the page ("+" on a list row; close on a light sheet) | `size.global.circleButton` (36) | `color.global.control` #F1F1F1 / #262626 | `color.global.textPrimary` |
| circle on media (close / edit on the postcard composer, viewer close ≈23) | `size.global.circleButton` (36) | `color.global.controlOnDeep` #262626 | `color.global.textOnMedia` |
| glass over a photo ("•••") | `size.global.circleButtonPhoto` (40) | `color.global.glass` (white 12 %) | `color.global.textOnMedia` |
| glass large (share / random beside a dial) | `size.global.circleButtonLarge` (64) | `color.global.glass` | `color.global.textOnMedia` |
| glass small (close over colour) | `size.global.circleButtonSmall` (32) | white ≈15 % (PAY; measured as a range — use `color.global.glass`) | `color.global.textOnMedia` |

Glyph size inside circles: close "×" 9.7 pt in a 32–36 circle (PAY, ST-03); other glyphs in the
`size.global.icon` box. **States.** Pressed: platform default. **Accessibility.** Label from copy; hit area
≥ 44 / 48. Contrast: glyph rows 10, 40, 47–48; the fills themselves fail non-text against the page
(failure 2) — identified by their glyph. **Evidence.** ED-W3 ("+" x3138–3277), ST-03 (977–1063,736–822), RWA
(more y276–396; share / random), PAY, TC-2B; RV §3.4, §3.7, §4 #7.

## C-12 Text field and search field

| part | token |
|---|---|
| fill | `color.global.control` #F1F1F1 / #262626 |
| height / corners | `size.global.fieldHeight` (52), `radius.global.field` (19) |
| width | full width inside `size.global.screenMargin` |
| leading glyph (search) | `icon.global.search` (ink 13.6 pt tall), `color.global.textSecondary` |
| placeholder / text | text role `placeholder` (17); placeholder `color.global.textSecondary`, typed text `color.global.textPrimary` |
| cursor / selection | platform tint (`color.global.selection` / `color.global.system.primary`) — PLATFORM |

**States.** Focused: keyboard up; Retro shows no focus ring (none captured). Error: inline message below in
`color.global.destructive`, text role `meta` (Retro's inline errors "Name too long" are short labels — RP §4.2;
placement not captured, **Gap**). Disabled: not captured (**Gap**).
**Accessibility.** The placeholder is not the label: the field's accessibility label comes from copy; search
has the search-field trait. Contrast: placeholder #999999 on #F1F1F1 **2.52:1 FAIL** (failure 1); typed text
18.59:1 / 15.13:1.
**Evidence.** ED-W3 (y558–759 → 51.9; corner fit 74.5 px; placeholder 'S'/'e' measured this pass), TC-1B (2023:
36 high, r 12); RV §3.4, §3.5, §4 #9.

## C-13 Reply / comment bar

Field at the bottom of the viewer (and of a thread): own avatar leading, placeholder, trailing glyph.

| part | token |
|---|---|
| fill | on media `color.global.controlOnDeep` #262626; on a page (Android thread) `color.global.surfaceSecondary.android` / iOS `color.global.control` |
| height / corners | `size.global.commentFieldHeight` (48), `radius.global.commentField` (12) |
| inset | `size.global.screenMargin` (16) each side |
| leading avatar | `size.global.avatarComment` (30), own photo |
| placeholder | text role `body` (15), `color.global.textSecondary` ("Add a comment…") |
| trailing glyph | `icon.global.more` (or send `icon.global.send` when text is present — mechanics) in `color.global.textSecondary` |

**Accessibility.** Text field with a label from copy; send button labelled. Contrast: placeholder on #262626
5.31:1 (row 41). **Evidence.** TC-2B (field rows 1821–1934 = 48 pt; corner fit 12.1 pt; field avatar x1377–1446 — measured this pass;
fill (1700–1720,1880–1890)); RV §4 #15; APK-X vv3.l "reply bar".

## C-14 Grouped section and rows (settings)

**Anatomy.** Small section header, then rows in a rounded group; first row rounds its top corners, last row its
bottom corners, a single row all four; middle rows square; hairline between rows.

| part | token |
|---|---|
| group fill | iOS `color.global.control` #F1F1F1 / #262626; Android `color.global.surfaceSecondary.android` #F7F7F7 / #262626 |
| corners | `radius.global.groupedRow` (12) |
| group inset | `size.global.screenMargin` (16) |
| row title | text role `body` (15) `color.global.textPrimary` — Title Case labels (copy `retro.voice.settings`) |
| row subtitle | text role `meta` (13) `color.global.textSecondary` (iOS) / `.textSecondary.android` |
| trailing | `icon.global.chevron` in `color.global.textSecondary`; or a native switch (PLATFORM, tint `color.global.selection` / `color.global.system.primary`) |
| divider | `color.global.separator` #CCCCCC / #4D4D4D, `size.global.hairline` |
| section header | text role `meta` (13) `color.global.textSecondary`, single Title Case word ("Account") |
| destructive row | C-10 |
| row padding | 16 (APK grouped list `pik` padding 16 dp — RV §4 #17) |

**States.** Pressed: platform default. **Accessibility.** Rows are buttons (or toggles); section headers have
the header trait. Contrast rows 9, 11, 32–33. **Gap.** Settings exist only as 640×800 video frames (VID-SET):
row height, section-header size and spacing are not measured — one raw Settings screenshot (top + scrolled).
**Evidence.** VID-SET frame 42 (≈#F2F2F2, ≈12 corners); APK-X `pik` (12 dp shapes), vv3.l; RV §3.5, §4 #17;
RP §3.5.

## C-15 List row with thumbnail (albums / groups)

| part | token |
|---|---|
| thumbnail | `size.global.rowThumbWidth` × `.rowThumbHeight` (72 × 97, 3:4), `radius.global.thumbnail` (4), aspect-fill |
| text block | starts `size.global.rowThumbGap` (17) after the thumbnail; title text role `listTitle` (15 semibold) `color.global.textPrimary`; subtitle text role `listSubtitle` (15) `color.global.textSecondary` with the actor's name in semibold ("**daniel** shared 2 posts") |
| avatar stack | C-23 stack below the subtitle |
| trailing action | circle button (C-11) `size.global.circleButton` (36) `color.global.control` with `icon.global.add`, ink at the right margin |
| row spacing | thumbnails `size.global.listGap` (22.5) apart (row pitch 119.5) |

**Accessibility.** Whole row is one button (title, subtitle combined); the "+" is a separate labelled button.
Counts in subtitles ("2 posts") are a Retro pattern our tenets drop (copy decides). **Evidence.** ED-W3 (thumbs
(1870–2148, 842–1217), title x=2213, + x3138–3277), ED-A; RV §3.4, §4 #10.

## C-16 People row (request / member / comment)

| part | token |
|---|---|
| avatar | `size.global.avatarPicker` (37) in request / member rows; `size.global.avatarComment` (30) in comment rows |
| name / line | text role `listTitle` (15 semibold) / `listSubtitle` (15) `color.global.textSecondary`; timestamp text role `caption` (14) |
| actions | pair of medium capsules (C-06) 150 × 36, gap ≈8.8 (`size.global.pillGap`) |
| unread marker | `size.global.tabBadgeDot` dot `color.global.badge` (TC-1B unread dot) |

**Evidence.** TC-1B (avatar 1356–1436; Accept x1473–1802 y1402–1482; dot), TC-2B (comment row "elton 2h");
RV §3.4, §4 #9-#11.

## C-17 Week strip and day tiles

**Anatomy.** Horizontal scroller at the margin; 3:4 tiles `size.global.stripGap` (2) apart, page colour showing
through; only the **strip's outer corners** round. Tiles: photo, empty day, add, placeholder. The add tile is
first when the week is empty, last otherwise (H22 / ST-01).

| part | token |
|---|---|
| tile | `size.global.stripTileWidth` × `.stripTileHeight` (84 × 112); inner corners `radius.global.photo` (0); outer corners of the first / last tile `radius.global.card` (18, continuous) |
| strip inset | leading `size.global.screenMargin` (16); scrolls with no trailing inset when it overflows |
| **photo tile** | aspect-fill photo; bottom scrim `layout.global.photoScrim` (black 0 → `color.global.scrim` 60 % from 55 % of the height); weekday label text role `tileLabel` (13 semibold) `color.global.textOnMedia`, centred, baseline `size.global.tileLabelBaseline` (13.4) above the bottom |
| **empty-day tile** | fill `color.global.control` #F1F1F1 / #262626; three centred lines in `color.global.emptyTileText` #D9D9D9 / #515151: month text role `tileMonth` (14), day text role `tileDay` (28 semibold, tabular digits), weekday `tileMonth`; line pitch 27 |
| **add tile** | fill `color.global.control`; `icon.global.add` 23 pt (2.3 stroke) centred, `color.global.textPrimary` |
| **placeholder tile** (loading / composer slot) | fill `color.global.control`, no content (VID-COMP grey placeholders) |

**States.** Pressed: platform default + Android tap haptic. Selected (composer): **Gap** (selection mark not
legible in VID-COMP). Insert motion: `duration.global.stripInsert` (250) with `easing.global.standard`; a new
tile fades in with `duration.global.fade` from scale ≤0.875 (VM §D; RP §5.1).
**Accessibility.** Each tile is a button labelled with its full date and content ("Monday, June 26, photo by
{name}" / "Thursday, June 29, no photos" / "Add a photo") — the empty-tile text fails contrast (failure 3) and
the photo label is photo-dependent (failure 8), so the label carries the information. The strip is a
horizontally scrolling list (accessibility container).
**Evidence.** H43 (x48–299, y468–803; gap x300–305; corner fit R 54 px; empty-tile glyphs (306–557,530–740);
"+" 23 pt), ST-02 (labels, scrim), WEB-PLUS (`web/retro.app-plus.png`), VID-COMP; RV §3.4, §3.5, §3.8, §4 #2;
`design/research/retro-timehop.md`.

## C-18 Friend card (photo card) with avatar and name

**Anatomy.** Avatar + name above a 2:3 photo card; cards in a horizontal pager, the next card peeking.

| part | token |
|---|---|
| avatar | `size.global.avatarList` (26.5) circle |
| name | text role `listTitle` (15 semibold) `color.global.textPrimary`, ink `size.global.cardNameGap` (11) after the avatar |
| header → card | `size.global.cardHeaderGap` (10) from the avatar bottom |
| card | `size.global.friendCardWidth` × `.friendCardHeight` (240 × 361), `radius.global.card` (18, continuous), aspect-fill photo, no border, no shadow |
| spacing | `size.global.cardGap` (16) between cards; first card at `size.global.screenMargin` |
| badge | C-24 "new" badge, `size.global.badgeInset` (12) from the card's top and right |

**States.** Pressed: platform default + tap haptic; opens the viewer with `duration.global.photoOpen` (250,
`easing.global.standard`). Seen / unseen: Retro's "Seen" pill and "N new" are do-not-copy as counts / read
receipts; only a count-free "new" badge is allowed.
**Accessibility.** One button: "{name}'s week, new photos" (copy). **Evidence.** ST-01 (card x209–782
y1417–2278; avatar col x=264 y1331–1393; gap x784–820), ED-A (badge (947–1138,1402–1495)); RV §3.4, §3.5,
§3.8, §4 #4.

## C-19 Profile header

| part | token |
|---|---|
| name | display serif, text role `headerTitle` (username as typed) |
| real name | text role `meta` (13) `color.global.textSecondary`, below the name |
| avatar | `size.global.avatarProfile` (64), ink at the right margin, aligned with the title |
| info rows | glyph `size.global.iconSmall` (≈14) `color.global.textPrimary` + text role `body` (15); pitch `size.global.infoRowPitch` (29); glyphs `icon.global.location`, `icon.global.calendar`, `icon.global.camera` |
| action row | medium capsules (C-06), height `size.global.pillHeight`, equal widths, gap `size.global.pillGap`, trailing icon-only capsule `size.global.iconPillWidth` (49) with `icon.global.settings` |
| below | week sections (C-20 + C-17); no divider (2026) |

**Accessibility.** Name is a header; avatar image has the person's name as label. "Weeks Posted: N" is
do-not-copy (count). **Evidence.** ST-02 (avatar 919–1072; rows y911/978/1048; buttons y1129–1217), JED,
Apptisan; RV §3.4, §4 #12.

## C-20 Section header ("Week 27  Jul 3 - 9")

**Anatomy.** Two runs on one baseline, one space apart, then "•••" at the right margin. Retro separates the
week and the range with a space and a weight / colour change, not a "·".

| part | token |
|---|---|
| week | text role `sectionLabel` (15 semibold) `color.global.textPrimary` ("Week 27") |
| range | text role `listSubtitle` (15 regular) `color.global.textSecondary` ("Jul 3 - 9"; current week without photos shows no range) |
| more | `icon.global.more` (dots 4.2 pt, pitch 7.1) `color.global.textPrimary`, ink at the right margin; opens a native menu (C-29) — Retro's week menu contents not captured (**Gap**) |
| spacing | header baseline → content `size.global.sectionHeaderToContent` (11.7); content bottom → next header cap `size.global.sectionGap` (36.4) |
| dated variant (album grid) | "January 25, 2024" text role `sectionLabel` + `icon.global.more` |

**Accessibility.** Header trait; read as one element ("Week 27, July 3 to 9"). Contrast: range on white
**2.85:1 FAIL** (failure 1). **Evidence.** ST-02 ("W" cap y1289–1313; baseline 1313 → strip 1341; strip 1608 →
header 1695), TC-J1; RV §4 #3, #24; `design/research/retro-timehop.md` "Measured values — week.history".

## C-21 Grids

| grid | anatomy and tokens |
|---|---|
| **profile / history week list** | vertical list of week sections: C-20 header + C-17 strip, repeated |
| **album photo grid (dated)** | sections C-20 (dated variant) over a 3-column grid of **square** cells, `radius.global.photo` (0), `size.global.stripGap` (2) gaps, full width inside the margins (album detail, TC-J1) |
| **composer picker grid** | 4 columns, square cells, ≈1–2 pt gaps (VID-COMP; FRAME — gap not exact, use `size.global.stripGap`) |
| **people grid** | 3 columns of `size.global.avatarGrid` (81) avatars, column pitch 125, name text role `listTitle` centred below (TC-1B 2023) |

**Accessibility.** Each cell is a button labelled with date / person; grids are lists for assistive technology.
**Evidence.** TC-J1 (row y=1950 white run x2751–2754), VID-COMP, TC-1B (avatars (1391–1569), (1666–1843)); RV
§3.4, §3.5, §3.8, §4 #24.

## C-22 Photo / story viewer chrome

**Anatomy.** Black page in both appearances. Header row; the photo at full width, native aspect, letterboxed;
footer; hairline; comments; reply bar (C-13). Advance by tap (Retro: "Tap anywhere to advance", "Tap left to go
back"); Retro shows no progress bars.

| part | token |
|---|---|
| page | `color.global.backgroundDeep` #000000 |
| header avatar | `size.global.avatarHeader` (39 incl. a white ring with a gap; ring width not measured — **Gap**) |
| header name / week | stacked: name text role `listTitle` `color.global.textOnMedia`; "Week 49" text role `listSubtitle` `color.global.textSecondary` |
| position pill (optional) | `size.global.positionPillHeight` (22) capsule `color.global.controlOnDeep`, label text role `badge` `color.global.textOnMedia` ("3 of 4") — position only, never a count of views or likes; the red 2023-12 variant ("2 of 9" in red) is do-not-copy |
| close | circle (C-11) on media, glyph `icon.global.close` |
| photo | full width, `radius.global.photo` (0) |
| footer | location text role `listTitle` + date text role `listSubtitle` `color.global.textSecondary`; trailing reaction slot (mechanics: Locket reactions; Retro's heart like is do-not-copy) |
| divider | `color.global.separator` dark value #4D4D4D, `size.global.hairline` |
| comment row | C-16 (avatar `size.global.avatarComment` (30), "name 2h": name text role `listTitle`, time text role `caption` `color.global.textSecondary`; text role `body` `color.global.textOnMedia`) |
| more | `icon.global.more` → native menu (Save / Delete / Report, destructive red) |

**Motion.** Open from a card / tile: `duration.global.photoOpen` (250) `easing.global.standard`; advance and close:
not captured (**Gap**). **Accessibility.** Photo label from copy (who, when, place); tap zones exposed as
"Next" / "Previous" actions (custom accessibility actions / TalkBack actions); header and footer text read in
order. Contrast rows 37–41. **Evidence.** TC-2B phone 2 (header box 1345–1440; "3 of 4" pill; footer; comment
field), TC-R3 phone 1 (black viewer under a light sheet); RV §2 row 15, §3.8, §4 #15; RP §5.3 (viewer NUX).

## C-23 Avatars and avatar stacks

| size token | value | where |
|---|---|---|
| `size.global.avatarSmall` | 22.6 | stack (album rows) |
| `size.global.avatarList` | 26.5 | friend-card header |
| `size.global.avatarComment` | 30 | comment rows, inside the reply field |
| `size.global.avatarPicker` | 37 | request / member rows |
| `size.global.avatarHeader` | 39 | viewer header (with ring) |
| `size.global.avatarProfile` | 64 | profile header |
| `size.global.avatarGrid` | 81 | people grid |

Circle, aspect-fill photo. **Stack:** avatars overlap by `size.global.avatarStackOverlap` (3), each with a white
ring (width not measured — **Gap**). **No photo:** initials on a solid colour circle (ED-W3 "SF" on green); the
colour palette and the initials' type are not measurable (chromatic colours from ED images are unusable) —
**Gap**: one raw screenshot of a friend without a photo; until then `icon.global.person` on `color.global.control`.
**Accessibility.** Decorative next to a visible name (hidden from assistive technology); alone, labelled with
the name. **Evidence.** ED-W3, ED-A, ST-01, ST-02, TC-1B, TC-2B; RV §4 #11.

## C-24 Badges: "new" and unread dot

| part | token |
|---|---|
| "new" capsule | fill `color.global.badge` #EA3337; label text role `badge` (11 semibold) `color.global.onBadge` #FFFFFF, lower case; height `size.global.badgeHeight` (24); capsule |
| placement on a card | `size.global.badgeInset` (12) from top and right |
| unread dot | `size.global.tabBadgeDot` (4) `color.global.badge` |

Retro's badge text is a count ("6 new") — **ours never shows a number** (tenets). **Accessibility.** Read as
part of the owner element ("new photos"). Contrast: white on red **4.18:1 FAIL** for 11 pt text (failure 5);
the dot passes as non-text. **Evidence.** ST-01 (row y=1480), ED-A ('6 new' (947–1138,1402–1495)), H43 (dot);
APK-X wv3.a (11/11 W600); RV §3.1, §3.3, §4 #8.

## C-25 Chips and small pills

| pill | tokens |
|---|---|
| fill pill / template "Create" | C-06 fill variant |
| position pill | see C-22 |
| video duration ("1:00") | capsule `color.global.surfaceLight` 71 × 24, `icon.global.video` + monospaced digits, text role `pillSmall` (13 bold) `color.global.onSurfaceLight` |
| premium pill ("FREE") | 51 × 26 capsule, `layout.global.premiumGradient` (top #D543DE → bottom #A327B8) / `color.global.premium`, label text role `pillSmall` (13 bold, caps) `color.global.onBadge`; coloured shadow not measured; **paywall only, owner decides** |
| relative week | C-03 |

**Evidence.** PAY ((945–955,1480–1495), col x=960 y1450–1525); RV §3.1, §3.3, §4 #8.

## C-26 Toasts and confirmations

- **Android:** the platform `Toast`, `LENGTH_SHORT` (Retro calls `Toast.makeText(…, LENGTH_SHORT)` 48 times,
  `LENGTH_LONG` once) — PLATFORM look, Retro copy ("Saved!", "Copied!", "Invite link copied to clipboard").
- **iOS:** Retro's iOS toast was not captured (**Gap** — one screenshot after "Copy Link" in the iOS app). No
  custom toast is drawn until then; the confirmation is the state change itself plus an accessibility
  announcement (`AccessibilityNotification.Announcement`, PLATFORM).
**Evidence.** APK-X 'TOASTS'; RP §3.9, §4.2 (success toasts); RV §6 (iOS toast gap).

## C-27 Empty state

**Anatomy.** Centred block in the free space between the content above (e.g. the strip) and the tab bar:
outline glyph → title → (optional two-line explanation) → one outline CTA (C-07) or medium capsule.

| part | token |
|---|---|
| glyph | `size.global.emptyIcon` (22), outline, `color.global.textPrimary` (e.g. `icon.global.calendar`) |
| glyph → title | `size.global.emptyIconToTitle` (26) |
| title | text role `emptyTitle` (20 semibold) `color.global.textPrimary`, centred, Sentence case (copy `retro.voice.empty-state`) |
| explanation | text role `emptyDetail` (14) `color.global.textSecondary`, centred, ≤ 2 lines (TC-2B variant) |
| title → action | `size.global.emptyTitleToAction` (25) to the capsule top |
| action | C-07 outline CTA (or a 36 pt outline capsule, TC-2B) |
| placement | block centred in the space between the content above and the tab bar (H43: block centre 521.8 vs space centre 529) |

**Variants.** Error and offline states use the same block with a retry action (copy `retro.voice.error`; Retro's
list errors are a tappable line "Error loading friends. Tap here to try again." — RP §4.2). Permission-denied
uses the same block with the pre-prompt copy (copy `retro.voice.permission`).
**Accessibility.** Glyph decorative; title is a header. **Evidence.** H43 (icon y1380–1445, title 1524–1565.5,
button 1641–1751), TC-2B phone 3; RV §3.4, §4 #13.

## C-28 Loading states

Retro shows no skeleton screens. Captured loading forms:
- **Placeholder tiles** — C-17 placeholder tiles (`color.global.control`) where photos will appear (VID-COMP).
- **Progress text** — a confirmation-style line with an ellipsis ("Updating…", "Downloading…", "Creating your
  collage…"; copy `retro.voice.progress`) — Android as a Toast (C-26).
- **Activity indicator** — the platform's (`easing.global.native.activityIndicator`: `ProgressView` /
  `CircularProgressIndicator`) in `color.global.textSecondary` on the page — PLATFORM. Retro's own spinner was not
  captured (**Gap**); its collage loader is a Rive animation (do-not-copy asset).
- Appearance of loaded content: fade `duration.global.fade`.
**Accessibility.** Busy state announced (`.updatesFrequently` / live region "Loading"). **Evidence.** VID-COMP;
RP §2.1 (Rive files), §3.9, §4.1 rule 3.

## C-29 Sheets, menus, alerts and other native components

| component | look | tokens |
|---|---|---|
| **page sheet** (composer, settings, referrals) | native (`.sheet` / `ModalBottomSheet`); motion measured on Retro: `spring.global.sheetPresent` (critically damped, response 0.347 s), first frame at rest `duration.global.sheetPresent` (567 ms); underlying sheet scales back (iOS) | `radius.global.sheet`; content on `color.global.background` |
| **sheet header** | centred title text role `sheetTitle` (17 semibold); either a trailing close circle (C-11: #262626 on dark, × in #F1F1F1 on light sheets) or the native toolbar "Cancel / Title / Update" (system tint) | C-08, C-11 |
| **feature-intro sheet** (2023) | light rounded sheet floating `size.global.featureSheetInset` (12) in from the edges over a dimmed screen: icon tile (≈64), title 17 semibold, two rows of 15 regular grey text each with a leading 20 pt outline glyph, full-width primary capsule (C-05) | `color.global.background`, text roles `sheetTitle` / `body`, `color.global.textSecondary` |
| **context menu / action sheet** | native `UIMenu` / M3 `DropdownMenu`; items Sentence case (copy `retro.voice.menu-labels`), destructive item in red | `color.global.system.ios`, `color.global.system.*` |
| **alert / dialog** | native `Alert` / M3 `AlertDialog` | `color.global.system.*` (Android: surfaceContainerHigh, onSurface, primary #0A84FF, error #EA3337) |
| **share sheet** | native (`ShareLink` / `Intent.ACTION_SEND` chooser) | — |
| **switch, picker, keyboard** | native | tint `color.global.selection` / `color.global.system.primary` |

**Accessibility.** Native components carry their own semantics. Contrast: M3 dialog actions in Retro blue
**2.98:1 / 3.94:1 FAIL** (failure 6). **Evidence.** VID-SET, VID-COMP (sheet motion VM §A, §C), TC-R3 phone 1
(feature-intro sheet), TC-RWP (menu), RV §4 #14, #16, #20; RP §5.1.

## C-30 Segmented control

Native (`Picker(.segmented)` / M3 `SingleChoiceSegmentedButtonRow`) — Retro uses the system control on
"Create Recap" (Yearly / Monthly / Weekly / All Posts): dark track #1E1E1E, selected #6B6B6B as drawn by iOS
(TC-REC row y=446). Android M3 selection colour = `color.global.system.secondaryContainer` (#F7F7F7 / #262626,
Retro's scheme). Selection plays `haptic.global.select`. PLATFORM. **Evidence.** TC-REC phone 1; RV §3.2, §4 #20.

## C-31 Page dots

`size.global.pageDot` (5.9) circles, `size.global.pageDotPitch` (9.6) apart, centred; active
`color.global.textPrimary` (on media `color.global.textOnMedia`), inactive `color.global.pageDotInactive` #DDDDDD /
#808080. **Accessibility.** The pager announces "page N of M" (platform page-control semantics). Contrast:
inactive on white **1.36:1 FAIL** (failure 9). **Evidence.** TC-REC phone 2 (dots x1360–1417, measured this
pass), TC-1B (light); RV §4 #21.

## C-32 Divider

`size.global.hairline` (1 device px) in `color.global.separator` (#CCCCCC / #4D4D4D), full width inside the
margins; used sparingly (between the viewer footer and comments, above "Total", between grouped rows).
Decorative (hidden from assistive technology). **Evidence.** TC-1B, JED, ST-03, TC-2B; APK-X vv3.h/.j; RV §4 #22.

## C-33 Onboarding / landing hero

**Anatomy (LAND, RAW dark).** Page background; the mark area at the top (the owner's mark — Retro's wordmark is
not copied); a large grey line; the primary capsule (C-05) at the bottom margin; a grey secondary link under it;
fine print with underlined links at the bottom.

| part | token |
|---|---|
| page | `color.global.background` (LAND is dark: #000000) |
| large line ("Friends Only") | text role `onboardingTitle` (30 regular) `color.global.textSecondary`, centred |
| primary capsule | C-05 (dark: white fill, black label "Get started") at `size.global.buttonMarginH` (20) |
| secondary link | text role `listTitle` (15 semibold) `color.global.textSecondary`, lower case ("already have an account?") |
| fine print | text role `caption` (14, line `lineHeight.global.caption` 21.7) `color.global.textSecondary`, centred, links underlined |
| onboarding pages | page transition `duration.global.pageTransition` (500) fade + expand / fade + shrink (APK-X); conversational titles in `font.global.display` text role `displayMedium` (Retro Android onboarding headlines are Roslindale Display Narrow 26/32 – 32/34) |

**Gap.** Sign-up form screens, onboarding pages and permission pre-prompts were not captured as images (RV §2
rows 36–41) — they compose C-05, C-12, C-27 per the APK order (RP §6.3). The light landing is not captured.
**Accessibility.** Links are buttons with their own labels ("Terms", "Privacy Policy"). Contrast: grey line and
fine print on black 7.37:1 (pass); in light they would fail (failure 1). **Evidence.** LAND ("F" y1235–1298;
capsule y2032–2211; link y2260–2320; legal y2385–2435, baselines 2429 → 2494); RV §3.3, §3.4; RP §6.3, §3.7.

## C-34 Card on a blurred backdrop (recap card, plan card)

**Anatomy.** Full-screen blurred, colour-rich version of a photo; a card centred on it; page dots and a light
pill below (recap preview) or a pager of plan cards (paywall).

| part | token |
|---|---|
| backdrop | the photo blurred (`layout.global.materials.backdrop`); blur radius not measurable (**Gap**) |
| recap card | `color.global.surfaceElevated` #FFFFFF / #181818; corners ≈4.5–5 % of the card width (TC-H; no exact fit on the gradient backdrop — **Gap**: one lossless share-image export); photo grid with `size.global.stripGap` gaps, `radius.global.thumbnail` cells; footer: year in `font.global.display` text role `displaySmall`, name text role `listTitle`, domain line text role `meta` `color.global.textSecondary` |
| plan card (paywall) | translucent white on iOS (alpha not derivable — **Gap**; opaque `color.global.surfaceElevated` is the APK value); corners `radius.global.cardLarge` (36); padding `size.global.planCardPadding` (27); its capsule (C-05) 16 from the card sides and bottom; next card peeks after `size.global.planCardGap` (8); width = screen − 2 × `size.global.buttonMarginH` |
| plan card text | title 24 bold / price 22 heavy, body 15, steps 17, footnote 15 (PAY) — paywall surface tokens (Pass 2) |
| close | glass circle `size.global.circleButtonSmall` (32) (C-11) |
| below | page dots (C-31), light pill "Share" (C-09) |

**Accessibility.** Card content read in order; pager announces position. **Evidence.** TC-REC phones 2–3, ST-04,
TC-H (`press/tc-2023-12-retro-header.png`), PAY (card x60–1144 y1386–2456; TL corner); RV §3.4, §3.5, §3.7, §4 #23.

## C-35 Full-bleed media page (Rewind-style)

Full-bleed photo on `color.global.backgroundDeep`; display date title (text role `headerTitle`,
`color.global.textOnMedia`) at the margin with an optional `icon.global.chevronDown`; subtitle ("On this week") text
role `textButton` (≈17 regular) in white at reduced opacity (opacity not measurable — **Gap**); top-right glass "•••"
(`size.global.circleButtonPhoto`); bottom `layout.global.photoScrim`; central control flanked by glass circles
(`size.global.circleButtonLarge`) with `icon.global.share` / `icon.global.random`; the tab bar (C-04, over-photo
colours) sits on the scrim. A dial / scrubber plays `haptic.global.select` once per step (RP §3.8).
**Evidence.** RWA, RWB (`press/tc-2025-12-rewind-device-b.jpg`), TC-RWP, ST-05; RV §4 #19; RP §3.8.

---

## Do-not-copy (visual)

Counts and read states in badges ("6 new", "Seen", red position pill), likes (filled heart, comment hearts),
"Weeks Posted: N", the lock / "Post to see" cards and widget lock, the "Key holders only" gate, referral counters,
Retro's wordmark, "R" mark, app icon, illustrations, Rive files, postcard stamps, the "Retro Premium" two-part
wordmark and every bundled font file (RV §7, RP §8).

## Gaps (summary)

Disabled states other than the dark primary capsule; tab-switch, push / pop, viewer advance / close motion;
iOS toast; settings row metrics; initials-avatar colours and ring widths; light-mode RAW captures of fills and
rows; recap-card corner radius; backdrop blur and plan-card alpha; Dynamic Type behaviour at accessibility
sizes; week "•••" menu contents. Each lists its smallest capture above and in `design/tokens/README.md` → "Not
available yet".

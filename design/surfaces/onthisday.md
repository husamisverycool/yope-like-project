# `onthisday` — photos from this date in past years

Visual reference: **Retro Rewind** (docs/SURFACES.md; `design/research/retro-visual.md` §2 rows 22–25, §4 #19;
components C-35). Retro has the analog, so structure and look are Retro's; Timehop is no longer referenced. Voice:
`retro.voice.rewind` + the Retro set (`design/copy-patterns.md`). Tokens: `design/tokens/memory.json`
(`*.onthisday.*`) + `design/tokens/global.json`. Copy: `design/copy/memory.json` (`onthisday.*`). Decisions:
`design/MERGE_DECISIONS.md` → "Redesign — Memory (RM-*)".

What it is: when a group has photos posted on today's month and day in earlier years, the group screen shows an
entry card; it opens a full-bleed page that shows one memory at a time — Retro's Rewind page: the memory's date in
the display serif, a dial to spin through the memories (one tick per memory), play / pause, share and shuffle. It is
**not** a push notification (not in the directive's notification list).

## References

| id | image (`references/auto/retro/…`) | what it verifies |
|---|---|---|
| RWB | `press/tc-2025-12-rewind-device-b.jpg` (RAW iOS, 3.000 px/pt) | dial at rest: 150 pt ring, 44 slots (8.18°), long 19.8 / short 11.8 / width 3.2 pt, ticks white 30 %, indicator 16.7 pt solid white, play glyph 35 pt; share / random 64 pt glass circles, equal gaps; date 'Jul 22, 2022' (abbreviated month); dial centre 139.2 pt above the safe-area bottom |
| RWA | `press/tc-2025-12-rewind-device-a.png` (RAW iOS, 3.000 px/pt) | 'May 1, 2019 ⌄' title at the margin, baseline 63.3 pt below the safe-area top (≈ `size.global.titleTop`); '•••' glass 40 pt, ink 16.3 pt from the right, centred on the title's cap middle; second dial state (143 pt ring, 28 pt indicator) |
| RWP | `press/tc-2025-12-rewind-panels.png` | phone 1 playing (pause glyph, no side circles); phone 2 paused + native '•••' menu (red destructive item); phone 3 native share sheet 'Tuesday, December 2' / 'Memory' |
| ST-05 | `store/retro-store-05.png` | 'July 5, 2021' + 'On this week' subtitle (baseline 26.4 pt below the date's), subtitle white ≈ 76 % |
| APK | `apk/retro-android-2026.10.1150-strings.txt` | `rewind_home_*`, `rewind_mode_selection_sheet_*`, `media_viewer_comment_overflow_*` copy; package: tick haptic per dial step (`apk/…-excerpts.txt` w9e / lh2) |

## Structure

**A. Entry (placed by `groups.screen`).** A Retro feed card in the group screen, visible only while
`on_this_day(group, localDate)` returns rows. `onthisday` supplies its copy; the card component, position and
tokens belong to the `groups.screen` pass: title `onthisday.entry.title` ("On this day"), line
`onthisday.entry.subtitle` ("Revisit memories from {date} over the years", `{date}` = today as
`layout.birthday.add.dateFormat`, e.g. "July 5"), action `onthisday.entry.button` ("View memories"). Tap → pushes B
at the newest memory. The first time a member opens B, the feature-intro sheet (C below) shows first.

**B. The memory page** (pushed; full bleed; media surface, dark in both appearances — render the subtree in the dark
appearance, `layout.global.appearance.media`). Top to bottom:

1. **Photo** — the current memory's display rendition, full bleed (edge to edge, under the status bar), aspect-fill,
   `radius.global.photo` (0), on `color.global.backgroundDeep`. No top scrim (Retro shows none).
2. **Header (components C-02 on media)** — back chevron `icon.global.back` in `color.global.textOnMedia`, ink at
   `size.global.backInset`; the **date title** after `size.global.headerGap`: the memory's date as
   `layout.onthisday.dateFormat` ("Jul 22, 2022"), `font.global.display`, text role `headerTitle`
   (`fontSize.global.headerTitle` / `fontWeight.global.headerTitle` / `lineHeight.global.headerTitle`),
   `color.global.textOnMedia`, baseline `size.global.titleTop` below the safe-area top. After the date: Retro's
   **expand chevron** (RWA 'May 1, 2019 ⌄') — `icon.global.chevronDown` in `color.global.textOnMedia`, scaled so its
   ink is `dimension.onthisday.modeChevron.width` (19.7) wide, symbol weight `fontWeight.onthisday.modeChevron` (iOS),
   its ink `dimension.onthisday.modeChevron.gap` (8.7) after the title, centred `dimension.onthisday.modeChevron.drop`
   (2.0) below the title's cap middle. Title and chevron open the **mode menu** (E).
3. **Subtitle** — baseline `dimension.onthisday.subtitleBaseline` below the date's baseline, aligned with the date's
   leading edge: `onthisday.subtitle.day` ("On this day · {name}") or, after a shuffle, `onthisday.subtitle.shuffle`
   ("Memories · {name}"); `{name}` = the poster's first name. Text role `textButton` (17 regular),
   `color.onthisday.subtitle`.
4. **More** — glass circle (C-11) `size.global.circleButtonPhoto`, fill `color.global.glass`, `icon.global.more` in
   `color.global.textOnMedia`, ink of the circle at `size.global.headerInset` from the right edge, centred on the
   date title's cap middle. Opens the native menu (D).
5. **Bottom scrim** — `layout.global.photoScrim` (black 0 → `color.global.scrim` from 55 % of the height).
6. **Control row** (`layout.onthisday.controls`), centres `dimension.onthisday.controls.centerY` above the
   safe-area bottom, distributed with equal gaps across the width: **share** circle, **dial**, **random** circle.
   - Share / random: glass circles (C-11 large) `size.global.circleButtonLarge`, `color.global.glass`, glyphs
     `icon.global.share` / `icon.global.random` in a `size.global.icon` box, `color.global.textOnMedia`. Hidden
     while playing. **Share shows only on your own memory** (owner decision 12: a photo leaves the app only when it
     is your own); on another member's memory its place stays empty, so the dial does not move (as while playing).
   - **Dial** (`layout.onthisday.dial`): `count.onthisday.dial.ticks` (44) slots on a ring of outer diameter
     `dimension.onthisday.dial.diameter`; slot 0 at 6° clockwise from 3 o'clock, pitch 8.18°; even slots long
     (`dimension.onthisday.dial.tickLong`), odd slots short (`dimension.onthisday.dial.tickShort`), every tick
     `dimension.onthisday.dial.tickWidth` wide, measured inward from the outer edge, colour
     `color.onthisday.dial.tick`. The **indicator** is drawn on the current memory's slot instead of its tick:
     `dimension.onthisday.dial.indicatorLength` long, same width, `color.global.textOnMedia`. Centre: `icon.global.play`
     (paused) / `icon.global.pause` (playing), ink height `dimension.onthisday.dial.glyph`,
     `color.global.textOnMedia`.
7. No tab bar (our page is pushed from a group; Retro's Rewind is a tab — the controls keep Retro's distance from the
   bottom).

**Memory order.** `on_this_day` returns posts newest first with `years_ago`; that order is the dial's order (slot 0 =
the newest). One post = one memory. The indicator starts on slot 0; slot index = memory index mod 44.

**Interactions.**
- **Drag the dial** (a circular drag anywhere on the dial): each slot crossed moves one memory (clockwise = next,
  older; counter-clockwise = previous) with `haptic.global.select`; the photo cross-fades over
  `duration.global.crossfade`. Stops at the first and last memory (no wrap).
- **Tap the dial centre**: play / pause. Playing advances every `duration.onthisday.playHold` with a cross-fade of
  `duration.onthisday.memoryChange`, one tick each step, and stops after the last memory (play glyph again). Share
  and random fade out while playing and back in when paused (`duration.global.fade`, `easing.global.standard`).
- **Share** (your own memory only — owner decision 12): native share sheet with the memory's photo (original);
  preview title = today's date as `layout.year.story.dateFormat` ("Tuesday, December 2"), subtitle
  `onthisday.share.subtitle` ("Memory") — as Retro, whose Rewind shares only the user's own camera-roll photos.
- **Random (dice) = shuffle**: shows a random memory from the group's whole history (data below); the subtitle
  switches to `onthisday.subtitle.shuffle`; the dial then steps through further random memories (each slot = one new
  random pick; previous = back through the picks already shown). Going back to the day: the mode menu's "On this
  day…" (E), the back chevron (pops) or reopening from the entry.
- No swipe or tap-to-advance on the photo (Retro advances only by the dial).

**C. Feature intro (first open, once per account)** — components C-29 feature-intro sheet over the page: title
`onthisday.nux.title` ("Introducing On This Day"), text `onthisday.nux.message`, primary capsule (C-05)
`onthisday.nux.button` ("Try it out") which closes it. Retro shows the same intro for Rewind (`rewind_home_nux_*`).
Never shown again (no nagging).

**D. Menu ('•••', native — C-29 context menu)**, items in this order: your own memory — `onthisday.menu.save` ("Save
to Camera Roll") and `onthisday.menu.delete` ("Delete Post", destructive red); someone else's memory —
`onthisday.menu.report` ("Report Post", destructive red) only: saving or sharing another member's photo is not
offered (owner decision 12; the camera roll is outside the app). Report → `safety.report`; Delete → native confirmation
(`onthisday.delete.title` / `.message` / `.confirm` "Yes, delete" / `.cancel`) → `delete_post` → toast
`onthisday.toast.deleted`, the memory leaves the dial. Save → toast `onthisday.toast.saved`; failure
`onthisday.saveFailed`; add-only photo access denied → native alert `onthisday.saveDenied.title` / `.message` /
`.button` (opens Settings).

**E. Mode menu (native — C-29 pull-down menu anchored to the date title; Retro's Rewind mode selection)**, items in
this order: `onthisday.mode.day` ("On this day…", Retro's 'On this week…' with the noun swapped as RM-2) → the day's
memories from the newest (from shuffle; nothing changes in day mode), and `onthisday.mode.shuffle` ("Shuffle",
verbatim) → as the dice. Retro's third item 'Pick a date…' is not built (Do-not-copy; its picker and subtitle were never
captured). Presentation: iOS SwiftUI `Menu` over the title (HIG pull-down buttons), Android M3 `DropdownMenu` anchored
under the title; no haptic of its own (the platform menu's). For VoiceOver / TalkBack the title is the menu button
(header trait, pop-up / dropdown role), read as the date.

## Elements

| element | component · tokens | copy keys | behaviour |
|---|---|---|---|
| entry card | `groups.screen` feed card | `onthisday.entry.title`, `.entry.subtitle`, `.entry.button` | shown only when the day has rows |
| photo | `layout.global.appearance` (media), `color.global.backgroundDeep`, `radius.global.photo` | `onthisday.a11y.photo` ("Photo by {name}, {date}") | `media.display_path` (original until `renditions_ready_at`) |
| back | C-02: `icon.global.back`, `size.global.backInset`, `color.global.textOnMedia`, hit `size.global.minTouchTarget.*` | `onthisday.a11y.back` | pops to the group screen |
| date title | C-35: `font.global.display`, text role `headerTitle`, `size.global.titleTop`, `size.global.headerGap`, `color.global.textOnMedia`, `layout.onthisday.dateFormat` | — (data) | changes with the memory (cross-fade); opens the mode menu (E) |
| expand chevron + mode menu | `icon.global.chevronDown`, `dimension.onthisday.modeChevron.width` / `.gap` / `.drop`, `fontWeight.onthisday.modeChevron`, `color.global.textOnMedia`; C-29 menu | `onthisday.mode.day`, `.mode.shuffle` | "On this day…" back to the day; "Shuffle" as the dice |
| subtitle | text role `textButton`, `color.onthisday.subtitle`, `dimension.onthisday.subtitleBaseline` | `onthisday.subtitle.day`, `.subtitle.shuffle` | `{name}` = poster |
| more | C-11 glass: `size.global.circleButtonPhoto`, `color.global.glass`, `icon.global.more`, `size.global.headerInset` | `onthisday.a11y.more`; menu `onthisday.menu.*`, `onthisday.delete.*`, `onthisday.toast.*`, `onthisday.saveFailed`, `onthisday.saveDenied.*` | native menu (D) |
| scrim | `layout.global.photoScrim`, `color.global.scrim` | — | decorative |
| share | C-11 large glass: `size.global.circleButtonLarge`, `color.global.glass`, `icon.global.share`, `size.global.icon`, `layout.onthisday.controls` | `onthisday.a11y.share`, `onthisday.share.subtitle` | native share sheet; your own memory only (owner decision 12) — elsewhere its place stays empty |
| random | same, `icon.global.random` | `onthisday.a11y.shuffle` | shuffle |
| dial | `layout.onthisday.dial`, `dimension.onthisday.dial.*`, `count.onthisday.dial.ticks`, `color.onthisday.dial.tick`, `color.global.textOnMedia`, `icon.global.play` / `.pause`, `dimension.onthisday.controls.centerY` | `onthisday.a11y.dial`, `.a11y.dialValue`, `.a11y.play`, `.a11y.pause`, `.a11y.next`, `.a11y.previous` | drag = step, centre tap = play / pause |
| feature intro | C-29 feature-intro sheet, C-05 | `onthisday.nux.*` | once per account |

## States

| state | design (components) | copy | source |
|---|---|---|---|
| loading | page `color.global.backgroundDeep`; platform activity indicator centred (C-28, `color.global.textSecondary`); header with back only | `onthisday.loading` (announcement) | C-28 |
| playing / paused | dial glyph pause / play; share + random hidden / shown | `onthisday.a11y.pause` / `.play` | RWP phones 1–2 |
| empty | not a screen: the entry is hidden when `on_this_day` returns nothing. If every memory is deleted while the page is open: C-27 empty block on the black page (no glyph; title text role `emptyTitle`, `color.global.textOnMedia`) | `onthisday.empty.title` | `rewind_home_empty_state_message` |
| error | C-27 error variant on the black page: title `emptyTitle` `color.global.textOnMedia`, detail `emptyDetail` `color.global.textSecondary`, light pill (C-09: `color.global.surfaceLight` / `color.global.onSurfaceLight`, `size.global.pillHeight`, label text role `pill`) | `onthisday.error.title`, `.error.detail`, `.error.retry` | `retro.voice.error` |
| offline | same block | `onthisday.offline.title`, `.offline.detail`, `.error.retry` | `retro.voice.error` |
| permission-denied (save) | native alert, button opens Settings | `onthisday.saveDenied.*` | `retro.voice.permission` |
| memory deleted while open (`post_deleted`) | drop it from the dial; if it was shown, show the next (or previous) one | — | docs/API.md 8.2 |

## Motion

| transition | token | Reduce Motion |
|---|---|---|
| push / pop | native (`easing.global.native.navigationPush`) | system |
| step by dragging | cross-fade `duration.global.crossfade`, `easing.global.standard` | same (a cross-fade already) |
| step while playing | cross-fade `duration.onthisday.memoryChange`, every `duration.onthisday.playHold` | same; playing still allowed (it is user-started and pausable) |
| indicator move | jumps to the new slot with the photo change | same |
| share / random hide-show | fade `duration.global.fade`, `easing.global.standard` | fade (no movement) |
| feature intro, menu, share sheet, alerts | native (`spring.global.sheetPresent` / platform) | system |

## Haptics

Each slot crossed on the dial and each automatic step while playing → `haptic.global.select` (Retro: one tick per
dial step, SEGMENT_FREQUENT_TICK / CLOCK_TICK). Taps on back, more, share, random, play / pause →
`haptic.global.tap` (Android VIRTUAL_KEY; iOS none). Save succeeded → `haptic.global.success`; delete confirmed →
`haptic.global.warning`; save / delete failed → `haptic.global.error`. Menu and share sheet play their own.

## Accessibility

- **Labels / traits.** Photo: image, `onthisday.a11y.photo` ("Photo by Maya, Jul 22, 2022"). Date title: header.
  Subtitle: static text (read after the title). Back, more, share, random, play / pause: buttons with
  `onthisday.a11y.*`. Scrim and ticks: hidden.
- **Dial** is one adjustable element (iOS `.accessibilityAdjustableAction`, Android `Modifier.semantics {
  progressBarRangeInfo; customActions }` with `onthisday.a11y.next` / `.previous`): label `onthisday.a11y.dial`
  ("Memories"), value `onthisday.a11y.dialValue` ("2 of 5"); increment = next, decrement = previous; after a change
  the new date title is announced. Play / pause is a separate button.
- **Focus order:** back → date title → subtitle → more → photo → share → dial → play / pause → random.
- **Dynamic Type:** title `headerTitle` → largeTitle; subtitle `textButton` → body (`layout.global.textStyleMap`);
  the title wraps to two lines at large sizes and pushes the subtitle down; the control row does not scale.
- **Touch targets:** circles ≥ 40 pt; the back chevron and dial centre get ≥ `size.global.minTouchTarget.ios` /
  `.android` hit areas.
- **Contrast** (`node tools/contrast.mjs`; the page is dark in both appearances, so one row covers both):

  | pair | ratio | needs | result |
  |---|---|---|---|
  | `color.global.textOnMedia` (date, glyphs) on `color.global.backgroundDeep` | 21.00 | 3 (40 pt) / 4.5 | pass |
  | `color.global.textOnMedia` over the photo, top of the page (no scrim) | photo-dependent (1.00 on white) | 3 | **not guaranteed** — Retro draws it so (reported) |
  | `color.onthisday.subtitle` on `color.global.backgroundDeep` (#C2C2C2) | 11.79 | 4.5 | pass; over a light photo **not guaranteed** (1.00 on white) |
  | `color.global.textOnMedia` (indicator, play glyph) on the scrim end over white (#666666) | 5.74 | 3 | pass |
  | `color.onthisday.dial.tick` (white 30 %) over the scrim end on white (#949494 on #666666) | 1.90 | 3 | **FAIL** (non-text; the indicator carries the position — reported) |
  | `color.onthisday.dial.tick` on `color.global.backgroundDeep` (#4D4D4D on #000000) | 2.48 | 3 | **FAIL** (same; reported) |
  | glass circle `color.global.glass` on black (#1F1F1F) | 1.27 | 3 | **FAIL** (non-text; identified by its glyph: white on glass over black 16.48, over mid-grey #808080 3.22 pass, over white 1.00 fail — photo-dependent, C-11) |
  | error pill `color.global.onSurfaceLight` on `color.global.surfaceLight` | 21.00 | 4.5 | pass |
  | error detail `color.global.textSecondary` on `color.global.backgroundDeep` | 7.37 | 4.5 | pass |

## Data & actions

- **Read:** `rpc("on_this_day", p_group_id, p_local_date)` with `p_local_date` = the date of (now in
  `groups.time_zone` − 5 h) (`layout.onthisday.dayBoundary`). Not limited by `free_history_days`
  (docs/SPEC_FLAGS.md T1). Then `posts` / `media` by id (renditions; originals for save / share) and `profiles`
  (`display_name` first word) for the subtitle and labels. Signed URLs, 1 h. Blocked authors are already filtered.
- **Shuffle (dice):** `rpc("group_history_weeks", p_group_id, p_limit: 52)` paged with `p_before_week` until a page
  has fewer than 52 rows (cache per session); pick a random week, then a random `post_id` of it; then `posts` /
  `media` / `profiles` as above. Respects `free_history_days` (older weeks are left out for free users — T1).
- **Writes:** save (your own memory: download the original to the photo library; no API call); `rpc("delete_post", p_post_id)` (own
  post); report → `safety.report` (target kind `post`).
- **Realtime:** private broadcast `group:<group_id>` `post_deleted` → drop that memory.
- **Navigation in:** the entry card on `groups.screen` (no deep link, no push). **Out:** back → group screen; menu →
  `safety.report`; share sheet.

## Platform notes

- iOS: pushed in the group's `NavigationStack` with the system bar hidden (`.toolbar(.hidden)`), back chevron drawn
  per C-02 and the interactive pop gesture kept; status bar light content. The dial is a custom view: a
  `DragGesture` converted to the angle around the dial centre (`atan2`), stepping when the accumulated angle passes
  8.18°; `UISelectionFeedbackGenerator` per step. Share: `ShareLink(item:preview: SharePreview(date, image:))`;
  menu: SwiftUI `Menu`; save: `PHPhotoLibrary` add-only.
- Android: destination in the group graph, edge-to-edge, light status-bar icons; dial = `pointerInput {
  detectDragGestures }` with the same angle stepping; `view.performHapticFeedback(SEGMENT_FREQUENT_TICK)` on API 34+,
  else `CLOCK_TICK`; menu `DropdownMenu` (destructive items `color.global.system.error`); share
  `Intent.createChooser(ACTION_SEND)` via `FileProvider`; save via `MediaStore.Images`.
- The control row's equal gaps: iOS `HStack` with equal `Spacer()`s, Android `Arrangement.SpaceEvenly`.

## Do-not-copy

Retro's own camera-roll source and "Delete from camera roll"; "Share to my week" / "Add to Album" / "Send as
Postcard" (no such features); the mode menu's "Pick a date…"; Retro's share frame (Helvetica / PP Fraktion Mono type,
'retro.app' footer); Retro's 'Relive %1$d memories' notification (count; no on-this-day push); Timehop's "N YEARS AGO"
banners, progress bar, streaks, mascot, watermark and nag pushes; any count of memories in visible text.

## Gaps

| item | status | smallest capture that closes it |
|---|---|---|
| dial states (RWA: smaller ring, longer indicator, larger glyph, controls 20 pt higher) | RWB's resting values used (MERGE RM-3) | 10 s screen recording of Retro's Rewind: drag the dial, release, tap play |
| indicator start slot and drag direction | slot 0 (RWA), clockwise = next (RM-4) | same recording |
| subtitle colour | white 76 % ±6 % (channel mismatch) | one RAW screenshot of Rewind in 'On this week' mode over a dark, flat photo |
| photo change animation | cross-fades (global crossfade when scrubbing; VidDay 700 ms while playing) | same recording |
| play cadence | 4 s (VidDay) | 20 s recording of Rewind playing |
| top legibility over bright photos | no top scrim, as Retro (contrast not guaranteed) | — (owner / verification) |
| shuffle source | built (RM-5) | owner decision |
| sharing others' photos | decided: your own photos only (owner decision 12; RM-6 closed) | — |
| Retro's 'Pick a date…' and its mode menu's look | not built / platform menu (Retro's sheet never captured) | one RAW recording of Retro's Rewind: tap the date title, pick a date |

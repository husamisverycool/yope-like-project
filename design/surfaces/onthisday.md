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

**D. Menu ('•••', native — C-29 context menu)**, items in this order: `onthisday.menu.reply` ("Reply", glyph
`icon.global.reply`, every memory — "then & now", owner decision 34, research #13: Timehop "Then & Now", Retro's Rewind menu
leads with "Share to my week", RWP phone 2) opens the camera for this group replying to the memory with a photo —
photo.viewer's reply-with-a-photo hand-off (iOS `PhotoReplyHandoff`, Android `SocialHandoff.REPLY_TO_POST_ID`), so the send
goes to this group only with `create_post(p_reply_to_post_id)` and the answer shows in the chat as a photo reply to the
memory; playing stops. Then `onthisday.menu.save` ("Save to
Camera Roll", every memory — owner decision 28), `onthisday.menu.hidePhoto` ("Hide Photo", every memory — Retro's Rewind
'Hide photo', RWP phone 2) and `onthisday.menu.hideDay` ("Hide This Day", every memory — Timehop "Hide your bad
memories", Google Photos "Hide this date from all memories"; owner decision 34, research #12), then your own memory —
`onthisday.menu.delete` ("Delete Post", destructive red); someone else's memory — `onthisday.menu.report` ("Report
Post", destructive red). **Hide** is for you only (nothing changes for anyone else, the photo stays in the group):
Hide Photo → `hide_memory(p_media_id)`; Hide This Day → `hide_memory(p_day)` with the memory's calendar day in the
group's time zone (the day `on_this_day` reckons). No confirmation (it is shown again from `settings.hidden`); the
memory — or every memory of that day — leaves the dial at once, as a deletion does (the next memory shows, else the
previous; none left: the C-27 empty block), and toast `onthisday.toast.hidden` ("Hidden"). No undo: no neighbouring
surface has one. Failure: the dial stays; `onthisday.error.detail` / `onthisday.offline.detail`. The shuffle never
picks a hidden photo or day (`my_hidden_memories`, read with its pool, plus the hides made on the page). Sharing another
member's photo is not offered (owner decision 12). Report → `safety.report`; Delete → native confirmation
(`onthisday.delete.title` / `.message` / `.confirm` "Yes, delete" / `.cancel`) → `delete_post` → toast
`onthisday.toast.deleted`, the memory leaves the dial. Save → toast `onthisday.toast.saved`; failure
`onthisday.saveFailed`; add-only photo access denied → native alert `onthisday.saveDenied.title` / `.message` /
`.button` (opens Settings).

**E. Mode menu (native — C-29 pull-down menu anchored to the date title; Retro's Rewind mode selection)**, items in
this order: `onthisday.mode.day` ("On this day…", Retro's 'On this week…' with the noun swapped as RM-2) → the day's
memories from the newest (from shuffle or a picked date; nothing changes in day mode), `onthisday.mode.shuffle`
("Shuffle", verbatim) → as the dice, and `onthisday.mode.pickDate` ("Pick a date…", verbatim — Retro's third item) →
**the calendar** (below). Presentation: iOS SwiftUI `Menu` over the title (HIG pull-down buttons), Android M3 `DropdownMenu` anchored
under the title; no haptic of its own (the platform menu's). For VoiceOver / TalkBack the title is the menu button
(header trait, pop-up / dropdown role), read as the date.

**F. Pick a date… (the calendar).** Retro's own date picker was never captured (Gaps), so the page reuses the app's
calendar: week.history's "jump to a date" sheet (`week.history.layout.calendar`, design/surfaces/week.history.md —
C-29 page sheet, "Memories" title, C-11 close circle, months newest first, Monday-first grid; iOS `HistoryCalendarSheet`
with `selection: .day`, Android `HistoryCalendarSheet` in `feature/memory/common`). Only the days that have photos are
enabled (`group_history_months` days, minus the days you hid — `my_hidden_memories`); month titles are plain headers here
(no jump). The sheet follows the system appearance, as the page's other sheets (RM-16). Opening it stops playing. Picking a
day closes the sheet and shows **that month and day across the years**, newest first, from the newest (dial, play and
the menus as in day mode, stopping at the oldest); the subtitle is `onthisday.subtitle.shuffle` ("Memories · {name}" —
Retro's title outside 'On this week' mode). "On this day…" goes back to today's memories, "Shuffle" to the dice. A day
that turns out empty (all its photos hidden, or a day the calendar shows only for a collage or by the day a photo was
revealed): the page stays as it was and toast `onthisday.empty.title`. Failure reading the calendar or the day:
`haptic.global.error` + `onthisday.error.detail` / `onthisday.offline.detail`.

## Elements

| element | component · tokens | copy keys | behaviour |
|---|---|---|---|
| entry card | `groups.screen` feed card | `onthisday.entry.title`, `.entry.subtitle`, `.entry.button` | shown only when the day has rows |
| photo | `layout.global.appearance` (media), `color.global.backgroundDeep`, `radius.global.photo` | `onthisday.a11y.photo` ("Photo by {name}, {date}") | `media.display_path` (original until `renditions_ready_at`) |
| back | C-02: `icon.global.back`, `size.global.backInset`, `color.global.textOnMedia`, hit `size.global.minTouchTarget.*` | `onthisday.a11y.back` | pops to the group screen |
| date title | C-35: `font.global.display`, text role `headerTitle`, `size.global.titleTop`, `size.global.headerGap`, `color.global.textOnMedia`, `layout.onthisday.dateFormat` | — (data) | changes with the memory (cross-fade); opens the mode menu (E) |
| expand chevron + mode menu | `icon.global.chevronDown`, `dimension.onthisday.modeChevron.width` / `.gap` / `.drop`, `fontWeight.onthisday.modeChevron`, `color.global.textOnMedia`; C-29 menu | `onthisday.mode.day`, `.mode.shuffle`, `.mode.pickDate` | "On this day…" back to the day; "Shuffle" as the dice; "Pick a date…" the calendar (F) |
| calendar (F) | week.history's calendar (`week.history.layout.calendar`: C-29, C-11, C-06 fill, text roles) | `week.history.calendar.title`, `.calendar.a11y.close`, `week.history.a11y.emptyday`; `onthisday.empty.title` (toast) | an enabled day → its month and day across the years |
| subtitle | text role `textButton`, `color.onthisday.subtitle`, `dimension.onthisday.subtitleBaseline` | `onthisday.subtitle.day`, `.subtitle.shuffle` | `{name}` = poster |
| more | C-11 glass: `size.global.circleButtonPhoto`, `color.global.glass`, `icon.global.more`, `size.global.headerInset` | `onthisday.a11y.more`; menu `onthisday.menu.*` (reply, save, hidePhoto, hideDay, delete / report), `onthisday.delete.*`, `onthisday.toast.*` (saved, deleted, hidden), `onthisday.saveFailed`, `onthisday.saveDenied.*` | native menu (D) |
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
| memory hidden (Hide Photo / Hide This Day) | the same as a deletion, for every memory the hide covers | `onthisday.toast.hidden` | migration 0038 |
| picked date (F) | the page as in day mode, subtitle "Memories · {name}"; its last memory deleted or hidden: back to today's memories | `onthisday.subtitle.shuffle` | — |
| picked date empty (F) | the page stays; toast | `onthisday.empty.title` | — |

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
`haptic.global.tap` (Android VIRTUAL_KEY; iOS none). Save or hide succeeded → `haptic.global.success`; delete confirmed →
`haptic.global.warning`; save / delete / hide failed → `haptic.global.error`. Menu and share sheet play their own.

## Accessibility

- **Labels / traits.** Photo: image, `onthisday.a11y.photo` ("Photo by Maya, Jul 22, 2022"). Date title: header
  and the mode menu's button (iOS `Menu` label, Android `Role.DropdownList`), read as the date. Subtitle: static text
  (read after the title). Back, more, share, random, play / pause: buttons with `onthisday.a11y.*`. Scrim, ticks and
  the mode chevron: hidden.
- **Dial** is one adjustable element (iOS `.accessibilityAdjustableAction`, Android `Modifier.semantics {
  progressBarRangeInfo; customActions }` with `onthisday.a11y.next` / `.previous`): label `onthisday.a11y.dial`
  ("Memories"), value `onthisday.a11y.dialValue` ("2 of 5"); increment = next, decrement = previous; after a change
  the new date title is announced. Play / pause is a separate button.
- **Focus order:** back → date title (mode menu) → subtitle → more → photo → share (your own memory) → dial →
  play / pause → random.
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
- **Pick a date… (F):** the calendar: `rpc("group_history_months", p_group_id)` (migration 0045; `free_history_days` as
  the history) with the days of `my_hidden_memories` left out. The picked day: `on_this_day` already takes the date —
  `rpc("on_this_day", p_group_id, p_local_date)` with `p_local_date` = the picked month and day in the first year after
  the current one that has it (Feb 29: the next leap year), because it returns the years **before** `p_local_date`'s;
  so every year up to this one is included. No backend change. Then `posts` / `media` / `profiles` as above. The
  calendar's days are by `visible_at`, `on_this_day` by the day taken — usually the same day; where not, the empty toast.
- **Writes:** save (any memory: download the original to the photo library; no API call); `rpc("delete_post", p_post_id)` (own
  post); `rpc("hide_memory", p_media_id | p_day)` (any memory, for you only; migration 0038); report → `safety.report`
  (target kind `post`).
- **Hidden memories:** `on_this_day` already leaves out your hidden photos and days; the shuffle filters its picks with
  `rpc("my_hidden_memories")` (read once per page with the pool).
- **Realtime:** private broadcast `group:<group_id>` `post_deleted` → drop that memory.
- **Navigation in:** the entry card on `groups.screen` (no deep link, no push). **Out:** back → group screen; menu →
  `safety.report`; share sheet. Hidden memories are shown again from `settings.hidden`.

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
Postcard" (no such features); Retro's share frame (Helvetica / PP Fraktion Mono type,
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
| sharing others' photos | decided: your own photos only (owner decision 12; RM-6 closed); saving any memory to your library (decision 28) | — |
| Retro's mode menu's look and its own date picker | platform menu; "Pick a date…" opens week.history's calendar (F) — Retro's picker and the subtitle it leaves were never captured | one RAW recording of Retro's Rewind: tap the date title, pick a date |

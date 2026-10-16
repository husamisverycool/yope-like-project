# `groups.screen` — the group (photos, members, chat, weeks, settings)

Visual reference: Retro **album detail** (inventory #13, TC-J1 phone 3: book cover with its shadow, serif title, grey
meta line, outline capsules Settings / Share + "+", dated sections with "•••", 3-column grid with 2 pt gaps) with
Retro's **home week strip** for the group's current week (#1 / #2: C-20 header + C-17 strip, add tile) and its
**friend cards** for the members' weeks (#2: C-18). Header glyphs follow Retro's home header (book + chat, H22).
Tokens: `groups.screen.*` + `global.*`. Copy: `groups.screen.*`.

## References

| id | file | used for |
|---|---|---|
| TC-J1 | `references/auto/retro/press/tc-2024-04-journals-1.webp` phone 3 (2.0687 px/pt) | cover 173.5 × 246 + shadow, cover → title 36.7, title cap 23.2 (≈ displayMedium), title → meta 16, meta → capsules 26.6, capsules 36.7 high, dated header + "•••", 3-column grid |
| H43, H22 | `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png`, `…-20260528-week22-dark-a.png` | header glyphs 48 apart (C-01), week strip and tiles (C-17), empty-week block (C-27) |
| ST-01, ST-02 | `references/auto/retro/store/retro-store-01.png`, `…-02.png` | populated strip with weekday labels; week header "Week 27  Jul 3 - 9" (C-20); friend cards (C-18); profile action row with gear capsule (C-19 / C-06) |
| ED-A | `references/auto/retro/store/editorial/retro-appstore-story-1840659619-albums.png` | friend-card pager geometry |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `journal_profile_*` empty / non-member states, `journal_tab_loading_error`, `header_title_week_number_template`, `self_profile_header_recaps`, `friends_tab_invite` |

## Structure (pushed screen; page `color.global.background` / `.background.android`; one vertical scroll)

1. **Header row (C-02 without a title)**: back chevron `icon.global.back` at `size.global.backInset`; trailing glyphs
   (C-01 metrics: `size.global.icon` box, `size.global.headerIconPitch` 48 apart, last ink at `size.global.headerInset`):
   `icon.global.calendar` → `week.history`, then `icon.global.chats` → `chat.thread`. The row sits where C-01 centres its
   glyphs (on the cap middle of a title at `size.global.titleTop`).
2. **Cover** (C-24): `size.global.titleToContent` below the title baseline line, centred, `groups.screen.size.coverWidth` ×
   `.coverHeight`, `radius.global.thumbnail`, shadow `groups.screen.shadow.cover`; aspect-fill; no cover →
   `color.global.control` fill with `icon.global.group` centred in `color.global.textSecondary`.
3. **Name**: `groups.screen.size.coverToTitle` (36.7) below the cover, the group name in `font.global.display`,
   `displayMedium` (32), `color.global.textPrimary`, centred, up to 2 lines.
4. **Members**: `groups.screen.size.titleToMeta` (16) below the name baseline: avatar stack (C-23,
   `size.global.avatarSmall`, overlap `size.global.avatarStackOverlap`), joining order, centred, as many as fit the
   screen width minus 2 × `size.global.screenMargin` (no "+N", no count) → tap = members in `groups.settings`.
5. **Actions**: `groups.screen.size.metaToActions` (26.6) below: action row (C-19 / C-06 metrics) inside
   `size.global.screenMargin`: outline capsule `groups.screen.recap.accessibilityLabel` ("Recaps") and outline capsule
   `groups.screen.invite` ("Invite"), equal widths, then the icon-only outline capsule (`size.global.iconPillWidth` 49,
   `icon.global.settings` `size.global.iconSmall`), all `size.global.pillHeight` high, `size.global.pillGap` apart.
6. **This week** — `size.global.sectionGap` (36.4) below the capsules:
   - C-20 header: `groups.screen.week.title` (text role `sectionLabel`) + date range (`listSubtitle`,
     `color.global.textSecondary`; locale range format); the current week shows no range when it has no photos (C-20);
   - `size.global.sectionHeaderToContent` (11.7) below: **week strip (C-17)** at the margin: the group's photos posted
     this week (group time zone, Monday start), oldest → newest, photo tiles 84 × 112 with the weekday label;
     **add tile last** (→ `camera.capture` for this group); when the week has no photos yet: add tile **first**, then
     empty-day tiles for each remaining day of the week (Retro's empty week, H43 / H22) and the C-27 block below
     (see States).
7. **Members' weeks** — shown when at least one member shared this week: `size.global.sectionGap` below the strip,
   a horizontal pager of **friend cards (C-18)**, one per member who shared this week (newest first): avatar
   `size.global.avatarList` + first name (`listTitle`) above a 240 × 361 card showing that member's newest photo of the
   week; cards `size.global.cardGap` apart, the next card peeking; no badge (Retro's "N new" / "Seen" are do-not-copy).
8. **Earlier** — photos from before this week, newest first, paged: dated sections (C-20 dated variant: the day in
   the long date format, text role `sectionLabel`; no "•••") over a 3-column grid of square cells (C-21, `radius.global.photo`
   0, `size.global.stripGap` 2 gaps, full width inside the margins); `size.global.sectionGap` between sections.

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| back | C-02 | `groups.screen.back.accessibilityLabel` | pop |
| calendar glyph | C-01 glyph `icon.global.calendar` | `groups.screen.weeks.accessibilityLabel` | → `week.history` |
| chat glyph | C-01 glyph `icon.global.chats` | `groups.screen.chat` | → `chat.thread` |
| cover | `groups.screen.size.coverWidth` / `.coverHeight`, `radius.global.thumbnail`, `groups.screen.shadow.cover` | `groups.screen.cover.accessibilityLabel` | decorative (no action) |
| name | `font.global.display`, `displayMedium`, `groups.screen.size.coverToTitle` | group name (data) | header trait |
| members | C-23 stack, `groups.screen.size.titleToMeta` | `groups.screen.members.accessibilityLabel` | → `groups.settings` (members section) |
| Recaps | C-06 outline | `groups.screen.recap.accessibilityLabel` | → latest `week.recap` (or `week.history` when none) |
| Invite | C-06 outline | `groups.screen.invite` | → `groups.invite` |
| settings capsule | C-06 icon-only (`size.global.iconPillWidth`, `icon.global.settings`) | `groups.screen.settings.accessibilityLabel` | → `groups.settings` (sheet) |
| week header | C-20 | `groups.screen.week.title` ({number} ISO week) + range | static |
| strip tiles | C-17 (`size.global.stripTileWidth` / `.stripTileHeight`, `size.global.stripGap`, `radius.global.card` outer, `layout.global.photoScrim`, `tileLabel`; empty-day `color.global.control` + `color.global.emptyTileText`) | photo tile `groups.screen.photo.accessibilityLabel` ({date}, {first_name}); add tile `groups.screen.week.add.accessibilityLabel` | photo → `photo.viewer` (this week, this group); add → `camera.capture` (`DeepLink.camera(groupID:)`); long press → `groups.screen.layout.menu` |
| friend card | C-18 | name (data); card label `groups.screen.photo.accessibilityLabel` | → `photo.viewer` on that member's photos of the week |
| grid cell | C-21 dated grid | `groups.screen.photo.accessibilityLabel` | → `photo.viewer`; long press → menu (`groups.screen.photo.menu.report`, `.block`) |

## States

| state | when | design | copy |
|---|---|---|---|
| loading | first fetch, nothing cached | header, cover placeholder (`color.global.control`), name; strip of C-17 placeholder tiles; no members' weeks; grid of `color.global.control` cells (C-28 placeholder form) | — |
| created (empty) | you created it and nobody posted yet | strip = add tile + empty-day tiles; under the strip the C-27 block: glyph `icon.global.calendar` → title → explanation → outline CTA C-07 with `icon.global.add` → `groups.invite` | `groups.screen.created.title`, `.created.detail`, `.created.invite.friends` / `.family` / `.roommates` / `.custom` (by `groups.kind`) |
| empty | joined group without posts | same strip; C-27 block whose CTA → `camera.capture` | `groups.screen.empty.title`, `.empty.detail`, `.empty.button` |
| quiet week | earlier photos exist, none this week | strip = add tile + empty-day tiles; no block (Retro's empty week shows the block only on an empty home) ; members' weeks hidden | — |
| error | fetch failed, nothing cached | header + cover + name; one tappable line under the actions (`body`, `color.global.textSecondary`) | `groups.screen.error.title` (tap = retry) |
| offline | no connection | cached content stays; with no cache, C-27 block without glyph or action under the name | `groups.screen.offline.title`, `.offline.detail` |
| removed | `not_group_member` | header (back only) + C-27 block centred | `groups.screen.removed.title`, `.removed.detail` |
| blocked author | RLS hides their posts | nothing shown, no placeholder | — |
| permission-denied | — | not applicable | — |

## Motion

- Push in from `groups.list` (native). Settings: sheet (`spring.global.sheetPresent`).
- Opening a photo from a tile / card / cell: `duration.global.photoOpen` (250 ms, `easing.global.standard`; C-22).
- A new post (realtime): its strip tile inserts with `duration.global.stripInsert` (250 ms), fading in from scale ≤ 0.875
  with `duration.global.fade` (C-17, VM §D); a new friend card fades in `duration.global.fade`; grid cells cross-fade
  `duration.global.crossfade`. Reduce Motion: no scale or slide; cross-fades of the same durations.

## Haptics

Presses (glyphs, capsules, tiles, cards, cells) → `haptic.global.tap` (Android). Long press → system
(`haptic.global.longPressStart`). No haptic on arriving posts.

## Accessibility

- Header glyphs: buttons with labels. Name: header. Avatar stack: one button "Members" (names not read individually).
- Strip: horizontally scrolling list; each tile a button labelled with its date and person ("Monday, June 26, photo by
  Ana") — the label carries what the empty-tile text and photo labels cannot (CONTRAST failures 3 and 8).
- Friend cards: one button each ("{first_name}, this week"); grid cells: buttons with date and person; menu exposed as a
  custom action ("Report Post", "Block Ana").
- Announce new photos (`.layoutChanged` / `announceForAccessibility`) only while the screen has focus.
- Dynamic Type: name `largeTitle`; capsules `subheadline`; section headers `subheadline`; tile labels `footnote`;
  empty-day day number `title`; card names `subheadline`.
- Focus order: back → calendar → chat → name → members → Recaps → Invite → settings → week header → strip tiles →
  friend cards → dated sections (header, cells).
- Contrast (`design/CONTRAST.md`):

| pair | light | dark |
|---|---|---|
| name / headers / capsule labels on page | 21:1 (row 1) | 21:1 (row 1; Android 17.01:1 row 2) |
| outline capsule border | 21:1 (row 20) | 21:1 |
| week range `textSecondary` | **2.85:1 FAIL** (row 3) | 7.37:1 |
| empty-day tile text | **1.25:1 FAIL** (rows 15–16) | **1.91:1 FAIL** |
| weekday label on photo | photo-dependent (failure 8) | same |
| tile / placeholder fill vs page | **1.13:1 FAIL** (row 13) | **1.39:1 FAIL** |

## Data & actions

- Reads: `groups` (+ cover signed URL), `group_members` + `profiles` (avatars, first names), `posts` + `media`
  (`display_path` / `thumb_path` signed URLs) newest first and paged (docs/API.md §5.8, §7); the current week's range from
  `groups.time_zone` and `app_config.week_start_isodow` (Monday); `group_history_weeks` for `week.history` (§6.4).
- Realtime: channel `group-<id>` inserts (`posts`) and private broadcast `group:<id>` (`post_deleted`) (§8); refetch on
  foreground / reconnect.
- In: `groups.list`, `groups.create`, invite join, deep links (`DeepLink.post`, `.chatMessage`, `.recap` put this screen
  in the back stack). Out: `chat.thread`, `week.history`, `week.recap`, `photo.viewer`, `groups.invite`, `groups.settings`,
  `camera.capture`, `safety.report`, `safety.block`.

## Platform notes

- iOS: `ScrollView` with a horizontal strip (`ScrollView(.horizontal)`), `TabView(.page)`-free pager for cards
  (`ScrollView` + `scrollTargetBehavior(.viewAligned)`), `LazyVGrid` with 3 flexible columns, `contextMenu` on cells.
- Android: `LazyColumn` with a `LazyRow` strip, `HorizontalPager` (peeking via `pageSize`), `LazyVerticalGrid`
  inside sections, `combinedClickable` long press → `DropdownMenu`.
- Retro presents its album detail as a page sheet (TC-J1); this screen is pushed because it is the hub other surfaces
  and deep links return to (MERGE RA-9).

## Do-not-copy

- Retro's meta counts ("6 members · 307 photos"), "N new" / "Seen" badges, the "Post to see" lock, the album cover's
  user-styled title fonts, and empty-day tiles between photos (they would read as days nobody posted — Retro shows them
  only for an empty week).

## Gaps

| item | status | smallest capture |
|---|---|---|
| Retro's dated-header "•••" menu | not built (contents not captured, RV §2 row 7) | one screenshot with an album section menu open |
| cover shadow in dark mode | invisible on black (light-only measurement) | dark screenshot of a Retro album |
| scrolled header (title collapsing) | not captured: the header row scrolls with the content (C-01 Gap) | one screenshot of a scrolled Retro album |
| group name placement under the cover | TC-J1 render values (±2.5 %) | raw screenshot of an album detail |

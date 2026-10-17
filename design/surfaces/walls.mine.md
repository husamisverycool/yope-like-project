# `walls.mine` — my wall (my photos, week by week)

Redesign on **Retro**: visual reference Retro's **own profile** (screen 4 — ST-02 2026: serif username, 64-pt avatar,
action capsules ending in a gear capsule, then **week sections** "Week 27  Jul 3 - 9" with strips; screen 5 — JED / ENG-P:
the current week first, with add, empty-day and placeholder tiles). The wall is my photos from all my groups, grouped by
week. Tokens: `design/tokens/social.json` (`walls.mine.*`, shared by `walls.member`; strip rules `week.history.*`) +
`global.*`. Copy: `design/copy/social.json` (`walls.mine.*`). Decisions: `design/MERGE_DECISIONS.md` → Redesign — Social
(RS-14, RS-15). Tab root: the profile item of the tab bar (C-04, `icon.global.wall`; tab items are owned by `groups.list`,
account group).

## References

| id | file | used for |
|---|---|---|
| ST-02 | `references/auto/retro/store/retro-store-02.png` (render, 2.389 px/pt) | **primary**: header (name, avatar 64, capsule row with the gear capsule), `walls.mine.dimension.nameToActions`, `.actionsToWeeks`, week sections |
| JED | `references/auto/retro/press/jeddacp-2024-05-home-profile-journals.png` (real 2024) | current week first, header without a range, empty-day tiles |
| ENG-P | `references/auto/retro/press/engadget-2026-08-profile.jpg` (live app 2026-08) | current week: photo tiles, add tile, then blank placeholder tiles; "Week 33  10–16 Aug" |
| H43 / H22 | `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png`, `…-20260528-week22-dark-a.png` (RAW dark) | empty week: add tile first, dated empty-day tiles; "Welcome to Week 22!" + "Get this week started" |
| TC-1B | `references/auto/retro/press/tc-2023-07-retro-1b.webp` phone 3 | 2023 profile with an outline icon capsule ending the row |

## Structure (top → bottom; one vertical scroll; page `color.global.background` / `.background.android`)

1. **Profile header** (C-19 adapted — `walls.mine.layout.header`):
   - my display name in the display serif (text role `headerTitle`, `font.global.display`, `color.global.textPrimary`) at
     `size.global.screenMargin`, baseline `size.global.titleTop` below the top safe area; one line, tail truncation, leaving
     room for the avatar;
   - my avatar `size.global.avatarProfile` (C-23) at the trailing margin, centred on the name's cap middle;
   - no real-name line and no info rows (`walls.mine.layout.header`: no such data; "Weeks Posted: N" is a count);
   - **action row** `walls.mine.dimension.nameToActions` below the name baseline: two C-06 outline icon capsules
     (`size.global.iconPillWidth` × `size.global.pillHeight`, 1-pt `color.global.textPrimary` border, glyph at
     `size.global.iconSmall`) at the trailing margin, `size.global.pillGap` apart: `icon.global.favorite` → `favorites`
     (your private favorites, Apple Photos' Favorites album; owner decision 34, research #19), then `icon.global.settings` →
     `settings.root`. (Retro's "Recaps" / "Share Profile" capsules are not product actions here — RS-14.)
2. **Week sections** (`walls.mine.layout.weeks`), the first header's cap top `walls.mine.dimension.actionsToWeeks` below the
   action row:
   - **section header** (C-20): `week.history.header.title` ("Week 27", text role `sectionLabel`) + one space + the date range
     ("Jul 3 - 9", text role `listSubtitle`, `color.global.textSecondary`; locale interval Monday–Sunday; left out for the
     current week while it has no photos); no "•••" on walls (`walls.mine.layout.weeks`);
   - **strip** (C-17) `size.global.sectionHeaderToContent` below the header baseline, at `size.global.screenMargin`:
     84 × 112 tiles `size.global.stripGap` apart, outer corners `radius.global.card`, scrolling sideways with no trailing
     inset. Photo tiles (aspect fill, bottom `layout.global.photoScrim`, weekday label `tileLabel` in
     `color.global.textOnMedia` at `size.global.tileLabelBaseline`) in time order, Monday → Sunday; a collage item is a photo
     tile showing the collage image;
   - **current week** always first (`week.history.layout.currentWeek`): with no photos, the add tile then seven dated
     empty-day tiles; with photos, the photo tiles, the add tile, then one blank placeholder tile per remaining day;
   - next section: `size.global.sectionGap` from the strip bottom to the next header's cap top; past weeks appear only when
     they hold photos, newest first.
3. **Empty wall** (no photos at all): the current week's strip as above, then the C-27 block centred in the space between the
   strip and the tab bar (see States).
4. The tab bar (C-04) at the bottom; the list's bottom inset clears it.

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| name | C-19 / C-01 title; text role `headerTitle`, `font.global.display`, `size.global.titleTop` | display name (data) | header trait |
| avatar | C-23; `size.global.avatarProfile` | decorative (name beside it) | — |
| favorites capsule | C-06 outline icon capsule; `size.global.iconPillWidth`, `size.global.pillHeight`, `icon.global.favorite`, `size.global.iconSmall`, `size.global.pillGap` | `favorites.title` | → `favorites` |
| settings capsule | C-06 outline icon capsule; `size.global.iconPillWidth`, `size.global.pillHeight`, `icon.global.settings`, `size.global.iconSmall`, `walls.mine.dimension.nameToActions` | `walls.mine.a11y.settings` | → `settings.root` |
| section header | C-20; text roles `sectionLabel` + `listSubtitle` | `week.history.header.title`; range (data) | header trait |
| photo tile | C-17 photo tile | `photo.viewer.a11y.photoMine` ("Your photo, {date}") | tap → `photo.viewer` (context = this wall's photos, newest week first, time order inside a week) |
| collage tile | C-17 photo tile with the collage image | `walls.browse.a11y.collage` | tap → `collage.view` (capture group) |
| add tile | C-17 add tile (`color.global.control`, `icon.global.add` 23 pt) | `week.history.a11y.add` | → `camera.capture` (group chosen in `camera.sendto`) |
| empty-day tile | C-17 empty-day tile (`color.global.control`, `color.global.emptyTileText`, `tileMonth` / `tileDay`) | `week.history.a11y.emptyDay` | not interactive |
| placeholder tile | C-17 placeholder tile (`color.global.control`) | `week.history.a11y.emptyDay` | not interactive |

## States

| state | what shows | components · tokens · copy | source |
|---|---|---|---|
| loading | header from cache / profile; one section of C-17 placeholder tiles (seven) under a header without a range | C-28; `week.history.a11y.loading` announced | C-28 (VID-COMP placeholders) |
| loading more | C-28 activity indicator after the last section | `easing.global.native.activityIndicator` | C-28 |
| empty (no photos) | current-week strip (add + empty days), then C-27: `icon.global.calendar` (`size.global.emptyIcon`) → `size.global.emptyIconToTitle` → title → `size.global.emptyTitleToAction` → C-07 outline CTA with `icon.global.add` | `walls.mine.empty.title` ("Welcome to Week {week_number}!"), `walls.mine.empty.action` ("Get this week started" → `camera.capture`) | H43 / H22 (Retro's empty week, verbatim) |
| error | header; in place of the sections one tappable line at `size.global.screenMargin`, text role `body`, `color.global.textSecondary` | `walls.mine.error.title` (tap reloads) | `retro.voice.error` (Retro list-error line) |
| offline | cached sections; nothing cached → the error line | `walls.mine.error.title` | — |
| permission-denied | not applicable | — | — |

## Motion

Tab switch and push / pop: native (`easing.global.native`). A new photo in the current week: the strip's tiles shift one slot
with `duration.global.stripInsert` + `easing.global.standard`, the new tile fades in (`duration.global.fade`) from scale
≤0.875 (C-17, VM §D). Opening a photo: `duration.global.photoOpen`. Reduce Motion: cross-fades of the same durations.

## Haptics

| interaction | token |
|---|---|
| tap on a tile / capsule (Android) | `haptic.global.tap` (iOS none) |

## Accessibility

- Name is a header; each section is a group with its header ("Week 27, July 3 to 9") as a heading; strips are horizontally
  scrolling lists; tiles carry their full date in the label (C-17).
- Dynamic Type: `headerTitle` → largeTitle, `sectionLabel` / `listSubtitle` → subheadline, tile labels → footnote; tiles keep
  their size (labels carry the information).
- Focus order: name → favorites → settings → (per week) header → tiles left → right.
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | light | dark | pair |
|---|---|---|---|---|---|
| `color.global.textPrimary` | `color.global.background` | text | 21.00:1 pass | 21.00:1 pass | name, "Week 27", capsule border / glyph |
| `color.global.textPrimary` | `color.global.background.android` | text | 21.00:1 pass | 17.01:1 pass | the same on Android |
| `color.global.textSecondary` | `color.global.background` | text | **2.85:1 FAIL** | 7.37:1 pass | date range, error line (iOS) |
| `color.global.textSecondary.android` | `color.global.background.android` | text | **4.00:1 FAIL** | 6.85:1 pass | the same on Android |
| `color.global.emptyTileText` | `color.global.control` | text | **1.25:1 FAIL** | **1.91:1 FAIL** | empty-day tile text (label carries the date) |
| `color.global.textPrimary` | `color.global.control` | nontext | 18.59:1 pass | 15.13:1 pass | "+" on the add tile |
| `color.global.control` | `color.global.background` | nontext | **1.13:1 FAIL** | **1.39:1 FAIL** | tile boundaries |

  Weekday labels sit on photos under `layout.global.photoScrim` (photo-dependent, C-17 failure 8). Failures are Retro's
  palette (design/CONTRAST.md); reported.

## Data & actions

- `wall(p_user_id: my id, p_before, p_limit: 50)` (docs/API.md §6.4): items `post` (`post_id`, `media_id`, `group_ids`) and
  `collage` (`collage_id`), newest first; page with `p_before = last created_at`. Weeks: device time zone,
  `app_config.week_start_isodow` (Monday), ISO week numbers. `media` (`thumb_path`), `collages` (`image_path`, status ready);
  signed URLs (§7). `profiles` for my name / avatar.
- Realtime: `post_deleted` on each of my groups → drop the tile; my own posts (`posts` INSERT) → insert into the current week;
  refetch on foreground (§8.3).
- Navigation in: profile tab; my avatar / name in `chat.thread` and `photo.viewer`. Out: `photo.viewer`, `collage.view`,
  `settings.root`, `camera.capture`, `favorites`. No deep link.

## Platform notes

- iOS: `ScrollView` + `LazyVStack` of sections, each strip a horizontal `ScrollView` (`.scrollTargetBehavior` none — free
  scrolling as Retro); `Calendar(identifier: .iso8601)`; `DateIntervalFormatter` for ranges.
- Android: `LazyColumn` with `LazyRow` strips; `IsoFields.WEEK_OF_WEEK_BASED_YEAR`; `DateUtils.formatDateRange`.
- The serif name uses the platform serif until the owner licenses Roslindale (R-28).

## Do-not-copy

- "Weeks Posted: N", "Getting Started" progress ring, key-holder gate, "Post to see" lock.
- "Share Profile" / QR profile card (no public profiles), "Recaps" capsule (recaps are per group), "Homebase", "Last photo"
  place rows.
- Yope's 3-column grid, free-form wall canvas, streak pill.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| `walls.mine.layout.mosaic`, `walls.mine.layout.freeformWall` (old BLOCKED) | closed: the wall is Retro's week list (RS-14) | — |
| number of blank tiles after the add tile | one per remaining day (ENG-P runs off-screen) | one raw screenshot of a Retro profile mid-week with 2 photos |
| profile header spacing | ST-02 render (store renders compress vertical spacing, retro-visual §3.4) | one raw screenshot of a Retro profile (light + dark) |
| the action row's capsules | composition (RS-14): favorites + settings icon capsules | owner may want more actions here |

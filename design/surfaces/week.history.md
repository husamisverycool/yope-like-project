# `week.history` — the group's weeks, scrolled back

Redesign on **Retro**: visual reference Retro's **profile week sections** (screens 4–5: "Week 27  Jul 3 - 9" + "•••", the
strip of 3:4 tiles with weekday labels) and its **current-week strip** (screen 1: add tile, dated empty-day tiles; 2026 live
app: photos, add tile, blank placeholders). Here the weeks are the group's: every member's photos, week by week. Tokens:
`design/tokens/social.json` (`week.history.*`) + `global.*`. Copy: `design/copy/social.json` (`week.history.*`). Decisions:
`design/MERGE_DECISIONS.md` → Redesign — Social (RS-20).

## References

| id | file | used for |
|---|---|---|
| ST-02 | `references/auto/retro/store/retro-store-02.png` (render, 2.389 px/pt) | **primary**: section header (C-20), strip, weekday labels, "•••" |
| H43 / H22 | `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png`, `…-20260528-week22-dark-a.png` (RAW dark, 3 px/pt) | strip geometry (C-17), add tile first in an empty week, dated empty-day tiles for every day, "Welcome to Week N!" / "Get this week started" |
| ENG-P | `references/auto/retro/press/engadget-2026-08-profile.jpg` (live 2026-08) | "Week 33  10–16 Aug"; photos, add tile, then blank placeholder tiles |
| JED | `references/auto/retro/press/jeddacp-2024-05-home-profile-journals.png` (real 2024) | current week first, header without a range; "Apr 29 – May 5" ranges |
| ED-W3 | `references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png` | C-02 pushed header |
| TC-RWP | `references/auto/retro/press/tc-2025-12-rewind-panels.png` | Retro's native menu (Sentence-case items) |

## Structure (top → bottom; one vertical scroll; page `color.global.background` / `.background.android`)

1. **Header** (C-02 pushed): back chevron + the group's name in the display serif (`headerTitle`), one line, tail truncation;
   once `group_history_months` has returned a month, the trailing glyph `icon.global.calendar` → the calendar (below).
2. **Week sections** (`week.history.layout.weeks`), newest first, the first section's header cap top
   `size.global.titleToContent` below the title baseline:
   - **header** (C-20): `week.history.header.title` ("Week 27", text role `sectionLabel`, `color.global.textPrimary`), one
     space, the date range (text role `listSubtitle`, `color.global.textSecondary`; locale interval Monday–Sunday — "Jul 3 - 9",
     "Apr 29 – May 5"; left out for the current week while it has no photos), and `icon.global.more` (`color.global.textPrimary`)
     with its ink at the trailing margin → week menu;
   - **strip** (C-17) `size.global.sectionHeaderToContent` below the header baseline, starting at `size.global.screenMargin`,
     scrolling sideways with no trailing inset: one photo tile per post in time order (several on a day = several tiles;
     photos posted together, `layout.global.photoBatch`, are **one tile**: the batch's first photo with the batch marker
     `layout.global.batchMarker`, its label + `chat.thread.a11y.batch`, opening `photo.viewer` on the batch),
     `size.global.stripTileWidth` × `.stripTileHeight`, `size.global.stripGap` apart, outer corners `radius.global.card` (first
     tile's leading, last tile's trailing), inner corners `radius.global.photo`; photo aspect fill under
     `layout.global.photoScrim`, weekday label (`tileLabel`, `color.global.textOnMedia`, baseline `size.global.tileLabelBaseline`);
     each day's same-moment collage (`group_history_weeks.collages`, migration 0033) is one more photo tile on its day,
     before that day's photos (the collage's widget image, else its page 1) — the group's photo of that day; a week with
     only a collage still shows, and a day with a collage is not an empty day;
   - **current week** (`week.history.layout.currentWeek`): no photos yet → add tile first, then seven dated empty-day tiles
     (month `tileMonth` / day `tileDay` / weekday `tileMonth` in `color.global.emptyTileText` on `color.global.control`);
     with photos → photo tiles, the add tile, then one blank placeholder tile per remaining day;
   - next section's header cap top `size.global.sectionGap` below the strip.
3. Older weeks load in pages of 8 at the end. If `app_config.free_history_days` limits browsing (owner), the list just ends.

### Week menu (`week.history.layout.weekMenu`; C-29 native)

| item | shown | copy | action |
|---|---|---|---|
| View recap | the week has a ready recap | `week.history.menu.viewRecap` | → `week.recap` preview of that recap |
| Save as Album | the week has photos | `week.history.menu.saveAsAlbum` | → `week.edit` album sheet with that week's photos selected |

A week with neither shows no "•••".

### Calendar — jump to a date (`week.history.layout.calendar`; owner decision 34, research #21)

Mechanics: BeReal's Memories calendar — past posts are reached from a month grid where only the days that have one open
(https://help.bereal.com/hc/en-us/articles/7531349180829, accessed 2026-10-17). Drawn with Retro's components.

- **Presentation**: page sheet (C-29); C-11 close circle (`week.history.calendar.a11y.close`) at the leading margin, the
  centred title `week.history.calendar.title` ("Memories", text role `sheetTitle`).
- **Months**, newest first (`group_history_months`): the month and year (locale format, text role `sectionLabel`,
  `color.global.textPrimary`), `size.global.sectionHeaderToContent` above a seven-column grid, Monday first (the locale's
  weekday initials, text role `meta`, `color.global.textSecondary`), inside `size.global.screenMargin`; months
  `size.global.sectionGap` apart.
- **Days**: cells at least `size.global.minTouchTarget.ios` / `.android` high. A day in the month's `days` is a button:
  its number (text role `pill`, `color.global.textPrimary`) on a `color.global.control` circle of `size.global.pillHeight`
  (C-06 fill; Android `color.global.surfaceSecondary.android`, as the C-06 fill there); every other day shows its number in `listSubtitle`, `color.global.textTertiary`, and does nothing.
- **Jump**: a day → the week containing it; the month title (a button) → that month's `newest_week`. The sheet closes and
  the list shows that week at its top: a week already loaded is scrolled to; otherwise the list starts at that week
  (`group_history_weeks(p_before_week => week + 7)`, whose first week is that one) and pages older from there as usual.
  Pull to refresh returns to the newest week (the current week first again).
- No count anywhere (tenet 2): the grid marks days, it never says how many photos a day or month holds.

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| back + title | C-02; `icon.global.back`, `size.global.backInset`, `size.global.headerGap`, text role `headerTitle` | `chat.thread.a11y.back`; group name (data) | pops to `groups.screen` |
| section header | C-20; text roles `sectionLabel` + `listSubtitle`, `icon.global.more`; `size.global.sectionHeaderToContent`, `size.global.sectionGap` | `week.history.header.title`; range (data); `week.history.a11y.more` | "•••" → week menu |
| photo tile | C-17 photo tile | `week.history.a11y.tile` | → `photo.viewer` (context = that week's posts, time order) with `duration.global.photoOpen` |
| batch tile | C-17 photo tile + `layout.global.batchMarker` (`icon.global.batch`) | `week.history.a11y.tile` + `chat.thread.a11y.batch` | → `photo.viewer` at the batch's first photo (the batch side by side, `photo.viewer.layout.batchDots`) |
| collage tile | C-17 photo tile | `walls.browse.a11y.collage` ({date} = the collage's day) | → `collage.view` of that collage (by its invitation) |
| add tile | C-17 add tile | `week.history.a11y.add` | → `camera.capture` for this group (`DeepLink.camera(groupID:)`) |
| empty-day tile | C-17 empty-day tile | `week.history.a11y.emptyDay` | not interactive |
| placeholder tile | C-17 placeholder tile | `week.history.a11y.emptyDay` | not interactive |
| calendar glyph | C-02 trailing glyph `icon.global.calendar` | `week.history.calendar.open` | → the calendar sheet (shown once the months are known) |
| calendar day | C-06 fill circle (`size.global.pillHeight`, `color.global.control`), text role `pill` | the full date (locale, spoken) | → that day's week |
| calendar month title | text role `sectionLabel` | month and year (locale) | → the month's `newest_week` |
| other day | text role `listSubtitle`, `color.global.textTertiary` | `week.history.a11y.emptyDay` | not interactive |

## States

| state | what shows | components · tokens · copy | source |
|---|---|---|---|
| loading | header; two sections of placeholder tiles (C-17) under headers without ranges | C-28; `week.history.a11y.loading` | C-28 |
| loading more | C-28 activity indicator after the last section | `easing.global.native.activityIndicator` | C-28 |
| empty (no photos in the group yet) | the current week (add + seven empty days), then the C-27 block centred in the space below: `icon.global.calendar` → title → C-07 outline CTA with `icon.global.add` | `week.history.empty.title` ("Welcome to Week {week_number}!"), `week.history.empty.action` ("Get this week started" → `camera.capture`) | H43 / H22 verbatim |
| error | header; one tappable line at `size.global.screenMargin` (text role `body`, `color.global.textSecondary`) | `week.history.error` (tap reloads) | `retro.voice.error` |
| offline | cached weeks; a line above them (same style) | `week.history.offline` | `retro.voice.error` |
| permission-denied | not applicable | — | — |

## Motion

| transition | tokens | Reduce Motion |
|---|---|---|
| push / pop, scrolling, menu | native (`easing.global.native`) | system |
| a new photo arrives in the current week | tiles shift one slot `duration.global.stripInsert` + `easing.global.standard`; the new tile fades in (`duration.global.fade`) from scale ≤0.875 (C-17) | cross-fade, no scale |
| photo opens | `duration.global.photoOpen` | cross-fade |

## Haptics

| interaction | token |
|---|---|
| tap a tile, "•••" (Android) | `haptic.global.tap` (iOS none) |
| menu | native |

## Accessibility

- Each section is a group with its header as a heading ("Week 27, July 3 to 9"); strips are horizontal lists; tiles carry
  full dates (`week.history.a11y.tile` / `.emptyDay` / `.add`); "•••" `week.history.a11y.more`.
- Dynamic Type: `sectionLabel` / `listSubtitle` → subheadline; tile labels footnote; tiles keep their size.
- Focus order: back → title → (per week) header → "•••" → tiles left → right.
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | light | dark | pair |
|---|---|---|---|---|---|
| `color.global.textPrimary` | `color.global.background` | text | 21.00:1 pass | 21.00:1 pass | title, "Week 27", "•••" |
| `color.global.textPrimary` | `color.global.background.android` | text | 21.00:1 pass | 17.01:1 pass | the same on Android |
| `color.global.textSecondary` | `color.global.background` | text | **2.85:1 FAIL** | 7.37:1 pass | date range, error line (C-20 failure 1) |
| `color.global.textSecondary.android` | `color.global.background.android` | text | **4.00:1 FAIL** | 6.85:1 pass | the same on Android |
| `color.global.emptyTileText` | `color.global.control` | text | **1.25:1 FAIL** | **1.91:1 FAIL** | empty-day tile text (C-17 failure 3; the label carries the date) |
| `color.global.textPrimary` | `color.global.control` | nontext | 18.59:1 pass | 15.13:1 pass | "+" on the add tile |
| `color.global.textPrimary` | `color.global.control` | text | 18.59:1 pass | 15.13:1 pass | calendar day numbers that open a week |
| `color.global.textTertiary` | `color.global.background` | text | **1.80:1 FAIL** | **2.48:1 FAIL** | calendar days without anything (inactive: WCAG exempts them; CONTRAST failure 7) |

  Weekday labels on photos: photo-dependent under the scrim (C-17 failure 8). Reported, not adjusted.

## Data & actions

- `group_history_weeks(p_group_id, p_before_week, p_limit: 8)` (docs/API.md §6.4): weeks with posts or ready collages,
  newest first, `post_ids` in time order, `collages` (`collage_id`, `invitation_id`, `local_date`, `image_path`,
  `widget_path`) oldest first; page with `p_before_week` = last `week_start`. The current week is added by the client when it has no
  posts. Week number: ISO-8601 of `week_start` in `groups.time_zone` (`week_start_isodow` = Monday).
- `posts` / `media` (`thumb_path`, `created_at` in the group's time zone for weekdays); `weekly_recaps` (`week_start`,
  `status = ready`) for "View recap".
- `group_history_months(p_group_id)` (migration 0045): `month`, `days` (the days with something), `newest_week`, newest
  month first; read with the screen, again on refresh; a failure leaves the glyph out (the list itself is unaffected).
- Realtime: `post_deleted` → drop tiles; `posts` INSERT → add to the current week.
- Navigation in: `groups.screen` (the group's weeks). Out: `photo.viewer`, `collage.view`, `week.recap`, `week.edit`
  (album sheet), `camera.capture`.

## Platform notes

- iOS: `LazyVStack` of sections with horizontal `ScrollView` strips; `Calendar(identifier: .iso8601)`;
  `DateIntervalFormatter` (medium-short date style) for ranges; `Menu` on the "•••" glyph.
- Android: `LazyColumn` + `LazyRow`; `IsoFields.WEEK_OF_WEEK_BASED_YEAR`; `DateUtils.formatDateRange`; `DropdownMenu`.

## Do-not-copy

- "Key holders only" gate and "Manage Key Holders"; "Post to see" lock; "Weeks Posted: N"; "N new" / "Seen" pills;
  "Getting Started" ring and "3 different weeks" goal; the "Last Week" relative pill is a home-screen element, not used here.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| `week.history.layout.weekMenu` (old BLOCKED) | closed: native menu with the product's two actions; Retro's own items remain uncaptured (non-blocking) | one screenshot of Retro's week "•••" menu |
| `week.history.color.emptyTile` / `.emptyTileText`, strip sizes, radius 14 / inset 20 (old surface tokens) | superseded by the RAW-measured globals (`color.global.control`, `.emptyTileText`, `size.global.strip*`, `radius.global.card` 18, margin 16 — R-10) | — |
| number of placeholder tiles after the add tile | one per remaining day (ENG-P runs off-screen) | one raw screenshot of a Retro profile mid-week |

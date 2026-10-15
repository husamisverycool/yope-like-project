# `week.history` — scroll back week by week

Reference app: **Retro** (profile week sections) (`docs/SURFACES.md`). Research: `design/research/retro-timehop.md`
§week.history. Tokens: `design/tokens/social.json` (`week.history.*`) + `global.*`. Copy: `design/copy/social.json`
(`week.history.*`), Retro voice (`retro.voice.*`: Title Case nav, Sentence-case menu labels, terse numbers).
Retro is light-mode in every measured image; this app is **dark only** (`layout.global.appearance`, F-1). Retro's geometry,
type sizes and voice are used; text and background colours come from the global dark tokens; the empty-day / add tile
fills are now measured on Retro's own dark appearance (three lossless Lazyweb captures; Gap fill G-15).

Stripped Retro items (do-not-copy): key holders / "Key holders only" gate (every member sees the group's whole history),
"Post to see" lock, "Weeks Posted: N", "N new" / "Seen" pills, the "Getting Started" progress ring.

## References

| id | file | used for |
|---|---|---|
| R2 | `references/auto/retro/store/retro-store-02.png` (1284 px, 2.389 px/pt; v124.0) | **primary**: week header, strip geometry, tile labels, add tile, profile name in the display style |
| R1 | `references/auto/retro/store/retro-store-01.png` | display title cap height, inset, title → strip |
| P2 | `references/auto/retro/play/retro-play-02.png` | Android render (ratios cross-check) |
| J24 | `references/auto/retro/press/jeddacp-2024-05-home-profile-journals.png` | real app 2024: "Week 19" without range, empty-day tiles, "Apr 29 – May 5" |
| E26 | `references/auto/retro/press/engadget-2026-08-profile.jpg`, `…-home-dark.jpg` | real app 2026: "Week 33 10–16 Aug", repeated weekday tiles, dark mode (low-res photo) |
| TC23 | `references/auto/retro/press/tc-2023-07-retro-2b.jpg`, `…-1b.webp` | empty-day tile texts, gate (do-not-copy) |
| RW | `references/auto/retro/press/tc-2025-12-rewind-panels.png` | menu-label voice ("Hide photo", "Share to my week") |

## Structure (top → bottom; one vertical scroll)

Background `color.global.backgroundDeep` (Retro's dark mode shows a black background — E26, not sampled).

1. **Back circle** top-left (Yope header: `size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.back`,
   `size.global.headerInset`) — this screen is pushed from `groups.screen`; Retro's profile is a tab root (S-16).
2. **Title** = the group's name, Retro display role: `week.history.fontSize.title` (43) / `.fontWeight.title` (heavy),
   `week.history.font.title` (platform), `color.global.textPrimary`, left ink inset `week.history.dimension.titleInset`
   (16), one line, tail truncation.
3. **Week sections**, newest first (`week.history.layout.weeks`); the first header's cap top sits
   `week.history.dimension.titleToStrip` below the title baseline. Each section:
   - **Header row** at `week.history.dimension.inset` (20) from the left: `week.history.header.title` ("Week {n}", ISO week
     number) in `week.history.fontSize.header` / `.fontWeight.headerTitle`, `color.global.textPrimary`; then, after
     `week.history.dimension.rangeGap`, the date range (locale interval Monday–Sunday, e.g. "Apr 29 – May 5", "10–16 Aug")
     in `week.history.fontSize.header` / `.fontWeight.headerRange`, `color.global.textSecondary`, same baseline; omitted for
     a current week with no photos. At the right, "•••" (`icon.global.more`, `color.global.textPrimary`) with its right ink
     edge `week.history.dimension.moreTrailing` from the screen edge, vertically centred on the header text.
   - **Strip**, top `week.history.dimension.headerToStrip` below the header baseline: one tile per photo in time order
     Mon → Sun (several photos on a day = several tiles), tiles `week.history.dimension.tileWidth` ×
     `.tileHeight` (`week.history.aspectRatio.tile` 3:4), gaps `week.history.dimension.tileGap` (the background shows
     through), outer corners `week.history.radius.strip` (first tile's left, last tile's right), inner corners square.
     Starts at `week.history.dimension.inset`; no trailing inset: it scrolls horizontally and clips at the screen edge.
     Photo tiles: the photo (aspect fill, `thumb_path`) with the weekday ("Mon") bottom-centred, baseline
     `week.history.dimension.weekdayBaseline` above the tile bottom, `week.history.fontSize.weekday` /
     `.fontWeight.weekday`, `color.global.textPrimary`.
   - **Current week only**: after the photo tiles, the **add tile** (fill `week.history.color.emptyTile` #262626,
     "+" `week.history.icon.add` sized `week.history.dimension.addGlyph` in `color.global.textPrimary` — #FFFFFF in Retro
     dark — centred), then one **empty-day tile** per day of the week without a photo: three centred lines — month
     (`MMM`), day number, weekday (`EEE`) — in `week.history.fontSize.emptyDayLabel` / `week.history.fontSize.emptyDay`
     (bold) / `week.history.fontSize.emptyDayLabel`, colour `week.history.color.emptyTileText` (#515151), fill
     `week.history.color.emptyTile` (#262626).
   - Next section: next header's cap top `week.history.dimension.sectionGap` below the strip bottom.
4. Pagination: more weeks load at the end (pages of 8). If `free_history_days` limits browsing (T1, owner), the list simply
   ends — no gate, no message.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| back circle | `size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.back` | `chat.thread.a11y.back` | pops to `groups.screen` |
| title | `week.history.fontSize.title`, `.fontWeight.title`, `.font.title`, `.dimension.titleInset`, `.dimension.titleToStrip` | group name (data) | header trait |
| week header | `week.history.fontSize.header`, `.fontWeight.headerTitle`, `.fontWeight.headerRange`, `.dimension.rangeGap`, `.dimension.inset`, `color.global.textPrimary` / `.textSecondary` | `week.history.header.title`; range (data, locale formatter) | — |
| ••• | `icon.global.more`, `week.history.dimension.moreTrailing`; Retro's menu contents **BLOCKED** (`week.history.layout.weekMenu`) | `week.history.a11y.more`; items `week.history.menu.viewRecap` (when the week has a ready recap), `week.history.menu.saveAsAlbum` | native menu (`photo.viewer.layout.menu` component); View recap → `week.recap`; Save as album → `week.edit` album sheet with that week's photos |
| photo tile | tile / strip tokens, `week.history.fontSize.weekday`, `.fontWeight.weekday`, `.dimension.weekdayBaseline` | weekday (data); `week.history.a11y.tile` | tap → `photo.viewer` (context = that week's photos) |
| add tile | tile tokens, `week.history.icon.add`, `.dimension.addGlyph`, fill `week.history.color.emptyTile`, "+" `color.global.textPrimary` | `week.history.a11y.add` | opens `camera.capture` for this group (`DeepLink.camera(groupID:)`) |
| empty-day tile | tile tokens, `week.history.fontSize.emptyDay` / `.emptyDayLabel`, `week.history.color.emptyTile` / `.emptyTileText` | month / day / weekday (data); `week.history.a11y.emptyDay` | not interactive |

## States

| state | what shows | tokens / copy | source |
|---|---|---|---|
| loading | platform activity indicator under the title | `easing.global.native.activityIndicator` | PLATFORM (Retro loading not found) |
| loading more weeks | indicator after the last section | same | PLATFORM |
| empty (group has no photos yet) | the current-week section (header without range, add tile, seven empty-day tiles), then one explanation line at `week.history.dimension.inset`, text role `listSubtitle`, `color.global.textSecondary` | `week.history.empty` | E26 onboarding card, rewritten without the "3 weeks" goal (`retro.voice.explanation`) |
| error | the same explanation-line slot | `week.history.error` (pull down to retry — native pull-to-refresh) | `retro.voice.explanation` |
| offline | cached weeks; line at the top of the list | `week.history.offline` | `retro.voice.explanation` |
| permission-denied | not applicable | — | — |

## Motion

No Retro motion was measurable (no video). Scrolling (vertical list, horizontal strips) and the push are native
(`easing.global.native.navigationPush`, `.scrollIndicator`). Pull-to-refresh: native. Reduce Motion: system.

## Haptics

| interaction | token |
|---|---|
| pull-to-refresh threshold | native refresh control's own feedback (design/research/platform.md `haptic.all.pullThreshold`: system / GESTURE_THRESHOLD_ACTIVATE) |
| tiles, menu | none / native menu |

## Accessibility

- Each section is a group: header "Week {n}, {range}" as a heading; strip tiles `week.history.a11y.tile`
  ("{weekday}, {date}, {name}’s photo"), add tile `week.history.a11y.add`, empty days `week.history.a11y.emptyDay`; the
  strip exposes horizontal scrolling to VoiceOver / TalkBack.
- Dynamic Type: `week.history.layout.textStyleMap` (header subheadline, weekday footnote, empty day title1 / subheadline,
  title largeTitle). Tile labels keep one line inside the tile (shrink to fit).
- Focus order: back → title → (per week) header → ••• → tiles left → right.
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | ratio | result | pair |
|---|---|---|---|---|---|
| `color.global.textPrimary` #FFFFFF | `color.global.backgroundDeep` #000000 | text | 21.00:1 | pass | 'Week N' 15 semibold, title, ••• |
| `color.global.textSecondary` #969696 | `color.global.backgroundDeep` #000000 | text | 7.10:1 | pass | date range 15 regular |

  Weekday labels sit on photos (no fixed backdrop; Retro's scrim not found): not computable. Empty-day labels
  `week.history.color.emptyTileText` #515151 on `week.history.color.emptyTile` #262626: **1.92:1 — FAIL** (text; reported,
  not adjusted — Retro's light pair fails too; `week.history.a11y.emptyDay` carries the date). "+" #FFFFFF on #262626:
  15.1:1 pass. Tile #262626 on #000000: 1.38:1 (boundary only).

## Data & actions

- `group_history_weeks(p_group_id, p_before_week, p_limit: 8)` (docs/API.md §6.4): weeks with posts, newest first,
  `post_ids` in time order; page with `p_before_week` = last `week_start`. The current week is synthesised by the client
  when it has no posts. Week number: ISO-8601 of `week_start` (Monday) in the group's time zone (`groups.time_zone`).
- `posts` / `media` for thumbnails and weekdays (`created_at` in the group's time zone); `weekly_recaps` (`week_start`,
  `status = ready`) to show "View recap".
- Realtime: `post_deleted` → drop tiles; INSERTs on `posts` → add to the current week.
- Navigation in: `groups.screen` (the group's week). Out: `photo.viewer`, `week.recap`, `week.edit`, `camera.capture`.

## Platform notes

- iOS: `DateIntervalFormatter` (date style medium-short per locale) for the range, `Calendar(identifier: .iso8601)` for
  week numbers; `LazyVStack` of sections with horizontal `ScrollView`s.
- Android: `java.time` `IsoFields.WEEK_OF_WEEK_BASED_YEAR`; `DateUtils.formatDateRange` for the range; `LazyColumn` with
  `LazyRow` strips.
- The display title uses the platform font (Retro's Roslindale is proprietary).

## Do-not-copy

- "Key holders only" / "Only friends you've given a key to can see back more than 4 weeks." / "Manage Key Holders".
- "Post to see" lock; "Weeks Posted: N"; "N new" / "Seen" pills; "Getting Started" progress ring and "3 different weeks" goal.
- Retro wordmark, Roslindale font, home "Last Week" capsule (trigger unconfirmed).

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| `week.history.color.emptyTile`, `week.history.color.emptyTileText` (dark mode) | **SOURCED (gap fill)**: #262626 / #515151 ("+" #FFFFFF → `color.global.textPrimary`) from Retro's dark appearance, 3 lossless captures 2025-10 / 2026-05 (G-15). `emptyTileText` now covers the labels only | — |
| `week.history.layout.weekMenu` (Retro's own ••• contents) | BLOCKED; our two items are product actions (gap fill: the public Retro screens show no menu) | one screenshot of Retro's week ••• menu |
| empty-day text sizes | ratio estimates (±2 pt) | one raw screenshot of a Retro current week with empty days |
| weekday label scrim on photos | not found | same screenshot |
| motion | not measured | one screen recording of scrolling Retro's profile |
| title + back circle composition | Retro profile title under a Yope back circle (S-16) | — |

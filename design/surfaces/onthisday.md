# `onthisday` — photos from this date in past years

Reference: **Timehop** (docs/SURFACES.md). Voice: `timehop.voice.uppercase-labels`, `timehop.voice.title-case-names`,
`timehop.voice.years-ago`, `timehop.voice.no-emoji`; states without a Timehop string use the app default voice
(`yope.voice.error`). Tokens: `design/tokens/memory.json` (`*.onthisday.*`) + `design/tokens/global.json`. Copy:
`design/copy/memory.json` (`onthisday.*`). Decisions: `design/MERGE_DECISIONS.md` → "Memory" (M-n below).

What it is: when a group has photos posted on today's month and day in earlier years, the group screen shows an
entry; tapping it opens a full-screen, tap-through "day": one screen per year, newest year first. It is **not** a
push notification (not in the directive's notification list) and Timehop's daily reminder is not built.

## References

| image | what it verifies |
|---|---|
| `references/auto/timehop/store/timehop-store-01.png` | single-photo memory: orange banner "3 YEARS AGO", photo fills the rest of the screen |
| `references/auto/timehop/store/timehop-store-02.png` | banner height from screen top (96.8 pt), label baseline 25.4 pt above banner bottom |
| `references/auto/timehop/store/timehop-store-05.png` | several photos: 2-column masonry, margins 3.8, gutter 4.2, 5.5 below the banner |
| `references/auto/timehop/store/timehop-store-03.png` | second sample of the orange banner colour |
| `references/auto/timehop/play/timehop-play-01.png`, `-02.png`, `-05.png` | Android build, same layout |
| `references/auto/timehop/help/th-help-2023-04-memory-view-hide.png` | progress bar at the top of the banner; meta row (source icon, "TUE  10:34 PM") over the photo; ✕ at the banner's right |
| `references/auto/timehop/help/th-help-2024-03-intro-day-in-history.jpg` | "VERONICA'S DAY IN HISTORY" (entry title wording) |
| `references/auto/timehop/help/th-help-2024-02-panel-share-1-year-ago.png` | singular "1 YEAR AGO" |

## Structure

**A. Entry (placed by `groups.screen`).** A row in the group screen, visible only while
`on_this_day(group, localDate)` returns at least one row. `onthisday` supplies the copy; the row component, its
position and tokens belong to the `groups.screen` pass (Yope).
1. Title: `onthisday.entry.title` ("{group}'s Day in History").
2. Second line: the newest memory's banner label (`onthisday.banner.yearsAgo.one` / `.other`).
Tap → opens the day (B) at the newest year.

**B. The day (full screen, one screen per year, newest first).** Top to bottom, edge to edge:
1. **Banner** — full screen width, from the screen top edge (behind the status bar) down to
   `dimension.onthisday.banner.height` (96.8 pt from the top). Fill `color.onthisday.banner`.
   - **Progress bar** on the banner's top edge directly below the status bar: full width, no inset, height
     `dimension.onthisday.progress.height`; reached part `color.onthisday.progress.fill`, rest
     `color.onthisday.progress.track`; reached fraction = (index + 1) / number of years (`layout.onthisday.progress`).
   - **Label** "N YEARS AGO", horizontally centred, baseline `dimension.onthisday.banner.labelBaseline` above the
     banner bottom; `fontSize.onthisday.banner.label` / `fontWeight.onthisday.banner.label`, `color.onthisday.banner.label`.
   - **Close** — header circle at the banner's right end, vertically centred on the label's row:
     `size.global.headerButton`, inset `size.global.headerInset` from the right edge, fill `color.global.controlOnDeep`,
     glyph `icon.global.close` in `color.global.textPrimary` (MERGE M-29: Timehop's 2023 ✕ sits there; its size was
     not measurable).
2. **Content** — one of:
   - **One photo** (`layout.onthisday.photo.single`): full width, from the banner bottom to the screen bottom,
     aspect-fill (cropped), no corner radius. Over its top-left, the **meta row**: the poster's avatar
     (`dimension.onthisday.meta.avatar` circle, `icon.global.person` on `color.global.control` when they have none)
     at `dimension.onthisday.meta.inset` from the left edge, centred `dimension.onthisday.meta.centerY` below the
     banner bottom; then, after `dimension.onthisday.meta.gap`, `onthisday.memory.meta` ("TUE 10:34 PM") in
     `fontSize.onthisday.meta` / `fontWeight.onthisday.meta`, `color.onthisday.meta.text`.
   - **Two or more photos** (`layout.onthisday.grid`): 2-column masonry, each photo at its own aspect ratio, placed in
     the shorter column, newest first (API order). First row `dimension.onthisday.grid.top` below the banner; outer
     margin `dimension.onthisday.grid.margin`; gutter `dimension.onthisday.grid.gutter` between columns and rows; gaps
     show `color.global.background`; no corner radius; no meta row (store-05 shows none). The content scrolls
     vertically under a fixed banner.
3. **Tap zones** over the content (`layout.onthisday.navigation`): right half → next (older) year; left half →
   previous (newer) year; on the newest year the left half does nothing; on the oldest year the right half closes the
   day. In the grid a tap on a photo is a zone tap too (the day is a pure tap-through, as in the reference); vertical
   drags scroll the grid; long-press is not used. No tap opens another screen.

Rows used for the day: `on_this_day` returns posts newest first with `years_ago`; group them by `years_ago`
ascending (1 year ago first), keeping API order inside a year.

## Elements

| element | tokens | copy keys | behaviour |
|---|---|---|---|
| entry title / second line | (row component: `groups.screen`) | `onthisday.entry.title`, `onthisday.banner.yearsAgo.one` / `.other` | shown only when the day has rows; tap opens the day |
| banner | `color.onthisday.banner`, `dimension.onthisday.banner.height`, `layout.onthisday.banner` | — | same colour for every year (M-9) |
| progress bar | `dimension.onthisday.progress.height`, `color.onthisday.progress.fill`, `color.onthisday.progress.track`, `layout.onthisday.progress` | — | fraction updates on each year change; hidden from accessibility (the banner label states the year) |
| years-ago label | `fontSize.onthisday.banner.label`, `fontWeight.onthisday.banner.label`, `color.onthisday.banner.label`, `dimension.onthisday.banner.labelBaseline`, `font.onthisday` | `onthisday.banner.yearsAgo.one` (years_ago = 1), `.other` (`{count}` = years_ago) | uppercase as stored |
| close | `size.global.headerButton`, `size.global.headerInset`, `color.global.controlOnDeep`, `icon.global.close`, `color.global.textPrimary` | `onthisday.a11y.close` | dismisses the day |
| single photo | `layout.onthisday.photo.single` | `onthisday.a11y.photo` | display rendition (`media.display_path`, original until `renditions_ready_at`) |
| meta row | `dimension.onthisday.meta.avatar`, `.inset`, `.centerY`, `.gap`, `fontSize.onthisday.meta`, `fontWeight.onthisday.meta`, `color.onthisday.meta.text`, `icon.global.person`, `color.global.control` | `onthisday.memory.meta` (`{weekday}` TUE, `{time}` 10:34 PM, group time zone) | single-photo memories only |
| grid | `layout.onthisday.grid`, `dimension.onthisday.grid.margin`, `.gutter`, `.top`, `color.global.background` | `onthisday.a11y.photo` per cell | thumb rendition (`thumb_path`) |
| tap zones | `layout.onthisday.navigation` | `onthisday.a11y.next`, `onthisday.a11y.previous` (accessibility actions) | no auto-advance |

## States

| state | design | copy | source |
|---|---|---|---|
| loading | banner area in `color.onthisday.banner`; centred platform activity indicator (`easing.global.native` activityIndicator) and the loading text in `fontSize.global.listSubtitle`, `color.global.textSecondary` on `color.global.background` | `onthisday.loading` "Collecting Memories" | Timehop help 812 (text); indicator PLATFORM |
| empty | not a screen: the entry is not shown when `on_this_day` returns no rows | — | caller brief; Timehop's empty state wording not found |
| error | `yope.voice.error` layout from foundations: text roles `emptyTitle` / `emptyDetail` centred on `color.global.background`, light pill `color.global.surfaceLight` / `color.global.onSurfaceLight`, `radius.global.capsule` | `onthisday.error.title` "Time Travel Failed", `onthisday.error.detail`, `onthisday.error.retry` | title Timehop help 767; rest app default voice |
| offline | same layout as error | `onthisday.offline.title`, `onthisday.offline.detail`, `onthisday.error.retry` | app default voice |
| photo missing (deleted while open, `post_deleted` broadcast) | drop the photo; drop the year when it was its last photo; close the day when none remain | — | docs/API.md 8.2 |
| permission-denied | n/a (no permission used) | — | — |

## Motion

| transition | token | Reduce Motion |
|---|---|---|
| open / close the day | native full-screen presentation (`easing.global.native` navigationPush / sheet) | system handles |
| year → year | cross-fade over `duration.onthisday.memoryChange` (700 ms, VidDay's photo-to-photo crossfade; curve `easing.global.native`) | same (a cross-fade is already the Reduce Motion substitute, `layout.global.reduceMotion`) |
| progress fill change | none (jumps with the year) | same |

## Haptics

None. Timehop's tap-through has no observed haptic, and HIG asks for haptics only where they add meaning.

## Accessibility

- **Labels / traits.** Banner label: header trait, read as stored ("3 YEARS AGO"). Close: `onthisday.a11y.close`,
  button. Each photo: `onthisday.a11y.photo` ("Photo by {name}, {weekday} {time}", spoken weekday in full), image
  trait. Meta row: hidden (its content is in the photo label). Progress bar: hidden.
- **Tap zones** are not reachable by VoiceOver / TalkBack: expose `onthisday.a11y.next` ("Older") and
  `onthisday.a11y.previous` ("Back") as custom accessibility actions on the content (iOS `accessibilityAction(named:)`,
  Android `CustomAccessibilityAction`); after a change, post a screen-changed notification so the new banner label is
  read.
- **Dynamic Type** (`layout.onthisday.textStyleMap`): banner label → `title1`; meta → `caption2`. The banner grows in
  height with the label (minimum `dimension.onthisday.banner.height`).
- **Focus order:** banner label → close → photo(s) top-left to bottom-right.
- **Contrast** (`node tools/contrast.mjs`):

  | pair | ratio | needs | result |
  |---|---|---|---|
  | `color.onthisday.banner.label` on `color.onthisday.banner` (25.8 pt bold) | 3.08 | 3 | pass |
  | `color.onthisday.progress.fill` vs `color.onthisday.progress.track` | 6.07 | 3 | pass |
  | `color.onthisday.progress.track` vs `color.onthisday.banner` | 2.91 | 3 | **FAIL** (reported; no sourced alternative) |
  | `color.onthisday.progress.fill` vs `color.onthisday.banner` | 2.09 | 3 | **FAIL** (reported) |
  | `color.global.surfaceLight` (error pill) on `color.global.background` | 17.93 | 3 | pass |
  | meta text `#FFFFFF` over a photo | photo-dependent | 4.5 | not guaranteed (no scrim in the reference) |
  | rejected v5 banner colours with the white label: `#FFC700` 1.56, `#14B6EF` 2.34 | — | 3 | **FAIL** → not used (M-9) |

## Data & actions

- **Read:** `rpc("on_this_day", p_group_id, p_local_date)` where `p_local_date` = the date of (now in
  `groups.time_zone` − 5 h) (`layout.onthisday.dayBoundary`). Not limited by `free_history_days` (docs/SPEC_FLAGS.md T1).
  Then `posts` / `media` by id for renditions, `profiles` (`display_name` first word, `avatar_path`) for the meta
  row and labels. Signed URLs, 1 h.
- **Realtime:** private broadcast `group:<group_id>` `post_deleted` → remove that post (States).
- **No writes.** No RPC is called.
- **Navigation in:** the entry on `groups.screen` (no deep link and no push for this surface). **Out:** close → back
  to the group screen.
- Blocks are already applied by `on_this_day` (rows from blocked authors are not returned).

## Platform notes

- iOS: present with `.fullScreenCover`; status bar text in light style over the banner. Android: full-screen
  destination, edge-to-edge (`WindowCompat.setDecorFitsSystemWindows(false)`), light status-bar icons over the banner.
- The banner bottom is measured from the screen top (not from the safe area) as in the reference; on devices with a
  taller status area the label still clears it (cap top ≈ 53 pt from the top).
- Masonry: iOS has no native masonry, so a two-column SwiftUI `Layout` that appends each photo to the shorter column;
  Android `LazyVerticalStaggeredGrid(StaggeredGridCells.Fixed(2))`, which places items the same way.

## Do-not-copy

Timehop streaks and streak screen ("2200", "6 YEAR CLUB", "ONE YEAR DOWN 365", Streak Pause); the mascot Abe and
news / sticker cards; ads, "Remove Ads", watermark and "Remove Watermark"; nag pushes (afternoon "haven't opened",
"finish your day … (you're so close!)") and the 8 am daily reminder (not in the directive's list); habit and expiry
framing ("it only lasts for 24 hours!", "your new daily habit"); "OPEN IN INSTAGRAM" and third-party source icons;
the Timehop wordmark. Not built either (MERGE M-20): the share screen (SQUARE / FULL, other members' photos leaving the
group), Then & Now ("AND NOW" blue fails contrast at 2.34:1; not in the product spec), "HIDE FROM {app_name}" (no API),
Timeskip, the intro card (white date on yellow).

## Gaps

| item | status | owner capture that closes it |
|---|---|---|
| per-memory banner colour rule | BLOCKED → one colour (`color.onthisday.banner`) | 15-20 s screen recording tapping through three years of one day on Timehop v5 (research capture 5) |
| `duration.onthisday.memoryChange` | SOURCED by gap fill: 700 ms from VidDay's memory montage (MERGE G2-17); Timehop's own not obtainable | same recording |
| progress bar in v5 | taken from the 2023 help composite (v5 renders show none) | same recording |
| banner height without the status bar | measured from the screen top on a marketing mockup (±5 %) | same recording |
| grid background in dark appearance | `color.global.background` (Timehop light #F5F0ED not used, M-8) | one Timehop dark-mode screenshot of a multi-photo day |
| empty-state wording | not needed (entry hidden) | research capture 4 if an empty screen is ever wanted |
| close button size / exact position | foundations header circle (M-29) | same recording |

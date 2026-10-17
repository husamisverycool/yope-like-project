# `plans.list` — every plan of a group: upcoming, past, cancelled

Server: `group_plans(p_group_id)` (`docs/API.md` §14.2, migration 0028). Tokens: existing names only (the `albums.list`
row and header composition). Copy: `design/copy/plans.json` (`plans.list.*`; the empty block's action reuses
`plans.create.entry`). Decisions: `design/MERGE_DECISIONS.md` → FV-1.

Visual reference: **Retro's Albums list** exactly as `albums.list` builds it (screen 10 / 11, ED-W3 pushed variant: back
chevron + serif title, C-15 rows with a 3:4 cover thumbnail, title over a grey line) with Retro's **C-20 section labels**
(`week.history`'s "Week N" headers) between the sections. Mechanics: **Apple Invites**' event categories — "Upcoming, All
Events, Past Events …" and, on iCloud.com, "See more events and categories: Scroll down" (support guide
view-your-events) — and the "+" next to the "Upcoming" title (AI-S 03); **Partiful**'s events page with "Past Events"
(help 15525513). Cancelled plans keep their own section (Apple keeps a cancelled event, "the name is crossed out", and
offers Restore). `level: SOURCED`, `method: "composition of Retro components C-02, C-01 glyph, C-20, C-15, C-27 in Apple
Invites' category order"`.

## References

| id | file | used for |
|---|---|---|
| AI-S 03 | `references/auto/apple-invites/store/apple-invites-store-03.png` | "Upcoming" title with the "+" (create) at the trailing edge |
| AI-G | https://support.apple.com/guide/apple-invites/view-your-events-dev18a008ffb/ios | the categories (Upcoming, Past Events), the web's scrolled categories |
| PF-H | help.partiful.com 15525513 "Where can I find my events?" | Past Events list |
| ED-W3 | `references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png` | pushed header, C-15 rows (as `albums.list`) |
| AV | `design/surfaces/albums.list.md`, `week.history.md` | the Retro composition reused |

## Structure (pushed from `groups.screen`; page `color.global.background`; one vertical scroll)

1. **Header** (C-02 pushed): back chevron (`plans.list.back.accessibilityLabel`) + `plans.list.title` ("Plans") in the
   display serif (`headerTitle`); trailing C-01 glyph `icon.global.add` (label `plans.create.entry`) → `plans.create`
   for this group (Apple's "+" beside "Upcoming").
2. **Sections**, in this order, each only when it has plans: `plans.list.section.upcoming` ("Upcoming"),
   `plans.list.section.past` ("Past Plans"), `plans.list.section.canceled` ("Canceled"). Each: C-20 label (text role
   `sectionLabel`, `color.global.textPrimary`, no "•••", no count) at `size.global.screenMargin` — the first one
   `size.global.titleToContent` below the header, the next ones `size.global.sectionGap` below the last row — then,
   `size.global.sectionHeaderToContent` below, C-15 rows `size.global.listGap` apart (`ThumbnailRowList`).
3. **Row** (C-15, as `albums.list`): the plan's cover as the 3:4 thumbnail (`size.global.rowThumbWidth` ×
   `.rowThumbHeight`, `radius.global.thumbnail`, aspect fill); a plan without a cover: the thumbnail in
   `color.global.control` with `icon.global.calendar` (`color.global.textSecondary`, `size.global.icon`) centred — the
   group cover's placeholder (`GroupCover` without a photo). Then the title (`listTitle`, up to two lines; cancelled:
   strikethrough in `color.global.textSecondary`, as `plans.page`) over the day line (`listSubtitle`,
   `color.global.textSecondary`: the locale's medium date + short time, all-day the date alone — `PlanFormats.rowLine`).
   No answer pill, no guest count (tenet 2). Tap → `plans.page`.
   Order (server): upcoming soonest first; past latest first; cancelled latest first.

## Entry on `groups.screen`

The plans block that holds the plan row (`PlanRowEntry` / `PlanEntries`): while the group has any plan, a C-20 label
`plans.list.title` with the trailing `icon.global.chevron` (`color.global.textSecondary`) at the right margin — the week
header's "see all" pattern (groups.screen item 7) — `size.global.sectionGap` under what precedes it; the plan row
`size.global.sectionHeaderToContent` below it. The label is one button → `plans.list` (header trait, hint
`plans.list.entry.accessibilityHint` "All Plans"). A group without plans shows only the "Make a Plan" row.

Next to a birthday request row (groups.screen item 6) the two blocks stand in date order, soonest first — Apple
Invites' "Upcoming" leads with "your next event": the birthday row's date is the birthday, the plan block's the next
plan's day; the same day keeps the birthday row first; with no upcoming plan the plan block comes last (MERGE FV-1).

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| back + title | C-02, `headerTitle` | `plans.list.back.accessibilityLabel`, `plans.list.title` | pop |
| + | C-01 glyph `icon.global.add` | `plans.create.entry` | → `plans.create` (sheet) |
| section label | C-20 (`sectionLabel`) | `plans.list.section.*` | header trait |
| row | C-15: `size.global.rowThumbWidth`, `.rowThumbHeight`, `.rowThumbGap`, `.listGap`, `radius.global.thumbnail`; `listTitle` / `listSubtitle` | title (data), day line (platform) | → `plans.page` |

## States

| state | when | design | copy |
|---|---|---|---|
| loading | first fetch, nothing cached | three C-15 thumbnails in `color.global.control`, no text (as `albums.list`) | announcement `week.history.a11y.loading` |
| empty | the group has no plan | C-27 centred under the header: `icon.global.calendar`, title, C-06 outline capsule → `plans.create` | `plans.list.empty.title`, `plans.create.entry` |
| loaded | ≥ 1 plan | sections as above | — |
| error | fetch failed, nothing shown yet | one tappable line under the header (`body`, `color.global.textSecondary`; tap = retry) — `albums.list` | `plans.list.error.title` |
| offline | no connection | the last list stays; nothing loaded yet → the same line with the offline text (tap = retry) | `plans.list.offline` |
| removed from group | `not_group_member` | pops back (the group screen shows its removed state) | — |
| permission-denied | not applicable | — | — |

Realtime: the group's plan changes (`plans`, `plan_answers` inserts and updates) refetch the list; it also refetches on
appear and when the app returns to the foreground.

## Motion

Push / pop native; rows appear with `duration.global.fade` (C-28). Reduce Motion: system.

## Haptics

Row tap (Android) `haptic.global.tap`; iOS none (as `albums.list`).

## Accessibility

- Header: the title is a header; the "+" reads `plans.create.entry`.
- Section labels: header trait. Rows: one button each, "{title}, {day line}"; a cancelled row is read under its
  "Canceled" header (the strikethrough itself is not read).
- Dynamic Type: rows grow; titles up to two lines, then truncate. Contrast as `albums.list` (`textSecondary` 5.10:1 light,
  7.37:1 dark).

## Do-not-copy

Guest counts ("12 Going"), "Hosting" / "Going" pills on rows (Apple's card pill), Drafts, Explore / public events,
Apple's category pull-down (one scroll holds the three sections, as on iCloud.com).

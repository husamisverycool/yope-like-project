# `plans.page` — one plan: details, answers, who's coming, album

Research: `design/research/plans.md`; data: `design/research/plans-data.md`; server: `docs/API.md` §14.2. Tokens:
existing names only. Copy: `design/copy/plans.json` (`plans.page.*`) — canonical, with each string's evidence and level;
pushes `notifications.push.plan*` in `design/copy/capture.json`. Decisions: `design/MERGE_DECISIONS.md` → New features
(PL-*).

Visual reference: Retro's **album detail** skeleton as used by `albums.view` / `groups.screen` (cover with its shadow,
serif name centred, grey meta line, a row of C-06 capsules, sections, a 3-column dated grid). Mechanics: **Apple Invites**
event page (order: title → date / time → place → RSVP → host + description → guests → shared album; cancel = crossed-out
name) and **Partiful** (answers Going · Maybe · Can't Go; guests see only Going and Maybe; photo album on the page).
`level: SOURCED`, `method: "composition of Retro components C-02, C-01 glyph, cover, C-06, C-16, C-20, C-23, C-14, C-21 in
Apple Invites' event-page order"`.

## References

| id | file | used for |
|---|---|---|
| AI-S 04 / 05 / 07 | `references/auto/apple-invites/store/apple-invites-store-04.png`, `-05.png`, `-07.png` (3.000 px/pt) | order; RSVP control (80-pt capsule, selected segment); host tile; guests tile; Shared Album tile + "Add Photos"; guest-list sections and 48-pt rows |
| AI-N | `references/auto/apple-invites/newsroom/ai-newsroom-2025-02-event-view*.jpg`, `-guest-list.jpg` | same, second event; guest notes under names |
| AI-G | support.apple.com guide: rsvp-to-an-event, cancel-or-delete-an-event, edit-an-event | answer, cancel (crossed-out, no RSVP, restorable), edit entry |
| AI-C | support.apple.com/guide/apple-invites/view-your-events-dev18a008ffb/ios ("Add an event to the Calendar app: Select an event, then select the Add to Calendar button"); AI-S 04 (the calendar glyph beside "•••" at the top of the event page) | Add to Calendar |
| PF-S 01 / 07 | `references/auto/partiful/store/partiful-store-01.png`, `-07.png` | in-app page: title, poster, date / time, "Hosted by", place, one-tap round "Going"; "Photo Album" + "Upload" |
| PF-W | `references/auto/partiful/web/pf-web-public-light-rsvp-sheet.png` (+ computed styles) | answer order Going · Maybe · Can't Go |
| PF-H | help.partiful.com 15525438, 15525507, 15525451, 15525446 | list visibility; no answer change after the event; cancel; photos |
| AV | `design/surfaces/albums.view.md`, `groups.screen.md` | the Retro composition reused |

## Structure (pushed from `groups.screen` / a push / the widget; page `color.global.background`; one vertical scroll)

1. **Header row** — C-02 back (`icon.global.back` at `size.global.backInset`); trailing C-01 glyphs
   (`size.global.headerIconPitch` apart): `icon.global.calendar` "Add to Calendar" (`plans.page.addToCalendar.accessibilityLabel`)
   while the plan is on (not canceled, its day not ended; AI-C), then `icon.global.more` → native menu: for the maker and admins while the plan is on `plans.page.menu.edit`, `plans.page.menu.cancel` (C-10
   red) / `plans.page.menu.restore` when canceled; on another member's plan `safety.report.menuItem.plan` and
   `safety.block.menuItemNamed` ("Block {first_name}", the maker), both C-10 red (safety.report kind `plan`, MERGE FV-4).
2. **Cover** (only when the plan has one) — `size.global.titleToContent` below the header line, centred,
   `groups.screen.size.coverWidth` × `.coverHeight`, `radius.global.thumbnail`, `groups.screen.shadow.cover`, aspect fill.
3. **Title** — `groups.screen.size.coverToTitle` below the cover (or `size.global.titleToContent` below the header),
   `font.global.display`, `displayMedium`, `color.global.textPrimary`, centred, up to 3 lines (Apple centres the title).
   Canceled: strikethrough (platform text attribute) in `color.global.textSecondary` (Apple "the name is crossed out").
4. **Meta lines** — `groups.screen.size.titleToMeta` below, centred, `listSubtitle`, `color.global.textSecondary`:
   line 1 the date and time (locale full date + short time; all-day: the date alone), line 2 the place (when set) —
   Apple's two centred lines under the title (17-pt lines, 26.3-pt pitch on AI-S 04; ours keep Retro's 15).
   Canceled: line 1 is `plans.page.canceled`.
5. **Answer row** (active plans whose day has not ended) — `groups.screen.size.metaToActions` below: three C-06
   capsules, equal widths, `size.global.pillGap` apart, inside `size.global.screenMargin`, `size.global.pillHeight` high:
   `plans.page.answer.going` · `plans.page.answer.maybe` · `plans.page.answer.cantGo` (Partiful's order). Unselected =
   outline variant; the member's current answer = primary variant (`color.global.accent` / `.onAccent`). Tapping the
   selected capsule again clears the answer (back to none). Hidden on canceled and past plans.
6. **Made by + note** — `size.global.sectionGap` below: C-16 people row with the maker's avatar
   (`size.global.avatarPicker`) and `plans.page.madeBy` (`listTitle`); the note under it (`body`, `color.global.textPrimary`,
   full text, links not detected). No crown or badge.
7. **Who's coming** — `size.global.sectionGap` below, one block per non-empty list in the order Going, Maybe:
   - C-20 label (`sectionLabel`): `plans.page.going` / `plans.page.maybe` — **no number, no range**; trailing
     `icon.global.chevron` (`color.global.textSecondary`) when the list continues in the sheet;
   - `size.global.sectionHeaderToContent` below: C-23 avatar stack (`size.global.avatarSmall`, overlap
     `size.global.avatarStackOverlap`, oldest answer first) and, under it, the first names joined by the platform list
     formatter (`listSubtitle`, `color.global.textSecondary`), wrapping;
   - tap → **who's coming sheet** (C-29 page sheet, title `plans.page.people.title`): C-14 sections "Going", "Maybe"
     (and "Can't go" for its own member and for the maker only) of C-16 rows (avatar `size.global.avatarPicker`, first
     name `listTitle`), like Apple's Guest List sections without "(9)".
   - When nobody has answered: no block (never "0 going", never "no one yet").
8. **Album** — after the plan's day, when the collected album has posts: C-20 label `plans.page.album` + trailing
   chevron → `albums.view` for it; `size.global.sectionHeaderToContent` below, the first rows of a C-21 3-column grid
   (square cells, `size.global.stripGap`, `radius.global.photo`) — at most 3 rows on this page (the album opens for the
   rest). Before the day ends: no album block (Apple's empty Shared Album tile + "Add Photos" is not copied: photos
   arrive by posting to the group as usual).

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| back | C-02 | `plans.page.back.accessibilityLabel` | pop |
| Add to Calendar | C-01 glyph `icon.global.calendar` | `plans.page.addToCalendar.accessibilityLabel` | the system's new-event editor, prefilled: title; timed → start, and end when the plan has one (iOS needs an end: start + 1 h, the person changes it; Android leaves it to the calendar app); all-day → the plan's day; place → location. iOS: EventKitUI `EKEventEditViewController` in a sheet (out of process since iOS 17: no calendar access asked, no usage string — developer.apple.com/documentation/eventkit/accessing-the-event-store); Android: `Intent.ACTION_INSERT` on `CalendarContract.Events.CONTENT_URI` (no `WRITE_CALENDAR` — developer.android.com/identity/providers/calendar-provider#intents); no calendar app → nothing happens. Nothing is written back to the plan |
| more | C-01 glyph `icon.global.more`, native menu (C-29) | `plans.page.more.accessibilityLabel`, `.menu.edit`, `.menu.cancel`, `.menu.restore` | edit → `plans.create` (edit mode); cancel → native confirm `plans.page.cancel.*` → `cancel_plan`; restore → `restore_plan` |
| cover | cover tokens as `groups.screen` | `plans.page.cover.accessibilityLabel` | → `photo.viewer` (single image) |
| title | `font.global.display` `displayMedium` | data | header trait |
| meta | `listSubtitle`, `color.global.textSecondary` | data; `plans.page.canceled` | none (no maps link) |
| answer capsules | C-06 outline / primary, `haptic.global.select` | `plans.page.answer.*` | `answer_plan` / `clear_answer`; optimistic; failure reverts + toast `plans.page.error.answer` |
| made by | C-16 + `body` | `plans.page.madeBy` | — |
| list block | C-20 + C-23 + list formatter | `plans.page.going`, `.maybe` | → people sheet |
| people sheet | C-29, C-14, C-16 | `plans.page.people.title`; sections `plans.page.going`, `plans.page.maybe`, `plans.page.people.cantGo` | rows are not tappable (no profile surface in scope) |
| album | C-20 + C-21 | `plans.page.album` | cell → `photo.viewer` (album order); label → `albums.view` |

## States

| state | when | design | copy |
|---|---|---|---|
| loading | first fetch | header, cover placeholder `color.global.control`, title skeleton-free (C-28: nothing until loaded, then `duration.global.fade`) | — |
| upcoming, no answer | default | answer row all outline | — |
| upcoming, answered | member answered | that capsule primary | — |
| today | `local_date` = today | same as upcoming; meta line 1 uses the platform "today" word + time (iOS `DateFormatter.doesRelativeDateFormatting`, Android ICU `DateFormat.RELATIVE_FULL`; VERIFIED, `references/auto/platform/relative-day-word-docs-excerpt.txt`, MERGE FV-2): "Today at 7:30 PM" | — |
| past | the day has ended | no answer row; lists read "Went" / "Maybe" (Partiful's past guest line "11 Went · 4 Maybe" without its counts); album block when collected | `plans.page.went` |
| canceled | `status = canceled` | strikethrough title, `plans.page.canceled`, no answer row, lists kept read-only (Apple keeps the guest list) | `plans.page.canceled` |
| removed from group / plan gone | RLS hides it | C-27 block centred | `plans.page.notFound.title`, `.notFound.detail` |
| error | fetch failed | C-27 error variant with retry | `plans.page.error.title` |
| offline | no connection | cached content; answer capsules disabled | `plans.page.offline` |

## Motion

Push / pop: native. Answer change: capsule fill cross-fade `duration.global.crossfade` (100 ms) — C-06 toggle (Retro's
own toggle motion is a Gap, `plans.md` §12 item 5); the name appearing in / leaving a list block: `duration.global.fade`.
Reduce Motion: cross-fades only (same durations). People sheet: `spring.global.sheetPresent`.

## Haptics

Answer selection: `haptic.global.select` (both platforms; C-30 selection rule). Other presses: `haptic.global.tap`
(Android). Cancel confirm: none beyond the platform alert.

## Accessibility

- The three capsules form one group "Your answer" (`plans.page.answer.groupLabel`) with selected trait on the current one
  (`.isSelected` / `selected = true` in a `selectableGroup`); double-tap the selected one = clear (custom action label
  `plans.page.answer.clear`).
- Title: header. Meta lines read as one element ("Saturday, October 24 at 7:30 PM, Maya's place").
- List blocks: one button each ("Going: Ana, Ben, and Chloe"); avatars hidden (decorative next to the names).
- Canceled: the strikethrough is announced through the line `plans.page.canceled` (strikethrough alone is not read).
- Dynamic Type: title `largeTitle`, meta and names `subheadline`, capsules `subheadline` (labels may wrap to 2 lines at
  AX sizes; capsules grow in height — C rules).
- Contrast (`node tools/contrast.mjs`): meta and names `textSecondary` on the page 5.10:1 light / 7.37:1 dark (pass since
  owner decision 20's #6E6E6E); capsule labels 21:1.

## Data & actions

Reads `plans` (+ cover signed URL), `plan_answers` (RLS-filtered: Going / Maybe for all, Can't go for self + maker),
`profiles` (first names, avatars), and the plan's photos — `plan_photos(p_plan_id)` (`docs/API.md` §14.2: the group's
posts of the plan's local days; none for a cancelled plan; there is no `albums` row, so the "Photos" label's target is
open — MERGE_DECISIONS "New features" → Problems found). Writes `answer_plan`, `clear_answer`, `cancel_plan`,
`restore_plan`. Realtime: inserts and updates of `plans` and `plan_answers` → refetch.
In: `groups.screen` plan row, `widget.countdown` (deep link), pushes `notifications.push.plan*`. Out: `plans.create`
(edit), `albums.view`, `photo.viewer`, the system calendar editor (Add to Calendar).

## Platform notes

iOS: `ScrollView` + `LazyVGrid`; strikethrough via `AttributedString.strikethroughStyle`; `ListFormatter.localizedString(byJoining:)`;
Add to Calendar `PlanCalendarEditor.swift`.
Android: `LazyColumn`; `TextDecoration.LineThrough`; `android.icu.text.ListFormatter.getInstance().format(names)`; Add to
Calendar `PlanCalendar.kt`.

## Do-not-copy

Counts ("12 Going • 3 Maybe • 4 Not Going", "GOING (9)", "+10"), "+ 2 additional guests", host crown badges, avatar
cluster bubbles, guest notes with reactions, weather / directions / map tiles, "Add Photos" / "Join Album" manual
uploads, Activity Feed with RSVP timestamps, event themes and animated backgrounds, "Remind me", "Interested", text
blasts.

## Gaps

| item | status | smallest capture |
|---|---|---|
| Retro capsule toggle motion | component default cross-fade | one screen recording of a Retro toggle capsule (e.g. "I'm in this") |
| past-plan list wording | Partiful's "Went" (count dropped), MERGE FV-2 | a screenshot of a past Apple Invites event's guest list would confirm |
| Apple Invites canceled event page | text only (AI-G) | one screenshot of a canceled event in Apple Invites |

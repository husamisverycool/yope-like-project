# `plans.page` — one plan: details, answers, who's coming, album (draft)

> **Draft, 2026-10-16.** Research: `design/research/plans.md`; data: `design/research/plans-data.md`. Copy keys are
> proposals (not yet in `design/copy/*.json`); tokens are existing names only.

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
| PF-S 01 / 07 | `references/auto/partiful/store/partiful-store-01.png`, `-07.png` | in-app page: title, poster, date / time, "Hosted by", place, one-tap round "Going"; "Photo Album" + "Upload" |
| PF-W | `references/auto/partiful/web/pf-web-public-light-rsvp-sheet.png` (+ computed styles) | answer order Going · Maybe · Can't Go |
| PF-H | help.partiful.com 15525438, 15525507, 15525451, 15525446 | list visibility; no answer change after the event; cancel; photos |
| AV | `design/surfaces/albums.view.md`, `groups.screen.md` | the Retro composition reused |

## Structure (pushed from `groups.screen` / a push / the widget; page `color.global.background`; one vertical scroll)

1. **Header row** — C-02 back (`icon.global.back` at `size.global.backInset`); trailing C-01 glyph `icon.global.more`
   (maker and admins only) → native menu: `plans.page.menu.edit`, `plans.page.menu.cancel` (C-10 red) /
   `plans.page.menu.restore` when canceled.
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
| more | C-01 glyph `icon.global.more`, native menu (C-29) | `plans.page.more.accessibilityLabel`, `.menu.edit`, `.menu.cancel`, `.menu.restore` | edit → `plans.create` (edit mode); cancel → native confirm `plans.page.cancel.*` → `cancel_plan`; restore → `restore_plan` |
| cover | cover tokens as `groups.screen` | `plans.page.cover.accessibilityLabel` | → `photo.viewer` (single image) |
| title | `font.global.display` `displayMedium` | data | header trait |
| meta | `listSubtitle`, `color.global.textSecondary` | data; `plans.page.canceled` | none (no maps link) |
| answer capsules | C-06 outline / primary, `haptic.global.select` | `plans.page.answer.*` | `answer_plan` / `clear_answer`; optimistic; failure reverts + toast `plans.page.error.answer` |
| made by | C-16 + `body` | `plans.page.madeBy` | — |
| list block | C-20 + C-23 + list formatter | `plans.page.going`, `.maybe` | → people sheet |
| people sheet | C-29, C-14, C-16 | `plans.page.people.title`, `.going`, `.maybe`, `.cantGo` | rows are not tappable (no profile surface in scope) |
| album | C-20 + C-21 | `plans.page.album` | cell → `photo.viewer` (album order); label → `albums.view` |

## States

| state | when | design | copy |
|---|---|---|---|
| loading | first fetch | header, cover placeholder `color.global.control`, title skeleton-free (C-28: nothing until loaded, then `duration.global.fade`) | — |
| upcoming, no answer | default | answer row all outline | — |
| upcoming, answered | member answered | that capsule primary | — |
| today | `local_date` = today | same as upcoming; meta line 1 uses the platform "today" word + time (BLOCKED word, `plans.md` §12 item 2) | — |
| past | the day has ended | no answer row; lists read "Went" / "Maybe" (Apple / Partiful past wording) — **BLOCKED** label text; album block when collected | `plans.page.went` (BLOCKED) |
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
- Contrast: meta and names `textSecondary` on page **2.85:1 FAIL** light (CONTRAST failure 1, reported like every
  `listSubtitle` line); capsule labels 21:1.

## Data & actions

Reads `plans` (+ cover signed URL), `plan_answers` (RLS-filtered: Going / Maybe for all, Can't go for self + maker),
`profiles` (first names, avatars), the plan's `albums` row and `album_items` → `posts` / `media` thumbnails. Writes
`answer_plan`, `clear_answer`, `cancel_plan`, `restore_plan`. Realtime `group:<id>` `plan_*` events → refetch.
In: `groups.screen` plan row, `widget.countdown` (deep link), pushes `notifications.push.plan*`. Out: `plans.create`
(edit), `albums.view`, `photo.viewer`.

## Copy (proposed, English)

| key | text | origin | pattern / source | level |
|---|---|---|---|---|
| `plans.page.answer.going` | Going | verbatim | Partiful (PF-W sheet), Apple (AI-S 04) | SOURCED |
| `plans.page.answer.maybe` | Maybe | verbatim | same | SOURCED |
| `plans.page.answer.cantGo` | Can't go | adapted | Partiful "Can't Go" → Retro sentence case (retro.voice.button) | SOURCED |
| `plans.page.answer.groupLabel` | Your answer | new | platform.a11yLabel | SOURCED |
| `plans.page.answer.clear` | Clear answer | new | platform.a11yLabel (verb first) | SOURCED |
| `plans.page.madeBy` | Made by {first_name} | adapted | Apple "Hosted by {name}" / Partiful "Hosted by" — "hosted" dropped (no host role; tenet 3) | SOURCED |
| `plans.page.going` | Going | verbatim | Apple guest-list section "Going" without its count (AI-S 07) | SOURCED |
| `plans.page.maybe` | Maybe | verbatim | same | SOURCED |
| `plans.page.people.title` | Who's Coming | new | retro.voice.title-case (sheet title); content of Apple "Guest List" | SOURCED |
| `plans.page.people.cantGo` | Can't go | adapted | Partiful "Can't Go" | SOURCED |
| `plans.page.album` | Photos | new | retro.voice.title-case section word; Apple "Shared Album" / Partiful "Photo Album" (the plan's album is already named after the plan) | SOURCED |
| `plans.page.canceled` | Canceled | adapted | Apple "the event has been canceled" / Partiful "the event was canceled" (US spelling of both) | SOURCED |
| `plans.page.menu.edit` | Edit Plan | adapted | Apple "Edit" + retro.voice.menu-labels; `plans.create.titleEdit` | SOURCED |
| `plans.page.menu.cancel` | Cancel Plan | adapted | Partiful "Cancel Event" (PF-H image), Apple "Cancel Event" — noun swapped | SOURCED |
| `plans.page.menu.restore` | Restore Plan | adapted | Apple "Restore Event" — noun swapped | VERIFIED |
| `plans.page.cancel.title` | Cancel {plan_title}? | new | retro.voice.confirm (action question naming its object) | SOURCED |
| `plans.page.cancel.message` | Everyone who's going or might go will be notified. | new | retro.voice.confirm (consequence in one line, "They will not be notified"); content: Apple "everyone on the guest list automatically receives a notification" | SOURCED |
| `plans.page.cancel.confirm` | Yes, cancel | new | retro.voice.confirm ("Yes, delete") | SOURCED |
| `plans.page.cancel.keep` | Keep Plan | new | retro.voice.button / title-case product object | SOURCED |
| `plans.page.error.answer` | Couldn't save your answer | adapted | Retro "Couldn't send comment" (`media_viewer_comment_send_failed_*`) | SOURCED |
| `plans.page.error.title` | Error loading plan. Tap here to try again. | adapted | Retro "Error loading friends. Tap here to try again." | SOURCED |
| `plans.page.notFound.title` | Couldn't find plan | adapted | Retro "Couldn't find album" | SOURCED |
| `plans.page.notFound.detail` | It may have been removed from the group. | new | retro.voice.explanation | SOURCED |
| `plans.page.offline` | Could not connect. Check your connection and try again. | verbatim | `groups.create.offline` | SOURCED |
| `plans.page.went` | — | — | past-tense list label: Partiful web shows "{n} Went" (count, do-not-copy); the word without a count is not evidenced as a label | BLOCKED |
| `plans.page.back.accessibilityLabel`, `.more.accessibilityLabel`, `.cover.accessibilityLabel` | Back · More · Cover of {plan_title} | adapted | `groups.screen.back.*`, `albums.view.a11y.cover` | VERIFIED / SOURCED |

## Platform notes

iOS: `ScrollView` + `LazyVGrid`; strikethrough via `AttributedString.strikethroughStyle`; `ListFormatter.localizedString(byJoining:)`.
Android: `LazyColumn`; `TextDecoration.LineThrough`; `android.icu.text.ListFormatter.getInstance().format(names)`.

## Do-not-copy

Counts ("12 Going • 3 Maybe • 4 Not Going", "GOING (9)", "+10"), "+ 2 additional guests", host crown badges, avatar
cluster bubbles, guest notes with reactions, weather / directions / map tiles, "Add Photos" / "Join Album" manual
uploads, Activity Feed with RSVP timestamps, event themes and animated backgrounds, "Remind me", "Interested", text
blasts.

## Gaps

| item | status | smallest capture |
|---|---|---|
| Retro capsule toggle motion | component default cross-fade | one screen recording of a Retro toggle capsule (e.g. "I'm in this") |
| past-plan list wording | BLOCKED (`plans.page.went`) | a screenshot of a past Apple Invites event's guest list |
| Apple Invites canceled event page | text only (AI-G) | one screenshot of a canceled event in Apple Invites |

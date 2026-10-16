# `plans.create` — make a plan in a group (draft)

> **Draft, 2026-10-16.** Research: `design/research/plans.md`; data: `design/research/plans-data.md`. Not yet in
> `docs/SURFACES.md`, `design/tokens/*.json` or `design/copy/*.json` — the copy keys below are proposals; tokens are
> existing `global.*` / `groups.*` names only (no new visual value).

Visual reference: Retro's **New Album** flow as already composed for `groups.create` step B (cover, C-07, C-12, C-05 on a
C-29 page sheet). Mechanics: **Apple Invites** create-an-event (fields and their order, all-day option, edit with ✓ / ×)
and **Partiful** New Event sheet (Cancel / New Event / Done; free-text place row; "Hosted by"). `level: SOURCED`,
`method: "composition of Retro components C-29, C-24 cover, C-07, C-12, C-14, C-05 in Apple Invites' create order"`.

## References

| id | file / URL | used for |
|---|---|---|
| AI-G | https://support.apple.com/guide/apple-invites/create-an-event-dev1d1c7cb6b/ios | field order: background → title → date and time (time zone, end, all-day) → location (optional name) → description; × / Save Event; Preview → Next |
| AI-N | `references/auto/apple-invites/newsroom/ai-newsroom-2025-02-create-an-event.jpg` | the create screen: "Edit Background" pill, "Event Title", tile "Date and Time" + "Location", "Hosted by {name}" / "Add a description." |
| PF-AP | `references/auto/partiful/frames/pf-apppreview-t7.250.png`, `-t9.250.png` | "Cancel / New Event / Done", title field, "Set a date...", "Hosted by (optional) host nickname", "Place name, address, or link…" |
| PF-H | help.partiful.com 15525294, 15525367 | square cover (1:1); date picker is a calendar |
| GC | `design/surfaces/groups.create.md` | the Retro composition reused (cover 173.5 × 246, C-07, C-12, C-05, sheet header) |

## Structure (page sheet C-29; page `color.global.background`)

Entry: `groups.screen` → the plan row's "+" / the group menu item `plans.create.entry` → this sheet (`spring.global.sheetPresent`).

1. **Sheet header** (C-29): centred title `plans.create.title` (text role `sheetTitle`); trailing close circle C-11
   (`size.global.circleButton`, `color.global.control`, `icon.global.close`).
2. **Cover** — `size.global.titleToContent` under the header, centred: `groups.screen.size.coverWidth` × `.coverHeight`,
   `radius.global.thumbnail`, `groups.screen.shadow.cover`; empty → `color.global.control`. Below it,
   `groups.screen.size.coverToTitle`: C-07 outline CTA `icon.global.add` + `plans.create.cover.add` (empty) or C-06
   outline `plans.create.cover.edit` (chosen). Optional (Apple: background first; Partiful: poster under the title).
3. **Title field** (C-12, inside `size.global.screenMargin`), `size.global.titleToContent` below: placeholder
   `plans.create.name.placeholder`; required; 1–80 characters.
4. **Details** — `size.global.sectionGap` below: one C-14 grouped section (`radius.global.groupedRow`), rows in Apple's order:
   - **Date** — leading `icon.global.calendar` (`size.global.iconSmall`), label `plans.create.date` (`body`), trailing value
     (`body`, `color.global.textSecondary`) = the chosen date in the locale's medium date format, or
     `plans.create.date.none` until chosen; tap → native date picker (inline graphical on iOS; M3 `DatePickerDialog`).
   - **All-day** — label `plans.create.allDay`, trailing native switch (tint `color.global.selection` /
     `color.global.system.primary`); default off.
   - **Time** (hidden while All-day is on) — label `plans.create.time`, trailing value in the locale's short time format;
     tap → native time picker (iOS wheel / M3 `TimePicker`); default: none chosen = all-day.
   - **Place** — leading `icon.global.location`, inline text field (placeholder `plans.create.place.placeholder`,
     `body`); optional, typed text only (no search, no suggestions, no Maps).
5. **Note** — `size.global.sectionGap` below: multi-line C-12 field (grows to 6 lines, then scrolls), placeholder
   `plans.create.note.placeholder`; optional; up to 2,048 characters.
6. **Create Plan** — C-05 primary capsule `plans.create.cta` (edit mode: `plans.create.save`), pinned
   `size.global.buttonMarginH` above the keyboard / bottom safe area; disabled until the title and a date are set.

No theme, effect, poll, playlist, link, co-host, guest-limit, approval or preview step (`plans.md` §10).

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| sheet header | C-29 `sheetTitle`, C-11 close | `plans.create.title` / `.titleEdit`, `plans.create.close.accessibilityLabel` | close with unsaved input → native confirm (`plans.create.discard.*`); empty form closes at once |
| cover | `groups.screen.size.coverWidth` / `.coverHeight`, `radius.global.thumbnail`, `groups.screen.shadow.cover`, `color.global.control` | `plans.create.cover.accessibilityLabel` | system photo picker; stored as a square crop (Partiful 1:1) |
| cover CTA | C-07 / C-06 outline | `plans.create.cover.add` / `.edit` | picker; "Remove" in the picker sheet when chosen |
| title | C-12 | `plans.create.name.placeholder`, `plans.create.name.accessibilityLabel`, `plans.create.error.tooLong` | trims; return moves to the date row |
| date / all-day / time / place rows | C-14, `icon.global.calendar`, `icon.global.location`, native pickers / switch | `plans.create.date`, `.date.none`, `.allDay`, `.time`, `.place.placeholder` | the date cannot be before today in the group's time zone (picker minimum) |
| note | C-12 multi-line | `plans.create.note.placeholder` | optional |
| Create Plan / Save | C-05 (disabled / busy as C-05) | `plans.create.cta` / `.save`; announcement `plans.create.creating` | upload cover → `create_plan` / `update_plan` → close and push / refresh `plans.page` |

## States

| state | when | design | copy |
|---|---|---|---|
| empty | opened | cover placeholder, empty fields, button disabled | — |
| ready | title + date set | button enabled | — |
| busy | creating | C-05 busy (platform indicator in the label colour) | `plans.create.creating` |
| error | RPC / upload failed | sheet stays; inline line under the button (`meta`, `color.global.destructive`) | `plans.create.error.failed`, `.error.cover` |
| offline | no connection | same line | `plans.create.offline` |
| edit | from `plans.page` menu "Edit Plan" | prefilled; title `plans.create.titleEdit`; button `plans.create.save` | — |
| past / canceled plan | edit not offered | — | — |
| permission-denied (photos) | picker denied | the platform's limited-access picker (PLATFORM); no app copy | — |

## Motion

Sheet: `spring.global.sheetPresent` (Retro measured, C-29). Time row show / hide with the All-day switch:
`duration.global.fade` + `easing.global.standard` (C rules); Reduce Motion: no height animation, cross-fade only.

## Haptics

Android presses: `haptic.global.tap`. Picker and switch: platform defaults. Create success: none (owner decision 15:
no haptic on send — creating a plan is a send).

## Accessibility

- Header: sheet title is a header; close labelled. Cover: button "Cover image" / "Edit cover image".
- Rows: each row is one element read as label + value ("Date, Saturday, October 24"); All-day is a switch; place and note
  fields have labels from copy (the placeholder is not the label).
- Dynamic Type: title field `body`, rows `subheadline`; the sheet scrolls; C-05 stays pinned.
- Contrast: as `groups.create` (placeholder `textSecondary` on `control` **2.52:1 FAIL** light — CONTRAST failure 1).

## Data & actions

`create_plan` / `update_plan` (`design/research/plans-data.md`); cover upload to storage as group covers; after create →
`plans.page` for the new plan; the group's members get one push (`notifications.push.planNew.*`).

## Copy (proposed, English)

| key | text | origin | pattern / source | level |
|---|---|---|---|---|
| `plans.create.entry` | Make a Plan | new | retro.voice.title-case (product-object button: "Create Album", "Send Postcard") | SOURCED |
| `plans.create.title` | New Plan | adapted | Retro "New Album" (`journal_creation_flow_title`, APK-S) — noun swapped; Partiful "New Event" (PF-AP) | SOURCED |
| `plans.create.titleEdit` | Edit Plan | adapted | `groups.create.titleEdit` "Edit Group" (Retro "Edit Profile") | SOURCED |
| `plans.create.close.accessibilityLabel` | Close | verbatim | `groups.create.close.accessibilityLabel` (platform) | VERIFIED |
| `plans.create.cover.add` | Add cover image | verbatim | Retro `journal_creation_profile_picture_primary_cta` via `groups.create.cover.add` | SOURCED |
| `plans.create.cover.edit` | Edit cover image | verbatim | `groups.create.cover.edit` | SOURCED |
| `plans.create.cover.accessibilityLabel` | Cover image | verbatim | `groups.create.cover.accessibilityLabel` | VERIFIED |
| `plans.create.name.placeholder` | Name your plan | adapted | Retro "Name your album" (`journal_creation_name_placeholder`) — noun swapped | SOURCED |
| `plans.create.name.accessibilityLabel` | Plan name | adapted | `groups.create.name.accessibilityLabel` "Group name" | SOURCED |
| `plans.create.date` | Date | adapted | Apple "Date and Time" (AI-G) split into two rows | SOURCED |
| `plans.create.date.none` | Choose | new | retro.voice.button ("Choose friends", RP §4.1) | SOURCED |
| `plans.create.allDay` | All-day | verbatim | Apple "all-day event" (AI-G); iOS Calendar row "All-day" (PLATFORM) | VERIFIED |
| `plans.create.time` | Time | adapted | Apple "Date and Time" | SOURCED |
| `plans.create.place.placeholder` | Place name or address | adapted | Partiful "Place name, address, or link" (PF-AP t 7.250) — "link" dropped (place is plain text) | SOURCED |
| `plans.create.note.placeholder` | Add a note… | adapted | Retro "Add a comment…" / "Add a caption…" (retro.voice.placeholder); Apple "Add Description" | SOURCED |
| `plans.create.cta` | Create Plan | adapted | `groups.create.cta` "Create Group" (Retro "Create Album") | SOURCED |
| `plans.create.save` | Save | verbatim | `groups.create.save` | SOURCED |
| `plans.create.creating` | Creating… | verbatim | `groups.create.creating` (retro.voice.progress) | SOURCED |
| `plans.create.error.failed` | Your plan wasn't created. Please try again. | adapted | `groups.create.error.failed` — noun swapped | SOURCED |
| `plans.create.error.cover` | Your cover image didn't upload. Please try again. | verbatim | `groups.create.error.cover` | SOURCED |
| `plans.create.error.tooLong` | Name too long | verbatim | `groups.create.error.tooLong` (Retro `error_full_name_too_long` pattern) | SOURCED |
| `plans.create.offline` | Could not connect. Check your connection and try again. | verbatim | `groups.create.offline` | SOURCED |
| `plans.create.discard.title` | Discard this plan? | new | retro.voice.confirm (action question naming its object: "Delete address?") | SOURCED |
| `plans.create.discard.confirm` | Yes, discard | new | retro.voice.confirm ("Yes, delete", "Yes, go back") | SOURCED |
| `plans.create.discard.cancel` | Cancel | verbatim | platform | PLATFORM |

## Do-not-copy

Apple: Image Playground backgrounds, title font styles, Maps search / weather, playlist, link tile, Preview / draft,
"Additional Guests", "Approve Guests". Partiful: themes, effects, "Poll your guests", host crown, ticketing, capacity.

## Gaps

| item | status | smallest capture |
|---|---|---|
| Retro's own creation form | not captured (as `groups.create`) | one screenshot of Retro's New Album sheet |
| Partiful in-app date picker | not in any store image or the preview | a 10-s recording of tapping "Set a date..." in Partiful |
| Apple Invites date/time picker | not captured | one screenshot of Apple Invites' Date and Time sheet |

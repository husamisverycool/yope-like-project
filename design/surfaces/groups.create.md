# `groups.create` — create a group: type, cover, name

Visual reference: Retro **"Ideas to Get Started"** templates (inventory #12, JED phone 3: Event / Friends / Couple rows
with a Fill "Create" pill) and Retro's **New Album** creation flow (APK-S `journal_creation_flow_title` "New Album",
`journal_creation_name_placeholder` "Name your album", `journal_creation_profile_picture_primary_cta` "+ Add cover image",
`journal_creation_form_next`). The creation form itself was not captured as an image: it composes the album-detail
cover (C-24 / `groups.screen.*` cover tokens), C-07, C-12 and C-05 in Retro's flow order (`level: SOURCED`,
`method: "composition of Retro components C-29 sheet header, C-15 template rows, C-24 cover, C-07, C-12, C-05 in Retro's
New Album order"`). Tokens: `groups.screen.size.cover*`, `groups.screen.shadow.cover` + `global.*`. Copy: `groups.create.*`.

Group kinds (`group_kind`: friends · family · roommates · custom) take Retro's template role: picking a template **is**
choosing the kind.

## References

| id | file | used for |
|---|---|---|
| JED | `references/auto/retro/press/jeddacp-2024-05-home-profile-journals.png` phone 3 | template rows: 3:4 cover, title 15 semibold, 2-line grey description, Fill "Create" capsule |
| TC-J1 | `references/auto/retro/press/tc-2024-04-journals-1.webp` phone 3 | book cover 173.5 × 246 with its drop shadow, centred |
| VID-SET | `references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png` | sheet header (centred 17 semibold title + close circle) |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | flow strings above; `journal_tab_suggestion_*`; `error_full_name_too_long` |

## Structure (page sheet, C-29; page `color.global.background`)

Sheet header (C-29): centred title (text role `sheetTitle`) + trailing close circle (C-11 on the page:
`size.global.circleButton`, `color.global.control`, `icon.global.close`); on step B a back chevron (C-02 glyph) leads.

### Step A — type (`groups.create.title`; skipped when opened from a template row or from edit)
1. `size.global.titleToContent` under the header: question `groups.create.type.label` (`font.global.display`,
   `displayMedium`) at the margin.
2. `size.global.titleToContent` below: four template rows (C-15 geometry, `size.global.listGap` apart), as in
   `groups.list` §3: the kind's cover photo (`groups.list.layout.templateCovers`), `groups.create.type.<kind>` + `.detail`, trailing fill capsule C-06
   `groups.create.type.create`. Tapping the row or its capsule → step B with that kind.

### Step B — cover and name (`groups.create.title`, or `groups.create.titleEdit` in edit mode)
1. `size.global.titleToContent` under the header: **cover**, centred: `groups.screen.size.coverWidth` ×
   `.coverHeight` (173.5 × 246), corners `radius.global.thumbnail` (4, C-15 cover corner), shadow
   `groups.screen.shadow.cover`; empty → `color.global.control` fill; chosen photo aspect-fills it.
2. `groups.screen.size.coverToTitle` (36.7) below the cover: outline CTA C-07 — `icon.global.add` +
   `groups.create.cover.add` while empty; C-06 outline capsule `groups.create.cover.edit` once chosen — centred.
3. `size.global.titleToContent` below: name field C-12 (inside `size.global.screenMargin`), placeholder
   `groups.create.name.placeholder`; inline `groups.create.error.tooLong` under it when needed (C-12 error).
4. Primary capsule C-05 `groups.create.cta` (edit: `groups.create.save`), pinned `size.global.buttonMarginH` above the
   keyboard / bottom safe area.

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| sheet header | C-29 (`sheetTitle`), C-11 close | `groups.create.title` / `.titleEdit`, `groups.create.close.accessibilityLabel`, `groups.create.back.accessibilityLabel` | close discards the form (no confirmation: nothing is lost that was saved) |
| question | `font.global.display`, `displayMedium` | `groups.create.type.label` | static |
| template row | C-15 + C-06 fill capsule | `groups.create.type.friends` / `.family` / `.roommates` / `.custom` + `.detail`; `groups.create.type.create` | selects the kind → step B |
| cover | `groups.screen.size.coverWidth` / `.coverHeight`, `radius.global.thumbnail`, `groups.screen.shadow.cover`, `color.global.control` | `groups.create.cover.accessibilityLabel` / `.changeAccessibilityLabel` | tap or the CTA → system photo picker (`auth.profile.layout.avatarPicker` mechanism) |
| cover CTA | C-07 / C-06 outline | `groups.create.cover.add` / `.edit` | picker |
| name field | C-12 | `groups.create.name.placeholder`, `groups.create.name.accessibilityLabel`; `groups.create.error.tooLong` | 1–80 characters after trimming; return = done |
| Create Group / Save | C-05 (disabled while the trimmed name is empty; busy with the platform indicator) | `groups.create.cta` / `.save`; announcement `groups.create.creating` | upload cover (if any) → `create_group` / `update_group` → close the sheet and push `groups.screen` (new group) |

## States

| state | when | design | copy |
|---|---|---|---|
| step A | opened from `groups.list` header glyph or empty-state CTA | as Structure A | — |
| step B, kind preselected | opened from a template row | as Structure B, no back chevron | — |
| edit | opened from `groups.settings` (admin) | step B prefilled with the cover and name; kind unchanged | `groups.create.titleEdit`, `groups.create.save` |
| creating / saving | upload + RPC | capsule busy (C-05 / C-28); fields disabled | `groups.create.creating` (announced) |
| create failed | RPC failed | message-only alert (`auth.phone.layout.inlineError`) | `groups.create.error.failed` + `auth.phone.error.dismiss` |
| save failed | RPC failed (edit) | message-only alert | `groups.create.error.saveFailed` |
| cover upload failed | Storage error | message-only alert; cover returns to empty | `groups.create.error.cover` |
| offline | no connection | message-only alert on the capsule tap; the form stays | `groups.create.offline` |
| empty / permission-denied | — | not applicable (the picker needs no permission) | — |

## Motion

- Sheet: native presentation (`spring.global.sheetPresent`, `duration.global.sheetPresent` 567 ms; C-29).
- Step A → B: native push inside the sheet (`easing.global.native`). Chosen cover fades in `duration.global.fade`.
- After create: the sheet closes (native) and `groups.screen` pushes. Reduce Motion: platform behaviour; fades stay.

## Haptics

Presses → `haptic.global.tap` (Android). Kind chosen → `haptic.global.select` (a choice among options, C-30 rule).
Created / saved → `haptic.global.success`; failed → `haptic.global.error`.

## Accessibility

- Template rows: one button each (title + description), the Create capsule a separate button with the same action.
- Cover: image button with its label; the CTA under it repeats the action.
- Dynamic Type: sheet title `headline`; question `largeTitle`; row title / description `subheadline`; field `body`;
  capsule `headline`.
- Focus order A: close → title → question → rows (row, Create). B: back → close → title → cover → cover CTA → name → capsule.
- Contrast: rows as `groups.list` (rows 1, 3, 9, 13 of CONTRAST); typed text 18.59:1 / 15.13:1 (row 9); placeholder
  **2.52:1 FAIL** light (row 11); cover / field fill vs page **1.13:1 / 1.39:1 FAIL** (row 13; non-text, labelled);
  error text red on page **4.18:1 FAIL** light (row 31).

## Data & actions

- Cover: upload to `u/<uid>/covers/<uuid>.jpg` (docs/API.md §9.2, §12 item 17).
- `create_group(p_name, p_kind, p_time_zone: device IANA zone, p_cover_path?)` → `groups` (caller = admin); waking hours
  omitted (default window).
- Edit: `update_group(p_group_id, p_name?, p_cover_path?)` (admins; `""` removes the cover).
- Errors: `invalid_name`, `invalid_kind`, `invalid_time_zone`, `invalid_path`, `not_group_admin` (edit).
- In: `groups.list` (header glyph, empty CTA, template rows), `groups.settings` ("Edit Group"). Out: `groups.screen`.

## Platform notes

- iOS `.sheet` large detent with its own `NavigationStack`; Android `ModalBottomSheet` expanded (or a full-screen
  destination) with an inner nav host. Keyboard: system; return key "done".

## Do-not-copy

- Retro's template photos, its user-styled cover titles and fonts (ED Lavonia, Chango, Mondwest …), and templates this
  app has no kind for (Event, Couple, Kid(s), Hobbies — mapped onto friends / family / custom).

## Gaps

| item | status | smallest capture |
|---|---|---|
| Retro's New Album form as an image | composition | screenshots of Retro's "New Album" flow (name + cover) |
| template thumbnails | closed (owner decision 9): the kinds' cover photos (`groups.list.layout.templateCovers`) | — |

# `settings.hidden` — Hidden Memories

What it is: the photos and calendar days you hid from your memories (On This Day's "Hide Photo" / "Hide This Day",
`onthisday.md` D), each with "Unhide" to show it again. Owner decision 34 ("hide a memory"),
`docs/RESEARCH_FEATURES_2026-10-17.md` #12. For you only: a hide changes nothing for anyone else (migration 0038).

Visual reference: Retro Settings rows (#28) with Retro's rows carrying a capsule action (#9, TC-1B), Retro's empty-state
voice and list errors as Retro's one tappable line — the same composition as `settings.blocked`
(`level: SOURCED`, `method: "composition of Retro components C-14, C-16, C-06, C-27 in the platform's list order"`).
Mechanics: Timehop's settings list its hidden memories with "UNHIDE" (T `help/th-help-2024-02-settings-hidden-memory.jpg`,
`design/research/retro-timehop.md`); Google Photos lists hidden dates under Preferences → Memories → "Hide dates"
(https://support.google.com/photos/answer/9454489, accessed 2026-10-17). Retro has no such list (its Rewind 'Hide photo'
is the only hide; where its hidden photos are shown again was never captured — Gaps). Copy: `settings.hidden.*`,
`settings.root.hiddenMemories`.

## References

| id | file | used for |
|---|---|---|
| TC-1B | `references/auto/retro/press/tc-2023-07-retro-1b.webp` | row with a trailing capsule action |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `friends_tab_loading_error`, `manage_keys_given_empty_state_title`, `rewind_home_no_permission_upsell_message`, `error_message_generic` |
| H43 | `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png` | C-27 block |
| T-HID | Timehop help `help/th-help-2024-02-settings-hidden-memory.jpg` (`design/research/retro-timehop.md`) | a settings list of hidden memories with "UNHIDE" (its count line is not copied) |

## Structure (pushed inside the Settings sheet; native back + centred `settings.hidden.title`)

One C-14 group of rows (C-16), newest hide first (`my_hidden_memories` order):
- **Hidden photo:** its thumbnail (`media.thumb_path`, the original until renditions are ready) at
  `size.global.avatarPicker` square, corners `radius.global.thumbnail`, aspect-fill; `size.global.rowThumbGap`; the day it
  was posted (`listTitle`, `layout.onthisday.dateFormat`, this device's time zone — the list spans groups).
- **Hidden day:** the C-23 circle (`size.global.avatarPicker`, fallback look) with `icon.global.calendar`; the day
  (`listTitle`, `layout.onthisday.dateFormat`), under it `settings.hidden.day.detail` ("Every photo from this day",
  `listSubtitle`, `color.global.textSecondary`).
- Trailing: hugging C-06 outline capsule `settings.hidden.unhide` (`size.global.pillHeight`), `size.global.pillGap` after
  the text. Rows ≥ `settings.root.size.rowHeight`, hairlines between.

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| row | C-14 + C-16; `size.global.avatarPicker`, `radius.global.thumbnail`, `icon.global.calendar`, `size.global.rowThumbGap` | date (data), `settings.hidden.day.detail` | static |
| Unhide | C-06 outline | `settings.hidden.unhide` | `unhide_memory(p_id)` at once (no confirmation: it only shows a memory again); the row fades out; `haptic.global.success`; no toast (the row leaving is the confirmation) |

## States

| state | design | copy |
|---|---|---|
| loading | one C-14 row with the platform activity indicator (C-28) | — |
| empty | C-27 block centred: glyph `icon.global.hide` → title → explanation (no action) | `settings.hidden.empty.title`, `.empty.message` |
| error | one tappable line centred (`body`, `color.global.textSecondary`) | `settings.hidden.error` (tap = retry) |
| offline | same line, retried when back online; on a list already shown, Unhide is disabled | `settings.hidden.error` |
| unhide failed | the row comes back; message-only alert; `haptic.global.error` | `settings.hidden.unhideError` |
| permission-denied | — | not applicable |

No count anywhere (Timehop's "1 Hidden Memory Today" is a count: tenets).

## Motion

Native push; a removed row fades `duration.global.fade` and the list closes the gap with the platform list animation.
Reduce Motion: fade only.

## Haptics

Unhide done → `haptic.global.success`; failed → `haptic.global.error`.

## Accessibility

- Row: the date as text; the thumbnail is decorative; the "Unhide" button's label includes the date ("Unhide Jul 22,
  2022") by composition.
- Dynamic Type: date `subheadline`; capsule `subheadline`.
- Contrast: as `settings.blocked` (rows 9, 12, 13, 20 of `design/CONTRAST.md`).

## Data & actions

- `rpc("my_hidden_memories")` (docs/API.md, migration 0038): hidden days, and hidden photos you can still see (with
  one post, its thumbnail path and when it was posted); signed thumbnail URLs (1 h).
- `rpc("unhide_memory", p_id)`: the photo or day is in On This Day, the Memories widget and the shuffle again from their
  next read.
- In: `settings.root` (Privacy → Hidden Memories). Out: back.

## Platform notes

- iOS: custom C-14 rows (not `List`), `StorageImage` thumbnail; Android: custom rows on
  `color.global.surfaceSecondary.android`, the thumbnail through the `Avatar` image component with the thumbnail shape.

## Do-not-copy

- Timehop's count line ("1 Hidden Memory Today"), capitals ("UNHIDE") and mascot.

## Gaps

| item | status | smallest capture |
|---|---|---|
| Retro's own place to show hidden Rewind photos again | not found (no string, no capture) | one recording of Retro's Rewind after 'Hide photo', then its settings |
| a hidden photo's row look in a reference app | composition (C-16 with a thumbnail) | Timehop's hidden-memory list with a photo row |

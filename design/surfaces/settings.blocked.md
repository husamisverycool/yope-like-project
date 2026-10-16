# `settings.blocked` — blocked people

Visual reference: Retro Settings rows (#28) with Retro's people rows (#9, TC-1B: avatar, name, capsule action) and
Retro's empty-state voice ("No keys shared yet"); list errors as Retro's one tappable line ("Error loading friends. Tap
here to try again."). Composition: `level: SOURCED`, `method: "composition of Retro components C-14, C-16, C-06, C-27
in the platform's list order"`. Copy: `settings.blocked.*`.

## References

| id | file | used for |
|---|---|---|
| TC-1B | `references/auto/retro/press/tc-2023-07-retro-1b.webp` | people row: avatar 37, name, capsule action |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `user_profile_unblock_profile`, `friends_tab_loading_error`, `manage_keys_given_empty_state_title` |
| H43 | `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png` | C-27 block |

## Structure (pushed inside the Settings sheet; native back + centred `settings.blocked.title`)

One C-14 group of people rows (C-16): avatar `size.global.avatarPicker` (C-23 fallback with `icon.global.person`
when you no longer share a group), first name (`listTitle`) or `settings.blocked.unknown` (`listTitle`,
`color.global.textSecondary`), trailing outline capsule C-06 `settings.blocked.unblock` (hugging, `size.global.pillHeight`).
Rows ≥ `settings.root.size.rowHeight`.

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| row | C-14 + C-16 | name (data) / `settings.blocked.unknown` | static |
| Unblock | C-06 outline | `settings.blocked.unblock` | `unblock_user(p_user_id)` at once (no confirmation: it is reversible); the row fades out; confirmation `safety.block.undone` (C-26) |

## States

| state | design | copy |
|---|---|---|
| loading | one C-14 row with the platform activity indicator (C-28) | — |
| empty | C-27 block centred: glyph `icon.global.person` → title → explanation (no action) | `settings.blocked.empty.title`, `.empty.message` |
| error | one tappable line centred (`body`, `color.global.textSecondary`) | `settings.blocked.error` (tap = retry) |
| offline | same line, retry when back online | `settings.blocked.error` |
| unblock failed | the row stays; message-only alert | `safety.block.error` |
| permission-denied | — | not applicable |

## Motion

Native push; removed row fades `duration.global.fade` and the list closes the gap with the platform list animation.
Reduce Motion: fade only.

## Haptics

Unblock press → `haptic.global.tap` (Android); done → `haptic.global.success`.

## Accessibility

- Row: name element + "Unblock" button (label includes the name: "Unblock Ana" via accessibility label composition).
- Dynamic Type: name `subheadline`; capsule `subheadline`.
- Contrast: rows 9, 12, 13, 20 of `design/CONTRAST.md`; unknown-name `textSecondary` on group **2.52:1 FAIL** light (row 11).

## Data & actions

- `blocks` (rows where you are the blocker, docs/API.md §5.6) + `profiles` when you still share a group; `unblock_user`.
- In: `settings.root` (Privacy → Blocked People). Out: back.

## Platform notes

- iOS: custom C-14 rows (not `List`); Android: custom rows on `color.global.surfaceSecondary.android`.

## Do-not-copy

- Retro's hidden-requests and key-holder lists (no such features).

## Gaps

| item | status | smallest capture |
|---|---|---|
| Retro's blocked list | not found in Retro (no strings beyond "Unblock Profile") | — (composition) |

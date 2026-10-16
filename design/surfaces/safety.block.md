# `safety.block` — block a person

Visual reference: Retro's block flow (APK-S `user_profile_block_profile` "Block Profile", `user_profile_confirm_block_title_template`
"Block %1$s?", `user_profile_confirm_block_message`; `user_profile_confirm_unfriend_message` "They will not be notified")
in native menus and confirmation dialogs (inventory #24, red destructive). System surface (PLATFORM) in Retro's voice.
Tokens: `safety.block.layout.menu`, `safety.block.layout.confirm`, `settings.account.layout.alert`. Copy: `safety.block.*`.

## References

| id | file / URL | used for |
|---|---|---|
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | menu item, confirm title / message, "Unfriended" confirmation pattern |
| TC-RWP | `references/auto/retro/press/tc-2025-12-rewind-panels.png` | native menu with a red destructive item |
| HIG | https://developer.apple.com/design/human-interface-guidelines/action-sheets | confirmation of an intentional destructive action |

## Structure

1. **Entry**: destructive menu item — `safety.block.menuItem` ("Block Profile") on a person (member "More Options",
   walls) or `safety.block.menuItemNamed` ("Block {first_name}") on their content (photo / message menus,
   `safety.report` next steps).
2. **Confirm** (`safety.block.layout.confirm`): iOS `confirmationDialog` with a visible title; Android `AlertDialog`:
   title `safety.block.title`, message `safety.block.message`, `safety.block.confirm` (destructive), `safety.block.cancel`.
3. **Done**: `block_user`; confirmation `safety.block.done` (C-26: Android Toast; iOS announcement); the person's content
   disappears from every shared group on the next fetch (RLS).

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| menu item | `safety.block.layout.menu` (C-29, destructive) | `safety.block.menuItem` / `.menuItemNamed` ({first_name}) | opens the confirm |
| confirm | `safety.block.layout.confirm` | `safety.block.title`, `.message`, `.confirm`, `.cancel` | `block_user(p_user_id)` |
| confirmation | C-26 | `safety.block.done`; after an unblock `safety.block.undone` | — |

## States

| state | design | copy |
|---|---|---|
| confirming | system dialog | as above |
| failed / offline | message-only alert (`auth.phone.layout.inlineError`) | `safety.block.error` + `auth.phone.error.dismiss` |
| done | confirmation; the screen you came from refreshes | `safety.block.done` |
| loading / empty / permission-denied | — | not applicable |

## Motion · Haptics

System dialog motion. Confirmed → `haptic.global.warning`; failed → `haptic.global.error`; press → `haptic.global.tap` (Android).

## Accessibility

Native dialog semantics; destructive role on the confirm button. Contrast: system colours (Android error #EA3337 on
`color.global.system.surfaceContainerHigh`, CONTRAST failure 6 family — reported).

## Data & actions

- `block_user(p_user_id)` / `unblock_user` (docs/API.md §6.3). The block works in both directions (§5.6).
- In: `groups.settings`, `groups.screen`, `photo.viewer`, `chat.thread`, `walls.member`, `safety.report`. Out: back.

## Platform notes

- iOS destructive button at the top of the action sheet, Cancel at the bottom; Android confirming action trailing.

## Do-not-copy

- Retro's "remove them as a friend" (no friendships here); any notice to the blocked person.

## Gaps

| item | status | smallest capture |
|---|---|---|
| Retro's block dialog as an image | strings only | screenshot of Retro's "Block …?" dialog |

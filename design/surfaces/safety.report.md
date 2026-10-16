# `safety.report` — report a post, message, person or group

Visual reference: Retro's report flow (APK-S `media_viewer_report_*`, `profile_report_*`: "Why are you reporting this
post?" / "What's wrong with this profile?", reason lists, "Next Steps" for "I don't like it", "Submitted!") shown in
native menus and action sheets as Retro does (inventory #24, TC-RWP: native menu with red destructive items).
System surface (PLATFORM) in Retro's voice. Tokens: `safety.report.layout.flow`, `safety.report.layout.reasons`.
Copy: `safety.report.*`.

## References

| id | file / URL | used for |
|---|---|---|
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | titles, reasons, next steps, "Submitted!", "Report Post" / "Report Profile" |
| TC-RWP | `references/auto/retro/press/tc-2025-12-rewind-panels.png` | native menu look, destructive red (C-29, C-10) |
| HIG | https://developer.apple.com/design/human-interface-guidelines/action-sheets ; App Review 1.2 | action sheet for a list of choices; reporting is required for user content |

## Structure

1. **Entry**: a menu item (C-29) on the content: `safety.report.menuItem.post` (photo long-press menu, viewer menu),
   `.message` (chat message menu), `.user` (member "More Options" in `groups.settings`, walls), `.group`
   (`groups.settings` "Report Group" row uses `groups.settings.report`).
2. **Reasons** (`safety.report.layout.flow`): native action sheet titled `safety.report.title.<kind>`; one button per
   reason from `safety.report.layout.reasons` (`safety.report.reason.*`), then `safety.report.cancel`.
   - iOS: `confirmationDialog(titleVisibility: .visible)`; Android: `ModalBottomSheet` with the title (text role
     `sheetTitle`) and one C-14-style row per reason (`body`), Cancel as the last row.
3. **Choosing a reason** files `report(kind, id, reason)` and closes the sheet; confirmation `safety.report.sent.title`
   (C-26: Android Toast; iOS accessibility announcement — no custom toast is drawn).
4. **"I don't like it"** (posts and messages) files nothing and opens a second action sheet titled
   `safety.report.nextSteps.title` with `safety.report.nextSteps.leave` (destructive) and
   `safety.report.nextSteps.block` (destructive), then Cancel. Leave → the leave alert of `groups.settings`
   (`groups.settings.leave.*`), then confirmation `safety.report.left`; Block → `safety.block`.

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| menu item | C-29 menu (destructive role not used for Report; Block items are destructive) | `safety.report.menuItem.*` | opens the reasons sheet |
| reasons sheet | C-29 action sheet / M3 bottom sheet; `safety.report.layout.flow` | `safety.report.title.post` / `.message` / `.user` / `.group`; `safety.report.reason.*`; `safety.report.cancel` | one tap files the report |
| next steps | C-29 action sheet | `safety.report.nextSteps.title`, `.nextSteps.leave`, `.nextSteps.block` | as Structure 4 |
| confirmation | C-26 | `safety.report.sent.title`; `safety.report.left` | — |

## States

| state | design | copy |
|---|---|---|
| sending | the sheet closes at once; the request runs in the background | — |
| sent | confirmation | `safety.report.sent.title` |
| failed / offline | message-only alert (`auth.phone.layout.inlineError`) titled | `safety.report.error.title`, `safety.report.error.detail` + `auth.phone.error.dismiss` |
| target gone | `target_not_found` | message-only alert | `safety.report.error.notFound` |
| loading / empty / permission-denied | — | not applicable | — |

## Motion · Haptics

Native sheets and menus (system motion). Reason chosen → `haptic.global.tap` (Android); report sent → `haptic.global.success`;
failed → `haptic.global.error`.

## Accessibility

Native semantics (sheet title read first, each reason a button). Dynamic Type: system styles in native sheets; the
Android sheet uses `sheetTitle` / `body` roles (`headline` / `subheadline`). Contrast: system colours (C-29); Android
rows 12 (19.60:1 / 15.13:1).

## Data & actions

- `report(p_target_kind, p_target_id, p_reason)` (docs/API.md §6.3); `p_reason` = the reason's text
  (`safety.report.layout.reasons.sent`). A block does not stop reporting.
- Leave: `leave_group`. Block: `block_user` (via `safety.block`).
- In: `photo.viewer`, `groups.screen` (cell menu), `chat.thread`, `groups.settings`, `walls.member`. Out: back.

## Platform notes

- iOS: `confirmationDialog` for both sheets. Android: `ModalBottomSheet` (`color.global.system.surfaceContainerLow`,
  top corners `radius.global.sheet.android`) — M3's own action-sheet form.

## Do-not-copy

- Retro's "Send a message" and "Unfriend" next steps (no direct messages or friendships here: mapped to Block, MERGE RA-12).

## Gaps

| item | status | owner input |
|---|---|---|
| moderation categories | Retro's lists used (`safety.report.layout.reasons`, was BLOCKED) | owner may extend the categories for moderation (docs/API.md §12 item 19) |
| free-text details | not offered (Retro offers none) | owner, if moderation needs details |
| Retro's report sheets as images | strings only | screenshot of Retro's report sheet |

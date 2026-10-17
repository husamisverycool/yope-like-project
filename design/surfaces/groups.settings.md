# `groups.settings` — members, notifications, invitation hours, leave, report

Visual reference: Retro **Settings sheet** (inventory #28, VID-SET: centred "Settings" + close circle, small grey section
headers, Fill grouped rows) with Retro's **album settings** sections (APK-S `journal_settings_*`: Members · Notifications
"Album updates" · Admin Settings · Leave Album) and member rows (#9 / TC-1B people rows; `journal_edit_members_*`).
Switches, pickers, menus and alerts are native (Apple HIG / Material 3, PLATFORM). Tokens: `settings.root.size.rowHeight`,
`settings.root.layout.list`, `settings.root.layout.toggleHaptic`, `settings.account.layout.alert` + `global.*`.
Copy: `groups.settings.*`.

## References

| id | file | used for |
|---|---|---|
| VID-SET | `references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png` frames 42–44 | sheet header, section headers, grouped Fill rows with chevrons |
| TC-J5 | `references/auto/retro/press/tc-2024-04-retro-journals-5.png` | grouped row height 58.7, red destructive row |
| TC-1B | `references/auto/retro/press/tc-2023-07-retro-1b.webp` | people rows: avatar 37, name, grey line, capsule actions |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `journal_settings_members_header`, `journal_settings_notifications_*`, `journal_settings_admin_settings_header`, `journal_settings_title_leave_journal`, `journal_edit_members_*`, `user_profile_*`, `notification_setting_title_pause_all` |

## Structure (page sheet, C-29; `settings.root.layout.list`; scrolls)

Header: centred `groups.settings.title` (`sheetTitle`) + trailing close circle (C-11 on the page,
`groups.settings.close.accessibilityLabel`).

Each section = C-14: header (text role `meta`, `color.global.textSecondary`, at `size.global.screenMargin`), then a
group (fill `color.global.control` iOS / `color.global.surfaceSecondary.android`, `radius.global.groupedRow`, inset
`size.global.screenMargin`, rows ≥ `settings.root.size.rowHeight`, row padding 16, hairline `color.global.separator`
between rows); sections `size.global.sectionGap` apart; footers under a group in text role `meta`,
`color.global.textSecondary`.

1. **Members** (`groups.settings.members.header`): one people row per member (C-16 in a C-14 row): avatar
   `size.global.avatarPicker` (37), first name (`listTitle`), subtitle (`listSubtitle` `color.global.textSecondary`):
   `groups.settings.members.you` on your row, `groups.settings.members.admin` for admins; trailing `icon.global.more`
   for admins on other members' rows (and for everyone on others' rows to report / block). Last row: outline capsule
   C-07 (`icon.global.add` + `groups.settings.members.invite.<kind>`) → `groups.invite`.
2. **Notifications** (`groups.settings.notifications.header`): row `groups.settings.notifications.updates` with a native
   switch (on = not muted); row `groups.settings.notifications.quietHours` with `icon.global.chevron` →
   `settings.notifications`; footer `groups.settings.notifications.footer`.
3. **Daily Invitation** (`groups.settings.invitation.header`): row `groups.settings.invitation.hours` with trailing value
   (`groups.settings.invitation.range` or `groups.settings.invitation.default`, `listSubtitle` `textSecondary`) →
   native time pickers (start / end); row `groups.settings.invitation.pause` with a switch; footer
   `groups.settings.invitation.footer`; non-admins: rows disabled, second footer line `groups.settings.invitation.adminOnly`.
4. **Admin Settings** (`groups.settings.group.header`, admins only): row `groups.settings.group.edit` + chevron → `groups.create` (edit).
5. Last group (no header): `groups.settings.report` (text `color.global.destructive`, C-10) and `groups.settings.leave`
   (`color.global.destructive`).

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| member row | C-16 in C-14 (`size.global.avatarPicker`, `listTitle`, `listSubtitle`) | first name (data), `groups.settings.members.you` / `.admin`; `groups.settings.members.more.accessibilityLabel` | tap → `walls.member` (that person's wall); "•••" → native menu (C-29, `groups.screen.layout.menu` look): `groups.settings.members.menu.remove` (admins, destructive), `.menu.report`, `.menu.block` (destructive) |
| remove alert | `settings.account.layout.alert` | `groups.settings.remove.title` ({first_name}), `.remove.message`, `.remove.confirm`, `groups.settings.alert.cancel` | `remove_member` |
| invite capsule | C-07 | `groups.settings.members.invite.friends` / `.family` / `.roommates` / `.custom` | → `groups.invite` |
| Group updates | C-14 row + native switch (`color.global.selection` / `color.global.system.primary`); `settings.root.layout.toggleHaptic` | `groups.settings.notifications.updates`, `.footer` | `set_group_muted(p_group_id, !on)` |
| Quiet Hours | C-14 row + `icon.global.chevron` | `groups.settings.notifications.quietHours` | → `settings.notifications` |
| Invitation Hours | C-14 row + value + native time pickers (iOS `DatePicker(.hourAndMinute)` in a sheet titled `.hours` with the rows `.start` / `.end`; Android two M3 `TimePicker` dialogs titled `.start`, then `.end`) | `groups.settings.invitation.hours`, `.start`, `.end`, `.range` ({start}, {end} locale short time), `.default`, `.invalid` | `set_group_invitation_hours(p_group_id, p_start, p_end)`; too-short window → message-only alert `groups.settings.invitation.invalid` |
| Pause Invitations | C-14 row + switch | `groups.settings.invitation.pause` | `set_group_invitation_paused` |
| Edit Group | C-14 row + chevron | `groups.settings.group.edit` | → `groups.create` (edit) |
| Report Group | C-14 row, C-10 | `groups.settings.report` | → `safety.report` (group) |
| Leave Group | C-14 row, C-10 | `groups.settings.leave`; alert `.leave.title` ({group_name}), `.leave.message` / `.leave.messageLast`, `.leave.confirm`, `groups.settings.alert.cancel` | `leave_group` → close the sheet and pop to `groups.list` |

## States

| state | when | design | copy |
|---|---|---|---|
| loading | members not loaded | sections with one C-14 row each showing the platform activity indicator (C-28) | — |
| default | — | as Structure | — |
| admin / member | role | admin-only rows hidden (Admin Settings) or disabled (invitation rows) | `groups.settings.invitation.adminOnly` |
| change failed | any RPC error | the control returns to its previous value; message-only alert | `groups.settings.error.generic` + `auth.phone.error.dismiss` |
| offline | no connection | controls disabled; the error alert on tap | `groups.settings.error.generic` |
| last member leaving | you are the only member | leave alert uses `groups.settings.leave.messageLast` | — |
| empty / permission-denied | — | not applicable | — |

## Motion

Sheet: native (`spring.global.sheetPresent`, `duration.global.sheetPresent`). Pushes inside the sheet: native.
Switches, pickers, menus, alerts: system. Rows disabled / enabled: `duration.global.crossfade`. Reduce Motion: platform.

## Haptics

Row presses → `haptic.global.tap` (Android). Switches: `settings.root.layout.toggleHaptic`. Destructive confirmed
(remove, leave) → `haptic.global.warning`. Failed → `haptic.global.error`.

## Accessibility

- Section headers: header trait. Member rows: one button (name + role) plus the "More Options" button. Switch rows:
  one toggle element each (label + state); footers read after their group.
- Destructive rows say their action in their label; colour is not the only cue (alerts confirm).
- Dynamic Type: rows `subheadline`; headers and footers `footnote`; rows grow with text.
- Focus order: close → title → members (rows, invite) → notifications → daily invitation → admin → report → leave.
- Contrast: row text on group 18.59:1 / 15.13:1 (row 9; Android row 12 19.60:1 / 15.13:1); subtitles and footers
  `textSecondary` on group **2.52:1 FAIL** light (row 11), 5.31:1 dark; on page **2.85:1 FAIL** light (row 3);
  Android meta **3.95:1 FAIL** light (row 6); red rows **3.70:1 / 3.62:1 FAIL** (row 32; Android 3.90:1 / 3.62:1 row 33);
  group fill vs page **1.13:1 / 1.39:1 FAIL** (rows 13–14). Reported (R-13).

## Data & actions

- Members: `group_members` + `profiles` (docs/API.md §5.4). Remove: `remove_member` (admins). Leave: `leave_group`.
- Mute: `set_group_muted`. Invitation: `set_group_invitation_hours` / `set_group_invitation_paused` (admins, §12 item 1).
- Quiet hours are per person (`settings.notifications`, `set_quiet_hours`).
- In: `groups.screen` (settings capsule, member stack). Out: `groups.invite`, `groups.create` (edit),
  `settings.notifications`, `walls.member`, `safety.report`, `safety.block`, `groups.list` (after leaving).

## Platform notes

- iOS: custom C-14 rows in a `ScrollView` (not `List(.insetGrouped)`: Retro's rows sit on the white page);
  `Toggle`, `DatePicker`, `Menu`, `.alert` native.
- Android: custom C-14 rows (`color.global.surfaceSecondary.android`), M3 `Switch` (tint `color.global.system.primary`),
  `TimePicker` dialog, `DropdownMenu`, `AlertDialog`.

## Do-not-copy

- Retro's album admin permissions ("Who can share photos?", "Who can manage members?"), "Download all photos" and
  "Delete Album" (no such API), view-only links, member counts.

## Gaps

| item | status | smallest capture |
|---|---|---|
| Settings rows at full resolution (title / subtitle sizes, row height) | C-14 + TC-J5 row height | raw screenshots of Retro's Settings (top + scrolled) (RV §6) |
| Retro's album settings screen as an image | strings only | screenshot of an album's Settings in Retro |

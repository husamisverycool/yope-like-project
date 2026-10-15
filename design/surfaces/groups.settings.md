# `groups.settings` — members, mute, quiet hours, invitation hours / pause, leave, report, block

Reference: **Yope + Apple HIG / Material 3** (`docs/SURFACES.md`). Yope's parts were found only in the 2024 build
(group ••• menu, members list; yope-a §2.13); mute, quiet hours, invitation hours and admin removal were not found in
Yope, so the screen is a **native grouped list** (system-surface components, PLATFORM) with Yope's words for labels and
explanations and the platform patterns for alerts and menus (copy-patterns surface map). API: `docs/API.md` §5.3–5.4,
§6.1, §9.7, §12 items 1, 2, 11, 12. Tokens: `settings.root.layout.list`, `settings.root.size.*.android`,
`settings.account.layout.alert`, `safety.block.layout.menu`. Copy: `groups.settings.*`.

## References

| id | file / URL | used for |
|---|---|---|
| M24 | `references/auto/yope/frames/a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png` | Yope's labels "share invite", "leave group" (red), "report" (red); native iOS menu |
| ML24 | `references/auto/yope/frames/a-yrrah-7434441926000037121-t43.23-members-list-2024.png` | member rows: avatar, bold name, ••• per row (no count used) |
| E26 | `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t51.23-group-created-empty-state.png` | "invite more friends" |
| HIG | https://developer.apple.com/design/human-interface-guidelines/lists-and-tables ; …/alerts ; …/menus | inset-grouped list, alerts, menus |
| M3 | https://m3.material.io/components/lists/specs ; …/dialogs/specs ; …/menus/specs | list items, dialogs, menus |

## Structure (native list, `settings.root.layout.list`)

Navigation title `groups.settings.title` (inline).

1. **members** (header `groups.settings.members.header`): one row per member in joining order — avatar
   (iOS `size.global.avatarPicker`, Android `settings.root.size.listItemAvatar.android`), name (first name + rest of
   `display_name`), secondary text `groups.settings.members.admin` for admins, `groups.settings.members.you` on the
   viewer's own row; trailing ••• (`icon.global.more`) on other members' rows. Last row: `groups.settings.members.invite.<kind>`
   with leading `icon.global.link` → `groups.invite` (hidden when the group is full).
2. **notifications**: Toggle `groups.settings.notifications.mute` (on = muted); row `groups.settings.notifications.quietHours`
   (disclosure) → `settings.notifications`; footer `groups.settings.notifications.footer`.
3. **daily invitation**: row `groups.settings.invitation.hours` with value `groups.settings.invitation.range`
   ({start}-{end}, `h:mm AM/PM`) or `groups.settings.invitation.default`; Toggle `groups.settings.invitation.pause`;
   footer `groups.settings.invitation.footer` (+ `groups.settings.invitation.adminOnly` for non-admins, rows read-only).
   Editing the hours (admins): two native time pickers (iOS `DatePicker(.hourAndMinute)` compact rows; Android M3
   `TimePicker` dialog), saved together.
4. **group** (admins only): row `groups.settings.group.edit` → `groups.create` (edit mode).
5. Actions section: `groups.settings.shareInvite` (→ `groups.invite`), `groups.settings.report` (destructive colour →
   `safety.report`, target group), `groups.settings.leave` (destructive colour → leave alert).

Member ••• menu (`safety.block.layout.menu`): `groups.settings.members.menu.remove` (admins; destructive) ·
`groups.settings.members.menu.report` (→ `safety.report`, target user) · `groups.settings.members.menu.block`
(→ `safety.block`).

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| list container | `settings.root.layout.list`; iOS `color.global.system.ios`; Android `color.global.system.surface`, `.onSurface`, `.onSurfaceVariant`, `.outline`; M3 sizes `settings.root.size.listItem*.android`, `.divider.android`; type `layout.global.system.typography` | headers / footers above | — |
| member row | avatar sizes above; label system body; secondary system subhead / bodyMedium | names (data), `groups.settings.members.admin`, `groups.settings.members.you`, ••• `groups.settings.members.more.accessibilityLabel` | row tap → `walls.member`; ••• → menu |
| toggles | system Toggle / M3 Switch; haptic `settings.root.layout.toggleHaptic` | `groups.settings.notifications.mute`, `groups.settings.invitation.pause` | optimistic; revert + footer error on failure |
| destructive rows | iOS `color.global.destructive` (Button role .destructive); Android `color.global.system.error`; glyphs `icon.global.report`, `icon.global.leave` | `groups.settings.report`, `groups.settings.leave` | — |
| leave alert | `settings.account.layout.alert` | `groups.settings.leave.title` ({group_name}), `.message` or `.messageLast` (last member), `.confirm`, `groups.settings.alert.cancel` | `leave_group` → pop to `groups.list` |
| remove alert | `settings.account.layout.alert` | `groups.settings.remove.title` ({first_name}), `.message`, `.confirm`, `groups.settings.alert.cancel` | `remove_member` |

## States

| state | design | copy |
|---|---|---|
| loading | native progress (`easing.global.native` activityIndicator) in place of the list | — |
| default | as Structure | — |
| non-admin | invitation rows read-only, "group" section hidden, no "remove" in member menus | `groups.settings.invitation.adminOnly` |
| error (save) | the control reverts; footer of that section shows the error | `groups.settings.error.generic` |
| invalid window | footer error under daily invitation | `groups.settings.invitation.invalid` |
| offline | toggles disabled; the list shows the cached values | `groups.settings.error.generic` on attempts |
| empty | never (the viewer is a member) | — |
| permission-denied | if notifications are off system-wide, the mute footer adds `settings.notifications.off.footer` + `settings.notifications.openSettings` | — |

## Motion · Haptics

All native (list push, menus, alerts, pickers). Toggles: `settings.root.layout.toggleHaptic`. Leave / remove confirmed →
`haptic.global.warning`. Errors → `haptic.global.error`.

## Accessibility

- System list semantics; member rows are buttons, ••• has its own label; destructive rows are announced by their text.
- Dynamic Type: system styles (iOS text styles, M3 type scale) — no fixed sizes.
- Focus order: members (rows, then invite) → notifications → daily invitation → group → actions.
- Contrast: platform colours; M3 pairs in design/CONTRAST.md (all pass except the drag handle, not used here).

## Data & actions

- Reads: `group_members` + `profiles` (§5.1, §5.4), `groups` (waking hours, paused, kind) (§5.3), own `muted`.
- Writes: `set_group_muted`, `set_group_invitation_hours(p_start, p_end)` (admins; both null = default),
  `set_group_invitation_paused` (admins), `remove_member` (admins), `leave_group`, `update_group` via `groups.create`.
- Errors: `not_group_admin`, `invalid_waking_window`, `member_not_found`, `cannot_target_self`.
- In: `groups.screen` profile ••• "group settings"; member avatars row. Out: `groups.invite`, `settings.notifications`,
  `groups.create` (edit), `safety.report`, `safety.block`, `walls.member`, `groups.list` (after leaving).

## Platform notes

- iOS: `List(.insetGrouped)`, `Toggle`, `Menu`, `.alert`. Android: `LazyColumn` of `ListItem`, `Switch`, `DropdownMenu`,
  `AlertDialog`, `TimePicker` in a dialog.
- `group_members.muted` is readable by co-members (API §12 item 12): the footer does not claim mute is private.

## Do-not-copy

- Member counts ("121 members"), "Pending" pills (no per-person pending state exists), presence dots, usernames.

## Report and block on this surface

- Report: the group (actions section, and ••• in `groups.screen`) and each member (member menu).
- Block: each member (member menu). Blocked members stay in the list (profiles stay readable, API §5.1).

## Gaps

| item | status | smallest capture |
|---|---|---|
| Yope 2026 group menu and member-row menu contents | not found (2024 only) | one screenshot of the ••• menu on the 2026 group profile + one of a member row's ••• menu |
| Yope mute / quiet hours / invitation hours UI | not found → native list (surface is Yope + HIG/M3) | — |

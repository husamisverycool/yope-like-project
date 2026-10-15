# Verification — `groups.settings` (iOS)

Members, notifications, invitation hours, leave / report / block — `Features/Account/Groups/GroupSettingsScreen.swift`.

Checklist written from the spec (`design/surfaces/groups.settings.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/groups.settings.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Reference image(s): `references/auto/yope/frames/a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png`, `references/auto/yope/frames/a-yrrah-7434441926000037121-t43.23-members-list-2024.png`, `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t51.23-group-created-empty-state.png`

Snapshots (CI): `groups.settings-admin.png`, `groups.settings-member-notifications-off.png`, `groups.settings-error.png`

**Summary: 47 matched · 1 approximated · 1 not matched (BLOCKED or not buildable) · 6 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | token | `settings.root.layout.list` | ios: List with .listStyle(.insetGrouped); Section(header:footer:); NavigationLink rows show the system disclosure indicator; colours color.global.system.ios;… (PLATFORM) | settings list container (also settings.notifications, settings.account, settings.blocked, groups.settings) | List with .insetGrouped style, system rows |
| matched | token | `settings.account.layout.alert` | ios: alert(_:isPresented:actions:message:): destructive-role button + Cancel; at most 3 buttons; Cancel is never the default; Cancel on the leading side; and… (VERIFIED) | confirmation alerts / dialogs (delete account; also leave group, remove member, block, turn off link) | iOS .alert / .confirmationDialog (system); the M3 dialog half is Android |
| matched | token | `safety.block.layout.menu` | ios: Menu (UIMenu) item with role .destructive; android: DropdownMenu item (M3 baseline: 48 dp items, 4 dp container corner, labelLarge) in color.global.syst… (VERIFIED) | 'Block' / 'Report…' items in overflow menus | Menu item with role .destructive |
| matched | copy | `groups.settings.title` | “group settings” (SOURCED) |  | `Copy.…groupsSettingsTitle` in GroupSettingsScreen.swift |
| matched | copy | `groups.settings.members.header` | “members” (SOURCED) |  | `Copy.…groupsSettingsMembersHeader` in GroupProfileScreen.swift, GroupSettingsScreen.swift |
| matched | token | `size.global.avatarPicker` | 40 pt (SOURCED) | avatar in a people-picker row | `Tokens.…globalAvatarPicker` in GroupSettingsScreen.swift |
| n/a | token | `settings.root.size.listItemAvatar.android` | 40 dp (VERIFIED) | M3 list item leading avatar size (blocked people, members) | Android only |
| matched | copy | `groups.settings.members.admin` | “admin” (SOURCED) |  | `Copy.…groupsSettingsMembersAdmin` in GroupSettingsScreen.swift |
| matched | copy | `groups.settings.members.you` | “you” (SOURCED) |  | `Copy.…groupsSettingsMembersYou` in GroupSettingsScreen.swift |
| matched | token | `icon.global.more` | ios: ellipsis; android: Rounded.MoreHoriz (PLATFORM) | more (•••) | `Tokens.…globalMore` in GroupProfileScreen.swift, GroupSettingsScreen.swift |
| matched | token | `icon.global.link` | ios: link; android: Rounded.Link (PLATFORM) | invite link | `Tokens.…globalLink` in GroupSettingsScreen.swift |
| matched | copy | `groups.settings.notifications.mute` | “mute this group” (SOURCED) |  | `Copy.…groupsSettingsNotificationsMute` in GroupSettingsScreen.swift |
| matched | copy | `groups.settings.notifications.quietHours` | “quiet hours” (SOURCED) |  | `Copy.…groupsSettingsNotificationsQuietHours` in GroupSettingsScreen.swift |
| matched | copy | `groups.settings.notifications.footer` | “muted groups don’t send you notifications. their pics still reach your widgets.” (SOURCED) |  | `Copy.…groupsSettingsNotificationsFooter` in GroupSettingsScreen.swift |
| matched | copy | `groups.settings.invitation.hours` | “invitation hours” (SOURCED) |  | `Copy.…groupsSettingsInvitationHours` in GroupSettingsScreen.swift |
| matched | copy | `groups.settings.invitation.range` | “{start}-{end}” (SOURCED) |  | `Copy.…groupsSettingsInvitationRange` in GroupSettingsModel.swift |
| matched | copy | `groups.settings.invitation.default` | “default hours” (SOURCED) |  | `Copy.…groupsSettingsInvitationDefault` in GroupSettingsModel.swift |
| matched | copy | `groups.settings.invitation.pause` | “pause invitations” (SOURCED) |  | `Copy.…groupsSettingsInvitationPause` in GroupSettingsScreen.swift |
| matched | copy | `groups.settings.invitation.footer` | “everyone gets the invitation at the same moment, once a day, sometime between these hours.” (SOURCED) |  | `Copy.…groupsSettingsInvitationFooter` in GroupSettingsScreen.swift |
| matched | copy | `groups.settings.invitation.adminOnly` | “only admins can change these.” (SOURCED) |  | `Copy.…groupsSettingsInvitationAdminOnly` in GroupSettingsScreen.swift |
| matched | copy | `groups.settings.group.edit` | “edit group” (SOURCED) |  | `Copy.…groupsSettingsGroupEdit` in GroupSettingsScreen.swift |
| matched | copy | `groups.settings.shareInvite` | “share invite” (SOURCED) |  | `Copy.…groupsSettingsShareInvite` in GroupSettingsScreen.swift |
| matched | copy | `groups.settings.report` | “report” (SOURCED) |  | `Copy.…groupsSettingsReport` in GroupSettingsScreen.swift |
| matched | copy | `groups.settings.leave` | “leave group” (SOURCED) |  | `Copy.…groupsSettingsLeave` in GroupSettingsScreen.swift |
| matched | copy | `groups.settings.members.menu.remove` | “Remove from Group” (VERIFIED) |  | `Copy.…groupsSettingsMembersMenuRemove` in GroupSettingsScreen.swift |
| matched | copy | `groups.settings.members.menu.report` | “Report…” (VERIFIED) |  | `Copy.…groupsSettingsMembersMenuReport` in GroupSettingsScreen.swift |
| matched | copy | `groups.settings.members.menu.block` | “Block” (VERIFIED) |  | `Copy.…groupsSettingsMembersMenuBlock` in GroupSettingsScreen.swift |
| matched | token | `color.global.system.ios` | groupedBackground: systemGroupedBackground; cell: secondarySystemGroupedBackground; label: label; secondaryLabel: secondaryLabel; placeholder: placeholderTex… (PLATFORM) | semantic colors of native inset-grouped lists, alerts and sheets on system surfaces (settings.*, safety.*, … | system list colours, no overrides |
| n/a | token | `color.global.system.surface` | #141218 (PLATFORM) | page / list container on Android system surfaces (role md.sys.color.surface, baseline dark scheme) | Android only |
| n/a | token | `color.global.system.onSurface` | #E6E0E9 (PLATFORM) | list item label, dialog headline (role md.sys.color.on-surface, baseline dark scheme) | Android only |
| n/a | token | `color.global.system.onSurfaceVariant` | #CAC4D0 (PLATFORM) | supporting text, leading icons, drag handle (role md.sys.color.on-surface-variant, baseline dark scheme) | Android only |
| n/a | token | `color.global.system.outline` | #938F99 (PLATFORM) | list divider (1 dp) (role md.sys.color.outline, baseline dark scheme) | Android only |
| matched | token | `layout.global.system.typography` | ios: built-in text styles (Font.TextStyle) on native lists, alerts and sheets; android: MaterialTheme.typography (M3 baseline type scale: list label bodyLarg… (PLATFORM) | text styles on system surfaces | system text styles (no custom font on system surfaces) |
| matched | copy | `groups.settings.members.more.accessibilityLabel` | “options for {first_name}” (SOURCED) |  | `Copy.…groupsSettingsMembersMoreAccessibilityLabel` in GroupSettingsScreen.swift |
| matched | token | `settings.root.layout.toggleHaptic` | ios: system (SwiftUI Toggle plays its own haptic; no custom generator); android: TOGGLE_ON / TOGGLE_OFF (API 34) only if the Switch does not already play one (PLATFORM) | haptic of every switch on settings surfaces | system Toggle haptic (no extra haptic added) |
| matched | token | `color.global.destructive` | #FF4245 (PLATFORM) | destructive actions on system surfaces (delete account, block, leave, report) — iOS systemRed via Button(ro… | role: .destructive (system red) |
| n/a | token | `color.global.system.error` | #F2B8B5 (PLATFORM) | error / destructive text and icons (role md.sys.color.error, baseline dark scheme) | Android only |
| matched | token | `icon.global.report` | ios: flag.fill; android: Rounded.Flag (PLATFORM) | report (menu item, destructive color) | `Tokens.…globalReport` in GroupProfileScreen.swift, GroupSettingsScreen.swift |
| matched | token | `icon.global.leave` | ios: rectangle.portrait.and.arrow.right; android: AutoMirrored.Rounded.Logout (PLATFORM) | leave group (menu item, destructive color) | `Tokens.…globalLeave` in GroupProfileScreen.swift, GroupSettingsScreen.swift |
| matched | copy | `groups.settings.leave.title` | “Leave {group_name}?” (VERIFIED) |  | `Copy.…groupsSettingsLeaveTitle` in GroupProfileScreen.swift |
| matched | copy | `groups.settings.leave.message` | “Your photos stay in the group. Delete them first if you want them gone.” (VERIFIED) |  | `Copy.…groupsSettingsLeaveMessage` in GroupProfileScreen.swift |
| matched | copy | `groups.settings.leave.messageLast` | “You’re the last member, so leaving deletes the group and everything in it.” (VERIFIED) |  | `Copy.…groupsSettingsLeaveMessageLast` in GroupProfileScreen.swift |
| matched | copy | `groups.settings.leave.confirm` | “Leave” (VERIFIED) |  | `Copy.…groupsSettingsLeaveConfirm` in GroupProfileScreen.swift |
| matched | copy | `groups.settings.alert.cancel` | “Cancel” (VERIFIED) |  | `Copy.…groupsSettingsAlertCancel` in GroupProfileScreen.swift, GroupSettingsScreen.swift |
| matched | copy | `groups.settings.remove.title` | “Remove {first_name}?” (VERIFIED) |  | `Copy.…groupsSettingsRemoveTitle` in GroupSettingsScreen.swift |
| matched | copy | `groups.settings.remove.message` | “Their photos stay in the group, and invite links they shared stop working.” (VERIFIED) |  | `Copy.…groupsSettingsRemoveMessage` in GroupSettingsScreen.swift |
| matched | copy | `groups.settings.remove.confirm` | “Remove” (VERIFIED) |  | `Copy.…groupsSettingsRemoveConfirm` in GroupSettingsScreen.swift |
| matched | token | `easing.global.native` | keyboard: system; alert: system; activityIndicator: system (ProgressView / CircularProgressIndicator); scrollIndicator: system; navigationPush: system (Navig… (PLATFORM) | motion of native components Yope uses; their curves and durations are the platform's | system push / sheet / alert animations |
| matched | copy | `groups.settings.error.generic` | “that didn’t work. check your connection and try again.” (SOURCED) |  | `Copy.…groupsSettingsErrorGeneric` in GroupSettingsModel.swift |
| matched | copy | `groups.settings.invitation.invalid` | “pick hours that are further apart” (SOURCED) |  | `Copy.…groupsSettingsInvitationInvalid` in GroupSettingsModel.swift |
| not matched | copy | `settings.notifications.off.footer` | “Notifications are off for {app_name}. You can turn them on in Settings.” (VERIFIED) |  | BLOCKED copy (uses {app_name}): DEBUG builds only (`AccountBlockedCopy.notificationsOffFooter`) |
| matched | copy | `settings.notifications.openSettings` | “Open Settings” (VERIFIED) |  | `Copy.…settingsNotificationsOpenSettings` in GroupSettingsScreen.swift |
| matched | token | `haptic.global.warning` | ios: notification.warning; android: CONFIRM (PLATFORM) | a destructive action was confirmed (delete account, block, leave) | `Tokens.…globalWarning` in BlockConfirmation.swift, GroupProfileScreen.swift, GroupSettingsScreen.swift |
| matched | token | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | a task failed (send failed) | `Tokens.…globalError` in BlockConfirmation.swift, GroupSettingsScreen.swift |

## Approximations

- Native inset-grouped list (system surface); invitation-hours pickers start at the saved window or the current time; nothing is saved until the two times differ.

## Not matched

- `settings.notifications.off.footer` — BLOCKED copy (uses {app_name}): DEBUG builds only (`AccountBlockedCopy.notificationsOffFooter`)

# Verification — `groups.settings` (iOS, Pass 4 — Retro redesign)

Group settings sheet — `Features/Account/Groups/GroupSettingsScreen.swift` (`GroupSettingsView`, `InvitationHoursSheet`), `GroupSettingsModel.swift`.

Checklist written from the spec (`design/surfaces/groups.settings.md`) against the iOS code: every token and copy key the spec names, its reference value, and where the iOS code uses it. The snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (AccountSnapshotTests: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/groups.settings.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png`, `references/auto/retro/press/tc-2024-04-retro-journals-5.png`, `references/auto/retro/press/tc-2023-07-retro-1b.webp`, `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`

Snapshots (CI, `ios/build/snapshots/account/`): `groups.settings-loading-light.png`, `groups.settings-admin-light.png`, `groups.settings-admin-dark.png`, `groups.settings-member-notifications-off-light.png`, `groups.settings-change-failed-light.png`

**Summary: 51 matched · 0 approximated · 0 not matched · 3 not applicable on iOS / owner / another pass.**


## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `settings.root.size.rowHeight` | 58.7 pt (SOURCED) | `Tokens.Sizes.settingsRootSizeRowHeight` in AccountGroupedRows.swift |
| matched | `settings.root.layout.list` | component: design/components.md C-14 on both platforms (custom rows; not List(.insetGrouped) / M3 ListItem); sheet: page sheet (C-29) with its own navigation… (SOURCED) | `SettingsList` / `SettingsGroup` / `SettingsRow` (AccountGroupedRows.swift): grouped rows on `color.global.background`, headers and footers |
| matched | `settings.root.layout.toggleHaptic` | ios: system (SwiftUI Toggle plays its own haptic; no custom generator); android: TOGGLE_ON / TOGGLE_OFF (API 34) only if the Switch does not already play one (PLATFORM) | SwiftUI `Toggle` plays its own haptic (no custom generator) |
| matched | `settings.account.layout.alert` | ios: alert(_:isPresented:actions:message:): destructive-role button + Cancel; at most 3 buttons; Cancel is never the default; android: M3 AlertDialog: contai… (VERIFIED) | native `.alert` / `.confirmationDialog` (C-29) |
| matched | `groups.settings.title` | “Settings” (SOURCED) | `Copy.groupsSettingsTitle` in GroupSettingsScreen.swift |
| matched | `groups.settings.close.accessibilityLabel` | “Close” (VERIFIED) | `Copy.groupsSettingsCloseAccessibilityLabel` in GroupSettingsScreen.swift |
| matched | `color.global.textSecondary` | #999999 (SOURCED) | `Tokens.Colors.globalTextSecondary` in AccountGroupedRows.swift, Avatar.swift, CheckRow.swift, CodeScreen.swift … |
| matched | `size.global.screenMargin` | 16 pt (SOURCED) | `Tokens.Sizes.globalScreenMargin` in AccountGroupedRows.swift, AgeGateForm.swift, CodeScreen.swift, EmptyStateView.swift … |
| matched | `color.global.control` | light: #F1F1F1; dark: #262626 (SOURCED) | `Tokens.Colors.globalControl` in AccountGroupedRows.swift, Avatar.swift, CapsuleButton.swift, CircleButton.swift … |
| n/a | `color.global.surfaceSecondary.android` | light: #F7F7F7; dark: #262626 (SOURCED) | Android only |
| matched | `radius.global.groupedRow` | 12 pt (SOURCED) | `Tokens.Radii.globalGroupedRow` in AccountGroupedRows.swift, GroupInviteScreen.swift, GroupedSection.swift |
| matched | `color.global.separator` | light: #CCCCCC; dark: #4D4D4D (SOURCED) | `Tokens.Colors.globalSeparator` in HairlineDivider.swift, ViewerChrome.swift |
| matched | `size.global.sectionGap` | 36.4 pt (SOURCED) | `Tokens.Sizes.globalSectionGap` in AccountGroupedRows.swift, GroupInviteScreen.swift, GroupScreen.swift, GroupsHomeScreen.swift … |
| matched | `groups.settings.members.header` | “Members” (SOURCED) | `Copy.groupsSettingsMembersHeader` in GroupSettingsScreen.swift |
| matched | `size.global.avatarPicker` | 37 pt (SOURCED) | `Tokens.Sizes.globalAvatarPicker` in GroupScreen.swift, GroupSettingsScreen.swift, PeopleRow.swift, SettingsBlockedScreen.swift |
| matched | `groups.settings.members.you` | “You” (SOURCED) | `Copy.groupsSettingsMembersYou` in GroupSettingsScreen.swift |
| matched | `groups.settings.members.admin` | “Admin” (SOURCED) | `Copy.groupsSettingsMembersAdmin` in GroupSettingsScreen.swift |
| matched | `icon.global.more` | ios: ellipsis; android: Rounded.MoreHoriz (PLATFORM) | `Tokens.Icons.globalMore` in FullBleedMediaPage.swift, GroupSettingsScreen.swift, ReplyBar.swift, SectionHeader.swift … |
| matched | `icon.global.add` | ios: plus; android: Rounded.Add (PLATFORM) | `Tokens.Icons.globalAdd` in GroupScreen.swift, GroupsHomeScreen.swift, OutlineCTA.swift, ThumbnailRow.swift … |
| matched | `groups.settings.notifications.header` | “Notifications” (SOURCED) | `Copy.groupsSettingsNotificationsHeader` in GroupSettingsScreen.swift |
| matched | `groups.settings.notifications.updates` | “Group updates” (SOURCED) | `Copy.groupsSettingsNotificationsUpdates` in GroupSettingsScreen.swift |
| matched | `groups.settings.notifications.quietHours` | “Quiet Hours” (SOURCED) | `Copy.groupsSettingsNotificationsQuietHours` in GroupSettingsScreen.swift |
| matched | `icon.global.chevron` | ios: chevron.right; android: AutoMirrored.Rounded.KeyboardArrowRight (PLATFORM) | `Tokens.Icons.globalChevron` in AccountGroupedRows.swift, GroupScreen.swift, GroupedSection.swift, SettingsAccountScreen.swift |
| matched | `groups.settings.notifications.footer` | “Turn this off to mute the group. Its photos still reach your widgets.” (SOURCED) | `Copy.groupsSettingsNotificationsFooter` in GroupSettingsScreen.swift |
| matched | `groups.settings.invitation.header` | “Daily Invitation” (SOURCED) | `Copy.groupsSettingsInvitationHeader` in GroupSettingsScreen.swift |
| matched | `groups.settings.invitation.hours` | “Invitation Hours” (SOURCED) | `Copy.groupsSettingsInvitationHours` in GroupSettingsScreen.swift |
| matched | `groups.settings.invitation.range` | “{start} – {end}” (SOURCED) | `Copy.groupsSettingsInvitationRange` in GroupSettingsModel.swift |
| matched | `groups.settings.invitation.default` | “Default” (SOURCED) | `Copy.groupsSettingsInvitationDefault` in GroupSettingsModel.swift |
| matched | `groups.settings.invitation.pause` | “Pause Invitations” (SOURCED) | `Copy.groupsSettingsInvitationPause` in GroupSettingsScreen.swift |
| matched | `groups.settings.invitation.footer` | “Everyone gets the invitation at the same moment, once a day, sometime between these hours.” (SOURCED) | `Copy.groupsSettingsInvitationFooter` in GroupSettingsScreen.swift |
| matched | `groups.settings.invitation.adminOnly` | “Only admins can change these.” (SOURCED) | `Copy.groupsSettingsInvitationAdminOnly` in GroupSettingsScreen.swift |
| matched | `groups.settings.group.header` | “Admin Settings” (SOURCED) | `Copy.groupsSettingsGroupHeader` in GroupSettingsScreen.swift |
| matched | `groups.settings.group.edit` | “Edit Group” (SOURCED) | `Copy.groupsSettingsGroupEdit` in GroupSettingsScreen.swift |
| matched | `groups.settings.report` | “Report Group” (SOURCED) | `Copy.groupsSettingsReport` in GroupSettingsScreen.swift |
| matched | `color.global.destructive` | #EA3337 (SOURCED) | `Tokens.Colors.globalDestructive` in AccountGroupedRows.swift, DestructiveButton.swift, FormField.swift, GroupInviteScreen.swift … |
| matched | `groups.settings.leave` | “Leave Group” (SOURCED) | `Copy.groupsSettingsLeave` in GroupSettingsScreen.swift |

## Elements

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `groups.settings.members.more.accessibilityLabel` | “More Options” (SOURCED) | `Copy.groupsSettingsMembersMoreAccessibilityLabel` in GroupSettingsScreen.swift |
| matched | `groups.screen.layout.menu` | ios: contextMenu on a grid cell / strip tile (UIMenu with a preview); destructive items role .destructive (red); android: DropdownMenu on long press of a gri… (PLATFORM) | `.contextMenu` on strip tiles, grid cells and friend cards: Report Post / Block {first_name} (destructive), none on own photos |
| matched | `groups.settings.members.menu.remove` | “Remove from Group” (SOURCED) | `Copy.groupsSettingsMembersMenuRemove` in GroupSettingsScreen.swift |
| matched | `groups.settings.remove.title` | “Remove {first_name}?” (SOURCED) | `Copy.groupsSettingsRemoveTitle` in GroupSettingsScreen.swift |
| matched | `groups.settings.alert.cancel` | “Cancel” (VERIFIED) | `Copy.groupsSettingsAlertCancel` in GroupSettingsScreen.swift, ReportFlow.swift |
| matched | `groups.settings.members.invite.friends` | “Invite Friends” (SOURCED) | `Copy.groupsSettingsMembersInviteFriends` in GroupKindCopy.swift |
| matched | `color.global.selection` | light: #0088FF; dark: #0091FF (PLATFORM) | `Tokens.Colors.globalSelection` in AccountGroupedRows.swift, CheckRow.swift, GroupedSection.swift, SettingsNotificationsScreen.swift … |
| n/a | `color.global.system.primary` | #0A84FF (SOURCED) | Android M3 dialog colour; iOS uses system alerts and the `color.global.selection` tint |
| matched | `groups.settings.invitation.invalid` | “Please pick hours that are further apart.” (SOURCED) | `Copy.groupsSettingsInvitationInvalid` in GroupSettingsModel.swift |

## States

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `groups.settings.error.generic` | “There was a problem. Please try again.” (SOURCED) | `Copy.groupsSettingsErrorGeneric` in GroupSettingsModel.swift |
| matched | `auth.phone.error.dismiss` | “OK” (VERIFIED) | `Copy.authPhoneErrorDismiss` in CodeScreen.swift, FormErrorAlert.swift, ReportFlow.swift |
| matched | `groups.settings.leave.messageLast` | “You're the last member, so leaving deletes the group and everything in it.” (SOURCED) | `Copy.groupsSettingsLeaveMessageLast` in GroupSettingsScreen.swift |

## Motion

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `spring.global.sheetPresent` | response: 0.347; dampingFraction: 1 (SOURCED) | system sheet presentation (`.sheet`) |
| matched | `duration.global.sheetPresent` | 567 ms (SOURCED) | system sheet presentation (`.sheet`) |
| matched | `duration.global.crossfade` | 100 ms (SOURCED) | `Tokens.Durations.globalCrossfade` in AgeGateForm.swift, ComponentSupport.swift |

## Haptics

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | Android only — iOS presses play no haptic |
| matched | `haptic.global.warning` | ios: notification.warning; android: CONFIRM (PLATFORM) | `Tokens.Haptics.globalWarning` in BlockConfirmation.swift, GroupInviteScreen.swift, GroupSettingsScreen.swift, ReportFlow.swift … |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | `Tokens.Haptics.globalError` in AgeGateForm.swift, BlockConfirmation.swift, CodeScreen.swift, GroupCreateScreen.swift … |

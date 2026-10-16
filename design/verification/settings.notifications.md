# Verification — `settings.notifications` (iOS, Pass 4 — Retro redesign)

Notification settings — `Features/Account/Settings/SettingsNotificationsScreen.swift`, `SettingsNotificationsModel.swift`.

Checklist written from the spec (`design/surfaces/settings.notifications.md`) against the iOS code: every token and copy key the spec names, its reference value, and where the iOS code uses it. The snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (AccountSnapshotTests: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/settings.notifications.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png`, `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`, `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png`

Snapshots (CI, `ios/build/snapshots/account/`): `settings.notifications-no-groups-light.png`, `settings.notifications-loading-light.png`, `settings.notifications-default-light.png`, `settings.notifications-default-dark.png`, `settings.notifications-quiet-hours-light.png`, `settings.notifications-permission-off-light.png`

**Summary: 23 matched · 0 approximated · 0 not matched · 4 not applicable on iOS / owner / another pass.**


## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `settings.root.size.rowHeight` | 58.7 pt (SOURCED) | `Tokens.Sizes.settingsRootSizeRowHeight` in AccountGroupedRows.swift |
| matched | `settings.notifications.title` | “Notifications” (SOURCED) | `Copy.settingsNotificationsTitle` in SettingsNotificationsScreen.swift |
| matched | `settings.notifications.off.title` | “Keep up to date!” (SOURCED) | `Copy.settingsNotificationsOffTitle` in SettingsNotificationsScreen.swift |
| matched | `settings.notifications.off.footer` | “Enable push notifications to make sure that you always see the latest updates from your groups.” (SOURCED) | `Copy.settingsNotificationsOffFooter` in SettingsNotificationsScreen.swift |
| matched | `color.global.textSecondary` | #999999 (SOURCED) | `Tokens.Colors.globalTextSecondary` in AccountGroupedRows.swift, Avatar.swift, CheckRow.swift, CodeScreen.swift … |
| matched | `settings.notifications.openSettings` | “Enable push” (SOURCED) | `Copy.settingsNotificationsOpenSettings` in SettingsNotificationsScreen.swift |
| matched | `settings.notifications.groups.header` | “Groups” (SOURCED) | `Copy.settingsNotificationsGroupsHeader` in SettingsNotificationsScreen.swift |
| matched | `size.global.avatarComment` | 31.2 pt (SOURCED) | `Tokens.Sizes.globalAvatarComment` in PeopleRow.swift, ReplyBar.swift, SettingsNotificationsScreen.swift |
| matched | `icon.global.group` | ios: person.2; android: Outlined.Group (PLATFORM) | `Tokens.Icons.globalGroup` in GroupCreateScreen.swift, SettingsNotificationsScreen.swift, TabBar.swift |
| matched | `settings.notifications.groups.footer` | “Turn a group off to mute it. Its photos still reach your widgets.” (SOURCED) | `Copy.settingsNotificationsGroupsFooter` in SettingsNotificationsScreen.swift |
| matched | `settings.notifications.quietHours` | “Quiet Hours” (SOURCED) | `Copy.settingsNotificationsQuietHours` in SettingsNotificationsScreen.swift |
| matched | `settings.notifications.quietHours.start` | “Start” (SOURCED) | `Copy.settingsNotificationsQuietHoursStart` in GroupSettingsScreen.swift, SettingsNotificationsScreen.swift |
| matched | `settings.notifications.quietHours.footer` | “Notifications arrive silently between these times.” (SOURCED) | `Copy.settingsNotificationsQuietHoursFooter` in SettingsNotificationsScreen.swift |
| matched | `settings.notifications.liveActivity` | “Live Activity” (VERIFIED) | `Copy.settingsNotificationsLiveActivity` in SettingsNotificationsScreen.swift |
| matched | `settings.notifications.liveActivity.footer` | “Shows the daily invitation on your Lock Screen while it's open.” (SOURCED) | `Copy.settingsNotificationsLiveActivityFooter` in SettingsNotificationsScreen.swift |
| n/a | `settings.notifications.categories` | “Notification Categories” (VERIFIED) | Android only (notification channels) |
| matched | `settings.root.layout.list` | component: design/components.md C-14 on both platforms (custom rows; not List(.insetGrouped) / M3 ListItem); sheet: page sheet (C-29) with its own navigation… (SOURCED) | `SettingsList` / `SettingsGroup` / `SettingsRow` (AccountGroupedRows.swift): grouped rows on `color.global.background`, headers and footers |
| matched | `size.global.sectionGap` | 36.4 pt (SOURCED) | `Tokens.Sizes.globalSectionGap` in AccountGroupedRows.swift, GroupInviteScreen.swift, GroupScreen.swift, GroupsHomeScreen.swift … |

## Elements

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `color.global.selection` | light: #0088FF; dark: #0091FF (PLATFORM) | `Tokens.Colors.globalSelection` in AccountGroupedRows.swift, CheckRow.swift, GroupedSection.swift, SettingsNotificationsScreen.swift … |
| n/a | `color.global.system.primary` | #0A84FF (SOURCED) | Android M3 dialog colour; iOS uses system alerts and the `color.global.selection` tint |

## States

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `settings.notifications.error` | “There was a problem saving your changes. Please try again.” (SOURCED) | `Copy.settingsNotificationsError` in SettingsNotificationsModel.swift |
| matched | `auth.phone.error.dismiss` | “OK” (VERIFIED) | `Copy.authPhoneErrorDismiss` in CodeScreen.swift, FormErrorAlert.swift, ReportFlow.swift |

## Motion

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `spring.global.platformDefault.android` | response: 0.16223; dampingFraction: 1 (PLATFORM) | Android only |
| matched | `duration.global.fade` | 150 ms (SOURCED) | `Tokens.Durations.globalFade` in ComponentSupport.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, PaywallScreen.swift … |

## Haptics

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `settings.root.layout.toggleHaptic` | ios: system (SwiftUI Toggle plays its own haptic; no custom generator); android: TOGGLE_ON / TOGGLE_OFF (API 34) only if the Switch does not already play one (PLATFORM) | SwiftUI `Toggle` plays its own haptic (no custom generator) |
| n/a | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | Android only — iOS presses play no haptic |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | `Tokens.Haptics.globalError` in AgeGateForm.swift, BlockConfirmation.swift, CodeScreen.swift, GroupCreateScreen.swift … |

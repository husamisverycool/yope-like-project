# Verification — `settings.notifications` (iOS)

Notification settings — `Features/Account/Settings/SettingsNotificationsScreen.swift`.

Checklist written from the spec (`design/surfaces/settings.notifications.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/settings.notifications.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Snapshots (CI): `settings.notifications-default.png`, `settings.notifications-quiet-hours.png`, `settings.notifications-system-off.png`

**Summary: 13 matched · 1 approximated · 1 not matched (BLOCKED or not buildable) · 1 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | token | `settings.root.layout.list` | ios: List with .listStyle(.insetGrouped); Section(header:footer:); NavigationLink rows show the system disclosure indicator; colours color.global.system.ios;… (PLATFORM) | settings list container (also settings.notifications, settings.account, settings.blocked, groups.settings) | List with .insetGrouped style, system rows |
| matched | token | `settings.root.layout.toggleHaptic` | ios: system (SwiftUI Toggle plays its own haptic; no custom generator); android: TOGGLE_ON / TOGGLE_OFF (API 34) only if the Switch does not already play one (PLATFORM) | haptic of every switch on settings surfaces | system Toggle haptic (no extra haptic added) |
| matched | copy | `settings.notifications.title` | “Notifications” (VERIFIED) |  | `Copy.…settingsNotificationsTitle` in SettingsNotificationsScreen.swift |
| not matched | copy | `settings.notifications.off.footer` | “Notifications are off for {app_name}. You can turn them on in Settings.” (VERIFIED) |  | BLOCKED copy (uses {app_name}): DEBUG builds only (`AccountBlockedCopy.notificationsOffFooter`) |
| matched | copy | `settings.notifications.openSettings` | “Open Settings” (VERIFIED) |  | `Copy.…settingsNotificationsOpenSettings` in SettingsNotificationsScreen.swift |
| matched | copy | `settings.notifications.groups.header` | “Groups” (VERIFIED) |  | `Copy.…settingsNotificationsGroupsHeader` in SettingsNotificationsScreen.swift |
| matched | copy | `settings.notifications.groups.footer` | “Turn a group off to mute it. Its photos still reach your widgets.” (VERIFIED) |  | `Copy.…settingsNotificationsGroupsFooter` in SettingsNotificationsScreen.swift |
| matched | copy | `settings.notifications.quietHours` | “Quiet Hours” (VERIFIED) |  | `Copy.…settingsNotificationsQuietHours` in SettingsNotificationsScreen.swift |
| matched | copy | `settings.notifications.quietHours.start` | “Start” (VERIFIED) |  | `Copy.…settingsNotificationsQuietHoursStart` in SettingsNotificationsScreen.swift |
| matched | copy | `settings.notifications.quietHours.end` | “End” (VERIFIED) |  | `Copy.…settingsNotificationsQuietHoursEnd` in SettingsNotificationsScreen.swift |
| matched | copy | `settings.notifications.quietHours.footer` | “Notifications arrive silently between these times.” (VERIFIED) |  | `Copy.…settingsNotificationsQuietHoursFooter` in SettingsNotificationsScreen.swift |
| matched | copy | `settings.notifications.liveActivity` | “Live Activity” (VERIFIED) |  | `Copy.…settingsNotificationsLiveActivity` in SettingsNotificationsScreen.swift |
| matched | copy | `settings.notifications.liveActivity.footer` | “Shows the daily invitation on your Lock Screen while it’s open.” (VERIFIED) |  | `Copy.…settingsNotificationsLiveActivityFooter` in SettingsNotificationsScreen.swift |
| n/a | copy | `settings.notifications.categories` | “Notification Categories” (VERIFIED) |  | Android only |
| matched | copy | `settings.notifications.error` | “Your change didn’t save. Check your connection and try again.” (VERIFIED) |  | `Copy.…settingsNotificationsError` in SettingsNotificationsModel.swift |

## Approximations

- Quiet-hours pickers start at the saved times or the current time; saved only when the two times differ.

## Not matched

- `settings.notifications.off.footer` — BLOCKED copy (uses {app_name}): DEBUG builds only (`AccountBlockedCopy.notificationsOffFooter`)

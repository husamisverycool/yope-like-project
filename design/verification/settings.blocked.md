# Verification — `settings.blocked` (iOS)

Blocked people — `Features/Account/Settings/SettingsBlockedScreen.swift`.

Checklist written from the spec (`design/surfaces/settings.blocked.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/settings.blocked.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Snapshots (CI): `settings.blocked-loading.png`, `settings.blocked-empty.png`, `settings.blocked-loaded.png`, `settings.blocked-error.png`

**Summary: 13 matched · 0 approximated · 0 not matched (BLOCKED or not buildable) · 2 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | token | `settings.root.layout.list` | ios: List with .listStyle(.insetGrouped); Section(header:footer:); NavigationLink rows show the system disclosure indicator; colours color.global.system.ios;… (PLATFORM) | settings list container (also settings.notifications, settings.account, settings.blocked, groups.settings) | List with .insetGrouped style, system rows |
| n/a | token | `settings.root.size.listItemAvatar.android` | 40 dp (VERIFIED) | M3 list item leading avatar size (blocked people, members) | Android only |
| matched | token | `settings.blocked.layout.empty` | ios: ContentUnavailableView(title, systemImage: nil, description); android: centred Column: headline in MaterialTheme.typography.bodyLarge, color.global.syst… (PLATFORM) | empty state of the blocked list | ContentUnavailableView(title, description), no image |
| matched | copy | `settings.blocked.title` | “Blocked People” (VERIFIED) |  | `Copy.…settingsBlockedTitle` in SettingsBlockedScreen.swift |
| matched | token | `size.global.avatarPicker` | 40 pt (SOURCED) | avatar in a people-picker row | `Tokens.…globalAvatarPicker` in SettingsBlockedScreen.swift |
| matched | token | `color.global.controlRaised` | #434343 (SOURCED) | raised fill: selected tab pill, inner pill inside the header capsule, inactive page dots | `Tokens.…globalControlRaised` in FloatingTabBar.swift, StorageImage.swift |
| matched | token | `icon.global.person` | ios: person.fill; android: Rounded.Person (PLATFORM) | default avatar silhouette | `Tokens.…globalPerson` in FloatingTabBar.swift, StorageImage.swift |
| matched | copy | `settings.blocked.unknown` | “Someone you blocked” (VERIFIED) |  | `Copy.…settingsBlockedUnknown` in SettingsBlockedModel.swift |
| matched | copy | `settings.blocked.unblock` | “Unblock” (VERIFIED) |  | `Copy.…settingsBlockedUnblock` in SettingsBlockedScreen.swift |
| n/a | token | `color.global.system.primary` | #D0BCFF (PLATFORM) | dialog action labels, switches, selected controls (role md.sys.color.primary, baseline dark scheme) | Android only |
| matched | copy | `settings.blocked.empty.title` | “No Blocked People” (VERIFIED) |  | `Copy.…settingsBlockedEmptyTitle` in SettingsBlockedScreen.swift |
| matched | copy | `settings.blocked.empty.message` | “When you block someone, you won’t see each other’s photos, messages or reactions in any group you share.” (VERIFIED) |  | `Copy.…settingsBlockedEmptyMessage` in SettingsBlockedScreen.swift |
| matched | copy | `settings.blocked.error` | “The list didn’t load. Check your connection and try again.” (VERIFIED) |  | `Copy.…settingsBlockedError` in SettingsBlockedScreen.swift |
| matched | copy | `settings.blocked.retry` | “Try Again” (VERIFIED) |  | `Copy.…settingsBlockedRetry` in SettingsBlockedScreen.swift |
| matched | token | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | any task completed successfully (same generator as send) | `Tokens.…globalSuccess` in SettingsBlockedScreen.swift |

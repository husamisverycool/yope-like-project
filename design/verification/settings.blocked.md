# Verification — `settings.blocked` (iOS, Pass 4 — Retro redesign)

Blocked people — `Features/Account/Settings/SettingsBlockedScreen.swift`, `SettingsBlockedModel.swift`.

Checklist written from the spec (`design/surfaces/settings.blocked.md`) against the iOS code: every token and copy key the spec names, its reference value, and where the iOS code uses it. The snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (AccountSnapshotTests: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/settings.blocked.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/press/tc-2023-07-retro-1b.webp`, `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`, `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png`

Snapshots (CI, `ios/build/snapshots/account/`): `settings.blocked-loading-light.png`, `settings.blocked-empty-light.png`, `settings.blocked-default-light.png`, `settings.blocked-default-dark.png`, `settings.blocked-error-light.png`

**Summary: 14 matched · 0 approximated · 0 not matched · 2 not applicable on iOS / owner / another pass.**


## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `settings.blocked.title` | “Blocked People” (SOURCED) | `Copy.settingsBlockedTitle` in SettingsBlockedScreen.swift |
| matched | `size.global.avatarPicker` | 37 pt (SOURCED) | `Tokens.Sizes.globalAvatarPicker` in GroupScreen.swift, GroupSettingsScreen.swift, PeopleRow.swift, SettingsBlockedScreen.swift |
| matched | `icon.global.person` | ios: person.fill; android: Rounded.Person (PLATFORM) | `Tokens.Icons.globalPerson` in Avatar.swift, SettingsBlockedScreen.swift |
| matched | `settings.blocked.unknown` | “Someone you blocked” (SOURCED) | `Copy.settingsBlockedUnknown` in SettingsBlockedModel.swift |
| matched | `color.global.textSecondary` | #999999 (SOURCED) | `Tokens.Colors.globalTextSecondary` in AccountGroupedRows.swift, Avatar.swift, CheckRow.swift, CodeScreen.swift … |
| matched | `settings.blocked.unblock` | “Unblock” (SOURCED) | `Copy.settingsBlockedUnblock` in SettingsBlockedScreen.swift |
| matched | `size.global.pillHeight` | 37 pt (SOURCED) | `Tokens.Sizes.globalPillHeight` in CapsuleButton.swift, LightPill.swift, OutlineCTA.swift |
| matched | `settings.root.size.rowHeight` | 58.7 pt (SOURCED) | `Tokens.Sizes.settingsRootSizeRowHeight` in AccountGroupedRows.swift |

## Elements

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `safety.block.undone` | “Unblocked {first_name}” (SOURCED) | `Copy.safetyBlockUndone` in SettingsBlockedScreen.swift |

## States

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `settings.blocked.empty.title` | “No blocked people” (SOURCED) | `Copy.settingsBlockedEmptyTitle` in SettingsBlockedScreen.swift |
| matched | `settings.blocked.error` | “Error loading blocked people. Tap here to try again.” (SOURCED) | `Copy.settingsBlockedError` in SettingsBlockedScreen.swift |
| matched | `safety.block.error` | “There was a problem. Please try again.” (SOURCED) | `Copy.safetyBlockError` in BlockConfirmation.swift, SettingsBlockedScreen.swift |

## Motion

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `duration.global.fade` | 150 ms (SOURCED) | `Tokens.Durations.globalFade` in ComponentSupport.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, PaywallScreen.swift … |

## Haptics

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | Android only — iOS presses play no haptic |
| matched | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | `Tokens.Haptics.globalSuccess` in AgeGateForm.swift, CodeScreen.swift, GroupCreateScreen.swift, InviteClipApp.swift … |

## Platform notes

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `color.global.surfaceSecondary.android` | light: #F7F7F7; dark: #262626 (SOURCED) | Android only |

# Verification — `settings.root` (iOS, Pass 4 — Retro redesign)

Settings sheet — `Features/Account/Settings/SettingsRootScreen.swift`, `Shared/AccountGroupedRows.swift`, `Settings/SystemPermissions.swift`.

Checklist written from the spec (`design/surfaces/settings.root.md`) against the iOS code: every token and copy key the spec names, its reference value, and where the iOS code uses it. The snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (AccountSnapshotTests: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/settings.root.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png`, `references/auto/retro/press/tc-2024-04-retro-journals-5.png`, `references/auto/retro/store/retro-store-02.png`, `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`

Snapshots (CI, `ios/build/snapshots/account/`): `settings.root-default-light.png`, `settings.root-default-dark.png`, `settings.root-subscription-loading-light.png`, `settings.root-subscriber-light.png`, `settings.root-permissions-denied-light.png`

**Summary: 35 matched · 1 approximated · 0 not matched · 2 not applicable on iOS / owner / another pass.**


## References

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `settings.root.size.rowHeight` | 58.7 pt (SOURCED) | `Tokens.Sizes.settingsRootSizeRowHeight` in AccountGroupedRows.swift |

## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| approximated | `settings.root.layout.list` | component: design/components.md C-14 on both platforms (custom rows; not List(.insetGrouped) / M3 ListItem); sheet: page sheet (C-29) with its own navigation… (SOURCED) | `SettingsList` / `SettingsGroup` / `SettingsRow` (AccountGroupedRows.swift): grouped rows on `color.global.background`, headers and footers — local C-14 variant (`SettingsRow`): row height is the platform's list row, not a measured token |
| matched | `settings.root.title` | “Settings” (SOURCED) | `Copy.settingsRootTitle` in SettingsRootScreen.swift |
| matched | `settings.root.close.accessibilityLabel` | “Close” (VERIFIED) | `Copy.settingsRootCloseAccessibilityLabel` in SettingsRootScreen.swift |
| matched | `color.global.textSecondary` | #999999 (SOURCED) | `Tokens.Colors.globalTextSecondary` in AccountGroupedRows.swift, Avatar.swift, CheckRow.swift, CodeScreen.swift … |
| matched | `size.global.avatarProfile` | 64 pt (SOURCED) | `Tokens.Sizes.globalAvatarProfile` in ProfileHeader.swift, SettingsAccountScreen.swift, SettingsRootScreen.swift |
| matched | `settings.root.account` | “Edit Profile” (SOURCED) | `Copy.settingsRootAccount` in SettingsRootScreen.swift |
| matched | `settings.root.subscription.header` | “Subscription” (SOURCED) | `Copy.settingsRootSubscriptionHeader` in SettingsRootScreen.swift |
| matched | `settings.root.premium.title` | “{app_name} Premium” (SOURCED) | `AccountBlockedCopy.premiumRowTitle` (BLOCKED {app_name}: release omits the row) |
| matched | `settings.root.premium.subtitle` | “Unlock more of what you love.” (SOURCED) | `Copy.settingsRootPremiumSubtitle` in SettingsRootScreen.swift |
| matched | `settings.root.manageSubscription` | “Your Subscription” (SOURCED) | `Copy.settingsRootManageSubscription` in SettingsRootScreen.swift |
| matched | `settings.root.premium.annual` | “Annual” (SOURCED) | `SettingsRootScreen.periodText` under "Your Subscription" from `PurchasesProviding.activePeriod()` (StoreKit current entitlements) — `Copy.settingsRootPremiumAnnual` in SettingsRootScreen.swift |
| matched | `settings.account.layout.manageSubscription` | ios: AppStore.showManageSubscriptions(in:) (manageSubscriptionsSheet); android: open https://play.google.com/store/account/subscriptions?sku={productId}&pack… (VERIFIED) | `.manageSubscriptionsSheet(isPresented:)` (StoreKit) |
| matched | `settings.root.notifications.header` | “Notifications” (SOURCED) | `Copy.settingsRootNotificationsHeader` in SettingsRootScreen.swift |
| matched | `settings.root.notifications` | “Notification Settings” (SOURCED) | `Copy.settingsRootNotifications` in SettingsRootScreen.swift |
| matched | `settings.root.widgets.header` | “Widgets” (SOURCED) | `Copy.settingsRootWidgetsHeader` in SettingsRootScreen.swift |
| matched | `settings.root.widgets.add` | “Add Widget” (SOURCED) | `Copy.settingsRootWidgetsAdd` in SettingsRootScreen.swift |
| matched | `settings.root.widgets.detail` | “See photos from your groups on your home screen” (SOURCED) | `Copy.settingsRootWidgetsDetail` in SettingsRootScreen.swift |
| matched | `settings.root.privacy.header` | “Privacy” (SOURCED) | `Copy.settingsRootPrivacyHeader` in SettingsRootScreen.swift |
| matched | `settings.root.blocked` | “Blocked People” (SOURCED) | `Copy.settingsRootBlocked` in SettingsRootScreen.swift |
| matched | `settings.root.permissions.header` | “System Permissions” (SOURCED) | `Copy.settingsRootPermissionsHeader` in SettingsRootScreen.swift |
| matched | `settings.root.permissions.camera` | “Camera” (SOURCED) | `Copy.settingsRootPermissionsCamera` in SystemPermissions.swift |
| matched | `settings.root.permissions.denied` | “Denied” (SOURCED) | `Copy.settingsRootPermissionsDenied` in SettingsRootScreen.swift |
| matched | `settings.root.about.header` | “About” (SOURCED) | `Copy.settingsRootAboutHeader` in SettingsRootScreen.swift |
| matched | `settings.root.contact` | “Contact Us” (SOURCED) | `Copy.settingsRootContact` in SettingsRootScreen.swift |
| matched | `settings.root.privacy` | “Privacy Policy” (SOURCED) | `Copy.settingsRootPrivacy` in SettingsRootScreen.swift |
| matched | `settings.root.terms` | “Terms of Use” (VERIFIED) | `Copy.settingsRootTerms` in SettingsRootScreen.swift |
| matched | `settings.root.version` | “Version” (SOURCED) | `Copy.settingsRootVersion` in SettingsRootScreen.swift |
| matched | `settings.root.signOut` | “Sign Out” (SOURCED) | `Copy.settingsRootSignOut` in SettingsRootScreen.swift |
| matched | `color.global.textPrimary` | light: #000000; dark: #FFFFFF (SOURCED) | `Tokens.Colors.globalTextPrimary` in AccountGroupedRows.swift, CapsuleButton.swift, CheckRow.swift, CircleButton.swift … |
| matched | `size.global.sectionGap` | 36.4 pt (SOURCED) | `Tokens.Sizes.globalSectionGap` in AccountGroupedRows.swift, GroupInviteScreen.swift, GroupScreen.swift, GroupsHomeScreen.swift … |

## Elements

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `icon.global.chevron` | ios: chevron.right; android: AutoMirrored.Rounded.KeyboardArrowRight (PLATFORM) | `Tokens.Icons.globalChevron` in AccountGroupedRows.swift, GroupScreen.swift, GroupedSection.swift, SettingsAccountScreen.swift |
| matched | `settings.root.signOut.title` | “Sign out?” (SOURCED) | `Copy.settingsRootSignOutTitle` in SettingsRootScreen.swift |
| matched | `settings.root.alert.cancel` | “Cancel” (VERIFIED) | `Copy.settingsRootAlertCancel` in SettingsRootScreen.swift |

## Motion

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `spring.global.sheetPresent` | response: 0.347; dampingFraction: 1 (SOURCED) | system sheet presentation (`.sheet`) |
| matched | `duration.global.sheetPresent` | 567 ms (SOURCED) | system sheet presentation (`.sheet`) |

## Haptics

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | Android only — iOS presses play no haptic |

## Platform notes

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `color.global.surfaceSecondary.android` | light: #F7F7F7; dark: #262626 (SOURCED) | Android only |

## Notes

- C-14 rows are the local `SettingsRow` / `SettingsGroup` (row height, value and custom rows are not in the C-14 API — component gap).

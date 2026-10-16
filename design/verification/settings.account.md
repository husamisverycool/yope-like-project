# Verification — `settings.account` (iOS, Pass 4 — Retro redesign)

Account settings and Edit Full Name — `Features/Account/Settings/SettingsAccountScreen.swift` (`SettingsAccountView`, `SettingsNameView`), `SettingsAccountModel.swift`.

Checklist written from the spec (`design/surfaces/settings.account.md`) against the iOS code: every token and copy key the spec names, its reference value, and where the iOS code uses it. The snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (AccountSnapshotTests: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/settings.account.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png`, `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`, `references/auto/retro/press/tc-2024-04-retro-journals-5.png`

Snapshots (CI, `ios/build/snapshots/account/`): `settings.account-default-light.png`, `settings.account-default-dark.png`, `settings.account-edit-name-light.png`, `settings.account-edit-name-too-long-light.png`, `settings.account-deleting-light.png`

**Summary: 28 matched · 0 approximated · 0 not matched · 1 not applicable on iOS / owner / another pass.**


## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `settings.root.size.rowHeight` | 58.7 pt (SOURCED) | `Tokens.Sizes.settingsRootSizeRowHeight` in AccountGroupedRows.swift |
| matched | `settings.root.layout.list` | component: design/components.md C-14 on both platforms (custom rows; not List(.insetGrouped) / M3 ListItem); sheet: page sheet (C-29) with its own navigation… (SOURCED) | `SettingsList` / `SettingsGroup` / `SettingsRow` (AccountGroupedRows.swift): grouped rows on `color.global.background`, headers and footers |
| matched | `settings.account.title` | “Account” (SOURCED) | `Copy.settingsAccountTitle` in SettingsAccountScreen.swift |
| matched | `size.global.avatarProfile` | 64 pt (SOURCED) | `Tokens.Sizes.globalAvatarProfile` in ProfileHeader.swift, SettingsAccountScreen.swift, SettingsRootScreen.swift |
| matched | `settings.account.photo` | “Profile Photo” (SOURCED) | `Copy.settingsAccountPhoto` in SettingsAccountScreen.swift |
| matched | `settings.account.photo.sheetTitle` | “Edit Profile Photo” (SOURCED) | `Copy.settingsAccountPhotoSheetTitle` in SettingsAccountScreen.swift |
| matched | `settings.account.photo.library` | “Choose from Library” (SOURCED) | `Copy.settingsAccountPhotoLibrary` in SettingsAccountScreen.swift |
| matched | `settings.account.name` | “Full Name” (SOURCED) | `Copy.settingsAccountName` in SettingsAccountScreen.swift |
| matched | `settings.account.phone` | “Phone Number” (SOURCED) | `Copy.settingsAccountPhone` in SettingsAccountScreen.swift |
| matched | `settings.account.birthday` | “Birthday” (SOURCED) | `Copy.settingsAccountBirthday` in SettingsAccountScreen.swift |
| matched | `settings.account.delete` | “Delete Account” (SOURCED) | `Copy.settingsAccountDelete` in SettingsAccountScreen.swift |
| matched | `color.global.destructive` | #EA3337 (SOURCED) | `Tokens.Colors.globalDestructive` in AccountGroupedRows.swift, DestructiveButton.swift, FormField.swift, GroupInviteScreen.swift … |
| matched | `settings.account.delete.footer` | “Deleting your account removes your photos, voice notes and messages from every group.” (SOURCED) | `Copy.settingsAccountDeleteFooter` in SettingsAccountScreen.swift |
| matched | `settings.account.name.title` | “Edit Full Name” (SOURCED) | `Copy.settingsAccountNameTitle` in SettingsAccountScreen.swift |
| matched | `size.global.titleToContent` | 30 pt (SOURCED) | `Tokens.Sizes.globalTitleToContent` in AccountGroupedRows.swift, AgeGateForm.swift, GroupCreateScreen.swift, GroupInviteScreen.swift … |
| matched | `settings.account.name.tooLong` | “Name too long” (SOURCED) | `Copy.settingsAccountNameTooLong` in SettingsAccountScreen.swift |
| matched | `settings.account.name.save` | “Save” (SOURCED) | `Copy.settingsAccountNameSave` in SettingsAccountScreen.swift |

## Elements

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `settings.account.alert.cancel` | “Cancel” (VERIFIED) | `Copy.settingsAccountAlertCancel` in SettingsAccountScreen.swift |
| matched | `settings.account.deleted.toast` | “Account deleted” (SOURCED) | `Copy.settingsAccountDeletedToast` in AccountSession.swift |
| matched | `settings.account.layout.manageSubscription` | ios: AppStore.showManageSubscriptions(in:) (manageSubscriptionsSheet); android: open https://play.google.com/store/account/subscriptions?sku={productId}&pack… (VERIFIED) | `.manageSubscriptionsSheet(isPresented:)` (StoreKit) |

## States

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `settings.account.name.error` | “There was a problem saving your changes. Please try again.” (SOURCED) | `Copy.settingsAccountNameError` in SettingsAccountModel.swift |
| matched | `auth.phone.error.dismiss` | “OK” (VERIFIED) | `Copy.authPhoneErrorDismiss` in CodeScreen.swift, FormErrorAlert.swift, ReportFlow.swift |
| matched | `settings.account.delete.error` | “Your account wasn't deleted. Please try again.” (SOURCED) | `Copy.settingsAccountDeleteError` in SettingsAccountModel.swift |

## Motion

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `duration.global.crossfade` | 100 ms (SOURCED) | `Tokens.Durations.globalCrossfade` in AgeGateForm.swift, ComponentSupport.swift |

## Haptics

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | Android only — iOS presses play no haptic |
| matched | `haptic.global.warning` | ios: notification.warning; android: CONFIRM (PLATFORM) | `Tokens.Haptics.globalWarning` in BlockConfirmation.swift, GroupInviteScreen.swift, GroupSettingsScreen.swift, ReportFlow.swift … |
| matched | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | `Tokens.Haptics.globalSuccess` in AgeGateForm.swift, CodeScreen.swift, GroupCreateScreen.swift, InviteClipApp.swift … |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | `Tokens.Haptics.globalError` in AgeGateForm.swift, BlockConfirmation.swift, CodeScreen.swift, GroupCreateScreen.swift … |

## Platform notes

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `settings.account.layout.alert` | ios: alert(_:isPresented:actions:message:): destructive-role button + Cancel; at most 3 buttons; Cancel is never the default; android: M3 AlertDialog: contai… (VERIFIED) | native `.alert` / `.confirmationDialog` (C-29) |

## Notes

- Birthday row pushes birthday.add (memory pass) inside the Settings sheet.

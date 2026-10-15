# Verification — `settings.account` (iOS)

Account and deletion — `Features/Account/Settings/SettingsAccountScreen.swift`.

Checklist written from the spec (`design/surfaces/settings.account.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/settings.account.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Snapshots (CI): `settings.account-default.png`, `settings.account-premium.png`

**Summary: 23 matched · 0 approximated · 0 not matched (BLOCKED or not buildable) · 1 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | token | `settings.root.layout.list` | ios: List with .listStyle(.insetGrouped); Section(header:footer:); NavigationLink rows show the system disclosure indicator; colours color.global.system.ios;… (PLATFORM) | settings list container (also settings.notifications, settings.account, settings.blocked, groups.settings) | List with .insetGrouped style, system rows |
| matched | copy | `settings.account.title` | “Account” (VERIFIED) |  | `Copy.…settingsAccountTitle` in SettingsAccountScreen.swift |
| matched | copy | `settings.account.name` | “Name” (VERIFIED) |  | `Copy.…settingsAccountName` in SettingsAccountScreen.swift |
| matched | copy | `settings.account.photo` | “Photo” (VERIFIED) |  | `Copy.…settingsAccountPhoto` in SettingsAccountScreen.swift |
| matched | token | `auth.profile.layout.avatarPicker` | ios: PhotosPicker (SwiftUI) / PHPickerViewController, single image, no library permission; android: ActivityResultContracts.PickVisualMedia(ImageOnly), no RE… (PLATFORM) | avatar picker | PhotosPicker (single image, no library permission); empty circle controlRaised + person glyph |
| matched | copy | `settings.account.phone` | “Phone Number” (VERIFIED) |  | `Copy.…settingsAccountPhone` in SettingsAccountScreen.swift |
| matched | copy | `settings.account.birthday` | “Birthday” (VERIFIED) |  | `Copy.…settingsAccountBirthday` in SettingsAccountScreen.swift |
| matched | copy | `settings.root.manageSubscription` | “Manage Subscription” (VERIFIED) |  | `Copy.…settingsRootManageSubscription` in SettingsAccountScreen.swift |
| matched | token | `settings.account.layout.manageSubscription` | ios: AppStore.showManageSubscriptions(in:) (manageSubscriptionsSheet); android: open https://play.google.com/store/account/subscriptions?sku={productId}&pack… (VERIFIED) | 'Manage Subscription' destination | .manageSubscriptionsSheet(isPresented:) |
| matched | copy | `settings.account.delete` | “Delete Account” (VERIFIED) |  | `Copy.…settingsAccountDelete` in SettingsAccountScreen.swift |
| matched | copy | `settings.account.delete.footer` | “Deleting your account removes your photos, voice notes and messages from every group.” (VERIFIED) |  | `Copy.…settingsAccountDeleteFooter` in SettingsAccountScreen.swift |
| matched | token | `settings.account.layout.alert` | ios: alert(_:isPresented:actions:message:): destructive-role button + Cancel; at most 3 buttons; Cancel is never the default; Cancel on the leading side; and… (VERIFIED) | confirmation alerts / dialogs (delete account; also leave group, remove member, block, turn off link) | iOS .alert / .confirmationDialog (system); the M3 dialog half is Android |
| matched | copy | `settings.account.delete.title` | “Delete your account?” (VERIFIED) |  | `Copy.…settingsAccountDeleteTitle` in SettingsAccountScreen.swift |
| matched | copy | `settings.account.delete.message` | “This deletes your account and everything you shared with your groups, including photos, voice notes and messages. It can’t be undone.” (VERIFIED) |  | `Copy.…settingsAccountDeleteMessage` in SettingsAccountScreen.swift |
| matched | copy | `settings.account.delete.subscriptionNote` | “Your subscription keeps renewing until you cancel it in your subscription settings.” (VERIFIED) |  | `Copy.…settingsAccountDeleteSubscriptionNote` in SettingsAccountScreen.swift |
| matched | copy | `settings.account.alert.cancel` | “Cancel” (VERIFIED) |  | `Copy.…settingsAccountAlertCancel` in SettingsAccountScreen.swift |
| matched | copy | `settings.account.delete.confirm` | “Delete” (VERIFIED) |  | `Copy.…settingsAccountDeleteConfirm` in SettingsAccountScreen.swift |
| matched | copy | `settings.account.deleted.toast` | “your account was deleted” (SOURCED) |  | `Copy.…settingsAccountDeletedToast` in AccountSession.swift |
| matched | token | `color.global.destructive` | #FF4245 (PLATFORM) | destructive actions on system surfaces (delete account, block, leave, report) — iOS systemRed via Button(ro… | role: .destructive (system red) |
| n/a | token | `color.global.system.error` | #F2B8B5 (PLATFORM) | error / destructive text and icons (role md.sys.color.error, baseline dark scheme) | Android only |
| matched | copy | `settings.account.delete.error` | “Your account wasn’t deleted. Check your connection and try again.” (VERIFIED) |  | `Copy.…settingsAccountDeleteError` in SettingsAccountScreen.swift |
| matched | copy | `settings.account.name.error` | “Your name didn’t save. Check your connection and try again.” (VERIFIED) |  | `Copy.…settingsAccountNameError` in SettingsAccountModel.swift |
| matched | token | `haptic.global.warning` | ios: notification.warning; android: CONFIRM (PLATFORM) | a destructive action was confirmed (delete account, block, leave) | `Tokens.…globalWarning` in BlockConfirmation.swift, SettingsAccountScreen.swift |
| matched | token | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | a task failed (send failed) | `Tokens.…globalError` in BlockConfirmation.swift, SettingsAccountScreen.swift |

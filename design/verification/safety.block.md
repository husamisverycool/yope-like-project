# Verification — `safety.block` (iOS)

Block confirmation and toast — `Components/BlockConfirmation.swift`, `Components/Toast.swift`.

Checklist written from the spec (`design/surfaces/safety.block.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/safety.block.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Snapshots (CI): `safety.block-toast.png`

**Summary: 23 matched · 1 approximated · 0 not matched (BLOCKED or not buildable) · 2 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | token | `safety.block.layout.menu` | ios: Menu (UIMenu) item with role .destructive; android: DropdownMenu item (M3 baseline: 48 dp items, 4 dp container corner, labelLarge) in color.global.syst… (VERIFIED) | 'Block' / 'Report…' items in overflow menus | Menu item with role .destructive |
| matched | token | `safety.block.layout.confirm` | ios: confirmationDialog(titleVisibility: .visible) with message; 'Block' role .destructive at the top, Cancel at the bottom; android: M3 AlertDialog (setting… (VERIFIED) | block confirmation | `.blockConfirmation` → confirmationDialog(titleVisibility: .visible), destructive Block, Cancel |
| matched | token | `safety.block.layout.toast` | fill: color.global.accent; content: icon.global.checkmark + label in color.global.onAccent, text role button; shape: radius.global.capsule, full width minus … (SOURCED) | confirmation toast after block / unblock / report (Yope lime toast) | `ToastView` / `.toastHost` (Components/Toast.swift): accent fill, checkmark + label onAccent, capsule, screenMargin, top |
| matched | token | `safety.block.duration.toast` | 2000 ms (SOURCED) | how long the lime toast stays before it leaves | `Tokens.…safetyBlockDurationToast` in Toast.swift |
| matched | token | `settings.account.layout.alert` | ios: alert(_:isPresented:actions:message:): destructive-role button + Cancel; at most 3 buttons; Cancel is never the default; Cancel on the leading side; and… (VERIFIED) | confirmation alerts / dialogs (delete account; also leave group, remove member, block, turn off link) | iOS .alert / .confirmationDialog (system); the M3 dialog half is Android |
| matched | copy | `groups.screen.photo.menu.block` | “Block {first_name}” (VERIFIED) |  | `Copy.…groupsScreenPhotoMenuBlock` in GroupScreen.swift |
| matched | copy | `groups.settings.members.menu.block` | “Block” (VERIFIED) |  | `Copy.…groupsSettingsMembersMenuBlock` in GroupSettingsScreen.swift |
| matched | copy | `safety.report.sent.block` | “Block” (VERIFIED) |  | `Copy.…safetyReportSentBlock` in ReportSheet.swift |
| n/a | copy | `safety.block.menuItemNamed` | “Block {first_name}” (VERIFIED) |  | placed by photo.viewer / chat.thread / walls.member (other passes) |
| n/a | copy | `safety.block.menuItem` | “Block” (VERIFIED) |  | placed by photo.viewer / chat.thread / walls.member (other passes) |
| matched | copy | `settings.blocked.unblock` | “Unblock” (VERIFIED) |  | `Copy.…settingsBlockedUnblock` in SettingsBlockedScreen.swift |
| matched | copy | `safety.block.title` | “block {first_name}?” (SOURCED) |  | `Copy.…safetyBlockTitle` in BlockConfirmation.swift |
| matched | copy | `safety.block.message` | “you won’t see each other’s pics, messages or reactions in any group you share. {first_name} won’t be notified.” (SOURCED) |  | `Copy.…safetyBlockMessage` in BlockConfirmation.swift |
| matched | copy | `safety.block.confirm` | “Block” (VERIFIED) |  | `Copy.…safetyBlockConfirm` in BlockConfirmation.swift |
| matched | copy | `safety.block.cancel` | “Cancel” (VERIFIED) |  | `Copy.…safetyBlockCancel` in BlockConfirmation.swift |
| matched | copy | `safety.block.done` | “you blocked {first_name}” (SOURCED) |  | `Copy.…safetyBlockDone` in BlockConfirmation.swift |
| matched | token | `color.global.accent` | #CDFD07 (SOURCED) | brand lime: composer camera button, primary buttons, coach tooltips, toasts, shutter ring, 'today' bar | `Tokens.…globalAccent` in OnboardingTitle.swift, PrimaryButton.swift, Toast.swift |
| matched | token | `icon.global.checkmark` | ios: checkmark; android: Rounded.Check (PLATFORM) | done / posted (bare check, e.g. in the 'posted in the wall' toast) | `Tokens.…globalCheckmark` in Toast.swift |
| matched | token | `color.global.onAccent` | #000000 (SOURCED) | text and glyphs on lime: camera glyph on the composer button, primary button labels, tooltip text | `Tokens.…globalOnAccent` in PrimaryButton.swift, Toast.swift |
| matched | token | `radius.global.capsule` | shape: capsule; radius: height / 2 (SOURCED) | full pill: header title capsule, composer text field, chat bubbles, tab-bar capsule, tooltip ends, white se… | Capsule() shape |
| matched | token | `size.global.screenMargin` | 12 pt (SOURCED) | side margin of full-width content (home list cards); edge elements sit at the same inset | `Tokens.…globalScreenMargin` in EmptyStateView.swift, Toast.swift |
| matched | copy | `safety.block.undone` | “you unblocked {first_name}” (SOURCED) |  | `Copy.…safetyBlockUndone` in SettingsBlockedScreen.swift |
| matched | copy | `safety.block.error` | “that didn’t work. check your connection and try again.” (SOURCED) |  | `Copy.…safetyBlockError` in BlockConfirmation.swift |
| matched | token | `haptic.global.warning` | ios: notification.warning; android: CONFIRM (PLATFORM) | a destructive action was confirmed (delete account, block, leave) | `Tokens.…globalWarning` in BlockConfirmation.swift, GroupSettingsScreen.swift |
| matched | token | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | a task failed (send failed) | `Tokens.…globalError` in BlockConfirmation.swift, GroupSettingsScreen.swift, ReportSheet.swift |

## Approximations

- Toast entrance: `spring.global.platformDefault.ios` (the measured ≈117 ms entrance has no curve); exit not observed → same spring.

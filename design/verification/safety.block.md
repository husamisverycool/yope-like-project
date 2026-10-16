# Verification — `safety.block` (iOS, Pass 4 — Retro redesign)

Block confirmation — C-29 `blockConfirmation` (Components/BlockConfirmation.swift) used by ReportFlow.swift and the hosting surfaces.

Checklist written from the spec (`design/surfaces/safety.block.md`) against the iOS code: every token and copy key the spec names, its reference value, and where the iOS code uses it. The snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (AccountSnapshotTests: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/safety.block.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`, `references/auto/retro/press/tc-2025-12-rewind-panels.png`

Snapshots (CI, `ios/build/snapshots/account/`): none (system UI)

**Summary: 13 matched · 0 approximated · 0 not matched · 5 not applicable on iOS / owner / another pass.**


## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `safety.block.layout.menu` | ios: Menu (UIMenu) item with role .destructive; android: DropdownMenu item (M3 baseline: 48 dp items, labelLarge) in color.global.destructive (VERIFIED) | menu item placed by the hosting surface (photo.viewer, chat.thread, walls.member — social pass); groups.screen's own context menu uses `safety.report.title` items |
| matched | `safety.block.layout.confirm` | ios: confirmationDialog(titleVisibility: .visible) with message; 'Yes, block' role .destructive at the top, Cancel at the bottom; android: M3 AlertDialog (se… (VERIFIED) | `blockConfirmation(target:toasts:perform:)` (C-29 alert with the destructive Block) |
| matched | `settings.account.layout.alert` | ios: alert(_:isPresented:actions:message:): destructive-role button + Cancel; at most 3 buttons; Cancel is never the default; android: M3 AlertDialog: contai… (VERIFIED) | native `.alert` / `.confirmationDialog` (C-29) |
| n/a | `safety.block.menuItem` | “Block Profile” (SOURCED) | menu item placed by the hosting surface (photo.viewer, chat.thread, walls.member — social pass); groups.screen's own context menu uses `safety.report.title` items |
| n/a | `safety.block.menuItemNamed` | “Block {first_name}” (SOURCED) | menu item placed by the hosting surface (photo.viewer, chat.thread, walls.member — social pass); groups.screen's own context menu uses `safety.report.title` items |
| matched | `safety.block.title` | “Block {first_name}?” (SOURCED) | `Copy.safetyBlockTitle` in BlockConfirmation.swift |
| matched | `safety.block.message` | “Blocking {first_name} hides your photos, messages and reactions from each other in every group you share. They will not be notified.” (SOURCED) | `Copy.safetyBlockMessage` in BlockConfirmation.swift |
| matched | `safety.block.confirm` | “Yes, block” (SOURCED) | `Copy.safetyBlockConfirm` in BlockConfirmation.swift |
| matched | `safety.block.cancel` | “Cancel” (VERIFIED) | `Copy.safetyBlockCancel` in BlockConfirmation.swift |
| matched | `safety.block.done` | “Blocked {first_name}” (SOURCED) | `Copy.safetyBlockDone` in BlockConfirmation.swift |

## Elements

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `safety.block.undone` | “Unblocked {first_name}” (SOURCED) | `Copy.safetyBlockUndone` in SettingsBlockedScreen.swift |

## States

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `auth.phone.layout.inlineError` | presentation: native alert: iOS SwiftUI .alert / Android M3 AlertDialog (settings.account.layout.alert); not dismissed by tapping outside; titled: code error… (SOURCED) | `formErrorAlert(_:trigger:)` (C-29 native message-only alert); code errors: titled alert with Retro's two recoveries |
| matched | `safety.block.error` | “There was a problem. Please try again.” (SOURCED) | `Copy.safetyBlockError` in BlockConfirmation.swift, SettingsBlockedScreen.swift |
| matched | `auth.phone.error.dismiss` | “OK” (VERIFIED) | `Copy.authPhoneErrorDismiss` in CodeScreen.swift, FormErrorAlert.swift, ReportFlow.swift |

## Motion · Haptics

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `haptic.global.warning` | ios: notification.warning; android: CONFIRM (PLATFORM) | `Tokens.Haptics.globalWarning` in BlockConfirmation.swift, GroupInviteScreen.swift, GroupSettingsScreen.swift, ReportFlow.swift … |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | `Tokens.Haptics.globalError` in AgeGateForm.swift, BlockConfirmation.swift, CodeScreen.swift, GroupCreateScreen.swift … |
| n/a | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | Android only — iOS presses play no haptic |

## Accessibility

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `color.global.system.surfaceContainerHigh` | light: #ECE6F0; dark: #2B2930 (PLATFORM) | Android M3 dialog container; iOS uses system alerts |

## Notes

- System alert: no snapshot. The confirmation is announced (C-26 iOS: no drawn toast).

# Verification — `safety.report` (iOS, Pass 4 — Retro redesign)

Report flow (native action sheets) — `Features/Account/Safety/ReportFlow.swift` (`reportFlow`, `ReportSheet`), `ReportModel.swift`; shell: `MainShell.reportFlow` for `.account(.report)`.

Checklist written from the spec (`design/surfaces/safety.report.md`) against the iOS code: every token and copy key the spec names, its reference value, and where the iOS code uses it. The snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (AccountSnapshotTests: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/safety.report.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`, `references/auto/retro/press/tc-2025-12-rewind-panels.png`

Snapshots (CI, `ios/build/snapshots/account/`): `safety.report-reasons-post-light.png`, `safety.report-reasons-post-dark.png`, `safety.report-reasons-person-light.png`

**Summary: 17 matched · 0 approximated · 0 not matched · 4 not applicable on iOS / owner / another pass.**


## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `safety.report.layout.flow` | entry: menu item 'Report Post' / 'Report Message' / 'Report Profile' / 'Report Group' (C-29 native menu); reasons: native action sheet (iOS confirmationDialo… (SOURCED) | `.reportFlow(target:dependencies:)` (ReportFlow.swift): `confirmationDialog` with the visible title, one button per reason, Cancel; "I don't like it" → Next Steps |
| matched | `safety.report.layout.reasons` | post: I don't like it · Nudity or sexual activity · Other; message: I don't like it · Nudity or sexual activity · Other; user: It's impersonating someone · I… (SOURCED) | `Tokens.Layouts.SafetyReportLayoutReasons` in ReportModel.swift |
| n/a | `safety.report.menuItem.post` | “Report Post” (SOURCED) | menu item placed by the hosting surface (photo.viewer, chat.thread, walls.member — social pass); groups.screen's own context menu uses `safety.report.title` items |
| matched | `groups.settings.report` | “Report Group” (SOURCED) | `Copy.groupsSettingsReport` in GroupSettingsScreen.swift |
| matched | `safety.report.cancel` | “Cancel” (VERIFIED) | `Copy.safetyReportCancel` in ReportFlow.swift |
| matched | `safety.report.sent.title` | “Submitted!” (SOURCED) | `Copy.safetyReportSentTitle` in ReportFlow.swift |
| matched | `safety.report.nextSteps.title` | “Next Steps” (SOURCED) | `Copy.safetyReportNextStepsTitle` in ReportFlow.swift |
| matched | `safety.report.nextSteps.leave` | “Leave the group” (SOURCED) | `Copy.safetyReportNextStepsLeave` in ReportFlow.swift |
| matched | `safety.report.nextSteps.block` | “Block {first_name}” (SOURCED) | `Copy.safetyReportNextStepsBlock` in ReportFlow.swift |
| matched | `safety.report.left` | “Left group” (SOURCED) | `Copy.safetyReportLeft` in ReportFlow.swift |

## Elements

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `safety.report.title.post` | “Why are you reporting this post?” (SOURCED) | `Copy.safetyReportTitlePost` in ReportModel.swift |

## States

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `auth.phone.layout.inlineError` | presentation: native alert: iOS SwiftUI .alert / Android M3 AlertDialog (settings.account.layout.alert); not dismissed by tapping outside; titled: code error… (SOURCED) | `formErrorAlert(_:trigger:)` (C-29 native message-only alert); code errors: titled alert with Retro's two recoveries |
| matched | `safety.report.error.title` | “Couldn't send report” (SOURCED) | `Copy.safetyReportErrorTitle` in ReportFlow.swift |
| matched | `safety.report.error.detail` | “There was a problem. Please try again.” (SOURCED) | `Copy.safetyReportErrorDetail` in ReportFlow.swift |
| matched | `auth.phone.error.dismiss` | “OK” (VERIFIED) | `Copy.authPhoneErrorDismiss` in CodeScreen.swift, FormErrorAlert.swift, ReportFlow.swift |
| matched | `safety.report.error.notFound` | “This is no longer available.” (SOURCED) | `Copy.safetyReportErrorNotFound` in ReportFlow.swift |

## Motion · Haptics

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | Android only — iOS presses play no haptic |
| matched | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | `Tokens.Haptics.globalSuccess` in AgeGateForm.swift, CodeScreen.swift, GroupCreateScreen.swift, InviteClipApp.swift … |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | `Tokens.Haptics.globalError` in AgeGateForm.swift, BlockConfirmation.swift, CodeScreen.swift, GroupCreateScreen.swift … |

## Platform notes

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `color.global.system.surfaceContainerLow` | light: #F7F2FA; dark: #1D1B20 (PLATFORM) | Android bottom sheet container; iOS uses action sheets |
| n/a | `radius.global.sheet` | ios: system; android: 28 (PLATFORM) | Android bottom sheet; iOS uses `confirmationDialog` |

## Notes

- Native action sheets are system UI: no snapshot; `ReportSheet` (the same reasons in sheet form) is recorded for review.

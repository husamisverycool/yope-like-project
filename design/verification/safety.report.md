# Verification — `safety.report` (iOS)

Report sheet — `Features/Account/Safety/ReportSheet.swift`.

Checklist written from the spec (`design/surfaces/safety.report.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/safety.report.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Snapshots (CI): `safety.report-form.png`, `safety.report-sent.png`, `safety.report-error.png`, `safety.report-not-found.png`

**Summary: 27 matched · 1 approximated · 2 not matched (BLOCKED or not buildable) · 3 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | token | `safety.report.layout.flow` | entry: a menu item 'Report…' (ellipsis: more input follows); ios: sheet with presentationDetents([.medium, .large]) and a visible grabber: title + explanatio… (VERIFIED) | report flow container | sheet [.medium, .large], visible grabber; title + explanation, optional details, Report (destructive) / Cancel in the navigation bar |
| not matched | token | `safety.report.layout.reasons` | None (BLOCKED) | list of report reasons shown before the details field | BLOCKED: omitted in release builds |
| matched | token | `safety.block.layout.menu` | ios: Menu (UIMenu) item with role .destructive; android: DropdownMenu item (M3 baseline: 48 dp items, 4 dp container corner, labelLarge) in color.global.syst… (VERIFIED) | 'Block' / 'Report…' items in overflow menus | Menu item with role .destructive |
| matched | token | `safety.block.layout.toast` | fill: color.global.accent; content: icon.global.checkmark + label in color.global.onAccent, text role button; shape: radius.global.capsule, full width minus … (SOURCED) | confirmation toast after block / unblock / report (Yope lime toast) | `ToastView` / `.toastHost` (Components/Toast.swift): accent fill, checkmark + label onAccent, capsule, screenMargin, top |
| matched | copy | `groups.screen.photo.menu.report` | “Report…” (VERIFIED) |  | photo card ••• menu (Screens/GroupScreen.swift) |
| matched | copy | `groups.screen.menu.report` | “report” (SOURCED) |  | profile ••• menu (GroupProfileScreen.swift) |
| matched | copy | `groups.settings.report` | “report” (SOURCED) |  | groups.settings list (GroupSettingsScreen.swift) |
| matched | copy | `groups.settings.members.menu.report` | “Report…” (VERIFIED) |  | member ••• menu (GroupSettingsScreen.swift) |
| n/a | copy | `safety.report.menuItem` | “Report…” (VERIFIED) |  | placed by photo.viewer / chat.thread / walls.member (other passes); account menus use their own keys |
| matched | copy | `safety.report.sent.block` | “Block” (VERIFIED) |  | `Copy.…safetyReportSentBlock` in ReportSheet.swift |
| matched | copy | `safety.report.cancel` | “Cancel” (VERIFIED) |  | `Copy.…safetyReportCancel` in ReportSheet.swift |
| matched | copy | `safety.report.submit` | “Report” (VERIFIED) |  | `Copy.…safetyReportSubmit` in ReportSheet.swift |
| matched | copy | `safety.report.title.post` | “report this pic” (SOURCED) |  | `Copy.…safetyReportTitlePost` in ReportModel.swift |
| matched | copy | `safety.report.title.message` | “report this message” (SOURCED) |  | `Copy.…safetyReportTitleMessage` in ReportModel.swift |
| matched | copy | `safety.report.title.user` | “report {first_name}” (SOURCED) |  | `Copy.…safetyReportTitleUser` in ReportModel.swift |
| matched | copy | `safety.report.title.group` | “report {group_name}” (SOURCED) |  | `Copy.…safetyReportTitleGroup` in ReportModel.swift |
| not matched | copy | `safety.report.explanation` | “reports go to the {app_name} team, not to the person you report.” (SOURCED) |  | uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (AccountBlockedCopy.swift); omitted in release |
| matched | copy | `safety.report.details.placeholder` | “add details (optional)” (SOURCED) |  | `Copy.…safetyReportDetailsPlaceholder` in ReportSheet.swift |
| matched | copy | `safety.report.sent.title` | “report sent” (SOURCED) |  | `Copy.…safetyReportSentTitle` in ReportSheet.swift |
| matched | copy | `safety.report.sent.message` | “thanks for telling us. you can also block {first_name} so you don’t see each other’s pics or messages.” (SOURCED) |  | `Copy.…safetyReportSentMessage` in ReportModel.swift |
| matched | copy | `safety.report.sent.messageGroup` | “thanks for telling us.” (SOURCED) |  | `Copy.…safetyReportSentMessageGroup` in ReportModel.swift |
| matched | copy | `safety.report.sent.done` | “Done” (VERIFIED) |  | `Copy.…safetyReportSentDone` in ReportSheet.swift |
| n/a | token | `color.global.system.surfaceContainerLow` | #1D1B20 (PLATFORM) | M3 modal bottom sheet container (role md.sys.color.surface-container-low, baseline dark scheme) | Android only |
| matched | token | `radius.global.sheet` | ios: system; android: 28 (PLATFORM) | sheet top corners (Yope's sheet radius was not measured) | system sheet corners (ios: system) |
| matched | token | `layout.global.system.typography` | ios: built-in text styles (Font.TextStyle) on native lists, alerts and sheets; android: MaterialTheme.typography (M3 baseline type scale: list label bodyLarg… (PLATFORM) | text styles on system surfaces | system text styles (no custom font on system surfaces) |
| n/a | token | `color.global.system.error` | #F2B8B5 (PLATFORM) | error / destructive text and icons (role md.sys.color.error, baseline dark scheme) | Android only |
| matched | copy | `safety.report.error.title` | “your report didn’t send” (SOURCED) |  | `Copy.…safetyReportErrorTitle` in ReportSheet.swift |
| matched | copy | `safety.report.error.detail` | “check your connection and try again. your details are still here.” (SOURCED) |  | `Copy.…safetyReportErrorDetail` in ReportSheet.swift |
| matched | copy | `safety.report.error.notFound` | “this is no longer here, so there’s nothing to report.” (SOURCED) |  | `Copy.…safetyReportErrorNotFound` in ReportSheet.swift |
| matched | token | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | any task completed successfully (same generator as send) | `Tokens.…globalSuccess` in ReportSheet.swift |
| matched | token | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | a task failed (send failed) | `Tokens.…globalError` in BlockConfirmation.swift, ReportSheet.swift |
| matched | token | `safety.block.duration.toast` | 2000 ms (SOURCED) | how long the lime toast stays before it leaves | `Tokens.…safetyBlockDurationToast` in Toast.swift |

## Approximations

- Reason list BLOCKED (owner categories): the sheet ships with the optional free-text details, the sourced presentation of MERGE G2-8; with categories, one single-select list above the details field (`DesignGaps.showsReportReasons`).

## Not matched

- `safety.report.layout.reasons` — BLOCKED: omitted in release builds
- `safety.report.explanation` — uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (AccountBlockedCopy.swift); omitted in release

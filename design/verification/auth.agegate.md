# Verification — `auth.agegate` (iOS, Pass 4 — Retro redesign)

Birthday / age gate — `Features/Account/Shared/AgeGateForm.swift` (`AgeGateForm`, `AgeGateRefusedScreen`), `Auth/AgeGateScreen.swift`, `Shared/AgeGateModel.swift`, `Shared/BirthdayEntry.swift`.

Checklist written from the spec (`design/surfaces/auth.agegate.md`) against the iOS code: every token and copy key the spec names, its reference value, and where the iOS code uses it. The snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (AccountSnapshotTests: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/auth.agegate.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png`, `references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png`, `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`

Snapshots (CI, `ios/build/snapshots/account/`): `auth.agegate-default-light.png`, `auth.agegate-default-dark.png`, `auth.agegate-filled-opt-in-light.png`, `auth.agegate-checking-light.png`, `auth.agegate-not-configured-light.png`, `auth.agegate-offline-light.png`, `auth.agegate-under-age-light.png`

**Summary: 34 matched · 0 approximated · 0 not matched · 3 not applicable on iOS / owner / another pass.**


## References

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `auth.agegate.layout.dateEntry` | control: C-12 text field (fill color.global.control, size.global.fieldHeight, radius.global.field, text role placeholder) with a numeric keyboard; format: th… (VERIFIED) | `BirthdayEntry`: the locale's numeric order as placeholder, digits only, separators inserted |

## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `color.global.background` | light: #FFFFFF; dark: #000000 (SOURCED) | `Tokens.Colors.globalBackground` in AccountGroupedRows.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, GroupScreen.swift … |
| matched | `auth.agegate.title` | “When's your birthday?” (SOURCED) | `Copy.authAgegateTitle` in AgeGateForm.swift |
| matched | `font.global.display` | ios: system-serif; android: serif (PLATFORM) | `Tokens.Fonts.globalDisplay` in InvitePreviewView.swift, PhoneScreen.swift, TextRoles.swift |
| matched | `size.global.titleTop` | 64 pt (SOURCED) | `Tokens.Sizes.globalTitleTop` in FullBleedMediaPage.swift, GroupScreen.swift, ScreenHeader.swift, SignUpLayout.swift |
| matched | `auth.agegate.subtitle` | “We use it to check your age. We don't save it.” (SOURCED) | `Copy.authAgegateSubtitle` in AgeGateForm.swift |
| matched | `color.global.textSecondary` | #999999 (SOURCED) | `Tokens.Colors.globalTextSecondary` in AccountGroupedRows.swift, Avatar.swift, CheckRow.swift, CodeScreen.swift … |
| matched | `size.global.titleToContent` | 30 pt (SOURCED) | `Tokens.Sizes.globalTitleToContent` in AccountGroupedRows.swift, AgeGateForm.swift, GroupCreateScreen.swift, GroupInviteScreen.swift … |
| matched | `auth.agegate.field.placeholder` | “{date_format}” (SOURCED) | `Copy.authAgegateFieldPlaceholder` in AgeGateModel.swift |
| matched | `auth.agegate.layout.optIn` | control: C-14 grouped section with a single row: title (text role body) + subtitle (text role meta, color.global.textSecondary) + trailing native switch (tin… (SOURCED) | `SettingsRow(kind: .toggle)` single grouped row with a switch, off by default |
| matched | `auth.agegate.optIn.label` | “Share My Birthday” (SOURCED) | `Copy.authAgegateOptInLabel` in AgeGateForm.swift |
| matched | `auth.agegate.optIn.detail` | “Your groups can make you a birthday video. We save your birthday for this.” (SOURCED) | `Copy.authAgegateOptInDetail` in AgeGateForm.swift |
| matched | `auth.agegate.continue` | “Next” (SOURCED) | `Copy.authAgegateContinue` in AgeGateForm.swift |
| matched | `size.global.buttonMarginH` | 20 pt (SOURCED) | `Tokens.Sizes.globalButtonMarginH` in BackdropCard.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, OnboardingTitle.swift … |

## Elements

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `color.global.control` | light: #F1F1F1; dark: #262626 (SOURCED) | `Tokens.Colors.globalControl` in AccountGroupedRows.swift, Avatar.swift, CapsuleButton.swift, CircleButton.swift … |
| matched | `size.global.fieldHeight` | 52 pt (SOURCED) | `Tokens.Sizes.globalFieldHeight` in FormField.swift |
| matched | `radius.global.field` | 19 pt (SOURCED) | `Tokens.Radii.globalField` in FormField.swift |
| matched | `auth.agegate.field.accessibilityLabel` | “Birthday” (VERIFIED) | `Copy.authAgegateFieldAccessibilityLabel` in AgeGateForm.swift |
| n/a | `color.global.surfaceSecondary.android` | light: #F7F7F7; dark: #262626 (SOURCED) | Android only |
| matched | `radius.global.groupedRow` | 12 pt (SOURCED) | `Tokens.Radii.globalGroupedRow` in AccountGroupedRows.swift, GroupInviteScreen.swift, GroupedSection.swift |
| matched | `size.global.screenMargin` | 16 pt (SOURCED) | `Tokens.Sizes.globalScreenMargin` in AccountGroupedRows.swift, AgeGateForm.swift, CodeScreen.swift, EmptyStateView.swift … |
| matched | `color.global.selection` | light: #0088FF; dark: #0091FF (PLATFORM) | `Tokens.Colors.globalSelection` in AccountGroupedRows.swift, CheckRow.swift, GroupedSection.swift, SettingsNotificationsScreen.swift … |
| n/a | `color.global.system.primary` | #0A84FF (SOURCED) | Android M3 dialog colour; iOS uses system alerts and the `color.global.selection` tint |
| matched | `settings.root.size.rowHeight` | 58.7 pt (SOURCED) | `Tokens.Sizes.settingsRootSizeRowHeight` in AccountGroupedRows.swift |
| matched | `auth.agegate.optIn.accessibilityLabel` | “Share my birthday with my groups” (VERIFIED) | `Copy.authAgegateOptInAccessibilityLabel` in AgeGateForm.swift |
| matched | `auth.phone.layout.inlineError` | presentation: native alert: iOS SwiftUI .alert / Android M3 AlertDialog (settings.account.layout.alert); not dismissed by tapping outside; titled: code error… (SOURCED) | `formErrorAlert(_:trigger:)` (C-29 native message-only alert); code errors: titled alert with Retro's two recoveries |
| matched | `auth.agegate.error.invalidDate` | “Please check the date and try again.” (SOURCED) | `Copy.authAgegateErrorInvalidDate` in AgeGateForm.swift |
| matched | `auth.phone.error.dismiss` | “OK” (VERIFIED) | `Copy.authPhoneErrorDismiss` in CodeScreen.swift, FormErrorAlert.swift, ReportFlow.swift |

## States

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `auth.agegate.notConfigured.title` | “Sign-up isn't open yet” (SOURCED) | `Copy.authAgegateNotConfiguredTitle` in AgeGateForm.swift |
| matched | `auth.agegate.underAge.title` | “Sorry, you need to be {min_age} or older to sign up.” (SOURCED) | `AgeGateRefusedScreen` (BLOCKED {app_name}: the explanation stands alone in release) |
| matched | `auth.agegate.underAge.detail` | “We didn't save your birthday.” (SOURCED) | `Copy.authAgegateUnderAgeDetail` in AgeGateForm.swift |

## Motion

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `duration.global.crossfade` | 100 ms (SOURCED) | `Tokens.Durations.globalCrossfade` in AgeGateForm.swift, ComponentSupport.swift |
| matched | `easing.global.standard` | x1: 0.4; y1: 0; x2: 0.2; y2: 1 (SOURCED) | `Tokens.Easings.globalStandard` in AgeGateForm.swift, ComponentSupport.swift, GroupCreateScreen.swift, GroupInviteScreen.swift … |

## Haptics

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | Android only — iOS presses play no haptic |
| matched | `settings.root.layout.toggleHaptic` | ios: system (SwiftUI Toggle plays its own haptic; no custom generator); android: TOGGLE_ON / TOGGLE_OFF (API 34) only if the Switch does not already play one (PLATFORM) | SwiftUI `Toggle` plays its own haptic (no custom generator) |
| matched | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | `Tokens.Haptics.globalSuccess` in AgeGateForm.swift, CodeScreen.swift, GroupCreateScreen.swift, InviteClipApp.swift … |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | `Tokens.Haptics.globalError` in AgeGateForm.swift, BlockConfirmation.swift, CodeScreen.swift, GroupCreateScreen.swift … |

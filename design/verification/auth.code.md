# Verification — `auth.code` (iOS, Pass 4 — Retro redesign)

SMS code — `Features/Account/Shared/CodeScreen.swift`, `Shared/CodeModel.swift`, `Shared/AuthFailure.swift`.

Checklist written from the spec (`design/surfaces/auth.code.md`) against the iOS code: every token and copy key the spec names, its reference value, and where the iOS code uses it. The snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (AccountSnapshotTests: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/auth.code.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`, `references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png`

Snapshots (CI, `ios/build/snapshots/account/`): `auth.code-default-light.png`, `auth.code-default-dark.png`, `auth.code-filled-light.png`, `auth.code-verifying-light.png`, `auth.code-offline-light.png`

**Summary: 42 matched · 0 approximated · 0 not matched · 1 not applicable on iOS / owner / another pass.**


## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `auth.phone.layout.inlineError` | presentation: native alert: iOS SwiftUI .alert / Android M3 AlertDialog (settings.account.layout.alert); not dismissed by tapping outside; titled: code error… (SOURCED) | `formErrorAlert(_:trigger:)` (C-29 native message-only alert); code errors: titled alert with Retro's two recoveries |
| matched | `color.global.background` | light: #FFFFFF; dark: #000000 (SOURCED) | `Tokens.Colors.globalBackground` in AccountGroupedRows.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, GroupScreen.swift … |
| matched | `icon.global.back` | ios: chevron.left; android: AutoMirrored.Rounded.ArrowBackIos (PLATFORM) | `Tokens.Icons.globalBack` in ScreenHeader.swift, SignUpLayout.swift |
| matched | `size.global.backInset` | 21.1 pt (SOURCED) | `Tokens.Sizes.globalBackInset` in ScreenHeader.swift, SignUpLayout.swift |
| matched | `auth.code.title` | “Enter your code” (SOURCED) | `Copy.authCodeTitle` in CodeScreen.swift |
| matched | `font.global.display` | ios: system-serif; android: serif (PLATFORM) | `Tokens.Fonts.globalDisplay` in InvitePreviewView.swift, PhoneScreen.swift, TextRoles.swift |
| matched | `color.global.textPrimary` | light: #000000; dark: #FFFFFF (SOURCED) | `Tokens.Colors.globalTextPrimary` in AccountGroupedRows.swift, CapsuleButton.swift, CheckRow.swift, CircleButton.swift … |
| matched | `size.global.screenMargin` | 16 pt (SOURCED) | `Tokens.Sizes.globalScreenMargin` in AccountGroupedRows.swift, AgeGateForm.swift, CodeScreen.swift, EmptyStateView.swift … |
| matched | `size.global.titleTop` | 64 pt (SOURCED) | `Tokens.Sizes.globalTitleTop` in FullBleedMediaPage.swift, GroupScreen.swift, ScreenHeader.swift, SignUpLayout.swift |
| matched | `auth.code.subtitle` | “We texted a code to {phone}.” (SOURCED) | `Copy.authCodeSubtitle` in CodeScreen.swift |
| matched | `color.global.textSecondary` | #999999 (SOURCED) | `Tokens.Colors.globalTextSecondary` in AccountGroupedRows.swift, Avatar.swift, CheckRow.swift, CodeScreen.swift … |
| matched | `size.global.titleToContent` | 30 pt (SOURCED) | `Tokens.Sizes.globalTitleToContent` in AccountGroupedRows.swift, AgeGateForm.swift, GroupCreateScreen.swift, GroupInviteScreen.swift … |
| matched | `auth.code.layout.codeField` | ios: one TextField, textContentType .oneTimeCode, keyboardType .numberPad; no per-digit boxes (a custom input view cannot show the AutoFill suggestion); andr… (PLATFORM) | `FormField(keyboard: .numberPad, contentType: .oneTimeCode)`; digits only (`CodeModel.setCode`) |
| matched | `auth.code.field.placeholder` | “Enter the code…” (SOURCED) | `Copy.authCodeFieldPlaceholder` in CodeScreen.swift |
| matched | `size.global.sectionHeaderToContent` | 11.7 pt (SOURCED) | `Tokens.Sizes.globalSectionHeaderToContent` in CodeScreen.swift, GroupInviteScreen.swift, GroupScreen.swift, GroupsHomeScreen.swift … |
| matched | `auth.code.helper` | “Your code may take up to 30 seconds to arrive” (SOURCED) | `Copy.authCodeHelper` in CodeScreen.swift |
| matched | `auth.code.resend.prefix` | “Didn't receive a code?” (SOURCED) | `Copy.authCodeResendPrefix` in CodeScreen.swift |
| matched | `auth.code.resend` | “Send again” (SOURCED) | `Copy.authCodeResend` in CodeScreen.swift |
| matched | `auth.code.continue` | “Next” (SOURCED) | `Copy.authCodeContinue` in CodeScreen.swift |
| matched | `size.global.buttonMarginH` | 20 pt (SOURCED) | `Tokens.Sizes.globalButtonMarginH` in BackdropCard.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, OnboardingTitle.swift … |

## Elements

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `auth.code.back.accessibilityLabel` | “Back” (VERIFIED) | `Copy.authCodeBackAccessibilityLabel` in CodeScreen.swift, PhoneForm.swift, ProfileScreen.swift, WidgetGuideScreen.swift |
| matched | `auth.code.field.accessibilityLabel` | “Verification code” (VERIFIED) | `Copy.authCodeFieldAccessibilityLabel` in CodeScreen.swift |
| matched | `color.global.textTertiary` | light: #C1C1C1; dark: #FFFFFF4D (SOURCED) | `Tokens.Colors.globalTextTertiary` in AccountGroupedRows.swift, CapsuleButton.swift, CodeScreen.swift |
| matched | `auth.code.duration.resendLock` | 60000 ms (VERIFIED) | `Tokens.Durations.authCodeDurationResendLock` in CodeModel.swift |
| matched | `auth.code.toast.resent` | “Code sent!” (SOURCED) | `Copy.authCodeToastResent` in CodeScreen.swift |

## States

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `auth.code.error.wrong.title` | “SMS Code Error” (SOURCED) | `Copy.authCodeErrorWrongTitle` in AuthFailure.swift |
| matched | `auth.code.error.wrong` | “Unable to verify code. Please check the code and try again.” (SOURCED) | `Copy.authCodeErrorWrong` in AuthFailure.swift |
| matched | `auth.code.error.editCode` | “Edit code” (SOURCED) | `Copy.authCodeErrorEditCode` in CodeScreen.swift |
| matched | `auth.code.error.sendNew` | “Send a new code” (SOURCED) | `Copy.authCodeErrorSendNew` in CodeScreen.swift |
| matched | `auth.code.error.expired.title` | “Code Expired” (SOURCED) | `Copy.authCodeErrorExpiredTitle` in AuthFailure.swift |
| matched | `auth.code.error.expired` | “That code has expired. Send a new code and try again.” (SOURCED) | `Copy.authCodeErrorExpired` in AuthFailure.swift |
| matched | `auth.code.error.service.title` | “Couldn't Verify Code” (SOURCED) | `Copy.authCodeErrorServiceTitle` in AuthFailure.swift |
| matched | `auth.code.error.service` | “We couldn't verify the code. Check your connection and try again.” (SOURCED) | `Copy.authCodeErrorService` in AuthFailure.swift |
| matched | `auth.phone.error.dismiss` | “OK” (VERIFIED) | `Copy.authPhoneErrorDismiss` in CodeScreen.swift, FormErrorAlert.swift, ReportFlow.swift |
| matched | `auth.code.error.tooMany` | “Too many tries. Please wait a minute, then send a new code.” (SOURCED) | `Copy.authCodeErrorTooMany` in AuthFailure.swift |
| matched | `auth.phone.offline.title` | “You're offline” (SOURCED) | `Copy.authPhoneOfflineTitle` in AuthFlowView.swift, SignUpLayout.swift |
| matched | `auth.phone.offline.detail` | “Could not connect. Check your connection and try again.” (SOURCED) | `Copy.authPhoneOfflineDetail` in AuthFlowView.swift, SignUpLayout.swift |
| matched | `auth.phone.offline.retry` | “Try again” (SOURCED) | `Copy.authPhoneOfflineRetry` in AuthFlowView.swift, SignUpLayout.swift |

## Motion

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `easing.global.native` | sheet: system (.sheet / ModalBottomSheet) — measured on Retro: spring.global.sheetPresent; navigationPush: system (NavigationStack / Compose Navigation defau… (PLATFORM) | platform push / sheet animations (`NavigationStack`, `.sheet`, `.fullScreenCover`) |
| matched | `duration.global.crossfade` | 100 ms (SOURCED) | `Tokens.Durations.globalCrossfade` in AgeGateForm.swift, ComponentSupport.swift |

## Haptics

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | Android only — iOS presses play no haptic |
| matched | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | `Tokens.Haptics.globalSuccess` in AgeGateForm.swift, CodeScreen.swift, GroupCreateScreen.swift, InviteClipApp.swift … |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | `Tokens.Haptics.globalError` in AgeGateForm.swift, BlockConfirmation.swift, CodeScreen.swift, GroupCreateScreen.swift … |

## Notes

- Resend: the line is `color.global.textTertiary` while locked; no countdown (spec).

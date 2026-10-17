# Verification — `auth.phone` (iOS, Pass 4 — Retro redesign)

Landing (state A) and phone form (state B) — `Features/Account/Auth/PhoneScreen.swift` (`PhoneScreen`, `PhoneLanding`), `Shared/PhoneForm.swift`, `Shared/PhoneModel.swift`, `Shared/SignUpLayout.swift`.

Checklist written from the spec (`design/surfaces/auth.phone.md`) against the iOS code: every token and copy key the spec names, its reference value, and where the iOS code uses it. The snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (AccountSnapshotTests: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/auth.phone.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png`, `references/auto/retro/web/retro.app-5bff8a0be69f7ec7.css`, `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`, `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png`, react-native-phone-input 1.4.1 (public source; `auth.phone.layout.countryCode`)

Snapshots (CI, `ios/build/snapshots/account/`): `auth.phone-landing-light.png`, `auth.phone-landing-dark.png`, `auth.phone-form-light.png`, `auth.phone-form-filled-light.png`, `auth.phone-form-filled-dark.png`, `auth.phone-sending-light.png`, `auth.phone-offline-light.png`, `auth.phone-country-list-light.png`

**Summary: 57 matched · 0 approximated · 0 not matched · 2 not applicable on iOS / owner / another pass.**


## References

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `auth.phone.fontSize.wordmark` | 64 pt (SOURCED) | `Tokens.FontSizes.authPhoneFontSizeWordmark` in PhoneScreen.swift |
| matched | `auth.phone.layout.countryCode` | pattern: flag at the field's leading edge + the calling code typed inline with the number ('+1 555 …'); no separate code button; flagWidth: 30; flagHeight: 2… (SOURCED) | `Tokens.Layouts.AuthPhoneLayoutCountryCode` in PhoneForm.swift — flag, prefill, inline code, country list done; `autoFormat` done in PhoneNumberInput.swift (`PhoneNumberFormatting`: PhoneNumberKit 4.2.13 `PartialFormatter`, the Swift port of libphonenumber's AsYouTypeFormatter that Android uses; edits at the end are re-formatted, an edit inside the number stays as typed so the cursor does not jump, deleting a separator deletes the digit before it; the shown text only — `send()` submits `PhoneNumberInput.normalized`, E.164) |

## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `color.global.background` | light: #FFFFFF; dark: #000000 (SOURCED) | `Tokens.Colors.globalBackground` in AccountGroupedRows.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, GroupScreen.swift … |
| n/a | `color.global.background.android` | light: #FFFFFF; dark: #1C1C1E (SOURCED) | Android only |
| matched | `font.global.display` | ios: system-serif; android: serif (PLATFORM) | `Tokens.Fonts.globalDisplay` in InvitePreviewView.swift, PhoneScreen.swift, TextRoles.swift |
| matched | `color.global.textPrimary` | light: #000000; dark: #FFFFFF (SOURCED) | `Tokens.Colors.globalTextPrimary` in AccountGroupedRows.swift, CapsuleButton.swift, CheckRow.swift, CircleButton.swift … |
| matched | `auth.phone.size.wordmarkToTagline` | 19.3 pt (SOURCED) | `Tokens.Sizes.authPhoneSizeWordmarkToTagline` in PhoneScreen.swift |
| matched | `auth.phone.tagline` | “Friends and Family Only” (SOURCED) | `Copy.authPhoneTagline` in PhoneScreen.swift |
| matched | `color.global.textSecondary` | #999999 (SOURCED) | `Tokens.Colors.globalTextSecondary` in AccountGroupedRows.swift, Avatar.swift, CheckRow.swift, CodeScreen.swift … |
| matched | `auth.phone.getStarted` | “Get started” (SOURCED) | `Copy.authPhoneGetStarted` in PhoneScreen.swift |
| matched | `size.global.buttonMarginH` | 20 pt (SOURCED) | `Tokens.Sizes.globalButtonMarginH` in BackdropCard.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, OnboardingTitle.swift … |
| matched | `size.global.buttonHeight` | 60 pt (SOURCED) | `Tokens.Sizes.globalButtonHeight` in PrimaryButton.swift |
| matched | `auth.phone.size.capsuleToLink` | 20.7 pt (SOURCED) | `Tokens.Sizes.authPhoneSizeCapsuleToLink` in PhoneScreen.swift, ProfileScreen.swift |
| matched | `auth.phone.signIn` | “already have an account?” (SOURCED) | `Copy.authPhoneSignIn` in PhoneScreen.swift |
| matched | `auth.phone.size.linkToLegal` | 28.4 pt (SOURCED) | `Tokens.Sizes.authPhoneSizeLinkToLegal` in PhoneScreen.swift |
| matched | `auth.phone.legal.text` | “By continuing, I agree to the Terms and Privacy Policy.” (SOURCED) | `Copy.authPhoneLegalText` in PhoneModel.swift |
| matched | `lineHeight.global.caption` | 21.7 pt (SOURCED) | `Tokens.LineHeights.globalCaption` in TextRoles.swift |
| matched | `size.global.screenMargin` | 16 pt (SOURCED) | `Tokens.Sizes.globalScreenMargin` in AccountGroupedRows.swift, AgeGateForm.swift, CodeScreen.swift, EmptyStateView.swift … |
| matched | `auth.phone.legal.terms` | “Terms” (SOURCED) | `Copy.authPhoneLegalTerms` in PhoneModel.swift |
| matched | `auth.phone.legal.privacy` | “Privacy Policy” (SOURCED) | `Copy.authPhoneLegalPrivacy` in PhoneModel.swift |
| matched | `auth.phone.size.legalToBottom` | 40 pt (SOURCED) | `Tokens.Sizes.authPhoneSizeLegalToBottom` in PhoneScreen.swift |
| matched | `icon.global.back` | ios: chevron.left; android: AutoMirrored.Rounded.ArrowBackIos (PLATFORM) | `Tokens.Icons.globalBack` in ScreenHeader.swift, SignUpLayout.swift |
| matched | `size.global.backInset` | 21.1 pt (SOURCED) | `Tokens.Sizes.globalBackInset` in ScreenHeader.swift, SignUpLayout.swift |
| matched | `auth.phone.title` | “What's your phone number?” (SOURCED) | `Copy.authPhoneTitle` in PhoneForm.swift |
| matched | `size.global.titleTop` | 64 pt (SOURCED) | `Tokens.Sizes.globalTitleTop` in FullBleedMediaPage.swift, GroupScreen.swift, ScreenHeader.swift, SignUpLayout.swift |
| matched | `auth.phone.subtitle` | “We'll text you a code to sign up or log in.” (SOURCED) | `Copy.authPhoneSubtitle` in PhoneForm.swift |
| matched | `size.global.titleToContent` | 30 pt (SOURCED) | `Tokens.Sizes.globalTitleToContent` in AccountGroupedRows.swift, AgeGateForm.swift, GroupCreateScreen.swift, GroupInviteScreen.swift … |
| matched | `auth.phone.field.placeholder` | “Enter your phone number…” (SOURCED) | `Copy.authPhoneFieldPlaceholder` in PhoneForm.swift |
| matched | `auth.phone.layout.keyboard` | ios: TextField keyboardType .phonePad, textContentType .telephoneNumber (system AutoFill offers the person's own number); android: TextField KeyboardOptions(… (PLATFORM) | `FormField(keyboard: .phonePad, contentType: .telephoneNumber)` (system AutoFill) |
| matched | `auth.phone.continue` | “Next” (SOURCED) | `Copy.authPhoneContinue` in PhoneForm.swift |

## Elements

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `auth.phone.layout.landingBlock` | centreY: 0.446; align: centre (horizontal); contents: wordmark (auth.phone.fontSize.wordmark) over the tagline (text role onboardingTitle, color.global.textS… (SOURCED) | `Tokens.Layouts.AuthPhoneLayoutLandingBlock` in PhoneScreen.swift |
| matched | `color.global.accent` | light: #000000; dark: #FFFFFF (SOURCED) | `Tokens.Colors.globalAccent` in CapsuleButton.swift, PrimaryButton.swift |
| matched | `color.global.onAccent` | light: #FFFFFF; dark: #000000 (SOURCED) | `Tokens.Colors.globalOnAccent` in CapsuleButton.swift, PrimaryButton.swift |
| matched | `radius.global.button` | 30 pt (SOURCED) | `Tokens.Radii.globalButton` in TextRoles.swift |
| matched | `size.global.headerButton` | 44 pt (PLATFORM) | `Tokens.Sizes.globalHeaderButton` in GroupScreen.swift, GroupSettingsScreen.swift, ScreenHeader.swift, SectionHeader.swift … |
| matched | `auth.code.back.accessibilityLabel` | “Back” (VERIFIED) | `Copy.authCodeBackAccessibilityLabel` in CodeScreen.swift, PhoneForm.swift, ProfileScreen.swift, WidgetGuideScreen.swift |
| matched | `color.global.control` | light: #F1F1F1; dark: #262626 (SOURCED) | `Tokens.Colors.globalControl` in AccountGroupedRows.swift, Avatar.swift, CapsuleButton.swift, CircleButton.swift … |
| matched | `size.global.fieldHeight` | 52 pt (SOURCED) | `Tokens.Sizes.globalFieldHeight` in FormField.swift |
| matched | `radius.global.field` | 19 pt (SOURCED) | `Tokens.Radii.globalField` in FormField.swift |
| matched | `auth.phone.field.accessibilityLabel` | “Phone number” (VERIFIED) | `Copy.authPhoneFieldAccessibilityLabel` in PhoneForm.swift |
| matched | `color.global.controlRaised` | light: #CCCCCC; dark: #4D4D4D (SOURCED) | `Tokens.Colors.globalControlRaised` in CapsuleButton.swift, PrimaryButton.swift |
| matched | `auth.phone.layout.inlineError` | presentation: native alert: iOS SwiftUI .alert / Android M3 AlertDialog (settings.account.layout.alert); not dismissed by tapping outside; titled: code error… (SOURCED) | `formErrorAlert(_:trigger:)` (C-29 native message-only alert); code errors: titled alert with Retro's two recoveries |
| matched | `auth.phone.error.invalidNumber` | “Unable to verify phone number. Please check the number and try again.” (SOURCED) | `Copy.authPhoneErrorInvalidNumber` in AuthFailure.swift |
| matched | `auth.phone.error.dismiss` | “OK” (VERIFIED) | `Copy.authPhoneErrorDismiss` in CodeScreen.swift, FormErrorAlert.swift, ReportFlow.swift |

## States

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `auth.phone.error.rateLimited` | “Please wait a minute, then try again.” (SOURCED) | `Copy.authPhoneErrorRateLimited` in AuthFailure.swift |
| matched | `auth.phone.error.sendFailed` | “There was a problem. Please try again.” (SOURCED) | `Copy.authPhoneErrorSendFailed` in AuthFailure.swift |
| matched | `auth.phone.offline.title` | “You're offline” (SOURCED) | `Copy.authPhoneOfflineTitle` in AuthFlowView.swift, SignUpLayout.swift |
| matched | `auth.phone.offline.detail` | “Could not connect. Check your connection and try again.” (SOURCED) | `Copy.authPhoneOfflineDetail` in AuthFlowView.swift, SignUpLayout.swift |
| matched | `auth.phone.offline.retry` | “Try again” (SOURCED) | `Copy.authPhoneOfflineRetry` in AuthFlowView.swift, SignUpLayout.swift |

## Motion

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `duration.global.pageTransition` | 500 ms (SOURCED) | `Tokens.Durations.globalPageTransition` in PaywallScreen.swift, PhoneScreen.swift, ProfileScreen.swift |
| matched | `easing.global.standard` | x1: 0.4; y1: 0; x2: 0.2; y2: 1 (SOURCED) | `Tokens.Easings.globalStandard` in AgeGateForm.swift, ComponentSupport.swift, GroupCreateScreen.swift, GroupInviteScreen.swift … |
| matched | `layout.global.reduceMotion` | ios: UIAccessibility.isReduceMotionEnabled / @Environment(\.accessibilityReduceMotion); android: Settings.Global.ANIMATOR_DURATION_SCALE == 0 or ValueAnimato… (PLATFORM) | `dsAnimation` / `dsTransition` (DesignSystem) drop movement under Reduce Motion, keep cross-fades |
| matched | `easing.global.native` | sheet: system (.sheet / ModalBottomSheet) — measured on Retro: spring.global.sheetPresent; navigationPush: system (NavigationStack / Compose Navigation defau… (PLATFORM) | platform push / sheet animations (`NavigationStack`, `.sheet`, `.fullScreenCover`) |
| matched | `spring.global.sheetPresent` | response: 0.347; dampingFraction: 1 (SOURCED) | system sheet presentation (`.sheet`) |

## Haptics

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | Android only — iOS presses play no haptic |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | `Tokens.Haptics.globalError` in AgeGateForm.swift, BlockConfirmation.swift, CodeScreen.swift, GroupCreateScreen.swift … |

## Accessibility

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `layout.global.textStyleMap` | headerTitle: largeTitle; displayMedium: largeTitle; displaySmall: title2; onboardingTitle: title; sheetTitle: headline; listTitle: subheadline; listSubtitle:… (PLATFORM) | `Tokens.Layouts.GlobalTextStyleMap` in InvitePreviewView.swift, TextRoles.swift |

## Data & actions

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `settings.account.deleted.toast` | “Account deleted” (SOURCED) | `Copy.settingsAccountDeletedToast` in AccountSession.swift |

## Platform notes

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `font.global.family` | ios: system; android: Inter (SOURCED) | `Tokens.Fonts.globalFamily` in GroupInviteScreen.swift, InvitePreviewView.swift, PaywallScreen.swift, ScreenHeader.swift … |

## Notes

- Landing: the wordmark is the BLOCKED app name (DEBUG placeholder); its vertical position follows `auth.phone.layout.landingBlock.centreY` of the height.
- Country flag + inline calling code; no phone-number formatting library (the number stays as typed).

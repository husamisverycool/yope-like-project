# Verification — `auth.phone` (iOS)

Sign up / log in with a phone number — `Features/Account/Auth/PhoneScreen.swift`.

Checklist written from the spec (`design/surfaces/auth.phone.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/auth.phone.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Reference image(s): `references/auto/yope/frames/a-yrrah-7454430216123862280-t6.73-signup-2024.png`, `references/auto/yope/frames/a-virgi-7686278541255642390-t31.23-signup-es.png`, `references/auto/yope/frames/a-yrrah-7452976839846382855-t3.73-create-new-group-empty-2024.png`, `references/auto/yope/web/a-bi-2025-create-group-composite.jpg`, `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t49.23-new-group-selected-create.png`, `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t50.60-loading-hud.png`, `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png`

Snapshots (CI): `auth.phone-default.png`, `auth.phone-filled.png`, `auth.phone-sending.png`, `auth.phone-offline.png`, `auth.phone-country-list.png`

**Summary: 66 matched · 3 approximated · 0 not matched (BLOCKED or not buildable) · 1 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | token | `color.global.backgroundDeep` | #000000 (SOURCED) | screen background of the home list, sheets ('new group', 'send to...'), camera, sign-up, profile 'pics' gri… | `Tokens.…globalBackgroundDeep` in SignUpLayout.swift |
| matched | copy | `auth.phone.title` | “sign up or log in” (SOURCED) |  | `Copy.…authPhoneTitle` in PhoneScreen.swift |
| matched | token | `groups.create.size.sheetTopToTitle` | 71 pt (SOURCED) | sheet top edge to the title's cap top (also the safe-area top to the title on full-screen onboarding steps) | `Tokens.…groupsCreateSizeSheetTopToTitle` in SignUpLayout.swift |
| matched | copy | `auth.phone.subtitle` | “to join or create your groups” (SOURCED) |  | `Copy.…authPhoneSubtitle` in PhoneScreen.swift |
| matched | token | `groups.create.size.titleToContent` | 34 pt (SOURCED) | title text bottom (descender) to the first content element | `Tokens.…groupsCreateSizeTitleToContent` in PhoneScreen.swift |
| matched | token | `size.global.buttonMarginH` | 19 pt (SOURCED) | side margin of the form primary button | `Tokens.…globalButtonMarginH` in PhoneScreen.swift |
| matched | token | `groups.create.size.fieldToButton` | 18 pt (SOURCED) | form field bottom to the primary button top | `Tokens.…groupsCreateSizeFieldToButton` in PhoneScreen.swift |
| matched | copy | `auth.phone.continue` | “continue” (SOURCED) |  | `Copy.…authPhoneContinue` in PhoneScreen.swift |
| matched | copy | `auth.phone.legal.text` | “by continuing you agree to our Terms of Use and Privacy Policy” (SOURCED) |  | `Copy.…authPhoneLegalText` in PhoneModel.swift |
| matched | token | `size.global.screenMargin` | 12 pt (SOURCED) | side margin of full-width content (home list cards); edge elements sit at the same inset | `Tokens.…globalScreenMargin` in EmptyStateView.swift, PhoneScreen.swift, Toast.swift |
| matched | token | `auth.phone.layout.keyboard` | ios: UITextField/TextField keyboardType .phonePad, textContentType .telephoneNumber (system AutoFill); android: TextField KeyboardOptions(keyboardType = Keyb… (PLATFORM) | keyboard and AutoFill of the phone-number field | FormField .phonePad / .telephoneNumber (AutoFill) |
| matched | token | `fontSize.global.onboardingTitle` | 40 pt (SOURCED) | onboarding / sign-up big title ('registrarse') | `Tokens.…globalOnboardingTitle` in TextRoles.swift |
| matched | token | `fontWeight.global.onboardingTitle` | heavy (SOURCED) | onboarding / sign-up big title | `Tokens.…fontWeightGlobalOnboardingTitle` in TextRoles.swift |
| matched | token | `color.global.textPrimary` | #FFFFFF (SOURCED) | primary text and glyphs | `Tokens.…globalTextPrimary` in CheckRow.swift, EmptyStateView.swift, FloatingTabBar.swift |
| matched | token | `font.global.family` | ios: system; android: system (PLATFORM) | typeface of all text (SF Pro on iOS, Roboto on Android) | `Tokens.…globalFamily` in PermissionCard.swift, SegmentedPills.swift, TextRoles.swift |
| matched | token | `auth.phone.fontSize.subtitle` | 14 pt (SOURCED) | italic subtitle under the sign-up title ('to join or create your friends groups') | `Tokens.…authPhoneFontSizeSubtitle` in TextRoles.swift |
| matched | token | `auth.phone.layout.subtitle` | style: italic; weight: regular; color: color.global.textPrimary; align: center (SOURCED) | subtitle text style under the sign-up title | OnboardingTitleBlock subtitle: italic, regular, textPrimary, centred |
| matched | token | `groups.create.color.field` | #141414 (SOURCED) | single-line text field fill on black ('name group (optional)'); reused by every form field on black (auth.*… | `Tokens.…groupsCreateColorField` in FormField.swift |
| matched | token | `size.global.fieldHeight` | 44 pt (SOURCED) | single-line form text field height | `Tokens.…globalFieldHeight` in FormField.swift |
| matched | token | `radius.global.field` | 12 pt (SOURCED) | single-line form text field corners ('name group (optional)') | `Tokens.…globalField` in FormField.swift |
| matched | token | `groups.create.fontSize.fieldText` | 15 pt (SOURCED) | typed text in the form field (centred) | `Tokens.…groupsCreateFontSizeFieldText` in TextRoles.swift |
| matched | token | `groups.create.fontWeight.fieldText` | bold (SOURCED) | typed text weight in the form field | `Tokens.…groupsCreateFontWeightFieldText` in TextRoles.swift |
| matched | token | `color.global.textSecondary` | #969696 (SOURCED) | secondary text, placeholders ('start typing...'), inactive tab-bar glyphs, chevrons inside capsules | `Tokens.…globalTextSecondary` in CheckRow.swift, EmptyStateView.swift, FloatingTabBar.swift |
| approximated | token | `auth.phone.layout.countryCode` | pattern: flag at the field's leading edge + the calling code typed inline with the number ('+1 555 ...'); no separate code button; flagWidth: 20; flagHeight:… (SOURCED) | country calling-code selector of the phone field | `CountryFlagButton`: regional-indicator flag in the flagWidth × flagHeight slot at flagLeading, text leading-aligned flagToText after it; tap → searchable country list sheet (`CountryCodeList`), choosing replaces the calling code; prefill "+" + region code. Not done: autoFormat (no phone-number formatting library; the number stays as typed) |
| matched | copy | `auth.phone.field.placeholder` | “phone number” (SOURCED) |  | `Copy.…authPhoneFieldPlaceholder` in PhoneScreen.swift |
| matched | copy | `auth.phone.field.accessibilityLabel` | “phone number” (SOURCED) |  | `Copy.…authPhoneFieldAccessibilityLabel` in PhoneScreen.swift |
| matched | token | `color.global.accent` | #CDFD07 (SOURCED) | brand lime: composer camera button, primary buttons, coach tooltips, toasts, shutter ring, 'today' bar | `Tokens.…globalAccent` in OnboardingTitle.swift, PrimaryButton.swift, Toast.swift |
| matched | token | `color.global.onAccent` | #000000 (SOURCED) | text and glyphs on lime: camera glyph on the composer button, primary button labels, tooltip text | `Tokens.…globalOnAccent` in PrimaryButton.swift, Toast.swift |
| matched | token | `size.global.buttonHeight` | 45 pt (SOURCED) | full-width primary button in a form ('create group') | `Tokens.…globalButtonHeight` in PrimaryButton.swift |
| matched | token | `radius.global.button` | 14 pt (SOURCED) | primary (lime) button corners — not a full pill | `Tokens.…globalButton` in PrimaryButton.swift, TextRoles.swift |
| matched | token | `fontSize.global.button` | 15 pt (SOURCED) | primary button label ('create group', 'send') | `Tokens.…globalButton` in PrimaryButton.swift, TextRoles.swift |
| matched | token | `fontWeight.global.button` | semibold (SOURCED) | primary button label | `Tokens.…fontWeightGlobalButton` in TextRoles.swift |
| matched | token | `groups.create.color.buttonDisabledFill` | #201D21 (SOURCED) | primary button while its form is incomplete ('continue' with an empty name) | `Tokens.…groupsCreateColorButtonDisabledFill` in PrimaryButton.swift |
| matched | token | `groups.create.color.buttonDisabledLabel` | #49464A (SOURCED) | label of the disabled primary button | `Tokens.…groupsCreateColorButtonDisabledLabel` in PrimaryButton.swift |
| matched | token | `auth.phone.layout.legalFooter` | text: color.global.textSecondary; links: same colour, bold weight (2026 build: bold 'Términos de uso' / 'Política de privacidad'); the 2024 build drew the li… (SOURCED) | legal footer under the sign-up controls | `PhoneModel.legalText`: caption, textSecondary, centred at the bottom; terms / privacy bold, linked when config/app.json has the URLs (opened in SFSafariViewController) |
| matched | token | `fontSize.global.caption` | 12 pt (SOURCED) | small meta text: voice-message duration ('00:38'), legal footer under sign-up | `Tokens.…globalCaption` in TextRoles.swift |
| matched | token | `lineHeight.global.caption` | 15.2 pt (SOURCED) | line pitch of the 3-line legal footer under sign-up (12 pt text) | `Tokens.…globalCaption` in TextRoles.swift |
| matched | copy | `auth.phone.legal.terms` | “Terms of Use” (SOURCED) |  | `Copy.…authPhoneLegalTerms` in PhoneModel.swift |
| matched | copy | `auth.phone.legal.privacy` | “Privacy Policy” (SOURCED) |  | `Copy.…authPhoneLegalPrivacy` in PhoneModel.swift |
| matched | token | `groups.create.color.hud` | #0C0C0C (SOURCED) | Loading HUD square fill (on black) | `Tokens.…groupsCreateColorHud` in LoadingHUD.swift |
| matched | token | `groups.create.size.hud` | 100 pt (SOURCED) | Loading HUD square side | `Tokens.…groupsCreateSizeHud` in LoadingHUD.swift |
| matched | token | `groups.create.fontSize.hudLabel` | 15 pt (SOURCED) | 'Loading' label under the spinner in the HUD | `Tokens.…groupsCreateFontSizeHudLabel` in TextRoles.swift |
| matched | token | `easing.global.native` | keyboard: system; alert: system; activityIndicator: system (ProgressView / CircularProgressIndicator); scrollIndicator: system; navigationPush: system (Navig… (PLATFORM) | motion of native components Yope uses; their curves and durations are the platform's | system push / sheet / alert animations |
| matched | copy | `groups.create.hud.loading` | “Loading” (SOURCED) |  | `Copy.…groupsCreateHudLoading` in LoadingHUD.swift |
| matched | token | `safety.block.layout.toast` | fill: color.global.accent; content: icon.global.checkmark + label in color.global.onAccent, text role button; shape: radius.global.capsule, full width minus … (SOURCED) | confirmation toast after block / unblock / report (Yope lime toast) | `ToastView` / `.toastHost` (Components/Toast.swift): accent fill, checkmark + label onAccent, capsule, screenMargin, top |
| matched | token | `safety.block.duration.toast` | 2000 ms (SOURCED) | how long the lime toast stays before it leaves | `Tokens.…safetyBlockDurationToast` in Toast.swift |
| matched | copy | `auth.phone.toast.codeSent` | “code sent” (SOURCED) |  | `Copy.…authPhoneToastCodeSent` in PhoneScreen.swift |
| matched | copy | `settings.account.deleted.toast` | “your account was deleted” (SOURCED) |  | `AccountSession.accountDeleted()` → toast on auth.phone |
| matched | token | `auth.phone.layout.inlineError` | presentation: system alert: iOS UIAlertController .alert / SwiftUI .alert, Android M3 AlertDialog; not dismissible by tapping outside; title: none: the auth.… (SOURCED) | how a field-level error (wrong number, wrong or expired code, invalid date) is presented on the sign-up scr… | `formErrorAlert` (Components/FormErrorAlert.swift): system alert, no title, the error sentence as its message, one `auth.phone.error.dismiss` button (+ haptic.global.error) |
| matched | copy | `auth.phone.error.invalidNumber` | “check your number and try again” (SOURCED) |  | `Copy.…authPhoneErrorInvalidNumber` in AuthFailure.swift |
| matched | copy | `auth.phone.error.dismiss` | “OK” (SOURCED) |  | `Copy.…authPhoneErrorDismiss` in FormErrorAlert.swift |
| matched | copy | `auth.phone.error.rateLimited` | “you can ask for a new code in a minute” (SOURCED) |  | `Copy.…authPhoneErrorRateLimited` in AuthFailure.swift |
| matched | copy | `auth.phone.error.sendFailed` | “we couldn’t send your code. try again in a moment.” (SOURCED) |  | `Copy.…authPhoneErrorSendFailed` in AuthFailure.swift |
| matched | token | `fontSize.global.emptyTitle` | 16 pt (SOURCED) | empty-state title ('you created group') | `Tokens.…globalEmptyTitle` in TextRoles.swift |
| matched | token | `fontSize.global.emptyDetail` | 14 pt (SOURCED) | empty-state detail line ('and added mẹ, Anh'), italic | `Tokens.…globalEmptyDetail` in TextRoles.swift |
| matched | token | `color.global.surfaceLight` | #FFFFFF (SOURCED) | light pill fill: secondary buttons ('invite more friends', 'enable', 'new recap'), selected segment pill, '… | `Tokens.…globalSurfaceLight` in LightPill.swift, SegmentedPills.swift |
| matched | token | `groups.screen.radius.lightPill` | 11 pt (SOURCED) | white secondary pill ('invite more friends') corner radius | `Tokens.…groupsScreenRadiusLightPill` in LightPill.swift |
| matched | token | `groups.screen.size.lightPillHeight` | 45 pt (SOURCED) | white secondary pill height ('invite more friends', 205 pt wide = hug + leading icon.global.link) | `Tokens.…groupsScreenSizeLightPillHeight` in LightPill.swift |
| matched | copy | `auth.phone.offline.title` | “you’re offline” (SOURCED) |  | `Copy.…authPhoneOfflineTitle` in AuthFlowView.swift, PhoneScreen.swift |
| matched | copy | `auth.phone.offline.detail` | “connect to the internet to sign up. your next memories are waiting.” (SOURCED) |  | `Copy.…authPhoneOfflineDetail` in AuthFlowView.swift, PhoneScreen.swift |
| matched | copy | `auth.phone.offline.retry` | “try again” (SOURCED) |  | `Copy.…authPhoneOfflineRetry` in AuthFlowView.swift, PhoneScreen.swift |
| matched | token | `duration.global.navigationPush` | 100 ms (SOURCED) | horizontal push to the next screen ('new group' → new group chat after create) | system NavigationStack push |
| matched | token | `spring.global.platformDefault.ios` | response: 0.55; dampingFraction: 1 (PLATFORM) | iOS default animation (SwiftUI Animation.default) for custom motion whose Yope curve was not measurable | `Tokens.…globalPlatformDefaultIos` in SegmentedPills.swift, Toast.swift |
| n/a | token | `spring.global.platformDefault.android` | response: 0.16223; dampingFraction: 1 (PLATFORM) | Android default spring (Compose spring() defaults) for custom motion whose Yope curve was not measurable | Android only |
| matched | token | `layout.global.reduceMotion` | ios: UIAccessibility.isReduceMotionEnabled / @Environment(\.accessibilityReduceMotion); android: Settings.Global.ANIMATOR_DURATION_SCALE == 0 or ValueAnimato… (PLATFORM) | Reduce Motion substitution rule for every token animation (implemented by DSAnimation.reducedMotion / dsMot… | system transitions follow Reduce Motion; custom motion through dsAnimation / dsTransition (cross-fade substitutes) |
| matched | token | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | any task completed successfully (same generator as send) | `Tokens.…globalSuccess` in PhoneScreen.swift |
| matched | token | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | a task failed (send failed) | `Tokens.…globalError` in BlockConfirmation.swift, PhoneScreen.swift |
| matched | token | `layout.global.textStyleMap` | onboardingTitle: largeTitle; sheetTitle: title3; headerTitle: subheadline; listTitle: headline; listSubtitle: subheadline; body: body; button: subheadline; c… (PLATFORM) | iOS Dynamic Type text style each fontSize.global.<role> scales with (SwiftUI Font.TextStyle case; DSTextSty… | `Tokens.…GlobalTextStyleMap` in TextRoles.swift |

## Approximations

- Title–subtitle gap: platform leading (not measured, auth.phone Gaps); the title top stands in for the cap top (SignUpLayout).
- Phone field with the flag: text trailing inset = flagLeading (not specified); the flag emoji is sized to flagHeight and scaled to the slot width.

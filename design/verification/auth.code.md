# Verification — `auth.code` (iOS)

SMS code entry — `Features/Account/Shared/CodeScreen.swift` (also used by the App Clip).

Checklist written from the spec (`design/surfaces/auth.code.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/auth.code.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Reference image(s): `references/auto/yope/frames/a-virgi-7686278541255642390-t31.23-signup-es.png`

Snapshots (CI): `auth.code-default.png`, `auth.code-filled.png`, `auth.code-verifying.png`, `auth.code-offline.png`

**Summary: 44 matched · 1 approximated · 0 not matched (BLOCKED or not buildable) · 0 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | token | `color.global.backgroundDeep` | #000000 (SOURCED) | screen background of the home list, sheets ('new group', 'send to...'), camera, sign-up, profile 'pics' gri… | `Tokens.…globalBackgroundDeep` in SignUpLayout.swift |
| matched | token | `size.global.headerButton` | 44 pt (SOURCED) | circle icon buttons in headers (back, close, download, film-strip, search) | `Tokens.…globalHeaderButton` in HeaderCircleButton.swift |
| matched | token | `color.global.controlOnDeep` | #101010 (SOURCED) | header circle icon buttons on black screens and sheets (✕, download) | `Tokens.…globalControlOnDeep` in HeaderCircleButton.swift |
| matched | token | `icon.global.back` | ios: chevron.left; android: AutoMirrored.Rounded.KeyboardArrowLeft (PLATFORM) | back (‹ in a header circle) | `Tokens.…globalBack` in CodeScreen.swift |
| matched | token | `color.global.textPrimary` | #FFFFFF (SOURCED) | primary text and glyphs | `Tokens.…globalTextPrimary` in CheckRow.swift, EmptyStateView.swift, FloatingTabBar.swift |
| matched | token | `size.global.headerInset` | 11.5 pt (SOURCED) | screen edge to the first / last header circle | `Tokens.…globalHeaderInset` in CodeScreen.swift, SignUpLayout.swift |
| matched | copy | `auth.code.title` | “enter the code” (SOURCED) |  | `Copy.…authCodeTitle` in CodeScreen.swift |
| matched | token | `groups.create.size.sheetTopToTitle` | 71 pt (SOURCED) | sheet top edge to the title's cap top (also the safe-area top to the title on full-screen onboarding steps) | `Tokens.…groupsCreateSizeSheetTopToTitle` in SignUpLayout.swift |
| matched | copy | `auth.code.subtitle` | “we sent it to {phone}” (SOURCED) |  | `Copy.…authCodeSubtitle` in CodeScreen.swift |
| matched | token | `groups.create.size.titleToContent` | 34 pt (SOURCED) | title text bottom (descender) to the first content element | `Tokens.…groupsCreateSizeTitleToContent` in CodeScreen.swift |
| matched | token | `groups.create.size.fieldToButton` | 18 pt (SOURCED) | form field bottom to the primary button top | `Tokens.…groupsCreateSizeFieldToButton` in CodeScreen.swift |
| matched | copy | `auth.code.continue` | “continue” (SOURCED) |  | `Copy.…authCodeContinue` in CodeScreen.swift |
| matched | copy | `auth.code.resend` | “send new code” (SOURCED) |  | `Copy.…authCodeResend` in CodeScreen.swift |
| matched | copy | `auth.code.back.accessibilityLabel` | “change number” (SOURCED) |  | `Copy.…authCodeBackAccessibilityLabel` in CodeScreen.swift |
| matched | token | `auth.phone.fontSize.subtitle` | 14 pt (SOURCED) | italic subtitle under the sign-up title ('to join or create your friends groups') | `Tokens.…authPhoneFontSizeSubtitle` in TextRoles.swift |
| matched | token | `auth.phone.layout.subtitle` | style: italic; weight: regular; color: color.global.textPrimary; align: center (SOURCED) | subtitle text style under the sign-up title | OnboardingTitleBlock subtitle: italic, regular, textPrimary, centred |
| matched | token | `auth.code.layout.codeField` | ios: one TextField, textContentType .oneTimeCode, keyboardType .numberPad; no per-digit boxes (a custom input view cannot show the AutoFill suggestion); andr… (PLATFORM) | verification-code field and its autofill | one FormField, .oneTimeCode / .numberPad (AutoFill suggestion), no per-digit boxes |
| matched | token | `groups.create.color.field` | #141414 (SOURCED) | single-line text field fill on black ('name group (optional)'); reused by every form field on black (auth.*… | `Tokens.…groupsCreateColorField` in FormField.swift |
| matched | token | `size.global.fieldHeight` | 44 pt (SOURCED) | single-line form text field height | `Tokens.…globalFieldHeight` in FormField.swift |
| matched | token | `radius.global.field` | 12 pt (SOURCED) | single-line form text field corners ('name group (optional)') | `Tokens.…globalField` in FormField.swift |
| matched | token | `groups.create.fontSize.fieldText` | 15 pt (SOURCED) | typed text in the form field (centred) | `Tokens.…groupsCreateFontSizeFieldText` in TextRoles.swift |
| matched | token | `groups.create.fontWeight.fieldText` | bold (SOURCED) | typed text weight in the form field | `Tokens.…groupsCreateFontWeightFieldText` in TextRoles.swift |
| matched | token | `color.global.textSecondary` | #969696 (SOURCED) | secondary text, placeholders ('start typing...'), inactive tab-bar glyphs, chevrons inside capsules | `Tokens.…globalTextSecondary` in CheckRow.swift, CodeScreen.swift, EmptyStateView.swift |
| matched | copy | `auth.code.field.placeholder` | “code” (SOURCED) |  | `Copy.…authCodeFieldPlaceholder` in CodeScreen.swift |
| matched | copy | `auth.code.field.accessibilityLabel` | “verification code” (SOURCED) |  | `Copy.…authCodeFieldAccessibilityLabel` in CodeScreen.swift |
| matched | token | `size.global.buttonHeight` | 45 pt (SOURCED) | full-width primary button in a form ('create group') | `Tokens.…globalButtonHeight` in PrimaryButton.swift |
| matched | token | `radius.global.button` | 14 pt (SOURCED) | primary (lime) button corners — not a full pill | `Tokens.…globalButton` in PrimaryButton.swift, TextRoles.swift |
| matched | token | `auth.code.fontSize.textLink` | 14.5 pt (SOURCED) | lime text link ('send new code'; Yope's sign-in link 'probar otras opciones' = 'try other options') | `Tokens.…authCodeFontSizeTextLink` in TextRoles.swift |
| matched | token | `auth.code.fontWeight.textLink` | bold (SOURCED) | lime text link weight | `Tokens.…authCodeFontWeightTextLink` in TextRoles.swift |
| matched | token | `color.global.accent` | #CDFD07 (SOURCED) | brand lime: composer camera button, primary buttons, coach tooltips, toasts, shutter ring, 'today' bar | `Tokens.…globalAccent` in CodeScreen.swift, OnboardingTitle.swift, PrimaryButton.swift |
| matched | token | `auth.code.duration.resendLock` | 60000 ms (VERIFIED) | time after a code request before 'send new code' is enabled | `Tokens.…authCodeDurationResendLock` in CodeModel.swift |
| matched | copy | `auth.code.toast.resent` | “new code sent” (SOURCED) |  | `Copy.…authCodeToastResent` in CodeScreen.swift |
| matched | copy | `groups.create.hud.loading` | “Loading” (SOURCED) |  | `Copy.…groupsCreateHudLoading` in LoadingHUD.swift |
| matched | token | `auth.phone.layout.inlineError` | presentation: system alert: iOS UIAlertController .alert / SwiftUI .alert, Android M3 AlertDialog; not dismissible by tapping outside; title: none: the auth.… (SOURCED) | how a field-level error (wrong number, wrong or expired code, invalid date) is presented on the sign-up scr… | `formErrorAlert` (Components/FormErrorAlert.swift): system alert, no title, the error sentence as its message, one `auth.phone.error.dismiss` button (+ haptic.global.error) |
| matched | copy | `auth.code.error.wrong` | “that code didn’t work. check it and try again.” (SOURCED) |  | `Copy.…authCodeErrorWrong` in AuthFailure.swift |
| matched | copy | `auth.phone.error.dismiss` | “OK” (SOURCED) |  | `Copy.…authPhoneErrorDismiss` in FormErrorAlert.swift |
| matched | copy | `auth.code.error.expired` | “that code expired. send a new one and try again.” (SOURCED) |  | `Copy.…authCodeErrorExpired` in AuthFailure.swift |
| matched | copy | `auth.code.error.tooMany` | “too many tries. wait a minute, then send a new code.” (SOURCED) |  | `Copy.…authCodeErrorTooMany` in AuthFailure.swift |
| matched | copy | `auth.phone.offline.title` | “you’re offline” (SOURCED) |  | `Copy.…authPhoneOfflineTitle` in CodeScreen.swift |
| matched | copy | `auth.code.offline.detail` | “connect to the internet to check your code. your next memories are waiting.” (SOURCED) |  | `Copy.…authCodeOfflineDetail` in CodeScreen.swift |
| matched | copy | `auth.phone.offline.retry` | “try again” (SOURCED) |  | `Copy.…authPhoneOfflineRetry` in CodeScreen.swift |
| matched | token | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | any task completed successfully (same generator as send) | `Tokens.…globalSuccess` in CodeScreen.swift |
| matched | token | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | a task failed (send failed) | `Tokens.…globalError` in BlockConfirmation.swift, CodeScreen.swift |
| matched | token | `safety.block.duration.toast` | 2000 ms (SOURCED) | how long the lime toast stays before it leaves | `Tokens.…safetyBlockDurationToast` in Toast.swift |

## Approximations

- Same sign-up layout approximations as auth.phone (title top, title–subtitle gap).

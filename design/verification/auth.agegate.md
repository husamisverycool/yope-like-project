# Verification — `auth.agegate` (iOS)

Birthday entry and age gate — `Features/Account/Auth/AgeGateScreen.swift`.

Checklist written from the spec (`design/surfaces/auth.agegate.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/auth.agegate.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Snapshots (CI): `auth.agegate-default.png`, `auth.agegate-filled-opt-in.png`, `auth.agegate-invalid-date.png`, `auth.agegate-not-configured.png`, `auth.agegate-offline.png`, `auth.agegate-under-age.png`

**Summary: 48 matched · 2 approximated · 1 not matched (BLOCKED or not buildable) · 0 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | copy | `auth.agegate.title` | “when’s your birthday?” (SOURCED) |  | `Copy.…authAgegateTitle` in AgeGateScreen.swift |
| matched | copy | `auth.agegate.subtitle` | “we use it to check your age. we don’t save it.” (SOURCED) |  | `Copy.…authAgegateSubtitle` in AgeGateScreen.swift |
| matched | token | `groups.create.size.titleToContent` | 34 pt (SOURCED) | title text bottom (descender) to the first content element | `Tokens.…groupsCreateSizeTitleToContent` in AgeGateScreen.swift |
| matched | token | `groups.create.size.fieldToButton` | 18 pt (SOURCED) | form field bottom to the primary button top | `Tokens.…groupsCreateSizeFieldToButton` in AgeGateScreen.swift |
| matched | token | `size.global.buttonMarginH` | 19 pt (SOURCED) | side margin of the form primary button | `Tokens.…globalButtonMarginH` in AgeGateScreen.swift |
| matched | copy | `auth.agegate.continue` | “continue” (SOURCED) |  | `Copy.…authAgegateContinue` in AgeGateScreen.swift |
| matched | token | `auth.phone.fontSize.subtitle` | 14 pt (SOURCED) | italic subtitle under the sign-up title ('to join or create your friends groups') | `Tokens.…authPhoneFontSizeSubtitle` in TextRoles.swift |
| matched | token | `auth.phone.layout.subtitle` | style: italic; weight: regular; color: color.global.textPrimary; align: center (SOURCED) | subtitle text style under the sign-up title | OnboardingTitleBlock subtitle: italic, regular, textPrimary, centred |
| matched | token | `auth.agegate.layout.dateEntry` | control: the Yope form field (groups.create.color.field, size.global.fieldHeight, radius.global.field, groups.create.fontSize.fieldText) with a numeric keybo… (VERIFIED) | birthday entry (neutral age screen) | FormField with numeric keyboard; separators per the locale template "MMddyyyy" (`BirthdayEntry`) |
| matched | token | `groups.create.color.field` | #141414 (SOURCED) | single-line text field fill on black ('name group (optional)'); reused by every form field on black (auth.*… | `Tokens.…groupsCreateColorField` in FormField.swift |
| matched | token | `size.global.fieldHeight` | 44 pt (SOURCED) | single-line form text field height | `Tokens.…globalFieldHeight` in FormField.swift |
| matched | token | `radius.global.field` | 12 pt (SOURCED) | single-line form text field corners ('name group (optional)') | `Tokens.…globalField` in FormField.swift |
| matched | token | `groups.create.fontSize.fieldText` | 15 pt (SOURCED) | typed text in the form field (centred) | `Tokens.…groupsCreateFontSizeFieldText` in TextRoles.swift |
| matched | copy | `auth.agegate.field.placeholder` | “birthday ({date_format})” (SOURCED) |  | `Copy.…authAgegateFieldPlaceholder` in AgeGateModel.swift |
| matched | copy | `auth.agegate.field.accessibilityLabel` | “birthday” (SOURCED) |  | `Copy.…authAgegateFieldAccessibilityLabel` in AgeGateScreen.swift |
| matched | token | `auth.agegate.layout.optIn` | control: row with icon.global.uncheck / icon.global.check (color.global.selection) at size.global.checkCircle, trailing, as in Yope's pickers; default: unche… (SOURCED) | optional 'tell my groups on my birthday' opt-in row | `CheckRow` under the field: check / uncheck glyph at checkCircle in selection colour, label + detail listSubtitle; unchecked by default |
| matched | token | `icon.global.uncheck` | ios: circle; android: Rounded.RadioButtonUnchecked (PLATFORM) | not selected (empty ring) | `Tokens.…globalUncheck` in CheckRow.swift |
| matched | token | `icon.global.check` | ios: checkmark.circle.fill; android: Rounded.CheckCircle (PLATFORM) | selected (filled check circle, color.global.selection) | `Tokens.…globalCheck` in CheckRow.swift |
| matched | token | `color.global.selection` | #0091FF (PLATFORM) | filled check circle on selected people / groups (Yope draws it in iOS system blue) | `Tokens.…globalSelection` in CheckRow.swift |
| matched | token | `size.global.checkCircle` | 24 pt (SOURCED) | selection circle (empty ring / filled check) in pickers and recipient rows | `Tokens.…globalCheckCircle` in CheckRow.swift |
| matched | token | `fontSize.global.listSubtitle` | 14 pt (SOURCED) | row subtitle ('new pic added · 9:43 AM'), secondary color | `Tokens.…globalListSubtitle` in TextRoles.swift |
| matched | token | `color.global.textPrimary` | #FFFFFF (SOURCED) | primary text and glyphs | `Tokens.…globalTextPrimary` in CheckRow.swift, EmptyStateView.swift, FloatingTabBar.swift |
| matched | token | `color.global.textSecondary` | #969696 (SOURCED) | secondary text, placeholders ('start typing...'), inactive tab-bar glyphs, chevrons inside capsules | `Tokens.…globalTextSecondary` in CheckRow.swift, EmptyStateView.swift, FloatingTabBar.swift |
| matched | copy | `auth.agegate.optIn.label` | “tell my groups when it’s my birthday” (SOURCED) |  | `Copy.…authAgegateOptInLabel` in AgeGateScreen.swift |
| matched | copy | `auth.agegate.optIn.detail` | “we’ll save your birthday for this” (SOURCED) |  | `Copy.…authAgegateOptInDetail` in AgeGateScreen.swift |
| matched | copy | `auth.agegate.optIn.accessibilityLabel` | “tell my groups when it’s my birthday” (SOURCED) |  | `Copy.…authAgegateOptInAccessibilityLabel` in AgeGateScreen.swift |
| matched | token | `groups.create.color.hud` | #0C0C0C (SOURCED) | Loading HUD square fill (on black) | `Tokens.…groupsCreateColorHud` in LoadingHUD.swift |
| matched | token | `groups.create.size.hud` | 100 pt (SOURCED) | Loading HUD square side | `Tokens.…groupsCreateSizeHud` in LoadingHUD.swift |
| matched | token | `groups.create.fontSize.hudLabel` | 15 pt (SOURCED) | 'Loading' label under the spinner in the HUD | `Tokens.…groupsCreateFontSizeHudLabel` in TextRoles.swift |
| matched | copy | `groups.create.hud.loading` | “Loading” (SOURCED) |  | `Copy.…groupsCreateHudLoading` in LoadingHUD.swift |
| matched | token | `auth.phone.layout.inlineError` | presentation: system alert: iOS UIAlertController .alert / SwiftUI .alert, Android M3 AlertDialog; not dismissible by tapping outside; title: none: the auth.… (SOURCED) | how a field-level error (wrong number, wrong or expired code, invalid date) is presented on the sign-up scr… | `formErrorAlert` (Components/FormErrorAlert.swift): system alert, no title, the error sentence as its message, one `auth.phone.error.dismiss` button (+ haptic.global.error) |
| matched | copy | `auth.agegate.error.invalidDate` | “check the date and try again” (SOURCED) |  | `Copy.…authAgegateErrorInvalidDate` in AgeGateScreen.swift |
| matched | copy | `auth.phone.error.dismiss` | “OK” (SOURCED) |  | `Copy.…authPhoneErrorDismiss` in FormErrorAlert.swift |
| matched | token | `fontSize.global.emptyTitle` | 16 pt (SOURCED) | empty-state title ('you created group') | `Tokens.…globalEmptyTitle` in TextRoles.swift |
| matched | token | `fontSize.global.emptyDetail` | 14 pt (SOURCED) | empty-state detail line ('and added mẹ, Anh'), italic | `Tokens.…globalEmptyDetail` in TextRoles.swift |
| matched | token | `color.global.surfaceLight` | #FFFFFF (SOURCED) | light pill fill: secondary buttons ('invite more friends', 'enable', 'new recap'), selected segment pill, '… | `Tokens.…globalSurfaceLight` in LightPill.swift, SegmentedPills.swift |
| matched | token | `groups.screen.radius.lightPill` | 11 pt (SOURCED) | white secondary pill ('invite more friends') corner radius | `Tokens.…groupsScreenRadiusLightPill` in LightPill.swift |
| matched | token | `groups.screen.size.lightPillHeight` | 45 pt (SOURCED) | white secondary pill height ('invite more friends', 205 pt wide = hug + leading icon.global.link) | `Tokens.…groupsScreenSizeLightPillHeight` in LightPill.swift |
| matched | copy | `auth.agegate.notConfigured.title` | “sign-up isn’t open yet” (SOURCED) |  | `Copy.…authAgegateNotConfiguredTitle` in AgeGateScreen.swift |
| matched | copy | `auth.agegate.notConfigured.detail` | “try again soon. your next memories are waiting.” (SOURCED) |  | `Copy.…authAgegateNotConfiguredDetail` in AgeGateScreen.swift |
| matched | copy | `auth.agegate.notConfigured.retry` | “try again” (SOURCED) |  | `Copy.…authAgegateNotConfiguredRetry` in AgeGateScreen.swift |
| not matched | copy | `auth.agegate.underAge.title` | “you need to be {min_age} or older to use {app_name}” (SOURCED) |  | uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (AccountBlockedCopy.swift); omitted in release |
| matched | copy | `auth.agegate.underAge.detail` | “we didn’t save your birthday or your number.” (SOURCED) |  | `Copy.…authAgegateUnderAgeDetail` in AgeGateScreen.swift |
| matched | copy | `auth.phone.offline.title` | “you’re offline” (SOURCED) |  | `Copy.…authPhoneOfflineTitle` in AgeGateScreen.swift |
| matched | copy | `auth.agegate.offline.detail` | “connect to the internet to keep going. your next memories are waiting.” (SOURCED) |  | `Copy.…authAgegateOfflineDetail` in AgeGateScreen.swift |
| matched | copy | `auth.phone.offline.retry` | “try again” (SOURCED) |  | `Copy.…authPhoneOfflineRetry` in AgeGateScreen.swift |
| matched | token | `haptic.global.select` | ios: selection; android: SEGMENT_TICK (PLATFORM) | a recipient / group toggled, a segmented choice, picker scrubbing | `Tokens.…globalSelect` in CheckRow.swift, SegmentedPills.swift |
| matched | token | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | any task completed successfully (same generator as send) | `Tokens.…globalSuccess` in AgeGateScreen.swift |
| matched | token | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | a task failed (send failed) | `Tokens.…globalError` in AgeGateScreen.swift, BlockConfirmation.swift |

## Approximations

- Same sign-up layout approximations as auth.phone.
- Under-age refusal: `delete_account`, falling back to sign-out when deletion fails; the refusal is kept in the Keychain (survives reinstall).

## Not matched

- `auth.agegate.underAge.title` — uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (AccountBlockedCopy.swift); omitted in release

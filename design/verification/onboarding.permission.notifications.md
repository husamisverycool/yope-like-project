# Verification — `onboarding.permission.notifications` (iOS)

Notifications pre-alert step — `Features/Account/Onboarding/NotificationsPermissionScreen.swift`.

Checklist written from the spec (`design/surfaces/onboarding.permission.notifications.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/onboarding.permission.notifications.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Reference image(s): `references/auto/yope/frames/a-virgi-7686278541255642390-t7.23-notif-preprompt-es.png`, `references/auto/yope/frames/a-virgi-7686278541255642390-t9.23-notif-system-alert-es.png`, `references/auto/yope/frames/a-virgi-7686278541255642390-t11.23-widget-preprompt-es.png`, `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png`, `references/auto/yope/frames/a-virgi-7686278541255642390-t31.23-signup-es.png`

Snapshots (CI): `onboarding.permission.notifications-default.png`

**Summary: 17 matched · 0 approximated · 1 not matched (BLOCKED or not buildable) · 3 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | token | `color.global.backgroundDeep` | #000000 (SOURCED) | screen background of the home list, sheets ('new group', 'send to...'), camera, sign-up, profile 'pics' gri… | `Tokens.…globalBackgroundDeep` in NotificationsPermissionScreen.swift, SignUpLayout.swift |
| matched | token | `onboarding.permission.notifications.layout.preAlert` | ios: one button ('continue') that triggers UNUserNotificationCenter.requestAuthorization; no close, skip or back on this screen; android: API 33+: same scree… (VERIFIED) | notifications pre-alert screen | one lime button → UNUserNotificationCenter.requestAuthorization (via PushService); no close / skip / back |
| matched | copy | `onboarding.permission.notifications.title` | “want to know when your groups post?” (SOURCED) |  | `Copy.…onboardingPermissionNotificationsTitle` in NotificationsPermissionScreen.swift |
| matched | token | `groups.create.size.sheetTopToTitle` | 71 pt (SOURCED) | sheet top edge to the title's cap top (also the safe-area top to the title on full-screen onboarding steps) | `Tokens.…groupsCreateSizeSheetTopToTitle` in NotificationsPermissionScreen.swift, SignUpLayout.swift |
| matched | copy | `onboarding.permission.notifications.detail` | “enable notifications” (SOURCED) |  | `Copy.…onboardingPermissionNotificationsDetail` in NotificationsPermissionScreen.swift |
| n/a | copy | `onboarding.permission.notifications.skip` | “maybe later” (SOURCED) |  | Android only |
| matched | token | `size.global.buttonMarginHSheet` | 27 pt (SOURCED) | side margin of the sheet-bottom primary button | `Tokens.…globalButtonMarginHSheet` in NotificationsPermissionScreen.swift |
| matched | token | `size.global.buttonHeightSheet` | 47 pt (SOURCED) | primary action button at the bottom of a sheet ('send ⓝ') | `Tokens.…globalButtonHeightSheet` in PrimaryButton.swift |
| n/a | token | `onboarding.permission.notifications.size.buttonGap` | 8 pt (SOURCED) | vertical gap between the stacked dark and lime buttons (Android) | Android only |
| matched | copy | `onboarding.permission.notifications.continue` | “continue” (SOURCED) |  | `Copy.…onboardingPermissionNotificationsContinue` in NotificationsPermissionScreen.swift |
| matched | token | `fontSize.global.onboardingTitle` | 40 pt (SOURCED) | onboarding / sign-up big title ('registrarse') | `Tokens.…globalOnboardingTitle` in TextRoles.swift |
| matched | token | `fontWeight.global.onboardingTitle` | heavy (SOURCED) | onboarding / sign-up big title | `Tokens.…fontWeightGlobalOnboardingTitle` in TextRoles.swift |
| matched | token | `color.global.textPrimary` | #FFFFFF (SOURCED) | primary text and glyphs | `Tokens.…globalTextPrimary` in CheckRow.swift, EmptyStateView.swift, FloatingTabBar.swift |
| matched | token | `auth.phone.fontSize.subtitle` | 14 pt (SOURCED) | italic subtitle under the sign-up title ('to join or create your friends groups') | `Tokens.…authPhoneFontSizeSubtitle` in TextRoles.swift |
| matched | token | `auth.phone.layout.subtitle` | style: italic; weight: regular; color: color.global.textPrimary; align: center (SOURCED) | subtitle text style under the sign-up title | OnboardingTitleBlock subtitle: italic, regular, textPrimary, centred |
| matched | token | `color.global.accent` | #CDFD07 (SOURCED) | brand lime: composer camera button, primary buttons, coach tooltips, toasts, shutter ring, 'today' bar | `Tokens.…globalAccent` in OnboardingTitle.swift, PrimaryButton.swift, Toast.swift |
| matched | token | `color.global.onAccent` | #000000 (SOURCED) | text and glyphs on lime: camera glyph on the composer button, primary button labels, tooltip text | `Tokens.…globalOnAccent` in PrimaryButton.swift, Toast.swift |
| matched | token | `radius.global.button` | 14 pt (SOURCED) | primary (lime) button corners — not a full pill | `Tokens.…globalButton` in PrimaryButton.swift, TextRoles.swift |
| n/a | token | `onboarding.permission.notifications.color.secondaryButton` | #171717 (SOURCED) | dark secondary button fill on black ('maybe later', Android only) | Android only |
| not matched | copy | `settings.notifications.off.footer` | “Notifications are off for {app_name}. You can turn them on in Settings.” (VERIFIED) |  | BLOCKED copy (uses {app_name}): DEBUG builds only (`AccountBlockedCopy.notificationsOffFooter`) |
| matched | copy | `settings.notifications.openSettings` | “Open Settings” (VERIFIED) |  | groups.settings / settings.notifications "open settings" row |

## Not matched

- `settings.notifications.off.footer` — BLOCKED copy (uses {app_name}): DEBUG builds only (`AccountBlockedCopy.notificationsOffFooter`)

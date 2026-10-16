# Verification — `onboarding.permission.notifications` (iOS, Pass 4 — Retro redesign)

Notifications pre-alert — `Features/Account/Onboarding/NotificationsPermissionScreen.swift`.

Checklist written from the spec (`design/surfaces/onboarding.permission.notifications.md`) against the iOS code: every token and copy key the spec names, its reference value, and where the iOS code uses it. The snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (AccountSnapshotTests: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/onboarding.permission.notifications.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`, `references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png`

Snapshots (CI, `ios/build/snapshots/account/`): `onboarding.permission.notifications-default-light.png`, `onboarding.permission.notifications-default-dark.png`

**Summary: 14 matched · 0 approximated · 0 not matched · 5 not applicable on iOS / owner / another pass.**


## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `onboarding.permission.notifications.layout.preAlert` | structure: onboarding page (C-33 variant): display title (text role displayMedium) + explanation (text role body, color.global.textSecondary) leading-aligned… (VERIFIED) | this page, then `requestAuthorization` on Continue (HIG pre-alert, no skip on iOS) |

## References

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `auth.phone.size.capsuleToLink` | 20.7 pt (SOURCED) | `Tokens.Sizes.authPhoneSizeCapsuleToLink` in PhoneScreen.swift, ProfileScreen.swift |

## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `color.global.background` | light: #FFFFFF; dark: #000000 (SOURCED) | `Tokens.Colors.globalBackground` in AccountGroupedRows.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, GroupScreen.swift … |
| matched | `onboarding.permission.notifications.title` | “Never miss a moment” (SOURCED) | `Copy.onboardingPermissionNotificationsTitle` in NotificationsPermissionScreen.swift |
| matched | `font.global.display` | ios: system-serif; android: serif (PLATFORM) | `Tokens.Fonts.globalDisplay` in InvitePreviewView.swift, PhoneScreen.swift, TextRoles.swift |
| matched | `color.global.textPrimary` | light: #000000; dark: #FFFFFF (SOURCED) | `Tokens.Colors.globalTextPrimary` in AccountGroupedRows.swift, CapsuleButton.swift, CheckRow.swift, CircleButton.swift … |
| matched | `size.global.screenMargin` | 16 pt (SOURCED) | `Tokens.Sizes.globalScreenMargin` in AccountGroupedRows.swift, AgeGateForm.swift, CodeScreen.swift, EmptyStateView.swift … |
| matched | `size.global.titleTop` | 64 pt (SOURCED) | `Tokens.Sizes.globalTitleTop` in FullBleedMediaPage.swift, GroupScreen.swift, ScreenHeader.swift, SignUpLayout.swift |
| matched | `onboarding.permission.notifications.detail` | “Do you want to get notifications for new photos, messages, and other activity in your groups?” (SOURCED) | `Copy.onboardingPermissionNotificationsDetail` in NotificationsPermissionScreen.swift |
| matched | `color.global.textSecondary` | #999999 (SOURCED) | `Tokens.Colors.globalTextSecondary` in AccountGroupedRows.swift, Avatar.swift, CheckRow.swift, CodeScreen.swift … |
| matched | `onboarding.permission.notifications.continue` | “Enable notifications” (SOURCED) | `Copy.onboardingPermissionNotificationsContinue` in NotificationsPermissionScreen.swift |
| matched | `size.global.buttonMarginH` | 20 pt (SOURCED) | `Tokens.Sizes.globalButtonMarginH` in BackdropCard.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, OnboardingTitle.swift … |
| n/a | `onboarding.permission.notifications.skip` | “Maybe later” (SOURCED) | Android only (iOS: no skip, spec Platform notes) |

## Elements

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `settings.account.layout.alert` | ios: alert(_:isPresented:actions:message:): destructive-role button + Cancel; at most 3 buttons; Cancel is never the default; android: M3 AlertDialog: contai… (VERIFIED) | native `.alert` / `.confirmationDialog` (C-29) |
| n/a | `system.permissions.rationale.notifications.title` | “Never miss a moment” (SOURCED) | Android rationale dialog only |
| n/a | `system.permissions.rationale.notNow` | “Not now” (SOURCED) | Android rationale dialog only |
| n/a | `system.permissions.rationale.continue` | “Give Permission” (SOURCED) | Android rationale dialog only |

## Motion

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `duration.global.pageTransition` | 500 ms (SOURCED) | `Tokens.Durations.globalPageTransition` in PaywallScreen.swift, PhoneScreen.swift, ProfileScreen.swift |

## Haptics

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | Android only — iOS presses play no haptic |

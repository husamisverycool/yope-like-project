# Verification — `onboarding.widget` (iOS, Pass 4 — Retro redesign)

Add-the-widget steps — `Features/Account/Onboarding/WidgetGuideScreen.swift`, `Auth/AuthFlowView.swift` (`WidgetGuideRoute`), `Settings/SettingsRootScreen.swift` (`SettingsWidgetsPage`).

Checklist written from the spec (`design/surfaces/onboarding.widget.md`) against the iOS code: every token and copy key the spec names, its reference value, and where the iOS code uses it. The snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (AccountSnapshotTests: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/onboarding.widget.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/apk/widget_preview_friends.webp`, `references/auto/retro/apk/retro-android-2026.10.1150-excerpts.txt`, `references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png`, `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`

Snapshots (CI, `ios/build/snapshots/account/`): `onboarding.widget-default-light.png`, `onboarding.widget-default-dark.png`, `onboarding.widget-no-photo-light.png`, `onboarding.widget-from-settings-light.png`

**Summary: 29 matched · 0 approximated · 0 not matched · 5 not applicable on iOS / owner / another pass.**


## References

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `onboarding.widget.size.preview` | 158 pt (SOURCED) | `Tokens.Sizes.onboardingWidgetSizePreview` in WidgetGuideScreen.swift |
| matched | `onboarding.widget.radius.preview` | 22 pt (SOURCED) | `Tokens.Radii.onboardingWidgetRadiusPreview` in WidgetGuideScreen.swift |

## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `color.global.background` | light: #FFFFFF; dark: #000000 (SOURCED) | `Tokens.Colors.globalBackground` in AccountGroupedRows.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, GroupScreen.swift … |
| matched | `onboarding.widget.title` | “Widgets for your home screen” (SOURCED) | `Copy.onboardingWidgetTitle` in WidgetGuideScreen.swift |
| matched | `font.global.display` | ios: system-serif; android: serif (PLATFORM) | `Tokens.Fonts.globalDisplay` in InvitePreviewView.swift, PhoneScreen.swift, TextRoles.swift |
| matched | `size.global.titleTop` | 64 pt (SOURCED) | `Tokens.Sizes.globalTitleTop` in FullBleedMediaPage.swift, GroupScreen.swift, ScreenHeader.swift, SignUpLayout.swift |
| matched | `onboarding.widget.detail` | “Never miss a moment from your groups — right on your home screen.” (SOURCED) | `Copy.onboardingWidgetDetail` in WidgetGuideScreen.swift |
| matched | `color.global.textSecondary` | #999999 (SOURCED) | `Tokens.Colors.globalTextSecondary` in AccountGroupedRows.swift, Avatar.swift, CheckRow.swift, CodeScreen.swift … |
| matched | `size.global.titleToContent` | 30 pt (SOURCED) | `Tokens.Sizes.globalTitleToContent` in AccountGroupedRows.swift, AgeGateForm.swift, GroupCreateScreen.swift, GroupInviteScreen.swift … |
| matched | `layout.global.cornerStyle` | ios: continuous (RoundedRectangle(cornerRadius:style: .continuous)); android: circular (RoundedCornerShape) (SOURCED) | `DSShape.rounded` (continuous corners) |
| matched | `layout.global.photoScrim` | color: #000000; startAt: 0.55; startOpacity: 0; endOpacity: 0.6; direction: top → bottom (SOURCED) | `Tokens.Layouts.GlobalPhotoScrim` in ComponentSupport.swift |
| matched | `color.global.textOnMedia` | #FFFFFF (SOURCED) | `Tokens.Colors.globalTextOnMedia` in CircleButton.swift, FullBleedMediaPage.swift, GroupScreen.swift, InvitePreviewView.swift … |
| matched | `color.global.control` | light: #F1F1F1; dark: #262626 (SOURCED) | `Tokens.Colors.globalControl` in AccountGroupedRows.swift, Avatar.swift, CapsuleButton.swift, CircleButton.swift … |
| matched | `icon.global.gallery` | ios: photo.on.rectangle; android: Outlined.PhotoLibrary (PLATFORM) | `Tokens.Icons.globalGallery` in WidgetGuideScreen.swift |
| matched | `size.global.sectionHeaderToContent` | 11.7 pt (SOURCED) | `Tokens.Sizes.globalSectionHeaderToContent` in CodeScreen.swift, GroupInviteScreen.swift, GroupScreen.swift, GroupsHomeScreen.swift … |
| matched | `widget.home.small.gallery.name` | “Group Updates” (SOURCED) | `Copy.widgetHomeSmallGalleryName` in WidgetGuideScreen.swift |
| matched | `onboarding.widget.step.ios.1` | “From your Home Screen, touch and hold a widget or empty area until the apps jiggle.” (SOURCED) | `Copy.onboardingWidgetStepIos1` in WidgetGuideScreen.swift |
| matched | `size.global.circleButton` | 36 pt (SOURCED) | `Tokens.Sizes.globalCircleButton` in CircleButton.swift, GroupsHomeScreen.swift, SheetChrome.swift, WidgetGuideScreen.swift |
| matched | `color.global.textPrimary` | light: #000000; dark: #FFFFFF (SOURCED) | `Tokens.Colors.globalTextPrimary` in AccountGroupedRows.swift, CapsuleButton.swift, CheckRow.swift, CircleButton.swift … |
| matched | `size.global.rowThumbGap` | 17 pt (SOURCED) | `Tokens.Sizes.globalRowThumbGap` in GroupsHomeScreen.swift, ThumbnailRow.swift, WidgetGuideScreen.swift |
| matched | `onboarding.widget.done` | “You're done!” (SOURCED) | `Copy.onboardingWidgetDone` in WidgetGuideScreen.swift |
| matched | `widget.arrival.help.delay` | “New photos can take a few minutes to show up on your widget. This helps save your battery.” (SOURCED) | `Copy.widgetArrivalHelpDelay` in WidgetGuideScreen.swift |
| matched | `onboarding.widget.continue` | “Next” (SOURCED) | `Copy.onboardingWidgetContinue` in WidgetGuideScreen.swift |
| n/a | `onboarding.widget.add` | “Add Widget” (SOURCED) | Android only (pin request) |
| matched | `auth.phone.size.capsuleToLink` | 20.7 pt (SOURCED) | `Tokens.Sizes.authPhoneSizeCapsuleToLink` in PhoneScreen.swift, ProfileScreen.swift |
| n/a | `onboarding.widget.skip` | “Maybe later” (SOURCED) | Android only |

## Elements

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `onboarding.widget.preview.accessibilityLabel` | “Widget preview” (VERIFIED) | `Copy.onboardingWidgetPreviewAccessibilityLabel` in WidgetGuideScreen.swift |
| matched | `onboarding.widget.stepNumber.accessibilityLabel` | “Step {number}” (VERIFIED) | `Copy.onboardingWidgetStepNumberAccessibilityLabel` in WidgetGuideScreen.swift |
| n/a | `onboarding.widget.added` | “Widget added to your home screen” (SOURCED) | Android only (pin result toast) |
| n/a | `onboarding.widget.pinFailed` | “Couldn't add the widget. Please try again.” (SOURCED) | Android only (pin result toast) |

## Motion

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `duration.global.pageTransition` | 500 ms (SOURCED) | `Tokens.Durations.globalPageTransition` in PaywallScreen.swift, PhoneScreen.swift, ProfileScreen.swift |
| matched | `duration.global.fade` | 150 ms (SOURCED) | `Tokens.Durations.globalFade` in ComponentSupport.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, PaywallScreen.swift … |

## Haptics

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | Android only — iOS presses play no haptic |
| matched | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | `Tokens.Haptics.globalSuccess` in AgeGateForm.swift, CodeScreen.swift, GroupCreateScreen.swift, InviteClipApp.swift … |

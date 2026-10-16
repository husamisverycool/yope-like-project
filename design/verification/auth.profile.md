# Verification — `auth.profile` (iOS, Pass 4 — Retro redesign)

Name (step 1) and profile photo (step 2) — `Features/Account/Shared/ProfileNameForm.swift`, `Auth/ProfileScreen.swift` (`ProfilePhotoStep`), `Shared/ProfileModel.swift`.

Checklist written from the spec (`design/surfaces/auth.profile.md`) against the iOS code: every token and copy key the spec names, its reference value, and where the iOS code uses it. The snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (AccountSnapshotTests: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/auth.profile.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`, `references/auto/retro/web/retro.app-5bff8a0be69f7ec7.css`, `references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png`

Snapshots (CI, `ios/build/snapshots/account/`): `auth.profile-name-light.png`, `auth.profile-name-dark.png`, `auth.profile-name-filled-light.png`, `auth.profile-name-too-long-light.png`, `auth.profile-saving-name-light.png`, `auth.profile-offline-light.png`, `auth.profile-photo-empty-light.png`, `auth.profile-photo-empty-dark.png`, `auth.profile-photo-chosen-light.png`, `auth.profile-uploading-light.png`

**Summary: 36 matched · 0 approximated · 0 not matched · 1 not applicable on iOS / owner / another pass.**


## References

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `auth.profile.size.avatar` | 112 pt (SOURCED) | `Tokens.Sizes.authProfileSizeAvatar` in ProfileScreen.swift |

## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `auth.profile.title` | “What's your name?” (SOURCED) | `Copy.authProfileTitle` in ProfileNameForm.swift |
| matched | `font.global.display` | ios: system-serif; android: serif (PLATFORM) | `Tokens.Fonts.globalDisplay` in InvitePreviewView.swift, PhoneScreen.swift, TextRoles.swift |
| matched | `size.global.titleTop` | 64 pt (SOURCED) | `Tokens.Sizes.globalTitleTop` in FullBleedMediaPage.swift, GroupScreen.swift, ScreenHeader.swift, SignUpLayout.swift |
| matched | `auth.profile.subtitle` | “This is how you'll show up in your groups.” (SOURCED) | `Copy.authProfileSubtitle` in ProfileNameForm.swift |
| matched | `color.global.textSecondary` | #999999 (SOURCED) | `Tokens.Colors.globalTextSecondary` in AccountGroupedRows.swift, Avatar.swift, CheckRow.swift, CodeScreen.swift … |
| matched | `size.global.titleToContent` | 30 pt (SOURCED) | `Tokens.Sizes.globalTitleToContent` in AccountGroupedRows.swift, AgeGateForm.swift, GroupCreateScreen.swift, GroupInviteScreen.swift … |
| matched | `auth.profile.field.placeholder` | “Enter your full name…” (SOURCED) | `Copy.authProfileFieldPlaceholder` in ProfileNameForm.swift |
| matched | `size.global.sectionHeaderToContent` | 11.7 pt (SOURCED) | `Tokens.Sizes.globalSectionHeaderToContent` in CodeScreen.swift, GroupInviteScreen.swift, GroupScreen.swift, GroupsHomeScreen.swift … |
| matched | `auth.profile.field.note` | “Your first name shows on invite links you share.” (SOURCED) | `Copy.authProfileFieldNote` in ProfileNameForm.swift |
| matched | `auth.profile.continue` | “Next” (SOURCED) | `Copy.authProfileContinue` in ProfileNameForm.swift, ProfileScreen.swift |
| matched | `size.global.buttonMarginH` | 20 pt (SOURCED) | `Tokens.Sizes.globalButtonMarginH` in BackdropCard.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, OnboardingTitle.swift … |
| matched | `auth.profile.photo.title` | “Add a profile photo” (SOURCED) | `Copy.authProfilePhotoTitle` in ProfileScreen.swift |
| matched | `auth.profile.photo.subtitle` | “Add a profile photo to help your groups recognize you.” (SOURCED) | `Copy.authProfilePhotoSubtitle` in ProfileScreen.swift |
| matched | `color.global.control` | light: #F1F1F1; dark: #262626 (SOURCED) | `Tokens.Colors.globalControl` in AccountGroupedRows.swift, Avatar.swift, CapsuleButton.swift, CircleButton.swift … |
| matched | `icon.global.person` | ios: person.fill; android: Rounded.Person (PLATFORM) | `Tokens.Icons.globalPerson` in Avatar.swift, SettingsBlockedScreen.swift |
| matched | `auth.profile.avatar.add` | “Choose photo” (SOURCED) | `Copy.authProfileAvatarAdd` in ProfileScreen.swift |
| matched | `auth.phone.size.capsuleToLink` | 20.7 pt (SOURCED) | `Tokens.Sizes.authPhoneSizeCapsuleToLink` in PhoneScreen.swift, ProfileScreen.swift |
| matched | `auth.profile.photo.skip` | “Maybe Later” (SOURCED) | `Copy.authProfilePhotoSkip` in ProfileScreen.swift |
| matched | `auth.profile.avatar.edit` | “Edit photo” (SOURCED) | `Copy.authProfileAvatarEdit` in ProfileScreen.swift |

## Elements

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `auth.profile.field.accessibilityLabel` | “Full name” (VERIFIED) | `Copy.authProfileFieldAccessibilityLabel` in ProfileNameForm.swift |
| matched | `color.global.destructive` | #EA3337 (SOURCED) | `Tokens.Colors.globalDestructive` in AccountGroupedRows.swift, DestructiveButton.swift, FormField.swift, GroupInviteScreen.swift … |
| matched | `auth.profile.error.tooLong` | “Name too long” (SOURCED) | `Copy.authProfileErrorTooLong` in ProfileNameForm.swift |
| matched | `radius.global.capsule` | shape: capsule; radius: height / 2 (SOURCED) | `Capsule()` shapes of C-05 / C-06 / C-09 |
| matched | `auth.profile.layout.avatarPicker` | ios: PhotosPicker (SwiftUI) / PHPickerViewController, single image, no library permission; android: ActivityResultContracts.PickVisualMedia(ImageOnly), no RE… (PLATFORM) | `.photosPicker(matching: .images)` (system picker, no library permission) |
| matched | `auth.profile.avatar.accessibilityLabel` | “Profile photo” (VERIFIED) | `Copy.authProfileAvatarAccessibilityLabel` in ProfileScreen.swift |
| matched | `auth.profile.avatar.changeAccessibilityLabel` | “Edit photo” (VERIFIED) | `Copy.authProfileAvatarChangeAccessibilityLabel` in ProfileScreen.swift |

## States

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `auth.phone.layout.inlineError` | presentation: native alert: iOS SwiftUI .alert / Android M3 AlertDialog (settings.account.layout.alert); not dismissed by tapping outside; titled: code error… (SOURCED) | `formErrorAlert(_:trigger:)` (C-29 native message-only alert); code errors: titled alert with Retro's two recoveries |
| matched | `auth.profile.error.save` | “There was a problem. Please try again.” (SOURCED) | `Copy.authProfileErrorSave` in ProfileModel.swift |
| matched | `auth.phone.error.dismiss` | “OK” (VERIFIED) | `Copy.authPhoneErrorDismiss` in CodeScreen.swift, FormErrorAlert.swift, ReportFlow.swift |
| matched | `auth.profile.error.upload` | “Your photo didn't upload. Please try again.” (SOURCED) | `Copy.authProfileErrorUpload` in ProfileModel.swift |

## Motion

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `duration.global.pageTransition` | 500 ms (SOURCED) | `Tokens.Durations.globalPageTransition` in PaywallScreen.swift, PhoneScreen.swift, ProfileScreen.swift |
| matched | `easing.global.standard` | x1: 0.4; y1: 0; x2: 0.2; y2: 1 (SOURCED) | `Tokens.Easings.globalStandard` in AgeGateForm.swift, ComponentSupport.swift, GroupCreateScreen.swift, GroupInviteScreen.swift … |
| matched | `duration.global.fade` | 150 ms (SOURCED) | `Tokens.Durations.globalFade` in ComponentSupport.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, PaywallScreen.swift … |

## Haptics

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | Android only — iOS presses play no haptic |
| matched | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | `Tokens.Haptics.globalSuccess` in AgeGateForm.swift, CodeScreen.swift, GroupCreateScreen.swift, InviteClipApp.swift … |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | `Tokens.Haptics.globalError` in AgeGateForm.swift, BlockConfirmation.swift, CodeScreen.swift, GroupCreateScreen.swift … |

## Notes

- Step 2 is skipped in the App Clip (the full app finishes onboarding).

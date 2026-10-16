# Verification — `groups.create` (iOS, Pass 4 — Retro redesign)

Create / edit a group (sheet: type, then cover and name) — `Features/Account/Groups/GroupCreateScreen.swift` (`GroupCreateView`, `GroupCover`), `GroupCreateModel.swift`, `GroupKindCopy.swift`.

Checklist written from the spec (`design/surfaces/groups.create.md`) against the iOS code: every token and copy key the spec names, its reference value, and where the iOS code uses it. The snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (AccountSnapshotTests: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/groups.create.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/press/jeddacp-2024-05-home-profile-journals.png`, `references/auto/retro/press/tc-2024-04-journals-1.webp`, `references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png`, `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`

Snapshots (CI, `ios/build/snapshots/account/`): `groups.create-type-light.png`, `groups.create-type-dark.png`, `groups.create-details-light.png`, `groups.create-details-dark.png`, `groups.create-filled-light.png`, `groups.create-name-too-long-light.png`, `groups.create-creating-light.png`, `groups.create-edit-light.png`

**Summary: 44 matched · 0 approximated · 0 not matched · 1 not applicable on iOS / owner / another pass.**


## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `groups.screen.shadow.cover` | color: #000000; blur: 8.5; x: 3; y: 10; opacity: 0.25 (SOURCED) | `Tokens.Shadows.groupsScreenShadowCover` in GroupCreateScreen.swift |
| matched | `color.global.background` | light: #FFFFFF; dark: #000000 (SOURCED) | `Tokens.Colors.globalBackground` in AccountGroupedRows.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, GroupScreen.swift … |
| matched | `size.global.circleButton` | 36 pt (SOURCED) | `Tokens.Sizes.globalCircleButton` in CircleButton.swift, GroupsHomeScreen.swift, SheetChrome.swift, WidgetGuideScreen.swift |
| matched | `color.global.control` | light: #F1F1F1; dark: #262626 (SOURCED) | `Tokens.Colors.globalControl` in AccountGroupedRows.swift, Avatar.swift, CapsuleButton.swift, CircleButton.swift … |
| matched | `icon.global.close` | ios: xmark; android: Rounded.Close (PLATFORM) | `Tokens.Icons.globalClose` in PaywallScreen.swift, PermissionCard.swift, SheetChrome.swift, ViewerChrome.swift |
| matched | `groups.create.title` | “New Group” (SOURCED) | `Copy.groupsCreateTitle` in GroupCreateScreen.swift |
| matched | `size.global.titleToContent` | 30 pt (SOURCED) | `Tokens.Sizes.globalTitleToContent` in AccountGroupedRows.swift, AgeGateForm.swift, GroupCreateScreen.swift, GroupInviteScreen.swift … |
| matched | `groups.create.type.label` | “What kind of group is this?” (SOURCED) | `Copy.groupsCreateTypeLabel` in GroupCreateScreen.swift |
| matched | `font.global.display` | ios: system-serif; android: serif (PLATFORM) | `Tokens.Fonts.globalDisplay` in InvitePreviewView.swift, PhoneScreen.swift, TextRoles.swift |
| matched | `size.global.listGap` | 22.5 pt (SOURCED) | `Tokens.Sizes.globalListGap` in ThumbnailRow.swift |
| matched | `groups.create.type.create` | “Create” (SOURCED) | `Copy.groupsCreateTypeCreate` in GroupsHomeScreen.swift |
| matched | `groups.create.titleEdit` | “Edit Group” (SOURCED) | `Copy.groupsCreateTitleEdit` in GroupCreateScreen.swift |
| matched | `groups.screen.size.coverWidth` | 173.5 pt (SOURCED) | `Tokens.Sizes.groupsScreenSizeCoverWidth` in GroupCreateScreen.swift, GroupScreen.swift |
| matched | `radius.global.thumbnail` | 4 pt (SOURCED) | `Tokens.Radii.globalThumbnail` in GroupCreateScreen.swift, GroupsHomeScreen.swift, ThumbnailRow.swift |
| matched | `groups.screen.size.coverToTitle` | 36.7 pt (SOURCED) | `Tokens.Sizes.groupsScreenSizeCoverToTitle` in GroupCreateScreen.swift, GroupScreen.swift |
| matched | `icon.global.add` | ios: plus; android: Rounded.Add (PLATFORM) | `Tokens.Icons.globalAdd` in GroupScreen.swift, GroupsHomeScreen.swift, OutlineCTA.swift, ThumbnailRow.swift … |
| matched | `groups.create.cover.add` | “Add cover image” (SOURCED) | `Copy.groupsCreateCoverAdd` in GroupCreateScreen.swift |
| matched | `groups.create.cover.edit` | “Edit cover image” (SOURCED) | `Copy.groupsCreateCoverEdit` in GroupCreateScreen.swift |
| matched | `size.global.screenMargin` | 16 pt (SOURCED) | `Tokens.Sizes.globalScreenMargin` in AccountGroupedRows.swift, AgeGateForm.swift, CodeScreen.swift, EmptyStateView.swift … |
| matched | `groups.create.name.placeholder` | “Name your group” (SOURCED) | `Copy.groupsCreateNamePlaceholder` in GroupCreateScreen.swift |
| matched | `groups.create.error.tooLong` | “Name too long” (SOURCED) | `Copy.groupsCreateErrorTooLong` in GroupCreateScreen.swift |
| matched | `groups.create.cta` | “Create Group” (SOURCED) | `Copy.groupsCreateCta` in GroupCreateScreen.swift |
| matched | `groups.create.save` | “Save” (SOURCED) | `Copy.groupsCreateSave` in GroupCreateScreen.swift, GroupSettingsScreen.swift |
| matched | `size.global.buttonMarginH` | 20 pt (SOURCED) | `Tokens.Sizes.globalButtonMarginH` in BackdropCard.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, OnboardingTitle.swift … |

## Elements

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `groups.create.close.accessibilityLabel` | “Close” (VERIFIED) | `Copy.groupsCreateCloseAccessibilityLabel` in GroupCreateScreen.swift |
| matched | `groups.create.back.accessibilityLabel` | “Back” (VERIFIED) | `Copy.groupsCreateBackAccessibilityLabel` in GroupCreateScreen.swift |
| matched | `groups.create.type.friends` | “Friends” (SOURCED) | `Copy.groupsCreateTypeFriends` in GroupKindCopy.swift |
| matched | `groups.create.cover.accessibilityLabel` | “Cover image” (VERIFIED) | `Copy.groupsCreateCoverAccessibilityLabel` in GroupCreateScreen.swift |
| matched | `auth.profile.layout.avatarPicker` | ios: PhotosPicker (SwiftUI) / PHPickerViewController, single image, no library permission; android: ActivityResultContracts.PickVisualMedia(ImageOnly), no RE… (PLATFORM) | `.photosPicker(matching: .images)` (system picker, no library permission) |
| matched | `groups.create.name.accessibilityLabel` | “Group name” (VERIFIED) | `Copy.groupsCreateNameAccessibilityLabel` in GroupCreateScreen.swift |
| matched | `groups.create.creating` | “Creating…” (SOURCED) | `Copy.groupsCreateCreating` in GroupCreateScreen.swift |

## States

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `auth.phone.layout.inlineError` | presentation: native alert: iOS SwiftUI .alert / Android M3 AlertDialog (settings.account.layout.alert); not dismissed by tapping outside; titled: code error… (SOURCED) | `formErrorAlert(_:trigger:)` (C-29 native message-only alert); code errors: titled alert with Retro's two recoveries |
| matched | `groups.create.error.failed` | “Your group wasn't created. Please try again.” (SOURCED) | `Copy.groupsCreateErrorFailed` in GroupCreateModel.swift |
| matched | `auth.phone.error.dismiss` | “OK” (VERIFIED) | `Copy.authPhoneErrorDismiss` in CodeScreen.swift, FormErrorAlert.swift, ReportFlow.swift |
| matched | `groups.create.error.saveFailed` | “There was a problem saving your changes. Please try again.” (SOURCED) | `Copy.groupsCreateErrorSaveFailed` in GroupCreateModel.swift |
| matched | `groups.create.error.cover` | “Your cover image didn't upload. Please try again.” (SOURCED) | `Copy.groupsCreateErrorCover` in GroupCreateModel.swift |
| matched | `groups.create.offline` | “Could not connect. Check your connection and try again.” (SOURCED) | `Copy.groupsCreateOffline` in GroupCreateModel.swift |

## Motion

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `spring.global.sheetPresent` | response: 0.347; dampingFraction: 1 (SOURCED) | system sheet presentation (`.sheet`) |
| matched | `duration.global.sheetPresent` | 567 ms (SOURCED) | system sheet presentation (`.sheet`) |
| matched | `easing.global.native` | sheet: system (.sheet / ModalBottomSheet) — measured on Retro: spring.global.sheetPresent; navigationPush: system (NavigationStack / Compose Navigation defau… (PLATFORM) | platform push / sheet animations (`NavigationStack`, `.sheet`, `.fullScreenCover`) |
| matched | `duration.global.fade` | 150 ms (SOURCED) | `Tokens.Durations.globalFade` in ComponentSupport.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, PaywallScreen.swift … |

## Haptics

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | Android only — iOS presses play no haptic |
| matched | `haptic.global.select` | ios: selection; android: SEGMENT_FREQUENT_TICK (PLATFORM) | `Tokens.Haptics.globalSelect` in CapsuleButton.swift, CheckRow.swift, GroupCreateScreen.swift, PaywallScreen.swift … |
| matched | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | `Tokens.Haptics.globalSuccess` in AgeGateForm.swift, CodeScreen.swift, GroupCreateScreen.swift, InviteClipApp.swift … |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | `Tokens.Haptics.globalError` in AgeGateForm.swift, BlockConfirmation.swift, CodeScreen.swift, GroupCreateScreen.swift … |

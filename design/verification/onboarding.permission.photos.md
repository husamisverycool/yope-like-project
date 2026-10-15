# Verification — `onboarding.permission.photos` (iOS)

Photos: picker without permission everywhere, add-only denied card — `Components/PermissionCard.swift` (`.photosDenied`).

Checklist written from the spec (`design/surfaces/onboarding.permission.photos.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/onboarding.permission.photos.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Reference image(s): `references/auto/yope/frames/a-yrrah-7454430216123862280-t21.23-photos-permission-alert-2024.png`, `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png`

Snapshots (CI): `onboarding.permission.photos-denied.png`

**Summary: 13 matched · 0 approximated · 0 not matched (BLOCKED or not buildable) · 0 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | token | `onboarding.permission.photos.layout.request` | ios: no screen: PhotosPicker / PHPickerViewController need no permission; saving asks add-only access (PHPhotoLibrary.requestAuthorization(for: .addOnly)) at… (VERIFIED) | photo library access | PhotosPicker everywhere a photo is picked (no permission); add-only access is asked by the save action (photo.viewer, social pass) |
| matched | copy | `system.permissions.photosAdd.purpose` | “The app saves photos from your groups to your library when you tap Save.” (VERIFIED) |  | Info.plist NSPhotoLibraryAddUsageDescription (InfoPlist.generated.xcconfig) |
| matched | copy | `system.permissions.photosRead.purpose` | “The app shows the photos you select so you can send them to your groups.” (VERIFIED) |  | Info.plist NSPhotoLibraryUsageDescription (InfoPlist.generated.xcconfig) |
| matched | token | `onboarding.permission.contacts.layout.card` | leading: none (Yope's contacts-app-like illustration with a red '!' is do-not-copy); text: title then detail, left-aligned, 16 pt from the card's leading edg… (SOURCED) | inline permission card structure | `PermissionCard` (Components): text block left at avatarInset, white pill trailing, ✕ top-trailing when dismissible |
| matched | token | `onboarding.permission.contacts.color.card` | #131313 (SOURCED) | inline permission card fill (contacts card; reused for every permission-denied card) | `Tokens.…onboardingPermissionContactsColorCard` in PermissionCard.swift |
| matched | token | `onboarding.permission.contacts.size.cardHeight` | 101 pt (SOURCED) | inline permission card height | `Tokens.…onboardingPermissionContactsSizeCardHeight` in PermissionCard.swift |
| matched | token | `onboarding.permission.contacts.size.cardMarginH` | 18 pt (SOURCED) | inline permission card side margin | `PermissionCard` horizontal padding (Components/PermissionCard.swift) |
| matched | token | `radius.global.card` | 17 pt (SOURCED) | list card corners (home conversation / group cards, inline permission card) | `Tokens.…globalCard` in PermissionCard.swift |
| matched | token | `color.global.surfaceLight` | #FFFFFF (SOURCED) | light pill fill: secondary buttons ('invite more friends', 'enable', 'new recap'), selected segment pill, '… | `Tokens.…globalSurfaceLight` in LightPill.swift, SegmentedPills.swift |
| matched | copy | `onboarding.permission.photos.denied.title` | “can’t save pics?” (SOURCED) |  | `Copy.…onboardingPermissionPhotosDeniedTitle` in PermissionCard.swift |
| matched | copy | `onboarding.permission.photos.denied.detail` | “enable photos” (SOURCED) |  | `Copy.…onboardingPermissionPhotosDeniedDetail` in PermissionCard.swift |
| matched | copy | `onboarding.permission.photos.denied.button` | “enable” (SOURCED) |  | `Copy.…onboardingPermissionPhotosDeniedButton` in PermissionCard.swift |
| matched | copy | `onboarding.permission.contacts.card.dismissAccessibilityLabel` | “dismiss” (SOURCED) |  | `Copy.…onboardingPermissionContactsCardDismissAccessibilityLabel` in PermissionCard.swift |

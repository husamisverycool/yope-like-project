# Verification — `onboarding.permission.camera` (iOS)

Camera permission: system request on first camera open (capture pass) and the denied card — `Components/PermissionCard.swift` (`.cameraDenied`).

Checklist written from the spec (`design/surfaces/onboarding.permission.camera.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/onboarding.permission.camera.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Reference image(s): `references/auto/yope/frames/a-virgi-7686278541255642390-t35.23-camera-permission-alert.png`, `references/auto/yope/frames/a-yrrah-7454430216123862280-t13.23-camera-permission-alert-2024.png`, `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png`

Snapshots (CI): `onboarding.permission.camera-denied.png`

**Summary: 21 matched · 0 approximated · 0 not matched (BLOCKED or not buildable) · 6 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| n/a | token | `onboarding.permission.camera.layout.request` | ios: no pre-alert screen: AVCaptureDevice.requestAccess(for: .video) the first time camera.capture opens; the system alert shows NSCameraUsageDescription ove… (SOURCED) | when and how camera access is requested | camera.capture (capture pass) calls AVCaptureDevice.requestAccess on first open; no pre-alert screen |
| matched | copy | `system.permissions.camera.purpose` | “The app uses your camera to take the photos you send to your groups.” (VERIFIED) |  | Info.plist NSCameraUsageDescription (ios/Config/InfoPlist.generated.xcconfig) |
| matched | token | `settings.account.layout.alert` | ios: alert(_:isPresented:actions:message:): destructive-role button + Cancel; at most 3 buttons; Cancel is never the default; Cancel on the leading side; and… (VERIFIED) | confirmation alerts / dialogs (delete account; also leave group, remove member, block, turn off link) | iOS .alert / .confirmationDialog (system); the M3 dialog half is Android |
| n/a | copy | `system.permissions.rationale.camera.title` | “want to share pics with your groups?” (SOURCED) |  | Android only |
| n/a | copy | `system.permissions.rationale.camera.message` | “{app_name} uses your camera to take the pics you share.” (SOURCED) |  | Android only |
| n/a | copy | `system.permissions.rationale.notNow` | “Not Now” (VERIFIED) |  | Android only |
| n/a | copy | `system.permissions.rationale.continue` | “Continue” (VERIFIED) |  | Android only |
| matched | token | `onboarding.permission.contacts.color.card` | #131313 (SOURCED) | inline permission card fill (contacts card; reused for every permission-denied card) | `Tokens.…onboardingPermissionContactsColorCard` in PermissionCard.swift |
| matched | token | `onboarding.permission.contacts.size.cardHeight` | 101 pt (SOURCED) | inline permission card height | `Tokens.…onboardingPermissionContactsSizeCardHeight` in PermissionCard.swift |
| matched | token | `onboarding.permission.contacts.size.cardMarginH` | 18 pt (SOURCED) | inline permission card side margin | `PermissionCard` horizontal padding (Components/PermissionCard.swift) |
| matched | token | `radius.global.card` | 17 pt (SOURCED) | list card corners (home conversation / group cards, inline permission card) | `Tokens.…globalCard` in PermissionCard.swift |
| matched | token | `onboarding.permission.contacts.layout.card` | leading: none (Yope's contacts-app-like illustration with a red '!' is do-not-copy); text: title then detail, left-aligned, 16 pt from the card's leading edg… (SOURCED) | inline permission card structure | `PermissionCard` (Components): text block left at avatarInset, white pill trailing, ✕ top-trailing when dismissible |
| matched | token | `onboarding.permission.contacts.fontSize.cardTitle` | 17 pt (SOURCED) | card title ('can’t see / your friends?', bold, white, 2 lines) | `Tokens.…onboardingPermissionContactsFontSizeCardTitle` in PermissionCard.swift |
| matched | token | `onboarding.permission.contacts.fontWeight.cardTitle` | bold (SOURCED) | card title weight | `Tokens.…onboardingPermissionContactsFontWeightCardTitle` in PermissionCard.swift |
| matched | token | `color.global.textPrimary` | #FFFFFF (SOURCED) | primary text and glyphs | `Tokens.…globalTextPrimary` in CheckRow.swift, EmptyStateView.swift, FloatingTabBar.swift |
| matched | copy | `onboarding.permission.camera.denied.title` | “can’t take pics?” (SOURCED) |  | `Copy.…onboardingPermissionCameraDeniedTitle` in PermissionCard.swift |
| matched | token | `onboarding.permission.contacts.fontSize.cardDetail` | 14 pt (SOURCED) | card detail ('enable contacts', color.global.textSecondary) | `Tokens.…onboardingPermissionContactsFontSizeCardDetail` in PermissionCard.swift |
| matched | token | `color.global.textSecondary` | #969696 (SOURCED) | secondary text, placeholders ('start typing...'), inactive tab-bar glyphs, chevrons inside capsules | `Tokens.…globalTextSecondary` in CheckRow.swift, EmptyStateView.swift, FloatingTabBar.swift |
| matched | copy | `onboarding.permission.camera.denied.detail` | “enable camera” (SOURCED) |  | `Copy.…onboardingPermissionCameraDeniedDetail` in PermissionCard.swift |
| matched | token | `onboarding.permission.contacts.size.cardButtonWidth` | 91 pt (SOURCED) | white 'enable' button width (color.global.surfaceLight, label color.global.onSurfaceLight) | `Tokens.…onboardingPermissionContactsSizeCardButtonWidth` in LightPill.swift |
| matched | token | `onboarding.permission.contacts.size.cardButtonHeight` | 37 pt (SOURCED) | white 'enable' button height | `Tokens.…onboardingPermissionContactsSizeCardButtonHeight` in LightPill.swift |
| matched | token | `color.global.surfaceLight` | #FFFFFF (SOURCED) | light pill fill: secondary buttons ('invite more friends', 'enable', 'new recap'), selected segment pill, '… | `Tokens.…globalSurfaceLight` in LightPill.swift, SegmentedPills.swift |
| matched | token | `color.global.onSurfaceLight` | #000000 (SOURCED) | label on the light pill (secondary buttons, selected segment, 'today') | `Tokens.…globalOnSurfaceLight` in LightPill.swift, SegmentedPills.swift |
| matched | token | `radius.global.capsule` | shape: capsule; radius: height / 2 (SOURCED) | full pill: header title capsule, composer text field, chat bubbles, tab-bar capsule, tooltip ends, white se… | Capsule() shape |
| matched | copy | `onboarding.permission.camera.denied.button` | “enable” (SOURCED) |  | `Copy.…onboardingPermissionCameraDeniedButton` in PermissionCard.swift |
| n/a | token | `haptic.global.shutter` | ios: none; android: none (PLATFORM) | shutter press (photo / video capture) | camera.capture (capture pass) |
| matched | copy | `system.permissions.microphone.purpose` | “The app uses your microphone to record voice notes and the sound in videos you send to your groups.” (VERIFIED) |  | Info.plist NSMicrophoneUsageDescription (InfoPlist.generated.xcconfig) |

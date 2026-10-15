# Verification — `onboarding.permission.contacts` (iOS)

Contacts in groups.invite (iOS 18 ContactAccessButton, iOS 17 contact picker) — `Features/Account/Groups/GroupInviteScreen.swift`.

Checklist written from the spec (`design/surfaces/onboarding.permission.contacts.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/onboarding.permission.contacts.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Reference image(s): `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png`, `references/auto/yope/frames/a-virgi-7686278541255642390-t44.23-suggested-friends-es.png`

Snapshots (CI): `onboarding.permission.contacts-contacts-shared.png`

**Summary: 21 matched · 0 approximated · 0 not matched (BLOCKED or not buildable) · 12 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | token | `groups.invite.layout.contacts` | ios18: ContactAccessButton(queryString:) under a search field: the person grants access per contact (limited access); granted contacts list below; ios17: but… (PLATFORM) | invite from contacts | iOS 18 search field + ContactAccessButton; iOS 17 white pill → CNContactPickerViewController; invite via MFMessageComposeViewController |
| matched | copy | `system.permissions.contacts.purpose` | “The app uses the contacts you choose to invite people to your groups.” (VERIFIED) |  | Info.plist NSContactsUsageDescription (InfoPlist.generated.xcconfig) |
| matched | copy | `onboarding.permission.contacts.search.placeholder` | “search contacts” (SOURCED) |  | `Copy.…onboardingPermissionContactsSearchPlaceholder` in GroupInviteScreen.swift |
| matched | copy | `onboarding.permission.contacts.choose` | “choose contacts” (SOURCED) |  | `Copy.…onboardingPermissionContactsChoose` in GroupInviteScreen.swift |
| matched | token | `onboarding.permission.contacts.layout.card` | leading: none (Yope's contacts-app-like illustration with a red '!' is do-not-copy); text: title then detail, left-aligned, 16 pt from the card's leading edg… (SOURCED) | inline permission card structure | `PermissionCard` (Components): text block left at avatarInset, white pill trailing, ✕ top-trailing when dismissible |
| matched | token | `onboarding.permission.contacts.color.card` | #131313 (SOURCED) | inline permission card fill (contacts card; reused for every permission-denied card) | `Tokens.…onboardingPermissionContactsColorCard` in PermissionCard.swift |
| matched | token | `onboarding.permission.contacts.size.cardHeight` | 101 pt (SOURCED) | inline permission card height | `Tokens.…onboardingPermissionContactsSizeCardHeight` in PermissionCard.swift |
| matched | token | `onboarding.permission.contacts.size.cardMarginH` | 18 pt (SOURCED) | inline permission card side margin | `PermissionCard` horizontal padding (Components/PermissionCard.swift) |
| matched | token | `radius.global.card` | 17 pt (SOURCED) | list card corners (home conversation / group cards, inline permission card) | `Tokens.…globalCard` in PermissionCard.swift |
| matched | token | `color.global.textPrimary` | #FFFFFF (SOURCED) | primary text and glyphs | `Tokens.…globalTextPrimary` in CheckRow.swift, EmptyStateView.swift, FloatingTabBar.swift |
| n/a | copy | `onboarding.permission.contacts.card.title.friends` | “can’t see your friends?” (SOURCED) |  | Android only |
| n/a | copy | `onboarding.permission.contacts.card.title.family` | “can’t see your family?” (SOURCED) |  | Android only |
| n/a | copy | `onboarding.permission.contacts.card.title.roommates` | “can’t see your roommates?” (SOURCED) |  | Android only |
| n/a | copy | `onboarding.permission.contacts.card.title.custom` | “can’t see your people?” (SOURCED) |  | Android only |
| matched | token | `color.global.textSecondary` | #969696 (SOURCED) | secondary text, placeholders ('start typing...'), inactive tab-bar glyphs, chevrons inside capsules | `Tokens.…globalTextSecondary` in CheckRow.swift, EmptyStateView.swift, FloatingTabBar.swift |
| n/a | copy | `onboarding.permission.contacts.card.detail` | “enable contacts” (SOURCED) |  | Android only |
| matched | token | `onboarding.permission.contacts.size.cardButtonWidth` | 91 pt (SOURCED) | white 'enable' button width (color.global.surfaceLight, label color.global.onSurfaceLight) | `Tokens.…onboardingPermissionContactsSizeCardButtonWidth` in LightPill.swift |
| matched | token | `onboarding.permission.contacts.size.cardButtonHeight` | 37 pt (SOURCED) | white 'enable' button height | `Tokens.…onboardingPermissionContactsSizeCardButtonHeight` in LightPill.swift |
| matched | token | `color.global.surfaceLight` | #FFFFFF (SOURCED) | light pill fill: secondary buttons ('invite more friends', 'enable', 'new recap'), selected segment pill, '… | `Tokens.…globalSurfaceLight` in LightPill.swift, SegmentedPills.swift |
| matched | token | `color.global.onSurfaceLight` | #000000 (SOURCED) | label on the light pill (secondary buttons, selected segment, 'today') | `Tokens.…globalOnSurfaceLight` in LightPill.swift, SegmentedPills.swift |
| matched | token | `radius.global.capsule` | shape: capsule; radius: height / 2 (SOURCED) | full pill: header title capsule, composer text field, chat bubbles, tab-bar capsule, tooltip ends, white se… | Capsule() shape |
| n/a | copy | `onboarding.permission.contacts.card.button` | “enable” (SOURCED) |  | Android only |
| matched | token | `icon.global.close` | ios: xmark; android: Rounded.Close (PLATFORM) | close / dismiss (✕ in a header circle on sheets) | `Tokens.…globalClose` in GroupInviteScreen.swift, PermissionCard.swift |
| n/a | token | `size.global.minTouchTarget.android` | 48 dp (VERIFIED) | minimum touch target, Android | Android only |
| matched | copy | `onboarding.permission.contacts.card.dismissAccessibilityLabel` | “dismiss” (SOURCED) |  | `Copy.…onboardingPermissionContactsCardDismissAccessibilityLabel` in PermissionCard.swift |
| matched | token | `groups.screen.size.lightPillHeight` | 45 pt (SOURCED) | white secondary pill height ('invite more friends', 205 pt wide = hug + leading icon.global.link) | `Tokens.…groupsScreenSizeLightPillHeight` in LightPill.swift |
| matched | token | `groups.screen.radius.lightPill` | 11 pt (SOURCED) | white secondary pill ('invite more friends') corner radius | `Tokens.…groupsScreenRadiusLightPill` in LightPill.swift |
| matched | token | `settings.account.layout.alert` | ios: alert(_:isPresented:actions:message:): destructive-role button + Cancel; at most 3 buttons; Cancel is never the default; Cancel on the leading side; and… (VERIFIED) | confirmation alerts / dialogs (delete account; also leave group, remove member, block, turn off link) | iOS .alert / .confirmationDialog (system); the M3 dialog half is Android |
| n/a | copy | `system.permissions.rationale.contacts.title` | “can’t see your friends?” (SOURCED) |  | Android only |
| n/a | copy | `system.permissions.rationale.contacts.message` | “{app_name} uses the contacts you choose to invite people to your groups.” (SOURCED) |  | Android only |
| n/a | copy | `system.permissions.rationale.notNow` | “Not Now” (VERIFIED) |  | Android only |
| n/a | copy | `system.permissions.rationale.continue` | “Continue” (VERIFIED) |  | Android only |
| n/a | copy | `system.permissions.openSettings` | “Open Settings” (VERIFIED) |  | Android only |

# Verification — `groups.invite` (iOS)

Invite by link or contacts — `Features/Account/Groups/GroupInviteScreen.swift`.

Checklist written from the spec (`design/surfaces/groups.invite.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/groups.invite.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Reference image(s): `references/auto/yope/frames/a-yrrah-7452976839846382855-t10.73-add-friends-share-link-2024.png`, `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t51.23-group-created-empty-state.png`, `references/auto/yope/frames/a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png`, `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t49.23-new-group-selected-create.png`, `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png`, `references/auto/yope/frames/a-virgi-7686278541255642390-t44.23-suggested-friends-es.png`

Snapshots (CI): `groups.invite-ready.png`, `groups.invite-error.png`, `groups.invite-full.png`

**Summary: 61 matched · 2 approximated · 1 not matched (BLOCKED or not buildable) · 0 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | token | `color.global.backgroundDeep` | #000000 (SOURCED) | screen background of the home list, sheets ('new group', 'send to...'), camera, sign-up, profile 'pics' gri… | `Tokens.…globalBackgroundDeep` in GroupInviteScreen.swift |
| matched | token | `size.global.headerButton` | 44 pt (SOURCED) | circle icon buttons in headers (back, close, download, film-strip, search) | `Tokens.…globalHeaderButton` in HeaderCircleButton.swift |
| matched | token | `color.global.controlOnDeep` | #101010 (SOURCED) | header circle icon buttons on black screens and sheets (✕, download) | `Tokens.…globalControlOnDeep` in HeaderCircleButton.swift |
| matched | token | `icon.global.close` | ios: xmark; android: Rounded.Close (PLATFORM) | close / dismiss (✕ in a header circle on sheets) | `Tokens.…globalClose` in GroupInviteScreen.swift, PermissionCard.swift |
| matched | token | `groups.create.layout.titleAccent` | line1: color.global.textPrimary; line2: color.global.accent; rule: a two-line onboarding or sheet title draws its second part in lime; font: fontSize.global.… (SOURCED) | two-tone title ('create **new group**', 'create your / **first group**', 'Add friends to / **2025 dumps**') | `TwoToneTitle` (Components/OnboardingTitle.swift): second part in color.global.accent |
| matched | token | `groups.create.size.titleToContent` | 34 pt (SOURCED) | title text bottom (descender) to the first content element | `Tokens.…groupsCreateSizeTitleToContent` in GroupInviteScreen.swift |
| matched | copy | `groups.invite.link.label` | “share this group link to invite” (SOURCED) |  | `Copy.…groupsInviteLinkLabel` in GroupInviteScreen.swift |
| matched | token | `icon.global.link` | ios: link; android: Rounded.Link (PLATFORM) | invite link | `Tokens.…globalLink` in GroupInviteScreen.swift |
| matched | copy | `groups.invite.link.share` | “share invite” (SOURCED) |  | `Copy.…groupsInviteLinkShare` in GroupInviteScreen.swift |
| matched | copy | `groups.invite.link.expiry` | “this link works until {date}” (SOURCED) |  | `Copy.…groupsInviteLinkExpiry` in GroupInviteScreen.swift |
| matched | copy | `groups.invite.link.turnOff` | “turn off link” (SOURCED) |  | `Copy.…groupsInviteLinkTurnOff` in GroupInviteScreen.swift |
| matched | token | `groups.invite.layout.contacts` | ios18: ContactAccessButton(queryString:) under a search field: the person grants access per contact (limited access); granted contacts list below; ios17: but… (PLATFORM) | invite from contacts | iOS 18 search field + ContactAccessButton; iOS 17 white pill → CNContactPickerViewController; invite via MFMessageComposeViewController |
| matched | copy | `groups.invite.contacts.label` | “from your contacts” (SOURCED) |  | `Copy.…groupsInviteContactsLabel` in GroupInviteScreen.swift |
| matched | copy | `onboarding.permission.contacts.choose` | “choose contacts” (SOURCED) |  | `Copy.…onboardingPermissionContactsChoose` in GroupInviteScreen.swift |
| matched | token | `groups.invite.size.pickerRowPitch` | 54.5 pt (SOURCED) | contact row pitch (avatar 40, bold name, trailing action) | `Tokens.…groupsInviteSizePickerRowPitch` in GroupInviteScreen.swift |
| matched | token | `size.global.screenMargin` | 12 pt (SOURCED) | side margin of full-width content (home list cards); edge elements sit at the same inset | `Tokens.…globalScreenMargin` in EmptyStateView.swift, GroupInviteScreen.swift, Toast.swift |
| matched | token | `size.global.avatarPicker` | 40 pt (SOURCED) | avatar in a people-picker row | `Tokens.…globalAvatarPicker` in GroupInviteScreen.swift |
| matched | token | `color.global.controlRaised` | #434343 (SOURCED) | raised fill: selected tab pill, inner pill inside the header capsule, inactive page dots | `Tokens.…globalControlRaised` in FloatingTabBar.swift, StorageImage.swift |
| matched | token | `icon.global.person` | ios: person.fill; android: Rounded.Person (PLATFORM) | default avatar silhouette | `Tokens.…globalPerson` in FloatingTabBar.swift, StorageImage.swift |
| matched | copy | `groups.invite.contacts.invite` | “invite” (SOURCED) |  | `Copy.…groupsInviteContactsInvite` in GroupInviteScreen.swift |
| matched | copy | `groups.invite.close.accessibilityLabel` | “close” (SOURCED) |  | `Copy.…groupsInviteCloseAccessibilityLabel` in GroupInviteScreen.swift |
| matched | token | `fontSize.global.onboardingTitle` | 40 pt (SOURCED) | onboarding / sign-up big title ('registrarse') | `Tokens.…globalOnboardingTitle` in TextRoles.swift |
| matched | token | `fontWeight.global.onboardingTitle` | heavy (SOURCED) | onboarding / sign-up big title | `Tokens.…fontWeightGlobalOnboardingTitle` in TextRoles.swift |
| matched | copy | `groups.invite.title.friends` | “add friends to {group_name}” (SOURCED) |  | `Copy.…groupsInviteTitleFriends` in GroupInviteScreen.swift |
| matched | copy | `groups.invite.title.family` | “add family to {group_name}” (SOURCED) |  | `Copy.…groupsInviteTitleFamily` in GroupInviteScreen.swift |
| matched | copy | `groups.invite.title.roommates` | “add roommates to {group_name}” (SOURCED) |  | `Copy.…groupsInviteTitleRoommates` in GroupInviteScreen.swift |
| matched | copy | `groups.invite.title.custom` | “add people to {group_name}” (SOURCED) |  | `Copy.…groupsInviteTitleCustom` in GroupInviteScreen.swift |
| matched | token | `fontSize.global.sectionLabel` | 16 pt (SOURCED) | section label ('suggested friends'), secondary color | `Tokens.…globalSectionLabel` in TextRoles.swift |
| matched | token | `fontWeight.global.sectionLabel` | semibold (SOURCED) | section label | `Tokens.…fontWeightGlobalSectionLabel` in TextRoles.swift |
| matched | token | `color.global.textSecondary` | #969696 (SOURCED) | secondary text, placeholders ('start typing...'), inactive tab-bar glyphs, chevrons inside capsules | `Tokens.…globalTextSecondary` in CheckRow.swift, EmptyStateView.swift, FloatingTabBar.swift |
| matched | token | `color.global.surfaceLight` | #FFFFFF (SOURCED) | light pill fill: secondary buttons ('invite more friends', 'enable', 'new recap'), selected segment pill, '… | `Tokens.…globalSurfaceLight` in LightPill.swift, SegmentedPills.swift |
| matched | token | `color.global.onSurfaceLight` | #000000 (SOURCED) | label on the light pill (secondary buttons, selected segment, 'today') | `Tokens.…globalOnSurfaceLight` in LightPill.swift, SegmentedPills.swift |
| matched | token | `groups.screen.size.lightPillHeight` | 45 pt (SOURCED) | white secondary pill height ('invite more friends', 205 pt wide = hug + leading icon.global.link) | `Tokens.…groupsScreenSizeLightPillHeight` in LightPill.swift |
| matched | token | `groups.screen.radius.lightPill` | 11 pt (SOURCED) | white secondary pill ('invite more friends') corner radius | `Tokens.…groupsScreenRadiusLightPill` in LightPill.swift |
| not matched | copy | `groups.invite.link.message` | “join {group_name} on {app_name} {link}” (SOURCED) |  | uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (AccountBlockedCopy.swift); omitted in release |
| matched | token | `groups.invite.layout.share` | ios: ShareLink / UIActivityViewController with the invite text and URL; android: Intent.createChooser(ACTION_SEND text/plain) (Sharesheet) (PLATFORM) | system share sheet opened by 'share invite' | `ActivityView` (UIActivityViewController) with the invite text (when unblocked) and the URL |
| matched | token | `fontSize.global.caption` | 12 pt (SOURCED) | small meta text: voice-message duration ('00:38'), legal footer under sign-up | `Tokens.…globalCaption` in TextRoles.swift |
| matched | token | `auth.code.fontSize.textLink` | 14.5 pt (SOURCED) | lime text link ('send new code'; Yope's sign-in link 'probar otras opciones' = 'try other options') | `Tokens.…authCodeFontSizeTextLink` in TextRoles.swift |
| matched | token | `auth.code.fontWeight.textLink` | bold (SOURCED) | lime text link weight | `Tokens.…authCodeFontWeightTextLink` in TextRoles.swift |
| matched | token | `color.global.accent` | #CDFD07 (SOURCED) | brand lime: composer camera button, primary buttons, coach tooltips, toasts, shutter ring, 'today' bar | `Tokens.…globalAccent` in GroupInviteScreen.swift, OnboardingTitle.swift, PrimaryButton.swift |
| matched | copy | `groups.invite.link.turnOff.title` | “Turn off this link?” (VERIFIED) |  | `Copy.…groupsInviteLinkTurnOffTitle` in GroupInviteScreen.swift |
| matched | copy | `groups.invite.link.turnOff.message` | “People who have it won’t be able to join with it. You can share a new link anytime.” (VERIFIED) |  | `Copy.…groupsInviteLinkTurnOffMessage` in GroupInviteScreen.swift |
| matched | copy | `groups.invite.link.turnOff.confirm` | “Turn Off” (VERIFIED) |  | `Copy.…groupsInviteLinkTurnOffConfirm` in GroupInviteScreen.swift |
| matched | copy | `groups.invite.link.turnOff.cancel` | “Cancel” (VERIFIED) |  | `Copy.…groupsInviteLinkTurnOffCancel` in GroupInviteScreen.swift |
| matched | token | `settings.account.layout.alert` | ios: alert(_:isPresented:actions:message:): destructive-role button + Cancel; at most 3 buttons; Cancel is never the default; Cancel on the leading side; and… (VERIFIED) | confirmation alerts / dialogs (delete account; also leave group, remove member, block, turn off link) | iOS .alert / .confirmationDialog (system); the M3 dialog half is Android |
| matched | copy | `groups.invite.link.turnedOff` | “link turned off” (SOURCED) |  | `Copy.…groupsInviteLinkTurnedOff` in GroupInviteScreen.swift |
| matched | token | `groups.invite.fontSize.pickerName` | 13.5 pt (SOURCED) | name on a picker row (bold, white) | `Tokens.…groupsInviteFontSizePickerName` in GroupInviteScreen.swift |
| matched | token | `groups.invite.fontWeight.pickerName` | bold (SOURCED) | picker row name weight | `Tokens.…groupsInviteFontWeightPickerName` in GroupInviteScreen.swift |
| matched | token | `color.global.textPrimary` | #FFFFFF (SOURCED) | primary text and glyphs | `Tokens.…globalTextPrimary` in CheckRow.swift, EmptyStateView.swift, FloatingTabBar.swift |
| matched | token | `onboarding.permission.contacts.size.cardButtonWidth` | 91 pt (SOURCED) | white 'enable' button width (color.global.surfaceLight, label color.global.onSurfaceLight) | `Tokens.…onboardingPermissionContactsSizeCardButtonWidth` in LightPill.swift |
| matched | token | `onboarding.permission.contacts.size.cardButtonHeight` | 37 pt (SOURCED) | white 'enable' button height | `Tokens.…onboardingPermissionContactsSizeCardButtonHeight` in LightPill.swift |
| matched | copy | `groups.invite.contacts.invited` | “invited” (SOURCED) |  | `Copy.…groupsInviteContactsInvited` in GroupInviteScreen.swift |
| matched | copy | `groups.create.hud.loading` | “Loading” (SOURCED) |  | `Copy.…groupsCreateHudLoading` in LoadingHUD.swift |
| matched | token | `fontSize.global.emptyTitle` | 16 pt (SOURCED) | empty-state title ('you created group') | `Tokens.…globalEmptyTitle` in TextRoles.swift |
| matched | token | `fontSize.global.emptyDetail` | 14 pt (SOURCED) | empty-state detail line ('and added mẹ, Anh'), italic | `Tokens.…globalEmptyDetail` in TextRoles.swift |
| matched | copy | `groups.invite.full.title` | “{group_name} is full” (SOURCED) |  | `Copy.…groupsInviteFullTitle` in GroupInviteScreen.swift |
| matched | copy | `groups.invite.full.detail` | “groups can have up to {max_members} people” (SOURCED) |  | `Copy.…groupsInviteFullDetail` in GroupInviteScreen.swift |
| matched | copy | `groups.invite.error.title` | “the invite link didn’t load” (SOURCED) |  | `Copy.…groupsInviteErrorTitle` in GroupInviteScreen.swift |
| matched | copy | `groups.invite.error.detail` | “check your connection and try again” (SOURCED) |  | `Copy.…groupsInviteErrorDetail` in GroupInviteScreen.swift |
| matched | copy | `groups.invite.error.retry` | “try again” (SOURCED) |  | `Copy.…groupsInviteErrorRetry` in GroupInviteScreen.swift |
| matched | token | `haptic.global.warning` | ios: notification.warning; android: CONFIRM (PLATFORM) | a destructive action was confirmed (delete account, block, leave) | `Tokens.…globalWarning` in BlockConfirmation.swift, GroupInviteScreen.swift |
| matched | token | `haptic.global.send` | ios: notification.success; android: CONFIRM (PLATFORM) | confirm / send: a photo or message was sent | `Tokens.…globalSend` in GroupInviteScreen.swift |

## Approximations

- White pill inner padding = `groups.list.size.avatarInset` (LightPill; not measured).
- Member avatar stack overlap = a quarter of the diameter (AvatarStack; not measured).

## Not matched

- `groups.invite.link.message` — uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (AccountBlockedCopy.swift); omitted in release

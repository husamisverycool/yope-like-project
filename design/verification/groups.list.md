# Verification — `groups.list` (iOS)

Home: groups list, cover, tab bar — `Screens/GroupsHomeScreen.swift`, `Components/FloatingTabBar.swift`.

Checklist written from the spec (`design/surfaces/groups.list.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/groups.list.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Reference image(s): `references/auto/yope/frames/a-savannahclooney-7683341732695592206-t6.73-home-list.png`, `references/auto/yope/frames/a-virgi-7686278541255642390-t40.23-home-list-es.png`, `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t44.23-home-list-new-group-icon.png`, `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png`, `references/auto/yope/store/yope-store-02.png`, `references/auto/yope/web/a-bi-2025-onboarding-composite.jpg`

Snapshots (CI): `groups.list-loading.png`, `groups.list-empty.png`, `groups.list-loaded.png`, `groups.list-error.png`, `groups.list-offline.png`

**Summary: 73 matched · 3 approximated · 0 not matched (BLOCKED or not buildable) · 0 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | token | `color.global.backgroundDeep` | #000000 (SOURCED) | screen background of the home list, sheets ('new group', 'send to...'), camera, sign-up, profile 'pics' gri… | `Tokens.…globalBackgroundDeep` in GroupsHomeScreen.swift |
| matched | token | `groups.list.size.coverHeight` | 205 pt (SOURCED) | home cover header (newest photo across groups, full-bleed from the top edge) height | `Tokens.…groupsListSizeCoverHeight` in GroupsHomeScreen.swift |
| matched | token | `icon.global.chevronDown` | ios: chevron.down; android: Rounded.ExpandMore (PLATFORM) | expand / dismiss down (⌄) | `Tokens.…globalChevronDown` in GroupsHomeScreen.swift |
| matched | token | `size.global.headerInset` | 11.5 pt (SOURCED) | screen edge to the first / last header circle | `Tokens.…globalHeaderInset` in GroupsHomeScreen.swift |
| matched | token | `size.global.headerButton` | 44 pt (SOURCED) | circle icon buttons in headers (back, close, download, film-strip, search) | `Tokens.…globalHeaderButton` in HeaderCircleButton.swift |
| matched | token | `icon.global.add` | ios: plus; android: Rounded.Add (PLATFORM) | add (+ in a header circle) | `Tokens.…globalAdd` in GroupsHomeScreen.swift |
| matched | token | `groups.list.color.headerCircleOverPhoto` | #00000094 (SOURCED) | translucent dark fill of the header circles drawn over the cover photo | `Tokens.…groupsListColorHeaderCircleOverPhoto` in HeaderCircleButton.swift |
| matched | token | `size.global.listGap` | 7.5 pt (SOURCED) | vertical gap between stacked list cards | `Tokens.…globalListGap` in GroupsHomeScreen.swift |
| matched | token | `size.global.screenMargin` | 12 pt (SOURCED) | side margin of full-width content (home list cards); edge elements sit at the same inset | `Tokens.…globalScreenMargin` in EmptyStateView.swift, GroupsHomeScreen.swift, Toast.swift |
| matched | token | `groups.list.layout.tabBar` | order: camera · groups (chats glyph) · walls (film-strip) · me (own avatar); selected: pill color.global.controlRaised (size.global.tabBarSelectedWidth × .ta… (SOURCED) | floating tab bar on the home list | `FloatingTabBar`: camera · groups · walls · me, icon-only, selected pill, avatar for me |
| matched | token | `size.global.tabBarInset` | 22 pt (SOURCED) | tab-bar side inset from the screen edges | `Tokens.…globalTabBarInset` in FloatingTabBar.swift |
| matched | token | `groups.list.color.card` | #181818 (SOURCED) | group card fill on the black home list | `Tokens.…groupsListColorCard` in GroupsHomeScreen.swift |
| matched | token | `groups.list.size.cardHeight` | 100 pt (SOURCED) | group card height | `Tokens.…groupsListSizeCardHeight` in GroupsHomeScreen.swift |
| matched | token | `radius.global.card` | 17 pt (SOURCED) | list card corners (home conversation / group cards, inline permission card) | `Tokens.…globalCard` in GroupsHomeScreen.swift, PermissionCard.swift |
| matched | copy | `groups.list.row.accessibilityLabel` | “{group_name}, {subtitle}” (SOURCED) |  | `Copy.…groupsListRowAccessibilityLabel` in GroupsHomeScreen.swift |
| matched | token | `size.global.avatarList` | 64 pt (SOURCED) | avatar in a home list card | `Tokens.…globalAvatarList` in GroupsHomeScreen.swift |
| matched | token | `groups.list.size.avatarInset` | 16 pt (SOURCED) | avatar left inset inside the card (and its vertical centring) | `Tokens.…groupsListSizeAvatarInset` in GroupsHomeScreen.swift, LightPill.swift, PermissionCard.swift |
| matched | token | `color.global.controlRaised` | #434343 (SOURCED) | raised fill: selected tab pill, inner pill inside the header capsule, inactive page dots | `Tokens.…globalControlRaised` in FloatingTabBar.swift, GroupsHomeScreen.swift, StorageImage.swift |
| matched | token | `icon.global.group` | ios: person.2.fill; android: Rounded.Group (PLATFORM) | group / people | `Tokens.…globalGroup` in GroupsHomeScreen.swift |
| matched | token | `color.global.textSecondary` | #969696 (SOURCED) | secondary text, placeholders ('start typing...'), inactive tab-bar glyphs, chevrons inside capsules | `Tokens.…globalTextSecondary` in CheckRow.swift, EmptyStateView.swift, FloatingTabBar.swift |
| matched | token | `fontSize.global.listTitle` | 17.5 pt (SOURCED) | row / card name on the home list ('kylee') | `Tokens.…globalListTitle` in TextRoles.swift |
| matched | token | `fontWeight.global.listTitle` | bold (SOURCED) | row / card name on the home list | `Tokens.…fontWeightGlobalListTitle` in TextRoles.swift |
| matched | token | `color.global.textPrimary` | #FFFFFF (SOURCED) | primary text and glyphs | `Tokens.…globalTextPrimary` in CheckRow.swift, EmptyStateView.swift, FloatingTabBar.swift |
| matched | token | `fontSize.global.listSubtitle` | 14 pt (SOURCED) | row subtitle ('new pic added · 9:43 AM'), secondary color | `Tokens.…globalListSubtitle` in TextRoles.swift |
| matched | token | `fontWeight.global.listSubtitle` | regular (SOURCED) | row subtitle | `Tokens.…fontWeightGlobalListSubtitle` in TextRoles.swift |
| matched | token | `color.global.accent` | #CDFD07 (SOURCED) | brand lime: composer camera button, primary buttons, coach tooltips, toasts, shutter ring, 'today' bar | `Tokens.…globalAccent` in GroupsHomeScreen.swift, OnboardingTitle.swift, PrimaryButton.swift |
| matched | copy | `groups.list.row.sentPic` | “{first_name} sent a pic · {time}” (SOURCED) |  | `Copy.…groupsListRowSentPic` in GroupsHomeScreen.swift |
| matched | copy | `groups.list.row.newPic` | “new pic added · {time}” (SOURCED) |  | `Copy.…groupsListRowNewPic` in GroupsHomeScreen.swift |
| matched | copy | `groups.list.row.noPics` | “new group!✨ share a pic?” (SOURCED) |  | `Copy.…groupsListRowNoPics` in GroupsHomeScreen.swift |
| matched | token | `icon.global.camera` | ios: camera.fill; android: Rounded.PhotoCamera (PLATFORM) | camera (composer button, row quick-camera, camera tab) | `Tokens.…globalCamera` in FloatingTabBar.swift, GroupsHomeScreen.swift |
| matched | token | `groups.list.size.cameraGlyph` | 16 pt (SOURCED) | trailing camera glyph on a card (opens the camera for that group) | `Tokens.…groupsListSizeCameraGlyph` in GroupsHomeScreen.swift |
| matched | copy | `groups.list.row.camera.accessibilityLabel` | “take a pic for {group_name}” (SOURCED) |  | `Copy.…groupsListRowCameraAccessibilityLabel` in GroupsHomeScreen.swift |
| matched | copy | `groups.list.cover.accessibilityLabel` | “newest pic, from {first_name} in {group_name}” (SOURCED) |  | `Copy.…groupsListCoverAccessibilityLabel` in GroupsHomeScreen.swift |
| matched | copy | `groups.list.header.add.accessibilityLabel` | “new group” (SOURCED) |  | `Copy.…groupsListHeaderAddAccessibilityLabel` in GroupsHomeScreen.swift |
| matched | token | `size.global.tabBarWidth` | 344 pt (SOURCED) | floating tab-bar capsule width | `Tokens.…globalTabBarWidth` in FloatingTabBar.swift |
| matched | token | `size.global.tabBarHeight` | 58 pt (SOURCED) | floating tab-bar capsule height | `Tokens.…globalTabBarHeight` in FloatingTabBar.swift |
| matched | token | `size.global.tabBarSelectedWidth` | 74 pt (SOURCED) | selected-tab pill width (fill color.global.controlRaised) | `Tokens.…globalTabBarSelectedWidth` in FloatingTabBar.swift |
| matched | token | `size.global.tabBarSelectedHeight` | 48 pt (SOURCED) | selected-tab pill height | `Tokens.…globalTabBarSelectedHeight` in FloatingTabBar.swift |
| matched | token | `size.global.tabBarIcon` | 21 pt (SOURCED) | tab glyph size (20-23 pt measured) | `Tokens.…globalTabBarIcon` in FloatingTabBar.swift |
| matched | token | `size.global.tabBarAvatar` | 34 pt (SOURCED) | 'me' tab avatar | `Tokens.…globalTabBarAvatar` in FloatingTabBar.swift |
| matched | token | `color.global.control` | #2E2E2E (SOURCED) | control fill on #171717: header circle buttons, header title capsule, floating tab-bar capsule, composer te… | `Tokens.…globalControl` in FloatingTabBar.swift, HeaderCircleButton.swift |
| matched | token | `radius.global.capsule` | shape: capsule; radius: height / 2 (SOURCED) | full pill: header title capsule, composer text field, chat bubbles, tab-bar capsule, tooltip ends, white se… | Capsule() shape |
| matched | token | `icon.global.chats` | ios: bubble.left.and.bubble.right.fill; android: Rounded.Forum (PLATFORM) | chats tab (two overlapping bubbles) | `Tokens.…globalChats` in FloatingTabBar.swift |
| matched | token | `icon.global.wall` | ios: film.stack.fill; android: Rounded.VideoLibrary (PLATFORM) | walls / recaps tab (film frame with stacked lines, filled) | `Tokens.…globalWall` in FloatingTabBar.swift |
| matched | copy | `groups.list.tab.camera.accessibilityLabel` | “camera” (SOURCED) |  | `Copy.…groupsListTabCameraAccessibilityLabel` in FloatingTabBar.swift |
| matched | token | `groups.create.color.hud` | #0C0C0C (SOURCED) | Loading HUD square fill (on black) | `Tokens.…groupsCreateColorHud` in LoadingHUD.swift |
| matched | token | `groups.create.size.hud` | 100 pt (SOURCED) | Loading HUD square side | `Tokens.…groupsCreateSizeHud` in LoadingHUD.swift |
| matched | token | `groups.create.fontSize.hudLabel` | 15 pt (SOURCED) | 'Loading' label under the spinner in the HUD | `Tokens.…groupsCreateFontSizeHudLabel` in TextRoles.swift |
| matched | copy | `groups.create.hud.loading` | “Loading” (SOURCED) |  | `Copy.…groupsCreateHudLoading` in LoadingHUD.swift |
| matched | token | `fontSize.global.onboardingTitle` | 40 pt (SOURCED) | onboarding / sign-up big title ('registrarse') | `Tokens.…globalOnboardingTitle` in TextRoles.swift |
| matched | token | `fontWeight.global.onboardingTitle` | heavy (SOURCED) | onboarding / sign-up big title | `Tokens.…fontWeightGlobalOnboardingTitle` in TextRoles.swift |
| matched | token | `groups.create.layout.titleAccent` | line1: color.global.textPrimary; line2: color.global.accent; rule: a two-line onboarding or sheet title draws its second part in lime; font: fontSize.global.… (SOURCED) | two-tone title ('create **new group**', 'create your / **first group**', 'Add friends to / **2025 dumps**') | `TwoToneTitle` (Components/OnboardingTitle.swift): second part in color.global.accent |
| matched | token | `auth.phone.fontSize.subtitle` | 14 pt (SOURCED) | italic subtitle under the sign-up title ('to join or create your friends groups') | `Tokens.…authPhoneFontSizeSubtitle` in TextRoles.swift |
| matched | token | `auth.phone.layout.subtitle` | style: italic; weight: regular; color: color.global.textPrimary; align: center (SOURCED) | subtitle text style under the sign-up title | OnboardingTitleBlock subtitle: italic, regular, textPrimary, centred |
| matched | token | `size.global.buttonHeight` | 45 pt (SOURCED) | full-width primary button in a form ('create group') | `Tokens.…globalButtonHeight` in PrimaryButton.swift |
| matched | token | `size.global.buttonMarginH` | 19 pt (SOURCED) | side margin of the form primary button | `Tokens.…globalButtonMarginH` in GroupsHomeScreen.swift |
| matched | token | `radius.global.button` | 14 pt (SOURCED) | primary (lime) button corners — not a full pill | `Tokens.…globalButton` in PrimaryButton.swift, TextRoles.swift |
| matched | token | `groups.create.size.titleToContent` | 34 pt (SOURCED) | title text bottom (descender) to the first content element | `Tokens.…groupsCreateSizeTitleToContent` in GroupsHomeScreen.swift |
| matched | copy | `groups.list.empty.title` | “create your first group” (SOURCED) |  | `Copy.…groupsListEmptyTitle` in GroupsHomeScreen.swift |
| matched | copy | `groups.list.empty.detail` | “to share pics daily and get recaps on your memories” (SOURCED) |  | `Copy.…groupsListEmptyDetail` in GroupsHomeScreen.swift |
| matched | copy | `groups.list.empty.button` | “create group” (SOURCED) |  | `Copy.…groupsListEmptyButton` in GroupsHomeScreen.swift |
| matched | token | `fontSize.global.emptyTitle` | 16 pt (SOURCED) | empty-state title ('you created group') | `Tokens.…globalEmptyTitle` in TextRoles.swift |
| matched | token | `fontSize.global.emptyDetail` | 14 pt (SOURCED) | empty-state detail line ('and added mẹ, Anh'), italic | `Tokens.…globalEmptyDetail` in TextRoles.swift |
| matched | token | `color.global.surfaceLight` | #FFFFFF (SOURCED) | light pill fill: secondary buttons ('invite more friends', 'enable', 'new recap'), selected segment pill, '… | `Tokens.…globalSurfaceLight` in LightPill.swift, SegmentedPills.swift |
| matched | token | `groups.screen.size.lightPillHeight` | 45 pt (SOURCED) | white secondary pill height ('invite more friends', 205 pt wide = hug + leading icon.global.link) | `Tokens.…groupsScreenSizeLightPillHeight` in LightPill.swift |
| matched | token | `groups.screen.radius.lightPill` | 11 pt (SOURCED) | white secondary pill ('invite more friends') corner radius | `Tokens.…groupsScreenRadiusLightPill` in LightPill.swift |
| matched | token | `color.global.onSurfaceLight` | #000000 (SOURCED) | label on the light pill (secondary buttons, selected segment, 'today') | `Tokens.…globalOnSurfaceLight` in LightPill.swift, SegmentedPills.swift |
| matched | copy | `groups.list.error.title` | “your groups didn’t load” (SOURCED) |  | `Copy.…groupsListErrorTitle` in GroupsHomeScreen.swift |
| matched | copy | `groups.list.error.detail` | “check your connection and try again” (SOURCED) |  | `Copy.…groupsListErrorDetail` in GroupsHomeScreen.swift |
| matched | copy | `groups.list.error.retry` | “try again” (SOURCED) |  | `Copy.…groupsListErrorRetry` in GroupsHomeScreen.swift |
| matched | copy | `groups.list.offline.title` | “you’re offline” (SOURCED) |  | `Copy.…groupsListOfflineTitle` in GroupsHomeScreen.swift |
| matched | copy | `groups.list.offline.detail` | “your groups will be here when you’re back online” (SOURCED) |  | `Copy.…groupsListOfflineDetail` in GroupsHomeScreen.swift |
| matched | token | `easing.global.native` | keyboard: system; alert: system; activityIndicator: system (ProgressView / CircularProgressIndicator); scrollIndicator: system; navigationPush: system (Navig… (PLATFORM) | motion of native components Yope uses; their curves and durations are the platform's | system push / sheet / alert animations |

## Approximations

- Cover bottom-corner radius not measured → square (spec Gaps).
- Groups without a cover: group glyph at the platform default symbol size on controlRaised (spec Gaps).
- Empty-state white pill: hugs its label with `groups.list.size.avatarInset` padding (LightPill; Yope inner padding not measured).

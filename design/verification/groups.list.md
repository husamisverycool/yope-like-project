# Verification — `groups.list` (iOS, Pass 4 — Retro redesign)

Home: groups list — `Screens/GroupsHomeScreen.swift` (`GroupsListView`, `GroupTemplateRow`), `Features/Account/Groups/GroupsListModel.swift`, shell tab bar in `RootView.swift`.

Checklist written from the spec (`design/surfaces/groups.list.md`) against the iOS code: every token and copy key the spec names, its reference value, and where the iOS code uses it. The snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (AccountSnapshotTests: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/groups.list.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png`, `references/auto/retro/press/tc-2024-04-journals-1.webp`, `references/auto/retro/press/jeddacp-2024-05-home-profile-journals.png`, `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png`, `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`

Snapshots (CI, `ios/build/snapshots/account/`): `groups.list-loading-light.png`, `groups.list-empty-light.png`, `groups.list-empty-dark.png`, `groups.list-default-light.png`, `groups.list-default-dark.png`, `groups.list-error-light.png`, `groups.list-offline-light.png`

**Summary: 46 matched · 0 approximated · 0 not matched · 2 not applicable on iOS / owner / another pass.**


## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `groups.list.layout.tabBar` | component: design/components.md C-04 (icon-only, evenly distributed, page-coloured, no hairline, no labels); order: camera · groups (home) · walls (people) ·… (SOURCED) | `AppTabBar` (C-04) + `ShellNavigation.select` (RootView.swift) |

## References

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `icon.global.newAlbum` | ios: plus.rectangle.on.rectangle; android: Outlined.LibraryAdd (PLATFORM) | `Tokens.Icons.globalNewAlbum` in GroupsHomeScreen.swift |

## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `color.global.background` | light: #FFFFFF; dark: #000000 (SOURCED) | `Tokens.Colors.globalBackground` in AccountGroupedRows.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, GroupScreen.swift … |
| matched | `groups.list.title` | “Groups” (SOURCED) | `Copy.groupsListTitle` in GroupsHomeScreen.swift |
| matched | `font.global.display` | ios: system-serif; android: serif (PLATFORM) | `Tokens.Fonts.globalDisplay` in InvitePreviewView.swift, PhoneScreen.swift, TextRoles.swift |
| matched | `color.global.textPrimary` | light: #000000; dark: #FFFFFF (SOURCED) | `Tokens.Colors.globalTextPrimary` in AccountGroupedRows.swift, CapsuleButton.swift, CheckRow.swift, CircleButton.swift … |
| matched | `size.global.screenMargin` | 16 pt (SOURCED) | `Tokens.Sizes.globalScreenMargin` in AccountGroupedRows.swift, AgeGateForm.swift, CodeScreen.swift, EmptyStateView.swift … |
| matched | `size.global.titleTop` | 64 pt (SOURCED) | `Tokens.Sizes.globalTitleTop` in FullBleedMediaPage.swift, GroupScreen.swift, ScreenHeader.swift, SignUpLayout.swift |
| matched | `size.global.headerInset` | 16 pt (SOURCED) | `Tokens.Sizes.globalHeaderInset` in GroupScreen.swift, ScreenHeader.swift |
| matched | `size.global.headerButton` | 44 pt (PLATFORM) | `Tokens.Sizes.globalHeaderButton` in GroupScreen.swift, GroupSettingsScreen.swift, ScreenHeader.swift, SectionHeader.swift … |
| matched | `size.global.titleToContent` | 30 pt (SOURCED) | `Tokens.Sizes.globalTitleToContent` in AccountGroupedRows.swift, AgeGateForm.swift, GroupCreateScreen.swift, GroupInviteScreen.swift … |
| matched | `size.global.listGap` | 22.5 pt (SOURCED) | `Tokens.Sizes.globalListGap` in ThumbnailRow.swift |
| matched | `size.global.rowThumbWidth` | 72 pt (SOURCED) | `Tokens.Sizes.globalRowThumbWidth` in GroupsHomeScreen.swift, PaywallScreen.swift, ThumbnailRow.swift |
| matched | `radius.global.thumbnail` | 4 pt (SOURCED) | `Tokens.Radii.globalThumbnail` in GroupCreateScreen.swift, GroupsHomeScreen.swift, ThumbnailRow.swift |
| matched | `color.global.control` | light: #F1F1F1; dark: #262626 (SOURCED) | `Tokens.Colors.globalControl` in AccountGroupedRows.swift, Avatar.swift, CapsuleButton.swift, CircleButton.swift … |
| matched | `icon.global.group` | ios: person.2; android: Outlined.Group (PLATFORM) | `Tokens.Icons.globalGroup` in GroupCreateScreen.swift, SettingsNotificationsScreen.swift, TabBar.swift |
| matched | `color.global.textSecondary` | #999999 (SOURCED) | `Tokens.Colors.globalTextSecondary` in AccountGroupedRows.swift, Avatar.swift, CheckRow.swift, CodeScreen.swift … |
| matched | `size.global.rowThumbGap` | 17 pt (SOURCED) | `Tokens.Sizes.globalRowThumbGap` in GroupsHomeScreen.swift, ThumbnailRow.swift, WidgetGuideScreen.swift |
| matched | `size.global.avatarSmall` | 22.6 pt (SOURCED) | `Tokens.Sizes.globalAvatarSmall` in Avatar.swift, GroupScreen.swift, GroupsHomeScreen.swift |
| matched | `size.global.avatarStackOverlap` | 3 pt (SOURCED) | `Tokens.Sizes.globalAvatarStackOverlap` in Avatar.swift, GroupsHomeScreen.swift |
| matched | `size.global.circleButton` | 36 pt (SOURCED) | `Tokens.Sizes.globalCircleButton` in CircleButton.swift, GroupsHomeScreen.swift, SheetChrome.swift, WidgetGuideScreen.swift |
| matched | `icon.global.add` | ios: plus; android: Rounded.Add (PLATFORM) | `Tokens.Icons.globalAdd` in GroupScreen.swift, GroupsHomeScreen.swift, OutlineCTA.swift, ThumbnailRow.swift … |
| matched | `size.global.sectionGap` | 36.4 pt (SOURCED) | `Tokens.Sizes.globalSectionGap` in AccountGroupedRows.swift, GroupInviteScreen.swift, GroupScreen.swift, GroupsHomeScreen.swift … |
| matched | `groups.list.ideas.title` | “Ideas to Get Started” (SOURCED) | `Copy.groupsListIdeasTitle` in GroupsHomeScreen.swift |
| matched | `groups.create.type.create` | “Create” (SOURCED) | `Copy.groupsCreateTypeCreate` in GroupsHomeScreen.swift |
| matched | `size.global.pillHeight` | 37 pt (SOURCED) | `Tokens.Sizes.globalPillHeight` in CapsuleButton.swift, LightPill.swift, OutlineCTA.swift |

## Elements

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `groups.list.header.add.accessibilityLabel` | “New Group” (VERIFIED) | `Copy.groupsListHeaderAddAccessibilityLabel` in GroupsHomeScreen.swift |
| matched | `groups.list.row.accessibilityLabel` | “{group_name}, {subtitle}” (VERIFIED) | `Copy.groupsListRowAccessibilityLabel` in GroupsHomeScreen.swift |
| matched | `groups.list.row.sentPic` | “{first_name} shared a post” (SOURCED) | `Copy.groupsListRowSentPic` in GroupsHomeScreen.swift |
| matched | `groups.list.row.newPic` | “you shared a post” (SOURCED) | `Copy.groupsListRowNewPic` in GroupsHomeScreen.swift |
| matched | `groups.list.row.createdByYou` | “you created the group” (SOURCED) | `Copy.groupsListRowCreatedByYou` in GroupsHomeScreen.swift |
| matched | `groups.list.row.camera.accessibilityLabel` | “Add to {group_name}” (VERIFIED) | `Copy.groupsListRowCameraAccessibilityLabel` in GroupsHomeScreen.swift |
| matched | `icon.global.camera` | ios: camera; android: Outlined.PhotoCamera (PLATFORM) | `Tokens.Icons.globalCamera` in TabBar.swift |
| matched | `color.global.tabInactive` | light: #B2B2B2; dark: #999999 (SOURCED) | `Tokens.Colors.globalTabInactive` in TabBar.swift |
| matched | `groups.list.tab.camera.accessibilityLabel` | “Camera” (VERIFIED) | `Copy.groupsListTabCameraAccessibilityLabel` in TabBar.swift |

## States

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `icon.global.albums` | ios: book; android: AutoMirrored.Outlined.MenuBook (PLATFORM) | `Tokens.Icons.globalAlbums` in GroupScreen.swift, GroupsHomeScreen.swift |
| matched | `groups.list.empty.title` | “Welcome to groups!” (SOURCED) | `Copy.groupsListEmptyTitle` in GroupsHomeScreen.swift |
| matched | `groups.list.empty.detail` | “Here you can share moments with a select group of people.” (SOURCED) | `Copy.groupsListEmptyDetail` in GroupsHomeScreen.swift |
| matched | `groups.list.empty.button` | “Create Group” (SOURCED) | `Copy.groupsListEmptyButton` in GroupsHomeScreen.swift |
| matched | `groups.list.error.title` | “Error retrieving your groups. Tap here to try again” (SOURCED) | `Copy.groupsListErrorTitle` in GroupsHomeScreen.swift |
| matched | `groups.list.offline.title` | “You're offline” (SOURCED) | `Copy.groupsListOfflineTitle` in GroupsHomeScreen.swift |

## Motion

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `easing.global.native` | sheet: system (.sheet / ModalBottomSheet) — measured on Retro: spring.global.sheetPresent; navigationPush: system (NavigationStack / Compose Navigation defau… (PLATFORM) | platform push / sheet animations (`NavigationStack`, `.sheet`, `.fullScreenCover`) |
| matched | `duration.global.crossfade` | 100 ms (SOURCED) | `Tokens.Durations.globalCrossfade` in AgeGateForm.swift, ComponentSupport.swift |
| matched | `duration.global.fade` | 150 ms (SOURCED) | `Tokens.Durations.globalFade` in ComponentSupport.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, PaywallScreen.swift … |
| matched | `easing.global.standard` | x1: 0.4; y1: 0; x2: 0.2; y2: 1 (SOURCED) | `Tokens.Easings.globalStandard` in AgeGateForm.swift, ComponentSupport.swift, GroupCreateScreen.swift, GroupInviteScreen.swift … |
| matched | `layout.global.reduceMotion` | ios: UIAccessibility.isReduceMotionEnabled / @Environment(\.accessibilityReduceMotion); android: Settings.Global.ANIMATOR_DURATION_SCALE == 0 or ValueAnimato… (PLATFORM) | `dsAnimation` / `dsTransition` (DesignSystem) drop movement under Reduce Motion, keep cross-fades |

## Haptics

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | Android only — iOS presses play no haptic |

## Platform notes

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `color.global.background.android` | light: #FFFFFF; dark: #1C1C1E (SOURCED) | Android only |

## Notes

- Loading rows: three placeholder rows (`GroupRowPlaceholder`).

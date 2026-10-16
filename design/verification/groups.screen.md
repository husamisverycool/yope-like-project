# Verification — `groups.screen` (iOS, Pass 4 — Retro redesign)

Group page — `Screens/GroupScreen.swift` (`GroupFeedView`, `GroupWeekStrip`, `GroupPhotoGrid`, `MemoryFeedCard`), `Features/Account/Groups/GroupFeedModel.swift`.

Checklist written from the spec (`design/surfaces/groups.screen.md`) against the iOS code: every token and copy key the spec names, its reference value, and where the iOS code uses it. The snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (AccountSnapshotTests: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/groups.screen.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/press/tc-2024-04-journals-1.webp`, `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png`, `references/auto/retro/store/retro-store-01.png`, `references/auto/retro/store/editorial/retro-appstore-story-1840659619-albums.png`, `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`

Snapshots (CI, `ios/build/snapshots/account/`): `groups.screen-loading-light.png`, `groups.screen-default-light.png`, `groups.screen-default-dark.png`, `groups.screen-created-light.png`, `groups.screen-empty-light.png`, `groups.screen-quiet-week-light.png`, `groups.screen-error-light.png`, `groups.screen-offline-light.png`, `groups.screen-removed-light.png`

**Summary: 77 matched · 0 approximated · 0 not matched · 1 not applicable on iOS / owner / another pass.**


## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `color.global.background` | light: #FFFFFF; dark: #000000 (SOURCED) | `Tokens.Colors.globalBackground` in AccountGroupedRows.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, GroupScreen.swift … |
| matched | `icon.global.back` | ios: chevron.left; android: AutoMirrored.Rounded.ArrowBackIos (PLATFORM) | `Tokens.Icons.globalBack` in ScreenHeader.swift, SignUpLayout.swift |
| matched | `size.global.backInset` | 21.1 pt (SOURCED) | `Tokens.Sizes.globalBackInset` in ScreenHeader.swift, SignUpLayout.swift |
| matched | `size.global.icon` | 24 pt (SOURCED) | `Tokens.Sizes.globalIcon` in CircleButton.swift, ComponentSupport.swift, GroupScreen.swift, GroupSettingsScreen.swift … |
| matched | `size.global.headerIconPitch` | 48 pt (SOURCED) | `Tokens.Sizes.globalHeaderIconPitch` in GroupScreen.swift, ScreenHeader.swift |
| matched | `size.global.headerInset` | 16 pt (SOURCED) | `Tokens.Sizes.globalHeaderInset` in GroupScreen.swift, ScreenHeader.swift |
| matched | `icon.global.albums` | ios: book; android: AutoMirrored.Outlined.MenuBook (PLATFORM) | `Tokens.Icons.globalAlbums` in GroupScreen.swift, GroupsHomeScreen.swift |
| matched | `icon.global.chats` | ios: bubble.left; android: Outlined.ChatBubbleOutline (PLATFORM) | `Tokens.Icons.globalChats` in GroupInviteScreen.swift, GroupScreen.swift |
| matched | `size.global.titleTop` | 64 pt (SOURCED) | `Tokens.Sizes.globalTitleTop` in FullBleedMediaPage.swift, GroupScreen.swift, ScreenHeader.swift, SignUpLayout.swift |
| matched | `size.global.titleToContent` | 30 pt (SOURCED) | `Tokens.Sizes.globalTitleToContent` in AccountGroupedRows.swift, AgeGateForm.swift, GroupCreateScreen.swift, GroupInviteScreen.swift … |
| matched | `groups.screen.size.coverWidth` | 173.5 pt (SOURCED) | `Tokens.Sizes.groupsScreenSizeCoverWidth` in GroupCreateScreen.swift, GroupScreen.swift |
| matched | `radius.global.thumbnail` | 4 pt (SOURCED) | `Tokens.Radii.globalThumbnail` in GroupCreateScreen.swift, GroupsHomeScreen.swift, ThumbnailRow.swift |
| matched | `groups.screen.shadow.cover` | color: #000000; blur: 8.5; x: 3; y: 10; opacity: 0.25 (SOURCED) | `Tokens.Shadows.groupsScreenShadowCover` in GroupCreateScreen.swift |
| matched | `color.global.control` | light: #F1F1F1; dark: #262626 (SOURCED) | `Tokens.Colors.globalControl` in AccountGroupedRows.swift, Avatar.swift, CapsuleButton.swift, CircleButton.swift … |
| matched | `icon.global.group` | ios: person.2; android: Outlined.Group (PLATFORM) | `Tokens.Icons.globalGroup` in GroupCreateScreen.swift, SettingsNotificationsScreen.swift, TabBar.swift |
| matched | `color.global.textSecondary` | #999999 (SOURCED) | `Tokens.Colors.globalTextSecondary` in AccountGroupedRows.swift, Avatar.swift, CheckRow.swift, CodeScreen.swift … |
| matched | `groups.screen.size.coverToTitle` | 36.7 pt (SOURCED) | `Tokens.Sizes.groupsScreenSizeCoverToTitle` in GroupCreateScreen.swift, GroupScreen.swift |
| matched | `font.global.display` | ios: system-serif; android: serif (PLATFORM) | `Tokens.Fonts.globalDisplay` in InvitePreviewView.swift, PhoneScreen.swift, TextRoles.swift |
| matched | `color.global.textPrimary` | light: #000000; dark: #FFFFFF (SOURCED) | `Tokens.Colors.globalTextPrimary` in AccountGroupedRows.swift, CapsuleButton.swift, CheckRow.swift, CircleButton.swift … |
| matched | `groups.screen.size.titleToMeta` | 16 pt (SOURCED) | `Tokens.Sizes.groupsScreenSizeTitleToMeta` in GroupScreen.swift |
| matched | `size.global.avatarSmall` | 22.6 pt (SOURCED) | `Tokens.Sizes.globalAvatarSmall` in Avatar.swift, GroupScreen.swift, GroupsHomeScreen.swift |
| matched | `size.global.avatarStackOverlap` | 3 pt (SOURCED) | `Tokens.Sizes.globalAvatarStackOverlap` in Avatar.swift, GroupsHomeScreen.swift |
| matched | `size.global.screenMargin` | 16 pt (SOURCED) | `Tokens.Sizes.globalScreenMargin` in AccountGroupedRows.swift, AgeGateForm.swift, CodeScreen.swift, EmptyStateView.swift … |
| matched | `groups.screen.size.metaToActions` | 26.6 pt (SOURCED) | `Tokens.Sizes.groupsScreenSizeMetaToActions` in GroupScreen.swift |
| matched | `groups.screen.recap.accessibilityLabel` | “Recaps” (SOURCED) | `Copy.groupsScreenRecapAccessibilityLabel` in GroupScreen.swift |
| matched | `groups.screen.invite` | “Invite” (SOURCED) | `Copy.groupsScreenInvite` in GroupScreen.swift |
| matched | `size.global.iconPillWidth` | 49 pt (SOURCED) | `Tokens.Sizes.globalIconPillWidth` in CapsuleButton.swift |
| matched | `icon.global.settings` | ios: gearshape; android: Outlined.Settings (PLATFORM) | `Tokens.Icons.globalSettings` in GroupScreen.swift |
| matched | `size.global.iconSmall` | 14.7 pt (SOURCED) | `Tokens.Sizes.globalIconSmall` in CapsuleButton.swift, GroupInviteScreen.swift, LightPill.swift, MediaPills.swift … |
| matched | `size.global.pillHeight` | 37 pt (SOURCED) | `Tokens.Sizes.globalPillHeight` in CapsuleButton.swift, LightPill.swift, OutlineCTA.swift |
| matched | `size.global.pillGap` | 8.8 pt (SOURCED) | `Tokens.Sizes.globalPillGap` in CapsuleButton.swift |
| matched | `size.global.sectionGap` | 36.4 pt (SOURCED) | `Tokens.Sizes.globalSectionGap` in AccountGroupedRows.swift, GroupInviteScreen.swift, GroupScreen.swift, GroupsHomeScreen.swift … |
| matched | `size.global.avatarPicker` | 37 pt (SOURCED) | `Tokens.Sizes.globalAvatarPicker` in GroupScreen.swift, GroupSettingsScreen.swift, PeopleRow.swift, SettingsBlockedScreen.swift |
| matched | `birthday.request.title` | “{name}'s birthday video” (SOURCED) | memory pass supplies the copy (`MemoryEntryContent`); GroupScreen.swift hosts `BirthdayRequestsEntry` / `OnThisDayEntry` / `YearStoryEntry` |
| matched | `birthday.request.due` | “Add yours by {date}” (SOURCED) | memory pass supplies the copy (`MemoryEntryContent`); GroupScreen.swift hosts `BirthdayRequestsEntry` / `OnThisDayEntry` / `YearStoryEntry` |
| matched | `icon.global.chevron` | ios: chevron.right; android: AutoMirrored.Rounded.KeyboardArrowRight (PLATFORM) | `Tokens.Icons.globalChevron` in AccountGroupedRows.swift, GroupScreen.swift, GroupedSection.swift, SettingsAccountScreen.swift |
| matched | `groups.screen.week.title` | “Week {number}” (SOURCED) | `Copy.groupsScreenWeekTitle` in GroupScreen.swift |
| matched | `size.global.sectionHeaderToContent` | 11.7 pt (SOURCED) | `Tokens.Sizes.globalSectionHeaderToContent` in CodeScreen.swift, GroupInviteScreen.swift, GroupScreen.swift, GroupsHomeScreen.swift … |
| matched | `size.global.friendCardWidth` | 240 pt (SOURCED) | `Tokens.Sizes.globalFriendCardWidth` in FriendCard.swift, GroupScreen.swift |
| matched | `radius.global.card` | 18 pt (SOURCED) | `Tokens.Radii.globalCard` in FriendCard.swift, GroupScreen.swift, WeekStrip.swift |
| matched | `size.global.cardGap` | 16 pt (SOURCED) | `Tokens.Sizes.globalCardGap` in FriendCard.swift |
| matched | `size.global.avatarList` | 26.5 pt (SOURCED) | `Tokens.Sizes.globalAvatarList` in FriendCard.swift, GroupScreen.swift |
| matched | `layout.global.photoScrim` | color: #000000; startAt: 0.55; startOpacity: 0; endOpacity: 0.6; direction: top → bottom (SOURCED) | `Tokens.Layouts.GlobalPhotoScrim` in ComponentSupport.swift |
| matched | `color.global.textOnMedia` | #FFFFFF (SOURCED) | `Tokens.Colors.globalTextOnMedia` in CircleButton.swift, FullBleedMediaPage.swift, GroupScreen.swift, InvitePreviewView.swift … |
| matched | `icon.global.rewind` | ios: clock.arrow.circlepath; android: Outlined.History (PLATFORM) | `Tokens.Icons.globalRewind` in GroupScreen.swift |
| matched | `icon.global.recap` | ios: film.stack; android: Outlined.VideoLibrary (PLATFORM) | `Tokens.Icons.globalRecap` in GroupScreen.swift |
| matched | `onthisday.entry.title` | “On this day” (SOURCED) | memory pass supplies the copy (`MemoryEntryContent`); GroupScreen.swift hosts `BirthdayRequestsEntry` / `OnThisDayEntry` / `YearStoryEntry` |
| matched | `year.story.entry.title` | “Year in Photos” (SOURCED) | memory pass supplies the copy (`MemoryEntryContent`); GroupScreen.swift hosts `BirthdayRequestsEntry` / `OnThisDayEntry` / `YearStoryEntry` |
| matched | `radius.global.photo` | 0 pt (SOURCED) | 0: grid cells and tiles are square-cornered (no clip) |
| matched | `size.global.stripGap` | 2 pt (SOURCED) | `Tokens.Sizes.globalStripGap` in GroupScreen.swift, PhotoGrid.swift, WeekStrip.swift |

## Elements

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `groups.screen.back.accessibilityLabel` | “Back” (VERIFIED) | `Copy.groupsScreenBackAccessibilityLabel` in GroupScreen.swift |
| matched | `groups.screen.albums.accessibilityLabel` | “Albums” (SOURCED) | `Copy.groupsScreenAlbumsAccessibilityLabel` in GroupScreen.swift |
| matched | `groups.screen.chat` | “Messages” (SOURCED) | `Copy.groupsScreenChat` in GroupScreen.swift |
| matched | `groups.screen.cover.accessibilityLabel` | “{group_name} cover” (VERIFIED) | `Copy.groupsScreenCoverAccessibilityLabel` in GroupScreen.swift |
| matched | `groups.screen.members.accessibilityLabel` | “Members” (SOURCED) | `Copy.groupsScreenMembersAccessibilityLabel` in GroupScreen.swift |
| matched | `groups.screen.settings.accessibilityLabel` | “Settings” (SOURCED) | `Copy.groupsScreenSettingsAccessibilityLabel` in GroupScreen.swift |
| matched | `groups.screen.weeks.accessibilityLabel` | “Past Weeks” (VERIFIED) | `Copy.groupsScreenWeeksAccessibilityLabel` in GroupScreen.swift |
| matched | `size.global.stripTileWidth` | 84 pt (SOURCED) | `Tokens.Sizes.globalStripTileWidth` in WeekStrip.swift |
| matched | `color.global.emptyTileText` | light: #D9D9D9; dark: #515151 (SOURCED) | `Tokens.Colors.globalEmptyTileText` in WeekStrip.swift |
| matched | `groups.screen.photo.accessibilityLabel` | “{date}, photo by {first_name}” (VERIFIED) | `Copy.groupsScreenPhotoAccessibilityLabel` in GroupScreen.swift |
| matched | `groups.screen.week.add.accessibilityLabel` | “Add a photo” (VERIFIED) | `Copy.groupsScreenWeekAddAccessibilityLabel` in GroupScreen.swift |
| matched | `groups.screen.layout.menu` | ios: contextMenu on a grid cell / strip tile (UIMenu with a preview); destructive items role .destructive (red); android: DropdownMenu on long press of a gri… (PLATFORM) | `.contextMenu` on strip tiles, grid cells and friend cards: Report Post / Block {first_name} (destructive), none on own photos |
| matched | `groups.screen.photo.menu.report` | “Report Post” (SOURCED) | `Copy.groupsScreenPhotoMenuReport` in GroupScreen.swift |

## States

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `icon.global.calendar` | ios: calendar; android: Outlined.CalendarMonth (PLATFORM) | `Tokens.Icons.globalCalendar` in GroupScreen.swift |
| matched | `icon.global.add` | ios: plus; android: Rounded.Add (PLATFORM) | `Tokens.Icons.globalAdd` in GroupScreen.swift, GroupsHomeScreen.swift, OutlineCTA.swift, ThumbnailRow.swift … |
| matched | `groups.screen.created.title` | “Let's get started” (SOURCED) | `Copy.groupsScreenCreatedTitle` in GroupScreen.swift |
| matched | `groups.screen.empty.title` | “Nothing has been added to this group” (SOURCED) | `Copy.groupsScreenEmptyTitle` in GroupScreen.swift |
| matched | `groups.screen.error.title` | “Error retrieving your group. Tap here to try again” (SOURCED) | `Copy.groupsScreenErrorTitle` in GroupScreen.swift |
| matched | `groups.screen.offline.title` | “You're offline” (SOURCED) | `Copy.groupsScreenOfflineTitle` in GroupScreen.swift |
| matched | `groups.screen.removed.title` | “Not a member” (SOURCED) | `Copy.groupsScreenRemovedTitle` in GroupScreen.swift |

## Motion

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `spring.global.sheetPresent` | response: 0.347; dampingFraction: 1 (SOURCED) | system sheet presentation (`.sheet`) |
| matched | `duration.global.photoOpen` | 250 ms (SOURCED) | `Tokens.Durations.globalPhotoOpen` in ComponentSupport.swift |
| matched | `easing.global.standard` | x1: 0.4; y1: 0; x2: 0.2; y2: 1 (SOURCED) | `Tokens.Easings.globalStandard` in AgeGateForm.swift, ComponentSupport.swift, GroupCreateScreen.swift, GroupInviteScreen.swift … |
| matched | `duration.global.stripInsert` | 250 ms (SOURCED) | `Tokens.Durations.globalStripInsert` in ComponentSupport.swift |
| matched | `duration.global.fade` | 150 ms (SOURCED) | `Tokens.Durations.globalFade` in ComponentSupport.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, PaywallScreen.swift … |
| matched | `duration.global.crossfade` | 100 ms (SOURCED) | `Tokens.Durations.globalCrossfade` in AgeGateForm.swift, ComponentSupport.swift |

## Haptics

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | Android only — iOS presses play no haptic |
| matched | `haptic.global.longPressStart` | ios: system (context menu plays its own haptic; no custom generator); android: LONG_PRESS (PLATFORM) | the system context menu's own haptic (`.contextMenu`) |

## Notes

- The week strip and photo grid are local variants (`GroupWeekStrip`, `GroupPhotoGrid`) because C-17 / C-21 have no per-cell context menu (component gap).
- Memory feed cards are `MemoryFeedCard` (C-18 geometry) fed by the memory pass's `MemoryEntryContent` (photo, glyph, copy).
- "Recaps" opens the recap list sheet (`AppModal.social(.recaps)`), or week.history while the group has no recap.

# Verification — `groups.screen` (iOS)

Group feed (view A) and profile page (view B) — `Screens/GroupScreen.swift`, `Features/Account/Groups/GroupProfileScreen.swift`.

Checklist written from the spec (`design/surfaces/groups.screen.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/groups.screen.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Reference image(s): `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t43.73-group-screen-hourly.png`, `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t51.23-group-created-empty-state.png`, `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t51.73-group-profile-add-20-pics.png`, `references/auto/yope/store/yope-store-01.png`, `references/auto/yope/frames/a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png`, `references/auto/yope/web/a-bi-2025-create-group-composite.jpg`, `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t8.73-group-wall-header.png`

Snapshots (CI): `groups.screen-loading.png`, `groups.screen-loaded.png`, `groups.screen-profile.png`, `groups.screen-created.png`, `groups.screen-empty.png`, `groups.screen-error.png`, `groups.screen-offline.png`, `groups.screen-removed.png`

**Summary: 93 matched · 6 approximated · 0 not matched (BLOCKED or not buildable) · 1 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | token | `groups.screen.layout.background` | feed: color.global.background (#171717); profile: color.global.backgroundDeep (#000000) (SOURCED) | screen background of the group feed and of the group profile page | feed `color.global.background`, profile page `color.global.backgroundDeep` |
| matched | token | `size.global.headerButton` | 44 pt (SOURCED) | circle icon buttons in headers (back, close, download, film-strip, search) | `Tokens.…globalHeaderButton` in GroupScreen.swift, HeaderCircleButton.swift |
| matched | token | `color.global.control` | #2E2E2E (SOURCED) | control fill on #171717: header circle buttons, header title capsule, floating tab-bar capsule, composer te… | `Tokens.…globalControl` in FloatingTabBar.swift, GroupProfileScreen.swift, GroupScreen.swift |
| matched | token | `icon.global.back` | ios: chevron.left; android: AutoMirrored.Rounded.KeyboardArrowLeft (PLATFORM) | back (‹ in a header circle) | `Tokens.…globalBack` in GroupProfileScreen.swift, GroupScreen.swift |
| matched | token | `size.global.headerInset` | 11.5 pt (SOURCED) | screen edge to the first / last header circle | `Tokens.…globalHeaderInset` in GroupProfileScreen.swift, GroupScreen.swift |
| matched | token | `size.global.headerGap` | 7.3 pt (SOURCED) | gap between the back circle and the header title capsule | `Tokens.…globalHeaderGap` in GroupScreen.swift |
| matched | token | `radius.global.capsule` | shape: capsule; radius: height / 2 (SOURCED) | full pill: header title capsule, composer text field, chat bubbles, tab-bar capsule, tooltip ends, white se… | Capsule() shape |
| matched | token | `size.global.avatarHeader` | 28 pt (SOURCED) | group avatar inside the header capsule | `Tokens.…globalAvatarHeader` in GroupScreen.swift |
| matched | token | `fontSize.global.headerTitle` | 15 pt (SOURCED) | group name in the header capsule | `Tokens.…globalHeaderTitle` in TextRoles.swift |
| matched | token | `fontWeight.global.headerTitle` | bold (SOURCED) | group name in the header capsule | `Tokens.…fontWeightGlobalHeaderTitle` in TextRoles.swift |
| matched | token | `color.global.textPrimary` | #FFFFFF (SOURCED) | primary text and glyphs | `Tokens.…globalTextPrimary` in CheckRow.swift, EmptyStateView.swift, FloatingTabBar.swift |
| matched | token | `icon.global.chevron` | ios: chevron.right; android: AutoMirrored.Rounded.KeyboardArrowRight (PLATFORM) | disclosure / forward (› at the end of the header capsule) | `Tokens.…globalChevron` in GroupScreen.swift |
| matched | token | `color.global.textSecondary` | #969696 (SOURCED) | secondary text, placeholders ('start typing...'), inactive tab-bar glyphs, chevrons inside capsules | `Tokens.…globalTextSecondary` in CheckRow.swift, EmptyStateView.swift, FloatingTabBar.swift |
| matched | token | `icon.global.calendar` | ios: calendar; android: Rounded.CalendarMonth (PLATFORM) | calendar circle in the group header | `Tokens.…globalCalendar` in GroupScreen.swift |
| matched | token | `icon.global.recap` | ios: film.stack; android: Rounded.VideoLibrary (PLATFORM) | recap entry in a header circle (film frame with stacked lines, outline) | `Tokens.…globalRecap` in GroupScreen.swift |
| matched | token | `groups.screen.size.cardMarginH` | 7.6 pt (SOURCED) | photo card side margin | `Tokens.…groupsScreenSizeCardMarginH` in GroupScreen.swift |
| matched | token | `groups.screen.size.cardHeight` | 152 pt (SOURCED) | photo card height on the group screen (one card per post, photo cropped to fill) | `Tokens.…groupsScreenSizeCardHeight` in GroupScreen.swift |
| matched | token | `groups.screen.radius.card` | 20 pt (SOURCED) | photo card corner radius | `Tokens.…groupsScreenRadiusCard` in GroupScreen.swift |
| matched | token | `groups.screen.size.cardGap` | 8.5 pt (SOURCED) | vertical gap between photo cards | `Tokens.…groupsScreenSizeCardGap` in GroupScreen.swift |
| matched | token | `fontSize.global.overlayTime` | 21 pt (SOURCED) | hour / time overlay centred on a photo in the chat ('10:00 PM') | `Tokens.…globalOverlayTime` in TextRoles.swift |
| matched | token | `fontWeight.global.overlayTime` | heavy (SOURCED) | time overlay on a photo | `Tokens.…fontWeightGlobalOverlayTime` in TextRoles.swift |
| matched | token | `fontSize.global.listSubtitle` | 14 pt (SOURCED) | row subtitle ('new pic added · 9:43 AM'), secondary color | `Tokens.…globalListSubtitle` in TextRoles.swift |
| matched | token | `fontWeight.global.listSubtitle` | regular (SOURCED) | row subtitle | `Tokens.…fontWeightGlobalListSubtitle` in TextRoles.swift |
| matched | copy | `groups.screen.memberJoined` | “{first_name} joined” (SOURCED) |  | `Copy.…groupsScreenMemberJoined` in GroupScreen.swift |
| matched | token | `size.global.avatarSmall` | 32.6 pt (SOURCED) | small avatar: chat sender, send-to recipient row | `Tokens.…globalAvatarSmall` in GroupScreen.swift, StorageImage.swift |
| matched | token | `groups.screen.size.chatPillWidth` | 88 pt (SOURCED) | floating 'chat' pill width (bottom centre) | `Tokens.…groupsScreenSizeChatPillWidth` in GroupScreen.swift |
| matched | token | `groups.screen.size.chatPillHeight` | 51 pt (SOURCED) | floating 'chat' pill height | `Tokens.…groupsScreenSizeChatPillHeight` in GroupScreen.swift |
| matched | token | `groups.screen.color.chatPill` | #080808 (SOURCED) | floating 'chat' pill fill | `Tokens.…groupsScreenColorChatPill` in GroupScreen.swift |
| matched | token | `radius.global.button` | 14 pt (SOURCED) | primary (lime) button corners — not a full pill | `Tokens.…globalButton` in GroupScreen.swift, PrimaryButton.swift, TextRoles.swift |
| matched | token | `icon.global.chats` | ios: bubble.left.and.bubble.right.fill; android: Rounded.Forum (PLATFORM) | chats tab (two overlapping bubbles) | `Tokens.…globalChats` in FloatingTabBar.swift, GroupScreen.swift |
| matched | copy | `groups.screen.chat` | “chat” (SOURCED) |  | `Copy.…groupsScreenChat` in GroupScreen.swift |
| matched | token | `groups.screen.fontSize.chatPill` | 15 pt (SOURCED) | 'chat' label in the pill (bold, white, after icon.global.chats) | `Tokens.…groupsScreenFontSizeChatPill` in GroupScreen.swift |
| matched | token | `color.global.controlOnDeep` | #101010 (SOURCED) | header circle icon buttons on black screens and sheets (✕, download) | `Tokens.…globalControlOnDeep` in HeaderCircleButton.swift |
| matched | token | `icon.global.more` | ios: ellipsis; android: Rounded.MoreHoriz (PLATFORM) | more (•••) | `Tokens.…globalMore` in GroupProfileScreen.swift, GroupScreen.swift |
| matched | token | `groups.screen.size.profileAvatar` | 92 pt (SOURCED) | group avatar on the group profile page | `Tokens.…groupsScreenSizeProfileAvatar` in GroupProfileScreen.swift |
| matched | token | `icon.global.group` | ios: person.2.fill; android: Rounded.Group (PLATFORM) | group / people | `Tokens.…globalGroup` in GroupProfileScreen.swift, GroupScreen.swift |
| matched | token | `groups.screen.fontSize.profileName` | 25 pt (SOURCED) | group name on the group profile page (bold, white, centred) | `Tokens.…groupsScreenFontSizeProfileName` in GroupScreen.swift |
| matched | token | `groups.screen.fontWeight.profileName` | bold (SOURCED) | group name weight on the profile page | `Tokens.…groupsScreenFontWeightProfileName` in GroupScreen.swift |
| matched | token | `groups.screen.size.segmentHeight` | 41.5 pt (SOURCED) | segmented control track height ('pics / wall / recaps'); also the group-type picker in groups.create | `Tokens.…groupsScreenSizeSegmentHeight` in SegmentedPills.swift |
| matched | token | `groups.screen.size.segmentMarginH` | 6 pt (SOURCED) | segmented control side margin | `Tokens.…groupsScreenSizeSegmentMarginH` in GroupProfileScreen.swift |
| matched | token | `groups.screen.size.segmentInset` | 4 pt (SOURCED) | inset of the selected pill inside the track (selected pill height 33.5 pt) | `Tokens.…groupsScreenSizeSegmentInset` in SegmentedPills.swift |
| matched | token | `groups.screen.color.segmentTrack` | #111111 (SOURCED) | segmented control track fill (on black) | `Tokens.…groupsScreenColorSegmentTrack` in SegmentedPills.swift |
| matched | token | `color.global.surfaceLight` | #FFFFFF (SOURCED) | light pill fill: secondary buttons ('invite more friends', 'enable', 'new recap'), selected segment pill, '… | `Tokens.…globalSurfaceLight` in LightPill.swift, SegmentedPills.swift |
| matched | token | `color.global.onSurfaceLight` | #000000 (SOURCED) | label on the light pill (secondary buttons, selected segment, 'today') | `Tokens.…globalOnSurfaceLight` in LightPill.swift, SegmentedPills.swift |
| matched | token | `groups.screen.fontSize.segmentLabel` | 14.5 pt (SOURCED) | segment labels ('pics', 'wall', 'recaps'): bold, white unselected / black selected | `Tokens.…groupsScreenFontSizeSegmentLabel` in SegmentedPills.swift |
| matched | token | `groups.screen.fontWeight.segmentLabel` | bold (SOURCED) | segment label weight | `Tokens.…groupsScreenFontWeightSegmentLabel` in SegmentedPills.swift |
| matched | token | `radius.global.photo` | 15 pt (SOURCED) | photo corners in the thread and in grids of walls | `Tokens.…globalPhoto` in GroupProfileScreen.swift |
| matched | token | `groups.screen.layout.menu` | ios: Menu (UIMenu) from the ••• circle; items with trailing SF Symbols; destructive items role .destructive (red); android: DropdownMenu anchored to the ••• … (PLATFORM) | group profile ••• menu (share invite, group settings, leave group, report) | Menu from the ••• circle; destructive items role .destructive |
| matched | copy | `groups.screen.menu.shareInvite` | “share invite” (SOURCED) |  | `Copy.…groupsScreenMenuShareInvite` in GroupProfileScreen.swift |
| matched | token | `icon.global.share` | ios: square.and.arrow.up; android: Rounded.IosShare (PLATFORM) | share (square + up arrow) | `Tokens.…globalShare` in GroupProfileScreen.swift |
| matched | copy | `groups.screen.menu.settings` | “group settings” (SOURCED) |  | `Copy.…groupsScreenMenuSettings` in GroupProfileScreen.swift |
| matched | token | `icon.global.settings` | ios: gearshape; android: Rounded.Settings (PLATFORM) | settings entry | `Tokens.…globalSettings` in GroupProfileScreen.swift |
| matched | copy | `groups.screen.menu.leave` | “leave group” (SOURCED) |  | `Copy.…groupsScreenMenuLeave` in GroupProfileScreen.swift |
| matched | token | `icon.global.leave` | ios: rectangle.portrait.and.arrow.right; android: AutoMirrored.Rounded.Logout (PLATFORM) | leave group (menu item, destructive color) | `Tokens.…globalLeave` in GroupProfileScreen.swift |
| matched | copy | `groups.screen.menu.report` | “report” (SOURCED) |  | `Copy.…groupsScreenMenuReport` in GroupProfileScreen.swift |
| matched | token | `icon.global.report` | ios: flag.fill; android: Rounded.Flag (PLATFORM) | report (menu item, destructive color) | `Tokens.…globalReport` in GroupProfileScreen.swift, GroupScreen.swift |
| matched | copy | `groups.screen.back.accessibilityLabel` | “back” (SOURCED) |  | `Copy.…groupsScreenBackAccessibilityLabel` in GroupProfileScreen.swift, GroupScreen.swift |
| matched | copy | `groups.screen.header.accessibilityLabel` | “{group_name}, group info” (SOURCED) |  | `Copy.…groupsScreenHeaderAccessibilityLabel` in GroupScreen.swift |
| matched | copy | `groups.screen.weeks.accessibilityLabel` | “past weeks” (SOURCED) |  | `Copy.…groupsScreenWeeksAccessibilityLabel` in GroupScreen.swift |
| matched | copy | `groups.screen.recap.accessibilityLabel` | “recaps” (SOURCED) |  | `Copy.…groupsScreenRecapAccessibilityLabel` in GroupScreen.swift |
| matched | copy | `groups.screen.photo.accessibilityLabel` | “pic from {first_name}, {time}” (SOURCED) |  | `Copy.…groupsScreenPhotoAccessibilityLabel` in GroupProfileScreen.swift, GroupScreen.swift |
| matched | token | `color.global.controlRaised` | #434343 (SOURCED) | raised fill: selected tab pill, inner pill inside the header capsule, inactive page dots | `Tokens.…globalControlRaised` in FloatingTabBar.swift, GroupScreen.swift, StorageImage.swift |
| matched | copy | `groups.screen.photo.more.accessibilityLabel` | “more” (SOURCED) |  | `Copy.…groupsScreenPhotoMoreAccessibilityLabel` in GroupScreen.swift |
| matched | copy | `groups.screen.photo.menu.report` | “Report…” (VERIFIED) |  | `Copy.…groupsScreenPhotoMenuReport` in GroupScreen.swift |
| matched | copy | `groups.screen.photo.menu.block` | “Block {first_name}” (VERIFIED) |  | `Copy.…groupsScreenPhotoMenuBlock` in GroupScreen.swift |
| matched | copy | `groups.screen.photo.menu.open` | “Open” (VERIFIED) |  | `Copy.…groupsScreenPhotoMenuOpen` in GroupScreen.swift |
| matched | token | `safety.block.layout.menu` | ios: Menu (UIMenu) item with role .destructive; android: DropdownMenu item (M3 baseline: 48 dp items, 4 dp container corner, labelLarge) in color.global.syst… (VERIFIED) | 'Block' / 'Report…' items in overflow menus | Menu item with role .destructive |
| matched | token | `fontSize.global.emptyTitle` | 16 pt (SOURCED) | empty-state title ('you created group') | `Tokens.…globalEmptyTitle` in TextRoles.swift |
| matched | token | `fontWeight.global.emptyTitle` | bold (SOURCED) | empty-state title | `Tokens.…fontWeightGlobalEmptyTitle` in TextRoles.swift |
| matched | token | `fontSize.global.emptyDetail` | 14 pt (SOURCED) | empty-state detail line ('and added mẹ, Anh'), italic | `Tokens.…globalEmptyDetail` in TextRoles.swift |
| matched | token | `groups.screen.size.lightPillHeight` | 45 pt (SOURCED) | white secondary pill height ('invite more friends', 205 pt wide = hug + leading icon.global.link) | `Tokens.…groupsScreenSizeLightPillHeight` in LightPill.swift |
| matched | token | `groups.screen.radius.lightPill` | 11 pt (SOURCED) | white secondary pill ('invite more friends') corner radius | `Tokens.…groupsScreenRadiusLightPill` in LightPill.swift |
| matched | token | `icon.global.link` | ios: link; android: Rounded.Link (PLATFORM) | invite link | `Tokens.…globalLink` in GroupScreen.swift |
| matched | copy | `groups.screen.created.title` | “you created group” (SOURCED) |  | `Copy.…groupsScreenCreatedTitle` in GroupScreen.swift |
| matched | copy | `groups.screen.created.detail` | “and added {names}” (SOURCED) |  | `Copy.…groupsScreenCreatedDetail` in GroupScreen.swift |
| matched | copy | `groups.screen.created.invite.friends` | “invite more friends” (SOURCED) |  | `Copy.…groupsScreenCreatedInviteFriends` in GroupScreen.swift |
| matched | copy | `groups.screen.created.invite.family` | “invite more family” (SOURCED) |  | `Copy.…groupsScreenCreatedInviteFamily` in GroupScreen.swift |
| matched | copy | `groups.screen.created.invite.roommates` | “invite more roommates” (SOURCED) |  | `Copy.…groupsScreenCreatedInviteRoommates` in GroupScreen.swift |
| matched | copy | `groups.screen.created.invite.custom` | “invite more people” (SOURCED) |  | `Copy.…groupsScreenCreatedInviteCustom` in GroupScreen.swift |
| matched | copy | `groups.screen.profile.segment.pics` | “pics” (SOURCED) |  | `Copy.…groupsScreenProfileSegmentPics` in GroupProfileScreen.swift |
| matched | copy | `groups.screen.profile.segment.wall` | “wall” (SOURCED) |  | `Copy.…groupsScreenProfileSegmentWall` in GroupProfileScreen.swift |
| matched | copy | `groups.screen.profile.segment.recaps` | “recaps” (SOURCED) |  | `Copy.…groupsScreenProfileSegmentRecaps` in GroupProfileScreen.swift |
| matched | copy | `groups.screen.profile.more.accessibilityLabel` | “group options” (SOURCED) |  | `Copy.…groupsScreenProfileMoreAccessibilityLabel` in GroupProfileScreen.swift |
| matched | copy | `groups.create.hud.loading` | “Loading” (SOURCED) |  | `Copy.…groupsCreateHudLoading` in LoadingHUD.swift |
| matched | token | `icon.global.camera` | ios: camera.fill; android: Rounded.PhotoCamera (PLATFORM) | camera (composer button, row quick-camera, camera tab) | `Tokens.…globalCamera` in FloatingTabBar.swift, GroupScreen.swift |
| matched | copy | `groups.screen.empty.title` | “no pics yet” (SOURCED) |  | `Copy.…groupsScreenEmptyTitle` in GroupScreen.swift |
| matched | copy | `groups.screen.empty.detail` | “share the first one” (SOURCED) |  | `Copy.…groupsScreenEmptyDetail` in GroupScreen.swift |
| matched | copy | `groups.screen.empty.button` | “take a pic” (SOURCED) |  | `Copy.…groupsScreenEmptyButton` in GroupScreen.swift |
| matched | copy | `groups.screen.removed.title` | “you’re not in this group anymore” (SOURCED) |  | `Copy.…groupsScreenRemovedTitle` in GroupScreen.swift |
| matched | copy | `groups.screen.removed.detail` | “ask someone in it to send you a new link” (SOURCED) |  | `Copy.…groupsScreenRemovedDetail` in GroupScreen.swift |
| matched | token | `haptic.global.longPressStart` | ios: system (context menu plays its own haptic; no custom generator); android: LONG_PRESS (PLATFORM) | a long press starts (context menu) | system Menu haptic |
| matched | token | `haptic.global.select` | ios: selection; android: SEGMENT_TICK (PLATFORM) | a recipient / group toggled, a segmented choice, picker scrubbing | `Tokens.…globalSelect` in CheckRow.swift, SegmentedPills.swift |
| n/a | token | `color.global.scrim` | #00000080 (SOURCED) | dimming layer behind sheets / over photos under text on app surfaces | the spec places no scrim (time overlay on photos is photo-dependent); none drawn |
| matched | token | `color.global.background` | #171717 (SOURCED) | screen background of group, chat and profile-grid screens (dark gray, not black) | `Tokens.…globalBackground` in GroupScreen.swift |

## Approximations

- Header capsule inner insets = (headerButton − avatarHeader) / 2 (not measured).
- Photo card ••• circle: icon.global.more on controlRaised, insets = cardGap (spec Gaps).
- Chat pill corners `radius.global.button` (not measured).
- "joined" pill: hugs the avatar, trailing padding = avatarSmall / 2 (not measured).
- Memory entry rows (onthisday / year.story / birthday.request, placed here per their specs): the groups.list card look (no Yope entry row was observed).
- Profile pics grid reuses the walls.mine grid tokens; cover ⌄ gap = listGap (not measured).

# `groups.list` — group list / home

Reference: **Yope** home list. Research: `design/research/yope-a.md` §1.5, §2.9; foundations `design/tokens/README.md`.
Tokens: `groups.list.*` + global. Copy: `groups.list.*`.

## References

| id | file | used for |
|---|---|---|
| H1 | `references/auto/yope/frames/a-savannahclooney-7683341732695592206-t6.73-home-list.png` (2026-09, en) | cover header, header circles, cards (#181818, ≈100 pt, 7.5 gap, 12 margin, r 17), avatar 64 at 16 inset, name 17.5 bold, subtitle "new pic added · 10:10 AM", sender name in lime, camera glyph |
| H2 | `references/auto/yope/frames/a-virgi-7686278541255642390-t40.23-home-list-es.png` (2026-09) | card height cross-check (101.6 pt) |
| H3 | `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t44.23-home-list-new-group-icon.png` (2026-05) | "you’re friends!✨ share a pic?", add-people glyph → "new group" |
| H4 | `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png` (2026-10) | cover height, ⌄, 4-item tab bar (camera, chats, wall, me) |
| TB | `references/auto/yope/store/yope-store-02.png` | tab-bar sizes (global tokens) |
| BI | `references/auto/yope/web/a-bi-2025-onboarding-composite.jpg` | empty-state copy "create your first group" / "to share pics daily and get recaps on your memories" / "create group" |

## Structure (black `color.global.backgroundDeep`, scrolls vertically)

1. **Cover header**: the newest photo across the person's groups, full-bleed from the top edge (under the status bar),
   height `groups.list.size.coverHeight`, rounded bottom corners (radius not measured: Gaps), image `scaledToFill`.
   ⌄ (`icon.global.chevronDown`, white) centred ≈8 pt under the cover (decorative scroll hint).
   Tapping the cover opens that photo (`photo.viewer`).
2. **Header circles over the cover**, top row at the safe area, inset `size.global.headerInset`: the trailing "+"
   circle (`size.global.headerButton`, glyph `icon.global.add`) → `groups.create`. Fill
   `groups.list.color.headerCircleOverPhoto` (#00000094, solved on the 2026 Yope home). Yope's leading search circle (friend search) and centre wordmark are
   not built (Do-not-copy).
3. **Group cards**, one per group, newest activity first; gap `size.global.listGap`; side margin `size.global.screenMargin`;
   first card `size.global.listGap` under the ⌄.
4. **Floating tab bar** over the bottom (`groups.list.layout.tabBar`), inset `size.global.tabBarInset`.

### Card (left → right)

avatar (group cover in a circle) · text block (name; subtitle) · trailing camera glyph.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| card | fill `groups.list.color.card`; height `groups.list.size.cardHeight`; corners `radius.global.card` | row label `groups.list.row.accessibilityLabel` | tap → `groups.screen`; long press: nothing (not observed) |
| avatar | `size.global.avatarList`, inset `groups.list.size.avatarInset`, circle; empty cover → `color.global.controlRaised` + `icon.global.group` in `color.global.textSecondary` | — | — |
| name | `fontSize.global.listTitle`, `fontWeight.global.listTitle`, `color.global.textPrimary`, one line, tail truncation | group name (data) | — |
| subtitle | `fontSize.global.listSubtitle`, `fontWeight.global.listSubtitle`, `color.global.textSecondary`; sender `{first_name}` in `color.global.accent` | `groups.list.row.sentPic` / `groups.list.row.newPic` / `groups.list.row.noPics` | {time} = newest post time, `h:mm AM/PM` (today) |
| camera glyph | `icon.global.camera`, `groups.list.size.cameraGlyph`, `color.global.textPrimary`, trailing inset `groups.list.size.avatarInset`; hit area `size.global.minTouchTarget.*` | `groups.list.row.camera.accessibilityLabel` | → `camera.capture` with the group preselected (`DeepLink.camera(groupID:)`) |
| cover | `groups.list.size.coverHeight`; ⌄ `icon.global.chevronDown` | `groups.list.cover.accessibilityLabel` | tap → `photo.viewer` |
| + circle | `size.global.headerButton`, `icon.global.add`, `groups.list.color.headerCircleOverPhoto` | `groups.list.header.add.accessibilityLabel` | → `groups.create` |
| tab bar | `size.global.tabBarWidth`, `.tabBarHeight`, `.tabBarInset`, `.tabBarSelectedWidth`, `.tabBarSelectedHeight`, `.tabBarIcon`, `.tabBarAvatar`; `color.global.control`, `.controlRaised`, `.textPrimary`, `.textSecondary`; `radius.global.capsule`; icons `icon.global.camera`, `icon.global.chats`, `icon.global.wall`, own avatar | `groups.list.tab.camera.accessibilityLabel`, `.groups`, `.walls`, `.me` | camera → `camera.capture`; groups = this screen; walls → `walls.browse`; me → `walls.mine` (where the settings circle lives) |

## States

| state | when | design | copy |
|---|---|---|---|
| loading | first fetch | Loading HUD (`groups.create.color.hud`, `.size.hud`, `.fontSize.hudLabel`) centred | `groups.create.hud.loading` |
| empty | no groups | no cover; Yope's 2025 "create your first group" screen (BI): two-line title (`fontSize.global.onboardingTitle`, `fontWeight.global.onboardingTitle`, second line lime per `groups.create.layout.titleAccent`), detail under it (`auth.phone.fontSize.subtitle`, `auth.phone.layout.subtitle`), lime primary button (`color.global.accent`, `size.global.buttonHeight`, `size.global.buttonMarginH`, `radius.global.button`) `groups.create.size.titleToContent` below; vertically centred above the tab bar | `groups.list.empty.title`, `groups.list.empty.detail`, `groups.list.empty.button` (→ `groups.create`) |
| error | fetch failed | Yope empty-state layout centred: title `fontSize.global.emptyTitle` bold, detail `fontSize.global.emptyDetail` italic `color.global.textSecondary`, white pill (`color.global.surfaceLight`, `groups.screen.size.lightPillHeight`, `groups.screen.radius.lightPill`, label `color.global.onSurfaceLight` text role `button`) | `groups.list.error.title`, `.detail`, `.retry` |
| offline | no connection and nothing cached | same layout, no pill | `groups.list.offline.title`, `groups.list.offline.detail` |
| offline with cache | cached rows shown; nothing else changes | — | — |
| permission-denied | — | none | — |

## Motion

Pull-to-refresh: system refresh control (`haptic` system). Push to `groups.screen`: native navigation push
(`easing.global.native`). No row animations (Yope's flame rain is do-not-copy). Reduce Motion: platform behaviour.

## Haptics

Pull-to-refresh threshold: system (iOS refresh control; Android `GESTURE_THRESHOLD_ACTIVATE` only if the component lacks it).
No other haptics.

## Accessibility

- Each card is one element (`groups.list.row.accessibilityLabel` = name + subtitle), trait button; the camera glyph is a
  second element. Tab items: buttons with the `groups.list.tab.*` labels, selected trait on the current tab.
- Dynamic Type: name `headline`, subtitle `subheadline`; the card grows in height with the text (minimum
  `groups.list.size.cardHeight`).
- Focus order: + → cover → cards top to bottom (each: card, camera) → tab bar.
- Contrast: card vs black 1.18:1 **FAIL** (non-text; text identifies the card); white on card 17.76:1, #969696 on card
  6.00:1, lime on card 14.92:1, camera glyph 17.76:1 pass. Tab bar pairs: see design/CONTRAST.md (foundations).

## Data & actions

- `groups` (member rows; RLS) + `group_members` (own role) + the newest `posts` per group (`select … order(created_at desc) limit 1`
  per group, docs/API.md §5.8) + `profiles` for sender first names + signed URLs for covers/avatars (§7).
- Realtime: `posts` inserts per group (docs/API.md §8.1) update subtitles and the cover; refetch on foreground/reconnect (§8.3).
- In: app launch with a session (`DeepLinkRouting.home`), end of onboarding, back from any group.
- Out: `groups.screen`, `groups.create`, `camera.capture` (`DeepLink.camera`), `photo.viewer`, `walls.browse`, `walls.mine`.

## Platform notes

- iOS `List`-free custom `ScrollView`/`LazyVStack`; Android `LazyColumn`. The tab bar is the app's own floating capsule on
  both (Yope draws its own; not `TabView`/`NavigationBar`).
- `DeepLink.camera` carries an optional group id on iOS and a required one on Android (`DeepLink.kt`); the row always has one.

## Do-not-copy

- Streak pills (🔥N), red unread badges on rows and tabs, flame rain over rows, the "YOPE" wordmark, friend search /
  "find friends", the discovery tab, "suggested friends" from public discovery, presence dots.

## Gaps

| item | status | smallest capture |
|---|---|---|
| header circle fill over the photo (`groups.list.color.headerCircleOverPhoto`) | SOURCED by gap fill: black at 0.58 ±0.06 solved on the 1080p 60 fps Yope home frame (MERGE G2-6); blur not measured; white glyph over it on a white photo 5.33:1 | one lossless screenshot of the 2026 Yope home with a cover photo |
| cover bottom-corner radius | not measured | same screenshot |
| app wordmark in the header centre | owner asset (app name/logo BLOCKED) | — |
| group card avatar for groups without a cover | approximation (group glyph on the gray role) | — |

# `groups.screen` — group screen (photos, members, entry to chat, walls, week, settings)

Reference: **Yope** group screen (header, hour cards, "chat" pill) and group profile page. Research:
`design/research/yope-a.md` §2.12–2.13; `design/research/yope-b.md` §1 (header values). API: `docs/API.md` §5.3–5.4,
§5.8, §8, §9.6. Tokens: `groups.screen.*` + global. Copy: `groups.screen.*`.

Two views: **A. feed** (the group's photos as stacked cards, header, floating "chat" pill) and **B. profile page**
(tap the header capsule: avatar, name, segmented "pics | wall | recaps", ••• menu).

## References

| id | file | used for |
|---|---|---|
| G1 | `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t43.73-group-screen-hourly.png` (2026-05) | header (‹, capsule, calendar, recap), photo cards 378 × 152 pt r 20, gap 8.5, "chat" pill 88 × 51 |
| G2 | `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t51.23-group-created-empty-state.png` | created empty state, white pill r 11 |
| G3 | `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t51.73-group-profile-add-20-pics.png` | profile page: ‹, •••, avatar 92, name 25 bold, segmented control |
| S1 | `references/auto/yope/store/yope-store-01.png` (lossless) | header capsule geometry (avatar 28, name 15 bold, ›), background #171717 |
| M24 | `references/auto/yope/frames/a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png` | ••• native menu: "share invite", "leave group" (red), "report" (red) |
| BI | `references/auto/yope/web/a-bi-2025-create-group-composite.jpg` | "Kailyn joined" system pill between photos |
| G4 | `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t8.73-group-wall-header.png` (2026-10, 1:1 space) | conflict only (taller cards, black background) |

## A. Feed — structure (background per `groups.screen.layout.background` → feed)

1. Header row (S1, matches yope-b header values): ‹ circle (`size.global.headerButton`, fill `color.global.control`,
   `icon.global.back`, inset `size.global.headerInset`); gap `size.global.headerGap`; **capsule** (height
   `size.global.headerButton`, fill `color.global.control`, `radius.global.capsule`, hugs content up to the space left):
   group avatar `size.global.avatarHeader` · name (`fontSize.global.headerTitle`, `fontWeight.global.headerTitle`,
   `color.global.textPrimary`, one line) · `icon.global.chevron` in `color.global.textSecondary`; trailing circles:
   calendar (`icon.global.calendar`) and recap (`icon.global.recap`), each `size.global.headerButton`, `color.global.control`,
   `size.global.headerGap` apart, inset `size.global.headerInset`.
2. Photo cards, newest at the top, one per post: full width minus `groups.screen.size.cardMarginH` each side, height
   `groups.screen.size.cardHeight`, corners `groups.screen.radius.card`, gap `groups.screen.size.cardGap`; photo
   `scaledToFill`. On the card: time centred (`fontSize.global.overlayTime`, `fontWeight.global.overlayTime`, white,
   `h:mm AM/PM`); caption under the time (`fontSize.global.listSubtitle`, white); author avatar
   (`size.global.avatarHeader`) + first name (`fontSize.global.listSubtitle`, `fontWeight.global.listSubtitle`, white) at the
   bottom-leading corner, `groups.screen.size.cardGap` from the card edges (insets not measured, see Gaps); ••• circle at
   the bottom-trailing corner. A dual-capture post shows its back
   image; Live Photos and videos follow `photo.viewer`.
3. "{first_name} joined" system pills between cards at the joining time (`groups.screen.memberJoined`; pill = capsule,
   fill `color.global.control`, text `fontSize.global.listSubtitle` `color.global.textPrimary`, avatar
   `size.global.avatarSmall` leading — from BI, sizes not measured).
4. Floating "chat" pill, bottom centre above the home indicator: `groups.screen.size.chatPillWidth` ×
   `.chatPillHeight`, fill `groups.screen.color.chatPill`, corners `radius.global.button` (approximation: rounded square
   ends, not measured), `icon.global.chats` + label `groups.screen.chat` (`groups.screen.fontSize.chatPill`, bold, white).

## B. Profile page — structure (background → profile, black)

1. Header row: ‹ circle (fill `color.global.controlOnDeep`) leading; ••• circle (`icon.global.more`) trailing.
2. Group avatar `groups.screen.size.profileAvatar`, centred (cover, or the gray + `icon.global.group` fallback).
3. Name `groups.screen.fontSize.profileName` / `.fontWeight.profileName`, white, centred, up to 2 lines.
4. Member avatars row (overlapping circles, `size.global.avatarSmall`, no count) → `groups.settings` members.
5. Segmented control (`groups.screen.size.segmentHeight`, `.segmentMarginH`, `.segmentInset`, track
   `groups.screen.color.segmentTrack`, selected `color.global.surfaceLight` / `color.global.onSurfaceLight`, labels
   `groups.screen.fontSize.segmentLabel` / `.fontWeight.segmentLabel`): pics → grid of the group's photos
   (`radius.global.photo`); wall → `walls.browse` scoped to this group's members; recaps → `week.history`.
6. ••• menu (`groups.screen.layout.menu`, native): `groups.screen.menu.shareInvite` (`icon.global.share`),
   `groups.screen.menu.settings` (`icon.global.settings`), `groups.screen.menu.leave` (`icon.global.leave`, destructive),
   `groups.screen.menu.report` (`icon.global.report`, destructive).

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| ‹ | as Structure | `groups.screen.back.accessibilityLabel` | pop |
| capsule | as Structure | `groups.screen.header.accessibilityLabel` | → B (profile) |
| calendar | `icon.global.calendar` | `groups.screen.weeks.accessibilityLabel` | → `week.history` |
| recap | `icon.global.recap` | `groups.screen.recap.accessibilityLabel` | → latest `week.recap` (or `week.history` when none) |
| photo card | card tokens above | `groups.screen.photo.accessibilityLabel` ({first_name}, {time}) | tap → `photo.viewer`; long press = `photo.viewer` reactions (that pass) |
| ••• on card | circle `size.global.avatarHeader`-sized hit area ≥ `size.global.minTouchTarget.*`, `icon.global.more`, fill `color.global.controlRaised` (approximation) | `groups.screen.photo.more.accessibilityLabel`; menu `groups.screen.photo.menu.report`, `.block` (others' photos) / `.open` (own) | native menu (`safety.block.layout.menu`) → `safety.report` (post) / `safety.block` (author) |
| chat pill | `groups.screen.size.chatPill*`, `.color.chatPill`, `.fontSize.chatPill`, `icon.global.chats` | `groups.screen.chat` | → `chat.thread` |
| created empty state | `fontSize.global.emptyTitle` / `fontWeight.global.emptyTitle`; `fontSize.global.emptyDetail` italic `color.global.textSecondary`; pill `color.global.surfaceLight`, `groups.screen.size.lightPillHeight`, `groups.screen.radius.lightPill`, `icon.global.link`, label text role `button` | `groups.screen.created.title`, `.detail` ({names}), `groups.screen.created.invite.friends` / `.family` / `.roommates` / `.custom` | pill → `groups.invite` |
| segmented | as B.5 | `groups.screen.profile.segment.pics`, `.wall`, `.recaps` | switches the page content |
| ••• (profile) | `size.global.headerButton`, `icon.global.more` | `groups.screen.profile.more.accessibilityLabel`; items `groups.screen.menu.*` | leave → `groups.settings` leave alert; report → `safety.report` (group) |

## States

| state | when | design | copy |
|---|---|---|---|
| loading | first fetch | Loading HUD centred | `groups.create.hud.loading` |
| created (empty) | the viewer created it and no posts exist | Yope created empty state centred in the feed (G2) | `groups.screen.created.*` (+ per-type invite pill) |
| empty | joined group without posts | same layout; pill with `icon.global.camera` | `groups.screen.empty.title`, `.detail`, `.button` (→ `camera.capture`) |
| error | fetch failed | same layout + retry pill | `groups.screen.error.*` |
| offline | no connection | cached cards stay; with no cache, the layout without pill | `groups.screen.offline.*` |
| removed | `not_group_member` | layout without pill; ‹ returns home | `groups.screen.removed.title`, `.detail` |
| blocked author | posts of a blocked person are absent (RLS) | nothing shown, no placeholder | — |
| permission-denied | — | none | — |

## Motion

Push in from `groups.list`; profile page = native push; menu = native. New post insert (realtime): the card appears at
the top with `spring.global.platformDefault.*` (Yope's arrival motion not measured); Reduce Motion → cross-fade.

## Haptics

Menu open: system (`haptic.global.longPressStart`). Segment change → `haptic.global.select`. No haptic on new posts.

## Accessibility

- Header: three buttons + capsule button. Cards: image elements with `groups.screen.photo.accessibilityLabel`, caption as
  value; ••• a separate button. Announce new cards (`UIAccessibility.post(.layoutChanged)` / `announceForAccessibility`)
  only while the screen is focused.
- Dynamic Type: header title `subheadline`; time overlay `title2`; caption/name `subheadline`; chat label `subheadline`;
  profile name 25 → `title1`; segments `subheadline`.
- Focus order (feed): ‹ → capsule → calendar → recap → cards (top to bottom: image, •••) → chat.
- Contrast: white on #2E2E2E (header, global pairs) pass; white on chat pill 20.03:1 pass; chat pill vs #171717 1.12:1 and
  vs black 1.05:1 **FAIL** (non-text; label identifies it); white segment label on track 18.88:1; track vs black 1.11:1
  **FAIL**; time overlay on photos: photo-dependent (no scrim is sourced: `color.global.scrim` BLOCKED).

## Data & actions

- Reads: `groups` (+ cover signed URL), `group_members` + `profiles` (avatars, first names, admin), `posts` + `media`
  (`display_path` / `thumb_path` signed URLs), newest first, paged (docs/API.md §5.8, §7).
- Realtime: channel `group-<id>` postgres inserts (`posts`, `messages`, `reactions`) and private broadcast
  `group:<id>` (`post_deleted`, `message_deleted`, `reactions_changed`) (§8). Refetch on foreground / reconnect.
- In: `groups.list`, `groups.create` (new group), invite join, deep links via `DeepLinkRouting` (`post`, `chat`, `recap`
  put this screen in the back stack). Out: `chat.thread`, `photo.viewer`, `week.history`, `week.recap`, `walls.browse`,
  `groups.invite`, `groups.settings`, `safety.report`, `safety.block`, `camera.capture`.

## Platform notes

- Background: the feed uses `color.global.background` (#171717) — Yope draws the 2026-10 1:1 space black; see MERGE A-6.
- iOS menu `Menu` with `Button(role: .destructive)`; Android `DropdownMenu`.

## Do-not-copy

- Placeholder hour slots with a member's avatar for hours they have not posted (an implied obligation), the streak pill in
  the capsule, the red count on the chat pill, "Add 20 pics more to get a recap" progress bar, "new recap" sticker art,
  "friends only see your wall pics" banner (no public walls), the "WALL" wordmark.

## Gaps

| item | status | smallest capture |
|---|---|---|
| on-card author avatar / name / ••• insets and sizes | not measured (G1 video; values above are role reuse) | one lossless screenshot of a 2026 Yope group screen with a filled hour card |
| chat pill corner radius | not measured (`radius.global.button` approximation) | same screenshot |
| feed background in the newest build | conflict (#171717 vs black, MERGE A-6) | same screenshot |
| "joined" pill sizes | not measured (BI JPEG) | same screenshot or BI-quality frame |
| card arrival motion | not measured | one 10-s recording of a Yope group while a friend posts |

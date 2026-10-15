# `walls.browse` — browse the walls of people in your groups

Reference app: **Yope** "me & friends" walls browser (`docs/SURFACES.md`). Research: `design/research/yope-b.md` §5.
Tokens: `design/tokens/social.json` (`walls.browse.*`, grid from `walls.mine.*`) + `global.*`. Copy:
`design/copy/social.json` (`walls.browse.*`). Opened by the **walls** tab (film-strip, `groups.list.layout.tabBar`).

## References

| id | file | used for |
|---|---|---|
| S5-b | `references/auto/yope/frames/b-yopeapp-7591560669967682847-t116.00-me-and-friends.png` (Dec 2025 build) | **primary**: title "me & friends", row of person circles with first names, selected wall below |
| S5-f | `references/auto/yope/frames/b-yopeapp-7591560669967682847-t118.00-friends-wall.png` | wall scrolled (free-form canvas; label "friends wall") |
| S4-p | `references/auto/yope/frames/b-presskit-profile.png` | grid used for the selected wall (S-11) |

## Structure (top → bottom)

Background `color.global.backgroundDeep` (S5-b reads #010002 on black).

1. **Title** `walls.browse.title` ("me & friends"), centred, text role `sheetTitle` (19.5 bold; measured ≈19.8 pt,
   x-height method), `color.global.textPrimary`, baseline `walls.browse.dimension.titleBaseline` (23.6) below the top
   safe-area inset.
2. **Person row** (horizontal scroll), centre `walls.browse.dimension.rowCenter` (93.5) below the top safe-area inset:
   circles `walls.browse.dimension.avatar` (60) at pitch `walls.browse.dimension.avatarPitch` (77.7), the first at
   `walls.browse.dimension.rowInset` (19.7) from the left edge. First circle = **me** (my avatar, label `walls.browse.me`);
   then everyone who shares a group with me, order **BLOCKED** (`walls.browse.layout.rowOrder`). Under each circle the first
   name (data), text role `caption` (12 semibold — measured ≈11.6 pt), `color.global.textPrimary`, centred, baseline
   `walls.browse.dimension.labelBaselineGap` (22) below the circle, one line no wider than the pitch, tail-truncated with
   "..." (S5-b "Our ban...", "friends..."). The selected person's marking is **BLOCKED** (`walls.browse.layout.selection`).
   Yope's first yellow "friends..." circle (everyone's combined wall) is not built: the API has no combined wall (Gaps).
3. **Selected person's wall**, top `walls.browse.dimension.wallTop` (173) below the top safe-area inset: the wall grid of
   `walls.mine.md` §Structure 2 for that person (me → `walls.mine` content; others → `walls.member` content). Scrolls
   vertically under the row (the title and row scroll away with it — S5-f shows the wall scrolled).
4. Floating tab bar overlays the bottom.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| title | text role `sheetTitle`, `color.global.textPrimary`, `walls.browse.dimension.titleBaseline` | `walls.browse.title` | header trait |
| person circle | `walls.browse.dimension.avatar`, `.avatarPitch`, `.rowInset`, `.rowCenter`; avatar image or `icon.global.person` | first name (data) / `walls.browse.me`; label `walls.member.a11y.wall` | tap → selects that person; the wall below switches |
| name label | text role `caption`, `color.global.textPrimary`, `walls.browse.dimension.labelBaselineGap` | first name (data) | — |
| wall grid | `walls.mine.*` grid tokens | tile labels `photo.viewer.a11y.photo` / `walls.browse.a11y.collage` | tap → `photo.viewer` / `collage.view` |

## States

| state | what shows | tokens / copy | source |
|---|---|---|---|
| loading (people) | platform activity indicator centred | `easing.global.native.activityIndicator` | PLATFORM |
| loading (wall) | indicator under the row | same | PLATFORM |
| empty (no groups / nobody else) | the row shows only "me"; below: bold title, gray detail, white pill | `walls.browse.empty.title`, `.empty.detail`, `.empty.action` ("create group" → `groups.create`); text roles `emptyTitle` / `emptyDetail`; pill `color.global.surfaceLight`, `color.global.onSurfaceLight`, `groups.screen.size.lightPillHeight`, `groups.screen.radius.lightPill` | `yope.voice.empty-state` |
| selected person's wall empty | `walls.member.empty.*` (or `walls.mine.empty.*` for me) | as those specs | — |
| error | `walls.mine.error.title`, `chat.thread.error.detail`, retry pill `chat.thread.error.retry` | — | `yope.voice.error` |
| offline | cached content; nothing cached → `chat.thread.offline.title` / `.detail` | — | `yope.voice.error` |
| permission-denied | not applicable | — | — |

## Motion

Switching person: the wall content is replaced (no Yope transition observed; no custom motion). Scrolling: native.
Reduce Motion: system.

## Haptics

| interaction | token |
|---|---|
| person selected in the row | `haptic.global.select` |

## Accessibility

- Row: each circle is a button labelled `walls.member.a11y.wall` ("{name}’s wall"; for me `walls.mine.title`), with the
  selected trait on the current one.
- Focus order: title → row (left → right) → wall tiles.
- Dynamic Type: title → `layout.global.textStyleMap.sheetTitle`; labels → `.caption` (labels keep one line, truncate).
- Hit targets: 60-pt circles exceed the minimum.
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | ratio | result | pair |
|---|---|---|---|---|---|
| `color.global.textPrimary` #FFFFFF | `color.global.backgroundDeep` #000000 | text | 21.00:1 | pass | first-name labels 12 semibold, title |

## Data & actions

- People: `profiles` (§5.1: everyone sharing a group with me) via `group_members` of my groups.
- Wall: `wall(p_user_id)` (§6.4) for the selected person, paged by `p_before`.
- Realtime: `post_deleted` → drop tiles; refetch on foreground.
- Navigation in: walls tab. Out: `photo.viewer`, `collage.view`, `groups.create`. No deep link.

## Platform notes

- iOS: `ScrollView(.horizontal)` row inside the vertical `ScrollView`; Android: `LazyRow` as the first item of the
  `LazyVerticalGrid` (full span).

## Do-not-copy

- Red "new" dots on circles; the numeric chat-tab badge ("3").
- Yellow "friends..." combined-wall circle (no combined wall in the API; also a stack glyph unrelated to our icons).
- Floating camera / share ↗ circles over the wall (camera is the tab bar's; wall export is not a product feature here).
- Free-form canvas with cut-outs and outlines.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| `walls.browse.layout.selection` | BLOCKED (gap fill: no comparable person row with a visible selected state found) | one screenshot of the row after tapping a person |
| `walls.browse.layout.rowOrder` | BLOCKED; approximation: newest wall item first (gap fill: no documented order in a comparable row) | one screenshot of the row before and after a friend posts |
| combined "friends wall" | not built (no API) | owner decision |
| title noun "friends" for family / roommates groups | verbatim kept (S-12) | owner decision |
| measurements from one Dec 2025 video frame | ±1.5–2 pt | 20-s recording (yope-b §14 capture 3) |

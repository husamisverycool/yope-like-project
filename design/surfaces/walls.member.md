# `walls.member` — a member's wall (only photos from shared groups)

Reference app: **Yope** (`docs/SURFACES.md`). Research: `design/research/yope-b.md` §5, §8. Tokens: the shared wall tokens
in `design/tokens/social.json` (`walls.mine.*`, `walls.browse.*`) + `global.*`. Copy: `design/copy/social.json`
(`walls.member.*`). Same grid as `walls.mine.md` (read that spec for the wall rules and S-11).

**Scope rule (data, not design):** `wall(p_user_id)` returns only the person's photos posted in groups **you both belong
to** (and collages of those groups containing one of their photos); nothing for a person you share no group with or have a
block with (docs/API.md §6.4). The screen never says why something is missing. How Yope scopes a friend's wall was not
observed (yope-b §5 "Not found").

## References

| id | file | used for |
|---|---|---|
| S4-p | `references/auto/yope/frames/b-presskit-profile.png` | grid (shared with `walls.mine`) |
| S5-w | `references/auto/yope/frames/b-yopeapp-7591560669967682847-t52.00-1on1-wall.png` | a member's / shared wall fills the screen (free-form canvas — BLOCKED) |
| S5-b | `references/auto/yope/frames/b-yopeapp-7591560669967682847-t116.00-me-and-friends.png` | title placement and size |
| S1 / S6 | `references/auto/yope/store/yope-store-05.png`, `references/auto/yope/frames/b-alexaa-7652512140875566349-t5.83-group-chat-pill.png` | back circle |

## Structure (top → bottom)

Background `color.global.backgroundDeep`.

1. **Header**: back circle at the top-left (`size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.back`,
   `size.global.headerInset`), vertically centred on the title; title = the member's display name (data), centred, text
   role `sheetTitle`, `color.global.textPrimary`, baseline `walls.browse.dimension.titleBaseline` below the top safe-area
   inset, one line, tail truncation.
2. **Wall grid** exactly as `walls.mine.md` §Structure 2 (`walls.mine.count.gridColumns`, `.dimension.gridInset`,
   `.dimension.gridGap`, `.aspectRatio.gridTile`, `.radius.gridTile`, `.layout.gridOrder`), top
   `walls.mine.dimension.titleToGrid` below the title baseline.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| back circle | `size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.back` | `chat.thread.a11y.back` | pops |
| title | text role `sheetTitle`, `color.global.textPrimary`, `walls.browse.dimension.titleBaseline` | display name (data); screen label `walls.member.a11y.wall` | — |
| photo tile | wall grid tokens | `photo.viewer.a11y.photo` | tap → `photo.viewer` (context = this wall) |
| collage tile | wall grid tokens | `walls.browse.a11y.collage` | tap → `collage.view` |

## States

| state | what shows | tokens / copy | source |
|---|---|---|---|
| loading | platform activity indicator under the title | `easing.global.native.activityIndicator` | PLATFORM |
| empty (no shared photos, blocked, or no shared group) | centred bold title + gray detail, no pill | text roles `emptyTitle` / `emptyDetail`; `walls.member.empty.title`, `walls.member.empty.detail` | `yope.voice.empty-state` |
| error | same layout + retry pill | `walls.mine.error.title`, `chat.thread.error.detail`, pill `chat.thread.error.retry` (`groups.screen.size.lightPillHeight`, `groups.screen.radius.lightPill`, `color.global.surfaceLight`) | `yope.voice.error` |
| offline | cached grid; nothing cached → `chat.thread.offline.title` / `.offline.detail` | as listed | `yope.voice.error` |
| permission-denied | not applicable | — | — |

## Motion

Push / pop: native (`easing.global.native.navigationPush`; `duration.global.navigationPush` noted in F-11). Reduce Motion:
system.

## Haptics

None.

## Accessibility

- Screen / title read as `walls.member.a11y.wall` ("{name}’s wall"); tiles `photo.viewer.a11y.photo` / collage label.
- Focus order: back → title → tiles row by row.
- Dynamic Type: title → `layout.global.textStyleMap.sheetTitle`.
- Contrast: same pairs as `walls.mine.md` (white 21.00:1, gray 7.10:1 on black: pass).

## Data & actions

- `wall(p_user_id: member id, p_before, p_limit: 50)` (docs/API.md §6.4); `profiles` (§5.1) for the name.
- Realtime: `post_deleted` on shared groups → drop the tile.
- Navigation in: sender avatar / name in `chat.thread` and `photo.viewer`, a person circle in `walls.browse` (inline there),
  member rows in `groups.settings`. Out: `photo.viewer`, `collage.view`. No deep link.

## Platform notes

As `walls.mine.md`.

## Do-not-copy

- Stranger / discovery profiles ("find friends like you", interests, "things in common") — no public profiles.
- Streaks, "@handle", red "new" dots, profile customisation.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| how Yope scopes a friend's wall | not observed; the API's shared-groups rule is the product rule | one screenshot of a friend's wall in Yope |
| free-form wall canvas | BLOCKED (`walls.mine.layout.freeformWall`) | see `walls.mine.md` |

# `walls.mine` — my wall

Reference app: **Yope** (profile "pics" grid and walls; `docs/SURFACES.md`). Research: `design/research/yope-b.md` §5, §8
(wall composition facts C3–C7), `design/research/yope-a.md` §2.12. Tokens: `design/tokens/social.json` (`walls.mine.*`,
shared by all `walls.*` surfaces) + `global.*`. Copy: `design/copy/social.json` (`walls.mine.*`). Opened by the **me** tab
(`groups.list.layout.tabBar`: "'me' opens walls.mine").

## What a wall is here, and what is built

Yope (2026) has two wall presentations: the **profile "pics" grid** (S4, Jul 2026: 3 columns, 4 pt gaps, rounded tiles)
and the **free-form wall canvas** (9:16 scrapbook of photos of mixed sizes, overlap, rotation, cut-outs; S4 wall.png,
S5 t52.00, C5–C7). The canvas has no observable layout rule (yope-b §5 "Not found: how wall tiles are ordered"), so it
is **BLOCKED** (`walls.mine.layout.freeformWall`). Every wall in this product is built as the profile grid (S-11):
"my photos as a collage" = all my wall items, newest first, in Yope's grid.

## References

| id | file | used for |
|---|---|---|
| S4-p | `references/auto/yope/frames/b-presskit-profile.png` (402 × 874 pt @2x, exact; 2026-07-22) | **primary**: 3-column grid, gaps, insets, tile corners, black background, title → grid gap |
| S3 | `references/auto/yope/frames/b-play-05.png`, `b-derot-play-05-rot+3.3.png` | 2-column grid of 9:16 wall thumbnails (C4) on #171717 — not used for the grid (S-11) |
| S4-w | `references/auto/yope/frames/b-presskit-wall.png` | free-form wall canvas (BLOCKED) |
| S5-b | `references/auto/yope/frames/b-yopeapp-7591560669967682847-t116.00-me-and-friends.png` | walls title placement and size (shared with `walls.browse`) |
| V-ch | `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t6.73-sendto-voice-tooltip.png` | the words "my wall" |

## Structure (top → bottom)

Background `color.global.backgroundDeep` (#000000, S4-p lossless; S-11).

1. **Header**: settings circle at the top-right (`size.global.headerButton`, `color.global.controlOnDeep`,
   `icon.global.settings` in `color.global.textPrimary`, `size.global.headerInset` from the edge; Yope's profile has a gear
   circle top-right, S4-p / V-arkadeep), vertically centred on the title. Title `walls.mine.title` ("my wall") centred, text
   role `sheetTitle` (`fontSize.global.sheetTitle` 19.5, `fontWeight.global.sheetTitle` bold — the walls title measured
   ≈19.8 pt bold on S5-b), `color.global.textPrimary`, baseline `walls.browse.dimension.titleBaseline` below the top
   safe-area inset. No back circle (tab root).
2. **Wall grid**, top `walls.mine.dimension.titleToGrid` (23.5) below the title baseline: `walls.mine.count.gridColumns`
   (3) columns, side insets `walls.mine.dimension.gridInset` (24), gaps `walls.mine.dimension.gridGap` (4) both ways,
   tiles `walls.mine.aspectRatio.gridTile` (115.3 : 158.5) with corners `walls.mine.radius.gridTile` (6.5); fill order
   `walls.mine.layout.gridOrder` (newest first, left → right, row by row; photos and same-moment collages, aspect fill).
   Scrolls vertically; loads more at the end (pages of 50).
3. Floating tab bar overlays the bottom (account group, `groups.list.layout.tabBar`); the grid's last row scrolls clear
   of it (bottom content inset = tab-bar height + its bottom gap, `size.global.tabBarHeight`).

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| settings circle | `size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.settings`, `size.global.headerInset` | `walls.mine.a11y.settings` | opens `settings.root` |
| title | text role `sheetTitle`, `color.global.textPrimary`, `walls.browse.dimension.titleBaseline` | `walls.mine.title` | — |
| photo tile | grid tokens; image `thumb_path` (original until renditions are ready) | `photo.viewer.a11y.photoMine` | tap → `photo.viewer` (context = this wall's photo items, same order) |
| collage tile | grid tokens; collage `image_path` (only `status = ready`) | `walls.browse.a11y.collage` | tap → `collage.view` (capture group) |

## States

| state | what shows | tokens / copy | source |
|---|---|---|---|
| loading | platform activity indicator centred under the title | `easing.global.native.activityIndicator` | PLATFORM (Yope wall loading not observed) |
| loading more | indicator after the last row | same | PLATFORM |
| empty (no wall items) | centred: bold title, gray detail, white pill | text roles `emptyTitle` (`color.global.textPrimary`) / `emptyDetail` (`color.global.textSecondary`); pill `color.global.surfaceLight` / `color.global.onSurfaceLight`, `groups.screen.size.lightPillHeight`, `groups.screen.radius.lightPill`, text role `button`, leading `icon.global.camera`; `walls.mine.empty.title`, `.empty.detail`, `.empty.action` | `yope.voice.empty-state`; pill opens `camera.capture` |
| error | same layout as empty | `walls.mine.error.title`, detail `chat.thread.error.detail`, pill `chat.thread.error.retry` (reloads) | `yope.voice.error` |
| offline | cached grid stays; nothing cached → `chat.thread.offline.title` / `chat.thread.offline.detail` (same layout, no pill) | as listed | `yope.voice.error` |
| permission-denied | not applicable | — | — |

## Motion

Tab switch and push / pop: native (`easing.global.native`). Grid scroll: native. The press-kit "living wall" jitter
(S4g `wall.gif`) is not verified in the app (yope-b §10) and is not built. Reduce Motion: system.

## Haptics

None (no haptic event on this surface; HIG "Avoid overusing haptics").

## Accessibility

- Tiles: `photo.viewer.a11y.photoMine` ("your pic, {date}") or `walls.browse.a11y.collage`; trait button; the grid is
  read row by row.
- Title is a header. Settings circle `walls.mine.a11y.settings`.
- Dynamic Type: title → `layout.global.textStyleMap.sheetTitle`; tiles do not scale; empty state → `emptyTitle` /
  `emptyDetail` / `button`.
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | ratio | result | pair |
|---|---|---|---|---|---|
| `color.global.textPrimary` #FFFFFF | `color.global.backgroundDeep` #000000 | text | 21.00:1 | pass | title / empty title on black |
| `color.global.textSecondary` #969696 | `color.global.backgroundDeep` #000000 | text | 7.10:1 | pass | empty detail on black |

  Header circle `color.global.controlOnDeep` on black: 1.10:1 as a boundary (design/CONTRAST.md, foundations); the glyph
  passes.

## Data & actions

- `wall(p_user_id: my id, p_before, p_limit: 50)` (docs/API.md §6.4): items `post` (`post_id`, `media_id`, `group_ids`) and
  `collage` (`collage_id`), newest first; page with `p_before = last created_at`. Media / collage rows for the images
  (§5.7, §5.13); signed URLs (§7).
- Realtime: `post_deleted` broadcast on each of my groups → drop the tile; refetch on foreground (§8.3).
- Navigation in: me tab; sender overlay "you" in `photo.viewer`. Out: `photo.viewer`, `collage.view`, `settings.root`,
  `camera.capture`. No deep link.

## Platform notes

- iOS: `LazyVGrid` with three flexible columns; Android: `LazyVerticalGrid(GridCells.Fixed(3))`. Tile aspect via
  `aspectRatio(115.3 / 158.5)`.
- Dark only.

## Do-not-copy

- Profile customisation (cut-out photo with outline, name sticker, "customize profile", vibe / music / interests widgets,
  wallpaper) — not a product feature; the pink outline/sticker is F-7's caveat.
- Streak "🔥154" pill, "@handle", share-profile button (no public profiles).
- Free-form wall editor (stickers, cut-outs, music, shuffle) — BLOCKED / do-not-build parts.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| `walls.mine.layout.freeformWall` (Yope's 9:16 wall canvas) | BLOCKED; grid built instead (S-11) | 20-s recording: own wall, a friend's wall, the "me & friends" row, tap shuffle once, tap edit (yope-b §14 capture 3) |
| `walls.mine.layout.mosaic` (row 2 of the press-kit grid looks different) | BLOCKED; uniform rows built | one screenshot of a 2026 Yope profile pics grid scrolled to three rows |
| wall loading / error visuals | not observed: platform indicator; error uses the shared empty-state layout | same recording in airplane mode |
| collage tiles cropped into the 0.73 tile | approximation (aspect fill) | — |

# `favorites` — your private favorites

A grid of the photos you favorited, only for you. **Mechanics reference: Apple Photos Favorites** — a heart on any photo
adds it to a Favorites album that only you see (https://iphonelife.com/blog/5/tip-day-quick-way-create-album-your-favorite-photos,
accessed 2026-10-17; owner decision 34, docs/RESEARCH_FEATURES_2026-10-17.md #19). **Visual reference: Retro** — the pushed
`albums.list` header ("Albums", RS-21) over the `albums.view` grid (TC-J1: 3 columns, 2-pt gaps, rounded outer corners). No new
design values: every token and component is `albums.list`'s, `albums.view`'s or `global.*`. Copy: `design/copy/social.json`
(`favorites.*`). Server: `my_favorites` / `set_favorite` (migration 0038, docs/API.md §6.4).

Tenets: nobody else sees your favorites — no heart on a photo for anyone else, no count anywhere ("12 favorites" is
forbidden, tenet 2), never a notification, never used to rank recaps or year stories (migration 0038, spec flag T2).

## References

| id | file / URL | used for |
|---|---|---|
| AP-FAV | https://iphonelife.com/blog/5/tip-day-quick-way-create-album-your-favorite-photos; https://discussions.apple.com/thread/254973196 | mechanics: the heart / Favorite · Unfavorite, the Favorites album, private to you |
| RS-21 | `references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png` | pushed serif header (`albums.list`) |
| TC-J1 | `references/auto/retro/press/tc-2024-04-journals-1.webp` phone 3 | the grid (`albums.view`) |

## Structure (top → bottom)

Pushed on the profile tab's stack from `walls.mine` (the heart capsule), page `color.global.background` /
`.background.android`, one vertical scroll:
1. **Header** (C-02, as `albums.list`): back chevron + `favorites.title` ("Favorites") in the pushed serif title.
2. **Grid** `size.global.titleToContent` below the title baseline: your favorites, newest favorite first (`favorited_at`),
   as the `albums.view` grid — `albums.view.count.gridColumns` columns inside `size.global.screenMargin`,
   `size.global.stripGap` gaps, cells `albums.view.aspectRatio.gridCell` (aspect fill, `thumb_path`), outer contour
   `albums.view.radius.grid` (inner corners square); a video cell carries the video pill (`layout.global.videoMarker`).
   More pages load when the last row shows (`p_before` = the last `favorited_at`, pages of 60) with the C-28 activity
   indicator under the grid.
3. A cell opens `photo.viewer` on that photo, the context being the favorites shown (in this order), the header naming
   each photo's group (`photo.viewer.header.groupWeek`, as from a wall). Unfavoriting there removes the photo from this
   grid when you come back.

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| header | C-02; text role `headerTitle` (pushed) | `favorites.title`; back `chat.thread.a11y.back` | back |
| grid cell | C-21 album grid; `albums.view.count.gridColumns`, `.aspectRatio.gridCell`, `.radius.grid`, `size.global.stripGap` | `photo.viewer.a11y.photo` / `.photoMine` ("{name}'s photo, {date}" / "Your photo, {date}", the date the photo was taken) | → `photo.viewer` |

## States

| state | what shows | components · tokens · copy | source |
|---|---|---|---|
| loading | header; two rows of `color.global.control` cells | C-28; `week.history.a11y.loading` announced | C-28 |
| empty | header; C-27 centred: `icon.global.favorite` (`size.global.emptyIcon`), title, detail | `favorites.empty.title` ("Nothing to see here yet"), `favorites.empty.detail` | Retro `activity_tab_empty_message`; `retro.voice.empty-state` |
| error | header; one tappable line at `size.global.screenMargin` (text role `body`, `color.global.textSecondary`) | `favorites.error.title` (tap reloads) | `retro.voice.error` (Retro list-error line) |
| offline | the favorites loaded this session (kept in memory only — a deleted photo never survives on the device); nothing loaded → the error line | `favorites.error.title` | — |
| permission-denied | not applicable | — | — |

Light and dark: the page roles of `albums.list` (`color.global.background`, `color.global.textPrimary`,
`color.global.textSecondary`, `color.global.control`) in both appearances.

## Motion

Push / pop native (`easing.global.native`); images fade in with `duration.global.fade`; photo open
`duration.global.photoOpen`. Reduce Motion: cross-fades.

## Haptics

| interaction | token |
|---|---|
| tap a cell (Android) | `haptic.global.tap` (iOS none) |

## Accessibility

- Title is a header; each cell a button labelled `photo.viewer.a11y.photo` / `.photoMine` (+ the video length,
  `layout.global.videoMarker`); the grid is one list in favorite order.
- Dynamic Type: `headerTitle` → largeTitle; cells keep their size (the label carries the information).
- Focus order: back → title → cells.
- Contrast: as `albums.view` (design/surfaces/albums.view.md → Accessibility).

## Data & actions

- **Reads**: `my_favorites(p_before, p_limit: 60)` → `media_id`, `post_id` (the photo's first post in your groups — the group
  it opens in), `group_id`, `group_name`, `author_id`, `kind`, `thumb_path`, `display_path`, `widget_path`, `taken_at`,
  `favorited_at`; `profiles` of the authors (cell labels); `media` (`duration_ms`) for the video pill. Rows you can no
  longer see (left the group, a block) are not returned; deleting the photo removes the favorite.
- **Writes**: none here; `set_favorite(p_media_id, p_on)` from `photo.viewer`'s menu.
- **Navigation in**: `walls.mine` (heart capsule). **Out**: `photo.viewer`, back.

## Platform notes

iOS: pushed `SocialRoute.favorites` (profile tab stack), `ScrollView` + `LazyVGrid` with the `AlbumGrid` cells. Android:
`AppRoute`-free destination `FavoritesRoute` (`app.model`), `LazyVerticalGrid(GridCells.Fixed(3))` with `gridCellShape`.

## Do-not-copy

- Any count ("12 favorites", "N photos"), a shared or public favorites list, a heart visible to others, "most loved"
  rankings (tenet 2).
- Apple Photos' pinned Favorites in the library grid, Memories built from favorites.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| grid composition | composed from `albums.list` + `albums.view` (Retro has no favorites) | — |
| a favorites widget | later (docs/API.md: reads `my_favorites` rows with a `widget_path`) | — |

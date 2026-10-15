# `albums.list` — a group's saved albums

Reference app: **Yope** (`docs/SURFACES.md`). **No Yope album screen was found**: only the release note "make your own
memory albums" (v1.214.0, yope-b §7). Under the owner decision of 2026-10-15 (any successful app may fill a gap) the album
list itself now follows **Apple Photos' Albums collection** (`albums.list.layout.yopeAlbums`, iOS 27 guide image; Gap fill
G-17); header, states and colours stay Yope's. Yope's own album screens (yope-b §14 capture 5) would supersede it.
Tokens: `design/tokens/social.json` (`albums.list.*`) + `global.*`. Copy: `design/copy/social.json` (`albums.list.*`).

## References

| id | file | used for |
|---|---|---|
| W1 | `references/auto/yope/store/listing.html` (v1.214.0) | "memory albums" |
| V-sav | `references/auto/yope/frames/a-savannahclooney-7683341732695592206-t6.73-home-list.png` | home list card: #181818 on black, ≈100 pt, 64-pt circle at 16 pt, name bold, gray subtitle, 12-pt margins, 17-pt corners |
| V-virgi | `references/auto/yope/frames/a-virgi-7686278541255642390-t40.23-home-list-es.png` | second card-height sample |
| O3 | `references/owner/yope-week-recap.jpg` | centred header title style (‹ + 17 semibold title) |

## Structure (top → bottom)

Background `color.global.backgroundDeep`.

1. **Header**: ‹ circle (`size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.back`,
   `size.global.headerInset`); title `albums.list.title` ("memory albums") centred, `week.recap.fontSize.title` /
   `.fontWeight.title`, `color.global.textPrimary`.
2. **Album covers** (`albums.list.layout.yopeAlbums`): a grid of 2 columns (`columns`), side margins `marginH` (23), gap
   `gap` (12.4) both ways, newest album first (`albums.created_at`). Each cover is square (`coverAspect` 1, ≈168 pt wide on a
   393-pt screen), corners `coverRadius` (18.5), the album's first photo (`thumb_path`), aspect fill. Over its bottom-leading
   corner: the album name, one line, tail truncation, `titleFontSize` 15 (weight not measured: platform default),
   `color.global.textPrimary`, ink `titleInsetLeading` (14) from the cover's leading edge, baseline `titleBaselineBottom`
   (17) above its bottom. The subtitle `albums.list.row.subtitle` is not drawn (the reference shows the name only); it joins
   the accessibility label. The home-card composition (`albums.list.layout.composition`, S-14) is superseded.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| ‹ circle | `size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.back` | `chat.thread.a11y.back` | pops |
| title | `week.recap.fontSize.title`, `.fontWeight.title` | `albums.list.title` | header trait |
| album cover | `albums.list.layout.yopeAlbums` (columns, marginH, gap, coverAspect, coverRadius) | album name (data) on the cover; label "{album name}, {subtitle}" with `albums.list.row.subtitle` | tap → `albums.view` |
| album name | `albums.list.layout.yopeAlbums` (titleFontSize, titleInsetLeading, titleBaselineBottom), `color.global.textPrimary` | album name (data) | — |

## States

| state | what shows | tokens / copy | source |
|---|---|---|---|
| loading | Loading HUD | `groups.create.size.hud`, `.color.hud`, `.fontSize.hudLabel`; `groups.create.hud.loading` | yope-a §1.8 |
| empty | centred bold title, gray detail, white pill | `albums.list.empty.title`, `.empty.detail`, `.empty.action` ("view recap" → `week.recap`); text roles `emptyTitle` / `emptyDetail`; pill `color.global.surfaceLight` / `.onSurfaceLight`, `groups.screen.size.lightPillHeight`, `groups.screen.radius.lightPill` | `yope.voice.empty-state` |
| error | same layout as empty, retry pill | `albums.list.error.title`, `chat.thread.error.detail`, pill `chat.thread.error.retry` | `yope.voice.error` |
| offline | cached cards; nothing cached → `chat.thread.offline.title` / `.offline.detail` | — | `yope.voice.error` |
| permission-denied | not applicable | — | — |

## Motion

Push / pop native; list scroll native. Reduce Motion: system.

## Haptics

None.

## Accessibility

- Cover: one button, label "{album name}, {subtitle}" (name data + `albums.list.row.subtitle`); the photo is decorative.
- Dynamic Type: the name on the cover scales with `layout.global.textStyleMap.listSubtitle` (subheadline, nearest style to
  15 pt) and stays one line (tail truncation); covers keep their size. Header title → `week.recap.layout.textStyleMap.title`.
- Contrast: the album name sits on photo content (no fixed backdrop; the reference's treatment under it is not measurable):
  not computable — flagged (MERGE_DECISIONS Gap fill G-17). Header title #FFFFFF on #000000: 21.00:1 pass.

## Data & actions

- `albums` (docs/API.md §5.15) `eq(group_id).order(created_at desc)`; first `album_items` row (`position = 0`) per album →
  `posts` → `media.thumb_path`; `profiles` for `created_by`.
- Realtime: none for albums (not published): refetch on appear / foreground.
- Navigation in: the group's albums entry on `groups.screen` (account group), after `week.edit`'s album save. Out:
  `albums.view`, `week.recap`.

## Platform notes

iOS `LazyVStack` of cards; Android `LazyColumn`. Dark only.

## Do-not-copy

Streak pills, unread badges, presence dots and the camera glyph of Yope's home cards (not meaningful for albums).

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| `albums.list.layout.yopeAlbums` | **SOURCED (gap fill)**: Apple Photos Albums collection, iOS 27 guide image (2 columns, square covers, name over the bottom-leading corner; ±1 pt) — G-17 | two screenshots: Yope's album list and one open album (yope-b §14 capture 5) would supersede |
| album name legibility on covers | not measurable (Apple's treatment under the name sits on photo content); contrast not computable | same capture |
| album order | approximation: newest first | same |

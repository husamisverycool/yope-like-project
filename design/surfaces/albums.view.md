# `albums.view` — one saved album

Redesign on **Retro**: visual reference Retro's **album detail** (screen 13 — TC-J1 2024: a sheet with a book-like cover, the
serif album name centred, a grey meta line, outline capsules "Settings / Share" + a "+" capsule, then the photo grid with
2-pt gaps and rounded outer corners) and the shared-album **web grid** (retro.app `/j/`: rounded outer corners .75rem = 12 px,
4 px gaps on desktop, 2 px on mobile). Tokens: `design/tokens/social.json` (`albums.view.*`) + `global.*`. Copy:
`design/copy/social.json` (`albums.view.*`). Decisions: `design/MERGE_DECISIONS.md` → Redesign — Social (RS-21).

## References

| id | file | used for |
|---|---|---|
| TC-J1 | `references/auto/retro/press/tc-2024-04-journals-1.webp` phone 3 (render, 2.069 px/pt) | **primary**: cover (`albums.view.dimension.cover*`), name (displayMedium), meta, capsule row, grid (3 columns, `albums.view.aspectRatio.gridCell`, 2-pt gaps, `albums.view.radius.grid`) |
| WEB | `references/auto/retro/web/retro.app-42b38811bebcd07d.css`, `references/auto/retro/web/retro.app-j-welcome-iphone-full.png` | grid outer radius 12, gaps 4 / 2 px, day headers; outline pill 1 px #0D0D0D |
| TC-J5 | `references/auto/retro/press/tc-2024-04-retro-journals-5.png` | album menu with a red destructive row |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | "Delete Album", "Nothing has been added to this album", "Couldn't find album", "Yes, delete", "Saved!", "Deleted" |

## Structure (top → bottom)

Page sheet (C-29) over `albums.list`, content on `color.global.background`, scrolling as one column:
1. **Cover** centred, `albums.view.dimension.coverTop` below the sheet top: `albums.view.dimension.coverWidth` ×
   `.coverHeight`, corners `radius.global.thumbnail` (C-15 cover), the album's first item, aspect fill; drop shadow
   `albums.view.shadow.cover`: Retro's book-cover drop shadow — black 25 %, Gaussian σ 8.5 pt, offset (3, 10) (TC-J1 fit, the
   same as `groups.screen.shadow.cover`; Android passes σ through the platform's blur-radius conversion).
2. **Name** centred, cap top `albums.view.dimension.coverToTitle` below the cover: the album name in the display serif (text role
   `displayMedium`, `font.global.display`, `color.global.textPrimary`), up to two lines.
3. **Meta** centred, baseline `albums.view.dimension.titleToMeta` below the name's baseline: `albums.list.row.subtitle` /
   `.row.subtitleMine` (text role `listSubtitle`, `color.global.textSecondary`) — no counts.
4. **Action row** (C-06) `albums.view.dimension.metaToActions` below the meta baseline, inside `size.global.screenMargin`:
   outline capsule `albums.view.menu.rename` ("Rename", fills the row) and — for the album's creator and group admins — an
   outline icon capsule (`size.global.iconPillWidth`, `icon.global.more`) `size.global.pillGap` after it → native menu with
   `albums.view.menu.delete` (red).
5. **Grid** `walls.mine.dimension.actionsToWeeks` below the capsules: the album's items in `position` order (the saved order;
   no date headers — RS-21), `albums.view.count.gridColumns` columns inside `size.global.screenMargin`,
   `size.global.stripGap` gaps, cells `albums.view.aspectRatio.gridCell` (aspect fill). The grid's outer contour rounds at
   `albums.view.radius.grid`: the top corners of the first row's end cells, the bottom-leading corner of the last row's first
   cell and the bottom-trailing corner of its last cell; when the last row is short, the trailing cell of the row above also
   rounds its bottom-trailing corner (the web page's `topRightCornerRounded` / `bottomRightCornerRounded` cells). Inner corners
   stay square.

### Rename sheet

Sheet (C-29): C-11 close circle + centred `albums.view.rename.title` (`sheetTitle`); C-12 field prefilled with the name
(`size.global.titleToContent` below); inline error `week.edit.error.albumName` (C-12 error); C-05 primary capsule
`albums.view.rename.save` ("Save"), disabled while empty → `rename_album` → Android Toast `albums.view.toast.renamed` /
iOS announcement.

### Delete confirmation (C-29 alert, `photo.viewer.layout.deleteConfirm`)

Title `albums.view.delete.title`, message `albums.view.delete.message`, destructive `albums.view.delete.confirm` ("Yes,
delete"), cancel `photo.viewer.delete.cancel` → `delete_album` → the sheet closes, Android Toast `albums.view.toast.deleted`.

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| cover | `albums.view.dimension.coverWidth`, `.coverHeight`, `.coverTop`, `radius.global.thumbnail`, `albums.view.shadow.cover` | `albums.view.a11y.cover` | → `photo.viewer` on the first item |
| name | text role `displayMedium`, `font.global.display`; `albums.view.dimension.coverToTitle` | album name (data) | header trait |
| meta | text role `listSubtitle`; `albums.view.dimension.titleToMeta` | `albums.list.row.subtitle` / `.row.subtitleMine` | — |
| Rename capsule | C-06 outline; `size.global.pillHeight`, `albums.view.dimension.metaToActions` | `albums.view.menu.rename` | rename sheet |
| more capsule | C-06 outline icon capsule; `size.global.iconPillWidth`, `icon.global.more` | `albums.view.a11y.more` | menu: `albums.view.menu.delete` |
| grid cell | C-21 album grid; `albums.view.count.gridColumns`, `.aspectRatio.gridCell`, `.radius.grid`, `size.global.stripGap` | `photo.viewer.a11y.photo` | → `photo.viewer` (context = album order) |

## States

| state | what shows | components · tokens · copy | source |
|---|---|---|---|
| loading | cover and cells as `color.global.control` placeholders; name from the list row | C-28 | C-28 |
| empty (every item deleted or hidden) | cover placeholder; name, meta, capsules; C-27 title + detail in place of the grid | `albums.view.empty.title`, `.empty.detail` | APK-S |
| not found (`album_not_found`) | C-27 title only, centred | `albums.view.notFound` | APK-S |
| error | one tappable line in place of the grid | `albums.list.error.title` | APK-S |
| rename name empty | inline under the field | `week.edit.error.albumName` | APK-S |
| offline | cached grid; rename / delete fail with `week.edit.error.save` | — | — |
| permission-denied | not applicable | — | — |

## Motion

Sheet in / out native (`spring.global.sheetPresent`); photo open `duration.global.photoOpen`; menu, alert native; images fade
in with `duration.global.fade`. Reduce Motion: system / cross-fades.

## Haptics

| interaction | token |
|---|---|
| tap a cell / capsule (Android) | `haptic.global.tap` (iOS none) |
| rename saved | `haptic.global.success` |
| delete confirmed | `haptic.global.warning` |
| failed | `haptic.global.error` |

## Accessibility

- Cover `albums.view.a11y.cover`; cells `photo.viewer.a11y.photo`; "•••" `albums.view.a11y.more`; menu items native
  (destructive role announced).
- Dynamic Type: `displayMedium` → largeTitle; `listSubtitle`, `pill` → subheadline.
- Focus order: cover → name → meta → Rename → more → cells.
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | light | dark | pair |
|---|---|---|---|---|---|
| `color.global.textPrimary` | `color.global.background` | text | 21.00:1 pass | 21.00:1 pass | name, capsule labels / borders |
| `color.global.textSecondary` | `color.global.background` | text | **2.85:1 FAIL** | 7.37:1 pass | meta line (iOS) |
| `color.global.textSecondary.android` | `color.global.background.android` | text | **4.00:1 FAIL** | 6.85:1 pass | meta line (Android) |
| `color.global.onAccent` | `color.global.accent` | text | 21.00:1 pass | 21.00:1 pass | "Save" (rename sheet) |

## Data & actions

- **Reads**: `albums` + `album_items` (§5.15; items need the post to be visible), `posts` / `media` (`thumb_path`),
  `profiles` (`created_by`), `group_members.role` (admin) for the more capsule.
- **RPCs**: `rename_album(p_album_id, p_name)` (any member; `invalid_name`, `album_not_found`), `delete_album(p_album_id)`
  (creator or admin; `not_album_owner`). Posts are never deleted by these.
- Realtime: `post_deleted` → drop the cell.
- Navigation in: `albums.list`. Out: `photo.viewer`, back.

## Platform notes

iOS `.sheet` (`.presentationDetents([.large])`), `LazyVGrid` with three flexible columns, the grid clipped by a shape that
rounds only its outer corners; `Menu` on the capsule; `confirmationDialog`. Android `ModalBottomSheet(skipPartiallyExpanded
= true)`, `LazyVerticalGrid(GridCells.Fixed(3))` with per-cell corner shapes; `DropdownMenu`; `AlertDialog`.

## Do-not-copy

- "6 members · 307 photos" counts; "Share" / link sharing / QR / Instagram story sticker (albums are private to the group);
  the "+" add capsule (no API to add items); notes composer, sort order, download-all, admin permission settings.
- The user-styled cover title on the cover image; the book overlay texture (`/journal-overlay.webp`).

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| `albums.view.shadow.cover` (old BLOCKED) | closed 2026-10-16: fitted on TC-J1 (the cover on white); the web /j/ page draws its cover flat (no CSS shadow — its book texture `/journal-overlay.webp` is opaque) | a raw in-app capture on white would refine σ |
| cell aspect | TC-J1 measures 4:5; components C-21 says square, the web uses 3:4 — the in-app capture is used (RS-21) | one raw screenshot of a Retro album grid |
| date headers | not used: our albums keep their saved order (RS-21) | — |
| capsule row contents | composition: Rename + more (Retro: Settings / Share / +) | — |

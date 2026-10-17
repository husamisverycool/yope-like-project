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
   outline capsule `albums.view.menu.rename` ("Rename", fills the row) and an outline icon capsule
   (`size.global.iconPillWidth`, `icon.global.more`) `size.global.pillGap` after it → native menu with
   `albums.view.menu.add` ("Add Photos", every member — albums anyone can add to, migration 0039),
   `albums.view.menu.download` ("Download Album", every member — premium, owner decision 29: `icon.global.download` with
   premium, `icon.global.lock` without; with premium it opens `settings.downloads` for this album, which starts at once;
   without, the paywall at the full-quality downloads perk under `paywall.layout.promptRule`) and, for the album's creator
   and group admins, `albums.view.menu.delete` (red).
5. **Grid** `walls.mine.dimension.actionsToWeeks` below the capsules: the album's items in `position` order (the saved order;
   no date headers — RS-21), `albums.view.count.gridColumns` columns inside `size.global.screenMargin`,
   `size.global.stripGap` gaps, cells `albums.view.aspectRatio.gridCell` (aspect fill). The grid's outer contour rounds at
   `albums.view.radius.grid`: the top corners of the first row's end cells, the bottom-leading corner of the last row's first
   cell and the bottom-trailing corner of its last cell; when the last row is short, the trailing cell of the row above also
   rounds its bottom-trailing corner (the web page's `topRightCornerRounded` / `bottomRightCornerRounded` cells). Inner corners
   stay square.

### Add sheet (`albums.view.layout.add`; Apple Shared Albums "Select all the items you want to add … tap Add to Shared Album", support.apple.com/108314)

Sheet (C-29) over the album: C-11 close circle + centred `albums.view.menu.add` (`sheetTitle`); `size.global.titleToContent`
below, the group's photos the album does not hold yet, newest week first (`group_history_weeks`, the first page —
`week.history`'s weeks), as `week.edit`'s composer grid (C-21: `week.edit.count.gridColumns` square cells,
`size.global.stripGap` gaps, inside `size.global.screenMargin`); a tap toggles a photo with `week.edit`'s pick mark
(`week.edit.layout.selectionMark`: the photo insets, `icon.global.check` on its disc; `duration.global.crossfade`;
accessibility: a checkbox, its checked state by the platform); the C-05 primary capsule
`albums.view.add.confirm` ("Add") pinned at the bottom (`size.global.buttonMarginHSheet`), disabled until a photo is
picked → `add_to_album(p_album_id, p_post_ids)` (in the order picked; photos already there are skipped) → the sheet closes,
the grid reloads, `haptic.global.success` + Android Toast / iOS announcement `week.edit.toast.albumSaved` ("Added to
Album!"); failed → `haptic.global.error` + `week.edit.error.save`, the selection stays. States: loading — two rows of
`color.global.control` cells (C-28); nothing to add — C-27 title `albums.view.add.empty`; error / offline — the
`albums.list.error.title` line (tap retries).

### Remove a photo (grid cell long press → native menu)

`albums.view.menu.remove` ("Remove from Album", `icon.global.remove`, destructive) on the photos you added
(`album_items.added_by`), and on every photo for the album's creator and group admins (Apple Shared Albums: "Other
participants can delete anything that they personally added"; the owner "can delete any photos"). No confirmation (the
photo stays in the group). The cell leaves at once → `remove_from_album(p_album_id, [post])` → Android Toast / iOS
announcement `albums.view.toast.removed`; `not_allowed` (403, someone else's photo) → the cell comes back,
`haptic.global.error` + `albums.view.error.notAllowed`; other failures → back + `week.edit.error.save`.

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
| more capsule | C-06 outline icon capsule; `size.global.iconPillWidth`, `icon.global.more` | `albums.view.a11y.more` | menu: `albums.view.menu.add` (everyone), `albums.view.menu.download` (everyone; premium), `albums.view.menu.delete` (creator / admin) |
| grid cell | C-21 album grid; `albums.view.count.gridColumns`, `.aspectRatio.gridCell`, `.radius.grid`, `size.global.stripGap` | `photo.viewer.a11y.photo` | → `photo.viewer` (context = album order); long press → `albums.view.menu.remove` when allowed |

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
  (creator or admin; `not_album_owner`), `add_to_album(p_album_id, p_post_ids)` (any member; `invalid_items`,
  `album_not_found`), `remove_from_album(p_album_id, p_post_ids)` (what you added; creator / admin: any; `not_allowed`).
  Posts are never deleted by these. `album_items.added_by` decides who sees "Remove from Album"; the add sheet reads
  `group_history_weeks` (first page) and `posts` / `media` of those weeks.
- Realtime: `post_deleted` → drop the cell.
- Navigation in: `albums.list`. Out: `photo.viewer`, back.

## Platform notes

iOS `.sheet` (`.presentationDetents([.large])`), `LazyVGrid` with three flexible columns, the grid clipped by a shape that
rounds only its outer corners; `Menu` on the capsule; `confirmationDialog`. Android `ModalBottomSheet(skipPartiallyExpanded
= true)`, `LazyVerticalGrid(GridCells.Fixed(3))` with per-cell corner shapes; `DropdownMenu`; `AlertDialog`.

## Do-not-copy

- "6 members · 307 photos" counts; "Share" / link sharing / QR / Instagram story sticker (albums are private to the group);
  notes composer, sort order, admin permission settings. (Download-all was left out until owner decision 29 / 34 made it
  "Download Album", premium.)
- The user-styled cover title on the cover image; the book overlay texture (`/journal-overlay.webp`).

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| `albums.view.shadow.cover` (old BLOCKED) | closed 2026-10-16: fitted on TC-J1 (the cover on white); the web /j/ page draws its cover flat (no CSS shadow — its book texture `/journal-overlay.webp` is opaque) | a raw in-app capture on white would refine σ |
| cell aspect | TC-J1 measures 4:5; components C-21 says square, the web uses 3:4 — the in-app capture is used (RS-21) | one raw screenshot of a Retro album grid |
| date headers | not used: our albums keep their saved order (RS-21) | — |
| capsule row contents | composition: Rename + more (Retro: Settings / Share / +); "Add Photos" sits in the more menu (Retro's "+" capsule is its add entry) so the row keeps its two capsules | — |
| add sheet reach | the first page of the group's weeks (`group_history_weeks`, 8 weeks); older photos join an album from the viewer's Add to Album | — |

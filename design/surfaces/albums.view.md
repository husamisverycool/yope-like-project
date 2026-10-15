# `albums.view` — one saved album

Reference app: **Yope** (`docs/SURFACES.md`). No Yope album screen was found (yope-b §7); built from documented Yope
components (header, week pics grid, native ••• menu, "new group"-style name sheet; S-14). Tokens: `design/tokens/social.json`
(grid from `week.recap.*`) + `global.*`. Copy: `design/copy/social.json` (`albums.view.*`).

## References

| id | file | used for |
|---|---|---|
| O3 | `references/owner/yope-week-recap.jpg` | header (‹ + centred 17 semibold title) and the full-bleed 3-column pics grid (C2) |
| YR | `references/auto/yope/frames/a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png` | native ••• menu, lowercase items, destructive in red |
| V-mthu | `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t45.23-new-group-empty.png` | name sheet (title, field, lime button) |
| W1 | `references/auto/yope/store/listing.html` (v1.214.0) | "memory albums" |

## Structure (top → bottom)

Background `color.global.background` (group-level screens; the recap screen it mirrors).

1. **Header**: ‹ circle (`size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.back`,
   `size.global.headerInset`); the album name centred (`week.recap.fontSize.title` / `.fontWeight.title`,
   `color.global.textPrimary`, one line, tail truncation); ••• circle at the right (same circle, `icon.global.more`) opening
   the native menu (`photo.viewer.layout.menu` component).
2. **Grid** of the album's items in `position` order: `week.recap.count.picsColumns` (3), `week.recap.dimension.picsGap`
   (1), `week.recap.aspectRatio.picsTile` (3:4), full width, square corners, aspect fill.

### Menu

| item | shown | glyph | copy | action |
|---|---|---|---|---|
| rename | every member | `icon.global.edit` | `albums.view.menu.rename` | rename sheet: Yope name sheet (`week.edit.md` album sheet) titled `albums.view.rename.title`, field prefilled, button `week.edit.save` → `rename_album` → toast `albums.view.toast.renamed` |
| delete album | the album's creator and group admins | `photo.viewer.icon.delete` (destructive) | `albums.view.menu.delete` | confirmation (`photo.viewer.layout.deleteConfirm` component): title `albums.view.delete.title`, message `albums.view.delete.message` ("the pics stay in your group — only the album goes away."), buttons `albums.view.delete.confirm` / `photo.viewer.delete.cancel` → `delete_album` → pop + toast `albums.view.toast.deleted` |

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| ‹ circle | header tokens | `chat.thread.a11y.back` | pops |
| title | `week.recap.fontSize.title`, `.fontWeight.title` | album name (data) | header trait |
| ••• circle | `size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.more` | `photo.viewer.a11y.more` | menu above |
| tile | week pics grid tokens | `photo.viewer.a11y.photo` | tap → `photo.viewer` (context = album order) |
| toast | `camera.sendto.layout.toast` (dwell BLOCKED) | `albums.view.toast.renamed`, `.toast.deleted` | — |

## States

| state | what shows | tokens / copy | source |
|---|---|---|---|
| loading | Loading HUD | `groups.create.size.hud`, `.color.hud`, `.fontSize.hudLabel`; `groups.create.hud.loading` | yope-a §1.8 |
| empty (every item deleted or hidden) | centred bold title + gray detail, no pill | `albums.view.empty.title`, `.empty.detail`; text roles `emptyTitle` / `emptyDetail` | `yope.voice.empty-state` |
| not found (`album_not_found`: deleted meanwhile) | same layout | `albums.view.empty.title` | `yope.voice.error` |
| error | same layout + retry | `albums.list.error.title`, `chat.thread.error.detail`, pill `chat.thread.error.retry` | `yope.voice.error` |
| rename name empty | inline under the field | `week.edit.error.albumName` | `yope.voice.error` |
| offline | cached grid; actions fail with `week.edit.error.save` | — | `yope.voice.error` |
| permission-denied | not applicable | — | — |

## Motion

Push / pop, menu, confirmation, sheet: native (`easing.global.native`). Reduce Motion: system.

## Haptics

| interaction | token |
|---|---|
| rename saved | `haptic.global.success` |
| delete confirmed | `haptic.global.warning` |
| failed | `haptic.global.error` |

## Accessibility

- Tiles `photo.viewer.a11y.photo`; ••• `photo.viewer.a11y.more`; menu items are native (destructive role announced).
- Dynamic Type: title → `week.recap.layout.textStyleMap.title`.
- Contrast: header and title pairs as `week.recap.md` (white on #171717 17.93:1 pass; header circle #101010 on #171717
  1.06:1 FAIL as a boundary, glyph 19.03:1 pass). Android destructive label `color.global.system.error` on
  `color.global.system.surfaceContainerHigh`: 8.41:1 pass. iOS menu material is a system colour (not a token): not computed.

## Data & actions

- **Reads**: `albums` + `album_items` (§5.15; items need the post to be visible), `posts` / `media` (`thumb_path`),
  `group_members.role` (admin) to show "delete album".
- **RPCs**: `rename_album(p_album_id, p_name)` (any member; `invalid_name`, `album_not_found`), `delete_album(p_album_id)`
  (creator or admin; `not_album_owner`). Posts are never deleted by these.
- Realtime: `post_deleted` → drop the tile.
- Navigation in: `albums.list`. Out: `photo.viewer`, back.

## Platform notes

iOS: `Menu` on the ••• circle, `confirmationDialog`; Android: `DropdownMenu`, `AlertDialog`. Rename sheet: as `week.edit.md`.

## Do-not-copy

Watermarks, share-to-socials buttons (export is not a product feature here), counts of photos ("12 pics").

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| Yope's own album screen (`albums.list.layout.yopeAlbums`) | BLOCKED; composition flagged (S-14) | two screenshots: Yope's album list and one open album (yope-b §14 capture 5) |
| album reorder / remove items | not offered (no API besides re-saving; no Yope evidence) | same |

# Verification — `albums.view` (iOS)

One album (Retro's journal page: cover, serif name, meta, capsules, grid with outer corners) — `ios/App/Sources/Features/Social/UI/AlbumViews.swift` (`AlbumScreen`, `AlbumGrid`, `AlbumGridCorners`), `UI/SocialSheetParts.swift` (rename sheet), `Core/AlbumModels.swift` (`AlbumModel`).

Pass 4 (Retro redesign). Checklist written from the spec (`design/surfaces/albums.view.md`, MERGE "Redesign — Social (RS-*)", lead L-3 / L-4) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>-<light|dark>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/albums.view.png` next to the Retro reference(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level). Components are the Pass 3 library (`ios/App/Sources/Components`, C-01…C-35).

Retro reference(s): `references/auto/retro/press/tc-2024-04-journals-1.webp (primary)`, `references/auto/retro/press/tc-2024-04-retro-journals-5.png`, `references/auto/retro/web/retro.app-j-welcome-iphone-full.png`

Snapshots (CI): `albums.view-ready-light.png`, `albums.view-ready-dark.png`, `albums.view-ready-mine-light.png`, `albums.view-loading-light.png`, `albums.view-empty-light.png`, `albums.view-not-found-light.png`, `albums.view-error-light.png`, `albums.view-offline-light.png`, `albums.view-rename-light.png`, `albums.view-rename-missing-light.png`

**Summary: 15 matched · 1 approximated · 1 not matched (BLOCKED or not buildable).**

## Elements

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| not matched | `albums.view.dimension.coverWidth`<br>`albums.view.dimension.coverHeight`<br>`albums.view.dimension.coverTop`<br>`radius.global.thumbnail`<br>`albums.view.a11y.cover` | 172.5 pt (SOURCED)<br>246 pt (SOURCED)<br>74 pt (SOURCED)<br>4 pt (SOURCED)<br>“Cover of {album_name}” (SOURCED) | cover | first item `coverWidth × coverHeight`, `radius.global.thumbnail`, centred `coverTop` below the sheet top; tap → viewer on the first item. Its shadow `albums.view.shadow.cover` is BLOCKED — drawn flat |
| matched | `font.global.display`<br>`albums.view.dimension.coverToTitle` | ios: system-serif; android: serif (PLATFORM)<br>36.7 pt (SOURCED) | name | `displayMedium` (display serif), centred, up to two lines, cap top `coverToTitle` below the cover; header trait; name from the list row while loading |
| matched | `albums.view.dimension.titleToMeta`<br>`albums.list.row.subtitle`<br>`albums.list.row.subtitleMine` | 23.7 pt (SOURCED)<br>“{name} created the album” (SOURCED)<br>“you created the album” (SOURCED) | meta | "{name} created the album" / "you created the album" (`listSubtitle`, `textSecondary`), baseline `titleToMeta` below the name's |
| matched | `size.global.pillHeight`<br>`albums.view.dimension.metaToActions`<br>`albums.view.menu.rename` | 37 pt (SOURCED)<br>28.5 pt (SOURCED)<br>“Rename” (SOURCED) | Rename capsule | C-06 `CapsuleButton` "Rename" filling the row, `metaToActions` below the meta baseline → rename sheet |
| matched | `size.global.iconPillWidth`<br>`icon.global.more`<br>`albums.view.a11y.more`<br>`albums.view.menu.delete` | 49 pt (SOURCED)<br>ios: ellipsis; android: Rounded.MoreHoriz (PLATFORM)<br>“More Options” (SOURCED)<br>“Delete Album” (SOURCED) | more capsule | creator / admin only: C-06 `CapsuleLabel(icon: more)` native menu → "Delete Album" (destructive) → confirmation → `delete_album` (unit-tested) |
| approximated | `albums.view.count.gridColumns`<br>`albums.view.aspectRatio.gridCell`<br>`albums.view.radius.grid`<br>`size.global.stripGap`<br>`photo.viewer.a11y.photo` | 3 (SOURCED)<br>width: 116.5; height: 145 (SOURCED)<br>12 pt (SOURCED)<br>2 pt (SOURCED)<br>“{name}'s photo, {date}” (SOURCED) | grid cell | `AlbumGrid`: `gridColumns` columns inside the margins, `stripGap`, cells `aspectRatio.gridCell` aspect fill in saved order; only the grid's outer contour rounds at `radius.grid` (`AlbumGridCorners`, incl. a short last row); tap → viewer in album order. A local grid: the shared `PhotoGrid` has square cells and square corners (component gap C-21) |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `color.global.control` | light #F1F1F1 / dark #262626 (SOURCED) | loading | cover and two rows of cells as `control` placeholders; the name from the list row |
| matched | `albums.view.empty.title`<br>`albums.view.empty.detail` | “Nothing has been added to this album” (SOURCED)<br>“Photos removed by the people who shared them leave albums too.” (SOURCED) | empty (every item deleted or hidden) | cover placeholder, name, meta, capsules; C-27 title + detail in place of the grid |
| matched | `albums.view.notFound` | “Couldn't find album” (SOURCED) | not found (`album_not_found`) | C-27 `albums.view.notFound` centred |
| matched | `albums.list.error.title` | “Error retrieving your albums. Tap here to try again” (SOURCED) | error | `SocialErrorLine` in place of the grid |
| matched | `week.edit.error.albumName` | “Name missing” (SOURCED) | rename name empty | `SocialNameSheet` inline `week.edit.error.albumName` under the field when submitted empty (unit-tested) |
| matched | `week.edit.error.save` | “There was a problem saving your changes. Please try again.” (SOURCED) | offline | cached grid; rename / delete fail with `changesFailed` (rename put back — unit-tested) |
| matched | `—` | — | permission-denied | n/a |

## Haptics

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | tap a cell / capsule (Android) | none on iOS |
| matched | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | rename saved | `.success` |
| matched | `haptic.global.warning` | ios: notification.warning; android: CONFIRM (PLATFORM) | delete confirmed | `.warning` |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | failed | `.failed` |

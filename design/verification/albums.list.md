# Verification — `albums.list` (iOS)

The group's albums (Retro's album list rows) — `ios/App/Sources/Features/Social/UI/AlbumViews.swift` (`AlbumsListScreen`), `Core/AlbumModels.swift` (`AlbumsListModel`).

Pass 4 (Retro redesign). Checklist written from the spec (`design/surfaces/albums.list.md`, MERGE "Redesign — Social (RS-*)", lead L-3 / L-4) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>-<light|dark>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/albums.list.png` next to the Retro reference(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level). Components are the Pass 3 library (`ios/App/Sources/Components`, C-01…C-35).

Retro reference(s): `references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png (primary)`, `references/auto/retro/store/editorial/retro-appstore-story-1840659619-albums.png`, `references/auto/retro/press/tc-2024-04-journals-1.webp`

Snapshots (CI): `albums.list-ready-light.png`, `albums.list-ready-dark.png`, `albums.list-no-results-light.png`, `albums.list-loading-light.png`, `albums.list-empty-light.png`, `albums.list-error-light.png`, `albums.list-offline-light.png`

**Summary: 10 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Elements

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `chat.thread.a11y.back`<br>`albums.list.title` | “Back” (SOURCED)<br>“Albums” (SOURCED) | back + title | C-02 `PushedScreenHeader` "Albums" → pops to the group |
| matched | `albums.list.search` | “Search” (SOURCED) | search | C-12 `SearchField` filtering by name (unit-tested) |
| matched | `size.global.rowThumbWidth`<br>`size.global.rowThumbHeight`<br>`size.global.rowThumbGap`<br>`size.global.listGap`<br>`radius.global.thumbnail`<br>`albums.list.row.subtitle`<br>`albums.list.row.subtitleMine` | 72 pt (SOURCED)<br>97 pt (SOURCED)<br>17 pt (SOURCED)<br>22.5 pt (SOURCED)<br>4 pt (SOURCED)<br>“{name} created the album” (SOURCED)<br>“you created the album” (SOURCED) | row | C-15 `ThumbnailRow` in `ThumbnailRowList`: cover = first item (`rowThumbWidth × rowThumbHeight`, `radius.global.thumbnail`), name (`listTitle`), "{name} created the album" with the name emphasised / "you created the album"; tap → `albums.view` as a page sheet |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `color.global.control`<br>`week.history.a11y.loading` | light #F1F1F1 / dark #262626 (SOURCED)<br>“Loading” (SOURCED) | loading | three `control` thumbnails, no text; announced |
| matched | `icon.global.albums`<br>`albums.list.empty.title`<br>`albums.list.empty.detail`<br>`albums.list.empty.action` | ios: book; android: AutoMirrored.Outlined.MenuBook (PLATFORM)<br>“Nothing to see here yet” (SOURCED)<br>“Save the photos of a week as an album from its recap.” (SOURCED)<br>“View recaps” (SOURCED) | empty | no field; C-27 (`icon.global.albums`, title, detail, C-06 "View recaps" → the recap list sheet) |
| matched | `albums.list.search.empty` | “No matching albums” (SOURCED) | no search results | C-27 title under the field |
| matched | `color.global.textSecondary`<br>`albums.list.error.title` | #999999 (SOURCED)<br>“Error retrieving your albums. Tap here to try again” (SOURCED) | error | `SocialErrorLine` (`albums.list.error.title`) |
| matched | `—` | — | offline | cached albums first; nothing cached → the error line |
| matched | `—` | — | permission-denied | n/a |

## Haptics

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | tap a row (Android) | none on iOS |

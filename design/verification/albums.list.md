# Verification — `albums.list` (iOS)

Group albums (Apple Photos cover grid) — `ios/App/Sources/Features/Social/UI/AlbumViews.swift` (`AlbumsListScreen`, `AlbumCover`), `Core/AlbumModels.swift`.

Checklist written from the spec (`design/surfaces/albums.list.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`), then `tools/sidebyside.py` makes `design/verification/albums.list.png` next to the reference image(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level).

Reference image(s): `references/auto/apple-photos/apple-support/photos-albums-ios27.png`, `references/owner/yope-week-recap.jpg`

Snapshots (CI): `albums.list-ready.png`, `albums.list-loading.png`, `albums.list-empty.png`, `albums.list-error.png`, `albums.list-offline.png`

**Summary: 8 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Layout

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `color.global.backgroundDeep`<br>`size.global.headerButton`<br>`color.global.controlOnDeep`<br>`size.global.headerInset`<br>`icon.global.back`<br>`albums.list.title`<br>`week.recap.fontSize.title` | #000000 (SOURCED)<br>44 pt (SOURCED)<br>#101010 (SOURCED)<br>11.5 pt (SOURCED)<br>ios: chevron.left; android: AutoMirrored.Rounded.KeyboardArrowLeft (PLATFORM)<br>“memory albums” (SOURCED)<br>17 pt (CAPTURED) | header: ‹ circle, centred title | SocialCenteredHeader |
| matched | `albums.list.layout.yopeAlbums` | format: grid of album covers (Apple Photos "Album Cover" format); columns: 2; coverAspect: 1; coverWidth: 168; gap: 12.4; marginH: 23; coverRadius: 18.5; cov… (SOURCED) | 2 columns, margins 23, gap 12.4, square covers, corners 18.5, newest first (G-17) | LazyVGrid; AlbumCover aspectRatio(coverAspect) clipped by coverRadius; cover decoded at its pixel width |
| matched | `albums.list.layout.yopeAlbums`<br>`color.global.textPrimary` | format: grid of album covers (Apple Photos "Album Cover" format); columns: 2; coverAspect: 1; coverWidth: 168; gap: 12.4; marginH: 23; coverRadius: 18.5; cov… (SOURCED)<br>#FFFFFF (SOURCED) | name over the bottom-leading corner: 15 pt, ink 14 from the edge, baseline 17 above the bottom, one line | overlay + lastTextBaseline guide; Dynamic Type of listSubtitle; the trailing inset mirrors the leading one (not measured) |
| matched | `albums.list.row.subtitle` | “saved by {name}” (SOURCED) | “saved by {name}” in the accessibility label only | accessibilityRepresentation of the name and subtitle texts combined by the platform (.combine); the photo is decorative |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `groups.create.size.hud`<br>`groups.create.color.hud`<br>`groups.create.fontSize.hudLabel`<br>`chat.thread.radius.loadingHud`<br>`groups.create.hud.loading` | 100 pt (SOURCED)<br>#0C0C0C (SOURCED)<br>15 pt (SOURCED)<br>10.5 pt (SOURCED)<br>“Loading” (SOURCED) | loading | HUD only when nothing is cached |
| matched | `albums.list.empty.title`<br>`albums.list.empty.detail`<br>`albums.list.empty.action` | “no memory albums yet” (SOURCED)<br>“save a recap, or any pics from it, as an album” (SOURCED)<br>“view recap” (SOURCED) | empty → latest recap | EmptyStateView; pill only when a ready recap exists |
| matched | `albums.list.error.title`<br>`chat.thread.error.detail`<br>`chat.thread.error.retry` | “couldn’t load your albums” (SOURCED)<br>“check your connection and try again — your pics are safe” (SOURCED)<br>“try again” (SOURCED) | error | EmptyStateView + retry |
| matched | `chat.thread.offline.title`<br>`chat.thread.offline.detail` | “you’re offline” (SOURCED)<br>“your group’s pics will be right here when you’re back” (SOURCED) | offline | cached albums; else the offline layout |

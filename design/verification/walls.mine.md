# Verification — `walls.mine` (iOS)

My wall (the profile “pics” grid) — `ios/App/Sources/Features/Social/UI/WallsViews.swift` (`WallMineScreen`, `WallGrid`, `WallHeader`), `Core/WallModels.swift`.

Checklist written from the spec (`design/surfaces/walls.mine.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`), then `tools/sidebyside.py` makes `design/verification/walls.mine.png` next to the reference image(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level).

Reference image(s): `references/auto/yope/frames/b-presskit-profile.png`, `references/auto/yope/frames/b-yopeapp-7591560669967682847-t116.00-me-and-friends.png`

Snapshots (CI): `walls.mine-ready.png`, `walls.mine-loading.png`, `walls.mine-empty.png`, `walls.mine-error.png`, `walls.mine-offline.png`

**Summary: 12 matched · 2 approximated · 0 not matched (BLOCKED or not buildable).**

## Layout

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `color.global.backgroundDeep` | #000000 (SOURCED) | black background | background ignoring safe area |
| matched | `size.global.headerButton`<br>`color.global.controlOnDeep`<br>`icon.global.settings`<br>`size.global.headerInset`<br>`walls.mine.a11y.settings` | 44 pt (SOURCED)<br>#101010 (SOURCED)<br>ios: gearshape; android: Rounded.Settings (PLATFORM)<br>11.5 pt (SOURCED)<br>“settings” (SOURCED) | settings circle top-right, centred on the title | HeaderCircleButton(.onDeep) → settings; centred on baseline − cap height / 2 |
| matched | `walls.mine.title`<br>`fontSize.global.sheetTitle`<br>`fontWeight.global.sheetTitle`<br>`walls.browse.dimension.titleBaseline` | “my wall” (SOURCED)<br>19.5 pt (SOURCED)<br>bold (SOURCED)<br>23.6 pt (SOURCED) | title “my wall”, baseline below the safe area | alignment guide on firstTextBaseline |
| matched | `walls.mine.dimension.titleToGrid` | 23.5 pt (SOURCED) | grid top below the baseline | header height = titleBaseline + titleToGrid |
| matched | `walls.mine.count.gridColumns`<br>`walls.mine.dimension.gridInset`<br>`walls.mine.dimension.gridGap`<br>`walls.mine.aspectRatio.gridTile`<br>`walls.mine.radius.gridTile`<br>`walls.mine.layout.gridOrder` | 3 (SOURCED)<br>24 pt (SOURCED)<br>4 pt (SOURCED)<br>width: 115.3; height: 158.5 (SOURCED)<br>6.5 pt (SOURCED)<br>order: wall() items newest first, filled left to right, row by row; items: photos and same-moment collages, each in one tile, aspect fill; rows: every row ha… (SOURCED) | 3 columns, insets 24, gaps 4, tile 115.3 : 158.5, corners 6.5, newest first | LazyVGrid flexible columns; thumbnails decoded at the tile’s pixel size |
| approximated | `walls.mine.layout.freeformWall`<br>`walls.mine.layout.mosaic` | BLOCKED<br>BLOCKED | free-form wall / row-2 mosaic | BLOCKED: uniform grid (S-11) |
| matched | `size.global.tabBarHeight` | 58 pt (SOURCED) | floating tab bar over the bottom (tab root) | account FloatingTabBar in a bottom safe-area inset when this is the “me” tab root; pushed from elsewhere: a back circle instead |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `easing.global.native` | keyboard: system; alert: system; activityIndicator: system (ProgressView / CircularProgressIndicator); scrollIndicator: system; navigationPush: system (Navig… (PLATFORM) | loading / loading more | ProgressView only when nothing is cached (cached grid first) |
| matched | `walls.mine.empty.title`<br>`walls.mine.empty.detail`<br>`walls.mine.empty.action`<br>`icon.global.camera` | “nothing on your wall yet” (SOURCED)<br>“pics you send to your groups show up here” (SOURCED)<br>“share a pic” (SOURCED)<br>ios: camera.fill; android: Rounded.PhotoCamera (PLATFORM) | empty: title, detail, white pill → camera | EmptyStateView + action |
| matched | `walls.mine.error.title`<br>`chat.thread.error.detail`<br>`chat.thread.error.retry` | “couldn’t load this wall” (SOURCED)<br>“check your connection and try again — your pics are safe” (SOURCED)<br>“try again” (SOURCED) | error + retry | EmptyStateView |
| matched | `chat.thread.offline.title`<br>`chat.thread.offline.detail` | “you’re offline” (SOURCED)<br>“your group’s pics will be right here when you’re back” (SOURCED) | offline, nothing cached | cached grid otherwise (unit-tested) |

## Tiles and data

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `photo.viewer.a11y.photoMine`<br>`walls.browse.a11y.collage` | “your pic, {date}” (SOURCED)<br>“collage, {date}” (SOURCED) | tile labels | buttons; photo → viewer with this wall’s photos; collage → collage.view |
| approximated | `—` | — | collage tiles cropped into the tile | aspect fill (spec approximation) |
| matched | `—` | — | pages of 50; post_deleted drops every tile of that photo | WallModel (unit-tested) |

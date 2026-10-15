# Verification — `walls.member` (iOS)

A member’s wall — `ios/App/Sources/Features/Social/UI/WallsViews.swift` (`WallMemberScreen`), `Core/WallModels.swift`.

Checklist written from the spec (`design/surfaces/walls.member.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`), then `tools/sidebyside.py` makes `design/verification/walls.member.png` next to the reference image(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level).

Reference image(s): `references/auto/yope/frames/b-presskit-profile.png`, `references/auto/yope/frames/b-yopeapp-7591560669967682847-t116.00-me-and-friends.png`

Snapshots (CI): `walls.member-ready.png`, `walls.member-empty.png`, `walls.member-error.png`, `walls.member-offline.png`

**Summary: 8 matched · 1 approximated · 0 not matched (BLOCKED or not buildable).**

## Layout

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `size.global.headerButton`<br>`color.global.controlOnDeep`<br>`icon.global.back`<br>`chat.thread.a11y.back` | 44 pt (SOURCED)<br>#101010 (SOURCED)<br>ios: chevron.left; android: AutoMirrored.Rounded.KeyboardArrowLeft (PLATFORM)<br>“back” (SOURCED) | back circle top-left, centred on the title | HeaderCircleButton(.onDeep) → dismiss |
| matched | `fontSize.global.sheetTitle`<br>`walls.browse.dimension.titleBaseline`<br>`walls.member.a11y.wall` | 19.5 pt (SOURCED)<br>23.6 pt (SOURCED)<br>“{name}’s wall” (SOURCED) | display name centred, one line, tail truncation; read as “{name}’s wall” | WallHeader |
| matched | `walls.mine.count.gridColumns`<br>`walls.mine.dimension.gridInset`<br>`walls.mine.dimension.gridGap`<br>`walls.mine.aspectRatio.gridTile`<br>`walls.mine.radius.gridTile`<br>`walls.mine.layout.gridOrder`<br>`walls.mine.dimension.titleToGrid` | 3 (SOURCED)<br>24 pt (SOURCED)<br>4 pt (SOURCED)<br>width: 115.3; height: 158.5 (SOURCED)<br>6.5 pt (SOURCED)<br>order: wall() items newest first, filled left to right, row by row; items: photos and same-moment collages, each in one tile, aspect fill; rows: every row ha… (SOURCED)<br>23.5 pt (SOURCED) | wall grid as walls.mine | WallGrid |
| approximated | `walls.mine.layout.freeformWall` | BLOCKED | free-form canvas | BLOCKED: grid (S-11) |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `easing.global.native` | keyboard: system; alert: system; activityIndicator: system (ProgressView / CircularProgressIndicator); scrollIndicator: system; navigationPush: system (Navig… (PLATFORM) | loading | ProgressView only when nothing is cached |
| matched | `walls.member.empty.title`<br>`walls.member.empty.detail` | “no pics from {name} yet” (SOURCED)<br>“you’ll see the pics {name} sends to groups you’re both in” (SOURCED) | empty (no shared photos / blocked) | EmptyStateView without pill |
| matched | `walls.mine.error.title`<br>`chat.thread.error.detail`<br>`chat.thread.error.retry` | “couldn’t load this wall” (SOURCED)<br>“check your connection and try again — your pics are safe” (SOURCED)<br>“try again” (SOURCED) | error | EmptyStateView + retry |
| matched | `chat.thread.offline.title`<br>`chat.thread.offline.detail` | “you’re offline” (SOURCED)<br>“your group’s pics will be right here when you’re back” (SOURCED) | offline | cached grid, else the offline layout |
| matched | `photo.viewer.a11y.photo`<br>`walls.browse.a11y.collage` | “{name}’s pic, {date}” (SOURCED)<br>“collage, {date}” (SOURCED) | tile labels | buttons |

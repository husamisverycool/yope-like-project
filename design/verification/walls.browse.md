# Verification — `walls.browse` (iOS)

“me & friends”: person row and the selected person’s wall — `ios/App/Sources/Features/Social/UI/WallsViews.swift` (`WallsBrowseScreen`), `Core/WallModels.swift` (`WallsBrowseModel`).

Checklist written from the spec (`design/surfaces/walls.browse.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`), then `tools/sidebyside.py` makes `design/verification/walls.browse.png` next to the reference image(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level).

Reference image(s): `references/auto/yope/frames/b-yopeapp-7591560669967682847-t116.00-me-and-friends.png`, `references/auto/yope/frames/b-yopeapp-7591560669967682847-t118.00-friends-wall.png`

Snapshots (CI): `walls.browse-ready.png`, `walls.browse-loading.png`, `walls.browse-empty.png`, `walls.browse-error.png`, `walls.browse-offline.png`

**Summary: 11 matched · 2 approximated · 0 not matched (BLOCKED or not buildable).**

## Layout

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `walls.browse.title`<br>`fontSize.global.sheetTitle`<br>`walls.browse.dimension.titleBaseline` | “me & friends” (SOURCED)<br>19.5 pt (SOURCED)<br>23.6 pt (SOURCED) | title centred, baseline 23.6 | alignment guide |
| matched | `walls.browse.dimension.rowCenter`<br>`walls.browse.dimension.avatar`<br>`walls.browse.dimension.avatarPitch`<br>`walls.browse.dimension.rowInset` | 93.5 pt (SOURCED)<br>60 pt (SOURCED)<br>77.7 pt (SOURCED)<br>19.7 pt (SOURCED) | person row: 60-pt circles at pitch 77.7, first at 19.7 | horizontal ScrollView; each item pitch wide, first item offset so its circle starts at rowInset |
| matched | `walls.browse.me`<br>`fontSize.global.caption`<br>`walls.browse.dimension.labelBaselineGap` | “me” (SOURCED)<br>12 pt (SOURCED)<br>22 pt (SOURCED) | first-name labels, baseline 22 under the circle, one line, no wider than the pitch | alignment guide; tail truncation |
| approximated | `walls.browse.layout.rowOrder` | BLOCKED | row order | BLOCKED: me first, then newest wall item first (spec approximation) |
| approximated | `walls.browse.layout.selection` | BLOCKED | selected person’s marking | BLOCKED: selected trait for VoiceOver only |
| matched | `walls.browse.dimension.wallTop`<br>`walls.mine.count.gridColumns`<br>`walls.mine.dimension.gridInset`<br>`walls.mine.dimension.gridGap`<br>`walls.mine.aspectRatio.gridTile`<br>`walls.mine.radius.gridTile`<br>`walls.mine.layout.gridOrder` | 173 pt (SOURCED)<br>3 (SOURCED)<br>24 pt (SOURCED)<br>4 pt (SOURCED)<br>width: 115.3; height: 158.5 (SOURCED)<br>6.5 pt (SOURCED)<br>order: wall() items newest first, filled left to right, row by row; items: photos and same-moment collages, each in one tile, aspect fill; rows: every row ha… (SOURCED) | selected person’s wall from top 173 | WallContent for the selected WallModel |
| matched | `size.global.tabBarHeight` | 58 pt (SOURCED) | floating tab bar (walls tab root) | account FloatingTabBar when this is the walls tab root; from a group profile: back circle instead |

## States and haptics

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `easing.global.native` | keyboard: system; alert: system; activityIndicator: system (ProgressView / CircularProgressIndicator); scrollIndicator: system; navigationPush: system (Navig… (PLATFORM) | loading people / wall | indicators only when nothing is cached (cached people first, refreshed in place; unit-tested) |
| matched | `walls.browse.empty.title`<br>`walls.browse.empty.detail`<br>`walls.browse.empty.action` | “no walls here yet” (SOURCED)<br>“create a group and everyone’s pics show up here” (SOURCED)<br>“create group” (SOURCED) | nobody else: row shows only me; white pill → groups.create | EmptyStateView + AccountModal.groupCreate |
| matched | `walls.mine.error.title`<br>`chat.thread.error.detail`<br>`chat.thread.error.retry` | “couldn’t load this wall” (SOURCED)<br>“check your connection and try again — your pics are safe” (SOURCED)<br>“try again” (SOURCED) | error | EmptyStateView + retry |
| matched | `chat.thread.offline.title`<br>`chat.thread.offline.detail` | “you’re offline” (SOURCED)<br>“your group’s pics will be right here when you’re back” (SOURCED) | offline | cached people and walls; else the offline layout |
| matched | `haptic.global.select` | ios: selection; android: SEGMENT_TICK (PLATFORM) | person selected | SocialFeedback.select (not on the initial selection) |
| matched | `walls.member.a11y.wall`<br>`walls.mine.title` | “{name}’s wall” (SOURCED)<br>“my wall” (SOURCED) | circle labels, selected trait | buttons |

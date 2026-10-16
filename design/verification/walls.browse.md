# Verification — `walls.browse` (iOS)

Friends (Retro's people grid: serif title, search, three columns of avatars) — `ios/App/Sources/Features/Social/UI/WallsViews.swift` (`WallsBrowseScreen`, `PeopleColumns`), `Core/WallModels.swift` (`WallsBrowseModel`).

Pass 4 (Retro redesign). Checklist written from the spec (`design/surfaces/walls.browse.md`, MERGE "Redesign — Social (RS-*)", lead L-3 / L-4) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>-<light|dark>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/walls.browse.png` next to the Retro reference(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level). Components are the Pass 3 library (`ios/App/Sources/Components`, C-01…C-35).

Retro reference(s): `references/auto/retro/press/tc-2023-07-retro-1b.webp (Friends grid, primary)`, `references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png`

Snapshots (CI): `walls.browse-ready-light.png`, `walls.browse-ready-dark.png`, `walls.browse-no-results-light.png`, `walls.browse-loading-light.png`, `walls.browse-empty-light.png`, `walls.browse-error-light.png`, `walls.browse-offline-light.png`, `walls.browse-group-light.png`

**Summary: 11 matched · 1 approximated · 0 not matched (BLOCKED or not buildable).**

## Elements

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `font.global.display`<br>`size.global.titleTop`<br>`walls.browse.title` | ios: system-serif; android: serif (PLATFORM)<br>64 pt (SOURCED)<br>“Members” (SOURCED; owner decision 10) | title | C-01 `ScreenHeader` "Members" at the tab root; C-02 with back when pushed for one group |
| matched | `size.global.fieldHeight`<br>`radius.global.field`<br>`color.global.control`<br>`icon.global.search`<br>`walls.browse.search` | 52 pt (SOURCED)<br>19 pt (SOURCED)<br>light #F1F1F1 / dark #262626 (SOURCED)<br>ios: magnifyingglass; android: Rounded.Search (PLATFORM)<br>“Search” (SOURCED) | search | C-12 `SearchField` inside `screenMargin` `titleToContent` below the title baseline (from the component); filters by name (unit-tested) |
| approximated | `size.global.avatarGrid`<br>`walls.browse.dimension.columnPitch`<br>`walls.browse.dimension.rowPitch`<br>`walls.browse.dimension.nameBaseline`<br>`walls.member.a11y.wall` | 81 pt (SOURCED)<br>124.3 pt (SOURCED)<br>131.1 pt (SOURCED)<br>27.2 pt (SOURCED)<br>“{name}'s profile” (SOURCED) | person cell | `PeopleColumns`: fixed columns `columnPitch` wide (count read from `layout.grid` — "3 columns"), rows `rowPitch`, `AvatarView` (`avatarGrid`), name (`listTitle`, one line) baseline `nameBaseline` below the avatar; tap → walls.member; label `walls.member.a11y.wall`. A local grid: the shared `PeopleGrid` shares the width between flexible columns with platform spacing (component gap C-21). Row order: next row |
| matched | `walls.browse.layout.rowOrder` | order: by display name, A to Z, in the device locale's collation, ignoring case and accents; tie: profile id (SOURCED) | order of people | `SocialOrdering.byName` (`.caseInsensitive` + `.diacriticInsensitive`, the device locale — the comparison Android's `Collator` makes; unit-tested `testBrowseListsEveryoneElseByName`, `testPeopleOrderIgnoresCaseAndAccentsAndBreaksTiesByID`) |
| matched | `—` | — | tab bar (C-04) | `AppTabBar(selected: .walls)` when Friends is the tab root |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `week.history.a11y.loading` | “Loading” (SOURCED) | loading | `LoadingHUD` under the field (no indicator over cached people) |
| matched | `icon.global.group`<br>`walls.browse.empty.title`<br>`walls.browse.empty.detail`<br>`walls.browse.empty.action` | ios: person.2; android: Outlined.Group (PLATFORM)<br>“Nothing to see here yet” (SOURCED)<br>“People in your groups show up here.” (SOURCED)<br>“Create a group” (SOURCED) | empty (no groups / nobody else) | no field; C-27 centred (`icon.global.group`, title, detail, C-06 "Create a group" → `groups.create`) |
| matched | `walls.browse.search.empty` | “No matching people” (SOURCED) | no search results | C-27 title `walls.browse.search.empty` under the field |
| matched | `size.global.screenMargin`<br>`color.global.textSecondary`<br>`walls.browse.error.title` | 16 pt (SOURCED)<br>#999999 (SOURCED)<br>“Error loading members. Tap here to try again.” (SOURCED; owner decision 10) | error | `SocialErrorLine` under the title |
| matched | `—` | — | offline | cached groups and members first, refreshed in place (unit-tested) |
| matched | `—` | — | permission-denied | n/a |

## Haptics

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | tap a person (Android) | none on iOS |

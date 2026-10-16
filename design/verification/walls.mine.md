# Verification — `walls.mine` (iOS)

My wall (Retro's profile tab: serif name, avatar, gear capsule, week sections) — `ios/App/Sources/Features/Social/UI/WallsViews.swift` (`WallMineScreen`, `WallProfileHeader`, `WallWeekList`, `WallTiles`, `WallPage`), `Core/WallModels.swift` (`WallModel`).

Pass 4 (Retro redesign). Checklist written from the spec (`design/surfaces/walls.mine.md`, MERGE "Redesign — Social (RS-*)", lead L-3 / L-4) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>-<light|dark>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/walls.mine.png` next to the Retro reference(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level). Components are the Pass 3 library (`ios/App/Sources/Components`, C-01…C-35).

Retro reference(s): `references/auto/retro/store/retro-store-02.png (ST-02, primary)`, `references/auto/retro/press/engadget-2026-08-profile.jpg (current week)`, `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png (empty week)`

Snapshots (CI): `walls.mine-ready-light.png`, `walls.mine-ready-dark.png`, `walls.mine-loading-light.png`, `walls.mine-empty-light.png`, `walls.mine-error-light.png`, `walls.mine-offline-light.png`

**Summary: 16 matched · 1 approximated · 0 not matched (BLOCKED or not buildable).**

## Elements

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `font.global.display`<br>`size.global.titleTop` | ios: system-serif; android: serif (PLATFORM)<br>64 pt (SOURCED) | name | `WallProfileHeader`: the name in `headerTitle` (display serif), one line, first baseline `titleTop` below the safe area (no chevron at the tab root), header trait |
| approximated | `size.global.avatarProfile` | 64 pt (SOURCED) | avatar | `AvatarView` (`avatarProfile`) at the trailing margin, centred on the name's cap middle (`.capMiddle`) — the shared `ProfileHeader` centres it on the name block with platform spacing (component gap C-19) |
| matched | `size.global.iconPillWidth`<br>`size.global.pillHeight`<br>`icon.global.settings`<br>`size.global.iconSmall`<br>`walls.mine.dimension.nameToActions`<br>`walls.mine.a11y.settings` | 49 pt (SOURCED)<br>37 pt (SOURCED)<br>ios: gearshape; android: Outlined.Settings (PLATFORM)<br>14.7 pt (SOURCED)<br>23 pt (SOURCED)<br>“Settings” (SOURCED) | settings capsule | C-06 `CapsuleButton(icon: settings)` at the trailing margin, its top `nameToActions` below the name's baseline → `settings.root` (account's sheet route) |
| matched | `week.history.header.title` | “Week {week_number}” (SOURCED) | section header | C-20 `SectionHeader`: "Week {n}" (ISO, device time zone) + the range ("Oct 12 – 18"), no "•••"; range left out for the current week without photos; first header `actionsToWeeks` below the actions |
| matched | `photo.viewer.a11y.photoMine` | “Your photo, {date}” (SOURCED) | photo tile | C-17 photo tile; label "Your photo, {date}"; tap → viewer with this wall's photos (newest week first, time order inside — unit-tested), group name in the header line |
| matched | `walls.browse.a11y.collage` | “Collage, {date}” (SOURCED) | collage tile | collage tile (ready collages only, unit-tested), label `walls.browse.a11y.collage`; tap → capture's `collage.view` presented full screen through the shell (`SocialNav.presentRoute` → `PresentedRoute`) |
| matched | `color.global.control`<br>`icon.global.add`<br>`week.history.a11y.add` | light #F1F1F1 / dark #262626 (SOURCED)<br>ios: plus; android: Rounded.Add (PLATFORM)<br>“Add photos” (SOURCED) | add tile | C-17 add tile in the current week → `camera.capture` (groups chosen in send-to) |
| matched | `color.global.control`<br>`color.global.emptyTileText`<br>`week.history.a11y.emptyDay` | light #F1F1F1 / dark #262626 (SOURCED)<br>light #D9D9D9 / dark #515151 (SOURCED)<br>“{weekday}, {date}, no photos” (SOURCED) | empty-day tile | C-17 dated empty-day tiles for the current week without photos (`emptyDays`, unit-tested) |
| matched | `color.global.control`<br>`week.history.a11y.emptyDay` | light #F1F1F1 / dark #262626 (SOURCED)<br>“{weekday}, {date}, no photos” (SOURCED) | placeholder tile | C-17 blank placeholders after the add tile for the current week's days without a photo |
| matched | `—` | — | tab bar (C-04) | `AppTabBar(selected: .me)` in the bottom inset when the wall is the profile tab's root (account's shell navigation) |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `week.history.a11y.loading` | “Loading” (SOURCED) | loading | header (profile from the cache / `profiles`); one section of seven placeholder tiles under a header without range; announced once |
| matched | `—` | — | loading more | `ProgressView` after the last section while the next page loads |
| matched | `icon.global.calendar`<br>`size.global.emptyIcon`<br>`size.global.emptyIconToTitle`<br>`size.global.emptyTitleToAction`<br>`icon.global.add`<br>`walls.mine.empty.title`<br>`walls.mine.empty.action` | ios: calendar; android: Outlined.CalendarMonth (PLATFORM)<br>22 pt (SOURCED)<br>26 pt (SOURCED)<br>25 pt (SOURCED)<br>ios: plus; android: Rounded.Add (PLATFORM)<br>“Welcome to Week {week_number}!” (SOURCED)<br>“Get this week started” (SOURCED) | empty (no photos) | current week strip, then C-27 centred below (`icon.global.calendar`, "Welcome to Week {n}!", C-07 "Get this week started" with `icon.global.add` → camera) |
| matched | `size.global.screenMargin`<br>`color.global.textSecondary`<br>`walls.mine.error.title` | 16 pt (SOURCED)<br>#999999 (SOURCED)<br>“Error loading your weeks. Tap here to try again.” (SOURCED) | error | `SocialErrorLine` (tappable `body` line in `textSecondary` at the margin) → retry |
| matched | `walls.mine.error.title` | “Error loading your weeks. Tap here to try again.” (SOURCED) | offline | cached wall first (`cachedWall`); nothing cached → the error line |
| matched | `—` | — | permission-denied | n/a |

## Haptics

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | tap on a tile / capsule (Android) | none on iOS |

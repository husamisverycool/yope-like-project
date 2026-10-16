# Verification — `week.history` (iOS)

The group's weeks (Retro's profile week sections for the group, with the week menu) — `ios/App/Sources/Features/Social/UI/WeekHistoryView.swift` (`WeekHistoryScreen`, `WeekHistorySection`), `Core/WeekModels.swift` (`WeekHistoryModel`).

Pass 4 (Retro redesign). Checklist written from the spec (`design/surfaces/week.history.md`, MERGE "Redesign — Social (RS-*)", lead L-3 / L-4) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>-<light|dark>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/week.history.png` next to the Retro reference(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level). Components are the Pass 3 library (`ios/App/Sources/Components`, C-01…C-35).

Retro reference(s): `references/auto/retro/store/retro-store-02.png (ST-02, primary)`, `references/auto/retro/press/engadget-2026-08-profile.jpg (current week)`, `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png`

Snapshots (CI): `week.history-ready-light.png`, `week.history-ready-dark.png`, `week.history-loading-light.png`, `week.history-empty-light.png`, `week.history-error-light.png`, `week.history-offline-light.png`

**Summary: 16 matched · 1 approximated · 0 not matched (BLOCKED or not buildable).**

## Elements

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `icon.global.back`<br>`size.global.backInset`<br>`size.global.headerGap`<br>`chat.thread.a11y.back` | ios: chevron.left; android: AutoMirrored.Rounded.ArrowBackIos (PLATFORM)<br>21.1 pt (SOURCED)<br>14.6 pt (SOURCED)<br>“Back” (SOURCED) | back + title | C-02 `PushedScreenHeader` with the group's name, one line |
| matched | `icon.global.more`<br>`size.global.sectionHeaderToContent`<br>`size.global.sectionGap`<br>`week.history.header.title`<br>`week.history.a11y.more` | ios: ellipsis; android: Rounded.MoreHoriz (PLATFORM)<br>11.7 pt (SOURCED)<br>36.4 pt (SOURCED)<br>“Week {week_number}” (SOURCED)<br>“More Options” (SOURCED) | section header | C-20 `SectionHeader` "Week {n}" + range (left out for the current week without photos) + "•••" native menu when the week has a ready recap or photos: "View recap" (→ the preview as a full-screen cover) · "Save as Album" (→ the album sheet with the week's photos); `week.history.layout.weekMenu` SOURCED (BlockedTokens use removed); `WeekStripSection` / `WeekSectionList` spacing |
| matched | `week.history.a11y.tile`<br>`duration.global.photoOpen` | “{weekday}, {date}, {name}'s photo” (SOURCED)<br>250 ms (SOURCED) | photo tile | C-17 tile labelled `week.history.a11y.tile`; tap → viewer with that week's posts in time order |
| matched | `week.history.a11y.add` | “Add photos” (SOURCED) | add tile | C-17 add tile in the current week → the camera for this group |
| matched | `week.history.a11y.emptyDay` | “{weekday}, {date}, no photos” (SOURCED) | empty-day tile | dated empty-day tiles for the current week without photos (unit-tested) |
| matched | `week.history.a11y.emptyDay` | “{weekday}, {date}, no photos” (SOURCED) | placeholder tile | blank placeholders for the current week's days without a photo |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `week.history.a11y.loading` | “Loading” (SOURCED) | loading | header; two placeholder sections under headers without ranges; announced |
| matched | `—` | — | loading more | `ProgressView` after the last section (8 weeks per page, unit-tested) |
| matched | `icon.global.calendar`<br>`icon.global.add`<br>`week.history.empty.title`<br>`week.history.empty.action` | ios: calendar; android: Outlined.CalendarMonth (PLATFORM)<br>ios: plus; android: Rounded.Add (PLATFORM)<br>“Welcome to Week {week_number}!” (SOURCED)<br>“Get this week started” (SOURCED) | empty (no photos in the group yet) | current week (add + seven empty days), then C-27 centred below: calendar glyph, "Welcome to Week {n}!", C-07 with `icon.global.add` → camera for this group |
| matched | `size.global.screenMargin`<br>`color.global.textSecondary`<br>`week.history.error` | 16 pt (SOURCED)<br>#999999 (SOURCED)<br>“Error loading weeks. Tap here to try again.” (SOURCED) | error | `SocialErrorLine` `week.history.error` → reload |
| matched | `week.history.offline` | “Couldn't load new weeks. Check your connection and try again.” (SOURCED) | offline | `week.history.offline` line above the cached weeks |
| matched | `—` | — | permission-denied | n/a |

## Motion

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `easing.global.native` | sheet: system (.sheet / ModalBottomSheet) — measured on Retro: spring.global.sheetPresent; navigationPush: system (NavigationStack / Compose… (PLATFORM) | push / pop, scrolling, menu | system |
| matched | `duration.global.stripInsert`<br>`easing.global.standard`<br>`duration.global.fade` | 250 ms (SOURCED)<br>x1: 0.4; y1: 0; x2: 0.2; y2: 1 (SOURCED)<br>150 ms (SOURCED) | a new photo arrives in the current week | the component strip's insert motion (C-17) |
| approximated | `duration.global.photoOpen` | 250 ms (SOURCED) | photo opens | native `.fullScreenCover`, not the 250-ms transition |

## Haptics

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | tap a tile, "•••" (Android) | none on iOS |
| matched | `—` | — | menu | native |

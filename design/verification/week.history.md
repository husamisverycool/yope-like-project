# Verification — `week.history` (iOS)

Group history by week (Retro) — `ios/App/Sources/Features/Social/UI/WeekViews.swift` (`WeekHistoryScreen`, `WeekSection`, `EmptyDayTile`), `Core/WeekModels.swift` (`WeekHistoryModel`).

Checklist written from the spec (`design/surfaces/week.history.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`), then `tools/sidebyside.py` makes `design/verification/week.history.png` next to the reference image(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level).

Reference image(s): `references/auto/retro/store/retro-store-02.png`, `references/auto/retro/store/retro-store-01.png`, `references/auto/retro/press/jeddacp-2024-05-home-profile-journals.png`

Snapshots (CI): `week.history-ready.png`, `week.history-loading.png`, `week.history-empty.png`, `week.history-error.png`, `week.history-offline.png`

**Summary: 12 matched · 2 approximated · 0 not matched (BLOCKED or not buildable).**

## Header and sections

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `color.global.backgroundDeep`<br>`size.global.headerButton`<br>`color.global.controlOnDeep`<br>`size.global.headerInset`<br>`icon.global.back` | #000000 (SOURCED)<br>44 pt (SOURCED)<br>#101010 (SOURCED)<br>11.5 pt (SOURCED)<br>ios: chevron.left; android: AutoMirrored.Rounded.KeyboardArrowLeft (PLATFORM) | back circle | HeaderCircleButton |
| matched | `week.history.fontSize.title`<br>`week.history.fontWeight.title`<br>`week.history.font.title`<br>`week.history.dimension.titleInset` | 43 pt (SOURCED)<br>heavy (SOURCED)<br>ios: system; android: system (PLATFORM)<br>16 pt (SOURCED) | group name, display role, one line | SocialText.historyTitle |
| approximated | `week.history.dimension.titleToStrip` | 17.6 pt (SOURCED) | first header below the title | padding on the first section (spec text: title baseline → header cap top; measured from the views’ edges) |
| matched | `week.history.header.title`<br>`week.history.fontSize.header`<br>`week.history.fontWeight.headerTitle`<br>`week.history.fontWeight.headerRange`<br>`week.history.dimension.rangeGap`<br>`week.history.dimension.inset` | “Week {week_number}” (SOURCED)<br>15 pt (SOURCED)<br>semibold (SOURCED)<br>regular (SOURCED)<br>7.5 pt (SOURCED)<br>20 pt (SOURCED) | “Week {n}” + locale range, same baseline; range omitted for an empty current week | HStack(.firstTextBaseline); ISO week numbers (unit-tested); DateIntervalFormatter template MMMd |
| approximated | `icon.global.more`<br>`week.history.dimension.moreTrailing`<br>`week.history.layout.weekMenu`<br>`week.history.menu.viewRecap`<br>`week.history.menu.saveAsAlbum` | ios: ellipsis; android: Rounded.MoreHoriz (PLATFORM)<br>22 pt (SOURCED)<br>BLOCKED<br>“View recap” (SOURCED)<br>“Save as album” (SOURCED) | ••• menu | Retro’s contents BLOCKED: our two product items (native Menu) |
| matched | `week.history.dimension.headerToStrip`<br>`week.history.dimension.tileWidth`<br>`week.history.dimension.tileHeight`<br>`week.history.dimension.tileGap`<br>`week.history.radius.strip` | 11.7 pt (SOURCED)<br>84.5 pt (SOURCED)<br>112 pt (SOURCED)<br>2 pt (SOURCED)<br>14 pt (SOURCED) | strip: tiles 84.5 × 112, gaps 2, outer corners 14, scrolls horizontally | HStack clipped by RoundedRectangle |
| matched | `week.history.fontSize.weekday`<br>`week.history.fontWeight.weekday`<br>`week.history.dimension.weekdayBaseline`<br>`week.history.a11y.tile` | 13 pt (SOURCED)<br>semibold (SOURCED)<br>13.4 pt (SOURCED)<br>“{weekday}, {date}, {name}’s photo” (SOURCED) | photo tile with weekday | overlay + baseline alignment guide |
| matched | `week.history.color.emptyTile`<br>`week.history.icon.add`<br>`week.history.dimension.addGlyph`<br>`color.global.textPrimary`<br>`week.history.a11y.add` | #262626 (SOURCED)<br>ios: plus; android: Rounded.Add (PLATFORM)<br>20 pt (SOURCED)<br>#FFFFFF (SOURCED)<br>“Add Photos” (SOURCED) | current week: add tile → camera for this group (G-15) | Button with the “+” in textPrimary |
| matched | `week.history.color.emptyTile`<br>`week.history.color.emptyTileText`<br>`week.history.fontSize.emptyDay`<br>`week.history.fontSize.emptyDayLabel`<br>`week.history.a11y.emptyDay` | #262626 (SOURCED)<br>#515151 (SOURCED)<br>29 pt (SOURCED)<br>15 pt (SOURCED)<br>“{weekday}, {date}, no photos” (SOURCED) | one empty-day tile per day without a photo: month / day (bold) / weekday | EmptyDayTile; days from the loaded photos only (no tile appears then disappears; unit-tested) |
| matched | `week.history.dimension.sectionGap` | 36.4 pt (SOURCED) | next section | padding |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `easing.global.native` | keyboard: system; alert: system; activityIndicator: system (ProgressView / CircularProgressIndicator); scrollIndicator: system; navigationPush: system (Navig… (PLATFORM) | loading / loading more | indicator only before any cached week (cached weeks first; unit-tested) |
| matched | `week.history.empty` | “Photos shared in {group_name} collect here, week by week.” (SOURCED) | empty: current week (add tile + 7 empty days) then the line | synthesised current week (unit-tested) |
| matched | `week.history.error` | “Couldn’t load your group’s weeks. Pull down to try again.” (SOURCED) | error line; pull to refresh | refreshable; cached weeks stay on screen |
| matched | `week.history.offline` | “You’re offline. Weeks you’ve already opened are still here.” (SOURCED) | offline line at the top | cached weeks |

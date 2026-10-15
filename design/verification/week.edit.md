# Verification — `week.edit` (iOS)

Recap editor (check / reorder / text / save; save as album) — `ios/App/Sources/Features/Social/UI/WeekViews.swift` (`WeekEditView`, `ReorderableTile`, `AlbumNameSheet`), `Core/WeekModels.swift` (`WeekEditModel`).

Checklist written from the spec (`design/surfaces/week.edit.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`), then `tools/sidebyside.py` makes `design/verification/week.edit.png` next to the reference image(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level).

Reference image(s): `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t6.73-sendto-voice-tooltip.png`, `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t45.23-new-group-empty.png`, `references/auto/apple-photos/apple-support/page-filter-sort-albums.png`

Snapshots (CI): `week.edit-ready.png`, `week.edit-error.png`, `week.edit-not-ready.png`, `week.edit-loading.png`, `week.edit-album-sheet.png`

**Summary: 9 matched · 3 approximated · 2 not matched (BLOCKED or not buildable).**

## Editor

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `color.global.backgroundDeep`<br>`size.global.headerButton`<br>`color.global.controlOnDeep`<br>`size.global.headerInset`<br>`icon.global.close`<br>`week.edit.a11y.close`<br>`week.edit.title` | #000000 (SOURCED)<br>44 pt (SOURCED)<br>#101010 (SOURCED)<br>11.5 pt (SOURCED)<br>ios: xmark; android: Rounded.Close (PLATFORM)<br>“close” (SOURCED)<br>“edit recap” (SOURCED) | full-height sheet: ✕ circle, title (sheetTitle) | SocialCenteredHeader(titleStyle: sheetTitle) |
| matched | `week.recap.count.picsColumns`<br>`week.recap.dimension.picsGap`<br>`week.recap.aspectRatio.picsTile` | 3 (CAPTURED)<br>1 pt (CAPTURED)<br>width: 131; height: 175 (CAPTURED) | grid: recap items first in recap order, then the week’s other posts | WeekEditModel.gridPosts (unit-tested); opens on what week.recap shows (no HUD) |
| approximated | `size.global.checkCircle`<br>`icon.global.check`<br>`icon.global.uncheck`<br>`color.global.selection`<br>`size.global.listGap` | 24 pt (SOURCED)<br>ios: checkmark.circle.fill; android: Rounded.CheckCircle (PLATFORM)<br>ios: circle; android: Rounded.RadioButtonUnchecked (PLATFORM)<br>#0091FF (PLATFORM)<br>7.5 pt (SOURCED) | selection circle top-right, inset listGap | spec approximation (position not observed) |
| matched | `week.edit.a11y.inRecap`<br>`week.edit.a11y.notInRecap`<br>`haptic.global.select` | “in recap” (SOURCED)<br>“not in recap” (SOURCED)<br>ios: selection; android: SEGMENT_TICK (PLATFORM) | tap toggles; label + value | model feedback |
| matched | `week.edit.layout.reorder`<br>`week.edit.haptic.dragStart`<br>`week.edit.haptic.dragAlign` | gesture: touch and hold a checked tile, then drag it into a new position; release to drop it there; scope: the checked tiles (the recap’s items); their order… (SOURCED)<br>ios: system (List / drag reordering plays its own feedback; no custom generator); android: DRAG_START (PLATFORM)<br>ios: sensoryFeedback(.alignment) (iOS 17); android: SEGMENT_TICK (PLATFORM) | touch and hold a checked tile, drag among the checked tiles (G-16) | draggable / dropDestination in every build; system pick-up feedback; sensoryFeedback(.alignment) per slot |
| not matched | `—` | — | reorder accessibility actions “move earlier / later” | no copy exists for them: not built |
| approximated | `week.edit.layout.recapText`<br>`groups.create.color.field`<br>`radius.global.field`<br>`size.global.fieldHeight`<br>`size.global.buttonMarginH`<br>`week.edit.textPlaceholder` | BLOCKED<br>#141414 (SOURCED)<br>12 pt (SOURCED)<br>44 pt (SOURCED)<br>19 pt (SOURCED)<br>“add a message” (SOURCED) | recap text field | position BLOCKED: spec approximation under the grid |
| matched | `week.edit.save`<br>`color.global.accent`<br>`size.global.buttonHeightSheet`<br>`size.global.buttonMarginHSheet` | “save” (SOURCED)<br>#CDFD07 (SOURCED)<br>47 pt (SOURCED)<br>27 pt (SOURCED) | pinned lime “save” | shared PrimaryButton(.sheet) → update_recap; closes; toast week.edit.toast.saved |
| not matched | `week.edit.saveAsAlbum` | “save as album” (SOURCED) | dark “save as album” button | no tokens for the compact pair: not drawn; “save as album” is in week.history’s week menu |

## Album sheet and states

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `week.edit.album.title`<br>`groups.create.fontSize.title`<br>`groups.create.fontWeight.title`<br>`week.edit.album.namePlaceholder`<br>`groups.create.size.titleToContent`<br>`groups.create.size.fieldToButton` | “new album” (SOURCED)<br>14.5 pt (SOURCED)<br>medium (SOURCED)<br>“name album” (SOURCED)<br>34 pt (SOURCED)<br>18 pt (SOURCED) | name sheet | AlbumNameSheet with the shared FormField and PrimaryButton (disabled until a photo and a name) |
| matched | `week.edit.error.albumName`<br>`week.edit.toast.albumSaved` | “give your album a name” (SOURCED)<br>“album saved” (SOURCED) | empty name on submit; saved | inline line; toast |
| matched | `groups.create.size.hud`<br>`groups.create.color.hud`<br>`groups.create.fontSize.hudLabel`<br>`chat.thread.radius.loadingHud`<br>`groups.create.hud.loading` | 100 pt (SOURCED)<br>#0C0C0C (SOURCED)<br>15 pt (SOURCED)<br>10.5 pt (SOURCED)<br>“Loading” (SOURCED) | loading / saving HUD | shared .loadingHUD |
| matched | `week.edit.error.notReady` | “this recap is still being made” (SOURCED) | recap_not_ready | line |
| approximated | `week.edit.error.save`<br>`haptic.global.error` | “couldn’t save your changes — try again” (SOURCED)<br>ios: notification.error; android: REJECT (PLATFORM) | save failed: inline line above the buttons, selection kept | the save waits for update_recap (the spec’s inline error needs the editor open), so it is not optimistic |

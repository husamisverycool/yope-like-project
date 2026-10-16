# Verification — `week.edit` (iOS)

Recap editor and album sheet (Retro's "Add to Your Week" composer, "Add a Message", "New Album") — `ios/App/Sources/Features/Social/UI/WeekEditView.swift` (`WeekEditView`, `IconCapsuleLabel`, `WeekEditMessageSheet`), `UI/SocialSheetParts.swift` (`SocialNameSheet`, `LeadingCloseSheetHeader`), `Core/WeekModels.swift` (`WeekEditModel`).

Pass 4 (Retro redesign). Checklist written from the spec (`design/surfaces/week.edit.md`, MERGE "Redesign — Social (RS-*)", lead L-3 / L-4) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>-<light|dark>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/week.edit.png` next to the Retro reference(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level). Components are the Pass 3 library (`ios/App/Sources/Components`, C-01…C-35).

Retro reference(s): `references/auto/retro/video/ig-DDbA_F7x-j7-composer-f130-147-f188-197.png (composer)`, `references/auto/retro/press/tc-2023-12-retro3.png`, `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`

Snapshots (CI): `week.edit-ready-light.png`, `week.edit-ready-dark.png`, `week.edit-loading-light.png`, `week.edit-saving-light.png`, `week.edit-empty-selection-light.png`, `week.edit-not-ready-light.png`, `week.edit-album-sheet-light.png`, `week.edit-album-name-missing-light.png`, `week.edit-message-light.png`

**Summary: 22 matched · 3 approximated · 1 not matched (BLOCKED or not buildable).**

## Elements

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `week.edit.cancel`<br>`week.edit.save`<br>`week.edit.toast.saved` | “Cancel” (SOURCED)<br>“Update” (SOURCED)<br>“Saved!” (SOURCED) | Cancel / Update | native toolbar: Cancel (with changes → the discard alert; `interactiveDismissDisabled` while changed) / Update → `save()` → announcement `toast.saved` + close (unit-tested) |
| matched | `week.edit.title` | “Edit Recap” (SOURCED) | title | `.navigationTitle(week.edit.title)`, inline |
| approximated | `week.edit.layout.reorder`<br>`week.edit.haptic.dragStart`<br>`week.edit.haptic.dragAlign`<br>`week.history.a11y.tile` | gesture: touch and hold a photo in the top strip, drag it to a new place in the strip, release to drop; scope: the strip (the recap's items)… (SOURCED)<br>ios: system (drag-and-drop lift plays its own feedback; no custom generator); android: DRAG_START (API 34+; none below) (PLATFORM)<br>ios: sensoryFeedback(.alignment) (iOS 17); android: SEGMENT_FREQUENT_TICK (API 34+; CLOCK_TICK below) (PLATFORM)<br>“{weekday}, {date}, {name}'s photo” (SOURCED) | strip tile | strip of the chosen photos in order (C-17 `DayTile`s, outer corners `radius.global.card`): `draggable` / `dropDestination` reorder (`model.move`, unit-tested), slots shift with `ComponentMotion.stripInsert`, `sensoryFeedback(.alignment)` per slot change, the lift's own system feedback; VoiceOver drag / drop points. A local strip: the shared `WeekStrip` has no reorder (component gap C-17) |
| approximated | `icon.global.edit`<br>`week.edit.message.add`<br>`week.edit.message.edit` | ios: pencil; android: Outlined.Edit (PLATFORM)<br>“Add a message” (SOURCED)<br>“Edit message” (SOURCED) | message capsule | `IconCapsuleLabel`: outline capsule with `icon.global.edit` + "Add a message" / "Edit message" (C-07 anatomy, fills its share of the row) → message sheet. Local: no shared fill-width glyph + label capsule (component gap C-06 / C-07) |
| matched | `week.edit.saveAsAlbum` | “Save as Album” (SOURCED) | Save as Album capsule | C-06 `CapsuleButton(fillsWidth:)` "Save as Album" → album sheet; `CapsuleRow`, `pillGap` apart |
| matched | `week.edit.header` | “Photos taken in Week {week_number}” (SOURCED) | header line | "Photos taken in Week {n}" (`listSubtitle`, `textSecondary`), cap top `sectionGap` below the actions; the grid `sectionHeaderToContent` below its baseline |
| not matched | `week.edit.count.gridColumns`<br>`size.global.stripGap`<br>`week.edit.layout.selectionMark`<br>`week.history.a11y.tile`<br>`week.edit.a11y.inRecap`<br>`week.edit.a11y.notInRecap` | 4 (SOURCED)<br>2 pt (SOURCED)<br>— (BLOCKED)<br>“{weekday}, {date}, {name}'s photo” (SOURCED)<br>“In recap” (SOURCED)<br>“Not in recap” (SOURCED) | grid cell | `gridColumns` square cells, `stripGap` gaps, the week's photos in time order (unit-tested), tap toggles (`haptic.global.select`), value in recap / not in recap. The in / out mark `week.edit.layout.selectionMark` is BLOCKED: DEBUG draws a check glyph (`SocialBlocked.showsSelectionMark`), release none |
| matched | `week.edit.layout.message`<br>`week.edit.message.title`<br>`week.edit.message.done`<br>`week.edit.textPlaceholder`<br>`week.edit.message.counter` | presentation: sheet (C-29) on color.global.background: centred title week.edit.message.title (sheetTitle), trailing text button week.edit.me… (SOURCED)<br>“Add a Message” (SOURCED)<br>“Done” (SOURCED)<br>“Add a message…” (SOURCED)<br>“{used}/{max}” (SOURCED) | message sheet | `WeekEditMessageSheet`: centred title, "Done" (C-08), text field (`placeholder` role) with the placeholder, limit read from `layout.message.limit` |
| matched | `week.edit.album.title`<br>`week.edit.album.namePlaceholder`<br>`week.edit.album.create`<br>`week.edit.error.albumName`<br>`week.edit.toast.albumSaved` | “New Album” (SOURCED)<br>“Name your album” (SOURCED)<br>“Create Album” (SOURCED)<br>“Name missing” (SOURCED)<br>“Added to Album!” (SOURCED) | album sheet | `SocialNameSheet`: leading close circle, centred "New Album", C-12 field (inline `error.albumName` when submitted empty), C-05 primary "Create Album" (`buttonHeightSheet`, busy while saving, disabled until a photo and a name — unit-tested); `save_album` → announcement |
| matched | `week.edit.lostChanges.title`<br>`week.edit.lostChanges.message`<br>`week.edit.lostChanges.confirm`<br>`photo.viewer.delete.cancel` | “Discard changes?” (SOURCED)<br>“Any changes you made will be lost” (SOURCED)<br>“Yes, go back” (SOURCED)<br>“Cancel” (PLATFORM) | discard confirmation | native alert: title, message, "Discard" (destructive), Cancel |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `week.history.a11y.loading` | “Loading” (SOURCED) | loading | placeholder strip and two placeholder grid rows; announced |
| matched | `—` | — | saving | toolbar `ProgressView` in place of "Update" while `isSaving` |
| matched | `week.edit.error.notReady` | “Creating your recap…” (SOURCED) | not ready (`recap_not_ready`) | `recap_not_ready` → C-27 line `week.edit.error.notReady` (the preview offers no editor for a pending recap) |
| matched | `week.edit.error.albumName` | “Name missing” (SOURCED) | empty selection | empty strip allowed (one placeholder tile); album creation disabled without photos |
| matched | `week.edit.error.save`<br>`haptic.global.error` | “There was a problem saving your changes. Please try again.” (SOURCED)<br>ios: notification.error; android: REJECT (PLATFORM) | error (save failed) | native alert `week.edit.error.save` (or `.notReady`); selection kept; `haptic.global.error` (unit-tested) |
| matched | `week.edit.error.save` | “There was a problem saving your changes. Please try again.” (SOURCED) | offline | as above |
| matched | `—` | — | permission-denied | n/a |

## Motion

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `spring.global.sheetPresent`<br>`duration.global.sheetPresent` | response: 0.347; dampingFraction: 1 (SOURCED)<br>567 ms (SOURCED) | sheets | native sheets |
| matched | `duration.global.stripInsert`<br>`easing.global.standard`<br>`duration.global.fade` | 250 ms (SOURCED)<br>x1: 0.4; y1: 0; x2: 0.2; y2: 1 (SOURCED)<br>150 ms (SOURCED) | photo added to / removed from the strip; reorder shifts | `dsAnimation(ComponentMotion.stripInsert, value: chosen)` + tile `.transition(.opacity)` |
| matched | `—` | — | drag | system drag preview follows the finger |
| matched | `duration.global.crossfade` | 100 ms (SOURCED) | message capsule label change | `ComponentMotion.crossfade` on the label |

## Haptics

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `haptic.global.select` | ios: selection; android: SEGMENT_FREQUENT_TICK (PLATFORM) | grid tile toggled | `.select` → `haptic.global.select` |
| approximated | `week.edit.haptic.dragStart`<br>`week.edit.haptic.dragAlign` | ios: system (drag-and-drop lift plays its own feedback; no custom generator); android: DRAG_START (API 34+; none below) (PLATFORM)<br>ios: sensoryFeedback(.alignment) (iOS 17); android: SEGMENT_FREQUENT_TICK (API 34+; CLOCK_TICK below) (PLATFORM) | drag start / slot change | slot change: `sensoryFeedback(.alignment)` (`dragAlign`); drag start: the system's drag-lift feedback (no hook in SwiftUI's `draggable`) |
| matched | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | saved | `.success` |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | save failed | `.failed` |
| matched | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | tap a capsule (Android) | none on iOS |

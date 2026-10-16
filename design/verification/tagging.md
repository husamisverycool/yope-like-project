# Verification — `tagging` (iOS)

The self-tag run in the viewer footer ('I'm in this' / 'with {names}') and the 'In this photo' sheet — `ios/App/Sources/Features/Memory/Tagging/ (TagRun, TagRunModel)`.

Pass 4 (Retro redesign). Checklist written from the spec (`design/surfaces/tagging.md`, MERGE "Redesign — Memory (RM-*)", lead L-4 / L-5) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/memory/<surface>-<state>-<light|dark>.png` (`ios/AppTests/Memory/MemorySnapshotTests.swift`: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/tagging.png` next to the Retro reference(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level). Components are the Pass 3 library (`ios/App/Sources/Components`, C-01…C-35).

Retro reference(s): `references/auto/retro/press/tc-2023-07-retro-2b.jpg phone 2 (footer)`, `references/auto/retro/press/tc-2023-07-retro-1b.webp phone 2 (people rows)`

Snapshots (CI): `tagging-run-untagged-light.png`, `tagging-run-untagged-dark.png`, `tagging-run-tagged-light.png`, `tagging-run-tagged-dark.png`, `tagging-run-truncated-light.png`, `tagging-run-pending-light.png`, `tagging-sheet-tagged-light.png`, `tagging-sheet-tagged-dark.png`, `tagging-sheet-not-tagged-light.png`, `tagging-sheet-empty-light.png`

**Summary: 13 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Footer run (A)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `tagging.toggle`<br>`fontSize.global.listSubtitle`<br>`color.global.textOnMedia` | “I'm in this” (SOURCED)<br>15 pt (SOURCED)<br>#FFFFFF (SOURCED) | nobody tagged: 'I'm in this' in white after ' · ' | `TagRun` / `TagRunLine` (the date in `color.global.textSecondary`, Retro's separator) |
| matched | `tagging.with`<br>`color.global.textSecondary`<br>`fontWeight.global.listTitle` | “with {names}” (SOURCED)<br>#999999 (SOURCED)<br>semibold (SOURCED) | someone tagged: 'with {names}' grey, names semibold, platform list formatter, one line, tail-truncated, never a count | Text runs with `.fontWeight` per name; `ListFormatter` |
| matched | `size.global.minTouchTarget.ios`<br>`tagging.a11y.people` | 44 pt (VERIFIED)<br>“People in this photo” (PLATFORM) | one button ≥ 44; VoiceOver label / value, selected when you are tagged | accessibilityElement(children: .ignore) |
| matched | `duration.global.crossfade` | 100 ms (SOURCED) | text change cross-fades | `ComponentMotion.crossfade` |

## 'In this photo' sheet (B)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `tagging.sheet.title`<br>`fontSize.global.sheetTitle`<br>`size.global.circleButton`<br>`color.global.control`<br>`icon.global.close` | “In this photo” (SOURCED)<br>17 pt (SOURCED)<br>36 pt (SOURCED)<br>light: #F1F1F1; dark: #262626 (SOURCED)<br>ios: xmark; android: Rounded.Close (PLATFORM) | C-29 page sheet (medium detent, follows the appearance), title + close circle on the page | C-29 `SheetHeader`; close labelled `photo.viewer.a11y.close` (no tagging key) |
| matched | `size.global.avatarPicker`<br>`fontSize.global.listTitle`<br>`size.global.screenMargin` | 37 pt (SOURCED)<br>15 pt (SOURCED)<br>16 pt (SOURCED) | people rows | C-16 `PeopleRow` |
| matched | `tagging.remove`<br>`size.global.pillHeight`<br>`radius.global.capsule`<br>`fontSize.global.pill` | “Remove tag” (SOURCED)<br>37 pt (SOURCED)<br>shape: capsule; radius: height / 2 (SOURCED)<br>15 pt (SOURCED) | your row: outline 'Remove tag' | C-06 `CapsuleButton(.outline)` |
| matched | `tagging.toggle`<br>`color.global.accent`<br>`color.global.onAccent`<br>`size.global.buttonHeight`<br>`size.global.buttonMarginH` | “I'm in this” (SOURCED)<br>light: #000000; dark: #FFFFFF (SOURCED)<br>light: #FFFFFF; dark: #000000 (SOURCED)<br>60 pt (SOURCED)<br>20 pt (SOURCED) | not tagged: C-05 'I'm in this' at the bottom | PrimaryButton (sheet height) |
| matched | `tagging.sheet.empty` | “No one is tagged” (SOURCED) | empty: C-27 title | EmptyStateView |
| matched | `duration.global.fade` | 150 ms (SOURCED) | rows appear / leave | fade |

## Behaviour

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `haptic.global.select`<br>`haptic.global.error` | ios: selection; android: SEGMENT_FREQUENT_TICK (PLATFORM)<br>ios: notification.error; android: REJECT (PLATFORM) | tag / untag applied: tick; failure: error | TagRunModel (optimistic, one call at a time, reverted on failure; unit-tested) |
| matched | `tagging.error`<br>`tagging.removeError`<br>`tagging.notFound`<br>`tagging.offline` | “Unable to add tag” (SOURCED)<br>“Unable to remove tag” (SOURCED)<br>“Couldn't find post” (SOURCED)<br>“Check your connection and try again.” (SOURCED) | failure lines; photo gone → the viewer closes it | C-26 announcement + `onMessage` / `onPostGone` for the host |
| matched | `—` | — (no token) | placement in the photo.viewer footer's second line | social's `PhotoViewerView` draws `TagRunLine(leadingText:run: TagRun(…))` after the date and presents `TaggingSheet` (medium detent); `TagRunControl` is the self-contained variant |

# `week.edit` — edit a recap; save its photos as a named album

Redesign on **Retro**: visual reference Retro's **composer sheet "Add to Your Week"** (screen 30 — native toolbar "Cancel /
title / Update", the selected photos as a strip on top, a grey "Photos taken since …" line, a 4-column grid) for choosing
and ordering the recap's photos; Retro's **"Add a Message" modal** (screen 18 — "Add a Message" / "Done", typed text,
"58/250" counter) for the recap text; Retro's **"New Album"** strings for the album sheet. Mechanics: reorder by touch and
hold + drag (Apple Photos / Google Photos, Gap fill G-16). Tokens: `design/tokens/social.json` (`week.edit.*`) +
`global.*`. Copy: `design/copy/social.json` (`week.edit.*`). Decisions: `design/MERGE_DECISIONS.md` → Redesign — Social
(RS-22).

## References

| id | file | used for |
|---|---|---|
| VID-COMP | `references/auto/retro/video/ig-DDbA_F7x-j7-composer-f130-147-f188-197.png` (frames, 640 × 800) | **primary**: sheet with Cancel / title / Update (system tint), selected strip with grey placeholders, "Photos taken since …", 4-column grid; tile shift 250 ms |
| VM | `references/auto/retro/video/retro-motion-measurements.txt` §C–D | sheet spring; a tile shifts one slot in ≈250 ms, a new tile fades in from scale ≤0.875 |
| TC-R3 | `references/auto/retro/press/tc-2023-12-retro3.png` phones 2–3 | "Add Message" pill (`icon.global.edit` + label); "Add a Message" modal with "Done" and counter |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | "Update", "Add a message", "Edit message", "Add a Message", "Add a message…", "Done", "New Album", "Name your album", "Create Album", "Yes, go back", "Name missing", "Saved!", "Added to Album!" |
| AP / GP | `references/auto/apple-photos/apple-support/page-filter-sort-albums.png`, `references/auto/google-photos/help/page-create-edit-albums-ios.png` | reorder gesture |

## Structure — editor (`week.edit.layout.composition`)

Page sheet (C-29, `radius.global.sheet`, `spring.global.sheetPresent`) on `color.global.background`, native toolbar: leading
`week.edit.cancel`, centred `week.edit.title` ("Edit Recap", system title), trailing `week.edit.save` ("Update") — toolbar
buttons in the system tint (`color.global.selection` / `color.global.system.primary`, C-08).

1. **Chosen photos strip** (C-17) at `size.global.screenMargin`: the recap's items in recap order as photo tiles (weekday
   labels), outer corners `radius.global.card`; scrolls sideways. Touch and hold a tile, drag it to a new place, release
   (`week.edit.layout.reorder`); the others shift with `duration.global.stripInsert`.
2. **Action row** (C-06, equal widths, `size.global.pillGap`), `size.global.sectionGap` below the strip: outline capsule with
   `icon.global.edit` (C-07 anatomy) + `week.edit.message.add` ("Add a message"; with text: `week.edit.message.edit`) →
   message sheet; outline capsule `week.edit.saveAsAlbum` → album sheet.
3. **Header line** `size.global.sectionGap` below: `week.edit.header` ("Photos taken in Week 27", text role `listSubtitle`,
   `color.global.textSecondary`) at the margin.
4. **Grid** `size.global.sectionHeaderToContent` below the line's baseline: every visible post of the recap's week in time
   order, `week.edit.count.gridColumns` columns of square cells, `size.global.stripGap` gaps, full width inside the margins,
   aspect fill. Each cell carries the in / out mark (`week.edit.layout.selectionMark`, **BLOCKED**). Tap toggles: a checked
   photo joins the strip's end (insert motion C-17); unchecking removes it from the strip.

### Message sheet (`week.edit.layout.message`)

Sheet (C-29) on `color.global.background`: centred `week.edit.message.title` ("Add a Message", text role `sheetTitle`),
trailing `week.edit.message.done` (C-08 text button, `textButton`, `color.global.textPrimary`); the text from
`size.global.screenMargin`, text role `placeholder` (typed `color.global.textPrimary`, placeholder `week.edit.textPlaceholder`
"Add a message…" in `color.global.textSecondary`), keyboard up; `week.edit.message.counter` ("58/2000", text role `body`,
monospaced digits, `color.global.textSecondary`) at the trailing margin above the keyboard. Limit 2000 characters
(`weekly_recaps.text`). "Done" keeps the text for the editor (saved with "Update").

### Album sheet (also opened from `week.recap` and the `week.history` week menu)

Sheet (C-29): C-11 close circle (`size.global.circleButton`, `color.global.control`) at the leading margin, centred
`week.edit.album.title` ("New Album", `sheetTitle`); `size.global.titleToContent` below, C-12 field (`size.global.fieldHeight`,
`radius.global.field`, `color.global.control`, placeholder `week.edit.album.namePlaceholder` "Name your album"); inline error
`week.edit.error.albumName` under the field (text role `meta`, `color.global.destructive`, C-12 error) when submitted empty;
C-05 primary capsule `week.edit.album.create` ("Create Album": `color.global.accent` / `color.global.onAccent`,
`size.global.buttonHeightSheet`, `size.global.buttonMarginHSheet`, `radius.global.button`, text role `button`) at the bottom
above the keyboard; disabled (`color.global.controlRaised`) while the name is empty. The album gets the selected photos in
their current order (from the editor: the strip; from `week.recap`: the recap's items; from `week.history`: that week's posts).

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| Cancel / Update | C-29 toolbar, C-08 (system tint) | `week.edit.cancel`, `week.edit.save` | Cancel with changes → confirmation below; Update → `update_recap` → Android Toast `week.edit.toast.saved` / iOS announcement, closes |
| title | system toolbar title | `week.edit.title` | — |
| strip tile | C-17 photo tile; `week.edit.layout.reorder`, `week.edit.haptic.dragStart` / `.dragAlign` | `week.history.a11y.tile`; actions "move earlier / later" (platform reorder) | drag reorders |
| message capsule | C-06 outline + `icon.global.edit` (C-07 anatomy) | `week.edit.message.add` / `.message.edit` | → message sheet |
| Save as Album capsule | C-06 outline | `week.edit.saveAsAlbum` | → album sheet |
| header line | text role `listSubtitle` | `week.edit.header` | — |
| grid cell | C-21 composer grid; `week.edit.count.gridColumns`, `size.global.stripGap`; mark `week.edit.layout.selectionMark` (BLOCKED) | `week.history.a11y.tile` + value `week.edit.a11y.inRecap` / `.a11y.notInRecap` | tap toggles |
| message sheet | C-29, C-08; `week.edit.layout.message` | `week.edit.message.title`, `.message.done`, `week.edit.textPlaceholder`, `week.edit.message.counter` | edits `text` |
| album sheet | C-29, C-11, C-12, C-05 | `week.edit.album.title`, `.album.namePlaceholder`, `.album.create`, `week.edit.error.albumName` | `save_album` → Android Toast `week.edit.toast.albumSaved` / iOS announcement |
| discard confirmation | C-29 alert | `week.edit.lostChanges.title`, `.lostChanges.message`, `.lostChanges.confirm`, cancel `photo.viewer.delete.cancel` | discards and closes |

## States

| state | what shows | components · tokens · copy | source |
|---|---|---|---|
| loading | strip and grid as C-17 placeholder tiles | C-28; `week.history.a11y.loading` | VID-COMP grey placeholders |
| saving | "Update" replaced by the platform activity indicator (C-05 busy rule, toolbar) | `easing.global.native.activityIndicator` | C-28 |
| not ready (`recap_not_ready`) | the editor does not open; the preview shows the pending line | `week.edit.error.notReady` | APK-S |
| empty selection | allowed (the API accepts an empty list); "Create Album" disabled until one photo and a name | `week.edit.error.albumName` | — |
| error (save failed) | the sheet stays; Android Toast / iOS alert with the message; selection kept | `week.edit.error.save`; `haptic.global.error` | APK-S |
| offline | saves fail as above | `week.edit.error.save` | — |
| permission-denied | not applicable | — | — |

## Motion

| transition | tokens | Reduce Motion |
|---|---|---|
| sheets | native (`spring.global.sheetPresent`, `duration.global.sheetPresent`) | system |
| photo added to / removed from the strip; reorder shifts | `duration.global.stripInsert` + `easing.global.standard`; new tile fades in (`duration.global.fade`) from scale ≤0.875 (VM §D) | cross-fade, no scale |
| drag | tracks the finger | allowed |
| message capsule label change | cross-fade `duration.global.crossfade` | same |

## Haptics

| interaction | token |
|---|---|
| grid tile toggled | `haptic.global.select` (Retro tick for a toggled selection) |
| drag start / slot change | `week.edit.haptic.dragStart` / `week.edit.haptic.dragAlign` |
| saved | `haptic.global.success` |
| save failed | `haptic.global.error` |
| tap a capsule (Android) | `haptic.global.tap` (iOS none) |

## Accessibility

- Grid cells: label `week.history.a11y.tile`, value `week.edit.a11y.inRecap` / `.a11y.notInRecap`, toggle trait. Strip
  tiles expose move-earlier / move-later actions (iOS `accessibilityDragPoint` + reorder actions; Android custom actions).
- The counter is read after the field ("58 of 2000" is the platform's reading of "58/2000").
- Dynamic Type: `listSubtitle`, `pill`, `placeholder`, `button` scale; tiles keep their size.
- Focus order: Cancel → title → Update → strip → message capsule → Save as Album → header line → grid.
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | light | dark | pair |
|---|---|---|---|---|---|
| `color.global.textPrimary` | `color.global.background` | text | 21.00:1 pass | 21.00:1 pass | capsule labels / borders, typed message |
| `color.global.textSecondary` | `color.global.background` | text | **2.85:1 FAIL** | 7.37:1 pass | header line, counter, placeholder (iOS) |
| `color.global.textSecondary` | `color.global.control` | text | **2.52:1 FAIL** | 5.31:1 pass | album-name placeholder |
| `color.global.onAccent` | `color.global.accent` | text | 21.00:1 pass | 21.00:1 pass | "Create Album" |
| `color.global.destructive` | `color.global.background` | text | **4.18:1 FAIL** | 5.03:1 pass | "Name missing" (13 pt) |

  Retro palette failures (design/CONTRAST.md); the disabled capsule is exempt. Toolbar buttons are system-drawn.

## Data & actions

- **Reads**: `weekly_recaps` (§5.14) row (`items`, `text`, `status`); `group_history_weeks` (§6.4) for the week's `post_ids`;
  `posts` / `media` thumbnails.
- **RPCs**: `update_recap(p_recap_id, p_items, p_text)` (§6.4: any member, `status = ready`; `p_text = ""` clears; errors
  `recap_not_found`, `recap_not_ready`, `invalid_items`, `invalid_text`); `save_album(p_group_id, p_name, p_post_ids)`
  (`invalid_name` 1–80 characters, `invalid_items`).
- **Navigation in**: `week.recap` (select-photos circle → editor; "Save as Album" → album sheet), `week.history` week menu
  (album sheet). **Out**: back to the opener; a saved album appears in `albums.list`.

## Platform notes

- iOS: `.sheet` with `.presentationDetents([.large])` and a `NavigationStack` toolbar (`.cancellationAction`,
  `.confirmationAction`); strip reorder with `.draggable` / `.dropDestination` or a custom long-press drag;
  `sensoryFeedback(.alignment)`.
- Android: `ModalBottomSheet(skipPartiallyExpanded = true)` with a top app bar row (text buttons in
  `color.global.system.primary`); drag in `LazyRow` with `HapticFeedbackConstants.DRAG_START` / `SEGMENT_FREQUENT_TICK`
  (API 34+).

## Do-not-copy

- Retro composer's camera-roll source switch ("Camera Roll ⌄", Favourites / Videos filters) — the grid is the week's posts.
- Recap collage tools (stickers, drawing, backgrounds, aspect ratios, "Recaps Pro") and "Max items reached" counts.
- Yope's lime / dark button pair and wall editor tools.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| `week.edit.layout.selectionMark` | **BLOCKED** (development approximation: check circle top-right, 6 pt in) | one raw screenshot of Retro's "Add to Your Week" with 2 photos selected |
| `week.edit.layout.recapText` (old BLOCKED) | closed: Retro's "Add a Message" modal (RS-22) | — |
| spacing between the strip, the action row and the grid | composition with `size.global.sectionGap` (VID-COMP is 640 × 800) | same raw screenshot |
| reorder inside Retro's composer strip | not observed (Retro adds / removes only); gesture from Apple / Google Photos | — |

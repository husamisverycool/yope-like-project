# `week.edit` — reorder, remove, edit text; save the recap or a selection as a named album

Reference app: **Yope** (`docs/SURFACES.md`). **No Yope edit UI was found** — only the release-note verbs "edit them, remix
them, make your own memory albums / save it or share it with your friends" (v1.214.0, yope-b §6). Per the brief this
screen is **built from documented Yope components** (S-13); everything those components cannot settle is BLOCKED with the
owner capture from yope-b §14 (capture 4). Tokens: `design/tokens/social.json` (`week.edit.*`, grid from `week.recap.*`) +
`global.*` + `groups.create.*` (field). Copy: `design/copy/social.json` (`week.edit.*`).

## References

| id | file | used for |
|---|---|---|
| W1 | `references/auto/yope/store/listing.html` (v1.214.0) | the verbs edit / save and the noun "memory albums" |
| V-ch | `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t6.73-sendto-voice-tooltip.png` | Yope sheet: ✕ circle + centred title + check circles + bottom lime "send" button |
| V-mthu | `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t45.23-new-group-empty.png`, `…-t49.23-new-group-selected-create.png` | "new group" sheet: title, name field "name group (optional)", check circles, lime "create group" |
| O3 | `references/owner/yope-week-recap.jpg` | the week's pics grid (3 columns, 1-pt gaps, 3:4) |
| S4-w | `references/auto/yope/frames/b-presskit-wall.png` | Yope's wall editor toolbar (photo, text, sticker, colour, cut-out, music, shuffle) — editing affordances of free-form walls; not built (do-not-build parts, BLOCKED canvas) |

## Structure

Full-height sheet over `week.recap` (Yope's "new group" / "send to..." sheets), background `color.global.backgroundDeep`.

1. **Header**: ✕ circle at the left (`size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.close`,
   `size.global.headerInset`); title `week.edit.title` ("edit recap") centred, text role `sheetTitle`, `color.global.textPrimary`.
2. **Photos grid** (scroll): every visible post of the recap's week — the recap's items first, in recap order, then the
   week's other posts in time order — in the week pics grid (`week.recap.count.picsColumns`, `week.recap.dimension.picsGap`,
   `week.recap.aspectRatio.picsTile`). Each tile carries Yope's selection circle (`size.global.checkCircle`):
   `icon.global.check` in `color.global.selection` = in the recap / in the selection; `icon.global.uncheck` in
   `color.global.textPrimary` = not. Circle position on a photo tile is not observed: top-right corner, inset
   `size.global.listGap` (approximation, Gaps). Tap toggles.
   **Reorder**: **BLOCKED** (`week.edit.layout.reorder`) — no Yope reorder gesture was observed. Approximation for
   development builds only: long-press a checked tile and drag it to a new place among the checked tiles, with
   `week.edit.haptic.dragStart` on pick-up and `week.edit.haptic.dragAlign` on each slot change.
3. **Recap text** (`weekly_recaps.text`, ≤ 2000): position **BLOCKED** (`week.edit.layout.recapText`) — approximation
   under the grid: multi-line field `groups.create.color.field`, `radius.global.field`, min height `size.global.fieldHeight`,
   side margin `size.global.buttonMarginH`, text role `body`, placeholder `week.edit.textPlaceholder` ("add a message") in
   `color.global.textSecondary`.
4. **Bottom actions** (pinned): lime primary button `week.edit.save` ("save") — `color.global.accent` /
   `color.global.onAccent`, `size.global.buttonHeightSheet`, side margins `size.global.buttonMarginHSheet`,
   `radius.global.button`, text role `button`; beside it on the left, Yope's dark secondary button `week.edit.saveAsAlbum`
   ("save as album") — the compact "more friends" + "send" pair of V-chuong t3.73 (`camera.sendto` tokens for the pair).

### Save as album (sheet over the editor)

Yope "new group" sheet form: ✕ circle + title `week.edit.album.title` ("new album", text role per `groups.create.fontSize.title`
/ `.fontWeight.title`), then the name field (`groups.create.color.field`, `radius.global.field`, `size.global.fieldHeight`,
text `groups.create.fontSize.fieldText` / `.fontWeight.fieldText`, placeholder `week.edit.album.namePlaceholder` "name album"),
then the lime button `week.edit.save` (`size.global.buttonHeight`, `size.global.buttonMarginH`), disabled while the name is
empty (`groups.create.color.buttonDisabledFill` / `.buttonDisabledLabel`). Spacing as `groups.create.size.titleToContent`
and `groups.create.size.fieldToButton`. The album gets the **checked** photos in their current order.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| ✕ circle | `size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.close` | `week.edit.a11y.close` | closes without saving |
| title | text role `sheetTitle`, `color.global.textPrimary` | `week.edit.title` | — |
| photo tile | week pics grid tokens; `size.global.checkCircle`, `icon.global.check` / `icon.global.uncheck`, `color.global.selection` | `photo.viewer.a11y.photo` + value `week.edit.a11y.inRecap` / `.notInRecap` | tap toggles; reorder BLOCKED |
| recap text field | `groups.create.color.field`, `radius.global.field`, `size.global.fieldHeight`; position BLOCKED | `week.edit.textPlaceholder` | edits `text` |
| save | primary button tokens above | `week.edit.save` | `update_recap(p_recap_id, p_items: checked ids in order, p_text)` → toast `week.edit.toast.saved`, closes |
| save as album | dark secondary button (`camera.sendto` pair tokens) | `week.edit.saveAsAlbum` | opens the album sheet |
| album name field | `groups.create.*` field tokens | `week.edit.album.namePlaceholder` | trimmed, 1–80 characters (API) |
| album save | lime button, disabled state | `week.edit.save` | `save_album(p_group_id, p_name, p_post_ids: checked ids in order)` → toast `week.edit.toast.albumSaved` |
| toast | `camera.sendto.layout.toast`, dwell BLOCKED | `week.edit.toast.saved`, `.toast.albumSaved` | — |

## States

| state | what shows | tokens / copy | source |
|---|---|---|---|
| loading | Loading HUD while the week's posts load / while saving | `groups.create.size.hud`, `.color.hud`, `.fontSize.hudLabel`; `groups.create.hud.loading` | yope-a §1.8 |
| not ready (`recap_not_ready`) | the editor does not open; line in the recap screen | `week.edit.error.notReady` | docs/API.md §3 |
| empty selection | "save" stays enabled (a recap may have no items? the API allows an empty list) — album save disabled until one photo is checked and a name is typed | `week.edit.error.albumName` when the name is empty on submit | `yope.voice.error` |
| error (save failed) | toast-free inline line above the buttons; selection kept | `week.edit.error.save`; `haptic.global.error` | `yope.voice.error` |
| offline | save fails as above | `week.edit.error.save` | — |
| permission-denied | not applicable | — | — |

## Motion

| transition | tokens | Reduce Motion |
|---|---|---|
| sheet in / out | Yope sheet: `duration.global.sheetPresent`, `spring.global.sheetPresentObserved` (spring itself BLOCKED, `spring.global.sheetPresent`) → native sheet (`easing.global.native.sheet`) until captured | system |
| check toggle | none observed | — |
| reorder drag | BLOCKED with the gesture | drag tracks the finger (allowed) |

## Haptics

| interaction | token |
|---|---|
| tile checked / unchecked | `haptic.global.select` |
| drag start / slot change (reorder, BLOCKED gesture) | `week.edit.haptic.dragStart` / `week.edit.haptic.dragAlign` |
| saved | `haptic.global.success` |
| save failed | `haptic.global.error` |

## Accessibility

- Tiles: label `photo.viewer.a11y.photo`, value `week.edit.a11y.inRecap` / `.notInRecap`, trait button (toggle). Reorder
  exposed as accessibility custom actions "move earlier / move later" once the gesture is captured.
- Dynamic Type: title → `layout.global.textStyleMap.sheetTitle`; field → `.body`; buttons → `.button`.
- Focus order: ✕ → title → tiles → text field → save as album → save.
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | ratio | result | pair |
|---|---|---|---|---|---|
| `color.global.selection` #0091FF | `color.global.background` #171717 | nontext | 5.54:1 | pass | filled check circle (on photos the backdrop varies) |
| `color.global.onAccent` #000000 | `color.global.accent` #CDFD07 | text | 17.65:1 | pass | 'save' on the lime button |

  Field fill / placeholder pairs: as `groups.create.md` (account group).

## Data & actions

- **Reads**: `weekly_recaps` (§5.14) row; `group_history_weeks` (§6.4) for the week's `post_ids`; `posts` / `media` thumbnails.
- **RPCs**: `update_recap(p_recap_id, p_items, p_text)` (§6.4: any member, `status = ready`; drop ids to remove, re-add
  any post of that week; `p_text = ""` clears; errors `recap_not_found`, `recap_not_ready`, `invalid_items`, `invalid_text`);
  `save_album(p_group_id, p_name, p_post_ids)` (`invalid_name`, `invalid_items`).
- **Navigation in**: pencil circle on `week.recap`; "Save as album" in the `week.history` week menu (opens straight on the
  album sheet with that week's photos checked). **Out**: back to `week.recap`; after an album save, `albums.view` of the new
  album is reachable from `albums.list`.

## Platform notes

- iOS: `.sheet` with `.presentationDetents([.large])`; grid reorder (when captured) via `.draggable` / `.dropDestination`;
  `sensoryFeedback(.alignment, …)`.
- Android: `ModalBottomSheet(skipPartiallyExpanded = true)`; drag in `LazyVerticalGrid` with
  `HapticFeedbackConstants.DRAG_START` / `SEGMENT_TICK` (API 34; fall back to no haptic below).

## Do-not-copy

- Yope's wall-editor tools that belong to do-not-build features: stickers, cut-outs, music, colour-dot decorations.
- "remix" / shuffle of a free-form canvas (the canvas itself is BLOCKED).

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| `week.edit.layout.reorder` | BLOCKED (dev-only approximation above) | 20-s recording: open a Yope weekly recap, swipe pages, toggle recap/pics, tap edit/remix, save (yope-b §14 capture 4) |
| `week.edit.layout.recapText` | BLOCKED | same recording |
| whole-screen composition | built from Yope components (S-13) | same recording |
| check-circle inset on tiles | approximation `size.global.listGap` | same recording |
| unsaved-changes prompt on ✕ | not observed: none | same recording |

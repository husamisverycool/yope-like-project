# `birthday.contribute` — pick a photo, add one line, send

Visual reference: **Retro screens 30, 17 and 18** (docs/SURFACES.md): the "Add to Your Week" composer sheet (native
toolbar Cancel / title / action, grey line, 4-column grid — components C-29, C-21), the dark **postcard composer**
(sheet title + close circle, rounded photo with the glass "Add a message" pill, 60-pt capsule —
`references/auto/retro/store/retro-store-03.png`) and the **"Add a Message"** modal (title + "Done", free text,
counter "58/250" — `references/auto/retro/press/tc-2023-12-retro3.png` phone 3). Retro has no birthday video, so the
flow is these Retro screens in Tribute / VidDay's order (choose a photo → write a line → send). Voice: Retro set +
`P-BC-1`, `P-BC-2`. Tokens: `design/tokens/memory.json` (`*.birthday.contribute.*`) + global. Copy:
`design/copy/memory.json` (`birthday.contribute.*`). Decisions: `design/MERGE_DECISIONS.md` → "Redesign — Memory
(RM-*)".

Rule from the product spec: a contributor can only pick a photo **they posted, or are self-tagged in** (`tagging`),
from the group of the request. One contribution per person; sending again replaces it until the due time.

## References

| image / source | what it verifies |
|---|---|
| `references/auto/retro/video/ig-DDbA_F7x-j7-composer-f130-147-f188-197.png` (VID-COMP) | composer sheet: Cancel / title / Update, grey line, 4-column square grid with ≈2-pt gaps |
| `references/auto/retro/store/retro-store-03.png` (ST-03, 2.389 px/pt) | dark sheet: 'Postcard' 17 semibold centred + close 36 circle #262626; title baseline → photo 32.6 pt; photo 297.4 × 422.8 box, r 8.5, centred; 'Add a message' pill (C-09 glass) 20.9 above the photo bottom; 60-pt white capsule at 20 pt margins |
| `references/auto/retro/press/tc-2023-12-retro3.png` phone 3 (1.595 px/pt) | 'Add a Message' (17 semibold) + 'Done' (17 regular, 20.7 from the edge); text 21.9 from the edge; counter '58/250' bottom-right, 20.7 from the edge, 18.5 above the keyboard; light appearance |
| Retro strings `postcard_composer_message_cta_add` / `_edit`, `postcard_composer_add_message_*`, `composer_header_template_current_week` | words |

## Structure

A page sheet (C-29) opened from `birthday.request` ("Add your photo" / "Change photo"), holding a navigation stack of
two steps; a toast confirms at the end.

**Step 1 — Choose a photo** (sheet follows the appearance; page `color.global.background` /
`color.global.background.android`):
1. Native sheet toolbar: leading `birthday.contribute.picker.cancel` ("Cancel"), centred title
   `birthday.contribute.picker.title` ("Choose a Photo", text role `sheetTitle`), trailing
   `birthday.contribute.picker.next` ("Next"), system tint (C-08 / C-29), disabled until a photo is chosen.
2. Grey line `birthday.contribute.picker.subtitle` ("Photos you posted or are in"), text role `body`,
   `color.global.textSecondary` (Android `.textSecondary.android`), leading at `size.global.screenMargin`.
3. **Grid** (C-21 composer picker grid): 4 columns, square cells, `size.global.stripGap` gaps,
   `radius.global.photo`, full width; the group's posts where `author_id` = you, plus posts with your `post_tags` row,
   newest first, deduplicated; thumbnails (`thumb_path`). Tap selects one photo (single choice): the cell shows the
   check `icon.global.check` in `color.global.selection` at `size.global.checkCircle` in its top-right corner, inset
   `size.global.badgeInset` (where Retro places a marker on a photo, C-24; C-17's selection mark is not captured, so
   the platform picker's filled check is used: PLATFORM); unselected cells show nothing. Opened from "Change photo", your current photo starts selected.
4. Next → step 2.

**Step 2 — Add a message** (dark media composer in both appearances, `layout.global.appearance.media`; page
`color.global.backgroundDeep`):
1. Sheet header (C-29): centred title `birthday.contribute.composer.title` ("Birthday Video"), text role
   `sheetTitle`, `color.global.textOnMedia`; leading native back (to step 1); trailing close circle on media (C-11:
   `size.global.circleButton`, `color.global.controlOnDeep`, `icon.global.close`, `color.global.textOnMedia`) →
   dismisses the whole sheet.
2. **Photo** `dimension.birthday.contribute.titleToPhoto` below the title's baseline: the chosen photo fitted (own
   aspect) inside a `dimension.birthday.contribute.photoWidth` × `dimension.birthday.contribute.photoMaxHeight` box,
   centred, corners `radius.birthday.contribute.photo`.
3. **Pill** (C-09 glass variant) on the photo, centred, bottom `dimension.birthday.contribute.pillBottom` above the
   photo's bottom: `icon.global.edit` + `birthday.contribute.message.add` ("Add a message") — or, once there is a line,
   `birthday.contribute.message.edit` ("Edit message"); fill `color.global.controlOnDeep`, label text role `pill`,
   `color.global.textOnMedia`, `size.global.pillHeight`. Opens the modal (step 2a).
4. When a line exists: the line under the photo, `size.global.listGap` below it, text role `body`,
   `color.global.textOnMedia`, centred, side margins `size.global.buttonMarginH`.
5. Pinned to the bottom: primary capsule (C-05 on media: `color.global.surfaceLight` / `color.global.onSurfaceLight`,
   `size.global.buttonHeight`, `size.global.buttonMarginH`, `radius.global.button`, text role `button`)
   `birthday.contribute.submit` ("Add to video"); disabled (C-05 disabled, `color.global.controlRaised` with
   `color.global.onAccent` — Retro's captured dark disabled capsule) until the line has a non-space character.

**Step 2a — "Add a Message" modal** (C-29 page sheet over the composer, follows the appearance):
1. Header: centred title `birthday.contribute.message.title` ("Add a Message", text role `sheetTitle`); trailing
   app-drawn text button (C-08) `birthday.contribute.message.done` ("Done", text role `textButton`,
   `color.global.textPrimary`) at `dimension.birthday.contribute.counterInset` from the edge.
2. Free text, insets `dimension.birthday.contribute.messageInset`: text role `placeholder` (17), typed text
   `color.global.textPrimary`, placeholder `birthday.contribute.message.placeholder` ("Add a message…") in
   `color.global.textSecondary`; no field fill (Retro's modal is the page). Keyboard up on open.
3. Counter bottom-right: `birthday.contribute.message.counter` ("{count}/{max}", `{max}` =
   `layout.birthday.contribute.lineMax` 110), text role `placeholder`, monospaced digits, `color.global.textSecondary`,
   right ink `dimension.birthday.contribute.counterInset` from the edge, baseline
   `dimension.birthday.contribute.counterAboveKeyboard` above the keyboard. Input stops at 110 characters.
4. Done → back to the composer with the line.

**Sent:** "Add to video" calls `contribute_tribute`; on success the sheet closes, toast
`birthday.contribute.done.title` ("Added to video!") (C-26), and `birthday.request` shows your contribution.

## Elements

| element | component · tokens | copy keys | behaviour |
|---|---|---|---|
| toolbar | C-29 / C-08 native toolbar | `birthday.contribute.picker.cancel`, `.picker.title`, `.picker.next` | Cancel dismisses |
| grey line | text role `body`, `color.global.textSecondary` | `birthday.contribute.picker.subtitle` | — |
| grid | C-21: 4 columns, `size.global.stripGap`, `radius.global.photo`; check `icon.global.check`, `color.global.selection`, `size.global.checkCircle` | `birthday.contribute.a11y.photo` | single selection |
| composer header | C-29 sheet header on media, C-11 on media | `birthday.contribute.composer.title`, `birthday.contribute.a11y.close` | close dismisses the sheet |
| photo | `dimension.birthday.contribute.titleToPhoto`, `.photoWidth`, `.photoMaxHeight`, `radius.birthday.contribute.photo` | — | display rendition |
| message pill | C-09 glass: `color.global.controlOnDeep`, `icon.global.edit`, text role `pill`, `color.global.textOnMedia`, `size.global.pillHeight`, `dimension.birthday.contribute.pillBottom` | `birthday.contribute.message.add` / `.message.edit` | opens 2a |
| line preview | text role `body`, `color.global.textOnMedia`, `size.global.listGap` | — (the user's line) | — |
| Add to video | C-05 on media | `birthday.contribute.submit` | `contribute_tribute` |
| modal | C-29 page sheet, C-08 | `birthday.contribute.message.title`, `.message.done`, `.message.placeholder` | — |
| counter | text role `placeholder`, monospaced digits, `color.global.textSecondary`, `dimension.birthday.contribute.counterInset`, `.counterAboveKeyboard`, `layout.birthday.contribute.lineMax` | `birthday.contribute.message.counter` | live |
| toast | C-26 | `birthday.contribute.done.title` | after success |

## States

| state | design (components) | copy | source |
|---|---|---|---|
| loading (grid) | C-17 placeholder tiles in the grid cells (`color.global.control`) | `birthday.contribute.loading` (announcement) | C-28 |
| empty (no eligible photos) | C-27 empty block in the sheet: title `emptyTitle`, detail `emptyDetail`, outline CTA (C-07 without glyph / C-06 outline) | `birthday.contribute.picker.empty.title`, `.empty.detail`, `.empty.action` (→ `groups.screen` of that group) | `retro.voice.empty-state` |
| sending | the capsule shows the platform activity indicator in its label colour (C-05 busy) | — | C-05 |
| not eligible (`post_not_eligible`) | inline line under the photo (text role `meta`, `color.global.destructive`); back to step 1 | `birthday.contribute.notEligible` | `retro.voice.error` |
| closed (`tribute_closed`) | C-27 block replaces the step content | `birthday.contribute.closed` | never "late" |
| error | C-27 error variant under the photo: title `emptyTitle`, detail `emptyDetail`; the capsule stays as retry | `birthday.contribute.error.title`, `.error.detail`, `.error.retry` | `retro.voice.error` |
| offline | inline line under the photo (`meta`, `color.global.textSecondary`) | `birthday.contribute.offline` | `retro.voice.error` |
| permission-denied | n/a (photos come from the group, not the photo library) | — | — |

## Motion

Sheet and modal: native (`spring.global.sheetPresent`, `duration.global.sheetPresent`); step 1 → 2: native push.
Selection check appears: fade `duration.global.fade`. Pill label change: crossfade `duration.global.crossfade`. Reduce
Motion: `layout.global.reduceMotion`.

## Haptics

Photo selected → `haptic.global.select`. Next, pill, Done, capsule → `haptic.global.tap` (Android). Sent →
`haptic.global.send`. Failed → `haptic.global.error`.

## Accessibility

- Grid cells: `birthday.contribute.a11y.photo` ("Photo from {date}") with the selected trait; the grid is a list.
  Pill, capsule, Done, Next: visible text. Close `birthday.contribute.a11y.close`. Message field: label
  `birthday.contribute.message.title`, value = the text; the counter is its hint ("12/110").
- Dynamic Type: `sheetTitle` → headline, `body` → subheadline, `placeholder` → body, `pill` → subheadline, `button`
  → headline.
- Focus order: Cancel → title → Next → line → grid (step 1); back → title → close → photo → pill → line → capsule (step
  2); title → Done → field → counter (2a).
- Contrast (`node tools/contrast.mjs`):

  | pair | ratio | needs | result |
  |---|---|---|---|
  | step 1 / 2a text `color.global.textPrimary` on `color.global.background` | light 21.00 · dark 21.00 | 4.5 | pass |
  | grey line / placeholder / counter `color.global.textSecondary` on `color.global.background` | light 2.85 · dark 7.37 | 4.5 | **FAIL in light** (reported; C-12 failure 1) |
  | check `color.global.selection` on white / over photos | 3.52 / 3.23; photo-dependent | 3 | pass on white; over photos not guaranteed |
  | step 2 `color.global.textOnMedia` on `color.global.backgroundDeep` | 21.00 | 4.5 | pass |
  | pill label on `color.global.controlOnDeep` | 15.13 | 4.5 | pass |
  | capsule label `color.global.onSurfaceLight` on `color.global.surfaceLight` | 21.00 | 4.5 | pass |
  | close fill `color.global.controlOnDeep` vs black page | 1.39 | 3 | **FAIL** (non-text; glyph identifies it) |

## Data & actions

- **Read:** the request (`tribute_requests` by id), the group's name; eligible posts:
  `from("posts").select().eq("group_id", g).eq("author_id", uid)` ∪ posts whose ids come from
  `from("post_tags").select("post_id").eq("group_id", g).eq("user_id", uid)`; `media` renditions; own contribution (to
  preselect on "Change photo").
- **Write:** `rpc("contribute_tribute", p_request_id, p_post_id, p_line)` → `tribute_contributions`. Errors:
  `request_not_found`, `tribute_closed`, `post_not_found`, `post_not_eligible`, `invalid_line`.
- **Realtime:** `group:<group_id>` `post_deleted` → drop the cell; if it was the chosen photo, back to step 1.
- **Navigation in:** `birthday.request`. **Out:** sent / Cancel / close → `birthday.request`; empty-state action →
  `groups.screen`.

## Platform notes

- iOS: `.sheet` with a `NavigationStack` (step 1 light / dark by appearance; step 2 `.environment(\.colorScheme,
  .dark)`); grid `LazyVGrid` 4 flexible columns; modal `.sheet` with a `TextField(axis: .vertical)` without
  background; counter `.monospacedDigit()`.
- Android: `ModalBottomSheet` (skipPartiallyExpanded) hosting a nested nav graph; `LazyVerticalGrid(GridCells.Fixed(4))`;
  modal = full-height sheet with `BasicTextField`; counter `FontFeatureSettings "tnum"`.
- The line is trimmed before sending; emoji allowed (the worker renders with Roboto: colour emoji show as missing glyphs
  in the video — worker hand-off, MERGE RM-12).

## Do-not-copy

Tribute's "Info" step (name / email), its pre-ticked offers box and stepper; video recording; uploading from the camera
roll; "Submit Another"; seeing anyone else's contribution; Retro's postcard stamp, mailing address, price rows and
"Send Postcard".

## Gaps

| item | status | smallest capture that closes it |
|---|---|---|
| selection mark in Retro's composer grid | platform check used (C-17 gap) | 1 RAW screenshot of "Add to Your Week" with 2 photos selected |
| composer / modal values from renders (2023, ±3 %) | SOURCED, render | 1 RAW screenshot each of the postcard composer and the "Add a Message" modal |
| real Tribute / VidDay step 2–3 screens | not observed | research capture 4 |

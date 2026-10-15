# `birthday.contribute` — pick a photo, write one line, send

Reference: **Tribute / VidDay** (docs/SURFACES.md). Geometry, colours and type from Tribute's live upload flow step 1
(VERIFIED computed styles); step sequence and words from Tribute's and VidDay's help centres. Voice: `P-BC-1`,
`P-BC-2`, `P-BC-3`; states use the app default voice. Tokens: `design/tokens/memory.json`
(`*.birthday.contribute.*`, `font.birthday`). Copy: `design/copy/memory.json` (`birthday.contribute.*`).

Rule from the product spec: a contributor can only pick a photo **they posted, or are self-tagged in**
(`tagging`), from the group of the request. One contribution per person; sending again replaces it until the due
time. No face recognition.

## References

| image / source | what it verifies |
|---|---|
| `references/auto/tribute/web/tribute-web-testimonials-upload-step1-info.png` + `tribute-web-testimonials-upload-step1.computed-styles.json` | stepper (40 circles at x31/127/223/319; active #B8B9B9 + white 14/600; others white 0.22 + white 0.55; captions 10 px, 10 below); heading 20/500 centred; sub-heading 16/400 white 0.72; label 16/600; field 350 × 46 r8 white 0.08, text 16/400; button 350 × 50 r8 16/600; margin 20 |
| https://www.tribute.co/help/creators/how-do-i-upload-a-video/ | Record → watch back → "Retake" → "Submit" → "Video Upload Complete!" |
| https://help.vidday.com/how-to-record-a-video-with-a-phone/ | "Retake", "Use Video", confirmation page |
| `references/auto/vidday/frames/vidday-tour-t102-phone.png` | "Let's add media!" greeting |

## Structure

Full screen on `color.global.backgroundDeep`, side margin `dimension.birthday.contribute.margin`, pushed from
`birthday.request`. Header: back / close circle (`size.global.headerButton`, `size.global.headerInset`,
`color.global.controlOnDeep`, `icon.global.back` on step 2, `icon.global.close` on steps 1 and 3).

**Stepper** (all steps), below the header (`layout.birthday.contribute.stepper`): three circles
`dimension.birthday.contribute.stepper.circle`, the first and last 11 pt inside the margins, the middle one centred;
number `fontSize/fontWeight.birthday.contribute.stepper.number`; caption 10 pt below
(`fontSize.birthday.contribute.stepper.label`) — `birthday.contribute.step.photo`, `.message`, `.done`. Current step:
fill `color.birthday.contribute.stepper.active`, number and caption `color.global.textPrimary`, caption weight
`fontWeight.birthday.contribute.stepper.labelActive`. Other steps: fill `color.birthday.contribute.stepper.inactive`,
number and caption `color.birthday.contribute.stepper.inactiveLabel`, caption weight
`fontWeight.birthday.contribute.stepper.label`. Done steps look like other steps (Tribute shows no done style).

**Step 1 — Photo.**
1. `dimension.birthday.contribute.heading.gap` below the captions: heading `birthday.contribute.greeting`, centred,
   `fontSize/fontWeight.birthday.contribute.heading`, `color.global.textPrimary`.
2. `dimension.birthday.contribute.subheading.gap` below: `birthday.contribute.thanks`, centred,
   `fontSize.birthday.contribute.subheading`, white at `opacity.birthday.contribute.subheading`.
3. `dimension.birthday.contribute.group.gap` below: the **eligible photos grid** — the group's posts where
   `author_id` = you, plus posts with your `post_tags` row, newest first, deduplicated. Grid component of the Yope
   wall (`walls.mine` spec: columns, gutter, `radius.global.photo`) with the global selection check
   (`icon.global.uncheck` / `icon.global.check`, `color.global.selection`, `size.global.checkCircle`) in the cell's
   top-right corner. Tap selects one photo (single choice; tapping another moves the check).
4. Pinned to the bottom (safe area + `dimension.birthday.contribute.margin`): primary **Use Photo**
   (`birthday.contribute.review.use`, VidDay's confirm after choosing) — same style as Submit below; enabled once a
   photo is selected → step 2. Opened from "Retake" on the request, the member's current photo starts selected.

**Step 2 — Message.**
1. The chosen photo, content width, aspect preserved, `radius.global.photo`.
2. `dimension.birthday.contribute.group.gap` below: label `birthday.contribute.line.label`
   (`fontSize/fontWeight.birthday.contribute.label`, `color.global.textPrimary`); `dimension.birthday.contribute.label.gap`
   below it the one-line field: `dimension.birthday.contribute.input.height`, `radius.birthday.contribute.input`, fill
   `color.birthday.contribute.input.fill`, text `fontSize.birthday.contribute.input`,
   `color.birthday.contribute.input.text`, horizontal padding = `dimension.birthday.contribute.label.gap`. No
   placeholder (not found). Grows to more lines when the text wraps. Character limit: 110
   (`layout.birthday.contribute.lineMax`, VidDay's text-card limit; the API bound 280 stays the server check), no visible counter.
3. `dimension.birthday.contribute.group.gap` below: **Message Ideas** exactly as in `birthday.request` (header bar +
   the two prompts) — helps write the line.
4. `dimension.birthday.contribute.button.gap` below: primary **Submit** — full content width,
   `dimension.birthday.contribute.button.height`, `radius.birthday.contribute.button`, fill `color.global.accent`,
   label `birthday.contribute.submit` in `fontSize/fontWeight.birthday.contribute.button`, `color.global.onAccent`;
   disabled (opacity of the platform disabled state) until the line has a non-space character.
5. `dimension.birthday.contribute.group.gap` below: secondary **Retake** (`birthday.contribute.review.retake`) — same
   size, fill `color.global.surfaceLight`, label `color.global.onSurfaceLight` → back to step 1 (selection kept).

**Step 3 — Done.**
1. Heading `birthday.contribute.done.title` (same role as the step 1 heading), centred.
2. The chosen photo thumbnail and the line (`fontSize.birthday.request.message`, `color.global.textPrimary`).
3. Primary button `birthday.contribute.done.button` (same as Submit) → back to `birthday.request`, which now shows the
   member's own block.

## Elements

| element | tokens | copy keys | behaviour |
|---|---|---|---|
| stepper | `layout.birthday.contribute.stepper`, `dimension.birthday.contribute.stepper.circle`, `color.birthday.contribute.stepper.active` / `.inactive` / `.inactiveLabel`, `fontSize/fontWeight.birthday.contribute.stepper.number`, `fontSize.birthday.contribute.stepper.label`, `fontWeight.birthday.contribute.stepper.labelActive` / `.label`, `color.global.textPrimary` | `birthday.contribute.step.photo`, `.message`, `.done` | not tappable |
| heading / thanks | `fontSize/fontWeight.birthday.contribute.heading`, `dimension.birthday.contribute.heading.gap`, `fontSize.birthday.contribute.subheading`, `opacity.birthday.contribute.subheading`, `dimension.birthday.contribute.subheading.gap` | `birthday.contribute.greeting` (`{name}`), `birthday.contribute.thanks`, `birthday.contribute.done.title` | thanks only on step 1 |
| photo grid + Use Photo | Yope wall grid (`walls.mine`), `radius.global.photo`, `icon.global.check` / `.uncheck`, `color.global.selection`, `size.global.checkCircle`; button as Submit | `birthday.contribute.a11y.photo`, `birthday.contribute.review.use` | single selection; thumbnails `thumb_path` |
| line field | `fontSize/fontWeight.birthday.contribute.label`, `dimension.birthday.contribute.label.gap`, `dimension.birthday.contribute.input.height`, `radius.birthday.contribute.input`, `color.birthday.contribute.input.fill` / `.text`, `fontSize.birthday.contribute.input`, `layout.birthday.contribute.lineMax` (110) | `birthday.contribute.line.label` | trimmed before sending |
| Message Ideas | as `birthday.request` | `birthday.request.prompts.title`, `birthday.request.prompt.*` | — |
| Submit / Done | `dimension.birthday.contribute.button.height` / `.gap`, `radius.birthday.contribute.button`, `fontSize/fontWeight.birthday.contribute.button`, `color.global.accent`, `color.global.onAccent` | `birthday.contribute.submit`, `birthday.contribute.done.button`, `birthday.contribute.review.use` | Submit → `contribute_tribute` |
| Retake | same size, `color.global.surfaceLight`, `color.global.onSurfaceLight` | `birthday.contribute.review.retake` | back to step 1 |

## States

| state | design | copy | source |
|---|---|---|---|
| loading (grid) | platform activity indicator centred under the thanks line | `birthday.contribute.loading` | Yope HUD word |
| empty (no eligible photos) | Yope empty state under the thanks line: text roles `emptyTitle` / `emptyDetail`, light pill (`color.global.surfaceLight`, `color.global.onSurfaceLight`, `radius.global.capsule`) | `birthday.contribute.picker.empty.title` (`{group}`), `.detail`, `.action` (→ `groups.screen` of that group) | `yope.voice.empty-state` |
| sending | Submit shows the platform activity indicator in place of its label | — | PLATFORM |
| not eligible (`post_not_eligible`) | inline under the field, `fontSize.global.listSubtitle`, `color.global.textSecondary`; back to step 1 | `birthday.contribute.notEligible` | app voice |
| closed (`tribute_closed`) | replaces the step content (text roles `emptyTitle` / `emptyDetail`) | `birthday.contribute.closed` (`{name}`) | app voice |
| error | inline under Submit + retry stays on Submit | `birthday.contribute.error.title`, `.detail`, `.retry` | app voice |
| offline | inline under Submit | `birthday.contribute.offline` | app voice |
| permission-denied | n/a (photos come from the group, not the photo library) | — | — |

## Motion

Native navigation push between steps (`easing.global.native`); `duration.global.navigationPush` where the platform
allows (MERGE F-11). Reduce Motion: `layout.global.reduceMotion`.

## Haptics

Photo selected → `haptic.global.select`. Submit succeeded → `haptic.global.send`. Failed → `haptic.global.error`.

## Accessibility

- Stepper: one element, label = the current step caption (e.g. "Message"), not interactive. Grid cells:
  `birthday.contribute.a11y.photo` ("Photo from {date}") with the selected trait. Field: label
  `birthday.contribute.line.label`. Close / back: `birthday.contribute.a11y.close` / the platform back label.
- Dynamic Type (`layout.birthday.contribute.textStyleMap`): heading `title3`, sub-heading / label / field / button
  `callout`, stepper number `subheadline`, stepper caption `caption2`.
- Focus order: close → stepper → heading → thanks → grid (or photo → label → field → Message Ideas → Submit → Retake).
- Contrast:

  | pair | ratio | needs | result |
  |---|---|---|---|
  | number white on `color.birthday.contribute.stepper.active` (14 pt semibold) | 1.97 | 4.5 | **FAIL** (reported; no sourced alternative) |
  | `color.birthday.contribute.stepper.inactiveLabel` on `.inactive` over black | 4.77 | 4.5 | pass |
  | caption `color.birthday.contribute.stepper.inactiveLabel` on black (10 pt) | 6.25 | 4.5 | pass |
  | `color.birthday.contribute.stepper.inactive` circle vs black | 1.79 | 3 | **FAIL** (non-text; reported) |
  | `color.birthday.contribute.stepper.active` circle vs black | 10.68 | 3 | pass |
  | sub-heading white 0.72 on black (#B8B8B8) | 10.59 | 4.5 | pass |
  | field text `color.birthday.contribute.input.text` on `.fill` over black | 12.82 | 4.5 | pass |
  | `color.birthday.contribute.input.fill` vs black (field boundary) | 1.14 | 3 | **FAIL** (non-text; the label above identifies the field — reported) |
  | `color.global.onAccent` on `color.global.accent` | 17.65 | 4.5 | pass |

## Data & actions

- **Read:** the request (`tribute_requests` by id), the group name; eligible posts:
  `from("posts").select().eq("group_id", g).eq("author_id", uid)` ∪ posts whose ids come from
  `from("post_tags").select("post_id").eq("group_id", g).eq("user_id", uid)`; `media` renditions; own contribution
  (to pre-select on "Retake" from the request).
- **Write:** `rpc("contribute_tribute", p_request_id, p_post_id, p_line)` → `tribute_contributions`. Errors:
  `request_not_found`, `tribute_closed`, `post_not_found`, `post_not_eligible`, `invalid_line`.
- **Realtime:** `group:<group_id>` `post_deleted` → drop the cell; if it was the chosen photo, back to step 1.
- **Navigation in:** `birthday.request` ("Add Your Photo" / "Retake"). **Out:** Done / close → `birthday.request`;
  empty-state action → `groups.screen`.

## Platform notes

- iOS: steps in the request sheet's `NavigationStack`; Android: nested navigation graph inside the sheet / destination.
- The field: iOS `TextField(axis: .vertical)`, Android `BasicTextField`, both drawn with the tokens above; the
  return key is "done" (one line of meaning; long text wraps).

## Do-not-copy

Tribute's step "Info" (name and email of people already in the group) and its pre-ticked "Send me offers & updates!";
video recording, minimum lengths, audio requirement; uploading from the camera roll (only group photos you posted or
are in); "Submit Another" (one contribution per person, replaced instead); seeing anyone else's contribution.

## Gaps

| item | status | owner capture |
|---|---|---|
| line placeholder and character limit | placeholder not found (none); limit SOURCED by gap fill: 110 (VidDay 'Text cards have a 110-character limit', MERGE G2-21) | research capture 4: a real Tribute / VidDay invitation opened on a phone up to the recorder / upload screen |
| photo picker layout | no reference has an "only your own photos" picker; the Yope wall grid is reused | — (owner decision) |
| step 2 / 3 screens of the references | not observed (would need a live submission) | same capture 4 |

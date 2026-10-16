# `tagging` — "I'm in this" (self-tag)

Visual reference: **Retro's tagged-people affordances in the media viewer** — the footer run " · with {names}" /
"Tag friends", the "In this photo" sheet with people rows and "Remove tag" (`media_viewer_footer_tagged_users_*`,
`media_viewer_tagged_user_*`, `media_viewer_view_tagged_users_empty` in
`references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`), drawn with components C-22 (viewer footer),
C-16 (people rows), C-29 (sheet), C-05 / C-06 (capsules). No face recognition; only yourself can be tagged. Voice:
Retro set. Tokens: none of its own (composition of global components). Copy: `design/copy/memory.json` (`tagging.*`).
Decisions: `design/MERGE_DECISIONS.md` → "Redesign — Memory (RM-*)".

What it does: on any photo in a group, a member can say "I'm in this" — only for themselves (`tag_self` /
`untag_self`). Tags are visible to the group's members (docs/API.md 5.11), as Retro shows who is in a photo. Self-tags
decide which photos a member may give to a birthday video (`birthday.contribute`: photos you posted or are in).

## References

| image / source | what it verifies |
|---|---|
| `references/auto/retro/press/tc-2023-07-retro-2b.jpg` phone 2 | viewer footer on black: location 15 semibold white, date line 15 regular #999999 ('Wednesday, July 5') — where the tag run sits |
| Retro strings `media_viewer_footer_tagged_users_divider` (" · with "), `media_viewer_footer_tagged_users_empty_state` ("Tag friends"), `media_viewer_tagged_user_title_photo` ("In this photo"), `media_viewer_tagged_user_action_untag_self` ("Remove tag"), `media_viewer_view_tagged_users_empty` ("No one is tagged"), `media_viewer_tag_user_permission_denied_error_tag_title` ("Unable to add tag") | the affordance and its words |
| `references/auto/retro/press/tc-2023-07-retro-1b.webp` phone 2 (lower half) | people rows: avatar 37, name 15 semibold, paired 36-pt capsules (C-16) |

## Structure

The control lives in the **`photo.viewer` footer** (C-22), placed by the `photo.viewer` pass; `tagging` owns its
content, the sheet and the behaviour.

**A. Footer run** — appended to the footer's second line (the date, text role `listSubtitle`,
`color.global.textSecondary`) after Retro's separator " · ":
- nobody tagged → `tagging.toggle` ("I'm in this"), same text role, `color.global.textOnMedia` (the tappable part, as
  Retro's "Tag friends" run); tap = tag yourself at once (optimistic) + `tag_self`;
- someone tagged → `tagging.with` ("with {names}"), `{names}` = the tagged members' first names in tag order joined by
  the platform list formatter (yours included), `color.global.textSecondary`, the names in semibold
  (`fontWeight.global.listTitle`, as Retro sets actor names in grey lines, C-15); one line, tail-truncated — never a
  count. Tap → the sheet (B).
The whole run is one button (hit area ≥ `size.global.minTouchTarget.*`).

**B. "In this photo" sheet** (C-29 page sheet, medium detent, follows the appearance):
1. Sheet header: title `tagging.sheet.title` ("In this photo"), text role `sheetTitle`, centred; trailing close circle
   (C-11 on the page: `size.global.circleButton`, `color.global.control`, `icon.global.close`).
2. People rows (C-16), `size.global.screenMargin` margins: avatar `size.global.avatarPicker`, first name text role
   `listTitle`; on **your** row a trailing outline medium capsule (C-06 outline) `tagging.remove` ("Remove tag").
3. Empty (everyone untagged while open): C-27 title only, `tagging.sheet.empty` ("No one is tagged").
4. When you are not tagged: a primary capsule at the bottom (C-05, `size.global.buttonHeight`,
   `size.global.buttonMarginH`) `tagging.toggle` ("I'm in this").

Shown on every photo the member can see, including their own (tagging yourself on your own photo is allowed and
changes nothing for tributes). Not shown on collages.

## Elements

| element | component · tokens | copy keys | behaviour |
|---|---|---|---|
| footer run (untagged) | C-22 footer line: text role `listSubtitle`, `color.global.textOnMedia` | `tagging.toggle` | tap → tagged (optimistic) + `tag_self(post_id)` |
| footer run (tagged) | text role `listSubtitle`, `color.global.textSecondary`, names `fontWeight.global.listTitle` | `tagging.with`, `tagging.a11y.people` | tap → sheet |
| sheet header | C-29: text role `sheetTitle`, C-11 close (`size.global.circleButton`, `color.global.control`, `icon.global.close`) | `tagging.sheet.title` | — |
| person row | C-16: `size.global.avatarPicker`, text role `listTitle`, `size.global.screenMargin` | — (names are data) | — |
| Remove tag | C-06 outline: `size.global.pillHeight`, 1 pt `color.global.textPrimary`, text role `pill`, `radius.global.capsule` | `tagging.remove` | untagged at once + `untag_self(post_id)`; your row leaves the list |
| I'm in this (sheet) | C-05: `color.global.accent` / `color.global.onAccent`, `size.global.buttonHeight`, `radius.global.button`, text role `button` | `tagging.toggle` | tagged at once + `tag_self` |
| pending | the control ignores taps while its call runs (≤ one call per photo) | — | — |

## States

| state | design | copy | source |
|---|---|---|---|
| untagged / tagged | A, B | `tagging.toggle`, `tagging.with` | Retro footer run |
| sheet empty | C-27 title | `tagging.sheet.empty` | `media_viewer_view_tagged_users_empty` |
| error (call failed) | revert; Android Toast (C-26); iOS accessibility announcement + the reverted run | `tagging.error` (add) / `tagging.removeError` (remove) | `retro.voice.error` |
| photo gone (`post_not_found`) | revert + message; the viewer closes the photo (`photo.viewer`) | `tagging.notFound` | `retro.voice.error` |
| offline | no change; message as error | `tagging.offline` | `retro.voice.error` |
| loading / permission-denied | n/a (tags come with the viewer's `post_tags` read) | — | — |

## Motion

Footer run text change: cross-fade `duration.global.crossfade` (`easing.global.standard`). Sheet: native
(`spring.global.sheetPresent`). Rows appear / leave: fade `duration.global.fade`. Reduce Motion:
`layout.global.reduceMotion`.

## Haptics

Tag / untag applied → `haptic.global.select` (a toggled selection, Retro's tick). Taps on the run, capsules and close →
`haptic.global.tap` (Android). Failed → `haptic.global.error`.

## Accessibility

- Footer run: button; untagged label `tagging.toggle`; tagged label `tagging.a11y.people` ("People in this photo")
  with the value `tagging.with` text. iOS adds `.isSelected` when you are tagged; Android `stateDescription`.
- Sheet: title header; rows read "name"; "Remove tag" button on your row.
- Dynamic Type: `listSubtitle` → subheadline; the run truncates, the full list is in the sheet.
- Contrast (`node tools/contrast.mjs`):

  | pair | ratio | needs | result |
  |---|---|---|---|
  | footer run `color.global.textOnMedia` on `color.global.backgroundDeep` (viewer, both appearances) | 21.00 | 4.5 | pass |
  | `color.global.textSecondary` on `color.global.backgroundDeep` | 7.37 | 4.5 | pass |
  | sheet text `color.global.textPrimary` on `color.global.background` | light 21.00 · dark 21.00 (Android dark page #1C1C1E 17.01) | 4.5 | pass |
  | outline capsule border / label `color.global.textPrimary` on the page | 21.00 | 3 / 4.5 | pass |
  | C-05 label `color.global.onAccent` on `color.global.accent` | 21.00 | 4.5 | pass |
  | close fill `color.global.control` vs page | light 1.13 · dark 1.39 (Android dark page 1.12) — C-11 failure 2 | 3 | **FAIL** (non-text; glyph identifies it — reported) |

## Data & actions

- **Read:** `from("post_tags").select("user_id").eq("post_id", p)` (the viewer's batch read of the post's tags) +
  `profiles` (first names, avatars) of those users.
- **Writes:** `rpc("tag_self", p_post_id)` → `post_tags`; `rpc("untag_self", p_post_id)` → void. Idempotent. Error
  `post_not_found`.
- **Used by:** `birthday.contribute` (eligible photos = posted by you ∪ tagged by you). `year.compute` does not read
  tags.
- **Navigation:** none (inline control + sheet). No push, nobody is notified.

## Platform notes

iOS: footer run is a `Button` with styled `Text` (`ListFormatter` for the names); sheet `.sheet` with
`.presentationDetents([.medium])`. Android: `ClickableText`-free `Text` inside a `Modifier.clickable` row
(`ListFormatter` API 33+, else the locale's "A, B and C" via `android.icu.text.ListFormatter`); `ModalBottomSheet`.
Optimistic update with rollback on error.

## Do-not-copy

Retro's tagging of other people ("Tag friends", "Suggest Tag", friend-request upsells, "%1$d friends" counts, "Tagged
you in a photo" notifications); face recognition or suggested tags; notifying anyone that you tagged yourself.

## Gaps

| item | status | smallest capture that closes it |
|---|---|---|
| Retro's footer and "In this photo" sheet as images | strings only (the 2023 viewer render predates tags) | one RAW screenshot of a Retro photo with a tagged friend, footer and the "In this photo" sheet |
| position in the viewer footer | owned by `photo.viewer` (hand-off, MERGE RM-9) | — |

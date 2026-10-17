# camera.sendto — choose groups, optional message and voice note, send

**Visual reference: Retro's "Postcard" composer** (ST-03 / TC-R3 phone 2: black modal, centred title + close circle,
photo with an "Add a message" pill, a labelled block under the photo, a hairline, a 60-pt white capsule at the bottom)
and its **"Add a Message" sheet** (TC-R3 phone 3: title, "Done", message field, 250-character counter). The group
choice is drawn as Retro rows with check circles (C-16 + C-32 + `size.global.checkCircle`, the composer's selection
circle). **Mechanics: Locket** (send to many at once, save to device, send states) and the product spec (multi-group
selection, optional voice note, no mandatory edit). Decisions: `design/MERGE_DECISIONS.md` RC-5 … RC-8.

## References

| image | what it verifies |
|---|---|
| `references/auto/retro/store/retro-store-03.png` (ST-03, 2026, dark) | header geometry (`camera.sendto.layout.header`), photo frame (`.layout.preview`), "Add a message" pill (`.layout.messageField`), field label + divider (`.layout.recipientRow`), 60-pt white capsule and its bottom (`.size.sendButtonBottom`) |
| `references/auto/retro/press/tc-2023-12-retro3.png` phone 2 | disabled "Send Postcard" on the black composer (#4D4D4D fill, black label); rows "Mailing Address" / "Total" with a hairline |
| `references/auto/retro/press/tc-2023-12-retro3.png` phone 3 | "Add a Message" sheet: title, "Done", text, counter "58/250" (`.layout.messageSheet`, `.fontSize.counter`, `.size.captionMaxLength`) |
| `references/auto/retro/video/ig-DDbA_F7x-j7-composer-f130-147-f188-197.png` | Retro composer sheet presentation (`spring.global.sheetPresent`) |
| `references/owner/locket-review-sendto.jpg`, `-review-sending.jpg`, `-review-sent.jpg` | mechanics: discard / send / save, sending → sent |

## Structure (top to bottom, 393 × 852 pt)

Full-screen modal on `color.global.backgroundDeep` in both appearances ("postcard-style composer",
`layout.global.appearance.media`). The content between the header and the bottom capsule scrolls.

1. **Header** (`camera.sendto.layout.header`): centred title `camera.sendto.title` — text role `sheetTitle`,
   `color.global.textOnMedia`, cap middle on the circles' centre line, 25.8 pt below the safe-area top. Trailing
   **close** circle (C-11 on media: `size.global.circleButton` 36, fill `color.global.controlOnDeep`,
   `icon.global.close` in `color.global.textOnMedia`), centre 37.7 pt from the trailing edge; leading **save** circle,
   mirrored, `icon.global.download`.
2. **Preview** (`camera.sendto.layout.preview`): 297.6 pt wide, centred, top 20 pt below the circles; native aspect
   (camera photos 3:4 → 397 pt), at most 422.8 pt tall; aspect-fill; corners 8.5 (`layout.global.cornerStyle`). On it,
   centred, bottom 20.5 pt above the photo bottom (`camera.sendto.layout.messageField`): the **message pill** (C-09 on
   media: fill `color.global.controlOnDeep`, `icon.global.edit` at `size.global.iconSmall`, label text role `pill`
   `color.global.textOnMedia`, height `size.global.pillHeight`, paddings `size.global.pillPaddingLeading` /
   `.pillPaddingTrailing`, icon gap `size.global.pillIconGap`) then, `size.global.pillGap` after it, the **voice
   capsule** (icon-only, `size.global.iconPillWidth` × `size.global.pillHeight`, same fill, `icon.global.mic`).
   Recording (`chat.voice.md`) swaps the message pill for the **recording capsule** (`camera.sendto.layout.messageField`
   `.recording`): holding — red mic · elapsed · "‹ Slide to cancel"; locked — red mic · elapsed · C-36 live waveform ·
   pause (`chat.voice.a11y.pauseRecording`); paused — trash · preview play / pause · C-36 draft waveform · length · red
   mic (`chat.voice.a11y.resumeRecording`); the voice capsule shows `icon.global.send` and keeps the note. A kept note
   is the **note capsule** (`.note`: the `chat.voice` capsule on media — play glyph · C-36 waveform
   `chat.voice.dimension.waveform` · duration) centred `size.global.pillGap` above the pill pair; the voice capsule stays
   the mic (a new recording replaces the note). Owner decision 16.
3. **Groups** (`camera.sendto.layout.recipientRow`): label `camera.sendto.groupsLabel` — text role `meta`,
   `color.global.textSecondary`, 35.2 pt below the photo, at `size.global.screenMargin`. Then one **row per group**
   (C-16): group cover in a `size.global.avatarPicker` circle (no cover: `icon.global.group` on
   `color.global.controlOnDeep`); the name starts `size.global.cardNameGap` (11) after the avatar; name text role `listTitle`, `color.global.textOnMedia`; trailing check (`size.global.checkCircle`):
   `icon.global.check` in `color.global.selection` when selected, `icon.global.uncheck` in `color.global.textSecondary`
   when not, ink at the trailing margin. Row padding 16 above and below the avatar (row 69 pt); a C-32 hairline
   (`color.global.separator` dark value #4D4D4D, `size.global.hairline`) between rows, inside the margins.
   **Several photos** (a library selection or a share, see "Several photos" below): between the photo and the groups
   label, the **selection strip** — C-17 tiles (`size.global.stripTileWidth` × `.stripTileHeight`, 84 × 112),
   `size.global.stripGap` apart with the page showing through, only the strip's outer corners rounded
   (`radius.global.card`), leading inset `size.global.screenMargin`, scrolling sideways; its top `size.global.sectionGap`
   below the photo, and the groups label keeps its own gap below the strip (as below the photo). Each tile is the photo
   aspect-fill (a video's first frame with the video marker, `layout.global.videoMarker`), `color.global.controlOnDeep`
   until decoded; no weekday, no number. The photo frame shows the first photo.
4. **Send capsule** pinned at the bottom (C-05 on media): `size.global.buttonHeight` (60), margins
   `size.global.buttonMarginH` (20), bottom 44.5 pt above the screen bottom (`camera.sendto.size.sendButtonBottom`),
   `radius.global.button`; fill `color.global.surfaceLight`, label `camera.sendto.send` text role `button`
   `color.global.onSurfaceLight`. Disabled with nothing selected: fill #4D4D4D (`color.global.controlRaised` dark value —
   Retro's disabled capsule on this composer), label #000000.

**"Add a Message" sheet** (opens from the message pill; native page sheet, follows the appearance — page
`color.global.background` / Android `color.global.background.android`; `camera.sendto.layout.messageSheet`):
toolbar with centred title `camera.sendto.message.title` (text role `sheetTitle`) and trailing text button
`camera.sendto.message.done` (C-08, text role `textButton`, `color.global.textPrimary`); multi-line field from 22 pt
inset, text role `placeholder` (17), typed text `color.global.textPrimary`, placeholder `camera.sendto.caption.placeholder`
in `color.global.textSecondary` (Android `.textSecondary.android`); counter `camera.sendto.message.counter`
(`camera.sendto.fontSize.counter` 16, monospaced digits, `color.global.textSecondary`) trailing, 20.7 pt from the edge,
22 pt above the keyboard. The keyboard is the system's.

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| title | C-29 sheet header · `sheetTitle`, `color.global.textOnMedia`, `camera.sendto.layout.header` | `camera.sendto.title`; while sending `camera.sendto.sending` | title text cross-fades to "Sending…" during the send |
| close | C-11 on media · `size.global.circleButton`, `color.global.controlOnDeep`, `icon.global.close` | a11y `camera.sendto.a11y.close` | back to `camera.capture`, discarding the capture; if a message or voice note was added, asks first (native alert): `camera.sendto.discard.title` / `.message`, destructive `camera.sendto.discard.confirm`, `camera.sendto.cancel` |
| save | C-11 on media · same, `icon.global.download` | a11y `camera.sendto.a11y.save`; Android toast `camera.sendto.toast.saved` | saves the photo / Live Photo / video to the device (add-only access, purpose string owned by `system.permissions`); iOS confirms with an accessibility announcement of `.toast.saved` (C-26) |
| preview | photo frame · `camera.sendto.layout.preview` | — (own photo: decorative) | Live Photo plays on long press (PHLivePhotoView); video plays muted in a loop |
| message pill | C-09 on media · `camera.sendto.layout.messageField`, `icon.global.edit`, text role `pill` | `camera.sendto.message.add`; after a message `camera.sendto.message.edit` | opens the "Add a Message" sheet |
| message sheet | C-29 page sheet · `camera.sendto.layout.messageSheet`, `camera.sendto.fontSize.counter` | `.message.title`, `.message.done`, `.caption.placeholder`, `.message.counter` ({count}, {max} = `camera.sendto.size.captionMaxLength` 250) | input stops at 250 characters; "Done" (or swipe down) keeps the text; an empty field clears the message |
| voice capsule | C-06 icon-only capsule on media · `size.global.iconPillWidth`, `color.global.controlOnDeep`, `icon.global.mic` (locked / paused: `icon.global.send`) | a11y `camera.sendto.a11y.voice` | records an optional voice note with the `chat.voice` recorder (hold, slide to cancel, lock; microphone asked here at first use); the note goes on every chosen group's post |
| recording capsule | `camera.sendto.layout.messageField` `.recording` (C-06 fill on media + C-36 + C-10 red glyphs) | `chat.voice.recording.slideToCancel`, `chat.voice.a11y.pauseRecording`, `.resumeRecording`, `.discard`, `.play` / `.pause` | holding / locked / paused draft (`chat.voice.layout.locked` order) |
| note capsule | `chat.voice.layout.capsule` on media (C-36 waveform `chat.voice.dimension.waveform`) · `camera.sendto.layout.messageField` `.note` | `chat.voice.a11y.play` / `.pause`; action `chat.voice.a11y.discard` | tap plays / pauses the note; context menu / accessibility action deletes it |
| groups label | text role `meta`, `color.global.textSecondary` | `camera.sendto.groupsLabel` | header trait |
| group row | C-16 · `camera.sendto.layout.recipientRow`, `size.global.avatarPicker`, `size.global.checkCircle`, `icon.global.check` / `.uncheck`, `color.global.selection` | group name (data) | tap toggles (multi-select). Preselected: the group from context (`app://camera?group=`, group screen, chat); without context, all of the member's groups (owner to confirm) |
| open invitation | under the group name: text role `listSubtitle`, tabular figures, `color.global.textSecondary` (dark value) | `daily.capture.countdown` (MM:SS) | while that group's daily invitation is open (`open_invitations`, migration 0035) the countdown ticks each second to `closes_at`, then goes — no "late", no colour change (tenet 5). Sending while it is open answers it for each chosen group (`p_invitation_ids`), exactly as the notification's daily capture does (BeReal: "You have 2 minutes to open the app and take your BeReal", design/research/bereal.md). Not shown, and nothing answered, for a photo reply or a 9 AM photo |
| selection strip (several photos) | C-17 tiles · `size.global.stripTileWidth` / `.stripTileHeight`, `size.global.stripGap`, `radius.global.card` (outer corners), `size.global.screenMargin`, `size.global.sectionGap`, `color.global.controlOnDeep`, `layout.global.videoMarker` | a11y `camera.sendto.a11y.selection` ("Selected photos") — one element, no number | shown only with several photos; not interactive (the order is the order picked) |
| send | C-05 on media · `size.global.buttonHeight`, `size.global.buttonMarginH`, `camera.sendto.size.sendButtonBottom`, `color.global.surfaceLight` / `.onSurfaceLight` | `camera.sendto.send` | disabled with no group selected; tap → busy (C-05 busy: the label is replaced by the platform activity indicator in `color.global.onSurfaceLight`), title "Sending…", upload + `create_post`; success → the modal closes, `haptic.global.send`, Android toast `.toast.postedOne` / `.postedMany` (iOS announcement) |

## States

| state | design | copy | source |
|---|---|---|---|
| loading (groups) | rows area: platform activity indicator (C-28, `color.global.textSecondary`), centred | — | C-28 |
| empty (no groups) | C-27 in the rows area on media: `icon.global.group`, title `emptyTitle` `color.global.textOnMedia`, explanation `emptyDetail` `color.global.textSecondary`, C-07 outline capsule (border / label `color.global.textOnMedia`); send disabled | `camera.sendto.empty.title` / `.detail` / `.button` → `groups.create` (capture kept) | `retro.voice.empty-state` |
| sending | title `camera.sendto.sending`; capsule busy; close, save, pill, rows disabled | `camera.sendto.sending` | Retro Postcard "Ordering postcard…" |
| sent | modal closes; Android toast; iOS announcement | `camera.sendto.toast.postedOne` (one group) / `.postedMany` | C-26 |
| error (upload or `create_post` failed) | stays in the sheet; native alert (C-29): title `.error.sendFailed`, message `.error.generic`, buttons `.error.retry` / `camera.sendto.cancel` (keeps everything); `haptic.global.error` | `camera.sendto.error.*` | `retro.voice.error` (`media_viewer_comment_send_failed_*`) |
| offline | same alert, message `camera.sendto.error.offline` | `camera.sendto.error.offline` | `retro.voice.error` |
| microphone denied | voice capsule opens the settings path owned by `system.permissions` | owned there | — |
| video by a free member | a picked library video → `paywall` once per session, otherwise send stays disabled for that media (`premium_required`) | — | API `create_post` |

## Several photos (one post of several photos — docs/RESEARCH_FEATURES_2026-10-17.md #1)

Mechanics: Retro's composer "Add to Your Week" picks several photos (repo screen 30, VID-COMP); Apple Shared Albums
"Select all the items you want to add" (support.apple.com/108314); at most `batch_max_photos` (20, Instagram carousels;
public `app_config`, migration 0051). A selection comes from the library picker (`camera.capture`) or a share
(`share.in`).

- **One send for the selection.** Each photo is **its own post** (reactions, replies, tags, deleting, walls and memories
  stay per photo) with the selection's **`batch_id`** (one client-generated UUID, `media.batch_id`, docs/API.md §5.0) —
  the apps show a batch together (chat, viewer, strip: another surface's spec). They are uploaded and posted **in the
  order picked**, one after the other through the outbox / upload queue, so the posts keep that order; the server sends
  one push for the batch.
- **The message, the voice note, the open invitations, a reply and a weekly question go with the first photo only.**
  Retro's composer takes one caption for what it adds; repeating it on every photo would show it once per photo when the
  batch is shown together. The groups chosen apply to every photo.
- **Library photos carry the day they were taken** (`media.taken_on`, `camera.capture.md`); camera captures none.
- **Premium:** a selection holding a video needs premium, as one video does (send stays disabled; the paywall once per
  session).
- **States.** Sending: as one photo, until the last photo is posted; one `haptic.global.send` and one confirmation for the
  selection. Error / offline: the alert as for one photo; the photos already posted stay posted, "Try Again" goes on with
  the rest (same `batch_id`), Cancel keeps them in the composer. Close (✕) discards the photos not yet posted.
- **Save** saves every photo of the selection.

## Motion

| motion | tokens | Reduce Motion |
|---|---|---|
| modal in / out | native full-screen presentation (`easing.global.native.sheet`); a custom presentation matches `spring.global.sheetPresent` / `duration.global.sheetPresent` | cross-fade |
| "Add a Message" sheet | native page sheet (`spring.global.sheetPresent`, measured on Retro) | system |
| pill label add ↔ edit; title ↔ "Sending…"; check on ↔ off | `duration.global.crossfade` (100) | same |
| busy indicator in the capsule | platform (`easing.global.native.activityIndicator`) | system |

## Haptics

Row toggle: `haptic.global.select` (tick on a toggled selection). Close, save, pill, voice, send presses:
`haptic.global.tap` (Android VIRTUAL_KEY; iOS none). Sent: `haptic.global.send`. Failed: `haptic.global.error`. None
while the microphone records (HIG).

## Accessibility

- Several photos: the selection strip is one element labelled `camera.sendto.a11y.selection` ("Selected photos"), never
  a number of photos (tenet 2); it follows the photo in the focus order.
- Labels: close `camera.sendto.a11y.close`, save `.a11y.save`, voice `.a11y.voice`; pill = its visible text; send =
  its visible text, disabled trait when nothing is selected; rows: label = group name, selected trait (iOS
  `.isSelected`, Android `Modifier.toggleable`); a row with an open invitation carries the time left as its value
  (iOS: the spoken duration; Android: `stateDescription`, the platform's elapsed-time format); counter read as "58 of
  250" via the platform (value of the field).
  Preview hidden (own photo).
- Dynamic Type: `sheetTitle` → headline, `listTitle` → subheadline, `meta` → footnote, `pill` → subheadline,
  `button` → headline, `placeholder` → body, counter → callout (`camera.sendto.layout.textStyleMap`).
- Focus order: save → title → close → preview pill → voice → groups label → rows → send.
- Contrast:

| pair | light | dark | result |
|---|---|---|---|
| title, names `textOnMedia` on `backgroundDeep` | 21.00:1 | 21.00:1 | pass |
| groups label / unchecked ring `textSecondary` on `backgroundDeep` | 7.37:1 | 7.37:1 | pass |
| check `selection` on `backgroundDeep` (non-text) | 5.97:1 (#0088FF) | 6.49:1 (#0091FF) | pass |
| pill / circle glyphs `textOnMedia` on `controlOnDeep` | 15.13:1 | 15.13:1 | pass |
| circle / capsule fill `controlOnDeep` vs `backgroundDeep` (non-text) | 1.39:1 | 1.39:1 | **FAIL** (container edge; glyph identifies it — CONTRAST failure 2) |
| divider #4D4D4D on `backgroundDeep` | 2.48:1 | 2.48:1 | decorative |
| send label `onSurfaceLight` on `surfaceLight` | 21.00:1 | 21.00:1 | pass; disabled #000000 on #4D4D4D 2.48:1 exempt (disabled) |
| sheet typed text `textPrimary` on `background` | 21.00:1 | 21.00:1 | pass |
| sheet placeholder / counter `textSecondary` on `background` (iOS) | 2.85:1 | 7.37:1 | **FAIL light** (CONTRAST failure 1) |
| same, Android `color.global.textSecondary.android` on `color.global.background.android` | 4.00:1 | 6.85:1 | **FAIL light** |

## Data & actions

- Reads: `groups` + own `group_members` rows (names, `cover_path` signed URLs).
- Writes (docs/API.md recipe 9.4): upload `u/<uid>/<media_id>/original.<ext>` (+ `motion.mov`, `voice.m4a`), insert
  `media` (with `taken_on` for a library photo, migration 0050, and `batch_id` for each photo of a selection, migration
  0051 — both client-written at insert), `create_post(p_media_id, p_group_ids, p_caption?, p_voice_path?, p_voice_duration_ms?, p_voice_levels?,
  p_reply_to_post_id?, p_invitation_ids?)` (`p_voice_levels`: the note's 100 levels of 0…31, C-36; `p_invitation_ids`:
  the chosen groups' invitations still open on the device clock — the server decides at `create_post`).
- Reads also `open_invitations()` once the groups load (each group's open daily invitation, server clock).
  `p_caption` = the message (≤ 250 here; API ≤ 1000). Errors: `premium_required`, `not_group_member`, `already_posted`,
  `invalid_caption`, `invalid_voice`, `no_groups`.
- In: `camera.capture` (capture or library pick, one or several), `share.in` (through the camera). Out: back to the screen the camera was opened from; `groups.create`
  (empty); `camera.capture` (close).

## Platform notes

- iOS: `.fullScreenCover`; the message sheet is a `.sheet` (system detents and grabber); toast on Android only (C-26).
- Android: full-screen dialog destination; the message sheet is a `ModalBottomSheet` (`radius.global.sheet`); toasts
  `Toast.LENGTH_SHORT`; page of the message sheet `color.global.background.android`.
- Live Photos from the picker arrive as `PHLivePhoto` without library access (PLATFORM_CONSTRAINTS §6).

## Do-not-copy

Retro: postcard stamp art, "Mailing Address" / "Total" / price rows, the "FREE" pill, "Send Postcard" wording. Locket:
"Sending your Locket", gray paper-plane circle. Yope: lime "send ⓝ" with the count disc, caption drawn on the photo,
streak pills, "my wall" row, the edit pencil.

## Gaps

| item | status | smallest capture / decision |
|---|---|---|
| Retro's composer at full resolution ("Add to Your Week" with photos selected) | FRAME only (VID-COMP); rows composed from C-16 | 1 raw screenshot of "Add to Your Week" with 2 photos selected (RV §6) |
| Retro's check-row selection look in a light page | not captured; the sheet is black in both appearances here | — |
| default audience with no context | all groups (references preselect everyone) | owner |
| counter face | monospaced slab in the render (unidentified) → platform monospaced | one raw iOS screenshot of "Add a Message" |

# camera.sendto — choose groups, optional caption and voice note, send

Reference: **Yope** (layout, voice) + **Locket** (default audience, sending states considered; C-5). No mandatory
edit step: after a capture this sheet is the only step before send. Tokens `camera.sendto.*` + globals; copy
`camera.sendto.*`.

## References

| image | what it verifies |
|---|---|
| `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t6.73-sendto-voice-tooltip.png` (2026-10-10) | header, preview card, message field + mic, voice coach, recipient rows, 'send ⓝ' |
| `references/auto/yope/frames/a-savannahclooney-7683341732695592206-t5.73-sendto-caption-keyboard.png` (2026-09-09) | caption typed on the photo under the hour overlay, keyboard, header with download |
| `references/auto/yope/frames/a-jacob-7691153057177931039-t4.73-sendto-voice-tooltip.png` | same layout, 'my moments' variant |
| `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png` | 'posted in the wall' toast after sending |
| `references/auto/yope/frames/a-virgi-7686278541255642390-t56.23-sendto-three-selected-es.png` | three recipients selected, 'enviar ❸' |
| `references/owner/locket-review-sendto.jpg`, `-review-sending.jpg`, `-review-sent.jpg`; `references/auto/locket/frames/locket-tt-7498394022428331295-01.300s-android-sendto-add-a-message.jpg` | Locket's send states (not used, C-5) |

## Structure (top to bottom)

Full-height screen on `color.global.backgroundDeep`.

1. **Header** (centre 78 pt from the screen top): leading ✕ circle and trailing download circle — each
   `size.global.headerButton`, fill `color.global.controlOnDeep`, glyph `color.global.textPrimary`
   (`icon.global.close`, `icon.global.download`), inset `size.global.headerInset`; centred title
   `camera.sendto.title`, text role `sheetTitle`, `color.global.textPrimary`.
2. **Preview card**, centred, 218 × 290 pt, top 130 pt (30.5 pt below the header circles)
   (`camera.sendto.layout.preview`), corners `radius.global.photo`, photo aspect-fill. On it:
   - hour overlay centred (text role `overlayTimeCamera`, `camera.capture.hourOverlay`, `color.global.textPrimary`);
   - caption (when typed) centred, baseline 31 pt under the overlay baseline
     (`camera.sendto.size.captionBaselineOffset`), `camera.sendto.fontSize.caption` / `.fontWeight.caption`,
     `color.global.textPrimary`, wraps within the card;
   - bottom row: **message field** capsule (height 37, 10 pt from the card's leading edge, 14.5 pt above its
     bottom) and **mic circle** (38 pt, 7.5 pt after the field, 8.5 pt from the trailing edge)
     (`camera.sendto.layout.messageField`), both filled `camera.sendto.color.messageField` (black at 0.48 over a backdrop blur);
     placeholder `camera.sendto.caption.placeholder` in `camera.sendto.fontSize.messagePlaceholder`,
     `color.global.textPrimary`; mic glyph `icon.global.mic`, `color.global.textPrimary`.
   - voice coach (first use): the Yope coach tooltip (`camera.capture.layout.coach`, text
     `camera.sendto.coach.voice`, wraps to two lines within the card) pointing at the mic.
3. **Recipient list** (scrolls): first row centre 49.5 pt below the card, pitch 60 pt
   (`camera.sendto.layout.recipientRow`). Each row: group avatar (`size.global.avatarSmall`, circle, cover photo or
   `icon.global.group`) centred 51.5 pt from the leading edge · group name at 83 pt, text role `headerTitle`,
   `color.global.textPrimary` · check circle (`size.global.checkCircle`) whose trailing edge is 29 pt from the
   screen edge: `icon.global.check` in `color.global.selection` when selected, `icon.global.uncheck` in
   `color.global.textSecondary` when not.
4. **Send button** pinned at the bottom: full width minus `size.global.buttonMarginHSheet` each side, height
   `size.global.buttonHeightSheet`, bottom edge 41.5 pt above the screen bottom (`camera.sendto.size.sendButtonBottom`),
   `radius.global.button`, fill `color.global.accent`; label `camera.sendto.send` (text role `button`,
   `color.global.onAccent`) then, 7 pt after it, the **count disc** (18.5 pt, fill `color.global.onAccent`,
   number `camera.sendto.fontSize.countNumber` / `.fontWeight.countNumber` in `color.global.accent`).
5. **Toast** after a send (shown on the screen the member returns to): lime bar 49 pt high, 8.5 pt side margins,
   top 59 pt, corner 20 pt (`camera.sendto.layout.toast`), `color.global.accent`; `icon.global.check` 17 pt and the
   text in `color.global.onAccent`, text role `button`.

## Elements

| element | tokens | copy | behavior |
|---|---|---|---|
| ✕ | `size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.close` | a11y `camera.sendto.a11y.close` | discards the capture (caption, voice note) and returns to `camera.capture`; no confirmation (none observed) |
| download | same circle, `icon.global.download` | a11y `camera.sendto.a11y.save`; toast `camera.sendto.toast.saved` | saves the photo / Live Photo / video to the library (add-only access, `NSPhotoLibraryAddUsageDescription` owned by `system.permissions`) |
| title | text role `sheetTitle` | `camera.sendto.title` | — |
| preview card | `camera.sendto.layout.preview`, `radius.global.photo` | `camera.capture.hourOverlay` | Live Photo plays its motion on long press (PHLivePhotoView); video plays muted in a loop (Yope 'speaker' glyph not built — Gaps) |
| caption | `camera.sendto.fontSize.caption`, `.fontWeight.caption`, `.size.captionBaselineOffset` | — | tap the field → keyboard (system); text appears on the photo as typed (Yope); optional; max length `camera.sendto.size.captionMaxLength` (36 characters, Locket; no counter) |
| message field | `camera.sendto.layout.messageField`, `camera.sendto.color.messageField`, `radius.global.capsule` | `camera.sendto.caption.placeholder` | hidden while the keyboard is up (Yope t5.73) |
| mic | `camera.sendto.layout.messageField.micDiameter`, `icon.global.mic` | a11y `camera.sendto.a11y.voice`; coach `camera.sendto.coach.voice` | records an optional voice note with the `chat.voice` recorder (same Yope component; microphone permission asked here at first use, App Review 5.1.1(iv)); the note goes on every chosen group's post |
| recipient row | `camera.sendto.layout.recipientRow`, `size.global.avatarSmall`, `size.global.checkCircle`, `icon.global.check` / `.uncheck`, `color.global.selection` | group name (data) | tap toggles selection (multi-select). Preselected: the group from context (`app://camera?group=`, group screen, chat); with no context, all of the member's groups (references preselect everyone: Locket 'All Friends', Yope 'my wall' — owner to confirm) |
| send | `size.global.buttonHeightSheet`, `.buttonMarginHSheet`, `radius.global.button`, `color.global.accent` / `.onAccent` | `camera.sendto.send` | tap → upload + `create_post`; the sheet closes at once. With nothing selected the button is hidden (a disabled look was never observed — every Yope frame has a selection; Gaps) |
| count disc | `camera.sendto.size.countDisc`, `.countDiscGap`, `.fontSize.countNumber` | — (number of selected groups) | selection count only |
| toast | `camera.sendto.layout.toast`, `icon.global.check`, `camera.sendto.duration.toastVisible` (2000 ms) | `camera.sendto.toast.postedOne` / `.postedMany` / `.saved` | appears when `create_post` succeeds |

## States

| state | design | copy | source |
|---|---|---|---|
| loading (groups) | rows area shows the platform activity indicator (`easing.global.native.activityIndicator`), centred | — | Yope HUD uses the platform indicator (yope-a §1.8) |
| empty (no groups) | Yope empty state centred in the list area: `emptyTitle`, `emptyDetail` (`color.global.textSecondary`), light pill (`camera.capture.size.permissionButtonHeight`, `color.global.surfaceLight`, `radius.global.capsule`) | `camera.sendto.empty.title` / `.detail` / `.button` → `groups.create` (capture kept) | `yope.voice.empty-state` |
| sending | the sheet is closed; upload continues in the background | — | Yope t6.73 → t7.73 |
| sent | toast on the screen the member returns to (`groups.list`, as in Yope t7.73) + `haptic.global.send` | `camera.sendto.toast.postedOne` (one group) / `.postedMany` | V-chuong t7.73 |
| error (upload or `create_post` failed) | the toast layout with the text and a trailing `camera.sendto.error.retry` text button (`color.global.onAccent`, text role `button`); tapping retries; capture, caption and voice note are kept until sent or discarded | `camera.sendto.error.sendFailed`, `.retry` | `yope.voice.error`; docs/API.md recipe 9.4 step 4 |
| offline | same as error | `camera.sendto.error.offline`, `.retry` | — |
| microphone denied | mic tap shows the system-settings path through `system.permissions` | owned there | — |
| video by a free member | not reachable: video capture is premium (`camera.capture`); a picked video from the library by a free member → `paywall` once per session, otherwise the send button is hidden for that media (`premium_required`) | — | API `create_post` |

## Motion

| motion | tokens | Reduce Motion |
|---|---|---|
| keyboard, sheet close | `easing.global.native` (keyboard, sheet) | system |
| recipient toggle | glyph swap, no animation observed | — |
| toast in / out | in ≈117 ms (Yope 60 fps, curve not measurable; `spring.global.platformDefault.*`), visible `camera.sendto.duration.toastVisible` 2000 ms, out not observed | cross-fade |

## Haptics

recipient toggled → `haptic.global.select`; sent (create_post success) → `haptic.global.send`; failed →
`haptic.global.error`; none while recording the voice note (HIG: no haptics while the microphone records).

## Accessibility

- Labels: ✕ `camera.sendto.a11y.close`, download `camera.sendto.a11y.save`, mic `camera.sendto.a11y.voice`,
  send `camera.sendto.send` (the count disc is hidden from accessibility; the rows expose their selected trait —
  iOS `.isSelected`, Android `Modifier.toggleable` state), field `camera.sendto.caption.placeholder` as the field
  label. Preview: label `widget.home.small.a11y.photo` pattern is not used here — the preview is the member's own
  photo, so it is decorative in this flow (hidden).
- Dynamic Type: title `sheetTitle` → title3; names `headerTitle` → subheadline; caption → callout, placeholder →
  subheadline, count → caption2 (`camera.sendto.layout.textStyleMap`); button → subheadline.
- Focus order: ✕ → title → download → message field → mic → recipient rows → send.
- Contrast: name white on black 21:1; check `color.global.selection` on black 6.49:1; unchecked ring
  `color.global.textSecondary` on black 7.10:1; send label black on lime 17.65:1; count number lime on black
  17.65:1 (bold, large-text rule) pass; toast black on lime 17.65:1 pass; placeholder / caption / overlay white on
  the photo: photo-dependent; over a white photo the field fill gives white 3.69:1 (passes the 3:1 large/bold rule, fails 4.5:1 for 16-pt regular), reported, not adjusted.

## Data & actions

- Reads: `groups` (+ `group_members` for own membership) for the rows; group avatar = `groups.cover_path` signed URL.
- Writes (docs/API.md recipe 9.4): upload `u/<uid>/<media_id>/original.<ext>` (+ `motion.mov`, `voice.m4a`), insert
  `media` (kind `photo` | `live_photo` | `video`), `create_post(p_media_id, p_group_ids, p_caption?, p_voice_path?,
  p_voice_duration_ms?, p_reply_to_post_id?)`. Errors: `premium_required`, `not_group_member`, `already_posted`,
  `invalid_caption`, `invalid_voice`, `no_groups`.
- In: `camera.capture` (capture or library pick). Out: `groups.list` with the toast; `groups.create` (empty state);
  `camera.capture` (✕).

## Platform notes

- iOS: the caption field is a `TextField` whose text is drawn on the photo; voice note recorder = `chat.voice`.
- Android: same; `ModalBottomSheet` is not used (full-height screen as in Yope).
- Live Photos from the picker arrive as `PHLivePhoto` without library access (PLATFORM_CONSTRAINTS §6).

## Do-not-copy

Streak pills next to recipient names ('🔥9'), 'my wall' / 'just for friends' own-wall row (our posts go to groups),
the edit pencil (C-4), the compact 'more friends' + 'send ❶' variant (its trigger is not documented), Locket's
'Sending your Locket' wording.

## Gaps

| item | status | capture |
|---|---|---|
| `camera.sendto.color.messageField` | SOURCED by gap fill: black at 0.48 ±0.05, solved on Yope's own frame (MERGE G2-10); blur radius not measured | Yope send-to over a flat white and a flat black photo |
| `camera.sendto.duration.toastVisible` (+ toast motion) | SOURCED by gap fill: 2000 ms (Locket SHORT toast, MERGE G2-7); entrance ≈117 ms measured on Yope; exit not visible | 5-s recording of Yope right after send |
| `camera.sendto.size.captionMaxLength` | SOURCED by gap fill: 36 (Locket `MAX_CHARS`, MERGE G2-11) | type a long caption in Yope |
| video sound glyph on the preview (`speaker.wave.2.fill`, yope-a) | not built (videos play muted) | — |
| default audience with no context | owner decision | owner |
| send button with nothing selected | hidden (not observed) | one Yope send-to frame with every row deselected |

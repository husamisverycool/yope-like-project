# `viewer.selfiereaction` — react to a photo with a live selfie (never a number)

Lives inside `photo.viewer` next to the emoji reactions of `chat.reactions`. Research: `design/research/selfie-reactions.md`
(2026-10-16). Tokens: `design/tokens/social.json` (`viewer.selfiereaction.*`) + `global.*`, `photo.viewer.*`,
`chat.reactions.*`, `camera.capture.size.shutter*`. Copy: `design/copy/social.json` (`viewer.selfiereaction.*`); push
`notifications.push.selfieReaction.*` in `design/copy/capture.json`; reused unchanged: `chat.reactions.list.removeHint`,
`chat.reactions.a11y.add`, `photo.viewer.delete.cancel`, `camera.capture.denied.*`,
`notifications.push.channel.reactionsReplies.*` (channel "Post Activity"). The JSON files are canonical (values, evidence,
levels). Decisions: `design/MERGE_DECISIONS.md` → New features (SR-1 … SR-9). Server: `docs/API.md` §14.1.

**Mechanics: BeReal's Instant RealMoji** — touch and hold the smiley, a live front-camera circle opens over the post,
slide into the target ring, release to capture, and the selfie is sent at once and joins a stack of faces at the
photo's bottom-left; one per person per post, replaceable; the author cannot react to their own post and may remove
others' (help.bereal.com, AP 2026). **Visual reference: Retro**: the layer, ring, pill, faces and sheet are composed of
Retro components (C-09, C-11, C-16, C-22, C-23, C-29) and existing tokens; three new tokens carry BeReal geometry where
Retro has no counterpart. Composition record: `level: SOURCED`, `method: "composition of Retro components C-22, C-23,
C-09, C-11, C-29, C-16, C-27 in BeReal's Instant RealMoji order"`. Tenets: no count anywhere, no unlock gate, live faces
only (no stored posed set).

## References

| id | file | used for |
|---|---|---|
| AP-375 | `references/auto/bereal/frames/appstore-preview-2026_t12.47s_instant-realmoji-capture.png` (2.2545 px/pt) | capture layer: circle size, border, centre, hint, target ring, second hint |
| AP-405 | `references/auto/bereal/frames/appstore-preview-2026_t13.47s_instant-realmoji-armed.png` | armed ring |
| AP-SEQ | `…/frames/appstore-preview-2026_overlay-in_f351-f364.jpg`, `…_slide-arm_f384-f412.jpg`, `…_t13.67s_capture-flash.png`, `…_land-in-stack_f413-f426.jpg` | gesture order, timings (do-not-copy effects) |
| AP-427 | `references/auto/bereal/frames/appstore-preview-2026_t14.20s_realmoji-stack.png` | stack position, order, z-order, three visible faces |
| H-RP | `references/auto/bereal/help/help-21088572284317_realpeople-realmoji-comments-3x.png` (3x, lossless) | 2.0-pt face border, 16.3-pt equal insets |
| AP-D | `references/auto/bereal/frames/appstore-preview-2026_t16.80s_post-detail-realmojis-row.png` | who-reacted content (faces + names; its count is do-not-copy) |
| HC | help.bereal.com articles 7536240858653, 17845941900445, 7545622582429, 10100086147229 (research §1) | one per post, replace, own post, author delete, report, sent on release |
| LK | `references/auto/locket/store/locket-store-04.png` (`design/research/locket.md` l.423–457) | gap filler: reactions at a photo's bottom-left, no numbers |
| TC-2B | `references/auto/retro/press/tc-2023-07-retro-2b.jpg` phone 2 | Retro viewer: white avatar ring 2.0 / gap 3.0 (`photo.viewer.layout.avatarRing`), header avatar size |
| ST-03 | `references/auto/retro/store/retro-store-03.png` | C-09 pill / C-11 circle on media (#262626) |

## Structure

### 1. Entry points

- **Touch and hold** the viewer footer's add-reaction glyph (`chat.reactions.icon.add`, `face.smiling` — BeReal's
  smiley) → the capture layer opens in **hold mode** with the finger still down (AP #351–#392). A plain tap keeps
  opening the emoji picker (`chat.reactions.layout.picker`).
- The photo's context menu (long press, C-29; `photo.viewer.layout.menu`) gains the item `viewer.selfiereaction.menu.react`
  (glyph `icon.global.camera`) under the quick-reaction row; it opens the layer in **tap mode** (single-pointer
  alternative, WCAG 2.2 SC 2.5.7). The same item is an accessibility custom action on the photo.
- Hidden on your own photo ("You cannot react to your own BeReal", HC 7536240858653).
- Double-tap is **not** an entry: a viewer tap advances (`photo.viewer.layout.advance`).

### 2. Capture layer (over the viewer, below its header)

The viewer header stays visible and inert (BeReal keeps its header and tabs, AP-375). Everything else:

1. **Panel** — full width, from the photo's top (`photo.viewer.dimension.headerToPhoto` below the header avatar) to
   the bottom of the screen, fill `color.global.controlOnDeep`, corners `radius.global.photo` (0). It hides the photo,
   footer, comments and reply field (BeReal's opaque card, AP-375).
2. **Live circle** — `viewer.selfiereaction.layout.captureCircle`: diameter screen − 2 × `size.global.screenMargin`
   (361 at 393 pt; the `camera.capture.layout.viewfinder` width rule), horizontally centred, its centre at the
   **screen's vertical middle** (AP-375: 425.6 of 852 pt); live front-camera preview, aspect-fill, circular clip;
   border `viewer.selfiereaction.size.captureBorder` (3.4) in `color.global.backgroundDeep`, drawn outside the clip.
   If the panel is shorter than circle + ring + hint, the circle shrinks (centre kept on the panel's middle).
3. **Hint pill** — C-09 coach pill on media (as `camera.capture` coach): fill `color.global.controlOnDeep`, label
   `viewer.selfiereaction.coach.slideHere` (hold mode) / `viewer.selfiereaction.coach.tapRing` (tap mode), text role
   `pill`, `color.global.textOnMedia`, height `size.global.pillHeight`, paddings `size.global.pillPaddingLeading` /
   `.pillPaddingTrailing`; centred on the circle's centre (BeReal's hint sits across the circle's middle, AP-375).
4. **Target ring** — centred on the circle's **bottom edge** (AP-375: ring centre on the border's bottom point):
   outer diameter `camera.capture.size.shutterOuter` (86), stroke `camera.capture.size.shutterRing` (4.5), no disc,
   `color.global.textSecondary` (dark value on media). BeReal's ring is the size of its own shutter (72.7 vs 74.0 pt),
   so Jolt's ring is Jolt's shutter ring. In tap mode it is a button.
5. **Second hint** — `viewer.selfiereaction.coach.slideToSend` (hold mode) only, text role `meta`,
   `color.global.textSecondary`, centred, first line `size.global.screenMargin` below the ring's outer bottom.
6. **Armed ring** (hold mode, while the finger is inside the target ring or the circle) — a ring inside the circle:
   `color.global.textOnMedia`, stroke `photo.viewer.layout.avatarRing.strokeWidth` (2.0), its outer edge
   `photo.viewer.layout.avatarRing.gap` (3.0) inside the photo edge (BeReal: white ring 4.0 pt inside, AP-405; Retro's
   white viewer ring supplies stroke and gap).

### 3. Faces on the photo — `viewer.selfiereaction.layout.stack`

Over the viewer photo's **bottom-leading** corner (BeReal AP-427 and H-RP; Locket LK), inset `size.global.screenMargin`
from the photo's leading and bottom edges (equal on both axes, as H-RP's 16.3 / 16.3 pt; aligns with the footer text
column); for a letterboxed photo, from the visible image's edges.
- Face: circle `size.global.avatarHeader` (40.7, ring included; BeReal 42.6 pt), aspect-fill selfie, ring
  `color.global.textOnMedia` 2.0 (`photo.viewer.layout.avatarRing.strokeWidth`; C-23 white stack ring; BeReal's
  lossless border is also 2.0).
- At most `chat.reactions.count.clusterMaxVisible` (3) faces, newest leading (`chat.reactions.layout.clusterOrder`; AP
  #423), each trailing face drawn over the one before it (AP-427), overlap `size.global.avatarStackOverlap` (C-23).
  **No "+N"** and no other number when more people reacted.
- Hidden when nobody reacted with a selfie. The stack is one button with its own hit area (≥
  `size.global.minTouchTarget.*`); a tap on it never advances the photo.
- Tap → the Reactions sheet (`chat.reactions.layout.list`), where selfie rows sit among emoji rows by time.

### 4. Rows in the Reactions sheet

C-16 people row as in `chat.reactions.md` §4, with the **selfie as the row avatar** (`size.global.avatarPicker`, circle)
and the line `viewer.selfiereaction.activity.row` / `.activity.rowMine`; your row adds `chat.reactions.list.removeHint`.
- Tap your row → remove your selfie (WhatsApp / Messages mechanic, `chat.reactions.layout.unreact`).
- Long press any selfie row → C-29 menu: on your own photo `viewer.selfiereaction.menu.remove` (destructive, C-10;
  HC 7545622582429) → confirmation; on any row that is not yours `viewer.selfiereaction.menu.report` (destructive) →
  `safety.report`.

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| add-reaction glyph (hold) | `chat.reactions.icon.add`, `size.global.icon`, hit `size.global.headerButton` | `chat.reactions.a11y.add`; custom action `viewer.selfiereaction.a11y.action` | tap → emoji picker; hold → layer (hold mode) |
| menu item | C-29; `icon.global.camera` | `viewer.selfiereaction.menu.react` | layer (tap mode) |
| panel | `color.global.controlOnDeep`, `radius.global.photo` | — | tap outside the circle (tap mode) → close |
| live circle | `viewer.selfiereaction.layout.captureCircle`, `viewer.selfiereaction.size.captureBorder`, `color.global.backgroundDeep` | `viewer.selfiereaction.a11y.preview` | hold mode: release inside → capture and send |
| hint pill | C-09 on media; `color.global.controlOnDeep`, `pill`, `color.global.textOnMedia`, `size.global.pillHeight`, `size.global.pillPaddingLeading`, `.pillPaddingTrailing` | `viewer.selfiereaction.coach.slideHere` / `.coach.tapRing` | static |
| target ring | `camera.capture.size.shutterOuter`, `camera.capture.size.shutterRing`, `color.global.textSecondary` | `viewer.selfiereaction.a11y.capture` | hold: release on it → capture; tap mode: tap → capture |
| second hint | text role `meta`, `color.global.textSecondary`, `size.global.screenMargin` | `viewer.selfiereaction.coach.slideToSend` | hold mode only |
| armed ring | `color.global.textOnMedia`, `photo.viewer.layout.avatarRing` (strokeWidth, gap) | — | shown while the finger is inside |
| face stack | `viewer.selfiereaction.layout.stack`, `size.global.avatarHeader`, `size.global.avatarStackOverlap`, `chat.reactions.count.clusterMaxVisible`, `chat.reactions.layout.clusterOrder`, `size.global.screenMargin` | `viewer.selfiereaction.a11y.stack` | tap → Reactions sheet |
| selfie row | C-16; `size.global.avatarPicker`, `chat.reactions.layout.listOrder` | `viewer.selfiereaction.activity.row`, `.activity.rowMine`, `chat.reactions.list.removeHint`, `viewer.selfiereaction.a11y.face` / `.faceMine` | yours: tap → remove; long press → remove (author) / report |
| remove confirmation | C-29 native alert (`photo.viewer.layout.deleteConfirm` form) | `viewer.selfiereaction.remove.title`, `.remove.message`, `.remove.confirm`, `photo.viewer.delete.cancel` | confirm → remove that person's selfie from your photo |

## States

| state | what shows | tokens · copy | source |
|---|---|---|---|
| idle (no selfie reactions) | no stack | — | BeReal AP #351 |
| layer, hold mode | panel, live circle, pill "Slide here to react", target ring, "Slide in to send" | as Structure §2 | AP-375 |
| armed | + armed ring | `photo.viewer.layout.avatarRing` | AP-405 |
| layer, tap mode | pill "Tap the circle to send", ring is a button, no second hint | `viewer.selfiereaction.coach.tapRing` | HC "Tap the white button to capture" |
| sending | the layer closes; your face appears at the leading end of the stack at once (optimistic, as `chat.reactions`) | `spring.global.playful` | chat.reactions.md |
| replaced | a new selfie replaces yours (one per person per post) | — | HC 7536240858653 |
| camera starting | circle filled `color.global.backgroundDeep` until the first frame; C-28 platform activity indicator centred | `easing.global.native.activityIndicator` | C-28 |
| permission-denied | inside the panel, C-27 block centred where the circle is: title / detail / button (opens Settings); no ring, no hints | `camera.capture.denied.title`, `.denied.detail`, `.denied.button` | `camera.capture` (reused) |
| no front camera | entry points hidden | — | PLATFORM |
| error / offline (upload fails) | your face is taken back out of the stack; Android Toast / iOS announcement | `viewer.selfiereaction.error`; `haptic.global.error` | `retro.voice.error` |
| photo deleted while open | layer closes; `photo.viewer` gone state | `photo.viewer.gone.*` | photo.viewer.md |
| empty | not applicable | — | — |

## Motion

| motion | tokens | Reduce Motion |
|---|---|---|
| layer in / out | fade `duration.global.fade` (150) + `easing.global.standard` (BeReal: 300 ms linear fade, AP #357–#365 — Retro's fade used) | same |
| armed ring in / out | `duration.global.crossfade` (100) (BeReal: ≈ 370–400 ms growth from the target ring — not copied) | same |
| capture | none: no flash, no shutter animation (`camera.capture`: platform press; BeReal's white flash AP #411 is do-not-copy) | — |
| face enters the stack | `spring.global.playful` (Retro "avatar entries"); the stack shifts with the same spring | cross-fade `duration.global.crossfade` |
| face removed | fade `duration.global.fade`; remaining faces settle with `spring.global.playful` | cross-fade |
| sheet, menu, alert | native (`easing.global.native.*`, `spring.global.sheetPresent`) | system |

No rising bubbles and no fly-to-stack (BeReal AP #413–#437; same rule as RS-8 for Locket's rain and fly-in).

## Haptics

| interaction | token |
|---|---|
| hold opens the layer | `haptic.global.longPressStart` (Android LONG_PRESS; iOS none — no custom generator) |
| finger enters the target (armed) | `haptic.global.select` (PLATFORM: selection feedback when the active target changes) |
| capture | `haptic.global.shutter` (none) |
| sent | none (owner decision 15) |
| tap the stack, menu item, ring in tap mode (Android) | `haptic.global.tap` (iOS none) |
| remove confirmed | `haptic.global.warning` |
| failed | `haptic.global.error` |

## Accessibility

- Single-pointer path (WCAG 2.2 SC 2.5.7): the photo's custom action / menu item `viewer.selfiereaction.a11y.action`
  opens tap mode; the target ring is a button `viewer.selfiereaction.a11y.capture`; escape (iOS two-finger scrub,
  Android back) and a tap on the panel outside the circle close the layer. VoiceOver / TalkBack never get hold mode.
- Opening the layer moves focus to the ring; `viewer.selfiereaction.a11y.preview` labels the live circle (not a button).
- Stack: one button, label `viewer.selfiereaction.a11y.stack` with the names of the people shown (never a count);
  hint opens the sheet. Rows: `viewer.selfiereaction.a11y.face` / `.faceMine`.
- After sending, post an announcement `viewer.selfiereaction.a11y.sent`.
- Dynamic Type: pill `pill` → subheadline, second hint `meta` → footnote (`layout.global.textStyleMap`); the circle and
  ring keep their size.
- Focus order in the layer: ring → circle → (close via escape). In the viewer the stack sits after the photo and before
  the caption.
- Contrast (`node tools/contrast.mjs --appearance dark`; media surface in both appearances):

| foreground | background | kind | ratio | result | pair |
|---|---|---|---|---|---|
| `color.global.textOnMedia` | `color.global.controlOnDeep` | text | 15.13:1 | pass | pill label |
| `color.global.textSecondary` | `color.global.controlOnDeep` | text | 5.31:1 | pass | "Slide in to send" |
| `color.global.textSecondary` | `color.global.controlOnDeep` | nontext | 5.31:1 | pass | target ring |
| `color.global.backgroundDeep` | `color.global.controlOnDeep` | nontext | 1.39:1 | **FAIL** | circle border (decorative; the live image identifies the circle) |
| `color.global.controlOnDeep` | `color.global.backgroundDeep` | nontext | 1.39:1 | **FAIL** | panel edge (Retro palette, CONTRAST failure 2) |
| `color.global.textOnMedia` ring | the photo | nontext | photo-dependent | reported | face ring on the photo |
| C-09 pill over the live image | the live image | — | camera-dependent | reported | pill is opaque, so its label pair above holds |

## Data & actions (`docs/API.md` §14.1)

- **Storage**: the selfie is a still JPEG uploaded first to `u/<uid>/selfies/<uuid>.jpg` in the private `media` bucket;
  signed URLs only, readable by whoever can read its row; square crop for the circle (resolution BLOCKED).
- **RPCs**: `react_with_selfie(p_post_id, p_image_path)` (one row per post and person; a new selfie replaces yours and
  its old file is deleted; errors `post_not_found`, `invalid_image`, `own_post`); `remove_selfie_reaction(p_post_id,
  p_user_id = null)` (yours, or anyone's on your own post; `not_allowed`).
- **Reads**: `selfie_reactions(id, post_id, user_id, group_id, image_path, created_at)` with the `reactions` read rule
  (members who can see the post, blocks hide both ways). Never a count.
- **Report**: `report('selfie', <selfie_reactions.id>, reason)` → `safety.report` (title `safety.report.title.selfie`,
  the `selfie` reasons of `safety.report.layout.reasons`; MERGE SR-10).
- **Cascades**: removed with the reactor's account, with a block, and with the photo (`delete_media`).
- **Push**: `push.selfie_reaction` (type `reaction`), once per person, with `notifications.push.selfieReaction.*`;
  channel "Post Activity".
- **Realtime**: inserts and updates published; removals arrive as the `reactions_changed` broadcast → refetch the
  post's selfie rows.
- **Navigation**: inside `photo.viewer`; a push opens `DeepLink.post(groupID:postID:)`. Selfies are never saved to the
  camera roll or shared out (owner decision 12).

## Platform notes

- iOS: hold = `LongPressGesture(minimumDuration:)` sequenced with a `DragGesture` on the glyph, hit-testing the ring and
  circle; front camera via `AVCaptureSession` (`.builtInWideAngleCamera`, `.front`), preview mirrored by the system;
  circular clip `Circle()`; tap mode adds `accessibilityAction(named:)` and `accessibilityAddTraits(.isModal)` on the layer.
- Android: `pointerInput { detectDragGesturesAfterLongPress }` on the glyph; CameraX `DEFAULT_FRONT_CAMERA`,
  `PreviewView` clipped with `CircleShape`; back closes the layer; TalkBack custom action on the photo.
- Both: release outside the circle and the ring sends nothing (UIKit touch-up-inside / Compose
  `waitForUpOrCancellation` semantics, PLATFORM).

## Do-not-copy

BeReal's `RealMojis 5` header count, `+7` / `+4` / `3+` overflow circles, comment counts; the Instant unlock gate
(`UNLOCKABLE`, `10/20`, `Send 20 RealMoji to Unlock`); the stored mood set and its emoji / ⚡ badges; the rising-bubble
burst, fly-to-stack and white capture flash; the warm grey card colour; the names RealMoji / Instant RealMoji /
WIDGETMOJI / BeReal, the wordmark and watermark; `5 min late`; double-tap to react.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| tap one face → enlarged view | BLOCKED (BeReal's single-RealMoji view not found); until then the stack opens the sheet only | one screenshot of a tapped RealMoji in BeReal |
| stored selfie mirrored or not | BLOCKED | one RealMoji taken holding up text, then viewed |
| selfie resolution / crop | BLOCKED (backend decision) | — |
| hold timeout; release outside | outside = PLATFORM fill; timeout BLOCKED | 20-s recording: hold, slide out, release |
| Android behaviour | iOS-only evidence | one Android recording of an Instant RealMoji |
| reaction push wording | BeReal's not found; pattern-derived `notifications.push.selfieReaction.*` (SR-9) | one screenshot of the push after a friend reacts |
| face overlap | resolved (MERGE_DECISIONS SR-1): Retro C-23 `size.global.avatarStackOverlap` (3); BeReal 16.0 / Locket ≈ 12 pt are the recorded alternatives | — |
| armed-ring and landing curves | not used (Retro tokens instead); BeReal durations only | 60 fps recording |
| author removal, report kind, selfie table | needs API changes (Data & actions) | — |

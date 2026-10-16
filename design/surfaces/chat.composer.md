# `chat.composer` — group chat composer

Redesign on **Retro**: the composer is Retro's **reply / comment field** (C-13, screen 15: 48-pt rounded field, own
avatar leading, grey placeholder, trailing glyph) on a page surface, with Retro's own thread placeholders. Mechanics:
**Apple Messages / WhatsApp** (camera and mic beside the text; send replaces them while typing; hold the mic to record).
Tokens: `design/tokens/social.json` (`chat.composer.*`) + `global.*`. Copy: `design/copy/social.json` (`chat.composer.*`).
Decisions: `design/MERGE_DECISIONS.md` → Redesign — Social (RS-6, RS-25). Composition record: `level: SOURCED`,
`method: "composition of Retro component C-13 with Apple Messages / WhatsApp's glyph order"`.

## References

| id | file | used for |
|---|---|---|
| TC-2B | `references/auto/retro/press/tc-2023-07-retro-2b.jpg` phone 2 (2.209 px/pt) | the field: x 1357–2152 (16-pt margins), rows 1821–1934, own avatar x 1376–1445, placeholder from x 1469, "•••" ink x 2077–2113, field bottom on the bottom safe area |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | "Send a message…" (`message_thread_composer_placeholder`), "Reply…" (`…_reply_placeholder`), "Take photo", "Send" |
| APK-X | `references/auto/retro/apk/retro-android-2026.10.1150-excerpts.txt` | m6a.java:1213–1240 message composer: fade 150 ms + slide (the house default) |
| WA / GP | `references/auto/whatsapp/store/whatsapp-store-04.png`; Google Photos panels showing Messages (Gap fill G-6) | mechanics: camera + mic beside the idle field; send replaces the mic while text is present |

## Structure (one row, pinned to the bottom)

1. **Field** (C-13 on a page): fill `color.global.control` (iOS) / `color.global.surfaceSecondary.android` (Android), height
   `size.global.commentFieldHeight` (grows with multi-line text), corners `radius.global.commentField`, inset
   `size.global.screenMargin` on both sides; bottom edge `chat.composer.dimension.bottomInset` (0) above the bottom safe area,
   on the keyboard's top edge while the keyboard is up.
2. Inside the field, left → right on one centre line (top-aligned to the first line once the field grows):
   - own avatar `size.global.avatarComment` at `chat.composer.dimension.avatarInset` (C-23; no photo → `icon.global.person` on
     `color.global.controlRaised`);
   - text / placeholder starting `chat.composer.dimension.avatarToText` after the avatar: placeholder `chat.composer.placeholder`
     (replying: `chat.composer.placeholderReply`), text role `body` (C-13), placeholder `color.global.textSecondary`, typed text
     `color.global.textPrimary`;
   - trailing glyphs (`chat.composer.layout.typingState`), bare, `size.global.icon` box: `icon.global.camera` then
     `icon.global.mic` in `color.global.textSecondary`, the mic's ink `chat.composer.dimension.glyphInsetTrailing` from the
     field's trailing edge and the camera centred `size.global.headerIconPitch` to its left. While the field holds text both
     give way to `icon.global.send` in `color.global.textPrimary` at the mic's place.
3. While replying, the reply bar (`chat.thread.md`) sits above the field.
4. While recording a voice message the field's content is replaced by the recording row (`chat.voice.layout.recording`);
   a locked (hands-free) recording adds the controls row below the field — delete · pause / continue · send — and draws
   the live or paused draft's waveform in the field (`chat.voice.layout.locked`, C-36; owner decision 16).

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| field | C-13; `color.global.control` / `color.global.surfaceSecondary.android`, `size.global.commentFieldHeight`, `radius.global.commentField`, `size.global.screenMargin`, `chat.composer.dimension.bottomInset` | `chat.composer.a11y.field`; placeholder `chat.composer.placeholder` / `.placeholderReply` | multi-line; 4000-character integrity limit (`invalid_body`); return inserts a line break (send is the glyph) |
| own avatar | C-23; `size.global.avatarComment`, `chat.composer.dimension.avatarInset`, `.avatarToText` | decorative | — |
| camera glyph | `icon.global.camera`, `color.global.textSecondary`, `size.global.headerIconPitch`; hit area `size.global.headerButton` | `chat.composer.a11y.camera` | opens `camera.capture` with this group only (`DeepLink.camera(groupID:)`); the photo is sent with `create_post` and appears as a photo message (as a reply to the quoted photo when the reply bar is up) |
| mic glyph | `icon.global.mic`, `color.global.textSecondary`, `chat.composer.dimension.glyphInsetTrailing` | `chat.composer.a11y.mic` | press and hold → recording (`chat.voice.md`); first use asks for the microphone (`system.permissions`) |
| send glyph | `icon.global.send`, `color.global.textPrimary` (replaces camera + mic while text is present) | `chat.composer.a11y.send` | `send_message(p_kind: text, p_body)` (+ reply ids); the field clears; the reply bar closes |

## States

| state | what shows | tokens · copy | source |
|---|---|---|---|
| idle | field with placeholder, camera + mic | — | TC-2B, WA |
| typing | send glyph in place of camera + mic (cross-fade `duration.global.crossfade`) | `chat.composer.a11y.send` | Messages (G-6) |
| replying | reply bar above; placeholder `chat.composer.placeholderReply` | `chat.thread.reply.bar` | APK-S |
| sending / failed | the message appears in the thread with `chat.thread.sending`; failure → `chat.thread.sendFailed` | `haptic.global.send` / `haptic.global.error` | `chat.thread.layout.failedMessage` |
| offline | the field stays editable; sends fail as above | — | — |
| permission-denied (microphone) | `chat.voice.md` (alert with Settings link) | `chat.voice.permission.*` | — |
| permission-denied (camera) | `camera.capture` (capture group) | — | — |
| loading / empty / error | not applicable (no content of its own) | — | — |

## Motion

| transition | tokens | Reduce Motion |
|---|---|---|
| glyph swap (camera + mic ↔ send) | cross-fade `duration.global.crossfade` | same |
| composer / reply bar appear | fade `duration.global.fade` + `easing.global.standard` (Retro's message composer, APK-X m6a) | same fade |
| keyboard raise / lower | native (`easing.global.native.keyboard`); the field rides on the keyboard | system |

## Haptics

| interaction | token |
|---|---|
| tap camera / send (Android) | `haptic.global.tap` (iOS none) |
| text sent | `haptic.global.send` |
| send failed | `haptic.global.error` |
| mic pressed | none (HIG: no haptics that disturb the microphone) |

## Accessibility

- Labels: `chat.composer.a11y.field` (text field; the placeholder is the hint), `.a11y.camera`, `.a11y.mic`, `.a11y.send`.
  The mic is also exposed with a custom action "Record" for switch / VoiceOver users (press-and-hold is not required:
  double-tap starts recording in the locked state, `chat.voice.layout.recording.lock`).
- Dynamic Type: typed text / placeholder `body` → subheadline; the field grows; glyphs keep `size.global.icon`.
- Hit targets: each glyph 44 pt / 48 dp (`size.global.headerButton`, `size.global.minTouchTarget.android`).
- Focus order: field → camera → mic (→ send).
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | light | dark | pair |
|---|---|---|---|---|---|
| `color.global.textPrimary` | `color.global.control` | text | 18.59:1 pass | 15.13:1 pass | typed text (iOS) |
| `color.global.textPrimary` | `color.global.surfaceSecondary.android` | text | 19.60:1 pass | 15.13:1 pass | typed text (Android) |
| `color.global.textSecondary` | `color.global.control` | text | **2.52:1 FAIL** | 5.31:1 pass | placeholder, idle glyphs (iOS) |
| `color.global.textSecondary.android` | `color.global.surfaceSecondary.android` | text | **3.95:1 FAIL** | 6.38:1 pass | placeholder (Android) |
| `color.global.textPrimary` | `color.global.control` | nontext | 18.59:1 pass | 15.13:1 pass | send glyph |
| `color.global.control` | `color.global.background` | nontext | **1.13:1 FAIL** | **1.39:1 FAIL** | field boundary (iOS) |
| `color.global.surfaceSecondary.android` | `color.global.background.android` | nontext | **1.07:1 FAIL** | **1.12:1 FAIL** | field boundary (Android) |

  Retro's palette (design/CONTRAST.md failures 1–2); reported, not adjusted. The field is identified by its placeholder
  and avatar; the idle glyphs fail as text-size graphics in light (they carry labels).

## Data & actions

- `send_message(p_group_id, p_kind: 'text', p_body, p_reply_to_post_id?, p_reply_to_message_id?)` (docs/API.md §6.2);
  errors `invalid_body`, `not_group_member`, `post_not_found`, `message_not_found`, `reply_group_mismatch`.
- Voice: upload `u/<uid>/voice/<uuid>.m4a`, then `send_message(p_kind: 'voice', p_voice_path, p_voice_duration_ms,
  p_voice_levels)` (`chat.voice.md`; 100 levels of 0…31).
- Photo: `camera.capture` → `create_post(p_group_ids: [this group], p_reply_to_post_id?)` (§6.2, recipe §9.4).
- Realtime: the sent message arrives through the thread's `messages` INSERT subscription (§8.1).

## Platform notes

- iOS: `TextField(axis: .vertical)` inside the field shape; glyphs as `Button`s with a 44-pt `contentShape`; the mic uses a
  `LongPressGesture` + `DragGesture` sequence for hold / slide.
- Android: `BasicTextField` in a `Surface` with `RoundedCornerShape(radius.global.commentField)`; `imeAction = ImeAction.Default`
  (line breaks); RECORD_AUDIO runtime permission at the first recording.
- Microphone access is never asked before a photo or text can be sent (App Review 5.1.1(iv)).

## Do-not-copy

- Retro's sticker / GIF comment attachments (premium; stickers are do-not-build here).
- Yope's lime camera circle, sticker circle and rimmed capsule (superseded).

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| field internals (avatar inset, text start, glyph inset) | measured on a 2023 render (±0.5 pt); not yet in C-13 — reported to the foundations (RS-25) | one raw screenshot of Retro's comment field with text typed |
| `size.global.commentFieldHeight` | the foundations' 48 pt used the 2.298 px/pt scale; at the verified 2.209 px/pt the field is 51.2 pt (RS-25) | same screenshot |
| maximum lines before the field scrolls | not captured | same screenshot with a long text |
| Retro's DM composer (vs the viewer's comment field) | not captured; C-13 used | one raw screenshot of a Retro DM thread |

# `chat.composer` — group chat composer

Reference app: **Yope** group chat composer (`docs/SURFACES.md`). Research: `design/research/yope-b.md` §2,
`design/research/yope-a.md` §1.1, §1.4. Tokens: `design/tokens/social.json` (`chat.composer.*`) + `global.*`.
Copy: `design/copy/social.json` (`chat.composer.*`). Decisions: `design/MERGE_DECISIONS.md` → Social.

## References

| id | file | used for |
|---|---|---|
| S1 | `references/auto/yope/store/yope-store-05.png` (lossless); coordinates in `references/auto/yope/frames/b-derot-store-05-rot-1.68.png` | **primary**: group-chat composer row (lime camera · field "start typing..." · sticker · mic) |
| S3 | `references/auto/yope/frames/b-play-04.png` | same design (cross-check) |
| S5 / O4 | `references/auto/yope/frames/b-yopeapp-7591560669967682847-t48.50-1on1-thread.png`, `references/owner/yope-1on1-feed.jpg` | 1:1 space composer (49–51 pt, different screen; F-19, S-1) |

## Structure (one row, left → right, one shared centre line)

1. **Lime camera circle** at `chat.composer.dimension.insetLeading` (22.8) from the left edge.
2. Gap `chat.composer.dimension.gapCameraField` (6.2).
3. **Text field** (flexes to fill): height `chat.composer.dimension.fieldHeight` (39.5), `radius.global.capsule`,
   fill `color.global.control`, hairline rim (`chat.composer.dimension.fieldRim`) shading from
   `chat.composer.color.fieldRimTop` to `chat.composer.color.fieldRimBottom`; text / placeholder start at
   `chat.composer.dimension.fieldPaddingLeading`.
4. Gap `chat.composer.dimension.gapFieldButton` (7.1).
5. **Mic circle** (`chat.composer.dimension.sideButton`, 39.5) at `chat.composer.dimension.insetTrailing` (23.4) from the
   right edge.

The sticker circle between the field and the mic is removed (stickers are do-not-build). The row's distance to the bottom
safe area / keyboard is **BLOCKED** (`chat.composer.dimension.bottomInset`). The field grows with multi-line text (line
height not measured → platform default leading, `design/tokens/README.md`).

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| camera circle | `chat.composer.dimension.cameraButton`, `color.global.accent`, `icon.global.camera` in `color.global.onAccent` sized `chat.composer.dimension.cameraGlyph` | `chat.composer.a11y.camera` | opens `camera.capture` with this group preselected (`DeepLink.camera(groupID:)`); the photo is sent with `create_post` to this group only and appears as a photo message |
| text field | `chat.composer.dimension.fieldHeight`, `color.global.control`, rim tokens, `radius.global.capsule`, `chat.composer.dimension.fieldPaddingLeading`; typed text: text role `body` in `color.global.textPrimary`; placeholder: `fontSize.global.placeholder` in `color.global.textSecondary` | placeholder `chat.composer.placeholder` ("start typing..."); `chat.composer.a11y.field` | multi-line; `invalid_body` limit 4000 characters is an integrity bound, the UI limit is not sourced |
| send control | **BLOCKED** `chat.composer.layout.typingState` (what replaces / joins the mic when the field has text) | `chat.composer.a11y.send` ("send") | sends `send_message(p_kind: text)`; until captured, the keyboard's return key sends (approximation, Gaps) |
| mic circle | `chat.composer.dimension.sideButton`, `color.global.controlRaised` (lossless median #414141, S-2), `icon.global.mic` in `color.global.textPrimary` sized `chat.composer.dimension.micGlyph` | `chat.composer.a11y.mic` | starts voice recording (`chat.voice.md`; recording UI **BLOCKED**); first use asks for the microphone (system prompt, `system.permissions`) |

## States

| state | what shows | tokens / copy | source |
|---|---|---|---|
| idle | row as above | — | S1 |
| typing | **BLOCKED** (`chat.composer.layout.typingState`) | — | yope-b §2 "Not found: typing state" |
| sending | the message appears in the thread; failure → `chat.thread.sendFailed` | `haptic.global.send` / `haptic.global.error` | — |
| offline | the field stays editable; send fails as above | `chat.thread.sendFailed` | `yope.voice.error` |
| loading / empty / error | not applicable (the composer has no content of its own) | — | — |
| permission-denied (microphone) | the inline card of `chat.voice.md` (Permission) | `chat.voice.permission.*` | `chat.voice.md` |
| permission-denied (camera) | handled by `camera.capture` | — | capture group |

## Motion

Keyboard raise / lower: native (`easing.global.native.keyboard`); the row rides on the keyboard. No other motion observed.
Reduce Motion: system.

## Haptics

| interaction | token |
|---|---|
| text sent | `haptic.global.send` |
| send failed | `haptic.global.error` |
| tap camera / mic | none (HIG "Avoid overusing haptics"; "don't disrupt … the camera … or microphone") |

## Accessibility

- Labels: `chat.composer.a11y.camera`, `chat.composer.a11y.field`, `chat.composer.a11y.mic`, `chat.composer.a11y.send`.
  Traits: buttons; the field is a text field with the placeholder as hint.
- Dynamic Type: typed text → `layout.global.textStyleMap.body`; placeholder → `.placeholder`. The row grows in height
  with the text; circles stay at their size and align to the bottom line.
- Hit targets: circles are 39.5–40.6 pt: extend the hit area to `size.global.minTouchTarget.ios` (44) /
  `.android` (48 dp) without changing the drawn size.
- Focus order: camera → field → mic (→ send).
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | ratio | result | pair |
|---|---|---|---|---|---|
| `color.global.textSecondary` #969696 | `color.global.control` #2E2E2E | text | 4.59:1 | pass | placeholder 'start typing...' 17 regular |
| `color.global.textPrimary` #FFFFFF | `color.global.control` #2E2E2E | text | 13.58:1 | pass | typed text 17 regular |
| `color.global.control` #2E2E2E | `color.global.background` #171717 | nontext | 1.32:1 | **FAIL** | field fill against the background |
| `chat.composer.color.fieldRimTop` #4B4B4B | `color.global.background` #171717 | nontext | 2.06:1 | **FAIL** | field top rim against the background |
| `color.global.accent` #CDFD07 | `color.global.background` #171717 | nontext | 15.07:1 | pass | lime camera circle |
| `color.global.onAccent` #000000 | `color.global.accent` #CDFD07 | nontext | 17.65:1 | pass | camera glyph on lime |
| `color.global.controlRaised` #434343 | `color.global.background` #171717 | nontext | 1.81:1 | **FAIL** | mic circle against the background |
| `color.global.textPrimary` #FFFFFF | `color.global.controlRaised` #434343 | nontext | 9.89:1 | pass | mic glyph on its circle |

  The field and mic fills fail SC 1.4.11 as boundaries; the glyph / placeholder inside each passes, which identifies the
  control. Reported; no sourced alternative (foundations found the same, design/CONTRAST.md).

## Data & actions

- `send_message(p_group_id, p_kind: 'text', p_body)` (docs/API.md §6.2); errors `invalid_body`, `not_group_member`.
- Voice: upload `u/<uid>/voice/<uuid>.m4a`, then `send_message(p_kind: 'voice', p_voice_path, p_voice_duration_ms)` (`chat.voice.md`).
- Photo: `camera.capture` → `create_post(p_group_ids: [this group])` (§6.2, recipe §9.4); a reply to a photo comes from
  `photo.viewer` (`p_reply_to_post_id`).
- Realtime: the sent message arrives through the thread's `messages` INSERT subscription (§8.1).

## Platform notes

- iOS: `TextField(axis: .vertical)`; `.submitLabel(.send)` for the return-key approximation; mic / camera as `Button`s with
  enlarged `contentShape`.
- Android: `BasicTextField` in a capsule `Surface`; `imeAction = ImeAction.Send`; RECORD_AUDIO runtime permission asked
  at the first voice message (design/research/platform.md §system.permissions).
- Microphone access is never asked before a photo can be posted (App Review 5.1.1(iv)).

## Do-not-copy

- The sticker circle (stickers / cut-outs are do-not-build).
- 1:1 quick reactions ❤️ 😂 🔥 inside the field (1:1 space only; reactions on photos are `chat.reactions`).

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| `chat.composer.layout.typingState` (send control) | BLOCKED; approximation: the keyboard return key sends | one screenshot of a Yope group chat with text typed in the field |
| `chat.composer.dimension.bottomInset` | BLOCKED (S1 is a marketing mock: 21.3 pt to the screen bottom, no home indicator) | one device screenshot of a Yope group chat, keyboard down and up |
| multi-line field behaviour (max lines) | not observed | same screenshot with a long text |

# `chat.voice` — voice message (record + playback)

Redesign on **Retro**: Retro has no voice messages, so the surface is **composed of Retro components** — the voice message
is Retro's medium fill capsule (C-06) laid out like its outline CTA (C-07: glyph, then label) carrying a duration in
Retro's media-duration format (C-25 "1:00"); recording reuses the message field (C-13), a circle (C-11) and Retro red (C-10).
Mechanics: **WhatsApp** (press and hold to record, slide to cancel, lock for hands-free; one message plays at a time) and
**Telegram** (elapsed time while playing). Tokens: `design/tokens/social.json` (`chat.voice.*`) + `global.*`. Copy:
`design/copy/social.json` (`chat.voice.*`). Decisions: `design/MERGE_DECISIONS.md` → Redesign — Social (RS-7).
Composition record: `level: SOURCED`, `method: "composition of Retro components C-06, C-07, C-25, C-11, C-13, C-10 in
WhatsApp's record / play order"`.

## References

| id | file | used for |
|---|---|---|
| H43 | `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png` | C-07 anatomy (leading glyph 14.7, gaps 18 / 9.7 / 17) |
| ST-02 | `references/auto/retro/store/retro-store-02.png` | C-06 medium capsules (37 pt, 15 semibold) |
| PAY | `references/auto/retro/lazyweb/retro-lazyweb-20260529-paywall.png` | duration format "1:00", monospaced digits (C-25) |
| WA-V | `references/auto/whatsapp/help/faq-657157755756612-send-voice-iphone.png`, `references/auto/whatsapp/store/whatsapp-store-02.png` | record gestures and the recording row |
| TG | `references/auto/telegram/store/telegram-store-03.png`; Telegram blog "Flexible Playback Speed" (Gap fill G-8) | recording row with lock, "Slide to cancel"; elapsed time while playing |

## Structure — the voice message

A capsule in the message's text column (`chat.thread.layout.runs`), hugging its content (`chat.voice.layout.capsule`):

- fill: `color.global.control` (iOS) / `color.global.surfaceSecondary.android` (Android); on the viewer (media)
  `color.global.controlOnDeep`;
- height `size.global.pillHeight`, corners `radius.global.capsule`;
- `size.global.pillPaddingLeading` → glyph `icon.global.play` (playing: `icon.global.pause`) at `size.global.iconSmall`,
  `color.global.textPrimary` → `size.global.pillIconGap` → duration `chat.voice.layout.durationFormat` ("0:38", monospaced
  digits) in text role `pill`, `color.global.textPrimary` → `size.global.pillPaddingTrailing`.

Playback (`chat.voice.layout.playback`): tap toggles play / pause; the label shows the total length when idle and the
elapsed time while playing or paused mid-way; starting another voice message stops the current one; at the end the
capsule returns to idle. Another member's and your own messages look the same (Retro rows do not separate senders).

## Structure — recording (`chat.voice.layout.recording`)

1. Press and hold the composer's mic glyph: the field's content is replaced, left → right, by `icon.global.mic` in
   `color.global.destructive` (C-10 red glyph), the elapsed time (`chat.voice.layout.durationFormat`, text role `body`,
   monospaced, `color.global.textPrimary`), and — centred in the remaining width — `icon.global.back` +
   `chat.voice.recording.slideToCancel` in `color.global.textSecondary`. The mic glyph stays under the finger.
2. Above the mic glyph, `size.global.pillGap` over the field, a C-11 circle (`size.global.circleButton`,
   `color.global.control`, `icon.global.lock`) — slide up onto it to keep recording hands-free.
3. Lift → send. Slide left past the hint → discard. Locked: the trailing glyphs become `icon.global.trash`
   (`color.global.destructive`, label `chat.voice.a11y.discard`) and `icon.global.send` (`color.global.textPrimary`).
4. Format: AAC in `.m4a`.

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| voice capsule | C-06 fill + C-07 anatomy; `chat.voice.layout.capsule` (`size.global.pillHeight`, `radius.global.capsule`, `size.global.pillPaddingLeading` / `.pillIconGap` / `.pillPaddingTrailing`, `size.global.iconSmall`, text role `pill`) | `chat.voice.a11y.message` / `.messageMine`; action `chat.voice.a11y.play` / `.pause` | tap → play / pause (`chat.voice.layout.playback`); long press → the thread's context menu |
| duration | `chat.voice.layout.durationFormat` | duration (data) | idle: total; playing: elapsed |
| recording row | C-13 field content; `icon.global.mic` (`color.global.destructive`), text role `body`, `color.global.textSecondary` | `chat.voice.recording.slideToCancel` | see Structure |
| lock circle | C-11; `size.global.circleButton`, `color.global.control`, `icon.global.lock`, `size.global.pillGap` | `chat.voice.a11y.lock` | slide up / double-tap → hands-free |
| discard / send (locked) | `icon.global.trash` (`color.global.destructive`), `icon.global.send` | `chat.voice.a11y.discard`, `chat.composer.a11y.send` | discard / send |
| microphone permission | C-29 native alert | `chat.voice.permission.title`, `.permission.detail`, `.permission.button` (opens Settings), cancel `photo.viewer.delete.cancel` | see States |

## States

| state | what shows | tokens · copy | source |
|---|---|---|---|
| idle | play glyph + total duration | — | composition |
| loading (file) | the capsule draws from the message row at once; the glyph is replaced by the platform activity indicator (C-28, `size.global.iconSmall`) until the signed URL's audio starts | `easing.global.native.activityIndicator` | C-28 |
| playing / paused | pause / play glyph, elapsed time | `icon.global.pause` | Telegram (G-8) |
| error (play) | the capsule stays; the duration label is replaced by `chat.voice.error.play` (text role `pill`, `color.global.destructive`); tap retries | `chat.voice.error.play` | `retro.voice.error` |
| error (record / upload) | nothing is sent; Android Toast `chat.voice.error.record`, iOS accessibility announcement; failed send → `chat.thread.sendFailed` | `haptic.global.error` | C-26 |
| offline | recording works; the send fails as above | — | — |
| permission-denied (microphone) | C-29 alert after the system denial: title / detail / "Allow Microphone Access" (opens the app's Settings page) / Cancel | `chat.voice.permission.*`; purpose string `system.permissions.microphone.purpose` (account group) | `retro.voice.permission` |
| empty | not applicable | — | — |

## Motion

| transition | tokens | Reduce Motion |
|---|---|---|
| play ↔ pause glyph | cross-fade `duration.global.crossfade` | same |
| field ↔ recording row | fade `duration.global.fade` + `easing.global.standard` | same fade |
| slide to cancel / to lock | tracks the finger (no curve) | allowed (`layout.global.reduceMotion`: finger-tracked motion stays) |

## Haptics

| interaction | token |
|---|---|
| voice message sent | `haptic.global.send` |
| send / record failed | `haptic.global.error` |
| tap play / pause (Android) | `haptic.global.tap` (iOS none) |
| recording start / stop | none (HIG: haptics must not disturb the microphone) |

## Accessibility

- The capsule is one button: label `chat.voice.a11y.message` / `.messageMine` ("Maya's voice message, 0:38"), action name
  `chat.voice.a11y.play` / `.pause`; `{duration}` is spoken as minutes and seconds.
- Recording without a press-and-hold: the mic's custom action starts recording in the locked state (lock circle label
  `chat.voice.a11y.lock`); discard and send are buttons. The elapsed time is a live region (updates every second, polite).
- Dynamic Type: the label `pill` → subheadline; the capsule grows in height with it (no clipping; C-06 rule).
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | light | dark | pair |
|---|---|---|---|---|---|
| `color.global.textPrimary` | `color.global.control` | text | 18.59:1 pass | 15.13:1 pass | duration 15 semibold, glyph (iOS) |
| `color.global.textPrimary` | `color.global.surfaceSecondary.android` | text | 19.60:1 pass | 15.13:1 pass | the same (Android) |
| `color.global.textOnMedia` | `color.global.controlOnDeep` | text | 15.13:1 pass | 15.13:1 pass | voice note in the viewer |
| `color.global.control` | `color.global.background` | nontext | **1.13:1 FAIL** | **1.39:1 FAIL** | capsule boundary (identified by its glyph and label) |
| `color.global.textSecondary` | `color.global.control` | text | **2.52:1 FAIL** | 5.31:1 pass | "Slide to cancel" (iOS) |
| `color.global.destructive` | `color.global.control` | nontext | 3.70:1 pass | 3.62:1 pass | red recording mic glyph |
| `color.global.destructive` | `color.global.control` | text | **3.70:1 FAIL** | **3.62:1 FAIL** | play-error line in the capsule (15 semibold; also announced) |

## Data & actions

- Send: upload `u/<uid>/voice/<uuid>.m4a` (`contentType` `audio/m4a`), then `send_message(p_group_id, p_kind: 'voice',
  p_voice_path, p_voice_duration_ms)` (docs/API.md §6.2; `invalid_voice`).
- Play: `createSignedURL(voice_path, 3600)` (§7).
- Unsend own: `delete_message` (§6.2) → `message_deleted` broadcast (§8.2).
- A photo's voice note (`posts.voice_path`) plays in `photo.viewer` with the same capsule on media.
- Lives inside `chat.thread`; no deep link of its own.

## Platform notes

- iOS: `AVAudioRecorder` (AAC, `.m4a`) / `AVAudioPlayer`; `AVAudioSession` `.playAndRecord` while recording, `.playback` to
  play; permission `AVAudioApplication.requestRecordPermission` with `NSMicrophoneUsageDescription`
  (`system.permissions.microphone.purpose`).
- Android: `MediaRecorder` (`MPEG_4` / `AAC`), `MediaPlayer` / ExoPlayer; RECORD_AUDIO at first use; after two denials the
  system dialog no longer shows, so the alert's button opens the app's settings page.
- Digits: `.monospacedDigit()` (iOS) / `fontFeatureSettings = "tnum"` (Android Inter).

## Do-not-copy

- Waveform bars, bubble shapes and colours from WhatsApp / Telegram / Messages / Yope (another app's visuals).
- Yope's purpose string naming video reactions.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| a Retro audio component | none exists; composition (RS-7) | — (owner may prefer a waveform: would need a visual reference) |
| `chat.voice.layout.widthRule` (old BLOCKED) | closed: the capsule hugs its label (C-07 rule) | — |
| playback progress beyond the elapsed time | not shown (no Retro progress component for audio) | — |

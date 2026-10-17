# `chat.voice` — voice message (record + playback)

Redesign on **Retro**: Retro has no voice messages, so the surface is **composed of Retro components** — the voice message
is Retro's medium fill capsule (C-06) laid out like its outline CTA (C-07: glyph, then label) carrying the voice waveform
(C-36, owner decision 16) and a duration in Retro's media-duration format (C-25 "1:00"); recording reuses the message field
(C-13), circles (C-11) and Retro red (C-10). Mechanics: **WhatsApp** (press and hold to record, slide to cancel, lock for
hands-free, pause / continue / preview a locked recording; one message plays at a time), **Apple Messages** (play ·
waveform · duration in one row; "Continue Recording") and **Telegram** (elapsed time and played bars while playing; the
waveform data). Tokens: `design/tokens/social.json` (`chat.voice.*`) + `global.*` (`layout.global.waveform`,
`size.global.waveform*`). Copy: `design/copy/social.json` (`chat.voice.*`). Decisions: `design/MERGE_DECISIONS.md` →
Redesign — Social (RS-7), Owner decision 16 (V-*). Measurements: `design/research/voice-waveform.md`.
Composition record: `level: SOURCED`, `method: "composition of Retro components C-06, C-07, C-25, C-36, C-11, C-13, C-10
in WhatsApp's record / play order"`.

## References

| id | file | used for |
|---|---|---|
| H43 | `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png` | C-07 anatomy (leading glyph 14.7, gaps 18 / 9.7 / 17) |
| ST-02 | `references/auto/retro/store/retro-store-02.png` | C-06 medium capsules (37 pt, 15 semibold) |
| PAY | `references/auto/retro/lazyweb/retro-lazyweb-20260529-paywall.png` | duration format "1:00", monospaced digits (C-25) |
| WA-V | `references/auto/whatsapp/help/faq-657157755756612-send-voice-iphone.png`, `references/auto/whatsapp/store/whatsapp-store-02.png` | record gestures and the recording row; pause / preview / continue (FAQ); idle waveform |
| WA-B2 | `references/auto/whatsapp/blog/whatsapp-blog-2022-03-voice-updates.png` | locked recording and paused draft panels (`chat.voice.layout.locked`); bar height ratio, played / unplayed |
| WA-B1 | `references/auto/whatsapp/blog/whatsapp-blog-2022-03-voice-bubbles.png` | one waveform width whatever the duration |
| MSG | `references/auto/imessage/apple-support/messages-audio-message-ios27.png`; iPhone User Guide "Send and receive audio messages" | play · waveform · duration order; bar width / gap; waveform length; Stop / Play / Continue Recording |
| TG | `references/auto/telegram/store/telegram-store-03.png`; `references/auto/telegram/blog/tg-blog-power-saving-playback-speed-t0{2,4,6}.png` (Gap fill G-8) | recording row with lock, "Slide to cancel"; elapsed time and played bars while playing |
| TG-D, TG-API | Telegram Desktop `PaintWaveform` (`history_view_document.cpp`); core.telegram.org `documentAttributeAudio` | width-driven bar count, split bar, no-waveform fallback; 100 five-bit levels |

## Structure — the voice message

A capsule in the message's text column (`chat.thread.layout.runs`), hugging its content (`chat.voice.layout.capsule`):

- fill: `color.global.control` (iOS) / `color.global.surfaceSecondary.android` (Android); on the viewer (media)
  `color.global.controlOnDeep`;
- height `size.global.pillHeight`, corners `radius.global.capsule`;
- `size.global.pillPaddingLeading` → glyph `icon.global.play` (playing: `icon.global.pause`) at `size.global.iconSmall`,
  `color.global.textPrimary` → `size.global.pillIconGap` → the **waveform** (C-36, `chat.voice.dimension.waveform` 154 pt:
  38 bars of `size.global.waveformBarWidth` / `.waveformBarGap`, up to `layout.global.waveform.maxHeightRatio` × 37 =
  20.5 pt) → `size.global.pillIconGap` → duration `chat.voice.layout.durationFormat` ("0:38", monospaced digits) in text
  role `pill`, `color.global.textPrimary` → `size.global.pillPaddingTrailing`.

Playback (`chat.voice.layout.playback`): tap toggles play / pause; the label shows the total length when idle and the
elapsed time while playing or paused mid-way; the waveform's bars are unplayed (`color.global.textSecondary`) when idle
and played (`color.global.textPrimary`; media `color.global.textOnMedia`) up to the progress while playing or paused
mid-way, the bar under the progress split; starting another voice message stops the current one; at the end the capsule
returns to idle. Another member's and your own messages look the same (Retro rows do not separate senders).

Scrubbing (`chat.voice.layout.scrub`; Apple Voice Memos: "drag the waveform left or right" to change where playback
begins): while the note plays or is paused part-way, a horizontal drag that starts on the capsule (past the platform's
touch slop) seeks to the finger's place along the waveform — its share of `chat.voice.dimension.waveform`, clamped to the
note; the played bars and the elapsed label follow the finger; a playing note plays on from there, a paused one stays
paused. A tap still plays / pauses (a drag never toggles); a drag that starts vertically scrolls the thread; an idle
capsule takes no drag (the thread scrolls and the viewer pages through it). No haptic, no playhead dot.

Levels: the note's `voice_levels` (100 values, 0…31). A note without levels (sent before 2026-10-16) draws every bar at
`size.global.waveformBarMinHeight` until it has been played once; then its levels are computed on the device from the
downloaded file (the recording's reduction, `layout.global.waveform.reduction`) and kept for that file.

## Structure — recording (`chat.voice.layout.recording`)

1. Press and hold the composer's mic glyph: the field's content is replaced, left → right, by `icon.global.mic` in
   `color.global.destructive` (C-10 red glyph), the elapsed time (`chat.voice.layout.durationFormat`, text role `body`,
   monospaced, `color.global.textPrimary`), and — centred in the remaining width — `icon.global.back` +
   `chat.voice.recording.slideToCancel` in `color.global.textSecondary`. The mic glyph stays under the finger.
2. Above the mic glyph, `size.global.pillGap` over the field, a C-11 circle (`size.global.circleButton`,
   `color.global.control`, `icon.global.lock`) — slide up onto it to keep recording hands-free.
3. Lift → send. Slide left past the hint → discard. Slide onto the lock → **locked** (below).
4. The recorder samples its peak level every 30 ms (none while paused); the 100 levels (`layout.global.waveform.reduction`)
   are sent with the note. Format: AAC in `.m4a`.

### Locked recording (`chat.voice.layout.locked`, WhatsApp's "Pause/Resume Recording" and "Draft Preview")

Two rows: the field, and `size.global.pillGap` below it a controls row (`size.global.headerButton` high, inside
`size.global.screenMargin`).

| | field (C-13) | controls row |
|---|---|---|
| recording | `icon.global.mic` (destructive) at the avatar's place · elapsed time (`body`, monospaced) · C-36 live waveform across the rest of the field, to the trailing glyph inset | `icon.global.trash` (destructive, bare) · centre C-11 page circle with `icon.global.pause` in `color.global.destructive` (`chat.voice.a11y.pauseRecording`) · C-11 circle in the primary fill (`color.global.accent`, `icon.global.send` in `color.global.onAccent`) |
| paused (draft) | `icon.global.play` / `.pause` (a button: previews the draft) at the avatar's place · C-36 draft waveform with the preview's progress · the draft's length (preview: elapsed) at the trailing glyph inset | trash · centre circle with `icon.global.mic` in `color.global.destructive` (`chat.voice.a11y.resumeRecording`) · send circle |

Pause keeps the draft; continue records on at its end; the preview plays the draft from its start (continuing or sending
stops it); trash deletes the recording; send sends all of it. The live and draft waveforms draw the samples so far across
the available width (WA-B2: 0:07 → 77 bars, the 0:11 draft in its capsule).

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| voice capsule | C-06 fill + C-07 anatomy + C-36; `chat.voice.layout.capsule` (`size.global.pillHeight`, `radius.global.capsule`, `size.global.pillPaddingLeading` / `.pillIconGap` / `.pillPaddingTrailing`, `size.global.iconSmall`, text role `pill`, `chat.voice.dimension.waveform`) | `chat.voice.a11y.message` / `.messageMine`; action `chat.voice.a11y.play` / `.pause` | tap → play / pause (`chat.voice.layout.playback`); playing / paused part-way: horizontal drag → seek (`chat.voice.layout.scrub`); long press → the thread's context menu |
| waveform | C-36; `layout.global.waveform`, `size.global.waveformBarWidth` / `.waveformBarGap` / `.waveformBarMinHeight`, `color.global.textPrimary` / `.textOnMedia` / `.textSecondary` | — (decorative) | played part follows the playback and the finger while scrubbing (x ÷ width = the position) |
| duration | `chat.voice.layout.durationFormat` | duration (data) | idle: total; playing: elapsed |
| recording row | C-13 field content; `icon.global.mic` (`color.global.destructive`), text role `body`, `color.global.textSecondary` | `chat.voice.recording.slideToCancel` | see Structure |
| lock circle | C-11; `size.global.circleButton`, `color.global.control`, `icon.global.lock`, `size.global.pillGap` | `chat.voice.a11y.lock` | slide up / double-tap → hands-free |
| locked field | C-13 + C-36; `chat.voice.layout.locked` | elapsed (live region) | live waveform; paused: draft waveform + preview glyph |
| preview glyph (paused) | `icon.global.play` / `.pause`, `color.global.textPrimary`, hit `size.global.headerButton` | `chat.voice.a11y.play` ({duration} = the draft) / `.pause` | plays / pauses the draft |
| delete | `icon.global.trash` (`color.global.destructive`), bare glyph | `chat.voice.a11y.discard` | deletes the recording |
| pause / continue | C-11 page circle, `icon.global.pause` / `icon.global.mic` in `color.global.destructive` | `chat.voice.a11y.pauseRecording` / `.resumeRecording` | pauses / continues the recording |
| send (locked) | C-11 circle, `color.global.accent` fill, `icon.global.send` in `color.global.onAccent` | `chat.composer.a11y.send` | sends the recording |
| microphone permission | C-29 native alert | `chat.voice.permission.title`, `.permission.detail`, `.permission.button` (opens Settings), cancel `photo.viewer.delete.cancel` | see States |

## States

| state | what shows | tokens · copy | source |
|---|---|---|---|
| idle | play glyph, every bar unplayed, total duration | `color.global.textSecondary` bars | WA-S, TG-D |
| loading (file) | the capsule draws from the message row at once; the glyph is replaced by the platform activity indicator (C-28, `size.global.iconSmall`) until the signed URL's audio starts | `easing.global.native.activityIndicator` | C-28 |
| playing / paused | pause / play glyph, played bars up to the progress, elapsed time | `icon.global.pause` | Telegram (G-8), TG-D |
| no stored levels | every bar a dot (`size.global.waveformBarMinHeight`); after the first play the computed levels | `layout.global.waveform.fallback` | TG-D |
| error (play) | the capsule stays; the waveform and the duration give way to `chat.voice.error.play` (text role `pill`, `color.global.destructive`); tap retries | `chat.voice.error.play` | `retro.voice.error` |
| recording (holding) | red mic, elapsed, "‹ Slide to cancel", lock circle | `chat.voice.layout.recording` | WA-V, TG |
| recording (locked) | red mic, elapsed, live waveform; trash · pause · send | `chat.voice.layout.locked` | WA-B2 |
| paused draft | preview glyph, draft waveform, length; trash · continue · send | `chat.voice.layout.locked` | WA-B2, WA-V, MSG |
| error (record / upload) | nothing is sent; Android Toast `chat.voice.error.record`, iOS accessibility announcement; failed send → `chat.thread.sendFailed` | `haptic.global.error` | C-26 |
| offline | recording works; the send fails as above | — | — |
| permission-denied (microphone) | C-29 alert after the system denial: title / detail / "Allow Microphone Access" (opens the app's Settings page) / Cancel | `chat.voice.permission.*`; purpose string `system.permissions.microphone.purpose` (account group) | `retro.voice.permission` |
| empty | not applicable | — | — |

## Motion

| transition | tokens | Reduce Motion |
|---|---|---|
| play ↔ pause glyph | cross-fade `duration.global.crossfade` | same |
| field ↔ recording row; locked rows; recording ↔ paused | fade `duration.global.fade` + `easing.global.standard` | same fade |
| slide to cancel / to lock | tracks the finger (no curve) | allowed (`layout.global.reduceMotion`: finger-tracked motion stays) |
| played bars / live waveform | follow the playback / each sample, no animation | same |
| scrubbing | the played bars and the label track the finger (no curve) | allowed (finger-tracked) |

## Haptics

| interaction | token |
|---|---|
| voice message sent | `haptic.global.send` |
| send / record failed | `haptic.global.error` |
| tap play / pause (Android) | `haptic.global.tap` (iOS none) |
| recording start / stop / pause / continue | none (HIG: haptics must not disturb the microphone) |

## Accessibility

- The capsule is one button: label `chat.voice.a11y.message` / `.messageMine` ("Maya's voice message, 0:38"), action name
  `chat.voice.a11y.play` / `.pause`; `{duration}` is spoken as minutes and seconds. The waveform is decorative (hidden).
- Scrubbing without a drag (`chat.voice.layout.scrub`): while the note plays or is paused part-way the capsule is also
  adjustable — VoiceOver swipe up / down (`accessibilityAdjustableAction`,
  https://developer.apple.com/documentation/swiftui/view/accessibilityadjustableaction(_:)), TalkBack's adjust (a progress
  range 0…duration with `SemanticsActions.SetProgress`; on the thread row and the viewer's reply row, whose semantics
  replace the capsule's) — moving `stepMs` (5 s; YouTube's seek-bar arrows "Seek backward/forward 5 seconds",
  https://support.google.com/youtube/answer/7631406) forward / back, clamped to the note; the value reads the elapsed time
  in the `{duration}` format. Idle: no change.
- Recording without a press-and-hold: the mic's custom action starts recording in the locked state (lock circle label
  `chat.voice.a11y.lock`); delete, pause / continue, preview and send are buttons. The elapsed time is a live region
  (updates every second, polite); paused, the field reads the draft's length.
- Dynamic Type: the label `pill` → subheadline; the capsule grows in height with it (no clipping; C-06 rule); the bars keep
  their ratio of the capsule's height.
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | light | dark | pair |
|---|---|---|---|---|---|
| `color.global.textPrimary` | `color.global.control` | text | 18.59:1 pass | 15.13:1 pass | duration 15 semibold, glyph, played bars (iOS) |
| `color.global.textPrimary` | `color.global.surfaceSecondary.android` | text | 19.60:1 pass | 15.13:1 pass | the same (Android) |
| `color.global.textOnMedia` | `color.global.controlOnDeep` | text | 15.13:1 pass | 15.13:1 pass | voice note in the viewer |
| `color.global.textSecondary` | `color.global.control` | nontext | 2.52:1 (decorative) | 5.31:1 | unplayed bars (iOS; Android #F7F7F7 2.66:1) |
| `color.global.textSecondary` | `color.global.controlOnDeep` | nontext | 5.31:1 | 5.31:1 | unplayed bars on media |
| `color.global.control` | `color.global.background` | nontext | **1.13:1 FAIL** | **1.39:1 FAIL** | capsule boundary (identified by its glyph and label) |
| `color.global.textSecondary` | `color.global.control` | text | **2.52:1 FAIL** | 5.31:1 pass | "Slide to cancel" (iOS) |
| `color.global.destructive` | `color.global.control` | nontext | 3.70:1 pass | 3.62:1 pass | red recording mic glyph, pause / continue glyphs |
| `color.global.onAccent` | `color.global.accent` | nontext | 21:1 pass | 21:1 pass | send circle |
| `color.global.destructive` | `color.global.control` | text | **3.70:1 FAIL** | **3.62:1 FAIL** | play-error line in the capsule (15 semibold; also announced) |

## Data & actions

- Send: upload `u/<uid>/voice/<uuid>.m4a` (`contentType` `audio/m4a`), then `send_message(p_group_id, p_kind: 'voice',
  p_voice_path, p_voice_duration_ms, p_voice_levels)` (docs/API.md §6.2; `invalid_voice`).
- Play: `createSignedURL(voice_path, 3600)` (§7).
- Unsend own: `delete_message` (§6.2) → `message_deleted` broadcast (§8.2).
- A photo's voice note (`posts.voice_path`, `posts.voice_levels`) plays in `photo.viewer` with the same capsule on media.
- Lives inside `chat.thread`; no deep link of its own.

## Platform notes

- iOS: `AVAudioRecorder` (AAC, `.m4a`, `isMeteringEnabled`, `peakPower(forChannel:)` dBFS → linear) / `AVAudioPlayer`;
  pause `pause()`, continue `record()`; `AVAudioSession` `.playAndRecord` while recording, `.playback` to play;
  permission `AVAudioApplication.requestRecordPermission` with `NSMicrophoneUsageDescription`
  (`system.permissions.microphone.purpose`).
- Android: `MediaRecorder` (`MPEG_4` / `AAC`; `getMaxAmplitude()` ÷ 32767), pause `pause()`, continue `resume()` (API 24;
  minSdk 26), ExoPlayer; RECORD_AUDIO at first use; after two denials the system dialog no longer shows, so the alert's
  button opens the app's settings page.
- Draft preview: an MPEG-4 file is finished only by `stop()`, so the first preview of a paused draft closes the open
  segment; continuing records a new segment; sending joins the segments into one `.m4a` (iOS `AVMutableComposition` +
  `AVAssetExportSession`, Android `MediaExtractor` + `MediaMuxer`).
- Digits: `.monospacedDigit()` (iOS) / `fontFeatureSettings = "tnum"` (Android Inter).

## Do-not-copy

- Bubble shapes and colours from WhatsApp / Telegram / Messages / Yope; WhatsApp's playhead dot and green send circle;
  Telegram's accent bars and unread state; Messages' blue bubble. Only the waveform mechanic is taken (C-36).
- Yope's purpose string naming video reactions.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| a Retro audio component | none exists; composition (RS-7) + C-36 (owner decision 16) | — |
| `chat.voice.layout.widthRule` (old BLOCKED) | closed: the capsule hugs its content (fixed waveform length) | — |
| playback progress beyond the elapsed time | closed: played bars (C-36) | — |
| scrubbing by dragging along the waveform (WhatsApp, Messages) | closed: `chat.voice.layout.scrub` — a horizontal drag on a playing / paused capsule seeks (Apple Voice Memos' waveform drag), the tap stays play / pause; VoiceOver / TalkBack adjust in 5-s steps | — |

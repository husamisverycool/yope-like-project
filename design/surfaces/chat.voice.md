# `chat.voice` — voice message (record + playback)

Reference app: **Yope** group chat (`docs/SURFACES.md`). Research: `design/research/yope-b.md` §3 (playback, one source),
release note v1.210.0–1.212.1 ("send voice messages in chat"). Tokens: `design/tokens/social.json` (`chat.voice.*`) +
`global.*`. Copy: `design/copy/social.json` (`chat.voice.*`).

## References

| id | file | used for |
|---|---|---|
| S1 | `references/auto/yope/store/yope-store-05.png` (lossless); coordinates in `references/auto/yope/frames/b-derot-store-05-rot-1.68.png` | the only voice bubble observed (mine, 0:38); colours re-sampled on lossless pixels (S-2) |
| S3 / O1 | `references/auto/yope/frames/b-play-04.png`, `references/owner/yope-04-chat.webp` | same panel (cross-check) |
| W1 | `references/auto/yope/store/listing.html` v1.210.0–1.212.1 | feature confirmation and the noun "voice messages" |
| V-chuong | `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png` | inline permission card pattern ("can’t see your friends?" / "enable contacts" / "enable") |

## Structure — playback bubble (mine, right-aligned like a text bubble)

Bubble `chat.voice.dimension.width` (271.8) × `chat.voice.dimension.height` (44.9), corners `chat.voice.radius.bubble` (14),
fill `chat.voice.color.bubble`, right edge at `chat.thread.dimension.bubbleInsetMine`. Inside, on one centre line:

1. **Play circle** `chat.voice.dimension.playButton` (31.5) at `chat.voice.dimension.playInsetLeading` (8) from the left,
   vertically centred; fill `chat.voice.color.playButton`; ▶ `icon.global.play` in `color.global.textPrimary`,
   `chat.voice.dimension.playGlyph` wide.
2. Gap `chat.voice.dimension.playToWaveform` (7.8).
3. **Waveform**: vertical bars `chat.voice.dimension.barWidth` (3.1) wide at `chat.voice.dimension.barPitch` (6.1), rounded
   ends, centred on the line, heights from the recording's level envelope between `chat.voice.dimension.barMinHeight` (9.3)
   and `chat.voice.dimension.barMaxHeight` (31.5); colour `chat.voice.color.waveform`; as many bars as fit.
4. Gap `chat.voice.dimension.waveformToDuration` (8.9).
5. **Duration** `chat.voice.layout.durationFormat` (`mm:ss`, "00:38"), text role `caption` (`fontSize.global.caption` 12,
   `fontWeight.global.caption` semibold), `chat.voice.color.duration`, `chat.voice.dimension.durationTrailing` (9.7) from
   the right edge.

Another member's voice message: left-aligned at `chat.thread.dimension.bubbleInsetTheirs` with the avatar rule of
`chat.thread`; its fill is **BLOCKED** (`chat.voice.color.bubbleTheirs`). Width for other durations: **BLOCKED**
(`chat.voice.layout.widthRule`); the observed width is used for all (Gaps).

## Structure — recording

**BLOCKED** (`chat.voice.layout.recording`): hold vs tap, lock, cancel, live waveform and timer were not observed. The mic
circle (`chat.composer.md`) is the entry. Upload format: AAC in `.m4a` (`audio/m4a`, docs/API.md §7).

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| bubble | `chat.voice.dimension.width`, `.height`, `chat.voice.radius.bubble`, `chat.voice.color.bubble` (theirs **BLOCKED**) | `chat.voice.a11y.messageMine` / `chat.voice.a11y.message` | long press → context menu (`chat.thread.menu.delete` own / `chat.thread.menu.report` others) |
| play circle | `chat.voice.dimension.playButton`, `.playInsetLeading`, `chat.voice.color.playButton`, `icon.global.play`, `chat.voice.dimension.playGlyph`; playing glyph **BLOCKED** (`chat.voice.icon.pause`) | `chat.voice.a11y.play` / `chat.voice.a11y.pause` | tap plays from the start / pauses; one voice message plays at a time |
| waveform | `chat.voice.dimension.barWidth`, `.barPitch`, `.barMinHeight`, `.barMaxHeight`, `chat.voice.color.waveform`; played part **BLOCKED** (`chat.voice.color.waveformPlayed`) | — (decorative) | — |
| duration | text role `caption`, `chat.voice.color.duration`, `chat.voice.layout.durationFormat` | duration (data) | shows the total length (counting down during playback not observed) |
| permission card | Yope's inline permission card, same tokens as the contacts card: `onboarding.permission.contacts.color.card`, `.size.cardHeight`, `.size.cardMarginH`, `.fontSize.cardTitle` / `.fontWeight.cardTitle` (`color.global.textPrimary`), `.fontSize.cardDetail` (`color.global.textSecondary`), white button `.size.cardButtonWidth` / `.cardButtonHeight` in `color.global.surfaceLight` / `color.global.onSurfaceLight`, `onboarding.permission.contacts.layout.card`, corners `radius.global.card` | `chat.voice.permission.title`, `.detail`, `.button` | see States |

## States

| state | what shows | tokens / copy | source |
|---|---|---|---|
| loading (file) | the bubble draws at once from the message row; playback starts once the signed URL loads (platform buffering) | — | — |
| playing | **BLOCKED** (pause glyph, progress colour) | `chat.voice.icon.pause`, `chat.voice.color.waveformPlayed` | yope-b §3 |
| error (play) | the bubble stays; a failed-state visual was not observed → **BLOCKED** (same capture as the playing state); the string is announced to VoiceOver / TalkBack | `chat.voice.error.play` | `yope.voice.error` |
| error (record / upload) | message not sent: `chat.voice.error.record`; failed send as `chat.thread.sendFailed` | `haptic.global.error` | `yope.voice.error` |
| offline | recording works; sending fails as above | `chat.thread.sendFailed` | — |
| permission-denied (microphone) | Yope's inline permission card above the composer: bold question, gray detail, white "enable" pill (opens system Settings) | `chat.voice.permission.title` ("can’t send voice messages?"), `.detail` ("enable your mic"), `.button` ("enable"); card tokens as in Elements | V-chuong t7.73 (`yope.voice.permission`); purpose string `system.permissions.microphone.purpose` (system.permissions group) |
| empty | not applicable | — | — |

## Motion

None measured (yope-b §10 "Not found: voice record/playback"). Playback progress motion **BLOCKED** with the playing state.
Reduce Motion: no custom motion to substitute.

## Haptics

| interaction | token |
|---|---|
| voice message sent | `haptic.global.send` |
| send failed | `haptic.global.error` |
| long press (context menu) | `haptic.global.longPressStart` |
| recording start / stop | none (HIG: haptics must not disrupt the microphone; recording UI BLOCKED) |

## Accessibility

- Bubble label `chat.voice.a11y.messageMine` / `.message` (`{duration}` spoken as minutes and seconds); play button
  `chat.voice.a11y.play` / `.pause`; waveform hidden from VoiceOver / TalkBack (decorative).
- Dynamic Type: duration → `layout.global.textStyleMap.caption`; the bubble keeps its height up to the caption's growth.
- Play circle 31.5 pt: hit area extended to 44 pt / 48 dp.
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | ratio | result | pair |
|---|---|---|---|---|---|
| `chat.voice.color.duration` #929292 | `chat.voice.color.bubble` #262626 | text | 4.86:1 | pass | duration '00:38' 12 semibold |
| `chat.voice.color.waveform` #919191 | `chat.voice.color.bubble` #262626 | nontext | 4.80:1 | pass | waveform bars |
| `chat.voice.color.playButton` #333333 | `chat.voice.color.bubble` #262626 | nontext | 1.20:1 | **FAIL** | play circle against the bubble |
| `color.global.textPrimary` #FFFFFF | `chat.voice.color.playButton` #333333 | nontext | 12.63:1 | pass | play glyph on its circle |
| `chat.voice.color.bubble` #262626 | `color.global.background` #171717 | nontext | 1.18:1 | **FAIL** | voice bubble against the background |

  The ▶ glyph (12.63:1) identifies the control; the circle and bubble fills are boundaries only. Reported.

## Data & actions

- Send: upload to `u/<uid>/voice/<uuid>.m4a` (`contentType` `audio/m4a`), then
  `send_message(p_group_id, p_kind: 'voice', p_voice_path, p_voice_duration_ms)` (docs/API.md §6.2; `invalid_voice`).
- Play: `createSignedURL(voice_path, 3600)` (§7; readable by members once the message exists).
- Delete own: `delete_message` (§6.2) → `message_deleted` broadcast (§8.2).
- A photo's voice note (`posts.voice_path`) plays in `photo.viewer` with this same bubble (position BLOCKED there).
- Navigation: lives inside `chat.thread`; no deep link of its own.

## Platform notes

- iOS: `AVAudioRecorder` (AAC, `.m4a`) / `AVAudioPlayer`; `AVAudioSession` category `.playAndRecord` while recording,
  `.playback` for playing; microphone permission via `AVAudioApplication.requestRecordPermission` with
  `NSMicrophoneUsageDescription` (string owned by `system.permissions`).
- Android: `MediaRecorder` (`AAC_ADTS`/`MPEG_4`) and `MediaPlayer`/`ExoPlayer`; RECORD_AUDIO runtime permission at first
  use; after two denials the system dialog no longer appears, so the card's "enable" opens app settings.
- Level envelope for the waveform: computed from the recorded samples on the sender's device would need storing; the
  API stores no envelope, so the receiving client computes it from the downloaded file.

## Do-not-copy

- "We need your mic to record your voice in video reactions." (Yope's purpose string names video reactions, a feature we
  do not have; the purpose string is `system.permissions`'s).
- Face-swap stickers announced with voice (release note) — stickers do-not-build.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| `chat.voice.layout.recording` | BLOCKED | 15-s screen recording of recording, sending and playing a voice message in a Yope group chat (yope-b §3) |
| `chat.voice.icon.pause`, `chat.voice.color.waveformPlayed` | BLOCKED | same recording |
| `chat.voice.color.bubbleTheirs` | BLOCKED | one screenshot of another member's voice message |
| `chat.voice.layout.widthRule` | BLOCKED; approximation: fixed observed width | one screenshot with two voice messages of different lengths |
| failed playback visual | BLOCKED (string ready) | same recording with airplane mode |

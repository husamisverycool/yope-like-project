# Verification — `chat.voice` (iOS)

Voice messages: the capsule in the thread and the viewer, the recording row with slide-to-cancel and lock — `ios/App/Sources/Features/Social/UI/VoiceUI.swift` (`VoiceCapsule`, `SocialVoicePlayback`, `SocialVoiceRecorder`) and the recording row of `ChatComposer.swift`.

Pass 4 (Retro redesign). Checklist written from the spec (`design/surfaces/chat.voice.md`, MERGE "Redesign — Social (RS-*)", lead L-3 / L-4) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>-<light|dark>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/chat.voice.png` next to the Retro reference(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level). Components are the Pass 3 library (`ios/App/Sources/Components`, C-01…C-35).

Retro reference(s): `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png (C-07 anatomy)`, `references/auto/retro/store/retro-store-02.png`, `references/auto/whatsapp/help/faq-657157755756612-send-voice-iphone.png`

Snapshots (CI): `chat.voice-idle-light.png`, `chat.voice-idle-dark.png`, `chat.voice-recording-light.png`, `chat.voice-recording-locked-light.png`, `chat.voice-recording-locked-dark.png`, `chat.voice-recording-paused-light.png`, `chat.voice-recording-paused-dark.png`, `chat.voice-error-play-light.png` (the recording states on the loaded thread, owner decision 16; C-36 alone: `components/testC36VoiceWaveform.*`)

**Summary: 27 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Elements

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `chat.voice.layout.capsule`<br>`size.global.pillHeight`<br>`radius.global.capsule`<br>`size.global.pillPaddingLeading`<br>`size.global.pillIconGap`<br>`size.global.pillPaddingTrailing`<br>`size.global.iconSmall`<br>`chat.voice.a11y.message`<br>`chat.voice.a11y.messageMine`<br>`chat.voice.a11y.play`<br>`chat.voice.a11y.pause`<br>`chat.voice.layout.playback` | component: C-06 fill capsule with the anatomy of C-07: leading glyph, then the label; height: size.global.pillHeight; corners: radius.global… (SOURCED)<br>37 pt (SOURCED)<br>shape: capsule; radius: height / 2 (SOURCED)<br>18 pt (SOURCED)<br>9.7 pt (SOURCED)<br>17 pt (SOURCED)<br>14.7 pt (SOURCED)<br>“{name}'s voice message, {duration}” (SOURCED)<br>“Your voice message, {duration}” (SOURCED)<br>“Play voice message, {duration}” (SOURCED)<br>“Pause” (SOURCED)<br>tap: the capsule toggles play / pause; one voice message plays at a time (starting another stops the first); label: total duration when idle… (SOURCED) | voice capsule | `VoiceCapsule`: C-06 fill capsule (`control` / `controlOnDeep` on media), min height `pillHeight`, `pillPaddingLeading` → glyph (`iconSmall`) → `pillIconGap` → label (`pill`, monospaced digits) → `pillPaddingTrailing`, hugs its content; one button labelled `a11y.message` / `.messageMine`, action play / pause |
| matched | `chat.voice.layout.durationFormat` | pattern: m:ss; example: 0:38; digits: monospaced (SOURCED) | duration | `SocialFormat.duration` with `chat.voice.layout.durationFormat.pattern` (m:ss); idle total, playing / paused elapsed |
| matched | `icon.global.mic`<br>`color.global.destructive`<br>`color.global.textSecondary`<br>`chat.voice.recording.slideToCancel` | ios: mic; android: Outlined.Mic (PLATFORM)<br>#EA3337 (SOURCED)<br>#999999 (SOURCED)<br>“Slide to cancel” (SOURCED) | recording row | `recordingRow`: `icon.global.mic` in `destructive` in the avatar's place, elapsed time (`body`, monospaced), "‹ Slide to cancel" (`textSecondary`) following the finger |
| matched | `size.global.circleButton`<br>`color.global.control`<br>`icon.global.lock`<br>`size.global.pillGap`<br>`chat.voice.a11y.lock` | 36 pt (SOURCED)<br>light #F1F1F1 / dark #262626 (SOURCED)<br>ios: lock.fill; android: Rounded.Lock (PLATFORM)<br>8.8 pt (SOURCED)<br>“Keep recording” (SOURCED) | lock circle | C-11 `CircleButtonFace(icon: lock)` `pillGap` above the field over the mic while holding; slide up past it locks; VoiceOver's default action records hands-free |
| matched | `layout.global.waveform`<br>`size.global.waveformBarWidth`<br>`size.global.waveformBarGap`<br>`size.global.waveformBarMinHeight`<br>`chat.voice.dimension.waveform`<br>`color.global.textSecondary`<br>`color.global.textPrimary` | C-36: bar count ⌊(width + gap) ÷ (bar + gap)⌋ ≤ 100, peak per bucket, heights min → 0.553 × holder, capsule ends (SOURCED)<br>2.0 pt (SOURCED)<br>2.1 pt (SOURCED)<br>2.0 pt (SOURCED)<br>154 pt (SOURCED)<br>#999999 (SOURCED)<br>light #000000 / dark #FFFFFF (SOURCED) | waveform in the capsule (owner decision 16) | `VoiceWaveform` (Components, C-36) between the glyph and the duration, `chat.voice.dimension.waveform` wide; `WaveformBars` (AppModels) gives count / heights / played share — unit-tested (AppModelsTests: 154 pt → 38 bars, 0.553 × 37 = 20.46 pt tallest, split bar at the edge); idle all unplayed, playing / paused part-way played bars up to the progress; no levels → dots, or levels computed from the audio (`AudioLevels`, Telegram Desktop's fallback); `.accessibilityHidden(true)` |
| matched | `layout.global.waveform`<br>`docs/API.md §5.8 / §5.9 voice_levels` | 100 values of 0…31 per note (Telegram documentAttributeAudio waveform) (SOURCED) | stored levels | `VoiceLevels.reduce` of the recorder's peak power every 30 ms (`AVAudioRecorder` metering); sent as `p_voice_levels` with `send_message` / `create_post`; server validates 100 × 0…31 (backend tests) |
| matched | `chat.voice.layout.locked`<br>`chat.voice.a11y.pauseRecording`<br>`size.global.headerButton`<br>`size.global.circleButton` | rows: field, then controls `size.global.pillGap` below (SOURCED)<br>“Pause recording” (SOURCED)<br>(SOURCED)<br>36 pt (SOURCED) | locked recording | field: red mic · elapsed (monospaced) · C-36 live waveform; controls: trash (red) · C-11 page circle with `icon.global.pause` in red · C-11 primary circle with send; snapshots `recording-locked-light/-dark` |
| matched | `chat.voice.layout.locked`<br>`chat.voice.a11y.resumeRecording`<br>`chat.voice.a11y.play` / `.pause` | paused: preview glyph · draft waveform with the preview's progress · length (SOURCED)<br>“Continue recording” (SOURCED)<br>(SOURCED) | paused draft | `AVAudioRecorder.pause()`; the preview closes the open segment and plays the draft from its start; continue records a new segment (`record()`), segments joined on send (`AVMutableComposition`); `VoiceRecordingSession` state machine unit-tested; snapshots `recording-paused-light/-dark` |
| matched | `icon.global.trash`<br>`color.global.destructive`<br>`icon.global.send`<br>`chat.voice.a11y.discard`<br>`chat.composer.a11y.send` | ios: trash; android: Outlined.Delete (PLATFORM)<br>#EA3337 (SOURCED)<br>ios: paperplane; android: AutoMirrored.Outlined.Send (PLATFORM)<br>“Delete recording” (SOURCED)<br>“Send” (SOURCED) | discard / send (locked) | locked: `icon.global.trash` (`destructive`) discards, `icon.global.send` sends |
| matched | `chat.voice.permission.title`<br>`chat.voice.permission.detail`<br>`chat.voice.permission.button`<br>`photo.viewer.delete.cancel` | “Microphone Access” (SOURCED)<br>“Voice messages use your microphone. Only people in this group can hear them.” (SOURCED)<br>“Allow Microphone Access” (SOURCED)<br>“Cancel” (PLATFORM) | microphone permission | native `.alert` in `ChatThreadView`: title, detail, "Allow Microphone Access" (opens Settings), Cancel |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `—` | — | idle | play glyph + total |
| matched | `size.global.iconSmall` | 14.7 pt (SOURCED) | loading (file) | `ProgressView` in the glyph slot while `SocialVoicePlayback` downloads (signed URL) |
| matched | `icon.global.pause` | ios: pause.fill; android: Rounded.Pause (PLATFORM) | playing / paused | pause / play glyph and elapsed time (one message plays at a time; resume from a pause) |
| matched | `chat.voice.error.play`<br>`color.global.destructive` | “Error loading voice message. Tap to retry” (SOURCED)<br>#EA3337 (SOURCED) | error (play) | `chat.voice.error.play` (`pill`, `destructive`) in the label slot; a tap retries |
| matched | `chat.voice.error.record`<br>`chat.thread.sendFailed`<br>`haptic.global.error` | “Couldn't record voice message” (SOURCED)<br>“Couldn't send. Tap to retry” (SOURCED)<br>ios: notification.error; android: REJECT (PLATFORM) | error (record / upload) | `voiceRecordingFailed()` → announcement (`recordFailed`) + `haptic.global.error`; failed send → failed-message layout (unit-tested) |
| matched | `—` | — | offline | recording works; the send fails as above |
| matched | `chat.voice.permission.*`<br>`system.permissions.microphone.purpose` | (each key of the group)<br>“The app uses your microphone to record voice notes and the sound in videos you share with your group…” (VERIFIED) | permission-denied (microphone) | the alert after the system denial (`onMicDenied`) |
| matched | `—` | — | empty | n/a |

## Motion

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `duration.global.crossfade` | 100 ms (SOURCED) | play ↔ pause glyph | `ComponentMotion.crossfade` on the glyph |
| matched | `duration.global.fade`<br>`easing.global.standard` | 150 ms (SOURCED)<br>x1: 0.4; y1: 0; x2: 0.2; y2: 1 (SOURCED) | field ↔ recording row | `ComponentMotion.fade` on `recorder.isActive` |
| matched | `layout.global.reduceMotion` | ios: UIAccessibility.isReduceMotionEnabled / @Environment(\.accessibilityReduceMotion); android: Settings.Global.ANIMATOR_DURATION_SCALE ==… (PLATFORM) | slide to cancel / to lock | finger-tracked offset, no curve |

## Haptics

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `haptic.global.send` | ios: notification.success; android: CONFIRM (PLATFORM) | voice message sent | `.sent` → `haptic.global.send` |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | send / record failed | `.failed` → `haptic.global.error` |
| matched | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | tap play / pause (Android) | none on iOS |
| matched | `—` | — | recording start / stop / pause / continue | none (`chat.voice.layout.recording` haptic: the microphone) |

## Notes

- The recording states are recorded on the loaded thread (header + messages) with the recorder injected (`ChatThreadView(model:recorder:)`), so the review shows the real screen. Snapshots of the playing state need audio and are not recorded; the recording rows are drawn through the DEBUG `showRecordingForSnapshot` hook (no microphone in tests); the permission alert is a system alert (not drawn by the snapshot renderer).

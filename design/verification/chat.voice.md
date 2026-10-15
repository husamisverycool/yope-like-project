# Verification — `chat.voice` (iOS)

Voice message bubble (playback; recording BLOCKED) — `ios/App/Sources/Features/Social/UI/VoiceUI.swift` (`VoiceBubble`, `Waveform`, `SocialVoicePlayback`, `VoiceEnvelope`).

Checklist written from the spec (`design/surfaces/chat.voice.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`), then `tools/sidebyside.py` makes `design/verification/chat.voice.png` next to the reference image(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level).

Reference image(s): `references/auto/yope/store/yope-store-05.png`, `references/auto/yope/frames/b-derot-store-05-rot-1.68.png`, `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png`

Snapshots (CI): `chat.voice-playback.png`, `chat.voice-permission-denied.png`

**Summary: 10 matched · 4 approximated · 3 not matched (BLOCKED or not buildable).**

## Bubble

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `chat.voice.dimension.width`<br>`chat.voice.dimension.height`<br>`chat.voice.radius.bubble`<br>`chat.voice.color.bubble` | 271.8 pt (SOURCED)<br>44.9 pt (SOURCED)<br>14 pt (SOURCED)<br>#262626 (SOURCED) | my bubble 271.8 × 44.9, corners 14 | frame(width:) + frame(minHeight:), RoundedRectangle fill |
| not matched | `chat.voice.color.bubbleTheirs` | #2B2B2B (SOURCED) | another member’s fill | BLOCKED: drawn without a fill (SocialBlocked.voiceBubbleTheirs) |
| approximated | `chat.voice.layout.widthRule` | BLOCKED | width per duration | BLOCKED: the observed width for every duration |
| matched | `chat.thread.dimension.bubbleInsetMine`<br>`chat.thread.dimension.bubbleInsetTheirs` | 23 pt (SOURCED)<br>50.5 pt (SOURCED) | alignment as text bubbles | same row layout as text |
| matched | `chat.voice.dimension.playButton`<br>`chat.voice.dimension.playInsetLeading`<br>`chat.voice.color.playButton`<br>`icon.global.play`<br>`chat.voice.dimension.playGlyph` | 31.5 pt (SOURCED)<br>8 pt (SOURCED)<br>#333333 (SOURCED)<br>ios: play.fill; android: Rounded.PlayArrow (PLATFORM)<br>11.5 pt (SOURCED) | play circle | circle with ▶; hit area 44 with the drawn position kept |
| matched | `chat.voice.dimension.playToWaveform`<br>`chat.voice.dimension.barWidth`<br>`chat.voice.dimension.barPitch`<br>`chat.voice.dimension.barMinHeight`<br>`chat.voice.dimension.barMaxHeight`<br>`chat.voice.color.waveform` | 7.8 pt (SOURCED)<br>3.1 pt (SOURCED)<br>6.1 pt (SOURCED)<br>9.3 pt (SOURCED)<br>31.5 pt (SOURCED)<br>#919191 (SOURCED) | waveform bars from the level envelope | RMS envelope computed off the main thread once per file and cached; bars resampled to the width |
| matched | `chat.voice.dimension.waveformToDuration`<br>`chat.voice.dimension.durationTrailing`<br>`chat.voice.layout.durationFormat`<br>`fontSize.global.caption`<br>`fontWeight.global.caption`<br>`chat.voice.color.duration` | 8.9 pt (SOURCED)<br>9.7 pt (SOURCED)<br>pattern: mm:ss; example: 00:38 (SOURCED)<br>12 pt (SOURCED)<br>semibold (SOURCED)<br>#929292 (SOURCED) | duration “00:38” | DateFormatter mm:ss (UTC), TextRole.caption |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `—` | — | loading (file): the bubble draws at once | drawn from the message row; waveform when levels arrive (cached thereafter) |
| not matched | `chat.voice.icon.pause`<br>`chat.voice.color.waveformPlayed` | ios: pause.fill; android: Rounded.Pause (PLATFORM)<br>#FFFFFF (SOURCED) | playing | BLOCKED: ▶ stays, no played colour; VoiceOver hears “pause” |
| approximated | `chat.voice.error.play` | “couldn’t play this voice message” (SOURCED) | play error | visual BLOCKED: line announced via the toast centre |
| approximated | `chat.voice.error.record`<br>`chat.thread.sendFailed`<br>`haptic.global.error` | “couldn’t record — try again” (SOURCED)<br>“couldn’t send — tap to try again” (SOURCED)<br>ios: notification.error; android: REJECT (PLATFORM) | record / upload error | DEBUG recording only (recording UI BLOCKED); optimistic voice message taken back on failure |
| approximated | `chat.voice.permission.title`<br>`chat.voice.permission.detail`<br>`chat.voice.permission.button`<br>`onboarding.permission.contacts.size.cardMarginH` | “can’t send voice messages?” (SOURCED)<br>“enable your mic” (SOURCED)<br>“enable” (SOURCED)<br>18 pt (SOURCED) | microphone denied card | shared PermissionCard above the composer (DEBUG builds: the mic is BLOCKED in release) |
| not matched | `chat.voice.layout.recording` | start: press and hold the mic circle: recording runs while the finger is down; send: lift the finger: the message is sent; cancel: slide left while holding: … (SOURCED) | recording UI | BLOCKED: release has no mic; DEBUG tap to record / tap to send without UI |

## Accessibility and haptics

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `chat.voice.a11y.messageMine`<br>`chat.voice.a11y.message`<br>`chat.voice.a11y.play`<br>`chat.voice.a11y.pause` | “your voice message, {duration}” (SOURCED)<br>“{name}’s voice message, {duration}” (SOURCED)<br>“play voice message, {duration}” (SOURCED)<br>“pause” (SOURCED) | labels (duration spoken) | DateComponentsFormatter .full minutes / seconds; waveform hidden |
| matched | `haptic.global.send`<br>`haptic.global.error` | ios: notification.success; android: CONFIRM (PLATFORM)<br>ios: notification.error; android: REJECT (PLATFORM) | sent / failed | model feedback |
| matched | `haptic.global.longPressStart` | ios: system (context menu plays its own haptic; no custom generator); android: LONG_PRESS (PLATFORM) | long press (context menu) | contextMenu plays the system haptic |
| matched | `—` | — | one voice message plays at a time | SocialVoicePlayback (shared) |

# Voice-note waveform and recording pause — measurements (owner decision 16)

Owner decision 16 (`docs/OWNER_DECISIONS.md`, 2026-10-16): "levels sampled while recording, stored with the note, drawn as
bars in Retro's colours" — Messages, WhatsApp and Telegram all draw one. Retro has no voice notes, so the waveform is a
mechanics reference drawn with Retro's colours (component C-36, `design/components.md`). Tool: `tools/measure_bars.py`
(bar detection + sub-pixel width / height by coverage, run with `python3 -I`). Images: `references/auto/{imessage,
whatsapp,telegram}/INDEX.md`.

## Sources and scales

| id | file | scale | what it shows |
|---|---|---|---|
| MSG | `imessage/apple-support/messages-audio-message-ios27.png` (Apple iPhone User Guide, iOS 27) | display x22–467 = 446 px for a 402-pt iPhone → 1.110 px/pt | audio message: play circle · waveform · "00:04" in one row |
| WA-S | `whatsapp/store/whatsapp-store-02.png` (App Store, listing 26.40.77) | content x179–1111 = 933 px for 393 pt → 2.37 px/pt (±5 %: the status-bar digits give 2.25, the home indicator 2.49) | incoming voice bubble, idle |
| WA-B1 | `whatsapp/blog/whatsapp-blog-2022-03-voice-bubbles.png` (blog 2022-03-30) | marketing composite, ratios only | nine bubbles of different durations |
| WA-B2 | `whatsapp/blog/whatsapp-blog-2022-03-voice-updates.png` (blog 2022-03-30) | Android callouts, ratios only | locked recording ("Pause/Resume Recording") and paused draft ("Draft Preview") panels |
| TG-S | `telegram/store/telegram-store-03.png` (App Store, listing 13.0) | not derivable (device frame) | incoming voice bubble (unread: all bars accent) |
| TG-V | `telegram/blog/tg-blog-power-saving-playback-speed-t0{2,4,6}.png` (blog video frames) | ratios only | a voice message playing |
| TG-API | https://core.telegram.org/constructor/documentAttributeAudio | — | `waveform`: "a series of bitpacked 5-bit values"; its "Example implementation" link (Telegram for Android `jni/audio.c`, `getWaveform2`) keeps `resultSamples = 100` |
| TG-D | https://github.com/telegramdesktop/tdesktop/blob/dev/Telegram/SourceFiles/history/view/media/history_view_document.cpp (`PaintWaveform`, accessed 2026-10-16) | — | Telegram's published desktop client: how stored levels are drawn |

## Bars

| measure | MSG | WA-S | WA-B2 draft capsule | WA-B1 bubble 4 | TG-S |
|---|---|---|---|---|---|
| bars | 38 | 33 visible + 1 under the playhead dot | 27 (played part) | 38 + ≈3 under the dot | 31 |
| bar width (coverage) | 2.26 px → **2.02 pt** | 6.24 px → 2.63 pt | 2.94 px (0.050 of the capsule height) | ≈4.6 px | 5 px |
| pitch | 4.539 px → **4.09 pt** | 10.68 px → 4.51 pt | 5.19 px | 7.92 px | 8.43 px |
| gap | **2.07 pt** | 1.88 pt | 2.25 px | ≈3.3 px | ≈3.4 px |
| min height | 3.3–4.1 px (low resolution) | 5.8 px ≈ the width → dots | 2.5–2.8 px ≈ the width → dots | 4 px ≈ width | 11 px |
| max height | 29.1 px = 26.2 pt | 60.0 px = 25.3 pt | 32.3 px of a 58.4-px capsule → **0.553** | 40 px of a 112-px bubble | 39 px |
| waveform length | 171 px = **154.1 pt** | ≈ 34 × 10.68 px = 151 pt | fills the capsule | fills the bubble | — |
| alignment | centred | centred | centred | centred | bottom |
| ends | rounded | rounded (silence = a dot) | rounded | rounded | rounded top |

- **Count across the width.** WA-B1's nine bubbles have one width whatever the duration (0:09 … 9:31): the bar count
  follows the width, not the length. TG-D: `barCount = min(availableWidth / (barWidth + skip), wfSize)` with
  `wfSize = kWaveformSamplesCount = 100`; each bar takes the maximum of its bucket of stored values. Width-driven.
- **Height scale.** TG-D: `barHeight = min + value × (max − min) / (wavemax + 1)`: the note's loudest value reaches
  (almost) the full height; heights are relative to the note itself.
- **Played / unplayed.** WA-B2 draft: played core (125,127,126), unplayed (195,196,196) on (243,243,243) → the unplayed
  bar has 0.41 of the played bar's contrast. TG-V t06: played ≈ (166,110,188), unplayed ≈ (225,204,235) on white →
  0.34 / 0.35 / 0.30 per channel ≈ 0.33. TG-D draws `msgWaveformActive` left of `activeWidth = width × progress` and
  `msgWaveformInactive` right of it; the bar under the edge is **split** at the edge.
- **Idle.** WA-S and WA-B1: an idle bubble draws every bar in the unplayed grey; TG-D: progress 0 when not playing →
  every bar inactive (only an *unread* incoming note draws all bars active — a read state, do-not-copy, tenets).
- **No stored waveform.** TG-D: `value = wf ? wf->at(i) : 0` → every bar at `msgWaveformMin` (a flat row); when the
  file has been downloaded (`loaded`) and the waveform is empty, `Local::countVoiceWaveform` computes it from the audio.

## Colours on Retro (`design/tokens/global.json`)

| pair | contrast share of the unplayed bar (reference 0.33–0.41) |
|---|---|
| `color.global.textSecondary` #999999 on `color.global.control` #F1F1F1 (iOS light) | 0.365 |
| `color.global.textSecondary` #999999 on `color.global.surfaceSecondary.android` #F7F7F7 (Android light) | 0.38 |
| `color.global.textSecondary` #999999 on #262626 (dark, and media `color.global.controlOnDeep`) | 0.53 |
| `color.global.textTertiary` #C1C1C1 / #FFFFFF4D on the same fills | 0.20 light / 0.30 dark |

Played = `color.global.textPrimary` (page) / `color.global.textOnMedia` (media) — the capsule's own glyph and label
colour. Unplayed = `color.global.textSecondary`: inside the reference band in light, nearest overall (tertiary is 0.20 in
light); one token for both platforms so iOS and Android draw the same bars.

## Levels (data)

TG-API's example implementation (`getWaveform2`): 100 result samples; each = the peak |sample| of its bucket; scale
`peak = max(2500, 1.8 × mean(bucket peaks))` on the 16-bit range; value = `min(31, sample × 31 / peak)`; packed as 5-bit
values. We store the 100 values unpacked (`smallint[]`, `docs/API.md` §5.8 / §5.9) and sample the recorder's peak level
every 30 ms (`AVAudioRecorder.peakPower` → linear; `MediaRecorder.getMaxAmplitude` / 32767) — 3 s of speech fills the 100
buckets; a shorter note repeats samples across buckets.

## Recording pause / resume (locked recording)

- WhatsApp FAQ (`whatsapp/help/faq-657157755756612-send-voice-iphone.png`): "if you're recording hands-free, tap [pause]
  to pause recording and preview a draft of your message before sending. Tap [mic] to continue recording." Blog
  2022-03-30: "Pause/Resume Recording: When recording a voice message, you can now pause the recording and resume when
  ready." / "Draft Preview: Listen to your voice messages before sending them."
- Apple iPhone User Guide, "Send and receive audio messages" (`imessage/apple-support/page-audio-messages.png`): "Tap
  [the Stop button] to pause or end your recording, then … Send it … Listen to review it: Tap [the Play button]. Add to
  the end of it: Tap [the Continue Recording button] … Cancel it."
- Layout, WA-B2: locked recording = elapsed time · live waveform across the width; below: trash · red pause ring · send
  circle. Paused draft = pause/play glyph · draft waveform with progress · duration; below: trash · red mic (continue)
  · send circle. Both panels draw the whole recording across the available width (0:07 → 77 bars, 0:11 → the full
  draft in the capsule).
- A paused draft can be played only from a finished file: `AVAudioRecorder.pause()` / `MediaRecorder.pause()` keep the
  MPEG-4 container open until `stop()`. Pause uses the platform pause; the first preview of a paused draft closes the
  open segment, a later "continue" records a new segment, and sending joins the segments into one `.m4a`.

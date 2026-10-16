# Verification — `chat.composer` (iOS)

The thread's composer (Retro's C-13 comment field with Messages / WhatsApp glyph order) — `ios/App/Sources/Features/Social/UI/ChatComposer.swift` (`ChatComposer`, `SocialFieldInput`, `SocialFieldGlyph`, `SocialFieldMetrics`, `ChatReplyBar`), hosted by `ChatThreadView`.

Pass 4 (Retro redesign). Checklist written from the spec (`design/surfaces/chat.composer.md`, MERGE "Redesign — Social (RS-*)", lead L-3 / L-4) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>-<light|dark>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/chat.composer.png` next to the Retro reference(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level). Components are the Pass 3 library (`ios/App/Sources/Components`, C-01…C-35).

Retro reference(s): `references/auto/retro/press/tc-2023-07-retro-2b.jpg (TC-2B, phone 2 field)`, `references/auto/whatsapp/store/whatsapp-store-04.png`

Snapshots (CI): `chat.composer-idle-light.png`, `chat.composer-idle-dark.png`, `chat.composer-typing-light.png`, `chat.composer-replying-light.png`, `chat.composer-sending-light.png`, `chat.composer-failed-light.png`, `chat.composer-emoji-only-light.png`

**Summary: 19 matched · 1 approximated · 0 not matched (BLOCKED or not buildable).**

## Elements

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| approximated | `color.global.control`<br>`color.global.surfaceSecondary.android`<br>`size.global.commentFieldHeight`<br>`radius.global.commentField`<br>`size.global.screenMargin`<br>`chat.composer.dimension.bottomInset`<br>`chat.composer.a11y.field`<br>`chat.composer.placeholder`<br>`chat.composer.placeholderReply` | light #F1F1F1 / dark #262626 (SOURCED)<br>light #F7F7F7 / dark #262626 (SOURCED)<br>51.2 pt (SOURCED)<br>12.6 pt (SOURCED)<br>16 pt (SOURCED)<br>0 pt (SOURCED)<br>“Message” (SOURCED)<br>“Send a message…” (SOURCED)<br>“Reply…” (SOURCED) | field | `socialFieldShape`: fill `control` (page) / `controlOnDeep` (media), min height `commentFieldHeight` (grows with text, `axis: .vertical`), `radius.global.commentField`, `screenMargin` insets, `bottomInset` above the safe area; placeholder `placeholder` / `placeholderReply`. A local variant of C-13: the shared `ReplyBar` has no measured internals, two glyph slots or a recording row (component gap C-13); text centring derived from the body line height |
| matched | `size.global.avatarComment`<br>`chat.composer.dimension.avatarInset`<br>`chat.composer.dimension.avatarToText` | 31.2 pt (SOURCED)<br>8.6 pt (SOURCED)<br>10.9 pt (SOURCED) | own avatar | `AvatarView` (`avatarComment`) at `avatarInset`, text `avatarToText` after it; decorative |
| matched | `icon.global.camera`<br>`color.global.textSecondary`<br>`size.global.headerIconPitch`<br>`size.global.headerButton`<br>`chat.composer.a11y.camera` | ios: camera; android: Outlined.PhotoCamera (PLATFORM)<br>#999999 (SOURCED)<br>48 pt (SOURCED)<br>44 pt (PLATFORM)<br>“Take photo” (SOURCED) | camera glyph | `SocialFieldGlyph` (`icon.global.camera`, `textSecondary`, `icon` box in a `headerButton` hit area), centres `headerIconPitch` apart → the camera for this group (`AppModal.camera`; while replying to a photo: `presentCameraReplying`) |
| matched | `icon.global.mic`<br>`color.global.textSecondary`<br>`chat.composer.dimension.glyphInsetTrailing`<br>`chat.composer.a11y.mic` | ios: mic; android: Outlined.Mic (PLATFORM)<br>#999999 (SOURCED)<br>17.7 pt (SOURCED)<br>“Record a voice message” (SOURCED) | mic glyph | `icon.global.mic` last, its ink `glyphInsetTrailing` from the field edge; press-and-hold records (chat.voice); first use asks for the microphone |
| matched | `icon.global.send`<br>`color.global.textPrimary`<br>`chat.composer.a11y.send` | ios: paperplane; android: AutoMirrored.Outlined.Send (PLATFORM)<br>light #000000 / dark #FFFFFF (SOURCED)<br>“Send” (SOURCED) | send glyph | with text: `icon.global.send` (`textPrimary`) in place of camera + mic → `sendDraft()` (reply ids, field cleared, reply bar closed — unit-tested) |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `—` | — | idle | placeholder, camera + mic |
| matched | `duration.global.crossfade`<br>`chat.composer.a11y.send` | 100 ms (SOURCED)<br>“Send” (SOURCED) | typing | send glyph, `.dsAnimation(ComponentMotion.crossfade, value: hasText)` |
| matched | `chat.composer.placeholderReply`<br>`chat.thread.reply.bar` | “Reply…” (SOURCED)<br>“Replying to {name}” (SOURCED) | replying | `ChatReplyBar` ("Replying to {name}" / to yourself, close glyph) `sectionHeaderToContent` above the field; placeholder `placeholderReply` |
| matched | `chat.thread.sending`<br>`chat.thread.sendFailed`<br>`haptic.global.send`<br>`haptic.global.error`<br>`chat.thread.layout.failedMessage` | “Sending” (SOURCED)<br>“Couldn't send. Tap to retry” (SOURCED)<br>ios: notification.success; android: CONFIRM (PLATFORM)<br>ios: notification.error; android: REJECT (PLATFORM)<br>indicator: one line under the failed message: chat.thread.sendFailed, text role caption, color.global.destructive; no glyph; sending: while… (SOURCED) | sending / failed | optimistic message with `chat.thread.sending`, then `sendFailed` + `haptic.global.error`; `haptic.global.send` on success (unit-tested) |
| matched | `—` | — | offline | the field stays editable; sends fail into the failed layout |
| matched | `chat.voice.permission.*` | (each key of the group) | permission-denied (microphone) | native alert in `ChatThreadView` (`chat.voice.permission.*`, Settings link) |
| matched | `—` | — | permission-denied (camera) | owned by capture's `camera.capture` |
| matched | `—` | — | loading / empty / error | n/a |

## Motion

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `duration.global.crossfade` | 100 ms (SOURCED) | glyph swap (camera + mic ↔ send) | `ComponentMotion.crossfade` |
| matched | `duration.global.fade`<br>`easing.global.standard` | 150 ms (SOURCED)<br>x1: 0.4; y1: 0; x2: 0.2; y2: 1 (SOURCED) | composer / reply bar appear | `.dsAnimation(ComponentMotion.fade)` for the reply bar and the recording row |
| matched | `—` | — | keyboard raise / lower | system keyboard avoidance (`safeAreaInset(edge: .bottom)`) |

## Haptics

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | tap camera / send (Android) | none on iOS |
| matched | `haptic.global.send` | ios: notification.success; android: CONFIRM (PLATFORM) | text sent | `haptic.global.send` via the model's `.sent` signal |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | send failed | `haptic.global.error` via `.failed` |
| matched | `—` | — | mic pressed | no haptic while recording |

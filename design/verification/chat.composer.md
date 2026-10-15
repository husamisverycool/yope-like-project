# Verification — `chat.composer` (iOS)

Group chat composer — `ios/App/Sources/Features/Social/UI/ChatThreadView.swift` (`ChatComposer`, `composerArea`).

Checklist written from the spec (`design/surfaces/chat.composer.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`), then `tools/sidebyside.py` makes `design/verification/chat.composer.png` next to the reference image(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level).

Reference image(s): `references/auto/yope/store/yope-store-05.png`, `references/auto/yope/frames/b-derot-store-05-rot-1.68.png`

Snapshots (CI): `chat.composer-idle.png`, `chat.composer-typing.png`

**Summary: 14 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Row

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `chat.composer.dimension.insetLeading`<br>`chat.composer.dimension.insetTrailing` | 22.8 pt (SOURCED)<br>23.4 pt (SOURCED) | row insets | padding(.leading/.trailing) |
| matched | `chat.composer.dimension.cameraButton`<br>`color.global.accent`<br>`icon.global.camera`<br>`color.global.onAccent`<br>`chat.composer.dimension.cameraGlyph`<br>`chat.composer.a11y.camera` | 40.6 pt (SOURCED)<br>#CDFD07 (SOURCED)<br>ios: camera.fill; android: Rounded.PhotoCamera (PLATFORM)<br>#000000 (SOURCED)<br>19.5 pt (SOURCED)<br>“send a pic” (SOURCED) | lime camera circle | Button; glyph height cameraGlyph; opens camera.capture for this group |
| matched | `chat.composer.dimension.gapCameraField`<br>`chat.composer.dimension.gapFieldButton` | 6.2 pt (SOURCED)<br>7.1 pt (SOURCED) | gaps | padding |
| matched | `chat.composer.dimension.fieldHeight`<br>`radius.global.capsule`<br>`color.global.control`<br>`chat.composer.dimension.fieldRim`<br>`chat.composer.color.fieldRimTop`<br>`chat.composer.color.fieldRimBottom` | 39.5 pt (SOURCED)<br>shape: capsule; radius: height / 2 (SOURCED)<br>#2E2E2E (SOURCED)<br>0.44 pt (SOURCED)<br>#4B4B4B (SOURCED)<br>#474747 (SOURCED) | text field capsule with hairline rim | TextField(axis: .vertical) in Capsule fill + gradient strokeBorder |
| matched | `chat.composer.dimension.fieldPaddingLeading`<br>`fontSize.global.body`<br>`color.global.textPrimary` | 17.8 pt (SOURCED)<br>17 pt (SOURCED)<br>#FFFFFF (SOURCED) | typed text inset, role body | padding(.horizontal) + TextRole.body |
| matched | `chat.composer.placeholder`<br>`fontSize.global.placeholder`<br>`color.global.textSecondary`<br>`chat.composer.a11y.field` | “start typing...” (SOURCED)<br>17 pt (SOURCED)<br>#969696 (SOURCED)<br>“message” (SOURCED) | placeholder “start typing...” | prompt Text in textSecondary (placeholder size = body size, 17) |
| matched | `chat.composer.layout.typingState`<br>`chat.composer.a11y.send`<br>`icon.global.send`<br>`color.global.accent`<br>`color.global.onAccent` | rule: while the field holds text, the mic circle is replaced in place by a send circle; when the field is empty again the mic circle returns; sendCircleSize:… (SOURCED)<br>“send” (SOURCED)<br>ios: paperplane; android: AutoMirrored.Rounded.Send (PLATFORM)<br>#CDFD07 (SOURCED)<br>#000000 (SOURCED) | while the field holds text the mic slot shows the lime send circle; empty → mic again (G-6) | SendCircle (sideButton, accent, send glyph at the mic glyph’s height), instant swap; return inserts a new line (UI test) |
| matched | `chat.composer.dimension.sideButton`<br>`color.global.controlRaised`<br>`icon.global.mic`<br>`chat.composer.dimension.micGlyph`<br>`chat.composer.a11y.mic` | 39.5 pt (SOURCED)<br>#434343 (SOURCED)<br>ios: mic.fill; android: Rounded.Mic (PLATFORM)<br>21.8 pt (SOURCED)<br>“record a voice message” (SOURCED) | mic circle: press and hold records (chat.voice) | drawn in every build; DragGesture(minimumDistance: 0) drives chat.voice.layout.recording; VoiceOver activation starts hands-free |
| matched | `chat.composer.dimension.bottomInset` | 8 pt (SOURCED) | row 8 above the bottom safe area and the keyboard (G-5) | padding(.bottom) inside the bottom safe-area inset (rides on the keyboard) |
| matched | `size.global.minTouchTarget.ios` | 44 pt (VERIFIED) | hit areas 44 without changing the drawn size | contentShape(Circle().inset(by: −…)) |

## States and haptics

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `haptic.global.send`<br>`haptic.global.error`<br>`chat.thread.sendFailed` | ios: notification.success; android: CONFIRM (PLATFORM)<br>ios: notification.error; android: REJECT (PLATFORM)<br>“couldn’t send — tap to try again” (SOURCED) | sending / failed | optimistic message; on failure taken back, text returned to the field, line announced |
| matched | `—` | — | offline: the field stays editable | send fails as above (unit-tested) |
| matched | `chat.voice.permission.title`<br>`chat.voice.permission.detail`<br>`chat.voice.permission.button` | “can’t send voice messages?” (SOURCED)<br>“enable your mic” (SOURCED)<br>“enable” (SOURCED) | microphone denied: inline card above the composer | shared PermissionCard; leaves once the microphone is allowed (checked on return from Settings) |
| matched | `easing.global.native` | keyboard: system; alert: system; activityIndicator: system (ProgressView / CircularProgressIndicator); scrollIndicator: system; navigationPush: system (Navig… (PLATFORM) | keyboard | system; scrollDismissesKeyboard(.interactively) |

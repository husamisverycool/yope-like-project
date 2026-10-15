# Verification — `birthday.tribute` (iOS)

The birthday video screen (honoree after delivery; members any time) — `ios/App/Sources/Features/Memory/Birthday/Tribute*.swift`.

Checklist written from the spec (`design/surfaces/birthday.tribute.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/memory/<surface>-<state>.png` (`ios/AppTests/Memory/MemorySnapshotTests.swift`), then `tools/sidebyside.py` makes `design/verification/birthday.tribute.png` next to the reference image(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level).

Reference image(s): `references/auto/vidday/store/vidday-store-08.png`, `references/auto/vidday/store/vidday-store-09.png`, `references/auto/tribute/mockups/tribute-home-phone-step-3-completed-page.png`

Snapshots (CI): `birthday.tribute-loading.png`, `birthday.tribute-ready.png`, `birthday.tribute-saved-toast.png`, `birthday.tribute-rendering.png`, `birthday.tribute-not-found.png`, `birthday.tribute-error.png`, `birthday.tribute-offline.png`, `birthday.tribute-save-failed.png`

**Summary: 11 matched · 1 approximated · 1 not matched (BLOCKED or not buildable).**

## Screen

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `size.global.headerButton`<br>`size.global.headerInset`<br>`color.global.controlOnDeep`<br>`icon.global.close`<br>`birthday.tribute.a11y.close` | 44 pt (SOURCED)<br>11.5 pt (SOURCED)<br>#101010 (SOURCED)<br>ios: xmark; android: Rounded.Close (PLATFORM)<br>“Close” (PLATFORM) | close top-left |  |
| matched | `birthday.tribute.title`<br>`fontSize.birthday.request.title`<br>`fontWeight.birthday.request.title`<br>`lineHeight.birthday.request.title`<br>`font.birthday` | “Birthday Video” (SOURCED)<br>24 pt (VERIFIED)<br>semibold (VERIFIED)<br>28.8 pt (VERIFIED)<br>ios: system; android: system (PLATFORM) | ‘Birthday Video’ | header trait |
| matched | `fontSize.birthday.request.message`<br>`color.global.textSecondary` | 16 pt (VERIFIED)<br>#969696 (SOURCED) | group name under the title | line height reserved while loading (no jump) |
| matched | `layout.birthday.tribute.player`<br>`layout.birthday.tribute.video`<br>`dimension.birthday.request.message.gap` | ios: AVPlayerViewController (SwiftUI VideoPlayer), system controls; android: Media3 PlayerView, default controls; aspect: 16:9 (layout.bi… (PLATFORM)<br>width: 1920; height: 1080; fps: 29.97 (SOURCED)<br>20.8 pt (VERIFIED) | player: content width, 16:9, native controls, poster until playback | AVKit VideoPlayer with an AVPlayer prepared as soon as the URL is known; poster overlay until .playing |
| matched | `—` | — (no token) | plays once on open unless ‘Auto-Play Video Previews’ is off | UIAccessibility.isVideoAutoplayEnabled |
| matched | `birthday.tribute.download`<br>`birthday.tribute.share`<br>`icon.global.download`<br>`icon.global.share`<br>`dimension.birthday.tribute.button.height`<br>`dimension.birthday.tribute.button.gap`<br>`radius.birthday.tribute.button`<br>`color.global.surfaceLight`<br>`color.birthday.tribute.button.label`<br>`fontSize.birthday.tribute.button`<br>`fontWeight.birthday.tribute.button`<br>`dimension.birthday.request.cta.gap` | “Download” (SOURCED)<br>“Share” (SOURCED)<br>ios: arrow.down.to.line; android: Rounded.Download (PLATFORM)<br>ios: square.and.arrow.up; android: Rounded.IosShare (PLATFORM)<br>44 pt (VERIFIED)<br>10 pt (VERIFIED)<br>8 pt (VERIFIED)<br>#FFFFFF (SOURCED)<br>#292D34 (VERIFIED)<br>14 pt (VERIFIED)<br>semibold (VERIFIED)<br>15 pt (VERIFIED) | Download / Share stacked | PHAssetCreationRequest via PhotoLibraryService (add-only); ShareLink with the MP4 |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `birthday.tribute.loading` | “Loading” (SOURCED) | loading / re-rendering: indicator in the player area, buttons disabled | pending re-reads on return to the foreground |
| matched | `birthday.tribute.notFound.title`<br>`birthday.tribute.notFound.detail` | “this video isn't here anymore” (SOURCED)<br>“your memories are waiting” (SOURCED) | deleted — or not yet delivered to the honoree | TributeModel.isVisible (unit-tested before / after delivery) |
| matched | `birthday.tribute.error.title`<br>`birthday.tribute.error.detail`<br>`birthday.tribute.error.retry` | “couldn't load your video” (SOURCED)<br>“try again in a moment” (SOURCED)<br>“try again” (SOURCED) | error + retry |  |
| matched | `birthday.tribute.offline` | “you're offline — connect to watch your video” (SOURCED) | offline under the title |  |
| approximated | `birthday.tribute.saved`<br>`birthday.tribute.saveFailed` | “saved to your photos” (SOURCED)<br>“couldn't save the video — try again in a moment” (SOURCED) | toasts | DEBUG draws the foundations toast; release announces (dwell BLOCKED); settings link for denied access not added (owned by system.permissions) |
| matched | `haptic.global.success`<br>`haptic.global.error` | ios: notification.success; android: CONFIRM (PLATFORM)<br>ios: notification.error; android: REJECT (PLATFORM) | saved / failed | unit-tested |

## Video (worker contract, not drawn by the app)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| not matched | `duration.birthday.tribute.photoHold`<br>`layout.birthday.tribute.caption`<br>`layout.birthday.tribute.endCard`<br>`birthday.tribute.endCard` | None (BLOCKED)<br>None (BLOCKED)<br>None (BLOCKED)<br>“From {group}” (BLOCKED) | BLOCKED worker values | the worker refuses to render until sourced; the app shows ‘loading’ while status = pending |

# Verification — `tagging` (iOS)

The “i'm in this” self-tag control (placed by photo.viewer) — `ios/App/Sources/Features/Memory/Tagging/`.

Checklist written from the spec (`design/surfaces/tagging.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/memory/<surface>-<state>.png` (`ios/AppTests/Memory/MemorySnapshotTests.swift`), then `tools/sidebyside.py` makes `design/verification/tagging.png` next to the reference image(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level).

Reference image(s): `references/auto/yope/store/yope-store-04.png`, `references/auto/yope/frames/a-jacob-7691153057177931039-t3.73-camera-hold-to-record.png`, `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t6.73-sendto-voice-tooltip.png`

Snapshots (CI): `tagging-off.png`, `tagging-on.png`, `tagging-pending.png`, `tagging-coach.png`, `tagging-error-toast.png`

**Summary: 6 matched · 3 approximated · 0 not matched (BLOCKED or not buildable).**

## Toggle

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `radius.global.capsule`<br>`color.global.surfaceLight` | shape: capsule; radius: height / 2 (SOURCED)<br>#FFFFFF (SOURCED) | white capsule | SelfTagToggleControl |
| matched | `icon.global.uncheck`<br>`icon.global.check`<br>`color.global.onSurfaceLight`<br>`color.global.selection`<br>`size.global.checkCircle` | ios: circle; android: Rounded.RadioButtonUnchecked (PLATFORM)<br>ios: checkmark.circle.fill; android: Rounded.CheckCircle (PLATFORM)<br>#000000 (SOURCED)<br>#0091FF (PLATFORM)<br>24 pt (SOURCED) | off ring / on check | glyph swap without animation |
| matched | `size.global.headerGap`<br>`tagging.toggle`<br>`fontSize.global.button`<br>`fontWeight.global.button` | 7.3 pt (SOURCED)<br>“i'm in this” (SOURCED)<br>15 pt (SOURCED)<br>semibold (SOURCED) | glyph, gap 7.3, ‘i'm in this’ | DSTextStyle (subheadline); capsule grows with the text |
| approximated | `size.global.buttonHeight`<br>`size.global.minTouchTarget.ios` | 45 pt (SOURCED)<br>44 pt (VERIFIED) | capsule height / insets | white-pill height 45 (≥ 44), label inset by the capsule radius (not measured) |
| matched | `—` | — (no token) | VoiceOver: button ‘i'm in this’, selected when on | accessibilityAddTraits(.isSelected) |
| matched | `haptic.global.select`<br>`haptic.global.error` | ios: selection; android: SEGMENT_TICK (PLATFORM)<br>ios: notification.error; android: REJECT (PLATFORM) | changed / failed | unit-tested |
| matched | `—` | — (no token) | optimistic, ≤ one call per photo, rollback on error | SelfTagModel (unit-tested) |

## Coach and messages

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| approximated | `tagging.coach`<br>`color.global.accent`<br>`color.global.onAccent`<br>`icon.global.close` | “tap if you're in this pic” (SOURCED)<br>#CDFD07 (SOURCED)<br>#000000 (SOURCED)<br>ios: xmark; android: Rounded.Close (PLATFORM) | first-use coach on others' photos, once per account | geometry of the measured Yope coach (camera.capture.layout.coach, camera.capture.fontSize/fontWeight.coach); ✕ labelled photo.viewer.a11y.close (no tagging key) |
| approximated | `tagging.error`<br>`tagging.notFound`<br>`tagging.offline` | “couldn't save that — try again in a moment” (SOURCED)<br>“this pic isn't here anymore” (SOURCED)<br>“you're offline — try again when you're connected” (SOURCED) | toasts; the toggle reverts | lines handed to the host (onMessage) + announced; toast drawn only in DEBUG while the dwell is BLOCKED |

## Notes

API for the photo viewer: `SelfTagToggleControl(isOn:isPending:showsCoach:onToggle:onDismissCoach:)` when the host owns the state (PhotoViewerModel.toggleTag), or `SelfTagToggle(postID:isTagged:isOthersPhoto:onMessage:onPostGone:onChange:)` to let the control call tag_self / untag_self itself.

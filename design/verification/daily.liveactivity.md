# Verification — `daily.liveactivity` (iOS)

Lock Screen + Dynamic Island — `ios/Widgets/Sources/LiveActivitySlots.swift`, `DailyInvitationLiveActivity.swift`.

Checklist written from the spec (`design/surfaces/daily.liveactivity.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>.png`, then `tools/sidebyside.py` makes `design/verification/daily.liveactivity.png` next to the reference image(s) below.

Reference image(s): `references/auto/platform/hig-live-activities-ios-dimensions.png`, `references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png`

Snapshots (CI): `daily.liveactivity-lock-screen.png`, `daily.liveactivity-lock-screen-stale.png`, `daily.liveactivity-compact.png`, `daily.liveactivity-minimal.png`, `daily.liveactivity-expanded.png`

**Summary: 6 matched · 2 approximated · 0 not matched (BLOCKED or not buildable).**

## Values

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `daily.liveactivity.size.lockScreenMargin` | 14 pt (VERIFIED) | 14 pt | padding |
| matched | `daily.liveactivity.layout.colors` | islandBackground: system black (not customizable); lockScreenBackground: color.global.backgroundDeep; countdown: color.global.accent; text: color.global.textPrimary; keyLine: color.global.accent; systemActionForeground: color.global.textPrimary (PLATFORM) | Lock Screen bg backgroundDeep; countdown accent; text textPrimary; key line accent; action fg textPrimary | activityBackgroundTint, keylineTint, activitySystemActionForegroundColor |
| matched | `daily.liveactivity.layout.typography` | groupName: headline (17 pt semibold, Dynamic Type); countdownLockScreen: daily.capture.fontSize.countdown (23 pt), monospaced digits; countdownCompact: headline, monospaced digits; countdownMinimal: caption1, semibold, monospaced digits (PLATFORM) | group name headline; countdown 23 pt / headline / caption1 semibold, monospaced | Font.system(textStyle) + parsed weight; monospacedDigit |
| approximated | `daily.liveactivity.fontWeight.min` | medium (VERIFIED) | every text ≥ medium | Lock Screen countdown weight until daily.capture.fontWeight.countdown is unblocked |
| matched | `daily.liveactivity.layout.lifecycle` | start: push-to-start at fires_at with the invitation alert; stale: closes_at; end: event end at closes_at, dismissal immediate; countdown: Text(timerInterval: now...closesAt, countsDown: true) (PLATFORM) | Text(timerInterval:) countdown, stale at closes_at | InvitationCountdown; stale hides the countdown |
| matched | `daily.liveactivity.layout.size` | w393compact: 52.33x36.67; w393minimal: 36.67-45x36.67; w393expanded: 371x84-160; w393lockScreen: 371x84-160; w430compact: 62.33x36.67; w430expanded: 408x84-160; w430lockScreen: 408x84-160; limitedWidth: 28x28 (VERIFIED) | compact 52.33 wide | compact trailing maxWidth from the token |
| approximated | `daily.capture.countdown` | “{mm}:{ss}” (SOURCED) | MM:SS | system timer format (M:SS under 10 min) — Text(timerInterval:) cannot be zero-padded |
| matched | `icon.global.camera` | ios: camera.fill; android: Rounded.PhotoCamera (PLATFORM) | compact leading / expanded leading | Image, accent, hidden from VoiceOver |

## Notes

- Minimal in limited width (landscape) should show the camera glyph only; no API distinguishes that context on iOS 17 — the countdown shows (reported). Stale: the glyph replaces the countdown.

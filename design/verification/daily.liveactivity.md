# Verification — `daily.liveactivity` (iOS, Pass 4 — Retro redesign)

Invitation countdown — `ios/Widgets/Sources/LiveActivitySlots.swift`, `DailyInvitationLiveActivity.swift`, `WidgetStyle.swift`.

Checklist written from the spec (`design/surfaces/daily.liveactivity.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>-<light|dark>.png` (every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/daily.liveactivity.png` next to the reference image(s) below.

Reference image(s): `references/auto/platform/hig-live-activities-ios-dimensions.png`, `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png (H43)`, `references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png`

Snapshots (CI, `ios/build/snapshots/capture/`): `daily.liveactivity-lock-screen-light.png`, `daily.liveactivity-lock-screen-dark.png`, `daily.liveactivity-lock-screen-stale-light.png`, `daily.liveactivity-compact-light.png`, `daily.liveactivity-minimal-light.png`, `daily.liveactivity-expanded-light.png`

**Summary: 8 matched · 1 approximated · 0 not matched (BLOCKED or not buildable).**

## Lock Screen

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `daily.liveactivity.layout.colors` | islandBackground: system black (not customizable); lockScreenBackground: color.global.backgroundDeep; countdown: color.global.textOnMedia; text: color.global.textOnMedia; keyLine: color.global.textOnMedia; systemActionForeground: color.global.textOnMedia (SOURCED) | background backgroundDeep; text, countdown, key line, system actions textOnMedia | `activityBackgroundTint`, `activitySystemActionForegroundColor`, `keylineTint`, foregrounds |
| matched | `daily.liveactivity.size.lockScreenMargin` | 14 pt (VERIFIED) | 14 | padding |
| matched | `daily.liveactivity.layout.size` | w393compact: 52.33x36.67; w393minimal: 36.67-45x36.67; w393expanded: 371x84-160; w393lockScreen: 371x84-160; w430compact: 62.33x36.67; w430expanded: 408x84-160; w430lockScreen: 408x84-160; limitedWidth: 28x28 (VERIFIED) | 371 × 84–160 | min height parsed from the token (84) |
| approximated | `daily.liveactivity.layout.typography` | groupNameLockScreen: font.global.display, text role displaySmall (24, regular), color.global.textOnMedia; countdownLockScreen: text role sheetTitle (17 semibold), monospaced digits, color.global.textOnMedia; groupNameExpanded: text role sheetTitle (17 semibold); countdownCompact: text role sheetTitle (17 semibold), monospaced digits; countdownMinimal: Caption 1 (12 pt) semibold, monospaced digits (system; Retro has no role this small) (SOURCED) | group name display serif displaySmall (24 regular); countdown sheetTitle monospaced | `WidgetType.liveActivityGroupName` (serif 24, weight raised to medium: the HIG floor `fontWeight.min`), `WidgetType.sheetTitle` + monospacedDigit |
| matched | `daily.liveactivity.fontWeight.min` | medium (VERIFIED) | every weight ≥ medium | group name medium, countdown semibold |
| matched | `daily.liveactivity.layout.lifecycle` | start: push-to-start at fires_at with the invitation alert; stale: closes_at; end: event end at closes_at, dismissal immediate; countdown: Text(timerInterval: now...closesAt, countsDown: true) (PLATFORM) | Text(timerInterval:countsDown:), stale hides nothing 'late' | `InvitationCountdown`; stale hides the countdown |

## Dynamic Island

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `icon.global.camera` | ios: camera; android: Outlined.PhotoCamera (PLATFORM) | compact / expanded leading, limited width | `InvitationCompactLeadingSlot` (24 box, textOnMedia) |
| matched | `fontSize.global.sheetTitle` | 17 pt (SOURCED) | compact / expanded countdown, expanded group name | sheetTitle |
| matched | `daily.liveactivity.layout.typography` | groupNameLockScreen: font.global.display, text role displaySmall (24, regular), color.global.textOnMedia; countdownLockScreen: text role sheetTitle (17 semibold), monospaced digits, color.global.textOnMedia; groupNameExpanded: text role sheetTitle (17 semibold); countdownCompact: text role sheetTitle (17 semibold), monospaced digits; countdownMinimal: Caption 1 (12 pt) semibold, monospaced digits (system; Retro has no role this small) (SOURCED) | minimal: Caption 1 semibold monospaced (system) | `WidgetType.platform(countdownMinimal)` |

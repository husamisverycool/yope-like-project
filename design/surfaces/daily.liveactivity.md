# daily.liveactivity — the invitation countdown on the Lock Screen and in the Dynamic Island (iOS)

Reference: **BeReal** has no Live Activity (bereal.md §4: none found) → layout per **Apple HIG Live Activities**
(PLATFORM), carrying BeReal's countdown format (MM:SS, `bereal.format.countdown`). Every rule below is quoted from
the HIG page (change log 2026-10-13).

## References

| image / doc | what it verifies |
|---|---|
| `references/auto/platform/hig-live-activities-ios-dimensions.png`; https://developer.apple.com/design/human-interface-guidelines/live-activities | sizes, margins, presentations, color and motion rules |
| `references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png` | countdown format and digit size (23 pt for the platform font) |
| `references/auto/locket/frames/locket-tt-7460656081153445163-01.000s-rollcall-live-activity-lockscreen.jpg` | another reference app's Lock Screen Live Activity exists (Locket Rollcall) — not this surface's reference; not used for values |

## Structure

Sizes: `daily.liveactivity.layout.size` (393-pt screen: compact 52.33 × 36.67 each side, minimal 36.67–45 × 36.67,
expanded / Lock Screen 371 × 84–160, limited width 28 × 28).

**Lock Screen** (and the banner on devices without the Dynamic Island) — HIG: "Don't replicate notification layouts";
"use the space you need"; margin 14 pt:
- background `color.global.backgroundDeep` (custom Lock Screen background allowed; the app is dark-only);
- one row inside `daily.liveactivity.size.lockScreenMargin`, height the minimum 84 pt: leading the **group name**
  (Headline, `color.global.textPrimary`), trailing the **countdown** (`daily.capture.fontSize.countdown` 23 pt,
  monospaced digits, `color.global.accent`).

**Compact** (Dynamic Island, one activity) — "read as a single piece of information … consistent color":
- leading: `icon.global.camera` in `color.global.accent`;
- trailing: countdown, Headline monospaced digits, `color.global.accent`.

**Minimal** — "the Timer app’s minimal Live Activity presentation displays the remaining time instead of a static icon":
- countdown, Caption 1 emphasized (semibold), monospaced digits, `color.global.accent`;
- limited width (landscape): "use a short abbreviation or graphic representation" → `icon.global.camera` only.

**Expanded** (touch and hold) — "an enlarged version of the compact … presentation":
- leading region: `icon.global.camera` (`color.global.accent`); trailing region: countdown (Headline, accent);
  bottom region: group name (Headline, `color.global.textPrimary`).

**StandBy**: the system scales the Lock Screen presentation 2× and extends the custom background.

Typography: `daily.liveactivity.layout.typography`; every text ≥ medium weight (`daily.liveactivity.fontWeight.min`).
Colors: `daily.liveactivity.layout.colors` (Dynamic Island background is system black; key line
`color.global.accent`; verify the generated dismiss-button color, `activitySystemActionForegroundColor`
= `color.global.textPrimary`).

## Elements

| element | tokens | copy | behavior |
|---|---|---|---|
| start alert | — | `notifications.push.dailyInvitation.title` / `.body` (the alert of the push-to-start payload) | the only alert; no update alerts, none at the end |
| group name | text style Headline | group name (data, `DailyInvitationAttributes`) | — |
| countdown | `daily.capture.fontSize.countdown` (Lock Screen), `daily.liveactivity.layout.typography`, `color.global.accent` | MM:SS format (`daily.capture.countdown`) | `Text(timerInterval: now...closesAt, countsDown: true)` — updates itself, no pushes (`daily.liveactivity.layout.lifecycle`) |
| camera glyph | `icon.global.camera`, `color.global.accent` | — (decorative, hidden from accessibility) | — |
| tap (any presentation) | — | — | `app://daily?group=<id>&invitation=<id>` → `daily.capture`; compact leading and trailing link to the same screen (HIG) |

## States

| state | behavior |
|---|---|
| active | as Structure |
| stale (end push missed) | `staleDate = closes_at`; the app ends it on next foreground; nothing "late" is shown |
| ended at `closes_at` | event `end` with dismissal immediate — HIG "Always end a Live Activity immediately when the task or event ends"; no summary (it would read as 'late', T4) |
| Live Activities off / not allowed | `daily.notification` alert path instead |
| loading / empty / error / offline | n/a (system-rendered from the payload) |

## Motion

System transitions only; the countdown digits are system-updated (`Text(timerInterval:)`), so BeReal's digit roll
cannot be reproduced here. Any custom animation ≤ `daily.liveactivity.duration.animationMax` (2 s). No animation on
Always-On (system).

## Haptics

The start alert's default sound / haptic (system; silent in quiet hours). None afterwards.

## Accessibility

VoiceOver reads the group name and the system timer text; the camera glyph is hidden. Text uses Dynamic Type styles
(Headline, Caption 1). Contrast: accent on black 17.65:1; white on black 21:1 — pass.

## Data & actions

- Push-to-start (iOS 17.2+) at `fires_at` with `attributes` (group id, group name, invitation id) and
  `content-state` (`closesAt`); `input-push-channel` on iOS 18+ for the end broadcast
  (backend/worker/src/jobs/invitation.ts, push/payloads.ts).
- `register_device(p_push_to_start_token)` keeps the token current.
- In-app control to turn the invitation Live Activity off (HIG: "make it easy for people to turn them off in your
  app") belongs to `settings.notifications` / `groups.settings`.

## Platform notes

- iOS 17.2+ (push-to-start). The first push-to-start while backgrounded shows an inline Allow / Don't Allow prompt
  (system) until answered.
- Payload ≤ 4 KB; images must fit the presentation (none used).
- Android counterpart: `daily.ongoing`.

## Do-not-copy

Any reminder or "closing soon" alert; color change near 00:00; a summary after the window; Locket Rollcall's copy.

## Gaps

| item | status | capture |
|---|---|---|
| countdown weight on the Lock Screen | BLOCKED via `daily.capture.fontWeight.countdown` | verification render (see daily.capture) |
| HIG design templates' exact text sizes | not in the research (Apple Design Resources) | — (text styles used instead) |

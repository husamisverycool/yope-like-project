# daily.liveactivity — the invitation countdown on the Lock Screen and in the Dynamic Island (iOS)

**Visual reference: Retro** has no Live Activity; its research mapping says "Live Activity drawn with dark tokens
(black, white SF, serif 'Week'-style title if a title is used)" (`design/research/retro-visual.md` §5). So the
presentations are **Retro's media colours and text roles placed in Apple HIG's Live Activity layouts** (PLATFORM),
carrying BeReal's MM:SS countdown (`bereal.format.countdown`; BeReal itself has no Live Activity). Decisions:
`design/MERGE_DECISIONS.md` RC-17.

## References

| image / doc | what it verifies |
|---|---|
| `references/auto/platform/hig-live-activities-ios-dimensions.png`; https://developer.apple.com/design/human-interface-guidelines/live-activities | sizes, margins, presentations, colour and motion rules (`daily.liveactivity.layout.size`, `.size.lockScreenMargin`, `.fontWeight.min`, `.duration.animationMax`) |
| `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png` (H43), `references/auto/retro/press/tc-2025-12-rewind-device-a.png` (RWA) | Retro's dark media look: black page, white SF text, serif display title |
| `references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png` | MM:SS countdown format |

## Structure

Sizes: `daily.liveactivity.layout.size` (393-pt screen: compact 52.33 × 36.67 each side, minimal 36.67–45 × 36.67,
expanded / Lock Screen 371 × 84–160, limited width 28 × 28). Colours: `daily.liveactivity.layout.colors`;
typography: `daily.liveactivity.layout.typography`.

**Lock Screen** (and the banner on devices without the Dynamic Island): background `color.global.backgroundDeep`;
one row inside `daily.liveactivity.size.lockScreenMargin` (14), minimum height 84:
- leading: the **group name** in `font.global.display`, text role `displaySmall` (24, regular),
  `color.global.textOnMedia`, one line, truncating;
- trailing: the **countdown**, text role `sheetTitle` (17 semibold), monospaced digits, `color.global.textOnMedia`.

**Compact** (Dynamic Island): leading `icon.global.camera` (`size.global.icon`, `color.global.textOnMedia`); trailing
the countdown (`sheetTitle`, monospaced digits).

**Minimal**: the countdown (Caption 1 semibold, monospaced — the system's; Retro has no role this small); limited
width: `icon.global.camera` only.

**Expanded** (touch and hold): leading region `icon.global.camera`; trailing region the countdown (`sheetTitle`);
bottom region the group name (`sheetTitle`, `color.global.textOnMedia`).

**StandBy**: the system scales the Lock Screen presentation 2× and extends the background.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| start alert | — | `notifications.push.dailyInvitation.title` / `.body` | the alert of the push-to-start payload; the only alert |
| group name | `font.global.display` + `displaySmall` (Lock Screen); `sheetTitle` (expanded) | group name (data, `DailyInvitationAttributes`) | — |
| countdown | `sheetTitle` / Caption 1, monospaced digits, `color.global.textOnMedia` | MM:SS (`daily.capture.countdown` format) | `Text(timerInterval: now...closesAt, countsDown: true)` — updates itself (`daily.liveactivity.layout.lifecycle`) |
| camera glyph | `icon.global.camera` | — (decorative) | — |
| tap | — | — | `app://daily?group=<id>&invitation=<id>` → `daily.capture` |

## States

| state | behaviour |
|---|---|
| active | as Structure |
| stale (end push missed) | `staleDate = closes_at`; the app ends it on next foreground; nothing "late" is shown |
| ended at `closes_at` | end with dismissal immediate (HIG "end … immediately when the … event ends"); no summary |
| Live Activities off / not allowed | `daily.notification` alert path |
| loading / empty / error / offline | n/a (system-rendered from the payload) |

## Motion

System transitions only; the countdown digits are system-updated (`Text(timerInterval:)`), so no custom digit motion.
Any custom animation ≤ `daily.liveactivity.duration.animationMax` (2 s). No animation on Always-On.

## Haptics

The start alert's default sound / haptic (system; silent in quiet hours). None afterwards.

## Accessibility

VoiceOver reads the group name and the system timer text; the camera glyph is hidden. Every weight ≥ medium
(`daily.liveactivity.fontWeight.min`). Contrast (Lock Screen background is black in both appearances):
`textOnMedia` on `backgroundDeep` 21.00:1 pass; the Dynamic Island is system black (same pair).

## Data & actions

- Push-to-start (iOS 17.2+) at `fires_at` with `attributes` (group id, group name, invitation id) and
  `content-state` (`closesAt`); `input-push-channel` on iOS 18+ for the end broadcast (backend/worker/src/jobs/invitation.ts).
- `register_device(p_push_to_start_token, p_live_activities_enabled)` keeps the token current and reports whether the
  iPhone shows Live Activities (iOS Settings `areActivitiesEnabled` and the in-app switch); with them off the worker
  sends the `daily.notification` alert instead of a push-to-start that iOS would not show (migration 0030).
- The in-app switch to turn invitation Live Activities off belongs to `settings.notifications` / `groups.settings`.

## Platform notes

- iOS 17.2+. The first push-to-start while backgrounded shows an inline Allow / Don't Allow prompt (system).
- Display serif in a widget extension: `.fontDesign(.serif)` / New York (`font.global.display`, PLATFORM) — no font file.
- Android counterpart: `daily.ongoing`.

## Do-not-copy

Any reminder or "closing soon" update; colour change near 00:00; a summary after the window; Yope's lime countdown;
Locket Rollcall copy; Retro's wordmark.

## Gaps

| item | status | capture |
|---|---|---|
| Retro Live Activity | none exists (composition of Retro roles in HIG layouts) | — |
| HIG design templates' exact text sizes | not in the research | — (Retro roles used) |

# daily.ongoing — the invitation countdown notification (Android)

**Visual reference: Retro's notifications** — system-drawn, with Retro's copy and channel naming
(`retro.voice.push`, `retro.voice.push-channel`); Retro's notification colour is not captured, so the system default
applies. Layout per **Material 3 / Android notifications** (PLATFORM), carrying BeReal's MM:SS countdown (the system
chronometer). **Mechanics: BeReal** (window countdown; BeReal itself has no ongoing notification). Decisions:
`design/MERGE_DECISIONS.md` RC-17.

## References

| doc | what it verifies |
|---|---|
| https://developer.android.com/reference/android/app/Notification.Builder (setUsesChronometer, setChronometerCountDown, setTimeoutAfter) | countdown and removal |
| https://developer.android.com/develop/ui/views/notifications/live-update (2026-10-07) | Live Update criteria |
| `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` `notification_channel_display_*` | Retro channel naming |
| `references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png` | MM:SS format |

## Structure

A standard notification in channel `daily_invitation` (`daily.ongoing.layout.notification`):

1. Header (system): small icon (the monochrome "J" of the app icon, `ic_stat_jolt`, owner decision 32), app name, **chronometer counting down
   to `closes_at`** (`setUsesChronometer(true)`, `setChronometerCountDown(true)`, `setWhen(closesAt)`), MM:SS.
2. Title `notifications.push.dailyInvitation.title` ({group}).
3. Text `notifications.push.dailyInvitation.body`.

No `setColor` (system default tint), no actions, no progress bar, no large icon.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| notification | `daily.ongoing.layout.notification` | title / body above | posted from the high-priority FCM data message at `fires_at`; one per group |
| chronometer | system | MM:SS | counts down; removed by `setTimeoutAfter(closesAt − now)` |
| tap | — | — | `PendingIntent` → `app://daily?group=<id>&invitation=<id>` → `daily.capture`; auto-cancel |
| dismiss | — | — | swipe dismisses it (not `ongoing`) |
| channel | `notifications.push.layout.channels` | `notifications.push.channel.dailyInvitation.name` / `.description` | `IMPORTANCE_HIGH` |

## States

| state | behaviour |
|---|---|
| window open | posted, counting down |
| window closes | removed by the system; nothing else posted |
| POST_NOTIFICATIONS denied or channel off | nothing posted (the group screen shows the invitation) |
| muted group | nothing sent |
| quiet hours | posted silently (device setting) |
| loading / empty / error / offline | n/a (system UI) |

## Motion

System only.

## Haptics

System channel sound / vibration; none afterwards.

## Accessibility

System-read; TalkBack reads the chronometer. No emoji. Contrast: system-drawn in the current appearance.

## Data & actions

FCM data message `type = daily_invitation` with `group_id`, `invitation_id`, `closes_at`; the app posts the
notification (`DailyInvitationNotifier`) with device-clock correction; `invitation.end` cancels it if still shown.

## Platform notes

- **Not promoted** to an Android 16 Live Update (third-party-triggered activity); promotion only after an explicit
  opt-in, with an Unpin action. **Code to change (C-11, still open):** `DailyInvitationNotifier` requests promotion.
- **Code to change (Pass 4):** `InvitationAppearance.accentColor` in
  `android/core/push/src/main/kotlin/app/push/NotificationUi.kt` still tints the invitation with `color.global.accent`
  (now black / white by appearance) — return no colour, as `NotificationAppearance.accentColor` does (RC-17).
- Not `setOngoing(true)`; minSdk 26, so `setTimeoutAfter` is always available.

## Do-not-copy

'Daily Reminders' channel (nag); any reminder or 'closing soon' update; colour change near 00:00.

## Gaps

| item | status | capture |
|---|---|---|
| monochrome notification small icon | closed: `ic_stat_jolt` (owner decision 32, tools/appicon.py) | — |
| Retro's notification tint | not captured → system default | one screenshot of a Retro notification on Android |

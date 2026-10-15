# daily.ongoing — the invitation countdown notification (Android)

Reference: **BeReal** has no ongoing notification (bereal.md §4) → layout per **Material 3 / Android notifications**
(PLATFORM), carrying BeReal's MM:SS countdown (the system chronometer already renders MM:SS).

## References

| doc | what it verifies |
|---|---|
| https://developer.android.com/reference/android/app/Notification.Builder (setUsesChronometer, setChronometerCountDown API 24, setTimeoutAfter API 26) | countdown and removal |
| https://developer.android.com/develop/ui/views/notifications/live-update (2026-10-07) | Live Update (promotion) criteria |
| https://developer.android.com/develop/ui/views/notifications/channels | channel rules |
| `references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png` | MM:SS format |

## Structure

A standard notification in channel `daily_invitation` (`daily.ongoing.layout.notification`):

1. Header (system): small icon (monochrome app glyph — owner asset, BLOCKED) tinted `color.global.accent`, app name,
   **chronometer counting down to `closes_at`** (`setUsesChronometer(true)`, `setChronometerCountDown(true)`,
   `setWhen(closesAt)`) in MM:SS.
2. Title `notifications.push.dailyInvitation.title`.
3. Text `notifications.push.dailyInvitation.body` ({group}).

No actions, no progress bar, no large icon (none in any reference).

## Elements

| element | tokens | copy | behavior |
|---|---|---|---|
| notification | `daily.ongoing.layout.notification` | title / body above | posted from the high-priority FCM data message at `fires_at`; one per group |
| chronometer | system | MM:SS | counts down; the notification is removed by `setTimeoutAfter(closesAt − now)` |
| tap | — | — | `PendingIntent` → `app://daily?group=<id>&invitation=<id>` → `daily.capture`; auto-cancel on tap |
| dismiss | — | — | swipe dismisses it (not `ongoing`): an invitation, not an obligation |
| channel | `notifications.push.layout.channels` | `notifications.push.channel.dailyInvitation.name` / `.description` | `IMPORTANCE_HIGH` (heads-up) |

## States

| state | behavior |
|---|---|
| window open | posted, counting down |
| window closes | removed by the system (`setTimeoutAfter`); nothing else posted |
| POST_NOTIFICATIONS denied (Android 13+) or channel off | nothing posted (the group screen shows the invitation) |
| muted group | nothing sent |
| quiet hours | posted silently (device setting) |
| loading / empty / error / offline | n/a (system UI) |

## Motion

System only.

## Haptics

System channel sound / vibration; none afterwards.

## Accessibility

System-read; the chronometer is read by TalkBack as elapsed time. No emoji.

## Data & actions

FCM data message `type = daily_invitation` with `group_id`, `invitation_id`, `closes_at` (worker `fcmInvitation`);
the app posts the notification (`DailyInvitationNotifier`) with device-clock correction; `invitation.end` sends the
end message (the app cancels if still shown).

## Platform notes

- **Not promoted** to an Android 16 Live Update: "Don't allow activities triggered by other parties to generate Live
  Updates"; promotion only if the member explicitly opts in to following the window, with an Unpin action (then status
  chip ≤ 96 dp, `setShortCriticalText` ≤ 7 characters). **Code to change (C-11):** `DailyInvitationNotifier` currently
  requests promotion.
- Not `setOngoing(true)`: ongoing is not required without promotion, and the member can dismiss an invitation.
- API 26+ (app minSdk 26), so `setTimeoutAfter` is always available.

## Do-not-copy

'Daily Reminders' channel (Locket, nag); any reminder or 'closing soon' update; color change near 00:00.

## Gaps

| item | status | capture |
|---|---|---|
| monochrome notification small icon | BLOCKED (owner app icon / logo) | owner asset |
| BeReal's Android daily notification | not found | Android screenshot of BeReal's push |

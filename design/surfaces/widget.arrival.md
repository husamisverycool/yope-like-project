# widget.arrival — how a new photo reaches a member's widget

**Mechanics: Locket** (instant swap of the image, push-driven refresh, "a slight delay of up to 5 minutes" help
statement) within platform limits (docs/PLATFORM_CONSTRAINTS.md §1, §4). **Retro:** hourly periodic update as the
safety net (`widget.android.duration.updatePeriod`), its "Background Work" notification channel for refresh work,
and its copy voice. No screen of its own. Expectation in copy: **up to a few minutes**, never "instant".

## References

| image / source | what it verifies |
|---|---|
| `references/auto/locket/frames/locket-tt-7168613044728155438-15.133s-widget-placeholder-just-added.jpg` → `15.167s-widget-photo-arrived.jpg` | the new image replaces the old in one frame, no fade |
| https://help.locket.com/en/articles/5859739-why-isn-t-my-locket-widget-updating (2026-05-05) | "a slight delay of up to 5 minutes. This delay helps conserve your phone's battery." |
| `references/auto/retro/apk/retro-android-2026.10.1150-excerpts.txt` "WIDGET PROVIDERS" (updatePeriodMillis 3600000), `AppWidgetDataWorker` | Retro's hourly safety net and worker-driven refresh |
| `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` `notification_channel_display_name_foreground_work` "Background Work", `app_widget_refreshing_toast` "Refreshing" | Retro's channel for background updates |

## Structure

The sequence for each recipient device after `create_post` (`widget.refresh` job per group):

1. iOS 26+: widget push (`apns-push-type: widgets`), coalesced per device.
2. Member with alerts on: the new-post alert (`notifications.push`) with `mutable-content`; the notification service
   extension downloads `media.widget_path` into the App Group and requests a reload (budgeted).
3. iOS < 26 or muted: background push (≤ 2–3 per hour per device); the app downloads and reloads.
4. Safety net: iOS timeline `.after(now + 15…60 min)` with per-device jitter; Android periodic update hourly
   (`widget.android.duration.updatePeriod`); app foreground reloads everything.
5. Android: high-priority FCM only with a visible notification → expedited WorkManager job → download →
   `GlanceAppWidget.updateAll`; muted groups get normal priority.
6. On the widget the new image **replaces the old one instantly** (`widget.arrival.duration.transition` = 0).

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| swap | `widget.arrival.duration.transition` | — | new timeline entry / Glance update with no transition |
| expected delay | `widget.arrival.duration.expectedDelay` (QA bound) | `widget.arrival.help.delay` (help / FAQ, e.g. in `onboarding.widget` or settings help) | never claim "instant" |
| Android refresh notification | channel IMPORTANCE_MIN | title `widget.arrival.android.refreshTitle`; channel `widget.arrival.android.refreshChannelName` / `.refreshChannelDescription` | only while a refresh runs as a foreground job (expedited work on Android 11 and lower needs `ForegroundInfo`) |

## States

| state | behaviour |
|---|---|
| loading (first rendition not cached) | `widget.home.small` loading state |
| error / offline | keep the last photo (HIG); retry on the next opportunity |
| muted group | widget still updates (silent paths, SPEC_FLAGS T6) |
| notifications denied | widget push (iOS 26+) / background push / timeline / periodic update still update |
| empty / permission-denied | n/a |

## Motion

None (0-ms swap; within HIG's ≤ 2 s allowance). Reduce Motion: unchanged.

## Haptics

None.

## Accessibility

The widget's label updates with the content (`widget.home.small.a11y.*`); no announcement is posted.

## Data & actions

- Server: `create_post` enqueues `widget.refresh` (dedupe per group) and `push.new_post`; the worker sends the new-photo
  alert (the Notification Service Extension writes the widget) or a background push with the widget fields (iOS) and FCM
  messages (Android). No WidgetKit push: the app has no widget push handler (docs/WIDGET_REFRESH.md).
- Client: the app writes each group's newest photo or collage into the widget store whenever it loads groups and feeds,
  and reloads the timelines (docs/WIDGET_REFRESH.md "The app itself").
- Renditions: `media.widget_path` / `collages.widget_path` (signed URLs, 1 h).

## Platform notes

iOS: 40–70 reloads / day per widget, entries ≥ 5 min apart, NSE reloads best-effort, widget pushes opportunistic.
Android: `updatePeriodMillis` ≥ 30 min honoured (Retro's 1 h); high-priority FCM only with a visible notification.

## Do-not-copy

"It instantly appears on your Locket widget!" and any "instant" claim; Locket's and Retro's names in help text;
Retro's "Refreshing" toast on tap (our tap opens the camera).

## Gaps

| item | status | capture |
|---|---|---|
| how a current iOS widget animates an arrival (Retro or Locket) | not observed; instant swap (Locket 2022) | 10-s iPhone recording of the Home Screen while a friend posts |
| `docs/WIDGET_REFRESH.md` (SPEC_FLAGS P1) | does not exist | engineering doc |

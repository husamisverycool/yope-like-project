# widget.arrival — how a new photo reaches a member's widget

Reference: **Locket** (help center statement, 2022 screen recording of the swap, Android refresh pipeline) + platform
limits (docs/PLATFORM_CONSTRAINTS.md §1, §4). Expectation: **up to a few minutes**, never "instant" in copy.

## References

| image / source | what it verifies |
|---|---|
| `references/auto/locket/frames/locket-tt-7168613044728155438-15.133s-widget-placeholder-just-added.jpg` → `15.167s-widget-photo-arrived.jpg` | the new image replaces the old in one frame (≤ 33 ms), no fade or slide |
| https://help.locket.com/en/articles/5859739-why-isn-t-my-locket-widget-updating (2026-05-05) | "a slight delay of up to 5 minutes. This delay helps conserve your phone’s battery." |
| `references/auto/locket/help/locket-help-5859739-widget-refresh-placeholder-crop.png` | help drawing (not an app screenshot; not used) |
| Locket APK 1.243.0 manifest + strings (`WidgetRefreshReceiver`, `AlarmReceiver`, short foreground service, 'Updating widget...', channel 'Widget Updating') | Android pipeline |

## Structure

No screen. The sequence for each recipient device after `create_post` (`widget.refresh` job per group):

1. iOS 26+: widget push (`apns-push-type: widgets`), coalesced per device by the server.
2. Member with alerts on: the new-post alert (`notifications.push`) with `mutable-content`; the notification service
   extension downloads `media.widget_path` into the App Group and requests a reload (budgeted).
3. iOS < 26 or muted: background push (≤ 2–3 per hour per device), the app downloads and reloads.
4. Timeline safety net: `.after(now + 15…60 min)` with per-device jitter; app foreground reloads everything.
5. Android: high-priority FCM only together with a visible notification → expedited WorkManager job → download →
   `GlanceAppWidget.updateAll`; muted groups get normal priority. Safety net `widget.android.duration.updatePeriod`.
6. On the widget, the new image **replaces the old one instantly** (`widget.arrival.duration.transition` = 0).

## Elements

| element | tokens | copy | behavior |
|---|---|---|---|
| swap | `widget.arrival.duration.transition` | — | new timeline entry / Glance update with no transition (SwiftUI: no `contentTransition`, `.transition(.identity)`) |
| expected delay | `widget.arrival.duration.expectedDelay` (QA bound) | `widget.arrival.help.delay` (help / FAQ text, e.g. in `onboarding.widget` or settings help) | never claim "instant" |
| Android refresh notification | — | `widget.arrival.android.refreshTitle`, channel `widget.arrival.android.refreshChannelName` / `.refreshChannelDescription` | shown only while a refresh runs as a foreground job (expedited work on Android 11 and lower needs `ForegroundInfo`); the channel is low importance |

## States

| state | behavior |
|---|---|
| loading (first rendition not cached) | `widget.home.small` placeholder |
| error / offline | keep the last photo (stale data shown, HIG); retry on the next refresh opportunity |
| muted group | widget still updates (silent paths only, SPEC_FLAGS T6) |
| notifications denied | no alert path; widget push (iOS 26+) / background push / timeline still update |
| empty / permission-denied | n/a |

## Motion

None (0 ms swap). Within HIG's ≤ 2 s allowance. Reduce Motion: unchanged.

## Haptics

None.

## Accessibility

The widget's label updates with the content (`widget.home.small.a11y.*`); the Home Screen does not announce widget
changes (no announcement is posted).

## Data & actions

- Server: `create_post` enqueues `widget.refresh` (dedupe per group) and `push.new_post`; the worker sends widget
  pushes to `devices.widget_push_token` (iOS) and FCM messages (Android).
- Client: `register_device(p_widget_push_token)` whenever the WidgetKit push token changes.
- Renditions: `media.widget_path` / `collages.widget_path` (signed URLs, 1 h).

## Platform notes

iOS budgets: 40–70 reloads/day per widget; entries ≥ 5 min apart; NSE reloads are best-effort; widget pushes are
opportunistic (iOS 26+). Android: `updatePeriodMillis` ≥ 30 min; high-priority FCM only with a visible notification
(else deprioritized). Full details: docs/PLATFORM_CONSTRAINTS.md §1.1–1.6, §4.3–4.5.

## Do-not-copy

The store copy "it instantly appears on your Locket widget!" and any "instant" claim; Locket's trademark in the help text.

## Gaps

| item | status | capture |
|---|---|---|
| how the current iOS Locket widget animates an arrival (iOS 17+) | not observed (2022 instant swap used) | 10-s iPhone recording of the Home Screen while a friend sends a photo |
| `docs/WIDGET_REFRESH.md` (referenced by SPEC_FLAGS P1) | does not exist | engineering doc, not a design capture |

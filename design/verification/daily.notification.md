# Verification — `daily.notification` (iOS, Pass 4 — Retro redesign)

Daily invitation push (system-drawn) — presentation in `ios/NotificationService/Sources/NotificationPresentation.swift`; texts from the worker.

Checklist written from the spec (`design/surfaces/daily.notification.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>-<light|dark>.png` (every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/daily.notification.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (post_reminder_notification_*)`, `references/auto/bereal/help/help-21089073691933_time-to-bereal-push.png (mechanics)`

Snapshots (CI, `ios/build/snapshots/capture/`): none (system UI)

**Summary: 3 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Presentation

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `daily.notification.layout.delivery` | ios: interruption-level active; passive during quiet hours; thread-id = group id; default sound (none in quiet hours); ios_liveActivities: the Live Activity push-to-start alert is the invitation (no second notification); android: channel daily_invitation; one notification per group per day; no reminder, no update on window close (PLATFORM) | interruption level active (passive in quiet hours), thread = group | `NotificationPresentation.apply`: time-sensitive / critical → active, passive kept, thread = group id (unit-tested) |
| matched | `notifications.push.dailyInvitation.title` | “{group}” (SOURCED) | "{group}" | worker copy (no app code) |
| matched | `notifications.push.dailyInvitation.body` | “What are you up to right now?” (SOURCED) | "What are you up to right now?" | worker copy |

## Notes

- No app-drawn UI: nothing to snapshot. The Live Activity start alert is the invitation where Live Activities are allowed (daily.liveactivity).

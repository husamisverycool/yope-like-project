# Verification — `notifications.push` (iOS, Pass 4 — Retro redesign)

iOS presentation of every push — `ios/NotificationService/Sources/NotificationPresentation.swift`, `NotificationService.swift`; texts are the worker's.

Checklist written from the spec (`design/surfaces/notifications.push.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>-<light|dark>.png` (every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/notifications.push.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (notification_settings_description_*, post_reminder_notification_*)`

Snapshots (CI, `ios/build/snapshots/capture/`): none (system UI)

**Summary: 3 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## iOS presentation

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `notifications.push.layout.ios` | interruptionLevel: active (passive during quiet hours); threadId: group id; newPostAttachment: widget rendition attached by the notification service extension; sound: default (PLATFORM) | active (passive in quiet hours), never time-sensitive; thread = group; new-post photo attachment | `apply(to:)` lowers time-sensitive / critical, keeps passive, threads by group; `attachesPhoto` only for `new_post` |
| matched | `notifications.push.newPost.body` | “{name} just posted.” (SOURCED) | "{name} just posted." | worker copy |
| matched | `notifications.push.reaction.body` | “{name} reacted {emoji} to your post.” (SOURCED) | "{name} reacted {emoji} to your post." | worker copy |

## Notes

- System-drawn; nothing to snapshot.

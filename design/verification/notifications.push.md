# Verification — `notifications.push` (iOS)

iOS presentation of every push — Notification Service Extension.

Checklist written from the spec (`design/surfaces/notifications.push.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>.png`, then `tools/sidebyside.py` makes `design/verification/notifications.push.png` next to the reference image(s) below.

Reference image(s): `references/auto/bereal/help/help-21089073691933_time-to-bereal-push.png`

Snapshots (CI): 

**Summary: 1 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Values

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `notifications.push.layout.ios` | interruptionLevel: active (passive during quiet hours); threadId: group id; newPostAttachment: widget rendition attached by the notification service extension; sound: default (PLATFORM) | interruption active / passive; thread = group id; new-post attachment = widget rendition; default sound | NotificationPresentation.apply + rendition attachment (existing) |

## Notes

- Texts come from the worker (`backend/worker/COPY_KEYS.md`).

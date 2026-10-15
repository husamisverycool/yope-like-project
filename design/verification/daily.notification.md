# Verification — `daily.notification` (iOS)

Invitation push presentation — `ios/NotificationService/Sources/NotificationPresentation.swift`; categories in AppServices `PushService`.

Checklist written from the spec (`design/surfaces/daily.notification.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>.png`, then `tools/sidebyside.py` makes `design/verification/daily.notification.png` next to the reference image(s) below.

Reference image(s): `references/auto/bereal/help/help-21089073691933_time-to-bereal-push.png`

Snapshots (CI): 

**Summary: 3 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Values

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `daily.notification.layout.delivery` | ios: interruption-level active; passive during quiet hours; thread-id = group id; default sound (none in quiet hours); ios_liveActivities: the Live Activity push-to-start alert is the invitation (no second notification); android: channel daily_invitation; one notification per group per day; no reminder, no update on window close (PLATFORM) | active (passive in quiet hours), thread = group | NSE lowers time-sensitive → active; thread id = group_id; category = push type |
| matched | `notifications.push.dailyInvitation.title` | “Time to share a photo.” (SOURCED) | title | sent by the worker |
| matched | `notifications.push.dailyInvitation.body` | “Capture a photo and see what {group} is up to!” (SOURCED) | body | sent by the worker |

## Notes

- No in-app screen: system UI. Categories carry no actions (no action copy exists); the tap opens daily.capture (DeepLinkParser).

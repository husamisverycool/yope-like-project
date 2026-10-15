# daily.notification — the daily same-moment invitation push

Reference: **BeReal** (push structure and voice) with the mandatory tenet-5 adaptations (design/copy-patterns.md
"BeReal → daily invitation"; docs/SPEC_FLAGS.md T4): no ⚠️, no TIME SENSITIVE, no "2 min left", no "late", no
follow-up, answering after the window posts normally.

## References

| image | what it verifies |
|---|---|
| `references/auto/bereal/help/help-21089073691933_time-to-bereal-push.png` (lossless) | title / body / 'now' / TIME SENSITIVE header (structure only) |
| `references/auto/bereal/frames/appstore-preview-2026_t0.30s_notification.png` | same text in 2026 |
| `references/auto/bereal/help/help-36182541825309_realgroup-notification-settings.png` | per-group daily toggle exists (settings surfaces own it) |

## Structure

A standard system notification, one per group per day, at the group's `fires_at` (the same instant for every member):

| platform | presentation | title | body |
|---|---|---|---|
| iOS with Live Activities allowed (push-to-start token) | the Live Activity starts; its start alert **is** the invitation (no second notification) → `daily.liveactivity` | `notifications.push.dailyInvitation.title` | `notifications.push.dailyInvitation.body` |
| iOS without Live Activities | standard alert, interruption level **active** (passive in quiet hours), thread = group | same | same |
| Android | the countdown notification in channel `daily_invitation` → `daily.ongoing` | same | same |

Delivery rules: `daily.notification.layout.delivery`; platform alert anatomy is the system's (app icon, app name,
'now', title, body).

## Elements

| element | tokens | copy | behavior |
|---|---|---|---|
| title | system notification title style | `notifications.push.dailyInvitation.title` ("Time to share a photo.") | — |
| body | system body style | `notifications.push.dailyInvitation.body` ("Capture a photo and see what {group} is up to!", {group} = group name) | — |
| tap | — | — | opens `daily.capture` (`app://daily?group=<id>&invitation=<id>`); after `closes_at` the same tap opens `daily.capture` without a countdown and the photo posts as an ordinary post |
| Android channel | `notifications.push.layout.channels.daily_invitation` | `notifications.push.channel.dailyInvitation.name` / `.description` | created once; importance cannot change later |

## States

| state | behavior |
|---|---|
| member muted the group | nothing is sent (widgets still get the collage later) |
| quiet hours | delivered silently (iOS passive; Android quiet hours on the device) |
| notifications not allowed | nothing visible; the group screen shows the open invitation (owned there) |
| window closes | nothing is sent; iOS: the Live Activity ends (dismissal immediate); Android: the notification times out; an iOS alert left in Notification Center stays and opens a normal capture |
| loading / empty / error / offline | n/a (system UI) |

## Motion

System presentation only.

## Haptics

System notification haptic / sound (`aps.sound = default`, none in quiet hours) — PLATFORM.

## Accessibility

System-read notification (title then body). No emoji, so nothing is read as a symbol name.

## Data & actions

- Worker: `invitation.fire` job at `fires_at` (backend/worker/src/jobs/invitation.ts) reads the copy keys above with
  `{group}`; one concurrent batch per group (SPEC_FLAGS P4).
- Payload keys: `type = daily_invitation`, `group_id`, `invitation_id` (DeepLinkParser → `.dailyInvitation`).
- `daily_invitations` row is readable after `fires_at`; `closes_at = fires_at + invitation_window_seconds` (120 s).

## Platform notes

- **Code to change (C-10):** `backend/worker/src/push/payloads.ts` marks the iOS fallback alert `time-sensitive`, and
  `AppChannel.DailyInvitation`'s comment calls it Time Sensitive; this spec requires `active` (tenet filter).
  Android `IMPORTANCE_HIGH` (heads-up) is kept: it does not override Do Not Disturb.
- No Time Sensitive Notifications capability is needed by this spec (docs/OWNER_SETUP mentions it for the worker's
  current behavior).

## Do-not-copy

'⚠️ Time to BeReal. ⚠️', 'TIME SENSITIVE', '2 min left …', 'Go, go, go!', 'your friends will know you posted late',
'{name} and {count} others posted', the brand used as a verb, any second reminder.

## Gaps

| item | status | capture |
|---|---|---|
| BeReal's Android notification wording / channel | not found | one Android screenshot of BeReal's daily push with the shade expanded |

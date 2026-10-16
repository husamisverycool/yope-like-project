# daily.notification — the daily same-moment invitation push

**Visual / voice reference: Retro's post reminder** — a local notification titled with its context ("Week %1$d") and
a `retro.voice.prompt` question as the body ("Anything from today you want to remember?", APK
`post_reminder_notification_*`) — with the tenet-5 rule of `design/copy-patterns.md` ("Daily invitation"): one alert at
the start of the window, no time-sensitive level, no deadline, no brand verb. **Mechanics: BeReal** (one invitation per
group per day at the same instant for everyone; a short window). The notification itself is drawn by the system
(PLATFORM). Decisions: `design/MERGE_DECISIONS.md` RC-16.

## References

| source | what it verifies |
|---|---|
| `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` `post_reminder_notification_title_template` "Week %1$d", `post_reminder_notification_message` "Anything from today you want to remember?" | Retro's invitation-to-share notification: context title + one prompt question |
| `design/research/retro-package-copy-motion.md` §6.2 (`PostReminderWorker`, Sharing Reminders Daily / Weekly / Monthly / Never) | one reminder per period, member-controlled |
| `references/auto/bereal/help/help-21089073691933_time-to-bereal-push.png` | mechanics: one push at the window start (structure only) |
| `references/auto/bereal/help/help-36182541825309_realgroup-notification-settings.png` | per-group daily toggle exists (owned by the settings surfaces) |

## Structure

A standard system notification, one per group per day at the group's `fires_at`:

| platform | presentation | title | body |
|---|---|---|---|
| iOS with Live Activities allowed (push-to-start token) | the Live Activity starts; its start alert **is** the invitation → `daily.liveactivity` | `notifications.push.dailyInvitation.title` ("{group}") | `notifications.push.dailyInvitation.body` ("What are you up to right now?") |
| iOS without Live Activities | standard alert, interruption level **active** (passive in quiet hours), thread = group | same | same |
| Android | countdown notification in channel `daily_invitation` → `daily.ongoing` | same | same |

Delivery rules: `daily.notification.layout.delivery`. Anatomy (app icon, app name, time, title, body) is the system's.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| title | system title style | `notifications.push.dailyInvitation.title` ({group}) | the context, as Retro's "Week N" (the worker fills only {group} for this key) |
| body | system body style | `notifications.push.dailyInvitation.body` | one `retro.voice.prompt` question; no deadline, no countdown text |
| tap | — | — | `app://daily?group=<id>&invitation=<id>` → `daily.capture`; after `closes_at` the same tap opens `daily.capture` without a countdown and the photo posts as an ordinary post |
| Android channel | `notifications.push.layout.channels.daily_invitation` | `notifications.push.channel.dailyInvitation.name` / `.description` | created once; importance fixed at creation |

## States

| state | behaviour |
|---|---|
| member muted the group | nothing is sent (widgets still get the collage later) |
| quiet hours | delivered silently (iOS passive; Android device quiet hours) |
| notifications not allowed | nothing visible; the group screen shows the open invitation (owned there) |
| window closes | nothing is sent; iOS: the Live Activity ends; Android: the notification times out; an iOS alert left in Notification Center still opens a normal capture |
| loading / empty / error / offline | n/a (system UI) |

## Motion

System presentation only.

## Haptics

System notification haptic / sound (`aps.sound = default`, none in quiet hours) — PLATFORM.

## Accessibility

Read by VoiceOver / TalkBack as title then body. No emoji.

## Data & actions

- Worker `invitation.fire` job at `fires_at` (backend/worker/src/jobs/invitation.ts) reads the copy keys above with
  `{group}`; one concurrent batch per group (SPEC_FLAGS P4).
- Payload: `type = daily_invitation`, `group_id`, `invitation_id` (DeepLinkParser → `.dailyInvitation`).
- `daily_invitations` is readable after `fires_at`; `closes_at = fires_at + invitation_window_seconds`.

## Platform notes

- **Code to change (C-10, still open):** `backend/worker/src/push/payloads.ts` marks the iOS fallback alert
  `time-sensitive`; this spec requires `active`.
- Android `IMPORTANCE_HIGH` (heads-up) is kept: it does not override Do Not Disturb.

## Do-not-copy

Retro: "Finish setting up your Retro!" nudges, Sunday "Week N is almost over" second reminder (we send one per event).
BeReal: '⚠️ Time to BeReal. ⚠️', 'TIME SENSITIVE', '2 min left …', 'Go, go, go!', 'your friends will know you posted
late', '{name} and {count} others posted', the brand used as a verb.

## Gaps

| item | status | capture |
|---|---|---|
| Retro's post-reminder notification as rendered on a device | strings only (APK) | one screenshot of Retro's "Week N" reminder on the Lock Screen |
| "Week {number}" as the title | needs a `{week}` placeholder the worker does not send | worker change (owner / worker team) |

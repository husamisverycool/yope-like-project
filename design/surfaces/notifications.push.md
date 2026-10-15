# notifications.push — every push text the app sends

References per event (docs/SURFACES.md): **BeReal** (daily invitation, adapted for tenet 5), **Locket** (new post,
reactions, Android channels), **Yope** (replies, recap ready), **Tribute / VidDay** (birthday request, tribute for
you). Keys are exactly those the worker calls (`backend/worker/COPY_KEYS.md`, `WORKER_COPY_KEYS` in
`backend/worker/src/copy.ts`); placeholders are only the ones the worker fills for each key. Only real events; no
reminders, no "you haven't…", no counts.

## References

| image / source | event |
|---|---|
| `references/auto/bereal/help/help-21089073691933_time-to-bereal-push.png`, `references/auto/bereal/frames/appstore-preview-2026_t0.30s_notification.png` | daily invitation (structure only) |
| Locket APK 1.243.0 `moment_notif_*`, Hermes reaction strings, notification channel strings (design/research/locket.md §9) | new post, reaction, channels |
| `references/auto/yope/frames/a-savannahclooney-7683341732695592206-t6.73-*` ('new pic added · 9:43 AM'), `references/auto/yope/frames/b-yrrah-7673901254787009810-t11.30-sent-to-wall.png` ('yrrah sent a pic to the wall · 9:00 PM') | Yope confirmation voice for reply and recap lines (Yope push texts were not found, yope-a §6) |
| design/research/wrapped-tribute-partiful.md §3.5 (VidDay V3), §4 (VidDay V7, Tribute T5–T6) | birthday request, tribute |

## Structure

Every push is a system notification: **title** + **body** (Android requires a title; iOS shows both), iOS thread =
group id, Android channel per kind (`notifications.push.layout.channels`), iOS presentation
`notifications.push.layout.ios` (interruption level active, passive in quiet hours; never time-sensitive).

| event (worker job) | title key → text | body key → text | channel | tap → |
|---|---|---|---|---|
| daily invitation (`invitation.fire`) — surface `daily.notification` | `notifications.push.dailyInvitation.title` → "Time to share a photo." | `notifications.push.dailyInvitation.body` → "Capture a photo and see what {group} is up to!" | `daily_invitation` | `daily.capture` |
| new post (`push.new_post`) | `notifications.push.newPost.title` → "{group}" | `notifications.push.newPost.body` → "{name} sent you a photo!" | `new_post` | the post (`app://post`) |
| reaction to your photo (`push.reaction`) | `notifications.push.reaction.title` → "{group}" | `notifications.push.reaction.body` → "{name} reacted {emoji} to your photo" | `reactions_replies` | the post |
| reply to you — text | `notifications.push.reply.title` → "{group}" | `notifications.push.reply.body.text` → "{name} replied · {message}" | `reactions_replies` | the message (`app://chat`) |
| reply to you — voice | same title | `notifications.push.reply.body.voice` → "{name} replied with a voice message" | `reactions_replies` | the message |
| reply to your photo with a photo | same title | `notifications.push.reply.body.photo` → "{name} replied with a pic" | `reactions_replies` | the post |
| weekly recap ready (`recap.generate` done) | `notifications.push.recapReady.title` → "{group}" | `notifications.push.recapReady.body` → "new recap added" | `recap` | `week.recap` (`app://recap`) |
| birthday contribution request (`push.birthday_request`) — never to the birthday person, once, no reminders | `notifications.push.birthdayRequest.title` → "{group}" | `notifications.push.birthdayRequest.body` → "You’re invited to add a photo and a line for {name}’s birthday. It’s quick and easy." | `birthday_request` | `birthday.request` |
| tribute for you (`tribute.render` delivered) | `notifications.push.tribute.title` → "Happy birthday!" | `notifications.push.tribute.body` → "{group} made you a birthday video." | `tribute` | `birthday.tribute` |

Android channel names / descriptions (user-visible in system settings): `notifications.push.channel.newPost.*`,
`.reactionsReplies.*`, `.recap.*`, `.birthdayRequest.*`, `.tribute.*`, and `.dailyInvitation.*` (surface
`daily.notification`). The widget-refresh channel is `widget.arrival.android.*`.

## Elements

| element | tokens | copy | behavior |
|---|---|---|---|
| title | system | the title keys above | {group} keeps its case |
| body | system | the body keys above | {name} = first word of the sender's `display_name`; {emoji} = the reaction emoji; {message} = reply text (worker shortens it only if over APNs' 4 KB) |
| photo attachment (new post, iOS) | `notifications.push.layout.ios.newPostAttachment` | — | the notification service extension attaches the widget rendition (also feeds the widget) |
| grouping | `notifications.push.layout.ios.threadId`; Android `setGroup(group_id)` | — | one stack per group |
| reaction replacement | — | — | a newer reaction push to the same photo replaces the previous one on the device (worker collapse id) |

## States

| state | behavior |
|---|---|
| member muted the group | no new-post / reply / reaction / invitation push for that group; widgets still update |
| quiet hours | delivered silently (iOS passive, no sound; Android device quiet hours) |
| blocked person | no push from or about them (worker) |
| unreact before send | the reaction push is cancelled (worker) |
| notifications not allowed | nothing visible; the app works without pushes (App Review 4.5.4) |
| loading / empty / error / offline / permission-denied (in app) | n/a (system UI); the notifications permission ask belongs to `onboarding.permission.notifications` |

## Motion

System.

## Haptics

System sound / haptic per channel; none custom.

## Accessibility

Read by VoiceOver / TalkBack as title then body; {emoji} in the reaction body is read by its system name. No other
emoji in any text.

## Data & actions

Worker payload keys: `type` (`daily_invitation`, `new_post`, `reaction`, `reply`, `recap_ready`, `birthday_request`,
`tribute`) + `group_id` / `post_id` / `message_id` / `invitation_id` / `recap_id` / `request_id` / `tribute_id`
(`ios/Packages/AppCore/Sources/AppModels/PushPayload.swift`, DeepLinkParser). The `widget` and
`daily_invitation_ended` types are silent.

## Platform notes

- iOS: `UNNotificationContent` from APNs; Live Activity start alert for the invitation (`daily.liveactivity`).
- Android: channels must exist before posting (`NotificationChannels.register` with these strings);
  importance is fixed at creation (`notifications.push.layout.channels`). `AppChannel.YearStory` has no event the
  worker sends — no copy is provided; registering an empty channel would advertise a notification that never comes
  (owner decision).
- Not sent (no event): ordinary chat messages that are not replies, "year story ready".

## Do-not-copy

'{name1}, {name2}, and {n} other friends sent you Lockets!' (count); "It's been #day# days since your last Locket"
and 'Tap to update your Locket' (guilt / nag); 'Daily Reminders' channel; '{name} and {count} others posted a BeReal';
'⚠️ Time to BeReal. ⚠️', '2 min left …', TIME SENSITIVE; birthday reminder chains and countdowns ('Submissions are due
in: 3d 12h'); 'From Russell and 36 others' (contributor count); every trademark (Locket, BeReal, Rollcall, Tribute,
VidDay, Yope).

## Gaps

| item | status | capture |
|---|---|---|
| Locket's iOS push banners (title of a single-sender push) | not observed; group name used as title | 2 iOS notification-banner screenshots (new Locket, reaction) |
| Yope push texts | not found | one screenshot of a Yope reply / recap notification |
| Tribute / VidDay "your video is ready" text | not found | one Tribute or VidDay delivery email / push |
| `AppChannel.YearStory` copy | owner decision | owner |

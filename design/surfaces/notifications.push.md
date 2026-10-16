# notifications.push — every push text the app sends

**Voice reference: Retro's notifications** (`retro.voice.push`, `retro.voice.push-channel`): title = the context or
the sender, body = one line — a `retro.voice.prompt` question for invitations, a plain statement with a period for
activity ("%1$s just posted."), a quoted comment after a colon ("%1$s commented on your post: "…"") — one notification
per event; Android channel names in Title Case with one-line descriptions ("New Posts — Recent posts from users you care
about"). **Mechanics:** BeReal (daily timing), Locket (reaction content: name + emoji, no count), Tribute / VidDay
(birthday request and tribute). The notification is drawn by the system (PLATFORM). Keys and placeholders are exactly
those the worker calls (`backend/worker/COPY_KEYS.md`, `WORKER_COPY_KEYS` in `backend/worker/src/copy.ts`).
Decisions: `design/MERGE_DECISIONS.md` RC-16, RC-18.

## References

| source | what it verifies |
|---|---|
| `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` `post_reminder_notification_*`, `notification_settings_description_*` ("%1$s just posted.", "%1$s commented on your post: "Wow this looks yummy!"", "%1$s reshared your post."), `notification_channel_display_*` | title / body forms, punctuation, channel naming |
| `design/research/retro-package-copy-motion.md` §6.2 | one notification per event; reply / mute actions exist in Retro (`Reply`, `Mute This Post`) |
| Locket APK 1.243.0 reaction strings (design/research/locket.md §9) | reaction content: name + emoji inline, no count |
| design/research/wrapped-tribute-partiful.md §3.5, §4 | birthday request (one private request, no reminders) and tribute delivery |

## Structure

Every push is a system notification: **title** + **body**; iOS thread = group id; Android channel per kind
(`notifications.push.layout.channels`); iOS presentation `notifications.push.layout.ios` (interruption level active,
passive in quiet hours; never time-sensitive).

| event (worker job) | title key → text | body key → text | channel | tap → |
|---|---|---|---|---|
| daily invitation (`invitation.fire`) — `daily.notification` | `notifications.push.dailyInvitation.title` → "{group}" | `notifications.push.dailyInvitation.body` → "What are you up to right now?" | `daily_invitation` | `daily.capture` |
| new post (`push.new_post`) | `notifications.push.newPost.title` → "{group}" | `notifications.push.newPost.body` → "{name} just posted." | `new_post` | the post (`app://post`) |
| reaction to your photo (`push.reaction`) | `notifications.push.reaction.title` → "{group}" | `notifications.push.reaction.body` → "{name} reacted {emoji} to your post." | `reactions_replies` | the post |
| reply — text | `notifications.push.reply.title` → "{group}" | `notifications.push.reply.body.text` → "{name} replied: "{message}"" | `reactions_replies` | the message (`app://chat`) |
| reply — voice | same title | `notifications.push.reply.body.voice` → "{name} replied with a voice message." | `reactions_replies` | the message |
| reply to your photo with a photo | same title | `notifications.push.reply.body.photo` → "{name} replied with a photo." | `reactions_replies` | the post |
| weekly recap ready (`recap.generate`) | `notifications.push.recapReady.title` → "{group}" | `notifications.push.recapReady.body` → "This week's recap is ready." | `recap` | `week.recap` (`app://recap`) |
| birthday request (`push.birthday_request`) — never to the birthday person; once | `notifications.push.birthdayRequest.title` → "{group}" | `notifications.push.birthdayRequest.body` → "You're invited to add a photo and a line for {name}'s birthday. No pressure." | `birthday_request` | `birthday.request` |
| tribute for you (`tribute.render` delivered) | `notifications.push.tribute.title` → "Happy birthday!" | `notifications.push.tribute.body` → "{group} made you a birthday video." | `tribute` | `birthday.tribute` |

Android channels (system settings): `notifications.push.channel.newPost.*` ("New Posts"), `.reactionsReplies.*`
("Post Activity"), `.recap.*` ("Weekly Recaps"), `.birthdayRequest.*` ("Birthday Requests"), `.tribute.*` ("Birthday
Videos"), `.dailyInvitation.*` ("Daily Invitation", surface `daily.notification`); widget refresh:
`widget.arrival.android.*` ("Background Work").

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| title | system | title keys above | {group} keeps its case |
| body | system | body keys above | {name} = first word of `display_name`; {emoji} = the reaction emoji; {message} = reply text (shortened by the worker only over 4 KB) |
| photo attachment (new post, iOS) | `notifications.push.layout.ios.newPostAttachment` | — | the notification service extension attaches the widget rendition |
| grouping | `notifications.push.layout.ios.threadId`; Android `setGroup(group_id)` | — | one stack per group |
| reaction replacement | — | — | a newer reaction push to the same photo replaces the previous one (worker collapse id) |
| small icon / colour (Android) | — | — | monochrome app glyph (owner asset, BLOCKED); no `setColor` (Retro's tint not captured) |

## States

| state | behaviour |
|---|---|
| member muted the group | no new-post / reply / reaction / invitation push for that group; widgets still update |
| quiet hours | delivered silently |
| blocked person | no push from or about them (worker) |
| unreact before send | the reaction push is cancelled (worker) |
| notifications not allowed | nothing visible; the app works without pushes (App Review 4.5.4) |
| loading / empty / error / offline / permission-denied (in app) | n/a (system UI); the permission ask belongs to `onboarding.permission.notifications` |

## Motion

System.

## Haptics

System sound / haptic per channel; none custom.

## Accessibility

Read by VoiceOver / TalkBack as title then body; {emoji} is read by its system name; no other emoji. Contrast:
system-drawn in the current appearance.

## Data & actions

Worker payload keys: `type` (`daily_invitation`, `new_post`, `reaction`, `reply`, `recap_ready`, `birthday_request`,
`tribute`) + `group_id` / `post_id` / `message_id` / `invitation_id` / `recap_id` / `request_id` / `tribute_id`
(`ios/Packages/AppCore/Sources/AppModels/PushPayload.swift`, DeepLinkParser). `widget` and `daily_invitation_ended`
are silent.

## Platform notes

- iOS: `UNNotificationContent` from APNs; Live Activity start alert for the invitation (`daily.liveactivity`).
- Android: channels registered before posting (`NotificationChannels.register` with these strings); importance fixed at
  creation (`notifications.push.layout.channels`). `AppChannel.YearStory` has no event — no copy (owner decision).
- Text changes need no code change: the worker reads the keys at run time; placeholders are a subset of those it fills.

## Do-not-copy

Retro: "Relive %1$d memories…" (count), "%1$s liked your post." (likes), "%1$s says you're friends, that true?",
"Finish setting up your Retro!", Sunday second reminder, "Media activity, such as comments and likes." Locket: "{name1},
{name2}, and {n} other friends sent you Lockets!", "It's been #day# days since your last Locket", 'Daily Reminders'.
BeReal: '⚠️ Time to BeReal. ⚠️', '2 min left …', TIME SENSITIVE. Birthday reminder chains, countdowns, contributor
counts. Every trademark.

## Gaps

| item | status | capture / decision |
|---|---|---|
| Retro push banners as rendered (iOS / Android) | strings only (APK) | 2 screenshots of a Retro "just posted" notification (iOS + Android) |
| "Week {number}" as the invitation title (Retro's form) | needs a week placeholder the worker does not send | worker change |
| `AppChannel.YearStory` copy | owner decision | owner |
| Android small icon | BLOCKED (owner app icon) | owner asset |

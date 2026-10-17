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
| `design/research/retro-package-copy-motion.md` §6.2 | one notification per event; reply / mute actions exist in Retro (`Reply`, `Mute This Post`; `MessageReplyNotificationReceiver`) |
| https://support.apple.com/104982 (accessed 2026-10-17) | Messages: reply to a message from the Lock Screen or Notification Center (touch and hold, type, send) |
| https://developer.android.com/develop/ui/views/notifications/build-notification (accessed 2026-10-17) | Android direct reply (`RemoteInput`, mutable PendingIntent, update or cancel the notification after the reply), action buttons |
| https://support.google.com/photos/answer/9454489 (accessed 2026-10-17) | memories notifications are a setting the person turns on (opt-in) |
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
| year story ready (`push.year_story`, once: the first time the story is ready; the 31 December refresh and other recomputes never notify — owner decision 31) | `notifications.push.yearStory.title` → "{group}" | `notifications.push.yearStory.body` → "Your {year} Recap is ready." | `year_story` | `year.story` (`app://year-story`) |
| memory (`push.memory`, opt-in in `settings.notifications` "Memories"; only on a local day with a memory, at most once a day — docs/API.md §5.21) | `onthisday.push.title` → "On This Day" | `onthisday.push.body` → "Relive your memories from this day over the years." | `memories` | the photo (`post_id`) in the viewer (`app://post`) |

Android channels (system settings): `notifications.push.channel.newPost.*` ("New Posts"), `.reactionsReplies.*`
("Post Activity"), `.recap.*` ("Weekly Recaps"), `.birthdayRequest.*` ("Birthday Requests"), `.tribute.*` ("Birthday
Videos"), `.yearStory.*` ("Year in Photos"), `.memories.*` ("Memories" — "Your memories from this day over the years"),
`.dailyInvitation.*` ("Daily Invitation", surface `daily.notification`); widget refresh:
`widget.arrival.android.*` ("Background Work"). iOS: the memory alert has its category (type `memory`) with no actions.

## Actions (owner decision 34, research #9)

Reply and react from the alert, and mute the group, without opening the app (Apple Messages from the Lock Screen;
Android direct reply; Retro's "Reply" and "Mute This Post"). The system draws the buttons and the reply field (PLATFORM);
the titles are copy. Shared rule: `AppModels/NotificationActions.swift` (`NotificationAction.actions(for:)`) and
`android/core/push` `AlertActions.forAlert`.

| alert (type) | actions, in order |
|---|---|
| new photo (`new_post`, the overnight reveal included) | Reply · the first quick reaction · Mute This Group |
| reply (`reply`: a chat message or a photo) | Reply · Mute This Group |
| reaction to your photo (`reaction`) | Reply · Mute This Group |
| daily invitation, widget, recap, birthday request, tribute, year story, plan, memory | none (an invitation is never a task; the others open a page) |

| action | copy | does | after |
|---|---|---|---|
| Reply | `notifications.push.action.reply` "Reply"; field placeholder `chat.composer.placeholderReply` "Reply…", send `chat.composer.a11y.send` "Send" (iOS) | `send_message(p_group_id, 'text', p_body, p_reply_to_message_id)` for an alert naming a message, else `p_reply_to_post_id` (the photo); blank text sends nothing | the alert goes (Android cancels it; iOS removes it) |
| quick reaction | the emoji itself: the first of `chat.reactions.layout.quickReactions` (🔥) | `react(p_post_id, emoji)` | the alert goes |
| Mute This Group | `notifications.push.action.mute` "Mute This Group" (Retro "Mute This Post", post → group) | `set_group_muted(p_group_id, true)` — the same mute as `groups.settings` "Group updates" off | the alert goes |
| any failure (signed out, offline, refused) | reply `chat.thread.sendFailed` "Couldn't send. Tap to retry"; reaction `chat.reactions.error`; mute `settings.notifications.error` | a notification with the alert's title and this line; tapping it opens what the alert opened; no actions; silent | — |

- iOS: one `UNNotificationCategory` per push type, registered once at launch (`PushService.install`; the worker sets
  `aps.category` = type); Reply is a `UNTextInputNotificationAction`. Every action has `.authenticationRequired` (it
  speaks for the person; the session is in the Keychain) and no `.foreground`: iOS launches the app in the background and
  `AppEnvironment.performNotificationAction` calls the API with the stored session.
- Android: actions built per notification (`AlertActions.addTo`), broadcasts to `AlertActionReceiver` (not exported) that
  run the call with `goAsync` (≤ 8 s) through the data layer (`DataGraph` sets `AlertActions.performer`). Reply carries a
  `RemoteInput` (`FLAG_MUTABLE`, explicit intent), `SEMANTIC_ACTION_REPLY`; mute `SEMANTIC_ACTION_MUTE`; all
  `setAuthenticationRequired(true)`. Success cancels the alert; a failure replaces it (same tag and id, so the reply
  field's progress ends).
- Blocks: an action only answers what the alert shows; the worker sends no alert from or about a person with a block.

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
`tribute`, `year_story`, `plan`, `memory`) + `group_id` / `post_id` / `message_id` / `invitation_id` / `recap_id` / `request_id` / `tribute_id` /
`year` (`year_story`: the story's year, a string)
(`ios/Packages/AppCore/Sources/AppModels/PushPayload.swift`, DeepLinkParser). `widget` and `daily_invitation_ended`
are silent.

**Deleted content is withdrawn** (directive Part 6, "Deleting a photo removes it everywhere"): an alert that shows a post
or a chat message (its `post_id` / `message_id` / link) leaves Notification Center / the shade once the app learns of the
deletion — the group's Realtime deletion broadcast while the app runs, the check of every shown alert's post against
the server at launch and on each return to the foreground, and the background push (iOS) / FCM widget message
(Android) the worker sends when the deletion changes the widget (`AppModels/NotificationWithdrawal.swift`,
`AppServices/DeliveredNotifications.swift`; Android `core/push` `DeliveredAlerts`). Platform limit: neither APNs nor FCM
can remove a delivered notification from the server, so with the app not running and no background push let through
(force-quit iPhone app, Doze), the alert stays until the app next runs.

## Platform notes

- iOS: `UNNotificationContent` from APNs; Live Activity start alert for the invitation (`daily.liveactivity`).
- Android: channels registered before posting (`NotificationChannels.register` with these strings); importance fixed at
  creation (`notifications.push.layout.channels`). `AppChannel.YearStory` carries the year story's one push
  (`notifications.push.channel.yearStory.*`).
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
| `AppChannel.YearStory` copy | closed 2026-10-17: the worker sends `year_story` once (owner decision 31) | — |
| Android small icon | BLOCKED (owner app icon) | owner asset |

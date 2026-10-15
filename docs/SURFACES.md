# Surface inventory

> **Owner decision 2026-10-15**: each surface keeps the primary reference listed here; any other
> successful app may fill what the primary reference doesn't show (`docs/OWNER_DECISIONS.md`).

Every screen and system surface in the app, with the reference app assigned to it (directive
Part 3). A reference is used only on the surfaces listed for it. Each surface gets a build spec at
`design/surfaces/<id>.md` once its references are gathered.

Two pseudo-surfaces hold values shared across screens: `global` (app-wide foundations: background,
text colors, accent, type scale, spacing, motion, haptics — Yope as the primary reference, platform
font) and `global.system` (native components used on system surfaces per Apple HIG / Material 3).

Every app surface needs these states, each with sourced design and copy:
**loading · empty · error · offline · permission-denied** (where a permission applies).

## Getting in

| id | surface | reference | notes |
|---|---|---|---|
| `invite.web` | Invite link web page seen before install: group, members, what you're joining, get-the-app CTA | Partiful (event invite page) | Web; also the App Clip card content and the Android web fallback |
| `invite.appclip` | iOS App Clip: same preview, join after install | Partiful + Apple HIG (App Clips) | |
| `auth.phone` | Phone number entry | Yope onboarding | |
| `auth.code` | SMS code entry | Yope onboarding | |
| `auth.agegate` | Birthday / age gate at sign-up | Yope onboarding | Birthday may also seed the optional birthday feature (opt-in) |
| `auth.profile` | Name + avatar | Yope onboarding | |
| `onboarding.permission.camera` | In-context camera permission | Yope | Then the system prompt (Apple HIG / Material 3) |
| `onboarding.permission.notifications` | In-context notifications permission | Yope | |
| `onboarding.permission.photos` | In-context photo library (limited access supported) | Yope | |
| `onboarding.permission.contacts` | Optional contacts | Yope | Skippable |
| `onboarding.widget` | Guided add-the-widget step | Locket | |

## Groups

| id | surface | reference |
|---|---|---|
| `groups.list` | Group list / home; switch between groups | Yope |
| `groups.create` | Create group: name, cover, type (friends, family, roommates, custom) | Yope |
| `groups.invite` | Invite by link or from contacts | Yope |
| `groups.screen` | Group screen (the group's photos, members, entry to chat, walls, week, settings) | Yope |
| `groups.settings` | Members (admin can remove), leave, mute, quiet hours, invitation hours / pause, report, block | Yope + Apple HIG / Material 3 |

## Posting

| id | surface | reference |
|---|---|---|
| `camera.capture` | Opens to camera; one tap captures; Live Photo; video (premium) | Yope + Locket |
| `camera.sendto` | Choose one or more groups; optional caption and voice note; send (no mandatory edit) | Yope + Locket |
| `camera.fromwidget` | Widget tap opens straight into the camera | Locket |

## Photos coming to you

| id | surface | reference |
|---|---|---|
| `widget.home.small` / `.medium` / `.large` / `.xl` | Home-screen widgets per group: newest photo; after a daily invitation, the collage | Locket |
| `widget.lock.rect` / `.circular` / `.inline` | Lock-screen widgets | Locket |
| `widget.arrival` | How a new photo arrives on the widget | Locket |
| `widget.android` | Glance widgets (all sizes) | Locket (Android) + Material 3 |

## Group chat

| id | surface | reference |
|---|---|---|
| `chat.thread` | Photos, text, replies to specific photos, voice messages together | Yope |
| `chat.composer` | Text, camera (reply with a photo), voice | Yope |
| `chat.voice` | Voice message record + playback | Yope |
| `chat.reactions` | Any-emoji reactions on photos; never shown as numbers | Locket (reactions) |
| `photo.viewer` | Full photo: caption, voice note, reactions, reply, "I'm in this", delete, report, save | Yope + Locket |

## Walls

| id | surface | reference |
|---|---|---|
| `walls.mine` | My wall: my photos as a collage | Yope |
| `walls.member` | A member's wall (only photos from shared groups) | Yope |
| `walls.browse` | Browse walls of people in your groups | Yope |

## Daily invitation

| id | surface | reference |
|---|---|---|
| `daily.notification` | The invitation push | BeReal (minus urgency/guilt framing that breaks tenet 5) |
| `daily.capture` | Capture with countdown; front + back together; sequential fallback | BeReal |
| `daily.liveactivity` | Live Activity countdown (iOS) | BeReal + Apple HIG (Live Activities) |
| `daily.ongoing` | Ongoing notification countdown (Android) | BeReal + Material 3 |
| `daily.dualimage` | How the two images are shown together | BeReal |
| `collage.view` | The same-moment collage (owner picks from options) | BeReal dual image + Yope walls composition |
| `collage.share` | Share image sized for Stories | Yope share (recap "share") |

## The week

| id | surface | reference |
|---|---|---|
| `week.recap` | Sunday recap of the group's week | Yope recaps (organized by week per Retro) |
| `week.edit` | Reorder, remove, edit recap; save selection as named album | Yope |
| `week.history` | Scroll back week by week | Retro |
| `albums.list` / `albums.view` | Saved albums | Yope |

## Remembering

| id | surface | reference |
|---|---|---|
| `onthisday` | Photos from this date in past years | Timehop |
| `birthday.add` | Add your birthday (optional) | Yope (onboarding voice) |
| `birthday.request` | Private request to contribute a photo + one line | Tribute / VidDay |
| `birthday.contribute` | Contribution flow (only photos you posted or are tagged in) | Tribute / VidDay |
| `birthday.tribute` | The tribute video for the birthday person | Tribute / VidDay |
| `year.story` | December tap-through year story + share cards | Spotify Wrapped |
| `tagging` | "I'm in this" self-tag | Yope voice (no face recognition) |

## Account, notifications, subscription, safety

| id | surface | reference |
|---|---|---|
| `settings.root` | Settings | Apple HIG / Material 3 |
| `settings.notifications` | Per-group mute, quiet hours | Apple HIG / Material 3 |
| `settings.account` | Account, delete account | Apple HIG / Material 3 |
| `settings.blocked` | Blocked people | Apple HIG / Material 3 |
| `paywall` | Premium screen and perks; at most one prompt per session | Locket (Gold) |
| `safety.report` | Report flow | Apple HIG / Material 3 (Yope voice for copy) |
| `safety.block` | Block flow | Apple HIG / Material 3 (Yope voice for copy) |
| `system.permissions` | System permission prompts and purpose strings | Apple HIG / Material 3 |
| `notifications.push` | All push texts (daily invitation, new post, reaction/reply to you, recap ready, birthday request, tribute for you) | BeReal (daily), Locket (new post, reactions), Yope (replies, recap), Tribute/VidDay (birthday) |

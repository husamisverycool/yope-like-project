# Surface inventory

> **Owner decision 2026-10-15** (redesign): **Retro** is the single visual reference for every surface
> (docs/DESIGN_DIRECTION.md, docs/REDESIGN_BRIEF.md). Each surface below names its **visual reference** — the
> Retro screen it follows, by the screen numbers of `design/research/retro-visual.md` §2 (inventory) and §5
> (mapping) — and, where Retro has no such feature, its **mechanics reference**: the app that defines what the
> controls do and the flow. Screens without a Retro analog are composed only from Retro components
> (`design/components.md`) in the mechanics reference's order. Copy voice is Retro's everywhere
> (`design/copy-patterns.md`); system components are Apple HIG / Material 3 (PLATFORM).

Two pseudo-surfaces hold values shared across screens: `global` (app-wide foundations: palette in light and
dark, type roles, spacing, radii, icons, motion, haptics — Retro) and `global.system` (native components on
system surfaces — Apple HIG / Material 3, with Retro's Android colour scheme).

Every app surface needs these states, each with sourced design and copy:
**loading · empty · error · offline · permission-denied** (where a permission applies), in **light and dark**.

Retro screen ids used below (retro-visual §2): 1 home empty week · 2 home populated · 4 profile · 5 profile with
empty days · 8 friends tab · 9 friend requests · 10 albums list · 11 albums pushed + search · 12 journal templates ·
13 album detail · 14 album share flow · 15 media viewer · 16 feature-intro sheet · 17 postcard composer ·
18 "Add a Message" modal · 19 create recap · 20 recap preview · 21 yearly recap card · 22–25 Rewind (player,
playing, menu, share) · 26 sign-up landing · 27 paywall · 28 settings sheet · 30 composer "Add to Your Week" ·
31 messages inbox · 32 Instagram story sticker · 34 widgets · 35 web invite / album pages.

## Getting in

| id | surface | visual reference (Retro) | mechanics reference |
|---|---|---|---|
| `invite.web` | Invite link web page seen before install: group, members, what you're joining, get-the-app CTA | 35 — retro.app `/u/[username]` (blurred-photo background, avatar, serif headline, "Let's go" pill) and `/j/[slug]` (album page) | — (Retro has the analog); web, also the Android fallback |
| `invite.appclip` | iOS App Clip: same preview, join after install | 35 — `/u/` page and its App Clip card (`io.lonepalm.Retro.Clip`) | Apple HIG (App Clips) |
| `auth.phone` | Phone number entry | 26 landing (RAW dark) + Retro sign-up order phone → code → username → full name (APK); form screens not captured — text field C-12 | — |
| `auth.code` | SMS code entry | 26 + APK sign-up form (AUTH_CODE); field C-12 | — |
| `auth.agegate` | Birthday / age gate at sign-up | 26 (legal line "I confirm that I am %1$d or older"); composed of C-12 / C-05 | Apple HIG / Material 3 (date picker) |
| `auth.profile` | Name + avatar | 26 + APK (USER_NAME, FULL_NAME, PROFILE_PHOTO steps) | — |
| `onboarding.permission.camera` | In-context camera permission | 16 feature-intro sheet or 1 empty-state block; Retro pre-prompt copy (`composer_permission_upsell_*`) | Apple HIG / Material 3 (system prompt) |
| `onboarding.permission.notifications` | In-context notifications permission | 16 / 1; Retro "Never miss a message" pre-prompt | Apple HIG / Material 3 |
| `onboarding.permission.photos` | In-context photo library (limited access supported) | 16 / 1; Retro "Allow Access to Photos" pre-prompt | Apple HIG / Material 3 |
| `onboarding.permission.contacts` | Optional contacts | 16 / 1; Retro "No Contacts Access" pre-prompt | Apple HIG / Material 3 |
| `onboarding.widget` | Guided add-the-widget step | 28 (Settings → Widgets carousel), 34 (widget art), Retro widget upsell copy | Locket (widget steps) |

## Groups

| id | surface | visual reference (Retro) | mechanics reference |
|---|---|---|---|
| `groups.list` | Group list / home; switch between groups | 10, 11 (Albums list: serif title, 3:4 cover rows, avatar stack, "+" circle; pushed with search) and 2 (home title + friend cards) | — |
| `groups.create` | Create group: name, cover, type (friends, family, roommates, custom) | 12 (journal templates Event / Friends / Couple + "Create" pills), name field C-12 | — |
| `groups.invite` | Invite by link or from contacts | 14 (link sharing flow: cover sheet, black capsule, grouped menu with red destructive row, share targets), 8 ("Invite") | — |
| `groups.screen` | Group screen (the group's photos, members, entry to chat, walls, week, settings) | 13 (album detail: cover, serif name, grey meta, outline pills, dated 3-column grid) + 2 (members' weeks as friend cards) | — |
| `groups.settings` | Members (admin can remove), leave, mute, quiet hours, invitation hours / pause, report, block | 28 (settings sheet: grouped rows), 9 (people rows), 24 (native menu, red destructive) | Apple HIG / Material 3 (switches, pickers, alerts) |
| `question.weekly` | One light question for the group each week, answered with a photo; the answers seen together; removable, no push, no tally | 2 (feed cards in the group screen's pager: C-18, scrim, C-09 light pill) + C-06; Retro "what to share" prompt cards (APK) | Retro prompt cards, Apple Journal (reflection prompts, Remove), BeReal (prompt over capture) |

## Plans

| id | surface | visual reference (Retro) | mechanics reference |
|---|---|---|---|
| `plans.create` | Make a plan in a group: cover, title, date / all-day / time, place (typed text), note | 12 / 13 (New Album flow as composed for `groups.create`: cover, C-07, C-12, C-05 on a C-29 sheet) | Apple Invites (create order, all-day), Partiful (New Event sheet, place row) |
| `plans.page` | One plan: details, Going · Maybe · Can't go, who's coming (names, never a count), the plan's photos; edit, cancel, restore | 13 (album detail: cover, serif name, grey meta, C-06 capsules, 3-column grid), 9 (people rows) | Apple Invites (event page, cancel / restore), Partiful (answers, list visibility) |
| `plans.list` | Every plan of a group: Upcoming, Past Plans, Canceled (reached from the group screen's plans block) | 10 / 11 (Albums list: pushed serif header, C-15 rows with a 3:4 cover) + C-20 section labels | Apple Invites (Upcoming / Past Events categories, "+"), Partiful (Past Events) |
| `widget.countdown` | Home-screen widget: the next plan, in days (never hours) | 34 (Retro widgets: full-bleed photo, white stack bottom-trailing) as `widget.home.small` | Apple Invites widget ("count down the days"), Widgetsmith; WidgetKit / Glance (PLATFORM) |

## Posting

| id | surface | visual reference (Retro) | mechanics reference |
|---|---|---|---|
| `camera.capture` | Opens to camera; one tap captures; Live Photo; video (premium) | no analog — media surface (black, C-11 glass / media circles, 22 Rewind controls layout) | Locket (camera), Yope |
| `camera.sendto` | Choose one or more groups; optional caption and voice note; send (no mandatory edit) | 30 (composer sheet "Add to Your Week": Cancel / title / Update, strip, grid), 17 (postcard composer: "Add a message" pill, 60 pt capsule), 8 (avatar grid) | Locket, Yope (send-to flow) |
| `camera.trim` | A library video longer than the camera's limit is trimmed before send-to (short videos; the server enforces the same limit) | no analog in Retro's visuals (its Android "Trim Video" editor was not captured) — iOS: the system trimmer (UIVideoEditorController); Android: media surface with C-29 header, Material 3 range slider | Retro (editor wording, "Video too long"), Apple (system trimmer) |
| `camera.fromwidget` | Widget tap opens straight into the camera | no analog — as `camera.capture` | Locket |
| `camera.quickaccess` | Control Center / Lock Screen / Action button control, App Shortcuts, Android Quick Settings tile and launcher shortcuts that open the camera | no analog — system components | Snapchat (Lock Screen control); Apple HIG / Material 3 (PLATFORM) |
| `share.in` | "Share to Jolt": photos and videos shared from Photos and other apps open `camera.sendto` with them (several photos in one post; signed out → sign-in first) | no analog — the system share sheet (PLATFORM), then `camera.capture` / `camera.sendto` | Apple Shared Albums "Share → Add to Shared Album" (support.apple.com/108314); Android "receive simple data" (developer.android.com/training/sharing/receive) |
| `camera.overnight` | Camera mode "9 AM · Now": photos develop for the chosen groups at 9 AM in the group's time zone; nobody sees them before; one developing tile per group | 19 (native segmented control on black, TC-REC) on the `camera.capture` media surface; C-09 pill, C-17 placeholder tile, C-29 sheet | Dispo (switch, 9 AM reveal, shoot to rolls), Lapse (no preview, one alert, sequential review) |

## Photos coming to you

| id | surface | visual reference (Retro) | mechanics reference |
|---|---|---|---|
| `widget.home.small` / `.medium` / `.large` / `.xl` | Home-screen widgets per group (or All Groups): newest photo; after a daily invitation, the collage | 34 (Retro widgets: full-bleed photo, 22 dp corners, white name + place stack bottom-right) | Locket (widget behaviour) |
| `widget.friend` | Friend Updates: one person's newest photo (posted by them or tagged "I'm in this"), every home-screen size | 34 (Retro's Friend Updates widget) | Locket (one-friend widget) |
| `widget.memories` | Your Memories: your own photo from this day in an earlier year, every home-screen size | 34 (Retro's Your Memories widget) | Retro ("time hop back to your own memories"), `onthisday` |
| `widget.styles` | Widget styles: Photo (free), Date and Frame (premium) on every home-screen photo widget | 22–23 (Rewind date), 20 (recap preview: instant print on the blurred backdrop) | Locket Gold (widget frames) |
| `widget.lock.rect` / `.circular` / `.inline` | Lock-screen widgets | no analog — PLATFORM (WidgetKit accessory families) | Locket, Apple HIG |
| `widget.arrival` | How a new photo arrives on the widget | 34 | Locket |
| `widget.android` | Glance widgets (all sizes) | 34 (Retro's Glance widgets: 2×2, 22 dp, states "No media. Tap to reload") | Locket (Android) + Material 3 |

## Group chat

| id | surface | visual reference (Retro) | mechanics reference |
|---|---|---|---|
| `chat.thread` | Photos, text, replies to specific photos, voice messages together | 31 (Messages inbox: serif "Messages", search, rows); thread bubbles not captured — composed from C-13 / C-16 | Messages / WhatsApp (thread behaviour), Yope |
| `chat.composer` | Text, camera (reply with a photo), voice | 15 (comment field: 48 pt, #262626 / fill, own avatar, trailing glyph) — C-13 | Messages, Yope |
| `chat.voice` | Voice message record + playback | no analog — composed of C-13, C-11, C-25 | Messages / WhatsApp, Yope |
| `chat.reactions` | Any-emoji reactions on photos; never shown as numbers | 15 (reaction slot in the viewer footer; Retro's heart like is do-not-copy) | Locket (reactions) |
| `photo.viewer` | Full photo: caption, voice note, reactions, reply, "I'm in this", delete, report, save | 15 (media viewer: black page, header avatar ring + name + "Week N", close, footer, comments, reply field), 24 (native menu) | Yope + Locket (actions) |
| `viewer.selfiereaction` | React to a photo with a live front-camera selfie; faces on the photo's corner, never a count | 15 (media viewer) composed of C-09, C-11, C-16, C-22, C-23, C-29 | BeReal (Instant RealMoji) |

## Walls

| id | surface | visual reference (Retro) | mechanics reference |
|---|---|---|---|
| `walls.mine` | My wall: my photos as a collage | 4 (profile: serif name, real name, 64 avatar, info rows, outline pills, week sections with strips), 5 | — |
| `walls.member` | A member's wall (only photos from shared groups) | 4 (another person's profile) | — |
| `walls.browse` | Browse walls of people in your groups | 8 (friends: serif title, search, 3-column 81 pt avatars) | — |

## Daily invitation

| id | surface | visual reference (Retro) | mechanics reference |
|---|---|---|---|
| `daily.notification` | The invitation push | Retro post reminder ("Week N" / "Anything from today you want to remember?", APK) | BeReal (minus urgency / guilt framing that breaks tenet 5) |
| `daily.capture` | Capture with countdown; front + back together; sequential fallback | no analog — media surface as `camera.capture` | BeReal |
| `daily.liveactivity` | Live Activity countdown (iOS) | no analog — dark media tokens, serif week title if a title is used | BeReal + Apple HIG (Live Activities) |
| `daily.ongoing` | Ongoing notification countdown (Android) | no analog — PLATFORM notification | BeReal + Material 3 |
| `daily.dualimage` | How the two images are shown together | 21 / 23 (recap card on a backdrop), 13 (2 pt grid) | BeReal (dual image) |
| `collage.view` | The same-moment collage (owner picks from options) | 21 (yearly recap card), 20 (recap preview: card on blurred backdrop, page dots, "Share") | BeReal dual image + group composition |
| `collage.share` | Share image sized for Stories | 20 (recap preview + Share), 32 (story sticker), 21 (serif year + name + domain footer) | Yope share (recap "share") |

## The week

| id | surface | visual reference (Retro) | mechanics reference |
|---|---|---|---|
| `week.recap` | Sunday recap of the group's week | 19 (Create Recap: segmented control, serif month cards), 20 (preview + Share), 21 | Yope recaps (organized by week per Retro) |
| `week.edit` | Reorder, remove, edit recap; save selection as named album | 30 (composer strip editing), 3 ("•••" per week — contents not captured) | Yope |
| `week.history` | Scroll back week by week; jump to a date from a calendar of the days that have something | 4, 5 (profile week sections: "Week N" + range, strip, "•••") | BeReal Memories calendar (jump to a date) |
| `search.photos` | Search the photos (captions, chat about a photo, a member or "I'm in this", dates; no face or AI search, no counts) from the group list or one group | 11 (Albums pushed + search field), 13 (album grid) | Yope (search on the group list), Retro albums search, Apple Shared Albums (filters) |
| `albums.list` / `albums.view` | Saved albums | 10 / 13 (Albums list, album detail) | Apple Shared Albums (anyone adds; you remove what you added) |
| `favorites` | Your private favorites (only you see them) | 11 / 13 (pushed header, album grid) | Apple Photos Favorites |

## Remembering

| id | surface | visual reference (Retro) | mechanics reference |
|---|---|---|---|
| `onthisday` | Photos from this date in past years | 22–25 (Rewind: full-bleed photo, serif date + chevron, "On this week", glass "•••", dial with tick haptic, 64 pt glass circles, native menu / share) | — (Retro has the analog; Timehop no longer referenced) |
| `birthday.add` | Add your birthday (optional) | 26 / 1 patterns (field on the landing / empty-state layout) | — |
| `birthday.request` | Private request to contribute a photo + one line | 27 (card on blurred backdrop, serif headline, 60 pt capsule), 16 (feature-intro sheet) | Tribute / VidDay |
| `birthday.contribute` | Contribution flow (only photos you posted or are tagged in) | 17, 18 (postcard composer, "Add a Message" modal with 250-character counter), 30 | Tribute / VidDay |
| `birthday.tribute` | The tribute video for the birthday person | 22 / 23 (full-bleed media + serif date), 20 (preview), page dots | Tribute / VidDay |
| `year.story` | December tap-through year story + share cards | 22 / 23, 20, 21; Retro "Year in Photos" retrospective copy (APK) | Spotify Wrapped (pacing) |
| `tagging` | "I'm in this" self-tag | composed of C-06 (outline → primary toggle) | — (no face recognition) |

## Account, notifications, subscription, safety

| id | surface | visual reference (Retro) | mechanics reference |
|---|---|---|---|
| `settings.root` | Settings | 28 (settings sheet: profile card, grouped Fill rows, section headers, chevrons) | Apple HIG / Material 3 (switches, pickers) |
| `settings.notifications` | Per-group mute, quiet hours | 28 (Notification Settings rows; "Pause All") | Apple HIG / Material 3 |
| `settings.account` | Account, delete account | 28 (Account section; "Delete Account" red row) | Apple HIG / Material 3 |
| `account.delete.web` | Web page for deleting an account without the app (`GET /delete-account`, Google Play requirement) | 35 — the invite page's state card / column | Google Play account deletion requirements |
| `support.web` | Web page with the support address (`GET /support`, the App Store's Support URL) | 35 — the invite page's state card / column | App Store Connect "Support URL" |
| `settings.blocked` | Blocked people | 28 + 9 (people rows) | Apple HIG / Material 3 |
| `settings.hidden` | Hidden Memories: the photos and days you hid from your memories, to show again (owner decision 34) | 28 + 9 (rows with a capsule action) | Timehop (hidden memory settings, "UNHIDE"), Google Photos (hidden dates) |
| `paywall` | Premium screen and perks; at most one prompt per session | 27 (Retro Premium paywall, RAW: glass close, serif headline, plan card on blurred backdrop, 60 pt capsule, "Cancel anytime") | StoreKit / Play Billing (purchase sheet, PLATFORM) |
| `safety.report` | Report flow | 24 (native menu, red destructive) + Retro report sheet copy ("Why are you reporting this post?") | Apple HIG / Material 3 |
| `safety.block` | Block flow | 24 + Retro confirm ("Block %1$s?") | Apple HIG / Material 3 |
| `system.permissions` | System permission prompts and purpose strings | — | Apple HIG / Material 3 |
| `notifications.push` | All push texts (daily invitation, new post, reaction/reply to you, selfie reaction, recap ready, birthday request, tribute for you, plan made / tomorrow / changed / cancelled; photos developed is `camera.overnight`'s) | Retro notifications (post reminder, "%1$s just posted.", "%1$s commented on your post", "On This Week") | BeReal (daily timing), Locket (reaction content), Tribute / VidDay (birthday) |

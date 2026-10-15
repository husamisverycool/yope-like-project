## Voice patterns

Every pattern a string may name in its `pattern` field. Each one comes from a research pass in
`design/research/` (ids kept as the researchers wrote them; where a pass described a voice without
naming it, the id below is new and the section it comes from is cited). Examples are verbatim, with
their source. A string follows the pattern of the reference assigned to its surface in
`docs/SURFACES.md` (map at the end), after the tenet filters in "Adaptation rules".

Evidence shorthands: `yope-a`, `yope-b`, `locket`, `bereal`, `retro-timehop`,
`wrapped-tribute-partiful`, `platform` = `design/research/<name>.md`. Video ids (V-mthu, V-chuong …)
and image ids (S1, S5, L, W-inv …) are the source tables at the top of those files.

### Yope (app-wide in-app voice)

| id | governs | rules (case · person · length · punctuation · emoji) | verbatim examples (source) | do-not-copy |
|---|---|---|---|---|
| `yope.voice.lowercase` | every Yope-referenced app surface | Every in-app string is lowercase, first word and headings included; proper names keep their own case ("Oblong", "Gabriel"). Exceptions seen: the HUD word "Loading", the recap card label in uppercase, dates "Oct 30 2025" / "26 May", 2024-build Sentence case. | "who would you like to add?" (yope-a §3.2, V-mthu) · "you created group" (V-mthu) · "hold down to record" (V-jacob) · "yope is all about sharing moments" (yope-a §3.1, L 1.212) · "share with friends" (yope-b §9, S5) | The "YOPE" wordmark; "yope" itself (→ `{app_name}`). |
| `yope.voice.second-person` | all Yope surfaces | Speaks to the user as "you / your", about the people around them; casual, present tense; never "users"; no "I". | "can’t see your friends?" (yope-a §2.8, V-chuong) · "who would you like to add?" (V-mthu) · "you’re friends!✨ share a pic?" (V-mthu) · "your space with friends got a glow up" (L 1.229) · "you sent to Oblong" (yope-b §4, S5) | — |
| `yope.voice.button` | buttons on Yope surfaces | 1-3 words, lowercase, verb first, no final punctuation, no emoji; a recipient count may follow as a separate black disc (not a social count). | "create group" · "invite more friends" (V-mthu) · "enable" · "send" (V-chuong) · "continue" / "join friends by link" (yope-a §3.2, BI 2025) · "new recap" (V-mthu) · "view recap" (yope-b §6, S6) | — |
| `yope.voice.title` | screen and sheet titles | Short lowercase noun phrase; pickers end with "..." (three periods, no space). | "new group" (V-mthu) · "send to..." (V-chuong, V-sav, V-jacob) · "suggested friends" (V-chuong) · "me & friends" (yope-b §5, S5) | — |
| `yope.voice.placeholder` | text fields | Lowercase instruction; "(optional)" marks optional fields; "..." ends open text; "to {name}" names the recipient. | "name group (optional)" (V-mthu) · "add a message" (V-chuong) · "start typing..." (S5 store) · "message..." (yope-b §2, S5) · "message to Oblong" (yope-b §2, S5 t57.07) | "message to Sabrina...." has four dots in O5 (owner image); use three. |
| `yope.voice.coach` | first-use tooltips | Lowercase imperative, ≤ 6 words, dismissible ✕, no emoji in the text (a leading glyph is allowed). | "hold down to record" (V-jacob, V-alexaa) · "add a voice memo on this pic" (V-chuong, V-jacob) · "tap one time" / "tap ‘allow’" (yope-a §2.5, 2024 build) | — |
| `yope.voice.confirmation` | toasts, system messages, success states, Yope's push lines | Past-tense statement of what happened, lowercase, no exclamation mark. | "posted in the wall" (V-chuong) · "you created group" (V-mthu) · "new pic added" (V-sav) · "Kailyn joined" (BI 2025) · "yrrah sent a pic to the wall · 9:00 PM" (yope-b §5, S7 Live Activity) | — |
| `yope.voice.empty-state` | empty states on every Yope surface | Bold statement + italic / gray detail that names people + one light pill action. | "you created group" / "and added mẹ, Anh" / "invite more friends" (V-mthu t51.23) · "skip the queue and create one now" / "new recap" (V-mthu, V-arkadeep) · "No messages yet!" / "Chat with someone new" (2024 build, V-yrrah24) | "Add {n} pics more to get a recap" is a progress count toward an unlock (tenet 5) — do not copy the count framing. |
| `yope.voice.permission` | in-app permission asks (`onboarding.permission.*`) | In-app ask = a question about the benefit to the person's people + a plain one-word action. Yope's system purpose strings are one benefit sentence ("So you can …", "This lets you …", "We need your mic to …"); on `system.permissions` the HIG pattern `platform.purposeString` governs. | "can’t see your friends?" / "enable contacts" / "enable" (V-chuong t7.73) · "Allow camera access. So you can take and share pics with friends" (V-virgi, V-yrrah24) · "This lets you share memories from your library." (V-yrrah24) · "We need your mic to record your voice in video reactions." (V-virgi) | The notification pre-prompt that imitates the iOS alert with a lime "Allow" and an arrow (V-virgi t7.23); "share what you’re up to / to unlock the group for 24h" (post-to-unlock gate); forced invites before using the app (yope-a §5). |
| `yope.voice.error` | error, offline and permission-denied states | Calm, blame-free, names the next step, ends warm; no emoji in product UI. | "This invite has expired" / "Ask your friend to send you a new link." / "Your next memories are waiting." (yope-a §1.8, W-inv) · "sorry about the crashes 😭 please send your username, device model, and a screen recording…" (support reply, L — tone only) | Support-reply emoji and text-speak (see `yope.voice.support`). |
| `yope.voice.release-notes` | release notes / store text only | Lowercase line-broken fragments; triplets with periods; em dashes; light slang. | "fewer steps. less noise. more sharing." (L 1.208) · "no audience. no pressure." (L) · "just a lil metadata update — so you can find us faster" (L 1.201) | "streaks that make friendships stronger" (L). |
| `yope.voice.support` | **not for product UI** | Very casual text-speak (u, ur, thx, ty, tho) and many emoji (💖🫶🙏😭✨🛠️). | "thx for keeping it real 🙏 we hear u & we’re working hard…" · "ouchhh 😭🙏 we hear u loud & clear." · "hey! so sorry u had that experience 😭" (all L, developer replies) | Do not use in the app. |
| `yope.voice.emoji` | all Yope surfaces | At most one emoji in a UI string, used as warmth, never in buttons or titles; emoji otherwise appear only as quick reactions and user content. | "you’re friends!✨ share a pic?" (V-mthu) · quick reactions ❤️ 😂 🔥 inside the 1:1 field (yope-b §2, S5) · none in any button or title across all frames (yope-a §4, yope-b §11) | 🔥 streak pills. |
| `yope.voice.punctuation` | all Yope surfaces (yope-b §11, id new) | No terminal period on labels; "&" instead of "and"; ranges with a bare hyphen, no spaces; em dash with spaces inside longer sentences. | "me & friends" (S5) · "daily & monthly recaps" (S2 headline) · "21-27 dec" (S5) · "— so you can find us faster" (L 1.201) | — |
| `yope.voice.formats` | times, dates, durations, week labels (yope-b §1-6, id new) | Time `h:mm AM/PM` (no leading zero); duration `mm:ss` with leading zeros; month label lowercase "month yyyy"; week label lowercase "d mmm-d mmm"; recap card label = the week label in uppercase; viewer date "Mmm d yyyy"; day title "d Month". | "10:00 PM" (S1), "8:47 PM" (S5) · "00:38" (S1) · "december 2025" · "21-27 dec" (S5) · "18 aug-24 aug" / "18 AUG-24 AUG" (owner yope-week-recap.jpg) · "Oct 30 2025" (S5) · "26 May" (S6) | — |

### Locket (widgets, camera-from-widget, reactions, paywall, new-post and reaction pushes)

The research (locket §11) lists five voice features without ids; the ids below are new.

| id | governs | rules | verbatim examples (source) | do-not-copy |
|---|---|---|---|---|
| `locket.voice.second-person` | all Locket-referenced surfaces | Second person, warm, short; "pics" used colloquially. | "Add your friends" (LZ) · "Live pics from your friends, on your home screen" (APK, LZ) · "Send pics to friends’ Home Screens" (locket §11) | "0 of 5 friends added" (count). |
| `locket.voice.exclamation` | confirmations and benefit lines | An exclamation mark on confirmations and benefits; not on labels. | "Sent you a Locket!" (APK) · "Welcome to Gold!" (MB) · "No thanks!" (MB) · "Never see an ad in History!" (MB) · "Add as many friends as you’d like!" (MB) | Ads; "Unlimited friends" vs a cap. |
| `locket.voice.ellipsis` | placeholders and progress text | Three-period ellipsis ends placeholders and in-progress states. | "Send message..." · "Send to..." · "Reply to {{name}}..." · "Updating widget..." · "Plus so much more..." (APK, MB) | — |
| `locket.voice.sentence-case` | labels, perk titles, steps | Mostly Sentence case; step lines are imperative sentences. | "Remove ads" · "Upload from camera roll" (MB) · "Hold down on an empty\nspace on your Home Screen" · "How to add the widget" (APK) | — |
| `locket.voice.title-case-names` | product, widget and screen names | Title Case for named things. | "Locket Widget" · "Best Friend Widget" (2025 gallery) · "Widget Tutorial" (APK) · "Locket Gold" (MB) | The names themselves (trademark) → `{app_name}`. |
| `locket.widget.gallery` | widget gallery description, Android picker description (`widget.*`) | One line starting with a verb or a noun phrase about live photos from your people; also satisfies `platform.widgetDescription` when it starts with a verb. | "See live pics from all your friends right on your Home Screen" (iOS gallery 2022) · "Live pics from your friends, on your home screen" (APK `app_widget_description`) · "…a special widget just for your best friend" (2025 gallery, first word cut off) | "{count} Friends" previews as a score; "Crush Widget". |
| `locket.widget.empty` | empty / unconfigured widget (`widget.*`) | Two short Sentence-case lines: state, then the one action. | "No pics yet" · "Tap to set up" (APK strings `no_pics_yet`, `tap_to_set_up`) · "No reactions yet" (APK, reactions) | — |
| `locket.onboarding.widgetSteps` | `onboarding.widget` | Title "Add the widget to your home screen" form; numbered imperative steps that name the system UI ("Edit", "Add Widget", "Widgets"); a closing "You're done!". | "Add the widget\nto your home screen" · "Tap the “Widgets” button\nto add a new widget" (APK) · "Tap Edit in the upper-left corner." / "Tap Add Widget." / "You're done!" (help 7914857) | "Locket doesn't work unless you add the widget to your home screen." (pressure); "Have you enabled the widget?" gate. |
| `locket.push.newPost` | new-post push (`notifications.push`) | Body names who sent, in a list with "and"; one exclamation mark; fallback sender "A friend". | "Sent you a Locket!" · "{name1} and {name2} sent you Lockets!" · "{name1}, {name2}, and {name3} sent you Lockets!" · "A friend" (APK `moment_notif_*`) | "{n} other friends" (count); "It's been #day# days since your last Locket" and "Tap to update your Locket" (guilt / nag); the noun "Locket" (trademark). |
| `locket.push.reaction` | reaction push and reaction activity (`notifications.push`, `chat.reactions`) | "{name} reacted {emoji} to {whose} {photo}" — the emoji inline, no count, no period. | "{{contactName}} reacted {{emoji}} to your Locket" · "{{contactName}} reacted {{emoji}} to {{name}}'s Locket" · "You reacted {{emoji}} to {{name}}'s Locket" · "{{name}} sent {{emoji}}" (APK) | "{{friendsCount}} friends sent {{emojis}}" (count); the push text itself was not observed (locket §9). |
| `locket.push.channel` | Android notification channels (`notifications.push`, `daily.ongoing`) | Channel name: 1-3 words, Title Case; description: one Sentence-case line without a period. Limits: name ≤ 40, description ≤ 300 characters (platform §daily.ongoing). | "New Lockets" / "Notifications when friends post new Lockets" · "Groups" / "Notifications for new messages and reactions in groups" · "Widget Updating" / "Shown briefly while the home screen widget refreshes" (APK) | "Daily Reminders" / "Reminders to share a Locket with your friends" (nag). |

### BeReal (daily invitation, daily capture, dual image)

| id | governs | rules | verbatim examples (source) | do-not-copy |
|---|---|---|---|---|
| `bereal.voice.push` | `daily.notification`, the daily line of `notifications.push`, the Live Activity / ongoing start alert (bereal §1, id new) | Second person, casual, short; Sentence case; a trailing period is kept even in the title; numerals for time; emoji only as markers at the edges of a line, never mid-sentence. **Tenet-5 adaptation is mandatory** (see "Adaptation rules"). | "⚠️ Time to BeReal. ⚠️" / "2 min left to capture a BeReal and see what your friends are up to!" (HN, AP #10) · "One daily notification. Two minutes. Real friends, real moments." (App Store 2026) · "Post on time or post late—it still counts." (App Store 2026) · "Get notified when it's time to BeReal in this conversation" (help image 36182541825309) | ⚠️ framing; `TIME SENSITIVE` interruption level; "2 min left …"; "Go, go, go!"; "your friends will know you posted late"; "{name} and {count} others posted"; the brand used as a verb (trademark, never copied even adapted). |
| `bereal.voice.capture-labels` | `daily.capture`, `daily.dualimage` (bereal §2, id new) | Action and mode labels in capitals ("SEND", "VIDEO", "PHOTO"); chips in Sentence case, 1-3 words ("My friends only", "Off"). | "SEND" (H2, TT #640, S2) · "VIDEO" / "PHOTO" (AP 2026) · "My friends only" (TT 2024) · "Off" (TT, H2, S2) | "{n} retakes"; "{n} min late". |
| `bereal.voice.capture-prompt` | the one centred line under the capture spinner (`daily.capture`, id new) | One short playful line, Sentence case, usually no final period, exclamation optional. The **layout** carries over; BeReal's smile-directive **content** does not. | "Smile now, uh I mean now" (TT #526-#601) · "Who goes there?" · "Umm, anybody here?" (FJ 2023) · "Keep smiling and don't change a thing" (TT #600-#681) | Every smile directive ("Say cheese!", "Wait, wait, wait, now smile", "Bonus point for the smile!") and "Your friends will definitely prefer to see your face!" — tenet "Real, not performed". |
| `bereal.format.countdown` | countdown text (`daily.capture`, `daily.liveactivity`, `daily.ongoing`; id new) | `MM:SS`, both fields zero-padded; no label text. | "01:31", "01:30", "01:29" (AP) · "00:59" … "00:54" (TT) | Any colour change or "late" state near 00:00 (not observed; not built). |

### Retro (week history)

retro-timehop §week.history lists four rules without ids; the ids below are new.

| id | governs | rules | verbatim examples (source) | do-not-copy |
|---|---|---|---|---|
| `retro.voice.title-case` | navigation, buttons, capsules (`week.history`) | Title Case. | "Share Profile" · "Manage Key Holders" · "Create Recap" · "Add to Album" · "Last Week" (retro-timehop §week.history) | "Key holders only" gate (history is never gated). |
| `retro.voice.menu-labels` | short contextual labels and menu verbs | Sentence case, no period. | "On this week" · "Hide photo" · "Share to my week" · "Delete from Photos" (Rewind menu, tc-2025-12) | — |
| `retro.voice.explanation` | one-line explanations | Sentence case with a final period. | "Only friends you've given a key to can see back more than 4 weeks." (tc-2023-07) · "Retro is a weekly photo album. Try adding photos to 3 different weeks below." (Engadget 2026) · "Retro is a weekly photo journal that (1) brings you closer…" (App Store v124.0) | The 4-week gate; "Weeks Posted: N". |
| `retro.voice.terse-numbers` | week titles, ranges, tile labels | Digits for numbers; terse labels; first-person possessive in actions ("my week"); no emoji, no exclamation marks; week = ISO-8601 Monday-start; range formatted by the locale (month once within a month). | "Week 27" (store-01/02) · "Apr 29 – May 5" (jedda 2024) · "10–16 Aug" (Engadget 2026, en-AU) · "Mon", "Tue", "Wed" (tile weekday) | "N new" pills; "Seen". |

### Timehop (on this day)

retro-timehop §onthisday lists six rules without ids; the ids below are new.

| id | governs | rules | verbatim examples (source) | do-not-copy |
|---|---|---|---|---|
| `timehop.voice.uppercase-labels` | in-image labels and buttons (`onthisday`) | Uppercase for short in-image labels and buttons. | "3 YEARS AGO" (store-01) · "AND NOW" (store-03) · "OPEN IN INSTAGRAM" / "HIDE FROM TIMEHOP" (help 2023) · "SQUARE" / "FULL" (help 2025) | Third-party names; the "timehop" watermark. |
| `timehop.voice.title-case-names` | screen, state and feature names | Title Case. | "Collecting Memories" (help 812) · "Daily Reminder" (help 2024) · "Time Travel Failed" (help 767) · "Then & Now" · "Change Color" (help 752, 1086) | — |
| `timehop.voice.years-ago` | the year label | Digits followed by the unit, uppercase in the banner; singular "1 YEAR AGO". | "43 YEARS AGO" (help 2025) · "8 YEARS AGO" (store-02) · "1 YEAR AGO" (help 2024 panel) | — |
| `timehop.voice.no-emoji` | all in-app labels | No emoji in in-app labels. | "Collecting Memories" · "3 YEARS AGO" · "Your private content remains private." (help 2024 settings) | — |
| `timehop.voice.playful` | marketing and help only — **not for product UI** | Playful second person with exclamation marks. | "Celebrate your best memories, every day!" · "We got you." · "Happy Timehopping!" (retro-timehop §onthisday) | Nag lines in this voice: "A little nudge to finish your day … (you're so close!)", "if you haven't opened the app by the afternoon", "it only lasts for 24 hours!", "It's your new daily habit". |
| `timehop.voice.release-notes` | **do not follow** | Jokey non-information release notes. | "Kept you waiting, huh?" (5.0.4) · "Pay no attention to that new feature behind the curtain!" (5.0) | Do not follow. |

### Spotify Wrapped (year story) — ids from wrapped-tribute-partiful §1.5

General voice for all P-YS patterns: Sentence case; second person for the user and "we" for the app;
headlines 2-9 words; full sentences end with a period, labels have none; no emoji and no exclamation
marks in card copy (except the quiz "You got it!"); buttons are Sentence-case verb phrases
("Share this story", "Let's go").

| id | governs | rules | verbatim examples (source) | do-not-copy |
|---|---|---|---|---|
| `P-YS-1` two-beat headline | `year.story` | "You {verb}. We {verb}." | "You listened. We counted." (D minutes) — the only exact match found; related two-beat lines: "You've changed. And so has your listening." (2024, xenarxoxo) · "It's that time of year again. Wrapped's ready. Are you?" (2024 intro) | Any headline that carries a consumption count. |
| `P-YS-2` setup + aside | `year.story` | A sentence, then a 1-5 word wry or affectionate aside, often opened by "But", "And" or "Luckily". | "Life moves fast" / "Luckily, we took notes." (2024) · "Once upon a time, there was a book lover." / "(It was you.)" (D audiobooks) · "You listened to {n} albums this year." / "Long live the album." (E) | "You overachiever."; "Where do you find the time?". |
| `P-YS-3` section label | `year.story` | "Your {noun phrase}", no period. | "Your top genres" (D genres) · "Your listening age" (E t048) · "Your top song" (E) | Rank / percentile labels ("top 5% fan"). |
| `P-YS-4` teaser | `year.story` | Short line ending with "...". | "One more thing..." (E t258) · "Big reveal in 3... 2... 1..." (2024) · "Until we meet again..." (2024 outro) | — |
| `P-YS-5` welcome / farewell | `year.story` | Invitational second person. | "We're ready for you." / "Come on down." (E t004.800) · "Thanks for coming along for the ride" (2024 outro) · "It's time for your 2025 Wrapped" / "We can't wait to show it to you." (entry card) | Leaderboards, "streak" chips. |

### Tribute / VidDay (birthday) — ids from wrapped-tribute-partiful §2.4, §3.5, §4.4

General voice: warm, second person, addressed to a group ("Hi everyone!", "Hey —"); one sentence
names the person and the occasion, one lowers the bar; prompts are open questions about the person;
buttons are imperative verb phrases in Title Case; exclamation marks only in greetings and titles; no emoji.

| id | governs | rules | verbatim examples (source) | do-not-copy |
|---|---|---|---|---|
| `P-BR-1` invitation | `birthday.request`, the birthday line of `notifications.push` | "You're invited to {action} for {name}." + a bar-lowering line. | "Hi everyone! You're invited to submit a video message and join in on the fun of making a personalized video for Amelia. It's quick and easy." (VidDay V3) · "Hey — I'm organizing a birthday video for [Name]'s birthday on [date]. Would love a short clip from you." (Tribute blog 2026-04-12) · "Tell contributors: 30 seconds is enough." (Tribute blog, guidance) | "It's your contribution that will help to make this unforgettable." (obligation); countdowns; reminder chains. |
| `P-BR-2` prompt | `birthday.request` | Open question about the person, with the name. | "What do you appreciate most about Harper?" · "How has Harper impacted your life?" (VidDay V1) · "Turn your phone sideways, find a window to face, and tell us your favorite memory of Dad." (Tribute help, participant prompt) | — |
| `P-BR-3` due line | `birthday.request` | "Submit by {date}" — a date, never a countdown. | "Submit by Wednesday, December 31, 2025" (Tribute T1) · "Contribute before…" / "Friday, May 14" (VidDay V3) | "Submissions are due in: 3d 12h 34m"; "Tribute Ends In:". |
| `P-BC-1` step greeting | `birthday.contribute` | "Let's {verb} a {noun} for {name}!" | "Let's record a video for Tribute!" (Tribute T4) · "Let's add media!" (VidDay V5) — the only two verbatim examples found | Pre-ticked marketing opt-in; asking group members for an email. |
| `P-BC-2` completion | `birthday.contribute` | "{Noun} Upload Complete!"; thanks are stated once, elsewhere in the flow ("Thank you for taking the time to participate!", Tribute T4). | "Video Upload Complete!" (Tribute help, how-do-i-upload-a-video) — the only verbatim example found | — |
| `P-BC-3` buttons | `birthday.contribute` | Single verbs or two-word verb phrases, Title Case. | "Retake" · "Submit" · "Continue" (Tribute) · "Use Video" · "Submit Another" (VidDay) | — |
| `P-BT-1` title card | `birthday.tribute` | "Happy birthday, {name}!" (case normalised; VidDay renders the theme in capitals). | "HAPPY BIRTHDAY, AMELIA!" (VidDay V7) · "Happy Birthday to Doug!" (Tribute sample title, T6) · "Birthday Tribute for Tess" (Tribute sample title, T5) | Brand stings; "From Russell and 36 others" (count). |

### Partiful (invite page) — ids from wrapped-tribute-partiful §5.5 and the invite consolidation pass

General voice (`partiful.voice.labels`, id new): Title Case for labels and buttons ("Guest List",
"Restricted Access", "Can't Go"); Sentence case with a period for explanations; "&" allowed; emoji only
as RSVP glyphs and in the marketing banner.

| id | governs | rules | verbatim examples (source) | do-not-copy |
|---|---|---|---|---|
| `partiful.voice.labels` | `invite.web`, `invite.appclip` | As above. | "Hosted by" · "Guest List" · "Restricted Access" · "View all" · "Get the app" (P1-P3 computed text) | Guest counts ("9514 Going · 7475 Interested"); "Trending This Week"; "Events can be easy 🕺 / Make your own"; "Interested" / "Follow" / "Remind me". |
| `P-IW-1` gate explanation | `invite.web` | "Verify your phone number to view {things}" — one clause, no period. | "Verify your phone number to view event details and activity" · "Only RSVP'd guests can view event activity & see who's going" · "Sign in for full location" (P1, P3) | — |
| `P-IW-2` reassurance | `invite.web` | "Just for {purpose}. No spam." | "Just for event updates. No spam." (P4) — the only verbatim example found | — |
| `P-IW-3` returning-user link | `invite.web` | "Already {state}? Sign in" | "Already RSVP'd? Sign in" (P1) — the only verbatim example found | — |
| `P-IW-4` … `P-IW-8`, `P-IW-T`, `P-IW-A` | `invite.web` | Defined by the invite consolidation pass with their own evidence (`design/copy/invite.json`, `pattern` fields): `P-IW-4` field row "{Participle} by {name}" ("Hosted by New York Dog Parade"); `P-IW-5` section label in Title Case ("Guest List"); `P-IW-6` "{Noun} not found" ("Event not found", "Page Not Found"); `P-IW-7` link status statement ("The existing link will no longer work.", "This link won't work once disabled."); `P-IW-8` recovery hint ("Try again, or ask the host for another link"); `P-IW-T` document title "{Event title} \| Partiful"; `P-IW-A` image alt "{Event title} Event Cover Image". | see each string's evidence in `design/copy/invite.json` | see above |
| `P-IW-A2` | `invite.appclip` | Glyph label for an emoji used as an illustration: the emoji's face named in sentence case (Partiful labels its not-found glyph "Grimace face", U+1F62C, in its production web code — `references/auto/partiful/js/partiful-web-js-excerpt-2026-10-15.js`, local only). New labels use the Unicode CLDR short name of the emoji. | `invite.appclip.full.glyphLabel` (see `design/copy/invite.json`) | — |

### Apple HIG / Material 3 (system surfaces) — ids from platform "Pattern ids introduced"

| id | governs | rules | verbatim examples (source) | do-not-copy |
|---|---|---|---|---|
| `platform.purposeString` | `system.permissions` (Info.plist purpose strings) | One brief, complete sentence; active voice; Sentence case; ends with a period; names the specific feature; separate string per resource. | "The app records during the night to detect snoring sounds." (HIG Privacy) · "The app uses location data to determine the recommended route to your destination and provide turn-by-turn directions." (App Review 5.1.1(ii)) · Counter-examples Apple rejects: "Microphone access is needed for a better experience.", "To use location." | Restating the resource without its use. |
| `platform.alertTitle` | alert / dialog titles on system surfaces | A complete sentence → Sentence case with ending punctuation; a fragment → Title Case, no punctuation; one or two lines; M3: "brief, clear statement or question". | HIG Alerts §Content; M3 Dialogs §Headline (rules quoted in platform §settings) — no verbatim title examples in the research | "Are you sure?", "Warning!", apologies. |
| `platform.alertMessage` | alert / dialog messages | Only if it adds value; complete sentences, Sentence case, punctuation. | HIG Alerts §Content — no verbatim examples in the research | — |
| `platform.alertButton` | alert, dialog and system action buttons; paywall's required links | One- or two-word verb describing the result, title-style capitalization, no punctuation; "Cancel" for cancel; "OK" only for informational alerts. | "View All" · "Reply" · "Ignore" · "Erase" · "Delete" (HIG Alerts) · "Cancel" (HIG: "Always use the title Cancel") | — |
| `platform.menuItem` | overflow menus and action sheets on system surfaces (platform §safety, id new) | Verbs in title-style capitalization, no articles; an ellipsis when the action needs more information; destructive items at the top of action sheets, Cancel at the bottom. | "Report" · "Block" · "Report…" (platform §safety.report, HIG Menus) | — |
| `platform.widgetDescription` | widget gallery descriptions (`widget.*`) | Begins with an action verb; no "This widget shows…"; Sentence-style capitalization; one description for all sizes. | "See the current weather conditions and forecast for a location" · "Keep track of your upcoming events and meetings." (HIG Widgets) · "See live pics from all your friends right on your Home Screen" (Locket gallery, already compliant) | — |
| `platform.appClipCard` | App Clip card (`invite.appclip`; platform §invite.appclip, id new) | Title ≤ 30 characters, subtitle ≤ 56 characters, one of Apple's preset action verbs; no text in the card image. | "Book Club" / "Make memories" / "View" (Partiful card, wrapped-tribute-partiful §6.1) — the only verbatim card found | Asking to install repeatedly. |

## Which pattern governs which surface

Rule: the reference assigned in `docs/SURFACES.md` governs; Yope's in-app voice is the default for app
surfaces; HIG / Material 3 govern system components. Loading · empty · error · offline ·
permission-denied states on Yope surfaces use `yope.voice.empty-state` / `yope.voice.error`.

| surface | patterns |
|---|---|
| `global` | `yope.voice.lowercase`, `yope.voice.second-person`, `yope.voice.button`, `yope.voice.title`, `yope.voice.placeholder`, `yope.voice.coach`, `yope.voice.confirmation`, `yope.voice.empty-state`, `yope.voice.error`, `yope.voice.emoji`, `yope.voice.punctuation`, `yope.voice.formats` |
| `global.system` | `platform.alertTitle`, `platform.alertMessage`, `platform.alertButton`, `platform.menuItem`, `platform.purposeString` |
| `invite.web`, `invite.appclip` | `partiful.voice.labels`, `P-IW-1` … `P-IW-8`, `P-IW-T`, `P-IW-A`, `P-IW-A2` |
| `invite.appclip` | `partiful.voice.labels`, `P-IW-1` … `P-IW-3`, `platform.appClipCard` |
| `auth.phone`, `auth.code`, `auth.agegate`, `auth.profile` | Yope (`global` set); `yope.voice.placeholder`; `yope.voice.error` for wrong-code / offline |
| `onboarding.permission.camera`, `.notifications`, `.photos`, `.contacts` | `yope.voice.permission`, `yope.voice.button`, `yope.voice.lowercase`, `yope.voice.second-person`; the system prompt that follows: `platform.purposeString` (iOS pre-alert rule: one button, "Continue"/"Next", no "Not now" — platform §system.permissions) |
| `onboarding.widget` | `locket.onboarding.widgetSteps`, `locket.voice.sentence-case`, `locket.voice.second-person` (Locket-referenced; see MERGE_DECISIONS Foundations F-18 on case) |
| `groups.list`, `groups.create`, `groups.invite`, `groups.screen` | Yope (`global` set) |
| `groups.settings` | Yope (`global` set) for labels and explanations; `platform.alertButton`, `platform.alertTitle`, `platform.menuItem` for native alerts / menus |
| `camera.capture`, `camera.sendto` | Yope (`global` set), esp. `yope.voice.coach`, `yope.voice.title`, `yope.voice.placeholder`, `yope.voice.formats` (hour overlay) |
| `camera.fromwidget` | `locket.voice.second-person` (no strings observed; a deep link) |
| `widget.home.small`, `.medium`, `.large`, `.xl`, `widget.lock.rect`, `.circular`, `.inline`, `widget.arrival`, `widget.android` | `locket.widget.gallery`, `locket.widget.empty`, `platform.widgetDescription`, `locket.voice.ellipsis` ("Updating widget..."), `locket.push.channel` (Android refresh channel) |
| `chat.thread`, `chat.composer`, `chat.voice` | Yope (`global` set) |
| `chat.reactions` | `locket.push.reaction` (activity lines), `locket.widget.empty` ("No reactions yet"), `locket.voice.ellipsis` ("Send message..."); never a count |
| `photo.viewer` | Yope (`global` set); `locket.voice.ellipsis` for the reply field |
| `walls.mine`, `walls.member`, `walls.browse` | Yope (`global` set) |
| `daily.notification` | `bereal.voice.push` with the tenet-5 adaptations below |
| `daily.capture` | `bereal.voice.capture-labels`, `bereal.voice.capture-prompt` (layout only), `bereal.format.countdown` |
| `daily.liveactivity` | `bereal.format.countdown`, `bereal.voice.push` (the one start alert, adapted) |
| `daily.ongoing` | `bereal.format.countdown`, `bereal.voice.push` (adapted), `locket.push.channel` |
| `daily.dualimage` | `bereal.voice.capture-labels` |
| `collage.view` | Yope (`global` set) |
| `collage.share` | `yope.voice.button` ("share"), `yope.voice.title` ("share with friends"); system share sheet text is PLATFORM |
| `week.recap`, `week.edit` | Yope (`global` set), esp. `yope.voice.formats` (week labels) |
| `week.history` | `retro.voice.title-case`, `retro.voice.menu-labels`, `retro.voice.explanation`, `retro.voice.terse-numbers` |
| `albums.list`, `albums.view` | Yope (`global` set) |
| `onthisday` | `timehop.voice.uppercase-labels`, `timehop.voice.title-case-names`, `timehop.voice.years-ago`, `timehop.voice.no-emoji` |
| `birthday.add` | Yope (`global` set, onboarding voice) |
| `birthday.request` | `P-BR-1`, `P-BR-2`, `P-BR-3` |
| `birthday.contribute` | `P-BC-1`, `P-BC-2`, `P-BC-3` |
| `birthday.tribute` | `P-BT-1` |
| `year.story` | `P-YS-1` … `P-YS-5` |
| `tagging` | Yope (`global` set) |
| `settings.root`, `settings.notifications`, `settings.account`, `settings.blocked` | `platform.alertTitle`, `platform.alertMessage`, `platform.alertButton`, `platform.menuItem`; `locket.push.channel` for Android channel names |
| `paywall` | `locket.voice.second-person`, `locket.voice.exclamation`, `locket.voice.sentence-case`; `platform.alertButton` for the required "Restore Purchases" / "Terms of Use" / "Privacy Policy" |
| `safety.report`, `safety.block` | `platform.menuItem`, `platform.alertButton` for menu items and buttons; Yope voice (`yope.voice.second-person`, `yope.voice.error`) for titles and explanations (SURFACES "Yope voice for copy"; platform §safety) |
| `system.permissions` | `platform.purposeString` |
| `notifications.push` | daily invitation: `bereal.voice.push` (adapted); new post: `locket.push.newPost`; reaction: `locket.push.reaction`; reply to you and recap ready: `yope.voice.confirmation` (Yope push texts were not found — yope-a §6); birthday request: `P-BR-1`; tribute for you: `P-BT-1` (the "video is ready" text was not found — wrapped-tribute-partiful §4.5); Android channels: `locket.push.channel` |

## Adaptation rules

**Allowed changes to a reference string** (`origin: adapted`, CONVENTIONS §4): only nouns are swapped,
and the swap is written in the string's `notes`.

| reference noun | becomes | seen in |
|---|---|---|
| Locket's "friends" / "your friends" (people who feed your widget) | the group, or the group's member noun | `locket.widget.gallery`, `locket.push.newPost` |
| "a Locket" / "Lockets" (the photo) | "a pic" / "a photo" | Locket APK strings |
| BeReal's brand verb ("Time to BeReal", "post a BeReal") | neutral wording with no brand verb (e.g. a plain verb of taking / sharing a photo) | `bereal.voice.push` |
| "event", "guest", "host", "RSVP" (Partiful) | "group", "member", "member" / inviter, "join" | `invite.*` strings (wrapped-tribute-partiful copy notes) |
| "video message", "video" (Tribute / VidDay) | "photo" (+ one line) | `birthday.*` strings |
| any app name or feature trademark (Locket, BeReal, Retro, Timehop, Partiful, Wrapped, Gold, Rollcall, YOPE) | `{app_name}` or a generic noun | all |

**`{app_name}`**: the app's display name, from `config/app.json` `displayName` (owner decision; BLOCKED
until set — `tools/designgen.mjs` keeps every string containing it in debug-only output). It replaces
every reference app name; another company's name, logo, trademark or mascot never appears in a string.
It keeps its own case inside lowercase Yope strings (`yope.voice.lowercase`: proper names keep their case).

**Tenet filters** (CONVENTIONS §6) applied before any pattern:

- **No counts**: no likes, reactions, views, "{n} others", "{n} friends", "{n} other friends sent",
  "0 of 5 friends added", guest counts, "Weeks Posted: N", "Add {n} pics more" progress, retake counts.
- **No streaks**: no 🔥N, "+1 streak", "streak restoration", streak widgets or chips.
- **No guilt**: no "It's been {n} days since…", "your friends will know you posted late",
  "Your friends will definitely prefer to see your face!".
- **No nagging**: one message per event; no repeat reminders, no afternoon "you haven't opened" pushes,
  no "you're so close!", no reminder chains for birthday requests, at most one paywall prompt per session.
- **No fake urgency**: no ⚠️, no `TIME SENSITIVE` interruption level, no "{n} min left", no "Go, go, go!",
  no countdown to a deadline (dates instead), no "late" labels, nothing on window close.

**BeReal → daily invitation (tenet 5)**: keep second person, casual, short, Sentence case, a trailing
period, "see what your group is up to" (noun swap); drop the ⚠️ markers, the time-sensitive level, the
"2 min left" deadline, any "late" wording and the brand verb. One alert at the start of the window only
(platform §daily.liveactivity: "Use one alert, at start").

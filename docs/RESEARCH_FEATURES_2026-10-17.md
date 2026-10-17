# Features from the reference apps (research of 2026-10-17)

What the best apps in this space have, that Jolt lacked, and that serve at least one tenet without touching the
do-not-build list. Decision 34 (`docs/OWNER_DECISIONS.md`) adopts the "built" list; decision 35 the "not built" one.
Each feature's design values and words are still sourced per the evidence rule when it is built (its surface spec in
`design/surfaces/`, its copy in `design/copy/`).

| # | feature | evidence (accessed 2026-10-17) | tenets |
|---|---|---|---|
| 1 | Several photos in one post (grouped in chat, the viewer and walls) | Retro composer "Add to Your Week" picks several photos (https://www.instagram.com/reel/DDbA_F7x-j7/; repo screen 30); Retro App Store v124 "backfill the weeks… with the photos and videos you want to remember" (https://apps.apple.com/us/app/id6443709020); Apple Shared Albums "Select all the items you want to add" (https://support.apple.com/en-us/108314); Instagram carousels up to 20 (https://www.techradar.com/computing/instagram/instagram-will-now-let-you-post-up-to-20-photos-or-videos-in-a-gallery-your-friends-should-be-thrilled) | 4, 1 |
| 2 | Downloads: an album in full quality (premium); all my photos (free) | Yope group menu "download all photos" (https://www.tiktok.com/@yrrah.yope/video/7434441926000037121; design/research/yope-a.md §2.13); Retro "Download your package" (https://retro.app/downloads); Apple Shared Albums full-resolution sharing (support 108314) | 4 |
| 3 | More widgets; the premium widget styles | Retro: "See the newest posts from friends or time hop back to your own memories with our new widgets" (App Store, above); Locket: "'Crush' or 'Best Friend' picture widget… photos only from that person" (https://apps.apple.com/us/app/id1600525061); Locket Gold widget frames (https://mobbin.com/explore/flows/775b5243-e2f1-42fa-a2af-cbee353c1dcd) | 1, 4 |
| 4 | "Share to Jolt" from Photos and other apps | Apple Shared Albums Share → Add to Shared Album (support 108314); Android receiving shared content (https://developer.android.com/training/sharing/receive) | 1, 4 |
| 5 | Library photos land on the day they were taken (date only, never location) | Retro "backfill the weeks" (App Store); Engadget on Retro reading when photos were taken (https://www.engadget.com/2234246/retro-app-what-is-it-how-to-use/) | 4 |
| 6 | Search (captions, chat, member, date, "I'm in this") — no face or AI search | Retro albums search (https://apps.apple.com/us/story/id1854931006); Yope search on the group list (https://www.tiktok.com/@savannahclooney/video/7683341732695592206); Apple Shared Albums filters (support 108314) | 4 |
| 7 | Reactions on chat messages, never counted | Locket 2.68.0 "chat reactions" (App Store, above); iOS 18 Tapbacks with any emoji (https://www.macrumors.com/guide/ios-18-messages/) | 1, 2 |
| 8 | Edit a sent message or caption ("Edited") | iMessage edit (https://support.apple.com/guide/iphone/iphe67195653/ios); WhatsApp edit (https://gulfnews.com/technology/media/whatsapp-new-feature-you-can-finally-edit-your-messages---how-to-use-and-more-1.1684777420759) | 1, 2 |
| 9 | Reply or react from the notification; mute the group from it | Messages reply from the Lock Screen (https://support.apple.com/104982); Android direct reply (https://developer.android.com/develop/ui/views/notifications/build-notification) | 1 |
| 10 | Albums anyone can add to; a new album from any photos | Retro private albums to collect photos (App Store); Apple Shared Albums (support 108314); Google Photos albums (https://support.google.com/photos/answer/6128849) | 3, 4 |
| 11 | Quick ways to open the camera: Control Center control, Shortcuts, Android Quick Settings tile and app shortcuts | Snapchat Lock Screen control (https://9to5mac.com/2024/10/24/snapchat-camera-will-be-available-from-the-iphone-lock-screen-but-no-filters/); https://developer.apple.com/documentation/appintents/app-shortcuts; https://developer.android.com/develop/ui/views/quicksettings-tiles; https://developer.android.com/develop/ui/views/launch/shortcuts | 1 |
| 12 | Hide a memory (for me) | Retro Rewind hiding (https://techcrunch.com/2025/12/12/retro-a-photo-sharing-app-for-friends-lets-you-time-travel-through-your-camera-roll/); Timehop "Hide your bad memories" (https://apps.apple.com/us/app/id569077959); Google Photos hide (https://support.google.com/photos/answer/9454489) | 4 |
| 13 | Reply to a memory in the group ("then & now") | Timehop "Then & Now" and sharing memories with friends (App Store, above); Retro Rewind share (TechCrunch, above) | 3, 4, 1 |
| 14 | Use a photo as the group cover | Google Photos "Use as → Album cover" (support 6128849); Retro album covers (Engadget) | 3 |
| 15 | Opt-in memory notification (only when there is a memory; at most once a day) | Google Photos memories notifications (support 9454489); Timehop alerts (App Store) | 4 |
| 16 | Tappable links in chat (previews built on the sender's device) | https://developer.apple.com/documentation/linkpresentation; iMessage, WhatsApp | 1 |
| 17 | Pause all notifications for today | Retro "Pause All — Turn off all notifications for the day" (design/research/retro-package-copy-motion.md §4.2) | 5 |
| 18 | "{name} joined" line in the chat | Yope "<name> joined" (https://www.aol.com/trying-buzzy-social-media-platform-110601376.html) | 1, 3 |
| 19 | Private favorites (only you see them) | Apple Photos Favorites (https://iphonelife.com/blog/5/tip-day-quick-way-create-album-your-favorite-photos) | 4 |
| 20 | Typing line with names (no "N typing", no read state) | WhatsApp typing indicators (https://www.digit.in/news/apps/whatsapp-launches-typing-indicators-feature-to-enhance-real-time-engagement.html) | 1 |
| 21 | Jump to a date in the history | BeReal Memories calendar (https://help.bereal.com/hc/en-us/articles/7531349180829) | 4 |
| 22 | Save other members' photos (decision 28) | Apple Shared Albums: save shared items to your library (support 108314) | 4 |

## Build status (2026-10-17)

Server = migrations and worker, tested against a local stack; apps = iOS and Android, merged and compiled in CI.
"Building" = in progress on a builder branch.

| # | feature | server | apps |
|---|---|---|---|
| 1 | Several photos in one post | 0051 (batch_id, one push per batch) | composer: building; grouped display: building (`layout.global.photoBatch`) |
| 2 | Downloads | 0052 download_items | building |
| 3 | More widgets, premium styles | 0036 | iOS 2082b58; Android merged |
| 4 | Share to Jolt | — (create_post) | building |
| 5 | Library photos on the day taken | 0050 (taken_on, visible_at trigger) | building (with #1) |
| 6 | Search | 0040 | merged |
| 7 | Reactions on chat messages | 0047 | merged |
| 8 | Edit a message or caption | 0047 | messages merged; captions building |
| 9 | Reply / react / mute from the notification | — (existing RPCs) | building |
| 10 | Albums anyone can add to | 0039 | merged |
| 11 | Quick camera access | — | iOS 2082b58; Android merged |
| 12 | Hide a memory | 0038 | merged |
| 13 | Reply to a memory ("then & now") | — (create_post reply) | building |
| 14 | A photo as the group cover | 0039 | merged |
| 15 | Opt-in memory notification | 0049 + worker push.memory | building |
| 16 | Tappable links in chat | — | merged (previews on the sender's device: later) |
| 17 | Pause all for today | 0037 | done |
| 18 | "{name} joined" line | 0041–0042 | done |
| 19 | Private favorites | 0038 | merged |
| 20 | Typing line with names | 0048 (chat_typing, RLS across blocks) | merged |
| 21 | Jump to a date | 0045 | merged |
| 22 | Save other members' photos | — | merged (decision 28) |

## Not built, and why

- Read receipts, "seen by", online / last-seen dots: tenet 5 and counts.
- "N typing", "N unread", "7 members · 24 photos": counts (tenet 2).
- Streaks (Timehop, Locket, Yope): do-not-build list.
- "Post to see" and posting reminders (Retro): tenet 5.
- Printing and postcards (Retro): payments.
- Location tags (Retro): location tracking.
- Face-based features, AI search, object removal (Google Photos): face recognition; AI only for recaps; no edit-first posting.
- Sticker and GIF comments (Retro Premium): stickers.
- Celebrity / artist content (Locket): strangers.
- Music (Locket, Apple Invites): music integration.
- Public album links (Apple, Retro `/j/`): privacy, decision 12.
- One-to-one messages (Retro): tenet 3; a two-person group covers it.
- Referral rewards (Retro): rewards and counts.
- Paid storage for history: tenet 4 / T1.
- Voice-message transcripts (WhatsApp): the directive limits AI to recaps.
- Activity inbox (Retro): decision 14.
- On-demand month / year video recaps (Retro, Locket): later.

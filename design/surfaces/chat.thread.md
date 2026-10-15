# `chat.thread` — group chat thread

Reference app: **Yope** group chat (`docs/SURFACES.md`); reactions shown in the thread are **Locket**'s (`chat.reactions`).
Research: `design/research/yope-b.md` §1 (primary), `design/research/yope-a.md` §1, §2.12; `design/research/locket.md` §7.
Tokens: `design/tokens/social.json` (`chat.thread.*`) + `design/tokens/global.json` by name. Copy: `design/copy/social.json`
(`chat.thread.*`). Decisions: `design/MERGE_DECISIONS.md` → Social (S-1 … S-15).

## References

| id | file | used for |
|---|---|---|
| S1 | `references/auto/yope/store/yope-store-05.png` (lossless, listing 1.229.0); coordinates in `references/auto/yope/frames/b-derot-store-05-rot-1.68.png` | **primary**: header, bubbles, avatars, photo messages, emoji-only message, voice bubble, composer, gaps; colours re-sampled on the lossless pixels (S-2) |
| S3 | `references/auto/yope/frames/b-play-04.png` | same design re-rendered for Google Play (cross-check, not independent) |
| O1 | `references/owner/yope-04-chat.webp` | owner copy of S1 (cross-check) |
| S5-r | `references/auto/yope/frames/b-yopeapp-7591560669967682847-t49.50-reply-to-photo.png` | reply to a photo (lime quote), caption box on a photo |
| S5-t | `references/auto/yope/frames/b-yopeapp-7591560669967682847-t48.50-1on1-thread.png`, `references/owner/yope-1on1-feed.jpg`, `-feed-2.jpg` | 1:1 space (different screen): portrait photo cards, caption box — context only |
| V-mthu | `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t51.23-group-created-empty-state.png`, `…-t50.60-loading-hud.png` | empty state, loading HUD |
| S6 | `references/auto/yope/frames/b-alexaa-7652512140875566349-t5.83-group-chat-pill.png` | 2026 header circles (‹, film strip) |
| AS-4 | `references/auto/locket/store/locket-store-04.png` | reaction cluster on photos (see `chat.reactions.md`) |

## Structure (top → bottom)

Screen background `color.global.background` (#171717). The message list scrolls under a floating header; newest message
at the bottom, just above the composer.

1. **Header** (floats over the list, top safe area): ‹ circle at the left (`size.global.headerInset` from the edge) → gap
   `size.global.headerGap` → **group capsule** (hugs its content) → film-strip circle at the right (`size.global.headerInset`).
   No calendar circle (that belongs to `groups.screen`), no streak pill.
2. **Message list** (vertical scroll), each run of consecutive messages from one sender stacked with the gaps below:
   - another member's messages: left; their avatar sits in the avatar column only beside the **last** message of a run,
     bottom-aligned with it;
   - my messages: right, no avatar;
   - message kinds: text bubble, emoji-only message, photo message, reply to a photo (text or photo), voice message
     (`chat.voice.md`).
   No day separators, no timestamps on text bubbles (S1 shows none; MERGE_DECISIONS S-6).
3. **Composer** pinned at the bottom (`chat.composer.md`).

### Message geometry

| item | left edge | right edge | height | corners | fill |
|---|---|---|---|---|---|
| their text bubble | `chat.thread.dimension.bubbleInsetTheirs` (50.5) | hugs text: `chat.thread.dimension.bubblePaddingH` each side; max `chat.thread.dimension.bubbleMaxWidth` (256 = 0.652 × screen width, iMessage; Gap fill G-1) | `chat.thread.dimension.bubbleHeight` (35.6) per single line | `chat.thread.radius.bubble` (16) all four, no tail | `chat.thread.color.bubbleTheirs` + hairline rim (`chat.thread.dimension.bubbleRim`) shading from `chat.thread.color.bubbleRimTheirsTop` at the top to `…BubbleRimTheirsBottom` at the bottom |
| my text bubble | hugs text, max `chat.thread.dimension.bubbleMaxWidth` | `chat.thread.dimension.bubbleInsetMine` (23) | same | same | `chat.thread.color.bubbleMine` + rim `…bubbleRimMineTop` → `…bubbleRimMineBottom` |
| avatar | `chat.thread.dimension.avatarInset` (11.2) | `+ size.global.avatarSmall` (32.6, circle) | — | circle | photo / `icon.global.person` |
| avatar → bubble | `chat.thread.dimension.avatarGap` (6.7) | | | | |
| emoji-only message | as a bubble of that sender | | emoji rendered `chat.thread.dimension.emojiOnlyGlyph` (47.5) wide, no bubble | — | — |
| photo message | `chat.thread.dimension.bubbleInsetTheirs` (photo x 51.2 in S1, within 0.7) | `chat.thread.dimension.photoInsetTrailing` (18.7) → 323 wide on a 393-pt screen | width × 174 / 323 (`chat.thread.dimension.photoWidth` × `…photoHeight`) | `radius.global.photo` (15) | the photo, `chat.thread.layout.photoFit` (aspect fill, centred) |

Vertical gaps: same-sender bubble → bubble `chat.thread.dimension.gapSameSender` (3.6); text → voice of the same sender
`chat.thread.dimension.gapTextToVoice` (4.7); photo → photo `chat.thread.dimension.photoGap` (15.3); between runs of
different senders `chat.thread.dimension.gapBetweenSenders` (15). Gaps between a photo and a bubble were not measured:
`chat.thread.dimension.photoGap` is used (flagged, Gaps).

### On a photo message (top → bottom, over the photo)

1. **Time** centred on the photo: text role `overlayTime` (`fontSize.global.overlayTime` 21, `fontWeight.global.overlayTime`
   heavy), `color.global.textPrimary`, format `chat.thread.layout.timeFormat` (`h:mm a`, e.g. "10:00 PM").
2. **Caption box** (only when the post has a caption), horizontally centred, `chat.thread.dimension.captionInsetBottom`
   above the photo's bottom edge: height `chat.thread.dimension.captionHeight`, padding `chat.thread.dimension.captionPaddingH`,
   corners `chat.thread.radius.caption`, fill `color.global.scrim` (**BLOCKED**, translucent), text `chat.thread.fontSize.caption`
   / `chat.thread.fontWeight.caption` in `color.global.textPrimary`, one line, tail truncation (S-8).
3. **Reaction cluster** bottom-left (`chat.reactions.md`): `chat.reactions.dimension.clusterInsetLeading` /
   `.clusterInsetBottom`; never a number.

### Reply to a photo (S5-r)

One bubble, two stacked parts, sender-aligned like a text bubble, width = the quote's natural width (142 pt observed,
`chat.thread.dimension.replyWidth`).

1. **Quote part**: height `chat.thread.dimension.replyQuoteHeight` (64), fill `color.global.accent`, top corners
   `chat.thread.radius.replyQuote` (18.2). Inside: black quote bar (`color.global.onAccent`, width
   `chat.thread.dimension.replyQuoteBar`, at `chat.thread.dimension.replyQuoteBarInset` from the left, spanning the name and
   label lines); the poster's first name (`chat.thread.fontSize.replyName` / `.fontWeight.replyName`, `color.global.onAccent`)
   at `chat.thread.dimension.replyTextInset`, cap top `chat.thread.dimension.replyNameCapTop`; under it the word **"pic"**
   (`chat.thread.reply.photoLabel`; `chat.thread.fontSize.replyLabel` / `.fontWeight.replyLabel`, `color.global.onAccent`)
   with its baseline at `chat.thread.dimension.replyLabelBaseline`; at the right a square thumbnail of the photo
   (`chat.thread.dimension.replyThumb`, corners `chat.thread.radius.replyThumb`, `chat.thread.dimension.replyThumbInsetTop`
   from the top, `chat.thread.dimension.replyThumbInsetTrailing` from the right; `thumb_path`).
2. **Text part** below, overlapping the quote's bottom so the lime shows behind its top corners: a text bubble of the
   sender (height `chat.thread.dimension.bubbleHeight`, `chat.thread.radius.bubble`, the sender's bubble fill — S-5).

**Reply to a photo with a photo** (create_post with `p_reply_to_post_id`): the photo message with the quote part attached
above it — an approximation built from the two observed parts (S-7, Gaps).
When the quoted photo is deleted (`reply_to_post_id` becomes null), the quote part is removed and the message stays.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| back circle | `size.global.headerButton`, `color.global.control`, `icon.global.back` in `color.global.textPrimary`, `size.global.headerInset` | `chat.thread.a11y.back` | pops to `groups.screen` |
| group capsule | `chat.thread.dimension.headerCapsuleHeight`, `color.global.control`, `radius.global.capsule`, `size.global.avatarHeader`, text role `headerTitle`, `icon.global.chevron` in `color.global.textSecondary`; insides as the group header in `design/surfaces/groups.screen.md` | group name (data); `chat.thread.a11y.groupCapsule` | opens the group profile / `groups.settings` |
| film-strip circle | `size.global.headerButton`, `color.global.control`, `icon.global.recap` | `chat.thread.a11y.recap` | opens `week.recap` (latest ready recap); hidden while the group has none |
| text bubble | table above; text role `body` (`fontSize.global.body` 17 regular) in `color.global.textPrimary` | message text (data); `chat.thread.a11y.message` / `.messageMine` | long press → native context menu (see Data & actions) |
| emoji-only message | `chat.thread.dimension.emojiOnlyGlyph`; threshold `chat.thread.count.emojiOnlyMax` (3: a message of only 1–3 emoji renders large without a bubble; 4+ as a text bubble — Messages / WhatsApp rule, G-2) | emoji (data) | as a text bubble |
| sender avatar | `size.global.avatarSmall`, `chat.thread.dimension.avatarInset`, `.avatarGap` | decorative (the message label carries the name) | tap → `walls.member` |
| photo message | table above; `radius.global.photo`; `chat.thread.layout.photoFit` | `chat.thread.a11y.photo` / `.photoMine` + `chat.thread.a11y.caption` | tap → `photo.viewer` (this thread's photos, chronological); long press → `chat.reactions` picker |
| time on photo | text role `overlayTime`, `color.global.textPrimary`, `chat.thread.layout.timeFormat` | time (data) | — |
| caption box | `chat.thread.fontSize.caption`, `.fontWeight.caption`, `.dimension.captionHeight`, `.captionPaddingH`, `.captionInsetBottom`, `.radius.caption`, `color.global.scrim` (**BLOCKED**) | caption (data) | — |
| reaction cluster | `chat.reactions.*` | `chat.reactions.a11y.cluster` | tap → reactions list (`chat.reactions.md`) |
| reply quote | quote tokens above | `chat.thread.reply.photoLabel`, poster first name (data), `chat.thread.a11y.replyQuote` | tap → `photo.viewer` on the quoted photo |
| voice message | `chat.voice.*` | `chat.voice.*` | `chat.voice.md` |
| composer | `chat.composer.*` | `chat.composer.*` | `chat.composer.md` |

## States

| state | what shows | tokens / copy | source |
|---|---|---|---|
| loading (first page) | centred HUD: platform activity indicator over "Loading" | `groups.create.size.hud`, `groups.create.color.hud`, `groups.create.fontSize.hudLabel`, `chat.thread.radius.loadingHud` (10.5, Yope frames, G-3), `easing.global.native.activityIndicator`; `groups.create.hud.loading` | V-mthu t50.60 (yope-a §1.8); HUD shared with the groups surfaces (account group) |
| loading older messages | platform activity indicator at the top of the list | `easing.global.native.activityIndicator` | PLATFORM |
| empty (no messages yet) | centred: bold title, italic gray detail, white pill with leading link glyph; composer stays | text roles `emptyTitle` (`color.global.textPrimary`) and `emptyDetail` (italic, `color.global.textSecondary`); pill `color.global.surfaceLight` / `color.global.onSurfaceLight`, `groups.screen.size.lightPillHeight`, `groups.screen.radius.lightPill`, text role `button`, `icon.global.link`; `chat.thread.empty.titleCreator` or `.titleMember`, `chat.thread.empty.detail`, `chat.thread.empty.invite` | V-mthu t51.23 (`yope.voice.empty-state`); pill opens `groups.invite` |
| error (load failed) | same layout as empty | `chat.thread.error.title`, `.error.detail`, pill `chat.thread.error.retry` (reloads) | `yope.voice.error` (no Yope error observed) |
| offline, nothing cached | same layout as empty, no pill | `chat.thread.offline.title`, `.offline.detail` | `yope.voice.error` |
| offline with cached messages / send failed | cached messages stay; a failed message of mine gets a red outlined "!" circle (22 pt) on its trailing side, 14 pt from the bubble, and `chat.thread.sendFailed` in red under it (text role `caption`); tapping the circle, label or bubble sends it again | `chat.thread.layout.failedMessage` (`exclamationmark.circle` / `Rounded.ErrorOutline`, `color.global.destructive`); haptic `haptic.global.error` | Apple Messages "Not Delivered" state (support article 118433; Gap fill G-4) — not observed in Yope |
| photo deleted while open | `post_deleted` broadcast removes the photo message; replies lose their quote part | — | docs/API.md §8.2 |
| permission-denied | none on this surface (camera → `camera.capture`, microphone → `chat.voice.md`) | — | — |

## Motion

| transition | tokens | Reduce Motion |
|---|---|---|
| push in from `groups.screen` / back | native navigation (`easing.global.native.navigationPush`; Yope measured `duration.global.navigationPush`, MERGE_DECISIONS F-11) | system cross-fade (`layout.global.reduceMotion`) |
| scroll, keyboard, context menu | native (`easing.global.native.scrollIndicator`, `.keyboard`) | system |
| message insert / send | not observed (yope-b §10 "Not found: message send/arrival"): no custom animation | — |
| emoji rain after a reaction | `chat.reactions.md` | `chat.reactions.layout.reduceMotion` |

## Haptics

| interaction | token |
|---|---|
| message sent (text) | `haptic.global.send` |
| send failed | `haptic.global.error` |
| long press on a photo (reaction picker opens) | `haptic.global.reaction` |
| long press on a text / voice message (context menu) | `haptic.global.longPressStart` |
| delete confirmed | `haptic.global.warning` |

## Accessibility

- Labels: header circles `chat.thread.a11y.back`, `chat.thread.a11y.recap`; capsule `chat.thread.a11y.groupCapsule`;
  text and emoji messages `chat.thread.a11y.message` / `.messageMine`; photos `chat.thread.a11y.photo` / `.photoMine`
  (+ `chat.thread.a11y.caption`), grouped with their reaction cluster (`chat.reactions.a11y.cluster`, emoji names, never a
  count); reply quote `chat.thread.a11y.replyQuote`. Avatars are decorative. Traits: photos and the quote are buttons;
  long-press actions are exposed as accessibility custom actions (react, delete / report).
- Dynamic Type: body → `layout.global.textStyleMap.body`; overlay time → `.overlayTime`; header name → `.headerTitle`;
  empty title / detail → `.emptyTitle` / `.emptyDetail`; reply name / label, caption, emoji-only →
  `chat.thread.layout.textStyleMap` (subheadline, footnote, title2, largeTitle). Bubbles grow in height with the text
  (single-line height is the minimum).
- Focus order: back → group capsule → recap circle → messages oldest → newest → composer (field, then buttons).
- Hit targets: header circles 44 pt (`size.global.minTouchTarget.ios` / `.android` 48 dp on Android: pad the hit area).
- New incoming messages are announced (HIG: "Inform VoiceOver when visible content or layout changes occur").
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | ratio | result | pair |
|---|---|---|---|---|---|
| `color.global.textPrimary` #FFFFFF | `chat.thread.color.bubbleTheirs` #2B2B2B | text | 14.16:1 | pass | message text 17 regular in another member's bubble |
| `color.global.textPrimary` #FFFFFF | `chat.thread.color.bubbleMine` #232323 | text | 15.72:1 | pass | message text 17 regular in my bubble |
| `chat.thread.color.bubbleTheirs` #2B2B2B | `color.global.background` #171717 | nontext | 1.27:1 | **FAIL** | their bubble fill against the thread background |
| `chat.thread.color.bubbleMine` #232323 | `color.global.background` #171717 | nontext | 1.14:1 | **FAIL** | my bubble fill against the thread background |
| `chat.thread.color.bubbleRimTheirsTop` #414141 | `color.global.background` #171717 | nontext | 1.76:1 | **FAIL** | their bubble top rim against the background |
| `color.global.onAccent` #000000 | `color.global.accent` #CDFD07 | text | 17.65:1 | pass | quoted name / 'pic' on the lime quote |
| `color.global.onAccent` #000000 | `color.global.accent` #CDFD07 | nontext | 17.65:1 | pass | quote bar on lime |
| `color.global.accent` #CDFD07 | `color.global.background` #171717 | nontext | 15.07:1 | pass | lime quote block against the background |
| `color.global.textPrimary` #FFFFFF | `groups.create.color.hud` #262626 | text | 15.13:1 | pass | 'Loading' on the HUD |
| `groups.create.color.hud` #262626 | `color.global.background` #171717 | nontext | 1.18:1 | **FAIL** | HUD against the background |
| `color.global.textPrimary` #FFFFFF | `color.global.background` #171717 | text | 17.93:1 | pass | empty-state title |
| `color.global.textSecondary` #969696 | `color.global.background` #171717 | text | 6.06:1 | pass | empty-state detail |
| `color.global.onSurfaceLight` #000000 | `color.global.surfaceLight` #FFFFFF | text | 21.00:1 | pass | 'invite more friends' pill label |

  The bubble / HUD fills are not needed to identify their content (the text inside passes), so SC 1.4.11 does not require
  them; reported, no sourced alternative. Caption text on `color.global.scrim` cannot be checked until the scrim is captured.

## Data & actions

- **Reads**: `messages` (docs/API.md §5.9) — `eq(group_id).order(created_at desc).limit(50)`, page with `lt(created_at)`;
  photo messages carry `post_id` → `posts` (§5.8: caption, voice note, `reply_to_post_id`) and `media` (§5.7: `thumb_path`
  for reply thumbnails, `display_path` for photo messages; originals until `renditions_ready_at`); `reactions` (§5.10) per
  post for clusters; `profiles` (§5.1) for names / avatars; `groups` (§5.3) and `group_members` for the header and the
  empty-state names; `weekly_recaps` (§5.14) for the film-strip target. Files through signed URLs (§7, 1 h).
- **RPCs**: `send_message` (text; `p_reply_to_post_id` when replying from `photo.viewer`); `delete_message` (own text /
  voice, after the native confirmation `chat.thread.deleteMessage.title` / `.message`, buttons `photo.viewer.delete.confirm` /
  `photo.viewer.delete.cancel`); `report` (`report_target_kind` `message`) via `safety.report`; `react` / `unreact` via
  `chat.reactions`; `create_post` via `chat.composer` → `camera.capture`.
- **Context menu** (long press, native: iOS `contextMenu`, Android `DropdownMenu`; Yope uses native menus for its •••
  (yope-a §2.13)): own text / voice → `chat.thread.menu.delete` (`photo.viewer.icon.delete`, destructive); others' →
  `chat.thread.menu.report` (`icon.global.report`, destructive).
- **Realtime** (§8): channel `group-<id>` postgres INSERTs on `messages`, `posts`, `reactions` and UPDATEs (reply target
  removed); private broadcast `group:<id>`: `post_deleted` (remove the photo message, strip quotes), `message_deleted`,
  `reactions_changed` (refetch that post's reactions). Refetch the visible page on foreground / reconnect (§8.3).
- **Navigation in**: `groups.screen` ("chat" pill); deep link `DeepLink.chatMessage(groupID:messageID:)` (`app://chat?group=…&message=…`,
  push type `reply`) opens the thread scrolled to that message. Push texts for replies to you are
  `notifications.push.reply.*` (design/copy/capture.json).
- **Navigation out**: `photo.viewer`, `week.recap`, `groups.settings`, `walls.member`, `groups.invite`, `safety.report`,
  `camera.capture`.

## Platform notes

- iOS: `ScrollView` + `LazyVStack` anchored to the bottom; `contextMenu` provides the long-press haptic. Hairline rim =
  `1 / displayScale` pt.
- Android: `LazyColumn(reverseLayout = true)`; `combinedClickable` long press + `DropdownMenu`; `HapticFeedbackConstants.LONG_PRESS`.
  Hairline = `Dp.Hairline`. Emoji fonts differ (Apple Color Emoji / Noto Color Emoji): size emoji-only messages by the
  rendered glyph width (`chat.thread.dimension.emojiOnlyGlyph`).
- Dark only (`layout.global.appearance`).

## Do-not-copy

- Streak pill in the header capsule ("🔥451", "🔥0", lime "🔥5") — tenet 2.
- Cut-out person stickers floating over the thread and the sticker composer button — do-not-build.
- Unread count badges (chat pill, tabs) — counts.
- Yope's reaction capsule under photos with reactor avatars (#2C2C2C, 24 pt): replaced by Locket's cluster
  (`chat.reactions` is Locket's surface, S-4).
- Any "late" label, sent / read receipts with counts.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| `chat.thread.dimension.bubbleMaxWidth` | **SOURCED (gap fill)**: 256 pt = 0.652 × screen width, from Apple Messages (iOS 27 guide image + Messages render in Google Photos' App Store panel; lower bound +0/+11 %) — MERGE_DECISIONS Gap fill G-1. Multi-line line height: still platform default leading | a Yope two-line text (yope-b §14 capture 1) would supersede |
| `chat.thread.count.emojiOnlyMax` | **SOURCED (gap fill)**: 3 (Messages + WhatsApp rule; Yope S1's 3-emoji message is consistent) — G-2 | one Yope screenshot with a 4-emoji message would confirm |
| `chat.thread.layout.failedMessage` | **SOURCED (gap fill)**: Apple Messages' "Not Delivered" layout (red "!" circle + red label, tap retries) — G-4 | one Yope screenshot of a failed message would supersede |
| `chat.thread.radius.loadingHud` | **SOURCED (gap fill)**: 10.5 pt, Yope's own HUD on 3 video frames (±1.5 pt) — G-3 | a lossless Yope HUD screenshot would tighten it |
| `color.global.scrim` (caption box fill) | BLOCKED (foundations) | one lossless screenshot of a captioned photo card |
| portrait photos in the group chat | approximation: the 323 × 174 landscape frame, aspect fill | same recording as above (send a portrait photo) |
| gap between a photo and a bubble | approximation: `chat.thread.dimension.photoGap` | same recording |
| photo reply to a photo | approximation: quote part + photo message (S-7) | same recording (reply to a photo with the camera) |
| reply to a text message (`reply_to_message_id`) | not offered (no Yope evidence) | same recording |
| caption box horizontal position | Locket's centring used (S-8) | — |
| header capsule internals | from `groups.screen.md` (S1's capsule is covered by a sticker) | — |

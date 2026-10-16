# `chat.thread` — group chat thread

Redesign on **Retro** (docs/REDESIGN_BRIEF.md). Visual reference: Retro **Messages** (screen 31, pushed serif header) and
Retro's **comment rows** under a photo (screen 15) — Retro's message thread itself was not captured, so the thread is
**composed of Retro components** (C-02, C-16, C-18, C-15, C-20, C-13, C-27) in the order of the mechanics references
**Apple Messages / WhatsApp** (runs, replies, failed sends), with Retro's own thread strings from its Android package.
Tokens: `design/tokens/social.json` (`chat.thread.*`) + `global.*`; components `design/components.md`. Copy:
`design/copy/social.json` (`chat.thread.*`). Decisions: `design/MERGE_DECISIONS.md` → Redesign — Social (RS-1 … RS-6).
Composition record: `level: SOURCED`, `method: "composition of Retro components C-02, C-16, C-18, C-15, C-20, C-13, C-27
in Apple Messages / WhatsApp's order"`.

## References

| id | file | used for |
|---|---|---|
| ENG-M | `references/auto/retro/press/engadget-2026-08-the-problem-with-friends-only-socials-1786385236.jpg` (live app, light, 780 × 438, low-res) | pushed header "‹ Messages" in the display serif; search field; inbox row (avatar, name, grey "Thank you · 5d"). Measured only as layout (phone photographed at an angle, ≈0.45 px/pt) |
| TC-2B | `references/auto/retro/press/tc-2023-07-retro-2b.jpg` phone 2 (2.209 px/pt) | comment row (avatar 31, "elton 2h", text), row metrics `chat.thread.dimension.rowAvatarToText` / `.rowLinePitch`; message field (C-13) |
| ST-01 | `references/auto/retro/store/retro-store-01.png` | photo card (C-18) used for photo messages |
| TC-J1 | `references/auto/retro/press/tc-2024-04-journals-1.webp` | dated section header ("January 25, 2024") used as the day divider |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | Retro's thread strings: "Send a message…", "Reply…", "Replying to %1$s", "Today", "Yesterday", "Post by %1$s", "Week %1$d", "Unsend", "Retry", "Sending", "Error loading your messages" |
| APK-X | `references/auto/retro/apk/retro-android-2026.10.1150-excerpts.txt` | message "entry animation" (250 ms, linear), composer fade 150 ms |
| IM | `references/auto/imessage/apple-support/messages-tapbacks-ios27.png`, `…/messages-not-delivered.png` | mechanics: runs with one avatar per incoming run; failed message label under the message |
| WA | `references/auto/whatsapp/store/whatsapp-store-04.png` | mechanics: sender shown once per run; reaction summary under a message |

## Structure (top → bottom)

Page `color.global.background` (iOS) / `color.global.background.android` (Android) — the thread follows the system
appearance (it is not a media surface).

1. **Header — C-02 pushed**: back chevron `icon.global.back` (ink at `size.global.backInset`), then the group's name as the
   serif title (text role `headerTitle`, `font.global.display`, `color.global.textPrimary`) `size.global.headerGap` after the
   chevron; one line, tail truncation. No trailing glyphs (the group's settings, recap and walls are reached from
   `groups.screen`, which this screen is pushed from). Content starts `size.global.titleToContent` below the title baseline.
2. **Message list** (vertical scroll, oldest at the top, newest at the bottom above the composer), inside
   `size.global.screenMargin`:
   - **Day divider** before the first message of each day — C-20 dated variant without "•••": `chat.thread.divider.today`,
     `chat.thread.divider.yesterday`, else the date "MMMM d, yyyy" (text role `sectionLabel`, `color.global.textPrimary`);
     `size.global.sectionGap` above it, `size.global.sectionHeaderToContent` below its baseline (`chat.thread.layout.timeFormat`).
   - **Runs** (`chat.thread.layout.runs`): consecutive messages from one sender. The run's first row is the C-16 comment row:
     avatar `size.global.avatarComment` at the margin, its top on the name line's ascender; then, `chat.thread.dimension.rowAvatarToText`
     after the avatar, the sender's display name (text role `listTitle`, `color.global.textPrimary`) and, one space after it,
     the time (`chat.thread.layout.timeFormat`, text role `caption`, `color.global.textSecondary`). Every item of the run sits
     in the text column (left edge = name ink):
     - **text** — text role `body`, `color.global.textPrimary` (Android `fontSize.global.body.android` /
       `lineHeight.global.body.android`), first baseline `chat.thread.dimension.rowLinePitch` below the name baseline, lines
       at the same pitch; links and long words wrap. A message of only 1–3 emoji (`chat.thread.count.emojiOnlyMax`) renders
       its emoji at `fontSize.global.headerTitle`.
     - **photo** — C-18 photo card (`chat.thread.layout.photoFit`: `size.global.friendCardWidth` × `.friendCardHeight`,
       `radius.global.card`, aspect fill). The post's caption follows as a text item; a voice note follows as the voice
       capsule with its waveform (`chat.voice.md`, C-36); the reaction chip follows the photo (`chat.reactions.layout.chip`,
       `chat.reactions.dimension.chipTop` below it).
     - **voice** — the voice capsule (`chat.voice.layout.capsule`): play glyph · C-36 waveform
       (`chat.voice.dimension.waveform`, the message's `voice_levels`; none stored → a row of dots until first played) ·
       duration (owner decision 16).
     - **reply quote** (`chat.thread.layout.replyQuote`) above the reply it belongs to: a C-15 row for a quoted photo
       (thumbnail `size.global.rowThumbWidth` × `.rowThumbHeight`, `radius.global.thumbnail`, `chat.thread.reply.postTitle`
       over `chat.thread.reply.postWeek`), or one grey line for a quoted message ("**name** text…").
     - **status line** under your own last message while it is in flight (`chat.thread.sending`) or after it failed
       (`chat.thread.sendFailed`, `chat.thread.layout.failedMessage`).
     Items inside a run are `chat.thread.dimension.itemGap` apart; runs are `size.global.listGap` apart. Later messages of
     a run carry no avatar or name. Your own messages use the same row (Retro shows everyone's comments the same way).
3. **Composer** pinned at the bottom (`chat.composer.md`; C-13 field). When replying, the reply bar sits above the field.
4. The message list's bottom content inset = the composer's height + `chat.composer.dimension.bottomInset`; the list keeps
   the newest message in view when the keyboard rises.

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| back | C-02; `icon.global.back`, `size.global.backInset`, `size.global.headerButton` (hit area) | `chat.thread.a11y.back` | pops to `groups.screen` |
| title | C-02; text role `headerTitle`, `font.global.display`, `size.global.headerGap`, `size.global.titleTop` | group name (data) | header trait |
| day divider | C-20 dated variant; text role `sectionLabel`; `size.global.sectionGap`, `size.global.sectionHeaderToContent` | `chat.thread.divider.today`, `.divider.yesterday`, date (data) | header trait |
| run header | C-16; `size.global.avatarComment`, `chat.thread.dimension.rowAvatarToText`, text roles `listTitle` + `caption`, `color.global.textSecondary`, `chat.thread.layout.timeFormat` | name, time (data) | avatar / name tap → `walls.member` (yours → `walls.mine`) |
| text message | text role `body`; `chat.thread.dimension.rowLinePitch`; emoji-only `chat.thread.count.emojiOnlyMax` + `fontSize.global.headerTitle` | text (data); `chat.thread.a11y.message` / `.messageMine` | long press → context menu (below) |
| photo message | C-18; `chat.thread.layout.photoFit`, `radius.global.card` | `chat.thread.a11y.photo` / `.photoMine` + `chat.thread.a11y.caption` | tap → `photo.viewer` (this thread's photos, chronological) with `duration.global.photoOpen`; long press → context menu with the quick-reaction row |
| caption | text role `body` | caption (data) | — |
| reaction chip | `chat.reactions.layout.chip`, `chat.reactions.dimension.chipTop` | `chat.reactions.a11y.cluster` | tap → Reactions sheet (`chat.reactions.md`) |
| voice message | `chat.voice.layout.capsule` | `chat.voice.a11y.*` | `chat.voice.md` |
| reply quote | C-15; `chat.thread.layout.replyQuote` | `chat.thread.reply.postTitle`, `.reply.postWeek`, `.reply.defaultText`, `.reply.defaultAttachment`, `chat.thread.a11y.replyQuote` | photo quote → `photo.viewer`; message quote → scrolls to it |
| status line | text role `caption`; `color.global.textSecondary` (sending) / `color.global.destructive` (failed); `chat.thread.layout.failedMessage` | `chat.thread.sending`, `chat.thread.sendFailed` | failed: tap → send again |
| context menu | C-29 native menu (iOS `contextMenu`, Android `DropdownMenu`) | items below | — |
| composer | C-13 (`chat.composer.md`) | `chat.composer.*` | — |

### Context menu (long press; C-29; items Sentence case, destructive last and red)

| target | items (in order) | copy | action |
|---|---|---|---|
| any text message | Reply · Copy · (others') Report Message · (yours) Unsend | `chat.thread.menu.reply`, `.menu.copy`, `.menu.report`, `.menu.delete` | Reply → reply bar + `chat.composer.placeholderReply`; Copy → clipboard + Android Toast `chat.thread.toast.copied`; Report → `safety.report` (kind `message`); Unsend → confirmation below → `delete_message` |
| voice message | Reply · (others') Report Message · (yours) Unsend | as above | as above |
| photo message | quick-reaction row (`chat.reactions.layout.quickReactions`) · Reply · Save · (others') Report Message · (yours) Delete | + `chat.thread.menu.save`, `.menu.deletePhoto` | Save → as `photo.viewer` save; Delete → `photo.viewer` delete confirmation → `delete_media` |
| your failed message | Retry · Unsend | `chat.thread.menu.retry`, `.menu.delete` | send again / remove locally |

**Unsend confirmation** (C-29 alert; `photo.viewer.layout.deleteConfirm` component): title `chat.thread.deleteMessage.title`,
message `chat.thread.deleteMessage.message`, destructive `chat.thread.deleteMessage.confirm`, cancel `photo.viewer.delete.cancel`.

**Reply bar** (above the composer while replying): one line `chat.thread.reply.bar` ("Replying to {name}", or
`chat.thread.reply.barSelf`) in text role `listSubtitle`, `color.global.textSecondary`, at `size.global.screenMargin`, and a
bare `icon.global.close` glyph (`size.global.icon`, `color.global.textSecondary`, label `chat.thread.a11y.cancelReply`) at the
trailing margin; the bar's baseline sits `size.global.sectionHeaderToContent` above the field (C-20 label → content spacing).
Appears / disappears with `duration.global.fade` + `easing.global.standard` (Retro's composer fade, APK-X m6a 150 ms).

## States

| state | what shows | components · tokens · copy | source |
|---|---|---|---|
| loading (first page) | C-28: the platform activity indicator centred in the list area, `color.global.textSecondary`; the header and composer are live | `easing.global.native.activityIndicator`; announced `week.history.a11y.loading` | C-28 (Retro shows no skeletons) |
| loading older messages | platform activity indicator above the first loaded message | same | C-28 |
| empty (no messages yet) | C-27 block centred between the header and the composer: glyph `icon.global.chats` (`size.global.emptyIcon`), title, detail, outline CTA (C-07 without glyph → C-06 outline capsule hugging its label) | `chat.thread.empty.title`, `.empty.detail`, `.empty.invite` (→ `groups.invite`); `size.global.emptyIconToTitle`, `.emptyTitleToAction`; text roles `emptyTitle` / `emptyDetail` | C-27; APK-S `journal_profile_empty_state_title`, `user_profile_empty_new_user_message` |
| error (first load failed) | C-27 block without glyph: title + detail + outline capsule | `chat.thread.error.title`, `.error.detail`, `.error.retry` (reloads) | APK-S `message_thread_fullscreen_error`, `error_message_generic` |
| offline, nothing cached | C-27 block, no capsule | `chat.thread.offline.title`, `.offline.detail` | `retro.voice.error` |
| offline with cached messages | cached messages stay; sends show `chat.thread.sending` then `chat.thread.sendFailed` | `chat.thread.layout.failedMessage` | Messages (mechanics) |
| message deleted / photo deleted | `message_deleted` / `post_deleted` remove the row; replies lose their quote | — | docs/API.md §8.2 |
| permission-denied | none here (camera → `camera.capture`; microphone → `chat.voice.md`) | — | — |

## Motion

| transition | tokens | Reduce Motion |
|---|---|---|
| push in / back | native (`easing.global.native.navigationPush`) | system |
| new message appears (sent or received) | fade in `chat.thread.duration.entry` (250 ms) with `chat.thread.easing.entry` (linear) — Retro's message-thread "entry animation" | same fade (no movement involved) |
| photo opens in the viewer | `duration.global.photoOpen` (250 ms) + `easing.global.standard` | cross-fade, same duration |
| reply bar in / out | `duration.global.fade` + `easing.global.standard` | same fade |
| scroll, keyboard, context menu | native (`easing.global.native.keyboard`, `.menu`, `.scrollIndicator`) | system |

## Haptics

| interaction | token |
|---|---|
| tap on a photo, avatar, quote (Android) | `haptic.global.tap` (iOS none) |
| long press opens the context menu | `haptic.global.longPressStart` (photo: `haptic.global.reaction`) |
| text sent | `haptic.global.send` |
| send failed | `haptic.global.error` |
| unsend confirmed | `haptic.global.warning` |

## Accessibility

- Labels: back `chat.thread.a11y.back`; each message is one element — text `chat.thread.a11y.message` / `.messageMine`,
  photo `chat.thread.a11y.photo` / `.photoMine` (+ `chat.thread.a11y.caption`), voice `chat.voice.a11y.message` / `.messageMine`;
  the run header (avatar + name + time) is read as part of the first message; the reaction chip `chat.reactions.a11y.cluster`
  (emoji names, never a count); quotes `chat.thread.a11y.replyQuote`. Context-menu actions are exposed as accessibility
  custom actions. Avatars are decorative next to a visible name.
- Day dividers and the title have the header trait. New incoming messages are announced (HIG: inform VoiceOver of changes).
- Dynamic Type: title `headerTitle` → largeTitle; names `listTitle`, text `body` → subheadline; time `caption`; divider
  `sectionLabel`; empty state `emptyTitle` / `emptyDetail` (`layout.global.textStyleMap`). Rows grow with the text.
- Focus order: back → title → messages oldest → newest (within a run: header, text, photo, chip) → reply bar → composer.
- Hit targets: back and the reply-bar close extend to 44 pt / 48 dp (`size.global.minTouchTarget.*`).
- Contrast (`node tools/contrast.mjs`, both appearances):

| foreground | background | kind | light | dark | pair |
|---|---|---|---|---|---|
| `color.global.textPrimary` | `color.global.background` | text | 21.00:1 pass | 21.00:1 pass | title, names, message text (iOS) |
| `color.global.textPrimary` | `color.global.background.android` | text | 21.00:1 pass | 17.01:1 pass | the same on Android |
| `color.global.textSecondary` | `color.global.background` | text | **2.85:1 FAIL** | 7.37:1 pass | time, sending line, quote line, reply bar (iOS) |
| `color.global.textSecondary.android` | `color.global.background.android` | text | **4.00:1 FAIL** | 6.85:1 pass | the same on Android |
| `color.global.destructive` | `color.global.background` | text | **4.18:1 FAIL** | 5.03:1 pass | failed-send line, 14 pt (iOS) |
| `color.global.destructive` | `color.global.background.android` | text | **4.18:1 FAIL** | **4.07:1 FAIL** | the same on Android |

  Failures are Retro's own palette (design/CONTRAST.md failures 1 and 5); reported, not adjusted. The failed state is also
  announced and carried by the message's accessibility value. Photos and the chip: see `chat.reactions.md`.

## Data & actions

- **Reads**: `messages` (docs/API.md §5.9) — `eq(group_id).order(created_at desc).limit(50)`, older pages with
  `lt(created_at)` (voice messages carry `voice_levels`); photo messages → `posts` (§5.8: caption, voice note with
  `voice_levels`, `reply_to_post_id`) + `media` (§5.7:
  `display_path` for the card; `thumb_path` for quotes; originals until `renditions_ready_at`); `reactions` (§5.10) for chips;
  `profiles` (§5.1); `groups` (§5.3) for the title. Signed URLs (§7, 1 h). Week number of a quoted post: ISO week of its
  `created_at` in `groups.time_zone`.
- **RPCs**: `send_message` (text; `p_reply_to_post_id` / `p_reply_to_message_id` when replying); `delete_message`;
  `delete_media` (own photo, via the viewer's confirmation); `report` (`message`) via `safety.report`; `react` / `unreact` via
  `chat.reactions`; `create_post` (photo) via `chat.composer` → `camera.capture`.
- **Realtime** (§8): channel `group-<id>` INSERTs on `messages`, `posts`, `reactions` and UPDATEs (reply target removed);
  private broadcast `group:<id>`: `post_deleted`, `message_deleted`, `reactions_changed`. Refetch the visible page on
  foreground / reconnect (§8.3).
- **Navigation in**: `groups.screen` (chat entry); `DeepLink.chatMessage(groupID:messageID:)` (`app://chat?group=…&message=…`,
  push type `reply`) opens the thread scrolled to that message. Push texts: `notifications.push.reply.*` (capture group).
- **Navigation out**: `photo.viewer`, `walls.member` / `walls.mine`, `groups.invite`, `safety.report`, `camera.capture`.

## Platform notes

- iOS: `ScrollView` + `LazyVStack` anchored to the bottom (`.defaultScrollAnchor(.bottom)`); `contextMenu` with a
  `ControlGroup` (`.controlGroupStyle(.palette)`, iOS 17) for the quick-reaction row; header via `NavigationStack` with the
  serif title drawn by the app (C-02).
- Android: `LazyColumn(reverseLayout = true)`; `combinedClickable` + `DropdownMenu` (first item a `Row` of quick reactions);
  `Toast.LENGTH_SHORT` for "Copied!". Inter weights per R-9.
- Emoji glyphs differ (Apple Color Emoji / Noto Color Emoji); emoji-only messages are sized by the font size, not by glyph width.

## Do-not-copy

- Retro thread titles listing names with a count ("%1$s, %2$s and %3$d others"), "%1$d members" subtitles, "Delivered" /
  "Seen" receipts, "✌️%1$s left the thread" (emoji system line).
- Yope's streak pill, sticker composer, lime quote block and bubble rims (superseded design).
- Messages' coloured bubbles and red "!" circle; WhatsApp's reaction count and wallpaper.
- Any unread count on the chat entry or tabs.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| Retro's own message thread (bubbles or rows, quote visuals, spacing between messages) | not captured; composed from the comment row (RS-1) | one raw screenshot of a Retro DM thread with a photo reply, light + dark (retro-visual §6) |
| spacing between runs (`size.global.listGap`) and items (`chat.thread.dimension.itemGap`) | composition (RS-3) | same screenshot |
| context-menu focus animation ("initial context message position / scale", APK-X m6a) | values not in the excerpts; native menu animation used | 60 fps recording of a long press in a Retro thread |
| Engadget inbox capture | low resolution: layout only (back chevron + serif "Messages", search field, row "Lali / Thank you · 5d"); no value taken from it | — |
| `color.global.textSecondary`, `color.global.destructive` text contrast in light | FAIL (Retro palette, R-13) | owner / verification |

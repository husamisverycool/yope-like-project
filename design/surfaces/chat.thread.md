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
| IM-E | https://support.apple.com/guide/iphone/unsend-or-edit-messages-iphe67195653/ios (accessed 2026-10-17) | "Touch and hold the message bubble, then tap Edit", the Send Edit / Cancel Edit buttons, "marked as Edited", "up to five times within 15 minutes" (`chat.thread.layout.editMessage`) |
| IM-T | https://support.apple.com/guide/iphone/react-with-tapbacks-iph018d3c336/ios (accessed 2026-10-17) | "You can only add one Tapback per message"; tap a different one to change it, the same one to remove it; tap the stack to see who (`chat.reactions.layout.messageReactions`) |
| LP | https://developer.apple.com/documentation/linkpresentation/lpmetadataprovider, https://ogp.me, https://developers.facebook.com/documentation/sharing/webmasters/web-crawlers, https://developers.facebook.com/documentation/sharing/webmasters/images (accessed 2026-10-17) | link previews on the sender's device: the page read once (LinkPresentation; og: tags in the first 1 MB, images ≤ 8 MB) (`chat.thread.layout.linkPreview`) |
| ST-T | https://unpkg.com/stream-chat-react@12.0.0/dist/i18n/en.json, https://getstream.io/chat/docs/sdk/react/v12/components/utility-components/indicators/ | Stream Chat's typing wording ("{{ user }} is typing...", "{{ users }} and {{ user }} are typing...") and its place at the end of the message list; "Edit Message", "Edited" |

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
       its emoji at `fontSize.global.headerTitle`. Web addresses in it are links (`chat.thread.layout.links`, owner decision
       34): the platform's detector finds them (http / https), they keep the body's colour and are underlined, a tap opens
       the browser.
     - **link preview** (`chat.thread.layout.linkPreview`, owner decision 34, research #16) — under a text whose
       `link_preview` is set, `chat.thread.dimension.itemGap` below it and above the reaction chip: a C-15 row (the photo
       quote's form) — the image as the thumbnail (`size.global.rowThumbWidth` × `.rowThumbHeight`, `radius.global.thumbnail`;
       none → no thumbnail), then `size.global.rowThumbGap` after it the title (text role `listTitle`) over the site (text
       role `listSubtitle`, `color.global.textSecondary`), one line each; no title → the site on the title line. A tap opens
       the address as the link does. Built on the **sender's** device only, after `send_message` returns: the first link
       written with its own scheme, the page read once (iOS LPMetadataProvider; Android one GET, og: tags within
       `htmlMaxBytes`), its image downscaled to `imageMaxPixels` JPEG, uploaded to `u/<uid>/links/<uuid>.jpg`, then
       `set_link_preview`. Best effort and silent: any failure → no preview, no message. Readers load only the uploaded
       image; nobody else's device contacts the site.
     - **photo** — C-18 photo card (`chat.thread.layout.photoFit`: `size.global.friendCardWidth` × `.friendCardHeight`,
       `radius.global.card`, aspect fill). The post's caption follows as a text item; a voice note follows as the voice
       capsule with its waveform (`chat.voice.md`, C-36); the reaction chip follows the photo (`chat.reactions.layout.chip`,
       `chat.reactions.dimension.chipTop` below it).
     - **photos posted together** (`chat.thread.layout.batch`, `layout.global.photoBatch`; owner decision 34, research #1):
       consecutive photo messages of one sender with the same `posts.batch_id` (in `created_at` order, same day, no reply
       quote between) are **one photo item**: the first photo's C-18 card carrying the batch marker at its top-trailing
       corner (`layout.global.batchMarker`: the video pill's form with `icon.global.batch` and no digits — Instagram's
       carousel icon, never a count such as "+3"), then the **first photo's** reaction chip, caption and voice note. The
       batch's other photos are not drawn here. Tap → `photo.viewer` at the first photo, the batch's photos side by side in
       posted order with page dots (`photo.viewer.layout.batchDots`). The long-press menu (quick reactions, Reply, Save,
       Report / Delete) acts on the first photo; the others are reacted to, replied to, saved or deleted in the viewer
       (each stays its own post). Another message between photos of a batch splits it into two items; a photo deleted from
       a batch leaves the rest; one photo left is an ordinary photo message.
     - **voice** — the voice capsule (`chat.voice.layout.capsule`): play glyph · C-36 waveform
       (`chat.voice.dimension.waveform`, the message's `voice_levels`; none stored → a row of dots until first played) ·
       duration (owner decision 16).
     - **reaction chip under a text or voice message** (`chat.reactions.layout.messageReactions`, owner decision 34) — the
       photo's chip (`chat.reactions.layout.chip`) `chat.reactions.dimension.chipTop` below the text or capsule: one
       reaction per person, distinct emoji newest first, never a number; tap → the Reactions sheet (who reacted with what).
     - **"Edited"** (`chat.thread.layout.editMessage`) — `chat.thread.edited` one line under a message whose `edited_at` is
       set, text role `caption`, `color.global.textSecondary`, `chat.thread.dimension.itemGap` below it (the status line's
       place).
     - **reply quote** (`chat.thread.layout.replyQuote`) above the reply it belongs to: a C-15 row for a quoted photo
       (thumbnail `size.global.rowThumbWidth` × `.rowThumbHeight`, `radius.global.thumbnail`, `chat.thread.reply.postTitle`
       over `chat.thread.reply.postWeek`), or one grey line for a quoted message ("**name** text…").
     - **status line** under your own last message while it is in flight (`chat.thread.sending`) or after it failed
       (`chat.thread.sendFailed`, `chat.thread.layout.failedMessage`).
   - **Joined / left line** (`chat.thread.layout.systemLine`, owner decision 34): when someone joins the group,
     `chat.thread.system.joined` ("{name} joined", Yope); when someone leaves, `chat.thread.system.left` ("{name} left
     the group", Retro's thread line without its emoji) — one centred line, text role `caption`, `color.global.textSecondary`,
     `size.global.listGap` from its neighbours; not part of any run (the next message starts a run); no menu; never a
     notification.
     Items inside a run are `chat.thread.dimension.itemGap` apart; runs are `size.global.listGap` apart. Later messages of
     a run carry no avatar or name. Your own messages use the same row (Retro shows everyone's comments the same way).
3. **Composer** pinned at the bottom (`chat.composer.md`; C-13 field). When replying, the reply bar sits above the field;
   when editing a sent message, the edit bar takes its place (`chat.thread.edit.bar`, below). Above both, while someone
   else types, the **typing line** (`chat.thread.layout.typingLine`): `chat.thread.typing.one` ("{name} is typing…") or
   `chat.thread.typing.several` ("{names} and {name} are typing…") — first names only, never a number — in text role
   `caption`, `color.global.textSecondary`, one line inside `size.global.screenMargin`, `chat.thread.dimension.itemGap`
   above the bar or the field.
4. The message list's bottom content inset = the composer's height + `chat.composer.dimension.bottomInset`; the list keeps
   the newest message in view when the keyboard rises. New messages (`chat.thread.layout.followNewest`, MUI X Chat / Stream
   Chat, as Messages and WhatsApp): a message I send — from the composer or from the photo viewer's reply field — brings
   the thread to it wherever the reader was (sent while the viewer covers the thread: as the viewer closes); someone
   else's is followed only while the newest message is in view — scrolled up, the list keeps its place.

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| back | C-02; `icon.global.back`, `size.global.backInset`, `size.global.headerButton` (hit area) | `chat.thread.a11y.back` | pops to `groups.screen` |
| title | C-02; text role `headerTitle`, `font.global.display`, `size.global.headerGap`, `size.global.titleTop` | group name (data) | header trait |
| day divider | C-20 dated variant; text role `sectionLabel`; `size.global.sectionGap`, `size.global.sectionHeaderToContent` | `chat.thread.divider.today`, `.divider.yesterday`, date (data) | header trait |
| run header | C-16; `size.global.avatarComment`, `chat.thread.dimension.rowAvatarToText`, text roles `listTitle` + `caption`, `color.global.textSecondary`, `chat.thread.layout.timeFormat` | name, time (data) | avatar / name tap → `walls.member` (yours → `walls.mine`) |
| text message | text role `body`; `chat.thread.dimension.rowLinePitch`; emoji-only `chat.thread.count.emojiOnlyMax` + `fontSize.global.headerTitle`; links `chat.thread.layout.links` | text (data); `chat.thread.a11y.message` / `.messageMine`; value `chat.thread.edited` when edited | long press → context menu (below); a link → the browser |
| photo message | C-18; `chat.thread.layout.photoFit`, `radius.global.card` | `chat.thread.a11y.photo` / `.photoMine` + `chat.thread.a11y.caption` | tap → `photo.viewer` (this thread's photos, chronological) with `duration.global.photoOpen`; long press → context menu with the quick-reaction row |
| photos posted together | C-18 + `layout.global.batchMarker` (`icon.global.batch`); `chat.thread.layout.batch`, `layout.global.photoBatch` | the first photo's label + `chat.thread.a11y.batch` ("Photos posted together") | tap → `photo.viewer` at the first photo (batch side by side, `photo.viewer.layout.batchDots`); long press → the first photo's menu |
| caption | text role `body` | caption (data) | — |
| reaction chip | `chat.reactions.layout.chip`, `chat.reactions.dimension.chipTop`; under text / voice: `chat.reactions.layout.messageReactions` | `chat.reactions.a11y.cluster`; on a message its value lists `chat.reactions.activity.row` / `.rowMine` | tap → Reactions sheet (`chat.reactions.md`) |
| "Edited" line | text role `caption`, `color.global.textSecondary`; `chat.thread.layout.editMessage` | `chat.thread.edited` | none (read as the message's value) |
| link preview | C-15 row; `chat.thread.layout.linkPreview`; `size.global.rowThumbWidth` / `.rowThumbHeight` / `.rowThumbGap`, `radius.global.thumbnail`, text roles `listTitle` + `listSubtitle` | title and site (data); read as "title, site", iOS link trait / Android button role | tap → the browser (as the link in the text) |
| typing line | text role `caption`, `color.global.textSecondary`; `chat.thread.layout.typingLine` | `chat.thread.typing.one`, `.typing.several` | none; not a live region |
| edit bar | the reply bar's form; `chat.thread.layout.editMessage` | `chat.thread.edit.bar`, `chat.thread.a11y.cancelEdit` | close → the message keeps its text, the draft comes back |
| voice message | `chat.voice.layout.capsule` | `chat.voice.a11y.*` | `chat.voice.md` |
| reply quote | C-15; `chat.thread.layout.replyQuote` | `chat.thread.reply.postTitle`, `.reply.postWeek`, `.reply.defaultText`, `.reply.defaultAttachment`, `chat.thread.a11y.replyQuote` | photo quote → `photo.viewer`; message quote → scrolls to it |
| joined / left line | `chat.thread.layout.systemLine`; text role `caption`, `color.global.textSecondary`, centred | `chat.thread.system.joined`, `.system.left` | none (read as its text; announced like an incoming message) |
| status line | text role `caption`; `color.global.textSecondary` (sending) / `color.global.destructive` (failed); `chat.thread.layout.failedMessage` | `chat.thread.sending`, `chat.thread.sendFailed` | failed: tap → send again |
| context menu | C-29 native menu (iOS `contextMenu`, Android `DropdownMenu`) | items below | — |
| composer | C-13 (`chat.composer.md`) | `chat.composer.*` | — |

### Context menu (long press; C-29; items Sentence case, destructive last and red)

| target | items (in order) | copy | action |
|---|---|---|---|
| any text message | quick-reaction row (`chat.reactions.layout.messageReactions`) · Reply · Copy · (yours, younger than `message_edit_window_s`) Edit · (others', group admins) Remove · (others') Report Message · (yours) Unsend | + `chat.thread.menu.edit`, `.menu.adminRemove` | Reply → reply bar + `chat.composer.placeholderReply`; Copy → clipboard + Android Toast `chat.thread.toast.copied`; Edit → the edit bar (`chat.thread.layout.editMessage`); Remove → admin remove confirmation below → `admin_delete_message`; Report → `safety.report` (kind `message`); Unsend → confirmation below → `delete_message` |
| voice message | quick-reaction row · Reply · (others', group admins) Remove · (others') Report Message · (yours) Unsend | as above | as above |
| photo message | quick-reaction row (`chat.reactions.layout.quickReactions`) · Reply · Save · (others', group admins) Remove · (others') Report Message · (yours) Delete | + `chat.thread.menu.save`, `.menu.deletePhoto`, `.menu.adminRemove` | Save → as `photo.viewer` save, on any photo (owner decision 28); Remove → admin remove confirmation → `admin_delete_post` (this group's copy); Delete → `photo.viewer` delete confirmation → `delete_media` |
| your failed message | Retry · Unsend | `chat.thread.menu.retry`, `.menu.delete` | send again / remove locally |

**Unsend confirmation** (C-29 alert; `photo.viewer.layout.deleteConfirm` component): title `chat.thread.deleteMessage.title`,
message `chat.thread.deleteMessage.message`, destructive `chat.thread.deleteMessage.confirm`, cancel `photo.viewer.delete.cancel`.

**Admin remove confirmation** (the same component; group admins on someone else's message, migration 0054; WhatsApp's admin
"Delete for Everyone", faq.whatsapp.com/1370476507114859): title `chat.thread.adminRemove.title`, message
`chat.thread.adminRemove.message` (the author is not notified), destructive `chat.thread.adminRemove.confirm`, cancel
`photo.viewer.delete.cancel`. Confirmed → `haptic.global.warning`, the message leaves the thread at once
(`admin_delete_message`; a photo message `admin_delete_post`); failed → it comes back, `haptic.global.error`. The joined /
left lines have no menu and are never removed.

**Reply bar** (above the composer while replying): one line `chat.thread.reply.bar` ("Replying to {name}", or
`chat.thread.reply.barSelf`) in text role `listSubtitle`, `color.global.textSecondary`, at `size.global.screenMargin`, and a
bare `icon.global.close` glyph (`size.global.icon`, `color.global.textSecondary`, label `chat.thread.a11y.cancelReply`) at the
trailing margin; the bar's baseline sits `size.global.sectionHeaderToContent` above the field (C-20 label → content spacing).
Appears / disappears with `duration.global.fade` + `easing.global.standard` (Retro's composer fade, APK-X m6a 150 ms).

**Edit bar** (`chat.thread.layout.editMessage`, owner decision 34; Apple Messages' edit, IM-E): the reply bar's form with
`chat.thread.edit.bar` ("Edit message") and the close glyph labelled `chat.thread.a11y.cancelEdit`. "Edit" puts the
message's text in the field (an unsent draft is put aside and comes back after; a reply in progress is dropped); send saves
it with `edit_message` and the new text shows at once; the same text closes the bar without a call. Edit is offered only
while the message is younger than `public_app_config.message_edit_window_s` (900 s, `chat.thread.duration.editWindow`); an
unknown window offers none. On failure (offline, `edit_window_closed`) the message gets its earlier text back, the field holds
the edited text with the bar again, and `chat.thread.edit.error` shows (Android Toast / iOS announcement,
`haptic.global.error`). Others' edits arrive as Realtime UPDATEs and replace the row in place; no push.

## States

| state | what shows | components · tokens · copy | source |
|---|---|---|---|
| loading (first page) | C-28: the platform activity indicator centred in the list area, `color.global.textSecondary`; the header and composer are live | `easing.global.native.activityIndicator`; announced `week.history.a11y.loading` | C-28 (Retro shows no skeletons) |
| loading older messages | platform activity indicator above the first loaded message | same | C-28 |
| empty (no messages yet) | C-27 block centred between the header and the composer: glyph `icon.global.chats` (`size.global.emptyIcon`), title, detail, outline CTA (C-07 without glyph → C-06 outline capsule hugging its label) | `chat.thread.empty.title`, `.empty.detail`, `.empty.invite` (→ `groups.invite`); `size.global.emptyIconToTitle`, `.emptyTitleToAction`; text roles `emptyTitle` / `emptyDetail` | C-27; APK-S `journal_profile_empty_state_title`, `user_profile_empty_new_user_message` |
| error (first load failed) | C-27 block without glyph: title + detail + outline capsule | `chat.thread.error.title`, `.error.detail`, `.error.retry` (reloads) | APK-S `message_thread_fullscreen_error`, `error_message_generic` |
| offline, nothing cached | C-27 block, no capsule | `chat.thread.offline.title`, `.offline.detail` | `retro.voice.error` |
| offline with cached messages | cached messages stay; sends show `chat.thread.sending` then `chat.thread.sendFailed` | `chat.thread.layout.failedMessage` | Messages (mechanics) |
| message deleted / photo deleted | `message_deleted` / `post_deleted` remove the row; replies lose their quote (an edit of that message ends) | — | docs/API.md §8.2 |
| editing | edit bar above the field holding the message's text | `chat.thread.edit.bar`, `chat.thread.a11y.cancelEdit` | IM-E |
| edit failed | the message's earlier text; the field holds the edit again | `chat.thread.edit.error`; `haptic.global.error` | IM-E; `retro.voice.error` |
| someone typing | the typing line above the composer | `chat.thread.typing.one`, `.typing.several` | ST-T; WhatsApp |
| permission-denied | none here (camera → `camera.capture`; microphone → `chat.voice.md`) | — | — |

## Motion

| transition | tokens | Reduce Motion |
|---|---|---|
| push in / back | native (`easing.global.native.navigationPush`) | system |
| new message appears (sent or received) | fade in `chat.thread.duration.entry` (250 ms) with `chat.thread.easing.entry` (linear) — Retro's message-thread "entry animation" | same fade (no movement involved) |
| photo opens in the viewer | `duration.global.photoOpen` (250 ms) + `easing.global.standard` | cross-fade, same duration |
| reply bar in / out | `duration.global.fade` + `easing.global.standard` | same fade |
| edit bar, typing line in / out | `duration.global.fade` + `easing.global.standard` (the reply bar's fade) | same fade |
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
  photo `chat.thread.a11y.photo` / `.photoMine` (+ `chat.thread.a11y.video`, + `chat.thread.a11y.batch` for photos posted
  together, + `chat.thread.a11y.caption`), voice `chat.voice.a11y.message` / `.messageMine`;
  the run header (avatar + name + time) is read as part of the first message; the reaction chip `chat.reactions.a11y.cluster`
  (emoji names, never a count; under a text or voice message its value says who reacted with what); quotes
  `chat.thread.a11y.replyQuote`. Context-menu actions are exposed as accessibility custom actions, with "Add reaction"
  (`chat.reactions.a11y.add`) on text and voice messages and one action per link named by its address. An edited message
  carries `chat.thread.edited` as its value. The typing line is read in place, never announced. Avatars are decorative next
  to a visible name.
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

- **Reads (owner decision 34)**: `message_reactions` (§5.10a) for the page's text and voice messages; `chat_typing` (§5.10b)
  rows with `until > now` when the thread opens; `public_app_config` (§11) `message_edit_window_s`, `typing_ttl_s`.
- **Reads**: `messages` (docs/API.md §5.9) — `eq(group_id).order(created_at desc).limit(50)`, older pages with
  `lt(created_at)` (voice messages carry `voice_levels`); photo messages → `posts` (§5.8: caption, voice note with
  `voice_levels`, `reply_to_post_id`) + `media` (§5.7:
  `display_path` for the card; `thumb_path` for quotes; originals until `renditions_ready_at`); `reactions` (§5.10) for chips;
  `profiles` (§5.1); `groups` (§5.3) for the title. Signed URLs (§7, 1 h). Week number of a quoted post: ISO week of its
  `created_at` in `groups.time_zone`.
- **RPCs**: `send_message` (text; `p_reply_to_post_id` / `p_reply_to_message_id` when replying); `delete_message`;
  `admin_delete_message` / `admin_delete_post` (migration 0054: group admins on others' messages; `not_group_admin`;
  `group_members.role` decides whether Remove shows);
  `delete_media` (own photo, via the viewer's confirmation); `report` (`message`) via `safety.report`; `react` / `unreact` via
  `chat.reactions`; `create_post` (photo) via `chat.composer` → `camera.capture`; `react_to_message` / `unreact_to_message`
  (text and voice); `edit_message` (`edit_window_closed`); `set_link_preview` (migration 0053: after `send_message` of my
  own text with an http(s) address, the image uploaded first to `u/<uid>/links/<uuid>.jpg`; the readers get the Realtime
  UPDATE); `set_typing` — true while the field holds text, again at most
  every `typing_ttl_s / 2`, false when it empties, on send and when the thread closes (nothing while editing, nothing
  without a TTL).
- **Realtime** (§8): channel `group-<id>` INSERTs on `messages`, `posts`, `reactions` and UPDATEs (reply target removed, an
  edit); INSERTs and UPDATEs on `message_reactions` (replace that person's row) and `chat_typing` (the typing line; a row
  stops counting when its `until` passes, with no event); private broadcast `group:<id>`: `post_deleted`, `message_deleted`,
  `reactions_changed`, `message_reactions_changed` (refetch that message's reactions). Refetch the visible page on
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
  "Seen" receipts, the emoji of "✌️%1$s left the thread" (the line itself is used without it: `chat.thread.system.left`);
  Yope's dark pill behind "<name> joined" (superseded visuals; the line is Retro caption text).
- Yope's streak pill, sticker composer, lime quote block and bubble rims (superseded design).
- Messages' coloured bubbles and red "!" circle; WhatsApp's reaction count and wallpaper.
- Any unread count on the chat entry or tabs.
- A number of photos on a batch ("+3", "5 photos", Instagram's "1/5" counter): the batch marker is a glyph (tenet 2).
- Read receipts, "seen", online dots, "N typing" or "3 people are typing" (names only); Stream's "{{ users }} and more are
  typing..." (hides who); Messages' history of earlier versions behind "Edited" (the server keeps none).

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| Retro's own message thread (bubbles or rows, quote visuals, spacing between messages) | not captured; composed from the comment row (RS-1) | one raw screenshot of a Retro DM thread with a photo reply, light + dark (retro-visual §6) |
| spacing between runs (`size.global.listGap`) and items (`chat.thread.dimension.itemGap`) | composition (RS-3) | same screenshot |
| context-menu focus animation ("initial context message position / scale", APK-X m6a) | values not in the excerpts; native menu animation used | 60 fps recording of a long press in a Retro thread |
| Engadget inbox capture | low resolution: layout only (back chevron + serif "Messages", search field, row "Lali / Thank you · 5d"); no value taken from it | — |
| `color.global.textSecondary`, `color.global.destructive` text contrast in light | FAIL (Retro palette, R-13) | owner / verification |
| Retro's own link previews | Retro shows none (not captured); the card is the thread's C-15 photo-quote row (`chat.thread.layout.linkPreview`), not iMessage's large LPLinkView card | one Retro DM screenshot with a link, if Retro ever previews links |
| Retro's own edit / typing UI | not captured; Messages' flow and Stream's wording used | one Retro DM screenshot while editing and while someone types |

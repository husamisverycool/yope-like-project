# `photo.viewer` — full photo

References: **Yope** (viewer frame, header, reply row, menu) + **Locket** (reactions, quick reactions, emoji rain)
(`docs/SURFACES.md`). Research: `design/research/yope-b.md` §4, §10; `design/research/locket.md` §7;
`design/research/platform.md` §safety, §system.permissions. Tokens: `design/tokens/social.json` (`photo.viewer.*`,
`chat.*`) + `global.*` + toast tokens of `camera.sendto` (capture group). Copy: `design/copy/social.json`
(`photo.viewer.*`) + `tagging.*` (design/copy/memory.json, `design/surfaces/tagging.md`). Only **one** independent Yope viewer source exists
(S5 t57.07): values from it are video measurements (±1.5–2 pt).

## References

| id | file | used for |
|---|---|---|
| S5-v | `references/auto/yope/frames/b-yopeapp-7591560669967682847-t57.07-photo-viewer.png` (Dec 2025 build) | **primary**: ✕ · two-line title "you sent to Oblong / Oct 30 2025" · •••, full-width photo, sender overlay, reply row |
| S5-s | `…-t57.20-viewer-swipe-start.png`, `…-t57.30-viewer-swipe-mid.png`, `…-t57.40-viewer-swipe-end.png` | horizontal swipe (`duration.global.photoSwipe`) |
| S5-r | `…-t49.50-reply-to-photo.png` | caption box styling (1:1 cards) |
| YR | `references/auto/yope/frames/a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png` | Yope's ••• opens a native pull-down menu; lowercase items, "report" in red |
| AS-8 | `references/auto/locket/store/locket-store-08.png` | Locket History (viewer): caption centred near the bottom, reply bar quick reactions 🔥 💖 + add |
| AS-4 | `references/auto/locket/store/locket-store-04.png` | reaction cluster on the photo |
| S5-sh | `references/auto/yope/frames/b-yopeapp-7591560669967682847-t66.00-share-with-friends.png` | the word "save" |

## Structure (top → bottom)

Full-screen, background `photo.viewer.color.background`. Presented over the screen it was opened from.

1. **Header row**, centred `photo.viewer.dimension.headerCenterY` (20) below the top safe-area inset:
   - ✕: bare glyph `icon.global.close` in `color.global.textPrimary`, `photo.viewer.dimension.closeGlyph` tall, centre
     `photo.viewer.dimension.closeCenterX` (39) from the left edge (no circle);
   - **title**, centred, two lines:
     line 1 = [`photo.viewer.title.you` for your photo, or the sender's first name] + space + `photo.viewer.title.sentTo` +
     space + the group name. All text role `headerTitle` (`fontSize.global.headerTitle` 15, `fontWeight.global.headerTitle`
     bold); the names in `color.global.textPrimary`, "sent to" in `color.global.textSecondary`; one line, the group name
     truncates at the tail;
     line 2 = the post date in `photo.viewer.layout.dateFormat` ("Oct 30 2025"), text role `listSubtitle` (14 regular),
     `color.global.textSecondary`; baseline `photo.viewer.dimension.titleToDate` below line 1's baseline;
   - •••: bare glyph `icon.global.more` in `color.global.textPrimary`, `photo.viewer.dimension.moreGlyphWidth` wide, centre
     `photo.viewer.dimension.moreCenterTrailing` (36) from the right edge.
2. **Photo** (`photo.viewer.layout.photo`): top `photo.viewer.dimension.photoTop` (107) below the top safe-area inset, full
   screen width, the photo's own aspect, `radius.global.photo` on all corners. A photo taller than the space above the reply
   row is scaled down to fit that space, centred (approximation, Gaps). Over it:
   - top-left: sender avatar circle `photo.viewer.dimension.senderAvatar` at `photo.viewer.dimension.senderInsetLeading` /
     `.senderInsetTop`, then the sender's first name ("you" for your own, `photo.viewer.title.you`) at
     `photo.viewer.dimension.senderNameGap`, text role `headerTitle`, `color.global.textPrimary`, top-aligned with the avatar;
   - top-right: the **"i'm in this" toggle** (component, states and copy owned by `design/surfaces/tagging.md`: white
     capsule, check glyph, `tagging.toggle`), its right edge `photo.viewer.dimension.actionTrailing` from the photo's right
     edge and its centre `photo.viewer.dimension.actionCenterTop` below the photo's top — the slot of Yope's top-right chip
     (S-19); with its first-use coach `tagging.coach`;
   - bottom-centre: caption box (only with a caption) — `chat.thread.fontSize.caption` / `.fontWeight.caption`,
     `chat.thread.dimension.captionHeight`, `.captionPaddingH`, `chat.thread.radius.caption`,
     `chat.thread.dimension.captionInsetBottom`, fill `color.global.scrim` (**BLOCKED**); centred per Locket (S-8); up to
     the full width minus the cluster; long captions wrap (text role `caption` of `chat.thread.layout.textStyleMap`);
   - bottom-left: reaction cluster (`chat.reactions.md` §1).
   - Live Photo: plays while pressed (platform Live Photo view); a dual capture shows as `daily.dualimage` (capture group).
3. **Voice note** (only when the post has one): the `chat.voice` playback bubble; position **BLOCKED**
   (`photo.viewer.layout.voiceNote`) — approximation: under the photo, left edge at `size.global.screenMargin`.
4. **Reply row**, pinned at the bottom (rides on the keyboard): text field (the composer field: `chat.composer.dimension.fieldHeight`,
   `color.global.control`, rim `chat.composer.color.fieldRimTop` / `.fieldRimBottom`, `radius.global.capsule`,
   `chat.composer.dimension.fieldPaddingLeading`) from `chat.composer.dimension.insetLeading`, placeholder
   `photo.viewer.reply.placeholder`; inside the field's right end the quick reactions 🔥 💖 and the add-reaction glyph
   (`chat.reactions.layout.quickReactions`); gap `chat.composer.dimension.gapFieldButton`; camera circle
   (`chat.composer.dimension.sideButton`, `color.global.controlRaised`, `icon.global.camera` in `color.global.textPrimary`) at
   `chat.composer.dimension.insetTrailing`. Distance to the bottom safe area: **BLOCKED** (`chat.composer.dimension.bottomInset`).
5. **Emoji rain** layer (behind the photo, in front of the background) — `chat.reactions.md` §4.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| ✕ | `icon.global.close`, `photo.viewer.dimension.closeGlyph`, `.closeCenterX`, `.headerCenterY`; hit area `size.global.minTouchTarget.*` | `photo.viewer.a11y.close` | closes the viewer (Android back too) |
| title | text roles `headerTitle`, `listSubtitle`; `color.global.textPrimary` / `.textSecondary`; `photo.viewer.dimension.titleToDate`; `photo.viewer.layout.dateFormat` | `photo.viewer.title.you`, `photo.viewer.title.sentTo`, names (data), date (data) | — |
| ••• | `icon.global.more`, `photo.viewer.dimension.moreGlyphWidth`, `.moreCenterTrailing` | `photo.viewer.a11y.more` | opens the menu below |
| menu | `photo.viewer.layout.menu` (native pull-down) | see Menu | — |
| photo | `photo.viewer.layout.photo`, `photo.viewer.dimension.photoTop`, `radius.global.photo`, swipe `duration.global.photoSwipe` + `easing.global.photoSwipe`, page gap **BLOCKED** (`photo.viewer.dimension.pageGap`) | `photo.viewer.a11y.photo` / `.photoMine` (+ `chat.thread.a11y.caption`) | horizontal swipe to the previous / next photo of the context it was opened from |
| "i'm in this" toggle | `tagging.md` tokens; position `photo.viewer.dimension.actionTrailing`, `.actionCenterTop` | `tagging.toggle`, `tagging.coach` | `tag_self` / `untag_self` (optimistic; `tagging.md`) |
| sender overlay | `photo.viewer.dimension.senderAvatar`, `.senderInsetLeading`, `.senderInsetTop`, `.senderNameGap`, text role `headerTitle` | name (data) / `photo.viewer.title.you` | tap → `walls.member` (or `walls.mine`) |
| caption box | caption tokens above | caption (data) | — |
| reaction cluster | `chat.reactions.*` | `chat.reactions.a11y.cluster` | tap → Activity sheet |
| voice note | `chat.voice.*`; position **BLOCKED** | `chat.voice.a11y.*` | plays the post's voice note |
| reply field | composer field tokens above | `photo.viewer.reply.placeholder` | typing + send (**BLOCKED** send control, `chat.composer.layout.typingState`; approximation: return key) → `send_message(text, p_reply_to_post_id)`; the reply appears in `chat.thread` |
| quick reactions | `chat.reactions.layout.quickReactions`, `chat.reactions.icon.add` | `chat.reactions.a11y.quick`, `chat.reactions.a11y.add` | 🔥 / 💖 react at once; the glyph opens the picker |
| camera circle | `chat.composer.dimension.sideButton`, `color.global.controlRaised`, `icon.global.camera` | `chat.composer.a11y.camera` | opens `camera.capture`; the photo is sent with `create_post(p_group_ids: [this group], p_reply_to_post_id)` (reply to a photo with a photo) |
| toast | `camera.sendto.layout.toast` (lime bar under the status bar: `color.global.accent`, `icon.global.check`, text role `button` in `color.global.onAccent`), dwell **BLOCKED** (`camera.sendto.duration.toastVisible`) | `photo.viewer.toast.saved`, `photo.viewer.toast.deleted` | after save / delete |

### Menu (`photo.viewer.layout.menu`, native; items in this order)

| item | shown | glyph | copy | action |
|---|---|---|---|---|
| save | always | `icon.global.download` | `photo.viewer.menu.save` | saves the original (Live Photo: still + motion) to the photo library → toast `photo.viewer.toast.saved` |
| delete | your photo | `photo.viewer.icon.delete` (destructive red) | `photo.viewer.menu.delete` | confirmation (below) → `delete_media` |
| report | someone else's photo | `icon.global.report` (destructive red) | `photo.viewer.menu.report` | `safety.report` (target kind `post`) |
| block {name} | someone else's photo | none | `photo.viewer.menu.block` | `safety.block` for the author |

**Delete confirmation** (`photo.viewer.layout.deleteConfirm`: iOS action sheet, Android AlertDialog): title
`photo.viewer.delete.title` ("delete this pic?"), message `photo.viewer.delete.message` ("it’ll be gone everywhere — from every
group you sent it to, and from chats, walls, recaps & albums."), destructive button `photo.viewer.delete.confirm`, cancel
`photo.viewer.delete.cancel`. Confirmed → `haptic.global.warning`, `delete_media`, the viewer moves to the next photo (or
closes when none), toast `photo.viewer.toast.deleted`.

## States

| state | what shows | tokens / copy | source |
|---|---|---|---|
| loading | the grid thumbnail (`thumb_path`) scaled into the frame, replaced by `display_path` when loaded; header and reply row are live | — | docs/API.md §7 (renditions) |
| error (image load) | the frame stays at the thumbnail / empty; line centred on the frame | `photo.viewer.error.load`; text role `emptyDetail`-size in `color.global.textSecondary` | `yope.voice.error` |
| gone (`post_not_found`, or `post_deleted` broadcast while open) | centred empty-state layout over the background: title + detail; ✕ stays | `photo.viewer.gone.title`, `photo.viewer.gone.detail`; text roles `emptyTitle` / `emptyDetail` | `yope.voice.error` |
| offline | cached image shows; save / delete / react / reply fail with their error strings | `photo.viewer.error.save`, `.error.delete`, `chat.reactions.error`, `chat.thread.sendFailed`; `haptic.global.error` | `yope.voice.error` |
| permission-denied (save) | Yope inline permission card above the reply row (tokens as in `chat.voice.md` Elements): bold question, gray detail, white "enable" (opens Settings) | `photo.viewer.permission.title`, `.detail`, `.button`; purpose string `system.permissions.photosAdd.purpose` | V-chuong t7.73 (`yope.voice.permission`) |
| tag error / gone / offline | as `tagging.md` (toggle reverts + toast) | `tagging.error`, `tagging.notFound`, `tagging.offline` (memory group) | — |
| empty | not applicable (the viewer always opens on a photo) | — | — |

## Motion

| transition | tokens | Reduce Motion |
|---|---|---|
| open / close | not observed (yope-b §4): native full-screen presentation (`easing.global.native.sheet`) | system cross-fade |
| swipe to adjacent photo | `duration.global.photoSwipe` (167 ms), `easing.global.photoSwipe` (paging) | finger-tracking stays (`layout.global.reduceMotion`) |
| emoji rain | `chat.reactions.md` §4 | `chat.reactions.layout.reduceMotion` |
| menu, action sheet, keyboard | native (`easing.global.native`) | system |
| toast in / out | `safety.block.layout.toast` enter rule (platform default spring), dwell BLOCKED | cross-fade |

## Haptics

| interaction | token |
|---|---|
| photo saved | `haptic.global.success` |
| delete confirmed | `haptic.global.warning` |
| save / delete / reply failed | `haptic.global.error` |
| reply sent | `haptic.global.send` |
| "i'm in this" toggled | as `tagging.md` |
| reaction | `chat.reactions.md` (none on send) |

## Accessibility

- Labels: ✕ `photo.viewer.a11y.close`; ••• `photo.viewer.a11y.more`; photo `photo.viewer.a11y.photo` / `.photoMine`
  (+ caption); the title lines are one header element read as "{you | name} sent to {group}, {date}"; sender overlay is
  a button labelled with the name; the tagging toggle per `tagging.md`; reactions per `chat.reactions.md`; quick reactions
  and camera as in Elements. The menu is exposed as accessibility actions on the photo too (save, delete / report / block).
- Swipe between photos: VoiceOver / TalkBack scroll actions (adjustable / page actions).
- Dynamic Type: title → `layout.global.textStyleMap.headerTitle`; date → `.listSubtitle`; caption →
  `chat.thread.layout.textStyleMap.caption`.
- Focus order: ✕ → title → ••• → photo → sender → "i'm in this" → caption → reactions → voice note → reply field → quick reactions → add → camera.
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | ratio | result | pair |
|---|---|---|---|---|---|
| `color.global.textPrimary` #FFFFFF | `photo.viewer.color.background` #1C191D | text | 17.41:1 | pass | title names 15 bold |
| `color.global.textSecondary` #969696 | `photo.viewer.color.background` #1C191D | text | 5.89:1 | pass | 'sent to' 15 bold and date 14 regular |
| `color.global.textPrimary` #FFFFFF | `photo.viewer.color.background` #1C191D | nontext | 17.41:1 | pass | ✕ and ••• glyphs |
| `color.global.textSecondary` #969696 | `color.global.control` #2E2E2E | text | 4.59:1 | pass | reply placeholder 17 regular |
| `color.global.control` #2E2E2E | `photo.viewer.color.background` #1C191D | nontext | 1.28:1 | **FAIL** | reply field against the background |
| `color.global.controlRaised` #434343 | `photo.viewer.color.background` #1C191D | nontext | 1.76:1 | **FAIL** | camera circle against the background |
| `color.global.onAccent` #000000 | `color.global.accent` #CDFD07 | text | 17.65:1 | pass | toast text on lime |

  Fills fail as boundaries only (the glyph / placeholder inside passes). Caption on `color.global.scrim`: not computable
  (BLOCKED). Sender name on the photo has no fixed backdrop (photo content): not computable.

## Data & actions

- **Reads**: `posts` by id (§5.8: caption, `voice_path`, `reply_to_post_id`, `created_at`), `media` (§5.7: `display_path`,
  `thumb_path`, `original_path`, `motion_path`, `front_*`), `profiles` (sender), `groups` (name), `reactions` (§5.10),
  `post_tags` (§5.11: your own row = toggle on). Context list (for swiping) comes from the opener: thread photo messages,
  `wall()` items, a week's `post_ids`, or an album's items.
- **RPCs**: `send_message(p_kind: text, p_reply_to_post_id)`; `create_post(…, p_reply_to_post_id)` (exactly this group);
  `react` / `unreact`; `tag_self` / `untag_self`; `delete_media` (owner only: removes the photo from every group, chats,
  reactions, tags, albums, recaps, tribute contributions; collages / tributes / year stories re-render without it);
  `report(post)` and `block_user` through `safety.report` / `safety.block`. `delete_post` (one group only) is not offered:
  the brief's delete removes it everywhere.
- **Save**: signed URL of `original_path` (+ `motion_path` for Live Photos) → photo library (see Platform notes).
- **Realtime**: `post_deleted` → gone state / move on; `reactions_changed` → refetch; `reactions` INSERT.
- **Navigation in**: `chat.thread`, `walls.*`, `week.recap`, `week.history`, `albums.view`; deep link
  `DeepLink.post(groupID:postID:)` (`app://post?group=…&post=…`, push types `new_post` and `reaction`).
- **Navigation out**: `walls.member`, `camera.capture`, `safety.report`, `safety.block`, back to the opener.

## Platform notes

- iOS: `.fullScreenCover`; paging `TabView(.page)` / `ScrollView` with `.scrollTargetBehavior(.paging)`; native `Menu`
  from the ••• glyph (`Button(role: .destructive)` for destructive items); `confirmationDialog` for delete; Live Photo
  via `PHLivePhotoView`; save with `PHPhotoLibrary.shared().performChanges` / `PHAssetCreationRequest` (`.photo` +
  `.pairedVideo`), add-only authorization `requestAuthorization(for: .addOnly)` with `NSPhotoLibraryAddUsageDescription`
  (`system.permissions.photosAdd.purpose`).
- Android: `HorizontalPager`; `DropdownMenu` (destructive items in `color.global.system.error`); `AlertDialog` for delete;
  save through `MediaStore.Images` insert — no permission on API 29+, `WRITE_EXTERNAL_STORAGE` runtime permission on API
  26–28 (minSdk 26, `config/app.json`). An iOS Live Photo saves as the still on Android (PLATFORM_CONSTRAINTS §Summary).

## Do-not-copy

- Streak pill under the sender name ("🔥32") — tenet 2.
- "✂ create sticker" chip — stickers / cut-outs are do-not-build.
- The sticker circle in the reply row.
- Any view count / "seen by".

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| Yope viewer beyond one frame (open / close motion, ••• contents, save, caption, ♡) | approximations above; one frame only | one 10-s recording: tap a photo in a Yope group chat, swipe to the next, open •••, close (yope-b §14 capture 2) |
| `photo.viewer.dimension.pageGap` | BLOCKED | same recording |
| tagging toggle position | Yope's top-right chip slot reused (S-19) | — |
| `photo.viewer.layout.voiceNote` | BLOCKED; approximation under the photo | one recording opening a photo with a voice memo |
| `chat.composer.dimension.bottomInset`, `chat.composer.layout.typingState` | BLOCKED (shared with the composer) | see `chat.composer.md` |
| caption box fill (`color.global.scrim`) | BLOCKED | see `chat.thread.md` |
| tall photos (taller than the free space) | approximation: fit | same recording with a 9:16 photo |
| caption + cluster overlap | not observed | — |
| video posts (premium) in the viewer | not observed in Yope: native player controls | one recording of a Yope video post |
| `camera.sendto.duration.toastVisible` | BLOCKED (capture group) | 5-s recording right after sending in Yope |

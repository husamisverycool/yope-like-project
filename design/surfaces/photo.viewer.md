# `photo.viewer` — full photo

Redesign on **Retro**: visual reference Retro's **media viewer** (screen 15: black page, header avatar with ring + name +
"Week N", "3 of 4" position pill, close circle, full-width photo, footer place / date with a trailing reaction slot,
hairline, comment rows, comment field) and its **native menu** (screen 24); the shared-album web viewer (retro.app `/j/`)
confirms the 2026 build (full-width image, "1 of N" pill, #262626 close circle, footer divider). Mechanics: Retro's own
tap-to-advance; actions (save, delete everywhere, report, block, "I'm in this", reactions, replies) from the product
brief with WhatsApp / Messages reaction mechanics (`chat.reactions.md`). Tokens: `design/tokens/social.json`
(`photo.viewer.*`, `chat.thread.*` row tokens) + `global.*`. Copy: `design/copy/social.json` (`photo.viewer.*`) + `tagging.*`
(memory group). Decisions: `design/MERGE_DECISIONS.md` → Redesign — Social (RS-10 … RS-13).

## References

| id | file | used for |
|---|---|---|
| TC-2B | `references/auto/retro/press/tc-2023-07-retro-2b.jpg` phone 2 (2.209 px/pt — verified by the full-width photo, x 1320–2188) | **primary**: every viewer measurement (`photo.viewer.dimension.*`), comment row, field |
| TC-R3 | `references/auto/retro/press/tc-2023-12-retro3.png` phone 1 | the viewer stays black under a white sheet in the light appearance; red "2 of 9" pill (do-not-copy colour) |
| WEB | `references/auto/retro/web/retro.app-42b38811bebcd07d.css`, `references/auto/retro/web/retro.app-j-welcome-iphone-full.png` | mobile viewer: image 100vw, radius 0, object-fit contain; "1 of N" pill #262626; close circle #262626; footer 12 px under the photo, 1-px divider |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | "%1$d of %2$d", "Tap to advance", "Tap left to go back", "Add a comment…", "Save to Camera Roll", "Report Post", " · with ", "Camera Roll Access", "Allow Photo Access", "Yes, delete" |
| APK-X | `references/auto/retro/apk/retro-android-2026.10.1150-excerpts.txt` | "comment media viewer transition" 250 ms FastOutSlowIn (open) |
| TC-RWP | `references/auto/retro/press/tc-2025-12-rewind-panels.png` | native menu with red destructive items |
| WEB-JS | `references/auto/retro/web/retro.app-viewer-and-hero-js-excerpts.txt` §1 (+ the album page script `retro.app/_next/static/chunks/pages/j/[journalSlug]-dafa8851fc588797.js`, read 2026-10-17) | a video page: Mux player, `loop`, `autoPlay: "muted"`, shown on `onCanPlay` over the photo; phone taps go back / forward over the player too |
| HIG-A / HIG-L | https://developer.apple.com/design/human-interface-guidelines/playing-audio, …/live-photos | sound rules (silent mode, headphones), Live Photo press-to-play and badge |

## Structure (top → bottom)

Full-screen, presented over the opener. The viewer renders in the **dark appearance in both system appearances**
(`photo.viewer.layout.appearance`): page `color.global.backgroundDeep`; themed tokens resolve to their dark values.

1. **Header** (fixed, below the top safe area):
   - leading: avatar `size.global.avatarHeader` (ring included; C-22) at `photo.viewer.dimension.headerInset`. The ring
     (`photo.viewer.layout.avatarRing`, TC-2B) is Retro's position indicator: a `color.global.textOnMedia` arc `strokeWidth`
     (2.0) wide with round caps, from 12 o'clock clockwise through index ÷ total of the context ("3 of 4" → three
     quarters; one photo → the full circle), the photo `gap` (3.0) inside it; it changes with the page cross-fade and is
     hidden from VoiceOver / TalkBack (the pill names the position);
   - `photo.viewer.dimension.headerAvatarToText` after it, two lines centred on the avatar, baselines
     `photo.viewer.dimension.headerLinePitch` apart: the author's display name (text role `listTitle`,
     `color.global.textOnMedia`) and `photo.viewer.header.week` ("Week 28"; opened from a wall:
     `photo.viewer.header.groupWeek`) in text role `listSubtitle`, `color.global.textSecondary`;
   - trailing, centred on the avatar: the position pill (C-22: `size.global.positionPillHeight`, `color.global.controlOnDeep`,
     label `photo.viewer.position` in text role `badge`, `color.global.textOnMedia`; only when the context holds more than one
     photo), `size.global.pillGap`, then the close circle (`photo.viewer.dimension.closeCircle`, `color.global.controlOnDeep`,
     `icon.global.close` with ink `photo.viewer.dimension.closeGlyph` in `color.global.textOnMedia`) whose right edge sits at
     `size.global.screenMargin`.
2. **Scroll area** (between the header and the field; scrolls vertically when the content is taller):
   - **Photo** `photo.viewer.dimension.headerToPhoto` below the avatar: full width, its own aspect, never cropped, square
     corners, letterboxed when taller than the area (`photo.viewer.layout.photo`). Tap = advance (`photo.viewer.layout.advance`):
     the leading 20 % of the photo (`photo.viewer.layout.backZone`, Retro's own viewer: `clientX < 0.2 × width` → previous) goes back, the rest goes forward; past the last photo the
     viewer closes. Long press = context menu with the quick-reaction row (`chat.reactions.layout.quickReactions`) and the
     menu items below. A **video** plays in the frame and a **Live Photo** plays while held (sections below).
   - **Footer** inside `size.global.screenMargin`: leading text block — first baseline `photo.viewer.dimension.footerFirstBaseline`
     below the photo, lines `photo.viewer.dimension.footerLinePitch` apart:
     1. the caption, if any (text role `listTitle`, `color.global.textOnMedia`, wraps) — Retro's place line;
     2. the date `photo.viewer.layout.dateFormat` ("Wednesday, July 5"), text role `listSubtitle`, `color.global.textSecondary`,
        followed by " · " and the **tag run** owned by `tagging.md` (memory group, RM-9): `tagging.toggle` ("I'm in this",
        `color.global.textOnMedia`) when nobody is tagged, else `tagging.with` ("with {names}"); the run is one button;
     3. the voice note, if any (`photo.viewer.layout.voiceNote`: voice capsule on `color.global.controlOnDeep` — play
        glyph · C-36 waveform from the post's `voice_levels`, played bars `color.global.textOnMedia`, unplayed
        `color.global.textSecondary` · duration; owner decision 16).
     Trailing, centred on the first line: the reaction chip (`chat.reactions.layout.chip`, on `color.global.controlOnDeep`;
     hidden when empty) and the add-reaction glyph (`chat.reactions.icon.add`, `color.global.textSecondary`) at the margin
     — Retro's reaction slot (its heart like is do-not-copy).
   - **Divider** (C-32, `color.global.separator` → #4D4D4D in the forced dark appearance, `size.global.hairline`, inside the
     margins) `photo.viewer.dimension.footerToDivider` below the footer's last baseline (or the voice capsule's bottom).
   - **Comments** (`photo.viewer.layout.comments`): the group-chat replies to this photo, oldest first, as `chat.thread`
     message rows (C-16) in `color.global.textOnMedia` (a voice reply is the voice capsule on media with its waveform,
     `chat.voice.md`); first row `photo.viewer.dimension.dividerToComments` below the divider,
     rows `size.global.listGap` apart. None → the divider and the list are left out.
3. **Reply field** (fixed, C-13 on media): `color.global.controlOnDeep`, `size.global.commentFieldHeight`,
   `radius.global.commentField`, `size.global.screenMargin` insets, own avatar at `chat.composer.dimension.avatarInset`,
   placeholder `photo.viewer.reply.placeholder` ("Add a comment…", `color.global.textSecondary`) after
   `chat.composer.dimension.avatarToText`; trailing `icon.global.camera` then `icon.global.more` (menu) with the last glyph's
   ink at `chat.composer.dimension.glyphInsetTrailing`, `size.global.headerIconPitch` apart; while typing both become
   `icon.global.send` (`chat.composer.layout.typingState`). `photo.viewer.dimension.commentsToField` above it; bottom on the
   safe area (`chat.composer.dimension.bottomInset`), on the keyboard while typing.

### Menu (`photo.viewer.layout.menu`; field "•••" and photo long press; C-29 native)

| item | shown | glyph | copy | action |
|---|---|---|---|---|
| Save to Camera Roll | your photo (owner decision 12) | `icon.global.download` | `photo.viewer.menu.save` | saves the original (Live Photo: still + motion) → Android Toast `photo.viewer.toast.saved` / iOS announcement; `haptic.global.success` |
| Delete | your photo | `icon.global.trash`, destructive | `photo.viewer.menu.delete` | confirmation → `delete_media` |
| Report Post | someone else's | `icon.global.report`, destructive | `photo.viewer.menu.report` | `safety.report` (kind `post`) |
| Block {name} | someone else's | none | `photo.viewer.menu.block` | `safety.block` for the author |

Save is your own photo only: saving to the camera roll takes the photo out of the app, and owner decision 12 lets a
photo leave the app only when it is the viewer's own (Retro's Rewind and Timehop resurface only your own photos; BeReal
has no way to save or share another person's post). Someone else's photo shows Report and Block only.

**Delete confirmation** (`photo.viewer.layout.deleteConfirm`: iOS action sheet, Android AlertDialog): title
`photo.viewer.delete.title`, message `photo.viewer.delete.message` (removed everywhere), destructive
`photo.viewer.delete.confirm` ("Yes, delete"), cancel `photo.viewer.delete.cancel`. Confirmed → `haptic.global.warning`,
`delete_media`, the viewer moves to the next photo (or closes), Android Toast `photo.viewer.toast.deleted`.

### Video (`photo.viewer.layout.video`; WEB-JS, HIG-A)

- The frame of a video is the photo frame at the video's own aspect (aspect fit, letterboxed on
  `color.global.backgroundDeep`). The poster (the display rendition) shows until the first frame is drawn.
- When its page shows, the video starts **muted and loops** (Retro's viewer: `autoPlay: "muted"`, `loop`). Taps still go
  forward and back (`photo.viewer.layout.advance` / `.backZone`); long press opens the menu.
- **Sound**: a C-11 glass circle (`size.global.circleButtonPhoto`, `color.global.glass`) at the visible video's
  bottom-trailing corner, `size.global.screenMargin` in on both axes (the selfie stack's mirror):
  `icon.photo.viewer.soundOff` while muted, `icon.photo.viewer.soundOn` with sound; a tap toggles. The choice holds for
  every video until the viewer closes. Muted it takes no audio focus and mixes with other apps (iOS `.ambient`); with
  sound — started by the person — it plays in silent mode (iOS `.playback`) and takes the media audio focus (Android
  `USAGE_MEDIA`); it pauses when headphones are disconnected.
- It **pauses** when its page changes, the viewer closes, the app goes to the background, or the selfie capture layer
  opens.
- **Reduce Motion** (and iOS Auto-Play Video Previews off): no autoplay. A C-11 glass circle with `icon.global.play`
  centred on the video plays it once, with sound; at its end the circle returns. The same circle shows after a system
  pause (headphones out, audio focus lost).
- **Error**: `photo.viewer.error.load` centred over the poster; a tap retries.
- Accessibility: the photo's label adds `chat.thread.a11y.video` ("Video, 0:08"); its custom actions add
  `photo.viewer.a11y.play` while the play circle shows, else `photo.viewer.a11y.unmute` / `.a11y.mute`. The circles
  themselves are hidden from VoiceOver / TalkBack (the photo's actions reach them; the photo keeps its tap zones).

### Live Photo (`photo.viewer.layout.livePhoto`; HIG-L)

- **Touch and hold** the photo plays its motion with its sound; release stops it (iOS `PHLivePhotoView` `.full`, its
  own press gesture off so taps still go forward and back; Android the paired movie played with ExoPlayer over the
  still). It plays under Reduce Motion too (the person starts it).
- On a Live Photo the long press plays it, so the menu and quick reactions are the field's "•••" and the add-reaction
  glyph (both already on the page). VoiceOver / TalkBack: custom action `photo.viewer.a11y.play` (the whole motion once).
- **Badge**: the system Live Photo badge at the visible photo's top-leading corner, `size.global.videoPillInset` in (iOS
  `PHLivePhotoView.livePhotoBadgeImage(options: .overContent)` once the Live Photo is loaded; Android
  `icon.photo.viewer.livePhoto` in `color.global.textOnMedia`, `size.global.icon`). Decorative. HIG-L: no
  video-style play button on a Live Photo.
- Android does not capture motion photos (CameraX has no such use case; docs/PLATFORM_CONSTRAINTS.md §6). It plays the
  ones iOS members post.

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| header avatar + lines | C-22, C-23; `size.global.avatarHeader`, `photo.viewer.dimension.headerInset`, `.headerAvatarToText`, `.headerLinePitch`; text roles `listTitle` / `listSubtitle` | name (data), `photo.viewer.header.week` / `.header.groupWeek` | tap → `walls.member` (yours → `walls.mine`) |
| position pill | C-22; `size.global.positionPillHeight`, `color.global.controlOnDeep`, text role `badge` | `photo.viewer.position` | — |
| close | C-11 on media; `photo.viewer.dimension.closeCircle`, `.closeGlyph`, `color.global.controlOnDeep`, `icon.global.close`; hit `size.global.minTouchTarget.*` | `photo.viewer.a11y.close` | closes (Android back too) |
| photo | `photo.viewer.layout.photo`, `photo.viewer.layout.advance`, `photo.viewer.layout.backZone` (0.2, leading) | `photo.viewer.a11y.photo` / `.photoMine` (+ `chat.thread.a11y.caption`); hints `photo.viewer.a11y.advanceHint`, `.backHint`; actions `.a11y.next`, `.a11y.previous` | tap advances; long press → menu with quick reactions |
| video sound / play circle | C-11 glass; `photo.viewer.layout.video`, `size.global.circleButtonPhoto`, `size.global.screenMargin`, `icon.photo.viewer.soundOff` / `.soundOn`, `icon.global.play` | `photo.viewer.a11y.unmute` / `.mute` / `.play` | toggles sound for the open viewer / plays once with sound |
| Live Photo badge | `photo.viewer.layout.livePhoto`, `size.global.videoPillInset`; Android `icon.photo.viewer.livePhoto` | — (decorative) | — |
| caption / date lines | text roles `listTitle` / `listSubtitle`; `photo.viewer.dimension.footerFirstBaseline`, `.footerLinePitch`; `photo.viewer.layout.dateFormat` | caption, date (data) | — |
| voice note | `photo.viewer.layout.voiceNote` (`chat.voice.layout.capsule` with C-36 on media) | `chat.voice.a11y.*` | plays the post's voice note; the played bars follow it |
| tag run ("I'm in this" / "with {names}") | footer line 2 after " · " (`tagging.md`: text role `listSubtitle`) | `tagging.toggle`, `tagging.with` | untagged: `tag_self`; tagged: opens the "In this photo" sheet (`tagging.md`) |
| reaction chip + add | `chat.reactions.layout.chip`, `chat.reactions.icon.add` | `chat.reactions.a11y.cluster`, `.a11y.add` | Reactions sheet / picker |
| divider | C-32 | — | decorative |
| comments | C-16 rows; `photo.viewer.layout.comments`, `.dimension.dividerToComments`, `chat.thread.dimension.*` | `chat.thread.a11y.message` / `.messageMine` | long press → the thread's message menu |
| reply field | C-13 on media; `chat.composer.dimension.*`, `chat.composer.layout.typingState` | `photo.viewer.reply.placeholder`, `chat.composer.a11y.camera`, `photo.viewer.a11y.more`, `chat.composer.a11y.send` | send → `send_message(text, p_reply_to_post_id)`; camera → `camera.capture` reply (`create_post(p_reply_to_post_id)`); "•••" → menu |

## States

| state | what shows | components · tokens · copy | source |
|---|---|---|---|
| loading | the opener's thumbnail (`thumb_path`) scaled into the photo frame, swapped for `display_path` with `duration.global.fade`; header, footer and field live | C-28 | docs/API.md §7 |
| error (image) | one tappable line centred on the photo frame, text role `body`, `color.global.textSecondary` | `photo.viewer.error.load` (tap retries) | `retro.voice.error` (list / widget one-liner) |
| gone (`post_not_found`, or `post_deleted` while open) | C-27 block centred in the scroll area, no glyph: title + detail; close stays | `photo.viewer.gone.title`, `.gone.detail`; text roles `emptyTitle` / `emptyDetail` | C-27 |
| loading (video) | the poster (display rendition, the thumbnail before it) until the first frame; the controls show over it | `photo.viewer.layout.video` | WEB-JS (`onCanPlay`) |
| error (video) | `photo.viewer.error.load` over the poster (tap retries) | `photo.viewer.layout.video` → error | — |
| offline | this device's copy of the photo: iOS the group's cached feed; Android the viewer's own copy of the photo from an earlier visit (post, media, people, reactions, comments, tags), else the post in its thread's cache. Nothing cached → the error line. Back online, a photo that failed or came from the copy loads again. Save / delete / react / reply fail with their strings | `photo.viewer.error.load`, `.error.save`, `.error.delete`, `chat.reactions.error`, `chat.thread.sendFailed`; `haptic.global.error` | — |
| permission-denied (save) | C-29 native alert (presented in the system appearance): title / detail / "Allow Photo Access" (opens Settings) / Cancel | `photo.viewer.permission.title`, `.permission.detail`, `.permission.button`, `photo.viewer.delete.cancel`; purpose string `system.permissions.photosAdd.purpose` | `retro.voice.permission` |
| tag error / gone / offline | per `tagging.md` | `tagging.error`, `tagging.removeError`, `tagging.notFound`, `tagging.offline` | memory group |
| empty | not applicable (the viewer opens on a photo) | — | — |

## Motion

| transition | tokens | Reduce Motion |
|---|---|---|
| open from a card / tile / message / comment | `duration.global.photoOpen` (250 ms) + `easing.global.standard` (Retro "comment media viewer transition") | cross-fade, same duration |
| advance / go back | cross-fade `duration.global.crossfade` between the two photos (Retro's advance motion not captured) | same |
| close | native dismissal of the full-screen presentation (`easing.global.native`) | system |
| image loaded (thumbnail → display) | `duration.global.fade` | same |
| video page shows | plays muted, looping (`photo.viewer.layout.video`) | no autoplay: the play circle (`layout.global.reduceMotion`; iOS also Auto-Play Video Previews off) |
| Live Photo held | its motion plays (`photo.viewer.layout.livePhoto`) | same (started by the person) |
| menu, alerts, keyboard | native | system |

## Haptics

| interaction | token |
|---|---|
| tap to advance, tap close / pill controls (Android) | `haptic.global.tap` (iOS none) |
| long press (menu with quick reactions) | `haptic.global.reaction` |
| photo saved | `haptic.global.success` |
| delete confirmed | `haptic.global.warning` |
| save / delete / reply failed | `haptic.global.error` |
| reply sent | `haptic.global.send` |

## Accessibility

- Labels: close `photo.viewer.a11y.close`; "•••" `photo.viewer.a11y.more`; photo `photo.viewer.a11y.photo` / `.photoMine`
  (+ caption) with hints `photo.viewer.a11y.advanceHint` / `.backHint` and custom actions `photo.viewer.a11y.next` /
  `.previous` (tap zones are not required); the menu items are also custom actions on the photo. A video adds
  `chat.thread.a11y.video` to the label and `photo.viewer.a11y.play` or `.a11y.unmute` / `.a11y.mute` to the actions; a
  Live Photo adds `photo.viewer.a11y.play`. The header (name + week) is one element; the pill is read as "3 of 4"
  (position only).
- Focus order: close → header → pill → photo → caption → date → tag run → voice note → reactions → add → comments →
  field → camera → "•••".
- Dynamic Type: `listTitle` / `listSubtitle` / `body` → subheadline, `badge` → caption2 (`layout.global.textStyleMap`); the
  footer grows; the pill and close keep their size (their labels carry the information).
- Contrast (`node tools/contrast.mjs --appearance dark`; the viewer is dark in both appearances):

| foreground | background | kind | ratio | result | pair |
|---|---|---|---|---|---|
| `color.global.textOnMedia` | `color.global.backgroundDeep` | text | 21.00:1 | pass | name, caption, comments |
| `color.global.textSecondary` | `color.global.backgroundDeep` | text | 7.37:1 | pass | week line, date, comment times |
| `color.global.textOnMedia` | `color.global.controlOnDeep` | text | 15.13:1 | pass | "3 of 4", close glyph, voice label |
| `color.global.textSecondary` | `color.global.controlOnDeep` | text | 5.31:1 | pass | "Add a comment…", field glyphs |
| `color.global.controlOnDeep` | `color.global.backgroundDeep` | nontext | 1.39:1 | **FAIL** | pill / close / field / chip boundaries (identified by their content) |
| #4D4D4D (`color.global.separator` dark) | `color.global.backgroundDeep` | nontext | 2.48:1 | **FAIL** | divider (decorative) |

  Fill failures are Retro's palette (design/CONTRAST.md failure 2); reported, not adjusted.

## Data & actions

- **Reads**: `posts` by id (§5.8: caption, `voice_path`, `created_at`), `media` (§5.7: `display_path`, `thumb_path`,
  `original_path`, `motion_path`, `front_*`), `profiles` (author, commenters), `groups` (name for the wall form),
  `reactions` (§5.10), `post_tags` (§5.11: names for "with …", your row = toggle on), `messages` with
  `reply_to_post_id = post` (§5.9, comments). Week number: ISO week of `created_at` in `groups.time_zone`. The context list
  (advance order) comes from the opener: thread photos, `wall()` items, a week's `post_ids`, recap items, an album's items.
- **RPCs**: `send_message(p_kind: text, p_reply_to_post_id)`; `create_post(…, p_reply_to_post_id)` (exactly this group);
  `react` / `unreact`; `tag_self` / `untag_self`; `delete_media` (owner: removes it from every group, chats, reactions, tags,
  albums, recaps, tribute contributions); `report(post)`, `block_user` via `safety.report` / `safety.block`.
- **Save** (your own photo only): signed URL of `original_path` (+ `motion_path`) → photo library.
- **Play**: a video streams the signed URL of `original_path` (the worker's H.264 / AAC MP4, at most `video_max_ms`;
  `media.duration_ms` for the label); a Live Photo's motion is `motion_path` (iOS downloads still + motion into the
  `PHLivePhoto`; Android streams the motion when held).
- **Realtime**: `post_deleted` → gone state / move on; `reactions_changed` → refetch; `messages` INSERT with this
  `reply_to_post_id` → new comment row.
- **Navigation in**: `chat.thread`, `walls.*`, `week.recap`, `week.history`, `albums.view`; `DeepLink.post(groupID:postID:)`
  (`app://post?group=…&post=…`, push types `new_post`, `reaction`).
- **Navigation out**: `walls.member` / `walls.mine`, `camera.capture`, `safety.report`, `safety.block`, back to the opener.

## Platform notes

- iOS: `.fullScreenCover`, root `.environment(\.colorScheme, .dark)`; tap zones via `onTapGesture` with location; native
  `Menu` on "•••" and `contextMenu` (palette `ControlGroup` for quick reactions) on the photo; `confirmationDialog` for
  delete; `PHLivePhotoView`; save with `PHPhotoLibrary` add-only authorization (`NSPhotoLibraryAddUsageDescription` =
  `system.permissions.photosAdd.purpose`). Video: `AVQueuePlayer` + `AVPlayerLooper` in an `AVPlayerLayer` (one per
  page), `AVAudioSession` `.ambient` muted / `.playback` with sound; `UIAccessibility.isVideoAutoplayEnabled`. Live
  Photo: `PHLivePhotoView.startPlayback(with: .full)` from the page's long press (`viewerTapNavigation(onHold:)`); the
  photo's `contextMenu` is off on a Live Photo.
- Android: full-screen route wrapped in `DsTheme(dark = true)`; `pointerInput` tap with x position; `DropdownMenu`
  (destructive items `color.global.system.error`); `AlertDialog`; save via `MediaStore` (no permission on API 29+;
  `WRITE_EXTERNAL_STORAGE` on 26–28); an iOS Live Photo saves as its still. Video and Live Photo motion: one Media3
  `ExoPlayer` for the open viewer (`rememberViewerPlayback`, paused on `ON_PAUSE`, released on close) drawn in a
  `TextureView`; muted volume 0 without audio focus, with sound `AudioAttributes(USAGE_MEDIA, CONTENT_TYPE_MOVIE)` with
  focus handling and `setHandleAudioBecomingNoisy`; Reduce Motion from `reduceMotion()` (animator duration
  scale 0 / animators disabled). Offline copy in the data cache under `viewer/<postId>`.

## Do-not-copy

- Retro's heart like, "Likers", comment hearts; the red "2 of 9" pill; "Seen" / view lists.
- Retro's postcard, share-to-Stories / TikTok targets, "Repost to Week", "Send as Postcard" (not product features).
- Yope's swipe paging, "✂ create sticker" chip, streak pill.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| `photo.viewer.layout.backZone` (old BLOCKED) | closed 2026-10-16: the leading 20 % (Retro's album-page viewer script, `references/auto/retro/web/retro.app-viewer-and-hero-js-excerpts.txt` §1; the in-app NUX names the same left zone) | a recording of the in-app viewer would confirm the app uses the web's fraction |
| header avatar ring (C-22 "ring width not measured") | closed 2026-10-16: `photo.viewer.layout.avatarRing` — Retro's ring is a progress arc (TC-2B "3 of 4" = three quarters), 2.0-pt stroke, 3.0-pt gap, round caps | — |
| `photo.viewer.layout.voiceNote` (old BLOCKED) | closed: footer line (composition, RS-13) | — |
| header position under the safe area; advance / close motion | not measurable from TC-2B (render) | 60 fps recording: open a friend's photo, tap through 3, close |
| year form of the date for older photos | platform long date with the year (not captured in Retro) | one Retro viewer screenshot of a photo from a past year |
| viewer metrics are 2023 render values (±0.5 pt); the foundations' C-22 / C-13 sizes used a 2.298 px/pt scale — at the verified 2.209 the avatar is 40.7, the pill 26.3, the field 51.2 pt (RS-25) | reported | one raw iPhone screenshot of the current viewer with a comment |
| Retro's in-app video viewer | the web viewer's mechanics stand in (WEB-JS: muted autoplay, loop, taps navigate); the in-app sound control's place is not captured — the apps put it at the bottom-trailing corner | a recording of a video post opened in Retro's app |
| where Retro shows a caption | unknown (its web title uses "caption or location · date"); the caption takes the place line (RS-11) | one raw screenshot of a captioned Retro photo |

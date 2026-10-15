# Verification — `chat.thread` (iOS)

Group chat thread — `ios/App/Sources/Features/Social/UI/ChatThreadView.swift`, `Core/ChatThreadModel.swift` (Screens/ChatScreen.swift is the route entry).

Checklist written from the spec (`design/surfaces/chat.thread.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`), then `tools/sidebyside.py` makes `design/verification/chat.thread.png` next to the reference image(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level).

Reference image(s): `references/auto/yope/store/yope-store-05.png`, `references/auto/yope/frames/b-derot-store-05-rot-1.68.png`, `references/auto/yope/frames/b-yopeapp-7591560669967682847-t49.50-reply-to-photo.png`, `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t51.23-group-created-empty-state.png`, `references/auto/yope/frames/b-alexaa-7652512140875566349-t5.83-group-chat-pill.png`

Snapshots (CI): `chat.thread-ready.png`, `chat.thread-loading.png`, `chat.thread-empty.png`, `chat.thread-error.png`, `chat.thread-offline.png`, `chat.thread-offline-cached.png`, `chat.thread-send-failed.png`

**Summary: 42 matched · 6 approximated · 1 not matched (BLOCKED or not buildable).**

## Header

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `color.global.background` | #171717 (SOURCED) | screen background | ZStack background, ignores safe area |
| matched | `size.global.headerButton`<br>`color.global.control`<br>`icon.global.back`<br>`color.global.textPrimary`<br>`size.global.headerInset`<br>`chat.thread.a11y.back` | 44 pt (SOURCED)<br>#2E2E2E (SOURCED)<br>ios: chevron.left; android: AutoMirrored.Rounded.KeyboardArrowLeft (PLATFORM)<br>#FFFFFF (SOURCED)<br>11.5 pt (SOURCED)<br>“back” (SOURCED) | ‹ circle at the header inset | shared HeaderCircleButton (fill .onBackground), padding(.horizontal, headerInset) |
| matched | `size.global.headerGap` | 7.3 pt (SOURCED) | gap ‹ → capsule | HStack(spacing: headerGap) |
| approximated | `chat.thread.dimension.headerCapsuleHeight`<br>`color.global.control`<br>`radius.global.capsule`<br>`size.global.avatarHeader`<br>`icon.global.chevron`<br>`color.global.textSecondary` | 43.3 pt (SOURCED)<br>#2E2E2E (SOURCED)<br>shape: capsule; radius: height / 2 (SOURCED)<br>28 pt (SOURCED)<br>ios: chevron.right; android: AutoMirrored.Rounded.KeyboardArrowRight (PLATFORM)<br>#969696 (SOURCED) | group capsule (hugs content) | Capsule fill, min height token; avatar start inset = (capsule − avatar)/2 (not measured); › glyph at the platform size |
| matched | `chat.thread.a11y.groupCapsule` | “{group_name}, group info” (SOURCED) | capsule label, opens the group profile | AccountRoute.groupProfile |
| matched | `icon.global.recap`<br>`chat.thread.a11y.recap` | ios: film.stack; android: Rounded.VideoLibrary (PLATFORM)<br>“view recap” (SOURCED) | film-strip circle → latest ready recap; hidden without one | shown only when latestRecapID != nil; pushes AppRoute.recap |

## Message geometry

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `chat.thread.dimension.bubbleInsetTheirs`<br>`chat.thread.dimension.bubbleInsetMine` | 50.5 pt (SOURCED)<br>23 pt (SOURCED) | their bubble left edge / my bubble right edge | avatar column + padding; trailing padding for mine |
| matched | `chat.thread.dimension.bubblePaddingH`<br>`chat.thread.dimension.bubbleHeight`<br>`chat.thread.radius.bubble` | 11.5 pt (SOURCED)<br>35.6 pt (SOURCED)<br>16 pt (SOURCED) | bubble padding, single-line height (minimum), corners, no tail | TextBubble: padding, frame(minHeight:), RoundedRectangle |
| matched | `chat.thread.dimension.bubbleMaxWidth` | 256 pt (SOURCED) | bubble hugs its text up to 256, then wraps (G-1) | SocialMaxWidth Layout proposes ≤ 256 to the padded text and takes its size |
| matched | `chat.thread.color.bubbleTheirs`<br>`chat.thread.color.bubbleMine` | #2B2B2B (SOURCED)<br>#232323 (SOURCED) | bubble fills | background by sender |
| matched | `chat.thread.dimension.bubbleRim`<br>`chat.thread.color.bubbleRimTheirsTop`<br>`chat.thread.color.bubbleRimTheirsBottom`<br>`chat.thread.color.bubbleRimMineTop`<br>`chat.thread.color.bubbleRimMineBottom` | 0.44 pt (SOURCED)<br>#414141 (SOURCED)<br>#363636 (SOURCED)<br>#393939 (SOURCED)<br>#343434 (SOURCED) | hairline rim shading top → bottom | strokeBorder(LinearGradient top→bottom, lineWidth: bubbleRim) |
| matched | `chat.thread.dimension.avatarInset`<br>`size.global.avatarSmall`<br>`chat.thread.dimension.avatarGap` | 11.2 pt (SOURCED)<br>32.6 pt (SOURCED)<br>6.7 pt (SOURCED) | avatar column, beside the last message of a run only | ChatRowLayout.showsAvatar (unit-tested); empty column keeps the inset |
| approximated | `chat.thread.dimension.emojiOnlyGlyph`<br>`chat.thread.count.emojiOnlyMax`<br>`chat.thread.layout.textStyleMap` | 47.5 pt (SOURCED)<br>3 (SOURCED)<br>replyName: subheadline; replyLabel: footnote; caption: title2; emojiOnly: largeTitle (PLATFORM) | a message of only 1–3 emoji: large, no bubble; 4+ as a text bubble (G-2) | SocialEmojiText.emojiOnlyCount (unit-tested); the glyph width is set as the font size (Apple Color Emoji advance ≈ point size), Dynamic Type largeTitle |
| matched | `chat.thread.dimension.photoInsetTrailing`<br>`chat.thread.dimension.photoWidth`<br>`chat.thread.dimension.photoHeight`<br>`radius.global.photo`<br>`chat.thread.layout.photoFit` | 18.7 pt (SOURCED)<br>323 pt (SOURCED)<br>174 pt (SOURCED)<br>15 pt (SOURCED)<br>content: aspect fill, centred; frameWidthPt: 323; frameHeightPt: 174; timeOverlay: centred on the photo (text role overlayTime) (SOURCED) | photo message 323 × 174 shape, aspect fill | aspectRatio(photoWidth/photoHeight) between the insets, clipShape(radius.global.photo), image .fill |
| matched | `chat.thread.dimension.gapSameSender`<br>`chat.thread.dimension.gapTextToVoice`<br>`chat.thread.dimension.photoGap`<br>`chat.thread.dimension.gapBetweenSenders` | 3.6 pt (SOURCED)<br>4.7 pt (SOURCED)<br>15.3 pt (SOURCED)<br>15 pt (SOURCED) | vertical gaps | ChatGap per row (unit-tested) |
| approximated | `chat.thread.dimension.photoGap` | 15.3 pt (SOURCED) | photo ↔ bubble gap (not measured) | photoGap, per spec Gaps |

## On a photo message

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `fontSize.global.overlayTime`<br>`fontWeight.global.overlayTime`<br>`color.global.textPrimary`<br>`chat.thread.layout.timeFormat` | 21 pt (SOURCED)<br>heavy (SOURCED)<br>#FFFFFF (SOURCED)<br>pattern: h:mm a; example: 10:00 PM; locale: device locale short time (SOURCED) | time centred on the photo | TextRole.overlayTime; DateFormatter template h:mm a in the device locale |
| matched | `chat.thread.dimension.captionInsetBottom`<br>`chat.thread.dimension.captionHeight`<br>`chat.thread.dimension.captionPaddingH`<br>`chat.thread.radius.caption`<br>`chat.thread.fontSize.caption`<br>`chat.thread.fontWeight.caption` | 7.8 pt (SOURCED)<br>45.8 pt (SOURCED)<br>20 pt (SOURCED)<br>13 pt (SOURCED)<br>21 pt (SOURCED)<br>bold (SOURCED) | caption box, one line, tail truncation | PhotoCaption (lineLimit 1) |
| not matched | `color.global.scrim` | #00000080 (SOURCED) | caption box fill | BLOCKED: drawn without a fill (SocialBlocked.scrim) |
| matched | `chat.reactions.dimension.clusterInsetLeading`<br>`chat.reactions.dimension.clusterInsetBottom`<br>`chat.reactions.a11y.cluster` | 17 pt (SOURCED)<br>20 pt (SOURCED)<br>“Reactions: {emoji_names}” (SOURCED) | reaction cluster bottom-left, never a number | ReactionCluster overlay (see chat.reactions) |

## Reply to a photo

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `chat.thread.dimension.replyWidth`<br>`chat.thread.dimension.replyQuoteHeight`<br>`color.global.accent`<br>`chat.thread.radius.replyQuote` | 142 pt (SOURCED)<br>64 pt (SOURCED)<br>#CDFD07 (SOURCED)<br>18.2 pt (SOURCED) | lime quote part, top corners | UnevenRoundedRectangle(top radii) fill accent, frame(replyWidth × replyQuoteHeight) |
| matched | `color.global.onAccent`<br>`chat.thread.dimension.replyQuoteBar`<br>`chat.thread.dimension.replyQuoteBarInset` | #000000 (SOURCED)<br>1.5 pt (SOURCED)<br>16 pt (SOURCED) | quote bar spanning name → label | Rectangle height = label baseline − name cap top |
| matched | `chat.thread.fontSize.replyName`<br>`chat.thread.fontWeight.replyName`<br>`chat.thread.dimension.replyTextInset`<br>`chat.thread.dimension.replyNameCapTop` | 14.5 pt (SOURCED)<br>bold (SOURCED)<br>29 pt (SOURCED)<br>18.9 pt (SOURCED) | poster first name, cap top | alignment guide: baseline − cap height = capTop |
| matched | `chat.thread.reply.photoLabel`<br>`chat.thread.fontSize.replyLabel`<br>`chat.thread.fontWeight.replyLabel`<br>`chat.thread.dimension.replyLabelBaseline` | “pic” (SOURCED)<br>12.7 pt (SOURCED)<br>regular (SOURCED)<br>44.9 pt (SOURCED) | “pic” baseline | alignment guide on firstTextBaseline |
| matched | `chat.thread.dimension.replyThumb`<br>`chat.thread.radius.replyThumb`<br>`chat.thread.dimension.replyThumbInsetTop`<br>`chat.thread.dimension.replyThumbInsetTrailing` | 41.7 pt (SOURCED)<br>7 pt (SOURCED)<br>12.2 pt (SOURCED)<br>14.5 pt (SOURCED) | square thumbnail top-right (thumb_path) | overlay(alignment: .topTrailing), decoded at its pixel size |
| matched | `chat.thread.radius.bubble`<br>`chat.thread.a11y.replyQuote` | 16 pt (SOURCED)<br>“reply to {name}’s pic” (SOURCED) | text part overlapping the quote bottom, sender fill | TextBubble with negative top padding = bubble radius |
| approximated | `—` | — | photo reply to a photo (S-7) | quote part above the photo message, photo overlapping by radius.global.photo; quoted post loaded with the thread (unit-tested) |
| matched | `—` | — | quoted photo deleted → quote removed, message stays | post_deleted strips reply_to_post_id on messages and posts (unit-tested) |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| approximated | `groups.create.size.hud`<br>`groups.create.color.hud`<br>`groups.create.fontSize.hudLabel`<br>`groups.create.hud.loading` | 100 pt (SOURCED)<br>#0C0C0C (SOURCED)<br>15 pt (SOURCED)<br>“Loading” (SOURCED) | loading HUD (first page) | shared LoadingHUD, shown only after the cache was checked and nothing was cached (no HUD flash) |
| matched | `chat.thread.radius.loadingHud` | 10.5 pt (SOURCED) | HUD corners 10.5 (G-3) | the account group’s shared LoadingHUD uses the token |
| matched | `easing.global.native` | keyboard: system; alert: system; activityIndicator: system (ProgressView / CircularProgressIndicator); scrollIndicator: system; navigationPush: system (Navig… (PLATFORM) | older page indicator at the top | ProgressView row; the next older page is prefetched a fifth of a page before the top |
| matched | `chat.thread.empty.titleCreator`<br>`chat.thread.empty.titleMember`<br>`chat.thread.empty.detail`<br>`chat.thread.empty.invite`<br>`icon.global.link` | “you created group” (SOURCED)<br>“{name} created group” (SOURCED)<br>“and added {names}” (SOURCED)<br>“invite more friends” (SOURCED)<br>ios: link; android: Rounded.Link (PLATFORM) | empty: title, italic detail, white pill → groups.invite | shared EmptyStateView + LightPill action; composer stays |
| matched | `chat.thread.error.title`<br>`chat.thread.error.detail`<br>`chat.thread.error.retry` | “couldn’t load this chat” (SOURCED)<br>“check your connection and try again — your pics are safe” (SOURCED)<br>“try again” (SOURCED) | error, retry pill | EmptyStateView; retry reloads |
| matched | `chat.thread.offline.title`<br>`chat.thread.offline.detail` | “you’re offline” (SOURCED)<br>“your group’s pics will be right here when you’re back” (SOURCED) | offline with nothing cached | EmptyStateView without pill |
| matched | `—` | — | offline with cached messages | cached messages first (also online: cached first, refreshed in place) |
| matched | `chat.thread.layout.failedMessage`<br>`chat.thread.sendFailed`<br>`color.global.destructive`<br>`haptic.global.error` | indicator: outlined exclamation-mark circle beside the bubble on its trailing side, vertically centred on the bubble; indicatorIconIos: exclamationmark.circl… (SOURCED)<br>“couldn’t send — tap to try again” (SOURCED)<br>#FF4245 (PLATFORM)<br>ios: notification.error; android: REJECT (PLATFORM) | failed message: red outlined ! (22) 14 after the bubble in the trailing slot, red caption label 2 under it; tap ! / label / bubble retries (G-4) | the message stays (local copy kept through refreshes), error haptic, line announced (no toast); retry re-sends the same payload; a failed copy can be deleted locally (unit-tested) |
| matched | `—` | — | photo deleted while open | post_deleted removes the photo message and strips quotes |

## Motion and haptics

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `duration.global.navigationPush` | 100 ms (SOURCED) | push from groups.screen | native NavigationStack push |
| matched | `—` | — | message insert: no custom animation; position kept unless at the bottom | scrollPosition(id:anchor: .bottom); follows new messages only when the reader was at the bottom or sent it |
| matched | `haptic.global.send` | ios: notification.success; android: CONFIRM (PLATFORM) | text sent | SocialFeedback.sent → sensoryFeedback |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | send failed | SocialFeedback.failed |
| approximated | `haptic.global.reaction`<br>`haptic.global.longPressStart` | ios: system (context menu plays its own haptic; no custom generator); android: LONG_PRESS (PLATFORM)<br>ios: system (context menu plays its own haptic; no custom generator); android: LONG_PRESS (PLATFORM) | long press haptics | system long-press feedback of onLongPressGesture / contextMenu (no custom haptic) |
| matched | `haptic.global.warning` | ios: notification.warning; android: CONFIRM (PLATFORM) | delete confirmed | SocialFeedback.warning |

## Data, actions and accessibility

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `chat.thread.deleteMessage.title`<br>`chat.thread.deleteMessage.message`<br>`photo.viewer.delete.confirm`<br>`photo.viewer.delete.cancel` | “delete this message?” (SOURCED)<br>“it’s removed from the chat for everyone.” (SOURCED)<br>“delete” (SOURCED)<br>“cancel” (SOURCED) | delete own text / voice: native confirmation | confirmationDialog; optimistic removal, put back on failure (unit-tested; UI test) |
| matched | `chat.thread.menu.delete`<br>`photo.viewer.icon.delete`<br>`chat.thread.menu.report`<br>`icon.global.report` | “delete” (SOURCED)<br>ios: trash; android: Rounded.Delete (PLATFORM)<br>“report” (SOURCED)<br>ios: flag.fill; android: Rounded.Flag (PLATFORM) | native context menu | contextMenu + the same items as accessibility actions; report → account safety.report |
| matched | `chat.thread.a11y.message`<br>`chat.thread.a11y.messageMine`<br>`chat.thread.a11y.photo`<br>`chat.thread.a11y.photoMine`<br>`chat.thread.a11y.caption` | “{name}, {message}” (SOURCED)<br>“you, {message}” (SOURCED)<br>“{name}’s pic, {time}” (SOURCED)<br>“your pic, {time}” (SOURCED)<br>“caption: {caption}” (SOURCED) | VoiceOver labels | per row; avatars hidden; photos are buttons with react / reactions actions |
| matched | `—` | — | new incoming messages announced | AccessibilityNotification.Announcement on arrival |
| matched | `size.global.minTouchTarget.ios` | 44 pt (VERIFIED) | header hit targets 44 | shared header circles |
| matched | `—` | — | pages of 50, realtime inserts / deletions / reactions_changed, refetch on foreground and reconnect | ChatThreadModel (unit-tested with FakeSocialData) |

## Notes

- Optimistic sends: a text / voice message shows at once with a local id and is replaced by the server row once (realtime echo de-duplicated); on failure it keeps the failed-message layout until a tap re-sends it.
- Deep link `chat?message=` opens the thread on that message (scrollPosition anchor).

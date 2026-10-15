# Verification — `photo.viewer` (iOS)

Full photo viewer — `ios/App/Sources/Features/Social/UI/PhotoViewerView.swift`, `Core/PhotoViewerModel.swift` (Screens/PhotoViewerScreen.swift is the deep-link entry; the "i'm in this" control is the memory group's `SelfTagToggleControl`).

Checklist written from the spec (`design/surfaces/photo.viewer.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`), then `tools/sidebyside.py` makes `design/verification/photo.viewer.png` next to the reference image(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level).

Reference image(s): `references/auto/yope/frames/b-yopeapp-7591560669967682847-t57.07-photo-viewer.png`, `references/auto/yope/frames/b-yopeapp-7591560669967682847-t57.20-viewer-swipe-start.png`, `references/auto/yope/frames/a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png`, `references/auto/locket/store/locket-store-08.png`, `references/auto/locket/store/locket-store-04.png`

Snapshots (CI): `photo.viewer-ready.png`, `photo.viewer-reply-typing.png`, `photo.viewer-ready-own.png`, `photo.viewer-permission-denied.png`, `photo.viewer-loading.png`, `photo.viewer-gone.png`, `photo.viewer-error.png`, `photo.viewer-offline.png`

**Summary: 32 matched · 3 approximated · 1 not matched (BLOCKED or not buildable).**

## Header

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `photo.viewer.color.background` | #1C191D (SOURCED) | background | full-screen cover background |
| matched | `photo.viewer.dimension.headerCenterY` | 20 pt (SOURCED) | header row centre below the safe area | row height = 2 × headerCenterY |
| matched | `icon.global.close`<br>`photo.viewer.dimension.closeGlyph`<br>`photo.viewer.dimension.closeCenterX`<br>`photo.viewer.a11y.close` | ios: xmark; android: Rounded.Close (PLATFORM)<br>14.1 pt (SOURCED)<br>39 pt (SOURCED)<br>“close” (SOURCED) | bare ✕, centre 39 from the left | 44-pt hit area offset so its centre is at closeCenterX |
| matched | `photo.viewer.title.you`<br>`photo.viewer.title.sentTo`<br>`fontSize.global.headerTitle`<br>`fontWeight.global.headerTitle`<br>`color.global.textPrimary`<br>`color.global.textSecondary` | “you” (SOURCED)<br>“sent to” (SOURCED)<br>15 pt (SOURCED)<br>bold (SOURCED)<br>#FFFFFF (SOURCED)<br>#969696 (SOURCED) | line 1: names primary, “sent to” secondary, one line, tail truncation | AttributedString runs, TextRole.headerTitle |
| matched | `photo.viewer.layout.dateFormat`<br>`photo.viewer.dimension.titleToDate`<br>`fontSize.global.listSubtitle` | pattern: MMM d yyyy; example: Oct 30 2025 (SOURCED)<br>20.9 pt (SOURCED)<br>14 pt (SOURCED) | line 2 date, baseline titleToDate below line 1 | ZStack on firstTextBaseline + alignment guide |
| matched | `icon.global.more`<br>`photo.viewer.dimension.moreGlyphWidth`<br>`photo.viewer.dimension.moreCenterTrailing`<br>`photo.viewer.a11y.more` | ios: ellipsis; android: Rounded.MoreHoriz (PLATFORM)<br>25.3 pt (SOURCED)<br>36 pt (SOURCED)<br>“more” (SOURCED) | bare •••, centre 36 from the right | native Menu label, 44-pt hit area |
| matched | `—` | — | title read as one header element | accessibilityElement(.ignore) + label “… sent to …, date” + isHeader |

## Photo and overlays

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `photo.viewer.layout.photo`<br>`photo.viewer.dimension.photoTop`<br>`radius.global.photo` | width: full screen width; height: the photo's own aspect (3:4 observed); corners: radius.global.photo on all four corners; swipe: horizontal paging to the ad… (SOURCED)<br>107 pt (SOURCED)<br>15 pt (SOURCED) | full width, own aspect, top 107, corners | aspectRatio(media w/h, .fit), padding(.top) from the header |
| approximated | `—` | — | tall photos scaled down to fit (spec approximation) | .fit inside the page |
| matched | `photo.viewer.dimension.senderAvatar`<br>`photo.viewer.dimension.senderInsetLeading`<br>`photo.viewer.dimension.senderInsetTop`<br>`photo.viewer.dimension.senderNameGap` | 38.7 pt (SOURCED)<br>13.8 pt (SOURCED)<br>12.3 pt (SOURCED)<br>13 pt (SOURCED) | sender avatar + first name (“you”), top-aligned | Button → walls.member / walls.mine |
| matched | `photo.viewer.dimension.actionTrailing`<br>`photo.viewer.dimension.actionCenterTop`<br>`tagging.toggle`<br>`tagging.coach` | 23.8 pt (SOURCED)<br>33.1 pt (SOURCED)<br>“i'm in this” (SOURCED)<br>“tap if you're in this pic” (SOURCED) | “i'm in this” toggle at Yope’s chip slot with its coach | memory group’s SelfTagToggleControl drawn from PhotoViewerModel state (optimistic, rollback, toasts; unit-tested) |
| matched | `chat.thread.fontSize.caption`<br>`chat.thread.dimension.captionHeight`<br>`chat.thread.dimension.captionPaddingH`<br>`chat.thread.radius.caption`<br>`chat.thread.dimension.captionInsetBottom` | 21 pt (SOURCED)<br>45.8 pt (SOURCED)<br>20 pt (SOURCED)<br>13 pt (SOURCED)<br>7.8 pt (SOURCED) | caption box bottom-centre, long captions wrap | PhotoCaption(wraps: true) |
| matched | `color.global.scrim` | #00000080 (SOURCED) | caption fill (gap fill G2) | RoundedRectangle fill behind the caption |
| matched | `chat.reactions.dimension.clusterInsetLeading`<br>`chat.reactions.dimension.clusterInsetBottom` | 17 pt (SOURCED)<br>20 pt (SOURCED) | reaction cluster bottom-left → Activity sheet | ReactionCluster button |
| matched | `—` | — | Live Photo plays while pressed; dual capture as daily.dualimage; video with the platform player | PHLivePhotoView (still + motion downloaded), capture group’s DualImageView, VideoPlayer |
| approximated | `photo.viewer.layout.voiceNote` | BLOCKED | voice note position | BLOCKED: spec approximation — under the photo, left edge at size.global.screenMargin, chat.voice bubble |
| approximated | `duration.global.photoSwipe`<br>`easing.global.photoSwipe` | 167 ms (SOURCED)<br>ios: system paging scroll physics; android: Compose HorizontalPager default fling (PLATFORM) | swipe to the adjacent photo | TabView(.page): system paging animation (the token duration is not applied to the platform pager) |
| matched | `photo.viewer.dimension.pageGap` | 0 pt (SOURCED) | page gap 0: pages touch (G-14) | TabView(.page) pages are adjacent |

## Reply row and menu

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `chat.composer.dimension.fieldHeight`<br>`color.global.control`<br>`chat.composer.color.fieldRimTop`<br>`chat.composer.color.fieldRimBottom`<br>`radius.global.capsule`<br>`chat.composer.dimension.fieldPaddingLeading`<br>`chat.composer.dimension.insetLeading`<br>`photo.viewer.reply.placeholder` | 39.5 pt (SOURCED)<br>#2E2E2E (SOURCED)<br>#4B4B4B (SOURCED)<br>#474747 (SOURCED)<br>shape: capsule; radius: height / 2 (SOURCED)<br>17.8 pt (SOURCED)<br>22.8 pt (SOURCED)<br>“message to {group_name}...” (SOURCED) | reply field | ViewerReplyRow: same field as the composer; placeholder names the group |
| matched | `chat.reactions.layout.quickReactions`<br>`chat.reactions.icon.add`<br>`chat.reactions.a11y.quick`<br>`chat.reactions.a11y.add` | emoji: 🔥 💖; then: add-reaction button (chat.reactions.icon.add); place: inside the right end of the reply field, after the text (SOURCED)<br>ios: face.smiling; android: Rounded.AddReaction (PLATFORM)<br>“React with {emoji_name}” (SOURCED)<br>“Add reaction” (SOURCED) | 🔥 💖 + add glyph inside the field’s right end | tap reacts at once (optimistic) / opens the picker |
| matched | `chat.composer.dimension.gapFieldButton`<br>`chat.composer.dimension.sideButton`<br>`color.global.controlRaised`<br>`icon.global.camera`<br>`chat.composer.dimension.insetTrailing`<br>`chat.composer.a11y.camera` | 7.1 pt (SOURCED)<br>39.5 pt (SOURCED)<br>#434343 (SOURCED)<br>ios: camera.fill; android: Rounded.PhotoCamera (PLATFORM)<br>23.4 pt (SOURCED)<br>“send a pic” (SOURCED) | camera circle → reply with a photo | cover closes, then AppModal.camera opens; reply target handed through PhotoReplyHandoff (capture reads it) |
| matched | `chat.composer.layout.typingState` | rule: while the field holds text, the mic circle is replaced in place by a send circle; when the field is empty again the mic circle returns; sendCircleSize:… (SOURCED) | with text, the camera circle’s slot shows the lime send circle | SendCircle → send_message(text, p_reply_to_post_id) (unit-tested; UI test) |
| matched | `chat.composer.dimension.bottomInset` | 8 pt (SOURCED) | row 8 above the bottom safe area | padding(.bottom) |
| matched | `photo.viewer.layout.menu`<br>`photo.viewer.menu.save`<br>`icon.global.download`<br>`photo.viewer.menu.delete`<br>`photo.viewer.icon.delete`<br>`photo.viewer.menu.report`<br>`icon.global.report`<br>`photo.viewer.menu.block` | ios: Menu (pull-down) from the ••• glyph, items with trailing SF Symbols, destructive items in the system red; android: DropdownMenu anchored to the ••• glyp… (PLATFORM)<br>“save” (SOURCED)<br>ios: arrow.down.to.line; android: Rounded.Download (PLATFORM)<br>“delete” (SOURCED)<br>ios: trash; android: Rounded.Delete (PLATFORM)<br>“report” (SOURCED)<br>ios: flag.fill; android: Rounded.Flag (PLATFORM)<br>“block {name}” (SOURCED) | native pull-down menu in order: save; delete (mine) or report + block (others) | Menu with Button(role: .destructive); also accessibility actions on the photo |
| matched | `photo.viewer.layout.deleteConfirm`<br>`photo.viewer.delete.title`<br>`photo.viewer.delete.message`<br>`photo.viewer.delete.confirm`<br>`photo.viewer.delete.cancel` | ios: confirmationDialog (action sheet): title, message, destructive button, Cancel at the bottom; android: M3 AlertDialog: title, text, dismiss + confirm but… (PLATFORM)<br>“delete this pic?” (SOURCED)<br>“it’ll be gone everywhere — from every group you sent it to, and from chats, walls, recaps & albums.” (SOURCED)<br>“delete” (SOURCED)<br>“cancel” (SOURCED) | delete-everywhere confirmation | confirmationDialog → delete_media; optimistic: moves to the next photo or closes, put back on failure (unit-tested) |
| matched | `photo.viewer.toast.saved`<br>`photo.viewer.toast.deleted` | “pic saved” (SOURCED)<br>“pic deleted” (SOURCED) | toasts after save / delete | shared ToastCenter (announced; drawn in DEBUG while the dwell is BLOCKED) |
| not matched | `camera.sendto.duration.toastVisible` | 2000 ms (SOURCED) | toast dwell | BLOCKED (capture group): release announces only |
| matched | `—` | — | report → safety.report (post); block → safety.block | account ReportSheet presented from the cover; shared blockConfirmation; the author’s photos leave the viewer |

## States and haptics

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `—` | — | loading: thumbnail first, then display_path | photos already on the device show at once (session memo / offline feed); grid thumbnail under the display image; neighbours prefetched at screen size |
| matched | `photo.viewer.error.load` | “couldn’t load this pic” (SOURCED) | image load error line on the frame | SocialPhoto failure view, text role emptyDetail |
| matched | `photo.viewer.gone.title`<br>`photo.viewer.gone.detail` | “this pic isn’t here anymore” (SOURCED)<br>“the person who shared it took it down” (SOURCED) | gone (post_not_found / post_deleted) | page shows the empty-state layout; ✕ stays (unit-tested) |
| matched | `photo.viewer.error.save`<br>`photo.viewer.error.delete`<br>`chat.reactions.error`<br>`chat.thread.sendFailed` | “couldn’t save this pic” (SOURCED)<br>“couldn’t delete this pic — try again” (SOURCED)<br>“Couldn’t send your reaction” (SOURCED)<br>“couldn’t send — tap to try again” (SOURCED) | offline: actions fail with their strings | toasts + error haptic |
| matched | `photo.viewer.permission.title`<br>`photo.viewer.permission.detail`<br>`photo.viewer.permission.button` | “can’t save your pics?” (SOURCED)<br>“enable photos” (SOURCED)<br>“enable” (SOURCED) | save permission denied: inline card above the reply row | shared PermissionCard; “enable” opens Settings |
| matched | `tagging.error`<br>`tagging.notFound`<br>`tagging.offline` | “couldn't save that — try again in a moment” (SOURCED)<br>“this pic isn't here anymore” (SOURCED)<br>“you're offline — try again when you're connected” (SOURCED) | tag errors | toggle reverts + toast |
| matched | `haptic.global.success`<br>`haptic.global.warning`<br>`haptic.global.error`<br>`haptic.global.send` | ios: notification.success; android: CONFIRM (PLATFORM)<br>ios: notification.warning; android: CONFIRM (PLATFORM)<br>ios: notification.error; android: REJECT (PLATFORM)<br>ios: notification.success; android: CONFIRM (PLATFORM) | saved / delete confirmed / failed / reply sent | model feedback → sensoryFeedback |
| matched | `chat.reactions.layout.reduceMotion` | rain: not played (automatic, repeating, peripheral motion is dropped); cluster: the new sticker appears in place; haptics: unchanged (PLATFORM) | emoji rain behind the photo | EmojiRain layer between background and content (see chat.reactions) |

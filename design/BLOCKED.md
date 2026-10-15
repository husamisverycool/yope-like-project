# BLOCKED values

Generated. These may not ship; release builds fail to compile if code uses any of them.

| item | surface | why |
|---|---|---|
| token `auth.phone.layout.countryCode` | auth.phone | Smallest owner capture: one ~40 s English screen recording of a fresh Yope install up to the first camera screen, tapping 'try other options'. Until then the field is pre-filled with '+' and the device region's calling code (Locale / libphonenumber) and the person edits it as text; no selector is drawn. |
| token `auth.phone.layout.inlineError` | auth.phone | Smallest owner capture: the same ~40 s English recording of a fresh Yope install via 'try other options', entering one wrong code. Copy exists (auth.*.error.*); only its presentation is blocked. Full-screen states (offline, not configured, under age) use the sourced empty-state layout instead. |
| token `groups.list.color.headerCircleOverPhoto` | groups.list | Smallest capture: one lossless screenshot of the 2026 Yope home with the cover photo. Same open item as color.global.scrim. |
| token `paywall.layout.iconTileArt` | paywall | Smallest owner input: the app icon (1024 × 1024). Until then the tile is not drawn; the title moves up by the tile height + gap. |
| token `safety.report.layout.reasons` | safety.report | Smallest owner input: the list of report categories the moderation process uses (docs/API.md §12 item 19). Without it, reports carry the optional free text; an empty text sends the target kind as p_reason. |
| token `safety.block.duration.toast` | safety.block | Smallest capture: one 10-s English screen recording of Yope sending a photo until the 'posted in the wall' toast is gone. Until then confirmations are not shown as toasts in release builds; the action itself completes normally. |
| token `camera.capture.size.recordingOutline` | camera.capture | Stroke width not observed. Smallest capture: a 10-second iPhone screen recording of Locket hold-to-record (locket.md §5). |
| token `camera.sendto.color.messageField` | camera.sendto | Blurred translucent material; one image cannot solve its alpha. Smallest capture: one screenshot of Yope's send-to card over a flat white and a flat black photo. |
| token `camera.sendto.duration.toastVisible` | camera.sendto | Smallest capture: a 5-second screen recording of Yope right after tapping send (toast in → out). |
| token `camera.sendto.size.captionMaxLength` | camera.sendto | Not observed. docs/API.md §12.18: the server bound (1000) is integrity only; UI limits come from the design. Smallest capture: type a long caption in Yope's send-to. |
| token `widget.home.small.color.emptyLabel` | widget.home.small | Smallest capture: one screenshot of a just-added, empty Locket Android widget. |
| token `widget.lock.rect.layout.content` | widget.lock.rect | Composed parts (circular = sender avatar; rectangular = avatar + caption; inline = caption) are specified in design/surfaces/widget.lock.*.md. Smallest capture: one screenshot of the iOS Lock Screen 'Add Widgets' sheet after searching 'Locket' (locket.md §3); otherwise an owner decision. |
| token `daily.capture.fontWeight.countdown` | daily.capture | Not measurable as a weight. Closing step (no owner capture): render the platform font's digits at 23 pt in each weight and pick the one whose stem ÷ digit height is 0.19–0.20. |
| token `daily.capture.color.overlayControl` | daily.capture | Translucent; one image cannot solve the alpha. Smallest capture: one lossless screenshot of a BeReal post preview over a flat light photo. |
| token `collage.share.color.pill` | collage.share | Material, not a solid color. Smallest capture: one lossless screenshot of Yope's 'share' pill over a flat white and a flat black area. |
| token `color.global.separator` | global | Smallest capture: one screenshot of a Yope list with row dividers (e.g. the 2026 group ••• menu or members list, yope-a §2.13). System surfaces use the platform separator (color.global.system.ios.separator / color.global.system.outline). |
| token `color.global.scrim` | global | System sheets supply their own dimming (PLATFORM). Smallest capture: one lossless screenshot of a Yope sheet over a known background. |
| token `spring.global.sheetPresent` | global | Not fitted here: a fit from 5 samples would be a decision, not a measurement. Either a 60 fps screen recording of a Yope sheet opening (smallest capture) or the native sheet (easing.global.native) — MERGE_DECISIONS F-15. |
| token `duration.onthisday.memoryChange` | onthisday | Owner capture: one 15-20 s screen recording tapping through three years of one day on Timehop v5. Until then the memory changes without animation. |
| token `duration.year.story.card` | year.story | Measured segments are chapters holding several beats; the time per single fact was not measurable (research §1.7). Owner capture: the 30 s 'Your Stories' replay recording (research capture 1) with three single-beat cards. Until then the story does not advance on its own and the pause control is hidden (MERGE memory M-16). |
| token `easing.year.story.reveal` | year.story | Owner capture: one 60 fps recording of any Wrapped card whose subline appears. Until then the reveal plays as the global Reduce Motion substitute (cross-fade, same durations). |
| token `layout.year.story.summary.dots` | year.story | Owner capture: one full-resolution screenshot of the Wrapped summary screen. Until then the carousel shows no dots. |
| token `layout.birthday.contribute.lineMax` | birthday.contribute | Until found the field accepts the API bound (280, invalid_line, docs/API.md contribute_tribute) with no visible counter. Owner capture: research capture 4 (a real Tribute or VidDay invitation opened to the contribution screen). |
| token `duration.birthday.tribute.photoHold` | birthday.tribute | Owner capture: one finished Tribute or VidDay video that contains photos (its share link, or a 20 s screen recording playing three photo contributions) - research capture 5. |
| token `layout.birthday.tribute.endCard` | birthday.tribute | Owner capture: one finished birthday Tribute or VidDay link (research capture 5), last 15 s. |
| token `layout.birthday.tribute.caption` | birthday.tribute | Owner capture: one finished Tribute in which the creator added 'text on a clip', or a VidDay with contributor names on photos - a 10 s screen recording or the share link settles text colour, sizes, position, gap and any band behind the text. |
| token `chat.thread.dimension.bubbleMaxWidth` | chat.thread | Smallest owner capture: one screenshot of a Yope group chat with a two-line text message (yope-b §14 capture 1: 30-s recording that includes a two-line text). Widest observed single-line bubble: 210.7 pt ('strictly vibes only tonight'). |
| token `chat.thread.count.emojiOnlyMax` | chat.thread | Smallest owner capture: one screenshot of a Yope group chat with a 1-emoji and a 4-emoji message. |
| token `chat.thread.radius.loadingHud` | chat.thread | Smallest owner capture: one lossless screenshot of Yope's 'Loading' HUD. |
| token `chat.thread.layout.failedMessage` | chat.thread | Smallest owner capture: one screenshot of a Yope chat message that failed to send (airplane mode). |
| token `chat.composer.dimension.bottomInset` | chat.composer | Smallest owner capture: one device screenshot of a Yope group chat with the keyboard down and one with it up (yope-b §14 capture 1). |
| token `chat.composer.layout.typingState` | chat.composer | Smallest owner capture: one screenshot of a Yope group chat with text typed in the field. |
| token `chat.voice.color.bubbleTheirs` | chat.voice | Smallest owner capture: one screenshot of a voice message from another member in a Yope group chat. |
| token `chat.voice.color.waveformPlayed` | chat.voice | Smallest owner capture: 15-s screen recording of playing a voice message in a Yope group chat (yope-b §3). |
| token `chat.voice.layout.widthRule` | chat.voice | Smallest owner capture: one screenshot of two voice messages of different lengths in a Yope chat. |
| token `chat.voice.icon.pause` | chat.voice | Smallest owner capture: 15-s screen recording of playing a voice message in a Yope group chat. |
| token `chat.voice.layout.recording` | chat.voice | Smallest owner capture: 15-s screen recording of recording, sending and playing a voice message in a Yope group chat (yope-b §3). |
| token `chat.reactions.layout.clusterOrder` | chat.reactions | Smallest owner capture: one screenshot of a Locket photo after three people reacted in a known order. |
| token `chat.reactions.count.clusterMaxVisible` | chat.reactions | Smallest owner capture: one screenshot of a Locket photo with six or more different reactions. |
| token `chat.reactions.easing.rain` | chat.reactions | Smallest owner capture: one 60-fps screen recording of Locket's emoji rain (current build). |
| token `chat.reactions.duration.flyToCluster` | chat.reactions | Smallest owner capture: one screen recording (not filmed) of reacting to a Locket Rollcall photo. |
| token `chat.reactions.layout.activitySheet` | chat.reactions | Smallest owner capture: one screenshot of Locket's reaction list for one of your photos. |
| token `chat.reactions.layout.unreact` | chat.reactions | Smallest owner capture: one screen recording of removing a reaction in Locket (or confirmation that Locket has none). |
| token `photo.viewer.dimension.pageGap` | photo.viewer | Smallest owner capture: one 10-s screen recording: tap a photo in a Yope group chat, swipe to the next, open •••, close (yope-b §14 capture 2). |
| token `photo.viewer.layout.voiceNote` | photo.viewer | Smallest owner capture: one Yope screen recording opening a photo that has a voice memo. |
| token `walls.mine.layout.mosaic` | walls.mine | Smallest owner capture: one screenshot of a Yope 2026 profile 'pics' grid scrolled to show three rows. |
| token `walls.mine.layout.freeformWall` | walls.mine | Smallest owner capture: 20-s recording: own wall, a friend's wall, the 'me & friends' row, tap shuffle once, tap edit (yope-b §14 capture 3). Until closed, walls use the grid above (MERGE_DECISIONS Social S-11). |
| token `walls.browse.layout.rowOrder` | walls.browse | Smallest owner capture: one screenshot of Yope's 'me & friends' row before and after one friend posts. |
| token `walls.browse.layout.selection` | walls.browse | Smallest owner capture: one screenshot of Yope's 'me & friends' row after tapping a person. |
| token `week.recap.layout.shortRowSplit` | week.recap | Smallest owner capture: one screen recording of a Yope weekly recap card for a week with only 2–5 photos (the capture named in design/collage-options/README.md). |
| token `week.recap.dimension.shortRowHeight` | week.recap | Smallest owner capture: same capture as week.recap.layout.shortRowSplit. |
| token `week.recap.layout.scrim` | week.recap | Smallest owner capture: one lossless export of a Yope recap card. |
| token `week.recap.layout.page2` | week.recap | Smallest owner capture: 20-s recording: open a Yope weekly recap, swipe the recap pages, toggle recap/pics, tap edit/remix, save (yope-b §14 capture 4). Where the recap text (weekly_recaps.text) is displayed depends on this capture. |
| token `week.edit.layout.reorder` | week.edit | Smallest owner capture: 20-s recording: open a Yope weekly recap, tap edit/remix, save (yope-b §14 capture 4). |
| token `week.edit.layout.recapText` | week.edit | Smallest owner capture: same capture as week.edit.layout.reorder. |
| token `week.history.color.emptyTile` | week.history | Smallest owner capture: one screenshot of Retro's profile in dark mode. Retro's dark-mode colours were not measured (design/research/retro-timehop.md §week.history 'Not found: Dark-mode colours'); the app is dark only (layout.global.appearance, F-1). |
| token `week.history.color.emptyTileText` | week.history | Smallest owner capture: one screenshot of Retro's profile in dark mode. Retro's dark-mode colours were not measured (design/research/retro-timehop.md §week.history 'Not found: Dark-mode colours'); the app is dark only (layout.global.appearance, F-1). |
| token `week.history.layout.weekMenu` | week.history | Smallest owner capture: one screenshot of Retro's week '•••' menu opened. |
| token `albums.list.layout.yopeAlbums` | albums.list | Smallest owner capture: two screenshots: Yope's album list and one open album (yope-b §14 capture 5). |
| copy `auth.agegate.underAge.title` | auth.agegate | uses {app_name}; owner has not named the app |
| copy `onboarding.widget.step.ios.4` | onboarding.widget | uses {app_name}; owner has not named the app |
| copy `onboarding.widget.step.android.3` | onboarding.widget | uses {app_name}; owner has not named the app |
| copy `groups.invite.link.message` | groups.invite | uses {app_name}; owner has not named the app |
| copy `settings.root.premium.title` | settings.root | uses {app_name}; owner has not named the app |
| copy `settings.root.premium.subtitle` | settings.root | uses {app_name}; owner has not named the app |
| copy `settings.notifications.off.footer` | settings.notifications | uses {app_name}; owner has not named the app |
| copy `safety.report.explanation` | safety.report | uses {app_name}; owner has not named the app |
| copy `system.permissions.rationale.camera.message` | system.permissions | uses {app_name}; owner has not named the app |
| copy `system.permissions.rationale.microphone.message` | system.permissions | uses {app_name}; owner has not named the app |
| copy `system.permissions.rationale.notifications.message` | system.permissions | uses {app_name}; owner has not named the app |
| copy `system.permissions.rationale.contacts.message` | system.permissions | uses {app_name}; owner has not named the app |
| copy `paywall.title` | paywall | uses {app_name}; owner has not named the app |
| copy `paywall.subtitle` | paywall | uses {app_name}; owner has not named the app |
| copy `paywall.perk.history.emoji` | paywall | BLOCKED: no sourced emoji for this perk (Locket's 'Unlimited friends' icon is a heart on fire, close to streak imagery). Smallest owner input: pick one emoji, or drop the icon for this perk. The perk itself is hidden while history is unlimited. |
| copy `paywall.cta` | paywall | uses {app_name}; owner has not named the app |
| copy `paywall.plans.title` | paywall | uses {app_name}; owner has not named the app |
| copy `paywall.legal.optional` | paywall | uses {app_name}; owner has not named the app |
| copy `paywall.welcome.body` | paywall | uses {app_name}; owner has not named the app |
| copy `widget.home.small.gallery.name` | widget.home.small | uses {app_name}; owner has not named the app |
| copy `widget.lock.rect.gallery.name` | widget.lock.rect | uses {app_name}; owner has not named the app |
| copy `widget.android.label` | widget.android | uses {app_name}; owner has not named the app |
| copy `invite.web.documentTitle` | invite.web | uses {app_name}; owner has not named the app |
| copy `birthday.tribute.endCard` | birthday.tribute | The end card itself was not observed in either reference (layout.birthday.tribute.endCard BLOCKED); this text stays debug-only until research capture 5 (one finished Tribute / VidDay) shows an end card. Worker key. |

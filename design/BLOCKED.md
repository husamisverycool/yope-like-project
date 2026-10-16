# BLOCKED values

Generated. These may not ship; release builds fail to compile if code uses any of them.

| item | surface | why |
|---|---|---|
| token `chat.reactions.layout.listOrder` | chat.reactions | Development approximation (debug builds only): newest first by reactions.created_at. Smallest capture: one screenshot of WhatsApp's (or Retro's) reaction list on a message with reactions from three people at different times. |
| token `photo.viewer.layout.backZone` | photo.viewer | Development approximation (debug builds only): the leading third of the photo. Smallest capture: a 10-s screen recording of Retro's viewer tapping at several x positions (or its NUX overlay). |
| token `walls.browse.layout.rowOrder` | walls.browse | Development approximation (debug builds only): newest wall item first, then by name. Smallest capture: one raw screenshot of Retro's current Friends tab with 7 or more friends. |
| token `week.recap.layout.gridFill` | week.recap | Development approximation (debug builds only): cells fill row by row in item order; empty cells show the card fill; items beyond 24 are not drawn on the card (they stay in the recap and the viewer). Smallest capture: one Retro recap preview (Week style) for a week with 5 photos. |
| token `week.edit.layout.selectionMark` | week.edit | Development approximation (debug builds only): size.global.checkCircle at the cell's top-right corner, 6 pt in (APK uniform padding 6 ×29); icon.global.check in color.global.textOnMedia on checked, icon.global.uncheck in color.global.textOnMedia otherwise. Smallest capture: one raw screenshot of Retro's 'Add to Your Week' with 2 photos selected. |
| token `albums.view.shadow.cover` | albums.view | Until captured the cover is drawn flat (release builds cannot use a BLOCKED token). Smallest capture: one raw screenshot of a Retro album sheet on a white background. |
| copy `onboarding.widget.step.ios.4` | onboarding.widget | uses {app_name}; owner has not named the app |
| copy `onboarding.widget.step.android.3` | onboarding.widget | uses {app_name}; owner has not named the app |
| copy `groups.invite.link.message` | groups.invite | uses {app_name}; owner has not named the app |
| copy `settings.root.premium.title` | settings.root | uses {app_name}; owner has not named the app |
| copy `paywall.title` | paywall | uses {app_name}; owner has not named the app |
| copy `paywall.legal.optional` | paywall | uses {app_name}; owner has not named the app |
| copy `invite.web.documentTitle` | invite.web | uses {app_name}; owner has not named the app |
| copy `year.story.card.app` | year.story | App line under the group name on the recap card and the full-bleed footer (Retro prints its domain). BLOCKED until the owner names the app (and its domain); until then the line is left out. |

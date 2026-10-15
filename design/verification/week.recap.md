# Verification — `week.recap` (iOS)

Weekly recap (card, week pics, “recap | pics” capsule) — `ios/App/Sources/Features/Social/UI/WeekViews.swift` (`WeekRecapView`, `WeekPicsGrid`, `RecapSegmentedControl`), `Core/WeekModels.swift` (`WeekRecapModel`); Screens/RecapScreen.swift is the route entry.

Checklist written from the spec (`design/surfaces/week.recap.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`), then `tools/sidebyside.py` makes `design/verification/week.recap.png` next to the reference image(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level).

Reference image(s): `references/owner/yope-week-recap.jpg`

Snapshots (CI): `week.recap-ready.png`, `week.recap-pending.png`, `week.recap-empty.png`, `week.recap-loading.png`, `week.recap-error.png`, `week.recap-offline.png`

**Summary: 15 matched · 2 approximated · 2 not matched (BLOCKED or not buildable).**

## Header and card

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `color.global.background` | #171717 (SOURCED) | background | ZStack background |
| matched | `size.global.headerButton`<br>`color.global.controlOnDeep`<br>`size.global.headerInset`<br>`icon.global.back`<br>`icon.global.edit`<br>`week.recap.a11y.edit` | 44 pt (SOURCED)<br>#101010 (SOURCED)<br>11.5 pt (SOURCED)<br>ios: chevron.left; android: AutoMirrored.Rounded.KeyboardArrowLeft (PLATFORM)<br>ios: pencil; android: Rounded.Edit (PLATFORM)<br>“edit” (SOURCED) | ‹ circle; pencil circle (ready recaps only) | SocialCenteredHeader + HeaderCircleButton(.onDeep) |
| matched | `week.recap.fontSize.title`<br>`week.recap.fontWeight.title`<br>`week.recap.layout.weekFormat` | 17 pt (CAPTURED)<br>semibold (CAPTURED)<br>title: d MMM-d MMM, lowercase, bare hyphen; label: the title in uppercase; example: 18 aug-24 aug / 18 AUG-24 AUG; week: Monday–Sunday in the group's time zone (CAPTURED) | title “18 aug-24 aug” | SocialFormat.weekTitle (token pattern halves, lowercase, group time zone) |
| matched | `week.recap.dimension.cardWidth`<br>`week.recap.radius.card`<br>`week.recap.count.gridColumns`<br>`week.recap.aspectRatio.gridTile`<br>`week.recap.dimension.gridGap` | 334 pt (CAPTURED)<br>12 pt (CAPTURED)<br>3 (CAPTURED)<br>width: 111; height: 167 (CAPTURED)<br>0 pt (CAPTURED) | card 334 wide, corners 12, full rows of 3 tiles 111:167, gap 0, aspect fill | VStack of HStacks of SocialPhoto tiles |
| not matched | `week.recap.layout.shortRowSplit`<br>`week.recap.dimension.shortRowHeight` | BLOCKED<br>BLOCKED | row of the leftover 1–2 photos | BLOCKED: not drawn; those photos stay in the pics grid |
| matched | `week.recap.fontSize.label`<br>`week.recap.fontWeight.label`<br>`week.recap.dimension.labelInsetLeading`<br>`week.recap.dimension.labelBaselineBottom` | 20 pt (CAPTURED)<br>heavy (CAPTURED)<br>25.3 pt (CAPTURED)<br>27.5 pt (CAPTURED) | week label uppercase, inset, baseline above the card bottom, one line (shrinks) | overlay + alignment guide on firstTextBaseline; minimumScaleFactor |
| not matched | `week.recap.layout.scrim` | BLOCKED | label scrim | BLOCKED: no scrim |
| approximated | `week.recap.layout.page2`<br>`week.recap.dimension.cardToDots`<br>`week.recap.dimension.pageDot`<br>`week.recap.dimension.dotsToPics` | BLOCKED<br>20.9 pt (CAPTURED)<br>8 pt (CAPTURED)<br>40 pt (CAPTURED) | page 2 and page dots | page 2 BLOCKED: one page, dots hidden; their space is reserved so a second page adds no jump |

## Pics grid and capsule

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `week.recap.count.picsColumns`<br>`week.recap.dimension.picsGap`<br>`week.recap.aspectRatio.picsTile`<br>`photo.viewer.a11y.photo` | 3 (CAPTURED)<br>1 pt (CAPTURED)<br>width: 131; height: 175 (CAPTURED)<br>“{name}’s pic, {date}” (SOURCED) | every visible post of the week, chronological, full width | LazyVGrid; thumbnails decoded at the tile’s pixel size; tap → viewer (the week’s posts) |
| matched | `week.recap.dimension.segmentedWidth`<br>`week.recap.dimension.segmentedHeight`<br>`color.global.control`<br>`week.recap.dimension.segmentedPillWidth`<br>`week.recap.dimension.segmentedPillHeight`<br>`week.recap.dimension.segmentedInset`<br>`color.global.surfaceLight`<br>`week.recap.segment.recap`<br>`week.recap.segment.pics`<br>`week.recap.fontSize.segmented`<br>`week.recap.fontWeight.segmented`<br>`week.recap.dimension.segmentedBottom` | 160 pt (CAPTURED)<br>47.5 pt (CAPTURED)<br>#2E2E2E (SOURCED)<br>83 pt (CAPTURED)<br>40.4 pt (CAPTURED)<br>3.5 pt (CAPTURED)<br>#FFFFFF (SOURCED)<br>“recap” (CAPTURED)<br>“pics” (CAPTURED)<br>17 pt (CAPTURED)<br>semibold (CAPTURED)<br>42.6 pt (CAPTURED) | floating “recap | pics” capsule | RecapSegmentedControl overlay |
| matched | `spring.global.platformDefault.ios` | response: 0.55; dampingFraction: 1 (PLATFORM) | pill moves with the platform default spring; Reduce Motion: jumps | animation(value: selection) |
| approximated | `—` | — | tap scrolls to the part; scrolling updates the selection | ScrollViewReader + a preference on the grid’s top (spec approximation); system scroll animation |
| matched | `haptic.global.select` | ios: selection; android: SEGMENT_TICK (PLATFORM) | segment tapped | model feedback (not when scrolling changes it) |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `groups.create.size.hud`<br>`groups.create.color.hud`<br>`groups.create.fontSize.hudLabel`<br>`chat.thread.radius.loadingHud`<br>`groups.create.hud.loading` | 100 pt (SOURCED)<br>#0C0C0C (SOURCED)<br>15 pt (SOURCED)<br>10.5 pt (SOURCED)<br>“Loading” (SOURCED) | loading HUD | shown only when nothing is on the device: a recap opened earlier this session shows at once with its photos (session memo / offline feed) and refreshes in place (unit-tested) |
| matched | `week.recap.pending` | “your recap is on its way” (SOURCED) | pending | centred bold line, no pill |
| matched | `week.recap.empty.title`<br>`week.recap.empty.detail`<br>`week.recap.empty.action` | “your first recap shows up on sunday” (SOURCED)<br>“it’s made from the pics your group shares this week” (SOURCED)<br>“share a pic” (SOURCED) | empty → camera | EmptyStateView + action |
| matched | `week.recap.error.title`<br>`chat.thread.error.detail`<br>`chat.thread.error.retry` | “couldn’t load this recap” (SOURCED)<br>“check your connection and try again — your pics are safe” (SOURCED)<br>“try again” (SOURCED) | error | EmptyStateView + retry |
| matched | `chat.thread.offline.title`<br>`chat.thread.offline.detail` | “you’re offline” (SOURCED)<br>“your group’s pics will be right here when you’re back” (SOURCED) | offline | the cached copy stays; else the offline layout |
| matched | `—` | — | post_deleted drops the item from card and grid | unit-tested |

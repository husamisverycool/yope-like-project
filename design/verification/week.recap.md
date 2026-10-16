# Verification — `week.recap` (iOS)

Recaps: the list sheet (Retro's "Create Recap" cards as week cards) and the recap preview (capture's shared chrome + memory's recap card) — `ios/App/Sources/Features/Social/UI/WeekRecapViews.swift` (`WeekRecapListScreen`, `WeekCard`, `PendingWeekCard`, `WeekRecapPreviewScreen`, `RecapNote`), `Core/WeekModels.swift` (`WeekRecapListModel`, `WeekRecapModel`); capture's `RecapPreviewScreen` / `RecapPreviewClose` / `RecapPill` (`Features/Capture/Collage/RecapPreviewScreen.swift`), memory's `RecapCard` / `RecapFooter` (`Features/Memory/Shared/RecapCard.swift`) and the C-34 `BlurredBackdrop` used as is; `Screens/RecapScreen.swift` is the route entry.

Pass 4 (Retro redesign). Checklist written from the spec (`design/surfaces/week.recap.md`, MERGE "Redesign — Social (RS-*)", lead L-3 / L-4) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>-<light|dark>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/week.recap.png` next to the Retro reference(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level). Components are the Pass 3 library (`ios/App/Sources/Components`, C-01…C-35).

Retro reference(s): `references/auto/retro/store/retro-store-04.png (ST-04, preview chrome)`, `references/auto/retro/press/tc-2023-12-recaps.png (list cards, card and full-bleed styles)`, `references/auto/retro/press/tc-2023-12-retro-header.png (card footer)`

Snapshots (CI): `week.recap-list-light.png`, `week.recap-list-dark.png`, `week.recap-list-loading-light.png`, `week.recap-list-empty-light.png`, `week.recap-list-error-light.png`, `week.recap-list-offline-light.png`, `week.recap-preview-light.png`, `week.recap-preview-dark.png`, `week.recap-preview-cover-light.png`, `week.recap-preview-note-light.png`, `week.recap-preview-loading-light.png`, `week.recap-preview-pending-light.png`, `week.recap-preview-error-light.png`

**Summary: 22 matched · 2 approximated · 1 not matched (BLOCKED or not buildable).**

## Elements

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `size.global.circleButton`<br>`color.global.control`<br>`week.recap.a11y.close` | 36 pt (SOURCED)<br>light #F1F1F1 / dark #262626 (SOURCED)<br>“Close” (SOURCED) | list close | `LeadingCloseSheetHeader`: C-11 `CircleButton(.page)` (`circleButton`, `control`) at the leading margin → dismiss. A local header: the shared `SheetHeader` puts its close circle at the trailing edge (component gap C-29) |
| matched | `week.recap.list.title` | “Recaps” (SOURCED) | list title | title centred, `sheetTitle`, header trait |
| matched | `week.recap.aspectRatio.weekCard`<br>`week.recap.radius.card`<br>`week.recap.dimension.weekCardTextInset`<br>`week.recap.dimension.weekCardTextTop`<br>`week.recap.dimension.weekCardLinePitch`<br>`icon.global.chevron`<br>`photo.viewer.header.week`<br>`week.recap.a11y.card` | width: 336; height: 251 (SOURCED)<br>14 pt (SOURCED)<br>21.2 pt (SOURCED)<br>21.8 pt (SOURCED)<br>20.6 pt (SOURCED)<br>ios: chevron.right; android: AutoMirrored.Rounded.KeyboardArrowRight (PLATFORM)<br>“Week {week_number}” (SOURCED)<br>“Recap of Week {week_number}, {date_range}” (SOURCED) | week card | `WeekCard`: full width inside `screenMargin`, `aspectRatio.weekCard`, `radius.card` (continuous), cover = first visible item (aspect fill), no scrim; "Week {n}" (`displayMedium`, `textOnMedia`) cap top `weekCardTextTop`, inset `weekCardTextInset`, range (`listSubtitle`) `weekCardLinePitch` below, chevron on the serif line's cap middle; one button labelled `week.recap.a11y.card`; `cardGap` apart, newest first (unit-tested) |
| matched | `collage.view.layout.screen`<br>`week.recap.a11y.close` | mediaPage: the collage's first photo (post_ids[0], its display rendition) aspect-filled and blurred full-bleed inside a rounded media page (… (SOURCED)<br>“Close” (SOURCED) | preview close | capture's `RecapPreviewClose` on the media page (C-11 on media at `closeCentreFromTrailing` / `closeCentreBelowPageTop`) → dismiss |
| not matched | `layout.year.story.recapCard`<br>`photo.viewer.a11y.photo` | widthRatio: 0.825; paddingRatio: 0.0241; columns: 4; maxRows: 6; cellAspect: 1.12; gap: size.global.stripGap; cornerRadiusRatio: 0.051; foot… (SOURCED)<br>“{name}'s photo, {date}” (SOURCED) | card grid cell | memory's `RecapCard` (white in both appearances, L-4) with the recap items in order; cell tap → viewer (recap order). Fill rule for other counts `week.recap.layout.gridFill` is BLOCKED: `SocialBlocked.recapCardItems` — DEBUG fills row by row up to 24, release shows the card only when the items fill whole rows (else page 2 alone) |
| matched | `layout.year.story.recapCard` | widthRatio: 0.825; paddingRatio: 0.0241; columns: 4; maxRows: 6; cellAspect: 1.12; gap: size.global.stripGap; cornerRadiusRatio: 0.051; foot… (SOURCED) | card footer | `RecapCard` footer: "Week {n}" (`headerTitle` serif) bottom-leading; group name over the range trailing |
| matched | `week.recap.layout.note`<br>`week.recap.radius.note`<br>`week.recap.dimension.notePaddingV`<br>`week.recap.dimension.notePaddingH`<br>`week.recap.dimension.noteGap` | component: Retro's journal note: rounded box, the text in text role body, color.global.textOnMedia, on color.global.controlOnDeep; corners:… (SOURCED)<br>18 pt (SOURCED)<br>16 pt (SOURCED)<br>18 pt (SOURCED)<br>20 pt (SOURCED) | note | `RecapNote`: the card's width, `noteGap` below it, `radius.note`, padding `notePaddingV` / `notePaddingH`, `controlOnDeep`; editor avatar (`avatarComment`) and first name (`listTitle` weight) lead the text (`body`, `textOnMedia`); card + note centred together |
| matched | `dimension.year.story.dots.offset` | 16.1 pt (SOURCED) | page dots | the chrome's C-31 dots `dimension.year.story.dots.offset` below the page (2 pages), "N of M" from `global.a11y.pagePosition`; pager `TabView(.page)` with its own dots hidden |
| matched | `week.recap.dimension.selectThumb`<br>`week.recap.radius.selectThumb`<br>`week.recap.dimension.selectThumbBorder`<br>`size.global.buttonMarginH`<br>`week.recap.a11y.edit` | 37.7 pt (SOURCED)<br>9 pt (SOURCED)<br>1.7 pt (SOURCED)<br>20 pt (SOURCED)<br>“Select photos” (SOURCED) | select-photos thumbnail | the chrome's leading slot (at `buttonMarginH`): first item, `selectThumb` square, `radius.selectThumb`, `selectThumbBorder` in `surfaceLight`, no badge → `week.edit` (ready recaps) |
| matched | `collage.share.layout.pill`<br>`week.recap.saveAsAlbum` | height: 43.5; paddingHorizontal: 23; trailingInset: size.global.buttonMarginH; centreFromScreenBottom: 59.2 (SOURCED)<br>“Save as Album” (SOURCED) | Save as Album pill | capture's `RecapPill` (`RecapPillLabel`, text role `pill`, `collage.share.layout.pill`) → the album sheet with the recap's photos selected (`WeekEditModel.recapAlbum`) |
| matched | `collage.view.layout.screen`<br>`size.global.backdropBlur`<br>`color.global.backdropDim` | mediaPage: the collage's first photo (post_ids[0], its display rendition) aspect-filled and blurred full-bleed inside a rounded media page (… (SOURCED)<br>1.8 pt (SOURCED)<br>#00000039 (SOURCED) | media page and backdrop (`week.recap.layout.preview`) | capture's `RecapPreviewScreen(dots:onSelectPage:page:overlay:leading:trailing:)` — full width page from the safe area to `mediaPageBottomFromScreenBottom`, corners `mediaPageCornerRadius`, dark in both (`captureMediaAppearance`); filled with the C-34 `BlurredBackdrop` of the cover (σ `backdropBlur` under `backdropDim`, L-5); light status bar via `.preferredColorScheme(.dark)` when presented as a cover |
| matched | `layout.global.photoScrim`<br>`dimension.year.story.footer.baseline`<br>`dimension.year.story.frame.padding` | color: #000000; startAt: 0.55; startOpacity: 0; endOpacity: 0.6; direction: top → bottom (SOURCED)<br>24.8 pt (SOURCED)<br>19.5 pt (SOURCED) | page 2 — cover | cover aspect-fill under C-35 `PhotoScrim`; memory's `RecapFooter`: "Week {n}" (`headerTitle`, `textOnMedia`) and name / range trailing |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `week.history.a11y.loading` | “Loading” (SOURCED) | loading (list) | two `WeekCardShape`s in `control` (no indicator over cached content) |
| approximated | `color.global.control`<br>`duration.global.fade` | light #F1F1F1 / dark #262626 (SOURCED)<br>150 ms (SOURCED) | loading (preview) | the media page on `backgroundDeep` (the cover is not known before the recap loads) with the C-28 indicator; card cells fade in as their images load |
| matched | `week.recap.pending` | “Creating your recap…” (SOURCED) | pending (`status = pending`) | list: `PendingWeekCard` (`control` card, `week.recap.pending` centred); preview: the line centred on the page |
| matched | `icon.global.recap`<br>`icon.global.add`<br>`week.recap.empty.title`<br>`week.recap.empty.detail`<br>`week.recap.empty.action` | ios: film.stack; android: Outlined.VideoLibrary (PLATFORM)<br>ios: plus; android: Rounded.Add (PLATFORM)<br>“Nothing to see here yet” (SOURCED)<br>“When your group fills in its weeks, you'll see recaps here.” (SOURCED)<br>“Add a memory” (SOURCED) | empty (no recaps yet) | C-27 in the sheet: `icon.global.recap`, title, detail, C-07 "Add a memory" with `icon.global.add` → camera for this group |
| matched | `color.global.textSecondary`<br>`week.recap.error.title` | #999999 (SOURCED)<br>“Error loading recaps. Tap here to try again.” (SOURCED) | error | list: `SocialErrorLine` under the header; preview: the same line centred on the page; tap reloads |
| matched | `chat.thread.offline.detail` | “Check your connection and try again.” (SOURCED) | offline | error line + `chat.thread.offline.detail`; a cached recap shows offline (unit-tested) |
| matched | `—` | — | permission-denied | n/a |

## Motion

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `spring.global.sheetPresent`<br>`duration.global.sheetPresent` | response: 0.347; dampingFraction: 1 (SOURCED)<br>567 ms (SOURCED) | list sheet in / out | native sheet (`SocialModal.recaps`, `presentsAsSheet`) |
| approximated | `duration.global.photoOpen`<br>`easing.global.standard` | 250 ms (SOURCED)<br>x1: 0.4; y1: 0; x2: 0.2; y2: 1 (SOURCED) | list → preview | native `.fullScreenCover` (from the list and from week.history's menu), not the 250-ms photo-open transition |
| matched | `—` | — | page swipe | native paging `TabView` |
| matched | `duration.global.fade` | 150 ms (SOURCED) | images appear | images fade in (component `PhotoView` / `StorageImage`) |

## Haptics

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | tap card / circle / pill (Android) | none on iOS |
| matched | `—` | — | page swipe | none |

# Verification — `onthisday` (iOS)

Photos from this date in past years (the day, one screen per year) and its group-screen entry — `ios/App/Sources/Features/Memory/OnThisDay/`.

Checklist written from the spec (`design/surfaces/onthisday.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/memory/<surface>-<state>.png` (`ios/AppTests/Memory/MemorySnapshotTests.swift`), then `tools/sidebyside.py` makes `design/verification/onthisday.png` next to the reference image(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level).

Reference image(s): `references/auto/timehop/store/timehop-store-01.png`, `references/auto/timehop/store/timehop-store-02.png`, `references/auto/timehop/store/timehop-store-05.png`, `references/auto/timehop/help/th-help-2023-04-memory-view-hide.png`

Snapshots (CI): `onthisday-loading.png`, `onthisday-single.png`, `onthisday-grid.png`, `onthisday-error.png`, `onthisday-offline.png`, `onthisday-entry.png`

**Summary: 24 matched · 4 approximated · 1 not matched (BLOCKED or not buildable).**

## Banner

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `color.onthisday.banner` | #FC5F33 (SOURCED) | banner fill, same for every year (M-9) | background of OnThisDayBannerLayout |
| matched | `dimension.onthisday.banner.height` | 96.8 pt (SOURCED) | banner bottom 96.8 from the screen top (behind the status bar) | Layout height = max(token, natural) from the screen top; ignoresSafeArea |
| matched | `layout.onthisday.banner` | width: full screen width; top: screen top edge, behind the status bar; labelAlign: centre; labelCase: uppercase; colourPerMemory: color.o… (SOURCED) | full width, top edge behind the status bar, label centred, uppercase | full-width layout; label centred; copy shown as stored |
| matched | `dimension.onthisday.progress.height`<br>`layout.onthisday.progress` | 4.3 pt (SOURCED)<br>position: top edge of the banner, directly below the status bar; width: full screen width; sideInset: 0; fill: fraction of the day's year… (SOURCED) | progress bar on the banner top, directly below the status bar, full width, fraction (index+1)/years | subview placed at safe-area top, width × model.progress |
| matched | `color.onthisday.progress.fill`<br>`color.onthisday.progress.track` | #F7D23E (SOURCED)<br>#93140A (SOURCED) | reached / not-reached parts | ZStack fill over track; hidden from accessibility |
| matched | `fontSize.onthisday.banner.label`<br>`fontWeight.onthisday.banner.label`<br>`color.onthisday.banner.label`<br>`font.onthisday` | 25.8 pt (SOURCED)<br>bold (SOURCED)<br>#FFFFFF (SOURCED)<br>ios: system; android: system (PLATFORM) | ‘N YEARS AGO’ label | DSTextStyle; header trait |
| matched | `layout.onthisday.textStyleMap` | bannerLabel: title1; meta: caption2 (PLATFORM) | label → title1, meta → caption2 | DSTextStyle.relativeTo |
| matched | `dimension.onthisday.banner.labelBaseline` | 25.4 pt (SOURCED) | label baseline 25.4 above banner bottom | Layout places the label by its lastTextBaseline; banner grows at large sizes |
| matched | `onthisday.banner.yearsAgo.one`<br>`onthisday.banner.yearsAgo.other` | “1 YEAR AGO” (SOURCED)<br>“{count} YEARS AGO” (SOURCED) | 1 YEAR AGO / {count} YEARS AGO | Copy by years_ago |

## Close

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `size.global.headerButton`<br>`size.global.headerInset`<br>`color.global.controlOnDeep`<br>`icon.global.close`<br>`color.global.textPrimary` | 44 pt (SOURCED)<br>11.5 pt (SOURCED)<br>#101010 (SOURCED)<br>ios: xmark; android: Rounded.Close (PLATFORM)<br>#FFFFFF (SOURCED) | header circle at the banner's right, centred on the label row (M-29) | MemoryHeaderCircle placed by the banner Layout; glyph at the platform default symbol size (no glyph token) |
| matched | `onthisday.a11y.close` | “Close” (PLATFORM) | VoiceOver label | accessibilityLabel |

## Content

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `layout.onthisday.photo.single` | width: full screen width; top: banner bottom; bottom: screen bottom; fit: fill (cropped to the area); cornerRadius: 0 (SOURCED) | one photo: full width, banner bottom → screen bottom, cropped, no corners | MemoryRemoteImage .fill, display rendition (original until renditions) |
| matched | `dimension.onthisday.meta.avatar`<br>`dimension.onthisday.meta.inset`<br>`dimension.onthisday.meta.centerY`<br>`dimension.onthisday.meta.gap` | 19.0 pt (SOURCED)<br>16.2 pt (SOURCED)<br>25.7 pt (SOURCED)<br>11.5 pt (SOURCED) | meta row: avatar 19, inset 16.2, centre 25.7 below banner, gap 11.5 | HStack in a frame of height 2 × centerY at the photo's top-left |
| matched | `fontSize.onthisday.meta`<br>`fontWeight.onthisday.meta`<br>`color.onthisday.meta.text`<br>`onthisday.memory.meta` | 10.6 pt (SOURCED)<br>bold (SOURCED)<br>#FFFFFF (SOURCED)<br>“{weekday} {time}” (SOURCED) | ‘TUE 10:34 PM’ (group time zone) | Copy with EEE upper-cased + locale short time; hidden from VoiceOver |
| approximated | `icon.global.person`<br>`color.global.control` | ios: person.fill; android: Rounded.Person (PLATFORM)<br>#2E2E2E (SOURCED) | avatar placeholder | person glyph sized by the meta text role (no glyph-size token) on the control circle |
| matched | `layout.onthisday.grid`<br>`dimension.onthisday.grid.margin`<br>`dimension.onthisday.grid.gutter`<br>`dimension.onthisday.grid.top`<br>`color.global.background` | columns: 2; arrangement: masonry: every photo keeps its aspect ratio and goes to the shorter column; scroll: vertical; background: color.… (SOURCED)<br>3.8 pt (SOURCED)<br>4.2 pt (SOURCED)<br>5.5 pt (SOURCED)<br>#171717 (SOURCED) | 2+ photos: 2-column masonry, shorter column first, margins 3.8, gutter 4.2, 5.5 below the banner, gaps show background | OnThisDayMasonry Layout in a vertical ScrollView; thumb rendition |
| approximated | `—` | — (no token) | photo aspect ratio | media width/height; a media row without dimensions is laid out square |
| matched | `layout.onthisday.navigation` | order: one memory screen per year, newest first (1 YEAR AGO, then 2, 3 ...); next: tap or swipe on the right half of the screen (older); … (SOURCED) | right half → older (closes after the oldest), left half → newer; grid taps are zone taps | onTapGesture(coordinateSpace:) on the content; no other tap targets |
| matched | `onthisday.a11y.next`<br>`onthisday.a11y.previous`<br>`onthisday.a11y.photo` | “Older” (SOURCED)<br>“Back” (SOURCED)<br>“Photo by {name}, {weekday} {time}” (PLATFORM) | custom actions + photo labels; screen-changed after a change | accessibilityAction(named:) on each photo; UIAccessibility screenChanged |
| matched | `layout.onthisday.dayBoundary` | hour: 5; clock: group time zone (groups.time_zone) (SOURCED) | day = group-local date of now, rolling over at 05:00 | OnThisDayCalendar.localDate (unit-tested) |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `onthisday.loading`<br>`fontSize.global.listSubtitle`<br>`color.global.textSecondary` | “Collecting Memories” (SOURCED)<br>14 pt (SOURCED)<br>#969696 (SOURCED) | loading: banner area + platform indicator + ‘Collecting Memories’ | MemoryLoadingIndicator; first frame already shows it (no empty frame) |
| matched | `onthisday.error.title`<br>`onthisday.error.detail`<br>`onthisday.error.retry`<br>`fontSize.global.emptyTitle`<br>`fontSize.global.emptyDetail`<br>`color.global.surfaceLight`<br>`color.global.onSurfaceLight` | “Time Travel Failed” (SOURCED)<br>“try again in a moment — your memories are waiting” (SOURCED)<br>“try again” (SOURCED)<br>16 pt (SOURCED)<br>14 pt (SOURCED)<br>#FFFFFF (SOURCED)<br>#000000 (SOURCED) | error: emptyTitle / emptyDetail centred + light pill | MemoryStateMessage |
| matched | `onthisday.offline.title`<br>`onthisday.offline.detail` | “you're offline” (SOURCED)<br>“connect to see this day — your memories are waiting” (SOURCED) | offline: same layout | MemoryStateMessage; cached day stays on screen when a refresh fails |
| approximated | `size.global.buttonHeight`<br>`radius.global.capsule` | 45 pt (SOURCED)<br>shape: capsule; radius: height / 2 (SOURCED) | retry pill size | height = buttonHeight, label inset = capsule radius (pill padding not measured) |
| approximated | `—` | — (no token) | error / offline keep the banner (with ✕) | so the full-screen day can be closed |
| matched | `—` | — (no token) | photo deleted while open (post_deleted) | drops the photo, then the year, closes when none remain (unit-tested) |

## Motion and presentation

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| not matched | `duration.onthisday.memoryChange` | None (BLOCKED) | year → year transition (BLOCKED) | changes without animation; one-line switch MemoryBlocked.onThisDayMemoryChange |
| matched | `easing.global.native` | keyboard: system; alert: system; activityIndicator: system (ProgressView / CircularProgressIndicator); scrollIndicator: system; navigatio… (PLATFORM) | open / close: native full-screen presentation | OnThisDayEntry → .fullScreenCover; MemoryModal.onThisDay → shell cover |

## Entry (groups.screen)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `onthisday.entry.title`<br>`onthisday.banner.yearsAgo.one` | “{group}'s Day in History” (SOURCED)<br>“1 YEAR AGO” (SOURCED) | row title + newest label; hidden without rows | OnThisDayEntry(groupID:) with a caller row builder; cached content first |

## Notes

Contrast failures reported by the spec (progress track / fill vs banner) are kept as sourced. The 44-pt close circle centred on the label row reaches the progress bar on notched phones, as the spec places it.

# Verification — `onthisday` (iOS)

Retro Rewind: one memory at a time, the dial, play / pause, share, shuffle, the '•••' menu, the feature intro and the group-screen entry — `ios/App/Sources/Features/Memory/OnThisDay/ (OnThisDayScreen, RewindDial, OnThisDayModel, OnThisDayEntry)`.

Pass 4 (Retro redesign). Checklist written from the spec (`design/surfaces/onthisday.md`, MERGE "Redesign — Memory (RM-*)", lead L-4 / L-5) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/memory/<surface>-<state>-<light|dark>.png` (`ios/AppTests/Memory/MemorySnapshotTests.swift`: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/onthisday.png` next to the Retro reference(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level). Components are the Pass 3 library (`ios/App/Sources/Components`, C-01…C-35).

Retro reference(s): `references/auto/retro/press/tc-2025-12-rewind-device-b.jpg (RWB)`, `references/auto/retro/press/tc-2025-12-rewind-device-a.png (RWA)`, `references/auto/retro/press/tc-2025-12-rewind-panels.png (RWP)`, `references/auto/retro/store/retro-store-05.png (ST-05)`

Snapshots (CI): `onthisday-loading-light.png`, `onthisday-paused-light.png`, `onthisday-paused-dark.png`, `onthisday-paused-own-memory-light.png`, `onthisday-playing-light.png`, `onthisday-shuffle-light.png`, `onthisday-intro-light.png`, `onthisday-intro-dark.png`, `onthisday-empty-light.png`, `onthisday-error-light.png`, `onthisday-offline-light.png`, `onthisday-entry-light.png`, `onthisday-entry-dark.png`

**Summary: 40 matched · 3 approximated · 0 not matched (BLOCKED or not buildable).**

## Entry (placed by groups.screen)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `onthisday.entry.title`<br>`onthisday.entry.subtitle`<br>`onthisday.entry.button` | “On this day” (SOURCED)<br>“Revisit memories from {date} over the years” (SOURCED)<br>“View memories” (SOURCED) | feed card copy, shown only while the day has rows | OnThisDayEntryModel → MemoryEntryContent (title, line, action); hidden zero-size stack otherwise |
| matched | `layout.birthday.add.dateFormat` | pattern: MMMM d; example: July 5; ios: Date.FormatStyle().month(.wide).day(); android: DateFormat.getBestDateTimePattern(locale, "MMMMd") (SOURCED) | {date} = today as 'July 5' | MemoryFormat.dayMonth (Date.FormatStyle month(.wide).day()) |
| matched | `icon.global.rewind` | ios: clock.arrow.circlepath; android: Outlined.History (PLATFORM) | the feature's glyph on the card's header line | MemoryEntryContent.icon; the newest memory's display path as photoPath |
| matched | `—` | — (no token) | card look and placement | groups.screen (account) draws its feed card from `MemoryEntryContent` (title, line, action, `icon`, `photoPath`); the default `MemoryEntryFeedCard` follows groups.screen item 8; a tap pushes `MemoryRoute.onThisDay` |

## Page (C-35 on media)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `color.global.backgroundDeep`<br>`layout.global.appearance` | #000000 (SOURCED)<br>mode: follows the system Light / Dark setting; ios: no UIUserInterfaceStyle key and no preferredColorScheme override; colour tokens are d… (SOURCED) | page black in both appearances, subtree dark | .environment(\.colorScheme, .dark) on the page; sheets over it follow the system |
| matched | `radius.global.photo` | 0 pt (SOURCED) | photo full bleed, aspect-fill, under the status bar, no top scrim | MemoryRemoteImage (.fill) ignoring the safe area |
| matched | `layout.global.photoScrim`<br>`color.global.scrim` | color: #000000; startAt: 0.55; startOpacity: 0; endOpacity: 0.6; direction: top → bottom (SOURCED)<br>#00000099 (SOURCED) | bottom scrim from 55 % of the height | C-35 `PhotoScrim` |
| matched | `—` | — (no token) | status bar light content; pushed with the system bar hidden, interactive pop kept | light status-bar content from the shell's `.mediaStatusBar()` at the push site (account, `RouteDestination`); `.toolbar(.hidden)` + `memoryInteractivePop()` keeps the edge swipe back |

## Header (C-02 / C-35 on media)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `icon.global.back`<br>`size.global.backInset`<br>`color.global.textOnMedia`<br>`size.global.minTouchTarget.ios` | ios: chevron.left; android: AutoMirrored.Rounded.ArrowBackIos (PLATFORM)<br>21.1 pt (SOURCED)<br>#FFFFFF (SOURCED)<br>44 pt (VERIFIED) | back chevron, ink at 21.1 from the edge, ≥ 44 hit area | Image at the `size.global.icon` symbol size (as C-02), `minimumHitArea`; pops |
| matched | `font.global.display`<br>`fontSize.global.headerTitle`<br>`fontWeight.global.headerTitle`<br>`lineHeight.global.headerTitle`<br>`size.global.titleTop`<br>`size.global.headerGap` | ios: system-serif; android: serif (PLATFORM)<br>40 pt (SOURCED)<br>regular (SOURCED)<br>48 pt (SOURCED)<br>64 pt (SOURCED)<br>14.6 pt (SOURCED) | date title in the display serif, baseline 64 below the safe-area top, 14.6 after the chevron | MetricStack `.metricGap(titleTop, .top → .firstBaseline)`; leading = backInset + chevron width + headerGap; wraps to two lines at large sizes |
| matched | `layout.onthisday.dateFormat` | style: medium date (the locale's abbreviated month, day, year); ios: Date.FormatStyle(date: .abbreviated, time: .omitted); android: DateF… (SOURCED) | 'Jul 22, 2022' | MemoryFormat.memoryDate (Date.FormatStyle date .abbreviated) in the group's time zone; cross-fades with the memory |
| matched | `dimension.onthisday.subtitleBaseline`<br>`color.onthisday.subtitle`<br>`fontSize.global.textButton` | 26.4 pt (SOURCED)<br>#FFFFFFC2 (SOURCED)<br>17 pt (SOURCED) | subtitle 26.4 below the title's last baseline, on its leading edge | `.metricGap(subtitleBaseline, .lastBaseline → .firstBaseline)` |
| matched | `onthisday.subtitle.day`<br>`onthisday.subtitle.shuffle` | “On this day · {name}” (SOURCED)<br>“Memories · {name}” (SOURCED) | 'On this day · {name}' / after the dice 'Memories · {name}' | OnThisDayModel.subtitle by mode; {name} = poster's first name |
| matched | `size.global.circleButtonPhoto`<br>`color.global.glass`<br>`icon.global.more`<br>`size.global.headerInset` | 40 pt (SOURCED)<br>#FFFFFF1F (SOURCED)<br>ios: ellipsis; android: Rounded.MoreHoriz (PLATFORM)<br>16 pt (SOURCED) | '•••' glass circle 40, ink 16 from the right, on the title's cap middle | C-11 `CircleMenu(.glass)` overlaid on the title's `.capMiddle` guide |
| matched | `onthisday.mode.day`<br>`onthisday.mode.shuffle`<br>`icon.global.chevronDown` | “On this day…” (SOURCED)<br>“Shuffle” (SOURCED)<br>ios: chevron.down; android: Rounded.ExpandMore (PLATFORM) | mode menu on the date title (RM-18): 'On this day…' → the day's memories from the newest, 'Shuffle' → as the dice; 'Pick a date…' not built | SwiftUI `Menu` over the title (clear label, the title's frame plus the chevron), `OnThisDayModel.showDay()` / `shuffle()`; VoiceOver: the title is the menu button (header trait, read as the date); MemoryOnThisDayTests.testModeMenuGoesBackFromShuffleToTheDay, MemoryOnThisDayUITests |
| approximated | `dimension.onthisday.modeChevron.width`<br>`dimension.onthisday.modeChevron.gap`<br>`dimension.onthisday.modeChevron.drop`<br>`fontWeight.onthisday.modeChevron` | 19.7 pt (SOURCED)<br>8.7 pt (SOURCED)<br>2.0 pt (SOURCED)<br>medium (PLATFORM) | chevron after the date: ink 19.7 wide, 8.7 after the date's last glyph ink, centre 2.0 below the cap middle | `ModeChevron` overlay: resizable `chevron.down` in a 19.7-pt frame, leading guide = title frame trailing + gap, `.capMiddle` guide + drop; the gap is laid from the text frame, so the last digit's right side bearing (≈ 1.3 pt at 43 pt) adds to RWA's ink-to-ink gap (Android measures 10.0 for 8.7) |

## Menu (D, native)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `onthisday.menu.save`<br>`onthisday.menu.report`<br>`onthisday.menu.delete` | “Save to Camera Roll” (SOURCED)<br>“Report Post” (SOURCED)<br>“Delete Post” (SOURCED) | your own memory: Save + Delete (red); someone else's: Report (red) — owner decision 12 | SwiftUI `Menu` with `Button(role: .destructive)`; report → `safety.report` (ReportTarget kind post) |
| matched | `onthisday.delete.title`<br>`onthisday.delete.message`<br>`onthisday.delete.confirm`<br>`onthisday.delete.cancel` | “Delete this post?” (SOURCED)<br>“This will permanently delete this photo from {group}” (SOURCED)<br>“Yes, delete” (SOURCED)<br>“Cancel” (SOURCED) | native confirmation | `.alert(presenting:)` → `delete_post`; the memory leaves the dial |
| matched | `onthisday.toast.saved`<br>`onthisday.toast.deleted`<br>`onthisday.saveFailed` | “Saved!” (SOURCED)<br>“Deleted” (SOURCED)<br>“Couldn't save photo” (SOURCED) | confirmations / failure | C-26 `ToastCenter` (iOS: announced, nothing drawn) |
| matched | `onthisday.saveDenied.title`<br>`onthisday.saveDenied.message`<br>`onthisday.saveDenied.button` | “Camera Roll Access” (SOURCED)<br>“Allow access in Settings to save photos to your camera roll.” (SOURCED)<br>“Allow Photo Access” (SOURCED) | add-only access denied → alert that opens Settings | `.alert` with `UIApplication.openSettingsURLString` |
| matched | `haptic.global.success`<br>`haptic.global.warning`<br>`haptic.global.error` | ios: notification.success; android: CONFIRM (PLATFORM)<br>ios: notification.warning; android: CONFIRM (PLATFORM)<br>ios: notification.error; android: REJECT (PLATFORM) | save ok / delete confirmed / failed | MemoryDependencies.haptics |

## Control row (`layout.onthisday.controls`)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `layout.onthisday.controls`<br>`dimension.onthisday.controls.centerY` | order: share circle, dial, random circle; arrangement: equal gaps across the screen width: edge | share | dial | random | edge (the dial'… (SOURCED)<br>139.2 pt (SOURCED) | share | dial | random with equal gaps, centres 139.2 above the safe-area bottom | HStack of equal `Spacer(minLength: 0)`s; bottom padding = centerY − diameter ÷ 2 |
| matched | `size.global.circleButtonLarge`<br>`color.global.glass`<br>`icon.global.share`<br>`icon.global.random`<br>`size.global.icon` | 64 pt (SOURCED)<br>#FFFFFF1F (SOURCED)<br>ios: square.and.arrow.up; android: Rounded.IosShare (PLATFORM)<br>ios: dice; android: Outlined.Casino (PLATFORM)<br>24 pt (SOURCED) | 64-pt glass circles, 24-pt glyph box | C-11 `CircleButton(.glassLarge)` / `CircleButtonFace` inside the ShareLink |
| matched | `duration.global.fade`<br>`easing.global.standard` | 150 ms (SOURCED)<br>x1: 0.4; y1: 0; x2: 0.2; y2: 1 (SOURCED) | share and random fade out while playing | opacity + hit testing off + hidden from VoiceOver, `ComponentMotion.fade` |
| matched | `onthisday.a11y.share` | “Share” (PLATFORM) | share circle on your own memory only (owner decision 12); on someone else's the place stays empty | `HiddenInPlace(isHidden: isPlaying || !canExport)` (opacity 0, no hit testing, hidden from VoiceOver); `OnThisDayModel.save()` / `shareItem` refuse others' memories; snapshots `paused` (someone else's) / `paused-own-memory`; MemoryOnThisDayTests.testOnlyYourOwnMemoryCanBeSavedOrShared |
| matched | `layout.year.story.dateFormat` | pattern: EEEE, MMMM d; example: Wednesday, July 5; ios: Date.FormatStyle().weekday(.wide).month(.wide).day(); android: DateFormat.getBest… (SOURCED) | share sheet preview title = today 'Tuesday, December 2' | `ShareLink(item:preview: SharePreview(title, image:))`; the original downloads when a destination is picked |
| approximated | `onthisday.share.subtitle` | “Memory” (SOURCED) | preview subtitle 'Memory' | `SharePreview` has no subtitle: the system draws the file type there |

## Dial (`layout.onthisday.dial`)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `count.onthisday.dial.ticks`<br>`dimension.onthisday.dial.diameter` | 44 (SOURCED)<br>150 pt (SOURCED) | 44 slots on a 150-pt ring, slot 0 at 6° clockwise from 3 o'clock, 8.18° pitch | `RewindDial` Canvas (firstSlotDegrees, pitchDegrees from the layout token) |
| matched | `dimension.onthisday.dial.tickLong`<br>`dimension.onthisday.dial.tickShort`<br>`dimension.onthisday.dial.tickWidth`<br>`color.onthisday.dial.tick` | 19.8 pt (SOURCED)<br>11.8 pt (SOURCED)<br>3.2 pt (SOURCED)<br>#FFFFFF4D (SOURCED) | even slots long 19.8, odd short 11.8, 3.2 wide, white 30 %, inward from the outer edge | stroked with round caps (`layout.global.iconStyle`) kept inside the measured length |
| matched | `dimension.onthisday.dial.indicatorLength`<br>`color.global.textOnMedia` | 16.7 pt (SOURCED)<br>#FFFFFF (SOURCED) | indicator 16.7 solid white on the current memory's slot | slot = memory index mod 44; starts on slot 0 |
| matched | `dimension.onthisday.dial.glyph`<br>`icon.global.play`<br>`icon.global.pause` | 35 pt (SOURCED)<br>ios: play.fill; android: Rounded.PlayArrow (PLATFORM)<br>ios: pause.fill; android: Rounded.Pause (PLATFORM) | centre play (paused) / pause (playing), ink 35 high | its own button, ≥ 44 hit area |
| matched | `haptic.global.select` | ios: selection; android: SEGMENT_FREQUENT_TICK (PLATFORM) | one tick per slot crossed and per automatic step | OnThisDayModel.move → `UISelectionFeedbackGenerator` (DSHaptic.selection) |
| matched | `duration.global.crossfade`<br>`duration.onthisday.memoryChange`<br>`duration.onthisday.playHold` | 100 ms (SOURCED)<br>700 ms (SOURCED)<br>4000 ms (SOURCED) | drag step cross-fades 100 ms; playing advances every 4 s with a 700-ms cross-fade, stops after the last | `.animation(value: current.id)` by the last change; play loop on `dependencies.sleep` (unit-tested) |
| matched | `onthisday.a11y.dial`<br>`onthisday.a11y.dialValue`<br>`onthisday.a11y.play`<br>`onthisday.a11y.pause` | “Memories” (PLATFORM)<br>“{position} of {total}” (SOURCED)<br>“Play” (PLATFORM)<br>“Pause” (PLATFORM) | one adjustable element 'Memories', '2 of 5'; play / pause separate | `.accessibilityAdjustableAction`; the new date is announced after a change |
| approximated | `onthisday.a11y.next`<br>`onthisday.a11y.previous` | “Next” (PLATFORM)<br>“Previous” (PLATFORM) | next / previous actions | iOS: the adjustable element's increment / decrement (swipe up / down) — the custom-action labels are Android's |

## Shuffle (RM-5)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `onthisday.a11y.shuffle` | “Shuffle” (SOURCED) | the dice: a random memory of the group's whole history; the dial then steps through further picks | `group_history_weeks` paged by 52 until a short page (cached per session); random week, then random post; previous goes back through the picks |

## Feature intro (C-29, once per account)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `onthisday.nux.title`<br>`onthisday.nux.message`<br>`onthisday.nux.button` | “Introducing On This Day” (SOURCED)<br>“On This Day is a private way to revisit what {group} shared on this date over the years. Drag the dial to take a spin through your memories.” (SOURCED)<br>“Try it out” (SOURCED) | intro sheet over the page, never shown again | C-29 `FeatureIntroSheet` (medium detent, follows the system appearance); per-account defaults flag |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `onthisday.loading`<br>`color.global.textSecondary` | “Loading…” (SOURCED)<br>#999999 (SOURCED) | loading: black page, platform indicator, back only | C-28 `LoadingHUD` + announcement |
| matched | `onthisday.empty.title`<br>`fontSize.global.emptyTitle` | “No photos found for this day” (SOURCED)<br>20 pt (SOURCED) | every memory deleted while open: C-27 title on black | EmptyStateView (dark: textPrimary = white) |
| matched | `onthisday.error.title`<br>`onthisday.error.detail`<br>`onthisday.error.retry`<br>`color.global.surfaceLight`<br>`color.global.onSurfaceLight`<br>`size.global.pillHeight`<br>`fontSize.global.pill` | “Something went wrong” (SOURCED)<br>“There was a problem. Please try again.” (SOURCED)<br>“Try Again” (SOURCED)<br>#FFFFFF (SOURCED)<br>#000000 (SOURCED)<br>37 pt (SOURCED)<br>15 pt (SOURCED) | error: C-27 + C-09 light pill | MemoryMediaStateBlock (EmptyStateView + LightPill, `size.global.emptyTitleToAction`) |
| matched | `onthisday.offline.title`<br>`onthisday.offline.detail` | “No Connection” (SOURCED)<br>“Check your connection and try again.” (SOURCED) | offline: same block; the cached day stays when a refresh fails | MemoryMediaStateBlock |
| matched | `onthisday.a11y.back`<br>`onthisday.a11y.more`<br>`onthisday.a11y.share`<br>`onthisday.a11y.photo` | “Back” (PLATFORM)<br>“More” (PLATFORM)<br>“Share” (PLATFORM)<br>“Photo by {name}, {date}” (PLATFORM) | labels; focus order back → title → subtitle → more → photo → share → dial → play → random | accessibilitySortPriority 9…1 |
| matched | `layout.onthisday.dayBoundary` | hour: 5; clock: group time zone (groups.time_zone) (SOURCED) | day = group-local date, rolling over at 05:00 | OnThisDayCalendar.localDate (unit-tested) |

## Notes

Hand-off (account): `ShellState.presentModalRoute` still turns a pushed `.memory(.onThisDay)` into a full-screen cover (the previous spec); the Rewind page is now pushed in the group's stack (platform notes), which also keeps the interactive pop gesture. The page works in both presentations (back = `dismiss`).

# Verification — `birthday.contribute` (iOS)

Choose a photo, add one line, send — Retro's composer sheet, postcard composer and 'Add a Message' modal in Tribute / VidDay's order — `ios/App/Sources/Features/Memory/Birthday/ (BirthdayContributeScreen, BirthdayContributeModel)`.

Pass 4 (Retro redesign). Checklist written from the spec (`design/surfaces/birthday.contribute.md`, MERGE "Redesign — Memory (RM-*)", lead L-4 / L-5) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/memory/<surface>-<state>-<light|dark>.png` (`ios/AppTests/Memory/MemorySnapshotTests.swift`: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/birthday.contribute.png` next to the Retro reference(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level). Components are the Pass 3 library (`ios/App/Sources/Components`, C-01…C-35).

Retro reference(s): `references/auto/retro/video/ig-DDbA_F7x-j7-composer-f130-147-f188-197.png (VID-COMP)`, `references/auto/retro/store/retro-store-03.png (ST-03)`, `references/auto/retro/press/tc-2023-12-retro3.png phone 3 (TC-R3)`

Snapshots (CI): `birthday.contribute-loading-light.png`, `birthday.contribute-picker-light.png`, `birthday.contribute-picker-dark.png`, `birthday.contribute-picker-selected-light.png`, `birthday.contribute-composer-light.png`, `birthday.contribute-composer-dark.png`, `birthday.contribute-composer-filled-light.png`, `birthday.contribute-message-light.png`, `birthday.contribute-message-dark.png`, `birthday.contribute-sending-light.png`, `birthday.contribute-not-eligible-light.png`, `birthday.contribute-error-light.png`, `birthday.contribute-offline-light.png`, `birthday.contribute-empty-light.png`, `birthday.contribute-closed-light.png`, `birthday.contribute-load-error-light.png`

**Summary: 18 matched · 2 approximated · 0 not matched (BLOCKED or not buildable).**

## Step 1 — Choose a Photo

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `birthday.contribute.picker.cancel`<br>`birthday.contribute.picker.title`<br>`birthday.contribute.picker.next`<br>`fontSize.global.sheetTitle`<br>`color.global.selection` | “Cancel” (SOURCED)<br>“Choose a Photo” (SOURCED)<br>“Next” (SOURCED)<br>17 pt (SOURCED)<br>light: #0088FF; dark: #0091FF (PLATFORM) | native toolbar Cancel / title / Next (disabled until a photo is chosen) | C-29 `.sheetToolbar` in the sheet's NavigationStack |
| matched | `birthday.contribute.picker.subtitle`<br>`fontSize.global.body`<br>`color.global.textSecondary`<br>`size.global.screenMargin` | “Photos you posted or are in” (SOURCED)<br>15 pt (SOURCED)<br>#999999 (SOURCED)<br>16 pt (SOURCED) | grey line | Text at the screen margin |
| approximated | `size.global.stripGap`<br>`radius.global.photo` | 2 pt (SOURCED)<br>0 pt (SOURCED) | 4-column square grid, 2-pt gaps, full width | LazyVGrid; the column count is `week.edit.count.gridColumns` (4, the same Retro composer) — no memory or global token (component gap) |
| matched | `icon.global.check`<br>`color.global.selection`<br>`size.global.checkCircle`<br>`size.global.badgeInset`<br>`duration.global.fade`<br>`haptic.global.select` | ios: checkmark.circle.fill; android: Rounded.CheckCircle (PLATFORM)<br>light: #0088FF; dark: #0091FF (PLATFORM)<br>24 pt (SOURCED)<br>12 pt (SOURCED)<br>150 ms (SOURCED)<br>ios: selection; android: SEGMENT_FREQUENT_TICK (PLATFORM) | single selection: filled check top-right, inset 12; fades in | palette symbol (white tick on the selection circle — the platform picker's), `.isSelected` trait |
| matched | `birthday.contribute.a11y.photo` | “Photo from {date}” (PLATFORM) | 'Photo from {date}' | medium date of the post |
| matched | `birthday.contribute.loading`<br>`color.global.control` | “Loading…” (SOURCED)<br>light: #F1F1F1; dark: #262626 (SOURCED) | loading: placeholder tiles in the cells | C-17 placeholders filling the visible grid + announcement |
| matched | `birthday.contribute.picker.empty.title`<br>`birthday.contribute.picker.empty.detail`<br>`birthday.contribute.picker.empty.action` | “Nothing to see here yet” (SOURCED)<br>“Photos you post in {group}, or tag yourself in with “I'm in this”, show up here.” (SOURCED)<br>“View {group}” (SOURCED) | empty: C-27 + outline capsule 'View {group}' → groups.screen | EmptyStateView action; the request closes too |
| matched | `birthday.contribute.notEligible` | “You can only add photos you posted or are in” (SOURCED) | not eligible: inline line (meta, red), back to step 1 | Text under the grey line |

## Step 2 — the composer (dark)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `color.global.backgroundDeep`<br>`birthday.contribute.composer.title`<br>`color.global.textOnMedia` | #000000 (SOURCED)<br>“Birthday Video” (SOURCED)<br>#FFFFFF (SOURCED) | dark composer, centred 'Birthday Video' (sheetTitle) | subtree dark; system bar hidden |
| approximated | `icon.global.back` | ios: chevron.left; android: AutoMirrored.Rounded.ArrowBackIos (PLATFORM) | leading native back | C-11 bare header glyph `HeaderIconButton` in `color.global.textOnMedia` (the system bar is hidden so the title's baseline places the photo); label from `onthisday.a11y.back` — the surface has no back key |
| matched | `size.global.circleButton`<br>`color.global.controlOnDeep`<br>`icon.global.close`<br>`birthday.contribute.a11y.close` | 36 pt (SOURCED)<br>#262626 (SOURCED)<br>ios: xmark; android: Rounded.Close (PLATFORM)<br>“Close” (PLATFORM) | close circle on media → dismisses the sheet | C-11 `.media` (glyph box `size.global.iconSmall`) |
| matched | `dimension.birthday.contribute.titleToPhoto`<br>`dimension.birthday.contribute.photoWidth`<br>`dimension.birthday.contribute.photoMaxHeight`<br>`radius.birthday.contribute.photo` | 32.6 pt (SOURCED)<br>297.4 pt (SOURCED)<br>422.8 pt (SOURCED)<br>8.5 pt (SOURCED) | photo fitted (own aspect) in 297.4 × 422.8, 32.6 below the title's baseline, corners 8.5 | MetricStack `.lastBaseline → .top` |
| matched | `birthday.contribute.message.add`<br>`birthday.contribute.message.edit`<br>`icon.global.edit`<br>`color.global.controlOnDeep`<br>`size.global.pillHeight`<br>`fontSize.global.pill`<br>`dimension.birthday.contribute.pillBottom`<br>`duration.global.crossfade` | “Add a message” (SOURCED)<br>“Edit message” (SOURCED)<br>ios: pencil; android: Outlined.Edit (PLATFORM)<br>#262626 (SOURCED)<br>37 pt (SOURCED)<br>15 pt (SOURCED)<br>20.9 pt (SOURCED)<br>100 ms (SOURCED) | C-09 dark pill on the photo, 20.9 above its bottom; label cross-fades | `LightPill(style: .dark)` |
| matched | `fontSize.global.body`<br>`size.global.listGap` | 15 pt (SOURCED)<br>22.5 pt (SOURCED) | the line under the photo, centred | Text 22.5 below |
| matched | `birthday.contribute.submit`<br>`color.global.surfaceLight`<br>`color.global.onSurfaceLight`<br>`color.global.controlRaised`<br>`color.global.onAccent` | “Add to video” (SOURCED)<br>#FFFFFF (SOURCED)<br>#000000 (SOURCED)<br>light: #CCCCCC; dark: #4D4D4D (SOURCED)<br>light: #FFFFFF; dark: #000000 (SOURCED) | C-05 on media pinned to the bottom; disabled until the line has a character; busy while sending | `PrimaryButton(surface: .media, isBusy:)` |
| matched | `birthday.contribute.offline`<br>`birthday.contribute.error.title`<br>`birthday.contribute.error.detail`<br>`birthday.contribute.error.retry` | “Check your connection and try again.” (SOURCED)<br>“Couldn't add your photo” (SOURCED)<br>“There was a problem. Please try again.” (SOURCED)<br>“Try Again” (SOURCED) | offline inline line; error C-27 block, the capsule retries | under the photo |

## Step 2a — 'Add a Message'

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `birthday.contribute.message.title`<br>`birthday.contribute.message.done`<br>`dimension.birthday.contribute.counterInset`<br>`fontSize.global.textButton` | “Add a Message” (SOURCED)<br>“Done” (SOURCED)<br>20.7 pt (SOURCED)<br>17 pt (SOURCED) | centred title, 'Done' at 20.7 from the edge | C-29 sheet (follows the appearance), C-08 `TextButton` |
| matched | `birthday.contribute.message.placeholder`<br>`dimension.birthday.contribute.messageInset`<br>`fontSize.global.placeholder` | “Add a message…” (SOURCED)<br>21.9 pt (SOURCED)<br>17 pt (SOURCED) | free text at 21.9, no fill, keyboard up | `TextField(axis: .vertical)` focused on appear |
| matched | `birthday.contribute.message.counter`<br>`layout.birthday.contribute.lineMax`<br>`dimension.birthday.contribute.counterAboveKeyboard` | “{count}/{max}” (SOURCED)<br>maxCharacters: 110 (SOURCED)<br>18.5 pt (SOURCED) | '{count}/110' bottom-right, monospaced digits, baseline 18.5 above the keyboard; input stops at 110 | MetricStack baseline gap; `normalizeLine` (unit-tested) |

## Sent

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `birthday.contribute.done.title`<br>`haptic.global.send` | “Added to video!” (SOURCED)<br>ios: notification.success; android: CONFIRM (PLATFORM) | the sheet closes, 'Added to video!', the request shows your contribution | C-26 + reload of the request |

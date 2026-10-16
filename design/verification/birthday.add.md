# Verification — `birthday.add` (iOS)

Add or manage your birthday — composition of C-33, C-12, C-05, C-08, C-14, C-10, C-29 in the age gate's order — `ios/App/Sources/Features/Memory/Birthday/ (BirthdayAddScreen, BirthdayAddModel)`.

Pass 4 (Retro redesign). Checklist written from the spec (`design/surfaces/birthday.add.md`, MERGE "Redesign — Memory (RM-*)", lead L-4 / L-5) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/memory/<surface>-<state>-<light|dark>.png` (`ios/AppTests/Memory/MemorySnapshotTests.swift`: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/birthday.add.png` next to the Retro reference(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level). Components are the Pass 3 library (`ios/App/Sources/Components`, C-01…C-35).

Retro reference(s): `references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png (LAND)`, `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png (H43)`, `references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png (ED-W3)`

Snapshots (CI): `birthday.add-loading-light.png`, `birthday.add-empty-field-light.png`, `birthday.add-empty-field-dark.png`, `birthday.add-filled-light.png`, `birthday.add-saving-light.png`, `birthday.add-invalid-light.png`, `birthday.add-error-light.png`, `birthday.add-offline-light.png`, `birthday.add-manage-light.png`, `birthday.add-manage-dark.png`

**Summary: 14 matched · 2 approximated · 0 not matched (BLOCKED or not buildable).**

## Not opted in

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `birthday.add.manage.title` | “Birthday” (SOURCED) | native back, inline title 'Birthday' | `.navigationTitle` inline in the settings stack |
| matched | `birthday.add.title`<br>`font.global.display`<br>`fontSize.global.displayMedium`<br>`color.global.textPrimary` | “Want a birthday video?” (SOURCED)<br>ios: system-serif; android: serif (PLATFORM)<br>32 pt (SOURCED)<br>light: #000000; dark: #FFFFFF (SOURCED) | serif headline, centred, screen margins | C-33 role; header trait |
| matched | `birthday.add.detail`<br>`birthday.add.privacy`<br>`fontSize.global.body`<br>`color.global.textSecondary`<br>`size.global.emptyIconToTitle`<br>`size.global.listGap` | “A week before your birthday, your groups get a private invite to add a photo and a line. On the day, you get the video.” (SOURCED)<br>“Only the day and month are shared, never your age.” (SOURCED)<br>15 pt (SOURCED)<br>#999999 (SOURCED)<br>26 pt (SOURCED)<br>22.5 pt (SOURCED) | two grey lines under the headline | MetricStack: headline baseline → detail cap top 26, detail → privacy 22.5 (C-27 measures baseline → cap top) |
| matched | `size.global.emptyTitleToAction`<br>`auth.agegate.field.placeholder`<br>`size.global.fieldHeight`<br>`radius.global.field`<br>`color.global.control`<br>`fontSize.global.placeholder` | 25 pt (SOURCED)<br>“{date_format}” (SOURCED)<br>52 pt (SOURCED)<br>19 pt (SOURCED)<br>light: #F1F1F1; dark: #262626 (SOURCED)<br>17 pt (SOURCED) | the age gate's date field (C-12), 25 below, full width inside the margins | C-12 `FormField` + account's `BirthdayEntry` (locale order, separators, no default year) |
| matched | `birthday.add.invalid`<br>`fontSize.global.meta`<br>`color.global.destructive` | “Invalid date” (SOURCED)<br>13 pt (SOURCED)<br>#EA3337 (SOURCED) | C-12 inline error | FormField errorMessage |
| matched | `birthday.add.offline` | “Check your connection and try again.” (SOURCED) | offline: inline line under the field (meta, grey) | Text under the field |
| matched | `birthday.add.confirm`<br>`color.global.accent`<br>`color.global.onAccent`<br>`size.global.buttonHeight`<br>`size.global.buttonMarginH`<br>`radius.global.button`<br>`fontSize.global.button`<br>`color.global.controlRaised`<br>`duration.global.crossfade` | “Add my birthday” (SOURCED)<br>light: #000000; dark: #FFFFFF (SOURCED)<br>light: #FFFFFF; dark: #000000 (SOURCED)<br>60 pt (SOURCED)<br>20 pt (SOURCED)<br>30 pt (SOURCED)<br>17 pt (SOURCED)<br>light: #CCCCCC; dark: #4D4D4D (SOURCED)<br>100 ms (SOURCED) | capsule pinned to the bottom, disabled until the date is complete; busy while saving | C-05 `PrimaryButton` in `.safeAreaInset(edge: .bottom)`; cross-fade on enable |
| matched | `birthday.add.later`<br>`fontSize.global.listTitle` | “Maybe later” (SOURCED)<br>15 pt (SOURCED) | secondary link 'Maybe later' → pops, never asked again | C-08 `TextButton(.link)` |
| matched | `birthday.add.error.title`<br>`birthday.add.error.detail`<br>`birthday.add.error.retry` | “Something went wrong” (SOURCED)<br>“There was a problem. Please try again.” (SOURCED)<br>“Try Again” (SOURCED) | error: C-27 block above the capsule; the capsule retries | EmptyStateView + capsule label switch |
| matched | `birthday.add.added`<br>`haptic.global.success`<br>`haptic.global.error` | “Saved!” (SOURCED)<br>ios: notification.success; android: CONFIRM (PLATFORM)<br>ios: notification.error; android: REJECT (PLATFORM) | added → presenter's toast, pop | onFinish(.added) (RootView `BirthdayAddRoute` shows it via C-26) |

## Opted in (manage)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| approximated | `layout.birthday.add.dateFormat`<br>`radius.global.groupedRow`<br>`color.global.control`<br>`fontSize.global.body` | pattern: MMMM d; example: July 5; ios: Date.FormatStyle().month(.wide).day(); android: DateFormat.getBestDateTimePattern(locale, "MMMMd") (SOURCED)<br>12 pt (SOURCED)<br>light: #F1F1F1; dark: #262626 (SOURCED)<br>15 pt (SOURCED) | C-14 row 'Birthday' with the value 'July 5' (no year) | `MemoryValueRow`: C-14's look with a trailing value — `GroupedRow` has no value accessory (component gap) |
| matched | `birthday.add.detail`<br>`fontSize.global.meta` | “A week before your birthday, your groups get a private invite to add a photo and a line. On the day, you get the video.” (SOURCED)<br>13 pt (SOURCED) | detail as the section footer | Text under the group at the rows' text inset |
| matched | `birthday.add.manage.remove`<br>`color.global.destructive` | “Remove Birthday” (SOURCED)<br>#EA3337 (SOURCED) | separate group: destructive row | C-14 `GroupedSection` + `GroupedRow(role: .destructive)` |
| matched | `birthday.add.remove.title`<br>`birthday.add.remove.message`<br>`birthday.add.remove.confirm`<br>`birthday.add.remove.cancel`<br>`birthday.add.removed`<br>`haptic.global.warning` | “Remove your birthday?” (SOURCED)<br>“Your groups won't be asked to make you a birthday video” (SOURCED)<br>“Yes, remove” (SOURCED)<br>“Cancel” (SOURCED)<br>“Removed” (SOURCED)<br>ios: notification.warning; android: CONFIRM (PLATFORM) | native confirmation → removed toast → not-opted-in state | `.alert`; optimistic, reverted with the error on failure |
| approximated | `size.global.sectionGap` | 36.4 pt (SOURCED) | spacing between the two groups | not specified — the section gap token |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `—` | — (no token) | loading (reading profile_private) | C-28 `LoadingHUD` centred |

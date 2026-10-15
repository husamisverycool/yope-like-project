# Verification — `birthday.add` (iOS)

Add / manage your birthday for tributes (opened from the settings row) — `ios/App/Sources/Features/Memory/Birthday/BirthdayAdd*.swift, BirthdayDateField.swift`.

Checklist written from the spec (`design/surfaces/birthday.add.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/memory/<surface>-<state>.png` (`ios/AppTests/Memory/MemorySnapshotTests.swift`), then `tools/sidebyside.py` makes `design/verification/birthday.add.png` next to the reference image(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level).

Reference image(s): `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png`, `references/auto/yope/frames/a-virgi-7686278541255642390-t31.23-signup-es.png`, `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t45.23-new-group-empty.png`

Snapshots (CI): `birthday.add-loading.png`, `birthday.add-empty-field.png`, `birthday.add-filled.png`, `birthday.add-saving.png`, `birthday.add-invalid.png`, `birthday.add-error.png`, `birthday.add-offline.png`, `birthday.add-manage.png`, `birthday.add-removed-toast.png`

**Summary: 13 matched · 4 approximated · 1 not matched (BLOCKED or not buildable).**

## Add (not opted in)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `size.global.headerButton`<br>`size.global.headerInset`<br>`color.global.controlOnDeep`<br>`icon.global.close`<br>`birthday.add.a11y.close` | 44 pt (SOURCED)<br>11.5 pt (SOURCED)<br>#101010 (SOURCED)<br>ios: xmark; android: Rounded.Close (PLATFORM)<br>“Close” (PLATFORM) | close circle top-left | MemoryHeaderCircle → ‘maybe later’ outcome |
| matched | `birthday.add.title`<br>`fontSize.global.onboardingTitle`<br>`fontWeight.global.onboardingTitle`<br>`color.global.textPrimary`<br>`size.global.buttonMarginH` | “want a birthday video?” (SOURCED)<br>40 pt (SOURCED)<br>heavy (SOURCED)<br>#FFFFFF (SOURCED)<br>19 pt (SOURCED) | title, centred, margins 19 | DSTextStyle (largeTitle); header trait |
| matched | `size.global.listGap`<br>`birthday.add.detail`<br>`birthday.add.privacy`<br>`fontSize.global.listSubtitle`<br>`fontWeight.global.listSubtitle`<br>`color.global.textSecondary` | 7.5 pt (SOURCED)<br>“a week before your birthday, your groups get asked for a pic & a line. on the day, you get the video” (SOURCED)<br>“only the day & month are shared, never your age” (SOURCED)<br>14 pt (SOURCED)<br>regular (SOURCED)<br>#969696 (SOURCED) | detail + privacy lines 7.5 apart | VStack(spacing: listGap) |
| approximated | `auth.agegate.layout.dateEntry`<br>`groups.create.color.field`<br>`size.global.fieldHeight`<br>`radius.global.field`<br>`groups.create.fontSize.fieldText`<br>`groups.create.fontWeight.fieldText`<br>`auth.agegate.field.placeholder`<br>`auth.agegate.field.accessibilityLabel` | control: the Yope form field (groups.create.color.field, size.global.fieldHeight, radius.global.field, groups.create.fontSize.fieldText) … (VERIFIED)<br>#141414 (SOURCED)<br>44 pt (SOURCED)<br>12 pt (SOURCED)<br>15 pt (SOURCED)<br>bold (SOURCED)<br>“birthday ({date_format})” (SOURCED)<br>“birthday” (SOURCED) | the auth.agegate birthday field | built locally (BirthdayDateField) from the same tokens: numeric keyboard, separators in the locale's order, empty, no default year; gap above it = listGap (not specified) |
| matched | `birthday.add.confirm`<br>`color.global.accent`<br>`color.global.onAccent`<br>`size.global.buttonHeight`<br>`radius.global.button`<br>`fontSize.global.button`<br>`fontWeight.global.button` | “add my birthday” (SOURCED)<br>#CDFD07 (SOURCED)<br>#000000 (SOURCED)<br>45 pt (SOURCED)<br>14 pt (SOURCED)<br>15 pt (SOURCED)<br>semibold (SOURCED) | primary, pinned to the bottom (safe area + 19) | MemoryFilledButton.yopePrimary; disabled until a complete date |
| approximated | `—` | — (no token) | disabled look | platform disabled state of the plain button style (Yope's groups.create disabled colours not used — not named by this spec) |
| matched | `birthday.add.later`<br>`color.global.surfaceLight`<br>`color.global.onSurfaceLight`<br>`radius.global.capsule` | “maybe later” (SOURCED)<br>#FFFFFF (SOURCED)<br>#000000 (SOURCED)<br>shape: capsule; radius: height / 2 (SOURCED) | ‘maybe later’ pill 7.5 below | no call; closes; never asked again |

## Manage (opted in)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `birthday.add.manage.title`<br>`fontSize.global.sheetTitle`<br>`fontWeight.global.sheetTitle` | “your birthday” (SOURCED)<br>19.5 pt (SOURCED)<br>bold (SOURCED) | title | DSTextStyle (title3) |
| matched | `layout.birthday.add.dateFormat`<br>`fontSize.global.listTitle`<br>`fontWeight.global.listTitle` | pattern: d MMMM; example: 26 May (SOURCED)<br>17.5 pt (SOURCED)<br>bold (SOURCED) | ‘26 May’ — day and month only | DateFormatter with the token pattern (unit-tested) |
| matched | `birthday.add.manage.remove` | “remove my birthday” (SOURCED) | remove pill | optimistic: the add form shows at once, rolls back with the error state on failure |

## States and feedback

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `easing.global.native` | keyboard: system; alert: system; activityIndicator: system (ProgressView / CircularProgressIndicator); scrollIndicator: system; navigatio… (PLATFORM) | saving: indicator in the primary, buttons disabled | ProgressView in place of the label |
| matched | `birthday.add.invalid` | “that date doesn't look right” (SOURCED) | invalid_birthday / impossible date under the field | inline listSubtitle line |
| matched | `birthday.add.error.title`<br>`birthday.add.error.detail`<br>`birthday.add.error.retry` | “couldn't save your birthday” (SOURCED)<br>“try again in a moment” (SOURCED)<br>“try again” (SOURCED) | error above the buttons; primary becomes retry | MemoryStateMessage + label swap |
| matched | `birthday.add.offline` | “you're offline — connect to add your birthday” (SOURCED) | offline under the field | inline line |
| approximated | `—` | — (no token) | loading (not in the spec) | platform indicator while profile_private is read the first time; cached opt-in state afterwards |
| not matched | `birthday.add.added` | “birthday added” (SOURCED) | toast ‘birthday added’, then close | toast dwell BLOCKED: the screen closes with a VoiceOver announcement and onFinish(.added) for the presenter's toast |
| approximated | `birthday.add.removed` | “birthday removed” (SOURCED) | toast after remove | DEBUG builds draw the foundations toast until tapped; release announces it (dwell BLOCKED, MemoryBlocked.toastDwell) |
| matched | `haptic.global.success`<br>`haptic.global.error` | ios: notification.success; android: CONFIRM (PLATFORM)<br>ios: notification.error; android: REJECT (PLATFORM) | add / remove succeeded; failed | dependencies.haptics (unit-tested) |

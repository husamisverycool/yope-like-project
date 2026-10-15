# Verification — `birthday.request` (iOS)

Private request to add a photo and one line (sheet from the group row; pushed from the push) — `ios/App/Sources/Features/Memory/Birthday/BirthdayRequest*.swift`.

Checklist written from the spec (`design/surfaces/birthday.request.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/memory/<surface>-<state>.png` (`ios/AppTests/Memory/MemorySnapshotTests.swift`), then `tools/sidebyside.py` makes `design/verification/birthday.request.png` next to the reference image(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level).

Reference image(s): `references/auto/tribute/web/tribute-web-testimonials-contribution-page-viewport.png`, `references/auto/tribute/web/tribute-web-ayejaye-contribution-page-viewport.png`, `references/auto/tribute/mockups/tribute-home-phone-step-1-contribution-page.png`, `references/auto/vidday/store/vidday-store-01.png`, `references/auto/vidday/frames/vidday-tour-t064-phone.png`

Snapshots (CI): `birthday.request-loading.png`, `birthday.request-open.png`, `birthday.request-contributed.png`, `birthday.request-closed.png`, `birthday.request-not-found.png`, `birthday.request-error.png`, `birthday.request-offline.png`, `birthday.request-entry.png`

**Summary: 17 matched · 2 approximated · 0 not matched (BLOCKED or not buildable).**

## Hero

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `dimension.birthday.request.hero.height`<br>`opacity.birthday.request.hero.image`<br>`color.global.backgroundDeep` | 365.8 pt (VERIFIED)<br>0.7 (VERIFIED)<br>#000000 (SOURCED) | hero 365.8 (minimum), honoree photo at 0.7 over black | background ZStack; grows with the text |
| matched | `size.global.headerButton`<br>`size.global.headerInset`<br>`color.global.controlOnDeep`<br>`icon.global.close`<br>`birthday.request.a11y.close` | 44 pt (SOURCED)<br>11.5 pt (SOURCED)<br>#101010 (SOURCED)<br>ios: xmark; android: Rounded.Close (PLATFORM)<br>“Close” (PLATFORM) | close top-left in the safe area | MemoryHeaderCircle; first in focus order |
| matched | `birthday.request.title`<br>`fontSize.birthday.request.title`<br>`fontWeight.birthday.request.title`<br>`lineHeight.birthday.request.title`<br>`font.birthday`<br>`dimension.birthday.request.margin` | “Birthday Video for {name}!” (SOURCED)<br>24 pt (VERIFIED)<br>semibold (VERIFIED)<br>28.8 pt (VERIFIED)<br>ios: system; android: system (PLATFORM)<br>15 pt (VERIFIED) | title, left at 15 | DSTextStyle (title2), header trait |
| approximated | `dimension.birthday.request.title.top` | 84 pt (VERIFIED) | title 84 from the hero top (below the safe area when taller) | max(84, safe top + header circle) so the title clears the close circle when pushed full screen |
| matched | `birthday.request.due`<br>`layout.birthday.request.dueDate`<br>`fontSize.birthday.request.message`<br>`lineHeight.birthday.request.message`<br>`opacity.birthday.request.message` | “Submit by {date}” (SOURCED)<br>style: full date: weekday, month day, year; example: Wednesday, December 31, 2025; value: the day before tribute_requests.birthday_date (… (SOURCED)<br>16 pt (VERIFIED)<br>28 pt (VERIFIED)<br>0.9 (VERIFIED) | due line: the day before the birthday, full date | Date.FormatStyle(date: .complete) in UTC on the calendar day (unit-tested) |
| matched | `birthday.request.body`<br>`birthday.request.ease`<br>`birthday.request.thanks`<br>`dimension.birthday.request.message.gap` | “You're invited to submit a photo and join in on the fun of making a birthday video for {name}.” (SOURCED)<br>“It's quick and easy.” (SOURCED)<br>“Thank you!” (SOURCED)<br>20.8 pt (VERIFIED) | message paragraph 20.8 below | three strings joined with spaces |

## Button / own contribution

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `birthday.request.cta`<br>`dimension.birthday.request.cta.gap`<br>`dimension.birthday.request.cta.height`<br>`radius.birthday.request.cta`<br>`fontSize.birthday.request.cta`<br>`fontWeight.birthday.request.cta`<br>`color.global.accent`<br>`color.global.onAccent` | “Add Your Photo” (VERIFIED)<br>15 pt (VERIFIED)<br>62 pt (VERIFIED)<br>8 pt (VERIFIED)<br>22 pt (VERIFIED)<br>semibold (VERIFIED)<br>#CDFD07 (SOURCED)<br>#000000 (SOURCED) | ‘Add Your Photo’ 62 high, r8, 15 below the hero | MemoryFilledButton → birthday.contribute (full screen) |
| matched | `birthday.request.contributed.title`<br>`fontSize.birthday.contribute.label`<br>`fontWeight.birthday.contribute.label`<br>`radius.global.photo` | “Your Photo” (VERIFIED)<br>16 pt (VERIFIED)<br>semibold (VERIFIED)<br>15 pt (SOURCED) | own block heading + photo (content width) | display rendition at its stored aspect (no jump) |
| matched | `birthday.request.contributed.change`<br>`birthday.request.contributed.remove`<br>`dimension.birthday.tribute.button.height`<br>`dimension.birthday.tribute.button.gap`<br>`radius.birthday.tribute.button`<br>`color.global.surfaceLight`<br>`color.birthday.tribute.button.label`<br>`fontSize.birthday.tribute.button`<br>`fontWeight.birthday.tribute.button` | “Retake” (SOURCED)<br>“Remove” (SOURCED)<br>44 pt (VERIFIED)<br>10 pt (VERIFIED)<br>8 pt (VERIFIED)<br>#FFFFFF (SOURCED)<br>#292D34 (VERIFIED)<br>14 pt (VERIFIED)<br>semibold (VERIFIED) | Retake / Remove stacked 10 apart | Remove is optimistic with rollback (unit-tested) |
| approximated | `—` | — (no token) | spacing inside the own block | platform default stack spacing (not specified) |

## Message Ideas

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `birthday.request.prompts.title`<br>`color.birthday.request.prompts.header`<br>`dimension.birthday.request.prompts.headerHeight`<br>`dimension.birthday.request.prompts.headerPadding`<br>`radius.birthday.request.prompts`<br>`fontSize.birthday.request.prompts.header`<br>`fontWeight.birthday.request.prompts.header` | “Message Ideas” (SOURCED)<br>#292D34 (VERIFIED)<br>42 pt (VERIFIED)<br>24 pt (VERIFIED)<br>8 pt (VERIFIED)<br>15 pt (VERIFIED)<br>medium (VERIFIED) | header bar 42 high, top corners 8, label padded 24 | MemoryMessageIdeas (UnevenRoundedRectangle) |
| matched | `birthday.request.prompt.appreciate`<br>`birthday.request.prompt.impact`<br>`dimension.birthday.request.prompt.indent`<br>`dimension.birthday.request.prompt.top`<br>`dimension.birthday.request.prompt.gap`<br>`fontSize.birthday.request.prompt`<br>`lineHeight.birthday.request.prompt`<br>`dimension.birthday.request.prompts.gap` | “What do you appreciate most about {name}?” (SOURCED)<br>“How has {name} impacted your life?” (SOURCED)<br>39 pt (VERIFIED)<br>24 pt (VERIFIED)<br>19.9 pt (VERIFIED)<br>15 pt (VERIFIED)<br>18.75 pt (VERIFIED)<br>20 pt (VERIFIED) | two bulleted prompts, text indented 39, 24 below the bar, 19.9 apart | bullet centred in the indent |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `birthday.request.loading` | “Loading” (SOURCED) | loading: black hero, indicator | no text in the hero until loaded (no ‘for !’ flash) |
| matched | `birthday.request.closed.title`<br>`birthday.request.closed.detail` | “this request has closed” (SOURCED)<br>“{name}'s video is on its way” (SOURCED) | closed: hero + title stay, rest replaced | never ‘late’ or ‘missed’ |
| matched | `birthday.request.notFound.title`<br>`birthday.request.notFound.detail` | “this request isn't available anymore” (SOURCED)<br>“your memories are waiting” (SOURCED) | not found (incl. the honoree: never sees a request about them) | unit-tested |
| matched | `birthday.request.error.title`<br>`birthday.request.error.detail`<br>`birthday.request.error.retry` | “couldn't load this request” (SOURCED)<br>“try again in a moment” (SOURCED)<br>“try again” (SOURCED) | error + retry pill | MemoryStateMessage |
| matched | `birthday.request.offline` | “you're offline — connect to see this request” (SOURCED) | offline line under the hero | also shown over cached content when a refresh fails |
| matched | `haptic.global.success`<br>`haptic.global.error` | ios: notification.success; android: CONFIRM (PLATFORM)<br>ios: notification.error; android: REJECT (PLATFORM) | remove succeeded / failed | unit-tested |

## Entry (groups.screen)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `birthday.request.title`<br>`birthday.request.due` | “Birthday Video for {name}!” (SOURCED)<br>“Submit by {date}” (SOURCED) | one row per open request of the group | BirthdayRequestsEntry; sheet .presentationDetents([.large]); no ‘not contributed’ badge |

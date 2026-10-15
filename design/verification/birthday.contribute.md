# Verification — `birthday.contribute` (iOS)

Pick a photo you posted or are in, write one line, send (full screen over the request) — `ios/App/Sources/Features/Memory/Birthday/BirthdayContribute*.swift`.

Checklist written from the spec (`design/surfaces/birthday.contribute.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/memory/<surface>-<state>.png` (`ios/AppTests/Memory/MemorySnapshotTests.swift`), then `tools/sidebyside.py` makes `design/verification/birthday.contribute.png` next to the reference image(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level).

Reference image(s): `references/auto/tribute/web/tribute-web-testimonials-upload-step1-info.png`, `references/auto/vidday/frames/vidday-tour-t102-phone.png`

Snapshots (CI): `birthday.contribute-loading.png`, `birthday.contribute-photo.png`, `birthday.contribute-photo-selected.png`, `birthday.contribute-message.png`, `birthday.contribute-message-filled.png`, `birthday.contribute-sending.png`, `birthday.contribute-done.png`, `birthday.contribute-not-eligible.png`, `birthday.contribute-error.png`, `birthday.contribute-offline.png`, `birthday.contribute-empty.png`, `birthday.contribute-closed.png`, `birthday.contribute-load-error.png`

**Summary: 22 matched · 5 approximated · 0 not matched (BLOCKED or not buildable).**

## Header and stepper

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `size.global.headerButton`<br>`size.global.headerInset`<br>`color.global.controlOnDeep`<br>`icon.global.close`<br>`icon.global.back`<br>`birthday.contribute.a11y.close` | 44 pt (SOURCED)<br>11.5 pt (SOURCED)<br>#101010 (SOURCED)<br>ios: xmark; android: Rounded.Close (PLATFORM)<br>ios: chevron.left; android: AutoMirrored.Rounded.KeyboardArrowLeft (PLATFORM)<br>“Close” (PLATFORM) | ✕ on steps 1 and 3, ‹ on step 2 | MemoryHeaderCircle |
| approximated | `—` | — (no token) | ‹ VoiceOver label (‘the platform back label’) | groups.screen.back.accessibilityLabel (no memory key; no platform string API) |
| approximated | `layout.birthday.contribute.stepper` | steps: 3; labels: Photo, Message, Done; distribution: first circle 11 pt inside the margin, last circle 11 pt inside the opposite margin,… (VERIFIED) | 3 circles, first / last 11 inside the margins, middle centred, captions 10 below | the 11-pt inset exists only inside the token's text; read from it (ContributeStepperMetrics, unit-tested) |
| matched | `dimension.birthday.contribute.stepper.circle`<br>`color.birthday.contribute.stepper.active`<br>`color.birthday.contribute.stepper.inactive`<br>`color.birthday.contribute.stepper.inactiveLabel`<br>`fontSize.birthday.contribute.stepper.number`<br>`fontWeight.birthday.contribute.stepper.number`<br>`fontSize.birthday.contribute.stepper.label`<br>`fontWeight.birthday.contribute.stepper.labelActive`<br>`fontWeight.birthday.contribute.stepper.label` | 40 pt (VERIFIED)<br>#B8B9B9 (VERIFIED)<br>#FFFFFF38 (VERIFIED)<br>#FFFFFF8C (VERIFIED)<br>14 pt (VERIFIED)<br>semibold (VERIFIED)<br>10 pt (VERIFIED)<br>medium (VERIFIED)<br>regular (VERIFIED) | circle 40; current / other fills and labels | one accessibility element labelled with the current caption |
| matched | `birthday.contribute.step.photo`<br>`birthday.contribute.step.message`<br>`birthday.contribute.step.done` | “Photo” (VERIFIED)<br>“Message” (SOURCED)<br>“Done” (VERIFIED) | captions | Copy |

## Step 1 — Photo

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `birthday.contribute.greeting`<br>`fontSize.birthday.contribute.heading`<br>`fontWeight.birthday.contribute.heading`<br>`dimension.birthday.contribute.heading.gap` | “Let's add a photo for {name}!” (VERIFIED)<br>20 pt (VERIFIED)<br>medium (VERIFIED)<br>107 pt (VERIFIED) | heading 107 below the captions | kept invisible until the name is known (no jump) |
| matched | `birthday.contribute.thanks`<br>`fontSize.birthday.contribute.subheading`<br>`opacity.birthday.contribute.subheading`<br>`dimension.birthday.contribute.subheading.gap` | “Thank you for taking the time to participate!” (VERIFIED)<br>16 pt (VERIFIED)<br>0.72 (VERIFIED)<br>12 pt (VERIFIED) | sub-heading 12 below, white 0.72 | weight not measured → platform regular |
| matched | `walls.mine.count.gridColumns`<br>`walls.mine.dimension.gridGap`<br>`walls.mine.aspectRatio.gridTile`<br>`radius.global.photo`<br>`dimension.birthday.contribute.group.gap` | 3 (SOURCED)<br>4 pt (SOURCED)<br>width: 115.3; height: 158.5 (SOURCED)<br>15 pt (SOURCED)<br>16 pt (VERIFIED) | Yope wall grid of eligible photos only (posted by you ∪ self-tagged), newest first | LazyVGrid; unit- and UI-tested |
| matched | `icon.global.check`<br>`icon.global.uncheck`<br>`color.global.selection`<br>`size.global.checkCircle`<br>`birthday.contribute.a11y.photo` | ios: checkmark.circle.fill; android: Rounded.CheckCircle (PLATFORM)<br>ios: circle; android: Rounded.RadioButtonUnchecked (PLATFORM)<br>#0091FF (PLATFORM)<br>24 pt (SOURCED)<br>“Photo from {date}” (PLATFORM) | selection check top-right, single choice | selected trait; select haptic |
| approximated | `—` | — (no token) | check inset in the cell / VoiceOver date | grid gap as inset (not specified); platform long date for {date} |
| matched | `birthday.contribute.review.use` | “Use Photo” (SOURCED) | ‘Use Photo’ pinned to the bottom, enabled once selected | contribute button style |

## Step 2 — Message

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `radius.global.photo` | 15 pt (SOURCED) | chosen photo, content width, aspect kept | display rendition |
| matched | `birthday.contribute.line.label`<br>`fontSize.birthday.contribute.label`<br>`fontWeight.birthday.contribute.label`<br>`dimension.birthday.contribute.label.gap` | “Your Message” (VERIFIED)<br>16 pt (VERIFIED)<br>semibold (VERIFIED)<br>10 pt (VERIFIED) | label + field 10 below | Text + TextField(axis: .vertical), field labelled for VoiceOver |
| matched | `dimension.birthday.contribute.input.height`<br>`radius.birthday.contribute.input`<br>`color.birthday.contribute.input.fill`<br>`color.birthday.contribute.input.text`<br>`fontSize.birthday.contribute.input` | 46 pt (VERIFIED)<br>8 pt (VERIFIED)<br>#FFFFFF14 (VERIFIED)<br>#E7E8E8EB (VERIFIED)<br>16 pt (VERIFIED) | field 46 (grows), r8, white 0.08 fill, no placeholder | return key = done (newline ends entry) |
| matched | `layout.birthday.contribute.lineMax` | maxCharacters: 110 (SOURCED) | line stops at 110 characters, no visible counter (API 280 stays the server check) | BirthdayContributeModel.normalizeLine() after each edit: removes a typed return (ends editing) and cuts at maxCharacters (unit-tested) |
| matched | `birthday.request.prompts.title`<br>`birthday.request.prompt.appreciate`<br>`birthday.request.prompt.impact` | “Message Ideas” (SOURCED)<br>“What do you appreciate most about {name}?” (SOURCED)<br>“How has {name} impacted your life?” (SOURCED) | Message Ideas as on the request | MemoryMessageIdeas |
| matched | `birthday.contribute.submit`<br>`dimension.birthday.contribute.button.gap`<br>`dimension.birthday.contribute.button.height`<br>`radius.birthday.contribute.button`<br>`fontSize.birthday.contribute.button`<br>`fontWeight.birthday.contribute.button`<br>`color.global.accent`<br>`color.global.onAccent` | “Submit” (SOURCED)<br>24 pt (VERIFIED)<br>50 pt (VERIFIED)<br>8 pt (VERIFIED)<br>16 pt (VERIFIED)<br>semibold (VERIFIED)<br>#CDFD07 (SOURCED)<br>#000000 (SOURCED) | Submit 24 below, 50 high, disabled until a non-space character | platform disabled state |
| matched | `birthday.contribute.review.retake`<br>`color.global.surfaceLight`<br>`color.global.onSurfaceLight` | “Retake” (SOURCED)<br>#FFFFFF (SOURCED)<br>#000000 (SOURCED) | Retake → step 1 (selection kept) |  |

## Step 3 — Done and states

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `birthday.contribute.done.title`<br>`birthday.contribute.done.button`<br>`fontSize.birthday.request.message` | “Photo Upload Complete!” (SOURCED)<br>“Done” (VERIFIED)<br>16 pt (VERIFIED) | heading, photo + line, Done → request | request reloads its own block on close |
| approximated | `—` | — (no token) | sending: indicator on Submit | optimistic (lead's bar): step 3 shows at once and its Done button carries the platform indicator until the call answers; failures roll back with the spec's lines |
| matched | `birthday.contribute.loading` | “Loading” (SOURCED) | loading under the thanks line | first frame already shows it |
| matched | `birthday.contribute.picker.empty.title`<br>`birthday.contribute.picker.empty.detail`<br>`birthday.contribute.picker.empty.action` | “no pics with you in {group} yet” (SOURCED)<br>“tap “i'm in this” on a pic you're in, or share a new one” (SOURCED)<br>“open group” (SOURCED) | no eligible photo: Yope empty state → open group | openGroup closes the request too |
| approximated | `birthday.contribute.notEligible` | “you can only pick pics you posted or are in” (SOURCED) | post_not_eligible: line under the field, back to step 1 | the line shows on step 1 (where the person lands) |
| matched | `birthday.contribute.closed` | “this request has closed — {name}'s video is on its way” (SOURCED) | tribute_closed replaces the steps |  |
| matched | `birthday.contribute.error.title`<br>`birthday.contribute.error.detail`<br>`birthday.contribute.error.retry` | “couldn't send your photo” (SOURCED)<br>“try again in a moment” (SOURCED)<br>“try again” (SOURCED) | error under Submit; Submit retries | label switches to ‘try again’ |
| matched | `birthday.contribute.offline` | “you're offline — connect to send your photo” (SOURCED) | offline under Submit |  |
| matched | `haptic.global.select`<br>`haptic.global.send`<br>`haptic.global.error` | ios: selection; android: SEGMENT_TICK (PLATFORM)<br>ios: notification.success; android: CONFIRM (PLATFORM)<br>ios: notification.error; android: REJECT (PLATFORM) | select / sent / failed | unit-tested |

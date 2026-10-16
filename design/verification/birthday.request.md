# Verification — `birthday.request` (iOS)

Private request to add a photo and one line — composition of C-34, C-11, C-23, C-05, C-06, C-10, C-15, C-27, C-29 in Tribute / VidDay's order — `ios/App/Sources/Features/Memory/Birthday/ (BirthdayRequestScreen, BirthdayRequestModel, BirthdayRequestsEntry)`.

Pass 4 (Retro redesign). Checklist written from the spec (`design/surfaces/birthday.request.md`, MERGE "Redesign — Memory (RM-*)", lead L-4 / L-5) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/memory/<surface>-<state>-<light|dark>.png` (`ios/AppTests/Memory/MemorySnapshotTests.swift`: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/birthday.request.png` next to the Retro reference(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level). Components are the Pass 3 library (`ios/App/Sources/Components`, C-01…C-35).

Retro reference(s): `references/auto/retro/lazyweb/retro-lazyweb-20260529-paywall.png (PAY)`, `references/auto/retro/press/tc-2023-12-retro3.png phone 1`

Snapshots (CI): `birthday.request-loading-light.png`, `birthday.request-open-light.png`, `birthday.request-open-dark.png`, `birthday.request-contributed-light.png`, `birthday.request-contributed-dark.png`, `birthday.request-closed-light.png`, `birthday.request-not-found-light.png`, `birthday.request-error-light.png`, `birthday.request-offline-light.png`, `birthday.request-entry-light.png`, `birthday.request-entry-dark.png`

**Summary: 20 matched · 3 approximated · 0 not matched (BLOCKED or not buildable).**

## Page

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `layout.global.materials`<br>`size.global.backdropBlur`<br>`color.global.backdropDim`<br>`color.global.backgroundDeep` | glass: only over photos or colour (color.global.glass); backdrop: full-screen blurred, colour-rich version of the photo behind a card (re… (SOURCED)<br>1.8 pt (SOURCED)<br>#00000039 (SOURCED)<br>#000000 (SOURCED) | the honoree's photo blurred over the screen (dark in both); none → black | C-34 `BlurredBackdrop` in the dark appearance |
| matched | `size.global.circleButtonSmall`<br>`color.global.glass`<br>`icon.global.close`<br>`dimension.birthday.request.close.inset`<br>`dimension.birthday.request.close.centerY`<br>`birthday.request.a11y.close` | 32 pt (SOURCED)<br>#FFFFFF1F (SOURCED)<br>ios: xmark; android: Rounded.Close (PLATFORM)<br>26.2 pt (SOURCED)<br>21.8 pt (SOURCED)<br>“Close” (PLATFORM) | glass close 32, right edge 26.2 in, centre 21.8 below the safe-area top | C-11 `.glassSmall` |
| approximated | `—` | — (no token) | close glyph ≈ 9.7 pt | no glyph token: `size.global.iconSmall` box (component gap) |
| matched | `size.global.avatarProfile`<br>`size.global.emptyIconToTitle` | 64 pt (SOURCED)<br>26 pt (SOURCED) | avatar 64, headline 26 below | C-23 + MetricStack `.bottom → .capTop` |
| matched | `birthday.request.title`<br>`font.global.display`<br>`fontSize.global.displayMedium`<br>`color.global.textOnMedia`<br>`size.global.buttonMarginH` | “{name}'s birthday video” (SOURCED)<br>ios: system-serif; android: serif (PLATFORM)<br>32 pt (SOURCED)<br>#FFFFFF (SOURCED)<br>20 pt (SOURCED) | serif headline, centred | header trait |
| matched | `birthday.request.body`<br>`fontSize.global.textButton`<br>`dimension.birthday.request.headlineToMessage` | “You're invited to add a photo and one line for {name}'s birthday video — no pressure.” (SOURCED)<br>17 pt (SOURCED)<br>19.3 pt (SOURCED) | invitation, cap top 19.3 below the headline | `.lastBaseline → .capTop` |
| matched | `—` | — (no token) | block anchored to the bottom; scrolls at large sizes | ScrollView with min height, bottom alignment |

## Card (C-34 plan card)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `color.global.surfaceElevated`<br>`radius.global.cardLarge`<br>`size.global.planCardPadding`<br>`dimension.birthday.request.messageToCard` | light: #FFFFFF; dark: #181818 (SOURCED)<br>36 pt (SOURCED)<br>27 pt (SOURCED)<br>29 pt (SOURCED) | card 29 below the invitation, follows the appearance | background on the system appearance (not forced dark) |
| matched | `birthday.request.prompts.title`<br>`fontSize.birthday.request.cardTitle`<br>`fontWeight.birthday.request.cardTitle` | “Message ideas” (SOURCED)<br>24 pt (SOURCED)<br>bold (SOURCED) | 'Message ideas' 24 bold | DSTextStyle scaled with the displaySmall text style (title2) |
| matched | `birthday.request.card.detail`<br>`dimension.birthday.request.card.titleToDetail` | “Pick a photo you posted or are in, then add one line.” (SOURCED)<br>11 pt (SOURCED) | grey line 11 below the title's baseline | `.lastBaseline → .capTop` |
| approximated | `dimension.birthday.request.card.blockGap`<br>`dimension.birthday.request.card.rowPitch` | 29.3 pt (SOURCED)<br>32 pt (SOURCED) | detail → prompts → capsule 29.3; rows 32 apart | block gap from text bottom to the next top; rows baseline to baseline (centres of single-line rows) |
| matched | `dimension.birthday.request.card.marker`<br>`dimension.birthday.request.card.markerGap`<br>`color.global.accent`<br>`color.global.onAccent`<br>`fontSize.global.badge`<br>`birthday.request.prompt.appreciate`<br>`birthday.request.prompt.impact` | 17.3 pt (SOURCED)<br>5 pt (SOURCED)<br>light: #000000; dark: #FFFFFF (SOURCED)<br>light: #FFFFFF; dark: #000000 (SOURCED)<br>11 pt (SOURCED)<br>“What do you appreciate most about {name}?” (SOURCED)<br>“How has {name} impacted your life?” (SOURCED) | numbered markers 17.3 on the first line's cap middle, 5 to the text; text wraps under itself | overlay on the `.capMiddle` guide; markers hidden from VoiceOver |
| matched | `birthday.request.cta`<br>`size.global.screenMargin` | “Add your photo” (SOURCED)<br>16 pt (SOURCED) | C-05 'Add your photo', 16 from the card sides and bottom | PrimaryButton with the card padding offset |
| matched | `birthday.request.contributed.title`<br>`size.global.rowThumbWidth`<br>`size.global.rowThumbHeight`<br>`radius.global.thumbnail`<br>`size.global.rowThumbGap` | “You added a photo” (SOURCED)<br>72 pt (SOURCED)<br>97 pt (SOURCED)<br>4 pt (SOURCED)<br>17 pt (SOURCED) | after contributing: thumbnail with your line beside it | C-15 geometry |
| matched | `birthday.request.contributed.change`<br>`birthday.request.contributed.remove`<br>`size.global.pillGap` | “Change photo” (SOURCED)<br>“Remove” (SOURCED)<br>8.8 pt (SOURCED) | outline 'Change photo' + red 'Remove' side by side | C-06 `CapsuleButton(.outline)` + C-10 `DestructiveButton` |
| matched | `birthday.request.remove.title`<br>`birthday.request.remove.message`<br>`birthday.request.remove.confirm`<br>`birthday.request.remove.cancel`<br>`birthday.request.removed`<br>`haptic.global.warning`<br>`haptic.global.success` | “Remove your photo?” (SOURCED)<br>“It won't be in {name}'s video” (SOURCED)<br>“Yes, remove” (SOURCED)<br>“Cancel” (SOURCED)<br>“Removed” (SOURCED)<br>ios: notification.warning; android: CONFIRM (PLATFORM)<br>ios: notification.success; android: CONFIRM (PLATFORM) | withdraw asks first; removed toast | `.alert`; optimistic, reverted with the inline line on failure |
| matched | `birthday.request.due`<br>`layout.birthday.request.dueDate`<br>`dimension.birthday.request.cardToFooter`<br>`fontSize.global.caption` | “Add yours by {date}” (SOURCED)<br>pattern: EEEE, MMMM d; example: Wednesday, July 5; ios: Date.FormatStyle().weekday(.wide).month(.wide).day(); android: DateFormat.getBest… (SOURCED)<br>15.3 pt (SOURCED)<br>14 pt (SOURCED) | 'Add yours by Wednesday, July 5' 15.3 under the card — a date, never a countdown | MemoryFormat.dueDate (day before the birthday, no year) |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `birthday.request.loading` | “Loading…” (SOURCED) | loading: black, platform indicator | C-28 + announcement |
| matched | `birthday.request.closed.title`<br>`birthday.request.closed.detail` | “This request is closed” (SOURCED)<br>“{name}'s video is on its way.” (SOURCED) | closed: the card holds the C-27 block, no capsule, no due line | EmptyStateView in the card |
| matched | `birthday.request.notFound.title` | “Couldn't find request” (SOURCED) | not found: C-27 title on black | EmptyStateView |
| matched | `birthday.request.error.title`<br>`birthday.request.error.detail`<br>`birthday.request.error.retry`<br>`birthday.request.offline.title`<br>`birthday.request.offline` | “Something went wrong” (SOURCED)<br>“There was a problem. Please try again.” (SOURCED)<br>“Try Again” (SOURCED)<br>“No Connection” (SOURCED)<br>“Check your connection and try again.” (SOURCED) | error / offline on the backdrop + light pill | MemoryMediaStateBlock |
| matched | `—` | — (no token) | entry row on groups.screen (title + due line + avatar) | BirthdayRequestsEntry → full-screen cover; default `MemoryEntryRequestRow` (C-14 + C-16) |
| approximated | `—` | — (no token) | full screen from the push | the shell (account) still presents the pushed route as a `.large` sheet (`PresentedRoute.modal`) — hand-off |

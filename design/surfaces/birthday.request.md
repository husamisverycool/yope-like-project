# `birthday.request` — private request to add a photo and one line

Reference: **Tribute / VidDay** (docs/SURFACES.md). Geometry and type from Tribute's live contribution page
(VERIFIED computed styles); order and words from Tribute's current page and VidDay's invitee page. Voice: `P-BR-1`,
`P-BR-2`, `P-BR-3`; Title Case buttons (Tribute); states use the app default voice (`yope.voice.error`). Tokens:
`design/tokens/memory.json` (`*.birthday.request.*`, `font.birthday`). Copy: `design/copy/memory.json`
(`birthday.request.*`).

What it is: seven days before an opted-in member's birthday (`birthday_request_lead_days`, group-local), every other
member of each group they share is asked **once, privately** (one push, no reminders, no deadline countdown —
docs/SPEC_FLAGS.md T5). The member can add one photo they posted or are self-tagged in, plus one line. Nobody sees
who else contributed. The honoree never sees the request.

## References

| image | what it verifies |
|---|---|
| `references/auto/tribute/web/tribute-web-testimonials-contribution-page-viewport.png` + `tribute-web-testimonials.computed-styles.json` | hero 390 × 365.8 (photo at 0.7 over black), title 24/600 at y84, message 16/400 lh 28 at 0.9, button 360 × 62 r8 22/600, prompts header 15/500 on #292D34 (42 high, padding 24), prompts 15/400 lh 18.75, margin 15 |
| `references/auto/tribute/web/tribute-web-ayejaye-contribution-page-viewport.png` | same template, birthday occasion |
| `references/auto/tribute/mockups/tribute-home-phone-step-1-contribution-page.png` | current page: title, "Submit by Wednesday, December 31, 2025" under it, message, button |
| `references/auto/vidday/store/vidday-store-01.png` | "Birthday Video", "Message Ideas" with two prompts |
| `references/auto/vidday/frames/vidday-tour-t064-phone.png` | invitee page order: photo, "Celebration video for / name", message, button |
| `references/auto/vidday/frames/vidday-tour-t036-phone.png`, `-t042-phone.png`, `-t072-phone.png` | invitation wording ("You're invited to submit …", "It's quick and easy.") |

## Structure

Full-screen sheet on `color.global.backgroundDeep` (`layout.birthday.request.structure`), scrolling vertically:

1. **Hero** — full width, `dimension.birthday.request.hero.height` tall, `color.global.backgroundDeep` behind the
   honoree's photo (`profiles.avatar_path`, aspect-fill) at `opacity.birthday.request.hero.image` (no photo → black
   only). Close circle top-left in the safe area: `size.global.headerButton`, `size.global.headerInset`,
   `color.global.controlOnDeep`, `icon.global.close`.
   - **Title** at `dimension.birthday.request.title.top` from the hero top (below the safe area when that is taller),
     left-aligned at `dimension.birthday.request.margin`: `birthday.request.title` — `fontSize/fontWeight/lineHeight.birthday.request.title`, `color.global.textPrimary`.
   - **Due line** directly under the title: `birthday.request.due` with `{date}` per `layout.birthday.request.dueDate`
     — `fontSize/lineHeight.birthday.request.message`, `color.global.textPrimary` at `opacity.birthday.request.message`.
   - **Message** `dimension.birthday.request.message.gap` below: `birthday.request.body` + " " + `birthday.request.ease`
     + " " + `birthday.request.thanks` as one paragraph — `fontSize/lineHeight.birthday.request.message`, white at
     `opacity.birthday.request.message`; right margin `dimension.birthday.request.margin`.
2. **Primary button** `dimension.birthday.request.cta.gap` below the hero: full width minus
   `dimension.birthday.request.margin` each side, `dimension.birthday.request.cta.height`,
   `radius.birthday.request.cta`, fill `color.global.accent`, label `birthday.request.cta` in
   `fontSize/fontWeight.birthday.request.cta`, `color.global.onAccent`. Opens `birthday.contribute`.
   - **After contributing** the button is replaced by the member's own block: heading `birthday.request.contributed.title`
     (`fontSize.birthday.contribute.label`, `fontWeight.birthday.contribute.label`), their photo thumbnail
     (`radius.global.photo`, width = content width) and their line (`fontSize.birthday.request.message`), then two
     Tribute secondary buttons stacked `dimension.birthday.tribute.button.gap` apart: `birthday.request.contributed.change`
     (opens `birthday.contribute` at step 1) and `birthday.request.contributed.remove` (withdraw) —
     `dimension.birthday.tribute.button.height`, `radius.birthday.tribute.button`, `color.global.surfaceLight`,
     label `color.birthday.tribute.button.label`, `fontSize/fontWeight.birthday.tribute.button`.
3. **Message Ideas** `dimension.birthday.request.prompts.gap` below: header bar full content width,
   `dimension.birthday.request.prompts.headerHeight`, fill `color.birthday.request.prompts.header`, top corners
   `radius.birthday.request.prompts`, label `birthday.request.prompts.title` in
   `fontSize/fontWeight.birthday.request.prompts.header`, `color.global.textPrimary`, left padding
   `dimension.birthday.request.prompts.headerPadding`. Then the two prompts as a bulleted list
   (`birthday.request.prompt.appreciate`, `birthday.request.prompt.impact`), text indented
   `dimension.birthday.request.prompt.indent`, first `dimension.birthday.request.prompt.top` below the bar, then
   `dimension.birthday.request.prompt.gap` apart, `fontSize/lineHeight.birthday.request.prompt`, `color.global.textPrimary`.
4. Bottom padding: safe area + `dimension.birthday.request.margin`.

**Entry on the group screen** (placed by `groups.screen`): while the request is open, a row with
`birthday.request.title` and `birthday.request.due`; tap opens this sheet.

## Elements

| element | tokens | copy keys | behaviour |
|---|---|---|---|
| hero photo | `dimension.birthday.request.hero.height`, `opacity.birthday.request.hero.image`, `color.global.backgroundDeep` | — | honoree avatar, decorative |
| close | `size.global.headerButton`, `size.global.headerInset`, `color.global.controlOnDeep`, `icon.global.close` | `birthday.request.a11y.close` | dismiss |
| title | `fontSize/fontWeight/lineHeight.birthday.request.title`, `dimension.birthday.request.title.top`, `dimension.birthday.request.margin`, `font.birthday` | `birthday.request.title` (`{name}`) | — |
| due line | `fontSize/lineHeight.birthday.request.message`, `opacity.birthday.request.message`, `layout.birthday.request.dueDate` | `birthday.request.due` (`{date}`) | the day before `birthday_date`, full date; never a countdown |
| message | `fontSize/lineHeight.birthday.request.message`, `opacity.birthday.request.message`, `dimension.birthday.request.message.gap` | `birthday.request.body`, `.ease`, `.thanks` | — |
| Add Your Photo | `dimension.birthday.request.cta.gap` / `.height`, `radius.birthday.request.cta`, `fontSize/fontWeight.birthday.request.cta`, `color.global.accent`, `color.global.onAccent` | `birthday.request.cta` | → `birthday.contribute` |
| own contribution | `fontSize/fontWeight.birthday.contribute.label`, `radius.global.photo`, `dimension.birthday.tribute.button.*`, `radius.birthday.tribute.button`, `color.global.surfaceLight`, `color.birthday.tribute.button.label` | `birthday.request.contributed.title`, `.change`, `.remove` | remove = direct DELETE of the own row before `due_at`; no confirmation (re-adding is possible until the due time) |
| Message Ideas | `color.birthday.request.prompts.header`, `dimension.birthday.request.prompts.*`, `radius.birthday.request.prompts`, `fontSize/fontWeight.birthday.request.prompts.header`, `dimension.birthday.request.prompt.*`, `fontSize/lineHeight.birthday.request.prompt` | `birthday.request.prompts.title`, `birthday.request.prompt.appreciate`, `.impact` | static |
| push | — | `birthday.request.push.title`, `birthday.request.push.body` (`{name}`) | one per request, never repeated; tap → `DeepLink.birthdayRequest` |

## States

| state | design | copy | source |
|---|---|---|---|
| loading | hero black, platform activity indicator centred in the content area | `birthday.request.loading` | Yope HUD word |
| closed (`tribute_closed` or `due_at` passed) | hero + title stay; button and prompts replaced by text roles `emptyTitle` / `emptyDetail`, `color.global.textPrimary` / `textSecondary` | `birthday.request.closed.title`, `birthday.request.closed.detail` | app voice; never "late" or "missed" |
| not found (`request_not_found`: honoree opted out, left, block) | centred text roles `emptyTitle` / `emptyDetail` on `color.global.backgroundDeep` | `birthday.request.notFound.title`, `.detail` | app voice |
| error | same + light pill retry (`color.global.surfaceLight`, `radius.global.capsule`) | `birthday.request.error.title`, `.detail`, `.retry` | app voice |
| offline | text role `listSubtitle`, `color.global.textSecondary`, under the hero | `birthday.request.offline` | app voice |
| empty / permission-denied | n/a (eligibility is handled in `birthday.contribute`) | — | — |

There is **no** "you haven't contributed" state, badge or reminder anywhere.

## Motion

Sheet presentation (`duration.global.sheetPresent` / native sheet, MERGE F-15); everything else static. Reduce Motion:
`layout.global.reduceMotion`.

## Haptics

Remove succeeded → `haptic.global.success`; failure → `haptic.global.error`.

## Accessibility

- Close `birthday.request.a11y.close`. Title: header trait. Hero photo: decorative. Prompts: list. Buttons: visible
  text.
- Dynamic Type (`layout.birthday.request.textStyleMap`): title `title2`, message / due `callout`, button `title2`,
  prompts header and prompts `subheadline`. At large sizes the hero grows to fit the text (its height is a minimum).
- Focus order: close → title → due → message → button (or own block) → Message Ideas.
- Contrast:

  | pair | ratio | needs | result |
  |---|---|---|---|
  | title white on black hero | 21.00 | 3 (24 pt) | pass; over a light photo at 0.7 not guaranteed (photo-dependent, as in the reference) |
  | message white at 0.9 on black (#E6E6E6) | 16.83 | 4.5 | pass (same photo caveat) |
  | `color.global.onAccent` on `color.global.accent` | 17.65 | 3 | pass |
  | white on `color.birthday.request.prompts.header` | 13.82 | 4.5 | pass |
  | prompt text white on `color.global.backgroundDeep` | 21.00 | 4.5 | pass |
  | `color.birthday.tribute.button.label` on `color.global.surfaceLight` | 13.82 | 4.5 | pass |

## Data & actions

- **Read:** `from("tribute_requests").select().eq("id", requestId).single()` (RLS: not visible to the honoree or
  across a block) → `group_id`, `honoree_id`, `birthday_date`, `due_at`; `profiles` of the honoree (`display_name`
  first word, `avatar_path`); own contribution `from("tribute_contributions").select().eq("request_id", id)` (RLS
  returns only yours) + its post's media for the thumbnail. Open requests for the group screen row:
  `from("tribute_requests").select().eq("group_id", g).is("closed_at", null).gt("due_at", now)`.
- **Writes:** withdraw = `from("tribute_contributions").delete().eq("id", contributionId)` before `due_at`
  (docs/API.md 5.0). Adding / replacing goes through `birthday.contribute` (`contribute_tribute`).
- **Push:** worker job `push.birthday_request` (once per request; dedupe key `push.birthday_request:<id>`), payload
  `type = birthday_request`, `request_id`, `group_id`.
- **Navigation in:** push → `DeepLink.birthdayRequest(requestID:groupID:)` / `app://birthday-request?request=<id>&group=<id>`
  (`ios/Packages/AppCore/Sources/AppModels/DeepLink.swift`, `android/core/model/src/main/kotlin/app/model/DeepLink.kt`);
  group screen row. **Out:** `birthday.contribute`; close → previous screen.

## Platform notes

- iOS `.sheet` with `.presentationDetents([.large])`; Android `ModalBottomSheet` (skipPartiallyExpanded) or full-screen
  destination when opened from a push.
- Full-date formatting: iOS `Date.FormatStyle(date: .complete)`, Android `DateFormat.getDateInstance(DateFormat.FULL)`.
- The worker's push keys today are `notifications.push.birthdayRequest.*` (notifications.push pass); this surface's
  texts are `birthday.request.push.*` (MERGE memory M-22).

## Do-not-copy

Countdowns ("Submissions are due in: 3d 12h 34m", "Tribute Ends In:" D/H/M/S); Tribute's five-email reminder chase and
VidDay's "Our built-in tools handle the 'nagging' for you"; "It's your contribution that will help to make this
unforgettable."; the public list of submitted videos; "Hi everyone!" (each request is private); "Add to Calendar";
asking for name or email; gift money ("Allow Gifts"); share buttons to social networks; Tribute's red and VidDay's
blue (brand accents, M-7); the Tribute / VidDay names.

## Gaps

| item | status | owner capture |
|---|---|---|
| Tribute's / VidDay's own request push or SMS wording | not found; adapted from VidDay's invitation message | forward one real Tribute or VidDay invitation (email / SMS) the owner received (research capture 4) |
| due-line size | uses the message role | same capture, opened on a phone |
| closed-request screen wording | not found; app voice | same |
| prompts card fill | Tribute's white card is a light-appearance value; dropped (dark only, M-8) | — (owner decision on F-1) |

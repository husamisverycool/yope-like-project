# `birthday.request` — private request to add a photo and one line

Visual reference: **Retro screen 27** — the paywall's card on a blurred backdrop (`references/auto/retro/lazyweb/
retro-lazyweb-20260529-paywall.png`, RAW: glass close circle, serif headline + line, plan card with a 24-pt title, a
grey line, numbered steps and a 60-pt capsule, a short line under the card) — and screen 16 (feature-intro sheet)
(docs/SURFACES.md). Retro has no birthdays, so the screen is **composed of Retro components** C-34 (card on a blurred
backdrop), C-11, C-05, C-10, C-29 in Tribute / VidDay's order (who it's for → invitation → message ideas → add
yours → date). Mechanics reference: **Tribute / VidDay**. Voice: Retro set + `P-BR-1`…`P-BR-3`. Tokens:
`design/tokens/memory.json` (`*.birthday.request.*`) + global. Copy: `design/copy/memory.json` (`birthday.request.*`).
Decisions: `design/MERGE_DECISIONS.md` → "Redesign — Memory (RM-*)".

What it is: seven days before an opted-in member's birthday (`birthday_request_lead_days`, group-local), every other
member of each group they share is asked **once, privately** (one push, no reminders, no countdown —
docs/SPEC_FLAGS.md T5). The member can add one photo they posted or are self-tagged in, plus one line. Nobody sees who
else contributed. The honoree never sees the request.

## References

| image / source | what it verifies |
|---|---|
| PAY `references/auto/retro/lazyweb/retro-lazyweb-20260529-paywall.png` (RAW, 3.000 px/pt) | close glass 32 pt, 26.2 pt from the right edge, centre 21.8 below the safe-area top; serif headline (displayMedium) → line 19.3; line → card 29; card (C-34: r 36, padding 27, width − 2 × 20); card title 24 bold; title → grey line 11; blocks 29.3 apart; numbered steps 17.3-pt markers, 5 pt to the text, pitch 32, text 17; capsule 60 pt, 16 from the card sides and bottom; line under the card 15.3 below it |
| `references/auto/retro/press/tc-2023-12-retro3.png` phone 1 | feature-intro sheet pattern (title + two grey rows + black capsule) |
| `references/auto/vidday/store/vidday-store-01.png` | "Message Ideas" with two prompts (content) |
| `references/auto/tribute/mockups/tribute-home-phone-step-1-contribution-page.png` | order: who → invitation → due date → add (mechanics) |

## Structure

Full-screen (from the push or the group screen's row). **Backdrop:** the honoree's photo (`profiles.avatar_path`)
blurred over the whole screen (`layout.global.materials.backdrop`, C-34) — dark in both appearances (media); no photo
→ `color.global.backgroundDeep`. Top to bottom:

1. **Close** — glass circle (C-11 small) `size.global.circleButtonSmall`, fill `color.global.glass`, `icon.global.close`
   (≈ 9.7 pt glyph) in `color.global.textOnMedia`; right edge `dimension.birthday.request.close.inset` from the screen
   edge, centre `dimension.birthday.request.close.centerY` below the safe-area top.
2. **Who** (centred block, bottom-anchored above the card): the honoree's avatar (C-23) `size.global.avatarProfile`,
   centred; `size.global.emptyIconToTitle` below it the **headline** `birthday.request.title` ("{name}'s birthday
   video") — `font.global.display`, text role `displayMedium`, `color.global.textOnMedia`, centred, side margins
   `size.global.buttonMarginH`.
3. **Invitation** — first line's cap top `dimension.birthday.request.headlineToMessage` below the headline's baseline:
   `birthday.request.body` ("You're invited to add a photo and one line for {name}'s birthday video — no pressure."),
   text role `textButton` (17 regular, PAY's line size), `color.global.textOnMedia`, centred.
4. **Card** (C-34 plan card) `dimension.birthday.request.messageToCard` below the last line: width = screen − 2 ×
   `size.global.buttonMarginH`, `color.global.surfaceElevated`, `radius.global.cardLarge`, padding
   `size.global.planCardPadding`; content left-aligned:
   - title `birthday.request.prompts.title` ("Message ideas") — `fontSize.birthday.request.cardTitle` /
     `fontWeight.birthday.request.cardTitle`, `color.global.textPrimary`;
   - `dimension.birthday.request.card.titleToDetail` below its baseline: `birthday.request.card.detail` ("Pick a photo
     you posted or are in, then add one line."), text role `body`, `color.global.textSecondary`;
   - `dimension.birthday.request.card.blockGap` below: two **prompt rows**, centres
     `dimension.birthday.request.card.rowPitch` apart: a marker circle `dimension.birthday.request.card.marker`
     (fill `color.global.accent`, number "1" / "2" in text role `badge`, `color.global.onAccent`), then
     `dimension.birthday.request.card.markerGap`, then `birthday.request.prompt.appreciate` /
     `birthday.request.prompt.impact` in text role `textButton`, `color.global.textPrimary` (wrapping under the text's
     own leading edge);
   - `dimension.birthday.request.card.blockGap` below: the primary capsule (C-05) `birthday.request.cta` ("Add your
     photo") — `color.global.accent` / `color.global.onAccent`, `size.global.buttonHeight`, `radius.global.button`,
     16 pt from the card sides and bottom (C-34) → `birthday.contribute`.
   - **After contributing** the card shows instead: title `birthday.request.contributed.title` ("You added a photo");
     your photo (C-15 thumbnail: `size.global.rowThumbWidth` × `.rowThumbHeight`, `radius.global.thumbnail`) with your
     line beside it (text role `body`, `color.global.textPrimary`, `size.global.rowThumbGap`); then two medium
     capsules side by side (C-06, `size.global.pillGap`): outline `birthday.request.contributed.change` ("Change photo")
     → `birthday.contribute` with your photo preselected, and the destructive text button (C-10)
     `birthday.request.contributed.remove` ("Remove") → native confirmation (C-29) `birthday.request.remove.title` /
     `.message` / `.confirm` / `.cancel` → withdraw → toast `birthday.request.removed`.
5. **Due line** — `dimension.birthday.request.cardToFooter` below the card, centred: `birthday.request.due` ("Add yours
   by {date}", `{date}` = `layout.birthday.request.dueDate`, the day before the birthday), text role `caption`,
   `color.global.textOnMedia`. A date, never a countdown. Then the safe-area bottom.

The block is anchored to the bottom (card and due line above the safe-area bottom); at large text sizes the page
scrolls.

**Entry on the group screen** (placed by `groups.screen`): while a request is open, a row with
`birthday.request.title` and `birthday.request.due`; tap opens this screen.

## Elements

| element | component · tokens | copy keys | behaviour |
|---|---|---|---|
| backdrop | C-34 `layout.global.materials.backdrop`, `color.global.backgroundDeep` | — | decorative |
| close | C-11 small glass: `size.global.circleButtonSmall`, `color.global.glass`, `icon.global.close`, `dimension.birthday.request.close.inset`, `.close.centerY` | `birthday.request.a11y.close` | dismiss |
| avatar | C-23 `size.global.avatarProfile` | — (decorative next to the name) | — |
| headline | `font.global.display`, text role `displayMedium`, `color.global.textOnMedia`, `size.global.emptyIconToTitle` | `birthday.request.title` | — |
| invitation | text role `textButton`, `color.global.textOnMedia`, `dimension.birthday.request.headlineToMessage` | `birthday.request.body` | — |
| card | C-34: `color.global.surfaceElevated`, `radius.global.cardLarge`, `size.global.planCardPadding`, `size.global.buttonMarginH`, `dimension.birthday.request.messageToCard` | — | — |
| card title / detail | `fontSize.birthday.request.cardTitle`, `fontWeight.birthday.request.cardTitle`, `color.global.textPrimary`; text role `body`, `color.global.textSecondary`, `dimension.birthday.request.card.titleToDetail` | `birthday.request.prompts.title` / `.contributed.title`, `birthday.request.card.detail` | — |
| prompt rows | `dimension.birthday.request.card.blockGap`, `.rowPitch`, `.marker`, `.markerGap`, `color.global.accent` / `.onAccent`, text roles `badge` / `textButton` | `birthday.request.prompt.appreciate`, `.prompt.impact` | static |
| Add your photo | C-05 | `birthday.request.cta` | → `birthday.contribute` |
| own contribution | C-15 thumbnail, C-06 outline, C-10 | `birthday.request.contributed.*`, `birthday.request.remove.*`, `birthday.request.removed` | change / withdraw before `due_at` |
| due line | text role `caption`, `color.global.textOnMedia`, `dimension.birthday.request.cardToFooter`, `layout.birthday.request.dueDate` | `birthday.request.due` | — |
| push | — | `notifications.push.birthdayRequest.title` / `.body` (owned by `notifications.push`, MERGE L-1) | one per request; tap → this screen |

## States

| state | design (components) | copy | source |
|---|---|---|---|
| loading | backdrop black; platform activity indicator centred (C-28) | `birthday.request.loading` (announcement) | C-28 |
| closed (`tribute_closed` or `due_at` passed) | the card holds a C-27 block: title `emptyTitle` `color.global.textPrimary`, detail `emptyDetail` `color.global.textSecondary`; no capsule; no due line | `birthday.request.closed.title`, `.closed.detail` | never "late" or "missed" |
| not found (`request_not_found`: honoree opted out, left, block) | C-27 title centred on `color.global.backgroundDeep` | `birthday.request.notFound.title` | `retro.voice.error` |
| error | C-27 error variant on the backdrop + light pill (C-09) retry | `birthday.request.error.title`, `.error.detail`, `.error.retry` | `retro.voice.error` |
| offline | same block | `birthday.request.offline.title`, `birthday.request.offline`, `.error.retry` | `retro.voice.error` |
| empty / permission-denied | n/a (eligibility is handled in `birthday.contribute`) | — | — |

There is **no** "you haven't contributed" state, badge or reminder anywhere.

## Motion

Full-screen presentation native (`easing.global.native`); dialog native. Card content swap (prompts ↔ own
contribution): crossfade `duration.global.crossfade`. Reduce Motion: `layout.global.reduceMotion`.

## Haptics

Close, capsules → `haptic.global.tap` (Android). Withdraw confirmed → `haptic.global.warning`; withdrawn →
`haptic.global.success`; failure → `haptic.global.error`.

## Accessibility

- Close `birthday.request.a11y.close`. Headline: header. Avatar: hidden (the name is in the headline). Prompt rows: a
  list (markers hidden; the list announces position). Capsules: visible text. Due line: static text.
- Dynamic Type: `displayMedium` → largeTitle, `textButton` → body, `body` → subheadline, card title (24) → title2,
  `caption` → subheadline (`layout.global.textStyleMap`); the page scrolls.
- Focus order: close → headline → invitation → card title → detail → prompts → capsule (or own block) → due line.
- Contrast (`node tools/contrast.mjs`):

  | pair | ratio | needs | result |
  |---|---|---|---|
  | `color.global.textOnMedia` on the blurred backdrop | photo-dependent (black fallback 21.00; light photo 1.00) | 3 / 4.5 | **not guaranteed** — Retro draws its paywall text on colour the same way (reported) |
  | card `color.global.textPrimary` on `color.global.surfaceElevated` | light 21.00 · dark 17.76 | 4.5 | pass |
  | card detail `color.global.textSecondary` on `color.global.surfaceElevated` | light 2.85 · dark 6.23 | 4.5 | **FAIL in light** (Retro's grey; reported) |
  | marker `color.global.accent` vs card; number `color.global.onAccent` on it | 21.00 / 17.76; 21.00 | 3; 4.5 | pass |
  | C-05 label on `color.global.accent` | 21.00 | 4.5 | pass |
  | glass close over the backdrop: glyph white on `color.global.glass` over white | 1.00 | 3 | **FAIL** over light photos (C-11; photo-dependent) |
  | `color.global.destructive` text on `color.global.surfaceElevated` | light 4.18 · dark 4.25 | 4.5 | **FAIL** (C-10 failure 5; reported) |

## Data & actions

- **Read:** `from("tribute_requests").select().eq("id", requestId).single()` (RLS: not visible to the honoree or across a
  block) → `group_id`, `honoree_id`, `birthday_date`, `due_at`; `profiles` of the honoree (`display_name` first word,
  `avatar_path`); own contribution `from("tribute_contributions").select().eq("request_id", id)` (RLS: yours only) +
  its post's media (thumb). Open requests for the group row: `…eq("group_id", g).is("closed_at", null).gt("due_at",
  now)`.
- **Writes:** withdraw = `from("tribute_contributions").delete().eq("id", contributionId)` before `due_at`
  (docs/API.md 5.0). Adding / replacing goes through `birthday.contribute` (`contribute_tribute`).
- **Push:** worker job `push.birthday_request` (once per request), payload `type = birthday_request`, `request_id`,
  `group_id`.
- **Navigation in:** push → `DeepLink.birthdayRequest(requestID:groupID:)` / `app://birthday-request?request=<id>&group=<id>`
  (`ios/Packages/AppCore/Sources/AppModels/DeepLink.swift`, `android/core/model/src/main/kotlin/app/model/DeepLink.kt`);
  group screen row. **Out:** `birthday.contribute`; close → previous screen.

## Platform notes

- iOS `.fullScreenCover`, `.environment(\.colorScheme, .dark)` for the backdrop layer only (the card follows the
  appearance: `color.global.surfaceElevated` is light in light mode, as PAY's card). Android full-screen destination,
  edge-to-edge.
- Date formatting: `layout.birthday.request.dueDate` (weekday, month, day; no year).
- Blur: `.blur` / `Modifier.blur` (API 31+; below, the photo under `color.global.scrim`); radius not sourced (C-34).

## Do-not-copy

Countdowns ("Submissions are due in: 3d 12h 34m"); reminder chains; "It's your contribution that will help to make this
unforgettable."; public lists of contributions; "Hi everyone!"; "Add to Calendar"; name / email collection; gift money;
social share buttons; Tribute's red and VidDay's blue; Retro's paywall wordmark, purple "FREE" pill, struck-through
done steps and prices; the Tribute / VidDay names.

## Gaps

| item | status | smallest capture that closes it |
|---|---|---|
| Retro has no birthday feature | composition of Retro components (RM-10) | — |
| due-line colour under the card | PAY's line is translucent (not measurable); drawn `color.global.textOnMedia` | one RAW paywall screenshot over a flat dark colour |
| marker number size | text role `badge` (not isolated at 3 px/pt) | lossless crop of PAY's step markers at 3× |
| real Tribute / VidDay invitation wording | adapted from VidDay's page (P-BR-1) | forward one real invitation (research capture 4) |

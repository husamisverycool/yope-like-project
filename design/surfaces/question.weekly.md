# `question.weekly` — one light question for the group each week

Research: `design/research/overnight-and-questions.md` (OQ) §3–§4; data: `design/research/overnight-and-questions-data.md`
§5–§7; server: `docs/API.md` §14.4. Tokens: `design/tokens/account.json` (`question.weekly.*`) + `global.*`. Copy:
`design/copy/account.json` (`question.weekly.*`; the question catalogue is `question.weekly.q01` … `q09`, the keys the
server stores in `app_config.weekly_question_keys`). The JSON files are canonical (values, evidence, levels). Decisions:
`design/MERGE_DECISIONS.md` → New features (WQ-1 … WQ-7).

**Visual reference: Retro** — the question is a **feed card in the group screen's pager** (`groups.screen` §8, the
same pager and card geometry as the on-this-day and year-story cards: C-18, `layout.global.photoScrim`, display text
role, C-09 light pill), plus C-06 primary capsule, C-09 pill on media in the camera, C-29 native context menu. **Copy and
mechanics:** Retro's own "what to share" prompt cards (questions about a moment with one button "Add a memory",
R-NUX) and **Apple Journal's** reflection prompts (an eyebrow naming the feature over a short prompt; prompts can be
removed; notifications only on a schedule the person sets). BeReal is the contrast case (prompts shown over the
camera; its locked Bonus is do-not-copy). No Apple or BeReal colour, type or glyph is used.

Tenet gate (docs/CONVENTIONS.md §6): never required, no reminder, no streak, no tally of who answered, no gate.

## References

| image / text | what it verifies |
|---|---|
| `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` `nux_card_title_what_to_share_0..7`, `nux_card_cta_what_to_share` (R-NUX; owner decision 22 caveat) | prompt voice (a question about a moment, second person, "?"), one CTA "Add a memory"; prompt cards live in Retro's home feed |
| `references/auto/retro/apk/nux_card_what_to_share_0.webp` (393 × 538 dp) | Retro's prompt card is a photo card with a dark bottom gradient for its text |
| `references/auto/apple-journal/store/journal-store-iPhone_2_Suggestions.png` (AJ2, 3x) | REFLECTION card: eyebrow naming the feature above the prompt; prompt ≤ 3 lines; one affordance (refresh — not taken) |
| `references/auto/apple-journal/store/journal-store-iPhone_7_Widget.png` (AJ7) | prompt phrased as a question ("What's something nice you can do for yourself today?") |
| support.apple.com "Write in your journal on iPhone" / "Change your Journal settings on iPhone" (AJS, VERIFIED) | "touch and hold the suggestion, then tap Remove"; prompts can be turned off; notifications on a user-set schedule |
| `references/auto/retro/store/retro-store-01.png` (ST-01), `retro/store/editorial/retro-appstore-story-1840659619-albums.png` (ED-A) | C-18 card pager geometry (via `groups.screen`) |
| `references/auto/retro/press/tc-2023-12-retro3.png` / C-06 evidence (ST-02, TC-1B) | primary capsule on a page |
| `design/research/bereal.md` §2 "On-screen prompts" | a prompt shown over the capture screen (mechanic for the camera pill) |

## Structure

### A. The card (placed by `groups.screen`)

In `groups.screen` → **Members' weeks and memories** pager (§8): the question card is the **first feed card** (after
the friend cards, before the on-this-day and year-story cards) for the whole group week (Monday 00:00 → Sunday 24:00,
`groups.time_zone`, `app_config.week_start_isodow`). With no friend cards that week the pager shows for the question
card alone. Card geometry: `size.global.friendCardWidth` × `.friendCardHeight` (240 × 361), `radius.global.card`,
`layout.global.cornerStyle`, `size.global.cardGap` between cards.

1. **Label line above the card** (the friend card's avatar + name slot, C-18; `size.global.cardHeaderGap` to the
   card): `question.weekly.card.label` — text role `listTitle`, `color.global.textPrimary`, starting at the card's
   leading edge (no glyph: Apple's eyebrow has none; Jolt has no question glyph token).
2. **Card, no answers yet** — fill `color.global.control` (Retro's no-photo surface, C-17 placeholder); inside
   `size.global.screenMargin` at the bottom: the **question** (`question.weekly.q*`, text role `displaySmall`,
   `font.global.displayNarrow`, `color.global.textPrimary`, up to 4 lines, then truncation — the a11y label carries
   the full text), then `size.global.pillGap` below it a **C-06 primary capsule** `question.weekly.card.button`
   (`color.global.accent` / `color.global.onAccent`, `size.global.pillHeight`, hugs the label).
3. **Card, with answers** — the **newest answer's photo**, aspect-fill, with `layout.global.photoScrim`; the question
   in `color.global.textOnMedia`, same role and position; the button becomes the **C-09 light pill** (fill
   `color.global.surfaceLight`, label `color.global.onSurfaceLight`, text role `pill`) — exactly the `groups.screen`
   feed-card composition. No names, no number of answers, no "you answered" mark.

### B. Answering

`question.weekly.card.button` → `camera.capture` with the question as context (`DeepLink.camera(groupID:, questionID:)`):

- The camera opens in **Now** mode (the default of `camera.overnight`).
- On the viewfinder, in the coach pill's slot (bottom, 20.5 pt above the viewfinder bottom,
  `camera.sendto.layout.messageField`): a **C-09 pill on media** with the question (fill `color.global.controlOnDeep`,
  text role `pill`, `color.global.textOnMedia`, width up to the viewfinder width − 2 × `size.global.screenMargin`, one
  line, truncated) — BeReal shows its prompt over the capture screen (bereal.md §2).
- Shutter or library pick → `camera.sendto` with **this group preselected** and the others unselected; the post to this
  group carries the question (`answer_question`, Data & actions); posts to other groups do not.
- Switching to **9 AM** drops the question context (the pill disappears); answering is an ordinary photo flow.
- Answers are allowed any time during the question's week; more than one per member is allowed (Retro and Apple set no
  limit).

### C. Seeing the answers together

Tap on the card (outside the pill) → `photo.viewer` on **the week's answers in this group**, oldest first (the strip's
order), with the viewer's position badge. Answers are also ordinary posts: they appear in the week strip, on friend
cards and in recaps like any photo. **BLOCKED:** showing the question inside `photo.viewer` (no reference labels a photo
viewer with a prompt) — the viewer is unchanged meanwhile.

### D. Removing the card for yourself

Long press on the card → native context menu (C-29) with one item `question.weekly.menu.remove` → the card is hidden
for this member until the next question (Apple: "touch and hold the suggestion, then tap Remove"). No confirmation (the
action hides only one card for one week).

### E. Turning it off for the group

A switch in `groups.settings` (`question.weekly.settings.row` / `.rowDetail`), with the same permission as the group's
other settings. **Default for new groups: on** (`question.weekly.layout.defaultOn`, lead decision 30, docs/OWNER_DECISIONS.md
2026-10-17): Retro shows its prompt cards in the feed without an opt-in; Apple asks at first launch. Existing groups keep their
value. The questions come in the catalogue's order, one per group week, starting again after the last
(`question.weekly.layout.rotation`).

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| label line | C-18 header slot · `listTitle`, `color.global.textPrimary`, `size.global.cardHeaderGap` | `question.weekly.card.label` | part of the card's button |
| card (no answers) | feed card · `color.global.control`, `displaySmall` / `font.global.displayNarrow` / `color.global.textPrimary`, C-06 primary | `question.weekly.q*`, `question.weekly.card.button`; a11y `question.weekly.card.a11y` | button → `camera.capture` (question context) |
| card (answers) | feed card · newest answer photo, `layout.global.photoScrim`, `color.global.textOnMedia`, C-09 light pill | same; custom action `question.weekly.card.a11y.answers` | card → `photo.viewer` (answers); pill → `camera.capture` |
| context menu | C-29 native | `question.weekly.menu.remove` | hides the card for you this week |
| camera pill | C-09 on media · `color.global.controlOnDeep`, `pill`, `color.global.textOnMedia` | the question; a11y `question.weekly.camera.a11y` | not a button |
| settings switch | C-14 row + native switch (`groups.settings`) | `question.weekly.settings.row`, `.rowDetail` | on / off for the group |

## States

| state | design | copy |
|---|---|---|
| loading | the pager's placeholder (C-28: `color.global.control` card, no text) | — |
| no answers | A.2 | — |
| with answers | A.3 | — |
| removed by you | card absent | — |
| feature off for the group | card absent | — |
| error (fetch failed) | card absent (the group screen's own error line covers the screen) | — |
| offline | cached question shows; the button still opens the camera (posting queues as in `camera.sendto`) | — |
| week ends | card leaves the pager at the end of the group week; answers stay as posts | — |
| empty / permission-denied | n/a | — |

## Motion

Card in / out of the pager: `duration.global.fade` + `easing.global.standard` (C-18 rules). No-answer → with-answer
switch: cross-fade `duration.global.crossfade`. Card → viewer: `duration.global.photoOpen` (C-22). Reduce Motion: the same
fades. No celebration on answering (none in the references).

## Haptics

Button, pill, card: `haptic.global.tap` (Android). Long press: `haptic.global.longPressStart`. None on answering.

## Accessibility

- The label line, question and button form one card element (button trait) labelled `question.weekly.card.a11y`
  ({question}); with answers, a custom action `question.weekly.card.a11y.answers` opens the viewer; the context-menu
  item is exposed as a custom action.
- Dynamic Type: question `displaySmall` → title2; label `listTitle` → subheadline; capsule `pill` → subheadline. The card
  is fixed-size: the a11y label carries the full question when it truncates.
- Focus order inside `groups.screen`: friend cards → **question card** → other feed cards.
- Contrast (`node tools/contrast.mjs`):

| pair | light | dark |
|---|---|---|
| question `textPrimary` on `color.global.control` | 18.59:1 pass | 15.13:1 pass |
| C-06 primary label `onAccent` on `accent` | 21:1 pass | 21:1 pass |
| C-06 primary fill `accent` vs card `control` (non-text) | 18.59:1 pass | 15.13:1 pass |
| card `control` vs page (non-text) | 1.13:1 **FAIL** (known C-17 / C-18 failure) | 1.39:1 **FAIL** |
| question on photo over the scrim | photo-dependent (CONTRAST failure 8) | same |
| C-09 light pill label `onSurfaceLight` on `surfaceLight` | 21:1 pass | 21:1 pass |
| camera pill `textOnMedia` on `controlOnDeep` | 15.13:1 pass | 15.13:1 pass |

## Data & actions

- Reads: `current_group_question(p_group_id)` → `(id, question_key, week_start, hidden_by_me)` (`docs/API.md` §14.4; no
  row when the feature is off or no catalogue is configured); answers = `posts` where `question_id = id`, newest first,
  limit 1 for the card, all for the viewer.
- Writes: `answer_question(p_post_id, p_question_id)` after posting (links the post in this group to the question during
  its week); `hide_question(p_question_id)` ("Remove"); `set_group_weekly_question(p_group_id, p_on)` (the switch).
- Realtime: `posts` inserts on `group-<id>` (existing) refresh the card's photo.
- In: `groups.screen`. Out: `camera.capture` (question context), `camera.sendto`, `photo.viewer`, `groups.settings`.
- No push is sent for the question (OQ Q-5).

## Platform notes

- iOS: card in the `groups.screen` pager; `contextMenu` for Remove. Android: `combinedClickable` long press →
  `DropdownMenu`.
- The question text comes from the app's copy (localised) by `question_key`; the server stores only the key.

## Do-not-copy

Apple Journal: streaks, insights, per-person refresh of the shared question, coral / lavender card fills, caps tracked
eyebrow styling, the Journal icon. Retro prompts not used (tenet "Real, not performed" / light tone, WQ-6): "Took a nice
fit pic?", "Took a cute selfie?" (invite performance), "Something unfortunate happened?" (not light; could press for
disclosure). Retro: the "Post to see" lock, "Weeks Posted", NUX stock photos (`nux_card_*` art).
BeReal: Bonus lock for late posters, "late" labels, in-capture instructions ("Smile now…"). Anywhere: "N answered",
"waiting for {name}", "be the first", "last day to answer", reminders, badges on the card.

## Gaps

| item | status | smallest capture / decision |
|---|---|---|
| question rotation (order, repeats, per-group offset) | closed: lead decision 30 (`question.weekly.layout.rotation`, WQ-5) | — |
| default on / off for new groups | closed: on, lead decision 30 (`question.weekly.layout.defaultOn`, WQ-4) | — |
| question shown in `photo.viewer` / `week.history` / recaps | BLOCKED (not shown) | one screenshot of any app labelling an answer photo with its prompt |
| Retro's own prompt-card layout | not captured (strings + background only) | one iOS screenshot of Retro's "Ideas to share" card |
| who may switch the feature off | follows `groups.settings` permissions | — |

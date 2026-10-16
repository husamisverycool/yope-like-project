# `birthday.add` — add your birthday (optional)

Visual reference: **Retro's conversational onboarding page and empty-state block** (docs/SURFACES.md: screens 26 / 1
patterns; components C-33 onboarding pages — display serif headline + explanation, C-12 field, C-05 primary capsule,
C-08 secondary link; C-14 / C-10 for the manage state; C-29 confirmation). Retro has no birthday feature: this screen
is **composed only from Retro components** (`level: SOURCED`, method "composition of Retro components C-33, C-12,
C-05, C-08, C-14, C-10, C-29 in the age gate's order") — no new visual values. Voice: Retro set +
`retro.voice.onboarding`. Copy: `design/copy/memory.json` (`birthday.add.*`). Token: `layout.birthday.add.dateFormat`.

What it does: an optional opt-in to birthday videos. Opted in, the person's groups get one private request seven days
before (`birthday.request`) and the person receives the video on the day (`birthday.tribute`). Opting out is always
possible and deletes requests about them that are not yet due (docs/API.md `set_birthday`).

## References

| image / source | what it verifies |
|---|---|
| `references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png` (LAND, RAW dark) | centred block, 60-pt capsule at 20 pt margins, grey secondary link under it (C-33) |
| `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png` (H43) | empty-state block spacing (C-27): glyph → 26 → title → 25 → action |
| `references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png` (ED-W3) | 52-pt field, radius 19, fill (C-12) |
| Retro strings `home_feed_card_invite_suggestion_placeholder_title_friend` ("Want to see your best friend on Retro?"), `media_viewer_suggested_tag_maybe_later` ("Maybe later"), `edit_address_success_message` ("Saved!"), settings rows (RP §4.2) | voice |

## Structure

Two entry points:

**A. During sign-up — owned by `auth.agegate`.** The age gate carries the opt-in as a row under its birthday field and
calls `set_birthday(date, true)` after `confirm_age` when it is checked (`design/surfaces/auth.agegate.md`). The server
does not store the birthdate from `confirm_age`, so sign-up has no separate birthday step (MERGE memory M-31).

**B. Later — this screen**, pushed from the "Birthday" row the `settings.account` pass places (and from nowhere else;
the app never asks again on its own). Page `color.global.background` (iOS) / `color.global.background.android`;
follows the appearance. Header: native back (C-02 inside the settings sheet's navigation; iOS inline title per
`settings.*`), title `birthday.add.manage.title` ("Birthday").

*Not opted in* — a centred block in the free space above the bottom controls (C-27 placement):
1. Headline `birthday.add.title` ("Want a birthday video?") — `font.global.display`, text role `displayMedium`,
   `color.global.textPrimary`, centred, side margins `size.global.screenMargin`.
2. `size.global.emptyIconToTitle` below the headline's baseline (C-27 spacing): `birthday.add.detail`, text role
   `body`, `color.global.textSecondary` (Android `color.global.textSecondary.android`), centred.
3. `size.global.listGap` below: `birthday.add.privacy`, same role and colour.
4. `size.global.emptyTitleToAction` below: the **`auth.agegate` date field** (C-12 look, owned by the auth pass:
   neutral free entry, no default year), full width inside `size.global.screenMargin`.
5. Pinned to the bottom (safe area): primary capsule (C-05) `birthday.add.confirm` ("Add my birthday") —
   `color.global.accent` / `color.global.onAccent`, `size.global.buttonHeight`, `size.global.buttonMarginH`,
   `radius.global.button`, text role `button`; disabled (C-05 disabled: `color.global.controlRaised`) until the field
   holds a complete date.
6. Under it, the secondary link (C-08) `birthday.add.later` ("Maybe later") — text role `listTitle`,
   `color.global.textSecondary`, centred → pops. Never asked again automatically.

*Opted in (manage)* — grouped section (C-14), `size.global.screenMargin` inset:
1. Row: label `birthday.add.manage.title` ("Birthday"), trailing value = the saved day and month
   (`layout.birthday.add.dateFormat`, "July 5"), text role `body`, `color.global.textSecondary`. The birth year is
   never shown.
2. Below it, `birthday.add.detail` as the section footer (text role `meta`, `color.global.textSecondary`).
3. Separate group: destructive row (C-10) `birthday.add.manage.remove` ("Remove Birthday") in
   `color.global.destructive` → native confirmation (C-29): `birthday.add.remove.title` / `.message` / `.confirm`
   ("Yes, remove", destructive) / `.cancel`.

## Elements

| element | component · tokens | copy keys | behaviour |
|---|---|---|---|
| headline | C-33: `font.global.display`, text role `displayMedium`, `color.global.textPrimary` | `birthday.add.title` | — |
| detail, privacy | text role `body`, `color.global.textSecondary` / `.textSecondary.android`, `size.global.emptyIconToTitle`, `size.global.listGap` | `birthday.add.detail`, `birthday.add.privacy` | — |
| date field | `auth.agegate` date entry (C-12) | (owned by `auth.agegate`) | complete date enables the capsule |
| inline error | C-12 error: text role `meta`, `color.global.destructive` | `birthday.add.invalid` | under the field |
| Add my birthday | C-05 | `birthday.add.confirm` | `set_birthday(date, true)` → toast `birthday.add.added` → pop |
| Maybe later | C-08 secondary link | `birthday.add.later` | pop, no call |
| manage row | C-14: `radius.global.groupedRow`, `color.global.control` (iOS) / `color.global.surfaceSecondary.android`, text role `body`, `layout.birthday.add.dateFormat` | `birthday.add.manage.title` | static |
| Remove Birthday | C-10 + C-14 | `birthday.add.manage.remove`; dialog `birthday.add.remove.*` | `set_birthday(saved, false)` → toast `birthday.add.removed` → shows the not-opted-in state |
| toasts | C-26 (Android Toast; iOS announcement) | `birthday.add.added`, `birthday.add.removed` | — |

## States

| state | design | copy | source |
|---|---|---|---|
| loading (reading `profile_private`) | platform activity indicator centred (C-28) | — | C-28 |
| saving | the capsule shows the platform activity indicator in its label colour (C-05 busy); controls disabled | — | C-05 |
| invalid date (`invalid_birthday`) | C-12 inline error | `birthday.add.invalid` | `retro.voice.error` |
| error | C-27 error variant above the capsule: title `emptyTitle`, detail `emptyDetail`; the capsule becomes the retry | `birthday.add.error.title`, `.error.detail`, `.error.retry` | `retro.voice.error` |
| offline | C-12 inline line under the field (text role `meta`, `color.global.textSecondary`) | `birthday.add.offline` | `retro.voice.error` |
| empty / permission-denied | n/a | — | — |

## Motion

Native push / pop (`easing.global.native`), native dialog. Capsule enabled ↔ disabled: crossfade
`duration.global.crossfade`. Reduce Motion: `layout.global.reduceMotion`.

## Haptics

Capsule and rows → `haptic.global.tap` (Android). Saved / removed → `haptic.global.success`; remove confirmed →
`haptic.global.warning`; failed → `haptic.global.error`.

## Accessibility

- Headline: header. Capsule and link: their visible text. Manage row: "Birthday, July 5". Remove: button, destructive
  trait in the dialog.
- Dynamic Type: `displayMedium` → largeTitle, `body` → subheadline, `button` → headline, `listTitle` → subheadline
  (`layout.global.textStyleMap`); the block scrolls when the headline wraps; the capsule stays pinned.
- Focus order: back → headline → detail → privacy → date field → capsule → link.
- Contrast (`node tools/contrast.mjs`):

  | pair | ratio | needs | result |
  |---|---|---|---|
  | `color.global.textPrimary` on `color.global.background` | light 21.00 · dark 21.00 (Android dark #1C1C1E 17.01) | 3 (32 pt) | pass |
  | `color.global.textSecondary` on `color.global.background` (iOS) | light 2.85 · dark 7.37 | 4.5 | **FAIL in light** (Retro's grey; C-27 / failure 1 — reported) |
  | `color.global.textSecondary.android` on `color.global.background.android` | light 4.00 · dark 6.85 | 4.5 | **FAIL in light** (reported) |
  | C-05 `color.global.onAccent` on `color.global.accent` | 21.00 | 4.5 | pass |
  | link `color.global.textSecondary` (15 semibold) on the page | light 2.85 · dark 7.37 | 4.5 | **FAIL in light** (reported) |
  | row text `color.global.textPrimary` on `color.global.control` | light 18.59 · dark 15.13 | 4.5 | pass |
  | row value `color.global.textSecondary` on `color.global.control` | light 2.52 · dark 5.31 | 4.5 | **FAIL in light** (reported) |
  | `color.global.destructive` on the row fill (iOS `color.global.control` / Android `color.global.surfaceSecondary.android`) | light 3.70 / 3.90 · dark 3.62 (C-10 failure 5) | 4.5 | **FAIL** (reported) |

## Data & actions

- `rpc("set_birthday", p_birthday: date, p_opt_in: true | false)` → `profile_private`. Errors `invalid_birthday`,
  `invalid_argument`. Manage state reads `from("profile_private").select("birthday, birthday_opt_in").single()`.
- Sign-up path (on `auth.agegate`): recipe 9.1 step 2 (`confirm_age` → optionally `set_birthday` with the same date).
- **Navigation in:** the settings row (settings pass). **Out:** back to settings. No deep link, no push.

## Platform notes

- iOS: SwiftUI view pushed in the settings `NavigationStack`; native `.alert` / `.confirmationDialog` for remove.
  Android: destination in the settings graph; M3 `AlertDialog` (`color.global.system.*`).
- Date entry is the `auth.agegate` component; this surface adds no date picker of its own.
- Apple privacy label: "Other Data > Other Data Types (birthday)" applies (docs/PLATFORM_CONSTRAINTS.md §9).

## Do-not-copy

Any countdown to the birthday; asking again after "Maybe later"; showing the age or birth year; Retro's onboarding
nudges ("Finish setting up your Retro!").

## Gaps

| item | status | smallest capture that closes it |
|---|---|---|
| Retro has no birthday screen | composition of Retro components | — |
| date field | owned by `auth.agegate` | — |
| light-mode greys fail 4.5:1 | Retro's values reported, not changed (R-13) | owner / verification |

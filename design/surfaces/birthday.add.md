# `birthday.add` — add your birthday (optional)

Reference: **Yope** onboarding voice (docs/SURFACES.md). No Yope birthday screen was observed (yope-a §2.3), so the
screen is built from Yope foundations (`design/tokens/global.json`) and Yope's own words about birthdays
("If you choose to provide them, we collect your birth day and month so people you know get reminded when it's your
birthday." — yope.tv/legal). Voice: `yope.voice.permission`, `.button`, `.confirmation`, `.error`, `.lowercase`,
`.punctuation`. Copy: `design/copy/memory.json` (`birthday.add.*`). Token: `layout.birthday.add.dateFormat`.

What it does: an optional opt-in to birthday tributes. Opted in, the person's groups get one private request seven
days before (`birthday.request`) and the person receives the video on the day (`birthday.tribute`). Opting out is
always possible and deletes requests about them that are not yet due (docs/API.md `set_birthday`).

## References

| image / source | what it verifies |
|---|---|
| `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png` (V-chuong, contacts card) | Yope's in-app optional ask: a question about the benefit ("can't see your friends?") + a plain action ("enable") |
| `references/auto/yope/frames/a-virgi-7686278541255642390-t31.23-signup-es.png` (V-virgi sign-up, es) | onboarding step layout on black: big heavy title, full-width buttons at the bottom |
| `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t45.23-new-group-empty.png` (V-mthu create group) | lime primary button 45 pt, margins 19 pt |
| https://www.yope.tv/legal (Privacy) | birthday = day and month, used to remind "people you know" |
| https://yope.app/ demo text | "maybe later" |

## Structure

Two entry points, one screen layout (`color.global.backgroundDeep`, Yope onboarding step):

**A. Onboarding step — right after `auth.agegate` succeeds** (`confirm_age` ok). The birthdate entered there is not
stored by the server, so this step must come immediately after it and reuses that date (docs/API.md §2).
Top to bottom:
1. Safe-area top, then `size.global.headerInset`.
2. Title `birthday.add.title` — text role `onboardingTitle` (`fontSize.global.onboardingTitle`,
   `fontWeight.global.onboardingTitle`), `color.global.textPrimary`, centred, side margins `size.global.buttonMarginH`.
3. `size.global.listGap` below: detail `birthday.add.detail` — text role `listSubtitle`, `color.global.textSecondary`,
   centred, same margins.
4. `size.global.listGap` below: `birthday.add.privacy` — same role and colour.
5. Bottom (safe-area bottom + `size.global.buttonMarginH`): primary button `birthday.add.confirm` — `color.global.accent`
   fill, `color.global.onAccent` label, text role `button`, `size.global.buttonHeight`, margins
   `size.global.buttonMarginH`, `radius.global.button`.
6. `size.global.listGap` below it: secondary pill `birthday.add.later` — `color.global.surfaceLight`,
   `color.global.onSurfaceLight`, `radius.global.capsule`, height `size.global.buttonHeight`, same margins.

**B. Later, from settings** (the `settings.account` pass places a "birthday" row that opens this screen):
- Not opted in: same as A, but the date is entered first with the **`auth.agegate` date field component** (owned by
  the auth pass; neutral free-entry field per docs/PLATFORM_CONSTRAINTS.md §9) placed between 4 and 5; the primary
  button is disabled until a valid date is entered.
- Opted in (**manage**): title `birthday.add.manage.title` (text role `sheetTitle`), the saved day and month in
  `layout.birthday.add.dateFormat` ("26 May", text role `listTitle`, `color.global.textPrimary`), `birthday.add.detail`,
  and at the bottom the secondary pill `birthday.add.manage.remove`. The birth year is never shown.

## Elements

| element | tokens | copy keys | behaviour |
|---|---|---|---|
| title | `fontSize.global.onboardingTitle`, `fontWeight.global.onboardingTitle`, `color.global.textPrimary` (manage: `fontSize/fontWeight.global.sheetTitle`) | `birthday.add.title` / `birthday.add.manage.title` | — |
| detail, privacy line | `fontSize.global.listSubtitle`, `fontWeight.global.listSubtitle`, `color.global.textSecondary` | `birthday.add.detail`, `birthday.add.privacy` | — |
| date (manage) | `fontSize.global.listTitle`, `fontWeight.global.listTitle`, `layout.birthday.add.dateFormat` | — (formatted data) | day + month only |
| add | `color.global.accent`, `color.global.onAccent`, `size.global.buttonHeight`, `size.global.buttonMarginH`, `radius.global.button`, `fontSize/fontWeight.global.button` | `birthday.add.confirm` | `set_birthday(date, true)` → toast `birthday.add.added` → continue onboarding / close |
| maybe later | `color.global.surfaceLight`, `color.global.onSurfaceLight`, `radius.global.capsule`, `size.global.buttonHeight` | `birthday.add.later` | no call; continue onboarding / close. Never asked again automatically (settings only) |
| remove (manage) | same as maybe later | `birthday.add.manage.remove` | `set_birthday(savedDate, false)` → toast `birthday.add.removed` |
| toast | the foundations toast (lime pill, `color.global.accent` / `color.global.onAccent`, `icon.global.checkmark`) | `birthday.add.added`, `birthday.add.removed` | — |

## States

| state | design | copy | source |
|---|---|---|---|
| saving | primary button shows the platform activity indicator in place of its label; buttons disabled | — | `easing.global.native` activityIndicator |
| invalid date (`invalid_birthday`) | inline under the date field, `fontSize.global.listSubtitle`, `color.global.textSecondary` | `birthday.add.invalid` | app voice |
| error | text roles `emptyTitle` / `emptyDetail` above the buttons; primary button becomes `birthday.add.error.retry` | `birthday.add.error.title`, `birthday.add.error.detail`, `birthday.add.error.retry` | app voice |
| offline | same place as the invalid-date line | `birthday.add.offline` | app voice |
| empty / permission-denied | n/a | — | — |

## Motion

Native push / sheet only (`easing.global.native`; Yope's measured push `duration.global.navigationPush` where the
platform allows, MERGE F-11). Toast: the foundations toast motion. Reduce Motion: `layout.global.reduceMotion`.

## Haptics

Add / remove succeeded → `haptic.global.success`. Error → `haptic.global.error`.

## Accessibility

- Title: header trait. Buttons: their visible text. Date: read in full ("26 May").
- Dynamic Type: roles map through `layout.global.textStyleMap` (onboardingTitle → largeTitle, listSubtitle →
  subheadline, button → subheadline, sheetTitle → title3, listTitle → headline). The content scrolls when the title
  wraps at accessibility sizes; buttons stay pinned to the bottom.
- Focus order: title → detail → privacy → (date) → primary → secondary.
- Contrast (foundations, `design/CONTRAST.md`): `textPrimary` on `backgroundDeep` 21.00 pass; `textSecondary` #969696
  on #000000 7.10 pass; `onAccent` on `accent` 17.65 pass; `onSurfaceLight` on `surfaceLight` 21.00 pass;
  `surfaceLight` pill vs `backgroundDeep` 21.00 pass.

## Data & actions

- `rpc("set_birthday", p_birthday: date, p_opt_in: true | false)` → `profile_private`. Errors `invalid_birthday`,
  `invalid_argument`. Manage state reads `from("profile_private").select("birthday, birthday_opt_in").single()`.
- Onboarding: recipe 9.1 step 2 (`confirm_age` → optionally `set_birthday` with the same date).
- **Navigation in:** onboarding after `auth.agegate`; settings row (settings pass). **Out:** onboarding continues to
  `auth.profile`; from settings, back. No deep link, no push.

## Platform notes

- iOS: plain SwiftUI screen in the onboarding `NavigationStack`; Android: Compose destination in the onboarding graph.
- Date entry is the `auth.agegate` component; this surface adds no date picker of its own.
- Apple privacy label: "Other Data > Other Data Types (birthday)" applies (docs/PLATFORM_CONSTRAINTS.md §9).

## Do-not-copy

Yope's streaks and forced invites; any countdown to the birthday; asking again after "maybe later"; showing the age
or birth year; Yope's notification pre-prompt that imitates the system alert.

## Gaps

| item | status | owner capture |
|---|---|---|
| Yope's own birthday screen (layout, copy) | not found; built from foundations + Yope's privacy wording | one 30 s English screen recording of a fresh Yope sign-up through the phone path (yope-a §2.1 capture) |
| date field | owned by `auth.agegate` | same |

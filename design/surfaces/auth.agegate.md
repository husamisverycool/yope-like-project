# `auth.agegate` — birthday / age gate at sign-up

Visual reference: Retro sign-up (inventory #26; Retro confirms age in its landing fine print, "I confirm that I am %1$d
or older", LAND / APK-S `onboarding_landing_welcome_by_continuing`). This app keeps a **neutral age screen** (FTC COPPA
FAQ, `docs/PLATFORM_CONSTRAINTS.md` §9), drawn as the onboarding form composition of `auth.phone` B:
`level: SOURCED`, `method: "composition of Retro components C-02, C-12, C-14, C-05 in Retro's sign-up order"`
(MERGE RA-4). API: `docs/API.md` §2, §6.3 (`confirm_age`, `set_birthday`), §12 item 6. Tokens: `auth.agegate.*`.
Copy: `auth.agegate.*`.

**Minimum age:** 13 (`app_config.min_age_years`, owner decision 26; the sign-up age in BeReal's, Locket's, Retro's and
Yope's terms, design/research/platform.md "auth.agegate — minimum age"). No age appears before submission; the refusal
uses `{min_age}` from `public_app_config.min_age_years`; should the value ever be unset, `confirm_age` fails closed
(`age_gate_not_configured`, the "not open yet" state).

## References

| id | file / URL | used for |
|---|---|---|
| LAND | `references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png` | page and capsule; Retro's age sentence (not copied, RA-4) |
| VID-SET | `references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png` | grouped row with a switch (C-14) for the opt-in |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `error_message_invalid_auth_code` (error pattern), `error_message_not_available_in_country` (refusal pattern), `settings_title_lock_friend_requests` (row label pattern) |
| FTC | docs/PLATFORM_CONSTRAINTS.md §9 | neutral entry rules (`auth.agegate.layout.dateEntry`) |

## Structure (page `color.global.background` / `.background.android`)

1. C-02 header row without a back chevron (the account exists after `auth.code`; going back would not undo it).
2. Title `auth.agegate.title` (`font.global.display`, `displayMedium`), leading, baseline `size.global.titleTop`.
3. Explanation `auth.agegate.subtitle` directly under it (`body`, `color.global.textSecondary`).
4. `size.global.titleToContent` below: birthday field C-12 (`auth.agegate.layout.dateEntry`), placeholder
   `auth.agegate.field.placeholder` (the locale's numeric date format).
5. `size.global.titleToContent` below: opt-in group `auth.agegate.layout.optIn` — C-14 single row: title
   `auth.agegate.optIn.label`, subtitle `auth.agegate.optIn.detail`, trailing native switch (off).
6. Primary capsule C-05 `auth.agegate.continue`, pinned `size.global.buttonMarginH` above the number keyboard.

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| title / explanation | `displayMedium`; `body` + `color.global.textSecondary` | `auth.agegate.title`, `auth.agegate.subtitle` | static; no age shown |
| birthday field | C-12 (`color.global.control`, `size.global.fieldHeight`, `radius.global.field`, text role `placeholder`), `auth.agegate.layout.dateEntry` | `auth.agegate.field.placeholder` ({date_format}), `auth.agegate.field.accessibilityLabel` | free numeric entry, separators inserted in locale order; empty by default; no default year |
| opt-in row | C-14: fill `color.global.control` (iOS) / `color.global.surfaceSecondary.android`, `radius.global.groupedRow`, inset `size.global.screenMargin`, title `body`, subtitle `meta` `color.global.textSecondary`; switch tint `color.global.selection` / `color.global.system.primary`; min height `settings.root.size.rowHeight` | `auth.agegate.optIn.label`, `auth.agegate.optIn.detail`, `auth.agegate.optIn.accessibilityLabel` | off by default; the whole row toggles |
| Next | C-05 (disabled until the date is complete; busy as C-05) | `auth.agegate.continue` | `confirm_age(p_birthdate)`; if the switch is on, then `set_birthday(p_birthday, true)` |
| error alert | `auth.phone.layout.inlineError` (message only) | `auth.agegate.error.invalidDate` + `auth.phone.error.dismiss` | — |

## States

| state | when | design | copy |
|---|---|---|---|
| default | after `auth.code` for a new account | as Structure | — |
| checking | RPCs in flight | Next busy (C-05 / C-28) | — |
| invalid date | `invalid_birthdate` or unparseable | error alert | `auth.agegate.error.invalidDate` |
| not configured | `age_gate_not_configured` (503) | C-27 block (no glyph) replacing 2–6, centred: title `emptyTitle`, explanation `emptyDetail` `textSecondary`, outline capsule C-06 | `auth.agegate.notConfigured.title`, `.detail`, `.retry` |
| under age | `under_minimum_age` (403) | C-27 block without an action; the session is signed out; the refusal is remembered on the device (Keychain / Keystore-backed preference) so going back cannot retry | `auth.agegate.underAge.title` ({min_age}), `auth.agegate.underAge.detail` |
| offline | no connection | title stays; C-27 block replaces 4–6 | `auth.phone.offline.*` |
| loading / empty / permission-denied | — | not applicable | — |

## Motion

Push in from `auth.code`; out by native push to `auth.profile`. State swaps cross-fade `duration.global.crossfade`
(100 ms, `easing.global.standard`). Reduce Motion: unchanged (cross-fade only).

## Haptics

Press → `haptic.global.tap` (Android). Switch → system (`settings.root.layout.toggleHaptic`). Confirmed →
`haptic.global.success`; refused / failed → `haptic.global.error`.

## Accessibility

- Field label `auth.agegate.field.accessibilityLabel`, the format read as its hint. Opt-in: one toggle element
  (`auth.agegate.optIn.accessibilityLabel`), detail as hint (iOS `.isToggle`; Android `Role.Switch`).
- Dynamic Type: title `largeTitle`; explanation, row title `subheadline`; row subtitle `footnote`; field `body`.
- Focus order: title → explanation → field → opt-in → Next.
- Contrast: rows 1, 3, 9, 11, 12, 13 of `design/CONTRAST.md` (as `auth.phone` B); switch tint on the row: system;
  row subtitle `textSecondary` on #F1F1F1 **2.52:1 FAIL** (light, row 11), 5.31:1 dark.

## Data & actions

- `rpc("confirm_age", { p_birthdate })` → `profile_private` (sets `age_confirmed_at`; the date is not stored).
- Opted in: `rpc("set_birthday", { p_birthday, p_opt_in: true })`.
- `public_app_config.min_age_years` (anon) only for `{min_age}` in the refusal.
- iOS 26: Declared Age Range (`com.apple.developer.declared-age-range`) where the law requires; Android: Play Age
  Signals (beta) — system sheets (PLATFORM_CONSTRAINTS §9).
- In: `auth.code` (new account) or any launch where `age_confirmed_at` is null. Out: `auth.profile`.

## Platform notes

- Numeric entry: iOS `.keyboardType(.numberPad)`, Android `KeyboardType.Number`. No wheel `DatePicker` (it shows a
  default date, against the neutral-screen rule).

## Do-not-copy

- Retro's age sentence in the landing fine print (reveals the cutoff); any 13+ dropdown or default year.

## Gaps

| item | status | owner action / capture |
|---|---|---|
| `min_age_years` | closed: 13 (owner decision 26, migration 20261017000026) | — |
| auth user on refusal | `confirm_age` stores nothing, but the phone account exists | backend / owner confirmation |
| Retro form layout | composition | raw screenshots of the first sign-up steps (RV §6) |

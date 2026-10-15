# `auth.agegate` — birthday / age gate at sign-up

Reference: **Yope onboarding**. Research: `design/research/yope-a.md` §2.3 (Terms 13+, privacy policy on birthdays);
platform: `docs/PLATFORM_CONSTRAINTS.md` §9 (COPPA neutral age screen, Declared Age Range, Play Age Signals);
API: `docs/API.md` §2, §6.3 (`confirm_age`, `set_birthday`), §12 item 6. Tokens: `auth.agegate.*` + the shared
sign-up/form tokens. Copy: `auth.agegate.*`.

**Yope's birthday screen was not found** (no 2024–2026 source; Apple/Google sign-in may skip it). The entry field is
Yope's form field; the entry rules are the FTC's; nothing else is invented.

**Minimum age:** Yope's Terms say 13+, but `app_config.min_age_years` is unset (owner decision). No age number appears
in any string: the refusal uses `{min_age}` from `public_app_config.min_age_years`, and while it is null `confirm_age`
fails closed with `age_gate_not_configured` (the "not open yet" state).

## References

As `auth.phone` (S24, S26, C24, BI, NG, HUD), plus NG check circles (`…-t49.23-new-group-selected-create.png`) for the
opt-in row, and `docs/PLATFORM_CONSTRAINTS.md` §9 for the entry rules.

## Structure (black, centred)

1. Status bar. 2. Header row: none — back is not offered (the account exists after `auth.code`; going back would not undo
   it). 3. Title `auth.agegate.title`. 4. Subtitle `auth.agegate.subtitle` (italic subtitle style).
5. Gap `groups.create.size.titleToContent`. 6. Birthday field. 7. Gap `groups.create.size.fieldToButton`.
8. Opt-in row (full width minus `size.global.buttonMarginH`). 9. Gap `groups.create.size.fieldToButton`.
10. Primary button `auth.agegate.continue`. 11. System number keyboard.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| title / subtitle | onboarding title tokens; `auth.phone.fontSize.subtitle`, `auth.phone.layout.subtitle` | `auth.agegate.title`, `auth.agegate.subtitle` | static; no minimum age shown |
| birthday field | `auth.agegate.layout.dateEntry` (Yope form field: `groups.create.color.field`, `size.global.fieldHeight`, `radius.global.field`, `groups.create.fontSize.fieldText`) | `auth.agegate.field.placeholder` ({date_format}), `auth.agegate.field.accessibilityLabel` | free entry, numeric keyboard, separators inserted in the locale's order as the person types; empty by default; no default year |
| opt-in row | `auth.agegate.layout.optIn`: `icon.global.uncheck` / `icon.global.check` in `color.global.selection`, `size.global.checkCircle`; label `fontSize.global.listSubtitle` `color.global.textPrimary`; detail `fontSize.global.listSubtitle` `color.global.textSecondary` | `auth.agegate.optIn.label`, `auth.agegate.optIn.detail`, `auth.agegate.optIn.accessibilityLabel` | unchecked by default; the whole row toggles it |
| continue | lime primary + disabled tokens (as `auth.phone`) | `auth.agegate.continue` | enabled when the field holds a complete date; tap → `confirm_age(p_birthdate)`; when checked, then `set_birthday(p_birthday, true)` |
| HUD | `groups.create.color.hud`, `.size.hud`, `.fontSize.hudLabel` | `groups.create.hud.loading` | while the RPCs run |

## States

| state | when | design | copy |
|---|---|---|---|
| default | after `auth.code` for a new account | as Structure | — |
| checking | RPC in flight | HUD | `groups.create.hud.loading` |
| invalid date | `invalid_birthdate` or unparseable | presentation **BLOCKED** (`auth.phone.layout.inlineError`) | `auth.agegate.error.invalidDate` |
| not configured | `age_gate_not_configured` (503; `min_age_years` null) | Yope empty-state layout replacing 3–10 (title `fontSize.global.emptyTitle` bold, detail `fontSize.global.emptyDetail` italic `color.global.textSecondary`, white pill `color.global.surfaceLight` / `groups.screen.radius.lightPill` / `groups.screen.size.lightPillHeight`) | `auth.agegate.notConfigured.title`, `.detail`, `.retry` |
| under age | `under_minimum_age` (403) | same empty-state layout, no button; the session is signed out; the refusal is remembered on the device (Keychain / Android Keystore-backed preference) so the screen cannot be retried by going back | `auth.agegate.underAge.title` ({min_age}, {app_name}), `auth.agegate.underAge.detail` |
| offline | no connection | empty-state layout + retry pill | `auth.phone.offline.title`, `auth.agegate.offline.detail`, `auth.phone.offline.retry` |
| permission-denied | — | none | — |

## Motion

Native push in; replacement by `auth.profile` with a native push. State changes swap content without animation
(no measured Yope transition); Reduce Motion: unchanged.

## Haptics

Opt-in toggled → `haptic.global.select`. Confirmed → `haptic.global.success`. Refused / failed → `haptic.global.error`.

## Accessibility

- Field label `auth.agegate.field.accessibilityLabel`; the placeholder's format is also read as the hint.
- Opt-in row: one element, label `auth.agegate.optIn.accessibilityLabel`, trait toggle (iOS `.isToggle`, Android
  `Role.Checkbox` with `toggleableState`), detail as its hint.
- Dynamic Type: title `largeTitle`; subtitle, field, row text `subheadline`.
- Focus order: title → subtitle → field → opt-in → continue.
- Contrast: as `auth.phone`; check circle #0091FF on black (global pair, non-text) pass.

## Data & actions

- `rpc("confirm_age", { p_birthdate })` → `profile_private` (sets `age_confirmed_at`; the date is not stored).
- When opted in: `rpc("set_birthday", { p_birthday, p_opt_in: true })` (stores the date for tributes).
- `public_app_config` `min_age_years` (anon read) only to fill `{min_age}` in the refusal.
- iOS 26: also request the Declared Age Range (`com.apple.developer.declared-age-range`) and honour its result where the
  law requires (PLATFORM_CONSTRAINTS §9); Android: Play Age Signals (beta). Their own sheets are system UI.
- In: `auth.code` (new account) or any launch where `age_confirmed_at` is null. Out: `auth.profile`.

## Platform notes

- iOS numeric entry: `.keyboardType(.numberPad)`; Android `KeyboardType.Number`. Do not use a wheel `DatePicker` (it
  shows a default date, against the neutral-screen rule, and Yope evidence for it is absent).

## Do-not-copy

- Any 13+ dropdown, default year, or wording that reveals the cutoff before entry (FTC). Yope's store ratings
  (4+ / 12+) and Terms (13+) conflict; none of those numbers is written into the copy.

## Gaps

| item | status | owner action / capture |
|---|---|---|
| `min_age_years` | owner decision (docs/API.md §12 item 6) | set the value; the copy needs no change |
| deletion of the entered data on refusal | backend: `confirm_age` stores nothing, but the auth user (phone number) exists; the "we didn’t save … your number" detail is true only if the client calls a delete (e.g. `delete_account`) on `under_minimum_age` | backend/owner confirmation |
| error presentation | BLOCKED (`auth.phone.layout.inlineError`) | ~40 s English recording of a fresh Yope install via "try other options" |
| Yope's own birthday screen | not found | same recording |
| back-button retry prevention method | counsel to confirm (PLATFORM_CONSTRAINTS §9) | — |

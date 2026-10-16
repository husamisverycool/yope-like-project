# `auth.phone` — landing and phone number entry

Visual reference: **Retro sign-up landing** (inventory #26, RAW dark) and Retro's sign-up order PHONE_NUMBER → AUTH_CODE →
USER_NAME → FULL_NAME (`docs/SURFACES.md`; RP §6.3). Retro's form screens were not captured as images (RV §2 rows 36–41),
so the phone step is a **composition of Retro components C-02, C-12, C-05, C-08 in Retro's sign-up order**
(`level: SOURCED`, `method: "composition of Retro components C-02, C-12, C-05, C-08 in Retro's sign-up order (APK enum e4b)"`).
Tokens: `design/tokens/account.json` (`auth.phone.*`) + `global.*`. Copy: `design/copy/account.json` (`auth.phone.*`).
Components: `design/components.md`.

Two states of one surface: **A. landing** (first launch, signed out) and **B. phone form** (after "Get started" or
"already have an account?"). One-time-code sign-in serves new and returning accounts, so both entries open B.

## References

| id | file | used for |
|---|---|---|
| LAND | `references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png` (RAW iOS dark, 3.000 px/pt) | landing: wordmark block, grey tagline 30 pt, white 60 pt capsule at 20 pt margins, grey lower-case link, 14 pt fine print with underlined links; all vertical gaps (`auth.phone.size.*`) |
| WEB | `references/auto/retro/web/retro.app-5bff8a0be69f7ec7.css` (`.page_largeRetroWordmark` 4rem) | wordmark size `auth.phone.fontSize.wordmark` |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | form copy: `onboarding_form_input_hint_phone_number`, `onboarding_form_input_next`, `onboarding_landing_phone_number_error`, `onboarding_landing_welcome_*` |
| H43 | `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png` | title baseline 64 below the safe area (C-01 metric used for the form title) |
| RNPI | react-native-phone-input 1.4.1 (MIT, public npm package; `dist/styles.js`, `dist/PhoneInput.js`, README) + https://developer.android.com/reference/android/telephony/PhoneNumberFormattingTextWatcher | country-code mechanics and sizes (`auth.phone.layout.countryCode`: flag 30 × 20 at C-12's text inset, 10 to the number, flag tap → country list, formatted while typing); re-sourced by owner decision 22 |

## Structure

### A. Landing (page `color.global.background` iOS / `color.global.background.android`; C-33)
1. Status bar (system; follows the appearance).
2. **Wordmark block**, centred horizontally, block centre at `auth.phone.layout.landingBlock.centreY` × screen height:
   - wordmark = the app's name in `font.global.display`, `auth.phone.fontSize.wordmark` (64), regular,
     `color.global.textPrimary` — owner asset, **BLOCKED** until `config/app.json` `displayName` (or a logo) exists;
   - `auth.phone.size.wordmarkToTagline` (19.3) below its baseline: tagline `auth.phone.tagline`, text role
     `onboardingTitle` (30 regular), `color.global.textSecondary`, centred.
3. Flexible space.
4. **Primary capsule** C-05 `auth.phone.getStarted`, full width minus `size.global.buttonMarginH` (20) each side,
   `size.global.buttonHeight` (60).
5. `auth.phone.size.capsuleToLink` (20.7) below: secondary link C-08 `auth.phone.signIn` (text role `listTitle`,
   `color.global.textSecondary`, lower case as written), centred.
6. `auth.phone.size.linkToLegal` (28.4) below: fine print `auth.phone.legal.text`, text role `caption` (14, line
   `lineHeight.global.caption` 21.7), `color.global.textSecondary`, centred, side margins `size.global.screenMargin`;
   the ranges `auth.phone.legal.terms` and `auth.phone.legal.privacy` underlined (LAND); last line's ink bottom
   `auth.phone.size.legalToBottom` (40) above the screen bottom.

### B. Phone form (same page colour; onboarding form composition, used by every `auth.*` step)
1. C-02 header row: back chevron `icon.global.back` at `size.global.backInset` → returns to A (no title in the row).
2. Title `auth.phone.title`: `font.global.display`, text role `displayMedium` (32), `color.global.textPrimary`,
   leading at `size.global.screenMargin`, baseline `size.global.titleTop` (64) below the safe-area top (C-01 metric).
3. Explanation `auth.phone.subtitle` directly under the title (text role `body`, `color.global.textSecondary`), the way
   C-19 sets the real name under the serif name.
4. `size.global.titleToContent` (30) below: phone field C-12 (full width inside `size.global.screenMargin`), placeholder
   `auth.phone.field.placeholder`; country flag slot and inline calling code per `auth.phone.layout.countryCode`;
   keyboard per `auth.phone.layout.keyboard`, raised on appear.
5. Primary capsule C-05 `auth.phone.continue` ("Next") pinned `size.global.buttonMarginH` above the keyboard (or the
   bottom safe area when the keyboard is down), full width minus `size.global.buttonMarginH`.

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| wordmark | `font.global.display`, `auth.phone.fontSize.wordmark`, `color.global.textPrimary`, `auth.phone.layout.landingBlock` | app name (BLOCKED) | static |
| tagline | text role `onboardingTitle`, `color.global.textSecondary`, `auth.phone.size.wordmarkToTagline` | `auth.phone.tagline` | static |
| Get started | C-05 (`color.global.accent` / `color.global.onAccent`, `size.global.buttonHeight`, `radius.global.button`, text role `button`) | `auth.phone.getStarted` | → state B (page transition, Motion) |
| already have an account? | C-08 secondary link (text role `listTitle`, `color.global.textSecondary`), hit area ≥ `size.global.minTouchTarget.*` | `auth.phone.signIn` | → state B |
| fine print | text role `caption`, `lineHeight.global.caption`, `color.global.textSecondary`; links underlined, same colour | `auth.phone.legal.text` with ranges `auth.phone.legal.terms`, `auth.phone.legal.privacy` | links open `config/app.json` `legal.termsUrl` / `legal.privacyUrl` in SFSafariViewController / Custom Tabs |
| back | C-02 (`icon.global.back`, `color.global.textPrimary`, `size.global.backInset`, hit `size.global.headerButton`) | `auth.code.back.accessibilityLabel` | → state A |
| title / explanation | `font.global.display` + `displayMedium`; `body` + `color.global.textSecondary` | `auth.phone.title`, `auth.phone.subtitle` | static |
| phone field | C-12: `color.global.control`, `size.global.fieldHeight`, `radius.global.field`, text role `placeholder` (typed text `color.global.textPrimary`, placeholder `color.global.textSecondary`); `auth.phone.layout.countryCode`, `auth.phone.layout.keyboard` | `auth.phone.field.placeholder`, `auth.phone.field.accessibilityLabel` | pre-filled "+" and the region's calling code; auto-formats; flag tap → country list (native sheet, C-29); normalised to E.164 before sending |
| Next | C-05; disabled = `color.global.controlRaised` fill, `color.global.onAccent` label (C-05 disabled); busy = platform activity indicator in the label colour (C-05 busy) | `auth.phone.continue` | enabled when digits follow the calling code; tap → `signInWithOTP`; on success push `auth.code` |
| error alert | `auth.phone.layout.inlineError` (native, C-29) | `auth.phone.error.invalidNumber` / `.rateLimited` / `.sendFailed` + `auth.phone.error.dismiss` | message-only alert; field keeps its text |

## States

| state | when | design | copy | source |
|---|---|---|---|---|
| landing | signed out, first screen | A | as above | LAND (RAW) |
| form (default) | after Get started / the link | B, keyboard up | as above | composition (C-02, C-12, C-05) |
| sending | `signInWithOTP` in flight | Next shows the activity indicator (C-05 busy, C-28); field and back disabled | — | C-05 / C-28 |
| invalid number | E.164 parse fails or Supabase rejects it | error alert | `auth.phone.error.invalidNumber` + `auth.phone.error.dismiss` | APK-S `onboarding_landing_phone_number_error` |
| rate limited | second request within 60 s (HTTP 429) | error alert | `auth.phone.error.rateLimited` + dismiss | PLATFORM_CONSTRAINTS §7 |
| send failed | 5xx / provider error | error alert | `auth.phone.error.sendFailed` + dismiss | APK-S `error_message_generic` |
| offline | no connection (NWPathMonitor / ConnectivityManager) on B | the title block stays; field and capsule are replaced by the C-27 block (no glyph), centred in the remaining space: title `auth.phone.offline.title` (text role `emptyTitle`), explanation `auth.phone.offline.detail` (`emptyDetail`, `color.global.textSecondary`), outline capsule C-06 `auth.phone.offline.retry` | `auth.phone.offline.*` | C-27 error / offline variant |
| loading / empty / permission-denied | — | not applicable (no list, no permission) | — | — |

Light and dark: both appearances use the same layout; LAND is the only capture (dark). In light, the page is
`color.global.background` #FFFFFF with black text and a black capsule (C-05 light values).

## Motion

- A → B and back: Retro's onboarding page transition — enter fade + expand, exit fade + shrink, `duration.global.pageTransition`
  (500 ms) with `easing.global.standard` (APK-X; C-33). Reduce Motion (`layout.global.reduceMotion`): cross-fade of the same duration.
- B → `auth.code`: native navigation push (`easing.global.native` navigationPush — Retro's push not captured, R-14).
- Keyboard, alerts, the country sheet (`spring.global.sheetPresent`): system.

## Haptics

| interaction | token |
|---|---|
| Get started, link, Next, back (press) | `haptic.global.tap` (Android VIRTUAL_KEY before the action; iOS none) |
| typing | none (system keyboard) |
| request failed | `haptic.global.error` (PLATFORM outcome, R-12) |

## Accessibility

- Wordmark: header trait, read as the app's name. Tagline: static text. Fine print: one text element with two link
  elements ("Terms", "Privacy Policy"; `.link` trait / `LinkAnnotation`).
- Form: title has the header trait; field label `auth.phone.field.accessibilityLabel`; Next announces its busy state.
- Dynamic Type (`layout.global.textStyleMap`): wordmark and title `largeTitle`; tagline `title`; link `subheadline`;
  fine print `subheadline`; field `body`; capsule `headline`. The landing block may wrap; the form scrolls above the keyboard.
- Focus order A: wordmark → tagline → Get started → link → fine print (Terms, Privacy Policy). B: back → title →
  explanation → field → Next.
- Contrast (`node tools/contrast.mjs`, `design/CONTRAST.md`):

| pair | light | dark |
|---|---|---|
| wordmark / title `textPrimary` on page | 21:1 pass (row 1) | 21:1 pass (Android 17.01:1, row 2) |
| tagline `textSecondary` 30 pt on page (large) | **2.85:1 FAIL** (row 4) | 7.37:1 pass |
| link 15 semibold / fine print 14 `textSecondary` on page | **2.85:1 FAIL** (row 3) | 7.37:1 pass |
| capsule label on fill | 21:1 pass (row 17) | 21:1 pass |
| typed text on field | 18.59:1 pass (row 9) | 15.13:1 pass |
| placeholder `textSecondary` on field | **2.52:1 FAIL** (row 11) | 5.31:1 pass |
| field fill vs page (non-text) | **1.13:1 FAIL** (row 13) | **1.39:1 FAIL** |

  Failures are Retro's own light palette (R-13), reported, not adjusted; the field's label carries its purpose.

## Data & actions

- `supabase.auth.signInWithOTP(phone:)` (docs/API.md §2; Twilio Verify). Error mapping: "invalid phone" → invalid
  number; HTTP 429 → rate limited; other → send failed.
- In: cold launch without a session; after sign-out (`settings.root`) or account deletion (`settings.account`, toast
  `settings.account.deleted.toast` on Android); installing from an invite (`DeepLink.invite(token:)` /
  `DeepLink.Invite` stored until onboarding ends, then `join_group`, docs/API.md §9.3).
- Out: `auth.code` with the normalised number.

## Platform notes

- iOS: `.keyboardType(.phonePad)`, `.textContentType(.telephoneNumber)`; status bar follows the appearance (the forced
  dark appearance is removed in Pass 3).
- Android: `KeyboardType.Phone`, `ContentType.PhoneNumber`; page `color.global.background.android` (#1C1C1E dark);
  Inter for UI text (`font.global.family`).
- App Clip: `invite.appclip` runs the same B → `auth.code` → `auth.agegate` → `auth.profile` (name step) screens.

## Do-not-copy

- Retro's wordmark, 3-D "R" mark and Roslindale files (LAND); "Continue with Apple / Google" (phone OTP only,
  docs/API.md §2); the age statement inside the fine print ("I confirm that I am 13 or older") — the neutral age
  screen `auth.agegate` must not reveal the cutoff first (MERGE RA-4).

## Gaps

| item | status | smallest capture / owner input |
|---|---|---|
| wordmark | BLOCKED: owner's name or logo (`config/app.json` displayName) | owner decision 0.1 / 0.2 |
| Retro's phone form (title, field, button placement) | composition of C-02 / C-12 / C-05 | raw screenshots of the first 4 sign-up steps on a fresh install (RV §6) |
| light landing | dark geometry reused | one raw light screenshot of the landing |
| country selector | Locket mechanics in C-12 | same sign-up capture |
| SMS / carrier disclosure under the field | not researched (counsel) | — |

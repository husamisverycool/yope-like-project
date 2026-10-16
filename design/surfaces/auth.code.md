# `auth.code` — SMS code entry

Visual reference: Retro's AUTH_CODE sign-up step (inventory #26 page, APK order PHONE_NUMBER → AUTH_CODE; RP §6.3).
The step was not captured as an image, so it is the **onboarding form composition** of `auth.phone` (state B):
`level: SOURCED`, `method: "composition of Retro components C-02, C-12, C-05, C-08 in Retro's sign-up order (APK enum e4b)"`.
Tokens: `auth.code.*`, `auth.phone.layout.inlineError` + `global.*`. Copy: `auth.code.*`.

## References

| id | file / URL | used for |
|---|---|---|
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `invite_redemption_title` ("Enter your code"), `onboarding_form_input_hint_auth_code`, `onboarding_form_input_auth_code_please_wait`, `onboarding_form_input_resend_auth_code_prefix` / `_resend`, `error_message_*_auth_code*`, `onboarding_landing_error_*` |
| LAND | `references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png` | page colours, capsule, grey secondary link (C-08) |
| AF | https://developer.apple.com/documentation/security/enabling-password-autofill-on-a-text-input-view ; https://developers.google.com/identity/sms-retriever/user-consent/request | one-time-code AutoFill, SMS User Consent |

## Structure (page `color.global.background` / `.background.android`)

1. C-02 header row: back chevron (`icon.global.back`, `size.global.backInset`) → `auth.phone` (number kept).
2. Title `auth.code.title` (`font.global.display`, `displayMedium`, `color.global.textPrimary`), leading at
   `size.global.screenMargin`, baseline `size.global.titleTop` below the safe-area top.
3. Explanation `auth.code.subtitle` directly under it (`body`, `color.global.textSecondary`).
4. `size.global.titleToContent` below: code field C-12 (`auth.code.layout.codeField`), placeholder `auth.code.field.placeholder`.
5. `size.global.sectionHeaderToContent` (11.7) below the field: helper `auth.code.helper` (text role `caption`,
   `color.global.textSecondary`, leading).
6. Resend line under the helper, same gap: `auth.code.resend.prefix` (text role `caption`, `color.global.textSecondary`)
   followed by the text button `auth.code.resend` (C-08 secondary link style: text role `listTitle`,
   `color.global.textSecondary`), one line, leading.
7. Primary capsule C-05 `auth.code.continue`, pinned `size.global.buttonMarginH` above the keyboard; system number
   keyboard (Android: the SMS User Consent sheet may appear over it).

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| back | C-02 | `auth.code.back.accessibilityLabel` | pop to `auth.phone` |
| title / explanation | `displayMedium` + `font.global.display`; `body` + `textSecondary` | `auth.code.title`, `auth.code.subtitle` ({phone} international format) | static |
| code field | C-12 + `auth.code.layout.codeField` | `auth.code.field.placeholder`, `auth.code.field.accessibilityLabel` | digits only; AutoFill / consent fills it; no per-digit boxes |
| helper | text role `caption`, `color.global.textSecondary` | `auth.code.helper` | static |
| Send again | C-08 link; dimmed (`color.global.textTertiary`, inactive) for `auth.code.duration.resendLock` after each request, no countdown | `auth.code.resend.prefix`, `auth.code.resend` | sends `signInWithOTP` again; confirmation `auth.code.toast.resent` (C-26: Android Toast; iOS accessibility announcement) |
| Next | C-05 (disabled / busy as C-05) | `auth.code.continue` | enabled with ≥ 1 digit; tap → `verifyOTP` |
| error alert | `auth.phone.layout.inlineError` (titled; two recovery buttons) | see States | — |

## States

| state | when | design | copy |
|---|---|---|---|
| default | code sent | as Structure | — |
| verifying | `verifyOTP` in flight | Next busy (C-05 / C-28) | — |
| wrong code | Supabase "invalid token" | alert, field cleared | title `auth.code.error.wrong.title`, message `auth.code.error.wrong`; buttons `auth.code.error.editCode` (closes, focuses the field) and `auth.code.error.sendNew` (resends) |
| expired | token older than its lifetime | alert | `auth.code.error.expired.title`, `auth.code.error.expired`; buttons `.sendNew`, `.editCode` |
| verification service / network error | request failed | alert | `auth.code.error.service.title`, `auth.code.error.service`; button `auth.phone.error.dismiss` |
| too many tries | HTTP 429 | message-only alert | `auth.code.error.tooMany` + `auth.phone.error.dismiss` |
| offline | no connection | title block stays; C-27 block replaces the field and capsule (as `auth.phone` offline) | `auth.phone.offline.title`, `auth.phone.offline.detail`, `auth.phone.offline.retry` |
| success, new account | session created, `profile_private.age_confirmed_at` null | push `auth.agegate` | — |
| success, returning | age confirmed and `display_name` set | replace the stack with `groups.list` (pending invite → `join_group` first) | — |
| empty / permission-denied | — | not applicable | — |

## Motion

Native push in / out (`easing.global.native`); keyboard, consent sheet and alerts are system. The resend link changes
state with `duration.global.crossfade` (100 ms). Reduce Motion: platform behaviour; the crossfade stays.

## Haptics

Next / Send again / back presses → `haptic.global.tap` (Android only). Verified → `haptic.global.success`; wrong /
expired / failed → `haptic.global.error` (PLATFORM outcomes, R-12). No key haptics (system keyboard).

## Accessibility

- Field label `auth.code.field.accessibilityLabel`; the helper is read after the field; Send again is a button whose
  dimmed state is announced as disabled; after a resend the confirmation is announced (`AccessibilityNotification.Announcement`).
- Dynamic Type: title `largeTitle`; explanation `subheadline`; field `body`; helper and resend `subheadline`; capsule `headline`.
- Focus order: back → title → explanation → field → helper → Send again → Next.
- Contrast: as `auth.phone` B (rows 1, 3, 9, 11, 13, 17): helper / resend `textSecondary` on the light page **2.85:1 FAIL**
  (dark 7.37:1 pass); the dimmed link `textTertiary` 1.80:1 / 2.48:1 (inactive control, exempt).

## Data & actions

- `supabase.auth.verifyOTP(phone:, token:, type: .sms)` (docs/API.md §2); resend = `signInWithOTP` (Twilio Verify returns
  the same code within its lifetime).
- After success: read `profile_private` (own row, docs/API.md §5.2) and `profiles.display_name` to choose the next step.
- In: `auth.phone`; `invite.appclip`. Out: `auth.agegate` (new) or `groups.list` (returning).

## Platform notes

- iOS: `.textContentType(.oneTimeCode)`, `.keyboardType(.numberPad)`.
- Android: `SmsRetriever.getClient(context).startSmsUserConsent(null)` on appear; extract a 4–10 digit code;
  `ContentType.SmsOtpCode` autofill as well.

## Do-not-copy

- Retro's "Get Help" sheet action (`onboarding_landing_error_sheet_cta`): no help destination exists.
- Any countdown on the resend link (Retro shows none).

## Gaps

| item | status | smallest capture |
|---|---|---|
| Retro's code step layout | composition | raw screenshots of the first 4 sign-up steps on a fresh install (RV §6) |
| helper / resend placement | composition (C-20 header → content gap reused) | same capture |

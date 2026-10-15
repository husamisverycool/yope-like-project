# `auth.code` — SMS code entry

Reference: **Yope onboarding**. Research: `design/research/yope-a.md` §2.2 (Terms: "you will be provided a verification
code … and asked to input the verification code"); platform: `docs/PLATFORM_CONSTRAINTS.md` §7. Tokens:
`auth.code.*`, `auth.phone.*`, `groups.create.*` (`design/tokens/account.json`). Copy: `auth.code.*`.

**Yope's code screen was not found** (no screen, length, resend timer or copy). Built from the same Yope parts as
`auth.phone`; the code field and its autofill are system behaviour (PLATFORM); the rest that is not documented is BLOCKED.

## References

As `auth.phone` (S24, S26, C24, BI, NG, HUD, T), plus:

| id | file / URL | used for |
|---|---|---|
| S26 link | `references/auto/yope/frames/a-virgi-7686278541255642390-t31.23-signup-es.png` x262-479 y76-94 | lime text link style ("probar otras opciones") for "send new code" |
| AF | https://developer.apple.com/documentation/security/enabling-password-autofill-on-a-text-input-view ; https://developers.google.com/identity/sms-retriever/user-consent/request | one-time-code AutoFill, SMS User Consent |

## Structure (black `color.global.backgroundDeep`, centred)

1. Status bar.
2. Header row: back circle at the leading edge — `size.global.headerButton`, fill `color.global.controlOnDeep`,
   glyph `icon.global.back` in `color.global.textPrimary`, inset `size.global.headerInset`.
3. Title `auth.code.title`, cap top `groups.create.size.sheetTopToTitle` below the safe-area top.
4. Subtitle `auth.code.subtitle` (italic subtitle style), directly under the title.
5. Gap `groups.create.size.titleToContent`.
6. Code field (one field).
7. Gap `groups.create.size.fieldToButton`.
8. Primary button `auth.code.continue`.
9. Lime text link `auth.code.resend`, centred, `groups.create.size.fieldToButton` under the button.
10. System number keyboard; on Android the SMS User Consent sheet may appear over it.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| back circle | `size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.back`, `size.global.headerInset` | `auth.code.back.accessibilityLabel` | returns to `auth.phone`, number kept |
| title / subtitle | as `auth.phone` (onboarding title; `auth.phone.fontSize.subtitle`, `auth.phone.layout.subtitle`) | `auth.code.title`, `auth.code.subtitle` ({phone}) | static |
| code field | `auth.code.layout.codeField`; drawn with `groups.create.color.field`, `size.global.fieldHeight`, `radius.global.field`, `groups.create.fontSize.fieldText` / `.fontWeight.fieldText`, placeholder `color.global.textSecondary` | `auth.code.field.placeholder`, `auth.code.field.accessibilityLabel` | digits only, centred; AutoFill / consent fills it; no auto-submit (not observed) |
| continue | as `auth.phone` continue (lime, `size.global.buttonHeight`, `radius.global.button`; disabled tokens) | `auth.code.continue` | enabled when the field has at least one digit; tap → `verifyOTP`; HUD while verifying |
| send new code | `auth.code.fontSize.textLink`, `auth.code.fontWeight.textLink`, `color.global.accent`; disabled = `color.global.textSecondary`; lock `auth.code.duration.resendLock` | `auth.code.resend` | disabled for 60 s after each request (no countdown shown), then sends `signInWithOTP` again; toast `auth.code.toast.resent` |
| HUD / toast | as `auth.phone` | `groups.create.hud.loading`, `auth.code.toast.resent` | — |

## States

| state | when | design | copy |
|---|---|---|---|
| default | after the code was sent | as Structure | — |
| verifying | `verifyOTP` in flight | HUD | `groups.create.hud.loading` |
| wrong code | Supabase "invalid token" | presentation **BLOCKED** (`auth.phone.layout.inlineError`); field cleared | `auth.code.error.wrong` |
| expired | token older than 1 h | **BLOCKED** presentation | `auth.code.error.expired` |
| too many tries | HTTP 429 | **BLOCKED** presentation | `auth.code.error.tooMany` |
| offline | no connection | Yope empty-state layout (as `auth.phone` offline) | `auth.phone.offline.title`, `auth.code.offline.detail`, `auth.phone.offline.retry` |
| success (new account) | session created, `profile_private.age_confirmed_at` null | push `auth.agegate` | — |
| success (returning) | session, age already confirmed, display name set | replace the stack with `groups.list` (pending invite → `join_group` first) | — |

## Motion

Native push in/out; keyboard and consent sheet are system. Toast as `auth.phone`.

## Haptics

Verified → `haptic.global.success`; wrong / expired / failed → `haptic.global.error`. No key haptics (system keyboard).

## Accessibility

- Field label `auth.code.field.accessibilityLabel`; back circle `auth.code.back.accessibilityLabel`; the link is a button
  with its own label; while disabled it is announced as dimmed / disabled.
- Dynamic Type: title `largeTitle`; subtitle `subheadline`; field `subheadline`; link 14.5 → `subheadline`.
- Focus order: back → title → subtitle → field → continue → send new code.
- Contrast: as `auth.phone`; lime link on black 17.65:1 pass (bold → large-text threshold); disabled link #969696 on black 7.10:1.

## Data & actions

- `supabase.auth.verifyOTP(phone:, token:, type: .sms)` (docs/API.md §2); resend = `signInWithOTP` (Twilio Verify returns
  the same code inside its lifetime).
- After success: read `profile_private` (own row, docs/API.md §5.2) and `profiles.display_name` to decide the next step.
- In: `auth.phone`; `invite.appclip` join sheet. Out: `auth.agegate`, or `groups.list` for returning accounts.

## Platform notes

- iOS: one `TextField` with `.textContentType(.oneTimeCode)`, `.keyboardType(.numberPad)`; per-digit boxes would block
  AutoFill (Apple doc), so none are drawn.
- Android: `SmsRetriever.getClient(context).startSmsUserConsent(null)` when the screen appears; the system consent sheet
  (system UI) hands back the message; extract the 4–10 digit code into the field. `ContentType.SmsOtpCode` autofill as well.

## Do-not-copy

Nothing observed on this surface.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| Yope code screen layout, code length display, resend timer | not found → composed from documented parts | one ~40 s English screen recording of a fresh Yope install up to the first camera screen, tapping "try other options" |
| error presentation | BLOCKED (`auth.phone.layout.inlineError`) | same recording, entering one wrong code |
| toast dwell | BLOCKED (`safety.block.duration.toast`) | one 10-s recording until the "posted in the wall" toast disappears |

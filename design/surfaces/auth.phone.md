# `auth.phone` — phone number entry (sign up or log in)

Reference: **Yope onboarding** (`docs/SURFACES.md`). Research: `design/research/yope-a.md` §1, §2.1; platform:
`docs/PLATFORM_CONSTRAINTS.md` §7. Tokens: `design/tokens/account.json` (`auth.phone.*`, the form tokens `groups.create.*`)
and `design/tokens/global.json`. Copy: `design/copy/account.json` (`auth.phone.*`).

**Yope's phone screen was not found.** Every 2024–2026 source opens on social sign-in (Apple / Google / Facebook);
the phone path sits behind "try other options" and was never filmed (yope-a §2.1, §6). This screen is assembled only
from documented Yope parts: the sign-in screen (title, subtitle, legal footer, black background), the onboarding form
stack (field + lime "continue", 2024–2025 builds) and Yope's voice. Everything else is BLOCKED (see Gaps).

## References

| id | file | used for |
|---|---|---|
| S24 | `references/auto/yope/frames/a-yrrah-7454430216123862280-t6.73-signup-2024.png` | title "sign up or log in", italic subtitle, legal footer text (read in this pass), centred layout |
| S26 | `references/auto/yope/frames/a-virgi-7686278541255642390-t31.23-signup-es.png` | 2026 sign-in layout: black, 40 pt heavy title, footer gray with bold links, lime text link |
| C24 | `references/auto/yope/frames/a-yrrah-7452976839846382855-t3.73-create-new-group-empty-2024.png` | onboarding form stack: title → content → field → "continue"; disabled button; gaps |
| BI | `references/auto/yope/web/a-bi-2025-create-group-composite.jpg`, `a-bi-2025-onboarding-composite.jpg` | the same stack sitting directly above the system keyboard; lime "continue" |
| NG | `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t49.23-new-group-selected-create.png` | 2026 form field (fill, height, radius, centred bold text, margins) |
| HUD | `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t50.60-loading-hud.png` | Loading HUD |
| T | `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png` | lime toast ("posted in the wall") |

## Structure (top to bottom, black `color.global.backgroundDeep`, everything centred on the vertical axis)

1. Status bar (system, light content).
2. No header circles (first screen; Yope's sign-in screen has none). When reached from an invite (`invite.web` /
   `invite.appclip` → install → launch), the same screen is shown; the pending invite token is kept for after onboarding.
3. Title `auth.phone.title`, cap top `groups.create.size.sheetTopToTitle` below the safe-area top; one line, centred.
4. Subtitle `auth.phone.subtitle`, directly under the title with the platform's default leading (the gap was not
   measured separately; S24 shows title and subtitle as one block), centred.
5. Gap `groups.create.size.titleToContent`.
6. Phone field: full width minus `size.global.buttonMarginH` on each side, centred text.
7. Gap `groups.create.size.fieldToButton`.
8. Primary button `auth.phone.continue`, full width minus `size.global.buttonMarginH`.
9. Legal footer `auth.phone.legal.text`, centred, `size.global.screenMargin` side margins, pinned above the home
   indicator; when the keyboard is up it sits under the button (it moves with the stack). Footer placement under a keyboard
   was not observed (approximation, see Gaps).
10. System phone keyboard (`auth.phone.layout.keyboard`), shown on appear; the stack (3–9) stays top-aligned as in BI.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| title | `fontSize.global.onboardingTitle`, `fontWeight.global.onboardingTitle`, `color.global.textPrimary`, `font.global.family` | `auth.phone.title` | static; one colour (S24 draws it all white) |
| subtitle | `auth.phone.fontSize.subtitle`, `auth.phone.layout.subtitle` (italic, regular, `color.global.textPrimary`) | `auth.phone.subtitle` | static |
| phone field | fill `groups.create.color.field`; height `size.global.fieldHeight`; corners `radius.global.field`; text `groups.create.fontSize.fieldText` + `groups.create.fontWeight.fieldText` in `color.global.textPrimary`; placeholder same size in `color.global.textSecondary`; keyboard/AutoFill `auth.phone.layout.keyboard`; country code `auth.phone.layout.countryCode` (BLOCKED) | `auth.phone.field.placeholder`, `auth.phone.field.accessibilityLabel` | pre-filled with "+" and the device region's calling code; the person edits it as text; normalised to E.164 before sending |
| continue | `color.global.accent` / `color.global.onAccent`; height `size.global.buttonHeight`; corners `radius.global.button`; label `fontSize.global.button` + `fontWeight.global.button`; disabled `groups.create.color.buttonDisabledFill` / `.buttonDisabledLabel` | `auth.phone.continue` | disabled until the field holds digits after the calling code; tap → `signInWithOTP`; HUD while the request runs |
| legal footer | `auth.phone.layout.legalFooter` (`fontSize.global.caption`, `lineHeight.global.caption`, `color.global.textSecondary`, links bold) | `auth.phone.legal.text` with link ranges `auth.phone.legal.terms`, `auth.phone.legal.privacy` | links open `config/app.json` `legal.termsUrl` / `legal.privacyUrl` in the in-app browser (SFSafariViewController / Custom Tabs) |
| Loading HUD | `groups.create.color.hud`, `groups.create.size.hud`, label `groups.create.fontSize.hudLabel` in `color.global.textPrimary`, spinner `easing.global.native` (activityIndicator) | `groups.create.hud.loading` | centred over the screen while sending; blocks input |
| toast | `safety.block.layout.toast`, `safety.block.duration.toast` (BLOCKED) | `auth.phone.toast.codeSent`; after an account deletion `settings.account.deleted.toast` | top of the screen; release builds omit it until the dwell time is captured |

## States

| state | when | design | copy | source |
|---|---|---|---|---|
| default | launch without a session | as Structure | as above | S24, S26, C24 |
| sending | `signInWithOTP` in flight | Loading HUD | `groups.create.hud.loading` | HUD (SOURCED) |
| invalid number | number fails E.164 parsing, or Supabase rejects it | presentation **BLOCKED** (`auth.phone.layout.inlineError`) | `auth.phone.error.invalidNumber` | copy SOURCED (pattern) |
| rate limited | second request within 60 s / provider limit | presentation **BLOCKED** | `auth.phone.error.rateLimited` | PLATFORM_CONSTRAINTS §7 |
| send failed | 5xx / provider error | presentation **BLOCKED** | `auth.phone.error.sendFailed` | — |
| offline | no connection (NWPathMonitor / ConnectivityManager) | Yope empty-state layout replacing 3–8: title `fontSize.global.emptyTitle` bold, detail `fontSize.global.emptyDetail` italic `color.global.textSecondary`, white pill (`color.global.surfaceLight`, `groups.screen.radius.lightPill`, height `groups.screen.size.lightPillHeight`) | `auth.phone.offline.title`, `auth.phone.offline.detail`, `auth.phone.offline.retry` | layout V-mthu t51.23 (SOURCED) |
| empty / permission-denied | — | not applicable (no list, no permission) | — | — |

## Motion

- Push to `auth.code`: native navigation push (`easing.global.native` navigationPush; Yope's measured push
  `duration.global.navigationPush` cannot be applied to a native push, F-11). Reduce Motion: platform behaviour.
- Keyboard: system (`easing.global.native` keyboard). HUD spinner: system.
- Toast enter: `spring.global.platformDefault.ios` / `.android`; Reduce Motion → cross-fade (`layout.global.reduceMotion`).

## Haptics

| interaction | token |
|---|---|
| typing | none (system keyboard; platform proposal `haptic.auth.keypad` = none with the system keyboard) |
| code sent | `haptic.global.success` |
| request failed | `haptic.global.error` |

## Accessibility

- Labels: field `auth.phone.field.accessibilityLabel` (the placeholder disappears once typing starts); links are separate
  link elements (`.link` trait / `Role.Button` + `LinkAnnotation`).
- Dynamic Type (`layout.global.textStyleMap`): title `largeTitle`; subtitle 14 pt → `subheadline` (F-13 tie rule:
  13 vs 15 → larger); field text 15 pt → `subheadline`; button `subheadline`; footer `caption`. The title may wrap
  to two lines at large sizes; the stack scrolls when it no longer fits above the keyboard.
- Focus order: title → subtitle → field → continue → footer (Terms of Use, Privacy Policy links).
- Contrast (`node tools/contrast.mjs`): white on field #141414 18.42:1 pass; placeholder #969696 on #141414 6.23:1 pass;
  black on lime 17.65:1 pass; footer #969696 on black 7.10:1 pass; field fill vs black 1.14:1 **FAIL** (non-text,
  the placeholder identifies the field); disabled button 1.79:1 / 1.26:1 (inactive control, exempt from SC 1.4.3/1.4.11).

## Data & actions

- `supabase.auth.signInWithOTP(phone:)` (docs/API.md §2; Twilio Verify). Errors are Supabase Auth errors, not the
  PostgREST codes of §3: map "invalid phone" → invalid number, HTTP 429 → rate limited, other → send failed.
- No table reads. The minimum-age config is not read here.
- In: cold launch without a session; after `settings.account` deletion / sign-out; after installing from an invite
  (`DeepLink.invite(token:)` stored until onboarding ends, then `join_group`, docs/API.md §9.3).
- Out: `auth.code` (with the normalised number).

## Platform notes

- iOS: `keyboardType(.phonePad)`, `textContentType(.telephoneNumber)` (system AutoFill offers the person's own number).
- Android: `KeyboardType.Phone`, `ContentType.PhoneNumber` autofill. No SMS Retriever hash (Twilio composes the SMS).
- App Clip: `invite.appclip` uses its own join sheet and then `auth.code` (see `design/surfaces/invite.appclip.md`).

## Do-not-copy

- Yope's ATT tracking alert during sign-up (ads; V-virgi), the "YOPE" logotype above the title, social sign-in buttons
  (phone OTP only: docs/API.md §2), "continue as <username>".

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| country-code selector (`auth.phone.layout.countryCode`) | BLOCKED | one ~40 s English screen recording of a fresh Yope install up to the first camera screen, tapping "try other options" |
| inline error presentation (`auth.phone.layout.inlineError`) | BLOCKED | same recording, entering one wrong code |
| toast dwell time (`safety.block.duration.toast`) | BLOCKED | one 10-s recording of a Yope post until the "posted in the wall" toast disappears |
| title–subtitle gap, footer position with the keyboard up | approximation (platform leading; footer moves with the stack) | the ~40 s recording above |
| footer weight | open item of F-24 (global caption role used) | lossless screenshot of the sign-up screen |
| whole-screen arrangement | approximation: Yope sign-in parts + Yope onboarding form stack | the ~40 s recording above |
| SMS/carrier disclosure under the field | not researched (counsel) | — |

# `onboarding.permission.notifications` — in-context notifications ask

Reference: **Yope** (`docs/SURFACES.md`), with the HIG pre-alert rule. Research: `design/research/yope-a.md` §2.5;
`design/research/platform.md` §system.permissions; `docs/PLATFORM_CONSTRAINTS.md` (4.5.4: notifications must not be
required). Tokens: `onboarding.permission.notifications.*`. Copy: `onboarding.permission.notifications.*`.

Yope's 2026 build shows a pre-prompt (title near the top, then a **fake iOS alert card with a lime "Allow" and an arrow**
— do-not-copy) and only in Spanish. This screen keeps Yope's structure (title near the top, lime full-width button at the
bottom) under Apple's pre-alert rule: **one button, no way to leave without the system alert** on iOS.

## References

| id | file | used for |
|---|---|---|
| NP | `references/auto/yope/frames/a-virgi-7686278541255642390-t7.23-notif-preprompt-es.png` | title centred near the top (frame is mid-transition; no values measured) |
| NA | `references/auto/yope/frames/a-virgi-7686278541255642390-t9.23-notif-system-alert-es.png` | the system alert that follows |
| WP | `references/auto/yope/frames/a-virgi-7686278541255642390-t11.23-widget-preprompt-es.png` | Yope pre-prompt anatomy: lime full-width button at the bottom, skip top-right |
| CC | `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png` | Yope's permission voice ("can’t see your friends?" / "enable contacts") |
| S26 | `references/auto/yope/frames/a-virgi-7686278541255642390-t31.23-signup-es.png` | dark secondary button (#171717 class) |
| HIG | https://developer.apple.com/design/human-interface-guidelines/privacy#Pre-alert-screens-windows-or-views | one button; "Continue"/"Next"; no close/cancel |

## Structure (black `color.global.backgroundDeep`) — `onboarding.permission.notifications.layout.preAlert`

1. Status bar.
2. Title `onboarding.permission.notifications.title`, centred, cap top `groups.create.size.sheetTopToTitle` below the safe area.
3. Detail `onboarding.permission.notifications.detail` under it (italic subtitle style).
4. Flexible space (Yope's illustration area; its art is do-not-copy and none is sourced — empty).
5. Android API 33+ only: dark secondary button `onboarding.permission.notifications.skip`, full width minus
   `size.global.buttonMarginHSheet`, `size.global.buttonHeightSheet` tall, 8 pt above the primary button
   (Yope's dark sign-in buttons sit ≈8 pt apart, yope-a proposal `dimension.signup.providerButton.gap`).
6. Primary button `onboarding.permission.notifications.continue`, full width minus `size.global.buttonMarginHSheet`,
   `size.global.buttonHeightSheet` tall, bottom of the safe area.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| title | `fontSize.global.onboardingTitle`, `fontWeight.global.onboardingTitle`, `color.global.textPrimary` | `onboarding.permission.notifications.title` | static |
| detail | `auth.phone.fontSize.subtitle`, `auth.phone.layout.subtitle` | `onboarding.permission.notifications.detail` | static |
| continue | `color.global.accent` / `color.global.onAccent`, `size.global.buttonHeightSheet`, `size.global.buttonMarginHSheet`, `radius.global.button`, text role `button` | `onboarding.permission.notifications.continue` | `UNUserNotificationCenter.requestAuthorization([.alert, .sound, .badge])` / `POST_NOTIFICATIONS`; whatever the answer, go on to `onboarding.widget` |
| maybe later (Android) | `onboarding.permission.notifications.color.secondaryButton`, `size.global.buttonHeightSheet`, `radius.global.button`, label `color.global.textPrimary` text role `button` | `onboarding.permission.notifications.skip` | goes on without asking; asked again only from `settings.notifications` |

## States

| state | when | design |
|---|---|---|
| default | after `auth.profile`, authorization not determined | as Structure |
| skipped | iOS: already determined → screen not shown; Android ≤ 32 → not shown | — |
| granted | → `register_device(...)` with the APNs/FCM token (docs/API.md §6.3) | — |
| denied (permission-denied) | the app works normally; `settings.notifications` shows `settings.notifications.off.footer` + `settings.notifications.openSettings` | — |
| loading / empty / error / offline | not applicable; `register_device` failures retry silently on the next token refresh | — |

## Motion · Haptics

Native push in/out; the system alert is the platform's. No haptic (the system alert plays none of ours).

## Accessibility

- Focus order: title → detail → (maybe later) → continue.
- Dynamic Type: title `largeTitle`; detail `subheadline`; buttons `subheadline`.
- Contrast: black on lime 17.65:1 pass; white on #171717 17.93:1 pass; #171717 vs black 1.17:1 **FAIL** (non-text, the
  label identifies the button).

## Data & actions

`register_device(p_platform, p_push_token, p_push_to_start_token?, p_widget_push_token?)` after a grant and on every
token change. In: `auth.profile`. Out: `onboarding.widget`.

## Platform notes

- iOS: no skip, no close, no back (HIG pre-alert rule). Provisional authorization is not used (not researched for this flow).
- Android: Android requires a way out of educational UI → "maybe later". On API ≤ 32 there is no runtime permission.

## Do-not-copy

- Yope's card that imitates the iOS alert with a lime "Allow" and an arrow (V-virgi t7.23).
- "Allow" on our own button (HIG: never "Allow").

## Gaps

| item | status | smallest capture |
|---|---|---|
| English pre-prompt copy and its sizes | not found (es only, frame mid-transition) → title written to `yope.voice.permission`; sizes from the onboarding title role | one 15-s English recording of Yope's notifications pre-prompt |
| illustration | none sourced (Yope's art is do-not-copy) | owner art, optional |

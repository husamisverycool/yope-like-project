# `onboarding.permission.notifications` — in-context notifications permission

Visual reference: Retro's onboarding page NOTIFICATION_PERMISSION_RETRY ("Never miss a message", APK-S
`onboarding_notification_permission_retry_*`, step order RP §6.3) — an onboarding page (C-33 variant) followed by the
system prompt (PLATFORM). Not captured as an image: `level: SOURCED`, `method: "composition of Retro components C-33
(onboarding page title), C-05, C-08 in Retro's onboarding order"`. Tokens:
`onboarding.permission.notifications.layout.preAlert`. Copy: `onboarding.permission.notifications.*`.

## References

| id | file / URL | used for |
|---|---|---|
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `onboarding_notification_permission_retry_title` / `_subtitle`, `activity_enable_push_upsell_cta` ("Enable notifications"), `media_viewer_suggested_tag_maybe_later` |
| LAND | `references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png` | capsule and secondary link geometry (`auth.phone.size.capsuleToLink`) |
| HIG | https://developer.apple.com/design/human-interface-guidelines/privacy#Pre-alert-screens-windows-or-views | one button that leads to the system alert; no way to leave on iOS |
| M3 | https://developer.android.com/training/permissions/requesting | Android needs a way out of educational UI |

## Structure (page `color.global.background` / `.background.android`)

1. Status bar; no header row (iOS pre-alert rule: no back, no close).
2. Title `onboarding.permission.notifications.title` (`font.global.display`, `displayMedium`, `color.global.textPrimary`),
   leading at `size.global.screenMargin`, baseline `size.global.titleTop` below the safe area.
3. Explanation `onboarding.permission.notifications.detail` directly under it (`body`, `color.global.textSecondary`).
4. Flexible space (no illustration: Retro's onboarding art is do-not-copy, none is sourced).
5. Primary capsule C-05 `onboarding.permission.notifications.continue`, side margins `size.global.buttonMarginH`,
   its bottom `size.global.buttonMarginH` above the bottom safe area (the same frame as the form capsules of `auth.*`).
6. Android API 33+ only: C-08 secondary link `onboarding.permission.notifications.skip`, `auth.phone.size.capsuleToLink`
   under the capsule (the capsule moves up by the link's height + gap).

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| title / explanation | `displayMedium`; `body` + `textSecondary` | `onboarding.permission.notifications.title`, `.detail` | static |
| Enable notifications | C-05 | `onboarding.permission.notifications.continue` | iOS `UNUserNotificationCenter.requestAuthorization([.alert, .sound, .badge])`; Android 13+ `POST_NOTIFICATIONS`; whatever the answer, continue to `onboarding.widget` |
| Maybe later (Android) | C-08 | `onboarding.permission.notifications.skip` | continue without asking |
| Android rationale (only when `shouldShowRequestPermissionRationale` is true, e.g. a later re-ask) | native dialog (C-29, `settings.account.layout.alert`) | `system.permissions.rationale.notifications.title`, `.message`, `system.permissions.rationale.notNow`, `system.permissions.rationale.continue` | — |

## States

| state | design | copy |
|---|---|---|
| default | as Structure | as above |
| system prompt open | system alert over the page (PLATFORM) | iOS: system text; Android: system text |
| granted / denied | the page closes either way (no retry loop); denied is recovered from `settings.notifications` ("Keep up to date!" row) | — |
| API ≤ 32 (Android) | page skipped (no runtime permission) | — |
| loading / empty / error / offline | not applicable (no network) | — |

## Motion

Enter from `auth.profile` with the onboarding page transition (`duration.global.pageTransition` fade + expand); exit
the same way to `onboarding.widget`. System alert: system. Reduce Motion: cross-fade.

## Haptics

Presses → `haptic.global.tap` (Android). System alerts: none of ours.

## Accessibility

- Title is a header; the capsule's label is its text. Dynamic Type: title `largeTitle`, explanation `subheadline`,
  capsule `headline`, link `subheadline`.
- Focus order: title → explanation → capsule → (Android) link.
- Contrast: title 21:1 (row 1); explanation / link `textSecondary` light **2.85:1 FAIL** (row 3), dark 7.37:1; capsule 21:1 (row 17).

## Data & actions

`register_device(p_platform, p_push_token, p_push_to_start_token?, p_widget_push_token?)` after a grant and on every token
change (docs/API.md §6.3). In: `auth.profile`; also, once per phone, an account that skips sign-up on a phone that has
not shown its onboarding pages — a returning account's code (`auth.code` "success, returning") or the app's first
launch after an App Clip join — at the same point (after sign-in, before home), as the first page when it opens the
flow (no back). Out: `onboarding.widget`. The app also registers with APNs at every launch once allowed
(`PushService.registerIfAuthorized`).

## Platform notes

- iOS: no skip (HIG pre-alert); provisional authorization is not used.
- Android: the skip exists because Android requires a way out of educational UI; on API ≤ 32 the page is skipped.

## Do-not-copy

- Retro's "Finish setting up your Retro!" nudge notifications and any re-ask loop (tenet 5).

## Gaps

| item | status | smallest capture |
|---|---|---|
| Retro's notifications page (title placement, any list of what you get) | composition | screenshots of Retro's onboarding pages on a fresh install (RV §6) |

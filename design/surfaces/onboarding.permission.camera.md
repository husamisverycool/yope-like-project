# `onboarding.permission.camera` — in-context camera permission

Visual reference: Retro has no camera; its permission upsells ("Camera Roll Access" / "…These photos are only visible
to you." / "Allow Photo Access", APK-S `rewind_home_no_permission_upsell_*`) are drawn as the empty-state block (C-27
permission-denied variant). Mechanics: Apple HIG / Material 3 system prompt (PLATFORM). Composition:
`level: SOURCED`, `method: "composition of Retro components C-27 (permission-denied variant) and C-07 / C-06 on the
camera's media surface, in the platform's request order"`. Tokens: `onboarding.permission.camera.layout.request`.
Copy: `onboarding.permission.camera.*`, `system.permissions.camera.purpose`, `system.permissions.rationale.camera.*`.

## References

| id | file / URL | used for |
|---|---|---|
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | permission copy pattern (`rewind_home_no_permission_upsell_*`, `composer_permission_upsell_*`) |
| H43 | `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png` | empty-state block on black: glyph 22 → 26 → title 20 semibold → 25 → outline capsule 37 (C-27) |
| PLAT | design/research/platform.md §system.permissions | request timing, Android rationale, permanent denial |

## Structure

1. **Request** (`onboarding.permission.camera.layout.request`): the first time `camera.capture` opens — iOS
   `AVCaptureDevice.requestAccess(for: .video)` (alert text `system.permissions.camera.purpose`,
   `NSCameraUsageDescription`); Android `CAMERA`. No pre-alert page.
2. **Android rationale** (only when `shouldShowRequestPermissionRationale(CAMERA)`): native dialog (C-29,
   `settings.account.layout.alert`): `system.permissions.rationale.camera.title`, `.message`,
   `system.permissions.rationale.notNow` (leading), `system.permissions.rationale.continue` (trailing).
3. **Denied** (permission-denied state of `camera.capture`): the C-27 block centred in the camera area, on the camera's
   black media surface (`color.global.backgroundDeep`, both appearances):
   glyph `icon.global.camera` (`size.global.emptyIcon`, `color.global.textOnMedia`) → `size.global.emptyIconToTitle` →
   title `onboarding.permission.camera.denied.title` (`emptyTitle`, `color.global.textOnMedia`) → explanation
   `onboarding.permission.camera.denied.detail` (`emptyDetail`, `color.global.textSecondary`, ≤ 2 lines) →
   `size.global.emptyTitleToAction` → outline capsule C-06 (1 pt `color.global.textOnMedia` border and label)
   `onboarding.permission.camera.denied.button`.

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| system alert | PLATFORM | `system.permissions.camera.purpose` | — |
| rationale dialog (Android) | C-29 | `system.permissions.rationale.camera.*`, `.notNow`, `.continue` | Give Permission → runtime request |
| denied block | C-27 on media (above) | `onboarding.permission.camera.denied.title`, `.detail`, `.button` | button: iOS opens the app's Settings page; Android re-requests until permanent denial, then opens Settings (`Settings.ACTION_APPLICATION_DETAILS_SETTINGS`) |

## States

| state | design | copy |
|---|---|---|
| not determined | system alert over the camera | purpose string |
| granted | camera runs (`camera.capture`) | — |
| denied (permission-denied) | denied block | `onboarding.permission.camera.denied.*` |
| restricted (MDM / Screen Time) | denied block; the button still opens Settings | same |
| loading / empty / error / offline | covered by `camera.capture` | — |

## Motion

System alert and dialog: system. The denied block fades in `duration.global.fade` (150 ms, `easing.global.standard`).
Reduce Motion: unchanged (fade only).

## Haptics

Button press → `haptic.global.tap` (Android). No camera haptic (`haptic.global.shutter` none).

## Accessibility

- Glyph decorative; title has the header trait; button labelled by its text.
- Dynamic Type: title `title3`, explanation `subheadline`, button `subheadline`.
- Contrast (media surface, both appearances): `textOnMedia` on #000000 21:1 (row 37); `textSecondary` on #000000 7.37:1
  (row 38); outline border white on black 21:1 (row 20 dark value).

## Data & actions

No API. Settings URL: `UIApplication.openSettingsURLString` / `Settings.ACTION_APPLICATION_DETAILS_SETTINGS` (`package:` URI).
Navigation stays on `camera.capture`. Microphone is asked separately at the first voice note or video
(`system.permissions.microphone.purpose`, App Review 5.1.1(iv)).

## Platform notes

- iOS asks once; after a denial only Settings can change it. Android: after two denials the request no longer shows
  (permanent denial) → the button opens Settings.

## Do-not-copy

- A fake system-alert card that imitates the OS prompt; asking again in a loop.

## Gaps

| item | status | smallest capture |
|---|---|---|
| Retro's own permission pre-prompts as images | strings only (RV §2 rows 36–41) | screenshots of Retro's permission screens (RV §6) |

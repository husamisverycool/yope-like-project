# `onboarding.permission.camera` — camera access

Reference: **Yope**, then the system prompt (Apple HIG / Material 3). Research: `design/research/yope-a.md` §2.6;
`design/research/platform.md` §system.permissions. Tokens: `onboarding.permission.camera.layout.request`, the inline
card tokens `onboarding.permission.contacts.*`. Copy: `onboarding.permission.camera.*`, `system.permissions.camera.purpose`,
`system.permissions.rationale.camera.*`.

**Yope shows no pre-prompt for the camera:** the system alert appears directly over the camera the first time it opens
(two builds, 2024 and 2026). So this surface has **no screen of its own**; it is the request moment plus the
permission-denied card inside `camera.capture`.

## References

| id | file | used for |
|---|---|---|
| CA26 | `references/auto/yope/frames/a-virgi-7686278541255642390-t35.23-camera-permission-alert.png` | system alert over the camera, no pre-prompt (2026-09) |
| CA24 | `references/auto/yope/frames/a-yrrah-7454430216123862280-t13.23-camera-permission-alert-2024.png` | same sequence (2024-12) |
| CC | `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png` | Yope's inline permission card ("can’t see your friends?" / "enable contacts" / "enable") reused for the denied state |

## Structure

1. **Request** (`onboarding.permission.camera.layout.request`): the first time `camera.capture` appears, call
   `AVCaptureDevice.requestAccess(for: .video)` (iOS) / request `CAMERA` (Android). The system alert shows
   `system.permissions.camera.purpose` (iOS Info.plist `NSCameraUsageDescription`).
2. **Android rationale** (only when `shouldShowRequestPermissionRationale(CAMERA)` is true): M3 basic dialog
   (`settings.account.layout.alert`) — title `system.permissions.rationale.camera.title`, text
   `system.permissions.rationale.camera.message`, actions `system.permissions.rationale.notNow` (dismissive, leading) and
   `system.permissions.rationale.continue` (confirming, trailing).
3. **Denied** — inline permission card centred in the viewfinder area of `camera.capture` (the camera pass places it):
   card fill `onboarding.permission.contacts.color.card`, height `onboarding.permission.contacts.size.cardHeight`, side
   margin `onboarding.permission.contacts.size.cardMarginH`, corners `radius.global.card`; structure
   `onboarding.permission.contacts.layout.card` without the dismiss ✕ (the camera cannot work without it).

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| system alert | system (PLATFORM) | `system.permissions.camera.purpose` | — |
| card title | `onboarding.permission.contacts.fontSize.cardTitle` / `.fontWeight.cardTitle`, `color.global.textPrimary` | `onboarding.permission.camera.denied.title` | — |
| card detail | `onboarding.permission.contacts.fontSize.cardDetail`, `color.global.textSecondary` | `onboarding.permission.camera.denied.detail` | — |
| enable pill | `onboarding.permission.contacts.size.cardButtonWidth` / `.cardButtonHeight`, `color.global.surfaceLight`, label `color.global.onSurfaceLight` text role `button`, shape `radius.global.capsule` | `onboarding.permission.camera.denied.button` | opens the app's page in system Settings; on return, re-check authorization and show the camera |

## States

| state | design | copy |
|---|---|---|
| not determined | system alert over the camera | purpose string |
| authorized | `camera.capture` as specified there | — |
| denied / restricted (permission-denied) | inline card | `onboarding.permission.camera.denied.*` |
| loading / empty / error / offline | not applicable (no network, no list) | — |

## Motion · Haptics

System alert and dialog motion are the platform's. No haptic (HIG: no haptics during camera use; `haptic.global.shutter` = none).

## Accessibility

- The card is one container: title and detail read together, then the button. Button label = its text.
- Dynamic Type: title 17 bold → `headline`; detail 14 → `subheadline`; button `subheadline`.
- Contrast: white on #131313 18.58:1 pass; #969696 on #131313 6.28:1 pass; white pill on #131313 18.58:1 pass; card
  fill vs black 1.13:1 **FAIL** (non-text; the text identifies the card).

## Data & actions

No API. Navigation stays on `camera.capture`. Settings URL: `UIApplication.openSettingsURLString` /
`Settings.ACTION_APPLICATION_DETAILS_SETTINGS` with `package:` URI.

## Platform notes

- iOS asks once; after a denial only Settings can change it. Android: after two denials the dialog no longer appears
  ("permanent denial") → the card's button opens Settings.
- Microphone is not requested here (App Review 5.1.1(iv)): it is asked at the first voice note or video
  (`system.permissions.microphone.purpose`).

## Do-not-copy

- None observed (Yope uses the plain system alert).

## Gaps

| item | status | smallest capture |
|---|---|---|
| Yope's own camera-denied state | not found (yope-a §6) → Yope's inline permission card reused (approximation) | one screenshot of Yope's camera tab with camera access turned off in Settings |

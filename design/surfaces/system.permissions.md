# `system.permissions` — system permission prompts and purpose strings

Visual reference: none (the operating system draws the prompts) — Apple HIG / Material 3 (PLATFORM). Copy: the system
prompt's purpose strings follow `platform.purposeString`; the app-drawn Android rationale dialogs and denied states use
Retro's permission voice (`retro.voice.permission`: APK-S `composer_permission_upsell_*`, `contact_permission_upsell_*`,
`onboarding_notification_permission_retry_*`). Tokens: `settings.account.layout.alert` (dialog). Copy: `system.permissions.*`.

## References

| id | file / URL | used for |
|---|---|---|
| HIG | https://developer.apple.com/design/human-interface-guidelines/privacy#Requesting-permission | purpose strings: one complete sentence naming the use |
| M3 | https://developer.android.com/training/permissions/requesting | rationale dialog only when `shouldShowRequestPermissionRationale` is true |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | Retro's permission titles / messages / "Give Permission" |
| PLAT | design/research/platform.md §system.permissions; docs/PLATFORM_CONSTRAINTS.md §6 | timing per permission |

## Structure

| permission | when asked | iOS (Info.plist key → copy) | Android rationale (C-29 dialog) | denied state |
|---|---|---|---|---|
| camera | first open of `camera.capture` | `NSCameraUsageDescription` → `system.permissions.camera.purpose` | `system.permissions.rationale.camera.title` / `.message` | `onboarding.permission.camera.md` |
| microphone | first voice note or video | `NSMicrophoneUsageDescription` → `system.permissions.microphone.purpose` | `system.permissions.rationale.microphone.title` / `.message` | C-27 block in the composer (chat.voice / camera passes) with the rationale copy and `system.permissions.openSettings` |
| photo library (save) | first save | `NSPhotoLibraryAddUsageDescription` → `system.permissions.photosAdd.purpose` | — (no permission on API 29+) | `onboarding.permission.photos.md` |
| photo library (read) | only if library reading ships | `NSPhotoLibraryUsageDescription` → `system.permissions.photosRead.purpose` | — | — |
| contacts | `groups.invite` Contacts section | `NSContactsUsageDescription` → `system.permissions.contacts.purpose` | `system.permissions.rationale.contacts.title` / `.message` | `onboarding.permission.contacts.md` |
| notifications | `onboarding.permission.notifications` | system text | `system.permissions.rationale.notifications.title` / `.message` | `settings.notifications` off block |

Rationale dialog buttons: `system.permissions.rationale.notNow` (dismissive, leading) and
`system.permissions.rationale.continue` (confirming, trailing → the runtime request). After a permanent denial, the app's
denied states offer `system.permissions.openSettings` (or the surface's own Retro-voice button).

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| system prompt | PLATFORM | purpose strings (`infoPlistKey`) | system |
| Android rationale | C-29 / `settings.account.layout.alert` (container `color.global.system.surfaceContainerHigh`, actions `color.global.system.primary`) | `system.permissions.rationale.*` | Give Permission → request; Not now → close |
| Open Settings | C-06 / alert button | `system.permissions.openSettings` | `UIApplication.openSettingsURLString` / `Settings.ACTION_APPLICATION_DETAILS_SETTINGS` |

## States

Not determined → system prompt; granted → feature; denied → the owning surface's C-27 permission-denied block;
restricted → same block. Loading / empty / error / offline: not applicable.

## Motion · Haptics

System. Presses on app-drawn buttons → `haptic.global.tap` (Android).

## Accessibility

System prompts carry their own semantics; the rationale dialog is a native `AlertDialog`. Contrast: Retro blue actions on
the M3 dialog container **2.98:1 / 3.94:1 FAIL** (CONTRAST failure 6, reported).

## Data & actions

No API. Info.plist entries are generated from the `infoPlistKey` strings by `tools/designgen.mjs`.

## Platform notes

- Purpose strings never contain `{app_name}` (they must ship before the app is named) — "The app …".
- Android 13+ notifications: `POST_NOTIFICATIONS`; Android 14+ partial photo access is not requested (picker only).

## Do-not-copy

- Pre-prompts that imitate the system alert; asking again in a loop; counts of friends found from contacts.

## Gaps

| item | status | smallest capture |
|---|---|---|
| Retro's iOS purpose strings | not captured (no IPA) | the iOS `.ipa` (decrypted) or screenshots of each Retro permission alert (RP §9) |

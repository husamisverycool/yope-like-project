# `onboarding.permission.photos` — photo library (limited access supported)

Visual reference: Retro's photo-library upsell ("Allow Access to Photos" / "Retro needs permission to access your photo
library so you can select and post photos." / "Give Permission", APK-S `composer_permission_upsell_*`), drawn as the
C-27 permission-denied variant. Mechanics: Apple HIG / Material 3 (pickers need no permission; saving asks add-only).
Composition: `level: SOURCED`, `method: "composition of Retro component C-27 (permission-denied variant) in the
platform's request order"`. Tokens: `onboarding.permission.photos.layout.request`. Copy:
`onboarding.permission.photos.*`, `system.permissions.photosAdd.purpose`, `system.permissions.photosRead.purpose`.

**No page.** Picking photos uses the system pickers (no permission on either platform); saving needs add-only access,
asked by the system at the first save.

## References

| id | file / URL | used for |
|---|---|---|
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `composer_permission_upsell_title` / `_message` / `_cta` |
| PK | https://developer.apple.com/documentation/photokit/delivering-an-enhanced-privacy-experience-in-your-photos-app ; https://developer.android.com/training/data-storage/shared/photo-picker | picker without permission, add-only, limited access |
| H43 | `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png` | C-27 geometry |

## Structure

1. Picking (avatar, group cover, photo upload): iOS `PhotosPicker` / `PHPickerViewController`; Android `PickVisualMedia`.
   No permission, no page.
2. Saving (`photo.viewer` "Save", album downloads): iOS `PHPhotoLibrary.requestAuthorization(for: .addOnly)` at the first
   save → system alert with `system.permissions.photosAdd.purpose`; Android MediaStore insert (no permission on API 29+).
3. Denied save: the C-27 block (glyph `icon.global.download`, title `onboarding.permission.photos.denied.title`,
   explanation `.detail`, outline capsule C-06 `.button`) shown where the save was attempted — `photo.viewer` places it
   on its black media surface (colours as `onboarding.permission.camera` Structure 3).

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| add-only alert | system | `system.permissions.photosAdd.purpose` | — |
| denied block | C-27 (media colours) | `onboarding.permission.photos.denied.title`, `.detail`, `.button` | Give Permission → the app's page in system Settings |

## States

| state | design | copy |
|---|---|---|
| picking | system picker | — |
| add-only not determined | system alert at the first save | purpose string |
| add-only denied (permission-denied) | denied block | `onboarding.permission.photos.denied.*` |
| limited (only if PhotoKit reading ever ships) | `.limited` handled with `PHPhotoLibraryPreventAutomaticLimitedAccessAlert = YES` and `presentLimitedLibraryPicker` from an in-app control | `system.permissions.photosRead.purpose` |
| loading / empty / error / offline | not applicable | — |

## Motion · Haptics

System pickers and alerts. Denied block fades in `duration.global.fade`. Button press → `haptic.global.tap` (Android).

## Accessibility

As `onboarding.permission.camera` (glyph decorative, title header, button labelled). Contrast rows 37, 38, 20 (media).

## Data & actions

No API. `NSPhotoLibraryAddUsageDescription` for saving; `NSPhotoLibraryUsageDescription` only if library reading ships.

## Platform notes

- Google Play restricts `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO`; none are declared.

## Do-not-copy

- Post-to-unlock pre-prompts ("share … to unlock"); Retro's "Post to See" gate (tenet 5).

## Gaps

| item | status | smallest capture |
|---|---|---|
| Retro's photo-permission screen as an image | strings only | screenshot of Retro's "Allow Access to Photos" screen (RV §6) |

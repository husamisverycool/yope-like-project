# `onboarding.permission.photos` — photo library (limited access supported)

Reference: **Yope**, with the platform rules. Research: `design/research/yope-a.md` §2.7; `design/research/platform.md`
§system.permissions; `docs/PLATFORM_CONSTRAINTS.md` §6. Tokens: `onboarding.permission.photos.layout.request`, the inline
card tokens `onboarding.permission.contacts.*`. Copy: `onboarding.permission.photos.*`, `system.permissions.photosAdd.purpose`,
`system.permissions.photosRead.purpose`.

**No screen.** Picking photos uses the system pickers, which need no permission on either platform; saving needs only
add-only access, asked by the system at the first save. Platform research: "use the picker plus add-only access. The
onboarding photos permission screen is then unnecessary." Yope's only evidence (2024) is a system alert behind a
post-to-unlock gate, which is do-not-copy.

## References

| id | file / URL | used for |
|---|---|---|
| PA24 | `references/auto/yope/frames/a-yrrah-7454430216123862280-t21.23-photos-permission-alert-2024.png` | Yope's purpose string ("This lets you share memories from your library."); pre-prompt behind it is do-not-copy |
| PK | https://developer.apple.com/documentation/photokit/delivering-an-enhanced-privacy-experience-in-your-photos-app ; https://developer.android.com/training/data-storage/shared/photo-picker | picker without permission, add-only, limited access |
| CC | `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png` | inline card for the denied-save state |

## Structure

`onboarding.permission.photos.layout.request`:
1. Picking (avatar, group cover, camera roll upload): iOS `PhotosPicker` / `PHPickerViewController`; Android
   `PickVisualMedia`. No permission, no screen. Limited access does not apply (the picker returns only what was chosen).
2. Saving (photo.viewer "save", album export): iOS `PHPhotoLibrary.requestAuthorization(for: .addOnly)` at the first
   save → system alert with `system.permissions.photosAdd.purpose`; Android MediaStore insert (no permission on API 29+).
3. Denied save: the inline permission card (same tokens as `onboarding.permission.camera` Structure 3, with the dismiss ✕
   from `onboarding.permission.contacts.layout.card`) shown where the save was attempted (photo.viewer places it).

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| add-only alert | system | `system.permissions.photosAdd.purpose` | — |
| denied card | `onboarding.permission.contacts.color.card`, `.size.cardHeight`, `.size.cardMarginH`, `radius.global.card`, `.fontSize.cardTitle`, `.fontSize.cardDetail`, `.size.cardButtonWidth`, `.size.cardButtonHeight`, `color.global.surfaceLight` | `onboarding.permission.photos.denied.title`, `.detail`, `.button`; ✕ `onboarding.permission.contacts.card.dismissAccessibilityLabel` | "enable" opens Settings; ✕ hides the card |

## States

| state | design | copy |
|---|---|---|
| picking (any) | system picker | — |
| add-only not determined | system alert at first save | purpose string |
| add-only denied (permission-denied) | inline card | `onboarding.permission.photos.denied.*` |
| limited (only if PhotoKit reading ships) | handle `.limited` with `PHPhotoLibraryPreventAutomaticLimitedAccessAlert = YES` and `presentLimitedLibraryPicker` from an in-app control | `system.permissions.photosRead.purpose` |
| loading / empty / error / offline | not applicable | — |

## Motion · Haptics

System pickers and alerts; no haptic.

## Accessibility

As `onboarding.permission.camera` (card read as one container, then the button, then dismiss). Contrast identical.

## Data & actions

No API. No Info.plist key is needed for picking; `NSPhotoLibraryAddUsageDescription` for saving;
`NSPhotoLibraryUsageDescription` only if library reading ships (e.g. a camera-roll thumbnail in `camera.capture`).

## Platform notes

- Google Play restricts `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` to apps whose core use the picker cannot serve, and
  `READ_MEDIA_VISUAL_USER_SELECTED` is only for custom galleries: **none are declared**.

## Do-not-copy

- "share what you’re up to / to unlock the group for 24h" pre-prompt (post-to-unlock gate, 2024).

## Gaps

| item | status | smallest capture |
|---|---|---|
| Yope 2026 photo-library prompt | not found | one screenshot of the 2026 Yope photo-library prompt (only if library reading is added) |
| camera-roll thumbnail in `camera.capture` (needs read access) | decision for the camera pass; if shipped, this surface's limited-access row applies | — |

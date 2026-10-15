# `system.permissions` — system permission prompts and purpose strings

Reference: **Apple HIG / Material 3** (system surface). Research: `design/research/platform.md` §system.permissions;
`docs/PLATFORM_CONSTRAINTS.md` §6; MERGE_DECISIONS F-20 (purpose strings follow `platform.purposeString`; Yope's benefit
content is used). Tokens: `onboarding.permission.*.layout.*`, `settings.account.layout.alert` (Android rationale dialog).
Copy: `system.permissions.*` (Info.plist strings carry `infoPlistKey`; `tools/designgen.mjs` writes them to
`ios/Config/InfoPlist.generated.xcconfig`).

## References

| id | URL / file | used for |
|---|---|---|
| HIG-P | https://developer.apple.com/design/human-interface-guidelines/privacy | purpose-string form; pre-alert rule |
| AR | https://developer.apple.com/help/app-review/guideline-reference/5-1-1-purpose-strings/ ; App Review 5.1.1(ii)/(iv), 5.1.2(v) | one string per resource, mic timing, contacts rules |
| AND | https://developer.android.com/training/permissions/requesting | in context, rationale only when `shouldShowRequestPermissionRationale()`, always cancellable, permanent denial after two |
| Y-CAM / Y-MIC / Y-PH | `references/auto/yope/frames/a-virgi-…-t35.23-camera-permission-alert.png`, `-t35.93-mic-permission-alert.png`, `a-yrrah-…-t21.23-photos-permission-alert-2024.png` | Yope's benefit content ("So you can take and share pics with friends", "We need your mic to record your voice…", "This lets you share memories from your library.") |

## Inventory

| resource | iOS key / Android permission | when asked | copy | screen before it |
|---|---|---|---|---|
| camera | `NSCameraUsageDescription` / `CAMERA` | first `camera.capture` | `system.permissions.camera.purpose`; Android rationale `system.permissions.rationale.camera.*` | none (`onboarding.permission.camera`) |
| microphone | `NSMicrophoneUsageDescription` / `RECORD_AUDIO` | first voice note or video (never before photo posting, 5.1.1(iv)) | `system.permissions.microphone.purpose`; `system.permissions.rationale.microphone.*` | none |
| notifications | (no purpose string on iOS) / `POST_NOTIFICATIONS` (API 33+) | `onboarding.permission.notifications` | system text; `system.permissions.rationale.notifications.*` for a later re-ask on Android | `onboarding.permission.notifications` |
| photo library, add-only | `NSPhotoLibraryAddUsageDescription` / none (MediaStore, API 29+) | first save | `system.permissions.photosAdd.purpose` | none |
| photo library, read | `NSPhotoLibraryUsageDescription` / none (Photo Picker) | only if PhotoKit reading ships | `system.permissions.photosRead.purpose` | none |
| contacts | `NSContactsUsageDescription` / `READ_CONTACTS` (Contact Picker on API 37+ when targeting 37) | `groups.invite` contacts section | `system.permissions.contacts.purpose`; `system.permissions.rationale.contacts.*` | Android card (`onboarding.permission.contacts`); none on iOS |
| tracking (ATT) | not used (no ads, no tracking) | never | — | — |

## Android rationale dialog (Structure)

M3 basic dialog (`settings.account.layout.alert`): headline = `system.permissions.rationale.<resource>.title` (Yope voice),
supporting text = `….message`, actions `system.permissions.rationale.notNow` (dismissive) and
`system.permissions.rationale.continue` (confirming → system dialog). After a permanent denial the confirming action is
`system.permissions.openSettings` (→ app details settings).

## Elements

| element | tokens | copy |
|---|---|---|
| iOS system alert | system (PLATFORM) | purpose strings |
| Android system dialog | system | — (system text) |
| Android rationale | `settings.account.layout.alert`; `color.global.system.*`; `layout.global.system.typography` | `system.permissions.rationale.*`, `system.permissions.openSettings` |

## States

not determined → system prompt; granted → feature; denied → the feature's permission-denied state (camera card in
`camera.capture`, photos card on save, notifications section in `settings.notifications`, contacts card in
`groups.invite`); restricted (parental controls) → same as denied.

## Motion · Haptics

System. None of ours.

## Accessibility

System dialogs are accessible by default; rationale dialog per M3 (headline first, then text, then actions).

## Data & actions

`register_device` after a notifications grant (docs/API.md §6.3). No other API.

## Platform notes

- One string per resource; each names the feature (5.1.1(ii)). If contacts are matched against accounts
  (`ContactMatching.swift`), the contacts string must say so before release.
- iOS pre-alert screens: one button ("continue"), no close/skip (HIG). Android: always cancellable.
- Play policy: no `READ_MEDIA_*`, no `READ_MEDIA_VISUAL_USER_SELECTED`; `READ_CONTACTS` declaration for API 37+ targets.

## Do-not-copy

Yope's fragment style without a final period ("Allow camera access. So you can …") for iOS purpose strings (F-20);
"Your data will be used to analyze the efficiency of our marketing channels" (ATT, ads).

## Gaps

| item | status |
|---|---|
| Yope's contacts and 2026 photo purpose strings | not found; not needed (HIG form governs) |
| "Save" label in `system.permissions.photosAdd.purpose` | must match the `photo.viewer` save label (that pass) |

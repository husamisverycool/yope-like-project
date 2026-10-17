# share.in — "Share to Jolt" from Photos and other apps

**What it is.** Owner decision 34; docs/RESEARCH_FEATURES_2026-10-17.md #4. From the system share sheet of Photos (or
any app sharing photos or videos), choosing the app hands the items to it: it opens on `camera.sendto` with them, as a
library selection — several photos in one post (`camera.sendto.md` "Several photos"), each with the day it was taken
(`camera.capture.md` "The day a library photo was taken").

- **Mechanics: Apple Shared Albums "Share → Add to Shared Album"** (https://support.apple.com/en-us/108314): select the
  items, tap Share, choose the destination; the destination's own composer follows. **Android: "Receiving simple data
  from other apps"** (https://developer.android.com/training/sharing/receive): `ACTION_SEND` / `ACTION_SEND_MULTIPLE`
  intent filters for `image/*` and `video/*`, the items as `EXTRA_STREAM` content URIs.
- **Components: platform** (the share sheet and its app row: the app's name `{app_name}` and icon, PLATFORM) and the
  app's own `camera.capture` → `camera.trim` → `camera.sendto`. **No screen of its own, and no new copy**: the share
  sheet draws the app's name; everything after is camera.sendto's.

## Flow

| step | iOS | Android |
|---|---|---|
| 1. share sheet | the app's Share Extension appears for photos and videos (Info.plist `NSExtensionActivationRule`: at most 20 images and 20 movies — `batch_max_photos`) | MainActivity's `SEND` / `SEND_MULTIPLE` filters (`image/*`, `video/*`) |
| 2. hand over | the extension copies the items into the App Group container (`ShareInbox`: the files and their order, nothing else), opens the app's own scheme `<bundle id>://share` (it carries nothing) and closes | MainActivity copies the `EXTRA_STREAM` items at once into the app's cache (the read grant lasts while its task lives), at most `batch_max_photos` |
| 3. sign-in first | signed out or not onboarded: the share waits (`AppRouter.pendingShare`, as every link) and continues once the person is home | the share waits (`ShareInbox`) until the shell is home (signed in, past sign-up and onboarding) |
| 4. the camera | the camera tab opens and takes the items as a library selection | the shell opens `camera.capture`, which takes them as a library selection |
| 5. send-to | at most `batch_max_photos` (1 while unknown); each long video through `camera.trim` first; then `camera.sendto` with the whole selection, no group preselected beyond the camera's rule (all groups) | same |

## States

| state | behaviour |
|---|---|
| signed out / onboarding | sign-up and onboarding first; then step 4 (iOS: the inbox stays in the App Group container; Android: in memory for the running app) |
| a composer already open | the share waits until it closes (the camera takes it next) |
| the extension cannot open the app (iOS) | the items wait in the inbox; the app takes them the next time it comes to the foreground |
| more items than `batch_max_photos` | the first ones in the share's order; the rest are not kept |
| an unreadable item / not a photo or video | left out; nothing shared → nothing opens |
| video by a free member | `camera.sendto`'s rule (paywall once per session, send disabled) |
| loading / empty / error / offline | `camera.sendto`'s (the copy happens on the device, offline too) |

## Privacy and safety

- Only the files are kept — no caption, no place, no sender; location tags are stripped (Android) / the photo is
  re-encoded without metadata at upload (iOS), as for a library pick. The day taken is the date only.
- Android takes only `content://` URIs of other apps: never a `file://` path and never one of the app's own providers
  (a crafted share must not make the app post its own private files).
- iOS: the extension's privacy manifest declares nothing collected (`ios/ShareExtension/PrivacyInfo.xcprivacy`).

## Motion, haptics, accessibility

System share sheet; then `camera.sendto`'s.

## Platform notes

- iOS: target `ShareExtension` (`ios/project.yml`; bundle id `$(APP_BUNDLE_ID).share`; App Group `group.$(APP_BUNDLE_ID)`;
  `Config/ShareExtension.xcconfig`); `ShareViewController` opens the app through the responder chain's `UIApplication`
  (share extensions have no `openURL`), so `APPLICATION_EXTENSION_API_ONLY` is off for that target. The app registers
  its bundle id as its only URL scheme (`CFBundleURLTypes`, `AppURLScheme`); widget links stay on the unregistered
  `app://`. Inbox and link: `AppModels/ShareInbox.swift`; the app side: `App/Sources/Features/Capture/Share/ShareIn.swift`.
- Android: `app/src/main/AndroidManifest.xml` filters on MainActivity (singleTask: the app's own task); copy and inbox:
  `feature/capture/.../share/ShareIn.kt`; the shell opens the camera (`AppNavHost`), `CameraRoute` takes the items.

## Gaps

| item | status |
|---|---|
| a mixed photo + video share whose sender types it `*/*` (Android) | not matched by the `image/*` / `video/*` filters (a `*/*` filter would offer the app for every file) |
| the share sheet's suggestion row (iOS `INSendMessageIntent` donations / Android direct share targets) | not built: no per-group targets |

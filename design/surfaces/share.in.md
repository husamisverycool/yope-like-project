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
- **Per-group targets: Apple "Supporting suggestions in your app's share extension"**
  (https://developer.apple.com/documentation/foundation/app_extension_support/supporting_suggestions_in_your_app_s_share_extension)
  and **Android sharing shortcuts** (https://developer.android.com/training/sharing/receive#sharing-shortcuts-api): the
  share sheet's suggestion row offers the person's groups next to the app (PLATFORM: the row, its order and how many it
  shows are the system's). Each target is the group's name (the person's data, not copy) and, on Android, its cover
  photo or initials.

## Flow

| step | iOS | Android |
|---|---|---|
| 1. share sheet | the app's Share Extension appears for photos and videos (Info.plist `NSExtensionActivationRule`: at most 20 images and 20 movies — `batch_max_photos`) | MainActivity's `SEND` / `SEND_MULTIPLE` filters (`image/*`, `video/*`) |
| 2. hand over | the extension copies the items into the App Group container (`ShareInbox`: the files and their order, nothing else), opens the app's own scheme `<bundle id>://share` (it carries nothing) and closes | MainActivity copies the `EXTRA_STREAM` items at once into the app's cache (the read grant lasts while its task lives), at most `batch_max_photos` |
| 3. sign-in first | signed out or not onboarded: the share waits (`AppRouter.pendingShare`, as every link) and continues once the person is home | the share waits (`ShareInbox`) until the shell is home (signed in, past sign-up and onboarding) |
| 4. the camera | the camera tab opens and takes the items as a library selection | the shell opens `camera.capture`, which takes them as a library selection |
| 5. send-to | at most `batch_max_photos` (1 while unknown); each long video through `camera.trim` first; then `camera.sendto` with the whole selection; a group picked in the suggestion row is preselected (alone), otherwise the camera's rule (all groups) | same |

## Per-group targets

| | iOS | Android |
|---|---|---|
| what becomes a target | an outgoing `INSendMessageIntent` donation per group, the group as the conversation (`speakableGroupName` = its name, `conversationIdentifier` = its id, interaction `groupIdentifier` = its id) | a long-lived dynamic shortcut per group (`share-group-<id>`), category `app.sharetarget.category.GROUP` matching the `share-target` in `res/xml/shortcuts.xml` (image/\*, video/\*), short label its name, icon its cover photo (centre square) or its initials on `color.global.control` in `color.global.textSecondary` |
| when | the person posts to the group (send-to's send, every group chosen) or opens it (`groups.screen`) | same (`ShortcutManagerCompat.pushDynamicShortcut`) |
| picked in the share sheet | the Share Extension opens with the intent (`extensionContext.intent`, Info.plist `IntentsSupported`); its conversation identifier goes into the inbox with the files (`ShareInbox` `group.txt`) | MainActivity receives SEND / SEND_MULTIPLE with `EXTRA_SHORTCUT_ID`; the group waits in `ShareInbox` with the items |
| in send-to | that group alone is preselected (a group no longer the person's is not: camera.sendto's rule) | same |
| a group left or deleted | its donations are deleted (`INInteraction.delete(with: groupID)`) after the group list refreshes | its shortcut is removed (dynamic and long-lived) when the group list loads |
| sign-out | every donation is deleted (`INInteraction.deleteAll`) | every share target is removed |
| room | the system's | the per-activity shortcut limit, after the static camera shortcut and camera.quickaccess's group shortcuts (those keep their slots; share targets rank after them) |

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
- Per-group targets hold only a group's id, name and (Android) cover image, on this device; they go when the person leaves
  the group or signs out. A shortcut id that is not the app's own `share-group-` form, or an id that is not a plain id, is
  no group (the share then preselects as any share).

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
- Per-group targets — iOS: `App/Sources/Features/Capture/Share/ShareTargets.swift` (`ShareTargetDonations`; donated from
  `SendToModel.send` and `GroupScreen`, kept to the person's groups by `SessionHooks.keepShareTargets` from
  `SessionCoordinator`); the app's Info.plist lists `INSendMessageIntent` in `NSUserActivityTypes`. Android:
  `feature/capture/.../share/ShareTargets.kt` (recorded from `GraphCaptureData.recordSend` and `AppNavHost` on
  `AppRoute.Group`; synced and cleared in `CaptureStartup`). `CameraShortcuts` publishes and removes only its own ids (no
  `setDynamicShortcuts` / `removeAllDynamicShortcuts`), so the two sets never replace each other.

## Gaps

| item | status |
|---|---|
| a mixed photo + video share whose sender types it `*/*` (Android) | not matched by the `image/*` / `video/*` filters (a `*/*` filter would offer the app for every file) |
| per-group targets before Android 10 | not offered: the `share-target` element needs API 29 (the `androidx.sharetarget` backport is not included) |
| iOS target image | none donated: the share sheet shows the system's placeholder with the group's name (the cover would need a download at donation) |

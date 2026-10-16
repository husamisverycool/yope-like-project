# Platform constraints (iOS 26 / Android 16 era)

Researched 2026-10-15. Every claim has a link to Apple, Google, Firebase, Meta, Supabase, RevenueCat,
Twilio, FTC or W3C documentation. Quotes are verbatim. Where an official source does not answer the
question, this file says **UNCONFIRMED** and cites the best available evidence, such as an Apple DTS
forum answer. Design values derived from these docs are in `design/research/platform.md` and
`design/proposals/platform.tokens.json`. Nothing here is legal advice. Sections 8 and 9 list
obligations that counsel should confirm.

Short names used below:
- **[KWU]** = https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date
- **[WKP]** = https://developer.apple.com/documentation/widgetkit/updating-widgets-with-widgetkit-push-notifications
- **[LAP]** = https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications
- **[LAD]** = https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
- **[APNS]** = https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns
- **[BG]** = https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app
- **[FCMP]** = https://firebase.google.com/docs/cloud-messaging/android/message-priority (updated 2026-10-13)
- **[RG]** = https://developer.apple.com/app-store/review/guidelines/ ("Last Updated: June 8, 2026")

---

## Summary: what is impossible or needs a compliant alternative

| Product spec item | Status | Compliant alternative |
|---|---|---|
| "A photo appears instantly on other members' widgets" (`widget.arrival`) | **Not guaranteed on either OS.** iOS widget reloads and widget pushes are budgeted and "delivered opportunistically" [WKP]. Locket documents "a slight delay of up to 5 minutes" (§1). | Use the layered path in §1. Design the arrival state for a delay of minutes. Never promise "instant" in copy. |
| `widget.home.xl` on iPhone | **Impossible.** HIG: System extra large on iPhone is "Not supported" (https://developer.apple.com/design/human-interface-guidelines/widgets). | Offer it on iPad only. On iPhone the largest is systemLarge (338×354 pt on 393-pt screens). |
| Color photos on `widget.lock.*` (iPhone Lock Screen) | **Impossible.** Lock Screen widgets use the vibrant mode, which "desaturates text, images, and gauges" (HIG widgets). | Monochrome or text accessory widgets (name, time, "new photo" glyph). Color stays on the Home Screen and in StandBy (full color). |
| `widget.lock.*` on Android | **No phone equivalent of iOS accessory widgets.** Android 16+ has a lock-screen widget *hub* (Pixel phones from Android 16 QPR2; OEM-dependent) that shows ordinary widgets at about 4×3 cells (§4). | The Glance widget opts in (`widgetCategory="home_screen\|keyguard"`, owner decision 18) and draws its Medium layout in the hub slot; taps open the app after unlock. Use lock-screen-visible notifications for new photos. |
| `daily.ongoing` as an Android 16 "Live Update" (promoted chip) | **Not compliant by default.** Live Updates must be "explicitly triggered by the user"; "Don't allow activities triggered by other parties to generate Live Updates" (§4). | Use a standard notification with a chronometer countdown (`setUsesChronometer` + `setChronometerCountDown` + `setTimeoutAfter`). Promote only after an explicit opt-in, with an Unpin action. |
| Instant-app invite preview on Android (`invite.web` equivalent of the App Clip) | **Impossible.** Google Play Instant ended December 2025 (§4). | Web page plus Play Store link with Install Referrer; Android App Links for installed users. |
| Skippable iOS pre-permission screens (`onboarding.permission.contacts` "skip") | **Non-compliant on iOS.** HIG: pre-alert screens must have one button and no way to leave without the system alert (`design/research/platform.md`). | Contacts are offered inside the invite flow (`ContactAccessButton` / `contactAccessPicker`, iOS 18+). Show iOS pre-alert screens only with a single "Continue". |
| READ_MEDIA_IMAGES / partial photo access on Android | **Play policy restricts it** to apps where pickers are insufficient (§6). | Android Photo Picker; no media permission. |
| READ_CONTACTS on Android 17+ | **Requires a Play declaration** from 2027-01-27 (§6). | Android Contact Picker (API 37+); declare "social discovery" only if matching contacts. |
| Dual camera everywhere (`daily.capture`) | **Hardware-dependent.** iOS needs `isMultiCamSupported` (A12+ per Apple sample). Android needs `FEATURE_CAMERA_CONCURRENT`. | Sequential capture (back, then front) as fallback (§5). |
| Live Photo during simultaneous front+back capture | **UNCONFIRMED.** Apple documents Live Photo support as dependent on format and preset; nothing says it works in a multi-cam session (§5). | Detect it at runtime. Live Photo applies to single-camera captures only unless proven otherwise. |
| Account deletion that keeps a deleted member's shared photos (tenet "Nothing gets lost") | **Conflicts with Apple 5.1.1(v) FAQ.** Deletion must include "user-generated content that's shared with others, such as photos" (§9). | Owner decision. Deleting the account deletes the member's photos. A pre-deletion export or save prompt is allowed. |
| Instagram Stories size "1080×1920 (from Meta docs)" | **The doc does not say 1080×1920.** It says "Minimum dimensions 720x1280. Recommended image ratios 9:16 or 9:18" (§share in research). | 1080×1920 is a valid 9:16 canvas above the minimum. It is labeled "computed" in tokens. |
| App Clip "15 MB / 50 MB / 100 MB" | **50 MB no longer appears in Apple's table** (§3). | 15 MB (iOS 16), or 100 MB on iOS 17+ under conditions (digital-only invocations, no iOS 16 support). |
| Android Live-Photo-style playback of iOS Live Photos | **Not researched / no platform API found.** | Treat as still + short video on Android (owner decision). |

---

## 1. iOS widget refresh and "photo posted on one device appears on another member's widget"

### 1.1 WidgetKit reload budget
- "For a widget the user frequently views, a daily budget typically includes from 40 to 70 refreshes. This
  rate roughly translates to widget reloads every 15 to 60 minutes" [KWU].
- The budget is per widget instance ("each widget has its own budget"). It runs over a 24-hour window
  "tuned ... to the user's daily usage pattern". "The system takes a few days to learn the user's
  behavior" [KWU].
- Reloads that do **not** count against the budget [KWU]:
  - "The widget's containing app is in the foreground."
  - Active audio or navigation session; Now Playing app.
  - "The widget performs an app intent, such as when the user taps a button or toggles a switch."
  - "The widget performs an animation."
  - Locale change; Dynamic Type or Accessibility setting change.
  - StandBy refreshes at "a system-defined rate that doesn't count against its budget".
- Timeline entries "should ... be at least about 5 minutes apart. WidgetKit may coalesce reloads across
  multiple widgets" [KWU].
- If many devices use `.after(date)` with the same date, "a significant increase in server load" can
  follow [KWU]. Stagger the dates.
- WWDC25 "What's new in widgets": a `reloadTimelines` call from the app while "the app is running ... the
  system does not budget this request". During development, "WidgetKit developer mode in Settings" ignores
  budgets (https://developer.apple.com/videos/play/wwdc2025/278/).
- Apple DTS (June 2025): a reload while "your app is running in the background ... is counted against the
  budget" (https://developer.apple.com/forums/thread/788713).

### 1.2 `WidgetCenter.reloadTimelines` from the app and from extensions
- `reloadTimelines(ofKind:)` is iOS 14+
  (https://developer.apple.com/documentation/widgetkit/widgetcenter/reloadtimelines(ofkind:)). The docs do not
  mark `WidgetCenter` as unavailable in app extensions, and they do not describe calling it from a
  Notification Service Extension.
- **Calling it from a Notification Service Extension: UNCONFIRMED.** Developers report that an NSE call
  "doesn't 'force' widget to reload" while the same call from the app works
  (https://developer.apple.com/forums/thread/669736, no Apple answer). Per DTS (above), any reload while the
  app is not in the foreground is budgeted.
- Treat an NSE reload as a **best-effort, budgeted** request. The NSE's real value is that it can
  **download the new photo into the App Group** before the widget's next timeline request.
- NSE limits: it runs only for remote notifications "configured ... to display an alert" with
  `mutable-content: 1`. It "isn't employed" if alerts are disabled or the payload only plays a sound or
  badges. It gets "only about 30 seconds"
  (https://developer.apple.com/documentation/usernotifications/modifying-content-in-newly-delivered-notifications ;
  https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension).
  - **Consequence:** the NSE path does nothing for a member who muted the group or turned off alerts.

### 1.3 Background pushes (`content-available`)
- "the system doesn't guarantee their delivery ... may throttle ... don't try to send more than two or
  three per hour" [BG].
- They must use `apns-push-type: background` with `apns-priority: 5` ("Using priority 10 is an error")
  [APNS].
- The system holds only the newest, and discards it if the app was force-quit. The app has 30 seconds [BG].
- "Notifications with apns-priority 5 and apns-priority 1 might get grouped and delivered in bursts" [APNS].

### 1.4 WidgetKit push notifications (iOS 26+)
- **Availability:** `WidgetPushHandler` is iOS/iPadOS/macOS/watchOS/visionOS **26.0+**
  (https://developer.apple.com/documentation/widgetkit/widgetpushhandler).
- **Mechanics** [WKP]:
  - Add the Push Notifications capability to the widget extension.
  - Implement `WidgetPushHandler.pushTokenDidChange(_:widgets:)`, which sends the token and `[WidgetInfo]`
    to the server.
  - Attach it with `.pushHandler(...)` on the `WidgetConfiguration`.
  - Send with `apns-push-type: widgets`, `apns-topic: <bundleID>.push-type.widgets`, and body
    `{"aps":{"content-changed":true}}`.
  - "When WidgetKit receives a push notification, it reloads your timelines, similar to when you call
    reloadAllTimelines()."
- **Limits** [WKP]:
  - "the system budgets WidgetKit push notifications and delivers them opportunistically ... doesn't
    replace timeline updates".
  - "You can't update widgets with broadcast push notifications you send on a channel."
  - WWDC25: "this will update all of the push enabled widgets configured on the device"; "Try to keep your
    update pushes limited, such as by throttling updates on your server"; "If you have an urgent or
    important update to show, provide a User Notification."
  - No numeric budget is published.
- **What it permits:** a server-originated reload of a member's widget with no visible notification, no app
  launch, and no dependence on notification settings. Per DTS, its budget is "separate than the budget"
  for background pushes (https://developer.apple.com/forums/thread/787892).

### 1.5 How Locket is known to do it (cited facts only)
- Locket's help center (updated May 5, 2026): "When a friend sends you a photo on Locket, it will appear on
  your Home Screen, but there may be a slight delay of up to 5 minutes. This delay helps conserve your
  phone's battery." (https://help.locket.com/en/articles/5859739-why-isn-t-my-locket-widget-updating).
- TechCrunch (2025-11-03): "Instead of updates sent via push notifications, the app's widget would update to
  show your friends' newly posted photos." The Rollcall feature uses a Live Activity: "Every Sunday, we'll
  take over your Lock Screen" (Matt Moss)
  (https://techcrunch.com/2025/11/03/lockets-social-app-is-picking-up-steam-with-gen-alpha/).
- **Not found:** any public statement of Locket's exact mechanism (NSE vs silent push vs widget push).
  The 5-minute figure fits the ≥5-minute entry spacing and coalescing in [KWU].

### 1.6 Recommended path (fastest compliant; layered, server-driven)

Server, on each new post, for each recipient device:

1. **Widget push (iOS 26+)** to every recipient device's widget token: `apns-push-type: widgets`. Coalesce
   on the server to one push per device per few minutes, because Apple says to throttle and the push reloads
   all widgets anyway. This is the primary channel for members who muted the group.
2. **Alert push** with `mutable-content: 1` (priority 10), only where the member wants a notification for
   that group (tenets: no fake or nagging notifications). The NSE:
   - downloads a widget-sized rendition (≤30 s) into the App Group container;
   - attaches it to the notification;
   - calls `WidgetCenter.shared.reloadTimelines(ofKind:)` as a budgeted, best-effort request.
   On iOS < 26 this is the main channel.
3. **iOS < 26 and muted groups:** a background push (`content-available`, priority 5). Keep it to 2–3 per
   hour or fewer per device [BG]. The app downloads the photo and reloads (budgeted).
4. **Timeline provider:**
   - Read from the App Group cache first. If the cache is stale, fetch with a background `URLSession` plus
     `onBackgroundURLSessionEvents`, because a widget request "may not have enough time to complete"
     (https://developer.apple.com/documentation/widgetkit/making-network-requests-in-a-widget-extension).
   - Return `.after(now + 15…60 min)` with per-device jitter as the safety net within the 40–70/day budget.
   - Keep entries ≥ 5 min apart.
5. **App foreground:** reload all widget kinds on every foreground and after the member posts. This is free
   of budget.
6. **Copy and design:** never claim "instant"; show "last updated" text if useful. HIG: "If people are
   likely to check your widget more frequently than you can update it, consider displaying text that
   describes when the data was last updated"
   (https://developer.apple.com/design/human-interface-guidelines/widgets).

**Android equivalent (§4):**
- Send an FCM **high-priority** message only when a visible notification is posted. `onMessageReceived`
  posts the notification immediately and enqueues an **expedited** WorkManager job, which gets a brief
  quota exemption after a high-priority FCM. That job downloads the image and calls
  `GlanceAppWidget().updateAll(context)`.
- For muted groups, send **normal priority**. Delivery "may be delayed" in Doze; the handler enqueues a
  regular WorkRequest.
- Use `updatePeriodMillis` (≥30 min) or periodic WorkManager as the safety net.

---

## 2. Live Activities (daily invitation, `daily.liveactivity`)

- **Push-to-start** is iOS/iPadOS **17.2+**. The app must have run to obtain the token, which comes from
  `Activity<...>.pushToStartTokenUpdates`; "You don't have to start a Live Activity from your app to receive
  the push-to-start token"
  (https://developer.apple.com/documentation/activitykit/activity/pushtostarttoken ; [LAP]).
- **Start payload** [LAP]:
  - Requires `"event":"start"`, an **`alert`** ("you make sure the system notifies a person about the newly
    started Live Activity"), `attributes-type` and `attributes`.
  - On iOS 18+, add `"input-push-token": 1` to receive an update token, or `"input-push-channel"` for
    broadcast updates.
  - "You can't use broadcast push notifications to start a Live Activity."
- **Headers** [LAP]:
  - `apns-push-type: liveactivity`, `apns-topic: <bundleID>.push-type.liveactivity`, `apns-priority: 5 or 10`.
  - Channel updates use `apns-channel-id` (iOS 18+).
- **Budget** [LAP]:
  - "The system allows for a certain budget of ActivityKit push notifications per hour". Priority 10 (the
    default) "counts toward the notification budget"; "low-priority ... priority 5 ... doesn't count
    toward the budget".
  - `NSSupportsLiveActivitiesFrequentUpdates = YES` raises the budget. People can turn this off; check
    `ActivityAuthorizationInfo.frequentPushesEnabled`.
  - (The ActivityAuthorizationInfo page spells the key `NSSupportsFrequentLiveActivityUpdates`. The
    Info.plist reference page is `NSSupportsLiveActivitiesFrequentUpdates`. Use the Info.plist page.)
  - Our use (start, then end, about 2 pushes per day per device) does not need frequent updates.
- **Payload size:** "Static and dynamic data ... can't exceed a combined size of 4 KB" [LAD].
- **Duration** [LAD]:
  - "active for up to eight hours"; after that the system ends it, and it stays on the Lock Screen "for up
    to four additional hours". The maximum is 12 h.
  - Images larger than the presentation "might fail to start the Live Activity".
- **staleDate:** set it to the window end, so `activityState` becomes `.stale` if the end push never arrives
  (https://developer.apple.com/documentation/activitykit/activitycontent/staledate ; [LAP]).
- **Consent and authorization:**
  - People can turn off Live Activities per app in Settings. Check `areActivitiesEnabled`
    (https://developer.apple.com/documentation/activitykit/activityauthorizationinfo).
  - **Push-to-start shows an inline "Allow / Don't Allow" prompt** when started while the app is in the
    background or closed. The prompt repeats until the person chooses. The update token arrives only after
    "Allow". Starting the first activity locally in the foreground avoids the prompt (Apple DTS, May 2026,
    https://developer.apple.com/forums/thread/825419).
  - In general "your app needs to be in the foreground to start a Live Activity", except through push-to-start
    or a `LiveActivityIntent` [LAD].
- **Ending at window close:**
  - Send `"event":"end"` with the final `content-state` and a `"dismissal-date"`. A past date dismisses
    immediately; otherwise the date must be within 4 h [LAP].
  - Also end it from the app when it is foregrounded (`end(_:dismissalPolicy:)`, `.immediate` / `.after(date)`).
  - On iOS 18+ a per-group/day **broadcast channel** can update or end all members' activities in one push
    (it cannot start them) [LAP].
- **Countdown:** `Text(timerInterval:countsDown:)` (iOS 16+) updates itself, so no per-second pushes are
  needed (https://developer.apple.com/documentation/swiftui/text/init(timerinterval:pausetime:countsdown:showshours:)).
- **HIG** (https://developer.apple.com/design/human-interface-guidelines/live-activities, 2026-10-13):
  - Offer an in-app control to turn the invitation Live Activity off.
  - Avoid alerting except for "essential updates"; send no reminder alerts (tenet 5).
  - "don't use push notifications alongside Live Activities for the same updates". The start alert *is* the
    daily invitation.
- **App Clips** may include a widget extension for Live Activities
  (https://developer.apple.com/documentation/appclip/choosing-the-right-functionality-for-your-app-clip).

---

## 3. App Clips (`invite.appclip`)

- **Size** (uncompressed binary; https://developer.apple.com/documentation/appclip/choosing-the-right-functionality-for-your-app-clip):

  | iOS version | Maximum uncompressed App Clip binary |
  |---|---|
  | iOS 15 and earlier | 10 MB |
  | iOS 16 and earlier | 15 MB |
  | iOS 17 and later | 100 MB, with conditions |

  - The 100 MB conditions: "only supports digital invocations"; no App Clip Codes, QR codes or NFC; "a
    reliable internet connection is likely"; "doesn't support iOS 16 and earlier".
  - The App Store Connect **demo link** allows 100 MB with physical invocations.
  - The "50 MB" figure in the brief is **not in the current table**.
  - **Recommendation:** invites are digital links, so target iOS 17+ with ≤100 MB, and keep it well below.
- **Invocation:** a default App Clip experience is required. Its default link works in Messages; a Smart App
  Banner or card on our site needs an associated website
  (https://developer.apple.com/documentation/appclip/configuring-the-launch-experience-of-your-app-clip).
  - Associate the site: add the `appclips:<domain>` associated domain plus an `appclips` entry in
    `/.well-known/apple-app-site-association`
    (https://developer.apple.com/documentation/appclip/associating-your-app-clip-with-your-website).
  - Banner/card meta tag: `<meta name="apple-itunes-app" content="app-id=…, app-clip-bundle-id=…, app-clip-display=card">`
    (https://developer.apple.com/documentation/appclip/supporting-invocations-from-your-website-and-the-messages-app).
  - **Advanced experiences** are needed for iOS 16.3 and earlier, or for extra domains. Use "URL prefix
    matching" (register a generic prefix such as `https://<domain>/i/`).
  - Handle launches without an invocation URL, for example a return from a notification.
- **Installing the full app:** `SKOverlay.AppClipConfiguration` / SwiftUI `appStoreOverlay`, shown "when
  someone completes a task or reaches a natural pause". "Don't require users to install your app to complete
  a task"
  (https://developer.apple.com/documentation/appclip/recommending-your-app-to-app-clip-users ;
  https://developer.apple.com/design/human-interface-guidelines/app-clips).
  - "When people install the full app, it replaces the App Clip". Invocations then open the full app.
    Guideline 2.5.16(a): "all App Clip features and functionality must be included in the main app binary.
    App Clips cannot contain advertising" [RG].
- **Passing data to the full app**
  (https://developer.apple.com/documentation/appclip/sharing-data-between-your-app-clip-and-your-full-app):
  - Shared **App Group** container and `UserDefaults(suiteName:)`. Store the session or invite code, never
    passwords.
  - **Keychain:** from iOS 15.4, items the App Clip stores are "accessible to its corresponding full app"
    (parent-application-identifiers entitlement). The App Clip cannot read the full app's keychain.
  - Sign in with Apple.
  - The full app also receives the same invocation URL, as an `NSUserActivity` browsing-web activity, for
    the invite. "confirm that the invocation is of type NSUserActivityTypeBrowsingWeb"; "If a user installs
    the full app, it replaces the App Clip"
    (https://developer.apple.com/documentation/appclip/responding-to-invocations).
- **Ephemeral notifications:** "up to 8 hours after each launch" with
  `NSAppClip > NSAppClipRequestEphemeralUserNotification = YES`. People can turn it off on the card. Check
  `authorizationStatus == .ephemeral`. Ask for full permission only if the flow spans more than a day
  (https://developer.apple.com/documentation/appclip/enabling-notifications-in-app-clips).
- **Not available in App Clips** (same page as Size):
  - Contacts, Photos (PhotoKit), background networking and background modes (so no silent pushes).
  - App extensions other than the Live Activity widget extension.
  - In-app purchases (reserve them for the full app); App Tracking Transparency; Face ID.
  - "When In Use" location resets at 4:00 a.m.
- **HIG card content:** 1800×1200 px image without transparency and without text; title ≤30 characters;
  subtitle ≤56 characters. "Avoid requiring people to create an account before they can benefit from your
  App Clip" (https://developer.apple.com/design/human-interface-guidelines/app-clips).
  - **Consequence for joining a group:** show the group preview first, then use phone OTP. Phone OTP is our
    own account system, so 4.8 does not require another login option: "Another login service is not
    required if: Your app exclusively uses your company's own account setup" [RG 4.8].

---

## 4. Android

### 4.1 Google Play Instant
- **Gone.** "Google Play Instant will no longer be available. Starting December 2025, Instant Apps cannot be
  published through Google Play, and all Google Play services Instant APIs will no longer work"
  (https://developer.android.com/topic/google-play-instant, page updated 2026-06-24).
- **Equivalent:** the `invite.web` page plus a Play listing link carrying the invite as a referrer. Read it
  after install with the Play Install Referrer API ("securely retrieve referral content",
  https://developer.android.com/google/play/installreferrer). Use Android App Links (`assetlinks.json`) for
  installed users (https://developer.android.com/training/app-links).

### 4.2 Lock-screen widgets
- Google FAQ (2025-03-06):
  - "Lock screen widgets will be available in AOSP for tablets and mobile starting with the release after
    Android 16 (QPR1)".
  - "All widgets are compatible with the lock screen widget experience". They are "sized to approximately
    4 cells wide by 3 cells tall".
  - The trigger is OEM-customizable.
  - Activities launched from it need authentication or `android:showWhenLocked="true"`.
  - Opt out with category `not_keyguard` in an `xml-36` resource
    (https://android-developers.googleblog.com/2025/03/widgets-on-lock-screen-faq.html ;
    `WIDGET_CATEGORY_NOT_KEYGUARD` "Added in API level 36",
    https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo).
- Pixel **phones** received it in Android 16 QPR2 (Android Authority, not a Google doc:
  https://www.androidauthority.com/lock-screen-widgets-on-phones-android-16-qpr2-3589668/). Google's official
  help page covers Pixel Tablet only (https://support.google.com/googlepixeltablet/answer/15627499).
- **Opt-in (owner decision 18, implemented):** the group photo widget declares
  `android:widgetCategory="home_screen|keyguard"` (`core/widget/src/main/res/xml/group_photo_widget_info.xml`;
  token `widget.android.layout.lockScreen`).
  - `WIDGET_CATEGORY_KEYGUARD` "Indicates that the widget can be displayed on the keyguard" (added in API level 17); a
    widget shown on both "needs to ensure that it follows the design guidelines for both widget classes"
    (https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo). Releases without a lock-screen
    hub ignore the flag: the widget stays a home-screen widget there ("shown only where the OS supports it").
  - Layout check: the hub slot (about 4 × 3 cells = `PlatformWidgetGrid.minSize(4, 3)`, 276 × 183 dp) selects the
    responsive Medium layout; Roborazzi renders of the real Glance widget at that size — photo, collage, empty, signed
    out (`android/feature/capture/src/test/snapshots/widget.android_keyguard_*.png`) — keep the full-bleed photo and the
    bottom-trailing text stack.
  - Privacy: the person places the widget on the hub; it shows what the home-screen widget shows (the newest group
    photo, as the iOS Home Screen widget does — iOS Lock Screen accessories stay monochrome, §summary). A tap needs
    authentication (`MainActivity` has no `showWhenLocked`), so the app itself never opens over the lock screen.
  - Preview: Glance's generated preview defaults to one preview for "WIDGET_CATEGORY_HOME_SCREEN or
    WIDGET_CATEGORY_KEYGUARD or WIDGET_CATEGORY_SEARCHBOX"
    (https://raw.githubusercontent.com/androidx/androidx/androidx-main/glance/glance-appwidget/src/main/java/androidx/glance/appwidget/GlanceAppWidgetManager.kt).
- **Closest compliant equivalent of iOS accessory widgets on phones:**
  - The Glance widget on the lock-screen hub (above).
  - Lock-screen notification visibility for new photos (channel/notification `VISIBILITY_*`).
  - The daily countdown notification (§4.6).

### 4.3 Glance / AppWidget update limits
- "`updatePeriodMillis` doesn't support values of less than 30 minutes"; set it to 0 and use WorkManager for
  other schedules. WorkManager is subject to standby buckets
  (https://developer.android.com/develop/ui/views/appwidgets/advanced, 2026-10-01).
- Receivers have 10 s before ANR; use `goAsync` or WorkManager (same page).
- Glance: `GlanceAppWidget().update(context, glanceId)` / `updateAll(context)` / `updateIf`, called from a
  `CoroutineWorker`.
  - "Your widget can update immediately when your app is awake ... while the app is already updating in
    response to a Firebase Cloud Messaging (FCM) message".
  - "Use WorkManager to schedule more frequent updates, such as every 15 minutes"; "Avoid updating your widget
    every minute"
  - Source: https://developer.android.com/develop/ui/compose/glance/glance-app-widget (2026-09-22).
- Generated previews: `setWidgetPreview` "is a rate-limited API. The default limit is approximately two calls
  per hour" (https://developer.android.com/develop/ui/compose/glance/generated-previews).

### 4.4 FCM priority, quotas, deprioritization
- **Normal priority:** "delivered immediately when the device is not sleeping. When the device is in Doze
  mode, delivery may be delayed".
- **High priority:** "allowing FCM to wake a sleeping device ... High priority messages generally should
  result in user interaction" [FCMP].
- **Deprioritization:** "If FCM detects a pattern in which messages don't result in user-facing
  notifications, your messages may be deprioritized to normal priority". The determination uses "7 days of
  message behavior ... independently for every instance". If the person disabled notifications, messages
  are deprioritized [FCMP].
  - So **send high priority only together with a visible notification.** Widget-only updates go at normal
    priority.
- **Processing:** "several seconds ... only expected to be long enough to immediately render a notification".
  Use an expedited WorkManager job after a high-priority message; "There is a brief exemption for expedited
  jobs scheduled immediately after a high priority FCM" [FCMP].
- **Quotas** (https://firebase.google.com/docs/cloud-messaging/throttling-and-quotas, 2026-10-13):
  - 600k messages/minute per project.
  - "up to 240 messages per minute and 5,000 messages per hour to a single device".
  - Collapsible messages: "burst of 20 messages per app per device, with a refill of 1 message every 3
    minutes".
- **Standby buckets:** "starting in Android 13, the app's standby bucket no longer determines how many high
  priority FCMs an app can use" (https://developer.android.com/topic/performance/power/power-details,
  2026-05-19).

### 4.5 Doze and App Standby
- Doze "Suspends network access", ignores wake locks, defers alarms (including `setExact`), and "Doesn't let
  JobScheduler run ... WorkManager tasks don't run" until a maintenance window.
- "If your users must see a notification right away, use an FCM high priority message. Only use high priority
  for messages that result in a notification"
  (https://developer.android.com/training/monitoring-device-state/doze-standby, 2026-08-18).
- Bucket limits (approximate; power-details page):

  | Bucket | Regular jobs | Expedited jobs | Alarms | Network |
  |---|---|---|---|---|
  | Active | 20 min / rolling 60 min (since Android 16) | 30 min / 24 h | — | — |
  | Working set | 10 min / 4 h | 15 min / 24 h | 10 per hour | — |
  | Frequent | 10 min / 12 h | 10 min / 24 h | 2 per hour | — |
  | Rare | 10 min / 24 h | 10 min / 24 h | 1 per hour | network "Disabled" |
  | Restricted | once per day | 5 min / 24 h | one alarm per day | network "Disabled" |

  - Consequence: widget refresh for people who rarely open the app relies on high-priority FCM plus a visible
    notification.

### 4.6 Ongoing countdown notification (`daily.ongoing`) and Live Updates
- Countdown: `setUsesChronometer(true)` ("Show the Notification.when field as a stopwatch"),
  `setChronometerCountDown(true)` (API 24), and `setTimeoutAfter(durationMs)` (API 26) to cancel at window
  close (https://developer.android.com/reference/android/app/Notification.Builder).
- **Android 16 Live Updates** (https://developer.android.com/develop/ui/views/notifications/live-update, 2026-10-07):
  - Promoted notifications show at the top of the shade, on the lock screen, and as a status-bar chip.
  - Requirements: Standard, BigText, Call, Progress or Metric style; `POST_PROMOTED_NOTIFICATIONS`;
    `setRequestPromotedOngoing` ("Added in version 36.1"); ongoing; title set; no `RemoteViews`; not
    colorized; channel not `IMPORTANCE_MIN`.
  - The person can disable promotion: check `NotificationManager.canPostPromotedNotifications()`.
  - "OEMs can enforce additional criteria".
  - **Usage criteria:** "Most Live Updates should represent activities that are explicitly triggered by the
    user ... Don't allow activities triggered by other parties to generate Live Updates"; inappropriate uses
    include "alerts, upcoming calendar events"; "Don't repost Live Updates that the user dismissed".
  - **Verdict:** the server-scheduled daily invitation should be a normal, non-promoted chronometer
    notification. Promote it only if the person explicitly opts in to following the window ("you can begin
    posting Live Updates ... include an Unpin action").
- `Notification.ProgressStyle` is API 36, for progress-centric journeys
  (https://developer.android.com/reference/android/app/Notification.ProgressStyle). It is not needed for a
  countdown.
- Channels: importance is immutable after creation. Names should be ≤40 characters and descriptions ≤300
  (https://developer.android.com/develop/ui/views/notifications/channels ;
  https://developer.android.com/reference/android/app/NotificationChannel).
  POST_NOTIFICATIONS is required on Android 13+
  (https://developer.android.com/develop/ui/views/notifications/notification-permission).

### 4.7 Foreground services and exact alarms
- Camera FGS (`FOREGROUND_SERVICE_TYPE_CAMERA`) needs the CAMERA permission, and "you cannot create a camera
  foreground service while your app is in the background"
  (https://developer.android.com/develop/background-work/services/fgs/service-types, 2026-10-01). It is
  **not needed**, because capture happens only in the foreground activity. Run uploads after capture with
  WorkManager.
- `SCHEDULE_EXACT_ALARM` "is no longer being pre-granted to most newly installed apps targeting Android 13
  and higher"; `USE_EXACT_ALARM` is for alarm-clock and calendar apps
  (https://developer.android.com/about/versions/14/changes/schedule-exact-alarms). It is **not needed**:
  - the invitation is server-triggered by high-priority FCM with a visible notification;
  - the countdown and auto-removal use the chronometer and `setTimeoutAfter`.

---

## 5. Dual camera

- **iOS:** `AVCaptureMultiCamSession` (iOS 13+) captures "simultaneous ... from multiple inputs of the same
  media type". Check the class property `isMultiCamSupported`
  (https://developer.apple.com/documentation/avfoundation/avcapturemulticamsession).
  - Apple's sample requires "An iPhone with an A12 or later processor" or "An iPad Pro with an A12X or later
    processor" (https://developer.apple.com/documentation/avfoundation/avmulticampip-capturing-from-multiple-cameras).
  - `hardwareCost` (0–1): "When the value is greater than 1.0, the capture session cannot run your
    configuration".
  - `systemPressureCost` > 1.0: "cannot run sustainably". Reduce frame rate or GPU use. At a critical level
    the session is interrupted.
  - The preset "is always inputPriority". Pick each device's `activeFormat`; multicam-capable formats have
    `AVCaptureDevice.Format.isMultiCamSupported`.
  - Single-camera apps should use `AVCaptureSession`.
- **Live Photo in multicam: UNCONFIRMED.** "Not all devices and capture formats support Live Photo capture.
  This property's value can change if the sessionPreset ... or the activeFormat ... changes"
  (https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/islivephotocapturesupported).
  Check at runtime.
- **Android CameraX:** `ConcurrentCamera` (camera-core 1.3.0+).
  - "Before binding ... check FEATURE_CAMERA_CONCURRENT".
  - "CameraX currently only supports dual concurrent camera ... with at most two UseCases bound for each. The
    max resolution is 720p or 1440p".
  - Composition mode exists for picture-in-picture
    (https://developer.android.com/reference/androidx/camera/core/ConcurrentCamera).
  - `PackageManager.FEATURE_CAMERA_CONCURRENT` (API 30) means "The device's main front and back cameras can
    stream concurrently" (https://developer.android.com/reference/android/content/pm/PackageManager).
  - Bind via `ProcessCameraProvider.bindToLifecycle(List<SingleCameraConfig>)`, which only accepts
    combinations from `availableConcurrentCameraInfos`. Otherwise it throws `IllegalArgumentException`
    (https://developer.android.com/reference/androidx/camera/lifecycle/ProcessCameraProvider).
- **Fallback (both platforms):** sequential capture. Take the back photo, switch cameras on the same session,
  then take the front photo. Use it whenever the multi-camera checks fail, cost is >1.0, or pressure is
  critical.

## 6. Live Photos, photo library, Android picker

- **Capture:**
  - Enable Live Photo on `AVCapturePhotoOutput` and set `livePhotoMovieFileURL` per shot.
  - The still and the movie arrive separately.
  - Save both together with `PHAssetCreationRequest` (`addResource(.photo…)` + `addResource(.pairedVideo…)`).
  - Source: https://developer.apple.com/documentation/avfoundation/capturing-and-saving-live-photos.
- **Upload:**
  - `PHPickerViewController` provides "PHLivePhoto objects without library access"
    (https://developer.apple.com/documentation/photosui/phpickerviewcontroller).
  - `PHAssetResource.assetResources(for: PHLivePhoto)` lists its still and video resources. Export them with
    `PHAssetResourceManager`.
  - Source: https://developer.apple.com/documentation/photos/phassetresource.
- **Display a received Live Photo:** `PHLivePhoto.request(withResourceFileURLs:placeholderImage:targetSize:contentMode:resultHandler:)`.
  The URLs must be "only the still URL and the video URL that constitute a Live Photo"
  (https://developer.apple.com/documentation/photos/phlivephoto/request(withresourcefileurls:placeholderimage:targetsize:contentmode:resulthandler:)).
- **Limited library:** `PHAuthorizationStatus.limited` (iOS 14+).
  - Add `PHPhotoLibraryPreventAutomaticLimitedAccessAlert = YES` and call `presentLimitedLibraryPicker`
    yourself.
  - With limited access you "can't create or fetch user albums".
  - Use `authorizationStatus(for:)` / `requestAuthorization(for:)`. The older calls report `.authorized` for
    limited access.
  - Source: https://developer.apple.com/documentation/photos/phauthorizationstatus/limited ;
    https://developer.apple.com/documentation/photokit/delivering-an-enhanced-privacy-experience-in-your-photos-app.
  - **Recommendation:** the picker needs no permission. Saving needs `NSPhotoLibraryAddUsageDescription` only.
- **Android Photo Picker:** `PickVisualMedia` / `PickMultipleVisualMedia` need no permission and fall back to
  `ACTION_OPEN_DOCUMENT` (https://developer.android.com/training/data-storage/shared/photo-picker).
- **Google Play policy:** "Apps that target Android 13 or later ... may only request the READ_MEDIA_IMAGES
  and READ_MEDIA_VIDEO permissions if system pickers ... are not sufficient for your app to provide core
  functionality". The same page says READ_CONTACTS for apps targeting Android 17+ requires a declaration;
  "January 27, 2027: Policy compliance is mandatory"
  (https://support.google.com/googleplay/android-developer/answer/14115180).
  - `READ_MEDIA_VISUAL_USER_SELECTED` (Android 14 Selected Photos Access) is only needed with a custom
    gallery (https://developer.android.com/about/versions/14/changes/partial-photo-video-access).
    **Don't ship it.**

## 7. Phone auth (Supabase + Twilio Verify) and code autofill

- **Supabase:**
  - `supabase.auth.signInWithOtp({ phone })` then `verifyOtp({ phone, token, type: 'sms' })`.
  - "By default, a user can only request an OTP once every 60 seconds and they expire after 1 hour".
  - Use rate limits and CAPTCHA to control SMS cost
  - Source: https://supabase.com/docs/guides/auth/phone-login.
- **Twilio Verify** (same page, Twilio section):
  1. "Create a new verification service in the Twilio dashboard".
  2. "Switch Phone Provider to Twilio Verify".
  3. "Configure the Twilio Verify Service ID field".

  With Verify, "OTPs are generated by Twilio ... the OTP expiry duration and message content fields are not
  configurable via the Supabase dashboard"; "if your user makes another request within that period, they
  will receive the same token"; "Twilio Verify has a separate set of rate limits".
- **Local/self-hosted config keys** (https://supabase.com/docs/guides/local-development/cli/config):
  - `[auth.sms] enable_signup`
  - `[auth.sms.twilio_verify] enabled = true`, `account_sid`, `message_service_sid`,
    `auth_token = "env(SUPABASE_AUTH_SMS_TWILIO_AUTH_TOKEN)"`
  - `auth.rate_limit.sms_sent` (default 30 per hour)
  - `[auth.sms.test_otp]` for test numbers

  The docs label `message_service_sid` "Twilio Message Service SID" for both providers. For `twilio_verify`
  it carries the Verify Service SID (the dashboard field "Twilio Verify Service ID"). **That mapping is an
  inference; confirm it in a test project.**
- **iOS autofill:** `textContentType = .oneTimeCode` ("autocomplete security codes from single-factor SMS
  login flows"). "If you use a custom input view ... iOS can't display the necessary AutoFill UI"
  (https://developer.apple.com/documentation/security/enabling-password-autofill-on-a-text-input-view).
- **Android:** the **SMS Retriever API** needs the server message to include an "11-character hash string"
  and be "no longer than 140 bytes" (https://developers.google.com/identity/sms-retriever/verify).
  - Twilio Verify composes the message, so Supabase cannot insert the hash. Use the **SMS User Consent API**
    instead. It prompts once per message, for 5 minutes after start, if "The message contains a 4-10
    character alphanumeric string with at least one number"
    (https://developers.google.com/identity/sms-retriever/user-consent/request).
  - Supabase's "Send SMS hook" (https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook, not read in
    detail) would allow a custom message with the hash, at the cost of not using Verify.

## 8. Subscriptions: StoreKit 2 / Google Play Billing via RevenueCat

- **RevenueCat entitlements** "represent a level of access ... typically unlocked after a user purchases a
  product". "Most apps only have one entitlement". Attach App Store and Play products to it
  (https://www.revenuecat.com/docs/getting-started/entitlements).
- **RevenueCat webhooks** (https://www.revenuecat.com/docs/integrations/webhooks):
  - Set an authorization header. Return 200 within 60 s, or RevenueCat retries "up to 5 times" (5, 10, 20,
    40, 80 min).
  - Delivery is usually "within 5 to 60 seconds"; cancellations arrive "within 2hrs".
  - Delivery is "at least one", so de-duplicate.
  - Call `GET /subscribers` after any webhook.
- **App Store 3.1.2** [RG]:
  - Subscription period "at least seven days", "available across all of the user's devices".
  - 3.1.2(c): "clearly describe what the user will get for the price".
  - Do not "trick users into purchasing a subscription under false pretenses".
- **Required on the sign-up (paywall) screen** (https://developer.apple.com/design/human-interface-guidelines/apple-in-app-purchase, 2026-09-17 ;
  https://developer.apple.com/app-store/subscriptions/):
  - "The subscription name, duration, and the content or services provided during each subscription period".
  - "The billing amount, correctly localized". It must be "the most prominent pricing element"; per-month
    breakdowns go "in a subordinate position and size".
  - "A way for existing subscribers to sign in or restore purchases".
  - "links to your Terms of Service and Privacy Policy" in the app and in metadata. The App Store page names
    them "Terms of Use and Privacy Policy".
  - For a free trial, "how long the free trial lasts and the price billed once the free trial is over". HIG:
    "make sure people know that when the free trial is over, a payment will be automatically initiated".
  - HIG: "Include a sign-up opportunity in your app's settings".
- **Google Play** (https://support.google.com/googleplay/android-developer/answer/9900533):
  - "clearly and explicitly disclosing your offer terms, the cost of your subscription, the frequency of your
    billing cycle, the automatic renewal terms, whether a subscription is required to use the app".
  - Violations include a missing or unclear dismiss button, monthly-breakdown-first pricing, and unlocalized
    currency.
  - Account settings must link to the Play Subscription Center or a cancellation flow.
- **Free trials (owner decision 7: one week on the annual plan, both stores).**
  - Play: a trial is an offer on an auto-renewing base plan; "Free trial: Provides a set number of days, weeks, or months
    at no charge", "Free trial phases can range from 3 days to 3 years"; eligibility "New customer acquisition" (never had
    this subscription / any subscription in the app) is evaluated by Google
    (https://support.google.com/googleplay/android-developer/answer/12154973). `queryProductDetailsAsync()` returns "a
    maximum of 50 user eligible offers per subscription" (https://developer.android.com/google/play/billing/integrate);
    each offer's `PricingPhase` has `getBillingPeriod()` ("P1W equates to one week") and `getPriceAmountMicros()`
    (https://developer.android.com/reference/com/android/billingclient/api/ProductDetails.PricingPhase). The app reads the
    zero-priced phase of the offer RevenueCat buys (`StoreProduct.defaultOption`, "longest free trial"; RevenueCat:
    ineligible offers do "not show up in the `subscriptionOptions`",
    https://www.revenuecat.com/docs/subscription-guidance/subscription-offers/google-play-offers).
  - App Store: an introductory offer of type free trial on `premium_yearly`; one per subscription group per person.
    RevenueCat `checkTrialOrIntroDiscountEligibility(product:)`: "The best course of action on unknown status is to
    display the non-intro pricing" (purchases-ios 5.95.0 `PurchasesType.swift`); the app shows the trial only when eligible.
  - Disclosure (both): the trial length is on the capsule ("Try 1 week free"), the price after it on the card ("And then
    billed {price} yearly after") and in the billing line under the cards (design/surfaces/paywall.md).
- **Tenet check:** "at most one prompt per session" (SURFACES `paywall`) is stricter than any store rule, so
  it is compatible.

## 9. Age rating, minimum age, COPPA, privacy label, account deletion

- **App Store age ratings** (https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/):
  - The new system is 4+, 9+, 13+, 16+, 18+ on iOS 26-era devices. Answers to the updated questions were due
    January 31, 2026 (https://developer.apple.com/news/upcoming-requirements/).
  - "User-generated content" and "Messaging and chat" appear among the **4+** capability descriptors.
  - **13+** lists "Social media" (feeds that "visibly spread content to many users" with "views, likes,
    comments, and shares") and "Social media disabled for users under 13" ("the Declared Age Range API is
    called ... before enabling social media features").
  - Private groups of ≤30 without a public feed or likes may not meet the "Social media" definition. The
    rating comes from the questionnaire. **The product's own 13+ minimum is a separate policy** that the app
    enforces.
  - Guideline 2.3.6: "Answer the age rating questions ... honestly" [RG].
- **Age assurance laws:**
  - **Texas SB 2420** applies to new Texas Apple Accounts from **June 4, 2026**: "age assurance and parent or
    guardian consent on behalf of minors under the age of 18 for downloads, Apple In-App Purchases, and
    significant changes" (https://developer.apple.com/news/?id=sg176nne).
  - Apple's tools: Declared Age Range API (iOS 26+, entitlement `com.apple.developer.declared-age-range`), the
    PermissionKit Significant Change API, StoreKit `ageRatingCode`, and the `RESCIND_CONSENT` server
    notification (https://developer.apple.com/documentation/declaredagerange ; https://developer.apple.com/support/age-assurance/).
  - Google: "Texas' App Store Accountability Act ... is now in effect". Use the Play Age Signals API (beta).
    "Google Play doesn't mandate the use of these features", but developers are responsible for compliance
    (https://support.google.com/googleplay/android-developer/answer/16569691).
  - **Counsel to confirm** Utah and Louisiana dates.
- **COPPA (FTC FAQ)** (https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions):
  - General-audience services are covered "only where such operators have actual knowledge that a child
    under age 13 is the person providing personal information".
  - A neutral age screen "allows a user freely to enter month and year of birth". Do not use a 13+-only
    dropdown or default.
  - Once a child is identified, "the operator must either meet COPPA's notice and parental consent
    requirements or delete the child's information".
  - "The COPPA Rule was amended on April 22, 2025".
  - Apple 5.1.4: apps that "collect ... personal information (e.g. name, ... photos, videos, ... the ability to
    chat ...) from a minor must include a privacy policy and must comply with all applicable children's
    privacy statutes". Do not use "For Kids" or "For Children" in metadata (2.3.8) [RG].
  - **Recommendation for `auth.agegate`:**
    - Use a neutral free-entry birthday field.
    - Under 13 → block sign-up and delete the entered data.
    - On iOS 26 also call Declared Age Range, and where required by law respect the returned age category and
      the significant-change flow. On Android use Play Age Signals.
- **UGC requirements (1.2)** [RG]: a filtering method, reporting with "timely responses", blocking, and
  "Published contact information".
- **App privacy label (nutrition label)** categories this app will likely declare
  (https://developer.apple.com/app-store/app-privacy-details/). This is a draft from the feature list. The
  backend's actual data inventory decides the final list.

  | Category > type | Why | Purpose | Linked |
  |---|---|---|---|
  | Contact Info > Phone Number | phone OTP account | App Functionality | yes |
  | Contact Info > Name | profile name | App Functionality | yes |
  | User Content > Photos or Videos | posts, avatar | App Functionality | yes |
  | User Content > Audio Data | voice notes / video sound | App Functionality | yes |
  | User Content > Emails or Text Messages ("contents of the ... message") | group chat | App Functionality | yes |
  | User Content > Other User Content | captions, reactions | App Functionality | yes |
  | User Content > Customer Support | reports, support requests | App Functionality | yes |
  | Contacts > Contacts | only if contacts are uploaded or matched | App Functionality | yes |
  | Identifiers > User ID | account id (and RevenueCat app user id) | App Functionality | yes |
  | Purchases > Purchase History | subscription | App Functionality | yes |
  | Diagnostics > Crash Data / Performance Data | if a crash SDK is used | App Functionality | per SDK |
  | Usage Data > Product Interaction | only if analytics are collected | Analytics | per SDK |
  | Other Data > Other Data Types | birthday (no specific type exists) | App Functionality | yes |

  - Tracking: none (no ads), so no ATT prompt.
  - Google Play's Data safety form, including the data-deletion questions, mirrors this.
- **Account deletion:**
  - 5.1.1(v): "If your app supports account creation, you must also offer account deletion within the app"
    [RG].
  - Apple FAQ (https://developer.apple.com/support/offering-account-deletion-in-your-app/):
    - "easy to find"; deactivation "is insufficient"; confirmation and re-authentication steps are allowed.
    - Manual processes may take time, but tell the person how long.
    - "**This includes user-generated content that's shared with others, such as photos**". This conflicts
      with the tenet "Nothing gets lost" and needs an **owner decision**.
    - For auto-renewing subscribers, say billing continues until cancelled, and link `showManageSubscriptions`.
  - Google Play: provide "an in-app path to delete their app accounts and associated data" **and** "a web link
    resource" (https://support.google.com/googleplay/android-developer/answer/13327111).
- **Push notifications (4.5.4):** they "must not be required for the app to function". Promotional pushes
  need explicit opt-in [RG].

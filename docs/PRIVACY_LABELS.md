# Privacy labels: App Store "App Privacy" and Google Play "Data safety"

The answers to paste into App Store Connect → your app → **App Privacy** (OWNER_SETUP.md §1.7) and Play Console →
**App content → Data safety** (OWNER_SETUP.md §2.4), derived from what the code sends off the phone and keeps. Each
answer names the code that does it. The iPhone app carries the same answers in its privacy manifests
(`ios/App/PrivacyInfo.xcprivacy`, `ios/AppClip/PrivacyInfo.xcprivacy`; the widget, notification and share extensions
collect nothing: `ios/Widgets/PrivacyInfo.xcprivacy`, `ios/NotificationService/PrivacyInfo.xcprivacy`,
`ios/ShareExtension/PrivacyInfo.xcprivacy` — the share extension only copies the shared photos into the App Group container
for the app, share.in). A library or shared photo's upload carries the day it was taken (`media.taken_on`, the date only —
never a time or a place; migration 0050): part of the photo's own data, not a new type.

Definitions used (read 2026-10-17):

- Apple, https://developer.apple.com/app-store/app-privacy-details/ — "'Collect' refers to transmitting data off the
  device in a way that allows you and/or your third-party partners to access it for a period longer than what is
  necessary to service the transmitted request in real time." "Data that is processed only on device is not
  'collected'." Data collected by code you add (SDKs) counts as yours.
- Google, https://support.google.com/googleplay/android-developer/answer/10787469 — data sent to a **service provider**
  that processes it on your behalf is **not "shared"**; only transfers to other third parties are.

Who processes the data on the owner's behalf (service providers, not sharing): **Supabase** (database, sign-in, photo
storage), **Twilio Verify** (sends the sign-in code to the phone number), **Fly.io** (runs the worker and the invite page),
**RevenueCat** (subscriptions), **Apple Push Notification service / Firebase Cloud Messaging** (deliver notifications),
**Anthropic** (only when `ANTHROPIC_API_KEY` is set: the week's captions and capture times, no photos, no names, to order a
recap and draft its text — `backend/worker/src/recap/ai.ts`). Nothing is sold, nothing is used for advertising, and
nothing is linked with other companies' data: **no tracking** (`NSPrivacyTracking` false, no tracking domains, no
advertising identifier is read anywhere in `ios/` or `android/`).

## Apple — App Store Connect → App Privacy

**Do you or your third-party partners collect data from this app?** Yes.

Every type below is **linked to the user** (it is stored with the account) and **not used for tracking**. Purpose:
**App Functionality** for all of them; Purchase History also **Analytics** (RevenueCat's own instructions: "All
RevenueCat users must select these two options",
https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy).

| App Store data type | What it is in Jolt | Code |
|---|---|---|
| Contact Info → **Phone Number** | the number you sign in with (Supabase Auth; Twilio Verify texts the code) | `ios/Packages/AppCore/Sources/AppData/Auth/AuthService.swift` `signInWithOTP` / `verifyOTP`; Android `core/data` `AuthRepository` |
| Contact Info → **Name** | your display name, shown to the members of your groups | `profiles.display_name` (`backend/supabase/migrations/20261015000002_tables.sql`); auth.profile, settings.account |
| User Content → **Photos or Videos** | what you post (photos, Live Photos, videos), your profile photo, group covers, selfie reactions, tribute contributions | `media` table + the private `media` storage bucket (`20261015000010_storage.sql`); `AppData/Media/MediaUploader.swift`, `PostPublisher.swift` |
| User Content → **Audio Data** | voice notes on posts and in chat, the sound of videos | `media.kind = 'voice'` (`20261015000017_voice_levels.sql`); `AppServices/Voice.swift` |
| User Content → **Other User Content** | chat messages, captions, emoji reactions, plans (title, date, typed place, note) and answers, weekly-question answers, album names, birthday-request lines, reports | `messages`, `posts.caption`, `reactions`, `plans`, `plan_answers`, `albums`, `tribute_contributions`, `reports` (`backend/supabase/migrations/`) |
| Identifiers → **User ID** | your account id (Supabase), also RevenueCat's app user id | `auth.users.id`; `AppServices/PurchasesService.swift` `logIn(userID:)` |
| Identifiers → **Device ID** | the phone's notification tokens (APNs device token, Live Activity push-to-start token), kept to send notifications | `devices` table (`register_device`, `20261015000007_rpc_account.sql`); `AppData/Glue/SessionCoordinator.swift` |
| Purchases → **Purchase History** | whether and what you subscribed to (RevenueCat SDK; the server keeps the entitlement) | `AppServices/PurchasesService.swift`; `entitlements` table, `backend/worker/src/revenuecat.ts` |
| Other Data → **Other Data Types** | your birthday, only if you add it (for birthday tributes) | `profile_private.birthday` (`20261015000002_tables.sql`); birthday.add |

Not collected (answer "No" / leave unticked):

- **Contacts**: read on the phone only, to pick whom to text an invite link; the text goes out through the phone's own
  Messages composer. No contact, number or hash is sent (`AppServices/ContactsService.swift`; `ContactMatcher` in
  `AppModels/ContactMatching.swift` has no server counterpart and is not called).
- **Location**: none is read (no Core Location / location permission). A plan's place is typed text (Other User Content).
- **Date of birth at the age gate**: checked by `confirm_age` and not stored — only the time of the confirmation is kept
  (`profile_private.age_confirmed_at`, `20261015000007_rpc_account.sql`).
- **Crash Data, Performance Data, Usage Data, Diagnostics**: no analytics or crash-reporting SDK in either app (App Store
  crash reports come from Apple: "You are not responsible for disclosing data collected by Apple").
- **Search History, Browsing History, Email Address, Payment Info** (Apple and Google take the payment), **Health,
  Financial Info, Sensitive Info, Customer Support** ("Contact Us" opens your own mail app).
- Server logs (Supabase, Fly.io) record IP addresses for operating the service and expire on the hosts' schedules; they
  are not used for anything else.

**App Clip.** The App Clip shows the invite, signs in by phone, asks the name and joins: Phone Number, Name and User ID,
same answers (App Store Connect asks once for the app; the clip's manifest lists its three types).

## Google Play — Data safety form

**Does your app collect or share any of the required user data types?** Yes. **Is all of the user data collected by
your app encrypted in transit?** Yes (every request is HTTPS: Supabase, the worker, RevenueCat, Firebase). **Do you
provide a way for users to request that their data is deleted?** Yes — in the app (Profile → Settings → Edit Profile →
Delete Account, `delete_account()`) and on the web at `https://<domain>/delete-account` (web/src, OWNER_SETUP.md §2.4).

Shared with third parties: **none** (every recipient above is a service provider). Processed ephemerally: **no**.

| Play data type | Collected | Required or optional | Purposes | Code |
|---|---|---|---|---|
| Personal info → **Name** | yes | required (sign-up) | App functionality, Account management | `profiles.display_name`; `feature/account` auth.profile |
| Personal info → **Phone number** | yes | required (sign-in) | App functionality, Account management | `core/data` `AuthRepository` (Supabase phone OTP) |
| Personal info → **User IDs** | yes | required | App functionality, Account management | Supabase user id; `core/billing` `Billing.identify(userId)` |
| Personal info → **Other info** (birthday) | yes | optional | App functionality | `profile_private.birthday` (birthday.add) |
| Financial info → **Purchase history** | yes | optional (only when subscribing) | App functionality, Analytics | RevenueCat SDK (`core/billing`), `entitlements` |
| Messages → **Other in-app messages** | yes | optional | App functionality | `messages` (group chat) |
| Photos and videos → **Photos**, **Videos** | yes | optional (you choose what to post) | App functionality | `media` + storage bucket; `core/data` uploads |
| Audio → **Voice or sound recordings** | yes | optional | App functionality | voice notes, video sound (`core/voice`) |
| App activity → **Other user-generated content** | yes | optional | App functionality | captions, reactions, plans, weekly answers, albums, reports |
| Device or other IDs | yes | required | App functionality | FCM registration token and Firebase installation ID (`core/push` `PushTokens`, `devices`) |

Not collected: Location, Contacts (read on the phone only, `feature/account` invite from contacts sends nothing),
Calendar, Files and docs, Web browsing, Health and fitness, App info and performance (no crash or analytics SDK),
Emails, SMS or MMS (the sign-in code is read on the phone with the user's consent through Google's SMS User Consent API,
`feature/account` `SmsUserConsent.kt`, and never sent), Installed apps, In-app search history.

## Account deletion (both stores)

`delete_account()` (`backend/supabase/migrations/20261015000007_rpc_account.sql`, extended by
`20261017000025_account_deletion_leftovers.sql`) deletes the person's photos, videos and voice notes everywhere (posts,
chat, collages, recaps, albums, tributes, widgets), messages, reactions, tags, plans, memberships, devices, settings,
blocks, reports, entitlement and profile; the worker then deletes the stored files, the sign-in account (`auth.users`)
and — with `REVENUECAT_SECRET_KEY` — the RevenueCat customer. Nothing is kept afterwards. The App Store and Google Play
keep their own purchase records (subscriptions are cancelled in the store's subscription settings).

## When the code changes

Adding an SDK, a new kind of upload, analytics or crash reporting changes these answers: update this file, both
`PrivacyInfo.xcprivacy` files and the two store forms together.

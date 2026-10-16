# Owner setup

Everything here needs your accounts, money, legal identity or a decision. Everything else is
built in the repo. Do the steps in order. Each step says what to send back (as a secret in the
deployment environment, never committed) or which file to edit.

Placeholders used below:

| Placeholder | Where it is set | Example |
|---|---|---|
| `APP_DISPLAY_NAME` | `config/app.json` → `displayName` | the name people see under the icon |
| `APP_BUNDLE_ID` | `config/app.json` → `ios.bundleId` | `com.yourcompany.yourapp` |
| `APP_ANDROID_ID` | `config/app.json` → `android.applicationId` | `com.yourcompany.yourapp` |
| `APP_DOMAIN` | `config/app.json` → `domain` | `yourapp.com` (invite links: `https://yourapp.com/i/<token>`) |
| `TEAM_ID` | `config/app.json` → `ios.teamId` | 10-character Apple Team ID |

---

## 0. Decisions only you can make

1. **App name** (`APP_DISPLAY_NAME`). Every string that names the app uses `{app_name}`; the app
   cannot ship until this is set (it is the one BLOCKED copy value by design).
2. **App icon.** The directive forbids us from inventing imagery; provide a 1024×1024 PNG
   (no transparency) at `config/AppIcon-1024.png`, or ask for one to be commissioned. When it is added to iOS as an
   `AppIcon.appiconset` in `ios/App/Resources/Assets.xcassets`, set `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` in
   `ios/project.yml` (App target → `settings.base`; it is `""` until then so the catalog of template covers builds without
   an icon set).
3. **Same-moment collage option** — pick one of the options in `design/collage-options/`.
4. **Premium price** — decided by the lead (docs/OWNER_DECISIONS.md #7): **$3.99/month, $35.99/year,
   with a 1-week free trial on the yearly plan** on both stores (`config/app.json` `premium`). The app
   always shows the store's localized prices, so you set the prices and the trial in App Store Connect
   (§1.6) and Play Console (§2.3); change them there (and in `config/app.json`) if you ever want to.
5. **Free history window** — decided (OWNER_DECISIONS #7, SPEC_FLAGS T1): **none**.
   `app_config.free_history_days` stays NULL (unlimited for everyone; tenet 4 "nothing gets lost"), and
   the paywall does not list a history perk.
6. **Display typeface (titles such as "Week 27", profile names, headlines).** The design follows
   Retro, whose display face is **Roslindale** by David Jonathan Ross (DJR) — a commercial font we
   may not copy from Retro's app. Choose one:
   - **License Roslindale** from DJR (https://djr.com/roslindale; terms https://djr.com/license):
     the retail styles **Roslindale Display Narrow** (headlines) and **Roslindale Deck Narrow**
     (smaller display text), with an **app-embedding licence for iOS and Android** (and a web licence
     if the invite page should match). Retro's own "Roslindale Retro v0.2" cut is custom and only DJR
     can offer it. Send back the licensed font files (`.otf` / `.ttf`) and the licence text; we bundle
     them and set `font.global.display` / `font.global.displayNarrow` (design/tokens/global.json) to their
     names.
   - **Keep the free stand-ins** (already in place): two static instances of Roboto Serif (Google, SIL
     Open Font License) whose width, weight, x-height and ink were matched to Retro's two display cuts
     by measurement (design/MERGE_DECISIONS.md L-8) — "Roboto Serif Title" for screen titles and
     "Roboto Serif Headline" for headlines. Close to Retro's look; not Roslindale's letterforms.
   - Or name **another licensed display serif** you prefer (same steps as the first option).
   Until you decide, the Roboto Serif stand-ins ship (licences bundled next to the font files). If you license
   Roslindale, also set the display sizes back to Retro's (40 / 32 / 24; the stand-in sizes are re-fitted to
   Roboto Serif's smaller cap height). (The UI text face needs nothing from you: SF Pro is
   the iPhone's own font and Inter, used on Android, is free under the SIL Open Font License —
   bundled with its licence at `android/core/designsystem/licenses/Inter-OFL.txt`.)
7. **The faint date on empty days (one contrast exception).** Owner decision 20 raised every grey, red and blue
   text colour below WCAG AA to the nearest passing shade (design/CONTRAST.md). One text colour was kept: the date
   Retro prints as a faint watermark on a week-strip day with no photos (`color.global.emptyTileText`, 1.25:1 light /
   1.91:1 dark). Raised to 4.5:1 it would read like any other label and the strip would no longer show at a glance
   which days are empty; the tile's VoiceOver / TalkBack label already says the date. Keep it (nothing to do), or say
   "raise it" and it becomes #6E6E6E / #999999 like other secondary text.
8. **Resemblance to Retro.** The app follows Retro's look closely (colours, type sizes, spacing, layouts) without
   copying its name, logo, icons, illustrations or fonts. Decide whether you are comfortable with how close it is
   before submitting to the stores; a design pass can move it further away if you want.
9. **Values read from Retro's Android package.** Decision 22 stopped using Locket values read from Locket's decompiled
   app and re-sourced them from public screenshots and documentation. Retro's Android package (APK) was read the same
   way in the research passes and is still evidence for **108 design tokens (52 of them rely on it alone — Android
   colours, Android type metrics, widget and dialog layouts) and 632 copy strings** (Retro's wording, which our copy
   adapts). Nothing from it is copied into the app as code or assets; it was used to read colour values, sizes and
   wording. Decide: **keep it** (nothing to do), or **re-source it**, which needs the capture session on a phone with
   Retro installed (`docs/CAPTURE_GUIDE.md` if present, or ask) and a copy rewrite from public material only.
10. **Repository visibility.** The repository is public. Screenshots, videos and the decompiled-package excerpts were
    never committed (git-ignored from the start; checked over the whole history on 2026-10-16). What is public: the
    research notes and measurements (Markdown, CSV), excerpts of two public web pages (retro.app's stylesheet, a
    Partiful page script) and Retro's wording quoted in `design/copy/*.json` evidence. If you would rather none of that
    be public, make the repository private (removing it from history as well needs a rewrite such as
    `git filter-repo` and a force-push, which breaks existing clones).

## 1. Apple

1. **Apple Developer Program** membership (organization account recommended, needs a D-U-N-S
   number): https://developer.apple.com/programs/enroll/ — note your **Team ID** (Membership page)
   → `config/app.json` `ios.teamId`.
2. **Identifiers** (Certificates, Identifiers & Profiles → Identifiers → +):
   - App ID `APP_BUNDLE_ID` with capabilities: **App Groups**, **Push Notifications**,
     **Associated Domains**. (No Time Sensitive Notifications: the daily invitation is an
     ordinary `active` alert — tenet 5, see design/surfaces/daily.notification.md.)
   - App ID `APP_BUNDLE_ID.widgets` (widget + Live Activity extension) with **App Groups**,
     **Push Notifications**.
   - App ID `APP_BUNDLE_ID.notificationservice` with **App Groups**.
   - App ID `APP_BUNDLE_ID.Clip` (App Clip) with **App Groups**, **Associated Domains**,
     **Push Notifications** (ephemeral).
   - App Group `group.APP_BUNDLE_ID` and assign it to all four IDs.
3. **APNs key**: Keys → + → enable "Apple Push Notifications service (APNs)" → download the
   `.p8` once. Send back as worker secrets: `APNS_KEY_P8` (file contents), `APNS_KEY_ID`,
   `APNS_TEAM_ID`, `APNS_BUNDLE_ID` = `APP_BUNDLE_ID`, `APNS_ENV` = `sandbox` for TestFlight
   development builds / `production` for App Store and TestFlight external builds.
4. **App Store Connect app**: https://appstoreconnect.apple.com → My Apps → + → New App,
   platform iOS, bundle ID `APP_BUNDLE_ID`, SKU of your choice.
5. **App Clip**: after the first build with the App Clip is uploaded, App Store Connect →
   your app → App Clip → set up the **Default App Clip Experience** (header image 1800×1200,
   subtitle, action "Open") and an **Advanced App Clip Experience** for the URL prefix
   `https://APP_DOMAIN/i/`. Header image and subtitle are owner-provided marketing assets.
6. **In-app purchases** (App Store Connect → your app → Subscriptions): create a subscription
   group "Premium" with two auto-renewable products: `premium_monthly` (1 month, **$3.99**) and
   `premium_yearly` (1 year, **$35.99**) — Subscription Prices → set the US price, let App Store
   Connect fill the other storefronts. Add the localized display names from `design/copy/account.json`
   (`paywall.*`).
   - **Free trial on the yearly plan:** `premium_yearly` → Subscription Prices → View all Subscription
     pricing → **Set up Introductory Offer** → select all countries or regions → start date today, no end
     date → **Free**, duration **1 Week** → Confirm
     (https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions:
     "each person is only eligible to redeem one introductory offer per subscription group"); the app shows
     "Try 1 week free" only to people StoreKit still offers it to. `premium_monthly` gets no offer.
   - Then create an **App Store Connect API key** (Users and Access → Integrations → In-App Purchase)
     and give it to RevenueCat (step 6).
7. **Privacy nutrition labels** (App Store Connect → App Privacy): fill from
   `docs/PRIVACY_LABELS.md` (generated from what the code actually collects).
8. **Age rating** questionnaire: answer per `docs/PLATFORM_CONSTRAINTS.md` §9.
9. **TestFlight**: after `ios` CI uploads a build (step 10), add internal testers in App Store
   Connect → TestFlight → Internal Testing.

## 2. Google

1. **Google Play Console** developer account ($25 one-time): https://play.google.com/console/signup
2. Create the app with package `APP_ANDROID_ID`. Enroll in **Play App Signing**. Copy the
   **app signing key SHA-256 fingerprint** (Setup → App signing) → `config/app.json`
   `android.sha256CertFingerprints` (used by `assetlinks.json`). Also add your upload key's
   fingerprint for internal builds.
3. **Subscriptions** (Monetize with Play → Products → Subscriptions): `premium_monthly` with an
   auto-renewing base plan (billing period 1 month, **$3.99**) and `premium_yearly` with an
   auto-renewing base plan (1 year, **$35.99**); activate both base plans.
   - **Free trial on the yearly plan:** `premium_yearly` → its base plan → **Add offer** → eligibility
     **New customer acquisition** ("Never had this subscription") → phase **Free trial**, duration
     **1 week** → activate
     (https://support.google.com/googleplay/android-developer/answer/12154973: "Free trial phases can range
     from 3 days to 3 years"). Do not tag it `rc-ignore-offer`: RevenueCat buys the eligible offer with the
     longest free trial by default, and the app reads that offer's free phase for "Try 1 week free"
     (`android/core/billing`). `premium_monthly` gets no offer.
   - Create a **service account** with Play Console access for RevenueCat (RevenueCat's guide:
     https://www.revenuecat.com/docs/service-credentials/creating-play-service-credentials).
4. **Data safety form**: fill from `docs/PRIVACY_LABELS.md`.
5. **Internal testing** track: upload the AAB from CI (step 10), add testers by email.

## 3. Firebase (Android push)

1. https://console.firebase.google.com → Add project → add an Android app with package
   `APP_ANDROID_ID` → download `google-services.json` → place at
   `android/app/google-services.json` (git-ignored; CI reads it from the secret
   `ANDROID_GOOGLE_SERVICES_JSON`, base64).
2. Project settings → Service accounts → Generate new private key → worker secret
   `FCM_SERVICE_ACCOUNT_JSON`.

## 4. Domain and links

1. Buy `APP_DOMAIN` and point it at the web service (step 7). HTTPS is required.
2. The web service serves `/.well-known/apple-app-site-association` (generated from
   `config/app.json`: `TEAM_ID.APP_BUNDLE_ID` and the App Clip ID for `/i/*`) and
   `/.well-known/assetlinks.json` (from the SHA-256 fingerprints). Nothing to hand-edit.
3. Verify after deploy: `curl https://APP_DOMAIN/.well-known/apple-app-site-association` and
   Google's Statement List tester.

## 5. Backend (Supabase)

1. Create a project at https://supabase.com/dashboard (region close to your users; Pro plan
   recommended for daily backups and no pausing).
2. Install the CLI locally (`npx supabase`) and run from `backend/`:
   `npx supabase link --project-ref <ref>` then `npx supabase db push` (applies all migrations,
   including the storage bucket and RLS policies).
3. Send back as worker/web secrets: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`; and the
   **anon key** (public, goes into `config/app.json` → `supabase.anonKey` with the URL).
4. Auth → Providers → Phone: enable, choose **Twilio Verify**, paste the Twilio values from
   step 6.1. Auth → Settings: disable email sign-ups.
5. Storage: the `media` bucket is created by migrations — nothing to do. Check its size limits
   (Storage → Settings → upload size limit ≥ 100 MB for premium video).

## 6. Third-party services

1. **SMS — Twilio Verify**: https://www.twilio.com/console/verify/services → create a Verify
   Service → note Account SID, Auth Token, Verify Service SID → enter them in Supabase (5.4).
   For US numbers, Twilio requires toll-free/10DLC registration only for non-Verify SMS; Verify
   is exempt, but check Twilio's current guidance for your countries.
2. **RevenueCat**: https://app.revenuecat.com → new project → add the App Store app (bundle ID,
   App Store Connect API key from 1.6) and the Play Store app (package, service account from
   2.3) → create entitlement `premium` attached to both products on both stores → Offerings:
   default offering with `$rc_monthly` and `$rc_annual` packages → copy the **public SDK keys**
   (iOS and Android) into `config/app.json` → `revenuecat.iosApiKey` / `androidApiKey` →
   Integrations → Webhooks → URL `https://<worker-host>/webhooks/revenuecat` with an
   authorization header value → worker secret `REVENUECAT_WEBHOOK_AUTH`.
3. **Anthropic API key** (recaps only): https://console.anthropic.com → API keys → worker secret
   `ANTHROPIC_API_KEY`. Optional `RECAP_MODEL` (default `claude-opus-5-5`). Without a key,
   recaps still assemble (deterministic order, template text from `design/copy.json`).

## 7. Hosting the worker and web service

Both are Docker images built by CI (`backend/worker/Dockerfile`, `web/Dockerfile`). Any
container host works (Fly.io, Render, Railway, Cloud Run). Worker: 1 instance, 1 vCPU / 1 GB
RAM minimum (ffmpeg), always on (it runs the scheduler). Web: smallest instance. Set the secrets
listed above as environment variables; `docs/DEPLOY.md` has a one-page checklist.

## 8. Legal

1. **Privacy policy** and **terms of service** at `https://APP_DOMAIN/privacy` and `/terms`.
   We cannot write legal documents for you; have a lawyer or a reputable generator produce them.
   They must cover: phone numbers, photos/videos/voice, contacts (optional, hashed matching),
   push tokens, birthdays, subscriptions, AI processing of group photos for recaps (Anthropic as
   a processor), deletion. Put the URLs in `config/app.json` → `legal`.
2. Age requirement decision: see `docs/PLATFORM_CONSTRAINTS.md` §9 and set
   `app_config.min_age_years` (the age gate fails closed until it is set).

## 9. Optional: design-reference site logins

Mobbin (https://mobbin.com), Page Flows, Refero and Screenlane keep most flows behind paid
logins. Not required: research used free sources. If you have an account, share a session for
the researcher to capture the flows listed under "approximated" in the session report.

## 10. CI secrets (GitHub → repo → Settings → Secrets and variables → Actions)

| Secret | For |
|---|---|
| `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` | iOS signing via App Store Connect API key and TestFlight upload ("send Jolt to TestFlight"). The key: App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys → **+**, access **Admin** (automatic signing needs it); `ASC_KEY_P8` is the whole text of the downloaded `.p8` file |
| `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD` | "set up the server": applies the migrations and the sign-in settings to the project named by `config/app.json` `supabase.url` |
| `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SERVICE_SID` | "set up the server" also switches on phone sign-in through Twilio Verify (step 6.1) |
| `ANDROID_UPLOAD_KEYSTORE_B64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | Android release signing |
| `ANDROID_GOOGLE_SERVICES_JSON` | Firebase config (base64) |
| `PLAY_SERVICE_ACCOUNT_JSON` | Upload to Play internal testing |

Without these, CI still builds and tests unsigned debug builds on every push.

### One-button release (GitHub → Actions → the workflow → **Run workflow**)

1. **set up the server** (`.github/workflows/setup-server.yml`): once the Supabase project exists, its URL and anon key
   are in `config/app.json` and the Supabase secrets above are set. Applies every migration and switches on phone
   sign-in (with the Twilio secrets) with email sign-up off. Safe to run again.
2. **send Jolt to TestFlight** (`.github/workflows/testflight.yml`): once the Apple secrets are set and the app exists
   in App Store Connect (My Apps → + → New App) with bundle ID `com.husamisverycool.jolt` — or another one, given as the
   workflow's input or the repository variable `IOS_BUNDLE_ID`. Builds Release, signs it automatically and uploads it;
   the build shows under TestFlight once Apple has processed it. Each run is a new build number.

Both stop at the start, naming each missing step, when something is not set up yet (`tools/release/check_setup.py`).

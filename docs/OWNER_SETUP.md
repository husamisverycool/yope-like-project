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
   (no transparency) at `config/AppIcon-1024.png`, or ask for one to be commissioned.
3. **Same-moment collage option** — pick one of the options in `design/collage-options/`.
4. **Premium price** — default in `config/app.json`: $3.99/month, $35.99/year. Change if you want.
5. **Free history window** — see "Open decisions" in the final session report: the spec asks for
   "unlimited history beyond the free window" as a premium perk, which pulls against tenet 4
   ("nothing gets lost"). Our implementation never deletes anything; the window (if you set one)
   only limits browsing old weeks for free users. `app_config.free_history_days` = NULL means
   unlimited for everyone.
6. **Display typeface (titles such as "Week 27", profile names, headlines).** The design follows
   Retro, whose display face is **Roslindale** by David Jonathan Ross (DJR) — a commercial font we
   may not copy from Retro's app. Choose one:
   - **License Roslindale** from DJR (https://djr.com/roslindale; terms https://djr.com/license):
     the retail styles **Roslindale Display Narrow** (headlines) and **Roslindale Deck Narrow**
     (smaller display text), with an **app-embedding licence for iOS and Android** (and a web licence
     if the invite page should match). Retro's own "Roslindale Retro v0.2" cut is custom and only DJR
     can offer it. Send back the licensed font files (`.otf` / `.ttf`) and the licence text; we bundle
     them and set `font.global.display` (design/tokens/global.json) to their names — every display
     size is already Retro's.
   - **Keep the platform serif** (New York on iOS, Noto Serif on Android — free, already in place).
     The titles keep Retro's sizes but look like the system serif, not Retro's face.
   - Or name **another licensed display serif** you prefer (same steps as the first option).
   Until you decide, the platform serif ships. (The UI text face needs nothing from you: SF Pro is
   the iPhone's own font and Inter, used on Android, is free under the SIL Open Font License —
   bundled with its licence at `android/core/designsystem/licenses/Inter-OFL.txt`.)

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
   group "Premium" with two auto-renewable products: `premium_monthly` and `premium_yearly`,
   prices per decision 0.4. Add the localized display names from `design/copy.json`
   (`paywall.*`). Then create an **App Store Connect API key** (Users and Access → Integrations →
   In-App Purchase) and give it to RevenueCat (step 6).
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
3. **Subscriptions** (Monetize → Subscriptions): `premium_monthly`, `premium_yearly` with base
   plans matching the iOS prices. Create a **service account** with Play Console access for
   RevenueCat (RevenueCat's guide: https://www.revenuecat.com/docs/service-credentials/creating-play-service-credentials).
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
| `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` | iOS signing via App Store Connect API key and TestFlight upload |
| `ANDROID_UPLOAD_KEYSTORE_B64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | Android release signing |
| `ANDROID_GOOGLE_SERVICES_JSON` | Firebase config (base64) |
| `PLAY_SERVICE_ACCOUNT_JSON` | Upload to Play internal testing |

Without these, CI still builds and tests unsigned debug builds on every push.

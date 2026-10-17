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
2. **App icon** — made by the lead (docs/OWNER_DECISIONS.md #32): the title serif's "J" in white on black, on iOS
   (app and App Clip), Android (adaptive, themed and status-bar icons) and the Play listing (`design/icon/play-icon-512.png`).
   Options B (black on white) and C (white on the premium purple) are in `design/icon/options.png`: switch with
   `python3 tools/appicon.py B` (or `C`), or replace the generated files with your own 1024 × 1024 PNG (no transparency).
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
3. **APNs key** (iPhone notifications): Keys → + → enable "Apple Push Notifications service (APNs)" → download the
   `.p8` once. GitHub secrets (§10): `APNS_KEY_P8` (open the `.p8` in TextEdit, copy all of it) and `APNS_KEY_ID` (the
   key's ID, shown next to it). "start the background service" (§7) hands them to the worker with the team
   (`APPLE_TEAM_ID`) and the bundle ID TestFlight uses. TestFlight and App Store builds use Apple's `production` push
   service, the default; set the secret `APNS_ENV` to `sandbox` only for builds installed straight from Xcode.
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
9. **TestFlight**: after "send Jolt to TestFlight" uploads a build (§10), add internal testers in App Store
   Connect → TestFlight → Internal Testing.
10. **App Store ID** (the invite page's "Get the app" link): App Store Connect → your app → App Information → **Apple
    ID** (a number) → `config/app.json` → `ios.appStoreId`.

## 2. Google

1. **Google Play Console** developer account ($25 one-time): https://play.google.com/console/signup
2. **The app, its signing key and the first upload** (the Android build and upload are one button):
   1. **Create the app**: Play Console → **Create app** (name, default language, App, Free, accept the declarations).
      Its package name is fixed by the first upload (§2.2.5): `com.husamisverycool.jolt`, the same ID as the iPhone
      app, unless you set the repository variable `ANDROID_APPLICATION_ID` (§10) to another. Google refuses names
      starting with `com.example`.
   2. **The Android signing key** (no terminal needed): make up a long password (five or six random words), save it in
      your password manager and as the GitHub secret `ANDROID_KEYSTORE_PASSWORD` (§10). Then GitHub → **Actions** →
      **create the Android signing key** → **Run workflow** → **Run workflow**. It makes the upload key, locks it with
      that password, saves the locked file in the repository (`android/keystore/upload.p12.enc`) and adds the key's
      fingerprint to `config/app.json` `android.sha256CertFingerprints`. Run it once: it refuses to replace a key.
      Without the password no new Android version can be signed; if the password or the key is ever lost, Play Console
      → Test and release → App integrity → **Request upload key reset** (Google keeps the real signing key, so the app
      is not lost).
   3. **Upload permission for GitHub** (a Google Cloud service account):
      https://console.cloud.google.com → project picker → **New project** (any name) → Create; then
      https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com (that project selected) →
      **Enable**; then **IAM & Admin → Service accounts → Create service account** → name `play-upload` → **Done** (no
      roles needed); open it → **Keys → Add key → Create new key → JSON** → a `.json` file downloads. Open it in
      TextEdit, copy all of it and save it as the GitHub secret `PLAY_SERVICE_ACCOUNT_JSON`.
   4. **Let that account release**: Play Console → **Users and permissions → Invite new users** → the account's email
      (`play-upload@….iam.gserviceaccount.com`, on its Google Cloud page) → **App permissions → Add app** → Jolt → tick
      **Release apps to testing tracks** → **Invite user**.
   5. **Send it**: GitHub → **Actions** → **send Jolt to Google Play** → **Run workflow**. It builds the signed app and
      uploads it to **internal testing**. The very first time Google only takes the bundle by hand: the run stops and
      its summary page lists the clicks (download the run's **jolt-android-…** artifact and unzip it; Play Console →
      Test and release → Testing → Internal testing → **Create new release** → keep **Use Google-generated key** (Play
      App Signing) → **Upload** the `.aab` → **Next** → **Save and publish**). After that one upload every run uploads
      by itself, each with the next build number.
   6. **App links**: after the first upload, Play Console → Test and release → App integrity → Play app signing → **App
      signing key certificate → SHA-256 certificate fingerprint** → add it to `config/app.json`
      `android.sha256CertFingerprints` (next to the upload key's from §2.2.2). The invite page's `assetlinks.json`
      lists both, so invite links open the app.
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
4. **Data safety form**: fill from `docs/PRIVACY_LABELS.md`. Its **Delete account URL** is
   `https://jolt-husamisverycool.fly.dev/delete-account` (your domain once you have one, §4): the invite page serves the
   steps in the app and, once you set your support address (§8.3), how to ask by email — Google requires a way to request
   deletion without the app.
5. **Internal testing** testers: Play Console → Test and release → Testing → Internal testing → **Testers** → create an
   email list with their Google accounts → **Copy link** and send it to them; each run of "send Jolt to Google Play"
   reaches them.

## 3. Firebase (Android push)

1. https://console.firebase.google.com → Add project → add an Android app with the package name the Play app uses
   (§2.2.1, `com.husamisverycool.jolt` unless you chose another) → download `google-services.json` → open it in
   TextEdit, copy all of it and save it as the GitHub secret `ANDROID_GOOGLE_SERVICES_JSON` (§10; base64 of the file
   is accepted too). "send Jolt to Google Play" puts it into the build (it is never committed); without it the Android
   app has no notifications, and the run says so. The run stops if the file names a different package.
2. Project settings → Service accounts → **Generate new private key** → a `.json` file downloads → its whole text as
   the GitHub secret `FCM_SERVICE_ACCOUNT_JSON`. "start the background service" (§7) hands it to the worker, which sends
   the Android notifications.

## 4. Domain and links

1. **Already set** (owner decision 33): invite links use the invite page's Fly.io address
   `jolt-husamisverycool.fly.dev` (`config/app.json` → `domain`, `ios/Config/Base.xcconfig` → `APP_DOMAIN`). Fly.io
   provides its HTTPS certificate. If the invite page runs under another Fly.io name (the repository variable
   `FLY_WEB_APP`, §10), use `<FLY_WEB_APP>.fly.dev` as in step 2.
2. **Your own domain** (optional, any time later): buy it and make **one change** — the repository variable
   `APP_DOMAIN` (§10; the name only, no `https://` and no `/`). Every release workflow uses it: the iPhone build's
   universal links and App Clip, the Android App Links and the invite page (`tools/release/app_identity.py`). (Or
   change `config/app.json` → `domain` → `value` and `ios/Config/Base.xcconfig` → `APP_DOMAIN` together in the
   repository.) Then run "start the background service" (§7) again. Its summary page shows the DNS records Fly.io asks
   for; add them at the company you bought the domain from, wait up to an hour for the certificate and run the workflow
   again. Then send a new build of each app (links are part of the apps). Links already sent with the `.fly.dev`
   address still open the invite page: the same Fly.io app answers on both addresses.
3. The web service serves `/.well-known/apple-app-site-association` (generated from
   `config/app.json`: `TEAM_ID.APP_BUNDLE_ID` and the App Clip ID for `/i/*`) and
   `/.well-known/assetlinks.json` (from the SHA-256 fingerprints). Nothing to hand-edit.
4. "start the background service" checks both files answer after each deploy. To check by hand:
   `curl https://APP_DOMAIN/.well-known/apple-app-site-association` and Google's Statement List tester.

## 5. Backend (Supabase)

1. Create a project at https://supabase.com/dashboard (region close to your users; Pro plan
   recommended for daily backups and no pausing).
2. Install the CLI locally (`npx supabase`) and run from `backend/`:
   `npx supabase link --project-ref <ref>` then `npx supabase db push` (applies all migrations,
   including the storage bucket and RLS policies).
3. Project Settings → API: the **Project URL** and the **anon public key** go into `config/app.json` → `supabase.url`
   / `supabase.anonKey` (both public); the **service_role secret** is the GitHub secret `SUPABASE_SERVICE_ROLE_KEY`
   (§10), which "start the background service" (§7) hands to the worker and the invite page.
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
   Integrations → Webhooks → URL `https://jolt-worker-<your GitHub name>.fly.dev/webhooks/revenuecat` (the exact
   address is on the summary page of "start the background service", §7) with an authorization header value of your
   choice (a long random string) → the same value as the GitHub secret `REVENUECAT_WEBHOOK_AUTH` → Project settings →
   **API keys** → **+ New secret API key** (API version **V1**, name `worker`) → copy the key (it starts with `sk_`) into
   the GitHub secret `REVENUECAT_SECRET_KEY`, so deleting an account in the app also deletes that person's purchase
   record at RevenueCat (REST API v1 "Delete Customer"); then run "start the background service" again.
   **The webhook is what makes a purchase count**: the server gives Premium (videos) only to people RevenueCat's webhook
   has reported as paying (`public.entitlements`). Without it, someone pays in the app and is still refused videos. So
   once `config/app.json` has a RevenueCat key, "start the background service" stops until `REVENUECAT_WEBHOOK_AUTH`
   is set — set up the webhook before a build with the keys reaches anyone.
3. **Anthropic API key** (recaps only): https://console.anthropic.com → API keys → GitHub secret
   `ANTHROPIC_API_KEY`, then run "start the background service" again. Optional repository variable `RECAP_MODEL`
   (default `claude-opus-5-5`). Without a key, recaps still assemble (deterministic order, template text from
   `design/copy.json`).

## 7. Hosting the worker and web service

The worker (daily invitations, notifications, collages, videos, recaps, the RevenueCat webhook) and the invite page
run on **Fly.io**, started by one button:

1. **Account**: https://fly.io → Sign up (GitHub sign-in works) → Dashboard → **Billing** → add a card. Two small
   always-on machines: the worker (1 shared CPU, 1 GB, the minimum for video work) and the invite page (1 shared CPU,
   512 MB), $6.70 + $3.69 a month plus outbound data ($0.02/GB in North America; https://fly.io/docs/about/pricing/,
   read 2026-10-16).
2. **Token**: Dashboard → your organization (usually *personal*) → **Tokens** → **Create token** (an organization
   token, name `github`; Fly.io's default lifetime is 20 years) → copy all of it, starting with `FlyV1`, and save it
   as the GitHub secret `FLY_API_TOKEN` (§10).
3. **The secrets it hands over** (§10): `SUPABASE_SERVICE_ROLE_KEY` (§5.3) is required; `APNS_KEY_P8` + `APNS_KEY_ID`
   (§1.3, iPhone notifications), `FCM_SERVICE_ACCOUNT_JSON` (§3.2, Android notifications), `REVENUECAT_SECRET_KEY`
   (§6.2), `ANTHROPIC_API_KEY` (§6.3) and `MODERATION_WEBHOOK_URL` (where reports are sent; docs/API.md §12.19) are
   optional: the run names each one that is missing and what goes without it. `REVENUECAT_WEBHOOK_AUTH` (§6.2) is
   optional only while `config/app.json` has no RevenueCat key; after that the run stops without it.
4. **Start it**: GitHub → **Actions** → **start the background service** → **Run workflow** → **Run workflow**. The
   first run creates the apps `jolt-worker-<your GitHub name>` and `jolt-<your GitHub name>` (names are shared by all
   of Fly.io: if one is taken, the run says how to choose another with the repository variables `FLY_WORKER_APP` /
   `FLY_WEB_APP`), builds both on Fly.io's builders and waits until each answers. The invite page starts once
   `config/app.json` has everything it needs (domain §4, App Store ID §1.10, Android fingerprints §2.2.6, the
   Supabase URL and anon key §5.3); until then only the worker starts and the run lists what is missing.
5. Run it again after changing a secret, `config/app.json` or the code: it redeploys both. The region is `iad`
   (Ashburn, Virginia) unless the repository variable `FLY_REGION` names another Fly.io region; set `FLY_ORG` when the token
   sees several organizations.

Any other container host works too (Render, Railway, Cloud Run): the images are `backend/worker/Dockerfile` and
`web/Dockerfile`; `docs/DEPLOY.md` lists the settings each needs.

## 8. Legal

1. **Privacy policy** and **terms of service** at `https://APP_DOMAIN/privacy` and `/terms`.
   We cannot write legal documents for you; have a lawyer or a reputable generator produce them.
   They must cover: phone numbers, photos/videos/voice, contacts (optional, hashed matching),
   push tokens, birthdays, subscriptions, AI processing of group photos for recaps (Anthropic as
   a processor), deletion. Put the URLs in `config/app.json` → `legal`.
2. Age requirement decision: see `docs/PLATFORM_CONSTRAINTS.md` §9 and set
   `app_config.min_age_years` (the age gate fails closed until it is set).
3. **Support address** (an email inbox you read): put it in `config/app.json` → `support` → `email`. It turns on
   Settings → **Contact Us** on both apps, "Contact Us" in the web pages' footer, and the deletion request on
   `/delete-account` (Google requires a way to ask without the app). The release runs warn while it is empty.
   **A deletion request by email**: Supabase → Authentication → Users → search the phone number → copy the user's UID;
   then SQL Editor → run (with that UID) the same deletion the app's Delete Account runs — everything goes, then the
   background service deletes the files and the sign-in account:
   ```sql
   begin;
   select set_config('request.jwt.claims', json_build_object('sub', 'THE-USER-UID', 'role', 'authenticated')::text, true);
   select public.delete_account();
   commit;
   ```

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
| `REVIEW_PHONE`, `REVIEW_CODE` | The app reviewers' sign-in (§11): "set up the server" lets that number sign in with that code, no text sent, for 365 days. Set both before the first store submission |
| `ANDROID_KEYSTORE_PASSWORD` | The password that locks the Android signing key (§2.2.2): "create the Android signing key" makes the key with it, "send Jolt to Google Play" unlocks it. At least 20 characters; keep a copy of your own |
| `ANDROID_UPLOAD_KEYSTORE_B64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | Only if you already have an upload keystore of your own instead: base64 of the keystore file, its alias (needed when it holds several keys) and the key's password when it differs from `ANDROID_KEYSTORE_PASSWORD` (the store's). Used only while `android/keystore/upload.p12.enc` does not exist |
| `PLAY_SERVICE_ACCOUNT_JSON` | "send Jolt to Google Play": the whole text of the Google Cloud service account's `.json` key (§2.2.3) |
| `ANDROID_GOOGLE_SERVICES_JSON` | Firebase's `google-services.json`, its whole text (base64 also accepted), for Android notifications (§3.1). Optional |
| `FLY_API_TOKEN` | "start the background service": the Fly.io organization token (§7.2) |
| `SUPABASE_SERVICE_ROLE_KEY` | "start the background service": the worker's and the invite page's server key (§5.3) |
| `APNS_KEY_P8`, `APNS_KEY_ID` | iPhone notifications from the worker (§1.3); `APPLE_TEAM_ID` (above) is the team. `APNS_ENV` (`sandbox`) only for builds installed from Xcode. Optional |
| `FCM_SERVICE_ACCOUNT_JSON` | Android notifications from the worker: the whole text of Firebase's service account key (§3.2). Optional |
| `REVENUECAT_WEBHOOK_AUTH` | The authorization value you gave RevenueCat's webhook (§6.2). Required as soon as `config/app.json` has a RevenueCat key ("start the background service" stops without it): the server gives Premium only to purchases this webhook reports |
| `REVENUECAT_SECRET_KEY` | RevenueCat secret API key, V1 (§6.2): a deleted account's RevenueCat customer is deleted too. Optional: without it that purchase record stays at RevenueCat |
| `ANTHROPIC_API_KEY` | Weekly recaps written by Claude (§6.3). Optional |
| `MODERATION_WEBHOOK_URL` | Where the worker sends reported photos and people (docs/API.md §12.19). Optional: without it reports wait in the database |

Without these, CI still builds and tests unsigned debug builds on every push.

**Repository variables** (same page → **Variables** tab → New repository variable), all optional:

| Variable | Default | For |
|---|---|---|
| `IOS_BUNDLE_ID` | `com.husamisverycool.jolt` | The iPhone app's bundle ID: TestFlight, the worker's iPhone notifications and the invite page's link file use it |
| `ANDROID_APPLICATION_ID` | `com.husamisverycool.jolt` | The Android package name in Google Play (fixed by the first upload): the Play build and the invite page's link file use it |
| `APP_DOMAIN` | `jolt-husamisverycool.fly.dev` (`config/app.json` `domain`, decision 33) | The invite-link domain once you have your own (§4.2): the iPhone build, the Android build and the invite page all follow it |
| `FLY_WORKER_APP`, `FLY_WEB_APP` | `jolt-worker-<GitHub name>`, `jolt-<GitHub name>` | The Fly.io app names (shared by all of Fly.io); `<FLY_WEB_APP>.fly.dev` is the invite address until you have a domain |
| `FLY_REGION` | `iad` | Where the worker and the invite page run (a Fly.io region code, close to the Supabase project) |
| `FLY_ORG` | the token's organization | Only when the Fly.io token sees several organizations |
| `RECAP_MODEL` | `claude-opus-5-5` | The recap model (docs/DEPLOY.md §4) |

### One-button release (GitHub → Actions → the workflow → **Run workflow**)

1. **set up the server** (`.github/workflows/setup-server.yml`): once the Supabase project exists, its URL and anon key
   are in `config/app.json` and the Supabase secrets above are set. Applies every migration and switches on phone
   sign-in (with the Twilio secrets) with email sign-up off, and the reviewers' sign-in (with `REVIEW_PHONE` and
   `REVIEW_CODE`, §11). Safe to run again.
2. **send Jolt to TestFlight** (`.github/workflows/testflight.yml`): once the Apple secrets are set and the app exists
   in App Store Connect (My Apps → + → New App) with bundle ID `com.husamisverycool.jolt` — or another one, given as the
   workflow's input or the repository variable `IOS_BUNDLE_ID`. Builds Release, signs it automatically and uploads it;
   the build shows under TestFlight once Apple has processed it. Each run is a new build number. Prefer the repository
   variable over the input: "start the background service" reads the same variable for iPhone notifications.
3. **create the Android signing key** (`.github/workflows/android-key.yml`): once, after `ANDROID_KEYSTORE_PASSWORD`
   is set (§2.2.2). Saves the locked key as `android/keystore/upload.p12.enc` and its fingerprint in `config/app.json`
   on the branch it runs on. Refuses to run when a key exists.
4. **send Jolt to Google Play** (`.github/workflows/play.yml`): once the key exists, `PLAY_SERVICE_ACCOUNT_JSON` is
   set and the app exists in Play Console (§2.2). Builds the signed app bundle (build number = the run number), keeps
   it as the run's artifact and uploads it to internal testing. The first upload of a new app is by hand: the run's
   summary lists the clicks (§2.2.5). While the app is still a draft in Play Console, the release is saved as a draft
   and the summary says how to publish it.
5. **start the background service** (`.github/workflows/services.yml`): once `FLY_API_TOKEN` and
   `SUPABASE_SERVICE_ROLE_KEY` are set (§7). Starts or updates the worker and, when `config/app.json` is complete, the
   invite page on Fly.io, and checks each answers. Safe to run again; run it after every change to a secret.

Each stops at the start, naming each missing step, when something is not set up yet (`tools/release/check_setup.py`);
optional steps still missing show as yellow warnings on the run's page.

## 11. App review sign-in

Both stores' reviewers must be able to sign in: "If your app includes account-based features, provide either an active
demo account or fully-featured demo mode" (App Review Guidelines 2.1, https://developer.apple.com/app-store/review/guidelines/);
"If your entire app or parts of your app are restricted based on login credentials [...] you must provide all required
details to enable access to your app" (Play Console Help, Prepare your app for review,
https://support.google.com/googleplay/android-developer/answer/9859455; both read 2026-10-17). Jolt signs in only with a
texted code, so the review account is a test number: Supabase lets it sign in with a fixed code and sends no text (its
test codes are checked before Twilio Verify).

1. **Choose the number and the code.** The number must not be anyone's: in North America 555-0100 to 555-0199 are kept
   for fiction by the numbering plan's administrator, and the Android app accepts such a number with a real area code,
   for example `+1 201 555 0142` (checked with libphonenumber 9.0.30, the library the Android app checks numbers with;
   `+1 555 …` numbers are refused). The code: six digits you make up.
2. **Save them** as the GitHub secrets `REVIEW_PHONE` (with `+` and the country code) and `REVIEW_CODE` (§10), then run
   **set up the server** again. The code works for 365 days from that run; run it again to renew it (the run's log says
   it set the code). Every "set up the server" run warns while the two secrets are missing.
3. **Give the account something to show** (once, before the first submission): on your phone, sign out (Profile →
   Settings → Sign Out) or use a spare phone, sign in with the review number and code, enter an adult's birthday and
   a name, **Create Group**, post a photo, and copy the group's invite link (the group → Invite → **Copy Link**). Sign out
   again.
4. **App Store Connect** → your app → the version → **App Review Information** → tick **Sign-in required** → User name:
   the review number; Password: the code. **Notes**: the text below.
5. **Play Console** → Policy and programs → **App content** → **Sign-in details** → **Start** (or **Manage**) →
   **+ Add new instructions** → Username: the review number; Password: the code; **Any other instructions**: the text
   below → **Save**.

Text for the notes (put in your number, code and invite link):

> Jolt signs in with a phone number and a code sent by text message; there are no passwords. This review account needs
> no text message: on the first screen enter +1 201 555 0142 and tap Next, then enter the code 123456 and tap Next.
> Enter any birthday of an adult (it is only used to check the age and is not saved) and tap Next. The account is in a
> group with photos. To try joining a group from an invite (the App Clip on iPhone, the invite page elsewhere), open
> https://jolt-husamisverycool.fly.dev/i/YOUR-INVITE-TOKEN on the device.


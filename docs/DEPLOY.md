# Deploy checklist

One page for putting the backend worker (and the secrets around it) into production. The steps that
need the owner's accounts are in [`OWNER_SETUP.md`](OWNER_SETUP.md); this file says where each
resulting value goes.

## 0. The one-button way: Fly.io

GitHub → Actions → **start the background service** (`.github/workflows/services.yml`, OWNER_SETUP §7) does §2–§4 and
§7 below on Fly.io for both services:

1. `tools/release/app_identity.py` writes the run's store identity (repository variables `IOS_BUNDLE_ID`,
   `ANDROID_APPLICATION_ID`, the secret `APPLE_TEAM_ID`) into the job's copy of `config/app.json` (never committed), so
   the worker's `APNS_BUNDLE_ID` and the invite page's association files name the apps the stores have.
2. `tools/release/check_setup.py services` stops on a missing required value (`FLY_API_TOKEN`,
   `SUPABASE_SERVICE_ROLE_KEY`, `config/app.json` `supabase.url`, malformed optional keys) and warns for each optional
   one. It decides whether the invite page can start: the page refuses to run in production without the anon key, a
   domain, the iOS team / bundle / App Store IDs and the Android package and fingerprints (`web/src/config.ts`); while
   any is missing only the worker is deployed.
3. `tools/release/fly_service.py ensure-app` creates the apps on the first run: `FLY_WORKER_APP` / `FLY_WEB_APP`
   (repository variables), else `jolt-worker-<owner>` / `jolt-<owner>`; `FLY_ORG` when the token sees several
   organizations.
4. `fly_service.py secrets worker|web` stages the settings of §4 on each app (`flyctl secrets set NAME=- --stage`, the
   value on standard input, never on a command line or in the log). Worker: `SUPABASE_URL` (from `config/app.json`),
   `SUPABASE_SERVICE_ROLE_KEY`, the `APNS_*` set (`APNS_BUNDLE_ID` = `config/app.json` `ios.bundleId`, `APNS_TEAM_ID` =
   `APNS_TEAM_ID` or `APPLE_TEAM_ID`, `APNS_ENV` default `production`), `FCM_SERVICE_ACCOUNT_JSON`,
   `REVENUECAT_WEBHOOK_AUTH`, `REVENUECAT_SECRET_KEY`, `ANTHROPIC_API_KEY`, `RECAP_MODEL`, `MODERATION_WEBHOOK_URL` (each only when set). Web:
   `SUPABASE_URL`, `SUPABASE_ANON_KEY` (from `config/app.json`), `SUPABASE_SERVICE_ROLE_KEY`.
5. `flyctl deploy --config deploy/worker.fly.toml` (then `deploy/web.fly.toml`) `--app <name> --primary-region
   <FLY_REGION, default iad> --remote-only --ha=false`, from the repository root: the build context is the root and the
   `dockerfile` / `ignorefile` paths in the `.toml` files are relative to the `.toml` (flyctl
   `internal/command/deploy/deploy_build.go`, v0.4.110, the version the workflow pins). Fly.io's builders build the
   images; the first deploy assigns the app a shared IPv4 and an IPv6 address.
6. `fly_service.py wait` polls `https://<worker>.fly.dev/healthz`, then the invite page's `/healthz`,
   `/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json`, until each answers 200 (2 minutes
   each), and writes the addresses on the run's summary page (with the RevenueCat webhook address, §6).
7. When `config/app.json` `domain` is not a `*.fly.dev` name, `fly_service.py cert` asks Fly.io for its certificate
   (`flyctl certs add`) and puts the DNS records Fly.io wants on the summary page.

Machines (`deploy/*.fly.toml`): worker 1 shared vCPU / 1 GB, invite page 1 shared vCPU / 512 MB, one machine each,
always on (`auto_stop_machines = "off"`, `min_machines_running = 1`), health check `GET /healthz` every 15 s;
`kill_timeout` 30 s for the worker (above `SHUTDOWN_GRACE_MS`, §3), 10 s for the page. The page sets
`TRUST_PROXY_HOPS = 1` (Fly.io's proxy adds one `X-Forwarded-For` entry). By hand, with `flyctl` logged in, the same
deploy is `flyctl deploy --config deploy/worker.fly.toml --app <name> --remote-only` from the repository root.

## 1. Database

From `backend/`: `npx supabase link --project-ref <ref>` then `npx supabase db push`. This applies
every migration, including the worker's:

- `20261015000012_worker_config.sql`: default waking window 09:48–21:12 (owner may change),
  `collage_option = 'B'` (pending the owner's choice), collage folder cleanup on delete, the
  RevenueCat event ledger + `apply_revenuecat_event`;
- `20261015000013_worker_release_job.sql`: `release_job` (graceful shutdown hands jobs back).

- `20261015000014_recap_time.sql`: weekly recaps run at the end of each group's waking window on
  Sunday (its own hours, else the default window). `weekly_recap_local_time` (NULL) is an optional
  override: `update app_config set value = '"HH:MM"' where key = 'weekly_recap_local_time'`;
- `20261015000015_collage_pages.sql`: `collages.page_count`.

## 2. Build the worker image

```sh
# from the repository root (the image also carries design/proposals and design/*.md)
docker build -f backend/worker/Dockerfile -t worker .
```

- Base image `node:22-slim` + Debian `ffmpeg` (libx264, AAC) + `fontconfig`; Roboto Serif Headline and Inter (SIL OFL)
  are vendored in `backend/worker/fonts/` (see `SOURCE.txt`).
- Fallback fonts for tribute names and lines in other scripts and with emoji (SIL OFL, `fonts/fallback/SOURCE.txt`):
  the image carries `fonts/fallback/scripts` (Noto: Greek serif, Arabic, Hebrew, Devanagari, Thai, CJK and Hangul
  subsets, 10.2 MB) and `fonts/fallback/emoji-color` (Noto Color Emoji COLRv1, 5.0 MB) at `/app/fonts/fallback/`.
  The worker points fontconfig at `backend/worker/fonts/fonts.conf` (`FONTCONFIG_FILE`, set at start unless the
  environment already sets it): those fonts only, no system fonts, so renders match CI.
- Docker Hub rate limits: `--build-arg NODE_IMAGE=public.ecr.aws/docker/library/node:22-slim`.
- Behind a TLS-intercepting proxy: `--build-arg HTTPS_PROXY=… --secret id=build_ca,src=<ca.pem>`.
- Runs `node --import tsx src/main.ts` as user `node`; listens on `PORT` (8080).

### The web image (invite page)

```sh
# from the repository root
docker build -f web/Dockerfile -t web .
```

- The share image (`/i/<token>/og.png`) sets group names with the faces in `web/assets/fonts/` and the fallback fonts of
  `fonts/fallback/scripts` + `fonts/fallback/emoji-mono` (monochrome Noto Emoji: librsvg draws SVG text as outlines,
  so a colour emoji font would come out as silhouettes), 11.1 MB in all, copied to `/app/fonts/fallback/`;
  `web/assets/fonts/fonts.conf` lists them and nothing from the system.

## 3. Run it

- **One instance, always on** (it runs the scheduler), 1 vCPU / 1 GB RAM minimum (OWNER_SETUP §7);
  tribute videos are the CPU peak (docs/COSTS.md). Several instances are safe for jobs
  (`FOR UPDATE SKIP LOCKED`), but each keeps its own widget-push throttle (docs/WIDGET_REFRESH.md).
- **Health check:** `GET /healthz` → 200 `{"status":"ok", …}`; 503 when the scheduler has not ticked
  for 3 intervals or the runner stopped. The image has a Docker `HEALTHCHECK` on it.
- **Shutdown:** SIGTERM stops claiming, waits up to `SHUTDOWN_GRACE_MS` for running jobs, then
  releases the rest back to the queue (no attempt spent). Give the platform a stop timeout above
  that value (default 25 s → 30 s).
- **Logs:** one JSON object per line on stdout (`ts`, `level`, `msg`, `job_id`, `kind`, …). Useful
  messages: `push batch` (with `dispatch_spread_ms`, `late_by_ms` for invitations), `job failed`
  (`status: queued` = will retry), `ai cost`, `tribute rendered` (`ffmpeg_cpu_seconds`).

## 4. Environment variables

### Worker secrets (from OWNER_SETUP.md)

| variable | required | from | used for |
|---|---|---|---|
| `SUPABASE_URL` | yes | OWNER_SETUP §5.3 | PostgREST, Storage, Auth admin |
| `SUPABASE_SERVICE_ROLE_KEY` | yes | §5.3 | service role (jobs, storage writes/deletes, signed URLs, auth user deletion) |
| `APNS_KEY_P8` | for iOS pushes | §1.3 (.p8 file contents; `\n` escapes accepted) | APNs provider token (ES256) |
| `APNS_KEY_ID` | with the key | §1.3 | JWT `kid` |
| `APNS_TEAM_ID` | with the key | §1.3 | JWT `iss` |
| `APNS_BUNDLE_ID` | with the key | §1.3 (= `config/app.json` `ios.bundleId`) | `apns-topic` (+ `.push-type.liveactivity`) |
| `APNS_ENV` | with the key | §1.3: `sandbox` or `production` (default `production`) | APNs host; tokens of the other environment are rejected |
| `FCM_SERVICE_ACCOUNT_JSON` | for Android pushes | §3.2 (service-account key JSON) | FCM HTTP v1 OAuth (JWT bearer grant) |
| `REVENUECAT_WEBHOOK_AUTH` | for subscriptions | §6.2 (the exact Authorization header value set in RevenueCat) | `POST /webhooks/revenuecat`; without it the endpoint answers 503 |
| `REVENUECAT_SECRET_KEY` | optional | §6.2 (a V1 secret API key, `sk_…`) | `auth.delete_user` also calls `DELETE https://api.revenuecat.com/v1/subscribers/{user id}`; without it the RevenueCat customer stays |
| `ANTHROPIC_API_KEY` | optional | §6.3 | recap photo choice/order and text; without it recaps use the deterministic order and the template text |
| `RECAP_MODEL` | optional | §6.3 (default `claude-opus-5-5`) | recap model; its price must be in `src/recap/pricing.ts` for `ai_cost_log` |

Without the APNs or FCM values the worker runs and skips that platform's pushes (logged once at start).

### Worker settings (optional)

| variable | default | meaning |
|---|---|---|
| `PORT` | 8080 | HTTP port (health, webhook) |
| `WORKER_ID` | hostname-pid | lock owner name in `jobs.locked_by` |
| `LOG_LEVEL` | info | debug / info / warn / error |
| `WORKER_REALTIME_CONCURRENCY` / `WORKER_REALTIME_POLL_MS` | 8 / 1000 | lane for invitations, pushes, widget refreshes |
| `WORKER_HEAVY_CONCURRENCY` / `WORKER_HEAVY_POLL_MS` | 2 / 2000 | lane for renditions, collages, tribute videos, recaps, year stories, deletions |
| `SCHEDULER_INTERVAL_MS` | 60000 | scheduler tick (invitations are additionally dispatched exactly at `fires_at` by a timer) |
| `SHUTDOWN_GRACE_MS` | 25000 | how long running jobs may finish on SIGTERM |
| `MODERATION_WEBHOOK_URL` | unset | where `moderation.report` POSTs reports (docs/API.md §12.19); unset = logged, reports stay `open` |
| `FONTS_DIR`, `DESIGN_DIR` | image paths | Roboto Serif Headline / Inter files; design folder with `proposals/` and `copy-patterns.md` |
| `APNS_ORIGIN`, `APNS_MANAGE_ORIGIN`, `FCM_ORIGIN` | Apple / Google hosts | test or staging overrides only |

### Everything else in OWNER_SETUP.md (not worker variables)

| value | goes to |
|---|---|
| Supabase anon key + URL | `config/app.json` → `supabase` (apps, web) |
| `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SERVICE_SID` | Supabase Auth → Phone → Twilio Verify (backend/README.md) |
| RevenueCat public SDK keys | `config/app.json` → `revenuecat.iosApiKey` / `androidApiKey` |
| `google-services.json` / `ANDROID_GOOGLE_SERVICES_JSON` | Android build ("send Jolt to Google Play"; GitHub secret, the file's text or base64) |
| `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` | GitHub Actions secrets (iOS signing, TestFlight) |
| `ANDROID_KEYSTORE_PASSWORD` + `android/keystore/upload.p12.enc` | The Android upload key, made and locked by "create the Android signing key" (`tools/release/android_key.py`: PKCS12, alias `upload`, RSA 4096, `openssl enc -aes-256-cbc -pbkdf2 -iter 1000000`); "send Jolt to Google Play" unlocks it into the runner's temporary folder and hands it to Gradle as `ANDROID_UPLOAD_STORE_FILE` / `ANDROID_UPLOAD_KEY_ALIAS` (`android/app/build.gradle.kts`) |
| `ANDROID_UPLOAD_KEYSTORE_B64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | An owner's own keystore instead, used only while the locked file does not exist |
| `PLAY_SERVICE_ACCOUNT_JSON` | Play upload (`tools/release/play_upload.py`, Google Play Developer API v3 edits) |
| `FLY_API_TOKEN` | "start the background service" (§0) |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` | also the web service (invite page signing); `PORT` 8080 and `TRUST_PROXY_HOPS` are in `deploy/web.fly.toml` |

## 5. Apple / Google settings the worker relies on

- **APNs key** with the Apple Push Notification service enabled (OWNER_SETUP §1.3). One key serves
  alerts, background pushes and Live Activities.
- **Live Activity broadcast channels (iOS 18+)**: the worker creates one channel per daily
  invitation (management API, `api-manage-broadcast[.sandbox].push.apple.com:2196/2195`), starts
  the activities subscribed to it, ends them all with one broadcast at window close, then deletes
  the channel. Apple's broadcast documentation requires broadcast push to be enabled for the app;
  if channel creation fails the worker logs it and activities end by their `stale-date` and the
  app instead.
- **No Time Sensitive Notifications capability is needed by the worker**: every alert, the
  iOS invitation fallback included, is `interruption-level: active` (`passive` in quiet hours);
  tenet 5, design/surfaces/daily.notification.md, MERGE_DECISIONS C-10.
- **FCM**: the service account needs the Firebase Cloud Messaging API (HTTP v1) enabled on the
  project.

## 6. RevenueCat webhook

RevenueCat → Integrations → Webhooks: URL `https://<worker-host>/webhooks/revenuecat` (on Fly.io
`https://<FLY_WORKER_APP or jolt-worker-<owner>>.fly.dev/webhooks/revenuecat`, printed on the summary page of "start the
background service"),
Authorization header = `REVENUECAT_WEBHOOK_AUTH`. The worker answers 200 with
`applied | duplicate | stale | ignored`; 401 on a wrong header; RevenueCat retries other failures.
Events are applied once per event id; an older event never overwrites a newer one.

## 7. After deploy

1. `curl https://<worker-host>/healthz` → 200 ("start the background service" checks it, and the invite page's
   association files, after every deploy).
2. Logs show `runner started` and a `scheduler tick` every minute (`invitations.created` on the
   first tick of a day; `recaps` > 0 on Sunday evenings, group-local).
3. Post a photo from a test account: logs show `push batch` for `new_post` and `widget.refresh`.
4. RevenueCat dashboard → "Send test event": the worker answers 200 `ignored` (TEST events change nothing).

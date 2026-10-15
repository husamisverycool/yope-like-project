# Deploy checklist

One page for putting the backend worker (and the secrets around it) into production. The steps that
need the owner's accounts are in [`OWNER_SETUP.md`](OWNER_SETUP.md); this file says where each
resulting value goes.

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

- Base image `node:22-slim` + Debian `ffmpeg` (libx264, AAC) + `fontconfig`; Roboto (Apache 2.0) is
  vendored in `backend/worker/fonts/`.
- Docker Hub rate limits: `--build-arg NODE_IMAGE=public.ecr.aws/docker/library/node:22-slim`.
- Behind a TLS-intercepting proxy: `--build-arg HTTPS_PROXY=… --secret id=build_ca,src=<ca.pem>`.
- Runs `node --import tsx src/main.ts` as user `node`; listens on `PORT` (8080).

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
| `APNS_BUNDLE_ID` | with the key | §1.3 (= `config/app.json` `ios.bundleId`) | `apns-topic` (+ `.push-type.liveactivity` / `.push-type.widgets`) |
| `APNS_ENV` | with the key | §1.3: `sandbox` or `production` (default `production`) | APNs host; tokens of the other environment are rejected |
| `FCM_SERVICE_ACCOUNT_JSON` | for Android pushes | §3.2 (service-account key JSON) | FCM HTTP v1 OAuth (JWT bearer grant) |
| `REVENUECAT_WEBHOOK_AUTH` | for subscriptions | §6.2 (the exact Authorization header value set in RevenueCat) | `POST /webhooks/revenuecat`; without it the endpoint answers 503 |
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
| `FONTS_DIR`, `DESIGN_DIR` | image paths | Roboto files; design folder with `proposals/` and `copy-patterns.md` |
| `APNS_ORIGIN`, `APNS_MANAGE_ORIGIN`, `FCM_ORIGIN` | Apple / Google hosts | test or staging overrides only |

### Everything else in OWNER_SETUP.md (not worker variables)

| value | goes to |
|---|---|
| Supabase anon key + URL | `config/app.json` → `supabase` (apps, web) |
| `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SERVICE_SID` | Supabase Auth → Phone → Twilio Verify (backend/README.md) |
| RevenueCat public SDK keys | `config/app.json` → `revenuecat.iosApiKey` / `androidApiKey` |
| `google-services.json` / `ANDROID_GOOGLE_SERVICES_JSON` | Android build (CI secret, base64) |
| `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` | GitHub Actions secrets (iOS signing, TestFlight) |
| `ANDROID_UPLOAD_KEYSTORE_B64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `PLAY_SERVICE_ACCOUNT_JSON` | GitHub Actions secrets (Android signing, Play upload) |
| `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | also the web service (invite page signing) |

## 5. Apple / Google settings the worker relies on

- **APNs key** with the Apple Push Notification service enabled (OWNER_SETUP §1.3). One key serves
  alerts, background pushes, Live Activities and WidgetKit pushes.
- **Live Activity broadcast channels (iOS 18+)**: the worker creates one channel per daily
  invitation (management API, `api-manage-broadcast[.sandbox].push.apple.com:2196/2195`), starts
  the activities subscribed to it, ends them all with one broadcast at window close, then deletes
  the channel. Apple's broadcast documentation requires broadcast push to be enabled for the app;
  if channel creation fails the worker logs it and activities end by their `stale-date` and the
  app instead.
- **Time Sensitive Notifications** capability (OWNER_SETUP §1.2): the iOS invitation alert uses
  `interruption-level: time-sensitive` when Live Activities are off.
- **FCM**: the service account needs the Firebase Cloud Messaging API (HTTP v1) enabled on the
  project.

## 6. RevenueCat webhook

RevenueCat → Integrations → Webhooks: URL `https://<worker-host>/webhooks/revenuecat`,
Authorization header = `REVENUECAT_WEBHOOK_AUTH`. The worker answers 200 with
`applied | duplicate | stale | ignored`; 401 on a wrong header; RevenueCat retries other failures.
Events are applied once per event id; an older event never overwrites a newer one.

## 7. After deploy

1. `curl https://<worker-host>/healthz` → 200.
2. Logs show `runner started` and a `scheduler tick` every minute (`invitations.created` on the
   first tick of a day; `recaps` > 0 on Sunday evenings, group-local).
3. Post a photo from a test account: logs show `push batch` for `new_post` and `widget.refresh`.
4. RevenueCat dashboard → "Send test event": the worker answers 200 `ignored` (TEST events change nothing).

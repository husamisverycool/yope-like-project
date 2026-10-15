# Backend (Supabase)

The database, auth, storage and realtime configuration of the app. Everything is in
SQL migrations under `supabase/migrations/`, with no steps done by hand in the dashboard.
The client contract is in [`docs/API.md`](../docs/API.md).

```
backend/
  supabase/config.toml        local stack + auth/storage settings (pushed with `supabase config push`)
  supabase/migrations/        schema, RLS, RPCs, storage policies, realtime (source of truth)
  supabase/seed.sql           local dev only (intentionally empty)
  tests/                      integration tests (vitest + supabase-js) against the local stack
  tests/security/             the security invariants of docs/ARCHITECTURE.md
```

## Required secrets

Phone sign-in uses Twilio Verify. `config.toml` reads these from the environment
(`env(...)`). For local OTP testing, export them in the shell before `npm run db:start`.
For production, set them in the hosted project's Auth settings (or with
`supabase config push`):

| Variable | What it is |
|---|---|
| `TWILIO_ACCOUNT_SID` | Twilio account SID (`AC…`) |
| `TWILIO_AUTH_TOKEN` | Twilio auth token |
| `TWILIO_VERIFY_SERVICE_SID` | Twilio Verify service SID (`VA…`) |

When they are unset, the local stack still starts. Sending an OTP fails, but nothing else does:
the tests create users with the admin API and sign their own JWTs.

Services that use the **service role key** (`SUPABASE_SERVICE_ROLE_KEY`): the worker
(job queue, scheduler, storage deletion, auth user deletion), the RevenueCat webhook
(writes `entitlements`) and the web invite page (signs cover/avatar URLs for
`invite_preview`). Mobile apps only ever use the anon (publishable) key plus the user's
session.

## Run locally

Needs Docker and Node 22.

```sh
cd backend
npm install
npm run db:start      # supabase start (Postgres, Auth, PostgREST, Storage, Realtime)
npm run db:reset      # re-apply all migrations + seed
npm test              # full integration suite (needs the local stack running)
npm run db:lint       # plpgsql_check lint of all functions
```

`npm run db:start` leaves out Studio, imgproxy, edge-runtime, logflare/vector, mailpit,
postgres-meta and supavisor. The tests don't need them; drop the `-x` list if you want them.

## Production notes

- Email sign-up and sign-in are disabled (`[auth.email] enable_signup = false`). Phone
  OTP is the only sign-in method. JWT expiry stays at the default 3600 s.
- Leave `pg_graphql` disabled on the hosted project. The apps use PostgREST only. It
  would respect RLS anyway.
- The worker must call the scheduler helpers periodically (see docs/API.md, "Worker
  contract"). `app_config` keys that are still NULL (waking window defaults, weekly
  recap time, minimum age) keep those features off until their values are sourced.

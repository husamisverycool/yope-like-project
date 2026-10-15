# Architecture

## Overview

```
 iOS app (SwiftUI)          Android app (Compose)
  ├─ Widget ext (WidgetKit,  ├─ Glance widgets
  │   Live Activity)         ├─ FCM service → WorkManager → widget update
  ├─ Notification Service    ├─ Ongoing countdown notification
  │   ext (pre-fetch photo,  └─ App Links (+ web fallback for invites)
  │   reload widgets)
  └─ App Clip (invite)
          │  supabase-swift / supabase-kt (PostgREST, Auth, Storage, Realtime)
          ▼
 ┌──────────────────────── Supabase ────────────────────────┐
 │ Auth (phone OTP via Twilio Verify)                        │
 │ Postgres: every table has RLS; RPCs (security definer     │
 │   with explicit membership checks) for multi-step writes  │
 │ Storage: private bucket `media`, RLS on storage.objects,  │
 │   clients read through short-lived signed URLs            │
 │ Realtime: chat + post inserts (RLS-filtered)              │
 └───────────────────────────────────────────────────────────┘
          ▲ service role
          │
 Worker (Node 22, TypeScript, Docker image with ffmpeg + libvips)
  ├─ Job queue: `jobs` table, `FOR UPDATE SKIP LOCKED`, retries with backoff
  ├─ Scheduler: daily invitations, Sunday recaps, birthday requests/tributes, year stories
  ├─ Media: renditions (thumb / widget / display), deterministic collage composition (sharp)
  ├─ Video: tribute + year videos with ffmpeg
  ├─ AI: recap photo choice/order + recap text (Anthropic API), cost logged per job
  ├─ Push: APNs (HTTP/2, token auth) + FCM HTTP v1; Live Activity push-to-start/end
  └─ HTTP: RevenueCat webhook, health
 Web (Node, server-rendered): invite preview page `/i/<token>`, `/.well-known/*`
```

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Backend | Supabase (managed Postgres + Auth + Storage + Realtime) | Directive allows it; RLS is native; phone auth with Twilio Verify is built in. |
| Long jobs | Separate worker service (Node + sharp + ffmpeg) | Edge Functions can't run ffmpeg/libvips; jobs need minutes and retries. |
| Queue | Postgres `jobs` table with `SKIP LOCKED` | No extra infrastructure; transactional enqueue with the write that causes it. |
| Collage | Server-side, deterministic (same inputs → byte-identical output) | Directive. Layout is a pure function `layout(n, option)` with unit tests for n = 1…30. |
| Tribute / year videos | Server-side ffmpeg | One implementation for both platforms; cost documented in `docs/COSTS.md`. |
| Server-rendered text font | Roboto (Apache 2.0), level PLATFORM | SF Pro may not be used off Apple platforms. |
| Widget delivery | Push-driven: alert push with `mutable-content` → Notification Service Extension downloads the widget rendition into the App Group and reloads timelines; plus WidgetKit push / background push where allowed. Android: FCM data message → WorkManager → Glance update. | See `docs/WIDGET_REFRESH.md` (from `docs/PLATFORM_CONSTRAINTS.md`). |
| Countdown | iOS Live Activity started by push-to-start at the invitation moment; Android ongoing notification with a count-down chronometer | Every member gets it at the same moment, server-driven. |
| AI | Anthropic Messages API, model configurable (`RECAP_MODEL`, default `claude-opus-5-5`, $4/$20 per MTok), effort `low`, structured output; only that group's content is sent; cost per job logged to `ai_cost_log` | Directive Part 7. |
| Subscriptions | RevenueCat (StoreKit 2 / Play Billing); webhook → `entitlements` table; server checks entitlement for premium-only writes (video posts) | Directive. |
| Invite links | `https://<domain>/i/<token>` universal link / App Link; App Clip experience on the same URL; Android web fallback | Directive; Play Instant status in `docs/PLATFORM_CONSTRAINTS.md`. |

## Data model (summary; the migrations are the source of truth)

- `profiles` (id = auth user, display_name, avatar_path, birthday (optional), birthday_opt_in, age_confirmed_at)
- `groups` (name, cover_path, kind: friends|family|roommates|custom, time_zone, waking_start, waking_end, invitation_paused, created_by)
- `group_members` (group_id, user_id, role: admin|member, muted, joined_at) — max 30 per group (enforced in DB)
- `group_invites` (token, group_id, created_by, expires_at, revoked_at)
- `media` (owner, kind: photo|live_photo|video, rendition paths, dims, duration, dual: back/front paths)
- `posts` (media_id, group_id, author_id, caption, voice_path, voice_duration_ms, invitation_id nullable, in_window bool)
- `messages` (group_id, author_id, kind: text|photo|voice, body, post_id, reply_to_post_id, reply_to_message_id)
- `reactions` (post_id, user_id, emoji) — exposed as a list of (user, emoji); never aggregated into counts for clients
- `post_tags` (post_id, user_id) — self-tags only ("I'm in this")
- `daily_invitations` (group_id, local_date, fires_at, closes_at, status)
- `collages` (group_id, invitation_id, option, post_ids, paths, composed_at)
- `weekly_recaps` (group_id, week_start, items, text, status) ; `albums`, `album_items`
- `tribute_requests`, `tribute_contributions`, `tributes`
- `year_stories` (group_id, year, data)
- `devices` (user_id, platform, push_token, push_to_start_token, widget_push_token)
- `notification_settings` (user quiet hours) ; per-group mute in `group_members`
- `blocks`, `reports`, `entitlements`, `jobs`, `ai_cost_log`

## Security invariants (each proven by tests in `backend/tests/security/`)

1. A user who is not a member of group G can read nothing belonging to G: no row in any table,
   no storage object, no RPC result, no Realtime event.
2. Deleting a photo removes it from: the group feed, chat, walls, collages (recomposed),
   recaps, albums, tribute contributions (tribute re-rendered), year stories (recomputed),
   widgets (refresh push), and storage.
3. Account deletion deletes all of the user's data and the auth user.
4. Blocking hides each person's content from the other in shared groups.
5. A birthday honoree cannot see their own tribute request or contributions before the tribute is delivered.

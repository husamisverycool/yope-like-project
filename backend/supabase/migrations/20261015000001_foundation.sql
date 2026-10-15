-- =============================================================================
-- 0001 foundation: schemas, privilege hardening, enums, validation helpers,
-- app_config (tunables), jobs queue primitives.
--
-- Conventions used by every later migration
--   * Tables live in `public` (exposed by PostgREST) and ALWAYS have RLS enabled.
--   * Helper functions live in `private` (NOT exposed by PostgREST).
--   * Client RPCs are `security definer`, `set search_path = ''`, check membership
--     explicitly and raise errors as:
--         raise exception '<error_code>' using errcode = 'PT<http status>';
--     PostgREST turns SQLSTATE PTxyz into HTTP status xyz; the JSON body carries
--     {"code":"PTxyz","message":"<error_code>"}. Error codes are documented in docs/API.md.
--   * Nothing in `public` is executable/readable by anon/authenticated unless granted
--     explicitly (default privileges are revoked below).
-- =============================================================================

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated, service_role;

-- Supabase grants every new table/function in `public` to anon + authenticated by
-- default. Turn that off so every exposure is an explicit, reviewed GRANT.
alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public revoke execute on functions from anon, authenticated;
alter default privileges for role postgres revoke execute on functions from public;
alter default privileges for role postgres in schema private revoke execute on functions from public;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.group_kind as enum ('friends', 'family', 'roommates', 'custom');
create type public.member_role as enum ('admin', 'member');
create type public.media_kind as enum ('photo', 'live_photo', 'video');
create type public.message_kind as enum ('text', 'photo', 'voice');
create type public.device_platform as enum ('ios', 'android');
create type public.invitation_status as enum ('scheduled', 'fired', 'closed', 'cancelled');
create type public.render_status as enum ('pending', 'ready', 'failed');
create type public.report_target_kind as enum ('post', 'message', 'user', 'group');
create type public.job_status as enum ('queued', 'running', 'done', 'failed', 'cancelled');

-- ---------------------------------------------------------------------------
-- Validation helpers (immutable, usable in CHECK constraints)
-- ---------------------------------------------------------------------------

-- Storage object paths: no traversal, no empty segments, conservative charset.
create function private.is_safe_path(p text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p is not null
     and char_length(p) between 3 and 512
     and p ~ '^[A-Za-z0-9_][A-Za-z0-9_./-]*$'
     and p !~ '\.\.'
     and p !~ '//'
     and p !~ '/$'
$$;

-- "Any emoji": 1..32 code points, at least one non-ASCII code point,
-- no whitespace, no ASCII letters (keycaps such as 1️⃣ / #️⃣ stay valid).
create function private.is_emoji(p text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p is not null
     and char_length(p) between 1 and 32
     and p ~ '[^\x01-\x7F]'
     and p !~ '[[:space:]]'
     and p !~ '[A-Za-z]'
$$;

create function private.is_uuid(p text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
$$;

create function private.is_valid_time_zone(p text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p is not null and exists (select 1 from pg_catalog.pg_timezone_names where name = p)
$$;

-- 144-bit random, URL-safe (base64url without padding: 18 bytes -> 24 chars).
create function private.new_invite_token()
returns text
language sql
volatile
set search_path = ''
as $$
  select translate(encode(extensions.gen_random_bytes(18), 'base64'), '+/', '-_')
$$;

create function private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- app_config: single source for tunables. Service role only; keys with
-- is_public = true are readable by clients through the view public_app_config.
-- A NULL value means "not sourced yet"; code that needs it fails closed.
-- ---------------------------------------------------------------------------
create table public.app_config (
  key         text primary key,
  value       jsonb,
  is_public   boolean not null default false,
  description text not null,
  updated_at  timestamptz not null default now()
);
alter table public.app_config enable row level security;
-- (no policies: clients have no access; see public_app_config view below)

create trigger app_config_touch before update on public.app_config
  for each row execute function private.touch_updated_at();

insert into public.app_config (key, value, is_public, description) values
  ('invitation_window_seconds', '120', true,
   'Length of the daily invitation window: closes_at = fires_at + this many seconds.'),
  ('default_waking_start', null, false,
   'Default local start of a group''s waking window (JSON string "HH:MM"). NULL: set from design/research/bereal.md. Groups without their own window are skipped by schedule_daily_invitations while this is NULL.'),
  ('default_waking_end', null, false,
   'Default local end of a group''s waking window (JSON string "HH:MM"). NULL: set from design/research/bereal.md.'),
  ('weekly_recap_local_time', null, false,
   'Local time (JSON string "HH:MM") on weekly_recap_isodow when the weekly recap is generated. NULL until sourced; due_weekly_recaps fails closed (config_missing) while NULL.'),
  ('weekly_recap_isodow', '7', false,
   'ISO day of week (1 = Monday ... 7 = Sunday) on which the weekly recap is generated. 7 per docs/SURFACES.md week.recap ("Sunday recap").'),
  ('week_start_isodow', '1', true,
   'ISO day of week on which a history week starts (1 = Monday). Change if design research says otherwise.'),
  ('free_history_days', null, true,
   'Days of group history browsable without premium in group_history_weeks. NULL = unlimited. Owner decision pending.'),
  ('max_group_members', '30', true,
   'Maximum members per group (enforced by trigger on group_members).'),
  ('min_age_years', null, true,
   'Minimum age accepted by confirm_age. NULL: set from design/research/platform.md / App Store rating; confirm_age fails closed (age_gate_not_configured) while NULL.'),
  ('invite_ttl_seconds', '604800', false,
   'Lifetime of an invite link created by create_invite (7 days). Owner decision pending (docs/API.md Open decisions).'),
  ('birthday_request_lead_days', '7', false,
   'Days before a birthday (group local date) when tribute requests are created.'),
  ('year_story_release_month_day', '"12-01"', false,
   'Local month-day ("MM-DD", December) from which year stories are generated. Owner decision pending on the exact day.'),
  ('job_lock_timeout_seconds', '600', false,
   'A running job whose lock is older than this is considered abandoned and is re-claimed.'),
  ('job_backoff_base_seconds', '30', false,
   'fail_job retry delay = min(job_backoff_max_seconds, base * 2^(attempts-1)).'),
  ('job_backoff_max_seconds', '3600', false,
   'Upper bound of the fail_job retry delay.');

create function private.config(p_key text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select c.value from public.app_config c where c.key = p_key
$$;

create function private.config_int(p_key text)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select (c.value #>> '{}')::integer from public.app_config c where c.key = p_key
$$;

create function private.config_text(p_key text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select c.value #>> '{}' from public.app_config c where c.key = p_key
$$;

-- Public subset of app_config (view runs with its owner's rights; only is_public rows).
create view public.public_app_config
with (security_barrier = true)
as
  select c.key, c.value
  from public.app_config c
  where c.is_public;

comment on view public.public_app_config is
  'Read-only client view of the app_config keys marked is_public.';

-- ---------------------------------------------------------------------------
-- jobs: Postgres-backed queue consumed by the worker (service role only).
-- ---------------------------------------------------------------------------
create table public.jobs (
  id           bigint generated always as identity primary key,
  kind         text not null check (kind ~ '^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$'),
  payload      jsonb not null default '{}'::jsonb,
  status       public.job_status not null default 'queued',
  run_at       timestamptz not null default now(),
  attempts     integer not null default 0 check (attempts >= 0),
  max_attempts integer not null default 5 check (max_attempts >= 1),
  locked_at    timestamptz,
  locked_by    text,
  last_error   text,
  dedupe_key   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  finished_at  timestamptz
);
alter table public.jobs enable row level security;

create index jobs_claim_idx on public.jobs (run_at, id) where status = 'queued';
create index jobs_running_idx on public.jobs (locked_at) where status = 'running';
create index jobs_kind_idx on public.jobs (kind, status);
-- At most one *queued* job per dedupe key (running jobs do not block a new one).
create unique index jobs_dedupe_queued_idx on public.jobs (dedupe_key) where status = 'queued' and dedupe_key is not null;

create trigger jobs_touch before update on public.jobs
  for each row execute function private.touch_updated_at();

-- Enqueue a job inside the caller's transaction. With a dedupe key, an already
-- queued job with the same key is reused (its run_at moves to the earlier time).
create function private.enqueue(
  p_kind text,
  p_payload jsonb,
  p_dedupe_key text default null,
  p_run_at timestamptz default now(),
  p_max_attempts integer default 5
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id bigint;
begin
  if p_dedupe_key is null then
    insert into public.jobs (kind, payload, run_at, max_attempts)
    values (p_kind, coalesce(p_payload, '{}'::jsonb), coalesce(p_run_at, now()), p_max_attempts)
    returning id into v_id;
  else
    insert into public.jobs (kind, payload, run_at, max_attempts, dedupe_key)
    values (p_kind, coalesce(p_payload, '{}'::jsonb), coalesce(p_run_at, now()), p_max_attempts, p_dedupe_key)
    on conflict (dedupe_key) where status = 'queued' and dedupe_key is not null
    do update set run_at = least(public.jobs.run_at, excluded.run_at),
                  payload = excluded.payload
    returning id into v_id;
  end if;
  return v_id;
end;
$$;

-- storage.delete payload: {"bucket":"media","paths":[...exact object names...],"prefixes":[...folder prefixes ending in "/"...]}
create function private.enqueue_storage_delete(p_paths text[], p_prefixes text[] default null)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_paths text[];
  v_prefixes text[];
begin
  select coalesce(array_agg(distinct x order by x), '{}') into v_paths
  from unnest(coalesce(p_paths, '{}'::text[])) as t(x) where x is not null;
  select coalesce(array_agg(distinct x order by x), '{}') into v_prefixes
  from unnest(coalesce(p_prefixes, '{}'::text[])) as t(x) where x is not null;
  if cardinality(v_paths) = 0 and cardinality(v_prefixes) = 0 then
    return null;
  end if;
  return private.enqueue(
    'storage.delete',
    jsonb_build_object('bucket', 'media', 'paths', to_jsonb(v_paths), 'prefixes', to_jsonb(v_prefixes)),
    null, now(), 10);
end;
$$;

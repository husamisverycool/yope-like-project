-- =============================================================================
-- 0012 worker configuration and worker-owned helpers (backend/worker).
--
--   * app_config defaults the worker needs: the default waking window and the
--     collage layout option;
--   * collages: delete the whole composed folder g/<group>/collages/<id>/ when a
--     collage row goes away (the worker writes more objects than the three paths
--     stored on the row: one master PNG per page and the extra pages);
--   * RevenueCat webhook: idempotent entitlement updates keyed on the event id
--     (private.revenuecat_events + public.apply_revenuecat_event, service role only).
--
-- weekly_recap_local_time is left as 0001 set it (NULL: recaps stay off until it is
-- sourced; docs/API.md section 11).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Default waking window.
-- BeReal publishes no hours; night is excluded (help.bereal.com article
-- 15416869159197); the only observed sample is ≈09:48–21:12 Central
-- (kapwing.com/resources/when-is-bereal-notification-time); see
-- design/research/bereal.md §1 — owner may change.
-- ---------------------------------------------------------------------------
update public.app_config
   set value = '"09:48"',
       description = 'Default local start of a group''s waking window ("HH:MM"). BeReal publishes no hours; night is excluded (help.bereal.com article 15416869159197); the only observed sample is about 09:48-21:12 Central (kapwing.com/resources/when-is-bereal-notification-time); see design/research/bereal.md section 1. Owner may change.'
 where key = 'default_waking_start';

update public.app_config
   set value = '"21:12"',
       description = 'Default local end of a group''s waking window ("HH:MM"). BeReal publishes no hours; night is excluded (help.bereal.com article 15416869159197); the only observed sample is about 09:48-21:12 Central (kapwing.com/resources/when-is-bereal-notification-time); see design/research/bereal.md section 1. Owner may change.'
 where key = 'default_waking_end';

-- ---------------------------------------------------------------------------
-- Collage layout option used for new collages (A, B or C).
-- Fallback pending the owner's choice, see design/collage-options/README.md.
-- ---------------------------------------------------------------------------
insert into public.app_config (key, value, is_public, description) values
  ('collage_option', '"B"', false,
   'Same-moment collage layout option (A, B or C) for new collages; existing collages keep theirs when recomposed. B is the fallback pending the owner''s choice, see design/collage-options/README.md.')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- Composed collage folder cleanup. 0004 deletes the three stored paths; the
-- worker also writes master-<n>.png and display-/share-<n>.jpg pages under
-- g/<group>/collages/<collage>/<version>/, so the whole folder goes.
-- (When the group itself is deleted, 0004 already deletes g/<group>/.)
-- ---------------------------------------------------------------------------
create function private.worker_on_collage_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if private.group_alive(old.group_id) then
    perform private.enqueue_storage_delete(null,
      array['g/' || old.group_id::text || '/collages/' || old.id::text || '/']);
  end if;
  return null;
end;
$$;
create trigger collages_after_delete_folder after delete on public.collages
  for each row execute function private.worker_on_collage_deleted();

-- ---------------------------------------------------------------------------
-- RevenueCat webhook (POST /webhooks/revenuecat on the worker).
-- Deliveries are at-least-once and may arrive out of order
-- (https://www.revenuecat.com/docs/integrations/webhooks), so:
--   * an event id is applied at most once (primary key);
--   * an event older than the newest one already applied for that user does not
--     overwrite the entitlement.
-- ---------------------------------------------------------------------------
create table private.revenuecat_events (
  event_id    text primary key check (char_length(event_id) between 1 and 200),
  user_id     uuid,
  event_type  text not null,
  event_at    timestamptz not null,
  expires_at  timestamptz,
  applied     boolean not null,
  received_at timestamptz not null default now()
);
create index revenuecat_events_user_idx on private.revenuecat_events (user_id, event_at desc);
alter table private.revenuecat_events enable row level security;
revoke all on private.revenuecat_events from public, anon, authenticated;
grant select, insert on private.revenuecat_events to service_role;

-- Returns 'applied' | 'duplicate' | 'stale' | 'ignored' (user unknown or the event
-- carries no entitlement change). p_active = false means "expire now" (EXPIRATION,
-- TRANSFER source); otherwise p_expires_at is the new expiry (NULL = no expiry).
create function public.apply_revenuecat_event(
  p_event_id text,
  p_user_id uuid,
  p_event_type text,
  p_event_at timestamptz,
  p_expires_at timestamptz,
  p_change boolean default true
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_newest timestamptz;
  v_known boolean;
begin
  if p_event_id is null or p_event_type is null or p_event_at is null then
    raise exception 'invalid_argument' using errcode = 'PT400';
  end if;
  if exists (select 1 from private.revenuecat_events e where e.event_id = p_event_id) then
    return 'duplicate';
  end if;

  v_known := p_user_id is not null and exists (select 1 from public.profiles p where p.id = p_user_id);
  if not v_known or not coalesce(p_change, true) then
    insert into private.revenuecat_events (event_id, user_id, event_type, event_at, expires_at, applied)
    values (p_event_id, case when v_known then p_user_id end, p_event_type, p_event_at, p_expires_at, false)
    on conflict (event_id) do nothing;
    return case when found then 'ignored' else 'duplicate' end;
  end if;

  -- serialize per user so two deliveries cannot interleave
  perform pg_advisory_xact_lock(hashtextextended('revenuecat:' || p_user_id::text, 0));
  select max(e.event_at) into v_newest
    from private.revenuecat_events e where e.user_id = p_user_id and e.applied;

  insert into private.revenuecat_events (event_id, user_id, event_type, event_at, expires_at, applied)
  values (p_event_id, p_user_id, p_event_type, p_event_at, p_expires_at,
          v_newest is null or p_event_at >= v_newest)
  on conflict (event_id) do nothing;
  if not found then
    return 'duplicate';
  end if;
  if v_newest is not null and p_event_at < v_newest then
    return 'stale';
  end if;

  insert into public.entitlements (user_id, entitlement, expires_at, source)
  values (p_user_id, 'premium', p_expires_at, 'revenuecat')
  on conflict (user_id, entitlement) do update
    set expires_at = excluded.expires_at, source = excluded.source;
  return 'applied';
end;
$$;

revoke all on function public.apply_revenuecat_event(text, uuid, text, timestamptz, timestamptz, boolean)
  from public, anon, authenticated;
grant execute on function public.apply_revenuecat_event(text, uuid, text, timestamptz, timestamptz, boolean)
  to service_role;

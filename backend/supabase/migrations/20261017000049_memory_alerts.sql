-- =============================================================================
-- 0049 the opt-in memory notification: only when there is a memory, at most once a day (owner decision 34,
-- docs/RESEARCH_FEATURES_2026-10-17.md #15).
--
-- Mechanics: Google Photos memories notifications (opt-in per kind, support.google.com/photos/answer/9454489);
-- Timehop's daily alert (App Store id569077959); Retro's own "On This Week" reminder (references: Retro APK
-- on_this_week_notification_*; its count is not copied — tenet: no counts).
--   * notification_settings.memories (off by default) and .memory_time_zone; set_memory_alerts(p_on, p_time_zone);
--   * due_memory_alerts(p_now) (worker scheduler, every minute): for each person with memories on whose local time
--     has reached app_config memory_alert_local_time ("09:48", the start of the default waking window, BeReal's
--     sample — design/research/bereal.md §1) and who was not looked at yet that local day: their newest memory of
--     the day — their own or self-tagged photo of this month and day in an earlier year, one they can still see,
--     not hidden (memory_hides) — and, when there is one, a push.memory job. Nothing is sent on a day without a
--     memory; each person is looked at once per local day (private.memory_alert_days).
-- =============================================================================

insert into public.app_config (key, value, is_public, description) values
  ('memory_alert_local_time', '"09:48"', false,
   'Local time ("HH:MM") from which the memory notification goes out (the start of the default waking window, default_waking_start: BeReal sample, design/research/bereal.md section 1). NULL: no memory notification is sent.')
on conflict (key) do nothing;

alter table public.notification_settings add column memories boolean not null default false;
alter table public.notification_settings add column memory_time_zone text;
alter table public.notification_settings add constraint notification_settings_memory_zone
  check (not memories or memory_time_zone is not null);

-- The local days each person was looked at (whether a memory was found or not). Service role only.
create table private.memory_alert_days (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  local_date date not null,
  post_id    uuid,
  primary key (user_id, local_date)
);

create function public.set_memory_alerts(p_on boolean, p_time_zone text default null)
returns public.notification_settings
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_row public.notification_settings;
begin
  if p_on is null then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_on';
  end if;
  if p_on and (p_time_zone is null or not private.is_valid_time_zone(p_time_zone)) then
    raise exception 'invalid_time_zone' using errcode = 'PT400';
  end if;
  if p_time_zone is not null and not private.is_valid_time_zone(p_time_zone) then
    raise exception 'invalid_time_zone' using errcode = 'PT400';
  end if;
  insert into public.notification_settings (user_id, memories, memory_time_zone)
  values (v_uid, p_on, p_time_zone)
  on conflict (user_id) do update
    set memories = excluded.memories,
        memory_time_zone = coalesce(excluded.memory_time_zone, public.notification_settings.memory_time_zone)
  returning * into v_row;
  return v_row;
end;
$$;

-- The person's memory for local day p_day in zone p_zone: their own or self-tagged photo of this month and day in an
-- earlier year, that they can see and have not hidden; newest year first.
create function private.memory_of_day(p_user uuid, p_day date, p_zone text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
    from public.posts p
   where (p.author_id = p_user
          or exists (select 1 from public.post_tags t where t.post_id = p.id and t.user_id = p_user))
     and extract(month from (p.created_at at time zone p_zone)) = extract(month from p_day)
     and extract(day from (p.created_at at time zone p_zone)) = extract(day from p_day)
     and extract(year from (p.created_at at time zone p_zone)) < extract(year from p_day)
     and private.user_can_see_post(p_user, p.id)
     and not private.memory_hidden(p_user, p.media_id, (p.created_at at time zone p_zone)::date)
   order by p.created_at desc, p.id desc
   limit 1
$$;
revoke all on function private.memory_of_day(uuid, date, text) from public;

create function public.due_memory_alerts(p_now timestamptz default now())
returns table (user_id uuid, post_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := coalesce(p_now, now());
  v_at time := private.config_text('memory_alert_local_time')::time;
  s record;
  v_day date;
  v_post uuid;
begin
  if v_at is null then
    return;
  end if;
  for s in
    select n.user_id, n.memory_time_zone as zone
      from public.notification_settings n
     where n.memories and n.memory_time_zone is not null
       and (v_now at time zone n.memory_time_zone)::time >= v_at
       and not exists (select 1 from private.memory_alert_days d
                        where d.user_id = n.user_id
                          and d.local_date = (v_now at time zone n.memory_time_zone)::date)
  loop
    v_day := (v_now at time zone s.zone)::date;
    v_post := private.memory_of_day(s.user_id, v_day, s.zone);
    insert into private.memory_alert_days (user_id, local_date, post_id) values (s.user_id, v_day, v_post)
    on conflict do nothing;
    if found and v_post is not null then
      perform private.enqueue('push.memory',
        jsonb_build_object('user_id', s.user_id, 'post_id', v_post, 'local_date', v_day),
        'push.memory:' || s.user_id || ':' || v_day);
      user_id := s.user_id;
      post_id := v_post;
      return next;
    end if;
  end loop;
end;
$$;

revoke all on function public.set_memory_alerts(boolean, text), public.due_memory_alerts(timestamptz) from public, anon;
grant execute on function public.set_memory_alerts(boolean, text) to authenticated;
grant execute on function public.due_memory_alerts(timestamptz) to service_role;

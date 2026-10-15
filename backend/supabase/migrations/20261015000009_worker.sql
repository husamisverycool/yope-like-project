-- =============================================================================
-- 0009 worker + scheduler helpers. SERVICE ROLE ONLY (no client grants).
--   enqueue_job, claim_jobs (FOR UPDATE SKIP LOCKED), complete_job, fail_job
--   schedule_daily_invitations, due_weekly_recaps, due_birthday_requests,
--   due_tributes, due_year_stories
-- =============================================================================

create function public.enqueue_job(
  p_kind text,
  p_payload jsonb default '{}'::jsonb,
  p_run_at timestamptz default null,
  p_max_attempts integer default 5,
  p_dedupe_key text default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_kind is null or p_kind !~ '^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$' then
    raise exception 'invalid_kind' using errcode = 'PT400', detail = 'e.g. "push.new_post"';
  end if;
  if coalesce(p_max_attempts, 5) < 1 then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_max_attempts';
  end if;
  return private.enqueue(p_kind, p_payload, p_dedupe_key, coalesce(p_run_at, now()), coalesce(p_max_attempts, 5));
end;
$$;

-- Claims up to p_limit due jobs. Jobs whose lock is older than
-- job_lock_timeout_seconds are re-claimed (or failed when out of attempts).
create function public.claim_jobs(p_worker_id text, p_kinds text[] default null, p_limit integer default 10)
returns setof public.jobs
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_timeout interval := make_interval(secs => coalesce(private.config_int('job_lock_timeout_seconds'), 600));
begin
  if p_worker_id is null or p_worker_id = '' then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_worker_id';
  end if;

  update public.jobs j
     set status = 'failed', finished_at = now(), locked_at = null, locked_by = null,
         last_error = coalesce(j.last_error || E'\n', '') || 'lock expired on final attempt'
   where j.status = 'running' and j.locked_at < now() - v_timeout and j.attempts >= j.max_attempts;

  return query
  with candidates as (
    select j.id
    from public.jobs j
    where ((j.status = 'queued' and j.run_at <= now())
           or (j.status = 'running' and j.locked_at < now() - v_timeout))
      and (p_kinds is null or j.kind = any (p_kinds))
    order by j.run_at, j.id
    limit least(greatest(coalesce(p_limit, 10), 1), 100)
    for update skip locked
  )
  update public.jobs j
     set status = 'running', locked_at = now(), locked_by = p_worker_id, attempts = j.attempts + 1
    from candidates c
   where j.id = c.id
  returning j.*;
end;
$$;

create function public.complete_job(p_job_id bigint, p_worker_id text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.jobs j
     set status = 'done', finished_at = now(), locked_at = null, last_error = null
   where j.id = p_job_id and j.status = 'running' and j.locked_by = p_worker_id;
  return found;
end;
$$;

-- Retry with exponential backoff, or fail permanently (p_retry = false or out of
-- attempts). If a newer queued job with the same dedupe key exists, this one is
-- cancelled instead of requeued (the newer one does the work).
create function public.fail_job(p_job_id bigint, p_worker_id text, p_error text, p_retry boolean default true)
returns public.jobs
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs;
  v_base integer := coalesce(private.config_int('job_backoff_base_seconds'), 30);
  v_max integer := coalesce(private.config_int('job_backoff_max_seconds'), 3600);
  v_delay double precision;
begin
  select * into v_job from public.jobs j
   where j.id = p_job_id and j.status = 'running' and j.locked_by = p_worker_id
   for update;
  if not found then
    raise exception 'job_not_found' using errcode = 'PT404';
  end if;

  if not coalesce(p_retry, true) or v_job.attempts >= v_job.max_attempts then
    update public.jobs j set status = 'failed', finished_at = now(), locked_at = null, last_error = p_error
     where j.id = p_job_id returning * into v_job;
  elsif v_job.dedupe_key is not null and exists (
      select 1 from public.jobs o where o.dedupe_key = v_job.dedupe_key and o.status = 'queued') then
    update public.jobs j set status = 'cancelled', finished_at = now(), locked_at = null, last_error = p_error
     where j.id = p_job_id returning * into v_job;
  else
    v_delay := least(v_max::double precision, v_base * power(2, greatest(v_job.attempts - 1, 0)));
    update public.jobs j
       set status = 'queued', locked_at = null, locked_by = null, last_error = p_error,
           run_at = now() + make_interval(secs => v_delay)
     where j.id = p_job_id returning * into v_job;
  end if;
  return v_job;
end;
$$;

-- ---------------------------------------------------------------------------
-- Daily invitations
-- ---------------------------------------------------------------------------

-- Deterministic pseudo-random fraction in [0, 1) from (group, local date).
create function private.invitation_fraction(p_group uuid, p_local_date date)
returns double precision
language sql
immutable
set search_path = ''
as $$
  select ((('x' || substr(md5(p_group::text || ':' || p_local_date::text), 1, 15))::bit(60)::bigint)::double precision
          / 1152921504606846976::double precision)
$$;

-- fires_at for a group on a local date: a deterministic instant in
-- [window start, window end - invitation window) so the whole countdown happens
-- inside the waking window. Windows that end at/before they start wrap past midnight.
-- Computed on absolute instants, so DST days (23 h / 25 h) stay inside the window.
create function private.invitation_fires_at(
  p_group uuid, p_local_date date, p_tz text, p_start time, p_end time, p_window_seconds integer
)
returns timestamptz
language plpgsql
stable
set search_path = ''
as $$
declare
  v_start timestamptz := (p_local_date + p_start) at time zone p_tz;
  v_end timestamptz := (p_local_date + p_end + case when p_end <= p_start then interval '1 day' else interval '0' end)
                       at time zone p_tz;
  v_span double precision := extract(epoch from (v_end - v_start)) - p_window_seconds;
begin
  if v_span <= 0 then
    return v_start;
  end if;
  return v_start + make_interval(secs => floor(private.invitation_fraction(p_group, p_local_date) * v_span));
end;
$$;

-- Schedules the invitation of local calendar date p_for_utc_date for every
-- non-paused group with members (call it for today and tomorrow, UTC; that covers
-- every time zone's "today"). Idempotent per (group, local_date): existing rows are
-- returned unchanged with created = false. Groups are skipped (with a reason) when
-- no waking window is known or the instant has already passed.
-- On creation it enqueues invitation.fire (run_at = fires_at) and collage.compose
-- (run_at = closes_at).
create function public.schedule_daily_invitations(p_for_utc_date date)
returns table (
  group_id uuid,
  local_date date,
  invitation_id uuid,
  fires_at timestamptz,
  closes_at timestamptz,
  created boolean,
  skipped_reason text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_window integer := private.config_int('invitation_window_seconds');
  v_def_start time := private.config_text('default_waking_start')::time;
  v_def_end time := private.config_text('default_waking_end')::time;
  g record;
  v_existing public.daily_invitations;
  v_start time;
  v_end time;
  v_fires timestamptz;
  v_id uuid;
begin
  if p_for_utc_date is null then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_for_utc_date';
  end if;
  if v_window is null or v_window <= 0 then
    raise exception 'config_missing' using errcode = 'PT503', detail = 'invitation_window_seconds';
  end if;

  for g in
    select gr.id, gr.time_zone, gr.waking_start, gr.waking_end
    from public.groups gr
    where not gr.invitation_paused
      and exists (select 1 from public.group_members m where m.group_id = gr.id)
    order by gr.id
  loop
    select * into v_existing from public.daily_invitations d
     where d.group_id = g.id and d.local_date = p_for_utc_date;
    if found then
      group_id := g.id; local_date := p_for_utc_date; invitation_id := v_existing.id;
      fires_at := v_existing.fires_at; closes_at := v_existing.closes_at;
      created := false; skipped_reason := null;
      return next;
      continue;
    end if;

    v_start := coalesce(g.waking_start, v_def_start);
    v_end := case when g.waking_start is not null then g.waking_end else v_def_end end;
    if v_start is null or v_end is null or v_start = v_end then
      group_id := g.id; local_date := p_for_utc_date; invitation_id := null;
      fires_at := null; closes_at := null; created := false; skipped_reason := 'waking_window_not_set';
      return next;
      continue;
    end if;

    v_fires := private.invitation_fires_at(g.id, p_for_utc_date, g.time_zone, v_start, v_end, v_window);
    if v_fires <= now() then
      group_id := g.id; local_date := p_for_utc_date; invitation_id := null;
      fires_at := v_fires; closes_at := v_fires + make_interval(secs => v_window);
      created := false; skipped_reason := 'window_passed';
      return next;
      continue;
    end if;

    insert into public.daily_invitations (group_id, local_date, fires_at, closes_at)
    values (g.id, p_for_utc_date, v_fires, v_fires + make_interval(secs => v_window))
    on conflict on constraint daily_invitations_group_id_local_date_key do nothing
    returning id into v_id;
    if v_id is null then
      select * into v_existing from public.daily_invitations d
       where d.group_id = g.id and d.local_date = p_for_utc_date;
      group_id := g.id; local_date := p_for_utc_date; invitation_id := v_existing.id;
      fires_at := v_existing.fires_at; closes_at := v_existing.closes_at; created := false; skipped_reason := null;
      return next;
      continue;
    end if;

    perform private.enqueue('invitation.fire',
      jsonb_build_object('invitation_id', v_id, 'group_id', g.id),
      'invitation.fire:' || v_id::text, v_fires);
    perform private.enqueue('collage.compose',
      jsonb_build_object('invitation_id', v_id, 'group_id', g.id),
      'collage.compose:' || v_id::text, v_fires + make_interval(secs => v_window));

    group_id := g.id; local_date := p_for_utc_date; invitation_id := v_id;
    fires_at := v_fires; closes_at := v_fires + make_interval(secs => v_window);
    created := true; skipped_reason := null;
    return next;
    v_id := null;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Weekly recaps: for each group whose most recent recap moment (weekly_recap_isodow
-- at weekly_recap_local_time, group time zone) has passed, create the recap of the
-- week that ended on or before that day — only if the group posted that week.
-- Returns the recaps created by this call (each with a recap.generate job).
create function public.due_weekly_recaps(p_now timestamptz default now())
returns setof public.weekly_recaps
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_time time := private.config_text('weekly_recap_local_time')::time;
  v_recap_dow integer := coalesce(private.config_int('weekly_recap_isodow'), 7);
  v_week_dow integer := coalesce(private.config_int('week_start_isodow'), 1);
  v_last_dow integer;
  g record;
  v_local timestamp;
  v_day date;
  v_last_day date;
  v_week_start date;
  v_row public.weekly_recaps;
begin
  if v_time is null then
    raise exception 'config_missing' using errcode = 'PT503', detail = 'weekly_recap_local_time';
  end if;
  v_last_dow := ((v_week_dow + 5) % 7) + 1;

  for g in select gr.id, gr.time_zone from public.groups gr order by gr.id loop
    v_local := coalesce(p_now, now()) at time zone g.time_zone;
    v_day := v_local::date - ((extract(isodow from v_local)::integer - v_recap_dow + 7) % 7);
    if v_day + v_time > v_local then
      v_day := v_day - 7;
    end if;
    v_last_day := v_day - ((extract(isodow from v_day)::integer - v_last_dow + 7) % 7);
    v_week_start := v_last_day - 6;

    if not exists (
      select 1 from public.posts p
      where p.group_id = g.id
        and p.created_at >= (v_week_start::timestamp at time zone g.time_zone)
        and p.created_at < ((v_week_start + 7)::timestamp at time zone g.time_zone)) then
      continue;
    end if;

    insert into public.weekly_recaps (group_id, week_start) values (g.id, v_week_start)
    on conflict (group_id, week_start) do nothing
    returning * into v_row;
    if found then
      perform private.enqueue('recap.generate',
        jsonb_build_object('recap_id', v_row.id, 'group_id', g.id, 'week_start', v_week_start),
        'recap.generate:' || v_row.id::text);
      return next v_row;
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Birthday requests: birthday_request_lead_days before a member's birthday (group
-- local date), for members who opted in, in every group with at least one other
-- member. The honoree is never in the audience (RLS + push.birthday_request
-- recipients = members except the honoree and anyone with a block with them).
-- Feb 29 birthdays fall on Feb 28 in non-leap years.
create function private.next_birthday(p_birthday date, p_from date)
returns date
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_year integer := extract(year from p_from)::integer;
  v_candidate date;
begin
  for i in 0..1 loop
    v_candidate := case
      when extract(month from p_birthday) = 2 and extract(day from p_birthday) = 29
           and not (((v_year + i) % 4 = 0 and (v_year + i) % 100 <> 0) or (v_year + i) % 400 = 0)
        then make_date(v_year + i, 2, 28)
      else make_date(v_year + i, extract(month from p_birthday)::integer, extract(day from p_birthday)::integer)
    end;
    if v_candidate >= p_from then
      return v_candidate;
    end if;
  end loop;
  return v_candidate;
end;
$$;

create function public.due_birthday_requests(p_now timestamptz default now())
returns setof public.tribute_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lead integer := coalesce(private.config_int('birthday_request_lead_days'), 7);
  r record;
  v_today date;
  v_next date;
  v_row public.tribute_requests;
begin
  for r in
    select m.group_id, m.user_id, pp.birthday, g.time_zone
    from public.group_members m
    join public.profile_private pp on pp.user_id = m.user_id and pp.birthday_opt_in and pp.birthday is not null
    join public.groups g on g.id = m.group_id
    where exists (select 1 from public.group_members o
                  where o.group_id = m.group_id and o.user_id <> m.user_id
                    and not private.is_blocked_between(o.user_id, m.user_id))
    order by m.group_id, m.user_id
  loop
    v_today := (coalesce(p_now, now()) at time zone r.time_zone)::date;
    v_next := private.next_birthday(r.birthday, v_today);
    if v_next <= v_today or v_next - v_today > v_lead then
      continue;
    end if;
    insert into public.tribute_requests (group_id, honoree_id, birthday_date, due_at)
    values (r.group_id, r.user_id, v_next, v_next::timestamp at time zone r.time_zone)
    on conflict (group_id, honoree_id, birthday_date) do nothing
    returning * into v_row;
    if found then
      perform private.enqueue('push.birthday_request',
        jsonb_build_object('request_id', v_row.id, 'group_id', v_row.group_id, 'honoree_id', v_row.honoree_id),
        'push.birthday_request:' || v_row.id::text);
      return next v_row;
    end if;
  end loop;
end;
$$;

-- Requests whose due time has passed: closed; a tribute row + tribute.render job
-- when there is at least one contribution (no empty tribute is ever delivered).
create function public.due_tributes(p_now timestamptz default now())
returns setof public.tributes
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.tribute_requests;
  v_row public.tributes;
begin
  for r in
    select * from public.tribute_requests q
    where q.closed_at is null and q.due_at <= coalesce(p_now, now())
    order by q.due_at, q.id
    for update skip locked
  loop
    update public.tribute_requests q set closed_at = now() where q.id = r.id;
    if exists (select 1 from public.tribute_contributions c where c.request_id = r.id) then
      insert into public.tributes (request_id, group_id, honoree_id)
      values (r.id, r.group_id, r.honoree_id)
      on conflict (request_id) do nothing
      returning * into v_row;
      if found then
        perform private.enqueue('tribute.render',
          jsonb_build_object('tribute_id', v_row.id, 'request_id', r.id, 'group_id', r.group_id),
          'tribute.render:' || v_row.id::text);
        return next v_row;
      end if;
    end if;
  end loop;
end;
$$;

-- Year stories: from year_story_release_month_day (December) local time, for every
-- group that posted that year. Returns the stories created by this call.
create function public.due_year_stories(p_now timestamptz default now())
returns setof public.year_stories
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_md text := coalesce(private.config_text('year_story_release_month_day'), '12-01');
  v_month integer := split_part(v_md, '-', 1)::integer;
  v_day integer := split_part(v_md, '-', 2)::integer;
  g record;
  v_local timestamp;
  v_year integer;
  v_row public.year_stories;
begin
  if v_month <> 12 then
    raise exception 'config_invalid' using errcode = 'PT503', detail = 'year_story_release_month_day must be in December';
  end if;
  for g in select gr.id, gr.time_zone from public.groups gr order by gr.id loop
    v_local := coalesce(p_now, now()) at time zone g.time_zone;
    v_year := extract(year from v_local)::integer;
    if v_local < make_date(v_year, v_month, v_day)::timestamp then
      continue;
    end if;
    if not exists (
      select 1 from public.posts p
      where p.group_id = g.id
        and p.created_at >= (make_date(v_year, 1, 1)::timestamp at time zone g.time_zone)
        and p.created_at < (make_date(v_year + 1, 1, 1)::timestamp at time zone g.time_zone)) then
      continue;
    end if;
    insert into public.year_stories (group_id, year) values (g.id, v_year)
    on conflict (group_id, year) do nothing
    returning * into v_row;
    if found then
      perform private.enqueue('year.compute',
        jsonb_build_object('year_story_id', v_row.id, 'group_id', g.id, 'year', v_year),
        'year.compute:' || v_row.id::text);
      return next v_row;
    end if;
  end loop;
end;
$$;

-- service role only
revoke all on function
  public.enqueue_job(text, jsonb, timestamptz, integer, text),
  public.claim_jobs(text, text[], integer),
  public.complete_job(bigint, text),
  public.fail_job(bigint, text, text, boolean),
  public.schedule_daily_invitations(date),
  public.due_weekly_recaps(timestamptz),
  public.due_birthday_requests(timestamptz),
  public.due_tributes(timestamptz),
  public.due_year_stories(timestamptz)
from public, anon, authenticated;
grant execute on function
  public.enqueue_job(text, jsonb, timestamptz, integer, text),
  public.claim_jobs(text, text[], integer),
  public.complete_job(bigint, text),
  public.fail_job(bigint, text, text, boolean),
  public.schedule_daily_invitations(date),
  public.due_weekly_recaps(timestamptz),
  public.due_birthday_requests(timestamptz),
  public.due_tributes(timestamptz),
  public.due_year_stories(timestamptz)
to service_role;

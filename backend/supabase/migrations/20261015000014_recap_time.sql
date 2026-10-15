-- =============================================================================
-- 0014 weekly recap moment without a configured time.
--
-- Until now due_weekly_recaps failed closed (config_missing) while
-- app_config.weekly_recap_local_time was NULL, so recaps never ran. No reference app
-- publishes a recap hour, but two sourced facts fix a moment without inventing one:
--   * the week: Retro organizes weeks Monday-Sunday (week_start_isodow = 1, recap day
--     weekly_recap_isodow = 7, docs/SURFACES.md week.recap "Sunday recap");
--   * the waking day: the group's own waking window (groups.waking_start/_end, set by its
--     admins), else the BeReal-sourced default window (app_config.default_waking_end,
--     migration 0012, design/research/bereal.md section 1).
-- So the recap is assembled at the last waking moment of the week: the end of the group's
-- waking window on the recap day, in the group's time zone. A window that wraps past
-- midnight (end <= start) ends early on the following day, which is still the end of the
-- recap day's waking period. weekly_recap_local_time stays as an explicit override
-- (owner decision, docs/API.md section 12).
--
-- DST: the moment is compared as a local wall-clock time in the group's zone, so it is the
-- same local time on 23-hour and 25-hour days; a wall time skipped by a spring-forward gap
-- counts as passed once the clock is past it.
-- A group whose window is unknown (no own hours, default NULL, no override) gets no recap.
-- =============================================================================

create or replace function public.due_weekly_recaps(p_now timestamptz default now())
returns setof public.weekly_recaps
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_override time := private.config_text('weekly_recap_local_time')::time;
  v_def_start time := private.config_text('default_waking_start')::time;
  v_def_end time := private.config_text('default_waking_end')::time;
  v_recap_dow integer := coalesce(private.config_int('weekly_recap_isodow'), 7);
  v_week_dow integer := coalesce(private.config_int('week_start_isodow'), 1);
  v_last_dow integer;
  g record;
  v_start time;
  v_at time;
  v_after interval;
  v_local timestamp;
  v_day date;
  v_last_day date;
  v_week_start date;
  v_row public.weekly_recaps;
begin
  v_last_dow := ((v_week_dow + 5) % 7) + 1;

  for g in select gr.id, gr.time_zone, gr.waking_start, gr.waking_end from public.groups gr order by gr.id loop
    -- the group's recap moment (local time of day, + 1 day when the waking window wraps)
    if v_override is not null then
      v_at := v_override;
      v_after := interval '0';
    else
      v_start := coalesce(g.waking_start, v_def_start);
      v_at := case when g.waking_start is not null then g.waking_end else v_def_end end;
      if v_at is null then
        continue; -- no known waking window: no recap (fails closed for this group)
      end if;
      v_after := case when v_start is not null and v_at <= v_start then interval '1 day' else interval '0' end;
    end if;

    v_local := coalesce(p_now, now()) at time zone g.time_zone;
    -- the most recent recap day whose moment has passed
    v_day := v_local::date - ((extract(isodow from v_local)::integer - v_recap_dow + 7) % 7);
    if v_day + v_at + v_after > v_local then
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

update public.app_config
   set description = 'Optional override (JSON string "HH:MM", group-local) of the weekly recap moment on weekly_recap_isodow. NULL (default): each group''s recap is assembled at the end of its waking window on the recap day (its own hours, else default_waking_end), i.e. the last waking moment of its week (migration 0014). Owner may set an explicit time.'
 where key = 'weekly_recap_local_time';

-- (create or replace keeps the existing grants: service role only)

-- =============================================================================
-- 0045 jump to a date in the group's history (owner decision 34; docs/RESEARCH_FEATURES_2026-10-17.md #21).
-- Mechanics reference: BeReal's Memories calendar — a month grid where only the days with a memory can be opened
-- (https://help.bereal.com/hc/en-us/articles/7531349180829, accessed 2026-10-17).
--
-- group_history_months(p_group_id): the months (group time zone) that hold something of the group's history as
-- group_history_weeks lists it (0033): photos by when the group could first see them (visible_at, 0027; blocked authors
-- left out) and the ready same-moment collages by their invitation day; free_history_days applies the same way.
-- Per month, `days` lists the days with something (for a calendar's selectable days) and `newest_week` is the newest
-- history week that touches the month: the apps jump with group_history_weeks(p_before_week => newest_week + 7) and
-- the first week returned is that one. Newest month first.
-- =============================================================================

create function public.group_history_months(p_group_id uuid)
returns table (month date, days date[], newest_week date)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_tz text;
  v_dow integer := coalesce(private.config_int('week_start_isodow'), 1);
  v_free integer := private.config_int('free_history_days');
  v_cutoff timestamptz;
begin
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  select g.time_zone into v_tz from public.groups g where g.id = p_group_id;
  if v_free is not null and not private.has_premium(v_uid) then
    v_cutoff := now() - make_interval(days => v_free);
  end if;

  return query
  with days as (
    select (p.visible_at at time zone v_tz)::date as d
      from public.posts p
     where p.group_id = p_group_id
       and p.author_id not in (select private.blocked_ids())
       and (v_cutoff is null or p.visible_at >= v_cutoff)
    union
    select d.local_date
      from public.collages c
      join public.daily_invitations d on d.id = c.invitation_id
     where c.group_id = p_group_id
       and c.status = 'ready'
       and (v_cutoff is null or d.fires_at >= v_cutoff)
  )
  select date_trunc('month', x.d)::date,
         array_agg(x.d order by x.d),
         private.week_start_of(max(x.d), v_dow)
    from days x
   group by date_trunc('month', x.d)
   order by 1 desc;
end;
$$;

revoke all on function public.group_history_months(uuid) from public, anon;
grant execute on function public.group_history_months(uuid) to authenticated;

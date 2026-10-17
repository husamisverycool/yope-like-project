-- =============================================================================
-- 0027 a photo belongs to the week (and year) in which the group could first see it.
--
-- An overnight photo (0020) keeps the time it was taken (created_at) and joins the group at its reveal
-- (revealed_at, 09:00 group-local). Taken on Sunday night, it becomes a post on Monday morning: after
-- Sunday's recap was assembled, yet dated in that week, so no recap ever held it and the week history
-- filed it under a week that had already been looked back on. Weeks now follow when the photo became
-- visible: posts.visible_at = coalesce(revealed_at, created_at) (a stored generated column, the same
-- as created_at for every photo that did not develop overnight).
--
-- Week queries moved to visible_at: group_history_weeks (buckets, order, the free_history_days
-- window), due_weekly_recaps (does the week have photos), update_recap (which posts belong to the
-- recap's week), wall (order, paging and the week sections clients draw from it), due_year_stories
-- (does the year have photos). The worker's recap.generate and year.compute read visible_at too.
-- on_this_day keeps the day the photo was taken (created_at): it resurfaces the date a moment
-- happened, as Retro's Rewind resurfaces "this week" by capture date (design/surfaces/onthisday.md),
-- and no week boundary is involved.
-- =============================================================================

alter table public.posts
  add column visible_at timestamptz generated always as (coalesce(revealed_at, created_at)) stored;
create index posts_group_visible_idx on public.posts (group_id, visible_at desc);

-- As in 0008, by visible_at.
create or replace function public.group_history_weeks(p_group_id uuid, p_before_week date default null, p_limit integer default 8)
returns table (week_start date, post_ids uuid[])
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
  v_limit integer := least(greatest(coalesce(p_limit, 8), 1), 52);
begin
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  select g.time_zone into v_tz from public.groups g where g.id = p_group_id;
  if v_free is not null and not private.has_premium(v_uid) then
    v_cutoff := now() - make_interval(days => v_free);
  end if;

  return query
  select w.ws, array_agg(w.id order by w.visible_at, w.id)
  from (
    select p.id, p.visible_at,
           private.week_start_of((p.visible_at at time zone v_tz)::date, v_dow) as ws
    from public.posts p
    where p.group_id = p_group_id
      and p.author_id not in (select private.blocked_ids())
      and (v_cutoff is null or p.visible_at >= v_cutoff)
  ) w
  where p_before_week is null or w.ws < p_before_week
  group by w.ws
  order by w.ws desc
  limit v_limit;
end;
$$;

-- As in 0014, with the week's photos counted by visible_at.
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
    if v_override is not null then
      v_at := v_override;
      v_after := interval '0';
    else
      v_start := coalesce(g.waking_start, v_def_start);
      v_at := case when g.waking_start is not null then g.waking_end else v_def_end end;
      if v_at is null then
        continue;
      end if;
      v_after := case when v_start is not null and v_at <= v_start then interval '1 day' else interval '0' end;
    end if;

    v_local := coalesce(p_now, now()) at time zone g.time_zone;
    v_day := v_local::date - ((extract(isodow from v_local)::integer - v_recap_dow + 7) % 7);
    if v_day + v_at + v_after > v_local then
      v_day := v_day - 7;
    end if;
    v_last_day := v_day - ((extract(isodow from v_day)::integer - v_last_dow + 7) % 7);
    v_week_start := v_last_day - 6;

    if not exists (
      select 1 from public.posts p
      where p.group_id = g.id
        and p.visible_at >= (v_week_start::timestamp at time zone g.time_zone)
        and p.visible_at < ((v_week_start + 7)::timestamp at time zone g.time_zone)) then
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

-- As in 0008, with the recap's week by visible_at.
create or replace function public.update_recap(p_recap_id uuid, p_items uuid[] default null, p_text text default null)
returns public.weekly_recaps
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_recap public.weekly_recaps;
  v_tz text;
  v_from timestamptz;
  v_to timestamptz;
  v_items uuid[];
begin
  select * into v_recap from public.weekly_recaps w where w.id = p_recap_id for update;
  if not found or not private.is_member(v_recap.group_id) then
    raise exception 'recap_not_found' using errcode = 'PT404';
  end if;
  if v_recap.status <> 'ready' then
    raise exception 'recap_not_ready' using errcode = 'PT409';
  end if;
  if p_text is not null and char_length(p_text) > 2000 then
    raise exception 'invalid_text' using errcode = 'PT400';
  end if;

  if p_items is not null then
    if exists (select 1 from unnest(p_items) x where x is null)
       or cardinality(p_items) <> (select count(distinct x) from unnest(p_items) x) then
      raise exception 'invalid_items' using errcode = 'PT400', detail = 'duplicate or null id';
    end if;
    select g.time_zone into v_tz from public.groups g where g.id = v_recap.group_id;
    v_from := (v_recap.week_start::timestamp) at time zone v_tz;
    v_to := ((v_recap.week_start + 7)::timestamp) at time zone v_tz;
    if exists (
      select 1 from unnest(p_items) x
      where not exists (select 1 from public.posts p
                        where p.id = x and p.group_id = v_recap.group_id
                          and p.visible_at >= v_from and p.visible_at < v_to
                          and private.can_see_post(p.id))) then
      raise exception 'invalid_items' using errcode = 'PT400', detail = 'not a post of this group and week';
    end if;
    select p_items || coalesce(array_agg(t.x order by t.i), '{}') into v_items
    from unnest(v_recap.items) with ordinality as t(x, i)
    where not private.can_see_post(t.x) and not (t.x = any (p_items));
  end if;

  update public.weekly_recaps w
     set items = coalesce(v_items, w.items),
         text = case when p_text is null then w.text else nullif(p_text, '') end,
         edited_by = v_uid,
         updated_at = now()
   where w.id = p_recap_id
  returning * into v_recap;
  return v_recap;
end;
$$;

-- As in 0008, ordered and paged by when each photo became visible (created_at in the result is that
-- moment, so the walls' week sections follow the same weeks as the group's history).
create or replace function public.wall(p_user_id uuid, p_before timestamptz default null, p_limit integer default 50)
returns table (
  item_kind text,
  post_id uuid,
  media_id uuid,
  collage_id uuid,
  group_ids uuid[],
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 200);
begin
  if p_user_id is null then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_user_id';
  end if;
  if p_user_id <> v_uid and (private.is_blocked_with(p_user_id) or not private.shares_group(v_uid, p_user_id)) then
    return;
  end if;

  return query
  with shared as (
    select a.group_id
    from public.group_members a
    join public.group_members b on b.group_id = a.group_id
    where a.user_id = v_uid and b.user_id = p_user_id
  ),
  photos as (
    select p.media_id,
           (array_agg(p.id order by p.visible_at, p.id))[1] as first_post_id,
           array_agg(p.group_id order by p.visible_at, p.group_id) as groups,
           min(p.visible_at) as first_at
    from public.posts p
    where p.author_id = p_user_id and p.group_id in (select s.group_id from shared s)
    group by p.media_id
  ),
  their_collages as (
    select c.id, c.group_id, coalesce(c.composed_at, c.created_at) as at
    from public.collages c
    where c.group_id in (select s.group_id from shared s)
      and exists (select 1 from public.posts p where p.id = any (c.post_ids) and p.author_id = p_user_id)
  )
  select x.item_kind, x.post_id, x.media_id, x.collage_id, x.group_ids, x.created_at
  from (
    select 'post'::text as item_kind, ph.first_post_id as post_id, ph.media_id, null::uuid as collage_id,
           ph.groups as group_ids, ph.first_at as created_at
    from photos ph
    union all
    select 'collage'::text, null::uuid, null::uuid, tc.id, array[tc.group_id], tc.at
    from their_collages tc
  ) x
  where p_before is null or x.created_at < p_before
  order by x.created_at desc, x.item_kind, coalesce(x.post_id, x.collage_id)
  limit v_limit;
end;
$$;

-- As in 0009, with the year's photos counted by visible_at.
create or replace function public.due_year_stories(p_now timestamptz default now())
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
        and p.visible_at >= (make_date(v_year, 1, 1)::timestamp at time zone g.time_zone)
        and p.visible_at < (make_date(v_year + 1, 1, 1)::timestamp at time zone g.time_zone)) then
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

-- (create or replace keeps every function's existing grants)

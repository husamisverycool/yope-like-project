-- =============================================================================
-- 0033 the same-moment collage in the group's history (directive Part 6: the collage "becomes the
-- group's photo of the day: shown on widgets, added to the group's history and walls").
--
-- Until now a collage was reachable only from a wall tile. It now belongs to the group's history too:
--   * group_collages(p_group_id, p_from, p_to): the group's ready collages by the group-local day of
--     their invitation (members only), newest first, with their file paths — the group screen's week
--     and the clients' day tiles;
--   * group_history_weeks also returns each week's collages (oldest first) as `collages` jsonb, and a
--     week that has only a collage (its photos hidden from the caller by a block) is still a week;
--   * weekly_recaps.collage_ids: the recap's same-moment collages, in order. recap.generate fills it
--     with the week's ready collages; update_recap(…, p_collage_ids) reorders or removes them (any of
--     the week's ready collages may be put back); a deleted collage leaves every recap.
-- A collage has no "late" or count anywhere: it holds the answers that came inside the window.
-- =============================================================================

alter table public.weekly_recaps add column collage_ids uuid[] not null default '{}';

-- The group's ready collages whose invitation day (group-local) is in [p_from, p_to] (either bound may be
-- null), newest first.
create function public.group_collages(p_group_id uuid, p_from date default null, p_to date default null)
returns table (
  collage_id uuid,
  invitation_id uuid,
  local_date date,
  image_path text,
  widget_path text,
  share_path text,
  page_count integer,
  composed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_user();
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  return query
  select c.id, c.invitation_id, d.local_date, c.image_path, c.widget_path, c.share_path, c.page_count, c.composed_at
    from public.collages c
    join public.daily_invitations d on d.id = c.invitation_id
   where c.group_id = p_group_id
     and c.status = 'ready'
     and (p_from is null or d.local_date >= p_from)
     and (p_to is null or d.local_date <= p_to)
   order by d.local_date desc, d.fires_at desc, c.id;
end;
$$;

-- As in 0027 (weeks by posts.visible_at), with each week's collages.
drop function public.group_history_weeks(uuid, date, integer);

create function public.group_history_weeks(p_group_id uuid, p_before_week date default null, p_limit integer default 8)
returns table (week_start date, post_ids uuid[], collages jsonb)
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
  with photos as (
    select p.id, p.visible_at,
           private.week_start_of((p.visible_at at time zone v_tz)::date, v_dow) as ws
      from public.posts p
     where p.group_id = p_group_id
       and p.author_id not in (select private.blocked_ids())
       and (v_cutoff is null or p.visible_at >= v_cutoff)
  ),
  moments as (
    select c.id, c.invitation_id, d.local_date, d.fires_at, c.image_path, c.widget_path,
           private.week_start_of(d.local_date, v_dow) as ws
      from public.collages c
      join public.daily_invitations d on d.id = c.invitation_id
     where c.group_id = p_group_id
       and c.status = 'ready'
       and (v_cutoff is null or d.fires_at >= v_cutoff)
  ),
  weeks as (
    select x.ws from (select ph.ws from photos ph union select m.ws from moments m) x
     where p_before_week is null or x.ws < p_before_week
     order by x.ws desc
     limit v_limit
  )
  select w.ws,
         coalesce((select array_agg(ph.id order by ph.visible_at, ph.id) from photos ph where ph.ws = w.ws), '{}'::uuid[]),
         coalesce((select jsonb_agg(jsonb_build_object(
                                      'collage_id', m.id, 'invitation_id', m.invitation_id, 'local_date', m.local_date,
                                      'image_path', m.image_path, 'widget_path', m.widget_path)
                                    order by m.local_date, m.fires_at, m.id)
                     from moments m where m.ws = w.ws), '[]'::jsonb)
    from weeks w
   order by w.ws desc;
end;
$$;

-- As in 0027 (week by visible_at), with the recap's collages: p_collage_ids reorders / removes them; only
-- ready collages of that group whose invitation day is in the recap's week.
drop function public.update_recap(uuid, uuid[], text);

create function public.update_recap(p_recap_id uuid, p_items uuid[] default null, p_text text default null, p_collage_ids uuid[] default null)
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

  if p_collage_ids is not null then
    if exists (select 1 from unnest(p_collage_ids) x where x is null)
       or cardinality(p_collage_ids) <> (select count(distinct x) from unnest(p_collage_ids) x) then
      raise exception 'invalid_items' using errcode = 'PT400', detail = 'duplicate or null collage id';
    end if;
    if exists (
      select 1 from unnest(p_collage_ids) x
      where not exists (select 1 from public.collages c
                          join public.daily_invitations d on d.id = c.invitation_id
                         where c.id = x and c.group_id = v_recap.group_id and c.status = 'ready'
                           and d.local_date >= v_recap.week_start and d.local_date < v_recap.week_start + 7)) then
      raise exception 'invalid_items' using errcode = 'PT400', detail = 'not a collage of this group and week';
    end if;
  end if;

  update public.weekly_recaps w
     set items = coalesce(v_items, w.items),
         collage_ids = coalesce(p_collage_ids, w.collage_ids),
         text = case when p_text is null then w.text else nullif(p_text, '') end,
         edited_by = v_uid,
         updated_at = now()
   where w.id = p_recap_id
  returning * into v_recap;
  return v_recap;
end;
$$;

-- A deleted collage (its last photo deleted, or its group gone) leaves every recap.
create function private.collages_leave_recaps()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.weekly_recaps w
     set collage_ids = array_remove(w.collage_ids, old.id), updated_at = now()
   where w.group_id = old.group_id and w.collage_ids @> array[old.id];
  return null;
end;
$$;

create trigger collages_leave_recaps after delete on public.collages
  for each row execute function private.collages_leave_recaps();

revoke all on function public.group_collages(uuid, date, date), public.group_history_weeks(uuid, date, integer),
                       public.update_recap(uuid, uuid[], text, uuid[]) from public, anon;
grant execute on function public.group_collages(uuid, date, date), public.group_history_weeks(uuid, date, integer),
                          public.update_recap(uuid, uuid[], text, uuid[]) to authenticated;
revoke all on function private.collages_leave_recaps() from public;

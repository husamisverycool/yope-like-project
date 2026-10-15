-- =============================================================================
-- 0008 browse & remember RPCs: wall, group_history_weeks, on_this_day,
-- update_recap, save_album, rename_album, delete_album, contribute_tribute.
-- =============================================================================

-- Local date -> start of its week (week_start_isodow, default Monday).
create function private.week_start_of(p_date date, p_week_start_isodow integer)
returns date
language sql
immutable
set search_path = ''
as $$
  select p_date - ((extract(isodow from p_date)::integer - p_week_start_isodow + 7) % 7)
$$;

-- ---------------------------------------------------------------------------
-- A person's wall as seen by the caller: their photos in groups the caller shares
-- with them (one item per photo even when it was sent to several shared groups),
-- plus collages in those groups that contain one of their photos.
-- Empty when there is a block between the two or no shared group.
create function public.wall(p_user_id uuid, p_before timestamptz default null, p_limit integer default 50)
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
           (array_agg(p.id order by p.created_at, p.id))[1] as first_post_id,
           array_agg(p.group_id order by p.created_at, p.group_id) as groups,
           min(p.created_at) as first_at
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

-- ---------------------------------------------------------------------------
-- Week buckets of a group's posts in the group's time zone, newest week first.
-- free_history_days (when set) limits browsing for non-premium callers only.
create function public.group_history_weeks(p_group_id uuid, p_before_week date default null, p_limit integer default 8)
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
  select w.ws, array_agg(w.id order by w.created_at, w.id)
  from (
    select p.id, p.created_at,
           private.week_start_of((p.created_at at time zone v_tz)::date, v_dow) as ws
    from public.posts p
    where p.group_id = p_group_id
      and p.author_id not in (select private.blocked_ids())
      and (v_cutoff is null or p.created_at >= v_cutoff)
  ) w
  where p_before_week is null or w.ws < p_before_week
  group by w.ws
  order by w.ws desc
  limit v_limit;
end;
$$;

-- ---------------------------------------------------------------------------
-- Posts from the same month/day (group's time zone) in previous years.
create function public.on_this_day(p_group_id uuid, p_local_date date)
returns table (post_id uuid, media_id uuid, author_id uuid, created_at timestamptz, years_ago integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tz text;
begin
  perform private.require_user();
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  if p_local_date is null then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_local_date';
  end if;
  select g.time_zone into v_tz from public.groups g where g.id = p_group_id;

  return query
  select x.id, x.media_id, x.author_id, x.created_at,
         (extract(year from p_local_date) - extract(year from x.d))::integer
  from (
    select p.id, p.media_id, p.author_id, p.created_at, (p.created_at at time zone v_tz)::date as d
    from public.posts p
    where p.group_id = p_group_id
      and p.author_id not in (select private.blocked_ids())
  ) x
  where extract(month from x.d) = extract(month from p_local_date)
    and extract(day from x.d) = extract(day from p_local_date)
    and extract(year from x.d) < extract(year from p_local_date)
  order by x.created_at desc, x.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Any member may reorder / remove / re-add (posts from that week) and edit text.
-- NULL argument = unchanged; p_text = '' clears the text. Items the caller cannot
-- see (blocked authors) are kept, after the caller's order.
create function public.update_recap(p_recap_id uuid, p_items uuid[] default null, p_text text default null)
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
                          and p.created_at >= v_from and p.created_at < v_to
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

-- ---------------------------------------------------------------------------
-- Albums: named, visible to the whole group.
create function private.assert_album_posts(p_group uuid, p_post_ids uuid[])
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_post_ids is null or cardinality(p_post_ids) = 0
     or exists (select 1 from unnest(p_post_ids) x where x is null)
     or cardinality(p_post_ids) <> (select count(distinct x) from unnest(p_post_ids) x) then
    raise exception 'invalid_items' using errcode = 'PT400', detail = 'empty, duplicate or null id';
  end if;
  if exists (select 1 from unnest(p_post_ids) x
             where not exists (select 1 from public.posts p
                               where p.id = x and p.group_id = p_group and private.can_see_post(p.id))) then
    raise exception 'invalid_items' using errcode = 'PT400', detail = 'not a post of this group';
  end if;
end;
$$;

create function public.save_album(p_group_id uuid, p_name text, p_post_ids uuid[])
returns public.albums
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_album public.albums;
begin
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  if p_name is null or char_length(btrim(p_name)) not between 1 and 80 then
    raise exception 'invalid_name' using errcode = 'PT400';
  end if;
  perform private.assert_album_posts(p_group_id, p_post_ids);
  insert into public.albums (group_id, name, created_by) values (p_group_id, btrim(p_name), v_uid)
  returning * into v_album;
  insert into public.album_items (album_id, post_id, position)
  select v_album.id, t.x, (t.i - 1)::integer from unnest(p_post_ids) with ordinality as t(x, i);
  return v_album;
end;
$$;

create function public.rename_album(p_album_id uuid, p_name text)
returns public.albums
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_album public.albums;
begin
  perform private.require_user();
  select * into v_album from public.albums a where a.id = p_album_id;
  if not found or not private.is_member(v_album.group_id) then
    raise exception 'album_not_found' using errcode = 'PT404';
  end if;
  if p_name is null or char_length(btrim(p_name)) not between 1 and 80 then
    raise exception 'invalid_name' using errcode = 'PT400';
  end if;
  update public.albums a set name = btrim(p_name) where a.id = p_album_id returning * into v_album;
  return v_album;
end;
$$;

-- Creator or a group admin.
create function public.delete_album(p_album_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_album public.albums;
begin
  select * into v_album from public.albums a where a.id = p_album_id;
  if not found or not private.is_member(v_album.group_id) then
    raise exception 'album_not_found' using errcode = 'PT404';
  end if;
  if v_album.created_by is distinct from v_uid and not private.is_admin(v_album.group_id) then
    raise exception 'not_album_owner' using errcode = 'PT403';
  end if;
  delete from public.albums a where a.id = p_album_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Birthday tribute contribution: one per contributor per request, editable until
-- the due time; only a photo of that group the contributor posted or is self-tagged in.
create function public.contribute_tribute(p_request_id uuid, p_post_id uuid, p_line text)
returns public.tribute_contributions
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_req public.tribute_requests;
  v_post public.posts;
  v_row public.tribute_contributions;
begin
  select * into v_req from public.tribute_requests r where r.id = p_request_id;
  if not found or not private.is_member(v_req.group_id) or v_req.honoree_id = v_uid
     or private.is_blocked_with(v_req.honoree_id) then
    raise exception 'request_not_found' using errcode = 'PT404';
  end if;
  if v_req.due_at <= now() or v_req.closed_at is not null then
    raise exception 'tribute_closed' using errcode = 'PT409';
  end if;
  select * into v_post from public.posts p where p.id = p_post_id and p.group_id = v_req.group_id;
  if not found or not private.can_see_post(p_post_id) then
    raise exception 'post_not_found' using errcode = 'PT404';
  end if;
  if v_post.author_id <> v_uid
     and not exists (select 1 from public.post_tags t where t.post_id = p_post_id and t.user_id = v_uid) then
    raise exception 'post_not_eligible' using errcode = 'PT403';
  end if;
  if p_line is null or char_length(btrim(p_line)) not between 1 and 280 then
    raise exception 'invalid_line' using errcode = 'PT400';
  end if;
  insert into public.tribute_contributions (request_id, contributor_id, post_id, line)
  values (p_request_id, v_uid, p_post_id, btrim(p_line))
  on conflict (request_id, contributor_id) do update set post_id = excluded.post_id, line = excluded.line
  returning * into v_row;
  return v_row;
end;
$$;

grant execute on function
  public.wall(uuid, timestamptz, integer),
  public.group_history_weeks(uuid, date, integer),
  public.on_this_day(uuid, date),
  public.update_recap(uuid, uuid[], text),
  public.save_album(uuid, text, uuid[]),
  public.rename_album(uuid, text),
  public.delete_album(uuid),
  public.contribute_tribute(uuid, uuid, text)
to authenticated;

-- =============================================================================
-- 0057 composited media and blocks (docs/API.md §12.13); reported content is hidden from its reporter (§12.19).
--
-- Composited media. Collages and tribute videos are rendered once per group, so they cannot leave one person's
-- photo out for one viewer. The server withholds the whole artifact instead, from a viewer who has a block (either
-- way) with the author of any photo in it:
--   * collages: the row (RLS; group_collages, group_history_weeks / _months, wall) and its files
--     (g/<group>/collages/<collage>/…); the worker's widget refresh skips such a collage for that member;
--   * tributes: can_see_tribute (the row and g/<group>/tributes/<tribute>/…) also requires no block with any
--     contributor or the author of any contributed photo; this applies to the honoree too.
--   Year stories are data, not a rendering (asset_paths is empty): their post ids are filtered per viewer by the
--   posts policy, and their everyone-answered days point at collages, which the rule above withholds (the apps
--   already skip a day whose collage they cannot read).
--
-- Reports. A post or message the caller reported (reports.target_kind 'post' / 'message') is no longer shown to the
-- caller: posts and messages RLS (so Realtime too), the chat line of a reported photo, user_can_see_post /
-- can_see_post (reactions, albums, downloads, memories, replies), visible_message, can_see_media and storage, and
-- the browse RPCs (history, wall, memories, favorites, on this day, newest photos, plan photos, search). A collage or
-- tribute that contains a reported photo is withheld from its reporter like a blocked one. Nothing changes for
-- anyone else. report() itself still accepts the same target again (it checks membership, not visibility).
-- Bodies are those of the latest definitions with the new conditions added.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Ids of the caller's reported targets of one kind.
create function private.reported_ids(p_kind public.report_target_kind)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select r.target_id from public.reports r where r.reporter_id = auth.uid() and r.target_kind = p_kind
$$;

-- Must a composited artifact made of these photos be withheld from p_user? (a block either way with the author of
-- any of them, or p_user reported one of them)
create function private.composite_withheld(p_user uuid, p_post_ids uuid[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.posts p
                 where p.id = any (coalesce(p_post_ids, '{}'::uuid[]))
                   and private.is_blocked_between(p_user, p.author_id))
      or exists (select 1 from public.reports r
                 where r.reporter_id = p_user and r.target_kind = 'post'
                   and r.target_id = any (coalesce(p_post_ids, '{}'::uuid[])))
$$;

revoke all on function private.reported_ids(public.report_target_kind) from public;
revoke all on function private.composite_withheld(uuid, uuid[]) from public;
grant execute on function
  private.reported_ids(public.report_target_kind),
  private.composite_withheld(uuid, uuid[])
to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Policies
-- ---------------------------------------------------------------------------

drop policy posts_select on public.posts;
create policy posts_select on public.posts for select to authenticated
  using (group_id in (select private.my_group_ids())
         and author_id not in (select private.blocked_ids())
         and id not in (select private.reported_ids('post')));

drop policy messages_select on public.messages;
create policy messages_select on public.messages for select to authenticated
  using (group_id in (select private.my_group_ids())
         and author_id not in (select private.blocked_ids())
         and id not in (select private.reported_ids('message'))
         and (post_id is null or post_id not in (select private.reported_ids('post'))));

drop policy collages_select on public.collages;
create policy collages_select on public.collages for select to authenticated
  using (group_id in (select private.my_group_ids())
         and not private.composite_withheld((select auth.uid()), post_ids));

-- ---------------------------------------------------------------------------
-- Visibility helpers
-- ---------------------------------------------------------------------------

create or replace function private.user_can_see_post(p_user uuid, p_post uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.posts p
    join public.group_members m on m.group_id = p.group_id and m.user_id = p_user
    where p.id = p_post
      and not private.is_blocked_between(p_user, p.author_id)
      and not exists (select 1 from public.reports r
                      where r.reporter_id = p_user and r.target_kind = 'post' and r.target_id = p.id))
$$;

create or replace function private.visible_message(p_message_id uuid)
returns public.messages
language sql
stable
security definer
set search_path = ''
as $$
  select m.* from public.messages m
   where m.id = p_message_id
     and private.is_member(m.group_id)
     and m.author_id not in (select private.blocked_ids())
     and m.id not in (select private.reported_ids('message'))
$$;

create or replace function private.can_see_media(p_media uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.media md
    where md.id = p_media
      and (md.owner_id = auth.uid()
           or (not private.is_blocked_between(auth.uid(), md.owner_id)
               and exists (select 1 from public.posts p
                           join public.group_members m on m.group_id = p.group_id and m.user_id = auth.uid()
                           where p.media_id = md.id
                             and p.id not in (select private.reported_ids('post'))))))
$$;

create or replace function private.can_see_tribute(p_tribute uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.tributes t
    where t.id = p_tribute
      and private.is_member(t.group_id)
      and t.delivered_at is not null and t.delivered_at <= now()
      and (
        t.honoree_id = auth.uid()
        or (not private.is_blocked_with(t.honoree_id)
            and exists (select 1 from public.tribute_contributions c
                        where c.request_id = t.request_id and c.contributor_id = auth.uid())))
      -- rendered once for everyone: withheld when it shows someone the viewer has a block with (0057)
      and not exists (select 1 from public.tribute_contributions c
                      where c.request_id = t.request_id
                        and c.contributor_id <> auth.uid()
                        and private.is_blocked_with(c.contributor_id))
      and not private.composite_withheld(auth.uid(),
            array(select c.post_id from public.tribute_contributions c where c.request_id = t.request_id)))
$$;

create or replace function private.can_read_object(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_seg text[];
begin
  if v_uid is null or p_name is null or not private.is_safe_path(p_name) then
    return false;
  end if;
  v_seg := string_to_array(p_name, '/');

  if v_seg[1] = 'u' then
    -- u/<owner>/<media_id>/... of a photo still developing (no post of it yet): nobody
    if private.is_uuid(v_seg[3])
       and exists (select 1 from public.developing_posts dp where dp.media_id = v_seg[3]::uuid)
       and not exists (select 1 from public.posts p where p.media_id = v_seg[3]::uuid) then
      return false;
    end if;
    if v_seg[2] = v_uid::text then
      return true;
    end if;
    -- u/<owner>/<media_id>/... : whoever can see that media
    if private.is_uuid(v_seg[2]) and private.is_uuid(v_seg[3])
       and exists (select 1 from public.media md where md.id = v_seg[3]::uuid and md.owner_id = v_seg[2]::uuid) then
      return private.can_see_media(v_seg[3]::uuid);
    end if;
    -- voice notes / covers referenced by rows the caller can see
    if exists (select 1 from public.messages m
               where m.voice_path = p_name
                 and m.group_id in (select private.my_group_ids())
                 and m.author_id not in (select private.blocked_ids())
                 and m.id not in (select private.reported_ids('message'))) then
      return true;
    end if;
    if exists (select 1 from public.posts p
               where p.voice_path = p_name
                 and p.group_id in (select private.my_group_ids())
                 and p.author_id not in (select private.blocked_ids())
                 and p.id not in (select private.reported_ids('post'))) then
      return true;
    end if;
    -- a link preview's image on a message the caller can see (0053)
    if exists (select 1 from public.messages m
               where m.link_preview ->> 'image_path' = p_name
                 and m.group_id in (select private.my_group_ids())
                 and m.author_id not in (select private.blocked_ids())
                 and m.id not in (select private.reported_ids('message'))) then
      return true;
    end if;
    -- a selfie reaction on a post the caller can see (blocks hide both ways)
    if exists (select 1 from public.selfie_reactions s
               where s.image_path = p_name
                 and s.group_id in (select private.my_group_ids())
                 and s.user_id not in (select private.blocked_ids())
                 and private.can_see_post(s.post_id)) then
      return true;
    end if;
    -- a plan's cover in one of the caller's groups
    if exists (select 1 from public.plans pl
               where pl.cover_path = p_name
                 and pl.group_id in (select private.my_group_ids())
                 and pl.created_by not in (select private.blocked_ids())) then
      return true;
    end if;
    return exists (select 1 from public.groups g
                   where g.cover_path = p_name and g.id in (select private.my_group_ids()));

  elsif v_seg[1] = 'g' then
    if not private.is_uuid(v_seg[2]) or not private.is_member(v_seg[2]::uuid) then
      return false;
    end if;
    if v_seg[3] = 'tributes' then
      return private.is_uuid(v_seg[4])
         and exists (select 1 from public.tributes t where t.id = v_seg[4]::uuid and t.group_id = v_seg[2]::uuid)
         and private.can_see_tribute(v_seg[4]::uuid);
    end if;
    -- a collage's files: withheld with its row (0057)
    if v_seg[3] = 'collages' and private.is_uuid(v_seg[4]) then
      return not exists (select 1 from public.collages c
                         where c.id = v_seg[4]::uuid and c.group_id = v_seg[2]::uuid
                           and private.composite_withheld(v_uid, c.post_ids));
    end if;
    return true;

  elsif v_seg[1] = 'avatars' then
    return private.is_uuid(v_seg[2])
       and (v_seg[2] = v_uid::text or private.shares_group(v_uid, v_seg[2]::uuid));
  end if;
  return false;
end;
$$;

-- ---------------------------------------------------------------------------
-- Browse RPCs
-- ---------------------------------------------------------------------------

create or replace function public.group_collages(p_group_id uuid, p_from date default null, p_to date default null)
returns table (collage_id uuid, invitation_id uuid, local_date date, image_path text, widget_path text, share_path text, composed_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  return query
  select c.id, c.invitation_id, d.local_date, c.image_path, c.widget_path, c.share_path, c.composed_at
    from public.collages c
    join public.daily_invitations d on d.id = c.invitation_id
   where c.group_id = p_group_id
     and c.status = 'ready'
     and not private.composite_withheld(v_uid, c.post_ids)
     and (p_from is null or d.local_date >= p_from)
     and (p_to is null or d.local_date <= p_to)
   order by d.local_date desc, d.fires_at desc, c.id;
end;
$$;

create or replace function public.group_history_months(p_group_id uuid)
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
       and p.id not in (select private.reported_ids('post'))
       and (v_cutoff is null or p.visible_at >= v_cutoff)
    union
    select d.local_date
      from public.collages c
      join public.daily_invitations d on d.id = c.invitation_id
     where c.group_id = p_group_id
       and c.status = 'ready'
       and not private.composite_withheld(v_uid, c.post_ids)
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

create or replace function public.group_history_weeks(p_group_id uuid, p_before_week date default null, p_limit integer default 8)
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
       and p.id not in (select private.reported_ids('post'))
       and (v_cutoff is null or p.visible_at >= v_cutoff)
  ),
  moments as (
    select c.id, c.invitation_id, d.local_date, d.fires_at, c.image_path, c.widget_path,
           private.week_start_of(d.local_date, v_dow) as ws
      from public.collages c
      join public.daily_invitations d on d.id = c.invitation_id
     where c.group_id = p_group_id
       and c.status = 'ready'
       and not private.composite_withheld(v_uid, c.post_ids)
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

create or replace function public.wall(p_user_id uuid, p_before timestamptz default null, p_limit integer default 50)
returns table (item_kind text, post_id uuid, media_id uuid, collage_id uuid, group_ids uuid[], created_at timestamptz)
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
      and p.id not in (select private.reported_ids('post'))
    group by p.media_id
  ),
  their_collages as (
    select c.id, c.group_id, coalesce(c.composed_at, c.created_at) as at
    from public.collages c
    where c.group_id in (select s.group_id from shared s)
      and exists (select 1 from public.posts p where p.id = any (c.post_ids) and p.author_id = p_user_id)
      and not private.composite_withheld(v_uid, c.post_ids)
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

create or replace function public.my_favorites(p_before timestamptz default null, p_limit integer default 60)
returns table (media_id uuid, post_id uuid, group_id uuid, group_name text, author_id uuid, kind public.media_kind, thumb_path text, display_path text, widget_path text, taken_at timestamptz, favorited_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_limit integer := least(greatest(coalesce(p_limit, 60), 1), 200);
begin
  return query
  select f.media_id, fp.id, fp.group_id, g.name, md.owner_id, md.kind,
         coalesce(md.thumb_path, md.original_path), coalesce(md.display_path, md.original_path), md.widget_path,
         fp.created_at, f.created_at
  from public.favorites f
  join public.media md on md.id = f.media_id
  join lateral (
    select p.id, p.group_id, p.created_at
    from public.posts p
    where p.media_id = f.media_id
      and p.group_id in (select private.my_group_ids())
      and p.author_id not in (select private.blocked_ids())
      and p.id not in (select private.reported_ids('post'))
    order by p.created_at, p.id
    limit 1
  ) fp on true
  join public.groups g on g.id = fp.group_id
  where f.user_id = v_uid
    and (p_before is null or f.created_at < p_before)
  order by f.created_at desc, f.media_id
  limit v_limit;
end;
$$;

create or replace function public.my_hidden_memories()
returns table (id uuid, media_id uuid, day date, created_at timestamptz, post_id uuid, group_id uuid, kind public.media_kind, thumb_path text, taken_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  return query
  select h.id, h.media_id, h.day, h.created_at, fp.id, fp.group_id, md.kind,
         coalesce(md.thumb_path, md.original_path), fp.created_at
  from public.memory_hides h
  left join public.media md on md.id = h.media_id
  left join lateral (
    select p.id, p.group_id, p.created_at
    from public.posts p
    where p.media_id = h.media_id
      and p.group_id in (select private.my_group_ids())
      and p.author_id not in (select private.blocked_ids())
      and p.id not in (select private.reported_ids('post'))
    order by p.created_at, p.id
    limit 1
  ) fp on true
  where h.user_id = v_uid
    and (h.day is not null or fp.id is not null)
  order by h.created_at desc, h.id;
end;
$$;

create or replace function public.my_memories(p_from date, p_days integer, p_time_zone text)
returns table (day date, post_id uuid, media_id uuid, group_id uuid, group_name text, author_id uuid, author_name text, widget_path text, taken_at timestamptz, years_ago integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  if p_from is null then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_from';
  end if;
  if p_days is null or p_days < 1 or p_days > 14 then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_days';
  end if;
  if p_time_zone is null or not private.is_valid_time_zone(p_time_zone) then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_time_zone';
  end if;

  return query
  with days as (
    select (p_from + i)::date as d from generate_series(0, p_days - 1) as i
  ),
  mine as (
    select p.id, p.media_id, p.group_id, p.author_id, p.created_at,
           private.post_day(p.taken_on, p.created_at, p_time_zone) as local_day
    from public.posts p
    where p.group_id in (select private.my_group_ids())
      and p.author_id not in (select private.blocked_ids())
      and p.id not in (select private.reported_ids('post'))
      and (p.author_id = v_uid
           or exists (select 1 from public.post_tags t where t.post_id = p.id and t.user_id = v_uid))
  ),
  matched as (
    select distinct on (dd.d) dd.d, m.id, m.media_id, m.group_id, m.author_id, m.created_at,
           (extract(year from dd.d) - extract(year from m.local_day))::integer as ago
    from days dd
    join mine m on extract(month from m.local_day) = extract(month from dd.d)
               and extract(day from m.local_day) = extract(day from dd.d)
               and extract(year from m.local_day) < extract(year from dd.d)
    where not private.memory_hidden(v_uid, m.media_id, m.local_day)
    order by dd.d, m.local_day desc, m.created_at desc, m.id desc
  )
  select x.d, x.id, x.media_id, x.group_id, g.name, x.author_id, pr.display_name, md.widget_path, x.created_at, x.ago
  from matched x
  join public.groups g on g.id = x.group_id
  join public.media md on md.id = x.media_id
  join public.profiles pr on pr.id = x.author_id
  order by x.d;
end;
$$;

create or replace function public.newest_photos_of(p_user_id uuid, p_limit integer default 3)
returns table (post_id uuid, media_id uuid, group_id uuid, group_name text, author_id uuid, author_name text, author_avatar_path text, widget_path text, caption text, visible_at timestamptz, via text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_limit integer := least(greatest(coalesce(p_limit, 3), 1), 10);
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
  )
  select p.id, p.media_id, p.group_id, g.name, p.author_id, pr.display_name, pr.avatar_path, md.widget_path,
         p.caption, p.visible_at,
         case when p.author_id = p_user_id then 'author' else 'tag' end
  from public.posts p
  join public.groups g on g.id = p.group_id
  join public.media md on md.id = p.media_id
  join public.profiles pr on pr.id = p.author_id
  where p.group_id in (select s.group_id from shared s)
    and p.author_id not in (select private.blocked_ids())
    and p.id not in (select private.reported_ids('post'))
    and (p.author_id = p_user_id
         or exists (select 1 from public.post_tags t where t.post_id = p.id and t.user_id = p_user_id))
  order by p.visible_at desc, p.id desc
  limit v_limit;
end;
$$;

create or replace function public.on_this_day(p_group_id uuid, p_local_date date)
returns table (post_id uuid, media_id uuid, author_id uuid, created_at timestamptz, years_ago integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_tz text;
begin
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
    select p.id, p.media_id, p.author_id, p.created_at, private.post_day(p.taken_on, p.created_at, v_tz) as d
    from public.posts p
    where p.group_id = p_group_id
      and p.author_id not in (select private.blocked_ids())
      and p.id not in (select private.reported_ids('post'))
  ) x
  where extract(month from x.d) = extract(month from p_local_date)
    and extract(day from x.d) = extract(day from p_local_date)
    and extract(year from x.d) < extract(year from p_local_date)
    and not private.memory_hidden(v_uid, x.media_id, x.d)
  order by x.d desc, x.created_at desc, x.id;
end;
$$;

create or replace function public.plan_photos(p_plan_id uuid)
returns setof public.posts
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_plan public.plans;
  v_tz text;
  v_last date;
begin
  perform private.require_user();
  select * into v_plan from public.plans pl where pl.id = p_plan_id;
  if not found or not private.is_member(v_plan.group_id)
     or v_plan.created_by in (select private.blocked_ids()) then
    raise exception 'plan_not_found' using errcode = 'PT404';
  end if;
  if v_plan.canceled_at is not null then
    return;
  end if;
  select g.time_zone into v_tz from public.groups g where g.id = v_plan.group_id;
  v_last := coalesce((v_plan.ends_at at time zone v_tz)::date, v_plan.local_date);
  return query
  select p.*
    from public.posts p
   where p.group_id = v_plan.group_id
     and p.author_id not in (select private.blocked_ids())
     and p.id not in (select private.reported_ids('post'))
     and p.created_at >= (v_plan.local_date::timestamp at time zone v_tz)
     and p.created_at < ((v_last + 1)::timestamp at time zone v_tz)
   order by p.created_at, p.id;
end;
$$;

create or replace function public.search_photos(
  p_text text default null,
  p_group_id uuid default null,
  p_member_id uuid default null,
  p_from date default null,
  p_to date default null,
  p_before timestamptz default null,
  p_limit integer default 60
)
returns table (post_id uuid, media_id uuid, group_id uuid, author_id uuid, created_at timestamptz, matched text[])
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_q tsquery := private.search_tsquery(p_text);
  v_limit integer := least(greatest(coalesce(p_limit, 60), 1), 200);
begin
  if v_q is null and p_member_id is null and p_from is null and p_to is null then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_text, p_member_id, p_from or p_to';
  end if;
  if p_from is not null and p_to is not null and p_to < p_from then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_to before p_from';
  end if;
  if p_group_id is not null and not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  -- a member you have a block with matches nothing
  if p_member_id is not null and p_member_id <> v_uid and private.is_blocked_with(p_member_id) then
    return;
  end if;

  return query
  with scope as (
    select p.id, p.media_id, p.group_id, p.author_id, p.created_at, p.caption,
           (p.created_at at time zone g.time_zone)::date as local_day
    from public.posts p
    join public.groups g on g.id = p.group_id
    where p.group_id in (select private.my_group_ids())
      and (p_group_id is null or p.group_id = p_group_id)
      and p.author_id not in (select private.blocked_ids())
      and p.id not in (select private.reported_ids('post'))
      and (p_before is null or p.created_at < p_before)
  ),
  hits as (
    select s.*,
           (v_q is not null and to_tsvector('simple', coalesce(s.caption, '')) @@ v_q) as by_caption,
           (v_q is not null and exists (
              select 1 from public.messages m
              where m.reply_to_post_id = s.id and m.group_id = s.group_id
                and m.author_id not in (select private.blocked_ids())
                and m.id not in (select private.reported_ids('message'))
                and to_tsvector('simple', coalesce(m.body, '')) @@ v_q)) as by_chat,
           (p_member_id is not null and s.author_id = p_member_id) as by_author,
           (p_member_id is not null and exists (
              select 1 from public.post_tags t where t.post_id = s.id and t.user_id = p_member_id)) as by_tag
    from scope s
    where (p_from is null or s.local_day >= p_from)
      and (p_to is null or s.local_day <= p_to)
  ),
  matches as (
    select h.*,
           row_number() over (partition by h.media_id order by (h.group_id = p_group_id) desc nulls last, h.created_at, h.id) as rn
    from hits h
    where (v_q is null or h.by_caption or h.by_chat)
      and (p_member_id is null or h.by_author or h.by_tag)
  )
  select x.id, x.media_id, x.group_id, x.author_id, x.created_at,
         array_remove(array[
           case when x.by_caption then 'caption' end,
           case when x.by_chat then 'chat' end,
           case when x.by_author then 'author' end,
           case when x.by_tag then 'tag' end,
           case when p_from is not null or p_to is not null then 'date' end], null)
  from matches x
  where x.rn = 1
  order by x.created_at desc, x.id
  limit v_limit;
end;
$$;

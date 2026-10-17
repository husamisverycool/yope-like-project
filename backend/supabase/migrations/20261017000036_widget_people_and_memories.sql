-- =============================================================================
-- 0036 what the new widgets read: one friend's newest photo, your own memories from this day, and the people
-- a person can pick for a friend widget (owner decision 34: "more widgets"; design/surfaces/widget.friend.md,
-- widget.memories.md; docs/WIDGET_REFRESH.md "Friend and memories widgets").
--
-- Mechanics references:
--   * Locket: "'Crush' or 'Best Friend' picture widget… photos only from that person"
--     (https://apps.apple.com/us/app/id1600525061). Ours finds a person's photos by who posted them or by
--     their own "I'm in this" self-tag (post_tags), never by face (directive: no face recognition).
--   * Retro: "See the newest posts from friends or time hop back to your own memories with our new widgets"
--     (https://apps.apple.com/us/app/id6443709020); its "Your Memories" widget shows your own photos. Ours shows
--     the photos you posted or tagged yourself in on this month and day in earlier years (on_this_day's rule,
--     0008: the day a photo was taken), in the device's time zone because the widget is the person's, not a
--     group's.
--
-- Visibility is the walls' (0027 public.wall): only groups the caller shares with that person (both current
-- members), never across a block in either direction (the friend, and every photo's author), and a widget
-- for someone who no longer shares a group returns nothing. Everything returned is something the caller can
-- already read through RLS (posts_select, media via private.can_see_media, co-member profiles); the functions
-- only save the apps several round trips and keep the rules in one place.
-- =============================================================================

-- People the caller can pick for a friend widget: everyone who shares a group with them, except themselves
-- and anyone with a block in either direction. Alphabetical by display name.
create function public.widget_people()
returns table (user_id uuid, display_name text, avatar_path text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  return query
  select p.id, p.display_name, p.avatar_path
  from public.profiles p
  where p.id in (select private.co_member_ids())
    and p.id <> v_uid
    and p.id not in (select private.blocked_ids())
  order by lower(p.display_name), p.id;
end;
$$;

-- The newest photos of one person the caller can see (newest first, at most p_limit, 1–10): posts they made, or
-- posts they tagged themselves in, in groups both share, by authors with no block with the caller. `via` says
-- which ('author' wins when both). Newest by when the group could first see the photo (visible_at, 0027), as
-- the group's own feed and widget. Widget renditions can lag a fresh post, so callers take the first row whose
-- widget_path is set.
create function public.newest_photos_of(p_user_id uuid, p_limit integer default 3)
returns table (
  post_id uuid,
  media_id uuid,
  group_id uuid,
  group_name text,
  author_id uuid,
  author_name text,
  author_avatar_path text,
  widget_path text,
  caption text,
  visible_at timestamptz,
  via text
)
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
    and (p.author_id = p_user_id
         or exists (select 1 from public.post_tags t where t.post_id = p.id and t.user_id = p_user_id))
  order by p.visible_at desc, p.id desc
  limit v_limit;
end;
$$;

-- The caller's own memories for each day from p_from for p_days days (1–14): for each day, the newest photo the
-- caller posted or tagged themselves in, taken on that month and day in an earlier year (in p_time_zone, the
-- device's zone), in a group they are still in, by an author with no block with them. A day without such a photo
-- has no row: the widget shows nothing it does not have. The same photo posted to several groups counts once.
create function public.my_memories(p_from date, p_days integer, p_time_zone text)
returns table (
  day date,
  post_id uuid,
  media_id uuid,
  group_id uuid,
  group_name text,
  author_id uuid,
  author_name text,
  widget_path text,
  taken_at timestamptz,
  years_ago integer
)
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
           (p.created_at at time zone p_time_zone)::date as local_day
    from public.posts p
    where p.group_id in (select private.my_group_ids())
      and p.author_id not in (select private.blocked_ids())
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
    order by dd.d, m.created_at desc, m.id desc
  )
  select x.d, x.id, x.media_id, x.group_id, g.name, x.author_id, pr.display_name, md.widget_path, x.created_at, x.ago
  from matched x
  join public.groups g on g.id = x.group_id
  join public.media md on md.id = x.media_id
  join public.profiles pr on pr.id = x.author_id
  order by x.d;
end;
$$;

revoke all on function public.widget_people(), public.newest_photos_of(uuid, integer), public.my_memories(date, integer, text)
  from public, anon;
grant execute on function public.widget_people(), public.newest_photos_of(uuid, integer), public.my_memories(date, integer, text)
  to authenticated;

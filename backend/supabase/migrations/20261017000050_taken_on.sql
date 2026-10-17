-- =============================================================================
-- 0050 library photos land on the day they were taken — the date only, never a place (owner decision 34,
-- docs/RESEARCH_FEATURES_2026-10-17.md #5).
--
-- Mechanics: Retro "backfill the weeks… with the photos and videos you want to remember" (App Store id6443709020)
-- and reading when library photos were taken (Engadget, research #5).
--   * media.taken_on date (client-written at insert, like width / height): the calendar day the photo was taken,
--     in the device's zone, from the library's creation date (PHAsset.creationDate / MediaStore DATE_TAKEN). Never
--     a time, never a location. Camera photos leave it null. Not after today, not before 1900.
--   * posts.taken_on: copied from the media when the post is made (and kept if the media is gone).
--   * posts.visible_at stops being a generated column; a trigger sets it: the reveal time of an overnight photo,
--     else noon of taken_on in the group's time zone (a day earlier than the day it was posted only — a photo
--     "taken" in the future is treated as taken today), else created_at. History weeks, months, recaps, walls and
--     year stories follow visible_at as before (0027), so a backfilled photo lands in its own week.
--   * on_this_day, my_memories and the memory notification (0049) match the day the photo was taken:
--     taken_on when set, else the day of created_at.
--   The chat, pushes and "new" in the group stay about now: the photo message is sent when it is posted.
-- =============================================================================

alter table public.media add column taken_on date
  check (taken_on is null or (taken_on >= date '1900-01-01' and taken_on <= (now() at time zone 'UTC')::date + 1));
grant insert (taken_on) on public.media to authenticated;

alter table public.posts add column taken_on date;
alter table public.posts alter column visible_at drop expression;

create function private.posts_set_visible_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tz text;
  v_taken timestamptz;
begin
  if tg_op = 'INSERT' and new.taken_on is null then
    select md.taken_on into new.taken_on from public.media md where md.id = new.media_id;
  end if;
  if new.taken_on is not null then
    select g.time_zone into v_tz from public.groups g where g.id = new.group_id;
    v_taken := (new.taken_on + time '12:00') at time zone coalesce(v_tz, 'UTC');
    if v_taken > new.created_at then
      v_taken := null; -- not taken before it was posted: an ordinary post
    end if;
  end if;
  new.visible_at := coalesce(new.revealed_at, v_taken, new.created_at);
  return new;
end;
$$;
revoke all on function private.posts_set_visible_at() from public;

create trigger posts_set_visible_at before insert or update of revealed_at, taken_on, created_at on public.posts
  for each row execute function private.posts_set_visible_at();

update public.posts p set visible_at = coalesce(p.revealed_at, p.created_at) where p.visible_at is null;
alter table public.posts alter column visible_at set not null;

-- The day a post's photo was taken, in zone p_zone.
create function private.post_day(p_taken_on date, p_created_at timestamptz, p_zone text)
returns date
language sql
stable
set search_path = ''
as $$
  select coalesce(p_taken_on, (p_created_at at time zone p_zone)::date)
$$;
revoke all on function private.post_day(date, timestamptz, text) from public;

-- As in 0038, by the day the photo was taken.
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
  ) x
  where extract(month from x.d) = extract(month from p_local_date)
    and extract(day from x.d) = extract(day from p_local_date)
    and extract(year from x.d) < extract(year from p_local_date)
    and not private.memory_hidden(v_uid, x.media_id, x.d)
  order by x.d desc, x.created_at desc, x.id;
end;
$$;

-- As in 0038, by the day the photo was taken.
create or replace function public.my_memories(p_from date, p_days integer, p_time_zone text)
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
           private.post_day(p.taken_on, p.created_at, p_time_zone) as local_day
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

-- As in 0049, by the day the photo was taken.
create or replace function private.memory_of_day(p_user uuid, p_day date, p_zone text)
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
     and extract(month from private.post_day(p.taken_on, p.created_at, p_zone)) = extract(month from p_day)
     and extract(day from private.post_day(p.taken_on, p.created_at, p_zone)) = extract(day from p_day)
     and extract(year from private.post_day(p.taken_on, p.created_at, p_zone)) < extract(year from p_day)
     and private.user_can_see_post(p_user, p.id)
     and not private.memory_hidden(p_user, p.media_id, private.post_day(p.taken_on, p.created_at, p_zone))
   order by private.post_day(p.taken_on, p.created_at, p_zone) desc, p.created_at desc, p.id desc
   limit 1
$$;

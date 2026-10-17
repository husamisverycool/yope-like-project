-- =============================================================================
-- 0038 your memories, for you only: hide a photo or a whole date from your memories, and private favorites
-- (owner decision 34: "hide a memory", "private favorites"; docs/RESEARCH_FEATURES_2026-10-17.md #12 and #19).
--
-- Mechanics references (accessed 2026-10-17):
--   * Google Photos (https://support.google.com/photos/answer/9454489): in a memory, More → Hide → "Remove this
--     photo from this memory"; More → "Hide this date from all memories"; Preferences → Memories → "Hide dates"
--     lists the hidden dates to show them again. "When you hide a date, you won't get photos taken on that date".
--   * Retro Rewind hides photos from its memories (https://techcrunch.com/2025/12/12/retro-a-photo-sharing-app-for-
--     friends-lets-you-time-travel-through-your-camera-roll/); Timehop "Hide your bad memories"
--     (https://apps.apple.com/us/app/id569077959).
--   * Apple Photos Favorites: a heart only you see; a Favorites album collects them
--     (https://iphonelife.com/blog/5/tip-day-quick-way-create-album-your-favorite-photos).
--
-- What a hide does: the photo (by media, so every group it was sent to) or every photo taken on that calendar day
-- (the day as each memory surface reckons it: the group's time zone for On This Day, the device's for the Memories
-- widget) leaves the caller's On This Day, the Memories widget (my_memories, 0036) and the On This Day shuffle (the
-- apps filter their shuffle picks with the caller's memory_hides rows). Nothing changes for anyone else: the photo
-- stays in the group, its week, recaps and walls. Hides are listed in Settings (my_hidden_memories) to show again.
--
-- Favorites: a heart only the caller sees (RLS: own rows; no other user, RPC or job reads them — never a count,
-- never used to rank recaps or year stories, spec flag T2). my_favorites lists the caller's favorites that they
-- can still see, for the "Favorites" section of their memories and, later, a widget.
-- Both tables cascade with the media (deleting a photo removes it everywhere) and with the account.
-- =============================================================================

create table public.memory_hides (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  media_id   uuid references public.media (id) on delete cascade,
  day        date,
  created_at timestamptz not null default now(),
  check ((media_id is null) <> (day is null))
);
alter table public.memory_hides enable row level security;
create unique index memory_hides_media_uq on public.memory_hides (user_id, media_id) where media_id is not null;
create unique index memory_hides_day_uq on public.memory_hides (user_id, day) where day is not null;
create index memory_hides_media_idx on public.memory_hides (media_id) where media_id is not null;

create policy memory_hides_select_own on public.memory_hides for select to authenticated
  using (user_id = (select auth.uid()));
grant select on public.memory_hides to authenticated;

create table public.favorites (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  media_id   uuid not null references public.media (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, media_id)
);
alter table public.favorites enable row level security;
create index favorites_media_idx on public.favorites (media_id);
create index favorites_user_created_idx on public.favorites (user_id, created_at desc);

create policy favorites_select_own on public.favorites for select to authenticated
  using (user_id = (select auth.uid()));
grant select on public.favorites to authenticated;

-- Is this photo (or its day) hidden from p_user's memories? p_day = the photo's local day as the calling surface
-- reckons it. For the memory functions below and for other memory readers (the Memories widget, the memory push).
create function private.memory_hidden(p_user uuid, p_media uuid, p_day date)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.memory_hides h
                 where h.user_id = p_user
                   and ((h.media_id is not null and h.media_id = p_media)
                        or (h.day is not null and h.day = p_day)))
$$;
revoke all on function private.memory_hidden(uuid, uuid, date) from public;
grant execute on function private.memory_hidden(uuid, uuid, date) to service_role;

-- ---------------------------------------------------------------------------
-- Hide one photo (p_media_id) or one calendar day (p_day) from the caller's memories. Exactly one of the two.
-- Idempotent: hiding again returns the existing row. A photo must be one the caller can see.
create function public.hide_memory(p_media_id uuid default null, p_day date default null)
returns public.memory_hides
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_row public.memory_hides;
begin
  if (p_media_id is null) = (p_day is null) then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_media_id or p_day';
  end if;
  if p_media_id is not null then
    if not private.can_see_media(p_media_id) then
      raise exception 'media_not_found' using errcode = 'PT404';
    end if;
    select * into v_row from public.memory_hides h where h.user_id = v_uid and h.media_id = p_media_id;
    if not found then
      insert into public.memory_hides (user_id, media_id) values (v_uid, p_media_id) returning * into v_row;
    end if;
  else
    if p_day > (now() at time zone 'UTC')::date + 1 or p_day < date '1900-01-01' then
      raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_day';
    end if;
    select * into v_row from public.memory_hides h where h.user_id = v_uid and h.day = p_day;
    if not found then
      insert into public.memory_hides (user_id, day) values (v_uid, p_day) returning * into v_row;
    end if;
  end if;
  return v_row;
end;
$$;

-- Show a hidden photo or day again (Settings → Hidden Memories). Only your own rows; unknown ids are a no-op.
create function public.unhide_memory(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  delete from public.memory_hides h where h.id = p_id and h.user_id = v_uid;
end;
$$;

-- The caller's hidden memories for Settings, newest hide first: hidden days, and hidden photos the caller can still
-- see (with one post of it and its thumbnail; a photo that left the caller's groups no longer appears anywhere, so
-- its hide is not listed).
create function public.my_hidden_memories()
returns table (
  id uuid,
  media_id uuid,
  day date,
  created_at timestamptz,
  post_id uuid,
  group_id uuid,
  kind public.media_kind,
  thumb_path text,
  taken_at timestamptz
)
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
    order by p.created_at, p.id
    limit 1
  ) fp on true
  where h.user_id = v_uid
    and (h.day is not null or fp.id is not null)
  order by h.created_at desc, h.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Favorites: a heart only you see. p_on = true adds (idempotent), false removes.
create function public.set_favorite(p_media_id uuid, p_on boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  if p_media_id is null or p_on is null then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_media_id, p_on';
  end if;
  if p_on then
    if not private.can_see_media(p_media_id) then
      raise exception 'media_not_found' using errcode = 'PT404';
    end if;
    insert into public.favorites (user_id, media_id) values (v_uid, p_media_id) on conflict do nothing;
  else
    delete from public.favorites f where f.user_id = v_uid and f.media_id = p_media_id;
  end if;
end;
$$;

-- The caller's favorites they can still see, newest favorite first (page with p_before = the last favorited_at;
-- p_limit 1–200). One row per photo: its first post in the caller's groups (the group it opens in).
create function public.my_favorites(p_before timestamptz default null, p_limit integer default 60)
returns table (
  media_id uuid,
  post_id uuid,
  group_id uuid,
  group_name text,
  author_id uuid,
  kind public.media_kind,
  thumb_path text,
  display_path text,
  widget_path text,
  taken_at timestamptz,
  favorited_at timestamptz
)
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

-- ---------------------------------------------------------------------------
-- On This Day without the caller's hidden photos and days (0008's function otherwise unchanged: posts from the same
-- month and day, group time zone, earlier years, by the day each photo was taken).
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
    select p.id, p.media_id, p.author_id, p.created_at, (p.created_at at time zone v_tz)::date as d
    from public.posts p
    where p.group_id = p_group_id
      and p.author_id not in (select private.blocked_ids())
  ) x
  where extract(month from x.d) = extract(month from p_local_date)
    and extract(day from x.d) = extract(day from p_local_date)
    and extract(year from x.d) < extract(year from p_local_date)
    and not private.memory_hidden(v_uid, x.media_id, x.d)
  order by x.created_at desc, x.id;
end;
$$;

-- The Memories widget's source (0036) without the caller's hidden photos and days (the day in the device's zone,
-- as the widget shows it). Body as 0036 plus the memory_hidden filter.
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
    where not private.memory_hidden(v_uid, m.media_id, m.local_day)
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

revoke all on function
  public.hide_memory(uuid, date),
  public.unhide_memory(uuid),
  public.my_hidden_memories(),
  public.set_favorite(uuid, boolean),
  public.my_favorites(timestamptz, integer)
from public, anon;
grant execute on function
  public.hide_memory(uuid, date),
  public.unhide_memory(uuid),
  public.my_hidden_memories(),
  public.set_favorite(uuid, boolean),
  public.my_favorites(timestamptz, integer)
to authenticated;

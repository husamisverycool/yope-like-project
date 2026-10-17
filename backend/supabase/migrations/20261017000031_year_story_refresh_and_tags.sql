-- =============================================================================
-- 0031 the year story: refreshed on 31 December, announced once, kept for good, self-tags count
-- (docs/OWNER_DECISIONS.md 2026-10-17 decision 31; directive Part 6 "Self-tagging … powers birthday
-- tributes and year stories").
--
-- * Refresh. A story is computed when it is created (from 1 December, year_story_release_month_day),
--   so December was missing. On 31 December, at the end of the group's waking window (its own hours,
--   else default_waking_end; a window that wraps past midnight ends early on 1 January) — the same
--   "last waking moment" as the weekly recap (0014) — due_year_stories queues year.recompute once
--   (year_stories.refreshed_at). A story created after that moment needs no refresh. A group whose
--   window is unknown is not refreshed (fails closed, as its recaps). Stories of earlier years that
--   were never refreshed are refreshed on the next run, so their December counts too.
-- * One push. The worker announces a story the first time it becomes ready (push.year_story, sets
--   year_stories.announced_at); recomputes (refresh, a deleted photo, a self-tag) never notify.
-- * Self-tags. Adding or removing an "I'm in this" tag on a photo of a ready story recomputes it, so
--   the story's self_tagged list (the photos someone tagged themselves in, docs/API.md §5.19) stays
--   true. No per-person count or ranking is computed.
-- * Kept for good: year_stories rows are never deleted by age; clients list every ready story
--   (docs/API.md §5.19), not only the current year's.
-- =============================================================================

alter table public.year_stories
  add column refreshed_at timestamptz,
  add column announced_at timestamptz;

-- As in 0027 (creation by visible_at), plus the 31 December refresh.
create or replace function public.due_year_stories(p_now timestamptz default now())
returns setof public.year_stories
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := coalesce(p_now, now());
  v_md text := coalesce(private.config_text('year_story_release_month_day'), '12-01');
  v_month integer := split_part(v_md, '-', 1)::integer;
  v_day integer := split_part(v_md, '-', 2)::integer;
  v_def_start time := private.config_text('default_waking_start')::time;
  v_def_end time := private.config_text('default_waking_end')::time;
  g record;
  s record;
  v_local timestamp;
  v_year integer;
  v_row public.year_stories;
  v_start time;
  v_end time;
  v_refresh timestamptz;
begin
  if v_month <> 12 then
    raise exception 'config_invalid' using errcode = 'PT503', detail = 'year_story_release_month_day must be in December';
  end if;

  -- 1. create (and compute) this year's story from the release day
  for g in select gr.id, gr.time_zone from public.groups gr order by gr.id loop
    v_local := v_now at time zone g.time_zone;
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

  -- 2. refresh each story once, at the end of its group's waking window on 31 December
  for s in
    select y.id, y.group_id, y.year, y.created_at, gr.time_zone, gr.waking_start, gr.waking_end
      from public.year_stories y
      join public.groups gr on gr.id = y.group_id
     where y.refreshed_at is null
     order by y.group_id, y.year
     for update of y skip locked
  loop
    v_start := coalesce(s.waking_start, v_def_start);
    v_end := case when s.waking_start is not null then s.waking_end else v_def_end end;
    if v_end is null then
      continue; -- unknown waking window: no refresh (as no recap)
    end if;
    v_refresh := ((make_date(s.year, 12, 31) + v_end)
                  + case when v_start is not null and v_end <= v_start then interval '1 day' else interval '0' end)
                 at time zone s.time_zone;
    if v_now < v_refresh then
      continue;
    end if;
    update public.year_stories y set refreshed_at = v_now where y.id = s.id;
    -- a story created after the refresh moment was computed with December already
    if s.created_at < v_refresh then
      perform private.enqueue('year.recompute',
        jsonb_build_object('year_story_id', s.id, 'group_id', s.group_id),
        'year.recompute:' || s.id::text);
    end if;
  end loop;
end;
$$;

-- A self-tag added or removed on a photo of a story recomputes that story (no clearing: the story stays
-- readable while it is recomputed).
create function private.year_stories_follow_tags()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post uuid := coalesce(new.post_id, old.post_id);
  v_group uuid := coalesce(new.group_id, old.group_id);
  r record;
begin
  for r in
    select y.id from public.year_stories y
     where y.group_id = v_group and y.post_ids @> array[v_post] and y.status = 'ready'
  loop
    perform private.enqueue('year.recompute',
      jsonb_build_object('year_story_id', r.id, 'group_id', v_group),
      'year.recompute:' || r.id::text);
  end loop;
  return null;
end;
$$;

create trigger post_tags_year_stories after insert or delete on public.post_tags
  for each row execute function private.year_stories_follow_tags();

revoke all on function private.year_stories_follow_tags() from public;
-- (create or replace keeps due_year_stories' grants: service role only)

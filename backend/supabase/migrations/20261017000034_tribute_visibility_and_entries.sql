-- =============================================================================
-- 0034 the birthday video is for the person; contributors get it once it is delivered; the app lists
-- the videos a person can watch.
--
-- Spec: "On the day, the person receives a tribute video" (Tribute / VidDay). Until now every member
-- but the honoree could read the tribute at any time, before the honoree had it, whether or not they
-- had contributed (0003 private.can_see_tribute). VidDay, the mechanics reference: "The final video is
-- private right from the start!" and "To automatically notify your contributors via email, click on
-- Share with Friends" (help.vidday.com/how-can-i-share-the-final-video, read 2026-10-17). So:
--   * the honoree reads it once delivered (unchanged);
--   * a contributor (a tribute_contributions row on its request) reads it once delivered — VidDay's
--     "Share with Friends" goes to the contributors after the video is finished;
--   * nobody else, and nobody before delivery (the worker uses the service role);
--   * a block with the honoree still hides it from a contributor.
-- The storage policy (g/<gid>/tributes/<id>/…) already asks private.can_see_tribute, so the video and
-- poster files follow. design/MERGE_DECISIONS.md FV-3.
--
-- group_tributes(p_group_id): the delivered birthday videos of a group the caller can watch (the
-- group screen's memory cards), newest first, with the birthday they celebrate and whether the
-- caller is the honoree.
-- =============================================================================

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
                        where c.request_id = t.request_id and c.contributor_id = auth.uid()))))
$$;

create function public.group_tributes(p_group_id uuid)
returns table (
  id uuid, group_id uuid, honoree_id uuid, poster_path text, birthday_date date, delivered_at timestamptz, for_me boolean
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
  select t.id, t.group_id, t.honoree_id, t.poster_path, r.birthday_date, t.delivered_at, t.honoree_id = auth.uid()
    from public.tributes t
    join public.tribute_requests r on r.id = t.request_id
   where t.group_id = p_group_id
     and t.status = 'ready'
     and private.can_see_tribute(t.id)
   order by t.delivered_at desc, t.id;
end;
$$;

revoke all on function public.group_tributes(uuid) from public, anon;
grant execute on function public.group_tributes(uuid) to authenticated;

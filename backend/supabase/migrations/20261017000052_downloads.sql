-- =============================================================================
-- 0052 downloads: all my photos (free) and an album in full quality (premium) (owner decision 34,
-- docs/RESEARCH_FEATURES_2026-10-17.md #2).
--
-- Mechanics: Yope's group menu "download all photos" (design/research/yope-a.md §2.13); Retro "Download your package"
-- (retro.app/downloads); Apple Shared Albums full-resolution saving (support.apple.com/108314). The apps save the
-- originals to the device's photo library themselves, page by page (signed URLs of the originals, as Save to Camera
-- Roll does — owner decision 28), so nothing is packaged or kept on the server.
--   * download_items('mine', null, p_before, p_limit): every photo and video you posted that is still posted in one
--     of your groups (one row per media, its first post), newest first — free;
--   * download_items('album', p_album_id): the album's photos you can see, all of them in album order (p_before and
--     p_limit do not apply) — premium (premium_required otherwise), members of the album's group only.
--   Rows carry the originals' paths, the caption and the day it was taken (taken_on, else the posting day); never a
--   number of photos (the apps page until a short page).
-- =============================================================================

create function public.download_items(
  p_scope text,
  p_album_id uuid default null,
  p_before timestamptz default null,
  p_limit integer default 100
)
returns table (
  post_id uuid,
  media_id uuid,
  kind public.media_kind,
  original_path text,
  front_original_path text,
  motion_path text,
  caption text,
  taken_on date,
  posted_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_limit integer := least(greatest(coalesce(p_limit, 100), 1), 200);
  v_group uuid;
begin
  if p_scope = 'mine' then
    if p_album_id is not null then
      raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_album_id';
    end if;
    return query
    select x.id, x.media_id, md.kind, md.original_path, md.front_original_path, md.motion_path, x.caption,
           coalesce(x.taken_on, md.taken_on), x.created_at
      from (
        select distinct on (p.media_id) p.id, p.media_id, p.caption, p.taken_on, p.created_at
          from public.posts p
         where p.author_id = v_uid
           and p.group_id in (select private.my_group_ids())
         order by p.media_id, p.created_at, p.id
      ) x
      join public.media md on md.id = x.media_id
     where p_before is null or x.created_at < p_before
     order by x.created_at desc, x.id desc
     limit v_limit;
  elsif p_scope = 'album' then
    select a.group_id into v_group from public.albums a where a.id = p_album_id;
    if v_group is null or not private.is_member(v_group) then
      raise exception 'album_not_found' using errcode = 'PT404';
    end if;
    if not private.has_premium(v_uid) then
      raise exception 'premium_required' using errcode = 'PT402';
    end if;
    return query
    select p.id, p.media_id, md.kind, md.original_path, md.front_original_path, md.motion_path, p.caption,
           coalesce(p.taken_on, md.taken_on), p.created_at
      from public.album_items ai
      join public.posts p on p.id = ai.post_id
      join public.media md on md.id = p.media_id
     where ai.album_id = p_album_id
       and private.can_see_post(p.id)
     order by ai.position, p.created_at, p.id
     limit 1000;
  else
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_scope';
  end if;
end;
$$;

revoke all on function public.download_items(text, uuid, timestamptz, integer) from public, anon;
grant execute on function public.download_items(text, uuid, timestamptz, integer) to authenticated;

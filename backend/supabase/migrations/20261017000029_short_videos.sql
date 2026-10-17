-- 0029 short videos: the length limit of a video post, enforced by the server (no client can bypass it).
--
-- The directive promises "short videos" (premium). The camera stops a recording at camera.capture.duration.videoMax
-- (10 s: Locket's "Longer videos / Record up to 10 seconds", design/research/locket.md §10); library picks are trimmed
-- to it on the device. Here:
--   * app_config.video_max_ms = 10000 (public: the apps may read it);
--   * create_post refuses a video whose media.duration_ms is longer, counted in whole seconds as the apps show it
--     ("0:10" is 10,000 to 10,999 ms: a recording stopped at the limit overshoots by a few frames), with
--     `video_too_long` (400, detail video_max_ms=…). media.duration_ms is required for video (media_video_duration)
--     and clients cannot update media rows;
--   * the worker cuts the stored video to video_max_ms when it transcodes (media.renditions) and writes the real
--     length into media.duration_ms, so a client that reports a false length still never stores a longer video.
-- Fails closed: with video_max_ms NULL no video can be posted.

insert into public.app_config (key, value, is_public, description) values
  ('video_max_ms', '10000', true,
   'Longest video post in milliseconds (camera.capture.duration.videoMax: Locket "Record up to 10 seconds", design/research/locket.md section 10). create_post refuses longer media (video_too_long, whole seconds as the apps show them); the worker cuts the stored video to it. NULL: no video can be posted.')
on conflict (key) do nothing;

-- create_post: + the length check (body otherwise as in 0017).
create or replace function public.create_post(
  p_media_id uuid,
  p_group_ids uuid[],
  p_caption text default null,
  p_voice_path text default null,
  p_voice_duration_ms integer default null,
  p_invitation_id uuid default null,
  p_reply_to_post_id uuid default null,
  p_voice_levels smallint[] default null
)
returns setof public.posts
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_now timestamptz := now();
  v_groups uuid[];
  v_group uuid;
  v_media public.media;
  v_inv public.daily_invitations;
  v_reply_group uuid;
  v_in_window boolean;
  v_post public.posts;
  v_video_max integer;
begin
  select coalesce(array_agg(distinct g), '{}') into v_groups
  from unnest(coalesce(p_group_ids, '{}'::uuid[])) as t(g) where g is not null;
  if cardinality(v_groups) = 0 then
    raise exception 'no_groups' using errcode = 'PT400';
  end if;
  foreach v_group in array v_groups loop
    if not private.is_member(v_group) then
      raise exception 'not_group_member' using errcode = 'PT403', detail = v_group::text;
    end if;
  end loop;

  select * into v_media from public.media md where md.id = p_media_id and md.owner_id = v_uid for update;
  if not found then
    raise exception 'media_not_found' using errcode = 'PT404';
  end if;
  -- premium gates video only; it never blocks anything else
  if v_media.kind = 'video' and not private.has_premium(v_uid) then
    raise exception 'premium_required' using errcode = 'PT402';
  end if;
  -- short videos: no longer than the camera's limit, in the whole seconds the apps show (0:10)
  if v_media.kind = 'video' then
    v_video_max := private.config_int('video_max_ms');
    if v_video_max is null or (v_media.duration_ms / 1000) * 1000 > v_video_max then
      raise exception 'video_too_long' using errcode = 'PT400', detail = 'video_max_ms=' || coalesce(v_video_max::text, 'null');
    end if;
  end if;

  if p_caption is not null and char_length(p_caption) > 1000 then
    raise exception 'invalid_caption' using errcode = 'PT400';
  end if;
  if p_voice_path is not null then
    if not private.is_own_upload(p_voice_path, v_uid) or coalesce(p_voice_duration_ms, 0) <= 0 then
      raise exception 'invalid_voice' using errcode = 'PT400';
    end if;
  elsif p_voice_duration_ms is not null then
    raise exception 'invalid_voice' using errcode = 'PT400';
  end if;
  if p_voice_levels is not null
     and (p_voice_path is null or not private.is_valid_voice_levels(p_voice_levels)) then
    raise exception 'invalid_voice' using errcode = 'PT400', detail = 'voice_levels';
  end if;

  if p_reply_to_post_id is not null then
    if not private.can_see_post(p_reply_to_post_id) then
      raise exception 'post_not_found' using errcode = 'PT404';
    end if;
    select p.group_id into v_reply_group from public.posts p where p.id = p_reply_to_post_id;
    if cardinality(v_groups) <> 1 or v_groups[1] <> v_reply_group then
      raise exception 'reply_group_mismatch' using errcode = 'PT400';
    end if;
  end if;

  -- An invitation only ever marks the post "in window"; outside the window (or for
  -- an unknown invitation) the post is an ordinary post. Never a "late" flag.
  if p_invitation_id is not null then
    select * into v_inv from public.daily_invitations d
     where d.id = p_invitation_id and private.is_member(d.group_id);
  end if;

  foreach v_group in array v_groups loop
    v_in_window := v_inv.id is not null
                   and v_inv.group_id = v_group
                   and v_now >= v_inv.fires_at
                   and v_now <= v_inv.closes_at;

    insert into public.posts (media_id, group_id, author_id, caption, voice_path, voice_duration_ms,
                              voice_levels, invitation_id, in_window, reply_to_post_id)
    values (v_media.id, v_group, v_uid, nullif(p_caption, ''), p_voice_path, p_voice_duration_ms,
            p_voice_levels, case when v_in_window then v_inv.id end, v_in_window, p_reply_to_post_id)
    on conflict (media_id, group_id) do nothing
    returning * into v_post;
    if not found then
      raise exception 'already_posted' using errcode = 'PT409', detail = v_group::text;
    end if;

    insert into public.messages (group_id, author_id, kind, post_id, reply_to_post_id)
    values (v_group, v_uid, 'photo', v_post.id, p_reply_to_post_id);

    perform private.enqueue('push.new_post',
      jsonb_build_object('post_id', v_post.id, 'group_id', v_group, 'author_id', v_uid));
    perform private.enqueue('widget.refresh',
      jsonb_build_object('group_id', v_group), 'widget.refresh:' || v_group::text);
    return next v_post;
  end loop;

  if v_media.renditions_ready_at is null then
    perform private.enqueue('media.renditions',
      jsonb_build_object('media_id', v_media.id), 'media.renditions:' || v_media.id::text);
  end if;
  return;
end;
$$;

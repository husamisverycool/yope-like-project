-- 0035 in-app answers to the open daily invitation.
--
-- A member who opens the app while their group's invitation is open answers it there exactly as from the
-- notification (owner audit 2026-10-17, item 3): the group screen shows the open invitation with its countdown and
-- opens the same daily capture (p_invitation_id), and the camera's send-to shows each chosen group's open invitation
-- and answers all of them at once. Evidence: BeReal "You have 2 minutes to open the app and take your BeReal"
-- (help.bereal.com/hc/en-us/articles/7350386715165, design/research/bereal.md "Timing rules") — the window counts,
-- not the way in. Tenet 5 holds: nothing marks a post taken after the window, and ignoring it changes nothing.
--   * open_invitations(p_group_ids): the caller's groups' invitations open now by the server's clock
--     (fires_at <= now() <= closes_at), soonest to close first; nothing before fires_at (the moment stays a
--     surprise, docs/API.md 5.12). Members only: a named group the caller is not in -> not_group_member (403).
--   * create_post: + p_invitation_ids uuid[]; each group's post answers that group's invitation among them while it
--     is open (in_window, invitation_id), as p_invitation_id does. Body otherwise as in 0029.

drop function public.create_post(uuid, uuid[], text, text, integer, uuid, uuid, smallint[]);

create function public.create_post(
  p_media_id uuid,
  p_group_ids uuid[],
  p_caption text default null,
  p_voice_path text default null,
  p_voice_duration_ms integer default null,
  p_invitation_id uuid default null,
  p_reply_to_post_id uuid default null,
  p_voice_levels smallint[] default null,
  p_invitation_ids uuid[] default null
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
  v_answering uuid[];
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

  -- The invitations being answered: p_invitation_id (one group's, from the notification or the group screen) and
  -- p_invitation_ids (each chosen group's open invitation, from the camera's send-to). An invitation only ever marks
  -- its own group's post "in window" while it is open; outside the window, for another group or an unknown id the
  -- post is an ordinary post. Never an error, never a "late" flag.
  v_answering := array_remove(array_append(coalesce(p_invitation_ids, '{}'::uuid[]), p_invitation_id), null);

  foreach v_group in array v_groups loop
    v_in_window := false;
    if cardinality(v_answering) > 0 then
      -- the caller is a member of v_group (checked above), so its invitations are theirs to answer
      select * into v_inv from public.daily_invitations d
       where d.group_id = v_group and d.id = any(v_answering)
         and v_now >= d.fires_at and v_now <= d.closes_at
       order by d.fires_at desc
       limit 1;
      v_in_window := found;
    end if;

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

create function public.open_invitations(p_group_ids uuid[] default null)
returns setof public.daily_invitations
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_group uuid;
begin
  perform private.require_user();
  foreach v_group in array coalesce(p_group_ids, '{}'::uuid[]) loop
    if v_group is not null and not private.is_member(v_group) then
      raise exception 'not_group_member' using errcode = 'PT403', detail = v_group::text;
    end if;
  end loop;
  return query
    select d.* from public.daily_invitations d
     where private.is_member(d.group_id)
       and (p_group_ids is null or d.group_id = any(p_group_ids))
       and d.fires_at <= now() and now() <= d.closes_at
     order by d.closes_at, d.group_id;
end;
$$;

revoke all on function public.create_post(uuid, uuid[], text, text, integer, uuid, uuid, smallint[], uuid[]),
                       public.open_invitations(uuid[]) from public, anon;
grant execute on function public.create_post(uuid, uuid[], text, text, integer, uuid, uuid, smallint[], uuid[]),
                          public.open_invitations(uuid[]) to authenticated;

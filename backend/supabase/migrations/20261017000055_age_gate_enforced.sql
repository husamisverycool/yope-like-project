-- =============================================================================
-- 0055 the age gate is enforced on the server (docs/API.md §12.6).
--
-- create_group, join_group and create_post raise age_not_confirmed (PT403) while the caller's
-- profile_private.age_confirmed_at is null, i.e. before confirm_age succeeded. The check comes first,
-- before any argument is looked at. Everything else (reading, chat, settings, delete_account) stays open:
-- the apps run the age gate during onboarding, before the first group.
-- The bodies are those of the latest definitions (0005, 0026, 0051) with the check added.
-- =============================================================================

create function private.age_confirmed(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.profile_private pp
                 where pp.user_id = p_user and pp.age_confirmed_at is not null)
$$;
revoke all on function private.age_confirmed(uuid) from public;

create function private.require_age_confirmed(p_user uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.age_confirmed(p_user) then
    raise exception 'age_not_confirmed' using errcode = 'PT403';
  end if;
end;
$$;
revoke all on function private.require_age_confirmed(uuid) from public;

create or replace function public.create_group(p_name text, p_kind public.group_kind, p_time_zone text, p_cover_path text default null, p_waking_start time default null, p_waking_end time default null)
returns public.groups
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_group public.groups;
begin
  perform private.require_age_confirmed(v_uid);
  if p_name is null or char_length(btrim(p_name)) not between 1 and 80 then
    raise exception 'invalid_name' using errcode = 'PT400';
  end if;
  if p_kind is null then
    raise exception 'invalid_kind' using errcode = 'PT400';
  end if;
  if not private.is_valid_time_zone(p_time_zone) then
    raise exception 'invalid_time_zone' using errcode = 'PT400';
  end if;
  if not private.waking_window_ok(p_waking_start, p_waking_end) then
    raise exception 'invalid_waking_window' using errcode = 'PT400';
  end if;
  if p_cover_path is not null and not private.is_own_upload(p_cover_path, v_uid) then
    raise exception 'invalid_path' using errcode = 'PT400', detail = 'cover_path must be under u/<your user id>/';
  end if;

  insert into public.groups (name, kind, cover_path, time_zone, waking_start, waking_end, created_by)
  values (btrim(p_name), p_kind, p_cover_path, p_time_zone, p_waking_start, p_waking_end, v_uid)
  returning * into v_group;

  insert into public.group_members (group_id, user_id, role) values (v_group.id, v_uid, 'admin');
  return v_group;
end;
$$;

create or replace function public.join_group(p_token text)
returns public.groups
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_invite public.group_invites;
  v_group public.groups;
begin
  perform private.require_age_confirmed(v_uid);
  select * into v_invite from public.group_invites i where i.token = p_token;
  if not found then
    raise exception 'invite_not_found' using errcode = 'PT404';
  end if;
  if not private.is_member_of(v_invite.group_id, v_uid) then
    if v_invite.revoked_at is not null then
      raise exception 'invite_revoked' using errcode = 'PT410';
    end if;
    if v_invite.expires_at is not null and v_invite.expires_at <= now() then
      raise exception 'invite_expired' using errcode = 'PT410';
    end if;
    insert into public.group_members (group_id, user_id, role)
    values (v_invite.group_id, v_uid, 'member')
    on conflict (group_id, user_id) do nothing;
  end if;
  select * into v_group from public.groups g where g.id = v_invite.group_id;
  return v_group;
end;
$$;

create or replace function public.create_post(
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
  perform private.require_age_confirmed(v_uid);
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

    if v_post.batch_id is null then
      perform private.enqueue('push.new_post',
        jsonb_build_object('post_id', v_post.id, 'group_id', v_group, 'author_id', v_uid));
    else
      -- photos sent together: one push for the batch (the newest photo of it), a few seconds after the last
      perform private.enqueue('push.new_post',
        jsonb_build_object('post_id', v_post.id, 'group_id', v_group, 'author_id', v_uid),
        'push.new_post:' || v_uid || ':' || v_post.batch_id || ':' || v_group,
        v_now + make_interval(secs => coalesce(private.config_int('batch_push_delay_s'), 0)));
    end if;
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

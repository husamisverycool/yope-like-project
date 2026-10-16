-- =============================================================================
-- 0017 voice levels: the waveform of a voice note (owner decision 16, docs/OWNER_DECISIONS.md).
--
-- The recording device samples the microphone level while recording and reduces it to
-- 100 values of 0…31 — the format of Telegram's documentAttributeAudio.waveform ("a series
-- of bitpacked 5-bit values", https://core.telegram.org/constructor/documentAttributeAudio;
-- its linked example implementation keeps 100 samples). Clients send the 100 values with the
-- note; every client draws the same bars (design/components.md C-36). Stored as a plain
-- smallint[] (no bit packing: 100 small integers, validated here).
--
-- posts.voice_levels    the photo's voice note (create_post p_voice_levels)
-- messages.voice_levels a voice message (send_message p_voice_levels)
--
-- Optional: notes sent before this migration, or by a client that sends none, keep NULL and
-- clients draw the sourced fallback (C-36). Levels without a voice note, a wrong count or a
-- value outside 0…31 are refused (invalid_voice; the check constraints back the RPCs up).
-- Reads follow the rows' existing RLS (posts_select / messages_select): nothing new to grant
-- on the tables. create_post and send_message gain a trailing defaulted parameter, so every
-- existing call (named or positional) keeps working; grants are re-issued for the new
-- signatures.
-- =============================================================================

create function private.is_valid_voice_levels(p_levels smallint[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_levels is null
      or (array_ndims(p_levels) = 1
          and cardinality(p_levels) = 100
          and array_position(p_levels, null) is null
          and 0 <= all (p_levels)
          and 31 >= all (p_levels))
$$;

revoke all on function private.is_valid_voice_levels(smallint[]) from public;
grant execute on function private.is_valid_voice_levels(smallint[]) to anon, authenticated, service_role;

alter table public.posts
  add column voice_levels smallint[],
  add constraint posts_voice_levels_valid check (private.is_valid_voice_levels(voice_levels)),
  add constraint posts_voice_levels_need_voice check (voice_levels is null or voice_path is not null);

alter table public.messages
  add column voice_levels smallint[],
  add constraint messages_voice_levels_valid check (private.is_valid_voice_levels(voice_levels)),
  add constraint messages_voice_levels_need_voice check (voice_levels is null or kind = 'voice');

-- ---------------------------------------------------------------------------
-- create_post: + p_voice_levels (body otherwise as in 0006).
drop function public.create_post(uuid, uuid[], text, text, integer, uuid, uuid);

create function public.create_post(
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

-- ---------------------------------------------------------------------------
-- send_message: + p_voice_levels (voice messages only; body otherwise as in 0006).
drop function public.send_message(uuid, public.message_kind, text, text, integer, uuid, uuid);

create function public.send_message(
  p_group_id uuid,
  p_kind public.message_kind,
  p_body text default null,
  p_voice_path text default null,
  p_voice_duration_ms integer default null,
  p_reply_to_post_id uuid default null,
  p_reply_to_message_id uuid default null,
  p_voice_levels smallint[] default null
)
returns public.messages
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_msg public.messages;
begin
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  if p_kind is null or p_kind = 'photo' then
    raise exception 'invalid_kind' using errcode = 'PT400', detail = 'photos are sent with create_post';
  end if;
  if p_kind = 'text' then
    if p_body is null or btrim(p_body) = '' or char_length(p_body) > 4000
       or p_voice_path is not null or p_voice_duration_ms is not null or p_voice_levels is not null then
      raise exception 'invalid_body' using errcode = 'PT400';
    end if;
  else -- voice
    if p_voice_path is null or not private.is_own_upload(p_voice_path, v_uid)
       or coalesce(p_voice_duration_ms, 0) <= 0 or p_body is not null then
      raise exception 'invalid_voice' using errcode = 'PT400';
    end if;
    if not private.is_valid_voice_levels(p_voice_levels) then
      raise exception 'invalid_voice' using errcode = 'PT400', detail = 'voice_levels';
    end if;
  end if;

  if p_reply_to_post_id is not null then
    if not private.can_see_post(p_reply_to_post_id) then
      raise exception 'post_not_found' using errcode = 'PT404';
    end if;
    if not exists (select 1 from public.posts p where p.id = p_reply_to_post_id and p.group_id = p_group_id) then
      raise exception 'reply_group_mismatch' using errcode = 'PT400';
    end if;
  end if;
  if p_reply_to_message_id is not null then
    if not exists (select 1 from public.messages m
                   where m.id = p_reply_to_message_id and m.group_id = p_group_id
                     and not private.is_blocked_with(m.author_id)) then
      raise exception 'message_not_found' using errcode = 'PT404';
    end if;
  end if;

  insert into public.messages (group_id, author_id, kind, body, voice_path, voice_duration_ms, voice_levels,
                               reply_to_post_id, reply_to_message_id)
  values (p_group_id, v_uid, p_kind, case when p_kind = 'text' then p_body end, p_voice_path,
          p_voice_duration_ms, p_voice_levels, p_reply_to_post_id, p_reply_to_message_id)
  returning * into v_msg;

  perform private.enqueue('push.new_message',
    jsonb_build_object('message_id', v_msg.id, 'group_id', p_group_id, 'author_id', v_uid));
  return v_msg;
end;
$$;

grant execute on function
  public.create_post(uuid, uuid[], text, text, integer, uuid, uuid, smallint[]),
  public.send_message(uuid, public.message_kind, text, text, integer, uuid, uuid, smallint[])
to authenticated;

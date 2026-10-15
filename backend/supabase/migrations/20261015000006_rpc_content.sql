-- =============================================================================
-- 0006 content RPCs: create_post, send_message, react, unreact, tag_self,
-- untag_self, delete_media, delete_post, delete_message.
-- =============================================================================

create function public.create_post(
  p_media_id uuid,
  p_group_ids uuid[],
  p_caption text default null,
  p_voice_path text default null,
  p_voice_duration_ms integer default null,
  p_invitation_id uuid default null,
  p_reply_to_post_id uuid default null
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
                              invitation_id, in_window, reply_to_post_id)
    values (v_media.id, v_group, v_uid, nullif(p_caption, ''), p_voice_path, p_voice_duration_ms,
            case when v_in_window then v_inv.id end, v_in_window, p_reply_to_post_id)
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
-- Text or voice messages. Photo messages are created by create_post (a reply
-- to a photo with a photo = create_post(..., p_reply_to_post_id)).
create function public.send_message(
  p_group_id uuid,
  p_kind public.message_kind,
  p_body text default null,
  p_voice_path text default null,
  p_voice_duration_ms integer default null,
  p_reply_to_post_id uuid default null,
  p_reply_to_message_id uuid default null
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
       or p_voice_path is not null or p_voice_duration_ms is not null then
      raise exception 'invalid_body' using errcode = 'PT400';
    end if;
  else -- voice
    if p_voice_path is null or not private.is_own_upload(p_voice_path, v_uid)
       or coalesce(p_voice_duration_ms, 0) <= 0 or p_body is not null then
      raise exception 'invalid_voice' using errcode = 'PT400';
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

  insert into public.messages (group_id, author_id, kind, body, voice_path, voice_duration_ms,
                               reply_to_post_id, reply_to_message_id)
  values (p_group_id, v_uid, p_kind, case when p_kind = 'text' then p_body end, p_voice_path,
          p_voice_duration_ms, p_reply_to_post_id, p_reply_to_message_id)
  returning * into v_msg;

  perform private.enqueue('push.new_message',
    jsonb_build_object('message_id', v_msg.id, 'group_id', p_group_id, 'author_id', v_uid));
  return v_msg;
end;
$$;

create function public.delete_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_msg public.messages;
begin
  select * into v_msg from public.messages m where m.id = p_message_id;
  if not found or v_msg.author_id <> v_uid or not private.is_member(v_msg.group_id) then
    raise exception 'message_not_found' using errcode = 'PT404';
  end if;
  if v_msg.kind = 'photo' then
    raise exception 'invalid_kind' using errcode = 'PT400', detail = 'delete the photo with delete_post';
  end if;
  delete from public.messages m where m.id = p_message_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Reactions are rows (user, emoji); there is no aggregate anywhere in the API.
create function public.react(p_post_id uuid, p_emoji text)
returns public.reactions
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_row public.reactions;
begin
  if not private.can_see_post(p_post_id) then
    raise exception 'post_not_found' using errcode = 'PT404';
  end if;
  if not coalesce(private.is_emoji(p_emoji), false) then
    raise exception 'invalid_emoji' using errcode = 'PT400';
  end if;
  insert into public.reactions (post_id, user_id, emoji)
  values (p_post_id, v_uid, p_emoji)
  on conflict (post_id, user_id, emoji) do nothing
  returning * into v_row;
  if found then
    perform private.enqueue('push.reaction',
      jsonb_build_object('post_id', p_post_id, 'group_id', v_row.group_id, 'user_id', v_uid, 'emoji', p_emoji));
  else
    select * into v_row from public.reactions r
     where r.post_id = p_post_id and r.user_id = v_uid and r.emoji = p_emoji;
  end if;
  return v_row;
end;
$$;

create function public.unreact(p_post_id uuid, p_emoji text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  if not private.can_see_post(p_post_id) then
    raise exception 'post_not_found' using errcode = 'PT404';
  end if;
  delete from public.reactions r
   where r.post_id = p_post_id and r.user_id = v_uid and r.emoji = p_emoji;
end;
$$;

-- ---------------------------------------------------------------------------
-- "I'm in this": self-tags only (no face recognition, nobody tags anyone else)
create function public.tag_self(p_post_id uuid)
returns public.post_tags
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_row public.post_tags;
begin
  if not private.can_see_post(p_post_id) then
    raise exception 'post_not_found' using errcode = 'PT404';
  end if;
  insert into public.post_tags (post_id, user_id) values (p_post_id, v_uid)
  on conflict (post_id, user_id) do nothing;
  select * into v_row from public.post_tags t where t.post_id = p_post_id and t.user_id = v_uid;
  return v_row;
end;
$$;

create function public.untag_self(p_post_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  delete from public.post_tags t where t.post_id = p_post_id and t.user_id = v_uid;
end;
$$;

-- ---------------------------------------------------------------------------
-- Deletion (owner only). The cascade itself lives in the 0004 triggers.
create function public.delete_media(p_media_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  perform 1 from public.media md where md.id = p_media_id and md.owner_id = v_uid for update;
  if not found then
    raise exception 'media_not_found' using errcode = 'PT404';
  end if;
  delete from public.media md where md.id = p_media_id;
end;
$$;

-- Removes the photo from one group. If it is then posted nowhere, the media and
-- its files are deleted too.
create function public.delete_post(p_post_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  perform 1 from public.posts p where p.id = p_post_id and p.author_id = v_uid for update;
  if not found then
    raise exception 'post_not_found' using errcode = 'PT404';
  end if;
  delete from public.posts p where p.id = p_post_id;
end;
$$;

grant execute on function
  public.create_post(uuid, uuid[], text, text, integer, uuid, uuid),
  public.send_message(uuid, public.message_kind, text, text, integer, uuid, uuid),
  public.delete_message(uuid),
  public.react(uuid, text),
  public.unreact(uuid, text),
  public.tag_self(uuid),
  public.untag_self(uuid),
  public.delete_media(uuid),
  public.delete_post(uuid)
to authenticated;

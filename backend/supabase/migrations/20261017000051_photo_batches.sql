-- =============================================================================
-- 0051 several photos in one post (owner decision 34, docs/RESEARCH_FEATURES_2026-10-17.md #1).
--
-- Mechanics: Retro's composer "Add to Your Week" picks several photos (repo screen 30); Apple Shared Albums "Select
-- all the items you want to add"; Instagram carousels (up to 20).
--   * media.batch_id uuid (client-written at insert, like taken_on): the composer gives every photo of one selection
--     the same id; posts.batch_id copies it. Each photo stays its own post (reactions, replies, tags, deletion, walls
--     and memories work per photo, as before); the apps show a batch's photos together — one chat bubble, swiped
--     through in the viewer, one tile in the strip — in the order they were posted.
--   * at most app_config batch_max_photos (20) photos per author, batch and group (invalid_items);
--   * one push per batch and group: push.new_post is enqueued with a dedupe key per (author, batch, group) and
--     app_config batch_push_delay_s (10) later, so the photos posted together are one notification ("{name} just
--     posted.", the newest photo of the batch); never a number of photos.
-- =============================================================================

insert into public.app_config (key, value, is_public, description) values
  ('batch_max_photos', '20', true,
   'Most photos one post (batch) can hold (Instagram carousels: up to 20). The composer stops at it; posting more in one batch fails with invalid_items.'),
  ('batch_push_delay_s', '10', false,
   'Seconds the new-photo push of a batch waits for the batch''s other photos, so they make one notification.')
on conflict (key) do nothing;

alter table public.media add column batch_id uuid;
grant insert (batch_id) on public.media to authenticated;
alter table public.posts add column batch_id uuid;
create index posts_batch_idx on public.posts (group_id, batch_id) where batch_id is not null;

create function private.posts_set_batch()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_max integer := private.config_int('batch_max_photos');
begin
  if new.batch_id is null then
    select md.batch_id into new.batch_id from public.media md where md.id = new.media_id;
  end if;
  if new.batch_id is not null and v_max is not null
     and (select count(*) from public.posts p
           where p.group_id = new.group_id and p.author_id = new.author_id and p.batch_id = new.batch_id) >= v_max then
    raise exception 'invalid_items' using errcode = 'PT400', detail = 'batch_max_photos';
  end if;
  return new;
end;
$$;
revoke all on function private.posts_set_batch() from public;
create trigger posts_set_batch before insert on public.posts
  for each row execute function private.posts_set_batch();

-- As in 0035, with one push per batch.
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

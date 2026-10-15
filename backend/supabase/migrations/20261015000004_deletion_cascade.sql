-- =============================================================================
-- 0004 deletion cascade (security invariant 2) + realtime deletion broadcasts.
--
-- Every path that removes content (delete_media, delete_post, delete_account,
-- leave_group of the last member, remove_member, admin tooling) goes through
-- these row triggers, so the cascade is identical whatever the entry point:
--
--   posts  deleted -> chat photo message, reactions, tags, album items, tribute
--                     contributions go by FK (ON DELETE CASCADE); replies keep
--                     existing with reply_to_* set to NULL;
--                  -> post id removed from collages.post_ids (collage paths
--                     deleted, collage.recompose), weekly_recaps.items,
--                     year_stories.post_ids (story data cleared, year.recompute);
--                  -> widget.refresh for the group; realtime broadcast;
--                  -> the media row is deleted once no post uses it.
--   media  deleted -> storage.delete for every path + the media folder.
--   tribute_contributions deleted -> tribute video cleared, tribute.rerender.
--   groups deleted -> storage.delete for g/<group_id>/ and its cover.
--
-- Recomposition never deletes a folder prefix (the worker may already be writing
-- the replacement); it deletes the exact old object paths only.
-- =============================================================================

create function private.group_alive(p_group uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.groups g where g.id = p_group)
$$;

-- Private realtime broadcast to the members of a group (topic "group:<id>").
-- Payloads carry ids only.
create function private.broadcast_group(p_group uuid, p_event text, p_payload jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform realtime.send(p_payload, p_event, 'group:' || p_group::text, true);
end;
$$;

-- Queued (not yet started) jobs about a deleted row have nothing left to do.
create function private.cancel_queued_jobs(p_kinds text[], p_key text, p_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.jobs j
     set status = 'cancelled', finished_at = now(), last_error = 'target deleted'
   where j.status = 'queued' and j.kind = any (p_kinds) and j.payload ->> p_key = p_id::text
$$;

create index jobs_queued_payload_idx on public.jobs (kind, (payload ->> 'post_id'), (payload ->> 'media_id'), (payload ->> 'message_id'))
  where status = 'queued';

create function private.voice_path_unreferenced(p_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (select 1 from public.posts p where p.voice_path = p_path)
     and not exists (select 1 from public.messages m where m.voice_path = p_path)
$$;

-- ---------------------------------------------------------------------------
-- posts
-- ---------------------------------------------------------------------------
create function private.on_post_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_alive boolean := private.group_alive(old.group_id);
  r record;
begin
  perform private.cancel_queued_jobs(array['push.new_post', 'push.reaction'], 'post_id', old.id);
  if old.voice_path is not null and private.voice_path_unreferenced(old.voice_path) then
    perform private.enqueue_storage_delete(array[old.voice_path]);
  end if;

  if v_alive then
    -- collages: drop the post, delete the old composed images, recompose
    for r in
      select c.id, c.image_path, c.widget_path, c.share_path,
             cardinality(array_remove(c.post_ids, old.id)) as remaining
      from public.collages c
      where c.group_id = old.group_id and c.post_ids @> array[old.id]
      for update
    loop
      perform private.enqueue_storage_delete(array[r.image_path, r.widget_path, r.share_path]);
      if r.remaining = 0 then
        delete from public.collages c where c.id = r.id;
      else
        update public.collages c
           set post_ids = array_remove(c.post_ids, old.id),
               image_path = null, widget_path = null, share_path = null,
               status = 'pending', composed_at = null
         where c.id = r.id;
        perform private.enqueue('collage.recompose',
          jsonb_build_object('collage_id', r.id, 'group_id', old.group_id),
          'collage.recompose:' || r.id::text);
      end if;
    end loop;

    -- weekly recaps: drop the item
    update public.weekly_recaps w
       set items = array_remove(w.items, old.id), updated_at = now()
     where w.group_id = old.group_id and w.items @> array[old.id];

    -- year stories: drop the post, clear the computed story, recompute
    for r in
      select y.id, y.asset_paths
      from public.year_stories y
      where y.group_id = old.group_id and y.post_ids @> array[old.id]
      for update
    loop
      perform private.enqueue_storage_delete(r.asset_paths);
      update public.year_stories y
         set post_ids = array_remove(y.post_ids, old.id),
             data = null, asset_paths = '{}', status = 'pending', generated_at = null
       where y.id = r.id;
      perform private.enqueue('year.recompute',
        jsonb_build_object('year_story_id', r.id, 'group_id', old.group_id),
        'year.recompute:' || r.id::text);
    end loop;

    perform private.enqueue('widget.refresh',
      jsonb_build_object('group_id', old.group_id), 'widget.refresh:' || old.group_id::text);
    perform private.broadcast_group(old.group_id, 'post_deleted',
      jsonb_build_object('post_id', old.id, 'media_id', old.media_id));
  end if;

  -- media posted nowhere any more -> delete it (its trigger deletes the objects)
  if not exists (select 1 from public.posts p where p.media_id = old.media_id) then
    delete from public.media md where md.id = old.media_id;
  end if;
  return null;
end;
$$;
create trigger posts_after_delete after delete on public.posts
  for each row execute function private.on_post_deleted();

-- ---------------------------------------------------------------------------
-- media
-- ---------------------------------------------------------------------------
create function private.on_media_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.cancel_queued_jobs(array['media.renditions'], 'media_id', old.id);
  perform private.enqueue_storage_delete(
    array[old.original_path, old.front_original_path, old.motion_path,
          old.display_path, old.thumb_path, old.widget_path,
          old.front_display_path, old.front_thumb_path],
    array['u/' || old.owner_id::text || '/' || old.id::text || '/']);
  return null;
end;
$$;
create trigger media_after_delete after delete on public.media
  for each row execute function private.on_media_deleted();

-- ---------------------------------------------------------------------------
-- messages
-- ---------------------------------------------------------------------------
create function private.on_message_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.cancel_queued_jobs(array['push.new_message'], 'message_id', old.id);
  if old.voice_path is not null and private.voice_path_unreferenced(old.voice_path) then
    perform private.enqueue_storage_delete(array[old.voice_path]);
  end if;
  if private.group_alive(old.group_id) then
    perform private.broadcast_group(old.group_id, 'message_deleted', jsonb_build_object('message_id', old.id));
  end if;
  return null;
end;
$$;
create trigger messages_after_delete after delete on public.messages
  for each row execute function private.on_message_deleted();

-- ---------------------------------------------------------------------------
-- reactions: tell members to refetch the post's reactions (no user/emoji in the
-- payload, so a block is never revealed)
-- ---------------------------------------------------------------------------
create function private.on_reaction_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.jobs j
     set status = 'cancelled', finished_at = now(), last_error = 'target deleted'
   where j.status = 'queued' and j.kind = 'push.reaction'
     and j.payload ->> 'post_id' = old.post_id::text
     and j.payload ->> 'user_id' = old.user_id::text
     and j.payload ->> 'emoji' = old.emoji;
  if private.group_alive(old.group_id) and exists (select 1 from public.posts p where p.id = old.post_id) then
    perform private.broadcast_group(old.group_id, 'reactions_changed', jsonb_build_object('post_id', old.post_id));
  end if;
  return null;
end;
$$;
create trigger reactions_after_delete after delete on public.reactions
  for each row execute function private.on_reaction_deleted();

-- ---------------------------------------------------------------------------
-- tribute contributions -> re-render an existing tribute
-- ---------------------------------------------------------------------------
create function private.on_tribute_contribution_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
begin
  for r in
    select t.id, t.group_id, t.video_path, t.poster_path
    from public.tributes t
    join public.tribute_requests q on q.id = t.request_id
    where t.request_id = old.request_id
    for update of t
  loop
    if private.group_alive(r.group_id) then
      perform private.enqueue_storage_delete(array[r.video_path, r.poster_path]);
      update public.tributes t
         set video_path = null, poster_path = null, status = 'pending', rendered_at = null
       where t.id = r.id;
      perform private.enqueue('tribute.rerender',
        jsonb_build_object('tribute_id', r.id, 'group_id', r.group_id),
        'tribute.rerender:' || r.id::text);
    end if;
  end loop;
  return null;
end;
$$;
create trigger tribute_contributions_after_delete after delete on public.tribute_contributions
  for each row execute function private.on_tribute_contribution_deleted();

-- ---------------------------------------------------------------------------
-- composed group assets deleted on their own (not via group deletion)
-- ---------------------------------------------------------------------------
create function private.on_group_asset_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.group_alive(old.group_id) then
    return null; -- the group's g/<id>/ prefix deletion covers it
  end if;
  if tg_table_name = 'collages' then
    perform private.enqueue_storage_delete(
      array[old.image_path, old.widget_path, old.share_path]);
  elsif tg_table_name = 'tributes' then
    perform private.enqueue_storage_delete(
      array[old.video_path, old.poster_path],
      array['g/' || old.group_id::text || '/tributes/' || old.id::text || '/']);
  elsif tg_table_name = 'year_stories' then
    perform private.enqueue_storage_delete(old.asset_paths);
  end if;
  return null;
end;
$$;
create trigger collages_after_delete after delete on public.collages
  for each row execute function private.on_group_asset_deleted();
create trigger tributes_after_delete after delete on public.tributes
  for each row execute function private.on_group_asset_deleted();
create trigger year_stories_after_delete after delete on public.year_stories
  for each row execute function private.on_group_asset_deleted();

-- ---------------------------------------------------------------------------
-- groups
-- ---------------------------------------------------------------------------
create function private.on_group_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cover text[];
begin
  if old.cover_path is not null
     and not exists (select 1 from public.groups g where g.cover_path = old.cover_path) then
    v_cover := array[old.cover_path];
  end if;
  -- (a group is deleted only when its last member leaves: nobody to notify, and
  -- nothing queued for it has anything left to do)
  update public.jobs j
     set status = 'cancelled', finished_at = now(), last_error = 'group deleted'
   where j.status = 'queued' and j.kind <> 'storage.delete' and j.payload ->> 'group_id' = old.id::text;
  perform private.enqueue_storage_delete(v_cover, array['g/' || old.id::text || '/']);
  return null;
end;
$$;
create trigger groups_after_delete after delete on public.groups
  for each row execute function private.on_group_deleted();

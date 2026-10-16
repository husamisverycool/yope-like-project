-- =============================================================================
-- 0018 selfie reactions: react to a photo with a front-camera selfie (BeReal's RealMoji mechanic,
-- design/research/selfie-reactions.md; tenets: shown as faces, never as a count).
--
-- selfie_reactions  one per person per post (a new one replaces yours); the image is the
--                   reacting member's own upload (u/<uid>/selfies/<uuid>.jpg).
-- Reads follow reactions: members of the post's group who can see the post, blocks hide both
-- ways. Writes only through react_with_selfie / remove_selfie_reaction (BeReal's help centre: one
-- per post, replaceable any time, never on your own post, and the post's author can delete
-- others'). A replaced or removed selfie's file is deleted by the worker (storage.delete). The
-- post's author is told once per person per post (push.selfie_reaction), as with emoji reactions.
-- A selfie can be reported (report target kind 'selfie', by the row's id).
-- =============================================================================

create table public.selfie_reactions (
  id         uuid not null default gen_random_uuid() unique,
  post_id    uuid not null references public.posts (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  group_id   uuid not null references public.groups (id) on delete cascade,
  image_path text not null check (private.is_safe_path(image_path)),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
alter table public.selfie_reactions enable row level security;
create index selfie_reactions_user_idx on public.selfie_reactions (user_id);
create index selfie_reactions_group_idx on public.selfie_reactions (group_id);
create index selfie_reactions_image_idx on public.selfie_reactions (image_path);

create trigger selfie_reactions_set_group before insert on public.selfie_reactions
  for each row execute function private.set_group_from_post();

create policy selfie_reactions_select on public.selfie_reactions for select to authenticated
  using (group_id in (select private.my_group_ids())
         and user_id not in (select private.blocked_ids())
         and private.can_see_post(post_id));
grant select on public.selfie_reactions to authenticated;

-- ---------------------------------------------------------------------------
create function public.react_with_selfie(p_post_id uuid, p_image_path text)
returns public.selfie_reactions
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_old text;
  v_row public.selfie_reactions;
begin
  if not private.can_see_post(p_post_id) then
    raise exception 'post_not_found' using errcode = 'PT404';
  end if;
  if not private.is_own_upload(p_image_path, v_uid) then
    raise exception 'invalid_image' using errcode = 'PT400';
  end if;
  if exists (select 1 from public.posts p where p.id = p_post_id and p.author_id = v_uid) then
    raise exception 'own_post' using errcode = 'PT400';
  end if;

  select s.image_path into v_old from public.selfie_reactions s
   where s.post_id = p_post_id and s.user_id = v_uid for update;

  insert into public.selfie_reactions (post_id, user_id, image_path)
  values (p_post_id, v_uid, p_image_path)
  on conflict (post_id, user_id) do update
    set image_path = excluded.image_path, created_at = now()
  returning * into v_row;

  if v_old is null then
    perform private.enqueue('push.selfie_reaction',
      jsonb_build_object('post_id', p_post_id, 'group_id', v_row.group_id, 'user_id', v_uid),
      'push.selfie_reaction:' || p_post_id::text || ':' || v_uid::text);
  elsif v_old <> p_image_path then
    perform private.enqueue_storage_delete(array[v_old]);
  end if;
  return v_row;
end;
$$;

-- Removes the caller's own selfie, or (the post's author) someone else's selfie on their post.
create function public.remove_selfie_reaction(p_post_id uuid, p_user_id uuid default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_target uuid := coalesce(p_user_id, v_uid);
begin
  if not private.can_see_post(p_post_id) then
    raise exception 'post_not_found' using errcode = 'PT404';
  end if;
  if v_target <> v_uid
     and not exists (select 1 from public.posts p where p.id = p_post_id and p.author_id = v_uid) then
    raise exception 'not_allowed' using errcode = 'PT403';
  end if;
  delete from public.selfie_reactions s where s.post_id = p_post_id and s.user_id = v_target;
end;
$$;

revoke all on function public.react_with_selfie(uuid, text), public.remove_selfie_reaction(uuid, uuid) from public, anon;
grant execute on function public.react_with_selfie(uuid, text), public.remove_selfie_reaction(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- A removed selfie (by its author, or with its post or group): delete the file, cancel an unsent
-- push, and tell members to refetch the post's reactions (no user in the payload, so a block is
-- never revealed).
create function private.on_selfie_reaction_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.enqueue_storage_delete(array[old.image_path]);
  update public.jobs j
     set status = 'cancelled', finished_at = now(), last_error = 'target deleted'
   where j.status = 'queued' and j.kind = 'push.selfie_reaction'
     and j.payload ->> 'post_id' = old.post_id::text
     and j.payload ->> 'user_id' = old.user_id::text;
  if private.group_alive(old.group_id) and exists (select 1 from public.posts p where p.id = old.post_id) then
    perform private.broadcast_group(old.group_id, 'reactions_changed', jsonb_build_object('post_id', old.post_id));
  end if;
  return null;
end;
$$;
create trigger selfie_reactions_after_delete after delete on public.selfie_reactions
  for each row execute function private.on_selfie_reaction_deleted();

alter publication supabase_realtime add table public.selfie_reactions;


-- ---------------------------------------------------------------------------
-- Reports: a selfie reaction (by its id) is a target, for members who can see it.
alter type public.report_target_kind add value if not exists 'selfie';

create or replace function public.report(p_target_kind public.report_target_kind, p_target_id uuid, p_reason text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_ok boolean;
  v_id uuid;
begin
  if p_reason is null or char_length(btrim(p_reason)) not between 1 and 1000 then
    raise exception 'invalid_reason' using errcode = 'PT400';
  end if;
  v_ok := case p_target_kind::text
    when 'post' then exists (select 1 from public.posts p where p.id = p_target_id and private.is_member(p.group_id))
    when 'message' then exists (select 1 from public.messages m where m.id = p_target_id and private.is_member(m.group_id))
    when 'user' then p_target_id <> v_uid
                     and (private.shares_group(v_uid, p_target_id) or private.is_blocked_with(p_target_id))
    when 'group' then private.is_member(p_target_id)
    when 'selfie' then exists (select 1 from public.selfie_reactions s
                               where s.id = p_target_id and s.user_id <> v_uid and private.can_see_post(s.post_id))
    else false
  end;
  if not coalesce(v_ok, false) then
    raise exception 'target_not_found' using errcode = 'PT404';
  end if;
  insert into public.reports (reporter_id, target_kind, target_id, reason)
  values (v_uid, p_target_kind, p_target_id, btrim(p_reason))
  returning id into v_id;
  perform private.enqueue('moderation.report', jsonb_build_object('report_id', v_id));
  return v_id;
end;
$$;
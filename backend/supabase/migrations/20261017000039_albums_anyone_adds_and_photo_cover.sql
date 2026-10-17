-- =============================================================================
-- 0039 albums anyone in the group can add to, and a photo of the group as its cover
-- (owner decision 34: "albums anyone can add to", "use a photo as the group cover";
-- docs/RESEARCH_FEATURES_2026-10-17.md #10 and #14).
--
-- Albums (mechanics reference: Apple Shared Albums, https://support.apple.com/en-us/108314, accessed 2026-10-17):
--   * "Select all the items you want to add … tap Add to Shared Album": any member adds any photo of the group they
--     can see (add_to_album); save_album still makes a new album from any selection of the group's photos, from any
--     weeks (it never limited the weeks; the apps' selection did).
--   * Removing: "Other participants can delete anything that they personally added"; the owner "can delete any
--     photos". Ours: the member who added a photo removes it; the album's creator and the group's admins (who may
--     already delete the album, 0008) remove any (remove_from_album). album_items.added_by records who added each
--     photo; items saved before this migration count as added by the album's creator.
--   * Removing a photo from an album never deletes the photo. Deleting a photo still removes it from every album
--     (album_items.post_id → posts on delete cascade, 0002).
--
-- Group cover from a photo (mechanics reference: Google Photos "Use as → Album cover",
-- https://support.google.com/photos/answer/6128849; Retro album covers): who may is update_group's rule — group
-- admins (docs/API.md §12.2, open decision; logged in design/MERGE_DECISIONS.md LM-3). The cover points at the
-- photo's display rendition (no copy), groups.cover_post_id remembers the photo, and deleting that photo removes it
-- as the cover too (tenet: deleting a photo removes it everywhere). Readers of the cover file are the readers of the
-- photo (storage: u/<owner>/<media_id>/… → can_see_media), so a member who blocked its author sees no cover image.
-- A cover that is a photo's rendition is never deleted as a "replaced cover" (update_group, group deletion): the
-- photo owns that file.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Albums: who added each photo.
alter table public.album_items
  add column added_by uuid references public.profiles (id) on delete set null,
  add column added_at timestamptz not null default now();
update public.album_items ai set added_by = a.created_by from public.albums a where a.id = ai.album_id;

create or replace function public.save_album(p_group_id uuid, p_name text, p_post_ids uuid[])
returns public.albums
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_album public.albums;
begin
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  if p_name is null or char_length(btrim(p_name)) not between 1 and 80 then
    raise exception 'invalid_name' using errcode = 'PT400';
  end if;
  perform private.assert_album_posts(p_group_id, p_post_ids);
  insert into public.albums (group_id, name, created_by) values (p_group_id, btrim(p_name), v_uid)
  returning * into v_album;
  insert into public.album_items (album_id, post_id, position, added_by)
  select v_album.id, t.x, (t.i - 1)::integer, v_uid from unnest(p_post_ids) with ordinality as t(x, i);
  return v_album;
end;
$$;

-- Any member adds photos of the album's group they can see, after the album's last item, in the given order.
-- Photos already in the album are skipped (idempotent). Returns the album (updated_at moves).
create function public.add_to_album(p_album_id uuid, p_post_ids uuid[])
returns public.albums
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_album public.albums;
  v_next integer;
begin
  select * into v_album from public.albums a where a.id = p_album_id for update;
  if not found or not private.is_member(v_album.group_id) then
    raise exception 'album_not_found' using errcode = 'PT404';
  end if;
  perform private.assert_album_posts(v_album.group_id, p_post_ids);
  select coalesce(max(ai.position) + 1, 0) into v_next from public.album_items ai where ai.album_id = p_album_id;
  insert into public.album_items (album_id, post_id, position, added_by)
  select p_album_id, n.x, v_next + (row_number() over (order by n.i))::integer - 1, v_uid
  from unnest(p_post_ids) with ordinality as n(x, i)
  where not exists (select 1 from public.album_items ai where ai.album_id = p_album_id and ai.post_id = n.x)
  order by n.i;
  update public.albums a set updated_at = now() where a.id = p_album_id returning * into v_album;
  return v_album;
end;
$$;

-- Removes photos from an album (never the photos themselves). Each must be in the album and either added by the
-- caller, or the caller is the album's creator or a group admin (Apple Shared Albums); otherwise nothing is removed
-- (not_allowed). Ids not in the album are ignored.
create function public.remove_from_album(p_album_id uuid, p_post_ids uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_album public.albums;
  v_manager boolean;
begin
  select * into v_album from public.albums a where a.id = p_album_id for update;
  if not found or not private.is_member(v_album.group_id) then
    raise exception 'album_not_found' using errcode = 'PT404';
  end if;
  if p_post_ids is null or cardinality(p_post_ids) = 0 or exists (select 1 from unnest(p_post_ids) x where x is null) then
    raise exception 'invalid_items' using errcode = 'PT400', detail = 'empty or null id';
  end if;
  v_manager := v_album.created_by = v_uid or private.is_admin(v_album.group_id);
  if not v_manager and exists (
    select 1 from public.album_items ai
    where ai.album_id = p_album_id and ai.post_id = any (p_post_ids) and ai.added_by is distinct from v_uid) then
    raise exception 'not_allowed' using errcode = 'PT403';
  end if;
  delete from public.album_items ai where ai.album_id = p_album_id and ai.post_id = any (p_post_ids);
  update public.albums a set updated_at = now() where a.id = p_album_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Group cover from a photo of the group.
-- No foreign key on purpose: a second relationship between groups and posts would make PostgREST's embedding of one
-- in the other ambiguous (PGRST201) for every client query that does it. The trigger below keeps it consistent
-- (deleting the post clears the cover), as a set-null key would.
alter table public.groups add column cover_post_id uuid;
create index groups_cover_post_idx on public.groups (cover_post_id) where cover_post_id is not null;

-- Admin only (update_group's rule). The photo must be a post of that group the caller can see, with its display
-- rendition made (a fresh post's renditions take seconds: media_not_ready).
create function public.set_group_cover_from_post(p_group_id uuid, p_post_id uuid)
returns public.groups
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group public.groups;
  v_path text;
  v_old_cover text;
  v_old_post uuid;
begin
  perform private.require_user();
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  if not private.is_admin(p_group_id) then
    raise exception 'not_group_admin' using errcode = 'PT403';
  end if;
  select md.display_path into v_path
  from public.posts p join public.media md on md.id = p.media_id
  where p.id = p_post_id and p.group_id = p_group_id and private.can_see_post(p.id);
  if not found then
    raise exception 'post_not_found' using errcode = 'PT404';
  end if;
  if v_path is null then
    raise exception 'media_not_ready' using errcode = 'PT409';
  end if;

  select g.cover_path, g.cover_post_id into v_old_cover, v_old_post from public.groups g where g.id = p_group_id for update;
  update public.groups g set cover_path = v_path, cover_post_id = p_post_id
   where g.id = p_group_id
  returning * into v_group;
  -- a replaced uploaded cover nobody uses any more is deleted (as update_group); a photo's rendition never is
  if v_old_cover is not null and v_old_post is null and v_old_cover is distinct from v_path
     and not exists (select 1 from public.groups g where g.cover_path = v_old_cover) then
    perform private.enqueue_storage_delete(array[v_old_cover]);
  end if;
  return v_group;
end;
$$;

-- update_group (0005) with the cover's photo forgotten when the cover changes, and a photo's rendition never deleted.
create or replace function public.update_group(
  p_group_id uuid,
  p_name text default null,
  p_kind public.group_kind default null,
  p_cover_path text default null,
  p_time_zone text default null
)
returns public.groups
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_group public.groups;
  v_old_cover text;
  v_old_post uuid;
begin
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  if not private.is_admin(p_group_id) then
    raise exception 'not_group_admin' using errcode = 'PT403';
  end if;
  if p_name is not null and char_length(btrim(p_name)) not between 1 and 80 then
    raise exception 'invalid_name' using errcode = 'PT400';
  end if;
  if p_time_zone is not null and not private.is_valid_time_zone(p_time_zone) then
    raise exception 'invalid_time_zone' using errcode = 'PT400';
  end if;
  if p_cover_path is not null and p_cover_path <> '' and not private.is_own_upload(p_cover_path, v_uid) then
    raise exception 'invalid_path' using errcode = 'PT400', detail = 'cover_path must be under u/<your user id>/';
  end if;

  select * into v_group from public.groups g where g.id = p_group_id for update;
  v_old_cover := v_group.cover_path;
  v_old_post := v_group.cover_post_id;

  if p_time_zone is not null and p_time_zone <> v_group.time_zone then
    perform private.cancel_scheduled_invitations(p_group_id);
  end if;

  update public.groups g
     set name = coalesce(btrim(p_name), g.name),
         kind = coalesce(p_kind, g.kind),
         cover_path = case when p_cover_path is null then g.cover_path
                           when p_cover_path = '' then null
                           else p_cover_path end,
         cover_post_id = case when p_cover_path is null then g.cover_post_id else null end,
         time_zone = coalesce(p_time_zone, g.time_zone)
   where g.id = p_group_id
  returning * into v_group;
  -- a replaced uploaded cover nobody uses any more is deleted; a photo's rendition belongs to the photo
  if v_old_cover is not null and v_old_post is null and v_old_cover is distinct from v_group.cover_path
     and not exists (select 1 from public.groups g where g.cover_path = v_old_cover) then
    perform private.enqueue_storage_delete(array[v_old_cover]);
  end if;
  return v_group;
end;
$$;

-- Deleting the cover's photo (in any way: delete_post, delete_media, account deletion) removes it as the cover.
create function private.on_post_deleted_cover()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.groups g set cover_path = null, cover_post_id = null where g.cover_post_id = old.id;
  return old;
end;
$$;
revoke all on function private.on_post_deleted_cover() from public;
create trigger posts_before_delete_cover before delete on public.posts
  for each row execute function private.on_post_deleted_cover();

-- Group deletion (0004) deletes an uploaded cover nobody else uses, never a photo's rendition.
create or replace function private.on_group_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cover text[];
begin
  if old.cover_path is not null and old.cover_post_id is null
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

revoke all on function
  public.add_to_album(uuid, uuid[]),
  public.remove_from_album(uuid, uuid[]),
  public.set_group_cover_from_post(uuid, uuid)
from public, anon;
grant execute on function
  public.add_to_album(uuid, uuid[]),
  public.remove_from_album(uuid, uuid[]),
  public.set_group_cover_from_post(uuid, uuid)
to authenticated;

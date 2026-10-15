-- =============================================================================
-- 0010 storage: private bucket `media` + RLS on storage.objects.
--
-- Path conventions (bucket `media`):
--   u/<uid>/<media_id>/...      originals (+ front image, live-photo motion, post voice
--                               note); renditions written by the worker (service role)
--   u/<uid>/voice/<uuid>.m4a    chat voice messages
--   u/<uid>/covers/<uuid>.jpg   group covers (passed to create_group / update_group)
--   avatars/<uid>/<uuid>.jpg    profile pictures
--   g/<group_id>/...            collages, tributes (g/<gid>/tributes/<tribute_id>/...),
--                               year stories, recap share images (service role writes)
-- Clients write only under u/<their uid>/ and avatars/<their uid>/ (insert only:
-- no overwrite). Reads are allowed when the caller can see the row that uses the
-- object. Clients read through signed URLs (createSignedUrl), never public URLs.
-- =============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'media', 'media', false, 104857600,
  array['image/jpeg', 'image/heic', 'image/heif', 'image/png', 'image/webp',
        'video/mp4', 'video/quicktime',
        'audio/mp4', 'audio/m4a', 'audio/x-m4a', 'audio/aac', 'audio/mpeg']
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create function private.can_write_object(p_name text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select auth.uid() is not null
     and private.is_safe_path(p_name)
     and (p_name like 'u/' || auth.uid()::text || '/%'
          or p_name like 'avatars/' || auth.uid()::text || '/%')
$$;

create function private.can_read_object(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_seg text[];
begin
  if v_uid is null or p_name is null or not private.is_safe_path(p_name) then
    return false;
  end if;
  v_seg := string_to_array(p_name, '/');

  if v_seg[1] = 'u' then
    if v_seg[2] = v_uid::text then
      return true;
    end if;
    -- u/<owner>/<media_id>/... : whoever can see that media
    if private.is_uuid(v_seg[2]) and private.is_uuid(v_seg[3])
       and exists (select 1 from public.media md where md.id = v_seg[3]::uuid and md.owner_id = v_seg[2]::uuid) then
      return private.can_see_media(v_seg[3]::uuid);
    end if;
    -- voice notes / covers referenced by rows the caller can see
    if exists (select 1 from public.messages m
               where m.voice_path = p_name
                 and m.group_id in (select private.my_group_ids())
                 and m.author_id not in (select private.blocked_ids())) then
      return true;
    end if;
    if exists (select 1 from public.posts p
               where p.voice_path = p_name
                 and p.group_id in (select private.my_group_ids())
                 and p.author_id not in (select private.blocked_ids())) then
      return true;
    end if;
    return exists (select 1 from public.groups g
                   where g.cover_path = p_name and g.id in (select private.my_group_ids()));

  elsif v_seg[1] = 'g' then
    if not private.is_uuid(v_seg[2]) or not private.is_member(v_seg[2]::uuid) then
      return false;
    end if;
    if v_seg[3] = 'tributes' then
      return private.is_uuid(v_seg[4])
         and exists (select 1 from public.tributes t where t.id = v_seg[4]::uuid and t.group_id = v_seg[2]::uuid)
         and private.can_see_tribute(v_seg[4]::uuid);
    end if;
    return true;

  elsif v_seg[1] = 'avatars' then
    return private.is_uuid(v_seg[2])
       and (v_seg[2] = v_uid::text or private.shares_group(v_uid, v_seg[2]::uuid));
  end if;
  return false;
end;
$$;

revoke all on function private.can_write_object(text), private.can_read_object(text) from public;
grant execute on function private.can_write_object(text), private.can_read_object(text) to authenticated, service_role;

create policy media_objects_insert_own on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and private.can_write_object(name));

create policy media_objects_select on storage.objects for select to authenticated
  using (bucket_id = 'media' and private.can_read_object(name));

-- Avatars may be replaced: the owner can delete their old avatar objects.
create policy media_objects_delete_own_avatar on storage.objects for delete to authenticated
  using (bucket_id = 'media'
         and private.is_safe_path(name)
         and name like 'avatars/' || (select auth.uid())::text || '/%');

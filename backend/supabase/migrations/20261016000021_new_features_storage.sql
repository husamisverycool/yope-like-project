-- =============================================================================
-- 0021 storage reads for the new features: a selfie reaction's image (0018) and a plan's cover
-- (0019) are the reacting member's / the plan maker's own uploads (u/<uid>/...), readable by
-- whoever can read the row that references them. An overnight photo (0020) is readable by nobody,
-- its owner included, until it has developed into a post. Everything else is unchanged from 0010.
-- =============================================================================

create or replace function private.can_read_object(p_name text)
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
    -- u/<owner>/<media_id>/... of a photo still developing (no post of it yet): nobody
    if private.is_uuid(v_seg[3])
       and exists (select 1 from public.developing_posts dp where dp.media_id = v_seg[3]::uuid)
       and not exists (select 1 from public.posts p where p.media_id = v_seg[3]::uuid) then
      return false;
    end if;
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
    -- a selfie reaction on a post the caller can see (blocks hide both ways)
    if exists (select 1 from public.selfie_reactions s
               where s.image_path = p_name
                 and s.group_id in (select private.my_group_ids())
                 and s.user_id not in (select private.blocked_ids())
                 and private.can_see_post(s.post_id)) then
      return true;
    end if;
    -- a plan's cover in one of the caller's groups
    if exists (select 1 from public.plans pl
               where pl.cover_path = p_name
                 and pl.group_id in (select private.my_group_ids())
                 and pl.created_by not in (select private.blocked_ids())) then
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

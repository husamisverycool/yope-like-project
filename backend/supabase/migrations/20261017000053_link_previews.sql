-- =============================================================================
-- 0053 link previews built on the sender's device (owner decision 34, docs/RESEARCH_FEATURES_2026-10-17.md #16:
-- https://developer.apple.com/documentation/linkpresentation; iMessage, WhatsApp).
--
-- The sender's app reads the page (LPMetadataProvider / its own fetch) once, uploads the preview image under its own
-- prefix and calls set_link_preview; the recipients' devices never contact the site (no IP or read signal leaks to
-- it), and the server never fetches anything.
--   * messages.link_preview jsonb: {url, title, site, image_path}; set_link_preview(p_message_id, p_url, p_title,
--     p_site, p_image_path) on your own text message whose text contains p_url (http/https); null clears it; members
--     get the Realtime UPDATE; no push;
--   * edit_message clears a preview whose url is no longer in the text;
--   * storage: members read the image as they read the message; replaced, cleared or deleted with the message, the
--     image is deleted.
-- =============================================================================

alter table public.messages add column link_preview jsonb;

create function public.set_link_preview(
  p_message_id uuid,
  p_url text,
  p_title text default null,
  p_site text default null,
  p_image_path text default null
)
returns public.messages
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_msg public.messages;
  v_preview jsonb;
begin
  select * into v_msg from public.messages m where m.id = p_message_id for update;
  if not found or v_msg.author_id <> v_uid or not private.is_member(v_msg.group_id) then
    raise exception 'message_not_found' using errcode = 'PT404';
  end if;
  if v_msg.kind <> 'text' then
    raise exception 'invalid_kind' using errcode = 'PT400', detail = 'only a text message has a link preview';
  end if;
  if p_url is null then
    v_preview := null;
  else
    if p_url !~* '^https?://[^\s]+$' or char_length(p_url) > 2000 or strpos(v_msg.body, p_url) = 0 then
      raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_url';
    end if;
    if char_length(coalesce(p_title, '')) > 300 or char_length(coalesce(p_site, '')) > 100 then
      raise exception 'invalid_text' using errcode = 'PT400';
    end if;
    if p_image_path is not null and not private.is_own_upload(p_image_path, v_uid) then
      raise exception 'invalid_path' using errcode = 'PT400';
    end if;
    v_preview := jsonb_strip_nulls(jsonb_build_object(
      'url', p_url, 'title', nullif(btrim(p_title), ''), 'site', nullif(btrim(p_site), ''), 'image_path', p_image_path));
  end if;
  update public.messages m set link_preview = v_preview where m.id = p_message_id returning * into v_msg;
  return v_msg;
end;
$$;

-- An image no longer used by its message (replaced, cleared, or the message deleted) is deleted.
create function private.on_link_preview_changed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old text := old.link_preview ->> 'image_path';
begin
  if v_old is not null and (tg_op = 'DELETE' or v_old is distinct from (new.link_preview ->> 'image_path')) then
    perform private.enqueue_storage_delete(array[v_old]);
  end if;
  return null;
end;
$$;
revoke all on function private.on_link_preview_changed() from public;
-- of body too: an edit's preview is cleared by a BEFORE trigger, which an UPDATE OF link_preview would not see
create trigger messages_link_preview_update after update of body, link_preview on public.messages
  for each row execute function private.on_link_preview_changed();
create trigger messages_link_preview_delete after delete on public.messages
  for each row when (old.link_preview is not null) execute function private.on_link_preview_changed();

-- An edit that drops the link drops its preview (as 0047, plus that).
create or replace function private.message_edit_clears_preview()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.link_preview is not null and new.body is distinct from old.body
     and strpos(coalesce(new.body, ''), new.link_preview ->> 'url') = 0 then
    new.link_preview := null;
  end if;
  return new;
end;
$$;
revoke all on function private.message_edit_clears_preview() from public;
create trigger messages_edit_clears_preview before update of body on public.messages
  for each row execute function private.message_edit_clears_preview();

-- As in 0021, plus link preview images.
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
    -- a link preview's image on a message the caller can see (0053)
    if exists (select 1 from public.messages m
               where m.link_preview ->> 'image_path' = p_name
                 and m.group_id in (select private.my_group_ids())
                 and m.author_id not in (select private.blocked_ids())) then
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

revoke all on function public.set_link_preview(uuid, text, text, text, text) from public, anon;
grant execute on function public.set_link_preview(uuid, text, text, text, text) to authenticated;

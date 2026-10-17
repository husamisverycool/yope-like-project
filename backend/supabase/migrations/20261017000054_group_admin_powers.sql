-- =============================================================================
-- 0054 group admin powers: admin_delete_post, admin_delete_message, set_member_role.
--
-- An admin of a group can remove anyone's photo or message in that group, and make
-- another member an admin or remove them as admin. A group never has zero admins while it
-- has members (0005 remove_membership hands the role on when the last admin leaves;
-- set_member_role refuses to dismiss the last one: `last_admin`).
--
-- The removals share their internals with the author deletes: the row delete lives in
-- private.delete_post_row / private.delete_message_row, and the 0004 triggers do the
-- cascade (reactions, tags, albums, recaps, collages, files, widgets, broadcasts). The
-- author RPCs are redefined to call the same helpers, with their errors unchanged.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Shared internals
-- ---------------------------------------------------------------------------

-- Deletes one post (one group's copy of a photo); the 0004 posts_after_delete trigger does
-- the cascade, and deletes the media when it is then posted nowhere.
create function private.delete_post_row(p_post_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.posts p where p.id = p_post_id;
end;
$$;

-- Deletes one text or voice message. Photo messages go with their post; the joined / left
-- lines are the group's record and are never deleted (0042).
create function private.delete_message_row(p_msg public.messages, p_photo_hint text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_msg.kind = 'photo' then
    raise exception 'invalid_kind' using errcode = 'PT400', detail = p_photo_hint;
  end if;
  if p_msg.kind in ('joined', 'left') then
    raise exception 'invalid_kind' using errcode = 'PT400', detail = 'a joined or left line cannot be deleted';
  end if;
  delete from public.messages m where m.id = p_msg.id;
end;
$$;

revoke all on function private.delete_post_row(uuid) from public;
revoke all on function private.delete_message_row(public.messages, text) from public;

-- ---------------------------------------------------------------------------
-- Author deletes, now through the shared internals (behaviour as in 0006 / 0042)
-- ---------------------------------------------------------------------------
create or replace function public.delete_post(p_post_id uuid)
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
  perform private.delete_post_row(p_post_id);
end;
$$;

create or replace function public.delete_message(p_message_id uuid)
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
  perform private.delete_message_row(v_msg, 'delete the photo with delete_post');
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin removals
-- ---------------------------------------------------------------------------

-- An admin removes anyone's photo from their group (the same cascade as delete_post).
-- Not a member of the post's group, or no such post: post_not_found (the post's existence
-- is not revealed outside its group). A member who is not an admin: not_group_admin.
create function public.admin_delete_post(p_post_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group uuid;
begin
  perform private.require_user();
  select p.group_id into v_group from public.posts p where p.id = p_post_id for update;
  if not found or not private.is_member(v_group) then
    raise exception 'post_not_found' using errcode = 'PT404';
  end if;
  if not private.is_admin(v_group) then
    raise exception 'not_group_admin' using errcode = 'PT403';
  end if;
  perform private.delete_post_row(p_post_id);
end;
$$;

-- An admin removes anyone's text or voice message in their group (the same cascade as
-- delete_message). A photo message goes with admin_delete_post (invalid_kind).
create function public.admin_delete_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_msg public.messages;
begin
  perform private.require_user();
  select * into v_msg from public.messages m where m.id = p_message_id for update;
  if not found or not private.is_member(v_msg.group_id) then
    raise exception 'message_not_found' using errcode = 'PT404';
  end if;
  if not private.is_admin(v_msg.group_id) then
    raise exception 'not_group_admin' using errcode = 'PT403';
  end if;
  perform private.delete_message_row(v_msg, 'remove the photo with admin_delete_post');
end;
$$;

-- ---------------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------------

-- Admin only. Makes a member an admin, or an admin a member (yourself included, while
-- another admin remains). Idempotent. The group row is locked first, as in
-- remove_membership, so two admins dismissing themselves at once cannot both succeed.
create function public.set_member_role(p_group_id uuid, p_user_id uuid, p_role public.member_role)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_user();
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  if not private.is_admin(p_group_id) then
    raise exception 'not_group_admin' using errcode = 'PT403';
  end if;
  if p_user_id is null then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_user_id';
  end if;
  if p_role is null then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_role';
  end if;
  perform 1 from public.groups g where g.id = p_group_id for no key update;
  -- re-checked under the lock: a concurrent call may have dismissed the caller
  if not private.is_admin(p_group_id) then
    raise exception 'not_group_admin' using errcode = 'PT403';
  end if;
  if not private.is_member_of(p_group_id, p_user_id) then
    raise exception 'member_not_found' using errcode = 'PT404';
  end if;
  if p_role = 'member' and not exists (
    select 1 from public.group_members m
     where m.group_id = p_group_id and m.role = 'admin' and m.user_id <> p_user_id
  ) then
    raise exception 'last_admin' using errcode = 'PT409', detail = 'make another member an admin first';
  end if;
  update public.group_members m set role = p_role
   where m.group_id = p_group_id and m.user_id = p_user_id and m.role <> p_role;
end;
$$;

revoke all on function
  public.admin_delete_post(uuid),
  public.admin_delete_message(uuid),
  public.set_member_role(uuid, uuid, public.member_role)
from public, anon;
grant execute on function
  public.admin_delete_post(uuid),
  public.admin_delete_message(uuid),
  public.set_member_role(uuid, uuid, public.member_role)
to authenticated;

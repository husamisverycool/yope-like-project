-- =============================================================================
-- 0005 group RPCs: create_group, update_group, create_invite, revoke_invite,
-- invite_preview (anon), join_group, remove_member, leave_group, set_group_muted,
-- set_group_invitation_hours, set_group_invitation_paused.
-- =============================================================================

-- Caller must be signed in and still have a profile (deleted accounts do not).
create function private.require_user()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null or not exists (select 1 from public.profiles p where p.id = v_uid) then
    raise exception 'not_authenticated' using errcode = 'PT401';
  end if;
  return v_uid;
end;
$$;

-- A path the user uploaded under their own prefix u/<uid>/...
create function private.is_own_upload(p_path text, p_user uuid)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select private.is_safe_path(p_path) and p_path like 'u/' || p_user::text || '/%'
$$;

create function private.first_name(p_display_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(split_part(btrim(coalesce(p_display_name, '')), ' ', 1), '')
$$;

-- Unfired invitations are recomputed after a change of hours / pause / time zone.
create function private.cancel_scheduled_invitations(p_group uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  for v_id in
    delete from public.daily_invitations d
     where d.group_id = p_group and d.status = 'scheduled' and d.fires_at > now()
    returning d.id
  loop
    update public.jobs j set status = 'cancelled', finished_at = now()
     where j.status = 'queued'
       and j.dedupe_key in ('invitation.fire:' || v_id::text, 'collage.compose:' || v_id::text);
  end loop;
end;
$$;

-- Deletes a group and (through FK cascades + triggers) all of its content.
create function private.delete_group(p_group uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.cancel_scheduled_invitations(p_group);
  delete from public.groups g where g.id = p_group;
end;
$$;

-- Removes one membership. Last member -> group deleted. Last admin -> the
-- longest-standing remaining member becomes admin.
create function private.remove_membership(p_group uuid, p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform 1 from public.groups g where g.id = p_group for no key update;
  delete from public.group_members m where m.group_id = p_group and m.user_id = p_user;
  if not found then
    return;
  end if;
  -- links they shared stop working; birthday requests about them in this group end
  update public.group_invites i set revoked_at = now()
   where i.group_id = p_group and i.created_by = p_user and i.revoked_at is null;
  delete from public.tribute_requests r where r.group_id = p_group and r.honoree_id = p_user;

  if not exists (select 1 from public.group_members m where m.group_id = p_group) then
    perform private.delete_group(p_group);
  elsif not exists (select 1 from public.group_members m where m.group_id = p_group and m.role = 'admin') then
    update public.group_members m set role = 'admin'
     where m.group_id = p_group
       and m.user_id = (select m2.user_id from public.group_members m2
                        where m2.group_id = p_group
                        order by m2.joined_at, m2.user_id
                        limit 1);
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
create function public.create_group(
  p_name text,
  p_kind public.group_kind,
  p_time_zone text,
  p_cover_path text default null,
  p_waking_start time default null,
  p_waking_end time default null
)
returns public.groups
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_group public.groups;
begin
  if p_name is null or char_length(btrim(p_name)) not between 1 and 80 then
    raise exception 'invalid_name' using errcode = 'PT400';
  end if;
  if p_kind is null then
    raise exception 'invalid_kind' using errcode = 'PT400';
  end if;
  if not private.is_valid_time_zone(p_time_zone) then
    raise exception 'invalid_time_zone' using errcode = 'PT400';
  end if;
  if (p_waking_start is null) <> (p_waking_end is null) or p_waking_start = p_waking_end then
    raise exception 'invalid_waking_window' using errcode = 'PT400';
  end if;
  if p_cover_path is not null and not private.is_own_upload(p_cover_path, v_uid) then
    raise exception 'invalid_path' using errcode = 'PT400', detail = 'cover_path must be under u/<your user id>/';
  end if;

  insert into public.groups (name, kind, cover_path, time_zone, waking_start, waking_end, created_by)
  values (btrim(p_name), p_kind, p_cover_path, p_time_zone, p_waking_start, p_waking_end, v_uid)
  returning * into v_group;

  insert into public.group_members (group_id, user_id, role) values (v_group.id, v_uid, 'admin');
  return v_group;
end;
$$;

-- Admin only. NULL argument = unchanged; p_cover_path = '' removes the cover.
create function public.update_group(
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

  if p_time_zone is not null and p_time_zone <> v_group.time_zone then
    perform private.cancel_scheduled_invitations(p_group_id);
  end if;

  update public.groups g
     set name = coalesce(btrim(p_name), g.name),
         kind = coalesce(p_kind, g.kind),
         cover_path = case when p_cover_path is null then g.cover_path
                           when p_cover_path = '' then null
                           else p_cover_path end,
         time_zone = coalesce(p_time_zone, g.time_zone)
   where g.id = p_group_id
  returning * into v_group;
  return v_group;
end;
$$;

-- ---------------------------------------------------------------------------
create function public.create_invite(p_group_id uuid)
returns public.group_invites
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_invite public.group_invites;
begin
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  insert into public.group_invites (group_id, created_by, expires_at)
  values (p_group_id, v_uid,
          now() + make_interval(secs => coalesce(private.config_int('invite_ttl_seconds'), 604800)))
  returning * into v_invite;
  return v_invite;
end;
$$;

create function public.revoke_invite(p_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_invite public.group_invites;
begin
  select * into v_invite from public.group_invites i where i.token = p_token;
  if not found or not private.is_member(v_invite.group_id) then
    raise exception 'invite_not_found' using errcode = 'PT404';
  end if;
  if v_invite.created_by <> v_uid and not private.is_admin(v_invite.group_id) then
    raise exception 'not_group_admin' using errcode = 'PT403';
  end if;
  update public.group_invites i set revoked_at = coalesce(i.revoked_at, now()) where i.id = v_invite.id;
end;
$$;

-- Callable by anon. Returns ONLY what a non-member may see before joining.
create function public.invite_preview(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_invite public.group_invites;
  v_group public.groups;
begin
  select * into v_invite from public.group_invites i where i.token = p_token;
  if not found then
    raise exception 'invite_not_found' using errcode = 'PT404';
  end if;
  if v_invite.revoked_at is not null then
    raise exception 'invite_revoked' using errcode = 'PT410';
  end if;
  if v_invite.expires_at <= now() then
    raise exception 'invite_expired' using errcode = 'PT410';
  end if;
  select * into v_group from public.groups g where g.id = v_invite.group_id;

  return jsonb_build_object(
    'group_name', v_group.name,
    'group_kind', v_group.kind,
    'cover_path', v_group.cover_path,
    'inviter_first_name',
      (select private.first_name(p.display_name) from public.profiles p where p.id = v_invite.created_by),
    'members', coalesce(
      (select jsonb_agg(jsonb_build_object('first_name', private.first_name(p.display_name),
                                           'avatar_path', p.avatar_path)
                        order by m.joined_at, m.user_id)
       from public.group_members m
       join public.profiles p on p.id = m.user_id
       where m.group_id = v_group.id),
      '[]'::jsonb));
end;
$$;

-- Idempotent: joining a group you are already in returns the group.
create function public.join_group(p_token text)
returns public.groups
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_invite public.group_invites;
  v_group public.groups;
begin
  select * into v_invite from public.group_invites i where i.token = p_token;
  if not found then
    raise exception 'invite_not_found' using errcode = 'PT404';
  end if;
  if not private.is_member_of(v_invite.group_id, v_uid) then
    if v_invite.revoked_at is not null then
      raise exception 'invite_revoked' using errcode = 'PT410';
    end if;
    if v_invite.expires_at <= now() then
      raise exception 'invite_expired' using errcode = 'PT410';
    end if;
    insert into public.group_members (group_id, user_id, role)
    values (v_invite.group_id, v_uid, 'member')
    on conflict (group_id, user_id) do nothing;
  end if;
  select * into v_group from public.groups g where g.id = v_invite.group_id;
  return v_group;
end;
$$;

create function public.remove_member(p_group_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  if not private.is_admin(p_group_id) then
    raise exception 'not_group_admin' using errcode = 'PT403';
  end if;
  if p_user_id = v_uid then
    raise exception 'cannot_target_self' using errcode = 'PT400', detail = 'use leave_group';
  end if;
  if not private.is_member_of(p_group_id, p_user_id) then
    raise exception 'member_not_found' using errcode = 'PT404';
  end if;
  perform private.remove_membership(p_group_id, p_user_id);
end;
$$;

create function public.leave_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  perform private.remove_membership(p_group_id, v_uid);
end;
$$;

create function public.set_group_muted(p_group_id uuid, p_muted boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  update public.group_members m set muted = coalesce(p_muted, false)
   where m.group_id = p_group_id and m.user_id = v_uid;
end;
$$;

-- Admin only (owner decision pending, see docs/API.md). Both NULL = use the default window.
create function public.set_group_invitation_hours(p_group_id uuid, p_start time, p_end time)
returns public.groups
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group public.groups;
begin
  perform private.require_user();
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  if not private.is_admin(p_group_id) then
    raise exception 'not_group_admin' using errcode = 'PT403';
  end if;
  if (p_start is null) <> (p_end is null) or p_start = p_end then
    raise exception 'invalid_waking_window' using errcode = 'PT400';
  end if;
  update public.groups g set waking_start = p_start, waking_end = p_end
   where g.id = p_group_id
  returning * into v_group;
  perform private.cancel_scheduled_invitations(p_group_id);
  return v_group;
end;
$$;

-- Admin only (owner decision pending, see docs/API.md).
create function public.set_group_invitation_paused(p_group_id uuid, p_paused boolean)
returns public.groups
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group public.groups;
begin
  perform private.require_user();
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  if not private.is_admin(p_group_id) then
    raise exception 'not_group_admin' using errcode = 'PT403';
  end if;
  if p_paused is null then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_paused';
  end if;
  update public.groups g set invitation_paused = p_paused
   where g.id = p_group_id
  returning * into v_group;
  if p_paused then
    perform private.cancel_scheduled_invitations(p_group_id);
  end if;
  return v_group;
end;
$$;

grant execute on function
  public.create_group(text, public.group_kind, text, text, time, time),
  public.update_group(uuid, text, public.group_kind, text, text),
  public.create_invite(uuid),
  public.revoke_invite(text),
  public.join_group(text),
  public.remove_member(uuid, uuid),
  public.leave_group(uuid),
  public.set_group_muted(uuid, boolean),
  public.set_group_invitation_hours(uuid, time, time),
  public.set_group_invitation_paused(uuid, boolean)
to authenticated;
grant execute on function public.invite_preview(text) to anon, authenticated;

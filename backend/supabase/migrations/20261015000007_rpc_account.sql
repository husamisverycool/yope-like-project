-- =============================================================================
-- 0007 account RPCs: delete_account, block_user, unblock_user, report,
-- register_device, unregister_device, set_quiet_hours, set_birthday, confirm_age.
-- =============================================================================

-- Security invariant 3: deletes everything the caller owns, then the worker
-- deletes the auth user (job auth.delete_user) and the storage prefixes.
create function public.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_group uuid;
begin
  -- 1. photos (full cascade: posts, chat photos, reactions, tags, recaps, albums,
  --    tribute contributions, collages, year stories, storage)
  delete from public.media md where md.owner_id = v_uid;
  -- 2. the rest of their content
  delete from public.messages m where m.author_id = v_uid;
  delete from public.reactions r where r.user_id = v_uid;
  delete from public.post_tags t where t.user_id = v_uid;
  delete from public.tribute_contributions c where c.contributor_id = v_uid;
  delete from public.tribute_requests q where q.honoree_id = v_uid;
  -- 3. memberships (admin hand-off; a group they were the last member of is deleted)
  for v_group in select m.group_id from public.group_members m where m.user_id = v_uid loop
    perform private.remove_membership(v_group, v_uid);
  end loop;
  update public.groups g set cover_path = null where g.cover_path like 'u/' || v_uid::text || '/%';
  delete from public.group_invites i where i.created_by = v_uid;
  -- 4. account rows
  delete from public.devices d where d.user_id = v_uid;
  delete from public.notification_settings s where s.user_id = v_uid;
  delete from public.blocks b where b.blocker_id = v_uid or b.blocked_id = v_uid;
  delete from public.reports r where r.reporter_id = v_uid;
  delete from public.entitlements e where e.user_id = v_uid;
  delete from public.profile_private pp where pp.user_id = v_uid;
  delete from public.profiles p where p.id = v_uid;
  -- 5. files and the auth user (worker, service role)
  perform private.enqueue_storage_delete(null,
    array['u/' || v_uid::text || '/', 'avatars/' || v_uid::text || '/']);
  perform private.enqueue('auth.delete_user', jsonb_build_object('user_id', v_uid),
    'auth.delete_user:' || v_uid::text);
end;
$$;

-- ---------------------------------------------------------------------------
create function public.block_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  if p_user_id = v_uid then
    raise exception 'cannot_target_self' using errcode = 'PT400';
  end if;
  if not exists (select 1 from public.profiles p where p.id = p_user_id) then
    raise exception 'user_not_found' using errcode = 'PT404';
  end if;
  insert into public.blocks (blocker_id, blocked_id) values (v_uid, p_user_id)
  on conflict (blocker_id, blocked_id) do nothing;
end;
$$;

create function public.unblock_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  delete from public.blocks b where b.blocker_id = v_uid and b.blocked_id = p_user_id;
end;
$$;

-- Reports are insert-only for clients; the target must be something the reporter
-- can reach (a block does not prevent reporting).
create function public.report(p_target_kind public.report_target_kind, p_target_id uuid, p_reason text)
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
  v_ok := case p_target_kind
    when 'post' then exists (select 1 from public.posts p where p.id = p_target_id and private.is_member(p.group_id))
    when 'message' then exists (select 1 from public.messages m where m.id = p_target_id and private.is_member(m.group_id))
    when 'user' then p_target_id <> v_uid
                     and (private.shares_group(v_uid, p_target_id) or private.is_blocked_with(p_target_id))
    when 'group' then private.is_member(p_target_id)
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

-- ---------------------------------------------------------------------------
-- A push token belongs to one account; registering it moves it to the caller.
create function public.register_device(
  p_platform public.device_platform,
  p_push_token text,
  p_push_to_start_token text default null,
  p_widget_push_token text default null
)
returns public.devices
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_row public.devices;
begin
  if p_platform is null then
    raise exception 'invalid_platform' using errcode = 'PT400';
  end if;
  if p_push_token is null or char_length(p_push_token) not between 1 and 4096 then
    raise exception 'invalid_token' using errcode = 'PT400';
  end if;
  if p_platform = 'android' and (p_push_to_start_token is not null or p_widget_push_token is not null) then
    raise exception 'invalid_token' using errcode = 'PT400', detail = 'push_to_start / widget tokens are iOS only';
  end if;
  insert into public.devices (user_id, platform, push_token, push_to_start_token, widget_push_token)
  values (v_uid, p_platform, p_push_token, p_push_to_start_token, p_widget_push_token)
  on conflict (push_token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        push_to_start_token = excluded.push_to_start_token,
        widget_push_token = excluded.widget_push_token
  returning * into v_row;
  return v_row;
end;
$$;

create function public.unregister_device(p_push_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  delete from public.devices d where d.user_id = v_uid and d.push_token = p_push_token;
end;
$$;

-- Both NULL = no quiet hours.
create function public.set_quiet_hours(p_start time, p_end time, p_time_zone text)
returns public.notification_settings
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_row public.notification_settings;
begin
  if (p_start is null) <> (p_end is null) or p_start = p_end then
    raise exception 'invalid_quiet_hours' using errcode = 'PT400';
  end if;
  if p_start is not null and not private.is_valid_time_zone(p_time_zone) then
    raise exception 'invalid_time_zone' using errcode = 'PT400';
  end if;
  if p_start is null and p_time_zone is not null and not private.is_valid_time_zone(p_time_zone) then
    raise exception 'invalid_time_zone' using errcode = 'PT400';
  end if;
  insert into public.notification_settings (user_id, quiet_start, quiet_end, time_zone)
  values (v_uid, p_start, p_end, p_time_zone)
  on conflict (user_id) do update
    set quiet_start = excluded.quiet_start, quiet_end = excluded.quiet_end, time_zone = excluded.time_zone
  returning * into v_row;
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- Optional birthday for tributes. Opting out cancels requests not yet due.
create function public.set_birthday(p_birthday date, p_opt_in boolean)
returns public.profile_private
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_row public.profile_private;
begin
  if p_opt_in is null then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_opt_in';
  end if;
  if p_opt_in and p_birthday is null then
    raise exception 'invalid_birthday' using errcode = 'PT400';
  end if;
  if p_birthday is not null and (p_birthday > current_date or p_birthday < date '1900-01-01') then
    raise exception 'invalid_birthday' using errcode = 'PT400';
  end if;
  insert into public.profile_private (user_id, birthday, birthday_opt_in)
  values (v_uid, p_birthday, p_opt_in)
  on conflict (user_id) do update set birthday = excluded.birthday, birthday_opt_in = excluded.birthday_opt_in
  returning * into v_row;
  if not p_opt_in then
    delete from public.tribute_requests r where r.honoree_id = v_uid and r.due_at > now();
  end if;
  return v_row;
end;
$$;

-- Age gate. Fails closed while min_age_years is not configured. The birthdate is
-- not stored (call set_birthday to opt in to birthday tributes).
create function public.confirm_age(p_birthdate date)
returns public.profile_private
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_min integer := private.config_int('min_age_years');
  v_today date := (now() at time zone 'UTC')::date;
  v_row public.profile_private;
begin
  if v_min is null then
    raise exception 'age_gate_not_configured' using errcode = 'PT503';
  end if;
  if p_birthdate is null or p_birthdate > v_today or p_birthdate < date '1900-01-01' then
    raise exception 'invalid_birthdate' using errcode = 'PT400';
  end if;
  if extract(year from age(v_today, p_birthdate)) < v_min then
    raise exception 'under_minimum_age' using errcode = 'PT403';
  end if;
  insert into public.profile_private (user_id, age_confirmed_at) values (v_uid, now())
  on conflict (user_id) do update set age_confirmed_at = coalesce(public.profile_private.age_confirmed_at, now())
  returning * into v_row;
  return v_row;
end;
$$;

grant execute on function
  public.delete_account(),
  public.block_user(uuid),
  public.unblock_user(uuid),
  public.report(public.report_target_kind, uuid, text),
  public.register_device(public.device_platform, text, text, text),
  public.unregister_device(text),
  public.set_quiet_hours(time, time, text),
  public.set_birthday(date, boolean),
  public.confirm_age(date)
to authenticated;

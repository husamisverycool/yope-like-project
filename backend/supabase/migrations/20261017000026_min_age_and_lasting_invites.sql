-- =============================================================================
-- 0026 minimum age 13 (owner decision 26) and invite links that never expire (decision 27),
-- docs/OWNER_DECISIONS.md 2026-10-17.
--
-- Minimum age. confirm_age failed closed (age_gate_not_configured) while min_age_years was NULL.
-- Every reference app's published terms set 13 as the age to sign up (read 2026-10-17; also
-- design/research/platform.md "auth.agegate — minimum age"):
--   * BeReal, Terms of Service (last updated September 11, 2026), section 1: "To use our services,
--     you must be a REAL human … who is at least 13 years old." — https://bereal.com/en/terms
--   * Locket, Terms of Service (effective May 25, 2022): "If you are under 13 years of age, you are
--     not authorized to use the Service, with or without registering." — https://locket.camera/terms
--   * Retro, Terms of Service (last updated April 18, 2024): users "between 13 years and 17 years
--     old" may use the Services with a parent's or guardian's agreement — https://retro.app/terms
--   * Yope, Terms §1d: "You affirm that you are 13 years of age or older" (design/research/yope-a.md
--     §2.3).
-- 13 is also COPPA's threshold (16 CFR 312.2, "child" = under 13). The refusal copy already reads
-- {min_age} from public_app_config, so no text changes.
--
-- Invite links. A link now works until an admin resets it or turns link sharing off (revoke_invite),
-- as WhatsApp group links stay valid until reset and Partiful links do not expire:
--   * invite_ttl_seconds NULL = no expiry; group_invites.expires_at becomes nullable (NULL = never);
--   * create_invite leaves expires_at NULL while the TTL is NULL (a TTL set later applies to new links);
--   * invite_preview / join_group refuse invite_expired only for a link that has an expiry and is
--     past it;
--   * links already shared and not revoked lose their 7-day expiry, so they keep working.
-- =============================================================================

update public.app_config
   set value = '13',
       description = 'Minimum age accepted by confirm_age: 13, the sign-up age in the terms of BeReal, Locket, Retro and Yope (owner decision 26, migration 0026)'
 where key = 'min_age_years';

update public.app_config
   set value = null,
       description = 'Lifetime in seconds of an invite link created by create_invite. NULL (owner decision 27, migration 0026): no expiry; a link works until it is revoked (reset or link sharing turned off)'
 where key = 'invite_ttl_seconds';

alter table public.group_invites alter column expires_at drop not null;

update public.group_invites set expires_at = null where revoked_at is null;

create or replace function public.create_invite(p_group_id uuid)
returns public.group_invites
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_ttl integer := private.config_int('invite_ttl_seconds');
  v_invite public.group_invites;
begin
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  insert into public.group_invites (group_id, created_by, expires_at)
  values (p_group_id, v_uid, case when v_ttl is null then null else now() + make_interval(secs => v_ttl) end)
  returning * into v_invite;
  return v_invite;
end;
$$;

-- As in 0016, with the expiry checked only for a link that has one.
create or replace function public.invite_preview(p_token text)
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
  if v_invite.expires_at is not null and v_invite.expires_at <= now() then
    raise exception 'invite_expired' using errcode = 'PT410';
  end if;
  select * into v_group from public.groups g where g.id = v_invite.group_id;

  return jsonb_build_object(
    'group_name', v_group.name,
    'group_kind', v_group.kind,
    'cover_path', v_group.cover_path,
    'inviter_first_name',
      (select private.first_name(p.display_name) from public.profiles p where p.id = v_invite.created_by),
    'inviter_avatar_path',
      (select p.avatar_path
         from public.group_members m
         join public.profiles p on p.id = m.user_id
        where m.group_id = v_group.id and m.user_id = v_invite.created_by),
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

-- As in 0005, with the expiry checked only for a link that has one.
create or replace function public.join_group(p_token text)
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
    if v_invite.expires_at is not null and v_invite.expires_at <= now() then
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

-- (create or replace keeps the existing grants: invite_preview anon + authenticated, the others authenticated)

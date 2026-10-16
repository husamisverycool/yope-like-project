-- =============================================================================
-- 0016 invite_preview: the inviter's avatar.
--
-- The invite page and the App Clip show the inviter's photo above "<first name> Invited You!"
-- (design/surfaces/invite.web.md, Retro's /u/ page). Until now the preview held the inviter's
-- first name only, so clients had to guess the inviter among the members by first name.
-- invite_preview now also returns inviter_avatar_path: the avatar of the invite's creator,
-- under the same rule as the member avatars it already returns — it is a current member's
-- profiles.avatar_path (a valid invite's creator is always a member: leaving or removal
-- revokes their invites, account deletion deletes them), else null. Non-members still cannot
-- read the object; the web service signs it like the other paths (docs/API.md section 6.1).
-- Signature, volatility, security and grants are unchanged (create or replace keeps grants).
-- =============================================================================

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

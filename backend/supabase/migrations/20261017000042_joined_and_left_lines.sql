-- =============================================================================
-- 0042 "{name} joined" and "{name} left the group" in the chat (owner decision 34, research #18).
--
-- Evidence: Yope's chat shows a system line when someone joins ("Kailyn joined", Business Insider 2025,
-- https://www.aol.com/trying-buzzy-social-media-platform-110601376.html; "Belle joined", design/research/yope-a.md
-- §2.12); Retro's threads show one when someone leaves ("✌️%1$s left the thread", APK strings
-- message_thread_user_left_message_template; the emoji is not copied).
--
-- messages.kind 'joined' / 'left': written here only (send_message refuses both through the shape check: neither
-- can carry what a text or voice message needs). author_id = the person; body = their display name at that moment,
-- so the line still names someone who left and no longer shares a group with the reader (profiles RLS hides them
-- then). Readers see the line under the messages RLS (members, minus a block with the person). No push is sent
-- (nothing is enqueued) and no count is involved.
--   joined: every new membership except the group's first member (its creator, create_group);
--   left:   leave_group only, when the group still has members afterwards (an admin's remove_member and account
--           deletion write no line; deleting the account deletes the person's lines with their other messages).
-- Clients: the line has no menu (no reply, react, edit, copy, report or unsend); delete_message refuses it.
-- =============================================================================

alter table public.messages drop constraint messages_kind_shape;
alter table public.messages add constraint messages_kind_shape check (
  case kind
    when 'text'   then body is not null and btrim(body) <> '' and post_id is null and voice_path is null
    when 'photo'  then post_id is not null and voice_path is null
    when 'voice'  then voice_path is not null and voice_duration_ms is not null and post_id is null
    when 'joined' then body is not null and post_id is null and voice_path is null
                       and reply_to_post_id is null and reply_to_message_id is null
    when 'left'   then body is not null and post_id is null and voice_path is null
                       and reply_to_post_id is null and reply_to_message_id is null
  end);

create function private.system_line(p_group uuid, p_user uuid, p_kind public.message_kind)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.messages (group_id, author_id, kind, body)
  select p_group, p_user, p_kind, p.display_name
    from public.profiles p where p.id = p_user;
end;
$$;
revoke all on function private.system_line(uuid, uuid, public.message_kind) from public;

-- "{name} joined": after every membership but the first (the creator's own, made with the group)
create function private.on_member_joined()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.group_members m where m.group_id = new.group_id and m.user_id <> new.user_id) then
    perform private.system_line(new.group_id, new.user_id, 'joined');
  end if;
  return null;
end;
$$;
revoke all on function private.on_member_joined() from public;
create trigger group_members_joined_line after insert on public.group_members
  for each row execute function private.on_member_joined();

-- "{name} left the group": as in 0005, plus the line when the group lives on
create or replace function public.leave_group(p_group_id uuid)
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
  if exists (select 1 from public.group_members m where m.group_id = p_group_id) then
    perform private.system_line(p_group_id, v_uid, 'left');
  end if;
end;
$$;

-- delete_message: the system lines are the group's record, not a message anyone unsends (body otherwise as in 0006)
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
  if v_msg.kind = 'photo' then
    raise exception 'invalid_kind' using errcode = 'PT400', detail = 'delete the photo with delete_post';
  end if;
  if v_msg.kind in ('joined', 'left') then
    raise exception 'invalid_kind' using errcode = 'PT400', detail = 'a joined or left line cannot be deleted';
  end if;
  delete from public.messages m where m.id = p_message_id;
end;
$$;

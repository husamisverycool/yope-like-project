-- =============================================================================
-- 0048 the typing line: "{name} is typing…" with names, never "N typing" and no read state (owner decision 34,
-- docs/RESEARCH_FEATURES_2026-10-17.md #20; WhatsApp typing indicators).
--
-- A broadcast from the typist would reach people they blocked (or who blocked them) — Realtime cannot filter a
-- broadcast per receiver — so typing is a row that Realtime checks against each subscriber's RLS like any message:
--   * chat_typing(group_id, user_id, until): one row per member and group, readable by members minus blocks both
--     ways; Realtime publishes its inserts and updates;
--   * set_typing(p_group_id, p_typing): typing → until = now() + typing_ttl_s (6 s; the apps call it again while
--     the person keeps typing, at most every few seconds); stopped or sent → until = now(). A row whose `until` has
--     passed means "not typing", so a closed app never leaves a line behind.
-- Leaving the group or deleting the account takes the row with it.
-- =============================================================================

insert into public.app_config (key, value, is_public, description) values
  ('typing_ttl_s', '6', true,
   'How long one set_typing call shows "{name} is typing…" without another, in seconds (WhatsApp shows the line for a few seconds after the last keystroke). The apps call set_typing again at most every typing_ttl_s / 2 while typing. NULL: set_typing records nothing.')
on conflict (key) do nothing;

create table public.chat_typing (
  group_id   uuid not null references public.groups (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  until      timestamptz not null,
  primary key (group_id, user_id)
);
alter table public.chat_typing enable row level security;
create index chat_typing_user_idx on public.chat_typing (user_id);

create policy chat_typing_select on public.chat_typing for select to authenticated
  using (group_id in (select private.my_group_ids())
         and user_id not in (select private.blocked_ids()));
grant select on public.chat_typing to authenticated;

alter publication supabase_realtime add table public.chat_typing;

create function public.set_typing(p_group_id uuid, p_typing boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_ttl integer := private.config_int('typing_ttl_s');
begin
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  if v_ttl is null then
    return;
  end if;
  insert into public.chat_typing (group_id, user_id, until)
  values (p_group_id, v_uid, case when p_typing then now() + make_interval(secs => v_ttl) else now() end)
  on conflict (group_id, user_id) do update set until = excluded.until;
end;
$$;

-- Leaving a group (or being removed) ends the person's typing row there.
create function private.on_member_left_typing()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.chat_typing t where t.group_id = old.group_id and t.user_id = old.user_id;
  return null;
end;
$$;
create trigger group_members_after_delete_typing after delete on public.group_members
  for each row execute function private.on_member_left_typing();
revoke all on function private.on_member_left_typing() from public;

revoke all on function public.set_typing(uuid, boolean) from public, anon;
grant execute on function public.set_typing(uuid, boolean) to authenticated;

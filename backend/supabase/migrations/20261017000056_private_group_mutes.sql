-- =============================================================================
-- 0056 muting a group is private (docs/API.md §12.12).
--
-- group_members.muted was readable by every co-member. It moves to group_mutes: one row per (group, person)
-- who muted the group, readable by that person only (RLS own rows; never published to Realtime). A row exists
-- only while its membership does (leaving, removal and account deletion remove it). set_group_muted keeps its
-- signature and errors; the worker reads group_mutes with the service role (push audiences).
-- =============================================================================

create table public.group_mutes (
  group_id   uuid not null,
  user_id    uuid not null,
  created_at timestamptz not null default now(),
  primary key (group_id, user_id),
  foreign key (group_id, user_id) references public.group_members (group_id, user_id) on delete cascade
);
alter table public.group_mutes enable row level security;
create index group_mutes_user_idx on public.group_mutes (user_id);

create policy group_mutes_select_own on public.group_mutes for select to authenticated
  using (user_id = (select auth.uid()));
grant select on public.group_mutes to authenticated;

insert into public.group_mutes (group_id, user_id)
select m.group_id, m.user_id from public.group_members m where m.muted;

alter table public.group_members drop column muted;

create or replace function public.set_group_muted(p_group_id uuid, p_muted boolean)
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
  if coalesce(p_muted, false) then
    insert into public.group_mutes (group_id, user_id) values (p_group_id, v_uid)
    on conflict (group_id, user_id) do nothing;
  else
    delete from public.group_mutes gm where gm.group_id = p_group_id and gm.user_id = v_uid;
  end if;
end;
$$;

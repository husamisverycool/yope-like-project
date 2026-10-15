-- =============================================================================
-- 0011 realtime
--
-- Postgres Changes: messages, posts, reactions are published; Realtime evaluates
-- each subscriber's SELECT policies before sending a row, so subscribers only get
-- rows of their groups minus blocked people.
--
-- Realtime does NOT apply RLS to DELETE events (it sends the primary key of every
-- deleted row to every subscriber of the table). To keep invariant 1 (no event of
-- group G reaches a non-member), the publication publishes INSERT and UPDATE only.
-- Deletions are announced on private broadcast topics "group:<group_id>"
-- (events post_deleted / message_deleted / reactions_changed, see 0004), which
-- only current members may join (policy on realtime.messages below). Clients send
-- nothing on these topics (no INSERT policy).
-- =============================================================================

alter publication supabase_realtime add table public.messages, public.posts, public.reactions;
alter publication supabase_realtime set (publish = 'insert, update');

create function private.can_join_topic(p_topic text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_topic is not null
     and p_topic ~ '^group:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     and private.is_member(substr(p_topic, 7)::uuid)
$$;
revoke all on function private.can_join_topic(text) from public;
grant execute on function private.can_join_topic(text) to authenticated, service_role;

create policy group_topic_members_receive on realtime.messages for select to authenticated
  using (realtime.messages.extension = 'broadcast'
         and private.can_join_topic((select realtime.topic())));

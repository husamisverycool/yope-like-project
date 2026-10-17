-- =============================================================================
-- 0047 reactions on chat messages; editing a sent text message or a photo's caption
-- (owner decision 34, docs/RESEARCH_FEATURES_2026-10-17.md #7 and #8).
--
-- Reactions on messages (iOS 18 Tapbacks with any emoji; Locket 2.68.0 "chat reactions"):
--   * message_reactions: one reaction per person per message (a Tapback replaces the last one), any emoji, on text
--     and voice messages (a photo message is reacted to through its post, `react`); joined / left lines take none;
--   * react_to_message(p_message_id, p_emoji) sets yours, unreact_to_message(p_message_id) removes it;
--   * rows (user, emoji) only — never a number (tenet: no counts); readable as the message is (members, blocks both
--     ways); no push (a reaction to a line of chat stays quiet);
--   * Realtime publishes inserts and updates; a removal is announced as `message_reactions_changed` on the group's
--     topic with the message id only (0011, as `reactions_changed`).
--
-- Editing (Apple Messages: "edit a sent message up to five times within 15 minutes"; WhatsApp edit; Retro captions):
--   * edit_message(p_message_id, p_body): your own text message, while app_config message_edit_window_s (900) has
--     not passed since it was sent and it was edited fewer than message_edit_max (5) times; otherwise
--     `edit_window_closed` (409). messages.edited_at marks it ("Edited"); earlier versions are not kept, only the
--     times of the edits (private.message_edits, for the limit). No push; Realtime sends the UPDATE.
--   * edit_caption(p_post_id, p_caption): your own photo's caption, any time; an empty caption removes it.
--     posts.caption_edited_at marks it.
-- =============================================================================

insert into public.app_config (key, value, is_public, description) values
  ('message_edit_window_s', '900', true,
   'How long after sending a text message can be edited, in seconds (chat.thread.duration.editWindow: Apple Messages, 15 minutes). edit_message refuses later edits (edit_window_closed).'),
  ('message_edit_max', '5', true,
   'How many times a sent text message can be edited (chat.thread.count.editMax: Apple Messages, five times). edit_message refuses more (edit_window_closed).')
on conflict (key) do nothing;

alter table public.messages add column edited_at timestamptz;
alter table public.posts add column caption_edited_at timestamptz;

-- ---------------------------------------------------------------------------
-- message_reactions
-- ---------------------------------------------------------------------------
create table public.message_reactions (
  message_id uuid not null references public.messages (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  emoji      text not null check (private.is_emoji(emoji)),
  group_id   uuid not null references public.groups (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (message_id, user_id)
);
alter table public.message_reactions enable row level security;
create index message_reactions_user_idx on public.message_reactions (user_id);
create index message_reactions_group_idx on public.message_reactions (group_id);

create policy message_reactions_select on public.message_reactions for select to authenticated
  using (group_id in (select private.my_group_ids())
         and user_id not in (select private.blocked_ids())
         and exists (select 1 from public.messages m
                      where m.id = message_id and m.author_id not in (select private.blocked_ids())));
grant select on public.message_reactions to authenticated;

alter publication supabase_realtime add table public.message_reactions;

create function private.on_message_reaction_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if private.group_alive(old.group_id) and exists (select 1 from public.messages m where m.id = old.message_id) then
    perform private.broadcast_group(old.group_id, 'message_reactions_changed', jsonb_build_object('message_id', old.message_id));
  end if;
  return null;
end;
$$;
create trigger message_reactions_after_delete after delete on public.message_reactions
  for each row execute function private.on_message_reaction_deleted();
revoke all on function private.on_message_reaction_deleted() from public;

-- The message a caller may react to or edit: a member's view of it (blocks both ways hide it).
create function private.visible_message(p_message_id uuid)
returns public.messages
language sql
stable
security definer
set search_path = ''
as $$
  select m.* from public.messages m
   where m.id = p_message_id
     and private.is_member(m.group_id)
     and m.author_id not in (select private.blocked_ids())
$$;
revoke all on function private.visible_message(uuid) from public;

create function public.react_to_message(p_message_id uuid, p_emoji text)
returns public.message_reactions
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_msg public.messages := private.visible_message(p_message_id);
  v_row public.message_reactions;
begin
  if v_msg.id is null then
    raise exception 'message_not_found' using errcode = 'PT404';
  end if;
  if v_msg.kind not in ('text', 'voice') then
    raise exception 'invalid_kind' using errcode = 'PT400', detail = 'react to a photo with react; joined and left lines take no reaction';
  end if;
  if not coalesce(private.is_emoji(p_emoji), false) then
    raise exception 'invalid_emoji' using errcode = 'PT400';
  end if;
  insert into public.message_reactions (message_id, user_id, emoji, group_id)
  values (p_message_id, v_uid, p_emoji, v_msg.group_id)
  on conflict (message_id, user_id) do update set emoji = excluded.emoji, created_at = now()
  returning * into v_row;
  return v_row;
end;
$$;

create function public.unreact_to_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  if (private.visible_message(p_message_id)).id is null then
    raise exception 'message_not_found' using errcode = 'PT404';
  end if;
  delete from public.message_reactions r where r.message_id = p_message_id and r.user_id = v_uid;
end;
$$;

-- ---------------------------------------------------------------------------
-- editing
-- ---------------------------------------------------------------------------
-- When each edit happened (never the earlier text): the limit counts them. Service role only.
create table private.message_edits (
  message_id uuid not null references public.messages (id) on delete cascade,
  edited_at  timestamptz not null default now()
);
create index message_edits_message_idx on private.message_edits (message_id);

create function public.edit_message(p_message_id uuid, p_body text)
returns public.messages
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_msg public.messages;
  v_window integer := private.config_int('message_edit_window_s');
  v_max integer := private.config_int('message_edit_max');
begin
  select * into v_msg from public.messages m where m.id = p_message_id for update;
  if not found or v_msg.author_id <> v_uid or not private.is_member(v_msg.group_id) then
    raise exception 'message_not_found' using errcode = 'PT404';
  end if;
  if v_msg.kind <> 'text' then
    raise exception 'invalid_kind' using errcode = 'PT400', detail = 'only a text message can be edited';
  end if;
  if p_body is null or btrim(p_body) = '' or char_length(p_body) > 4000 then
    raise exception 'invalid_body' using errcode = 'PT400';
  end if;
  -- Fails closed: without the settings no message can be edited.
  if v_window is null or v_max is null
     or now() > v_msg.created_at + make_interval(secs => v_window)
     or (select count(*) from private.message_edits e where e.message_id = p_message_id) >= v_max then
    raise exception 'edit_window_closed' using errcode = 'PT409';
  end if;
  if p_body = v_msg.body then
    return v_msg;
  end if;
  insert into private.message_edits (message_id) values (p_message_id);
  update public.messages m set body = p_body, edited_at = now() where m.id = p_message_id
  returning * into v_msg;
  return v_msg;
end;
$$;

create function public.edit_caption(p_post_id uuid, p_caption text)
returns public.posts
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_post public.posts;
  v_caption text := nullif(btrim(coalesce(p_caption, '')), '');
begin
  select * into v_post from public.posts p where p.id = p_post_id for update;
  if not found or v_post.author_id <> v_uid or not private.is_member(v_post.group_id) then
    raise exception 'post_not_found' using errcode = 'PT404';
  end if;
  if v_caption is not null and char_length(v_caption) > 1000 then
    raise exception 'invalid_caption' using errcode = 'PT400';
  end if;
  if v_caption is not distinct from v_post.caption then
    return v_post;
  end if;
  update public.posts p set caption = v_caption, caption_edited_at = now() where p.id = p_post_id
  returning * into v_post;
  return v_post;
end;
$$;

revoke all on function public.react_to_message(uuid, text), public.unreact_to_message(uuid),
                       public.edit_message(uuid, text), public.edit_caption(uuid, text) from public, anon;
grant execute on function public.react_to_message(uuid, text), public.unreact_to_message(uuid),
                          public.edit_message(uuid, text), public.edit_caption(uuid, text) to authenticated;

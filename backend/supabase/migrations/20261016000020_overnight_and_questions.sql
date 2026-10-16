-- =============================================================================
-- 0020 overnight photos and the weekly group question (design/research/overnight-and-questions.md,
-- overnight-and-questions-data.md; surfaces camera.overnight, question.weekly).
--
-- Overnight photos (Dispo: "Photos develop every day at 9am"): a photo taken in 9 AM mode is held in
-- developing_posts and becomes an ordinary post only at the first reveal time (app_config
-- overnight_reveal_local_time, group time zone) after it was taken. Until then nobody sees it, the
-- sender included: it is not a post, so no post read path (feeds, walls, weeks, On This Day) reaches
-- it, and storage refuses its files to everyone (0021). Clients learn only that the group has photos
-- developing and when they reveal (group_developing / my_developing): never a number, never a name.
-- The developed post keeps the time it was taken (created_at), so it lands in the right day and week;
-- it gets its chat photo message as every post does. At each reveal the group's members hear once
-- (push.photos_developed), unless they turned overnight alerts off (notification_settings.overnight)
-- or muted the group.
--
-- Weekly question: once a week a group that turned it on (groups.weekly_question, admins) is asked one
-- light question (group_questions), created when a member first opens the group that week. The
-- questions are copy keys (app_config weekly_question_keys, asked in order, as Retro cycles its
-- prompts); with no keys configured nothing is asked. Answered with ordinary posts linked to it
-- (answer_question); a member can remove the card for the week (hide_question). Never obligatory:
-- no push, no reminder, no streak, nothing that counts or names who answered.
-- =============================================================================

insert into public.app_config (key, value, is_public, description) values
  ('overnight_reveal_local_time', '"09:00"', true,
   'Overnight photos reveal at the first occurrence of this local time (group time zone) after they were taken (Dispo: "Photos develop every day at 9am"; design/research/overnight-and-questions.md)'),
  ('weekly_question_keys', null, true,
   'Ordered copy keys of the weekly questions (question.weekly.q*), asked in order; NULL until the catalogue and its order are decided, and then no question is asked')
on conflict (key) do nothing;

alter table public.notification_settings add column overnight boolean not null default true;
-- set on posts that developed overnight: the reveal time they joined the group at
alter table public.posts add column revealed_at timestamptz;
alter table public.groups add column weekly_question boolean not null default false;

-- ---------------------------------------------------------------------------
-- Overnight photos
-- ---------------------------------------------------------------------------
create table public.developing_posts (
  id          uuid primary key default gen_random_uuid(),
  media_id    uuid not null references public.media (id) on delete cascade,
  group_id    uuid not null references public.groups (id) on delete cascade,
  author_id   uuid not null references public.profiles (id) on delete cascade,
  develops_at timestamptz not null,
  created_at  timestamptz not null default now(),
  unique (media_id, group_id)
);
-- No policy and no grant: clients read only group_developing / my_developing.
alter table public.developing_posts enable row level security;
create index developing_posts_due_idx on public.developing_posts (develops_at);
create index developing_posts_group_idx on public.developing_posts (group_id, develops_at);
create index developing_posts_author_idx on public.developing_posts (author_id);

-- The first reveal time (local) strictly after p_at in p_tz.
create function private.next_reveal_at(p_at timestamptz, p_tz text)
returns timestamptz
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_time time := coalesce(private.config_text('overnight_reveal_local_time')::time, time '09:00');
  v_local timestamp := p_at at time zone p_tz;
  v_candidate timestamp := date_trunc('day', v_local) + v_time;
begin
  if v_candidate <= v_local then
    v_candidate := v_candidate + interval '1 day';
  end if;
  return v_candidate at time zone p_tz;
end;
$$;

create function public.create_overnight_post(p_media_id uuid, p_group_ids uuid[])
returns table (group_id uuid, develops_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_groups uuid[];
  v_group uuid;
  v_media public.media;
  v_tz text;
  v_at timestamptz;
begin
  select coalesce(array_agg(distinct x), '{}') into v_groups
  from unnest(coalesce(p_group_ids, '{}'::uuid[])) as t(x) where x is not null;
  if cardinality(v_groups) = 0 then
    raise exception 'no_groups' using errcode = 'PT400';
  end if;
  foreach v_group in array v_groups loop
    if not private.is_member(v_group) then
      raise exception 'not_group_member' using errcode = 'PT403', detail = v_group::text;
    end if;
  end loop;
  select * into v_media from public.media md where md.id = p_media_id and md.owner_id = v_uid for update;
  if not found then
    raise exception 'media_not_found' using errcode = 'PT404';
  end if;
  -- photos only (no Live Photo motion, no video)
  if v_media.kind <> 'photo' then
    raise exception 'develop_photo_only' using errcode = 'PT400';
  end if;

  foreach v_group in array v_groups loop
    if exists (select 1 from public.posts p where p.media_id = v_media.id and p.group_id = v_group)
       or exists (select 1 from public.developing_posts dp where dp.media_id = v_media.id and dp.group_id = v_group) then
      raise exception 'already_posted' using errcode = 'PT409', detail = v_group::text;
    end if;
    select g.time_zone into v_tz from public.groups g where g.id = v_group;
    v_at := private.next_reveal_at(now(), v_tz);
    insert into public.developing_posts (media_id, group_id, author_id, develops_at)
    values (v_media.id, v_group, v_uid, v_at);
    -- members refetch whether the group has photos developing (no user, no photo in the payload)
    perform private.broadcast_group(v_group, 'developing_changed', '{}'::jsonb);
    group_id := v_group;
    develops_at := v_at;
    return next;
  end loop;

  if v_media.renditions_ready_at is null then
    perform private.enqueue('media.renditions',
      jsonb_build_object('media_id', v_media.id), 'media.renditions:' || v_media.id::text);
  end if;
end;
$$;

-- Whether the group has photos developing (by people the caller has no block with) and the next reveal.
create function public.group_developing(p_group_id uuid)
returns table (developing boolean, reveal_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_user();
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  return query
  select count(*) > 0, min(dp.develops_at)
    from public.developing_posts dp
   where dp.group_id = p_group_id
     and dp.author_id not in (select private.blocked_ids());
end;
$$;

-- Whether the caller has photos developing (any group) and the next reveal: the camera's stack.
create function public.my_developing()
returns table (developing boolean, reveal_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select count(*) > 0, min(dp.develops_at)
    from public.developing_posts dp
   where dp.author_id = auth.uid()
$$;

-- Overnight alerts on or off for the caller (settings.notifications), on by default.
create function public.set_overnight_alerts(p_on boolean)
returns public.notification_settings
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_row public.notification_settings;
begin
  if p_on is null then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_on';
  end if;
  insert into public.notification_settings (user_id, overnight) values (v_uid, p_on)
  on conflict (user_id) do update set overnight = excluded.overnight
  returning * into v_row;
  return v_row;
end;
$$;

-- Worker (scheduler, every minute): developing photos whose time has come become posts, each with its
-- chat photo message. One push per group and reveal time (push.photos_developed). A photo whose author
-- has left the group by then is dropped.
create function public.due_developed_posts(p_now timestamptz default now())
returns setof public.posts
language plpgsql
security definer
set search_path = ''
as $$
declare
  d record;
  v_post public.posts;
begin
  for d in
    delete from public.developing_posts dp
     where dp.develops_at <= coalesce(p_now, now())
    returning dp.*
  loop
    perform private.broadcast_group(d.group_id, 'developing_changed', '{}'::jsonb);
    if not exists (select 1 from public.group_members m where m.group_id = d.group_id and m.user_id = d.author_id) then
      continue;
    end if;
    insert into public.posts (media_id, group_id, author_id, created_at, revealed_at)
    values (d.media_id, d.group_id, d.author_id, d.created_at, d.develops_at)
    on conflict (media_id, group_id) do nothing
    returning * into v_post;
    if not found then
      continue;
    end if;
    insert into public.messages (group_id, author_id, kind, post_id)
    values (d.group_id, d.author_id, 'photo', v_post.id);
    perform private.enqueue('push.photos_developed',
      jsonb_build_object('group_id', d.group_id, 'develops_at', d.develops_at, 'post_id', v_post.id),
      'push.photos_developed:' || d.group_id::text || ':' || d.develops_at::text);
    perform private.enqueue('widget.refresh',
      jsonb_build_object('group_id', d.group_id), 'widget.refresh:' || d.group_id::text);
    return next v_post;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Weekly question
-- ---------------------------------------------------------------------------
create table public.group_questions (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.groups (id) on delete cascade,
  week_start   date not null,
  question_key text not null check (question_key ~ '^question\.weekly\.[a-z0-9]+$'),
  created_at   timestamptz not null default now(),
  unique (group_id, week_start)
);
alter table public.group_questions enable row level security;
create policy group_questions_select on public.group_questions for select to authenticated
  using (group_id in (select private.my_group_ids()));
grant select on public.group_questions to authenticated;

create table public.group_question_hides (
  group_question_id uuid not null references public.group_questions (id) on delete cascade,
  user_id           uuid not null references public.profiles (id) on delete cascade,
  created_at        timestamptz not null default now(),
  primary key (group_question_id, user_id)
);
alter table public.group_question_hides enable row level security;
create index group_question_hides_user_idx on public.group_question_hides (user_id);
create policy group_question_hides_select on public.group_question_hides for select to authenticated
  using (user_id = auth.uid());
grant select on public.group_question_hides to authenticated;

alter table public.posts add column question_id uuid references public.group_questions (id) on delete set null;
create index posts_question_idx on public.posts (question_id) where question_id is not null;

-- The group's week (group time zone, week_start_isodow) containing p_at.
create function private.group_week_start(p_group_id uuid, p_at timestamptz default now())
returns date
language sql
stable
security definer
set search_path = ''
as $$
  select private.week_start_of((coalesce(p_at, now()) at time zone g.time_zone)::date,
                               coalesce(private.config_int('week_start_isodow'), 1))
    from public.groups g where g.id = p_group_id
$$;

create function public.set_group_weekly_question(p_group_id uuid, p_on boolean)
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
  if p_on is null then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_on';
  end if;
  update public.groups g set weekly_question = p_on where g.id = p_group_id returning * into v_group;
  return v_group;
end;
$$;

-- This week's question of the group (created on first read), or no row when the group has it off or
-- no questions are configured.
create function public.current_group_question(p_group_id uuid)
returns table (id uuid, question_key text, week_start date, hidden_by_me boolean)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_keys jsonb;
  v_week date;
  v_asked integer;
  v_row public.group_questions;
begin
  perform private.require_user();
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  select ac.value into v_keys from public.app_config ac where ac.key = 'weekly_question_keys';
  if not (select g.weekly_question from public.groups g where g.id = p_group_id)
     or v_keys is null or jsonb_typeof(v_keys) <> 'array' or jsonb_array_length(v_keys) = 0 then
    return;
  end if;
  v_week := private.group_week_start(p_group_id);
  select * into v_row from public.group_questions q where q.group_id = p_group_id and q.week_start = v_week;
  if not found then
    select count(*) into v_asked from public.group_questions q where q.group_id = p_group_id;
    insert into public.group_questions (group_id, week_start, question_key)
    values (p_group_id, v_week, v_keys ->> (v_asked % jsonb_array_length(v_keys)))
    on conflict (group_id, week_start) do nothing;
    select * into v_row from public.group_questions q where q.group_id = p_group_id and q.week_start = v_week;
  end if;
  id := v_row.id;
  question_key := v_row.question_key;
  week_start := v_row.week_start;
  hidden_by_me := exists (select 1 from public.group_question_hides h
                          where h.group_question_id = v_row.id and h.user_id = auth.uid());
  return next;
end;
$$;

-- "Remove": the card goes for the caller, for that week.
create function public.hide_question(p_question_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  if not exists (select 1 from public.group_questions q where q.id = p_question_id and private.is_member(q.group_id)) then
    raise exception 'question_not_found' using errcode = 'PT404';
  end if;
  insert into public.group_question_hides (group_question_id, user_id) values (p_question_id, v_uid)
  on conflict do nothing;
end;
$$;

-- Links one of the caller's own posts in the question's group to the question, during its week (or
-- unlinks it with p_question_id null). The answer is the post: it shows in the group as any post does.
create function public.answer_question(p_post_id uuid, p_question_id uuid)
returns public.posts
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_post public.posts;
  v_q public.group_questions;
begin
  select * into v_post from public.posts p where p.id = p_post_id and p.author_id = v_uid for update;
  if not found then
    raise exception 'post_not_found' using errcode = 'PT404';
  end if;
  if p_question_id is not null then
    select * into v_q from public.group_questions q where q.id = p_question_id;
    if not found or v_q.group_id <> v_post.group_id or not private.is_member(v_q.group_id) then
      raise exception 'invalid_question' using errcode = 'PT404';
    end if;
    if not (select g.weekly_question from public.groups g where g.id = v_q.group_id) then
      raise exception 'question_off' using errcode = 'PT409';
    end if;
    if v_q.week_start <> private.group_week_start(v_q.group_id) then
      raise exception 'question_closed' using errcode = 'PT409';
    end if;
  end if;
  update public.posts p set question_id = p_question_id where p.id = p_post_id returning * into v_post;
  return v_post;
end;
$$;

revoke all on function public.create_overnight_post(uuid, uuid[]), public.group_developing(uuid), public.my_developing(),
                       public.set_overnight_alerts(boolean), public.set_group_weekly_question(uuid, boolean),
                       public.current_group_question(uuid), public.hide_question(uuid), public.answer_question(uuid, uuid)
  from public, anon;
grant execute on function public.create_overnight_post(uuid, uuid[]), public.group_developing(uuid), public.my_developing(),
                          public.set_overnight_alerts(boolean), public.set_group_weekly_question(uuid, boolean),
                          public.current_group_question(uuid), public.hide_question(uuid), public.answer_question(uuid, uuid)
  to authenticated;
revoke all on function public.due_developed_posts(timestamptz) from public, anon, authenticated;
grant execute on function public.due_developed_posts(timestamptz) to service_role;
revoke all on function private.next_reveal_at(timestamptz, text), private.group_week_start(uuid, timestamptz) from public;

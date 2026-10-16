-- =============================================================================
-- 0019 plans: a group makes a plan (dinner Saturday, a trip) and members answer Going / Maybe /
-- Can't go (Partiful's and Apple Invites' mechanics, design/research/plans.md, plans-data.md).
-- Tenets: who is going is shown by name, never as a number; a member who has not answered is in no
-- list; "Can't go" is seen only by the person who answered it and the plan's maker (Partiful: "Guests
-- also cannot see who RSVP'd "Can't Go.""); one push the day before (Partiful's Group Reminder: "24
-- hours before"), only to Going and Maybe; nothing else nags.
--
-- plans         title, start (all-day or timed, optional end), the plan's day in the group time zone,
--               optional typed place (the app never collects location), note and cover (the maker's
--               own upload). Cancelled plans keep their row and can be restored (Apple: "Cancel Event
--               or Restore Event"); there is no delete (tenet 4). A deleted account leaves its plans
--               (created_by null), as groups.created_by.
-- plan_answers  one answer per member per plan; the maker starts as Going. No answer = no row.
-- plan_photos   the plan's album: the group's posts from the plan's first local day to its last
--               (group time zone, the app's day as in weeks and walls), minus blocked authors.
-- next_plans    upcoming plans of the caller's groups (the group screen's row and the countdown widget).
-- Answers lock once the plan is over (Partiful: "We don't enable people to change their RSVP after
-- the event"): after its end, or after its last day when it has no end.
-- Edits, cancel and restore: the maker or a group admin, until the plan is over.
-- =============================================================================

create table public.plans (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references public.groups (id) on delete cascade,
  created_by  uuid references public.profiles (id) on delete set null,
  title       text not null check (char_length(btrim(title)) between 1 and 80),
  starts_at   timestamptz not null,
  ends_at     timestamptz,
  all_day     boolean not null default false,
  local_date  date not null,
  place       text check (place is null or char_length(btrim(place)) between 1 and 200),
  note        text check (note is null or char_length(note) between 1 and 2048),
  cover_path  text check (cover_path is null or private.is_safe_path(cover_path)),
  canceled_at timestamptz,
  canceled_by uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint plans_ends_after_start check (ends_at is null or ends_at >= starts_at)
);
alter table public.plans enable row level security;
create index plans_group_date_idx on public.plans (group_id, local_date);
create index plans_upcoming_idx on public.plans (group_id, starts_at) where canceled_at is null;
create index plans_creator_idx on public.plans (created_by);
create index plans_cover_idx on public.plans (cover_path) where cover_path is not null;
create trigger plans_touch before update on public.plans
  for each row execute function private.touch_updated_at();

create table public.plan_answers (
  plan_id     uuid not null references public.plans (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  group_id    uuid not null references public.groups (id) on delete cascade,
  answer      text not null check (answer in ('going', 'maybe', 'cant_go')),
  answered_at timestamptz not null default now(),
  primary key (plan_id, user_id)
);
alter table public.plan_answers enable row level security;
create index plan_answers_user_idx on public.plan_answers (user_id);
create index plan_answers_group_idx on public.plan_answers (group_id);

create policy plans_select on public.plans for select to authenticated
  using (group_id in (select private.my_group_ids())
         and (created_by is null or created_by not in (select private.blocked_ids())));
grant select on public.plans to authenticated;

-- Going and Maybe: every member. Can't go: the person who answered it and the plan's maker.
create policy plan_answers_select on public.plan_answers for select to authenticated
  using (group_id in (select private.my_group_ids())
         and user_id not in (select private.blocked_ids())
         and (answer in ('going', 'maybe')
              or user_id = auth.uid()
              or exists (select 1 from public.plans pl where pl.id = plan_id and pl.created_by = auth.uid())));
grant select on public.plan_answers to authenticated;

-- ---------------------------------------------------------------------------
-- The plan is over: after its end, or after its last local day when it has no end.
create function private.plan_over(p_plan public.plans, p_now timestamptz default now())
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(p_now, now()) >= coalesce(
    p_plan.ends_at,
    ((p_plan.local_date + 1)::timestamp at time zone
       (select g.time_zone from public.groups g where g.id = p_plan.group_id)))
$$;

-- The day-before push: one queued job per plan, moved when the start moves, dropped on cancel.
create function private.schedule_plan_reminder(p_plan public.plans)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.jobs j
     set status = 'cancelled', finished_at = now(), last_error = 'plan changed'
   where j.status = 'queued' and j.kind = 'push.plan_tomorrow'
     and j.payload ->> 'plan_id' = p_plan.id::text;
  -- skipped when the plan starts less than a day ahead (plans-data.md, plan_reminder)
  if p_plan.canceled_at is null and p_plan.starts_at - interval '1 day' > now() then
    perform private.enqueue('push.plan_tomorrow',
      jsonb_build_object('plan_id', p_plan.id, 'group_id', p_plan.group_id),
      null, p_plan.starts_at - interval '1 day');
  end if;
end;
$$;

create function private.can_edit_plan(p_plan public.plans)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_member(p_plan.group_id)
     and (p_plan.created_by = auth.uid() or private.is_admin(p_plan.group_id))
$$;

-- Validates the fields; returns the start (00:00 of the plan's day for an all-day plan) and the day.
create function private.plan_when(
  p_group_id uuid, p_starts_at timestamptz, p_all_day boolean, p_ends_at timestamptz,
  out starts_at timestamptz, out local_date date
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tz text;
begin
  select g.time_zone into v_tz from public.groups g where g.id = p_group_id;
  if p_starts_at is null then
    raise exception 'invalid_date' using errcode = 'PT400';
  end if;
  local_date := (p_starts_at at time zone v_tz)::date;
  starts_at := case when coalesce(p_all_day, false) then local_date::timestamp at time zone v_tz else p_starts_at end;
  if local_date < (now() at time zone v_tz)::date or (p_ends_at is not null and p_ends_at < starts_at) then
    raise exception 'invalid_date' using errcode = 'PT400';
  end if;
end;
$$;

create function private.check_plan_text(p_title text, p_place text, p_note text, p_cover_path text, p_user uuid)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if p_title is null or char_length(btrim(p_title)) not between 1 and 80 then
    raise exception 'invalid_name' using errcode = 'PT400';
  end if;
  if p_place is not null and char_length(btrim(p_place)) > 200 then
    raise exception 'invalid_place' using errcode = 'PT400';
  end if;
  if p_note is not null and char_length(p_note) > 2048 then
    raise exception 'invalid_note' using errcode = 'PT400';
  end if;
  if p_cover_path is not null and not private.is_own_upload(p_cover_path, p_user) then
    raise exception 'invalid_cover' using errcode = 'PT400';
  end if;
end;
$$;

create function public.create_plan(
  p_group_id uuid,
  p_title text,
  p_starts_at timestamptz,
  p_all_day boolean default false,
  p_ends_at timestamptz default null,
  p_place text default null,
  p_note text default null,
  p_cover_path text default null
)
returns public.plans
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_when record;
  v_plan public.plans;
begin
  if not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  perform private.check_plan_text(p_title, p_place, p_note, p_cover_path, v_uid);
  select * into v_when from private.plan_when(p_group_id, p_starts_at, p_all_day, p_ends_at);

  insert into public.plans (group_id, created_by, title, starts_at, ends_at, all_day, local_date, place, note, cover_path)
  values (p_group_id, v_uid, btrim(p_title), v_when.starts_at, p_ends_at, coalesce(p_all_day, false), v_when.local_date,
          nullif(btrim(p_place), ''), nullif(p_note, ''), p_cover_path)
  returning * into v_plan;
  insert into public.plan_answers (plan_id, user_id, group_id, answer) values (v_plan.id, v_uid, p_group_id, 'going');

  perform private.enqueue('push.plan_created',
    jsonb_build_object('plan_id', v_plan.id, 'group_id', p_group_id, 'author_id', v_uid));
  perform private.schedule_plan_reminder(v_plan);
  return v_plan;
end;
$$;

-- Same fields as create_plan. A change of day, time or place tells Going and Maybe once (push.plan_changed).
create function public.update_plan(
  p_plan_id uuid,
  p_title text,
  p_starts_at timestamptz,
  p_all_day boolean default false,
  p_ends_at timestamptz default null,
  p_place text default null,
  p_note text default null,
  p_cover_path text default null
)
returns public.plans
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_old public.plans;
  v_plan public.plans;
  v_when record;
begin
  select * into v_old from public.plans pl where pl.id = p_plan_id for update;
  if not found or not private.is_member(v_old.group_id) then
    raise exception 'plan_not_found' using errcode = 'PT404';
  end if;
  if not private.can_edit_plan(v_old) then
    raise exception 'not_allowed' using errcode = 'PT403';
  end if;
  if v_old.canceled_at is not null then
    raise exception 'plan_canceled' using errcode = 'PT409';
  end if;
  if private.plan_over(v_old) then
    raise exception 'plan_past' using errcode = 'PT409';
  end if;
  -- A cover kept as is may be the maker's upload while an admin edits.
  perform private.check_plan_text(p_title, p_place, p_note,
    case when p_cover_path is distinct from v_old.cover_path then p_cover_path end, v_uid);
  select * into v_when from private.plan_when(v_old.group_id, p_starts_at, p_all_day, p_ends_at);

  update public.plans pl
     set title = btrim(p_title), starts_at = v_when.starts_at, ends_at = p_ends_at, all_day = coalesce(p_all_day, false),
         local_date = v_when.local_date, place = nullif(btrim(p_place), ''), note = nullif(p_note, ''),
         cover_path = p_cover_path
   where pl.id = p_plan_id
  returning * into v_plan;

  if v_old.cover_path is not null and v_old.cover_path is distinct from v_plan.cover_path then
    perform private.enqueue_storage_delete(array[v_old.cover_path]);
  end if;
  if v_plan.starts_at is distinct from v_old.starts_at or v_plan.all_day is distinct from v_old.all_day
     or v_plan.ends_at is distinct from v_old.ends_at or v_plan.place is distinct from v_old.place then
    perform private.enqueue('push.plan_changed',
      jsonb_build_object('plan_id', v_plan.id, 'group_id', v_plan.group_id, 'author_id', v_uid,
                         'time_changed', v_plan.starts_at is distinct from v_old.starts_at
                                         or v_plan.all_day is distinct from v_old.all_day
                                         or v_plan.ends_at is distinct from v_old.ends_at,
                         'place_changed', v_plan.place is distinct from v_old.place,
                         'updated_at', v_plan.updated_at),
      'push.plan_changed:' || v_plan.id::text || ':' || v_plan.updated_at::text);
  end if;
  perform private.schedule_plan_reminder(v_plan);
  return v_plan;
end;
$$;

-- Cancel tells Going and Maybe once (push.plan_canceled); restore tells nobody (Apple documents no notice).
create function public.cancel_plan(p_plan_id uuid)
returns public.plans
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_plan public.plans;
begin
  select * into v_plan from public.plans pl where pl.id = p_plan_id for update;
  if not found or not private.is_member(v_plan.group_id) then
    raise exception 'plan_not_found' using errcode = 'PT404';
  end if;
  if not private.can_edit_plan(v_plan) then
    raise exception 'not_allowed' using errcode = 'PT403';
  end if;
  if private.plan_over(v_plan) then
    raise exception 'plan_past' using errcode = 'PT409';
  end if;
  if v_plan.canceled_at is null then
    update public.plans pl set canceled_at = now(), canceled_by = v_uid where pl.id = p_plan_id returning * into v_plan;
    perform private.schedule_plan_reminder(v_plan);
    update public.jobs j
       set status = 'cancelled', finished_at = now(), last_error = 'plan canceled'
     where j.status = 'queued' and j.kind in ('push.plan_created', 'push.plan_changed')
       and j.payload ->> 'plan_id' = v_plan.id::text;
    perform private.enqueue('push.plan_canceled',
      jsonb_build_object('plan_id', v_plan.id, 'group_id', v_plan.group_id, 'author_id', v_uid),
      'push.plan_canceled:' || v_plan.id::text || ':' || v_plan.canceled_at::text);
  end if;
  return v_plan;
end;
$$;

create function public.restore_plan(p_plan_id uuid)
returns public.plans
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_plan public.plans;
begin
  perform private.require_user();
  select * into v_plan from public.plans pl where pl.id = p_plan_id for update;
  if not found or not private.is_member(v_plan.group_id) then
    raise exception 'plan_not_found' using errcode = 'PT404';
  end if;
  if not private.can_edit_plan(v_plan) then
    raise exception 'not_allowed' using errcode = 'PT403';
  end if;
  if private.plan_over(v_plan) then
    raise exception 'plan_past' using errcode = 'PT409';
  end if;
  if v_plan.canceled_at is not null then
    update public.plans pl set canceled_at = null, canceled_by = null where pl.id = p_plan_id returning * into v_plan;
    update public.jobs j
       set status = 'cancelled', finished_at = now(), last_error = 'plan restored'
     where j.status = 'queued' and j.kind = 'push.plan_canceled'
       and j.payload ->> 'plan_id' = v_plan.id::text;
    perform private.schedule_plan_reminder(v_plan);
  end if;
  return v_plan;
end;
$$;

create function private.answerable_plan(p_plan_id uuid, p_uid uuid)
returns public.plans
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_plan public.plans;
begin
  select * into v_plan from public.plans pl where pl.id = p_plan_id;
  if not found or not private.is_member(v_plan.group_id)
     or (v_plan.created_by is not null and private.is_blocked_between(p_uid, v_plan.created_by)) then
    raise exception 'plan_not_found' using errcode = 'PT404';
  end if;
  if v_plan.canceled_at is not null then
    raise exception 'plan_canceled' using errcode = 'PT409';
  end if;
  if private.plan_over(v_plan) then
    raise exception 'plan_past' using errcode = 'PT409';
  end if;
  return v_plan;
end;
$$;

-- One tap commits; a new answer replaces the previous one (Partiful: "it will replace your previous RSVP").
create function public.answer_plan(p_plan_id uuid, p_answer text)
returns public.plan_answers
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_plan public.plans := private.answerable_plan(p_plan_id, v_uid);
  v_row public.plan_answers;
begin
  if p_answer is null or p_answer not in ('going', 'maybe', 'cant_go') then
    raise exception 'invalid_answer' using errcode = 'PT400';
  end if;
  insert into public.plan_answers (plan_id, user_id, group_id, answer)
  values (p_plan_id, v_uid, v_plan.group_id, p_answer)
  on conflict (plan_id, user_id) do update set answer = excluded.answer, answered_at = now()
  returning * into v_row;
  return v_row;
end;
$$;

-- Back to no answer.
create function public.clear_answer(p_plan_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_plan public.plans := private.answerable_plan(p_plan_id, v_uid);
begin
  delete from public.plan_answers a where a.plan_id = v_plan.id and a.user_id = v_uid;
end;
$$;

-- The plan's album: the group's posts of the plan's local days (group time zone), minus blocked
-- authors (as posts_select). A cancelled plan has none.
create function public.plan_photos(p_plan_id uuid)
returns setof public.posts
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_plan public.plans;
  v_tz text;
  v_last date;
begin
  perform private.require_user();
  select * into v_plan from public.plans pl where pl.id = p_plan_id;
  if not found or not private.is_member(v_plan.group_id)
     or v_plan.created_by in (select private.blocked_ids()) then
    raise exception 'plan_not_found' using errcode = 'PT404';
  end if;
  if v_plan.canceled_at is not null then
    return;
  end if;
  select g.time_zone into v_tz from public.groups g where g.id = v_plan.group_id;
  v_last := coalesce((v_plan.ends_at at time zone v_tz)::date, v_plan.local_date);
  return query
  select p.*
    from public.posts p
   where p.group_id = v_plan.group_id
     and p.author_id not in (select private.blocked_ids())
     and p.created_at >= (v_plan.local_date::timestamp at time zone v_tz)
     and p.created_at < ((v_last + 1)::timestamp at time zone v_tz)
   order by p.created_at, p.id;
end;
$$;

-- Upcoming plans (not cancelled, not over) of the caller's groups, or of one group, soonest first:
-- the group screen's row and the countdown widget. The caller's own answer comes with each.
create function public.next_plans(p_group_id uuid default null)
returns table (
  id uuid, group_id uuid, created_by uuid, title text, starts_at timestamptz, ends_at timestamptz, all_day boolean,
  local_date date, place text, cover_path text, my_answer text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_user();
  if p_group_id is not null and not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  return query
  select pl.id, pl.group_id, pl.created_by, pl.title, pl.starts_at, pl.ends_at, pl.all_day, pl.local_date, pl.place,
         pl.cover_path, a.answer
    from public.plans pl
    left join public.plan_answers a on a.plan_id = pl.id and a.user_id = auth.uid()
   where pl.group_id in (select private.my_group_ids())
     and (p_group_id is null or pl.group_id = p_group_id)
     and pl.canceled_at is null
     and (pl.created_by is null or pl.created_by not in (select private.blocked_ids()))
     and not private.plan_over(pl)
   order by pl.starts_at, pl.id;
end;
$$;

revoke all on function public.create_plan(uuid, text, timestamptz, boolean, timestamptz, text, text, text),
                       public.update_plan(uuid, text, timestamptz, boolean, timestamptz, text, text, text),
                       public.cancel_plan(uuid), public.restore_plan(uuid), public.answer_plan(uuid, text),
                       public.clear_answer(uuid), public.plan_photos(uuid), public.next_plans(uuid)
  from public, anon;
grant execute on function public.create_plan(uuid, text, timestamptz, boolean, timestamptz, text, text, text),
                          public.update_plan(uuid, text, timestamptz, boolean, timestamptz, text, text, text),
                          public.cancel_plan(uuid), public.restore_plan(uuid), public.answer_plan(uuid, text),
                          public.clear_answer(uuid), public.plan_photos(uuid), public.next_plans(uuid)
  to authenticated;
revoke all on function private.schedule_plan_reminder(public.plans), private.can_edit_plan(public.plans),
                       private.plan_when(uuid, timestamptz, boolean, timestamptz),
                       private.check_plan_text(text, text, text, text, uuid),
                       private.answerable_plan(uuid, uuid), private.plan_over(public.plans, timestamptz)
  from public;

-- A deleted plan (only with its group): its cover file goes too, its pushes are dropped.
create function private.on_plan_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.cover_path is not null then
    perform private.enqueue_storage_delete(array[old.cover_path]);
  end if;
  update public.jobs j
     set status = 'cancelled', finished_at = now(), last_error = 'target deleted'
   where j.status = 'queued' and j.kind in ('push.plan_tomorrow', 'push.plan_created', 'push.plan_changed', 'push.plan_canceled')
     and j.payload ->> 'plan_id' = old.id::text;
  return null;
end;
$$;
create trigger plans_after_delete after delete on public.plans
  for each row execute function private.on_plan_deleted();

-- A deleted account's files go with it (u/<uid>/…): a plan cover among them is cleared, the plan stays.
create function private.on_profile_deleted_plans()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.plans pl set cover_path = null where pl.cover_path like 'u/' || old.id::text || '/%';
  return old;
end;
$$;
create trigger profiles_before_delete_plans before delete on public.profiles
  for each row execute function private.on_profile_deleted_plans();

alter publication supabase_realtime add table public.plans, public.plan_answers;

-- =============================================================================
-- 0002 tables: the data model of docs/ARCHITECTURE.md. RLS is enabled here on
-- every table; policies and grants are in 0003.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- profiles (readable by self + people sharing a group) and profile_private
-- (birthday + age gate; readable only by self).
-- ---------------------------------------------------------------------------
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 80),
  avatar_path  text check (avatar_path is null
                           or (private.is_safe_path(avatar_path) and avatar_path like 'avatars/' || id::text || '/%')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
alter table public.profiles enable row level security;
create trigger profiles_touch before update on public.profiles
  for each row execute function private.touch_updated_at();

create table public.profile_private (
  user_id          uuid primary key references public.profiles (id) on delete cascade,
  birthday         date check (birthday is null or birthday >= date '1900-01-01'),
  birthday_opt_in  boolean not null default false,
  age_confirmed_at timestamptz,
  updated_at       timestamptz not null default now(),
  check (not birthday_opt_in or birthday is not null)
);
alter table public.profile_private enable row level security;
create trigger profile_private_touch before update on public.profile_private
  for each row execute function private.touch_updated_at();

-- New auth user -> profile rows.
create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, left(coalesce(new.raw_user_meta_data ->> 'display_name', ''), 80))
  on conflict (id) do nothing;
  insert into public.profile_private (user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ---------------------------------------------------------------------------
-- groups, group_members, group_invites
-- ---------------------------------------------------------------------------
create table public.groups (
  id                uuid primary key default gen_random_uuid(),
  name              text not null check (char_length(btrim(name)) between 1 and 80),
  kind              public.group_kind not null,
  cover_path        text check (cover_path is null or private.is_safe_path(cover_path)),
  time_zone         text not null,
  waking_start      time,
  waking_end        time,
  invitation_paused boolean not null default false,
  created_by        uuid references public.profiles (id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint groups_waking_both check ((waking_start is null) = (waking_end is null)),
  constraint groups_waking_nonempty check (waking_start is null or waking_start <> waking_end)
);
alter table public.groups enable row level security;
create trigger groups_touch before update on public.groups
  for each row execute function private.touch_updated_at();

create function private.groups_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not private.is_valid_time_zone(new.time_zone) then
    raise exception 'invalid_time_zone' using errcode = 'PT400', detail = coalesce(new.time_zone, '');
  end if;
  return new;
end;
$$;
create trigger groups_validate before insert or update of time_zone on public.groups
  for each row execute function private.groups_validate();

create table public.group_members (
  group_id  uuid not null references public.groups (id) on delete cascade,
  user_id   uuid not null references public.profiles (id) on delete cascade,
  role      public.member_role not null default 'member',
  muted     boolean not null default false,
  joined_at timestamptz not null default clock_timestamp(),
  primary key (group_id, user_id)
);
alter table public.group_members enable row level security;
create index group_members_user_idx on public.group_members (user_id);

-- Race-safe member cap: serialize joins per group on the group row, then count.
create function private.group_members_enforce_cap()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_max integer := coalesce(private.config_int('max_group_members'), 30);
  v_count integer;
begin
  perform 1 from public.groups g where g.id = new.group_id for no key update;
  -- already a member: let ON CONFLICT handle it (idempotent join of a full group)
  if exists (select 1 from public.group_members m where m.group_id = new.group_id and m.user_id = new.user_id) then
    return new;
  end if;
  select count(*) into v_count from public.group_members m where m.group_id = new.group_id;
  if v_count >= v_max then
    raise exception 'group_full' using errcode = 'PT409', detail = format('max %s members', v_max);
  end if;
  return new;
end;
$$;
create trigger group_members_cap before insert on public.group_members
  for each row execute function private.group_members_enforce_cap();

create table public.group_invites (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references public.groups (id) on delete cascade,
  token      text not null unique default private.new_invite_token() check (char_length(token) >= 22),
  created_by uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz
);
alter table public.group_invites enable row level security;
create index group_invites_group_idx on public.group_invites (group_id);

-- ---------------------------------------------------------------------------
-- blocks
-- ---------------------------------------------------------------------------
create table public.blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
alter table public.blocks enable row level security;
create index blocks_blocked_idx on public.blocks (blocked_id);

-- ---------------------------------------------------------------------------
-- media: one captured photo / live photo / video, owned by its author.
-- Every path lives under u/<owner_id>/<media id>/ .
-- ---------------------------------------------------------------------------
create function private.media_path_ok(p_path text, p_owner uuid, p_media uuid)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_path is null
      or (private.is_safe_path(p_path) and p_path like 'u/' || p_owner::text || '/' || p_media::text || '/%')
$$;

create table public.media (
  id                  uuid primary key default gen_random_uuid(),
  owner_id            uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  kind                public.media_kind not null,
  original_path       text not null,
  front_original_path text,
  motion_path         text,
  display_path        text,
  thumb_path          text,
  widget_path         text,
  front_display_path  text,
  front_thumb_path    text,
  width               integer check (width > 0),
  height              integer check (height > 0),
  front_width         integer check (front_width > 0),
  front_height        integer check (front_height > 0),
  duration_ms         integer check (duration_ms > 0),
  renditions_ready_at timestamptz,
  created_at          timestamptz not null default now(),
  constraint media_paths_under_owner check (
        private.media_path_ok(original_path, owner_id, id)
    and private.media_path_ok(front_original_path, owner_id, id)
    and private.media_path_ok(motion_path, owner_id, id)
    and private.media_path_ok(display_path, owner_id, id)
    and private.media_path_ok(thumb_path, owner_id, id)
    and private.media_path_ok(widget_path, owner_id, id)
    and private.media_path_ok(front_display_path, owner_id, id)
    and private.media_path_ok(front_thumb_path, owner_id, id)),
  constraint media_video_duration check (kind <> 'video' or duration_ms is not null),
  constraint media_live_motion check (kind <> 'live_photo' or motion_path is not null)
);
alter table public.media enable row level security;
create index media_owner_idx on public.media (owner_id);

-- ---------------------------------------------------------------------------
-- daily_invitations (one per group per local date)
-- ---------------------------------------------------------------------------
create table public.daily_invitations (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references public.groups (id) on delete cascade,
  local_date date not null,
  fires_at   timestamptz not null,
  closes_at  timestamptz not null,
  status     public.invitation_status not null default 'scheduled',
  created_at timestamptz not null default now(),
  unique (group_id, local_date),
  check (closes_at > fires_at)
);
alter table public.daily_invitations enable row level security;
create index daily_invitations_fires_idx on public.daily_invitations (fires_at);

-- ---------------------------------------------------------------------------
-- posts: one row per group a photo is sent to.
-- ---------------------------------------------------------------------------
create table public.posts (
  id                uuid primary key default gen_random_uuid(),
  media_id          uuid not null references public.media (id) on delete cascade,
  group_id          uuid not null references public.groups (id) on delete cascade,
  author_id         uuid not null references public.profiles (id) on delete cascade,
  caption           text check (caption is null or char_length(caption) <= 1000),
  voice_path        text check (voice_path is null or private.is_safe_path(voice_path)),
  voice_duration_ms integer check (voice_duration_ms is null or voice_duration_ms > 0),
  invitation_id     uuid references public.daily_invitations (id) on delete set null,
  in_window         boolean not null default false,
  reply_to_post_id  uuid references public.posts (id) on delete set null,
  created_at        timestamptz not null default now(),
  unique (media_id, group_id),
  check ((voice_path is null) = (voice_duration_ms is null))
);
alter table public.posts enable row level security;
create index posts_group_created_idx on public.posts (group_id, created_at desc);
create index posts_author_idx on public.posts (author_id, created_at desc);
create index posts_media_idx on public.posts (media_id);
create index posts_invitation_idx on public.posts (invitation_id) where invitation_id is not null;
create index posts_voice_idx on public.posts (voice_path) where voice_path is not null;
create index posts_reply_idx on public.posts (reply_to_post_id) where reply_to_post_id is not null;

-- ---------------------------------------------------------------------------
-- messages: group chat (text | photo (a post) | voice)
-- ---------------------------------------------------------------------------
create table public.messages (
  id                  uuid primary key default gen_random_uuid(),
  group_id            uuid not null references public.groups (id) on delete cascade,
  author_id           uuid not null references public.profiles (id) on delete cascade,
  kind                public.message_kind not null,
  body                text check (body is null or char_length(body) <= 4000),
  post_id             uuid references public.posts (id) on delete cascade,
  voice_path          text check (voice_path is null or private.is_safe_path(voice_path)),
  voice_duration_ms   integer check (voice_duration_ms is null or voice_duration_ms > 0),
  reply_to_post_id    uuid references public.posts (id) on delete set null,
  reply_to_message_id uuid references public.messages (id) on delete set null,
  created_at          timestamptz not null default now(),
  constraint messages_kind_shape check (
    case kind
      when 'text'  then body is not null and btrim(body) <> '' and post_id is null and voice_path is null
      when 'photo' then post_id is not null and voice_path is null
      when 'voice' then voice_path is not null and voice_duration_ms is not null and post_id is null
    end)
);
alter table public.messages enable row level security;
create index messages_group_created_idx on public.messages (group_id, created_at desc);
create index messages_author_idx on public.messages (author_id);
create index messages_post_idx on public.messages (post_id) where post_id is not null;
create index messages_reply_post_idx on public.messages (reply_to_post_id) where reply_to_post_id is not null;
create index messages_reply_msg_idx on public.messages (reply_to_message_id) where reply_to_message_id is not null;
create index messages_voice_idx on public.messages (voice_path) where voice_path is not null;

-- ---------------------------------------------------------------------------
-- reactions (rows only, never counts) and post_tags (self-tags)
-- group_id is denormalized from the post (set by trigger) for RLS + realtime filters.
-- ---------------------------------------------------------------------------
create table public.reactions (
  post_id    uuid not null references public.posts (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  emoji      text not null check (private.is_emoji(emoji)),
  group_id   uuid not null references public.groups (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id, emoji)
);
alter table public.reactions enable row level security;
create index reactions_user_idx on public.reactions (user_id);
create index reactions_group_idx on public.reactions (group_id);

create table public.post_tags (
  post_id    uuid not null references public.posts (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  group_id   uuid not null references public.groups (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
alter table public.post_tags enable row level security;
create index post_tags_user_idx on public.post_tags (user_id);
create index post_tags_group_idx on public.post_tags (group_id);

create function private.set_group_from_post()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  select p.group_id into new.group_id from public.posts p where p.id = new.post_id;
  if new.group_id is null then
    raise exception 'post_not_found' using errcode = 'PT404';
  end if;
  return new;
end;
$$;
create trigger reactions_set_group before insert on public.reactions
  for each row execute function private.set_group_from_post();
create trigger post_tags_set_group before insert on public.post_tags
  for each row execute function private.set_group_from_post();

-- ---------------------------------------------------------------------------
-- collages (same-moment collage per daily invitation), weekly recaps, albums
-- ---------------------------------------------------------------------------
create table public.collages (
  id            uuid primary key default gen_random_uuid(),
  group_id      uuid not null references public.groups (id) on delete cascade,
  invitation_id uuid references public.daily_invitations (id) on delete cascade,
  option        text not null,
  post_ids      uuid[] not null default '{}',
  image_path    text check (image_path is null or (private.is_safe_path(image_path) and image_path like 'g/' || group_id::text || '/%')),
  widget_path   text check (widget_path is null or (private.is_safe_path(widget_path) and widget_path like 'g/' || group_id::text || '/%')),
  share_path    text check (share_path is null or (private.is_safe_path(share_path) and share_path like 'g/' || group_id::text || '/%')),
  status        public.render_status not null default 'pending',
  composed_at   timestamptz,
  created_at    timestamptz not null default now()
);
alter table public.collages enable row level security;
create unique index collages_invitation_uidx on public.collages (invitation_id) where invitation_id is not null;
create index collages_group_idx on public.collages (group_id, created_at desc);
create index collages_post_ids_gin on public.collages using gin (post_ids);

create table public.weekly_recaps (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.groups (id) on delete cascade,
  week_start   date not null,
  items        uuid[] not null default '{}',
  text         text check (text is null or char_length(text) <= 2000),
  status       public.render_status not null default 'pending',
  generated_at timestamptz,
  edited_by    uuid references public.profiles (id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (group_id, week_start)
);
alter table public.weekly_recaps enable row level security;
create index weekly_recaps_items_gin on public.weekly_recaps using gin (items);

create table public.albums (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references public.groups (id) on delete cascade,
  name       text not null check (char_length(btrim(name)) between 1 and 80),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.albums enable row level security;
create index albums_group_idx on public.albums (group_id);
create trigger albums_touch before update on public.albums
  for each row execute function private.touch_updated_at();

create table public.album_items (
  album_id uuid not null references public.albums (id) on delete cascade,
  post_id  uuid not null references public.posts (id) on delete cascade,
  position integer not null check (position >= 0),
  primary key (album_id, post_id)
);
alter table public.album_items enable row level security;
create index album_items_post_idx on public.album_items (post_id);

-- ---------------------------------------------------------------------------
-- Birthday tributes
-- ---------------------------------------------------------------------------
create table public.tribute_requests (
  id            uuid primary key default gen_random_uuid(),
  group_id      uuid not null references public.groups (id) on delete cascade,
  honoree_id    uuid not null references public.profiles (id) on delete cascade,
  birthday_date date not null,
  due_at        timestamptz not null,
  closed_at     timestamptz,
  created_at    timestamptz not null default now(),
  unique (group_id, honoree_id, birthday_date)
);
alter table public.tribute_requests enable row level security;
create index tribute_requests_due_idx on public.tribute_requests (due_at) where closed_at is null;

create table public.tribute_contributions (
  id             uuid primary key default gen_random_uuid(),
  request_id     uuid not null references public.tribute_requests (id) on delete cascade,
  contributor_id uuid not null references public.profiles (id) on delete cascade,
  post_id        uuid not null references public.posts (id) on delete cascade,
  line           text not null check (char_length(btrim(line)) between 1 and 280),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (request_id, contributor_id)
);
alter table public.tribute_contributions enable row level security;
create index tribute_contributions_post_idx on public.tribute_contributions (post_id);
create index tribute_contributions_contributor_idx on public.tribute_contributions (contributor_id);
create trigger tribute_contributions_touch before update on public.tribute_contributions
  for each row execute function private.touch_updated_at();

create table public.tributes (
  id           uuid primary key default gen_random_uuid(),
  request_id   uuid not null unique references public.tribute_requests (id) on delete cascade,
  group_id     uuid not null references public.groups (id) on delete cascade,
  honoree_id   uuid not null references public.profiles (id) on delete cascade,
  video_path   text check (video_path is null or (private.is_safe_path(video_path) and video_path like 'g/' || group_id::text || '/tributes/' || id::text || '/%')),
  poster_path  text check (poster_path is null or (private.is_safe_path(poster_path) and poster_path like 'g/' || group_id::text || '/tributes/' || id::text || '/%')),
  status       public.render_status not null default 'pending',
  rendered_at  timestamptz,
  delivered_at timestamptz,
  created_at   timestamptz not null default now()
);
alter table public.tributes enable row level security;
create index tributes_group_idx on public.tributes (group_id);

-- ---------------------------------------------------------------------------
-- Year stories (December)
-- ---------------------------------------------------------------------------
create table public.year_stories (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.groups (id) on delete cascade,
  year         integer not null check (year between 2000 and 2200),
  status       public.render_status not null default 'pending',
  data         jsonb,
  post_ids     uuid[] not null default '{}',
  asset_paths  text[] not null default '{}',
  generated_at timestamptz,
  created_at   timestamptz not null default now(),
  unique (group_id, year)
);
alter table public.year_stories enable row level security;
create index year_stories_post_ids_gin on public.year_stories using gin (post_ids);

-- ---------------------------------------------------------------------------
-- Account-scoped tables
-- ---------------------------------------------------------------------------
create table public.devices (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references public.profiles (id) on delete cascade,
  platform            public.device_platform not null,
  push_token          text not null unique check (char_length(push_token) between 1 and 4096),
  push_to_start_token text check (push_to_start_token is null or char_length(push_to_start_token) <= 4096),
  widget_push_token   text check (widget_push_token is null or char_length(widget_push_token) <= 4096),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
alter table public.devices enable row level security;
create index devices_user_idx on public.devices (user_id);
create trigger devices_touch before update on public.devices
  for each row execute function private.touch_updated_at();

create table public.notification_settings (
  user_id     uuid primary key references public.profiles (id) on delete cascade,
  quiet_start time,
  quiet_end   time,
  time_zone   text,
  updated_at  timestamptz not null default now(),
  check ((quiet_start is null) = (quiet_end is null)),
  check (quiet_start is null or time_zone is not null)
);
alter table public.notification_settings enable row level security;
create trigger notification_settings_touch before update on public.notification_settings
  for each row execute function private.touch_updated_at();

create table public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  target_kind public.report_target_kind not null,
  target_id   uuid not null,
  reason      text not null check (char_length(btrim(reason)) between 1 and 1000),
  status      text not null default 'open' check (status in ('open', 'reviewed', 'actioned', 'dismissed')),
  created_at  timestamptz not null default now()
);
alter table public.reports enable row level security;
create index reports_reporter_idx on public.reports (reporter_id);

create table public.entitlements (
  user_id     uuid not null references public.profiles (id) on delete cascade,
  entitlement text not null default 'premium' check (entitlement in ('premium')),
  expires_at  timestamptz,
  source      text not null check (char_length(source) between 1 and 64),
  updated_at  timestamptz not null default now(),
  primary key (user_id, entitlement)
);
alter table public.entitlements enable row level security;
create trigger entitlements_touch before update on public.entitlements
  for each row execute function private.touch_updated_at();

create table public.ai_cost_log (
  id            bigint generated always as identity primary key,
  job_id        bigint references public.jobs (id) on delete set null,
  group_id      uuid references public.groups (id) on delete set null,
  purpose       text not null,
  model         text not null,
  input_tokens  integer not null default 0 check (input_tokens >= 0),
  output_tokens integer not null default 0 check (output_tokens >= 0),
  cost_usd      numeric(12, 6) not null default 0 check (cost_usd >= 0),
  created_at    timestamptz not null default now()
);
alter table public.ai_cost_log enable row level security;
create index ai_cost_log_created_idx on public.ai_cost_log (created_at);

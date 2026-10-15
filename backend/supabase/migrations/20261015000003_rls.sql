-- =============================================================================
-- 0003 row level security: visibility helpers, policies, explicit grants.
--
-- Visibility rules
--   * Group content: readable only by current members of that group.
--   * Blocking (either direction) hides each person's posts, messages, reactions,
--     tags and walls from the other.
--   * Profiles: self + people who share a group with you.
--   * tribute_requests / tributes: hidden from the honoree until the tribute is
--     delivered; tribute_contributions: contributor only.
--   * devices, notification_settings, entitlements, blocks, profile_private: own rows.
--     reports: insert only.
--   * jobs, ai_cost_log, app_config: no client access (service role only).
-- Helper functions are SECURITY DEFINER (owner bypasses RLS) to avoid recursive
-- policy evaluation; they only ever answer questions about auth.uid().
-- =============================================================================

create function private.my_group_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.group_id from public.group_members m where m.user_id = auth.uid()
$$;

create function private.is_member(p_group uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.group_members m where m.group_id = p_group and m.user_id = auth.uid())
$$;

create function private.is_member_of(p_group uuid, p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.group_members m where m.group_id = p_group and m.user_id = p_user)
$$;

create function private.is_admin(p_group uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.group_members m
                 where m.group_id = p_group and m.user_id = auth.uid() and m.role = 'admin')
$$;

-- Users with a block relation with the caller, in either direction.
create function private.blocked_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select b.blocked_id from public.blocks b where b.blocker_id = auth.uid()
  union
  select b.blocker_id from public.blocks b where b.blocked_id = auth.uid()
$$;

create function private.is_blocked_between(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.blocks b
                 where (b.blocker_id = p_a and b.blocked_id = p_b)
                    or (b.blocker_id = p_b and b.blocked_id = p_a))
$$;

create function private.is_blocked_with(p_other uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_blocked_between(auth.uid(), p_other)
$$;

-- Everyone who shares at least one group with the caller (including the caller).
create function private.co_member_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select distinct other.user_id
  from public.group_members mine
  join public.group_members other on other.group_id = mine.group_id
  where mine.user_id = auth.uid()
$$;

create function private.shares_group(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.group_members x
                 join public.group_members y on y.group_id = x.group_id
                 where x.user_id = p_a and y.user_id = p_b)
$$;

-- Can user p_user see post p_post? (member of its group, no block with its author)
create function private.user_can_see_post(p_user uuid, p_post uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.posts p
    join public.group_members m on m.group_id = p.group_id and m.user_id = p_user
    where p.id = p_post
      and not private.is_blocked_between(p_user, p.author_id))
$$;

create function private.can_see_post(p_post uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.user_can_see_post(auth.uid(), p_post)
$$;

-- Can the caller see media p_media? (owner, or it is posted in a group the caller
-- belongs to and there is no block between caller and owner)
create function private.can_see_media(p_media uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.media md
    where md.id = p_media
      and (md.owner_id = auth.uid()
           or (not private.is_blocked_between(auth.uid(), md.owner_id)
               and exists (select 1 from public.posts p
                           join public.group_members m on m.group_id = p.group_id and m.user_id = auth.uid()
                           where p.media_id = md.id))))
$$;

create function private.has_premium(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.entitlements e
                 where e.user_id = p_user and e.entitlement = 'premium'
                   and (e.expires_at is null or e.expires_at > now()))
$$;

-- Tribute visibility: members other than the honoree (and not blocked with the
-- honoree) always; the honoree only once delivered.
create function private.can_see_tribute(p_tribute uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.tributes t
    where t.id = p_tribute
      and private.is_member(t.group_id)
      and (
        (t.honoree_id <> auth.uid() and not private.is_blocked_with(t.honoree_id))
        or (t.honoree_id = auth.uid() and t.delivered_at is not null and t.delivered_at <= now())))
$$;

revoke all on all functions in schema private from public;
grant execute on function
  private.my_group_ids(),
  private.is_member(uuid),
  private.is_admin(uuid),
  private.blocked_ids(),
  private.is_blocked_with(uuid),
  private.co_member_ids(),
  private.can_see_post(uuid),
  private.can_see_media(uuid),
  private.can_see_tribute(uuid),
  private.is_safe_path(text),
  private.is_emoji(text),
  private.is_uuid(text),
  private.media_path_ok(text, uuid, uuid),
  private.new_invite_token()
to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Policies
-- ---------------------------------------------------------------------------

-- profiles
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or id in (select private.co_member_ids()));
create policy profiles_update_own on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
grant select on public.profiles to authenticated;
grant update (display_name, avatar_path) on public.profiles to authenticated;

-- profile_private (writes only through set_birthday / confirm_age)
create policy profile_private_select_own on public.profile_private for select to authenticated
  using (user_id = (select auth.uid()));
grant select on public.profile_private to authenticated;

-- groups (writes only through RPCs)
create policy groups_select_member on public.groups for select to authenticated
  using (id in (select private.my_group_ids()));
grant select on public.groups to authenticated;

-- group_members
create policy group_members_select on public.group_members for select to authenticated
  using (group_id in (select private.my_group_ids()));
grant select on public.group_members to authenticated;

-- group_invites
create policy group_invites_select on public.group_invites for select to authenticated
  using (group_id in (select private.my_group_ids()));
grant select on public.group_invites to authenticated;

-- blocks (own rows; the blocked person never sees the row)
create policy blocks_select_own on public.blocks for select to authenticated
  using (blocker_id = (select auth.uid()));
grant select on public.blocks to authenticated;

-- media
create policy media_select on public.media for select to authenticated
  using (owner_id = (select auth.uid()) or private.can_see_media(id));
create policy media_insert_own on public.media for insert to authenticated
  with check (owner_id = (select auth.uid()));
grant select on public.media to authenticated;
grant insert (id, owner_id, kind, original_path, front_original_path, motion_path,
              width, height, front_width, front_height, duration_ms)
  on public.media to authenticated;

-- daily_invitations: members, and only once fired (the moment stays a surprise)
create policy daily_invitations_select on public.daily_invitations for select to authenticated
  using (group_id in (select private.my_group_ids()) and fires_at <= now());
grant select on public.daily_invitations to authenticated;

-- posts
create policy posts_select on public.posts for select to authenticated
  using (group_id in (select private.my_group_ids())
         and author_id not in (select private.blocked_ids()));
grant select on public.posts to authenticated;

-- messages
create policy messages_select on public.messages for select to authenticated
  using (group_id in (select private.my_group_ids())
         and author_id not in (select private.blocked_ids()));
grant select on public.messages to authenticated;

-- reactions (rows only; writes through react / unreact)
create policy reactions_select on public.reactions for select to authenticated
  using (group_id in (select private.my_group_ids())
         and user_id not in (select private.blocked_ids())
         and private.can_see_post(post_id));
grant select on public.reactions to authenticated;

-- post_tags: self-tag only, member of the post's group
create policy post_tags_select on public.post_tags for select to authenticated
  using (group_id in (select private.my_group_ids())
         and user_id not in (select private.blocked_ids())
         and private.can_see_post(post_id));
create policy post_tags_insert_self on public.post_tags for insert to authenticated
  with check (user_id = (select auth.uid()) and private.can_see_post(post_id));
create policy post_tags_delete_self on public.post_tags for delete to authenticated
  using (user_id = (select auth.uid()));
grant select, delete on public.post_tags to authenticated;
grant insert (post_id, user_id) on public.post_tags to authenticated;

-- collages
create policy collages_select on public.collages for select to authenticated
  using (group_id in (select private.my_group_ids()));
grant select on public.collages to authenticated;

-- weekly_recaps (edits through update_recap)
create policy weekly_recaps_select on public.weekly_recaps for select to authenticated
  using (group_id in (select private.my_group_ids()));
grant select on public.weekly_recaps to authenticated;

-- albums / album_items
create policy albums_select on public.albums for select to authenticated
  using (group_id in (select private.my_group_ids()));
grant select on public.albums to authenticated;

create policy album_items_select on public.album_items for select to authenticated
  using (exists (select 1 from public.albums a
                 where a.id = album_id and a.group_id in (select private.my_group_ids()))
         and private.can_see_post(post_id));
grant select on public.album_items to authenticated;

-- tribute_requests: members except the honoree (and anyone blocked with the honoree)
create policy tribute_requests_select on public.tribute_requests for select to authenticated
  using (group_id in (select private.my_group_ids())
         and honoree_id <> (select auth.uid())
         and honoree_id not in (select private.blocked_ids()));
grant select on public.tribute_requests to authenticated;

-- tribute_contributions: the contributor only; withdrawable until the due time
create policy tribute_contributions_select_own on public.tribute_contributions for select to authenticated
  using (contributor_id = (select auth.uid()));
create policy tribute_contributions_delete_own on public.tribute_contributions for delete to authenticated
  using (contributor_id = (select auth.uid())
         and exists (select 1 from public.tribute_requests r where r.id = request_id and r.due_at > now()));
grant select, delete on public.tribute_contributions to authenticated;

-- tributes: honoree only once delivered
create policy tributes_select on public.tributes for select to authenticated
  using (private.can_see_tribute(id));
grant select on public.tributes to authenticated;

-- year_stories
create policy year_stories_select on public.year_stories for select to authenticated
  using (group_id in (select private.my_group_ids()));
grant select on public.year_stories to authenticated;

-- devices (writes through register_device / unregister_device)
create policy devices_select_own on public.devices for select to authenticated
  using (user_id = (select auth.uid()));
create policy devices_delete_own on public.devices for delete to authenticated
  using (user_id = (select auth.uid()));
grant select, delete on public.devices to authenticated;

-- notification_settings (writes through set_quiet_hours)
create policy notification_settings_select_own on public.notification_settings for select to authenticated
  using (user_id = (select auth.uid()));
grant select on public.notification_settings to authenticated;

-- reports: insert only (also available as the report() RPC)
create policy reports_insert_own on public.reports for insert to authenticated
  with check (reporter_id = (select auth.uid()));
grant insert (reporter_id, target_kind, target_id, reason) on public.reports to authenticated;

-- entitlements: read own (written by the RevenueCat webhook with the service role)
create policy entitlements_select_own on public.entitlements for select to authenticated
  using (user_id = (select auth.uid()));
grant select on public.entitlements to authenticated;

-- jobs, ai_cost_log, app_config: RLS on, no policies, no grants -> service role only.
revoke all on public.jobs, public.ai_cost_log, public.app_config from anon, authenticated;

-- public subset of app_config
grant select on public.public_app_config to anon, authenticated;

-- service role (worker, webhooks, web server) keeps full table access.
grant all on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to service_role;

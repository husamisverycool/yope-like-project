-- =============================================================================
-- 0025 account deletion takes the person's plans and named albums with it.
--
-- Spec (Safety and privacy): "Full account deletion deletes all data." Until now a deleted account
-- left its plans (created_by null, keeping the title, place and note it wrote) and its albums
-- (created_by null, keeping the name it gave). Both are the person's own words, so both go:
--   * plans: Partiful, the mechanics reference for plans — "Deleting your Partiful account removes
--     your personal data and account history from Partiful's servers"
--     (help.partiful.com/en/articles/15525644, read 2026-10-17); every plan they made goes, upcoming,
--     past or cancelled. No notice is sent: the notices Apple Invites and Partiful send belong to a
--     host's own "Delete Event" / "Cancel Event", and a notice would carry the departed person's name
--     and words after their deletion (design/MERGE_DECISIONS.md FV-5). The plan's answers and queued
--     pushes go with it (plan_answers cascade; private.on_plan_deleted drops the jobs and the cover).
--   * albums: Apple Shared Albums — "the shared album is automatically removed from all of your
--     devices and the devices of your subscribers" (support.apple.com/108314, read 2026-10-17). The
--     photos in them are group posts and stay in the group; only the album (its name and order) goes.
-- Everything else delete_account did is unchanged (0007).
-- =============================================================================

create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_group uuid;
begin
  -- 1. photos (full cascade: posts, chat photos, reactions, tags, recaps, albums,
  --    tribute contributions, collages, year stories, storage)
  delete from public.media md where md.owner_id = v_uid;
  -- 2. the rest of their content
  delete from public.messages m where m.author_id = v_uid;
  delete from public.reactions r where r.user_id = v_uid;
  delete from public.post_tags t where t.user_id = v_uid;
  delete from public.tribute_contributions c where c.contributor_id = v_uid;
  delete from public.tribute_requests q where q.honoree_id = v_uid;
  delete from public.plans pl where pl.created_by = v_uid;
  delete from public.albums a where a.created_by = v_uid;
  -- 3. memberships (admin hand-off; a group they were the last member of is deleted)
  for v_group in select m.group_id from public.group_members m where m.user_id = v_uid loop
    perform private.remove_membership(v_group, v_uid);
  end loop;
  update public.groups g set cover_path = null where g.cover_path like 'u/' || v_uid::text || '/%';
  delete from public.group_invites i where i.created_by = v_uid;
  -- 4. account rows
  delete from public.devices d where d.user_id = v_uid;
  delete from public.notification_settings s where s.user_id = v_uid;
  delete from public.blocks b where b.blocker_id = v_uid or b.blocked_id = v_uid;
  delete from public.reports r where r.reporter_id = v_uid;
  delete from public.entitlements e where e.user_id = v_uid;
  delete from public.profile_private pp where pp.user_id = v_uid;
  delete from public.profiles p where p.id = v_uid;
  -- 5. files, the auth user and the subscription record (worker, service role)
  perform private.enqueue_storage_delete(null,
    array['u/' || v_uid::text || '/', 'avatars/' || v_uid::text || '/']);
  perform private.enqueue('auth.delete_user', jsonb_build_object('user_id', v_uid),
    'auth.delete_user:' || v_uid::text);
end;
$$;

-- (create or replace keeps the function's grants from 0007: authenticated only.)

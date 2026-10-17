-- =============================================================================
-- 0032 reports reach every surface with user-made or group-made content (spec, Safety: "Block, report
-- and leave on every relevant surface"). New report target kinds, as 'selfie' was added in 0018:
--   plan        a plan (its title, place, note and cover are its maker's), by plans.id — another
--               member's plan of one of your groups;
--   tribute     a birthday video, by tributes.id — one you can watch (private.can_see_tribute);
--   year_story  a group's year story, by year_stories.id — one of your groups';
--   collage     a same-moment collage, by collages.id — one of your groups';
--   recap       a weekly recap, by weekly_recaps.id — one of your groups'.
-- A block does not stop reporting (as for posts). Everything else report() did is unchanged.
-- =============================================================================

alter type public.report_target_kind add value if not exists 'plan';
alter type public.report_target_kind add value if not exists 'tribute';
alter type public.report_target_kind add value if not exists 'year_story';
alter type public.report_target_kind add value if not exists 'collage';
alter type public.report_target_kind add value if not exists 'recap';

create or replace function public.report(p_target_kind public.report_target_kind, p_target_id uuid, p_reason text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_ok boolean;
  v_id uuid;
begin
  if p_reason is null or char_length(btrim(p_reason)) not between 1 and 1000 then
    raise exception 'invalid_reason' using errcode = 'PT400';
  end if;
  v_ok := case p_target_kind::text
    when 'post' then exists (select 1 from public.posts p where p.id = p_target_id and private.is_member(p.group_id))
    when 'message' then exists (select 1 from public.messages m where m.id = p_target_id and private.is_member(m.group_id))
    when 'user' then p_target_id <> v_uid
                     and (private.shares_group(v_uid, p_target_id) or private.is_blocked_with(p_target_id))
    when 'group' then private.is_member(p_target_id)
    when 'selfie' then exists (select 1 from public.selfie_reactions s
                               where s.id = p_target_id and s.user_id <> v_uid and private.can_see_post(s.post_id))
    when 'plan' then exists (select 1 from public.plans pl
                             where pl.id = p_target_id and private.is_member(pl.group_id)
                               and pl.created_by is distinct from v_uid)
    when 'tribute' then private.can_see_tribute(p_target_id)
    when 'year_story' then exists (select 1 from public.year_stories ys where ys.id = p_target_id and private.is_member(ys.group_id))
    when 'collage' then exists (select 1 from public.collages c where c.id = p_target_id and private.is_member(c.group_id))
    when 'recap' then exists (select 1 from public.weekly_recaps r where r.id = p_target_id and private.is_member(r.group_id))
    else false
  end;
  if not coalesce(v_ok, false) then
    raise exception 'target_not_found' using errcode = 'PT404';
  end if;
  insert into public.reports (reporter_id, target_kind, target_id, reason)
  values (v_uid, p_target_kind, p_target_id, btrim(p_reason))
  returning id into v_id;
  perform private.enqueue('moderation.report', jsonb_build_object('report_id', v_id));
  return v_id;
end;
$$;

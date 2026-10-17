-- =============================================================================
-- 0058 the age gate also covers the other ways a post is made (docs/API.md §12.6): create_overnight_post and
-- answer_question raise age_not_confirmed (PT403) before confirm_age, as create_post does since 0055.
-- The bodies are the current definitions with the check added first.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.create_overnight_post(p_media_id uuid, p_group_ids uuid[])
 RETURNS TABLE(group_id uuid, develops_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := private.require_user();
  v_groups uuid[];
  v_group uuid;
  v_media public.media;
  v_tz text;
  v_at timestamptz;
begin
  perform private.require_age_confirmed(v_uid);
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
$function$;

CREATE OR REPLACE FUNCTION public.answer_question(p_post_id uuid, p_question_id uuid)
 RETURNS posts
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := private.require_user();
  v_post public.posts;
  v_q public.group_questions;
begin
  perform private.require_age_confirmed(v_uid);
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
$function$;

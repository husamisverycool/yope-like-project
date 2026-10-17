-- =============================================================================
-- 0028 group_plans: every plan of a group, for the group's plans list (plans.list).
--
-- Until now only the next upcoming plan could be reached in the app (next_plans); past plans (and
-- their photos) and cancelled ones (and Restore) only from an old notification. The list follows
-- Apple Invites, whose events are "sorted into the following categories: Upcoming, All Events, Past
-- Events …" and, on iCloud.com, read by scrolling down through the categories
-- (support.apple.com/guide/apple-invites/view-your-events-dev18a008ffb/ios), and Partiful's events
-- page with its Past Events (help.partiful.com/en/articles/15525513):
--   upcoming  not cancelled and not over, soonest first (Apple: "your next event" leads);
--   past      over (after its end, or after its last local day — private.plan_over), latest first;
--   canceled  cancelled (upcoming or not), latest first — still restorable while not over.
-- Same visibility as the plans table (members; plans by someone with a block hidden) and the
-- caller's own answer, as next_plans.
-- =============================================================================

create function public.group_plans(p_group_id uuid)
returns table (
  id uuid, group_id uuid, created_by uuid, title text, starts_at timestamptz, ends_at timestamptz, all_day boolean,
  local_date date, place text, cover_path text, canceled_at timestamptz, my_answer text, state text
)
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
  with listed as (
    select pl.*, a.answer,
           case when pl.canceled_at is not null then 'canceled'
                when private.plan_over(pl) then 'past'
                else 'upcoming' end as plan_state
      from public.plans pl
      left join public.plan_answers a on a.plan_id = pl.id and a.user_id = auth.uid()
     where pl.group_id = p_group_id
       and (pl.created_by is null or pl.created_by not in (select private.blocked_ids()))
  )
  select l.id, l.group_id, l.created_by, l.title, l.starts_at, l.ends_at, l.all_day, l.local_date, l.place,
         l.cover_path, l.canceled_at, l.answer, l.plan_state
    from listed l
   order by case l.plan_state when 'upcoming' then 0 when 'past' then 1 else 2 end,
            case when l.plan_state = 'upcoming' then l.starts_at end asc,
            case when l.plan_state <> 'upcoming' then l.starts_at end desc,
            l.id;
end;
$$;

revoke all on function public.group_plans(uuid) from public, anon;
grant execute on function public.group_plans(uuid) to authenticated;

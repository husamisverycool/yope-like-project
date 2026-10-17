-- =============================================================================
-- 0046 group_collages without page_count.
--
-- group_collages (0033) returned collages.page_count. No client reads it there (a collage's pages come
-- from its `collages` row, §5.13), and an RPC returns no number of anything (tenet: no counts,
-- tests/security/no-counts.test.ts). Same function, same order, without the column.
-- =============================================================================

drop function public.group_collages(uuid, date, date);

create function public.group_collages(p_group_id uuid, p_from date default null, p_to date default null)
returns table (
  collage_id uuid,
  invitation_id uuid,
  local_date date,
  image_path text,
  widget_path text,
  share_path text,
  composed_at timestamptz
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
  select c.id, c.invitation_id, d.local_date, c.image_path, c.widget_path, c.share_path, c.composed_at
    from public.collages c
    join public.daily_invitations d on d.id = c.invitation_id
   where c.group_id = p_group_id
     and c.status = 'ready'
     and (p_from is null or d.local_date >= p_from)
     and (p_to is null or d.local_date <= p_to)
   order by d.local_date desc, d.fires_at desc, c.id;
end;
$$;

revoke all on function public.group_collages(uuid, date, date) from public, anon;
grant execute on function public.group_collages(uuid, date, date) to authenticated;

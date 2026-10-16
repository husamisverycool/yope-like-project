-- =============================================================================
-- 0022 sweep of unlinked selfie and plan-cover uploads. The apps upload a selfie (u/<uid>/selfies/…) or a plan cover
-- (u/<uid>/plans/…) first and link it with react_with_selfie / create_plan / update_plan; when that call never comes
-- (it failed, or the person left the sheet), the file is linked to nothing and nobody can see it. Files a row
-- replaces or loses are deleted by the triggers of 0018 / 0019; this catches the rest.
--
-- due_unlinked_uploads (worker scheduler, hourly): such files older than 7 days (an upload in progress is never
-- touched) are deleted through storage.delete, at most p_limit per call. Media of posts, voice notes, avatars and
-- group covers are not swept here: their uploads can wait in an app's outbox for days.
-- =============================================================================

create function public.due_unlinked_uploads(p_now timestamptz default now(), p_limit integer default 500)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_paths text[];
begin
  select coalesce(array_agg(o.name), '{}') into v_paths
    from (
      select so.name
        from storage.objects so
       where so.bucket_id = 'media'
         and (so.name like 'u/%/selfies/%' or so.name like 'u/%/plans/%')
         and so.created_at < coalesce(p_now, now()) - interval '7 days'
         and not exists (select 1 from public.selfie_reactions s where s.image_path = so.name)
         and not exists (select 1 from public.plans pl where pl.cover_path = so.name)
         -- a delete already waiting for this file
         and not exists (select 1 from public.jobs j
                          where j.kind = 'storage.delete' and j.status in ('queued', 'running')
                            and j.payload -> 'paths' ? so.name)
       order by so.created_at
       limit greatest(coalesce(p_limit, 500), 1)
    ) o;
  if cardinality(v_paths) > 0 then
    perform private.enqueue_storage_delete(v_paths);
  end if;
  return cardinality(v_paths);
end;
$$;

revoke all on function public.due_unlinked_uploads(timestamptz, integer) from public, anon, authenticated;
grant execute on function public.due_unlinked_uploads(timestamptz, integer) to service_role;

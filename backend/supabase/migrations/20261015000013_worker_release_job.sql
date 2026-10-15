-- =============================================================================
-- 0013 release_job: a worker that stops (deploy, scale-down) hands its running jobs back
-- to the queue without spending an attempt or waiting for a backoff, so another worker
-- picks them up at once. SERVICE ROLE ONLY.
-- If a newer queued job with the same dedupe key exists, the released one is cancelled
-- (the newer one does the work), as in fail_job.
-- =============================================================================

create function public.release_job(p_job_id bigint, p_worker_id text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs;
begin
  select * into v_job from public.jobs j
   where j.id = p_job_id and j.status = 'running' and j.locked_by = p_worker_id
   for update;
  if not found then
    return false;
  end if;
  if v_job.dedupe_key is not null and exists (
      select 1 from public.jobs o where o.dedupe_key = v_job.dedupe_key and o.status = 'queued') then
    update public.jobs j set status = 'cancelled', finished_at = now(), locked_at = null,
                             last_error = 'released: a newer queued job does the work'
     where j.id = p_job_id;
  else
    update public.jobs j
       set status = 'queued', locked_at = null, locked_by = null,
           attempts = greatest(j.attempts - 1, 0), run_at = now(),
           last_error = 'released: worker shutdown'
     where j.id = p_job_id;
  end if;
  return true;
end;
$$;

revoke all on function public.release_job(bigint, text) from public, anon, authenticated;
grant execute on function public.release_job(bigint, text) to service_role;

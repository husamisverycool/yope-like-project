-- =============================================================================
-- 0023 weekly recaps stuck at "Creating your recap…".
--
-- Until design/copy carried week.recap.template, every recap.generate job failed with
-- MissingCopyError (the worker resolves the template before anything else) and ended 'failed'
-- after its attempts, so the recap stayed 'pending' and no recap-ready push was sent. The key now
-- exists (backend/worker/test/unit/copy-tokens.test.ts checks every worker key against the real
-- generated table). Queue one fresh recap.generate job for each pending recap that has no queued or
-- running job; the job is idempotent (it returns at once for a recap already 'ready').
-- =============================================================================

select private.enqueue('recap.generate',
         jsonb_build_object('recap_id', r.id, 'group_id', r.group_id, 'week_start', r.week_start),
         'recap.generate:' || r.id::text)
  from public.weekly_recaps r
 where r.status = 'pending'
   and not exists (
         select 1 from public.jobs j
          where j.kind = 'recap.generate'
            and j.payload ->> 'recap_id' = r.id::text
            and j.status in ('queued', 'running'));

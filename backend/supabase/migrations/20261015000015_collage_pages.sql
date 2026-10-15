-- =============================================================================
-- 0015 collages.page_count: how many pages the composed collage has.
--
-- Layout option B ("wall pages", design/collage-options/README.md) puts at most 12 answers
-- on a 9:16 page and continues on further pages; options A and C are always one page. The
-- worker writes page n as display-<n>.jpg (and share-<n>.jpg for B) next to image_path
-- (= page 1), so clients build the other pages' paths from this count
-- (docs/API.md section 5.13). Readable by members through the existing select policy.
-- =============================================================================

alter table public.collages
  add column page_count integer not null default 1 check (page_count >= 1);

comment on column public.collages.page_count is
  'Number of composed pages (display-1.jpg … display-<n>.jpg in the folder of image_path). Set by the worker.';

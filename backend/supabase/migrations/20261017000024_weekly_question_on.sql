-- =============================================================================
-- 0024 the weekly question is on (docs/OWNER_DECISIONS.md 2026-10-17 decision 30).
--
-- Decision 30: "the catalogue is asked in order, a new question each week; on by default for new
-- groups, an admin can turn it off". It closes the two lead decisions left BLOCKED in 0020
-- (design tokens question.weekly.layout.rotation and question.weekly.layout.defaultOn):
--   * rotation: the whole catalogue (copy keys question.weekly.q01 … q09, design/copy/account.json)
--     in its order, as Retro shows its prompts in a fixed order (nux_card_title_what_to_share_0..7);
--     every group starts at the first key and starts again after the last one
--     (current_group_question: number of questions asked so far modulo the catalogue length);
--   * default: groups.weekly_question is true for groups created from now on. Existing groups keep
--     their value (the decision names new groups; an admin may already have chosen). Admins still
--     turn it off or on with set_group_weekly_question.
-- Nothing else changes: no push, no reminder, no tally (tenet 5).
-- =============================================================================

update public.app_config
   set value = '["question.weekly.q01", "question.weekly.q02", "question.weekly.q03",
                 "question.weekly.q04", "question.weekly.q05", "question.weekly.q06",
                 "question.weekly.q07", "question.weekly.q08", "question.weekly.q09"]'::jsonb,
       description = 'Ordered copy keys of the weekly questions (question.weekly.q*), asked in order, one per group week, starting again after the last (owner decision 30, migration 0024). NULL: no question is asked'
 where key = 'weekly_question_keys';

alter table public.groups alter column weekly_question set default true;

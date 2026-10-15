-- Local development seed (runs after migrations on `supabase db reset`; never deployed).
-- Intentionally empty: tests create their own users and data through the APIs, and
-- tunables that are not sourced yet (app_config NULL values) must stay NULL so the
-- code paths that depend on them keep failing closed.
select 1;

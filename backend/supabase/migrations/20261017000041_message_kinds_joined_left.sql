-- =============================================================================
-- 0041 two more message kinds: the chat's "{name} joined" and "{name} left the group" lines (owner decision 34,
-- docs/RESEARCH_FEATURES_2026-10-17.md #18). Their rows are written by migration 0042; the enum values are added in
-- a migration of their own because a new enum value cannot be used in the transaction that adds it.
-- =============================================================================

alter type public.message_kind add value if not exists 'joined';
alter type public.message_kind add value if not exists 'left';

// Invite tokens: 18 random bytes, base64url without padding = exactly 24 characters
// (backend/supabase/migrations/…_foundation.sql private.new_invite_token; docs/API.md §5.5).
// Anything else is rejected before any database call.

export const TOKEN_RE = /^[A-Za-z0-9_-]{24}$/;

export const isTokenFormat = (s: string): boolean => TOKEN_RE.test(s);

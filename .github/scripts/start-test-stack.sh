#!/usr/bin/env bash
# CI end-to-end jobs ("android e2e", "ios e2e server"): starts the local Supabase stack (migrations applied) with the
# journeys' test settings, then writes E2E_ANON_KEY and E2E_SERVICE_ROLE_KEY to $GITHUB_ENV.
#   - Test OTPs (code 123456) for the fictional numbers given as arguments (e.g. 12015550101), CI only: they are never
#     committed to config.toml, which `supabase config push` sends to the hosted project, where they would let anyone
#     sign in as these numbers.
#   - min_age_years 13: the age gate fails closed until the owner sets it (docs/OWNER_SETUP.md).
#   - weekly_question_keys q01, q02: the weekly question asks nothing until the owner orders the catalogue (§14.4).
# Run from backend/ (npm ci done by the caller or here).
set -euo pipefail
[ "$#" -gt 0 ] || { echo "usage: start-test-stack.sh <test number>…"; exit 2; }
{
  printf '\n[auth.sms.test_otp]\n'
  for number in "$@"; do printf '%s = "123456"\n' "$number"; done
} >> supabase/config.toml
npm ci
supabase start -x studio,imgproxy,edge-runtime,logflare,vector,supavisor
DB=$(docker ps --format '{{.Names}}' | grep '^supabase_db_' | head -1)
docker exec "$DB" psql -U postgres -v ON_ERROR_STOP=1 \
  -c "update public.app_config set value = '13' where key = 'min_age_years'" \
  -c "update public.app_config set value = '[\"question.weekly.q01\", \"question.weekly.q02\"]' where key = 'weekly_question_keys'"
supabase migration list --local || true
ANON=$(supabase status -o json | jq -r '.ANON_KEY // empty')
SERVICE=$(supabase status -o json | jq -r '.SERVICE_ROLE_KEY // empty')
test -n "$ANON" && test -n "$SERVICE"
echo "E2E_ANON_KEY=$ANON" >> "$GITHUB_ENV"
echo "E2E_SERVICE_ROLE_KEY=$SERVICE" >> "$GITHUB_ENV"

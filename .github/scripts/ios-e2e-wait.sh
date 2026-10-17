#!/usr/bin/env bash
# CI job "ios e2e server": keeps the stack, the worker and the tunnel up until the macOS job named $1 of this run has
# finished (polls the run's jobs through the GitHub API with the job's token, actions: read), at most $2 minutes.
# Checks the API through the tunnel every 30 s and logs if it stops answering (the macOS job's evidence then shows
# the effect), and logs Realtime's postgres_changes subscriptions (realtime.subscription) when their number changes:
# the app's live updates need them. Exits 0 when the job finished (whatever its result: that job reports it), 1 on
# timeout.
set -u
DB=$(docker ps --format '{{.Names}}' | grep '^supabase_db_' | head -1)
subscriptions=""
JOB="${1:?usage: ios-e2e-wait.sh <job name> <minutes>}"
MINUTES="${2:?usage: ios-e2e-wait.sh <job name> <minutes>}"
deadline=$(( $(date +%s) + MINUTES * 60 ))
last=""
while [ "$(date +%s)" -lt "$deadline" ]; do
  state=$(gh api "repos/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID/jobs?per_page=100" \
    --jq ".jobs[] | select(.name == \"$JOB\") | \"\(.status) \(.conclusion)\"" 2> /dev/null | head -1)
  if [ "$state" != "$last" ]; then echo "$(date -u +%H:%M:%S) $JOB: ${state:-not listed yet}"; last="$state"; fi
  case "$state" in
    completed*) exit 0 ;;
  esac
  if [ -n "${E2E_TUNNEL_URL:-}" ] && ! curl -fsS -m 10 -H "apikey: $E2E_ANON_KEY" "$E2E_TUNNEL_URL/auth/v1/health" > /dev/null 2>&1; then
    echo "$(date -u +%H:%M:%S) the API did not answer through the tunnel"
  fi
  now=$(docker exec "$DB" psql -U postgres -At -c "select count(*) from realtime.subscription" 2> /dev/null || echo "?")
  if [ "$now" != "$subscriptions" ]; then echo "$(date -u +%H:%M:%S) Realtime subscriptions: $now"; subscriptions="$now"; fi
  sleep 30
done
echo "$JOB had not finished after $MINUTES minutes"
exit 1

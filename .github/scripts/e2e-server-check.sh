#!/usr/bin/env bash
# CI end-to-end jobs, after the journey ($1: android | ios): what the server and the worker did, read from the job's
# local Supabase. The journey's screenshots show the app; this shows the rows behind them and that the worker processed
# what the journey queued:
# - both: every photo has its renditions (worker: media.renditions), nothing is left queued, no job failed
#   (jobs.status = 'failed', with its error), a reaction, Going answers from two people, Maya's and Theo's messages;
# - android: nothing is left developing, a 9 AM photo was revealed (posts.revealed_at) and its reveal push job ran
#   (push.photos_developed; skipped without FCM keys, logged), a selfie reaction, a weekly question with an answer, the
#   plan restored after its cancel.
# Waits up to 2 minutes for the worker's queue (jobs due now) to drain first. Prints a report; exits 1 if a check fails.
set -u
JOURNEY="${1:?usage: e2e-server-check.sh android|ios}"
DB=$(docker ps --format '{{.Names}}' | grep '^supabase_db_' | head -1)
q() { docker exec "$DB" psql -U postgres -At -v ON_ERROR_STOP=1 -c "$1"; }

for _ in $(seq 1 60); do
  due=$(q "select count(*) from public.jobs where status in ('queued', 'running') and run_at <= now()")
  [ "$due" = "0" ] && break
  sleep 2
done

status=0
check() { # name, sql returning one number, comparison (e.g. "-eq 0", "-ge 1")
  local value
  value=$(q "$2")
  # shellcheck disable=SC2086
  if [ -n "$value" ] && [ "$value" $3 ]; then
    echo "ok    $1: $value"
  else
    echo "FAIL  $1: $value (expected $3)"
    status=1
  fi
}

echo "== server after the $JOURNEY journey"
check "jobs due now still queued or running" "select count(*) from public.jobs where status in ('queued', 'running') and run_at <= now()" "-eq 0"
check "photos without renditions" "select count(*) from public.media where kind = 'photo' and renditions_ready_at is null" "-eq 0"
check "photos with renditions" "select count(*) from public.media where kind = 'photo' and renditions_ready_at is not null" "-ge 1"
check "reactions" "select count(*) from public.reactions" "-ge 1"
check "Going answers" "select count(*) from public.plan_answers where answer = 'going'" "-ge 2"
check "Maya's text messages" "select count(*) from public.messages m join public.profiles p on p.id = m.author_id where m.kind = 'text' and p.display_name like 'Maya%'" "-ge 1"
if [ "$JOURNEY" = "android" ]; then
  check "photos with renditions (first, question answer, 9 AM)" "select count(*) from public.media where kind = 'photo' and renditions_ready_at is not null" "-ge 3"
  check "photos still developing" "select count(*) from public.developing_posts" "-eq 0"
  check "posts revealed at 9 AM" "select count(*) from public.posts where revealed_at is not null" "-ge 1"
  check "reveal push jobs done" "select count(*) from public.jobs where kind = 'push.photos_developed' and status = 'done'" "-ge 1"
  check "selfie reactions" "select count(*) from public.selfie_reactions" "-ge 1"
  check "plans not canceled (restored)" "select count(*) from public.plans where canceled_at is null" "-ge 1"
  check "weekly questions asked" "select count(*) from public.group_questions" "-ge 1"
  check "question answers" "select count(*) from public.posts where question_id is not null" "-ge 1"
else
  check "Theo's text messages" "select count(*) from public.messages m join public.profiles p on p.id = m.author_id where m.kind = 'text' and p.display_name like 'Theo%'" "-ge 1"
fi
check "failed jobs" "select count(*) from public.jobs where status = 'failed'" "-eq 0"

echo "== jobs by kind and status"
q "select kind, status, count(*) from public.jobs group by 1, 2 order by 1, 2"
failed=$(q "select count(*) from public.jobs where status = 'failed'")
if [ "$failed" != "0" ]; then
  echo "== failed jobs"
  q "select id, kind, attempts, left(coalesce(last_error, ''), 300) from public.jobs where status = 'failed' order by id"
fi
exit $status

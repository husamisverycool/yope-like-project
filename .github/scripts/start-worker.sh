#!/usr/bin/env bash
# CI end-to-end jobs: starts backend/worker against the job's local stack, as production runs it (`npm start`):
# renditions, collages, push and widget jobs, the scheduler (every 5 s here instead of every minute). No APNs / FCM
# keys: pushes are skipped and logged. Its log goes to $1. Waits for /healthz. Needs E2E_SERVICE_ROLE_KEY.
# Run from the repository root.
set -euo pipefail
LOG=$(realpath -m "${1:?usage: start-worker.sh <log file>}")
mkdir -p "$(dirname "$LOG")"
(cd backend/worker && npm ci)
(
  cd backend/worker
  SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_SERVICE_ROLE_KEY="${E2E_SERVICE_ROLE_KEY:?E2E_SERVICE_ROLE_KEY is not set}" \
    PORT=8787 WORKER_ID=e2e SCHEDULER_INTERVAL_MS=5000 nohup npm start > "$LOG" 2>&1 &
)
for i in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:8787/healthz > /dev/null 2>&1; then echo "worker up after ${i} s"; exit 0; fi
  sleep 1
done
echo "the worker did not answer /healthz"
tail -50 "$LOG"
exit 1

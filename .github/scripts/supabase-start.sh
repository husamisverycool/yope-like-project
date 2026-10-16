#!/usr/bin/env bash
# CI jobs with a local Supabase: starts the stack (backend/supabase, migrations applied) without the services no test
# uses. Run from backend/.
#
# The stack's host ports (backend/supabase/config.toml, 54320-54329) lie inside Linux's ephemeral port range
# (32768-60999): an outgoing connection, such as one of the image pulls just before, can hold one of them as its local
# port, and the container's binding then fails (run 105, android: "failed to bind host port for 0.0.0.0:54322 …
# address already in use"). The range is reserved first, so new outgoing connections stay off it; a start that still
# meets a port taken earlier is stopped and tried again.
set -euo pipefail
sudo sysctl -q -w net.ipv4.ip_local_reserved_ports=54320-54329
for attempt in 1 2 3; do
  if supabase start -x studio,imgproxy,edge-runtime,logflare,vector,supavisor; then
    exit 0
  fi
  echo "supabase start failed (attempt $attempt of 3)"
  supabase stop --no-backup || true
  sleep $((attempt * 10))
done
exit 1

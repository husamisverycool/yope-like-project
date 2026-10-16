#!/usr/bin/env bash
# CI job "ios e2e server": exposes the job's local Supabase API (127.0.0.1:54321) to the macOS job's simulator through
# a Cloudflare quick tunnel (no account: cloudflared asks trycloudflare.com for a temporary https host). GitHub's macOS
# runners cannot run Docker, so the stack runs here and the iOS journey reaches it through the tunnel.
# The cloudflared release is pinned and checked against its SHA-256. Retries the tunnel up to 3 times, then waits until
# the API answers through it (/auth/v1/health with the anon key). Writes $1/server.json ({url, anonKey}) for the macOS
# job and E2E_TUNNEL_URL to $GITHUB_ENV. cloudflared keeps running for the rest of the job (its log: $2).
#
# What the tunnel exposes: a throwaway stack with the Supabase CLI's well-known local keys and fictional accounts, for
# the length of one CI job, at an unguessable host that only this run's artifact names.
set -euo pipefail
OUT=$(realpath -m "${1:?usage: ios-e2e-tunnel.sh <out dir> <log file>}")
LOG=$(realpath -m "${2:?usage: ios-e2e-tunnel.sh <out dir> <log file>}")
: "${E2E_ANON_KEY:?E2E_ANON_KEY is not set}"
CLOUDFLARED_VERSION=2025.8.1
CLOUDFLARED_SHA256=a66353004197ee4c1fcb68549203824882bba62378ad4d00d234bdb8251f1114

mkdir -p "$OUT" "$(dirname "$LOG")"
BIN="$RUNNER_TEMP/cloudflared"
curl -fsSL --retry 4 -o "$BIN" "https://github.com/cloudflare/cloudflared/releases/download/$CLOUDFLARED_VERSION/cloudflared-linux-amd64"
echo "$CLOUDFLARED_SHA256  $BIN" | sha256sum -c -
chmod +x "$BIN"
"$BIN" --version

url=""
for attempt in 1 2 3; do
  : > "$LOG"
  nohup "$BIN" tunnel --no-autoupdate --protocol http2 --url http://127.0.0.1:54321 >> "$LOG" 2>&1 &
  pid=$!
  for _ in $(seq 1 60); do
    url=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$LOG" | head -1 || true)
    [ -n "$url" ] && break
    kill -0 "$pid" 2> /dev/null || break
    sleep 1
  done
  if [ -n "$url" ]; then
    # The new host needs a moment in DNS and at the edge: wait until the API answers through it.
    for _ in $(seq 1 90); do
      if curl -fsS -m 10 -H "apikey: $E2E_ANON_KEY" "$url/auth/v1/health" > /dev/null 2>&1; then
        echo "tunnel up (attempt $attempt): $url"
        printf '{"url": "%s", "anonKey": "%s"}\n' "$url" "$E2E_ANON_KEY" > "$OUT/server.json"
        echo "E2E_TUNNEL_URL=$url" >> "$GITHUB_ENV"
        exit 0
      fi
      sleep 2
    done
    echo "attempt $attempt: $url never answered"
  else
    echo "attempt $attempt: cloudflared gave no tunnel host"
  fi
  tail -20 "$LOG"
  kill "$pid" 2> /dev/null || true
  url=""
  sleep 5
done
echo "no working tunnel after 3 attempts"
exit 1

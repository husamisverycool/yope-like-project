#!/usr/bin/env bash
# CI job "ios-core", inside the pinned Swift image on the runner's network (`docker run --network host`): AppCore's
# tests on Linux, AppData's integration tests (ios/Packages/AppCore/Tests/AppDataTests) against the job's local Supabase
# (SUPABASE_URL and the keys from `supabase status -o json`).
#
# supabase-swift Realtime opens WebSockets through URLSession, which on Linux goes through the system libcurl, and
# Ubuntu 24.04's libcurl 8.5.0 is built without ws/wss (LocalStack.requireWebSockets). This builds curl (pinned version,
# checked against its SHA-256, the same digest as the GitHub release asset) with WebSockets into /opt/curl-ws and runs
# the tests with it first on LD_LIBRARY_PATH.
#
# APPDATA_INTEGRATION_REQUIRED=1 turns every "stack unreachable" / "no WebSockets" skip into a failure, and the run
# fails if any test still reports itself skipped.
set -euo pipefail

CURL_VERSION=8.16.0
CURL_SHA256=40c8cddbcb6cc6251c03dea423a472a6cea4037be654ba5cf5dec6eb2d22ff1d

: "${SUPABASE_URL:?SUPABASE_URL is not set (the job's supabase status)}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is not set}"
: "${SUPABASE_SERVICE_ROLE_KEY:?SUPABASE_SERVICE_ROLE_KEY is not set}"
: "${SUPABASE_JWT_SECRET:?SUPABASE_JWT_SECRET is not set}"

echo "::group::curl $CURL_VERSION with WebSockets"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends ca-certificates curl make xz-utils libssl-dev zlib1g-dev > /dev/null
work=$(mktemp -d)
curl -fsSL --retry 4 -o "$work/curl.tar.xz" "https://curl.se/download/curl-$CURL_VERSION.tar.xz"
echo "$CURL_SHA256  $work/curl.tar.xz" | sha256sum -c -
tar -xf "$work/curl.tar.xz" -C "$work"
(
  cd "$work/curl-$CURL_VERSION"
  CC=clang ./configure --prefix=/opt/curl-ws --with-openssl --with-zlib --enable-websockets \
    --without-libpsl --without-brotli --without-zstd --without-libidn2 --without-nghttp2 \
    --disable-ldap --disable-manual --disable-docs --disable-static > "$work/configure.log"
  make -j"$(nproc)" > "$work/make.log"
  make install > "$work/install.log"
) || { tail -60 "$work"/*.log; exit 1; }
/opt/curl-ws/bin/curl --version
/opt/curl-ws/bin/curl --version | grep -Eq '^Protocols:.* wss( |$)' || { echo "curl was built without WebSockets"; exit 1; }
echo "::endgroup::"

echo "::group::swift build"
swift --version
swift build --build-tests
echo "::endgroup::"

log="$work/swift-test.log"
set +e
LD_LIBRARY_PATH=/opt/curl-ws/lib APPDATA_INTEGRATION_REQUIRED=1 swift test --skip-build 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
set -e
if grep -E "^Test Case '.*' skipped" "$log"; then
  echo "ios-core: the tests above skipped; in CI every test runs"
  status=1
fi
grep -E "^[[:space:]]*Executed [0-9]+ tests?" "$log" | tail -1 || true
exit "$status"

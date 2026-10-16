#!/usr/bin/env bash
# CI job "ios-core", inside the pinned Swift image on the runner's network (`docker run --network host`): AppCore's
# tests on Linux, AppData's integration tests (ios/Packages/AppCore/Tests/AppDataTests) against the job's local Supabase
# (SUPABASE_URL and the keys from `supabase status -o json`).
#
# supabase-swift Realtime opens WebSockets through URLSession, which on Linux goes through the system libcurl, and
# Ubuntu 24.04's libcurl 8.5.0 is built without ws/wss (LocalStack.requireWebSockets). This builds the same curl version
# (8.5.0; tarball checked against its SHA-256, the same digest as the GitHub release asset) with WebSockets switched on
# into /opt/curl-ws and runs the tests with it first on LD_LIBRARY_PATH:
# - the same version, because FoundationNetworking assembles messages the way curl ≤ 8.5 hands over frame data; with
#   curl 8.16 a frame that straddles two socket reads reached supabase-swift as two broken messages (seen locally:
#   "message_id": null},"columns":[… as a message of its own), the socket was dropped and events were lost;
# - versioned symbols (CURL_OPENSSL_4), because FoundationNetworking links the distribution's.
# Only the tests' process loads it, against the job's local stack; the apps never use it (iOS has Apple's URLSession).
#
# APPDATA_INTEGRATION_REQUIRED=1 turns every "stack unreachable" / "no WebSockets" skip into a failure, and the run
# fails if any test still reports itself skipped.
set -euo pipefail

CURL_VERSION=8.5.0
CURL_SHA256=42ab8db9e20d8290a3b633e7fbb3cec15db34df65fd1015ef8ac1e4723750eeb

: "${SUPABASE_URL:?SUPABASE_URL is not set (from supabase status)}"
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
  CC=clang ./configure --prefix=/opt/curl-ws --with-openssl --with-zlib --enable-websockets --enable-versioned-symbols \
    --without-libpsl --without-brotli --without-zstd --without-libidn2 --without-nghttp2 \
    --disable-ldap --disable-manual --disable-docs --disable-static > "$work/configure.log"
  make -j"$(nproc)" > "$work/make.log"
  make install > "$work/install.log"
) || { tail -60 "$work"/*.log; exit 1; }
/opt/curl-ws/bin/curl --version
/opt/curl-ws/bin/curl --version | grep -Eq '^Protocols:.* wss( |$)' || { echo "curl was built without WebSockets"; exit 1; }
objdump -T /opt/curl-ws/lib/libcurl.so.4 | grep -q 'CURL_OPENSSL_4 *curl_easy_init$' || { echo "libcurl's symbols are not versioned CURL_OPENSSL_4"; exit 1; }
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

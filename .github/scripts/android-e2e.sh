#!/usr/bin/env bash
# CI job "android e2e": runs the on-device journey (android/app/src/androidTest/kotlin/app/main/e2e/JourneyTest.kt) on
# the booted emulator against the job's local Supabase and worker (the emulator reaches the host's loopback at 10.0.2.2),
# then collects its evidence into $E2E_OUT (default android/build/e2e): screenshots and semantics dumps of every step
# (written by the test to /sdcard/Download/e2e), logcat, the Gradle test report and results, and what the server and
# the worker did (e2e-server-check.sh → server.txt; the worker's own log is worker.log, written by the job).
#
# Run from android/. Needs E2E_ANON_KEY and E2E_SERVICE_ROLE_KEY (the stack's keys; the service role is the journey's,
# for the 9 AM reveal, never the app's) and a device on adb.
set -u
OUT="${E2E_OUT:-$PWD/build/e2e}"
mkdir -p "$OUT"

# No system crash / "isn't responding" dialogs over the journey (run 96: "Pixel Launcher isn't responding" covered the
# screen of the CI emulator, an image under load); the app's own crashes still fail the run and show in logcat.
adb shell settings put global hide_error_dialogs 1 || true
adb logcat -G 16M || true
adb logcat -c || true
adb shell rm -rf /sdcard/Download/e2e || true

./gradlew --no-daemon :app:connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.supabaseUrl=http://10.0.2.2:54321 \
  -Pandroid.testInstrumentationRunnerArguments.supabaseAnonKey="${E2E_ANON_KEY:?E2E_ANON_KEY is not set}" \
  -Pandroid.testInstrumentationRunnerArguments.serviceRoleKey="${E2E_SERVICE_ROLE_KEY:?E2E_SERVICE_ROLE_KEY is not set}"
status=$?

bash ../.github/scripts/e2e-server-check.sh > "$OUT/server.txt" 2>&1 || status=1
cat "$OUT/server.txt"

adb logcat -d -v threadtime > "$OUT/logcat.txt" || true
adb pull /sdcard/Download/e2e "$OUT/screens" || true
cp -r app/build/reports/androidTests "$OUT/report" 2>/dev/null || true
cp -r app/build/outputs/androidTest-results "$OUT/results" 2>/dev/null || true
# Gradle can report success when the instrumentation process dies before any test starts (a crash in the app's
# start-up, e.g. a manifest component whose class is missing): the journey must have run, and passed, with no skips.
python3 - "$OUT/results" <<'PY' || status=1
import glob, sys, xml.etree.ElementTree as ET
files = glob.glob(sys.argv[1] + "/**/TEST-*.xml", recursive=True)
total = failed = skipped = 0
for f in files:
    for suite in ET.parse(f).getroot().iter("testsuite"):
        total += int(suite.get("tests", 0))
        failed += int(suite.get("failures", 0)) + int(suite.get("errors", 0))
        skipped += int(suite.get("skipped", 0))
    root = ET.parse(f).getroot()
    if root.tag == "testsuites" and not list(root):
        total += int(root.get("tests", 0))
print(f"android e2e: {total} tests, {failed} failed, {skipped} skipped ({len(files)} result files)")
sys.exit(0 if files and total > 0 and failed == 0 and skipped == 0 else 1)
PY

echo "android e2e: exit $status; evidence in $OUT"
ls -R "$OUT" | head -100 || true
exit $status

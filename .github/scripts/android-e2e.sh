#!/usr/bin/env bash
# CI job "android e2e": runs the on-device journey (android/app/src/androidTest/kotlin/app/main/e2e/JourneyTest.kt) on
# the booted emulator against the job's local Supabase (the emulator reaches the host's loopback at 10.0.2.2), then
# collects its evidence into $E2E_OUT (default android/build/e2e): screenshots and semantics dumps of every step
# (written by the test to /sdcard/Download/e2e), logcat, and the Gradle test report and results.
#
# Run from android/. Needs E2E_ANON_KEY (the stack's anon key) and a device on adb.
set -u
OUT="${E2E_OUT:-$PWD/build/e2e}"
mkdir -p "$OUT"

adb logcat -G 16M || true
adb logcat -c || true
adb shell rm -rf /sdcard/Download/e2e || true

./gradlew --no-daemon :app:connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.supabaseUrl=http://10.0.2.2:54321 \
  -Pandroid.testInstrumentationRunnerArguments.supabaseAnonKey="${E2E_ANON_KEY:?E2E_ANON_KEY is not set}"
status=$?

adb logcat -d -v threadtime > "$OUT/logcat.txt" || true
adb pull /sdcard/Download/e2e "$OUT/screens" || true
cp -r app/build/reports/androidTests "$OUT/report" 2>/dev/null || true
cp -r app/build/outputs/androidTest-results "$OUT/results" 2>/dev/null || true
echo "android e2e: exit $status; evidence in $OUT"
ls -R "$OUT" | head -100 || true
exit $status

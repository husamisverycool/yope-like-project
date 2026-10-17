"""Tests of the release scripts (standard library only): python3 -m unittest discover -s tools/release

- play_upload: the Google Play request sequence against a scripted fake session (no network, no google-auth);
- check_setup: the plain-language messages of each mode, on a temporary config/app.json;
- android_key: create → lock → unlock → fingerprint, when keytool and openssl are installed.
"""
import base64
import contextlib
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import play_upload  # noqa: E402

PACKAGE = "com.yourname.jolt"
BASE = f"{play_upload.API}/{PACKAGE}"
UPLOAD = f"{play_upload.UPLOAD_API}/{PACKAGE}"
DRAFT_ERROR = {"error": {"code": 400, "message": "Only releases with status draft may be created on draft app.",
                         "status": "INVALID_ARGUMENT", "errors": [{"reason": "badRequest"}]}}


class FakeResponse:
    def __init__(self, status: int, body: dict | None = None):
        self.status_code = status
        self.content = json.dumps(body).encode() if body is not None else b""
        self.text = self.content.decode()

    def json(self):
        return json.loads(self.content)


class FakeSession:
    """Answers each (method, url) with the next scripted response and records every request."""

    def __init__(self, script: list[tuple[str, str, int, dict | None]]):
        self.script = list(script)
        self.calls: list[dict] = []

    def request(self, method, url, timeout=None, **kwargs):
        self.calls.append({"method": method, "url": url, **kwargs})
        if not self.script:
            raise AssertionError(f"unexpected request {method} {url}")
        want_method, want_url, status, body = self.script.pop(0)
        if (method, url) != (want_method, want_url):
            raise AssertionError(f"expected {want_method} {want_url}, got {method} {url}")
        return FakeResponse(status, body)


def happy(edit: str, status: str = "completed") -> list:
    return [
        ("POST", f"{BASE}/edits", 200, {"id": edit}),
        ("POST", f"{UPLOAD}/edits/{edit}/bundles", 200, {"versionCode": 42, "sha256": "x"}),
        ("PUT", f"{BASE}/edits/{edit}/tracks/internal", 200, {"track": "internal"}),
        ("POST", f"{BASE}/edits/{edit}:commit", 200, {"id": edit}),
    ]


SERVICE_ACCOUNT = {"type": "service_account", "client_email": "uploader@project.iam.gserviceaccount.com",
                   "private_key": "-----BEGIN PRIVATE KEY-----\nx\n-----END PRIVATE KEY-----\n"}


class PlayUploadTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.aab = self.tmp / "jolt-42.aab"
        self.aab.write_bytes(b"PK\x03\x04 bundle")
        self.summary = self.tmp / "summary.md"
        patcher = mock.patch.dict(os.environ, {"PLAY_SERVICE_ACCOUNT_JSON": json.dumps(SERVICE_ACCOUNT),
                                               "GITHUB_STEP_SUMMARY": str(self.summary)})
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(shutil.rmtree, self.tmp)

    def run_main(self, session: FakeSession) -> tuple[int, str]:
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = play_upload.main(["--package", PACKAGE, "--aab", str(self.aab), "--release-name", "0.1.0 (42)",
                                     "--artifact", "jolt-android-42"], session_factory=lambda info: session,
                                    sleep=lambda s: None)
        return code, out.getvalue()

    def test_insert_upload_track_commit(self):
        session = FakeSession(happy("e1"))
        code, out = self.run_main(session)
        self.assertEqual(code, 0)
        self.assertEqual(session.script, [])
        upload = session.calls[1]
        self.assertEqual(upload["params"], {"uploadType": "media"})
        self.assertEqual(upload["headers"]["Content-Type"], "application/octet-stream")
        self.assertEqual(upload["data"], self.aab.read_bytes())
        self.assertEqual(session.calls[2]["json"], {"track": "internal", "releases": [
            {"versionCodes": ["42"], "status": "completed", "name": "0.1.0 (42)"}]})
        self.assertIn("::notice::Build 42 is on Google Play", out)
        self.assertIn("Build 42 is on Google Play", self.summary.read_text())

    def test_draft_app_at_track_update_is_redone_as_draft(self):
        script = happy("e1")[:2] + [
            ("PUT", f"{BASE}/edits/e1/tracks/internal", 400, DRAFT_ERROR),
            ("DELETE", f"{BASE}/edits/e1", 204, None),
        ] + happy("e2")
        session = FakeSession(script)
        code, out = self.run_main(session)
        self.assertEqual(code, 0)
        self.assertEqual(session.script, [])
        self.assertEqual(session.calls[-2]["json"]["releases"][0]["status"], "draft")
        self.assertIn("draft", self.summary.read_text())
        self.assertIn("::warning::", out)

    def test_draft_app_at_commit_is_redone_as_draft(self):
        script = happy("e1")[:3] + [
            ("POST", f"{BASE}/edits/e1:commit", 400, DRAFT_ERROR),
            ("DELETE", f"{BASE}/edits/e1", 404, {"error": {"code": 404, "message": "Edit not found"}}),
        ] + happy("e2")
        session = FakeSession(script)
        code, _ = self.run_main(session)
        self.assertEqual(code, 0)
        self.assertEqual(session.calls[-2]["json"]["releases"][0]["status"], "draft")

    def test_new_app_asks_for_the_first_upload_by_hand(self):
        session = FakeSession([("POST", f"{BASE}/edits", 404,
                                {"error": {"code": 404, "message": f"Package not found: {PACKAGE}.", "status": "NOT_FOUND"}})])
        code, out = self.run_main(session)
        self.assertEqual(code, 2)
        summary = self.summary.read_text()
        self.assertIn("first upload by hand", summary)
        self.assertIn("jolt-android-42", summary)
        self.assertIn("Create new release", summary)
        self.assertIn("::error::", out)

    def test_missing_permission_names_the_service_account(self):
        session = FakeSession([("POST", f"{BASE}/edits", 403,
                                {"error": {"code": 403, "message": "The caller does not have permission", "status": "PERMISSION_DENIED"}})])
        code, out = self.run_main(session)
        self.assertEqual(code, 1)
        self.assertIn(SERVICE_ACCOUNT["client_email"], out)
        self.assertIn("Users and permissions", out)

    def test_api_switched_off(self):
        message = "Google Play Android Developer API has not been used in project 123 before or it is disabled."
        session = FakeSession([("POST", f"{BASE}/edits", 403, {"error": {"code": 403, "message": message}})])
        code, out = self.run_main(session)
        self.assertEqual(code, 1)
        self.assertIn("androidpublisher.googleapis.com", out)

    def test_other_errors_stop_without_draft_retry(self):
        script = happy("e1")[:2] + [
            ("PUT", f"{BASE}/edits/e1/tracks/internal", 400,
             {"error": {"code": 400, "message": "APK specifies a version code that has already been used."}}),
            ("DELETE", f"{BASE}/edits/e1", 204, None),
        ]
        session = FakeSession(script)
        code, out = self.run_main(session)
        self.assertEqual(code, 1)
        self.assertEqual(session.script, [])
        self.assertIn("build number", out)

    def test_transient_errors_are_retried(self):
        script = [("POST", f"{BASE}/edits", 503, {"error": {"code": 503, "message": "backend"}})] + happy("e1")
        session = FakeSession(script)
        code, _ = self.run_main(session)
        self.assertEqual(code, 0)
        self.assertEqual(session.script, [])

    def test_key_as_base64(self):
        os.environ["PLAY_SERVICE_ACCOUNT_JSON"] = base64.b64encode(json.dumps(SERVICE_ACCOUNT).encode()).decode()
        seen = {}
        session = FakeSession(happy("e1"))

        def factory(info):
            seen.update(info)
            return session

        with contextlib.redirect_stdout(io.StringIO()):
            code = play_upload.main(["--package", PACKAGE, "--aab", str(self.aab)], session_factory=factory, sleep=lambda s: None)
        self.assertEqual(code, 0)
        self.assertEqual(seen["client_email"], SERVICE_ACCOUNT["client_email"])


class CheckSetupTest(unittest.TestCase):
    """check_setup.py on a temporary config/app.json; secrets come only from the environment given here."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp)
        self.config = json.loads((HERE.parents[1] / "config" / "app.json").read_text())

    def check(self, mode: str, config_changes: dict | None = None, **secrets) -> tuple[int, str]:
        config = json.loads(json.dumps(self.config))
        for path, value in (config_changes or {}).items():
            node = config
            *parents, last = path.split(".")
            for key in parents:
                node = node[key]
            node[last] = value
        path = self.tmp / "app.json"
        path.write_text(json.dumps(config))
        environment = {k: v for k, v in os.environ.items() if k in ("PATH", "HOME", "LANG")}
        environment.update(APP_CONFIG_PATH=str(path), GITHUB_REPOSITORY_OWNER="Some-Owner", **secrets)
        result = subprocess.run([sys.executable, str(HERE / "check_setup.py"), mode], capture_output=True, text=True,
                                env=environment)
        return result.returncode, result.stdout + result.stderr

    ready = {
        "supabase.url": "https://abcdefghijklmnopqrst.supabase.co",
        "supabase.anonKey": "anon",
        "domain.value": "jolt-some-owner.fly.dev",
        "ios.teamId": "ABCDE12345",
        "ios.appStoreId": "1234567890",
        "android.applicationId": "com.yourname.jolt",
        "android.sha256CertFingerprints": [":".join(["AB"] * 32)],
    }

    def test_play_names_every_missing_step(self):
        code, out = self.check("play", {"domain.value": None, "android.applicationId": "com.example.groupphotos"})
        self.assertEqual(code, 1)
        self.assertIn("Google Play does not accept the package name com.example", out)
        self.assertIn("create the Android signing key", out)
        self.assertIn("PLAY_SERVICE_ACCOUNT_JSON is not set", out)
        self.assertIn("jolt-some-owner.fly.dev", out)
        self.assertIn("::warning::GitHub secret ANDROID_GOOGLE_SERVICES_JSON", out)

    def test_support_address_is_a_warning_until_set(self):
        code, out = self.check("services", {"supabase.url": "https://abcdefghijklmnopqrst.supabase.co"},
                               FLY_API_TOKEN="t", SUPABASE_SERVICE_ROLE_KEY="k")
        self.assertEqual(code, 0, out)
        self.assertIn("::warning::config/app.json support.email is not set", out)
        code, out = self.check("services", {"supabase.url": "https://abcdefghijklmnopqrst.supabase.co", "support.email": "help@example.com"},
                               FLY_API_TOKEN="t", SUPABASE_SERVICE_ROLE_KEY="k")
        self.assertNotIn("support.email", out)
        code, out = self.check("testflight", self.ready, APPLE_TEAM_ID="ABCDE12345", ASC_KEY_ID="k", ASC_ISSUER_ID="i", ASC_KEY_P8="p")
        self.assertIn("the App Store a Support URL", out)

    def test_play_checks_the_firebase_file_names_the_app(self):
        firebase = {"client": [{"client_info": {"android_client_info": {"package_name": "com.other.app"}}}]}
        code, out = self.check("play", self.ready, ANDROID_GOOGLE_SERVICES_JSON=json.dumps(firebase),
                               PLAY_SERVICE_ACCOUNT_JSON="not json")
        self.assertEqual(code, 1)
        self.assertIn("has no Android app com.yourname.jolt", out)
        self.assertIn("PLAY_SERVICE_ACCOUNT_JSON is not the text of a .json file", out)

    def test_testflight_needs_the_domain(self):
        secrets = dict(APPLE_TEAM_ID="ABCDE12345", ASC_KEY_ID="k", ASC_ISSUER_ID="i", ASC_KEY_P8="p")
        code, out = self.check("testflight", {**self.ready, "domain.value": None}, **secrets)
        self.assertEqual(code, 1)
        self.assertIn("repository variable APP_DOMAIN", out)
        code, out = self.check("testflight", self.ready, **secrets)
        self.assertEqual(code, 0, out)

    def test_server_review_account(self):
        base = {"supabase.url": "https://abcdefghijklmnopqrst.supabase.co"}
        secrets = dict(SUPABASE_ACCESS_TOKEN="t", SUPABASE_DB_PASSWORD="p")
        code, out = self.check("server", base, **secrets)
        self.assertEqual(code, 0, out)
        self.assertIn("::warning::GitHub secrets REVIEW_PHONE and REVIEW_CODE are not set", out)
        code, out = self.check("server", base, REVIEW_PHONE="+1 201 555 0142", REVIEW_CODE="123456", **secrets)
        self.assertEqual(code, 0, out)
        self.assertNotIn("REVIEW_", out)
        code, out = self.check("server", base, REVIEW_PHONE="2015550142", REVIEW_CODE="12 456", **secrets)
        self.assertEqual(code, 1)
        self.assertIn("REVIEW_PHONE is not a phone number", out)
        self.assertIn("REVIEW_CODE must be digits only", out)
        code, out = self.check("server", base, REVIEW_CODE="123456", **secrets)
        self.assertEqual(code, 1)
        self.assertIn("Set both GitHub secrets REVIEW_PHONE and REVIEW_CODE", out)

    def test_review_phone_digits(self):
        sys.path.insert(0, str(HERE))
        from release_common import review_phone_digits
        self.assertEqual(review_phone_digits("+1 (201) 555-0142"), "12015550142")
        self.assertIsNone(review_phone_digits("2015550142"))
        self.assertIsNone(review_phone_digits("+0 123"))

    def test_android_key_wants_a_long_password(self):
        code, out = self.check("android-key", ANDROID_KEYSTORE_PASSWORD="short")
        self.assertEqual(code, 1)
        self.assertIn("too short", out)
        code, out = self.check("android-key", ANDROID_KEYSTORE_PASSWORD="five random words for the key")
        self.assertEqual(code, 0, out)

    def test_services_minimum_and_web_wait(self):
        code, out = self.check("services")
        self.assertEqual(code, 1)
        self.assertIn("FLY_API_TOKEN is not set", out)
        self.assertIn("SUPABASE_SERVICE_ROLE_KEY is not set", out)
        code, out = self.check("services", {"supabase.url": "https://abcdefghijklmnopqrst.supabase.co"},
                               FLY_API_TOKEN="t", SUPABASE_SERVICE_ROLE_KEY="k")
        self.assertEqual(code, 0, out)
        self.assertIn("worker_app=jolt-worker-some-owner", out)
        self.assertIn("web_app=jolt-some-owner", out)
        self.assertIn("web=wait", out)
        self.assertIn("The invite page waits: config/app.json ios.appStoreId", out)

    def test_services_revenuecat_webhook_required_once_the_apps_sell(self):
        base = {"supabase.url": "https://abcdefghijklmnopqrst.supabase.co"}
        secrets = dict(FLY_API_TOKEN="t", SUPABASE_SERVICE_ROLE_KEY="k")
        code, out = self.check("services", base, **secrets)
        self.assertEqual(code, 0, out)
        self.assertIn("::warning::GitHub secret REVENUECAT_WEBHOOK_AUTH is not set", out)
        selling = dict(base, **{"revenuecat.iosApiKey": "appl_x"})
        code, out = self.check("services", selling, **secrets)
        self.assertEqual(code, 1)
        self.assertIn("REVENUECAT_WEBHOOK_AUTH is not set, but config/app.json has a RevenueCat key", out)
        code, out = self.check("services", selling, REVENUECAT_WEBHOOK_AUTH="w", **secrets)
        self.assertEqual(code, 0, out)

    def test_services_ready_and_bad_push_keys(self):
        code, out = self.check("services", self.ready, FLY_API_TOKEN="t", SUPABASE_SERVICE_ROLE_KEY="k")
        self.assertEqual(code, 0, out)
        self.assertIn("web=ready", out)
        code, out = self.check("services", self.ready, FLY_API_TOKEN="t", SUPABASE_SERVICE_ROLE_KEY="k",
                               APNS_KEY_P8="nope", FCM_SERVICE_ACCOUNT_JSON='{"project_id": "p"}', FLY_WEB_APP="Bad_Name")
        self.assertEqual(code, 1)
        self.assertIn("APNS_KEY_P8 is not a .p8 key", out)
        self.assertIn("APNS_KEY_ID is not set", out)
        self.assertIn("FCM_SERVICE_ACCOUNT_JSON is not a Firebase service account key", out)
        self.assertIn("'bad_name' is not allowed", out)


class ConfigIdentityTest(unittest.TestCase):
    """The committed identity (decision 33, the store IDs) and app_identity.py's repository variables."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp)
        self.path = self.tmp / "app.json"
        shutil.copy(HERE.parents[1] / "config" / "app.json", self.path)

    def identity(self, **variables) -> tuple[int, str, dict]:
        environment = {k: v for k, v in os.environ.items() if k in ("PATH", "HOME", "LANG")}
        environment.update(APP_CONFIG_PATH=str(self.path), **variables)
        result = subprocess.run([sys.executable, str(HERE / "app_identity.py")], capture_output=True, text=True, env=environment)
        return result.returncode, result.stdout + result.stderr, json.loads(self.path.read_text())

    def test_committed_identity_matches_the_ios_build_settings(self):
        config = json.loads(self.path.read_text())
        self.assertEqual(config["domain"]["value"], "jolt-husamisverycool.fly.dev")
        self.assertEqual(config["ios"]["bundleId"], "com.husamisverycool.jolt")
        self.assertEqual(config["android"]["applicationId"], "com.husamisverycool.jolt")
        base = (HERE.parents[1] / "ios" / "Config" / "Base.xcconfig").read_text()
        self.assertIn("APP_DOMAIN = jolt-husamisverycool.fly.dev\n", base)
        self.assertIn("APP_BUNDLE_ID = com.husamisverycool.jolt\n", base)

    def test_domain_variable_moves_the_config(self):
        code, out, config = self.identity(APP_DOMAIN="Photos.Example.com")
        self.assertEqual(code, 0, out)
        self.assertEqual(config["domain"]["value"], "photos.example.com")
        self.assertIn("domain = photos.example.com", out)
        self.assertEqual(config["domain"]["level"], "OWNER", "the rest of the entry stays")

    def test_bad_domain_variable_stops_the_run(self):
        code, out, config = self.identity(APP_DOMAIN="https://photos.example.com/")
        self.assertEqual(code, 1)
        self.assertIn("APP_DOMAIN", out)
        self.assertEqual(config["domain"]["value"], "jolt-husamisverycool.fly.dev")

    def test_no_variables_keep_the_file(self):
        before = self.path.read_text()
        code, out, _ = self.identity()
        self.assertEqual(code, 0, out)
        self.assertIn("as in config/app.json", out)
        self.assertEqual(self.path.read_text(), before)


@unittest.skipUnless(shutil.which("keytool") and shutil.which("openssl"), "needs keytool and openssl")
class AndroidKeyTest(unittest.TestCase):
    def test_create_lock_unlock(self):
        tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmp)
        config = tmp / "app.json"
        shutil.copy(HERE.parents[1] / "config" / "app.json", config)
        environment = {**os.environ, "ANDROID_KEYSTORE_PASSWORD": "a long test password for the key", "RUNNER_TEMP": str(tmp),
                       "APP_CONFIG_PATH": str(config), "GITHUB_ENV": str(tmp / "env"), "GITHUB_STEP_SUMMARY": str(tmp / "summary.md"),
                       "JAVA_TOOL_OPTIONS": ""}
        locked = tmp / "upload.p12.enc"
        script = str(HERE / "android_key.py")
        created = subprocess.run([sys.executable, script, "create", "--out", str(locked)], capture_output=True, text=True, env=environment)
        self.assertEqual(created.returncode, 0, created.stdout + created.stderr)
        self.assertTrue(locked.read_bytes().startswith(b"Salted__"))
        fingerprint = json.loads(config.read_text())["android"]["sha256CertFingerprints"][-1]
        self.assertIn(fingerprint, (tmp / "summary.md").read_text())
        again = subprocess.run([sys.executable, script, "create", "--out", str(locked)], capture_output=True, text=True, env=environment)
        self.assertEqual(again.returncode, 1)
        self.assertIn("never replaces a key", again.stdout)
        prepared = subprocess.run([sys.executable, script, "prepare", "--locked", str(locked)], capture_output=True, text=True, env=environment)
        self.assertEqual(prepared.returncode, 0, prepared.stdout + prepared.stderr)
        written = dict(line.split("=", 1) for line in (tmp / "env").read_text().splitlines())
        self.assertEqual(written["ANDROID_UPLOAD_SHA256"], fingerprint)
        self.assertEqual(written["ANDROID_UPLOAD_KEY_ALIAS"], "upload")
        self.assertNotIn("::warning::", prepared.stdout)
        wrong = subprocess.run([sys.executable, script, "prepare", "--locked", str(locked)], capture_output=True, text=True,
                               env={**environment, "ANDROID_KEYSTORE_PASSWORD": "not the password at all, no"})
        self.assertEqual(wrong.returncode, 1)
        self.assertIn("does not unlock", wrong.stdout)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Before a release job runs: say, in plain words, which owner setup steps are still missing (docs/OWNER_SETUP.md).

    python3 tools/release/check_setup.py server      # "set up the server"
    python3 tools/release/check_setup.py testflight  # "send Jolt to TestFlight"
    python3 tools/release/check_setup.py android-key # "create the Android signing key"
    python3 tools/release/check_setup.py play        # "send Jolt to Google Play"
    python3 tools/release/check_setup.py services    # "start the background service"

Secrets are read from the environment (the workflow passes them); values are never printed.
Exit code 1 lists every missing step as a GitHub error annotation; optional steps still missing are warnings.
"""
import os
import sys

from release_common import (
    ANDROID_PACKAGE_RE,
    APP_STORE_ID_RE,
    BUNDLE_RE,
    DOMAIN_RE,
    FINGERPRINT_RE,
    FLY_NAME_RE,
    ROOT,
    TEAM_RE,
    annotate,
    env,
    fly_app_names,
    json_secret,
    load_config,
    set_env,
    set_output,
    supabase_ref,
)

config = load_config()
ENCRYPTED_KEY = ROOT / "android" / "keystore" / "upload.p12.enc"
MIN_KEY_PASSWORD = 20

missing: list[str] = []
warnings: list[str] = []


def need_secret(name: str, step: str) -> None:
    if not env(name):
        missing.append(f"GitHub secret {name} is not set — {step}")


def web_address() -> str:
    return f"{fly_app_names()[1]}.fly.dev"


def domain_problem() -> str | None:
    domain = ((config.get("domain") or {}).get("value") or "").strip()
    if not domain:
        return (f"config/app.json domain is not set — the address of invite links. No domain of your own yet? Use your invite "
                f"page's address {web_address()} (OWNER_SETUP.md §4): set it as the repository variable APP_DOMAIN, or put it in "
                "config/app.json \"domain\" → \"value\" and in ios/Config/Base.xcconfig APP_DOMAIN")
    if not DOMAIN_RE.fullmatch(domain):
        return (f"config/app.json domain {domain!r} is not a host name — just the name, like {web_address()}: no https:// and no / "
                "(the repository variable APP_DOMAIN, or config/app.json)")
    return None


def check_server() -> None:
    if not supabase_ref(config):
        missing.append("config/app.json supabase.url is not your project's URL (https://<ref>.supabase.co) — OWNER_SETUP.md §5")
    need_secret("SUPABASE_ACCESS_TOKEN", "Supabase → Account → Access Tokens (OWNER_SETUP.md §5)")
    need_secret("SUPABASE_DB_PASSWORD", "the database password chosen when the Supabase project was created (OWNER_SETUP.md §5)")


def check_app_has_server() -> None:
    supabase = config.get("supabase") or {}
    if not supabase_ref(config) or not supabase.get("anonKey"):
        missing.append("config/app.json supabase.url and supabase.anonKey are not set — the app would have no server (OWNER_SETUP.md §5)")


def check_testflight() -> None:
    for name, step in [
        ("APPLE_TEAM_ID", "developer.apple.com → Account → Membership details → Team ID (OWNER_SETUP.md §1)"),
        ("ASC_KEY_ID", "App Store Connect → Users and Access → Integrations → the API key's Key ID (OWNER_SETUP.md §1)"),
        ("ASC_ISSUER_ID", "App Store Connect → Users and Access → Integrations → Issuer ID (OWNER_SETUP.md §1)"),
        ("ASC_KEY_P8", "the downloaded AuthKey_….p8 file's whole text (OWNER_SETUP.md §1)"),
    ]:
        need_secret(name, step)
    problem = domain_problem()
    if problem:
        missing.append(problem)
    check_app_has_server()


def check_key_password() -> None:
    password = os.environ.get("ANDROID_KEYSTORE_PASSWORD", "")
    if not password.strip():
        missing.append("GitHub secret ANDROID_KEYSTORE_PASSWORD is not set — make up a long password (five or six random words) "
                       "and save it as this secret, and somewhere safe of your own (OWNER_SETUP.md §2)")
    elif len(password) < MIN_KEY_PASSWORD:
        missing.append(f"GitHub secret ANDROID_KEYSTORE_PASSWORD is too short — use at least {MIN_KEY_PASSWORD} characters "
                       "(five or six random words); the locked key is stored in the repository (OWNER_SETUP.md §2)")


def check_android_key() -> None:
    if os.environ.get("GITHUB_REF_TYPE", "branch") != "branch":
        missing.append("Run this workflow on a branch (Run workflow → \"Use workflow from\" → a branch), not a tag")
    if ENCRYPTED_KEY.exists():
        missing.append("An Android signing key already exists (android/keystore/upload.p12.enc) — this workflow never replaces a "
                       "key. Nothing to do: \"send Jolt to Google Play\" uses it")
        return
    check_key_password()


def check_play() -> None:
    # Store identity (app_identity.py has put the run's package name into config/app.json).
    package = (config.get("android") or {}).get("applicationId") or ""
    if not ANDROID_PACKAGE_RE.fullmatch(package):
        missing.append(f"The Android package name {package!r} is not a package name like com.yourname.jolt (OWNER_SETUP.md §2)")
    elif package.startswith("com.example."):
        missing.append(f"Google Play does not accept the package name {package} — create the app in Play Console with your own "
                       "(like com.yourname.jolt) and set it as the repository variable ANDROID_APPLICATION_ID (OWNER_SETUP.md §2)")

    # Signing: the key made by "create the Android signing key", else the older secrets.
    if ENCRYPTED_KEY.exists():
        if not env("ANDROID_KEYSTORE_PASSWORD"):
            missing.append("GitHub secret ANDROID_KEYSTORE_PASSWORD is not set — the password you chose when the Android "
                           "signing key was created (OWNER_SETUP.md §2)")
    elif env("ANDROID_UPLOAD_KEYSTORE_B64"):
        need_secret("ANDROID_KEYSTORE_PASSWORD", "the password of the keystore in ANDROID_UPLOAD_KEYSTORE_B64 (OWNER_SETUP.md §10)")
    else:
        missing.append("There is no Android signing key yet — run Actions → \"create the Android signing key\" → Run workflow "
                       "once (OWNER_SETUP.md §2)")
        if not env("ANDROID_KEYSTORE_PASSWORD"):
            check_key_password()

    try:
        account = json_secret("PLAY_SERVICE_ACCOUNT_JSON")
    except ValueError as err:
        missing.append(f"{err} (OWNER_SETUP.md §2)")
    else:
        if account is None:
            missing.append("GitHub secret PLAY_SERVICE_ACCOUNT_JSON is not set — the Google Cloud service account's .json key "
                           "that may upload to Play (OWNER_SETUP.md §2)")
        elif account.get("type") != "service_account" or not account.get("client_email") or not account.get("private_key"):
            missing.append("GitHub secret PLAY_SERVICE_ACCOUNT_JSON is not a service account key — in Google Cloud: IAM & Admin → "
                           "Service accounts → the account → Keys → Add key → JSON, then paste that file's text (OWNER_SETUP.md §2)")

    try:
        firebase = json_secret("ANDROID_GOOGLE_SERVICES_JSON")
    except ValueError as err:
        missing.append(f"{err} (OWNER_SETUP.md §3)")
    else:
        if firebase is None:
            warnings.append("GitHub secret ANDROID_GOOGLE_SERVICES_JSON is not set: this Android build will get no notifications "
                            "(OWNER_SETUP.md §3 — paste the text of Firebase's google-services.json)")
        else:
            packages = {
                ((client.get("client_info") or {}).get("android_client_info") or {}).get("package_name")
                for client in firebase.get("client") or []
            }
            if package and package not in packages:
                missing.append(f"The google-services.json in ANDROID_GOOGLE_SERVICES_JSON has no Android app {package} — in Firebase: "
                               f"Project settings → Your apps → Add app → Android, package {package}, then download "
                               "google-services.json again and paste its text (OWNER_SETUP.md §3)")

    if not (config.get("displayName") or {}).get("value"):
        missing.append("config/app.json displayName is not set — the name under the app's icon (OWNER_SETUP.md §0.1)")
    problem = domain_problem()
    if problem:
        missing.append(problem)
    check_app_has_server()


def web_problems() -> list[str]:
    """What keeps the invite page from starting (it refuses to run in production with any; web/src/config.ts)."""
    out: list[str] = []
    if not (config.get("supabase") or {}).get("anonKey"):
        out.append("config/app.json supabase.anonKey is not set (Supabase → Project Settings → API → anon public key; OWNER_SETUP.md §5)")
    problem = domain_problem()
    if problem:
        out.append(problem)
    ios = config.get("ios") or {}
    if not BUNDLE_RE.fullmatch(ios.get("bundleId") or ""):
        out.append("config/app.json ios.bundleId is not a bundle ID")
    team = ios.get("teamId")
    if not team:
        out.append("Apple Team ID missing — set the GitHub secret APPLE_TEAM_ID (developer.apple.com → Account → Membership "
                   "details) or config/app.json ios.teamId (OWNER_SETUP.md §1)")
    elif not TEAM_RE.fullmatch(str(team)):
        out.append("config/app.json ios.teamId is not a 10-character Team ID")
    store_id = ios.get("appStoreId")
    if store_id in (None, ""):
        out.append("config/app.json ios.appStoreId is not set — App Store Connect → your app → App Information → Apple ID "
                   "(a number); put it in config/app.json ios.appStoreId (OWNER_SETUP.md §1.10)")
    elif not APP_STORE_ID_RE.fullmatch(str(store_id).strip()):
        out.append("config/app.json ios.appStoreId is not the App Store's Apple ID (a number of 6 to 12 digits)")
    android = config.get("android") or {}
    if not ANDROID_PACKAGE_RE.fullmatch(android.get("applicationId") or ""):
        out.append("config/app.json android.applicationId is not a package name")
    prints = android.get("sha256CertFingerprints")
    if not isinstance(prints, list) or not prints:
        out.append("config/app.json android.sha256CertFingerprints is empty — run \"create the Android signing key\" (it adds its "
                   "fingerprint), and add Play Console → Test and release → App integrity → App signing key SHA-256 (OWNER_SETUP.md §2)")
    elif not all(isinstance(p, str) and FINGERPRINT_RE.fullmatch(p.upper()) for p in prints):
        out.append("config/app.json android.sha256CertFingerprints must look like \"AB:CD:…\" (32 pairs) — copy them from Play Console")
    for field in ("privacyUrl", "termsUrl"):
        url = (config.get("legal") or {}).get(field)
        if url and not str(url).startswith("https://"):
            out.append(f"config/app.json legal.{field} must start with https://")
    return out


def check_services() -> None:
    worker_app, web_app = fly_app_names()
    for variable, name in (("FLY_WORKER_APP", worker_app), ("FLY_WEB_APP", web_app)):
        if not FLY_NAME_RE.fullmatch(name):
            missing.append(f"The Fly.io app name {name!r} is not allowed — lowercase letters, digits and dashes only; set the "
                           f"repository variable {variable} to one")
    need_secret("FLY_API_TOKEN", "fly.io → your organization → Tokens → create an organization token (OWNER_SETUP.md §7)")
    if not supabase_ref(config):
        missing.append("config/app.json supabase.url is not your project's URL (https://<ref>.supabase.co) — OWNER_SETUP.md §5")
    need_secret("SUPABASE_SERVICE_ROLE_KEY", "Supabase → Project Settings → API → service_role secret (OWNER_SETUP.md §5)")

    if env("APNS_KEY_P8"):
        if "PRIVATE KEY" not in env("APNS_KEY_P8"):
            missing.append("GitHub secret APNS_KEY_P8 is not a .p8 key — open the AuthKey_….p8 file in TextEdit and paste all of it (OWNER_SETUP.md §1.3)")
        need_secret("APNS_KEY_ID", "the APNs key's Key ID, next to the key on developer.apple.com → Keys (OWNER_SETUP.md §1.3)")
        if not env("APNS_TEAM_ID"):
            missing.append("GitHub secret APPLE_TEAM_ID is not set — iPhone notifications need it (OWNER_SETUP.md §1)")
        if env("APNS_ENV") not in ("", "sandbox", "production"):
            missing.append("APNS_ENV must be production or sandbox (leave it unset for production)")
    else:
        warnings.append("GitHub secret APNS_KEY_P8 is not set: the service runs, but iPhones get no notifications (OWNER_SETUP.md §1.3)")

    try:
        fcm = json_secret("FCM_SERVICE_ACCOUNT_JSON")
    except ValueError as err:
        missing.append(f"{err} (OWNER_SETUP.md §3.2)")
    else:
        if fcm is None:
            warnings.append("GitHub secret FCM_SERVICE_ACCOUNT_JSON is not set: the service runs, but Android phones get no "
                            "notifications (OWNER_SETUP.md §3.2)")
        elif not all(fcm.get(k) for k in ("project_id", "client_email", "private_key")):
            missing.append("GitHub secret FCM_SERVICE_ACCOUNT_JSON is not a Firebase service account key — Firebase → Project "
                           "settings → Service accounts → Generate new private key, then paste that file's text (OWNER_SETUP.md §3.2)")
    if not env("REVENUECAT_WEBHOOK_AUTH"):
        warnings.append("GitHub secret REVENUECAT_WEBHOOK_AUTH is not set: subscriptions bought in the app are not recorded yet (OWNER_SETUP.md §6.2)")
    if env("REVENUECAT_WEBHOOK_AUTH") and not env("REVENUECAT_SECRET_KEY"):
        warnings.append("GitHub secret REVENUECAT_SECRET_KEY is not set: a deleted account's purchase record stays at RevenueCat (OWNER_SETUP.md §6.2)")
    if not env("ANTHROPIC_API_KEY"):
        print("::notice::No ANTHROPIC_API_KEY: weekly recaps use the plain order and template text (optional, OWNER_SETUP.md §6.3)")

    web = web_problems()
    for line in web:
        warnings.append(f"The invite page waits: {line}")
    # For the workflow's later steps: outputs for `if:` conditions, environment variables for scripts.
    for name, value in (("worker_app", worker_app), ("web_app", web_app), ("web", "wait" if web else "ready")):
        set_output(name, value)
        set_env(name.upper(), value)


MODES = {
    "server": check_server,
    "testflight": check_testflight,
    "android-key": check_android_key,
    "play": check_play,
    "services": check_services,
}

which = sys.argv[1] if len(sys.argv) > 1 else ""
if which not in MODES:
    sys.exit("usage: check_setup.py " + "|".join(MODES))
MODES[which]()

for line in warnings:
    annotate("warning", line)
if missing:
    for line in missing:
        annotate("error", line)
    sys.exit(1)
if which == "server":
    print(f"project ref: {supabase_ref(config)}")
print("setup: ok")

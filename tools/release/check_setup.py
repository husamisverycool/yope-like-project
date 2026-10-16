#!/usr/bin/env python3
"""Before a release job runs: say, in plain words, which owner setup steps are still missing (docs/OWNER_SETUP.md).

    python3 tools/release/check_setup.py server     # "Set up the server"
    python3 tools/release/check_setup.py testflight # "Send Jolt to TestFlight"

Secrets are read from the environment (the workflow passes them); values are never printed.
Exit code 1 lists every missing step as a GitHub error annotation.
"""
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
config = json.loads((ROOT / "config" / "app.json").read_text())

missing: list[str] = []


def need_secret(name: str, step: str) -> None:
    if not os.environ.get(name, "").strip():
        missing.append(f"GitHub secret {name} is not set — {step}")


def supabase_ref() -> str | None:
    url = (config.get("supabase") or {}).get("url") or ""
    match = re.match(r"^https://([a-z0-9]{20})\.supabase\.co/?$", url)
    return match.group(1) if match else None


which = sys.argv[1] if len(sys.argv) > 1 else ""
if which == "server":
    if not supabase_ref():
        missing.append("config/app.json supabase.url is not your project's URL (https://<ref>.supabase.co) — OWNER_SETUP.md §5")
    need_secret("SUPABASE_ACCESS_TOKEN", "Supabase → Account → Access Tokens (OWNER_SETUP.md §5)")
    need_secret("SUPABASE_DB_PASSWORD", "the database password chosen when the Supabase project was created (OWNER_SETUP.md §5)")
elif which == "testflight":
    for name, step in [
        ("APPLE_TEAM_ID", "developer.apple.com → Account → Membership details → Team ID (OWNER_SETUP.md §1)"),
        ("ASC_KEY_ID", "App Store Connect → Users and Access → Integrations → the API key's Key ID (OWNER_SETUP.md §1)"),
        ("ASC_ISSUER_ID", "App Store Connect → Users and Access → Integrations → Issuer ID (OWNER_SETUP.md §1)"),
        ("ASC_KEY_P8", "the downloaded AuthKey_….p8 file's whole text (OWNER_SETUP.md §1)"),
    ]:
        need_secret(name, step)
    supabase = config.get("supabase") or {}
    if not supabase_ref() or not supabase.get("anonKey"):
        missing.append("config/app.json supabase.url and supabase.anonKey are not set — the app would have no server (OWNER_SETUP.md §5)")
else:
    sys.exit("usage: check_setup.py server|testflight")

if missing:
    for line in missing:
        print(f"::error::{line}")
    sys.exit(1)
if which == "server":
    print(f"project ref: {supabase_ref()}")
print("setup: ok")

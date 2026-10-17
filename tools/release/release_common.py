"""Helpers shared by the release scripts in tools/release/ (standard library only).

Secrets come from the environment (the workflow passes them); no helper here prints a secret value.
"""
import base64
import binascii
import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# APP_CONFIG_PATH: another config/app.json (tests); the web service reads the same variable.
CONFIG_PATH = Path(os.environ.get("APP_CONFIG_PATH") or ROOT / "config" / "app.json")

# The same shapes the invite page accepts (web/src/config.ts); a value it would reject stops it from starting.
DOMAIN_RE = re.compile(r"^(?=.{1,253}$)([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$", re.I)
TEAM_RE = re.compile(r"^[A-Z0-9]{10}$")
BUNDLE_RE = re.compile(r"^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$")
ANDROID_PACKAGE_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$")
FINGERPRINT_RE = re.compile(r"^([0-9A-F]{2}:){31}[0-9A-F]{2}$")
APP_STORE_ID_RE = re.compile(r"^[0-9]{6,12}$")
FLY_NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$")

# Same default as "send Jolt to TestFlight" (.github/workflows/testflight.yml), so both stores carry one identity.
DEFAULT_APP_ID = "com.husamisverycool.jolt"


def load_config() -> dict:
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def save_config(config: dict) -> None:
    """config/app.json is hand-edited: 2-space indent, UTF-8 kept as is, newline at the end."""
    CONFIG_PATH.write_text(json.dumps(config, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def env(name: str) -> str:
    return os.environ.get(name, "").strip()


def json_secret(name: str) -> dict | None:
    """A JSON key file pasted into a GitHub secret: its text as is, or base64 of it. None when the secret is empty.

    Raises ValueError (with a plain-language message, never the value) when it is neither.
    """
    raw = env(name)
    if not raw:
        return None
    text = raw
    if not raw.startswith("{"):
        try:
            text = base64.b64decode("".join(raw.split()), validate=True).decode("utf-8")
        except (binascii.Error, UnicodeDecodeError):
            raise ValueError(f"GitHub secret {name} is not the text of a .json file — open the downloaded .json file in "
                             "TextEdit, copy everything (⌘A, ⌘C) and paste it as the secret's value") from None
    try:
        value = json.loads(text)
    except json.JSONDecodeError:
        raise ValueError(f"GitHub secret {name} is not complete JSON — paste the whole text of the .json file, from the "
                         "first {{ to the last }}") from None
    if not isinstance(value, dict):
        raise ValueError(f"GitHub secret {name} is not a .json key file")
    return value


def review_phone_digits(raw: str) -> str | None:
    """The review account's phone as Supabase's test-OTP list wants it (country code and number, digits only), or None
    when it is not a phone number: "+1 (201) 555-0142" → "12015550142"."""
    text = raw.strip()
    if not text.startswith("+"):
        return None
    digits = re.sub(r"[\s().-]", "", text[1:])
    return digits if re.fullmatch(r"[1-9][0-9]{6,14}", digits) else None


# Supabase's management API takes the test codes as "<phone digits>=<code digits>" (its sms_test_otp pattern
# ^([0-9]{1,15}=[0-9]+,?)*$); the apps' code field takes any number of digits.
REVIEW_CODE_RE = re.compile(r"^[0-9]+$")


def supabase_ref(config: dict) -> str | None:
    url = (config.get("supabase") or {}).get("url") or ""
    match = re.match(r"^https://([a-z0-9]{20})\.supabase\.co/?$", url)
    return match.group(1) if match else None


def repo_owner() -> str:
    owner = os.environ.get("GITHUB_REPOSITORY_OWNER") or os.environ.get("GITHUB_REPOSITORY", "").partition("/")[0]
    return re.sub(r"[^a-z0-9-]+", "-", owner.lower()).strip("-")


def fly_app_names() -> tuple[str, str]:
    """(worker app, web app) on Fly.io. Names are global across Fly.io, so they carry the GitHub owner's name unless the
    repository variables FLY_WORKER_APP / FLY_WEB_APP choose others."""
    owner = repo_owner() or "your-github-name"

    def name(variable: str, prefix: str) -> str:
        chosen = env(variable).lower()
        return chosen if chosen else f"{prefix}-{owner}"[:63].rstrip("-")

    return name("FLY_WORKER_APP", "jolt-worker"), name("FLY_WEB_APP", "jolt")


def annotate(kind: str, message: str) -> None:
    """kind: error | warning | notice — shown on the run's page in GitHub."""
    print(f"::{kind}::{message}", flush=True)


def write_summary(markdown: str) -> None:
    """Append to the run's summary page (GitHub → Actions → the run); printed when run outside GitHub."""
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a", encoding="utf-8") as fh:
            fh.write(markdown.rstrip("\n") + "\n\n")
    else:
        print(markdown)


def set_output(name: str, value: str) -> None:
    path = os.environ.get("GITHUB_OUTPUT")
    if path:
        with open(path, "a", encoding="utf-8") as fh:
            fh.write(f"{name}={value}\n")
    else:
        print(f"{name}={value}")


def set_env(name: str, value: str) -> None:
    """For the job's later steps (GITHUB_ENV)."""
    path = os.environ.get("GITHUB_ENV")
    if path:
        with open(path, "a", encoding="utf-8") as fh:
            fh.write(f"{name}={value}\n")
    os.environ[name] = value

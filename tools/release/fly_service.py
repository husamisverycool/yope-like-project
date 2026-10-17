#!/usr/bin/env python3
"""Fly.io steps of "start the background service" (.github/workflows/services.yml), with plain-language errors.

    fly_service.py ensure-app NAME           # create the Fly.io app on the first run (names are global on Fly.io)
    fly_service.py secrets worker|web NAME   # hand the GitHub secrets to the app (staged; the deploy applies them)
    fly_service.py wait LABEL URL [URL …]    # until each address answers 200; reports on the run's summary page
    fly_service.py cert NAME DOMAIN          # HTTPS certificate for your own domain (not needed for *.fly.dev)

flyctl reads FLY_API_TOKEN from the environment. Secret values go to flyctl on standard input (`NAME=-`), never on a
command line, and are never printed.
"""
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request

from release_common import annotate, env, json_secret, load_config, supabase_ref, write_summary


class Problem(Exception):
    pass


def flyctl(*args: str, stdin: str | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(["flyctl", *args], input=stdin, capture_output=True, text=True)


def last_line(result: subprocess.CompletedProcess) -> str:
    lines = (result.stderr or result.stdout).strip().splitlines()
    return lines[-1] if lines else f"exit {result.returncode}"


def ensure_app(name: str) -> None:
    listed = flyctl("apps", "list", "--json")
    if listed.returncode != 0:
        text = (listed.stderr + listed.stdout).lower()
        if "unauthorized" in text or "token" in text or "authenticat" in text:
            raise Problem("Fly.io did not accept FLY_API_TOKEN — make a new token (fly.io → your organization → Tokens) and "
                          "paste all of it, starting with FlyV1, as the GitHub secret FLY_API_TOKEN")
        raise Problem(f"Could not list the apps on Fly.io: {last_line(listed)}")
    try:
        names = {app.get("Name") or app.get("name") for app in json.loads(listed.stdout or "[]")}
    except json.JSONDecodeError:
        names = set()
    if name in names:
        print(f"{name}: already on Fly.io")
        return
    args = ["apps", "create", name]
    if env("FLY_ORG"):
        args += ["--org", env("FLY_ORG")]
    created = flyctl(*args)
    if created.returncode == 0:
        print(f"{name}: created on Fly.io")
        return
    text = (created.stderr + created.stdout).lower()
    if "taken" in text or "already exists" in text or "not unique" in text:
        raise Problem(f"The Fly.io name {name} belongs to someone else. Choose another: GitHub → Settings → Secrets and "
                      "variables → Actions → Variables → New repository variable FLY_WORKER_APP (worker) or FLY_WEB_APP "
                      "(invite page) = a name of your own (lowercase letters, digits, dashes), then run this again")
    if "org slug must be specified" in text or ("organization" in text and "not found" in text):
        raise Problem("Fly.io needs to know which organization to use: set the repository variable FLY_ORG to its short "
                      "name (fly.io → Dashboard → the organization's name in the address bar, e.g. personal)")
    if "payment" in text or "credit card" in text or "billing" in text:
        raise Problem("Fly.io wants a payment method before it creates apps: fly.io → Dashboard → Billing → add a card, "
                      "then run this again")
    raise Problem(f"Fly.io did not create the app {name}: {last_line(created)}")


def worker_secrets() -> dict[str, str]:
    config = load_config()
    values = {
        "SUPABASE_URL": f"https://{supabase_ref(config)}.supabase.co",
        "SUPABASE_SERVICE_ROLE_KEY": env("SUPABASE_SERVICE_ROLE_KEY"),
    }
    if env("APNS_KEY_P8"):
        values.update({
            "APNS_KEY_P8": env("APNS_KEY_P8"),
            "APNS_KEY_ID": env("APNS_KEY_ID"),
            "APNS_TEAM_ID": env("APNS_TEAM_ID"),
            # The iPhone app's bundle ID this run uses (app_identity.py; the same one TestFlight builds).
            "APNS_BUNDLE_ID": config["ios"]["bundleId"],
            "APNS_ENV": env("APNS_ENV") or "production",
        })
    fcm = json_secret("FCM_SERVICE_ACCOUNT_JSON")
    if fcm:
        values["FCM_SERVICE_ACCOUNT_JSON"] = json.dumps(fcm)
    for name in ("REVENUECAT_WEBHOOK_AUTH", "REVENUECAT_SECRET_KEY", "ANTHROPIC_API_KEY", "RECAP_MODEL", "MODERATION_WEBHOOK_URL"):
        if env(name):
            values[name] = env(name)
    return values


def web_secrets() -> dict[str, str]:
    config = load_config()
    return {
        "SUPABASE_URL": f"https://{supabase_ref(config)}.supabase.co",
        "SUPABASE_ANON_KEY": config["supabase"]["anonKey"],
        "SUPABASE_SERVICE_ROLE_KEY": env("SUPABASE_SERVICE_ROLE_KEY"),
    }


def set_secrets(which: str, app: str) -> None:
    values = worker_secrets() if which == "worker" else web_secrets()
    for name, value in values.items():
        result = flyctl("secrets", "set", f"{name}=-", "--app", app, "--stage", stdin=value)
        if result.returncode != 0:
            raise Problem(f"Fly.io did not take the setting {name} for {app}: {last_line(result)}")
    print(f"{app}: {len(values)} settings handed over ({', '.join(values)})")


def get(url: str) -> tuple[int, str]:
    request = urllib.request.Request(url, headers={"User-Agent": "jolt-release-check"})
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            return response.status, response.read(2000).decode("utf-8", "replace")
    except urllib.error.HTTPError as err:
        return err.code, ""
    except (urllib.error.URLError, OSError) as err:
        return 0, str(err)


def wait(label: str, urls: list[str], attempts: int = 20, delay: float = 6) -> None:
    lines = []
    for url in urls:
        status = 0
        for attempt in range(attempts):
            status, _ = get(url)
            if status == 200:
                break
            time.sleep(delay)
        if status != 200:
            write_summary(f"- {label}: **{url} did not answer** (last status {status or 'no answer'}). Fly.io → Dashboard → the app → "
                          "Logs shows why.")
            raise Problem(f"{url} did not answer after the deploy (status {status or 'no answer'}) — open fly.io → the app → "
                          "Logs; the first lines after \"Starting\" say what is missing")
        lines.append(url)
        print(f"{url}: 200")
    write_summary("\n".join(f"- {label}: {url} answers." for url in lines))


def cert(app: str, domain: str) -> None:
    added = flyctl("certs", "add", domain, "--app", app)
    text = (added.stderr + added.stdout).lower()
    if added.returncode != 0 and "already" not in text:
        raise Problem(f"Fly.io did not start a certificate for {domain}: {last_line(added)}")
    shown = flyctl("certs", "show", domain, "--app", app)
    write_summary("\n".join([
        f"### Your domain {domain}",
        "",
        "At the company where you bought the domain, add the DNS records Fly.io asks for below (it can take an hour before "
        "the certificate is issued; run this workflow again to check):",
        "",
        "```",
        (shown.stdout or added.stdout).strip(),
        "```",
    ]))


def main(argv: list[str]) -> int:
    try:
        if len(argv) == 2 and argv[0] == "ensure-app":
            ensure_app(argv[1])
        elif len(argv) == 3 and argv[0] == "secrets" and argv[1] in ("worker", "web"):
            set_secrets(argv[1], argv[2])
        elif len(argv) >= 3 and argv[0] == "wait":
            wait(argv[1], argv[2:])
        elif len(argv) == 3 and argv[0] == "cert":
            cert(argv[1], argv[2])
        else:
            print(__doc__)
            return 2
    except Problem as err:
        annotate("error", str(err))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
